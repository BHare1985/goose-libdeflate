# Guide

How to use goose-libdeflate, and why its API has this shape. The
[README](../README.md) is the quick version; [internals](internals.md) is for
people changing the binding.

## Pick a buffer strategy

All operations work on whole buffers; there is no streaming writer or reader.
Ordinary one-shot functions hide native context allocation and cleanup. Choose
between appending to a growable builder and reusing fixed buffers:

| Situation | Use | Notes |
|---|---|---|
| A few inputs, simplest call | `compress(out, data, format)` / `decompress(out, data, format)` | Creates and frees a context for the call; builder appends |
| Many inputs, minimal per-call work | `compressor(level)` + `compress_into` | Reuse a native context and `compress_bound`-sized output buffer |
| Known decoded length | `decompress_into(out, data, format, info)` or reusable `decompress_exact` | Fixed output; no growth/retry loop |
| Unknown decoded length | `decompress(out, data, format, max_size)` | Grows output up to the caller-visible cap |

## Errors: bool plus the last status

Every operation that can fail returns a bool, with the reason recorded per
thread in `status()` and `error()`. This follows igzip's and Goose's graphics
API shape: the error belongs to the call, not to an integer result that must be
threaded through every helper.

```goose
var plain: u8[>..] = [];
guard deflate::decompress(plain, packed, deflate::Format.Gzip) else {
    print("decompression failed: ", deflate::error());
    exit(1);
}
```

Ask `error()` immediately after false. The record is the most recent operation
on the current thread and a later call overwrites it. A successful operation
records `Status.Ok`, so an old failure is cleared. The current status variants
are:

| Status | Meaning |
|---|---|
| `Status.Ok` | The most recent operation succeeded |
| `Status.BadData` | Corrupt data, wrong format, or unsupported input (e.g. a zlib preset dictionary) |
| `Status.ShortOutput` | `decompress_exact` decoded fewer bytes than the exact size requested |
| `Status.InsufficientSpace` | Output exceeded `max_size` or a fixed destination |
| `Status.InvalidArgument` | Negative output cap or exact size |
| `Status.BadLevel` | Compression level outside 0–12 |
| `Status.OutOfMemory` | libdeflate could not allocate a native context |
| `Status.Closed` | A reusable native handle was used after close |
| `Status.Other` | An unrecognized native failure |

Use `status()` when branching on a specific failure and `error()` for text.
`status_name(status)` is also available for formatting a known `Status` value.

## Compression

The simple form allocates and releases a temporary compressor inside the call:

```goose
var packed: u8[>..] = [];
guard deflate::compress(packed, data, deflate::Format.Gzip, 6) else {
    print("compression failed: ", deflate::error());
    exit(1);
}
```

It appends compressed bytes and leaves the original builder unchanged on
setup failure. `compressed(data, format, level)` returns a fresh builder plus a
bool if the caller has nowhere to put the result yet.

For repeated work, reuse a compressor and fixed output buffer:

```goose
let c, opened = deflate::compressor(6);
guard opened else { print(deflate::error()); exit(1); };
defer deflate::close(c);

var packed: u8[>..] = [];
packed.resize(deflate::compress_bound(c, 65536, deflate::Format.Zlib), 0);

// For each input of at most 65536 bytes:
let written, ok = deflate::compress_into(c, packed, data, deflate::Format.Zlib);
guard ok else { print(deflate::error()); exit(1); };
write_stdout(packed[..written]);
```

`compress_bound` guarantees enough room for an input of the requested size,
format and compression level. It returns 0 and records an error for an invalid
size or closed handle. `compress_into` returns `(byte_count, bool)`; the error
for false is available through `error()`. A too-small output buffer reports
`InsufficientSpace`. The builder form reserves the bound, writes once and trims
the unused capacity.

Levels range from 0 to 12. Level 0 stores data, 1 is the fastest compression,
6 is the default, and 12 searches hardest for smaller output. Compression can
make short data larger because headers and block framing have a cost.

## Decompression

The builder form grows its output as needed, but never beyond `max_size` (1 GiB
by default):

```goose
var plain: u8[>..] = [];
guard deflate::decompress(plain, packed, deflate::Format.Gzip) else {
    print("bad gzip: ", deflate::error());
    exit(1);
}
```

The append is transactional: on failure, `plain` is restored to its old
length. A small compressed input can describe a very large output, so choose a
lower `max_size` for untrusted input when the application has a tighter limit.
A negative cap is `InvalidArgument`.

When the decoded length is known, use a fixed buffer or an exact-size builder.
The one-shot fixed-buffer form also hides the native decompressor lifetime:

```goose
var plain: u8[>..] = [];
plain.resize(expected_size, 0);
var info = deflate::Info { 0, 0 };
guard deflate::decompress_into(plain, packed, deflate::Format.Zlib, info) else {
    print("decompression failed: ", deflate::error());
    exit(1);
}
// info.out_nbytes bytes were produced; info.in_nbytes bytes were consumed.
```

For an exact-size append with a reusable decompressor:

```goose
let d, opened = deflate::decompressor();
guard opened else { print(deflate::error()); exit(1); };
defer deflate::close(d);

var plain: u8[>..] = [];
var info = deflate::Info { 0, 0 };
guard deflate::decompress_exact(d, plain, packed, deflate::Format.Zlib,
                                expected_size, info) else {
    print("decompression failed: ", deflate::error());
    exit(1);
}
```

`ShortOutput` means the stream decoded successfully but produced fewer bytes
than requested; `Info` still reports those actual counts. If the stream produces
more than the exact destination, the status is `InsufficientSpace`. Both
failure cases leave the builder unchanged. For `decompress_into`, `Info` is
meaningful on success; bytes in a fixed destination on failure must be
discarded.

## Input following a stream

`Info.in_nbytes` identifies where the first stream ended; trailing bytes remain
for the caller. This supports containers with consecutive compressed records
and concatenated gzip members without silently joining them:

```goose
let d, opened = deflate::decompressor();
guard opened else { print(deflate::error()); exit(1); };
defer deflate::close(d);
var plain: u8[>..] = [];
var info = deflate::Info { 0, 0 };
guard deflate::decompress(d, plain, all, deflate::Format.Gzip, info) else {
    print(deflate::error());
    exit(1);
}
let next_record = all[info.in_nbytes..];
```

This is whole-buffer decoding, not incremental streaming. The full compressed
input and resulting output must fit in memory. Decode each member separately
when the container stores members as distinct records.

## Native handle lifetime

Ordinary `compress` and `decompress` builder calls allocate a native context
and close it before returning; the caller has no handle to manage. The
fixed-buffer one-shot `compress_into` / `decompress_into` forms do the same.
Reusable handles are an advanced path for repeated calls: libdeflate allocates
native state with `malloc`, and Goose has no destructors. Constructors return a
handle plus bool; on false, `error()` reports `BadLevel` or `OutOfMemory`.

Use `defer close(handle)` immediately after successful construction so cleanup
runs on every exit. Do not copy a live handle and close both copies, use one
after closing, or share one concurrently between threads. Give each worker its
own handle. Context size depends on compression level: about 6 KiB at level 0,
200 KiB at level 1, 650 KiB at levels 2–9, and 8.8 MiB at levels 10–12 on the
measured x86-64 libdeflate 1.26 build; a decompressor is about 11 KiB. These
are approximate, platform-dependent measurements.

## Formats and checksums

- `Format.Deflate`: raw DEFLATE (RFC 1951), no container header/trailer.
- `Format.Zlib`: zlib (RFC 1950), including and validating Adler-32.
- `Format.Gzip`: gzip (RFC 1952), including and validating the trailer CRC-32
  and uncompressed size. The optional gzip-header CRC is not checked by
  libdeflate.

`crc32` and `adler32` accept an optional starting value for incremental
checksums. Their initial values are `CRC32_INIT` (0) and `ADLER32_INIT` (1).

## Testing and maintenance

Run `make check` after Goose edits and `make verify` before relying on behavior.
The package tests its encoder against its decoder, and the independent
interoperability test checks both directions against Python zlib and system
gzip; see [verification.md](verification.md) for the test-by-test contract.
