#!/bin/bash
#
# Interoperability test: streams the package writes must be read by zlib and
# gzip, and streams they write must be read by the package.
#
# Usage: test/interop.sh
# Environment: GOOSE is the goose binary to use (default: goose).

set -eu -o pipefail
cd "$(dirname "$0")/.."

: "${GOOSE:=goose}"
work=$(mktemp -d -t goose_libdeflate_interop.XXXXXXXX)
trap 'rm -rf "$work"' EXIT

"$GOOSE" build -o "$work/tool" test/tool.goose >/dev/null

# Inputs: text, source code, noise, zeros, one byte, nothing.
cat deflate.goose test/*.goose src/*.c vendor/libdeflate/lib/*.c > "$work/in.text"
head -c 300000 /dev/urandom > "$work/in.noise"
head -c 5000000 /dev/zero > "$work/in.zeros"
printf 'x' > "$work/in.one"
: > "$work/in.empty"

# The examples that work on files.
"$GOOSE" build -o "$work/gz_compress" examples/gz_compress.goose >/dev/null
"$GOOSE" build -o "$work/gz_decompress" examples/gz_decompress.goose >/dev/null

fail=0
for name in text noise zeros one empty; do
	in="$work/in.$name"
	for level in 0 1 6 9 12; do
		# The package compresses; the reference decompresses.
		"$work/tool" compress gzip "$level" "$in" "$work/p.gz"
		gzip -dc < "$work/p.gz" | cmp - "$in" || { echo "FAIL: gzip cannot read $name at level $level"; fail=1; }
		"$work/tool" compress zlib "$level" "$in" "$work/p.zlib"
		"$work/tool" compress deflate "$level" "$in" "$work/p.raw"
		python3 -I - "$work/p.zlib" "$work/p.raw" "$in" <<'PY' || { echo "FAIL: zlib cannot read $name at level $level"; fail=1; }
import sys, zlib
zl, raw, orig = (open(p, "rb").read() for p in sys.argv[1:4])
assert zlib.decompress(zl) == orig, "zlib stream"
assert zlib.decompress(raw, -15) == orig, "raw deflate stream"
PY
	done
	"$work/gz_compress" "$in" "$work/ex.gz" 6 >/dev/null
	gzip -dc < "$work/ex.gz" | cmp - "$in" || { echo "FAIL: gz_compress example on $name"; fail=1; }
	gzip -6 -c < "$in" > "$work/ex2.gz"
	"$work/gz_decompress" "$work/ex2.gz" "$work/ex.out" >/dev/null
	cmp "$work/ex.out" "$in" || { echo "FAIL: gz_decompress example on $name"; fail=1; }
	"$work/tool" checksum - - "$in" "$work/sums"
	python3 -I - "$in" "$work/sums" <<'PY' || { echo "FAIL: checksums of $name"; fail=1; }
import sys, zlib
orig = open(sys.argv[1], "rb").read()
got = open(sys.argv[2]).read().split()
assert got == [str(zlib.crc32(orig)), str(zlib.adler32(orig))], got
PY
	for level in 1 6 9; do
		# The reference compresses; the package decompresses.
		gzip -"$level" -c < "$in" > "$work/r.gz"
		"$work/tool" decompress gzip 0 "$work/r.gz" "$work/out"
		cmp "$work/out" "$in" || { echo "FAIL: cannot read gzip's $name at level $level"; fail=1; }
		python3 -I - "$in" "$work/r.zlib" "$work/r.raw" "$level" <<'PY'
import sys, zlib
orig = open(sys.argv[1], "rb").read()
level = int(sys.argv[4])
open(sys.argv[2], "wb").write(zlib.compress(orig, level))
co = zlib.compressobj(level, zlib.DEFLATED, -15)
open(sys.argv[3], "wb").write(co.compress(orig) + co.flush())
PY
		"$work/tool" decompress zlib 0 "$work/r.zlib" "$work/out"
		cmp "$work/out" "$in" || { echo "FAIL: cannot read zlib's $name at level $level"; fail=1; }
		"$work/tool" decompress deflate 0 "$work/r.raw" "$work/out"
		cmp "$work/out" "$in" || { echo "FAIL: cannot read raw deflate of $name at level $level"; fail=1; }
	done
done

if [ "$fail" -ne 0 ]; then
	echo "interop: FAILED"
	exit 1
fi
echo "interop: all passed"
