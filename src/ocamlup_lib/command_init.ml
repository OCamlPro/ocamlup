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

let shell_line = {|. "$HOME/.ocamlup/env"|}
let shell_config_files =
  [
  (* Sh *)
  ".profile" ;

  (* Bash *)
  ".bashrc" ;
  ".bash_login";
  ".bash_profile" ;

  (* Zsh *)
  ".zshrc" ;
  ".zshenv" ;
  ".zprofile" ;
]

let ocaml_platform_binaries = [
  "dune" ;
  "odoc" ;
  "ocamlformat" ;
  "dune-release" ;
  "ocamllsp" ;
  "merlin" ;
  "utop" ;
]

let bin_aliases = [
  "ocamlup-init" ;
  "opam" ;
  "opam-bin" ;
  "drom" ;
  "ocp-indent" ;
]

let bin_wrappers = [
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

  "ocp-index" ;
  "menhir" ;
] @
  ocaml_platform_binaries

let env_content = {|#!/bin/sh
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
|}

let expand_share share_drom_dir =
  List.iter (fun file ->
      match Drom_lib.Share.read file with
      | None -> assert false
      | Some content ->
          let fullname = share_drom_dir // file in
          let dirname = Filename.dirname fullname in
          Misc.mkdir dirname ;
          EzFile.write_file fullname content;
    ) Drom_lib.Share.file_list ;
  ()

let action ?repo_url ~src_flag ~editions
    ~no_modify_path
    ~no_wrappers
    ~no_sandboxing
    () =

  let on_error = Misc.on_error_exit in
  Misc.display "Running ocamlup-init!";

  Misc.mkdir Globals.ocamlup_bin_dir;
  let bin_content = EzFile.read_file Sys.executable_name in
  let ocamlup_file = Globals.ocamlup_bin_dir // "ocamlup" in
  Misc.display "Creating %s" ocamlup_file;
  if Sys.file_exists ocamlup_file then begin
    Misc.eprintln 2 "Removing %S\n%!" ocamlup_file ;
    Sys.remove ocamlup_file;
  end;
  EzFile.write_file ocamlup_file bin_content;
  Unix.chmod ocamlup_file 0o755;
  List.iter (fun basename ->
      let target_file = Globals.ocamlup_bin_dir // basename in
      if Sys.file_exists target_file then begin
        Misc.eprintln 2 "Removing %S\n%!" target_file ;
        Sys.remove target_file;
      end;
      Misc.eprintln 2 "Creating %S\n%!" target_file ;
      Unix.symlink ocamlup_file target_file;
      Unix.chmod target_file 0o755;
    )
    (bin_aliases @
     if no_wrappers then [] else bin_wrappers);

  let path = Sys.getenv "PATH" in
  Unix.putenv "PATH"
    ( Printf.sprintf "%s:%s"
        Globals.ocamlup_bin_dir
        path );

  let env_file = Globals.ocamlup_dir // "env" in
  Misc.eprintln 2 "Creating %s\n%!" env_file;
  EzFile.write_file env_file env_content;
  Unix.chmod env_file 0o755;

  if not no_modify_path then begin
    List.iter (fun basename ->
        let shell_file = Globals.home_dir // basename in
        if Sys.file_exists shell_file then
          let has_line = ref false in
          EzFile.iter_lines (fun line ->
              if line = shell_line then has_line := true
            ) shell_file ;
          if not !has_line then begin
            let shell_content = EzFile.read_file shell_file in
            Misc.display "Modifying %s" shell_file;
            let shell_content = Printf.sprintf "%s\n%s\n" shell_content shell_line in
            EzFile.write_file shell_file shell_content;
            Unix.chmod shell_file 0o755;
          end;
        else begin
          EzFile.write_file shell_file (shell_line^ "\n");
          Unix.chmod shell_file 0o755;
        end
      ) shell_config_files
  end;

  Misc.display "Initializing opam repository";
  Call.command ~on_error
    "%s/opam init --bare%s -n%s"
    Globals.ocamlup_bin_dir
    (if no_sandboxing then " --disable-sandboxing" else "")
    (match repo_url with
     | None -> ""
     | Some repo_url ->
         Printf.sprintf " %s '%s'" "default" repo_url
    );

  (* Disable ocaml-system package *)
  Call.command ~on_error
    "%s/opam var --global --cli 2.1 \"sys-ocaml-version=\""
    Globals.ocamlup_bin_dir;

  Misc.display "Initializing opam-bin plugin";
  Call.command ~on_error
    "%s/opam-bin install"
    Globals.ocamlup_bin_dir
  ;
  Call.command ~on_error
    "%s/opam-bin config --enable-share"
    Globals.ocamlup_bin_dir
  ;

  let share_drom_dir = Globals.ocamlup_dir // "share" in
  expand_share share_drom_dir ;

  if not src_flag then begin
    let arch = Architecture.get () in
    let remote = "ocamlup" in
    let url = Printf.sprintf
        "https://ocamlup.ocaml-lang.org/dist/%s/repo" arch in
    Misc.display "Adding remote %s to opam" remote;
    Call.command ~on_error
      "%s/opam remote add %s --all --set-default %s"
      Globals.ocamlup_bin_dir
      remote
      url ;
  end;

  let editions = match editions with
      [] -> [ "4.14.0" ]
    | [ "none" ] -> []
    | _ -> editions in
  List.iter (fun ocaml_version ->
      Misc.display "Installing OCaml version %s" ocaml_version ;
      Call.command ~on_error
        "%s/opam switch create %s"
        Globals.ocamlup_bin_dir
        ocaml_version;
    ) editions ;

  Misc.display "";
  Misc.display "OCaml Installed in user space!";
  Misc.display "";
  Misc.display
    "To setup your PATH, use the following line (inserted in shell configs):";
  Misc.display ". $HOME/.ocamlup/env";
  Misc.display "";
  Misc.display "Then, use the following line to access an OCaml switch:";
  Misc.display "eval $(opam env)";
  ()

open Ezcmd.V2
open EZCMD.TYPES

let cmd =
  let repo_url = ref None in
  let src_flag = ref false in
  let no_modify_path = ref false in
  let no_wrappers = ref false in
  let no_sandboxing = ref false in
  let editions = ref [] in
  let args = [

    [ "default-switch" ], Arg.String (fun s -> editions := s :: !editions),
    EZCMD.info
      ~env:(EZCMD.env "OCAMLUP_DEFAULT_SWITCH")
      ~docv:"VERSION" "Install OCaml with version $(VERSION)";

    [ "repo-url" ], Arg.String (fun s -> repo_url := Some s),
    EZCMD.info
      ~env:(EZCMD.env "OCAMLUP_REPO_URL")
      ~docv:"REPO-URL" "Use this repository as default repository" ;

    [ "src" ], Arg.Set src_flag,
    EZCMD.info
      ~env:(EZCMD.env "OCAMLUP_SRC")
      "Do not use a remote binary repository, build everything from sources";

    [ "no-modify-path" ], Arg.Set no_modify_path,
    EZCMD.info
      ~env:(EZCMD.env "OCAMLUP_NO_MODIFY_PATH")
      "Do not modify shell initialization scripts to setup PATH";

    [ "no-wrappers" ], Arg.Set no_wrappers,
    EZCMD.info
      ~env:(EZCMD.env "OCAMLUP_NO_WRAPPERS")
      "Do not install wrappers for ocaml/platform commands in PATH";

    [ "no-sandboxing" ], Arg.Set no_sandboxing,
    EZCMD.info
      ~env:(EZCMD.env "OCAMLUP_NO_SANDBOXING")
      "Disable sandboxing in opam";

  ] in
  let doc = "Initialize OCaml installation in User-Space" in
  let man =  [
    `S "DESCRIPTION";
    `Blocks [
      `P doc ;
    ]
  ] in
  EZCMD.sub "init"
    (fun () ->
       action
         ?repo_url:!repo_url
         ~src_flag:!src_flag
         ~editions:!editions
         ~no_modify_path:!no_modify_path
         ~no_wrappers:!no_wrappers
         ~no_sandboxing:!no_sandboxing
         ())
    ~args
    ~doc
    ~version:Version.version
    ~man
