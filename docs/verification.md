# Verification

What the repository's checks prove. Compression returning a plausible size is
not proof that a stream is valid: the output must be decoded and compared, and
at least one decoder must be independent of this binding.

## Commands

| Command | What it proves |
|---|---|
| `make check` | `goose check deflate.goose` succeeds |
| `make test` | Contract test runs in-process, debug-compiled, and optimized-compiled; a native test verifies thread-local status isolation |
| `make interop` | Python zlib and system gzip read/write streams interoperably; checksums and examples are exercised |
| `make examples` | Each example root typechecks with the selected Goose compiler |
| `make verify` | `check`, `test`, `interop` and `examples` all pass |
| `make bench` | Runs the corpus comparison against zlib; measurement, not a correctness gate |
| `make overhead` | Measures Goose API overhead against direct C calls; measurement only |

`GOOSE=/path/to/goose` selects the compiler. Interop requires Python 3 and
`gzip`. `make overhead` needs Python 3, CMake and GCC/Clang; the zlib corpus
benchmark additionally needs zlib development headers.

## Goose tests: `test/test_deflate.goose`

The test root includes deterministic and randomized checks across all three
formats and all thirteen compression levels. It covers:

- known streams produced by independent zlib/gzip implementations;
- empty, one-byte, text, zero-filled and pseudorandom input;
- sizes at format/block/buffer boundaries and larger multi-block inputs;
- compression bounds, fixed output buffers, one-byte-short and overlapping
  buffers, plus reused compressor/decompressor handles;
- appending after existing bytes and restoring the builder after failures;
- `Info.in_nbytes` and `Info.out_nbytes`, trailing data, and concatenated
  streams decoded one member at a time;
- corrupt checksums, invalid format, truncation, unsupported preset dictionaries,
  output-size limits, exact-size short/long outputs and zero-sized outputs;
- deterministic output, checksum known answers, checksum continuation, version
  reporting, bool/status agreement on each operation, error text and clearing on
  success, invalid-level reporting, and safe invalid-argument handling.

The test emits a check count. Assertions compare the decompressed result to the
original bytes; both the bool result and the immediately observed per-thread
`status()` are checked. `test/status_threads.goose` runs natively and proves one
worker's success or failure does not overwrite the caller thread's status.

## Independent interoperability: `test/interop.sh`

The script exercises the package through `test/tool.goose` and uses Python's
`zlib` and the system `gzip` as independent implementations. It checks that
this package's raw/zlib/gzip streams can be read externally, that externally
produced streams can be decoded here, and that gzip examples produce the
expected data. Python checks are important because two paths in the same
libdeflate binding could agree on the same bug.

## CI matrix

GitHub Actions checks out the pinned libdeflate submodule, installs the pinned
Goose compiler release, and uses the host C compiler/CMake to build and run the
Goose test on linux-x64, macos-x64, macos-arm64 and windows-x64. Every leg
typechecks and format-checks the package, runs the test program, and checks
examples. The Linux leg additionally runs
interoperability against Python zlib and gzip. The matrix checks the actual source build rather than
assuming a compatible system `libdeflate` is installed.

Documentation-only changes are filtered from CI because prose cannot change
the native build; edits to workflow, source, build file, tests or examples do
run the matrix.
