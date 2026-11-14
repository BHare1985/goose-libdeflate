// Binding overhead benchmark. The Goose and direct-C loops share one executable,
// one libdeflate archive, same handles and caller-owned buffers.
import std;
import os;
import deflate from "..";

extern fn direct_compress(handle: u64, format: i32, input: const u8[:], output: u8[:],
                          iterations: i64) -> u64;
extern fn direct_decompress(handle: u64, format: i32, input: const u8[:], output: u8[:],
                            iterations: i64) -> u64;
extern fn direct_checksum(operation: i32, input: const u8[:], iterations: i64) -> u64;

fn goose_loop(c: const deflate::Compressor&, d: const deflate::Decompressor&,
              operation: i32, format: deflate::Format, input: const u8[:],
              stream:    const u8[:], compressed: u8[:], output: u8[:],
              iterations: i64) -> u64 {
    var sum: u64 = 0;
    if operation == 0 {
        for i in iterations {
            let n, ok = deflate::compress_into(c, compressed, input, format);
            if !ok { abort(str("compress: ", deflate::error())); }
            sum += n as u64;
        }
    } else if operation == 1 {
        var info = deflate::Info { 0, 0 };
        for i in iterations {
            let ok = deflate::decompress_into(d, output, stream, format, info);
            if !ok { abort(str("decompress: ", deflate::error())); }
            sum += (info.in_nbytes + info.out_nbytes) as u64;
        }
    } else if operation == 2 {
        for i in iterations { sum += deflate::crc32(input); }
    } else {
        for i in iterations { sum += deflate::adler32(input); }
    }
    return sum;
}

fn c_loop(c: const deflate::Compressor&, d: const deflate::Decompressor&,
          operation: i32, format_code: i32, input: const u8[:],
          stream:    const u8[:], compressed: u8[:], output: u8[:],
          iterations: i64) -> u64 {
    if operation == 0 {
        return direct_compress(c.handle, format_code, input, compressed, iterations);
    }
    if operation == 1 {
        return direct_decompress(d.handle, format_code, stream, output, iterations);
    }
    return direct_checksum(operation, input, iterations);
}

fn identical(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    for i in a.len { if a[i] != b[i] { return false; } }
    return true;
}

fn format_code(format: deflate::Format) -> i32 {
    return match format {
        Deflate => 0,
        Zlib => 1,
        Gzip => 2,
    };
}

fn main() {
    let argv = args();
    if argv.len != 5 { abort("usage: overhead goose|c format operation iterations"); }
    let format_num, f_ok = parse_int(argv[2]);
    let operation, o_ok = parse_int(argv[3]);
    let iterations, i_ok = parse_int(argv[4]);
    if !f_ok || !o_ok || !i_ok || iterations <= 0 { abort("bad arguments"); }
    if format_num < 0 || format_num > 2 || operation < 0 || operation > 3 { abort("bad format/operation"); }

    var format = deflate::Format.Deflate;
    if format_num == 1 { format = deflate::Format.Zlib; }
    if format_num == 2 { format = deflate::Format.Gzip; }
    let c, c_ok = deflate::compressor(1);
    let d, d_ok = deflate::decompressor();
    if !c_ok || !d_ok { abort(str("context allocation: ", deflate::error())); }
    defer deflate::close(c);
    defer deflate::close(d);

    var input: u8[>..] = [];
    if !read_file("input", input) || input.len == 0 { abort("missing input"); }
    var compressed: u8[>..] = [];
    compressed.resize(deflate::compress_bound(c, input.len, format), 0);
    var decoded: u8[>..] = [];
    decoded.resize(input.len, 0);
    let n, packed_ok = deflate::compress_into(c, compressed, input, format);
    if !packed_ok { abort(str("fixture compression: ", deflate::error())); }
    var stream: u8[>..] = [];
    stream.append(compressed[..n]);

    // Warm both paths outside the measured interval and ensure they agree.
    let warm_goose = goose_loop(c, d, operation as! i32, format, input, stream,
                                compressed, decoded, 8);
    let warm_c = c_loop(c, d, operation as! i32, format_code(format), input,
                        stream, compressed, decoded, 8);
    if warm_goose != warm_c { abort("warmup checksum mismatch"); }

    let start = clock_ns();
    var sum: u64 = 0;
    if argv[1] == "goose" {
        sum = goose_loop(c, d, operation as! i32, format, input, stream,
                         compressed, decoded, iterations);
    } else if argv[1] == "c" {
        sum = c_loop(c, d, operation as! i32, format_code(format), input,
                     stream, compressed, decoded, iterations);
    } else {
        abort("mode must be goose or c");
    }
    let elapsed = clock_ns() - start;

    // Verify complete output outside the timed interval.
    if operation == 0 {
        var info = deflate::Info { 0, 0 };
        let ok = deflate::decompress_into(d, decoded, compressed, format, info);
        if !ok || info.out_nbytes != input.len || !identical(decoded, input) { abort("compression output mismatch"); }
    } else if operation == 1 && !identical(decoded, input) {
        abort("decompression output mismatch");
    }
    print(elapsed, " ", sum);
}
