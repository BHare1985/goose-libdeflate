# Benchmark results

Made with `bench/run.sh`. libdeflate 1.26 against zlib 1.3.1.

- CPU: AMD Ryzen 5 3550H with Radeon Vega Mobile Gfx
- OS: Linux 7.0.0-42-generic
- C compiler: cc (Ubuntu 15.2.0-16ubuntu1) 15.2.0
- Goose: goose v2026.4 (runtime dce889723a23)
- Corpus: Calgary and Canterbury, 29 files, 6040451 bytes

### Whole corpus, by level

| level | zlib compress MB/s | libdeflate compress MB/s | speedup | zlib size | libdeflate size | zlib decompress MB/s | libdeflate decompress MB/s | speedup |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 101 | 219 | 2.2x | 2096447 | 1933410 | 329 | 849 | 2.6x |
| 3 | 65 | 122 | 1.9x | 1953377 | 1830168 | 355 | 1031 | 2.9x |
| 6 | 26 | 78 | 3.0x | 1793911 | 1778655 | 340 | 918 | 2.7x |
| 9 | 8 | 24 | 3.1x | 1783714 | 1739806 | 344 | 937 | 2.7x |
| 12 | n/a | 5 | n/a | n/a | 1688514 | n/a | 938 | n/a |

### Each file, level 6

| file | size [KiB] | zlib compress [us] | libdeflate compress [us] | speedup | zlib decompress [us] | libdeflate decompress [us] | speedup |
|---|---:|---:|---:|---:|---:|---:|---:|
| bib | 108 | 4102 | 1611 | 2.5 | 364 | 116 | 3.1 |
| book1 | 750 | 43137 | 13978 | 3.1 | 2901 | 1035 | 2.8 |
| book2 | 596 | 26394 | 9204 | 2.9 | 2051 | 668 | 3.1 |
| geo | 100 | 10698 | 1428 | 7.5 | 511 | 228 | 2.2 |
| news | 368 | 13616 | 5305 | 2.6 | 1419 | 519 | 2.7 |
| obj1 | 21 | 547 | 217 | 2.5 | 84.5 | 34.2 | 2.5 |
| obj2 | 241 | 9647 | 2848 | 3.4 | 842 | 289 | 2.9 |
| paper1 | 51 | 1755 | 721 | 2.4 | 177 | 58.6 | 3.0 |
| paper2 | 80 | 3456 | 1270 | 2.7 | 282 | 92.6 | 3.0 |
| paper3 | 45 | 1760 | 697 | 2.5 | 165 | 56.5 | 2.9 |
| paper4 | 12 | 331 | 153 | 2.2 | 48.1 | 18.6 | 2.6 |
| paper5 | 11 | 275 | 133 | 2.1 | 42.8 | 17.3 | 2.5 |
| paper6 | 37 | 1140 | 486 | 2.3 | 127 | 42.6 | 3.0 |
| pic | 501 | 9262 | 3950 | 2.3 | 966 | 262 | 3.7 |
| progc | 38 | 1154 | 492 | 2.3 | 128 | 42.5 | 3.0 |
| progl | 69 | 1949 | 783 | 2.5 | 176 | 52.4 | 3.3 |
| progp | 48 | 1134 | 471 | 2.4 | 119 | 36.8 | 3.2 |
| trans | 91 | 1936 | 837 | 2.3 | 207 | 63.4 | 3.3 |
| alice29.txt | 145 | 7104 | 2417 | 2.9 | 507 | 168 | 3.0 |
| asyoulik.txt | 122 | 6509 | 2116 | 3.1 | 454 | 159 | 2.9 |
| cp.html | 24 | 537 | 268 | 2.0 | 75.3 | 26.0 | 2.9 |
| fields.c | 10 | 213 | 105 | 2.0 | 28.9 | 11.2 | 2.6 |
| grammar.lsp | 3 | 64.2 | 34.0 | 1.9 | 11.5 | 5.6 | 2.1 |
| kennedy.xls | 1005 | 29054 | 8361 | 3.5 | 1828 | 1172 | 1.6 |
| lcet10.txt | 409 | 19132 | 6427 | 3.0 | 1390 | 451 | 3.1 |
| plrabn12.txt | 460 | 28765 | 8730 | 3.3 | 1760 | 635 | 2.8 |
| ptt5 | 501 | 9234 | 3956 | 2.3 | 965 | 262 | 3.7 |
| sum | 37 | 1447 | 397 | 3.6 | 121 | 48.1 | 2.5 |
| xargs.1 | 4 | 76.4 | 40.0 | 1.9 | 14.5 | 6.9 | 2.1 |

### Checksums

| checksum | zlib GB/s | libdeflate GB/s | speedup |
|---|---:|---:|---:|
| CRC-32 | 4.3 | 12.3 | 2.9x |
| Adler-32 | 3.0 | 15.2 | 5.1x |

