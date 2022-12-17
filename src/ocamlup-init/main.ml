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

let () =
  let fullname = Sys.executable_name in
  let basename = Filename.basename fullname in
  let basename = String.lowercase_ascii basename in
  match basename with
  | "opam" -> OpamCliMain.main ()
  | "drom" -> Drom_lib.Main.main ()
  | "ocamlup-init" -> Ocamlup_lib.Command_init.main ()
  | "ocamlup" -> Ocamlup_lib.Main.main ()
  | "ocp-indent" -> Ocamlup_lib.IndentMain.main ()
  | _ ->
      begin
        match Sys.getenv "OCAMLUP_INSIDE" with
        | _ ->
            Printf.eprintf "Error: wrapper %S called from within opam switch %S\n%!"
              fullname (try Sys.getenv "OPAM_SWITCH_PREFIX" with _ -> "(unknown)");
            Printf.eprintf "Tool %S is not installed in the current opam switch!\n%!" basename;
            exit 2
        | exception Not_found -> ()
      end;
      Unix.putenv "OCAMLUP_INSIDE" "x";
      let new_exe = ( Filename.dirname fullname ) // "opam" in
      let argv =
        Array.concat [ [| new_exe ; "exec" ; "--" ; basename |];
                       Array.sub Sys.argv 1  (Array.length Sys.argv-1)
                     ]
      in
      Unix.execvp new_exe argv
