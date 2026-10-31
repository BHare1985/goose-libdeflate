// Compares libdeflate (through this package) with zlib on a directory of
// files, and prints the results as markdown. Run it with bench/run.sh, which
// also fetches the corpus and records the machine.
//
// What is measured, as in the libdeflater (Rust) benchmarks: whole buffers
// that are already in memory, one thread, no file or stream I/O. A compressor
// (or zlib stream) is made once and reused, the output buffers are made once
// and reused, and the format is zlib. Each timing is the median of 11 samples,
// each sample the mean over enough calls to last at least 2 ms.
//
// Both libraries decompress the same stream, the one zlib wrote at that level.
// Before anything is timed, each library's output for each file is checked by
// the other: decompressing it must give the file back.

import deflate from "..";
import std;
import os;

extern fn zb_compress(level: i32, data: const u8[:], out: u8[:]) -> i64;
extern fn zb_decompress(data: const u8[:], out: u8[:]) -> i64;
extern fn zb_crc32(crc: u32, data: const u8[:]) -> u32;
extern fn zb_adler32(adler: u32, data: const u8[:]) -> u32;

let SAMPLES = 11;
let SAMPLE_NS: i64 = 2000000;

// The median time of F() in nanoseconds.
fn measure<F>() -> f64 {
    var iters: i64 = 1;
    loop {
        let start = clock_ns();
        for i in iters { F(); }
        if clock_ns() - start >= SAMPLE_NS { break; }
        iters *= 2;
    }
    var times: f64[>..] = [];
    for s in SAMPLES {
        let start = clock_ns();
        for i in iters { F(); }
        times.push((clock_ns() - start) as f64 / iters as f64);
    }
    sort(times) { a, b => a < b };
    return times[SAMPLES / 2];
}

struct Timing {
    zlib_compress: f64,
    libdeflate_compress: f64,
    zlib_decompress: f64,
    libdeflate_decompress: f64,
    zlib_size: i64,
    libdeflate_size: i64,
}

fn identical(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    for i in a.len { if a[i] != b[i] { return false; } }
    return true;
}

// zlib's level for a libdeflate one: zlib stops at 9.
fn zlib_level(level: i32) -> i32 { return min(level, 9); }

fn bench_file(data: const u8[:], level: i32, zlib_too: bool) -> Timing {
    var c = deflate::compressor(level);
    var d = deflate::decompressor();
    let zlib_format = deflate::Format.Zlib;
    let cap = deflate::compress_bound(c, data.len, zlib_format);
    var zbuf: u8[>..] = [];
    var dbuf: u8[>..] = [];
    var out: u8[>..] = [];
    zbuf.resize(cap, 0);
    dbuf.resize(cap, 0);
    out.resize(data.len + 1, 0);

    let zn = zb_compress(zlib_level(level), data, zbuf);
    let dn = deflate::compress_into(c, dbuf, data, zlib_format);
    assert(zn > 0 && dn > 0);

    // Each one's output must come back as the file from the other.
    var info = deflate::Info { 0, 0 };
    let status = deflate::decompress_into(d, out, zbuf[..zn], zlib_format, info);
    assert(status == deflate::SUCCESS && identical(out[..info.out_nbytes], data));
    let back = zb_decompress(dbuf[..dn], out);
    assert(back == data.len && identical(out[..back], data));

    // What the stream at this level is: zlib's, for both to decompress.
    let stream = zbuf[..zn];

    var t = Timing { 0.0, 0.0, 0.0, 0.0, zn, dn };
    var sink: i64 = 0;
    if zlib_too {
        t.zlib_compress = measure() { sink += zb_compress(zlib_level(level), data, zbuf); };
        t.zlib_decompress = measure() { sink += zb_decompress(stream, out); };
    }
    t.libdeflate_compress = measure() { sink += deflate::compress_into(c, dbuf, data, zlib_format); };
    t.libdeflate_decompress = measure() {
        sink += deflate::decompress_into(d, out, stream, zlib_format, info) as i64 + info.out_nbytes;
    };
    assert(sink != 0);
    deflate::close(c);
    deflate::close(d);
    return t;
}

fn num(out: u8[>..]&, x: f64, digits: i64) { format_flt(out, x, digits); }

// Microseconds, from nanoseconds.
fn micros(out: u8[>..]&, ns: f64) { format_flt(out, ns / 1000.0, if ns < 100000.0 { 1 } else { 0 }); }

fn main() {
    let a = args();
    if a.len < 2 { write_stderr("usage: bench corpus_dir [corpus_dir...]\n"); exit(2); }

    // Every file of every directory given.
    var paths: u8[][>..] = [];
    for k in 1..a.len {
        var names: u8[>..] = [];
        guard list_dir(a[k], names) else { write_stderr("cannot read the directory\n"); exit(2); }
        each_split(names, '\n') {
            if it.len > 0 { paths.push(str(a[k], "/", it)); }
        };
    }

    let levels: i32[] = [1, 3, 6, 9, 12];
    var table: u8[>..] = [];
    table.append("| level | zlib compress MB/s | libdeflate compress MB/s | speedup | zlib size | libdeflate size | zlib decompress MB/s | libdeflate decompress MB/s | speedup |\n");
    table.append("|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
    var files: u8[>..] = [];
    files.append("| file | size [KiB] | zlib compress [us] | libdeflate compress [us] | speedup | zlib decompress [us] | libdeflate decompress [us] | speedup |\n");
    files.append("|---|---:|---:|---:|---:|---:|---:|---:|\n");

    for level in levels {
        let zlib_too = level <= 9;
        var total_bytes: i64 = 0;
        var zc: f64 = 0.0;
        var dc: f64 = 0.0;
        var zd: f64 = 0.0;
        var dd: f64 = 0.0;
        var zsize: i64 = 0;
        var dsize: i64 = 0;
        for path in paths {
            var data: u8[>..] = [];
            guard read_file(path, data) else { write_stderr("cannot read a file\n"); exit(2); }
            let t = bench_file(data, level, zlib_too);
            total_bytes += data.len;
            zc += t.zlib_compress;
            dc += t.libdeflate_compress;
            zd += t.zlib_decompress;
            dd += t.libdeflate_decompress;
            zsize += t.zlib_size;
            dsize += t.libdeflate_size;
            if level == 6 {
                var name: u8[>..] = [];
                var i = path.len;
                while i > 0 && path[i - 1] != '/' { i--; }
                name.append(path[i..]);
                files.append("| ");
                files.append(name);
                format(files, " | ", data.len / 1024, " | ");
                micros(files, t.zlib_compress);
                files.append(" | ");
                micros(files, t.libdeflate_compress);
                files.append(" | ");
                num(files, t.zlib_compress / t.libdeflate_compress, 1);
                files.append(" | ");
                micros(files, t.zlib_decompress);
                files.append(" | ");
                micros(files, t.libdeflate_decompress);
                files.append(" | ");
                num(files, t.zlib_decompress / t.libdeflate_decompress, 1);
                files.append(" |\n");
            }
        }
        // bytes per nanosecond is GB/s; times 1000 is MB/s.
        let mb = total_bytes as f64 * 1000.0;
        format(table, "| ", level, " | ");
        if zlib_too {
            num(table, mb / zc, 0);
            format(table, " | ");
        } else {
            format(table, "n/a | ");
        }
        num(table, mb / dc, 0);
        format(table, " | ");
        if zlib_too { num(table, zc / dc, 1); format(table, "x | "); } else { format(table, "n/a | "); }
        if zlib_too { format(table, zsize, " | "); } else { format(table, "n/a | "); }
        format(table, dsize, " | ");
        if zlib_too { num(table, mb / zd, 0); format(table, " | "); } else { format(table, "n/a | "); }
        num(table, mb / dd, 0);
        format(table, " | ");
        if zlib_too { num(table, zd / dd, 1); format(table, "x |\n"); } else { format(table, "n/a |\n"); }
        write_stderr(str("level ", level, " done\n"));
    }

    // The checksums, over the whole corpus as one buffer.
    var all: u8[>..] = [];
    for path in paths {
        guard read_file(path, all) else { write_stderr("cannot read a file\n"); exit(2); }
    }
    assert(zb_crc32(0, all) == deflate::crc32(all) && zb_adler32(1, all) == deflate::adler32(all));
    var sink: u32 = 0;
    let bytes = all.len as f64;
    let zcrc = measure() { sink ^= zb_crc32(0, all); };
    let dcrc = measure() { sink ^= deflate::crc32(all); };
    let zadler = measure() { sink ^= zb_adler32(1, all); };
    let dadler = measure() { sink ^= deflate::adler32(all); };
    var sums: u8[>..] = [];
    sums.append("| checksum | zlib GB/s | libdeflate GB/s | speedup |\n|---|---:|---:|---:|\n");
    sums.append("| CRC-32 | ");
    num(sums, bytes / zcrc, 1);
    sums.append(" | ");
    num(sums, bytes / dcrc, 1);
    sums.append(" | ");
    num(sums, zcrc / dcrc, 1);
    sums.append("x |\n| Adler-32 | ");
    num(sums, bytes / zadler, 1);
    sums.append(" | ");
    num(sums, bytes / dadler, 1);
    sums.append(" | ");
    num(sums, zadler / dadler, 1);
    sums.append("x |\n");

    print("### Whole corpus, by level\n");
    print(table);
    print("### Each file, level 6\n");
    print(files);
    print("### Checksums\n");
    print(sums);
    if sink == 0 { print("(the checksums were all zero)"); }
}
