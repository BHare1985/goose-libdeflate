# Agent notes

This repository binds upstream libdeflate 1.26 to Goose as package version
0.2.0. The public API is in **[deflate.goose](deflate.goose)**; the native
boundary is the inline adapter in **[src/libdeflate.h](src/libdeflate.h)**,
with the TinyCC fallback emitted by [src/libdeflate.c](src/libdeflate.c). Read those and
[CMakeLists.txt](CMakeLists.txt) before changing the binding. `vendor/libdeflate/`
is a pinned submodule and should stay unmodified.

The design follows igzip's bool-plus-error call convention while respecting
libdeflate's whole-buffer API and native context allocations. Fallible calls
return bool and record a typed per-thread `Status` for `status()` / `error()`;
one-shot operations own their temporary contexts, while reusable handles use
`defer close(...)`. See [docs/internals.md](docs/internals.md) for ownership and
error policy, [docs/guide.md](docs/guide.md) for caller patterns, and
[ROADMAP.md](ROADMAP.md) for deliberate limits.

## Layout

| Path | What it is |
|---|---|
| `deflate.goose` | Public Goose module: formats, typed statuses, handles, buffer management, checksums |
| `deflate.build` | Goose `.build` sidecar: CMake target and inline C header |
| `CMakeLists.txt` | Builds static libdeflate plus the TinyCC adapter fallback |
| `src/libdeflate.h` | `GLD_INLINE` native FFI adapter and thread-local status slot |
| `src/libdeflate.c` | Emits ordinary external adapter functions for TinyCC from the same header |
| `vendor/libdeflate/` | Upstream libdeflate 1.26 submodule, pinned by gitlink; do not patch |
| `.gitmodules` | Upstream submodule URL; exact revision is the gitlink |
| `test/test_deflate.goose`, `test/status_threads.goose` | API contracts and native per-thread status isolation |
| `test/interop.sh` | Independent interoperability checks with gzip and Python zlib |
| `test/run_tests.sh` | In-process, debug, optimized and native thread-local status tests |
| `examples/*.goose` | File compression/decompression and round-trip programs |
| `bench/` | Corpus benchmark, zlib shim and benchmark results |
| `docs/` | Usage guide, coverage map, internals, verification contract |
| `.github/workflows/ci.yml` | Multi-platform build and test workflow |
| `.pi/` | Project-local Goose skill, references, examples, and pi prompts |

## Commands

| Command | Meaning |
|---|---|
| `make check` | Typecheck `deflate.goose` |
| `make test` | Run contract tests and native per-thread status test |
| `make interop` | Test both directions against gzip and Python zlib |
| `make examples` | Typecheck every example |
| `make verify` | All correctness checks above |
| `make bench` | Download corpora, run zlib comparison and update `bench/RESULTS.md` |
| `make overhead` | Compare Goose bindings with direct C calls to the same libdeflate build |
| `make fmt` | Format Goose sources |
| `make submodule` | Initialize the pinned libdeflate submodule |

Set `GOOSE=/path/to/goose` to select a compiler. Builds need git, CMake 3.20+
and a C compiler. Interop needs Python 3 and `gzip`; the overhead benchmark
needs Python 3; the zlib corpus benchmark also needs zlib development headers.

## Goose and FFI rules

Load the project-local Goose skill (`.pi/skills/goose-lang/SKILL.md`) before
non-trivial Goose changes. Read `.pi/skills/goose-lang/references/language.md`
before inventing syntax, and `memory.md` before changing references or buffer
storage. Goose has no garbage collector, destructors or lifetime annotations;
do not assume Rust, C++ or Zig semantics.

Keep these binding invariants in mind:

1. **Preserve FFI layouts.** Goose slices cross as packed `{ data, len }`
   values. The inline adapter copies decompression counts through an `i64[:]`
   slice into `deflate::Info`; native handles cross as `u64`. Keep C and Goose
   representations in sync and verify both native and TinyCC builds.
2. **One-shot APIs own their contexts.** Reusable constructors return
   `(handle, bool)`; use `defer close(handle)` and do not copy, use-after-close,
   or share a handle concurrently between threads.
3. **Errors follow igzip.** Return bool, record outcomes (success too) through
   the C thread-local status slot, and expose typed `status()` / `error()`.
   Keep mapping centralized in `status_of`; static assertions pin upstream
   result values. Do not introduce process-global error state.
4. **Keep the API whole-buffer.** libdeflate does not stream. Preserve output
   sizing, rollback on decompression failure, `max_size`, and consumed/produced
   byte counts.
5. **Keep upstream pristine.** Change `src/libdeflate.h` or `CMakeLists.txt`
   rather than patching `vendor/libdeflate/`. Upstream CMake owns CPU feature
   detection and runtime dispatch.
6. **Independently decode output.** Same-library round trips are necessary but
   not sufficient. Keep Python zlib/gzip interoperability in `make verify`.

Run `make check` after Goose edits and `make verify` for behavioral or FFI
changes. A plausible compressed byte count is not proof of a valid stream.
