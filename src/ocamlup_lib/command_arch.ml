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

open Ezcmd.V2
(* open EZCMD.TYPES *)

let cmd =
  let args = [] in
  let action () =
    let arch = Architecture.get () in
    Printf.printf "%s\n%!" arch
  in
  let doc = "Compute the footprint of the architecture" in
  let man =  [
    `S "DESCRIPTION";
    `Blocks [
      `P doc ;
    ]
  ] in
  EZCMD.sub "get arch"
    action
    ~args
    ~doc
    ~version:Version.version
    ~man
