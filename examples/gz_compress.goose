// Compresses a file to gzip, the way gzip -c does.
//
//     goose examples/gz_compress.goose -- input output.gz [level]

import deflate from "..";
import std;
import os;

fn main() {
    let a = args();
    if a.len < 3 || a.len > 4 {
        write_stderr("usage: gz_compress input output.gz [level]\n");
        exit(2);
    }
    var level = deflate::DEFAULT_LEVEL;
    if a.len == 4 {
        let n, ok = parse_int(a[3]);
        if !ok || n < deflate::MIN_LEVEL || n > deflate::MAX_LEVEL {
            write_stderr("the level is 0 to 12\n");
            exit(2);
        }
        level = n as! i32;
    }

    var data: u8[>..] = [];
    if !read_file(a[1], data) { write_stderr("cannot read the input\n"); exit(1); }

    var packed: u8[>..] = [];
    deflate::compress(packed, data, deflate::Format.Gzip, level);
    if !write_file(a[2], packed) { write_stderr("cannot write the output\n"); exit(1); }
    print(data.len, " -> ", packed.len, " bytes");
}
