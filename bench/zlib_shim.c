/* The baseline for bench.goose: zlib, the library libdeflate is usually
   compared with. Like a flate2 encoder that is reset between buffers, the
   stream state is made once and reused, so the timings count the compressing
   and not the setting up. */
#include <stdint.h>
#include <string.h>
#include <zlib.h>

typedef struct { uint8_t *data; int64_t len; } zb_slice;
typedef struct { const uint8_t *data; int64_t len; } zb_cslice;

static z_stream cstream;
static int clevel = -1000;

/* Compresses in zlib format at `level` (1 to 9). Returns the compressed size,
   or -1 if it didn't fit in `out`. */
int64_t zb_compress(int32_t level, zb_cslice in, zb_slice out)
{
    if (level != clevel) {
        if (clevel != -1000)
            deflateEnd(&cstream);
        memset(&cstream, 0, sizeof(cstream));
        if (deflateInit(&cstream, level) != Z_OK)
            return -1;
        clevel = level;
    }
    deflateReset(&cstream);
    cstream.next_in = (Bytef *)in.data;
    cstream.avail_in = (uInt)in.len;
    cstream.next_out = out.data;
    cstream.avail_out = (uInt)out.len;
    if (deflate(&cstream, Z_FINISH) != Z_STREAM_END)
        return -1;
    return (int64_t)cstream.total_out;
}

static z_stream dstream;
static int dready;

/* Decompresses a zlib stream. Returns the decompressed size, or -1 on error. */
int64_t zb_decompress(zb_cslice in, zb_slice out)
{
    if (!dready) {
        memset(&dstream, 0, sizeof(dstream));
        if (inflateInit(&dstream) != Z_OK)
            return -1;
        dready = 1;
    }
    inflateReset(&dstream);
    dstream.next_in = (Bytef *)in.data;
    dstream.avail_in = (uInt)in.len;
    dstream.next_out = out.data;
    dstream.avail_out = (uInt)out.len;
    if (inflate(&dstream, Z_FINISH) != Z_STREAM_END)
        return -1;
    return (int64_t)dstream.total_out;
}


uint32_t zb_crc32(uint32_t crc, zb_cslice in)
{
    return (uint32_t)crc32(crc, in.data, (uInt)in.len);
}

uint32_t zb_adler32(uint32_t adler, zb_cslice in)
{
    return (uint32_t)adler32(adler, in.data, (uInt)in.len);
}
