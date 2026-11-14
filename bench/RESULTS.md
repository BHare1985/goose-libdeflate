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
| 1 | 101 | 209 | 2.1x | 2096447 | 1933410 | 329 | 845 | 2.6x |
| 3 | 65 | 120 | 1.8x | 1953377 | 1830168 | 357 | 1028 | 2.9x |
| 6 | 26 | 78 | 3.0x | 1793911 | 1778655 | 340 | 916 | 2.7x |
| 9 | 8 | 24 | 3.1x | 1783714 | 1739806 | 345 | 932 | 2.7x |
| 12 | n/a | 5 | n/a | n/a | 1688514 | n/a | 934 | n/a |

### Each file, level 6

| file | size [KiB] | zlib compress [us] | libdeflate compress [us] | speedup | zlib decompress [us] | libdeflate decompress [us] | speedup |
|---|---:|---:|---:|---:|---:|---:|---:|
| bib | 108 | 4251 | 1472 | 2.9 | 364 | 119 | 3.1 |
| book1 | 750 | 42685 | 13816 | 3.1 | 2896 | 1033 | 2.8 |
| book2 | 596 | 25856 | 9179 | 2.8 | 2049 | 672 | 3.0 |
| geo | 100 | 10728 | 1419 | 7.6 | 511 | 232 | 2.2 |
| news | 368 | 13650 | 5607 | 2.4 | 1418 | 524 | 2.7 |
| obj1 | 21 | 546 | 217 | 2.5 | 84.7 | 34.3 | 2.5 |
| obj2 | 241 | 9630 | 2834 | 3.4 | 842 | 292 | 2.9 |
| paper1 | 51 | 1755 | 719 | 2.4 | 176 | 58.5 | 3.0 |
| paper2 | 80 | 3472 | 1264 | 2.7 | 280 | 93.1 | 3.0 |
| paper3 | 45 | 1762 | 685 | 2.6 | 166 | 56.7 | 2.9 |
| paper4 | 12 | 329 | 154 | 2.1 | 47.7 | 18.5 | 2.6 |
| paper5 | 11 | 277 | 133 | 2.1 | 43.0 | 17.2 | 2.5 |
| paper6 | 37 | 1137 | 486 | 2.3 | 127 | 42.6 | 3.0 |
| pic | 501 | 9283 | 3938 | 2.4 | 965 | 262 | 3.7 |
| progc | 38 | 1158 | 531 | 2.2 | 129 | 42.6 | 3.0 |
| progl | 69 | 1957 | 755 | 2.6 | 176 | 52.1 | 3.4 |
| progp | 48 | 1134 | 468 | 2.4 | 118 | 36.9 | 3.2 |
| trans | 91 | 1931 | 833 | 2.3 | 207 | 63.5 | 3.3 |
| alice29.txt | 145 | 7039 | 2394 | 2.9 | 509 | 173 | 2.9 |
| asyoulik.txt | 122 | 6511 | 2108 | 3.1 | 453 | 162 | 2.8 |
| cp.html | 24 | 539 | 239 | 2.3 | 75.5 | 26.0 | 2.9 |
| fields.c | 10 | 214 | 104 | 2.1 | 28.8 | 11.2 | 2.6 |
| grammar.lsp | 3 | 65.0 | 34.0 | 1.9 | 11.6 | 5.6 | 2.1 |
| kennedy.xls | 1005 | 29203 | 8325 | 3.5 | 1825 | 1162 | 1.6 |
| lcet10.txt | 409 | 19113 | 6806 | 2.8 | 1389 | 453 | 3.1 |
| plrabn12.txt | 460 | 28809 | 8690 | 3.3 | 1761 | 634 | 2.8 |
| ptt5 | 501 | 9252 | 3937 | 2.4 | 964 | 262 | 3.7 |
| sum | 37 | 1456 | 394 | 3.7 | 121 | 48.1 | 2.5 |
| xargs.1 | 4 | 75.9 | 39.9 | 1.9 | 14.7 | 7.0 | 2.1 |

### Checksums

| checksum | zlib GB/s | libdeflate GB/s | speedup |
|---|---:|---:|---:|
| CRC-32 | 4.3 | 12.0 | 2.8x |
| Adler-32 | 3.0 | 14.7 | 4.9x |

