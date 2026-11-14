# Goose libdeflate package: CMake builds the pinned libdeflate submodule and
# deflate.build supplies the inline header plus TinyCC adapter.
SHELL := /bin/bash

GOOSE ?= goose
ENTRY := deflate.goose
EXAMPLES := $(sort $(wildcard examples/*.goose))

.PHONY: all submodule tools check test interop examples bench overhead verify fmt fmt-check clean

all: check

submodule:
	@git submodule update --init --depth 1 vendor/libdeflate

tools: submodule
	@echo "goose: $(shell command -v $(GOOSE) 2>/dev/null || echo 'NOT FOUND - set GOOSE=/path/to/goose')"
	@$(GOOSE) version
	@echo "C compiler: $$(command -v cc 2>/dev/null || command -v gcc 2>/dev/null || command -v clang 2>/dev/null || echo 'not found')"
	@echo "cmake: $$(command -v cmake 2>/dev/null || echo 'not found - required for libdeflate build')"
	@echo "python3: $$(command -v python3 2>/dev/null || echo 'not found - required for interop/overhead')"
	@echo "gzip: $$(command -v gzip 2>/dev/null || echo 'not found - required for interop')"

check:
	@$(GOOSE) check $(ENTRY)

# This script runs the same assertions in-process, debug-compiled, and optimized.
test: submodule
	@GOOSE="$(GOOSE)" test/run_tests.sh

# Independent readers/writers, checksums and file examples (Python 3 + gzip).
interop: submodule
	@GOOSE="$(GOOSE)" test/interop.sh

examples: check
	@for f in $(EXAMPLES); do echo "== $$f"; $(GOOSE) check "$$f" || exit 1; done

bench: submodule
	@GOOSE="$(GOOSE)" bench/run.sh

overhead: submodule
	@GOOSE="$(GOOSE)" python3 bench/run_overhead.py --cc "$(CC)"

verify: check test interop examples
	@echo "verify: ok"

fmt:
	@$(GOOSE) format $(ENTRY) test examples bench

fmt-check:
	@$(GOOSE) format --check $(ENTRY) test examples bench

clean:
	@rm -rf build
