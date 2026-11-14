# Benchmarks

These benchmarks answer two different questions:

1. **Why libdeflate?** Compare the package with zlib on Calgary and Canterbury.
2. **What does the Goose binding cost?** Compare its hot calls with direct C
   calls into the same libdeflate build.

Both are whole-buffer, one-thread benchmarks. Neither times file I/O or context
allocation. Run them on an otherwise idle machine; results vary with CPU, compiler,
OS scheduling and library versions. No timing is a CI pass/fail threshold.

## Goose libdeflate vs zlib

Run `make bench`. It fetches the Calgary and Canterbury corpora, builds the Goose
program and writes all per-file results to [`RESULTS.md`](RESULTS.md).
The current recorded run is on a Ryzen 5 3550H / Linux, with zlib 1.3.1 and
libdeflate 1.26:

| Operation | zlib | libdeflate | Speedup |
|---|---:|---:|---:|
| Compress, level 1 | 101 MB/s | 218 MB/s | 2.2× |
| Compress, level 6 | 26 MB/s | 78 MB/s | 3.0× |
| Decompress, level-6 streams | 340 MB/s | 919 MB/s | 2.7× |
| CRC-32 | 4.3 GB/s | 12.3 GB/s | 2.8× |

On the same corpus, level 6 produces 1,778,655 bytes with libdeflate versus
1,793,911 bytes with zlib. Level 9 is 1,739,806 versus 1,783,714 bytes; libdeflate
levels 10–12 can trade more CPU time for a smaller result. See `RESULTS.md` for
every file and level.

`bench.goose` times already-created contexts and already-sized/reused buffers.
It uses zlib's level-appropriate output as the common decompression fixture and
cross-decodes each library's compressed output before timing. Each reported time
is the median of 11 samples, with each sample long enough to run for at least
2 ms. The benchmark records sizes as well as speed, so a faster but invalid or
larger stream is not presented as a win.

## Goose binding vs direct C

Run `make overhead`, or select the C compilers explicitly:

```sh
python3 bench/run_overhead.py --cc gcc clang --output bench/overhead_results.json
```

This generates a standalone Goose program containing both paths in the **same
executable**:

- the Goose API (`compress_into`, `decompress_into`, `crc32`, `adler32`), and
- direct calls to libdeflate's C API, with loops implemented in C.

Both paths reuse the same kind of native handles and caller-owned buffers. The
CMake build compiles the same pinned libdeflate source once for each compiler
with `-O3 -DNDEBUG`; the generated Goose application is compiled with native
`-O3`, and Goose frontend inlining uses `-O2`. Setup, allocation and fixture
creation are outside the timed region. Checksums/counts must agree, and decoded
bytes are compared after each timing.

The inputs include deterministic synthetic read-like data and pseudorandom
bytes at 64 B, 4 KiB, 64 KiB and 1 MiB. Compression uses level 1. The sweep
covers raw, zlib and gzip compression/decompression plus CRC-32 and Adler-32.
The runner currently targets GCC/Clang on Unix-like systems, not Windows.
`overhead_results.json` keeps the compiler, iterations and per-case timings.
On the recorded Linux x64 run, the median Goose/direct-C time ratio across the
cases was:

| Input size | GCC 15.2 | Clang 21.1 |
|---:|---:|---:|
| 64 B | 0.98× | 0.99× |
| 4 KiB | 1.00× | 0.99× |
| 64 KiB | 1.01× | 1.00× |
| 1 MiB | 1.00× | 1.00× |

A ratio of 1.00 means equal time; above 1.00 means Goose took longer. The 64 B
cases are near the timer/scheduler noise floor and have wide per-case variation;
use the raw JSON and repeat on an idle machine before interpreting a small
ratio. This benchmark measures binding overhead, not a new compression codec
speedup.
