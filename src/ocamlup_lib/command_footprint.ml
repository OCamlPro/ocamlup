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

open EzCompat

open Ez_file.V1
open EzFile.OP

open Ezcmd.V2
open EZCMD.TYPES

let ldd_filename ~libset file =
  let args = [ "ldd" ; file ] in
  match Call.call_stdout_lines args with
  | exception Error.Error _ -> ()
  | lines ->
      List.iter (fun line ->
          let line = String.trim line in
          match String.split_on_char ' ' line with
          | lib :: _ ->
              if lib <> "statically" then
                libset := StringSet.add lib !libset
          |  _ -> ()) lines

let footprint_directory dir =
  let bindir = dir // "bin" in
  let libset = ref StringSet.empty in
  Array.iter (fun basename ->
      ldd_filename ~libset ( bindir // basename )
    ) ( Sys.readdir bindir );
  List.iter (fun subdir ->
      let libdir = dir // "lib" // "ocaml" // subdir in
      Array.iter (fun basename ->
          if Filename.check_suffix basename ".so"
          || Filename.check_suffix basename ".cmxs" then
            ldd_filename ~libset (libdir // basename )
        ) ( Sys.readdir libdir )
    ) [ "." ; "stublibs" ];
  StringSet.iter (fun lib ->
      Printf.eprintf "LIB: %s\n%!" lib;
    ) !libset ;
  ()


let cmd =
  let dirs = ref [ "." ] in
  let args = [

    [], Arg.Anons (fun list -> dirs := list),
    EZCMD.info ~docv:"DIRS"
      "List of directories containing OCaml installations" ;

  ] in
  let action () =
    List.iter footprint_directory !dirs
  in
  let doc = "Generate a footprint of an OCaml installation" in
  let man =  [
    `S "DESCRIPTION";
    `Blocks [
      `P doc ;
    ]
  ] in
  EZCMD.sub "foot print"
    action
    ~args
    ~doc
    ~version:Version.version
    ~man
