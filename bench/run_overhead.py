#!/usr/bin/env python3
"""Compare Goose calls with direct C libdeflate calls in one executable."""
import argparse
import json
import os
from pathlib import Path
import platform
import random
import shutil
import statistics
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def dataset(size: int, kind: str) -> bytes:
    rng = random.Random(173)
    if kind == "random":
        return rng.randbytes(size)
    # Synthetic read-like bytes; not a BAM file or a biological benchmark.
    out = bytearray()
    while len(out) < size:
        out.extend(f"read:{len(out)}\0chr17\t".encode())
        out.extend(rng.choices(b"ACGT", k=150))
        out.extend(rng.choices(b"IIIIIIIIIIIIII!5?", k=150))
    return bytes(out[:size])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cc", nargs="+", default=["cc"])
    parser.add_argument("--rounds", type=int, default=7)
    parser.add_argument("--seconds", type=float, default=0.05,
                        help="target time per sample")
    parser.add_argument("--sizes", type=int, nargs="+",
                        default=[64, 4096, 65536, 1048576])
    parser.add_argument("--output", type=Path, default=ROOT / "bench/overhead_results.json")
    args = parser.parse_args()
    if args.rounds < 1 or args.seconds <= 0 or any(size <= 0 for size in args.sizes):
        parser.error("rounds, seconds, and sizes must be positive")
    if os.name == "nt":
        parser.error("the standalone C linker flags currently target Unix-like systems")

    goose = os.environ.get("GOOSE", "goose")
    report = {
        "platform": platform.platform(),
        "processor": platform.processor(),
        "goose": subprocess.check_output([goose, "version"], text=True).strip(),
        "native_compilers": [],
        "goose_frontend_flags": ["-O2"],
        "native_application_flags": ["-O3"],
        "libdeflate": "1.26, static, built with -O3 -DNDEBUG",
        "rounds": args.rounds,
        "target_sample_seconds": args.seconds,
        "results": [],
    }

    formats = ((0, "raw"), (1, "zlib"), (2, "gzip"))
    with tempfile.TemporaryDirectory(prefix="goose-libdeflate-overhead-") as temp:
        temp_dir = Path(temp)
        generated_c = temp_dir / "overhead.c"
        # Goose frontend inlining is fixed at -O2; the C compiler below uses -O3
        # for both the Goose wrapper and direct C loop in the same translation unit.
        subprocess.run([goose, "-o", str(generated_c), "--standalone", "-O2",
                        str(ROOT / "bench/overhead.goose")], cwd=ROOT, check=True)

        for compiler_index, cc in enumerate(args.cc):
            cc_path = shutil.which(cc) or cc
            build_dir = temp_dir / f"codec-{compiler_index}"
            subprocess.run([
                "cmake", "-S", str(ROOT / "vendor/libdeflate"), "-B", str(build_dir),
                "-DCMAKE_BUILD_TYPE=Release", f"-DCMAKE_C_COMPILER={cc_path}",
                "-DCMAKE_C_FLAGS_RELEASE=-O3 -DNDEBUG",
                "-DLIBDEFLATE_BUILD_STATIC_LIB=ON",
                "-DLIBDEFLATE_BUILD_SHARED_LIB=OFF",
                "-DLIBDEFLATE_BUILD_GZIP=OFF",
                "-DLIBDEFLATE_BUILD_TESTS=OFF",
                "-DLIBDEFLATE_INSTALL=OFF",
            ], check=True, stdout=subprocess.DEVNULL)
            subprocess.run(["cmake", "--build", str(build_dir), "--target",
                            "libdeflate_static", "--parallel"], check=True,
                           stdout=subprocess.DEVNULL)
            archives = list(build_dir.rglob("libdeflate.a"))
            if len(archives) != 1:
                raise RuntimeError(f"expected one libdeflate.a in {build_dir}, found {archives}")
            exe = temp_dir / f"overhead-{compiler_index}"
            link_flags = ["-lm", "-pthread"]
            if platform.system() == "Linux":
                link_flags.append("-ldl")
            subprocess.run([cc_path, "-O3", "-Wno-attributes", "-I", str(ROOT / "bench"),
                            str(generated_c), str(archives[0]), *link_flags,
                            "-o", str(exe)], check=True)
            compiler_name = subprocess.check_output([cc_path, "--version"], text=True).splitlines()[0]
            report["native_compilers"].append(compiler_name)

            def sample(mode: str, fmt: int, operation: int, iterations: int) -> tuple[int, int]:
                output = subprocess.check_output(
                    [str(exe), mode, str(fmt), str(operation), str(iterations)],
                    cwd=temp_dir, text=True)
                elapsed_ns, checksum = map(int, output.split())
                return elapsed_ns, checksum

            for size in args.sizes:
                for kind in ("read-like", "random"):
                    (temp_dir / "input").write_bytes(dataset(size, kind))
                    cases = [(fmt, name, op, opname)
                             for fmt, name in formats
                             for op, opname in ((0, "compress"), (1, "decompress"))]
                    cases.extend(((0, "raw", 2, "crc32"), (0, "raw", 3, "adler32")))
                    for fmt, format_name, operation, opname in cases:
                        probe_ns, _ = sample("c", fmt, operation, 100)
                        ns_per_call = max(1.0, probe_ns / 100.0)
                        iterations = max(10, min(1_000_000,
                            int(args.seconds * 1e9 / ns_per_call)))
                        times: dict[str, list[float]] = {"goose": [], "c": []}
                        for round_index in range(args.rounds):
                            order = ("goose", "c") if round_index % 2 == 0 else ("c", "goose")
                            checksums = []
                            for mode in order:
                                elapsed_ns, checksum = sample(mode, fmt, operation, iterations)
                                times[mode].append(elapsed_ns / iterations)
                                checksums.append(checksum)
                            assert checksums[0] == checksums[1], (cc, size, kind, format_name, opname)
                        goose_ns = statistics.median(times["goose"])
                        c_ns = statistics.median(times["c"])
                        ratio = goose_ns / c_ns
                        row = {
                            "compiler": compiler_name,
                            "cc": cc,
                            "size": size,
                            "data": kind,
                            "format": format_name,
                            "operation": opname,
                            "iterations": iterations,
                            "goose_ns": goose_ns,
                            "direct_c_ns": c_ns,
                            "ratio": ratio,
                        }
                        report["results"].append(row)
                        print(f"{cc:8} {size:7} {kind:8} {format_name:4} {opname:10} "
                              f"Goose/C {ratio:.3f} ({goose_ns:.1f}/{c_ns:.1f} ns)", flush=True)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {args.output}")


if __name__ == "__main__":
    main()
