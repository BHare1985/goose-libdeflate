// Decompresses a gzip file, the way gzip -dc does.
//
// A gzip file ends with the size of the original data (modulo 2^32). Knowing
// the size is what lets libdeflate decompress fastest: it gets one buffer of
// the right size and one pass. The size is wrong for a file of several gzip
// members, or of 4 GiB or more, so then this falls back to decompress, which
// finds the size by trying.
//
//     goose examples/gz_decompress.goose -- input.gz output

import deflate from "..";
import std;
import os;

fn main() {
    let a = args();
    if a.len != 3 { write_stderr("usage: gz_decompress input.gz output\n"); exit(2); }

    var packed: u8[>..] = [];
    if !read_file(a[1], packed) { write_stderr("cannot read the input\n"); exit(1); }
    if packed.len < 18 { write_stderr("too short to be a gzip file\n"); exit(1); }

    // The last four bytes, little endian.
    let t = packed[packed.len - 4..];
    let size = t[0] | (t[1] as i64) << 8 | (t[2] as i64) << 16 | (t[3] as i64) << 24;

    let d, opened = deflate::decompressor();
    guard opened else {
        write_stderr(str("decompressor allocation failed: ", deflate::error(), "\n"));
        exit(1);
    }
    defer deflate::close(d);
    var plain: u8[>..] = [];
    var info = deflate::Info { 0, 0 };
    var ok = deflate::decompress_exact(d, plain, packed, deflate::Format.Gzip, size, info);
    if !ok && (deflate::status() == deflate::Status.ShortOutput ||
               deflate::status() == deflate::Status.InsufficientSpace) {
        ok = deflate::decompress(d, plain, packed, deflate::Format.Gzip, info);
    }
    guard ok else {
        write_stderr(str("not a good gzip file: ", deflate::error(), "\n"));
        exit(1);
    }
    if !write_file(a[2], plain) { write_stderr("cannot write the output\n"); exit(1); }
    print(packed.len, " -> ", plain.len, " bytes");
}
