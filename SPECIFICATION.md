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

This script (modified from Rustup) has the following options:

```
USAGE:
    ocamlup-init [FLAGS] [OPTIONS]

FLAGS:
    -v, --verbose           Enable verbose output
    -q, --quiet             Disable progress output
    -y                      Disable confirmation prompt.
        --no-modify-path    Don't configure the PATH environment variable
    -h, --help              Prints help information
    -V, --version           Prints version information

OPTIONS:
        --default-switch <default-switch      >    Choose a default switch to install
        --default-toolchain none                   Do not install any toolchains
    -c, --component <components>...                Component name to also install
```

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

4. Release relocation patches for 4.04.2 and 5.0.0

5. Release opam-bin.1.2.0 with fix for log

6. Release drom with fix for ocamlformat




## Known bugs



