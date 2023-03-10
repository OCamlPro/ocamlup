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

let on_error = Misc.on_error_exit

let action ~remove_opam_flag () =

  Misc.display "Removing .ocamlup directory";
  Call.command ~on_error "rm -rf %s" Globals.ocamlup_dir ;

  if remove_opam_flag then begin
    Misc.display "Removing .opam directory";
    let opam_dir = Globals.home_dir // ".opam" in
    Call.command ~on_error "rm -rf %s" opam_dir ;
  end;

  List.iter (fun shell_file ->
      let shell_file = Globals.home_dir // shell_file in
      Misc.remove_line_from_file ~line:Command_init.shell_line ~file:shell_file
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
