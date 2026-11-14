// Compresses a string with each format, shows the sizes, and reads it back.
//
//     goose examples/gzip_roundtrip.goose

import deflate from "..";
import std;

fn main() {
    var data: u8[>..] = [];
    for i in 2000 { format(data, "line ", i, ": the quick brown fox\n"); }

    for level in [1, 6, 12] {
        var packed: u8[>..] = [];
        guard deflate::compress(packed, data, deflate::Format.Gzip, level as! i32) else {
            print("compress failed: ", deflate::error());
            exit(1);
        }

        var plain: u8[>..] = [];
        guard deflate::decompress(plain, packed, deflate::Format.Gzip) else {
            print("level ", level, ": ", deflate::error());
            exit(1);
        }
        let same = plain.len == data.len && deflate::crc32(plain) == deflate::crc32(data);
        print("level ", level, ": ", data.len, " -> ", packed.len, " bytes, round trip ok: ", same);
    }
}
