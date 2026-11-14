// Goose bindings for libdeflate (https://github.com/ebiggers/libdeflate, by
// Eric Biggers): DEFLATE, zlib and gzip compression and decompression, and
// the Adler-32 and CRC-32 checksums. This package carries libdeflate 1.26 and
// builds it itself, so a program only needs
//
//     import deflate from "github.com/bhare1985/goose-libdeflate@v0.2.0";
//
// plus git and a C compiler on the machine that builds it.
//
// The ordinary operations own their temporary native contexts and return a
// bool. A failure's typed reason is available from error() on the same thread:
//
//     guard deflate::compress(packed, data, deflate::Format.Gzip) else {
//         print("compress failed: ", deflate::error());
//         exit(1);
//     }
//     guard deflate::decompress(plain, packed, deflate::Format.Gzip) else {
//         print("decompress failed: ", deflate::error());
//         exit(1);
//     }
//
// For repeated buffers, an advanced API reuses a native compressor or
// decompressor. Those objects use libdeflate's malloc-backed contexts, so
// scope their lifetime with `defer close(c)` / `defer close(d)`. The common
// one-shot API does not expose this cleanup responsibility.
//
// Calls that can fail record their result on the current thread. Check error()
// immediately after false; a later call replaces it. Each thread should own
// its own reusable handles.
//
// A failed decompression leaves `out` unchanged. The zlib/gzip trailer is
// checked; the optional CRC in a gzip header is skipped, as libdeflate does.
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

// The outcome of the most recent operation on this thread. Calls return a
// bool; ask status() or error() immediately after false.
enum Status {
    Ok,
    BadData,
    ShortOutput,
    InsufficientSpace,
    InvalidArgument,
    BadLevel,
    OutOfMemory,
    Closed,
    Other,
}

// Compression levels: 0 stores the data as it is, 1 is the fastest way to
// compress it and 12 compresses it the most.
let MIN_LEVEL:     i32 = 0;
let MAX_LEVEL:     i32 = 12;
let DEFAULT_LEVEL: i32 = 6;
// The names the other libdeflate bindings give the ends of the range.
let FASTEST_LEVEL: i32 = 1;
let BEST_LEVEL:    i32 = 12;

// How much decompress will produce unless told otherwise. A few kilobytes of
// input can describe gigabytes of output, so it's good to have a cap.
let DEFAULT_MAX_SIZE: i64 = 1 << 30;

// What a decompression tells you about the stream it read: how many bytes of
// the input it took, and how many bytes it produced. Anything after
// `in_nbytes` isn't part of the stream. Native decode failures zero both; a
// `decompress_exact` ShortOutput still reports the successfully decoded counts.
struct Info { in_nbytes: i64, out_nbytes: i64 }

// A libdeflate compressor. Its handle is 0 when it isn't open.
struct Compressor { handle: u64 }

// A libdeflate decompressor. Its handle is 0 when it isn't open.
struct Decompressor { handle: u64 }

// The C adapter is declared in include/deflate.h. Native compilers inline its
// functions into generated C; TinyCC links the copies in src/native.c.
extern fn gdf_record_status(code: i32);
extern fn gdf_last_status() -> i32;
extern fn gdf_version_major() -> i32;
extern fn gdf_version_minor() -> i32;
extern fn gdf_open_compressor(level: i32) -> u64;
extern fn gdf_close_compressor(handle: u64);
extern fn gdf_bound(handle: u64, format: i32, in_nbytes: i64) -> i64;
extern fn gdf_compress(handle: u64, format: i32, data: const u8[:], out: u8[:]) -> i64;
extern fn gdf_open_decompressor() -> u64;
extern fn gdf_close_decompressor(handle: u64);
extern fn gdf_decompress(handle: u64, format: i32, data: const u8[:], out: u8[:], counts: i64[:]) -> i32;
extern fn gdf_adler32(data: const u8[:], initial: u32) -> u32;
extern fn gdf_crc32(data: const u8[:], initial: u32) -> u32;

// Translate native results and Goose-side validation failures to one Status.
fn status_of(code: i32) -> Status {
    return match code {
        0 => Status.Ok,
        1 => Status.BadData,
        2 => Status.ShortOutput,
        3 => Status.InsufficientSpace,
        4 => Status.InvalidArgument,
        5 => Status.BadLevel,
        6 => Status.OutOfMemory,
        7 => Status.Closed,
        _ => Status.Other,
    };
}

fn status_code(status: Status) -> i32 {
    return match status {
        Ok => 0,
        BadData => 1,
        ShortOutput => 2,
        InsufficientSpace => 3,
        InvalidArgument => 4,
        BadLevel => 5,
        OutOfMemory => 6,
        Closed => 7,
        Other => 8,
    };
}

// Record every outcome (including success) so the last error describes the
// call that returned false, not an older operation.
fn record(code: i32) -> bool {
    gdf_record_status(code);
    return code == 0;
}

fn record_status(status: Status) -> bool {
    gdf_record_status(status_code(status));
    return false;
}

fn status() -> Status {
    return status_of(gdf_last_status());
}

fn error() -> const u8[:] {
    let s = status();
    if s == Status.Ok { return ""; }
    return status_name(s);
}

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
    return gdf_version_major(), gdf_version_minor();
}

// --- compression ---------------------------------------------------------------

// Allocates a reusable compressor. The handle is owned by convention; close it
// or use `defer close(c)` when leaving its scope. Failure returns a closed
// value and records BadLevel or OutOfMemory.
fn compressor(level: i32 = DEFAULT_LEVEL) -> Compressor, bool {
    if level < MIN_LEVEL || level > MAX_LEVEL {
        return Compressor { handle: 0 }, record_status(Status.BadLevel);
    }
    let handle = gdf_open_compressor(level);
    if handle == 0 {
        return Compressor { handle: 0 }, record_status(Status.OutOfMemory);
    }
    return Compressor { handle: handle }, record(0);
}

fn close(c: Compressor&) {
    gdf_close_compressor(c.handle);
    c.handle = 0;
}

// The most bytes compress can append for `size` bytes of input, or 0 when the
// handle or size is invalid.
fn compress_bound(c: const Compressor&, size: i64, format: Format) -> i64 {
    if c.handle == 0 { record_status(Status.Closed); return 0; }
    if size < 0 { record_status(Status.InvalidArgument); return 0; }
    let bound = gdf_bound(c.handle, code(format), size);
    if bound < 0 { record_status(Status.InvalidArgument); return 0; }
    record(0);
    return bound;
}

// Compresses into caller-owned storage. Returns the byte count and success;
// failure is reported by error() (usually insufficient output space).
fn compress_into(c: const Compressor&, out: u8[:], data: const u8[:],
                 format: Format) -> i64, bool {
    if c.handle == 0 { return 0, record_status(Status.Closed); }
    let n = gdf_compress(c.handle, code(format), data, out);
    if n > 0 { return n, record(0); }
    if n == 0 { return 0, record_status(Status.InsufficientSpace); }
    return 0, record_status(Status.InvalidArgument);
}

// One-shot fixed-buffer compression; the native context is closed on return.
fn compress_into(out: u8[:], data: const u8[:], format: Format,
                 level: i32 = DEFAULT_LEVEL) -> i64, bool {
    let c, ok = compressor(level);
    if !ok { return 0, false; }
    defer close(c);
    return compress_into(c, out, data, format);
}

// Appends `data`, compressed, to `out`; on failure the builder is unchanged.
fn compress(c: const Compressor&, out: u8[>..]&, data: const u8[:], format: Format) -> bool {
    let bound = compress_bound(c, data.len, format);
    if bound <= 0 { return false; }
    let start = out.len;
    out.resize(start + bound, 0);
    let n, ok = compress_into(c, out[start..], data, format);
    if !ok { out.resize(start); return false; }
    out.resize(start + n);
    return true;
}

// One-shot compression: the temporary native context is closed in this scope,
// so ordinary callers have no handle lifetime to manage.
fn compress(out: u8[>..]&, data: const u8[:], format: Format,
            level: i32 = DEFAULT_LEVEL) -> bool {
    let c, ok = compressor(level);
    if !ok { return false; }
    defer close(c);
    return compress(c, out, data, format);
}

// Compresses into a new builder and returns it with success, like igzip's
// `compressed` helper.
fn compressed(data: const u8[:], format: Format, level: i32 = DEFAULT_LEVEL) -> u8[>..], bool {
    var out: u8[>..] = [];
    let ok = compress(out, data, format, level);
    return out, ok;
}

// --- decompression -------------------------------------------------------------

// Allocates a reusable decompressor. Use `defer close(d)` or the one-shot
// builder APIs if the caller should not manage a native handle.
fn decompressor() -> Decompressor, bool {
    let handle = gdf_open_decompressor();
    if handle == 0 {
        return Decompressor { handle: 0 }, record_status(Status.OutOfMemory);
    }
    return Decompressor { handle: handle }, record(0);
}

fn close(d: Decompressor&) {
    gdf_close_decompressor(d.handle);
    d.handle = 0;
}

// Appends the first decompressed stream to `out`. Returns true on success; on
// false, `error()` describes the failure and `out` is unchanged. `info` gives
// the consumed input and produced output counts on success.
fn decompress(d: const Decompressor&, out: u8[>..]&, data: const u8[:], format: Format,
              info: Info&, max_size: i64 = DEFAULT_MAX_SIZE) -> bool {
    if d.handle == 0 { return record_status(Status.Closed); }
    if max_size < 0 {
        info.in_nbytes = 0;
        info.out_nbytes = 0;
        return record_status(Status.InvalidArgument);
    }
    let f = code(format);
    let start = out.len;
    info.in_nbytes = 0;
    info.out_nbytes = 0;
    var size = max_size;
    if max_size > 64 && data.len <= (max_size - 64) / 4 { size = data.len * 4 + 64; }
    loop {
        if size > max_size { size = max_size; }
        out.resize(start + size, 0);
        var counts: i64[2] = [0; 2];
        let rc = gdf_decompress(d.handle, f, data, out[start..], counts);
        if rc == 0 {
            info.in_nbytes = counts[0];
            info.out_nbytes = counts[1];
            out.resize(start + info.out_nbytes);
            return record(0);
        }
        out.resize(start);
        if rc != 3 || size >= max_size { return record(rc); }
        if size > max_size / 2 { size = max_size; }
        else { size *= 2; }
    }
}

// The same, without `info`.
fn decompress(d: const Decompressor&, out: u8[>..]&, data: const u8[:], format: Format,
              max_size: i64 = DEFAULT_MAX_SIZE) -> bool {
    var info = Info { 0, 0 };
    return decompress(d, out, data, format, info, max_size);
}

// One-shot builder decode. The native handle is closed in this scope, so the
// caller gets append semantics and a max-size cap without owning a resource.
fn decompress(out: u8[>..]&, data: const u8[:], format: Format,
              max_size: i64 = DEFAULT_MAX_SIZE) -> bool {
    if max_size < 0 { return record_status(Status.InvalidArgument); }
    let d, ok = decompressor();
    if !ok { return false; }
    defer close(d);
    return decompress(d, out, data, format, max_size);
}

// Decodes into a caller-owned fixed slice. `info` is set on success, and the
// bool/status pair follows the same `guard` pattern as the builder operation.
fn decompress_into(d: const Decompressor&, out: u8[:], data: const u8[:], format: Format,
                   info: Info&) -> bool {
    if d.handle == 0 { return record_status(Status.Closed); }
    var counts: i64[2] = [0; 2];
    let rc = gdf_decompress(d.handle, code(format), data, out, counts);
    if rc == 0 {
        info.in_nbytes = counts[0];
        info.out_nbytes = counts[1];
    } else {
        info.in_nbytes = 0;
        info.out_nbytes = 0;
    }
    return record(rc);
}

// Fixed-buffer one-shot form; no reusable native handle escapes this call.
fn decompress_into(out: u8[:], data: const u8[:], format: Format, info: Info&) -> bool {
    let d, ok = decompressor();
    if !ok { return false; }
    defer close(d);
    return decompress_into(d, out, data, format, info);
}

// Appends exactly `size` decoded bytes. A decoded stream shorter than `size`
// reports ShortOutput; a stream larger than the destination reports
// InsufficientSpace. On every failure `out` is restored to its old length.
fn decompress_exact(d: const Decompressor&, out: u8[>..]&, data: const u8[:], format: Format,
                    size: i64, info: Info&) -> bool {
    if d.handle == 0 { return record_status(Status.Closed); }
    if size < 0 {
        info.in_nbytes = 0;
        info.out_nbytes = 0;
        return record_status(Status.InvalidArgument);
    }
    let start = out.len;
    out.resize(start + size, 0);
    let ok = decompress_into(d, out[start..], data, format, info);
    if !ok { out.resize(start); return false; }
    if info.out_nbytes != size {
        out.resize(start);
        return record_status(Status.ShortOutput);
    }
    return true;
}

// A short description for diagnostics. `error()` returns this for the last
// failed call and an empty string after success.
fn status_name(status: Status) -> const u8[:] {
    return match status {
        Ok => "ok",
        BadData => "bad data",
        ShortOutput => "short output",
        InsufficientSpace => "insufficient output space",
        InvalidArgument => "invalid argument",
        BadLevel => "compression level must be 0..12",
        OutOfMemory => "libdeflate could not allocate a context",
        Closed => "compressor or decompressor is closed",
        Other => "libdeflate reported an unknown error",
    };
}

// --- checksums -----------------------------------------------------------------

// What to start a new checksum from.
let ADLER32_INIT: u32 = 1;
let CRC32_INIT:   u32 = 0;

// The Adler-32 of `data` (the checksum zlib streams end with). To checksum in
// pieces, pass the result for the earlier pieces as `adler`.
fn adler32(data: const u8[:], adler: u32 = ADLER32_INIT) -> u32 {
    return gdf_adler32(data, adler);
}

// The CRC-32 of `data` (the checksum gzip streams end with). To checksum in
// pieces, pass the result for the earlier pieces as `crc`.
fn crc32(data: const u8[:], crc: u32 = CRC32_INIT) -> u32 {
    return gdf_crc32(data, crc);
}
