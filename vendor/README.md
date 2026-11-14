# vendor

`libdeflate/` is a git submodule of
[upstream libdeflate](https://github.com/ebiggers/libdeflate), pinned at commit
`92e6a0db9fa848d742f9eb286c92afc60f2c3dda` (tag `v1.26`). The pin is the
superproject's gitlink; `.gitmodules` records the upstream URL. The upstream MIT
license remains in `libdeflate/COPYING`.

Initialize it after a fresh clone with:

```sh
git submodule update --init --depth 1 vendor/libdeflate
```

To review or update the pin, check out the intended upstream tag in this
submodule, verify the resulting commit, then run `make verify` and
`bench/run.sh`. Do not patch upstream sources for binding changes; adapt
`include/deflate.h` or `CMakeLists.txt` instead.
