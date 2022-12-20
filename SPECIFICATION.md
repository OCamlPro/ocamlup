# Specification of ocamlup

`ocamlup` is a tool to easily install OCaml on a raw computer, by
downloading binaries when possible.

## Usage

### Initial installation

The user should simply use:

```
curl --proto '=https' --tlsv1.2 -sSf https://ocamlup.ocaml-lang.org/ocamlup-shell.sh | sh
```

This command will download the `ocamlup-shell.sh` script and run it.

It will detect the architecture and download the corresponding
`ocamlup-init` binary.

For example:

```
https://ocamlup.ocaml-lang.org/dist/x86_64-unknown-linux-gnu/ocamlup-init
```

and then run `ocamlup-init` with the same options as given to the
download script.

## Behavior of `ocamlup-init`

This tool performs the following steps:

* Create $HOME/.ocamlup/bin
* Promote itself as `ocamlup-init`, `opam`, `ocp-indent` and `drom` in $HOME/.ocamlup/bin
* Create a file $HOME/.ocamlup/env with the following content:

```
#!/bin/sh
# ocamlup shell setup
# affix colons on either side of $PATH to simplify matching
case ":${PATH}:" in
    *:"$HOME/.ocamlup/bin":*)
        ;;
    *)
        # Prepending path in case a system-installed opam needs to be overridden
        export PATH="$HOME/.ocamlup/bin:$PATH"
        ;;
esac
```

* Promote other tools as hardlink to itself in
$HOME/.ocamlup/bin. Call `opam exec -- ARGS` when called, checking an
env variable OCAMLUP_INSIDE to avoid infinite loops in call

* Configure opam with no compiler

$ opam init --bare -n

* Install opam-bin

$ opam-bin install

* Detect environment and setup opam-bin configuration to a
  corresponding binary repository

* Create a first switch in opam with the latest compiler available

base-bigarray.base
base-threads.base
base-unix.base
cache
ocaml.4.14.0
ocaml-base-compiler.4.14.0
ocaml-config.2
ocaml-options-vanilla.1

* Configure drom (install its skeleton files)

## Roadmap

1. Publish a repository of compiler binary artefacts on
   ocamlup.ocaml-lang.org/ for arch x86_64-unknown-linux-gnu

BASE:
https://ocamlup.ocaml-lang.org/dist/x86_64-unknown-linux-gnu/

CONTENT:
  ocamlup-init
  archives/
    <ARCHIVES>
  repo/
    <...>

2. New website pour ocamlup.ocaml-lang.org

3. Get architecture from OCaml, checkout binary repository

opam remote add ocamlup https://ocamlup.ocaml-lang.org/dist/x86_64-unknown-linux-gnu/repo --all --set-default

4. Release relocation patches for 4.04.2 and 5.0.0

5. Release opam-bin.1.2.0 with fix for log

6. Release drom with fix for ocamlformat

7. Patch ocaml-4.14.0 and ocaml-5.00.0 to decrease the binary size of their archive
   7.1 share binaries in bin/
   7.2 remove .cmt when .cmti is available

2022/12/19:18:08:24: Could not find cached binary package ocaml-base-compiler.4.13.1+bin+efcd71d2+


## Working features

* Tested on  `x86_64-unknown-linux-gnu` (Linux Ubuntu 22)
  * Binary versions for OCaml between 4.02.0 and 5.0.0
* Features:
  * `opam` working correctly, no modification
  * `opam-bin` working correctly, no modification
  * `ocp-indent` working correctly, but `findlib` support disabled, so no plugins
  * `drom` working correctly, shared files in `.ocamlup/share/drom`

## Known bugs

* Currently, arch is always detected as `x86_64-unknown-linux-gnu`


