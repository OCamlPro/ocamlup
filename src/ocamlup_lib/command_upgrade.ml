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


let ocamlup_update_root = "https://ocamlup.ocaml-lang.org"

let action ~update_opam ~update_opam_bin () =
  let on_error = Misc.on_error_exit in

  if not (Sys.file_exists Globals.ocamlup_bin_dir) then begin
    Printf.eprintf "Error: %s does not exist. Use `ocamlup init` instead.\n%!"
      Globals.ocamlup_bin_dir;
    exit 2;
  end;

  (* TODO: we should download the md5 of the next executable before,
     to check if it is worth downloading the executable, instead of
     downloading the executable everytime. *)
  let arch = Architecture.get () in
  let ext = "" in
  let url = Printf.sprintf
      "%s/dist/%s/ocamlup-init%s"
      ocamlup_update_root arch ext
  in
  let new_exe =
    Printf.sprintf "%s/ocamlup-new%s"
      Globals.ocamlup_bin_dir
      ext
  in
  (* TODO: we should 'ext' everywhere, probably for later Windows
     compatibility *)
  let current_exe = Globals.ocamlup_bin_dir // "ocamlup" in
  if Sys.file_exists new_exe then Sys.remove new_exe ;
  (* Here, we should probably handle both curl and wget, and specific
     versions (Busybox). TODO *)
  Misc.display "Downloading new version";
  Call.command ~on_error
    "curl --progress-bar --proto '=https' --tlsv1.2 -o %s %s"
    new_exe
    url ;

  let current_md5 = Digest.file current_exe in
  let new_md5 = Digest.file new_exe in
  if current_md5 = new_md5 then begin
    Printf.eprintf "ocamlup already up to date!\n%!";
  end else begin

    let prev_exe = Globals.ocamlup_bin_dir // "ocamlup.prev" in
    let prev_md5 =
      if Sys.file_exists prev_exe then
        Some ( Digest.file prev_exe )
      else
        None
    in
    begin
      match prev_md5 with
      | Some prev_md5 when prev_md5 = current_md5 ->
          (* already saved, no need to backup current ocamlup *)
          Sys.remove current_exe
      | _ ->
          if prev_md5 != None then
            Sys.remove prev_exe ;
          Misc.display "Backuping %s to %s" current_exe prev_exe ;
          Sys.rename current_exe prev_exe;
    end ;
    Misc.display "ocamlup/ocaml/ocp-indent/drom updated";
    Unix.chmod new_exe 0o755 ;
    Sys.rename new_exe current_exe ;
  end;

  if update_opam then begin
    Misc.display "Updating opam repository";
    Call.command ~on_error
      "%s/opam update" Globals.ocamlup_bin_dir ;
  end;

  if update_opam_bin then begin
    Misc.display "Updating opam-bin relocation patches";
    Call.command ~on_error
      "%s/opam-bin install patches" Globals.ocamlup_bin_dir ;
  end;
  ()


open Ezcmd.V2
open EZCMD.TYPES

let cmd =
  let update_opam = ref true in
  let update_opam_bin = ref true in
  let args = [

    [ "not-opam" ], Arg.Clear update_opam,
    EZCMD.info
      ~env:(EZCMD.env "OCAMLUP_NO_OPAM_UPDATE")
      "Do not update opam repository";

    [ "not-opam-bin" ], Arg.Clear update_opam_bin,
    EZCMD.info
      ~env:(EZCMD.env "OCAMLUP_NO_OPAMBIN_UPDATE")
      "Do not update opam-bin relocation patches";

  ]
  in
  let doc = "Upgrade ocamlup and opam installations" in
  let man =  [
    `S "DESCRIPTION";
    `Blocks [
      `P doc ;
    ]
  ] in
  EZCMD.sub "upgrade"
    (fun () ->
       action
         ~update_opam:!update_opam
         ~update_opam_bin:!update_opam_bin
         ())
    ~args
    ~doc
    ~version:Version.version
    ~man
