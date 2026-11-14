# Roadmap

This repository binds the whole-buffer compression, decompression and checksum
API of libdeflate 1.26 to Goose. The goal is a small, predictable Goose package,
not a mirror of every upstream symbol.

The design stays within four rules:

- One-shot calls own temporary C contexts; reusable handles are an advanced
  path with explicit `close` scoped by `defer`.
- Failures follow Goose's bool-plus-error convention: fallible calls return
  `bool`, while typed `status()` / `error()` report the latest result per thread.
- Decompression is bounded by a caller-visible maximum and failed appends are
  transactional.
- The package builds a known upstream source version itself and tests its
  output against independent implementations.

## Shipped surface

| Area | What is available |
|---|---|
| Compression | raw DEFLATE, zlib and gzip; levels 0–12; one-shot builder append or reusable caller-owned output buffer |
| Reuse | reusable compressors and fixed-buffer `compress_into`; upstream output bounds |
| Decompression | all three formats; fixed-buffer `decompress_into`, exact-size appends, or capped growing append |
| Stream boundaries | consumed/produced byte counts through `Info`; trailing bytes and later members remain with the caller |
| Checksums | CRC-32 and Adler-32, including continuation from a previous checksum |
| Errors | bool results; typed per-thread `Status` / `error()`; failed builder appends roll back |
| Validation | comprehensive Goose round trips, known external streams, Python zlib and gzip interoperability |
| Performance | corpus benchmark against zlib, with results and methodology in `bench/RESULTS.md` |

## Deliberate limits

These are design boundaries, not accidental omissions:

- **No streaming interface.** libdeflate consumes complete buffers. This package
  does not pretend a sequence of independent blocks is a stateful stream.
- **No custom allocator.** Upstream uses `malloc` for reusable contexts. Goose
  owns its output builders, but cannot route upstream allocations through its
  data stack.
- **No implicit multi-member concatenation.** One call decodes the first stream
  and reports consumed input. The caller decides how records or gzip members
  are sequenced.
- **No preset dictionaries.** The upstream entry points used here do not expose
  dictionary operation; streams requiring one fail with `BadData`.
- **No container authoring/inspection API.** The package delegates gzip/zlib
  format handling to libdeflate and exposes no metadata editing surface.

## Next, if there is a concrete need

1. Add a README/guide snippet compilation check so documentation cannot silently
   drift from Goose syntax.
2. Add CI sanitizer or fuzz coverage for the C boundary if the Goose build
   workflow can run it portably across supported platforms.
3. Re-evaluate new upstream capabilities only when they preserve the whole-buffer
   contract and have a clear ownership/error design.

A vendor upgrade should remain a separately reviewed change, documented in
[docs/internals.md](docs/internals.md), with benchmark comparisons made on the
same machine. No upstream version bump is implied by these maintenance items.
