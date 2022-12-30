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

val verbose : int -> bool
val eprintln : int -> ('a, unit, string, unit) format4 -> 'a
val display : ('a, unit, string, unit) format4 -> 'a
val on_error_exit : int -> 'a
val remove_line_from_file : line:string -> file:string -> unit
val mkdir : string -> unit
