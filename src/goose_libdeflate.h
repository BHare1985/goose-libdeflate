/* The C side of deflate.goose. libdeflate hands out pointers to its
   compressors, which Goose can't hold, so they cross as i64 handles (0 means
   none). Buffers cross as the { data, len } struct that Goose uses for slices. */
#ifndef GOOSE_LIBDEFLATE_H
#define GOOSE_LIBDEFLATE_H

#include <stdint.h>

/* The layout Goose gives `u8[:]` and `const u8[:]`. */
typedef struct { uint8_t *data; int64_t len; } gld_slice;
typedef struct { const uint8_t *data; int64_t len; } gld_cslice;

/* The layout of `deflate::Info`, filled in by a decompression. */
typedef struct { int64_t in_nbytes; int64_t out_nbytes; } gld_info;

/* The formats, numbered as deflate::code() in deflate.goose numbers them. */
enum { GLD_DEFLATE = 0, GLD_ZLIB = 1, GLD_GZIP = 2 };

/* gld_decompress returns libdeflate's enum libdeflate_result, or this when the
   format isn't one of the above. */
enum { GLD_BAD_FORMAT = 4 };

int32_t gld_version_major(void);
int32_t gld_version_minor(void);

int64_t gld_compressor_new(int32_t level);
void gld_compressor_free(int64_t handle);
int64_t gld_compress_bound(int64_t handle, int32_t format, int64_t in_nbytes);
int64_t gld_compress(int64_t handle, int32_t format, gld_cslice in, gld_slice out);

int64_t gld_decompressor_new(void);
void gld_decompressor_free(int64_t handle);
int32_t gld_decompress(int64_t handle, int32_t format, gld_cslice in, gld_slice out,
                       gld_info *info);

uint32_t gld_adler32(uint32_t adler, gld_cslice in);
uint32_t gld_crc32(uint32_t crc, gld_cslice in);

#endif
