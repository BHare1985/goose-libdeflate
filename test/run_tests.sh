#!/bin/bash
#
# Runs the package's tests: the Goose test program in-process, then as a
# debug build (the checks that abort on overflow and out-of-range) and an
# optimized one, then the interoperability test against zlib and gzip.
#
# Usage: test/run_tests.sh
# Environment: GOOSE is the goose binary to use (default: goose).

set -eu -o pipefail
cd "$(dirname "$0")/.."

: "${GOOSE:=goose}"
work=$(mktemp -d -t goose_libdeflate_tests.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
export GOOSE

echo "== in-process"
"$GOOSE" test/test_deflate.goose | tail -1 | tee /dev/stderr | grep -q "checks passed"

echo "== debug build"
"$GOOSE" build --debug -o "$work/debug" test/test_deflate.goose >/dev/null
"$work/debug" | tee /dev/stderr | grep -q "checks passed"

echo "== optimized build"
"$GOOSE" build -O2 -o "$work/opt" test/test_deflate.goose >/dev/null
"$work/opt" | tee /dev/stderr | grep -q "checks passed"

echo "== interop"
test/interop.sh
