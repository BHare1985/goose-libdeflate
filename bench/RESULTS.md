# Benchmark results

Made with `bench/run.sh`. libdeflate 1.26 against zlib 1.3.2.

- CPU: Intel(R) Core(TM) i7-7700 CPU @ 3.60GHz
- OS: Linux 6.18.54.1-microsoft-standard-WSL2
- C compiler: cc (Debian 16.2.0-3) 16.2.0
- Goose: goose runtime 4d3da949e563
- Corpus: Calgary and Canterbury, 29 files, 6040451 bytes

### Whole corpus, by level

| level | zlib compress MB/s | libdeflate compress MB/s | speedup | zlib size | libdeflate size | zlib decompress MB/s | libdeflate decompress MB/s | speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 108 | 238 | 2.2x | 2096447 | 1933410 | 354 | 972 | 2.7x |
| 3 | 69 | 124 | 1.8x | 1953377 | 1830168 | 381 | 1120 | 2.9x |
| 6 | 28 | 81 | 2.9x | 1793911 | 1778655 | 369 | 1025 | 2.8x |
| 9 | 9 | 27 | 3.1x | 1783714 | 1739806 | 372 | 1039 | 2.8x |
| 12 | n/a | 5 | n/a | n/a | 1688514 | n/a | 976 | n/a |

### Each file, level 6

| file | size [KiB] | zlib compress [us] | libdeflate compress [us] | speedup | zlib decompress [us] | libdeflate decompress [us] | speedup |
|---|---:|---:|---:|---:|---:|---:|---:|
| bib | 108 | 3715 | 1503 | 2.5 | 335 | 114 | 2.9 |
| book1 | 750 | 39146 | 14467 | 2.7 | 2667 | 927 | 2.9 |
| book2 | 596 | 23929 | 9300 | 2.6 | 1863 | 597 | 3.1 |
| geo | 100 | 10168 | 1347 | 7.5 | 485 | 214 | 2.3 |
| news | 368 | 12780 | 5248 | 2.4 | 1313 | 477 | 2.8 |
| obj1 | 21 | 496 | 208 | 2.4 | 81.0 | 28.9 | 2.8 |
| obj2 | 241 | 9280 | 2774 | 3.3 | 774 | 267 | 2.9 |
| paper1 | 51 | 1593 | 699 | 2.3 | 167 | 52.1 | 3.2 |
| paper2 | 80 | 3191 | 1295 | 2.5 | 270 | 84.1 | 3.2 |
| paper3 | 45 | 1590 | 665 | 2.4 | 158 | 49.9 | 3.2 |
| paper4 | 12 | 303 | 158 | 1.9 | 45.1 | 14.9 | 3.0 |
| paper5 | 11 | 256 | 134 | 1.9 | 40.7 | 13.3 | 3.1 |
| paper6 | 37 | 1012 | 476 | 2.1 | 122 | 37.9 | 3.2 |
| pic | 501 | 8756 | 2521 | 3.5 | 810 | 247 | 3.3 |
| progc | 38 | 1033 | 482 | 2.1 | 125 | 37.1 | 3.4 |
| progl | 69 | 1762 | 738 | 2.4 | 169 | 44.1 | 3.8 |
| progp | 48 | 1001 | 461 | 2.2 | 116 | 31.3 | 3.7 |
| trans | 91 | 1727 | 833 | 2.1 | 210 | 59.2 | 3.6 |
| alice29.txt | 145 | 6455 | 2397 | 2.7 | 481 | 156 | 3.1 |
| asyoulik.txt | 122 | 5907 | 2075 | 2.8 | 414 | 144 | 2.9 |
| cp.html | 24 | 485 | 252 | 1.9 | 73.5 | 21.7 | 3.4 |
| fields.c | 10 | 200 | 101 | 2.0 | 25.2 | 8.8 | 2.9 |
| grammar.lsp | 3 | 54.4 | 27.6 | 2.0 | 8.0 | 4.5 | 1.8 |
| kennedy.xls | 1005 | 26990 | 8315 | 3.2 | 1738 | 985 | 1.8 |
| lcet10.txt | 409 | 17621 | 6475 | 2.7 | 1287 | 410 | 3.1 |
| plrabn12.txt | 460 | 26370 | 8759 | 3.0 | 1634 | 568 | 2.9 |
| ptt5 | 501 | 8657 | 2520 | 3.4 | 824 | 252 | 3.3 |
| sum | 37 | 1356 | 376 | 3.6 | 125 | 41.4 | 3.0 |
| xargs.1 | 4 | 67.8 | 33.4 | 2.0 | 9.7 | 5.5 | 1.8 |

### Checksums

| checksum | zlib GB/s | libdeflate GB/s | speedup |
|---|---:|---:|---:|
| CRC-32 | 3.2 | 13.3 | 4.2x |
| Adler-32 | 2.7 | 10.8 | 3.9x |

