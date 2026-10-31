// Tests of the deflate package. Run from the package directory:
//
//     goose test/test_deflate.goose
//
// Exit status 0 and the last line "all N checks passed" mean success.

import deflate from "..";
import std;

var checks: i64 = 0;
var failures: i64 = 0;

fn check(ok: bool, what: const u8[:]) {
    checks++;
    if !ok {
        failures++;
        print("FAIL: ", what);
    }
}

fn same(a: const u8[:], b: const u8[:]) -> bool {
    if a.len != b.len { return false; }
    for i in a.len { if a[i] != b[i] { return false; } }
    return true;
}

// Data of a few kinds, for sizes and seeds.
fn text(out: u8[>..]&, n: i64, seed: u64) {
    var r = rng { seed };
    let words = ["the ", "quick ", "brown ", "fox ", "jumps ", "over ", "lazy ", "dog ", "and ", "so on\n"];
    while out.len < n {
        out.append(words[r.rand_int(words.len)]);
    }
    out.resize(n);
}

fn noise(out: u8[>..]&, n: i64, seed: u64) {
    var r = rng { seed };
    for i in n { out.push(r.rand_int(256) as! u8); }
}

fn zeros(out: u8[>..]&, n: i64) { out.resize(n, 0); }

let FORMATS = [deflate::Format.Deflate, deflate::Format.Zlib, deflate::Format.Gzip];

fn format_name(f: deflate::Format) -> u8[:] {
    return match f { Deflate => "deflate", Zlib => "zlib", Gzip => "gzip" };
}

// --- known answers --------------------------------------------------------------

fn test_checksums() {
    check(deflate::crc32("123456789") == 0xCBF43926, "crc32 of 123456789");
    check(deflate::adler32("Wikipedia") == 0x11E60398, "adler32 of Wikipedia");
    check(deflate::crc32("") == 0, "crc32 of nothing");
    check(deflate::adler32("") == 1, "adler32 of nothing");

    // Running checksums over pieces equal the checksum of the whole.
    var data: u8[>..] = [];
    text(data, 100000, 1);
    var crc = deflate::CRC32_INIT;
    var adler = deflate::ADLER32_INIT;
    var at = 0;
    while at < data.len {
        let end = min(at + 777, data.len);
        crc = deflate::crc32(data[at..end], crc);
        adler = deflate::adler32(data[at..end], adler);
        at = end;
    }
    check(crc == deflate::crc32(data), "crc32 in pieces");
    check(adler == deflate::adler32(data), "adler32 in pieces");
}

// Streams made by zlib and gzip themselves (Python's, at level 9) for
// "hello hello hello hello".
let HELLO = "hello hello hello hello";
let HELLO_RAW: u8[] = [0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0xc8, 0x40, 0x27, 0x01];
let HELLO_ZLIB: u8[] = [0x78, 0xda, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0xc8, 0x40, 0x27, 0x01,
                        0x68, 0x03, 0x08, 0xb1];
let HELLO_GZIP: u8[] = [0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xff, 0xcb, 0x48,
                        0xcd, 0xc9, 0xc9, 0x57, 0xc8, 0x40, 0x27, 0x01, 0xe3, 0x51, 0x3d, 0x8d,
                        0x17, 0x00, 0x00, 0x00];

fn test_known_streams() {
    for f in FORMATS {
        let stream: const u8[:] = match f {
            Deflate => HELLO_RAW,
            Zlib => HELLO_ZLIB,
            Gzip => HELLO_GZIP,
        };
        var out: u8[>..] = [];
        let status = deflate::decompress(out, stream, f);
        check(status == deflate::SUCCESS, str("decompress known ", format_name(f), " stream"));
        check(same(out, HELLO), str("known ", format_name(f), " stream's content"));
    }
}

// --- round trips ----------------------------------------------------------------

fn roundtrip(data: const u8[:], level: i32, f: deflate::Format, what: const u8[:]) {
    let name = str(what, " ", format_name(f), " level ", level, " size ", data.len);

    var packed: u8[>..] = [];
    let n = deflate::compress(packed, data, f, level);
    check(n == packed.len, str(name, ": compress returns the bytes appended"));

    var c = deflate::compressor(level);
    check(n <= deflate::compress_bound(c, data.len, f), str(name, ": within compress_bound"));
    deflate::close(c);

    var plain: u8[>..] = [];
    var info = deflate::Info { 0, 0 };
    var d = deflate::decompressor();
    let status = deflate::decompress(d, plain, packed, f, info);
    deflate::close(d);
    check(status == deflate::SUCCESS, str(name, ": decompress"));
    check(same(plain, data), str(name, ": same bytes back"));
    check(info.in_nbytes == packed.len, str(name, ": the stream is all the input"));
    check(info.out_nbytes == data.len, str(name, ": info.out_nbytes"));

    // With the size known.
    var exact: u8[>..] = [];
    var d2 = deflate::decompressor();
    let status2 = deflate::decompress_exact(d2, exact, packed, f, data.len, info);
    deflate::close(d2);
    check(status2 == deflate::SUCCESS, str(name, ": decompress_exact"));
    check(same(exact, data), str(name, ": decompress_exact bytes"));
}

fn test_roundtrips() {
    var empty: u8[>..] = [];
    var one: u8[>..] = [];
    one.push(42);
    var small: u8[>..] = [];
    text(small, 100, 2);
    var medium: u8[>..] = [];
    text(medium, 70000, 3);
    var random: u8[>..] = [];
    noise(random, 70000, 4);
    var zero: u8[>..] = [];
    zeros(zero, 300000);

    for f in FORMATS {
        for level in 0..13 {
            let lv = level as! i32;
            roundtrip(empty, lv, f, "empty");
            roundtrip(one, lv, f, "one byte");
            roundtrip(small, lv, f, "short text");
            roundtrip(medium, lv, f, "text");
            roundtrip(random, lv, f, "noise");
            roundtrip(zero, lv, f, "zeros");
        }
    }
}

// Sizes around the places a compressor's blocks and buffers change over.
fn test_sizes() {
    for size in [2, 3, 255, 256, 257, 1023, 1024, 1025, 32767, 32768, 32769, 65535, 65536, 65537,
                 262143, 262144, 262145] {
        var data: u8[>..] = [];
        text(data, size, 5 + size as! u64);
        roundtrip(data, 6, deflate::Format.Zlib, "boundary text");
        roundtrip(data, 1, deflate::Format.Gzip, "boundary text");
        var noisy: u8[>..] = [];
        noise(noisy, size, 6 + size as! u64);
        roundtrip(noisy, 12, deflate::Format.Deflate, "boundary noise");
    }
}

// A level compresses at least as well as the one-step-faster one on text
// (not a law of the library, but a sanity check on the levels reaching it),
// and level 0 stores.
fn test_levels_differ() {
    var data: u8[>..] = [];
    text(data, 200000, 7);
    var sizes: i64[>..] = [];
    for level in 0..13 {
        var packed: u8[>..] = [];
        deflate::compress(packed, data, deflate::Format.Deflate, level as! i32);
        sizes.push(packed.len);
    }
    check(sizes[0] > data.len, "level 0 stores, a little larger than the input");
    check(sizes[1] < data.len / 2, "level 1 compresses text");
    check(sizes[12] <= sizes[1], "level 12 is no worse than level 1");
    check(sizes[9] <= sizes[6], "level 9 is no worse than level 6");
}

// --- appending, reuse -----------------------------------------------------------

fn test_appending() {
    var data: u8[>..] = [];
    text(data, 5000, 8);

    // compress appends after what `out` holds.
    var out: u8[>..] = [];
    out.append("PREFIX");
    let n = deflate::compress(out, data, deflate::Format.Zlib);
    check(out.len == 6 + n, "compress appends");
    check(same(out[..6], "PREFIX"), "compress leaves the prefix alone");

    // so does decompress, whose input is a slice of the same kind of buffer.
    var plain: u8[>..] = [];
    plain.append("HEAD:");
    let status = deflate::decompress(plain, out[6..], deflate::Format.Zlib);
    check(status == deflate::SUCCESS, "decompress after a prefix");
    check(same(plain[..5], "HEAD:"), "decompress leaves the prefix alone");
    check(same(plain[5..], data), "decompress appends");

    // A failure leaves `out` as it was.
    var kept: u8[>..] = [];
    kept.append("KEEP");
    let bad = deflate::decompress(kept, "this is not compressed data", deflate::Format.Zlib);
    check(bad == deflate::BAD_DATA, "garbage is BAD_DATA");
    check(same(kept, "KEEP"), "a failed decompress leaves out as it was");
}

fn test_reuse() {
    var c = deflate::compressor(9);
    var d = deflate::decompressor();
    for i in 20 {
        var data: u8[>..] = [];
        text(data, 1000 + i * 3000, 100 + i as! u64);
        var packed: u8[>..] = [];
        deflate::compress(c, packed, data, deflate::Format.Gzip);
        var plain: u8[>..] = [];
        let status = deflate::decompress(d, plain, packed, deflate::Format.Gzip);
        check(status == deflate::SUCCESS && same(plain, data), "reused handles");
    }
    deflate::close(c);
    deflate::close(d);
    check(c.handle == 0 && d.handle == 0, "close clears the handle");
    deflate::close(c);
    deflate::close(d);
    check(c.handle == 0 && d.handle == 0, "closing twice is harmless");
}

// --- bad data -------------------------------------------------------------------

fn test_bad_data() {
    var data: u8[>..] = [];
    text(data, 20000, 9);

    for f in FORMATS {
        var packed: u8[>..] = [];
        deflate::compress(packed, data, f);
        let name = format_name(f);

        // Cut short at a few places.
        for keep in [0, 1, 2, 5, packed.len / 2, packed.len - 1] {
            var out: u8[>..] = [];
            let status = deflate::decompress(out, packed[..keep], f);
            check(status != deflate::SUCCESS, str(name, " cut to ", keep, " bytes fails"));
            check(out.len == 0, str(name, " cut to ", keep, " bytes leaves out empty"));
        }

        // The checksum at the end of a zlib or a gzip stream is checked.
        if f != deflate::Format.Deflate {
            var bent = copy(packed);
            bent[bent.len - 1] ^= 0x55;
            var out: u8[>..] = [];
            check(deflate::decompress(out, bent, f) == deflate::BAD_DATA,
                  str(name, " with a bad checksum is BAD_DATA"));
        }
    }

    // One format's data read as another's.
    var gz: u8[>..] = [];
    deflate::compress(gz, data, deflate::Format.Gzip);
    var zl: u8[>..] = [];
    deflate::compress(zl, data, deflate::Format.Zlib);
    var out: u8[>..] = [];
    check(deflate::decompress(out, gz, deflate::Format.Zlib) == deflate::BAD_DATA, "gzip as zlib");
    check(deflate::decompress(out, zl, deflate::Format.Gzip) == deflate::BAD_DATA, "zlib as gzip");
    check(deflate::decompress(out, "", deflate::Format.Gzip) == deflate::BAD_DATA, "nothing as gzip");
    check(out.len == 0, "out untouched by the failures");

    // Every single flipped bit in a short stream either fails or decodes to
    // something (a stored byte, say) that is not a crash; the checksums mean
    // it never decodes to the original.
    for i in HELLO_ZLIB.len * 8 {
        var bent = copy(HELLO_ZLIB);
        bent[i / 8] ^= (1 << (i % 8)) as! u8;
        var o: u8[>..] = [];
        let status = deflate::decompress(o, bent, deflate::Format.Zlib);
        check(status != deflate::SUCCESS || !same(o, HELLO), "a flipped bit never decodes as the original");
    }
}

// --- how much, and where it ended -----------------------------------------------

fn test_limits() {
    var data: u8[>..] = [];
    zeros(data, 8000000);
    var packed: u8[>..] = [];
    deflate::compress(packed, data, deflate::Format.Gzip);
    check(packed.len < 20000, "eight million zeros are a few thousand bytes");

    var out: u8[>..] = [];
    check(deflate::decompress(out, packed, deflate::Format.Gzip) == deflate::SUCCESS, "default max_size");
    check(out.len == 8000000, "the whole 8000000 bytes");

    var capped: u8[>..] = [];
    let status = deflate::decompress(capped, packed, deflate::Format.Gzip, 1000000);
    check(status == deflate::INSUFFICIENT_SPACE, "max_size below the size is INSUFFICIENT_SPACE");
    check(capped.len == 0, "and out is as it was");
    check(deflate::decompress(capped, packed, deflate::Format.Gzip, 8000000) == deflate::SUCCESS,
          "max_size exactly the size succeeds");
    check(capped.len == 8000000, "exactly the size");
    var capped2: u8[>..] = [];
    check(deflate::decompress(capped2, packed, deflate::Format.Gzip, 7999999) == deflate::INSUFFICIENT_SPACE,
          "max_size one below the size fails");

    // decompress_exact is exact in both directions.
    var d = deflate::decompressor();
    var info = deflate::Info { 0, 0 };
    var e: u8[>..] = [];
    check(deflate::decompress_exact(d, e, packed, deflate::Format.Gzip, 8000000, info) == deflate::SUCCESS,
          "decompress_exact with the size");
    check(deflate::decompress_exact(d, e, packed, deflate::Format.Gzip, 8000001, info) == deflate::SHORT_OUTPUT,
          "decompress_exact with a size too large is SHORT_OUTPUT");
    check(deflate::decompress_exact(d, e, packed, deflate::Format.Gzip, 7999999, info) == deflate::INSUFFICIENT_SPACE,
          "decompress_exact with a size too small is INSUFFICIENT_SPACE");
    check(e.len == 8000000, "decompress_exact left only the successful result in out");
    deflate::close(d);
}

// Bytes after a stream, and several streams in a row, are the caller's: info
// says where the next one starts.
fn test_trailing_and_concatenated() {
    var a: u8[>..] = [];
    var b: u8[>..] = [];
    text(a, 3000, 10);
    text(b, 4000, 11);

    for f in FORMATS {
        var pa: u8[>..] = [];
        var pb: u8[>..] = [];
        deflate::compress(pa, a, f);
        deflate::compress(pb, b, f);

        var both: u8[>..] = [];
        both.append(pa);
        both.append(pb);
        both.append("trailing");

        var d = deflate::decompressor();
        var info = deflate::Info { 0, 0 };
        var first: u8[>..] = [];
        check(deflate::decompress(d, first, both, f, info) == deflate::SUCCESS, "first stream");
        check(same(first, a), "first stream's bytes");
        check(info.in_nbytes == pa.len, str(format_name(f), ": first stream's length"));

        var second: u8[>..] = [];
        let rest = both[info.in_nbytes..];
        check(deflate::decompress(d, second, rest, f, info) == deflate::SUCCESS, "second stream");
        check(same(second, b), "second stream's bytes");
        check(info.in_nbytes == pb.len, str(format_name(f), ": second stream's length"));
        check(same(rest[info.in_nbytes..], "trailing"), "what follows the streams");
        deflate::close(d);
    }
}

// --- format details -------------------------------------------------------------

// A gzip header with every optional field: an extra field, a file name, a
// comment and a header CRC. Made by hand, since gzip itself writes few of them.
let HELLO_GZIP_FULL: u8[] = [
    0x1f, 0x8b, 0x08, 0x1e, 0x01, 0x02, 0x03, 0x04, 0x00, 0x03, 0x03, 0x00, 0x61, 0x62, 0x63,
    0x6e, 0x61, 0x6d, 0x65, 0x2e, 0x74, 0x78, 0x74, 0x00, 0x61, 0x20, 0x63, 0x6f, 0x6d, 0x6d,
    0x65, 0x6e, 0x74, 0x00, 0xbe, 0x0c, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0xc8, 0x40, 0x27,
    0x01, 0xe3, 0x51, 0x3d, 0x8d, 0x17, 0x00, 0x00, 0x00];

// A raw stream of one stored block (final, length 23), which is what level 0
// writes.
let HELLO_STORED: u8[] = [
    0x01, 0x17, 0x00, 0xe8, 0xff, 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x68, 0x65, 0x6c, 0x6c, 0x6f,
    0x20, 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x68, 0x65, 0x6c, 0x6c, 0x6f];

// A zlib stream made with a preset dictionary ("hello "), which libdeflate
// doesn't support.
let HELLO_ZLIB_DICT: u8[] = [
    0x78, 0xf9, 0x08, 0x61, 0x02, 0x35, 0xcb, 0xc0, 0x4e, 0x02, 0x00, 0x68, 0x03, 0x08, 0xb1];

fn test_format_details() {
    var out: u8[>..] = [];
    check(deflate::decompress(out, HELLO_GZIP_FULL, deflate::Format.Gzip) == deflate::SUCCESS,
          "gzip with extra, name, comment and header crc");
    check(same(out, HELLO), "gzip with every header field: content");

    var stored: u8[>..] = [];
    check(deflate::decompress(stored, HELLO_STORED, deflate::Format.Deflate) == deflate::SUCCESS,
          "stored block");
    check(same(stored, HELLO), "stored block: content");

    var dict: u8[>..] = [];
    check(deflate::decompress(dict, HELLO_ZLIB_DICT, deflate::Format.Zlib) == deflate::BAD_DATA,
          "zlib with a preset dictionary is BAD_DATA");
    check(dict.len == 0, "and out is untouched");

    // libdeflate skips a gzip header's CRC without checking it, so a wrong one
    // changes nothing. The data's own CRC, in the trailer, is checked (see
    // test_bad_data).
    var bent = copy(HELLO_GZIP_FULL);
    bent[34] ^= 1;
    var o2: u8[>..] = [];
    check(deflate::decompress(o2, bent, deflate::Format.Gzip) == deflate::SUCCESS && same(o2, HELLO),
          "a gzip header crc that is wrong is not checked");
}

// The end of a zlib stream is the Adler-32 of the data, big endian; a gzip
// stream ends with its CRC-32 and its length mod 2^32, little endian.
fn be32(s: const u8[:]) -> u32 {
    return (s[0] as u32) << 24 | (s[1] as u32) << 16 | (s[2] as u32) << 8 | s[3];
}

fn le32(s: const u8[:]) -> u32 {
    return (s[3] as u32) << 24 | (s[2] as u32) << 16 | (s[1] as u32) << 8 | s[0];
}

fn test_trailers() {
    for size in [0, 1, 1000, 100000] {
        var data: u8[>..] = [];
        noise(data, size, 20 + size as! u64);
        var zl: u8[>..] = [];
        deflate::compress(zl, data, deflate::Format.Zlib);
        check(be32(zl[zl.len - 4..]) == deflate::adler32(data), str("zlib trailer for ", size, " bytes"));
        var gz: u8[>..] = [];
        deflate::compress(gz, data, deflate::Format.Gzip);
        check(le32(gz[gz.len - 8..]) == deflate::crc32(data), str("gzip crc for ", size, " bytes"));
        check(le32(gz[gz.len - 4..]) == size as! u32, str("gzip length for ", size, " bytes"));
        check(gz[0] == 0x1f && gz[1] == 0x8b, "gzip magic");
        check(zl[0] & 0x0f == 8, "zlib method is deflate");
    }
}

// --- reproducibility ------------------------------------------------------------

// The same input gives the same output, and a compressor that has been used
// before gives what a new one does.
fn test_deterministic() {
    var data: u8[>..] = [];
    text(data, 150000, 30);
    for level in [1, 6, 12] {
        var a: u8[>..] = [];
        var b: u8[>..] = [];
        deflate::compress(a, data, deflate::Format.Gzip, level as! i32);
        deflate::compress(b, data, deflate::Format.Gzip, level as! i32);
        check(same(a, b), str("level ", level, " twice"));

        var c = deflate::compressor(level as! i32);
        var other: u8[>..] = [];
        noise(other, 50000, 31);
        var scratch: u8[>..] = [];
        deflate::compress(c, scratch, other, deflate::Format.Gzip);
        var used: u8[>..] = [];
        deflate::compress(c, used, data, deflate::Format.Gzip);
        deflate::close(c);
        check(same(a, used), str("level ", level, " on a used compressor"));
    }
}

// --- inputs that don't start where the allocation does --------------------------

fn test_offsets() {
    var data: u8[>..] = [];
    text(data, 9000, 40);
    var packed: u8[>..] = [];
    deflate::compress(packed, data, deflate::Format.Zlib);

    for off in 0..9 {
        // The stream starting `off` bytes into a buffer.
        var buf: u8[>..] = [];
        for i in off { buf.push(0xAA); }
        buf.append(packed);
        buf.append("tail");
        var out: u8[>..] = [];
        let status = deflate::decompress(out, buf[off..], deflate::Format.Zlib);
        check(status == deflate::SUCCESS && same(out, data), str("stream at offset ", off));

        // The data to compress starting `off` bytes into a buffer, ending early.
        var packed2: u8[>..] = [];
        deflate::compress(packed2, data[off..9000 - off], deflate::Format.Zlib);
        var back: u8[>..] = [];
        let status2 = deflate::decompress(back, packed2, deflate::Format.Zlib);
        check(status2 == deflate::SUCCESS && same(back, data[off..9000 - off]), str("data at offset ", off));
    }
}

// --- the limits at zero ---------------------------------------------------------

fn test_zero_max_size() {
    // An empty stream decompresses to nothing, which fits in nothing.
    for f in FORMATS {
        var empty: u8[>..] = [];
        var packed: u8[>..] = [];
        deflate::compress(packed, empty, f);
        var out: u8[>..] = [];
        check(deflate::decompress(out, packed, f, 0) == deflate::SUCCESS, str(format_name(f), ": empty into 0"));
        check(out.len == 0, "and gives nothing");

        packed.resize(0);
        deflate::compress(packed, "x", f);
        check(deflate::decompress(out, packed, f, 0) == deflate::INSUFFICIENT_SPACE,
              str(format_name(f), ": one byte into 0"));
        check(deflate::decompress(out, packed, f, 1) == deflate::SUCCESS, str(format_name(f), ": one byte into 1"));
        check(same(out, "x"), "and gives it");
    }
}

// Failure leaves info zeroed, so that it can't be mistaken for a result.
fn test_info_on_failure() {
    var d = deflate::decompressor();
    var info = deflate::Info { 99, 99 };
    var out: u8[>..] = [];
    check(deflate::decompress(d, out, "garbage garbage garbage", deflate::Format.Gzip, info) == deflate::BAD_DATA,
          "garbage");
    check(info.in_nbytes == 0 && info.out_nbytes == 0, "info is zero after a failure");
    deflate::close(d);
}

// --- larger inputs --------------------------------------------------------------

fn test_large() {
    var data: u8[>..] = [];
    text(data, 24000000, 50);
    var tail: u8[>..] = [];
    noise(tail, 1000000, 51);
    data.append(tail);
    roundtrip(data, 3, deflate::Format.Gzip, "large");

    var smaller: u8[>..] = [];
    text(smaller, 3000000, 52);
    roundtrip(smaller, 12, deflate::Format.Zlib, "large");
}

// --- many random cases ----------------------------------------------------------

// Data of a random kind, from long runs of a few bytes to noise, in a random size.
fn random_data(out: u8[>..]&, r: rng&) {
    let size = r.rand_int(r.rand_int(100000) + 1);
    let kind = r.rand_int(4);
    if kind == 0 { noise(out, size, r.rand_u64()); }
    if kind == 1 { text(out, size, r.rand_u64()); }
    if kind == 2 {
        // Runs of random length and byte.
        while out.len < size {
            let b = r.rand_int(256) as! u8;
            for i in r.rand_int(300) + 1 { out.push(b); }
        }
        out.resize(size);
    }
    if kind == 3 {
        // Pieces of text and noise mixed.
        while out.len < size {
            var piece: u8[>..] = [];
            if r.rand_int(2) == 0 { text(piece, r.rand_int(2000), r.rand_u64()); }
            else { noise(piece, r.rand_int(2000), r.rand_u64()); }
            out.append(piece);
        }
        out.resize(size);
    }
}

fn test_random_roundtrips() {
    var r = rng { 12345 };
    var c: i64 = 0;
    for i in 400 {
        var data: u8[>..] = [];
        random_data(data, r);
        let level = r.rand_int(13) as! i32;
        let f = FORMATS[r.rand_int(3)];
        var packed: u8[>..] = [];
        deflate::compress(packed, data, f, level);
        var plain: u8[>..] = [];
        let status = deflate::decompress(plain, packed, f);
        if status != deflate::SUCCESS || !same(plain, data) {
            print("random case ", i, ": ", format_name(f), " level ", level, " size ", data.len);
            c++;
        }
    }
    check(c == 0, "random round trips");
}

// Streams with a few bytes changed, and bytes that were never a stream, must
// fail cleanly or decode to something: never crash, and leave `out` alone when
// they fail. A zlib stream with a changed byte after its header must not
// decode to the wrong data, since its checksum covers it.
fn test_random_damage() {
    var r = rng { 777 };
    var d = deflate::decompressor();
    var wrong: i64 = 0;
    for i in 600 {
        var data: u8[>..] = [];
        text(data, r.rand_int(30000) + 1, r.rand_u64());
        var packed: u8[>..] = [];
        let f = FORMATS[r.rand_int(3)];
        deflate::compress(packed, data, f, r.rand_int(13) as! i32);

        var bent = copy(packed);
        for k in r.rand_int(3) + 1 {
            bent[r.rand_int(bent.len)] ^= (r.rand_int(255) + 1) as! u8;
        }
        var out: u8[>..] = [];
        out.append("keep");
        let status = deflate::decompress(d, out, bent, f);
        if status != deflate::SUCCESS {
            if !same(out, "keep") { wrong++; }
        } else {
            if f == deflate::Format.Zlib && bent[0] == packed[0] && bent[1] == packed[1] && !same(out[4..], data) {
                wrong++;
            }
        }

        // Pure noise as the input.
        var junk: u8[>..] = [];
        noise(junk, r.rand_int(2000), r.rand_u64());
        var o2: u8[>..] = [];
        o2.append("keep");
        if deflate::decompress(d, o2, junk, f) != deflate::SUCCESS && !same(o2, "keep") { wrong++; }
    }
    deflate::close(d);
    check(wrong == 0, "damaged streams fail cleanly or decode correctly");
}

// --- buffers you provide --------------------------------------------------------

fn test_into() {
    var data: u8[>..] = [];
    text(data, 60000, 60);

    for f in FORMATS {
        var c = deflate::compressor(6);
        var d = deflate::decompressor();
        let bound = deflate::compress_bound(c, data.len, f);

        // The same bytes as the appending call gives.
        var buf: u8[>..] = [];
        buf.resize(bound, 0);
        let n = deflate::compress_into(c, buf, data, f);
        var appended: u8[>..] = [];
        deflate::compress(c, appended, data, f);
        check(n > 0 && same(buf[..n], appended), str(format_name(f), ": compress_into"));

        // A buffer that is too small gives 0, one byte short included.
        var small: u8[>..] = [];
        small.resize(n - 1, 0);
        check(deflate::compress_into(c, small, data, f) == 0, str(format_name(f), ": one byte short"));
        small.resize(n, 0);
        check(deflate::compress_into(c, small, data, f) == n, str(format_name(f), ": exactly enough"));

        // Decompressing into a buffer bigger than needed, exact, and too small.
        var out: u8[>..] = [];
        out.resize(data.len + 100, 0);
        var info = deflate::Info { 0, 0 };
        check(deflate::decompress_into(d, out, appended, f, info) == deflate::SUCCESS, "decompress_into");
        check(info.out_nbytes == data.len && same(out[..info.out_nbytes], data), "decompress_into: result");
        check(info.in_nbytes == appended.len, "decompress_into: info.in_nbytes");
        out.resize(data.len);
        check(deflate::decompress_into(d, out, appended, f, info) == deflate::SUCCESS, "exactly enough room");
        out.resize(data.len - 1);
        check(deflate::decompress_into(d, out, appended, f, info) == deflate::INSUFFICIENT_SPACE,
              "one byte short of room");

        // The buffers can be used again.
        for i in 5 {
            var more: u8[>..] = [];
            text(more, 1000 * (i + 1), 70 + i as! u64);
            var big: u8[>..] = [];
            big.resize(deflate::compress_bound(c, more.len, f), 0);
            let m = deflate::compress_into(c, big, more, f);
            var back: u8[>..] = [];
            back.resize(more.len, 0);
            check(deflate::decompress_into(d, back, big[..m], f, info) == deflate::SUCCESS && same(back, more),
                  "reused buffers");
        }
        deflate::close(c);
        deflate::close(d);
    }
}

fn test_misc() {
    let major, minor = deflate::native_version();
    check(major == deflate::VERSION_MAJOR && minor == deflate::VERSION_MINOR,
          "the C layer is the version the module says");
    check(deflate::status_name(deflate::BAD_DATA) == "bad data", "status_name");
}

fn main() {
    test_checksums();
    test_known_streams();
    test_roundtrips();
    test_sizes();
    test_levels_differ();
    test_appending();
    test_reuse();
    test_bad_data();
    test_limits();
    test_trailing_and_concatenated();
    test_format_details();
    test_trailers();
    test_deterministic();
    test_offsets();
    test_zero_max_size();
    test_info_on_failure();
    test_into();
    test_large();
    test_random_roundtrips();
    test_random_damage();
    test_misc();
    if failures > 0 {
        print(failures, " of ", checks, " checks FAILED");
        exit(1);
    }
    print("all ", checks, " checks passed");
}
