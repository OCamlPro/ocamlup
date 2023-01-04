# Changes from opam-bin

This directory is here to avoid synchronization with opam-repository when
building static executables.

* sync with master commit 6467495e30f88d120f8cd63391cd5a4a97468d8d of opam-bin

## Changes

* 'tar' command:
  * Add OPAM_BIN_TAR_ARGS env variable to override default arguments
  * Default arguments modified to:
     `--mtime=2020/07/13 --group=1000 --owner=1000`
    from:
     `--mtime=2020/07/13 --group=user:1000 --owner=user:1000`

