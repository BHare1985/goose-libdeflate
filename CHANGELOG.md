# Changelog

## 0.2.0 — libdeflate 1.26 binding

- Bind compression and decompression for raw DEFLATE, zlib and gzip.
- Support compression levels 0–12, reusable compressor/decompressor handles,
  caller-owned output buffers and append-to-builder helpers.
- Report decompression status and consumed/produced byte counts; cap growing
  decompression and preserve builders on failure.
- Expose CRC-32 and Adler-32, plus corpus benchmarks against zlib.
- Add Goose round-trip tests and independent interoperability checks with Python
  zlib and system gzip.
- Use Goose-style bool results with typed per-thread `status()` / `error()`;
  invalid levels and native allocation failures no longer abort one-shot calls.
- Pin upstream libdeflate 1.26 as a git submodule and build its static target via
  CMake; inline the adapter for native Goose builds and share it with TinyCC.
