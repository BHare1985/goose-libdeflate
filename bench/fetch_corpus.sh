#!/bin/bash
#
# Downloads the Calgary and Canterbury corpora into bench/data, the same 29
# files the libdeflater (Rust) benchmarks use. The files come from two GitHub
# repositories that carry copies, pinned by commit, since the corpora's own
# site doesn't answer scripted downloads.
#
# Calgary is the original files. In the Canterbury copy, alice29.txt,
# lcet10.txt and plrabn12.txt are a little smaller than in the official
# archive (the line endings differ), so their numbers aren't comparable with
# other people's on those three files.

set -eu -o pipefail
cd "$(dirname "$0")"

calgary=https://raw.githubusercontent.com/simonis/zlib-bench/29d1927c75a75f5674e5d8778f6d3de6236fa497/data/calgary
canterbury=https://raw.githubusercontent.com/ChrisLomont/CompressionTools/3d179d9a9fc19218d35c55f79249c8c0ccf6580e/Corpus/Cantebury

mkdir -p data/calgary data/canterbury
for f in bib book1 book2 geo news obj1 obj2 paper1 paper2 paper3 paper4 paper5 paper6 pic progc progl progp trans; do
	[ -s "data/calgary/$f" ] || curl -sSfL -o "data/calgary/$f" "$calgary/$f"
done
for f in alice29.txt asyoulik.txt cp.html fields.c grammar.lsp kennedy.xls lcet10.txt plrabn12.txt ptt5 sum xargs.1; do
	[ -s "data/canterbury/$f" ] || curl -sSfL -o "data/canterbury/$f" "$canterbury/$f"
done
echo "corpus in $(pwd)/data"
