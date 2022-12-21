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
(* open EzFile.OP *)

let verbose = Globals.verbose

let eprintln v fmt =
  Printf.kprintf (fun s ->
      if verbose v then
        Printf.eprintf "%s\n%!" s
    ) fmt

let display fmt =
  Printf.kprintf (fun s ->
      Printf.printf "%s\n%!" s
    ) fmt

let on_error_exit retcode =
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
      display "Modifying %s" file;
      EzFile.write_file file shell_content;
      Unix.chmod file 0o755;
    end

let rec mkdir dir =
  if not (Sys.file_exists dir) then
    let parent_dir = Filename.dirname dir in
    mkdir parent_dir;
    EzFile.mkdir dir 0o755
