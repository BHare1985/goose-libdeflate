#include "goose_libdeflate.h"

#include <stddef.h>

#include "libdeflate.h"

int32_t gld_version_major(void) { return LIBDEFLATE_VERSION_MAJOR; }
int32_t gld_version_minor(void) { return LIBDEFLATE_VERSION_MINOR; }

int64_t gld_compressor_new(int32_t level)
{
    return (int64_t)(intptr_t)libdeflate_alloc_compressor(level);
}

void gld_compressor_free(int64_t handle)
{
    libdeflate_free_compressor((struct libdeflate_compressor *)(intptr_t)handle);
}

/* The worst-case compressed size, or -1 for a format that does not exist. */
int64_t gld_compress_bound(int64_t handle, int32_t format, int64_t in_nbytes)
{
    struct libdeflate_compressor *c = (struct libdeflate_compressor *)(intptr_t)handle;
    size_t n = (size_t)in_nbytes;

    switch (format) {
    case GLD_DEFLATE: return (int64_t)libdeflate_deflate_compress_bound(c, n);
    case GLD_ZLIB:    return (int64_t)libdeflate_zlib_compress_bound(c, n);
    case GLD_GZIP:    return (int64_t)libdeflate_gzip_compress_bound(c, n);
    }
    return -1;
}

/* The compressed size, 0 when it does not fit in `out` (never the case for an
   `out` of gld_compress_bound() bytes), or -1 for a format that does not
   exist. */
int64_t gld_compress(int64_t handle, int32_t format, gld_cslice in, gld_slice out)
{
    struct libdeflate_compressor *c = (struct libdeflate_compressor *)(intptr_t)handle;

    switch (format) {
    case GLD_DEFLATE:
        return (int64_t)libdeflate_deflate_compress(c, in.data, (size_t)in.len,
                                                    out.data, (size_t)out.len);
    case GLD_ZLIB:
        return (int64_t)libdeflate_zlib_compress(c, in.data, (size_t)in.len,
                                                 out.data, (size_t)out.len);
    case GLD_GZIP:
        return (int64_t)libdeflate_gzip_compress(c, in.data, (size_t)in.len,
                                                 out.data, (size_t)out.len);
    }
    return -1;
}

int64_t gld_decompressor_new(void)
{
    return (int64_t)(intptr_t)libdeflate_alloc_decompressor();
}

void gld_decompressor_free(int64_t handle)
{
    libdeflate_free_decompressor((struct libdeflate_decompressor *)(intptr_t)handle);
}

/* Decompresses into `out`, whose size is the most the data may decompress to.
   Returns a libdeflate_result (or GLD_BAD_FORMAT) and fills in `info` with the
   bytes of `in` the stream took and the bytes written to `out`; on
   LIBDEFLATE_INSUFFICIENT_SPACE `out` was too small and `info` is zeros. */
int32_t gld_decompress(int64_t handle, int32_t format, gld_cslice in, gld_slice out,
                       gld_info *info)
{
    struct libdeflate_decompressor *d = (struct libdeflate_decompressor *)(intptr_t)handle;
    size_t in_used = 0, out_used = 0;
    enum libdeflate_result r;

    switch (format) {
    case GLD_DEFLATE:
        r = libdeflate_deflate_decompress_ex(d, in.data, (size_t)in.len, out.data,
                                             (size_t)out.len, &in_used, &out_used);
        break;
    case GLD_ZLIB:
        r = libdeflate_zlib_decompress_ex(d, in.data, (size_t)in.len, out.data,
                                          (size_t)out.len, &in_used, &out_used);
        break;
    case GLD_GZIP:
        r = libdeflate_gzip_decompress_ex(d, in.data, (size_t)in.len, out.data,
                                          (size_t)out.len, &in_used, &out_used);
        break;
    default:
        return GLD_BAD_FORMAT;
    }
    info->in_nbytes = r == LIBDEFLATE_SUCCESS ? (int64_t)in_used : 0;
    info->out_nbytes = r == LIBDEFLATE_SUCCESS ? (int64_t)out_used : 0;
    return (int32_t)r;
}

uint32_t gld_adler32(uint32_t adler, gld_cslice in)
{
    return libdeflate_adler32(adler, in.data, (size_t)in.len);
}

uint32_t gld_crc32(uint32_t crc, gld_cslice in)
{
    return libdeflate_crc32(crc, in.data, (size_t)in.len);
}
