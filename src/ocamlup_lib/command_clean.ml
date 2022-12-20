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

let on_error retcode =
  Printf.eprintf "Exiting because last command failed with code %d\n%!"
    retcode;
  exit retcode

let remove_line_from_file ~line ~file =
  if Sys.file_exists file then
    let has_line = ref false in
    let lines = ref [] in
    EzFile.iter_lines (fun file_line ->
        if file_line = line then has_line := true else lines := file_line :: !lines
      ) file ;
    if !has_line then begin
      let shell_content = String.concat "\n" ( List.rev !lines ) in
      Globals.display "Modifying %s" file;
      EzFile.write_file file shell_content;
      Unix.chmod file 0o755;
    end

let action ~remove_opam_flag () =

  Globals.display "Removing .ocamlup directory";
  let home_dir = Sys.getenv "HOME" in
  let ocamlup_dir = home_dir // ".ocamlup" in
  Call.command ~on_error "rm -rf %s" ocamlup_dir ;

  if remove_opam_flag then begin
    Globals.display "Removing .opam directory";
    let opam_dir = home_dir // ".opam" in
    Call.command ~on_error "rm -rf %s" opam_dir ;
  end;

  List.iter (fun shell_file ->
      let shell_file = home_dir // shell_file in
      remove_line_from_file ~line:Command_init.shell_line ~file:shell_file
    ) Command_init.shell_config_files ;

  ()

open Ezcmd.V2
open EZCMD.TYPES

let cmd =
  let remove_opam_flag = ref false in
  let args = [
    [ "opam" ], Arg.Set remove_opam_flag,
    EZCMD.info
      "Also remove .opam directory";
  ] in
  let doc = "Remove OCaml installation in User-Space" in
  let man =  [
    `S "DESCRIPTION";
    `Blocks [
      `P doc ;
    ]
  ] in
  EZCMD.sub "clean"
    (fun () ->
       action ~remove_opam_flag:!remove_opam_flag
         ())
    ~args
    ~doc
    ~version:Version.version
    ~man
