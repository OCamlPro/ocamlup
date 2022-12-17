(**************************************************************************)
(*                                                                        *)
(*  Copyright (c) 2022 OCamlPro SAS                                       *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  This file is distributed under the terms of the GNU Lesser General    *)
(*  Public License version 2.1, with the special exception on linking     *)
(*  described in the LICENSE.md file in the root directory.               *)
(*                                                                        *)
(*                                                                        *)
(**************************************************************************)

open Ez_file.V1
open EzFile.OP

let env_content = {|#!/bin/sh
# rustup shell setup
# affix colons on either side of $PATH to simplify matching
case ":${PATH}:" in
    *:"$HOME/.ocamlup/bin":*)
        ;;
    *)
        # Prepending path in case a system-installed opam needs to be overridden
        export PATH="$HOME/.ocamlup/bin:$PATH"
        ;;
esac
|}

let rec mkdir dir =
  if not (Sys.file_exists dir) then
    let parent_dir = Filename.dirname dir in
    mkdir parent_dir;
    EzFile.mkdir dir 0o755

let main () =

  Printf.eprintf "Running ocamlup-init!\n";
  let home_dir = Sys.getenv "HOME" in
  let opam_dir = home_dir // ".ocamlup" in
  let opam_bin_dir = opam_dir // "bin" in

  mkdir opam_bin_dir;
  let bin_content = EzFile.read_file Sys.executable_name in
  let ocamlup_file = opam_bin_dir // "ocamlup" in
  Printf.eprintf "Creating %s\n%!" ocamlup_file;
  if Sys.file_exists ocamlup_file then begin
    Printf.eprintf "Removing %S\n%!" ocamlup_file ;
    Sys.remove ocamlup_file;
  end;
  EzFile.write_file ocamlup_file bin_content;
  Unix.chmod ocamlup_file 0o755;
  List.iter (fun basename ->
      let target_file = opam_bin_dir // basename in
      if Sys.file_exists target_file then begin
        Printf.eprintf "Removing %S\n%!" target_file ;
        Sys.remove target_file;
      end;
      Printf.eprintf "Creating %S\n%!" target_file ;
      Unix.link ocamlup_file target_file;
      Unix.chmod target_file 0o755;
    )
    [
      "ocamlup-init" ;
      "opam" ;
      "opam-bin" ;
      "drom" ;
      "ocp-indent" ;

      (* promotions of ocaml tools *)
      "ocaml" ;
      "ocamlc" ;
      "ocamlcp" ;
      "ocamldebug" ;
      "ocamldep" ;
      "ocaml-instr-graph" ;
      "ocaml-instr-report" ;
      "ocamllex" ;
      "ocamlyacc" ;
      "ocamlmklib" ;
      "ocamlmktop" ;
      "ocamlobjinfo" ;
      "ocamlopt" ;
      "ocamlprof" ;
      "ocamlrun" ;
      "ocamlrund" ;
      "ocamlruni" ;
      "ocamlyacc" ;

      (* promotions of community tools *)
      "merlin" ;
      "dune" ;
      "ocp-index" ;
      "menhir" ;
    ];


  let env_file = opam_dir // "env" in
  Printf.eprintf "Creating %s\n%!" env_file;
  EzFile.write_file env_file env_content;
  Unix.chmod env_file 0o755;

  let shell_line = {|. "$HOME/.ocamlup/env"|} in
  List.iter (fun basename ->
      let shell_file = home_dir // basename in
      if Sys.file_exists shell_file then
        let has_line = ref false in
        EzFile.iter_lines (fun line ->
            if line = shell_line then has_line := true
          ) shell_file ;
        if not !has_line then begin
          let shell_content = EzFile.read_file shell_file in
          let shell_content = Printf.sprintf "%s\n%s\n" shell_content shell_line in
          EzFile.write_file shell_file shell_content;
          Unix.chmod shell_file 0o755;
        end;
      else begin
        EzFile.write_file shell_file (shell_line^ "\n");
        Unix.chmod shell_file 0o755;
      end
    )
    [
      ".bashrc" ;
      ".profile" ;
      ".zshrc" ;
    ];


  Array.iteri (fun i s ->
      Printf.eprintf "argv[%d] = %S\n%!" i s
    ) Sys.argv ;
  ()



(*
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
        --default-switch <default-switch      Choose a default switch to install
        --default-switch    none              Do not install any switch
    -c, --component <components>...           Component name to also install
EOF
*)
