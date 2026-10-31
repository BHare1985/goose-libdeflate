# vendor

`libdeflate/` is [libdeflate](https://github.com/ebiggers/libdeflate) 1.26 by
Eric Biggers, unmodified. It is the output of `git archive v1.26` in the
upstream repository, which is commit `92e6a0db9fa848d742f9eb286c92afc60f2c3dda`.
Its license is in `libdeflate/COPYING` (MIT) and must stay with the code.

To check it, export that tag and diff it against this directory.

To move to a newer release, replace the directory with that release's
`git archive`, change `VERSION_MAJOR` and `VERSION_MINOR` in `deflate.goose`,
and run `test/run_tests.sh`.
