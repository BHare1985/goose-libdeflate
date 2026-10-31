// A command-line front end to the package, for the interoperability test
// (test/interop.sh):
//
//     tool compress|decompress deflate|zlib|gzip level input output
//     tool checksum - - input output     (writes "<crc32> <adler32>")

import deflate from "..";
import std;
import os;

fn main() {
    let a = args();
    if a.len != 6 { write_stderr("usage: tool compress|decompress|checksum deflate|zlib|gzip level in out\n"); exit(2); }
    var fmt = deflate::Format.Gzip;
    if a[2] == "deflate" { fmt = deflate::Format.Deflate; }
    if a[2] == "zlib" { fmt = deflate::Format.Zlib; }
    let level, level_ok = parse_int(a[3]);
    if a[1] == "compress" && (!level_ok || level < 0 || level > 12) { write_stderr("bad level\n"); exit(2); }
    var input: u8[>..] = [];
    if !read_file(a[4], input) { write_stderr("cannot read input\n"); exit(2); }
    var output: u8[>..] = [];
    if a[1] == "checksum" {
        format(output, deflate::crc32(input), " ", deflate::adler32(input));
    } else if a[1] == "compress" {
        deflate::compress(output, input, fmt, level as! i32);
    } else {
        let status = deflate::decompress(output, input, fmt);
        if status != deflate::SUCCESS {
            write_stderr(str("decompress failed: ", deflate::status_name(status), "\n"));
            exit(1);
        }
    }
    if !write_file(a[5], output) { write_stderr("cannot write output\n"); exit(2); }
}
