# goose-libdeflate

[libdeflate](https://github.com/ebiggers/libdeflate) for
[Goose](https://github.com/aardappel/goose): zlib, gzip and raw DEFLATE
compression and decompression, and CRC-32 and Adler-32, two to three times as
fast as zlib.

This repository contains libdeflate 1.26 and builds it, so using it from a
program takes one line:

```goose
import deflate from "github.com/bhare1985/goose-libdeflate@v1.26";
```

The tag follows libdeflate's version, so `@v1.26` is libdeflate 1.26. The first
build needs `git` and a C compiler (gcc, clang or MSVC); Goose compiles the C
itself and keeps the result in `~/.goose`. Both `goose program.goose` and
`goose build program.goose` work.

## Why use it

libdeflate is a fast implementation of the DEFLATE family, and zlib is what most
programs use for it. On the Calgary and Canterbury corpora, through this
package and with the same buffers and the same zlib-format output:

| | zlib | libdeflate | |
|---|---:|---:|---:|
| compress, level 6 | 28 MB/s | 81 MB/s | 2.9x |
| compress, level 1 | 108 MB/s | 238 MB/s | 2.2x |
| decompress | 369 MB/s | 1025 MB/s | 2.8x |
| CRC-32 | 3.2 GB/s | 13.3 GB/s | 4.2x |

The output is also smaller at the same level: at level 6, 1.78 MB against zlib's
1.79 MB, and at level 9, 1.74 MB against 1.78 MB. libdeflate also has levels 10
to 12 that compress better than anything zlib offers (1.69 MB at level 12), for
a price: 5 MB/s here, against 9 MB/s for zlib's level 9. The full tables, with a line for every file
and how they were made, are in [bench/RESULTS.md](bench/RESULTS.md).

It is made for data you have in memory all at once, which is the common case
for network packets, database pages, cache entries, assets in an archive, and
files that are read in one go. If you want to compress a stream that doesn't fit
in memory, one piece at a time, libdeflate can't do that and this isn't the
package for it: it works on whole buffers and has no streaming. (libdeflate's
author suggests compressing in chunks of about a megabyte or less, and storing
each chunk's uncompressed size next to it.)

## Features

- Compression and decompression in zlib, gzip and raw DEFLATE formats
- A buffer you provide, for the fastest path, or an `out` builder that grows
- A known upper bound on the compressed size, to size that buffer
- Decompression that tells you how many bytes it used and how many it produced,
  for streams that are followed by other data
- CRC-32 and Adler-32, which can be continued
- Compressors and decompressors you can reuse
- Plain statuses instead of aborting on bad data, and a cap on the output size
  so a hostile input can't use up your memory

Of libdeflate's API (`libdeflate.h`):

- [x] zlib, gzip and DEFLATE compression
- [x] zlib, gzip and DEFLATE decompression
- [x] the upper bound of the compressed size (`compress_bound`)
- [x] decompression with the number of bytes consumed (`Info`)
- [x] `adler32` and `crc32`
- [ ] a custom memory allocator: not available, Goose manages its own memory and
  libdeflate's compressors use plain `malloc`

## Use

```goose
import deflate from "github.com/bhare1985/goose-libdeflate@v1.26";

fn main() {
    var packed: u8[>..] = [];
    deflate::compress(packed, "hello hello hello hello", deflate::Format.Gzip);

    var plain: u8[>..] = [];
    let status = deflate::decompress(plain, packed, deflate::Format.Gzip);
    if status != deflate::SUCCESS { print(deflate::status_name(status)); exit(1); }
    print(plain);
}
```

As with `base64` in the standard library, those functions append to the `out`
builder you give them. If a decompression fails, `out` is left as it was. There
are file-to-file versions in [examples/](examples): `gz_compress.goose` and
`gz_decompress.goose`.

The `format` is `deflate::Format.Deflate` (raw, RFC 1951), `.Zlib` (RFC 1950)
or `.Gzip` (RFC 1952). The `level` goes from 0 (store only) to 12 (smallest
output), 1 (`FASTEST_LEVEL`) is the fastest compression, and 6 is the default.
Compressing a few bytes can make them larger, and level 0 always does, because
of the headers.

### The fast way: a compressor and your own buffers

The calls above make a compressor, use it and free it, and the builder
version fills the new space with zeros before libdeflate writes into it. To
process many buffers, make a compressor once and give it a buffer to write
into:

```goose
var c = deflate::compressor(6);
var out: u8[>..] = [];
out.resize(deflate::compress_bound(c, 65536, deflate::Format.Zlib), 0);   // once

// for each buffer of up to 65536 bytes:
let n = deflate::compress_into(c, out, data, deflate::Format.Zlib);
write_stdout(out[..n]);

deflate::close(c);
```

`compress_bound` is the most that `compress_into` can write for that much input,
so a buffer of that size always has room. Decompression is the same, and it is
fastest when you know how big the result will be, because then there is no
guessing:

```goose
var d = deflate::decompressor();
var info = deflate::Info { 0, 0 };
let status = deflate::decompress_into(d, plain, packed, deflate::Format.Zlib, info);
// info.out_nbytes bytes of `plain` are the result; info.in_nbytes bytes of
// `packed` were used, and whatever is after that wasn't part of the stream.
deflate::close(d);
```

If you don't know the size, `decompress` finds it by trying a guess and
doubling it, up to `max_size` (1 GiB unless you say otherwise, so that a tiny
hostile input can't make you allocate more than that). `decompress_exact`
is `decompress_into` for a size you know, appending to a builder.

### Statuses

`decompress`, `decompress_into` and `decompress_exact` return
`deflate::SUCCESS`, `BAD_DATA` (corrupt, not the format, or something libdeflate
doesn't support), `SHORT_OUTPUT` (`decompress_exact` only: fewer bytes than the
size given) or `INSUFFICIENT_SPACE` (more bytes than the room allowed).
`status_name` turns one into text. The checksum at the end of a zlib or gzip
stream is checked. The optional CRC in a gzip header isn't, and zlib streams
that need a preset dictionary aren't supported; those give `BAD_DATA`.

### Checksums

```goose
let crc = deflate::crc32(data);               // what gzip uses
let more = deflate::crc32(next_chunk, crc);   // carrying on from crc
let adler = deflate::adler32(data);           // what zlib uses
```

### Notes

- Goose has no destructors, so a compressor or decompressor you make with
  `compressor()` or `decompressor()` has to be closed with `close`. Closing it
  twice is harmless.
- Don't use one compressor or decompressor from two threads at once. Make one
  for each thread.
- A compressor allocates memory with `malloc`, not from Goose's stacks, and how
  much depends on the level. Measured on x86-64 with libdeflate 1.26: level 0
  takes 6 KiB, level 1 about 200 KiB, levels 2 to 9 about 650 KiB and levels 10
  to 12, which search harder, about 8.8 MiB. A decompressor takes about 11 KiB.
  So make levels 10 to 12 compressors rarely, and reuse them.
- `deflate::compressor(level)` aborts if the level isn't 0 to 12 or if memory
  runs out; compressing itself can't fail.

## Benchmarks

```bash
bench/run.sh
```

downloads the corpora, builds [bench/bench.goose](bench/bench.goose) and writes
[bench/RESULTS.md](bench/RESULTS.md). It needs a C compiler and zlib's headers
(`zlib1g-dev` on Debian and Ubuntu).

The benchmark follows the libdeflater (Rust) one, so the numbers are comparable:
whole buffers in memory, one thread, no I/O, the 29 files of the Calgary and
Canterbury corpora, and a baseline that is reused between files, as a reset
encoder is in the Rust one. The baseline here is C zlib 1.3.2, called through
a few lines of C in `bench/zlib_shim.c`; libdeflate is called through this
package. Both write zlib format into buffers that are made once. Each time is
the median of 11 samples, each sample long enough to last 2 ms, and both
libraries decompress the same stream. Before anything is timed, each library's
output is checked by decompressing it with the other.

Numbers differ between machines, and these were taken on an i7-7700 under WSL2,
so run it on yours. The ratios between the libraries are what carries over,
and they match what libdeflater and go-libdeflate report on their own corpora
(2 to 3 times faster than flate2's miniz and 4 to 5 times faster than Go's
standard library).

Three of the Canterbury files, `alice29.txt`, `lcet10.txt` and `plrabn12.txt`,
are a few percent smaller in the copy this downloads than in the official
archive, whose server doesn't answer scripted downloads. They are the same
text with different line endings, so their times aren't comparable with other
people's, and the rest are.

## What's in the repository

| | |
|---|---|
| `deflate.goose` | the Goose module |
| `deflate.build` | lists the C files for Goose to compile |
| `src/` | the C layer: handles as `i64`, buffers as slices |
| `vendor/libdeflate` | libdeflate 1.26, unmodified |
| `examples/` | gzip and gunzip of a file, and a round trip |
| `test/` | tests |
| `bench/` | the benchmark, the zlib baseline for it, and its results |

libdeflate's sources are compiled with the same `-O2` as upstream's release
build. It picks the code for your CPU (AVX2, AVX-512, PCLMUL, ARM CRC32 and so
on) at run time, as it does upstream.

Upstream's CMake file also checks whether your assembler knows a few newer
instructions. This package doesn't run those checks, so a very old binutils
(before about 2018) could fail to build it.

## Tests

```bash
test/run_tests.sh
```

This runs `test/test_deflate.goose` three ways (in-process, as a `--debug`
build and as an optimized build), then `test/interop.sh`. The Goose tests cover
every format and level on text, noise, runs and mixes, sizes around the places
a compressor changes block, header variants, corrupt and truncated streams,
decompression limits, trailing data and several streams in a row, and a
thousand random round trips and damaged streams. The interop script checks that `gzip` and Python's `zlib` can read
what this package writes, that this package can read what they write, that the
checksums agree, and that the examples work. Set `GOOSE=/path/to/goose` to
choose the compiler. The interop script needs `gzip` and Python 3.

libdeflate's own test suite lives in its repository and passes at this
version.

## Credits and licenses

libdeflate was written by Eric Biggers, with contributions from others, and is
copyright 2016 Eric Biggers and 2024 Google LLC. It is under the MIT license,
reproduced in
[`vendor/libdeflate/COPYING`](vendor/libdeflate/COPYING). The code in
`vendor/libdeflate` is as released upstream; see
[`vendor/README.md`](vendor/README.md).

The shape of this README and of the benchmark follow
[libdeflater](https://github.com/libdeflater/libdeflater) (Rust) and
[go-libdeflate](https://github.com/4kills/go-libdeflate), two other bindings to
the same library; no code was taken from either.

Goose is by Wouter van Oortmerssen. The way this package is laid out follows
the packages guide in the Goose documentation and its bundled `physics`
package.

The corpora that `bench/fetch_corpus.sh` downloads are the
[Calgary](https://en.wikipedia.org/wiki/Calgary_corpus) and
[Canterbury](https://corpus.canterbury.ac.nz/) corpora, from copies in
[simonis/zlib-bench](https://github.com/simonis/zlib-bench) and
[ChrisLomont/CompressionTools](https://github.com/ChrisLomont/CompressionTools).
They aren't part of this repository.

The rest of this repository (the Goose module, the C layer, the build file, the
tests, the examples and the benchmark) is under the MIT license, in
[`LICENSE`](LICENSE).
