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


let ocamlup_main () =
  Printexc.record_backtrace true;
  let commands = [
    Command_init.cmd ;
    Command_footprint.cmd ;
  ] in

  let common_args = [
  ] in

  let argv = Sys.argv in
  try
    Globals.MAIN.main
      ~on_error: (fun () -> () )
      ~on_exit: (fun () -> () )
      ~print_config: (fun () -> () )
      ~argv
      commands
      ~common_args;
  with
  | Error.Error s ->
      Printf.eprintf "Error: %s\n%!" s;
      exit 2
  | exn ->
      let bt = Printexc.get_backtrace () in
      let error = Printexc.to_string exn in
      Printf.eprintf "fatal exception %s\n%s\n%!" error bt;
      exit 2

open Ez_file.V1
open EzFile.OP

let main () =
  let fullname = Sys.executable_name in
  Printf.eprintf "Wrapper %s\n%!" fullname ;
  let basename = Filename.basename fullname in
  let basename = String.lowercase_ascii basename in
  match basename with
  | "opam"
  | "opam.exe"
    -> OpamCliMain.main ()
  | "opam-bin"
  | "opam-bin.exe"
    -> Opam_bin_lib.Main.main ()
  | "drom"
  | "drom.exe"
    -> Drom_lib.Main.main ()
  | "ocamlup-init"
  | "ocamlup-init.exe"
    -> Command_init.main ()
  | "ocamlup"
  | "ocamlup.exe"
    -> ocamlup_main ()
  | "ocp-indent"
  | "ocp-indent.exe"
    -> IndentMain.main ()
  | _ ->
      begin
        match Sys.getenv "OCAMLUP_INSIDE" with
        | _ ->
            Printf.eprintf
              "Error: wrapper %S called from within opam switch %S\n%!"
              fullname (try Sys.getenv "OPAM_SWITCH_PREFIX"
                        with _ -> "(unknown)");
            Printf.eprintf
              "Tool %S is not installed in the current opam switch!\n%!"
              basename;
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
      Printf.eprintf "Wrapper: exe = %S\n%!" new_exe ;
      Array.iteri (fun i s ->
          Printf.eprintf "Wrapper: arg[%d] = %S\n%!" i s
        ) argv ;
      Unix.execvp new_exe argv
