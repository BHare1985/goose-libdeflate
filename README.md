# goose-libdeflate

Package version **0.2.0**, backed by upstream libdeflate **1.26**. The Goose
import tag follows the package version, not the codec's version.

[![linux-x64](https://img.shields.io/github/actions/workflow/status/BHare1985/goose-libdeflate/ci.yml?branch=main&job=linux-x64&label=linux-x64)](https://github.com/BHare1985/goose-libdeflate/actions/workflows/ci.yml)
[![macos-x64](https://img.shields.io/github/actions/workflow/status/BHare1985/goose-libdeflate/ci.yml?branch=main&job=macos-x64&label=macos-x64)](https://github.com/BHare1985/goose-libdeflate/actions/workflows/ci.yml)
[![macos-arm64](https://img.shields.io/github/actions/workflow/status/BHare1985/goose-libdeflate/ci.yml?branch=main&job=macos-arm64&label=macos-arm64)](https://github.com/BHare1985/goose-libdeflate/actions/workflows/ci.yml)
[![windows-x64](https://img.shields.io/github/actions/workflow/status/BHare1985/goose-libdeflate/ci.yml?branch=main&job=windows-x64&label=windows-x64)](https://github.com/BHare1985/goose-libdeflate/actions/workflows/ci.yml)

[libdeflate](https://github.com/ebiggers/libdeflate) for
[Goose](https://github.com/aardappel/goose): fast compression and decompression
for raw DEFLATE, zlib and gzip, plus CRC-32 and Adler-32. Package version
0.2.0 builds upstream libdeflate 1.26 from a pinned git submodule; it does not
depend on a system libdeflate installation.

```goose
import deflate from "github.com/bhare1985/goose-libdeflate@v0.2.0";
```

The package tag and upstream codec version are deliberately independent.
The first build needs git (to initialize the submodule), CMake 3.20+, and a C
compiler (gcc, clang or MSVC). Goose builds the vendored codec; no system
libdeflate is needed. Both `goose program.goose` and `goose build program.goose`
work. CI builds and tests on linux-x64, macos-x64, macos-arm64 and windows-x64.

## Why libdeflate

On the Calgary and Canterbury corpora, through this package and with the same
buffers and zlib-format output:

| | zlib | libdeflate | Speedup |
|---|---:|---:|---:|
| compress, level 6 | 26 MB/s | 79 MB/s | 3.0x |
| compress, level 1 | 101 MB/s | 218 MB/s | 2.2x |
| decompress, level 6 | 340 MB/s | 919 MB/s | 2.7x |
| CRC-32 | 4.3 GB/s | 12.3 GB/s | 2.8x |

libdeflate also produced smaller output on this corpus: 1.78 MB versus zlib's
1.79 MB at level 6, and 1.74 MB versus 1.78 MB at level 9. Levels 10–12 search
harder still (1.69 MB at level 12 here), at lower throughput. Full per-file
results and the benchmark method are in [bench/RESULTS.md](bench/RESULTS.md).
See [bench/README.md](bench/README.md) for the zlib comparison and the Goose
binding-overhead versus direct-C benchmark.
Numbers vary by machine; these were measured on an AMD Ryzen 5 3550H under Linux.

libdeflate works on complete buffers in memory. It has no streaming interface.
For data larger than memory, process independent chunks and store each chunk's
uncompressed size alongside it, or choose a streaming codec.

## Quick start

```goose
import deflate from "github.com/bhare1985/goose-libdeflate@v0.2.0";
import std;

fn main() {
    var packed: u8[>..] = [];
    guard deflate::compress(packed, "hello hello hello hello", deflate::Format.Gzip) else {
        print("compression failed: ", deflate::error());
        exit(1);
    }

    var plain: u8[>..] = [];
    guard deflate::decompress(plain, packed, deflate::Format.Gzip) else {
        print("decompression failed: ", deflate::error());
        exit(1);
    }
    print(plain);
}
```

The builder forms append bytes. If decompression fails, the builder is restored
to its original length. Ordinary one-shot calls own and release their temporary
native contexts; callers do not manage handles. For fixed-buffer operation and
reusable contexts, see below and the detailed [guide](docs/guide.md).

## API shape

### Formats and levels

`Format.Deflate` is raw DEFLATE (RFC 1951), `Format.Zlib` is zlib (RFC 1950),
and `Format.Gzip` is gzip (RFC 1952). Compression levels run from 0 to 12: 0
stores data, 1 is fastest, 6 is the default, and 12 searches hardest. A stream
can be larger than its input, especially at level 0 or for short inputs.

### Reuse a compressor and your own buffers

The convenience form allocates a compressor for the call. To process many
buffers, keep one compressor and reserve the upstream worst-case bound once:

```goose
let c, opened = deflate::compressor(6);
guard opened else { print(deflate::error()); exit(1); };
defer deflate::close(c);
var out: u8[>..] = [];
out.resize(deflate::compress_bound(c, 65536, deflate::Format.Zlib), 0);

// For each input of at most 65536 bytes:
let n, ok = deflate::compress_into(c, out, data, deflate::Format.Zlib);
guard ok else { print(deflate::error()); exit(1); };
write_stdout(out[..n]);
```

`compress_bound` guarantees the buffer capacity required for that size, format
and compressor. `compress_into` returns the byte count plus a bool; on false,
`error()` explains the failure. `compress` appends and manages that temporary
capacity for you. The one-shot calls return false for invalid levels or native
allocation failures instead of asserting.

### Decompression and failure

A call that can fail returns a bool, and its failure reason is available from
`deflate::error()` / `deflate::status()` on the current thread. Check it
immediately after a false result; the next operation replaces it. This is the
same call shape as igzip and Goose's graphics APIs, not a status value threaded
through every helper.

| Status | Meaning |
|---|---|
| `Status.Ok` | Most recent operation succeeded |
| `Status.BadData` | Corrupt, wrong format, or unsupported data such as a preset zlib dictionary |
| `Status.ShortOutput` | `decompress_exact` produced fewer bytes than the requested size |
| `Status.InsufficientSpace` | Output exceeded the configured cap or fixed destination |
| `Status.InvalidArgument` | Negative cap/size, overlapping input/output, or an unrepresentable builder size |
| `Status.BadLevel` | Compression level is outside 0–12 |
| `Status.OutOfMemory` | libdeflate could not allocate a native context |
| `Status.Closed` | A reusable handle has already been closed |
| `Status.Other` | An unrecognized native failure |

Input and output byte ranges must not overlap. The adapter rejects overlap as
`InvalidArgument`; keep separate source and destination buffers.

Use `Info` when a stream is followed by more data. `in_nbytes` identifies where
the first stream ended; `out_nbytes` is how many bytes it produced:

```goose
let d, opened = deflate::decompressor();
guard opened else { print(deflate::error()); exit(1); };
defer deflate::close(d);
var plain: u8[>..] = [];
var info = deflate::Info { 0, 0 };
guard deflate::decompress(d, plain, packed, deflate::Format.Gzip, info) else {
    print("decompression failed: ", deflate::error());
    exit(1);
}
let following_data = packed[info.in_nbytes..];
```

If you know the output length, use `decompress_into` with a fixed slice or
`decompress_exact` with a builder and exact size. If you do not, `decompress`
retries with a larger output buffer up to `max_size`, 1 GiB by default. Keep a
cap appropriate to the application when decoding untrusted input: a small
compressed buffer can describe a very large output. Failed appends leave the
builder unchanged.

The zlib and gzip trailers are checked by libdeflate. The optional CRC in a gzip
header is not checked, and streams requiring a preset zlib dictionary return
`BadData`. One decompression call stops at the first stream; it reports consumed
input rather than silently joining concatenated gzip members.

### Native handles and allocation failures

The ordinary builder calls allocate a native context for the operation and
free it before returning, so callers do not manage that lifetime. For
high-throughput loops, reusable compressor/decompressor handles avoid repeated
context setup. They are native `malloc`-backed values: acquire them with
`let c, ok = deflate::compressor(level)` / `decompressor()`, then use
`defer deflate::close(c)` / `close(d)` so cleanup runs on every scope exit. A
false constructor result records `BadLevel` or `OutOfMemory` in `error()`.

Do not copy a live handle, close a copied alias, use a handle after closing, or
share one concurrently between threads; use one per thread. See
[docs/internals.md](docs/internals.md) for the native ownership model.

A compressor uses roughly 6 KiB at level 0, 200 KiB at level 1, 650 KiB at
levels 2–9, and 8.8 MiB at levels 10–12 on the measured x86-64 libdeflate 1.26
build. A decompressor uses about 11 KiB. These figures vary with platform and
version; reuse a high-level compressor rather than constructing one per small
request.

### Checksums

```goose
let crc = deflate::crc32(data);               // gzip CRC-32
let more = deflate::crc32(next_chunk, crc);   // continue from crc
let adler = deflate::adler32(data);           // zlib Adler-32
```

The initial values are `CRC32_INIT` (0) and `ADLER32_INIT` (1).

## Build, test and verify

```bash
make tools       # compiler and local test dependencies
make check       # typecheck the Goose package
make test        # in-process, debug and optimized tests plus native TLS test
make interop     # Python zlib and system gzip, both directions
make examples    # typecheck every example
make verify      # all correctness checks above
make bench       # fetch corpora, compare against zlib
make overhead    # compare Goose calls with direct C calls
make fmt         # format Goose sources
```

Set `GOOSE=/path/to/goose` to choose a compiler. The Makefile and shell scripts
are POSIX developer helpers; Windows CI runs the Goose commands directly rather
than depending on `make` or Bash. Interop needs Python 3 and `gzip`; the overhead benchmark needs Python 3 and
CMake. The zlib corpus benchmark additionally needs zlib development headers
(`zlib1g-dev` on Debian/Ubuntu). See [docs/verification.md](docs/verification.md)
for the test-by-test contract and
[docs/coverage.md](docs/coverage.md) for what is intentionally not exposed.

## Repository map

| Path | Purpose |
|---|---|
| `deflate.goose` | public Goose module and handle/status behavior |
| `deflate.build` | Goose CMake target and inline C header declaration |
| `CMakeLists.txt` | static libdeflate target and TinyCC adapter fallback |
| `src/libdeflate.h` | inline native adapter and TinyCC fallback declarations |
| `src/libdeflate.c` | emits the same adapter functions for TinyCC |
| `vendor/libdeflate/` | pinned libdeflate 1.26 git submodule, unmodified |
| `test/` | Goose contract, thread-local status, and independent interoperability tests |
| `examples/` | file compression, decompression and round-trip programs |
| `bench/` | [zlib and direct-C comparisons](bench/README.md), scripts and recorded results |
| `docs/` | usage guide, upstream API coverage, internals and verification contract |
| `ROADMAP.md`, `CHANGELOG.md` | design boundaries and shipped surface |

The package builds libdeflate's static library with upstream CMake and uses
its assembler feature checks and runtime CPU dispatch. `src/libdeflate.h`
inlines slice unpacking and dispatch into native Goose-generated C; the same
header is compiled into exported adapter functions for TinyCC.

## Credits and licenses

libdeflate was written by Eric Biggers, with contributions from others, and is
copyright 2016 Eric Biggers and 2024 Google LLC. It is under the MIT license,
reproduced in [`vendor/libdeflate/COPYING`](vendor/libdeflate/COPYING). See
[`vendor/README.md`](vendor/README.md) for the vendored source details.

The benchmark method follows
[libdeflater](https://github.com/libdeflater/libdeflater) and
[go-libdeflate](https://github.com/4kills/go-libdeflate); no code was taken from
either. Goose is by Wouter van Oortmerssen. The benchmark fetches Calgary and
Canterbury corpus copies from
[simonis/zlib-bench](https://github.com/simonis/zlib-bench) and
[ChrisLomont/CompressionTools](https://github.com/ChrisLomont/CompressionTools); those data
files are not part of this repository. The binding and its tests are MIT
licensed in [`LICENSE`](LICENSE).
