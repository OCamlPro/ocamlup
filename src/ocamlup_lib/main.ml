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

let main () =
  Printf.eprintf "Running ocamlup!\n";
  Array.iteri (fun i s ->
      Printf.eprintf "argv[%d] = %S\n%!" i s
    ) Sys.argv ;
  ()