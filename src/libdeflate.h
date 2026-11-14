#ifndef GOOSE_LIBDEFLATE_H
#define GOOSE_LIBDEFLATE_H

/*
 * The native compiler includes this adapter in generated Goose C, where the
 * calls inline directly through to libdeflate. TinyCC cannot include headers
 * containing native compiler attributes, so in that configuration it calls
 * the exported copies emitted by src/libdeflate.c instead.
 */
#if !defined(__TINYC__)
#include "../vendor/libdeflate/libdeflate.h"
#include <stdint.h>
#include <stddef.h>
#include <limits.h>
#include <string.h>

_Static_assert(LIBDEFLATE_SUCCESS == 0, "Goose Status.Ok mapping changed");
_Static_assert(LIBDEFLATE_BAD_DATA == 1, "Goose Status.BadData mapping changed");
_Static_assert(LIBDEFLATE_SHORT_OUTPUT == 2, "Goose Status.ShortOutput mapping changed");
_Static_assert(LIBDEFLATE_INSUFFICIENT_SPACE == 3,
               "Goose Status.InsufficientSpace mapping changed");

#ifndef GLD_INLINE
#if defined(_MSC_VER)
#define GLD_INLINE static __forceinline
#elif defined(__GNUC__) || defined(__clang__)
#define GLD_INLINE static inline __attribute__((always_inline))
#else
#define GLD_INLINE static inline
#endif
#endif

#if defined(_MSC_VER)
#define GLD_THREAD_LOCAL __declspec(thread)
#else
#define GLD_THREAD_LOCAL _Thread_local
#endif

/* Goose operations report their latest outcome per thread, including success. */
static GLD_THREAD_LOCAL int32_t gld_last_status_code = 0;

GLD_INLINE void gld_record_status(int32_t code) { gld_last_status_code = code; }
GLD_INLINE int32_t gld_last_status(void) { return gld_last_status_code; }

GLD_INLINE uint64_t gld_open_compressor(int32_t level) {
    return (uint64_t)(uintptr_t)libdeflate_alloc_compressor(level);
}

GLD_INLINE uint64_t gld_open_decompressor(void) {
    return (uint64_t)(uintptr_t)libdeflate_alloc_decompressor();
}

GLD_INLINE void gld_close_compressor(uint64_t handle) {
    libdeflate_free_compressor((struct libdeflate_compressor *)(uintptr_t)handle);
}

GLD_INLINE void gld_close_decompressor(uint64_t handle) {
    libdeflate_free_decompressor((struct libdeflate_decompressor *)(uintptr_t)handle);
}

GLD_INLINE int32_t gld_version_major(void) { return LIBDEFLATE_VERSION_MAJOR; }
GLD_INLINE int32_t gld_version_minor(void) { return LIBDEFLATE_VERSION_MINOR; }

/* Returns -1 for a closed handle, invalid length, or unrepresentable bound. */
GLD_INLINE int64_t gld_bound(uint64_t handle, int32_t format, int64_t size) {
    if (handle == 0 || size < 0 || (uint64_t)size > SIZE_MAX) return -1;
    struct libdeflate_compressor *c = (struct libdeflate_compressor *)(uintptr_t)handle;
    size_t n;
    switch (format) {
    case 0: n = libdeflate_deflate_compress_bound(c, (size_t)size); break;
    case 1: n = libdeflate_zlib_compress_bound(c, (size_t)size); break;
    case 2: n = libdeflate_gzip_compress_bound(c, (size_t)size); break;
    default: return -1;
    }
    return n > INT64_MAX ? -1 : (int64_t)n;
}

/* Positive byte count on success, 0 if the destination is too small, -1 on
 * an invalid/closed call. Empty slices still need non-null C pointers. */
GLD_INLINE int64_t gld_compress(uint64_t handle, int32_t format,
                                sl_u8 input, sl_u8 output) {
    if (handle == 0 || input.len < 0 || output.len < 0 ||
        (uint64_t)input.len > SIZE_MAX || (uint64_t)output.len > SIZE_MAX ||
        (input.len != 0 && input.data == NULL) ||
        (output.len != 0 && output.data == NULL)) return -1;
    struct libdeflate_compressor *c = (struct libdeflate_compressor *)(uintptr_t)handle;
    unsigned char dummy = 0;
    const void *in = input.len ? input.data : &dummy;
    void *out = output.len ? output.data : &dummy;
    switch (format) {
    case 0:
        return (int64_t)libdeflate_deflate_compress(c, in, (size_t)input.len,
                                                   out, (size_t)output.len);
    case 1:
        return (int64_t)libdeflate_zlib_compress(c, in, (size_t)input.len,
                                                 out, (size_t)output.len);
    case 2:
        return (int64_t)libdeflate_gzip_compress(c, in, (size_t)input.len,
                                                 out, (size_t)output.len);
    default:
        return -1;
    }
}

/* These local values are added to libdeflate_result for wrapper validation. */
enum { GLD_INVALID_ARGUMENT = 4, GLD_CLOSED = 7 };

/* Returns libdeflate_result. Counts are written only on success; packed Goose
 * arrays are copied with memcpy rather than cast to a potentially unaligned
 * int64_t pointer. */
GLD_INLINE int32_t gld_decompress(uint64_t handle, int32_t format,
                                 sl_u8 input, sl_u8 output, sl_i64 counts) {
    if (handle == 0) return GLD_CLOSED;
    if (input.len < 0 || output.len < 0 ||
        (uint64_t)input.len > SIZE_MAX || (uint64_t)output.len > SIZE_MAX ||
        (input.len != 0 && input.data == NULL) ||
        (output.len != 0 && output.data == NULL) ||
        counts.len < 2 || counts.data == NULL) return GLD_INVALID_ARGUMENT;

    struct libdeflate_decompressor *d = (struct libdeflate_decompressor *)(uintptr_t)handle;
    size_t consumed = 0, written = 0;
    enum libdeflate_result status;
    unsigned char dummy = 0;
    const void *in = input.len ? input.data : &dummy;
    void *out = output.len ? output.data : &dummy;
    switch (format) {
    case 0:
        status = libdeflate_deflate_decompress_ex(d, in, (size_t)input.len,
                    out, (size_t)output.len, &consumed, &written);
        break;
    case 1:
        status = libdeflate_zlib_decompress_ex(d, in, (size_t)input.len,
                    out, (size_t)output.len, &consumed, &written);
        break;
    case 2:
        status = libdeflate_gzip_decompress_ex(d, in, (size_t)input.len,
                    out, (size_t)output.len, &consumed, &written);
        break;
    default:
        return GLD_INVALID_ARGUMENT;
    }

    int64_t result[2] = {0, 0};
    if (status == LIBDEFLATE_SUCCESS) {
        result[0] = (int64_t)consumed;
        result[1] = (int64_t)written;
    }
    memcpy(counts.data, result, sizeof result);
    return (int32_t)status;
}

GLD_INLINE uint32_t gld_crc32(sl_u8 bytes, uint32_t initial) {
    if (bytes.len == 0) return initial;
    if (bytes.len < 0 || bytes.data == NULL) return initial;
    return libdeflate_crc32(initial, bytes.data, (size_t)bytes.len);
}

GLD_INLINE uint32_t gld_adler32(sl_u8 bytes, uint32_t initial) {
    if (bytes.len == 0) return initial;
    if (bytes.len < 0 || bytes.data == NULL) return initial;
    return libdeflate_adler32(initial, bytes.data, (size_t)bytes.len);
}

#undef GLD_THREAD_LOCAL
#undef GLD_INLINE
#endif /* !__TINYC__ */
#endif /* GOOSE_LIBDEFLATE_H */
