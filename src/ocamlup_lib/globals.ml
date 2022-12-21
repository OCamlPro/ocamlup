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

let verbosity = ref 1
let verbose n = !verbosity >= n

open Ezcmd.V2
module PROGRAM = struct
  let command = "ocamlup"
  let about = "ocamlup COMMAND COMMAND-OPTIONS"
  let set_verbosity n = verbosity := n
  let get_verbosity () = !verbosity
  let backtrace_var = Some "OCAMLUP_BACKTRACE"
  let usage = "Create and manage an OCaml installation in User-Space"
  let version = Version.version
  exception Error = Error.Error
end
module MAIN = EZCMD.MAKE( PROGRAM )
include PROGRAM

open Ez_file.V1
open EzFile.OP

let home_dir = Sys.getenv "HOME"
let ocamlup_dir = home_dir // ".ocamlup"
let ocamlup_bin_dir = ocamlup_dir // "bin"
