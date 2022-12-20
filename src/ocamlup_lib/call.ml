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

open Globals
open Ez_file.V1

let command ?on_error fmt =
  Printf.kprintf (fun cmd ->
      Printf.eprintf "%s\n%!" cmd;
      let retcode = Sys.command cmd in
      if retcode <> 0 then begin
        Printf.eprintf "  returned error %d\n%!" retcode;
        match on_error with
        | None -> ()
        | Some f -> f retcode
      end
    ) fmt

let tmpfile () =
  Filename.temp_file "tmpfile" ".tmp"

let call ?(stdout = Unix.stdout) args =
  if verbose 2 then
    Printf.eprintf "Calling %s\n%!" (String.concat " " args);
  let targs = Array.of_list args in
  let pid = Unix.create_process targs.(0) targs
      Unix.stdin stdout Unix.stderr in
  let rec iter () =
    match Unix.waitpid [] pid with
    | exception Unix.Unix_error (EINTR, _, _) -> iter ()
    | _pid, status -> (
      match status with
      | WEXITED 0 -> ()
      | _ ->
        Error.raise "Command '%s' exited with error code %s"
          (String.concat " " args)
          ( match status with
          | WEXITED n -> string_of_int n
          | WSIGNALED n -> Printf.sprintf "SIGNAL %d" n
          | WSTOPPED n -> Printf.sprintf "STOPPED %d" n ) )
  in
  iter ()

let call_stdout_file ?file args =
  let tmpfile = match file with
    | None -> tmpfile ()
    | Some file -> file in
  let stdout = Unix.openfile tmpfile
      [ Unix.O_CREAT ; Unix.O_WRONLY ; Unix.O_TRUNC ] 0o644 in
  match call ~stdout args with
  | () ->
      Unix.close stdout;
      tmpfile
  | exception exn ->
      let stdout = EzFile.read_file tmpfile in
      if Globals.verbose 2 then
        Printf.eprintf "Stdout after error:\n%s\n" stdout;
      raise exn

let call_stdout_lines args =
  let file = call_stdout_file args in
  let stdout = EzFile.read_lines file in
  Sys.remove file;
  let lines = Array.to_list stdout in
  if Globals.verbose 2 then
    Printf.eprintf "stdout:\n%s\n%!"
      (String.concat "\n" lines);
  lines
