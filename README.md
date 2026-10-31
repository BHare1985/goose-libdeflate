# goose-libdeflate

[libdeflate](https://github.com/ebiggers/libdeflate) for
[Goose](https://github.com/aardappel/goose). It does DEFLATE, zlib and gzip
compression and decompression, and the Adler-32 and CRC-32 checksums.

This repository contains libdeflate 1.26 and builds it, so using it from a
program takes one line:

```goose
import deflate from "github.com/bhare1985/goose-libdeflate@v1.26";
```

The tag follows libdeflate's version, so `@v1.26` is libdeflate 1.26.

The first build needs `git` and a C compiler (gcc, clang or MSVC). Goose
compiles the C itself and caches the result in `~/.goose`. Both `goose program.goose` and `goose build program.goose` work.

## Example

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

As with `base64` in the standard library, the functions append to the `out`
builder you give them. If a decompression fails, `out` is left as it was.

## Functions

| | |
|---|---|
| `compress(out, data, format, level = 6) -> i64` | appends `data` compressed, and returns how many bytes it appended |
| `decompress(out, data, format, max_size = 1 GiB) -> i32` | appends the decompressed `data` and returns a status |
| `decompress_exact(d, out, data, format, size, info) -> i32` | the same when you know the exact decompressed `size` |
| `compress_bound(c, size, format) -> i64` | the most `compress` can append for `size` bytes of input |
| `crc32(data, crc = 0)`, `adler32(data, adler = 1)` | checksums, which can be continued from an earlier result |

`format` is `deflate::Format.Deflate` (raw, RFC 1951), `.Zlib` (RFC 1950) or
`.Gzip` (RFC 1952). `level` goes from 0 (store only) to 12 (smallest output);
1 is the fastest compression.

`decompress` returns `deflate::SUCCESS`, `BAD_DATA`, `SHORT_OUTPUT` or
`INSUFFICIENT_SPACE`, and `status_name` turns one into text. It gives up with
`INSUFFICIENT_SPACE` once the output would pass `max_size`. That is there so
that a small hostile input can't use up all your memory, so raise it if you
expect more than a gigabyte.

`decompress` stops at the end of the first stream in the input. To read
several in a row, or to find data after one, pass an `Info` and use
`info.in_nbytes` as the start of what comes next.

libdeflate doesn't verify the optional CRC in a gzip header (the checksum at
the end of the stream is verified), and it doesn't support zlib streams that
need a preset dictionary; those give `BAD_DATA`.

### Reusing a compressor

The calls above build a compressor or decompressor, use it and free it. If you
have lots of buffers to process, make one and pass it in as the first argument,
which saves building it each time:

```goose
var c = deflate::compressor(9);
deflate::compress(c, packed, data, deflate::Format.Zlib);
deflate::close(c);

var d = deflate::decompressor();
var info = deflate::Info { 0, 0 };
deflate::decompress(d, plain, packed, deflate::Format.Zlib, info);
deflate::close(d);
```

Goose has no destructors, so you have to call `close` yourself. Closing twice
is harmless. Don't share one between threads.

### Checksums

```goose
let crc = deflate::crc32(data);               // what gzip uses
let more = deflate::crc32(next_chunk, crc);   // carrying on from crc
let adler = deflate::adler32(data);           // what zlib uses
```

## What's in the repository

| | |
|---|---|
| `deflate.goose` | the Goose module |
| `deflate.build` | lists the C files for Goose to compile |
| `src/` | the C layer: handles as `i64`, buffers as slices |
| `vendor/libdeflate` | libdeflate 1.26, unmodified |
| `test/`, `examples/` | programs of their own, not part of the package |

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
build and as an optimized build), then `test/interop.sh`. The interop script
checks that `gzip` and Python's `zlib` can read what this package writes, and
that this package can read what they write, and that the checksums agree.
Set `GOOSE=/path/to/goose` to choose the compiler. The interop script needs
`gzip` and Python 3.

libdeflate's own test suite lives in its repository and passes at this
version.

## Credits and licenses

libdeflate was written by Eric Biggers, with contributions from others, and is
copyright 2016 Eric Biggers and 2024 Google LLC. It is under the MIT license,
reproduced in
[`vendor/libdeflate/COPYING`](vendor/libdeflate/COPYING). The code in
`vendor/libdeflate` is as released upstream; see
[`vendor/README.md`](vendor/README.md).

Goose is by Wouter van Oortmerssen. The way this package is laid out follows
the packages guide in the Goose documentation and its bundled `physics`
package.

The rest of this repository (the Goose module, the C layer, the CMake file and
the tests) is under the MIT license, in [`LICENSE`](LICENSE).
