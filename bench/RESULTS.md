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
| 1 | 101 | 218 | 2.2x | 2096447 | 1933410 | 328 | 847 | 2.6x |
| 3 | 65 | 125 | 1.9x | 1953377 | 1830168 | 357 | 1030 | 2.9x |
| 6 | 26 | 78 | 3.0x | 1793911 | 1778655 | 340 | 919 | 2.7x |
| 9 | 8 | 24 | 3.1x | 1783714 | 1739806 | 345 | 937 | 2.7x |
| 12 | n/a | 5 | n/a | n/a | 1688514 | n/a | 939 | n/a |

### Each file, level 6

| file | size [KiB] | zlib compress [us] | libdeflate compress [us] | speedup | zlib decompress [us] | libdeflate decompress [us] | speedup |
|---|---:|---:|---:|---:|---:|---:|---:|
| bib | 108 | 4091 | 1479 | 2.8 | 364 | 116 | 3.1 |
| book1 | 750 | 42564 | 14024 | 3.0 | 2907 | 1033 | 2.8 |
| book2 | 596 | 25938 | 9316 | 2.8 | 2049 | 667 | 3.1 |
| geo | 100 | 10734 | 1427 | 7.5 | 513 | 229 | 2.2 |
| news | 368 | 13651 | 5340 | 2.6 | 1422 | 522 | 2.7 |
| obj1 | 21 | 546 | 216 | 2.5 | 84.9 | 34.8 | 2.4 |
| obj2 | 241 | 9616 | 2861 | 3.4 | 846 | 289 | 2.9 |
| paper1 | 51 | 1753 | 719 | 2.4 | 177 | 58.7 | 3.0 |
| paper2 | 80 | 3469 | 1345 | 2.6 | 282 | 93.2 | 3.0 |
| paper3 | 45 | 1764 | 687 | 2.6 | 166 | 57.2 | 2.9 |
| paper4 | 12 | 330 | 154 | 2.1 | 47.9 | 18.7 | 2.6 |
| paper5 | 11 | 274 | 132 | 2.1 | 43.4 | 17.2 | 2.5 |
| paper6 | 37 | 1131 | 520 | 2.2 | 127 | 42.9 | 2.9 |
| pic | 501 | 9249 | 3950 | 2.3 | 968 | 262 | 3.7 |
| progc | 38 | 1148 | 494 | 2.3 | 129 | 42.7 | 3.0 |
| progl | 69 | 1946 | 803 | 2.4 | 176 | 52.3 | 3.4 |
| progp | 48 | 1134 | 468 | 2.4 | 120 | 37.1 | 3.2 |
| trans | 91 | 1917 | 832 | 2.3 | 208 | 62.9 | 3.3 |
| alice29.txt | 145 | 7059 | 2422 | 2.9 | 508 | 168 | 3.0 |
| asyoulik.txt | 122 | 6502 | 2144 | 3.0 | 454 | 158 | 2.9 |
| cp.html | 24 | 536 | 239 | 2.2 | 75.1 | 26.0 | 2.9 |
| fields.c | 10 | 213 | 270 | 0.8 | 28.9 | 11.2 | 2.6 |
| grammar.lsp | 3 | 64.3 | 33.9 | 1.9 | 11.5 | 5.6 | 2.1 |
| kennedy.xls | 1005 | 29014 | 8308 | 3.5 | 1828 | 1161 | 1.6 |
| lcet10.txt | 409 | 19115 | 6436 | 3.0 | 1390 | 455 | 3.1 |
| plrabn12.txt | 460 | 28776 | 8747 | 3.3 | 1758 | 632 | 2.8 |
| ptt5 | 501 | 9239 | 3945 | 2.3 | 965 | 263 | 3.7 |
| sum | 37 | 1445 | 393 | 3.7 | 121 | 48.3 | 2.5 |
| xargs.1 | 4 | 75.5 | 40.0 | 1.9 | 14.6 | 6.9 | 2.1 |

### Checksums

| checksum | zlib GB/s | libdeflate GB/s | speedup |
|---|---:|---:|---:|
| CRC-32 | 4.3 | 12.3 | 2.8x |
| Adler-32 | 3.0 | 15.1 | 5.0x |

