# Internals

How the binding is put together and the invariants that are easy to miss when
reading one file. The [guide](guide.md) is for callers;
[coverage](coverage.md) maps upstream's API surface; [verification](verification.md)
explains what the tests prove.

## Native source and version

`vendor/libdeflate` is a git submodule pinned at upstream commit
`92e6a0db9fa848d742f9eb286c92afc60f2c3dda` (release **1.26**). The package
builds its static library through `CMakeLists.txt`; it does not link to a
system-installed libdeflate. The gitlink is the exact source pin, while
`.gitmodules` records only the upstream URL. Initialize the checkout with
`git submodule update --init --depth 1 vendor/libdeflate`.

`CMakeLists.txt` disables the upstream shared library, command-line gzip tool,
test suite and install rules, then links the static codec into
`goose_libdeflate`. Upstream CMake owns the architecture-specific source list,
assembler feature checks and runtime CPU dispatch. The package adapter is
`include/deflate.h`; `deflate.build` adds that header to generated Goose C and
names the CMake target.

A vendor update is deliberate:

1. Fetch and review the intended upstream commit or tag in the submodule, then
   commit the new gitlink. Update `vendor/README.md` to document the new pin.
2. Update `VERSION_MAJOR` / `VERSION_MINOR` and verify `gdf_version_*` reports
   the linked header version.
3. Re-check CMake's source selection, the inline adapter and result enum static
   assertions. Run `make verify` and compare benchmark results on the same
   machine before publishing.

## Why the C boundary is small

For native GCC/Clang/MSVC builds, Goose splices `include/deflate.h` into the
application's generated C. Adapter functions use `GDF_INLINE`, defaulting to a
compiler-specific always-inline form, so slice unpacking, format selection and
the libdeflate call can live in the caller's generated function. There is no
separate out-of-line `gdf_*` hop on that path.

TinyCC cannot use those native inline definitions. Under `__TINYC__` the header
body is omitted from generated code, and `src/native.c` includes the same header
with `GDF_INLINE` empty. That emits ordinary C adapter functions into the
CMake-built static target for the JIT to call. One implementation therefore
serves the optimized native and TinyCC backends without maintaining two adapter
bodies.

The native handle is an opaque `u64` representation of libdeflate's pointer.
`gdf_decompress` writes the two counts through a Goose `i64[:]`; it uses
`memcpy` because Goose arrays may be packed and must not be cast to an aligned
`int64_t *`. `Info` is assembled in Goose from those two counts. Empty slices
use a non-null dummy pointer because libdeflate may interpret a null pointer as
special even when the byte count is zero. Empty checksum calls return their
initial value rather than passing a null pointer upstream.

## Ownership and errors

libdeflate allocates reusable compressor and decompressor contexts with
`malloc`. Ordinary builder and fixed-buffer one-shot functions allocate a
context, perform one operation, and close it inside that call. The caller gets
Goose builder/buffer ownership without a native resource to release.

The advanced reusable API returns `(handle, bool)`. The caller scopes each
successful handle with `defer close(handle)`, does not copy a live handle, and
uses one handle per concurrent thread. A false constructor records
`BadLevel` or `OutOfMemory`; an operation on a closed handle records `Closed`.

`include/deflate.h` keeps the last result in C thread-local storage. Each
fallible Goose operation records success as well as failure, so `status()` and
`error()` refer to the latest call on the current thread, not stale history.
The C implementation spells thread-local storage as `_Thread_local` or
`__declspec(thread)` for MSVC. `test/status_threads.goose` verifies that a worker
cannot overwrite the caller thread's status.

## FFI and result mapping

Goose slices cross as packed `{data, len}` values. `Info` does not cross the C
boundary directly: Goose uses an `i64[2]` counts buffer and C copies into it.
Handles cross as `u64`. Keep these declarations aligned between
`deflate.goose`, `include/deflate.h`, and the packed slice ABI.

The adapter translates upstream `libdeflate_result` values into the public
`Status` codes. `_Static_assert`s in `include/deflate.h` pin the native values
used for `Success`, `BadData`, `ShortOutput` and `InsufficientSpace`. Local
validation statuses occupy distinct values. Do not rely on ordinal conversion
between the Goose enum and C integer codes; `status_of` and `status_code` are
the mapping.

`Format` is mapped to stable codes in Goose: raw DEFLATE=0, zlib=1, gzip=2.
Only values created from `Format` should reach the adapter. The format switch
is intentionally inline for native C builds and shared with TinyCC through the
fallback adapter.

## API invariants

1. **Ordinary calls hide native lifetime.** One-shot calls close their
   temporary context in the same scope. Keep cleanup in a `defer` so new early
   returns cannot leak it.
2. **Reusable handles are advanced.** Constructors return `(handle, bool)`;
   bool-returning calls on closed handles report `Status.Closed`. Scalar
   `compress_bound` returns its 0 sentinel and records `Closed`.
3. **Compression bounds are upstream's contract.** Builder `compress` reserves
   `compress_bound` bytes. `compress_into` returns `(written, bool)` and reports
   insufficient output through `error()`; zero is not a successful empty
   stream.
4. **Decompression is capped.** Builder `decompress` grows output only up to
   `max_size`. Preserve zero-size behavior, overflow-safe retries and rollback
   on failure. A caller-supplied cap is the defense against expansion bombs.
5. **`Info` counts the first stream.** The `_ex` API reports consumed input and
   produced output. Trailing input remains with the caller; do not silently
   concatenate members.
6. **Statuses belong to the thread's latest call.** Keep result mapping
   centralized in `status_of`/`status_code` and always record success as well
   as failure. Callers must read `error()` before another fallible operation on
   the same thread.
7. **Checksums are part of validation.** zlib and gzip trailer checks are
   performed by libdeflate. Optional gzip-header CRC handling follows upstream
   behavior and is not an extra guarantee of this wrapper.
8. **No streaming is implied.** libdeflate requires complete buffers. Do not
   add a `Writer`/`Reader` state machine without a real streaming backend and a
   separate design for lifecycle, chunking, truncation and bounds.

## Review gates

- API or behavior changes: add/adjust Goose contract tests and independent
  Python zlib/gzip interoperability tests.
- Inline adapter, FFI, buffer sizing, pointer conversion or status mapping:
  run the full test suite, including the native TLS test, and inspect the build
  on each CI platform.
- Submodule version changes: review the new gitlink, CMake selection and CPU
  dispatch, then run the full suite and refresh benchmark results. Keep
  upstream code pristine.
- README/API examples: typecheck examples and keep `docs/verification.md`
  current.
