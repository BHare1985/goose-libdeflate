#ifndef GOOSE_LIBDEFLATE_BENCH_DIRECT_H
#define GOOSE_LIBDEFLATE_BENCH_DIRECT_H

#include "../vendor/libdeflate/libdeflate.h"
#include <stdint.h>
#include <stdlib.h>

/* C loops bypass the Goose adapter but use the same handles, codec archive and
 * buffers as the Goose loops. This isolates adapter/call-contract overhead. */
static uint64_t direct_compress(uint64_t handle, int32_t format, sl_u8 input,
                                sl_u8 output, int64_t iterations) {
    struct libdeflate_compressor *c = (struct libdeflate_compressor *)(uintptr_t)handle;
    uint64_t sum = 0;
    for (int64_t i = 0; i < iterations; ++i) {
        size_t n;
        switch (format) {
        case 0: n = libdeflate_deflate_compress(c, input.data, (size_t)input.len,
                                                output.data, (size_t)output.len); break;
        case 1: n = libdeflate_zlib_compress(c, input.data, (size_t)input.len,
                                             output.data, (size_t)output.len); break;
        case 2: n = libdeflate_gzip_compress(c, input.data, (size_t)input.len,
                                             output.data, (size_t)output.len); break;
        default: abort();
        }
        if (n == 0) abort();
        sum += n;
    }
    return sum;
}

static uint64_t direct_decompress(uint64_t handle, int32_t format, sl_u8 input,
                                  sl_u8 output, int64_t iterations) {
    struct libdeflate_decompressor *d = (struct libdeflate_decompressor *)(uintptr_t)handle;
    uint64_t sum = 0;
    for (int64_t i = 0; i < iterations; ++i) {
        size_t consumed = 0, written = 0;
        enum libdeflate_result rc;
        switch (format) {
        case 0:
            rc = libdeflate_deflate_decompress_ex(d, input.data, (size_t)input.len,
                    output.data, (size_t)output.len, &consumed, &written);
            break;
        case 1:
            rc = libdeflate_zlib_decompress_ex(d, input.data, (size_t)input.len,
                    output.data, (size_t)output.len, &consumed, &written);
            break;
        case 2:
            rc = libdeflate_gzip_decompress_ex(d, input.data, (size_t)input.len,
                    output.data, (size_t)output.len, &consumed, &written);
            break;
        default: abort();
        }
        if (rc != LIBDEFLATE_SUCCESS || consumed != (size_t)input.len ||
            written != (size_t)output.len) abort();
        sum += consumed + written;
    }
    return sum;
}

static uint64_t direct_checksum(int32_t operation, sl_u8 input, int64_t iterations) {
    uint64_t sum = 0;
    if (operation == 2) {
        for (int64_t i = 0; i < iterations; ++i)
            sum += libdeflate_crc32(0, input.data, (size_t)input.len);
    } else {
        for (int64_t i = 0; i < iterations; ++i)
            sum += libdeflate_adler32(1, input.data, (size_t)input.len);
    }
    return sum;
}

#endif
