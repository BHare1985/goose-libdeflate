// Goose bindings for libdeflate (https://github.com/ebiggers/libdeflate, by
// Eric Biggers): DEFLATE, zlib and gzip compression and decompression, and
// the Adler-32 and CRC-32 checksums. This package carries libdeflate 1.26 and
// builds it itself, so a program only needs
//
//     import deflate from "github.com/bhare1985/goose-libdeflate@v1.26";
//
// plus git and a C compiler on the machine that builds it.
//
// Like base64 in the standard library, the calls append to the `out` builder
// you pass and leave what was already in it alone:
//
//     var packed: u8[>..] = [];
//     deflate::compress(packed, data, deflate::Format.Gzip);
//
//     var plain: u8[>..] = [];
//     let status = deflate::decompress(plain, packed, deflate::Format.Gzip);
//     if status != deflate::SUCCESS { print(deflate::status_name(status)); }
//
// Those calls set up a compressor or decompressor and free it again before
// they return. If you have many buffers to do, make one yourself and pass it
// in, so its tables are only built once:
//
//     var c = deflate::compressor(9);
//     deflate::compress(c, packed, data, deflate::Format.Zlib);
//     deflate::close(c);
//
// Goose has no destructors, so a compressor or decompressor you make is yours
// to close, once (closing it again does nothing). Don't use one from two
// threads at the same time; make one per thread.
//
// Compressing can't fail for a valid level. Decompressing returns a status
// other than SUCCESS for bad data, and then `out` is as it was before the call.
// The checksum a zlib or gzip stream ends with is checked; the optional CRC in
// a gzip header is skipped, as libdeflate does.
//
// This is libdeflate's whole-buffer interface: the input and the output both
// have to fit in memory, and there is no streaming.

namespace deflate;

import std;

// The libdeflate version in vendor/. test_misc checks it against the C.
let VERSION_MAJOR = 1;
let VERSION_MINOR = 26;

// The three formats: raw DEFLATE (RFC 1951), zlib (RFC 1950) and gzip (RFC
// 1952). zlib and gzip wrap a DEFLATE stream in a header and a checksum.
enum Format { Deflate, Zlib, Gzip }

// The results of decompressing, libdeflate's `enum libdeflate_result`.
let SUCCESS: i32 = 0;
// The data is corrupt, isn't in the format, or uses a feature libdeflate
// doesn't support (a zlib preset dictionary, for one).
let BAD_DATA: i32 = 1;
// decompress_exact: the data has fewer bytes than the `size` it was given.
let SHORT_OUTPUT: i32 = 2;
// The data has more bytes than `max_size` (decompress) or `size`
// (decompress_exact).
let INSUFFICIENT_SPACE: i32 = 3;

// Compression levels: 0 stores the data as it is, 1 is the fastest way to
// compress it and 12 compresses it the most.
let MIN_LEVEL: i32 = 0;
let MAX_LEVEL: i32 = 12;
let DEFAULT_LEVEL: i32 = 6;

// How much decompress will produce unless told otherwise. A few kilobytes of
// input can describe gigabytes of output, so it's good to have a cap.
let DEFAULT_MAX_SIZE: i64 = 1 << 30;

// What a decompression tells you about the stream it read: how many bytes of
// the input it took, and how many bytes it produced. Anything after
// `in_nbytes` isn't part of the stream. Both are 0 if it failed.
struct Info { in_nbytes: i64, out_nbytes: i64 }

// A libdeflate compressor. Its handle is 0 when it isn't open.
struct Compressor { handle: i64 }

// A libdeflate decompressor. Its handle is 0 when it isn't open.
struct Decompressor { handle: i64 }

// The C side, in src/goose_libdeflate.h. libdeflate's compressors are
// pointers, which Goose can't hold, so they cross as i64 handles.
extern fn gld_version_major() -> i32;
extern fn gld_version_minor() -> i32;
extern fn gld_compressor_new(level: i32) -> i64;
extern fn gld_compressor_free(handle: i64);
extern fn gld_compress_bound(handle: i64, format: i32, in_nbytes: i64) -> i64;
extern fn gld_compress(handle: i64, format: i32, data: const u8[:], out: u8[:]) -> i64;
extern fn gld_decompressor_new() -> i64;
extern fn gld_decompressor_free(handle: i64);
extern fn gld_decompress(handle: i64, format: i32, data: const u8[:], out: u8[:], info: Info&) -> i32;
extern fn gld_adler32(adler: u32, data: const u8[:]) -> u32;
extern fn gld_crc32(crc: u32, data: const u8[:]) -> u32;

// The number the C side uses for a format (GLD_DEFLATE and friends).
fn code(format: Format) -> i32 {
    match format {
        Deflate => 0,
        Zlib => 1,
        Gzip => 2,
    }
}

// The libdeflate version the C was built from, as major and minor. It should
// match VERSION_MAJOR and VERSION_MINOR.
fn native_version() -> i32, i32 {
    return gld_version_major(), gld_version_minor();
}

// --- compression ---------------------------------------------------------------

// Makes a compressor for `level`, which is MIN_LEVEL to MAX_LEVEL. It aborts
// on a level outside that, or if libdeflate runs out of memory.
fn compressor(level: i32 = DEFAULT_LEVEL) -> Compressor {
    assert(level >= MIN_LEVEL && level <= MAX_LEVEL);
    let handle = gld_compressor_new(level);
    assert(handle != 0);
    return Compressor { handle: handle };
}

fn close(c: Compressor&) {
    gld_compressor_free(c.handle);
    c.handle = 0;
}

// The most bytes compress can append for `size` bytes of input, however badly
// the data compresses.
fn compress_bound(c: Compressor, size: i64, format: Format) -> i64 {
    assert(c.handle != 0);
    return gld_compress_bound(c.handle, code(format), size);
}

// Appends `data`, compressed, to `out`. Returns the number of bytes appended.
fn compress(c: Compressor, out: u8[>..]&, data: const u8[:], format: Format) -> i64 {
    assert(c.handle != 0);
    let f = code(format);
    let start = out.len;
    // Make room for the worst case, so that it can't run out, and give back
    // what turned out to be unused.
    out.resize(start + gld_compress_bound(c.handle, f, data.len), 0);
    let n = gld_compress(c.handle, f, data, out[start..]);
    assert(n > 0);
    out.resize(start + n);
    return n;
}

// The same, with a compressor that lives for just this call.
fn compress(out: u8[>..]&, data: const u8[:], format: Format, level: i32 = DEFAULT_LEVEL) -> i64 {
    var c = compressor(level);
    let n = compress(c, out, data, format);
    close(c);
    return n;
}

// --- decompression -------------------------------------------------------------

// Makes a decompressor. It aborts if libdeflate runs out of memory.
fn decompressor() -> Decompressor {
    let handle = gld_decompressor_new();
    assert(handle != 0);
    return Decompressor { handle: handle };
}

fn close(d: Decompressor&) {
    gld_decompressor_free(d.handle);
    d.handle = 0;
}

// Appends the decompressed `data` to `out` and returns SUCCESS, or the reason
// it couldn't (and `out` is as it was). It stops at the end of the first
// stream in `data`: `info.in_nbytes` is where that is, so the next stream
// starts there, if there is one.
//
// The size of the output isn't known, so this tries a buffer of a guess and
// doubles it while the data doesn't fit, up to `max_size` bytes. If you know
// the size, decompress_exact doesn't need to do that.
fn decompress(d: Decompressor, out: u8[>..]&, data: const u8[:], format: Format,
              info: Info&, max_size: i64 = DEFAULT_MAX_SIZE) -> i32 {
    assert(d.handle != 0);
    assert(max_size >= 0);
    let f = code(format);
    let start = out.len;
    var size = data.len * 4 + 64;
    loop {
        if size > max_size { size = max_size; }
        out.resize(start + size, 0);
        let status = gld_decompress(d.handle, f, data, out[start..], info);
        if status == SUCCESS {
            out.resize(start + info.out_nbytes);
            return SUCCESS;
        }
        out.resize(start);
        if status != INSUFFICIENT_SPACE || size >= max_size { return status; }
        size *= 2;
    }
}

// The same, without `info`.
fn decompress(d: Decompressor, out: u8[>..]&, data: const u8[:], format: Format,
              max_size: i64 = DEFAULT_MAX_SIZE) -> i32 {
    var info = Info { 0, 0 };
    return decompress(d, out, data, format, info, max_size);
}

// The same, with a decompressor that lives for just this call.
fn decompress(out: u8[>..]&, data: const u8[:], format: Format,
              max_size: i64 = DEFAULT_MAX_SIZE) -> i32 {
    var d = decompressor();
    let status = decompress(d, out, data, format, max_size);
    close(d);
    return status;
}

// For when you know exactly how many bytes `data` decompresses to, say from
// the size a container format stores next to it. It appends exactly `size`
// bytes to `out`, with a single pass over the data and no retrying. It returns
// SHORT_OUTPUT if the data has fewer bytes than that (`info.out_nbytes` is how
// many it has) and INSUFFICIENT_SPACE if it has more. When it fails, `out` is
// as it was.
fn decompress_exact(d: Decompressor, out: u8[>..]&, data: const u8[:], format: Format,
                    size: i64, info: Info&) -> i32 {
    assert(d.handle != 0);
    assert(size >= 0);
    let start = out.len;
    out.resize(start + size, 0);
    var status = gld_decompress(d.handle, code(format), data, out[start..], info);
    if status == SUCCESS && info.out_nbytes != size { status = SHORT_OUTPUT; }
    if status != SUCCESS { out.resize(start); }
    return status;
}

// A short description of a status, for messages.
fn status_name(status: i32) -> u8[:] {
    return match status {
        0 => "success",
        1 => "bad data",
        2 => "short output",
        3 => "insufficient space",
        _ => "unknown status",
    };
}

// --- checksums -----------------------------------------------------------------

// What to start a new checksum from.
let ADLER32_INIT: u32 = 1;
let CRC32_INIT: u32 = 0;

// The Adler-32 of `data` (the checksum zlib streams end with). To checksum in
// pieces, pass the result for the earlier pieces as `adler`.
fn adler32(data: const u8[:], adler: u32 = ADLER32_INIT) -> u32 {
    return gld_adler32(adler, data);
}

// The CRC-32 of `data` (the checksum gzip streams end with). To checksum in
// pieces, pass the result for the earlier pieces as `crc`.
fn crc32(data: const u8[:], crc: u32 = CRC32_INIT) -> u32 {
    return gld_crc32(crc, data);
}
