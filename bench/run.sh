#!/bin/bash
#
# Fetches the corpus, builds bench.goose, runs it and writes bench/RESULTS.md.
# It takes a few minutes, and the machine should be otherwise idle.
#
# Needs a C compiler and zlib's headers (zlib1g-dev, zlib-devel, brew install
# zlib).
#
# Usage: bench/run.sh
# Environment: GOOSE is the goose binary to use (default: goose).

set -eu -o pipefail
cd "$(dirname "$0")"

: "${GOOSE:=goose}"
./fetch_corpus.sh

work=$(mktemp -d -t goose_libdeflate_bench.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
"$GOOSE" build -O2 -o "$work/bench" bench.goose >/dev/null

cpu=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | sed 's/.*: //' || true)
[ -n "$cpu" ] || cpu=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m)
zlib=$(sed -n 's/^#define ZLIB_VERSION "\(.*\)"/\1/p' "$(echo '#include <zlib.h>' | cc -E -x c - | sed -n 's/^# [0-9]* "\(.*zlib.h\)".*/\1/p' | head -1)")
cc=$(cc --version | head -1)

{
	echo "# Benchmark results"
	echo
	echo "Made with \`bench/run.sh\`. libdeflate $(sed -n 's/^let VERSION_MAJOR = \(.*\);/\1/p' ../deflate.goose).$(sed -n 's/^let VERSION_MINOR = \(.*\);/\1/p' ../deflate.goose) against zlib $zlib."
	echo
	echo "- CPU: $cpu"
	echo "- OS: $(uname -sr)"
	echo "- C compiler: $cc"
	echo "- Goose: $("$GOOSE" version 2>&1 | head -1)"
	echo "- Corpus: Calgary and Canterbury, $(find data -type f | wc -l) files, $(cat data/calgary/* data/canterbury/* | wc -c) bytes"
	echo
	"$work/bench" data/calgary data/canterbury
} > RESULTS.md
echo "wrote $(pwd)/RESULTS.md"
