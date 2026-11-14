# libdeflate coverage

What upstream [`libdeflate.h`](../vendor/libdeflate/libdeflate.h) exposes and
how this Goose binding maps it. The binding stays focused on whole-buffer
compression, decompression and checksums.

## Exposed

| libdeflate API | Goose API |
|---|---|
| `libdeflate_alloc_compressor` / `libdeflate_free_compressor` | `compressor`, `close(Compressor&)`; one-shot calls scope the temporary handle internally |
| `libdeflate_*_compress` | `compress_into` (fixed buffers and builder append), with a bool result and per-thread `error()` |
| `libdeflate_*_compress_bound` | `compress_bound` |
| `libdeflate_alloc_decompressor` / `libdeflate_free_decompressor` | `decompressor`, `close(Decompressor&)`; one-shot calls scope the temporary handle internally |
| `libdeflate_*_decompress_ex` | `decompress_into`, `decompress_exact`, `decompress`; `Info` reports consumed/produced lengths |
| `libdeflate_adler32` | `adler32` |
| `libdeflate_crc32` | `crc32` |
| `LIBDEFLATE_VERSION_MAJOR` / `MINOR` | `VERSION_MAJOR` / `VERSION_MINOR`, checked against `native_version()` |
| `enum libdeflate_result` | typed Goose `Status`, returned through `status()` / `error()` after a false result; C `_Static_assert`s pin native values |
| zlib, gzip and raw DEFLATE families | `Format.Zlib`, `Format.Gzip`, `Format.Deflate` |

## Not exposed, with the reason

| Upstream facility | Why not |
|---|---|
| `libdeflate_*_decompress` (non-`_ex`) | The `_ex` forms give the same result plus exact consumed/produced counts. Exposing a second family with less information adds surface without capability. |
| Custom allocators | libdeflate allocates compressor/decompressor internals with `malloc` and does not offer a custom allocator. Goose owns builder buffers but cannot replace this upstream allocation model. |
| Streaming interfaces | libdeflate intentionally accepts complete buffers. The package does not invent stateful streaming semantics over a whole-buffer library. |
| gzip header construction or inspection | libdeflate compresses/decompresses gzip members; header authoring and inspection are a separate container API. The decoder checks the trailer but does not validate optional FHCRC. |
| Preset zlib dictionaries | The API does not expose dictionary-aware compression/decompression. A stream requiring a preset dictionary returns `BadData`. |
| zlib/gzip concatenated-member orchestration | The `_ex` call stops at the first member and reports `Info.in_nbytes`. The caller can iterate members explicitly; silent joining would hide record boundaries. |
| `crc32_combine` / `adler32_combine` | This binding exposes the base checksum functions and continuation value, not checksum combination for independently checksummed buffers. Add only for a concrete caller need. |

The choice not to wrap every upstream symbol is intentional. New surface should
have a Goose-shaped use case and explicit semantics for ownership, bounds and
failure; a one-for-one C mirror is not the design goal.
