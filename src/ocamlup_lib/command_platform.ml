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

(* open Ez_file.V1 *)
(* open EzFile.OP *)

let on_error = Misc.on_error_exit

let ocaml_platform_packages = [
  "dune" ;
  "odoc" ;
  "ocamlformat" ;
  "dune-release" ;
  "ocaml-lsp-server" ;
  "merlin" ;
  "utop" ;
]

let action () =

  Misc.display "Installing OCaml Platform" ;
  Call.command ~on_error
    "%s/opam install -y %s"
    Globals.ocamlup_bin_dir
    (String.concat " " ocaml_platform_packages);

  ()

open Ezcmd.V2
(* open EZCMD.TYPES *)

let cmd =
  let args = [
  ] in
  let doc = "Install OCaml Platform packages" in
  let man =  [
    `S "DESCRIPTION";
    `Blocks [
      `P doc ;
    ]
  ] in
  EZCMD.sub "platform"
    (fun () -> action () )
    ~args
    ~doc
    ~version:Version.version
    ~man
