#!/bin/bash
#
# Runs the Goose contract test in-process, as a debug build, and optimized,
# then verifies thread-local error isolation in a native multithreaded program.
# Independent implementations are tested separately by test/interop.sh.
#
# Usage: test/run_tests.sh
# Environment: GOOSE is the goose binary to use (default: goose).

set -eu -o pipefail
cd "$(dirname "$0")/.."

: "${GOOSE:=goose}"
work=$(mktemp -d -t goose_libdeflate_tests.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
suffix=""
if [[ "${OS:-}" == "Windows_NT" ]]; then suffix=".exe"; fi
export GOOSE

run_and_check() {
    label=$1
    shift
    echo "== $label"
    output=$("$@")
    printf '%s\n' "$output"
    grep -q "checks passed" <<< "$output"
}

run_and_check "in-process" "$GOOSE" run test/test_deflate.goose

echo "== debug build"
"$GOOSE" build --debug -o "$work/debug$suffix" test/test_deflate.goose >/dev/null
run_and_check "debug test" "$work/debug$suffix"

echo "== optimized build"
"$GOOSE" build -O2 -o "$work/opt$suffix" test/test_deflate.goose >/dev/null
run_and_check "optimized test" "$work/opt$suffix"

echo "== thread-local status"
"$GOOSE" build --debug -o "$work/status_threads$suffix" test/status_threads.goose >/dev/null
"$work/status_threads$suffix"
