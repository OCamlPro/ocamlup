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


let ocamlup_update_root =
  match Sys.getenv "OCAMLUP_UPGRADE_SITE" with
  | s -> s
  | exception Not_found -> "https://ocamlup.ocaml-lang.org"

let on_error = Misc.on_error_exit

let download ~url ~file =
  if Sys.file_exists file then Sys.remove file ;
  Call.command ~on_error
    "curl --progress-bar --proto '=https' --tlsv1.2 -o %s %s"
    file
    url ;
  ()

let action ~update_opam ~update_opam_bin ~self () =
  if not (Sys.file_exists Globals.ocamlup_bin_dir) then begin
    Printf.eprintf "Error: %s does not exist. Use `ocamlup init` instead.\n%!"
      Globals.ocamlup_bin_dir;
    exit 2;
  end;
  let current_exe = Globals.ocamlup_bin_dir // "ocamlup" in
  let current_md5 = Digest.file current_exe in
  let new_exe =
    if self then
      Some Sys.executable_name
    else
      (* TODO: we should download the md5 of the next executable before,
         to check if it is worth downloading the executable, instead of
         downloading the executable everytime. *)
      let arch = Architecture.get () in
      let ext = "" in
      let md5_url = Printf.sprintf
          "%s/dist/%s/ocamlup.hash"
          ocamlup_update_root arch
      in

      Misc.display "Downloading executable hash";
      Misc.display "from: %s" md5_url ;
      let md5_file = Globals.ocamlup_bin_dir // "ocamlup.hash" in
      let new_md5 = try
          download ~url:md5_url ~file:md5_file ;
          let ic = open_in md5_file in
          let md5 = input_line ic in
          close_in ic;
          Digest.from_hex md5
        with exn ->
          Printf.eprintf "Error while downloading/parsing executable hash: %s\n%!"
            ( Printexc.to_string exn );
          Digest.string ""
      in

      if new_md5 = current_md5 then
        None
      else
        let bin_url = Printf.sprintf
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
        if Sys.file_exists new_exe then Sys.remove new_exe ;
        (* Here, we should probably handle both curl and wget, and specific
           versions (Busybox). TODO *)
        Misc.display "Downloading new version";
        Misc.display "from: %s" bin_url ;
        download ~url:bin_url ~file:new_exe ;
        Some new_exe
  in
  begin
    match new_exe with
    | None ->
        Printf.eprintf "ocamlup already up to date!\n%!"
    | Some new_exe ->
        let new_md5 = Digest.file new_exe in
        if current_md5 = new_md5 then begin
          Printf.eprintf "ocamlup already up to date!\n%!"
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
  end;

  Call.command ~on_error
    "%s/opam-bin install exe" Globals.ocamlup_bin_dir ;

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

  let share_current = Globals.ocamlup_dir // "share" in
  let share_next = Globals.ocamlup_dir // "share-next" in
  let share_prev = Globals.ocamlup_dir // "share-prev" in
  if not ( Sys.file_exists share_prev ) then
    Misc.mkdir share_prev ;
  let share_drom_next = share_next // "drom" in
  let share_drom_current = share_current // "drom" in
  let share_drom_prev = share_prev // "drom" in
  if Sys.file_exists share_drom_prev then
    Call.command "rm -rf %s" share_drom_prev ;
  if Sys.file_exists share_next then
    Call.command "rm -rf %s" share_next ;
  Command_init.expand_share share_next ;
  if Sys.file_exists share_drom_next then begin
    Misc.display "Updating drom directory" ;
    Sys.rename share_drom_current share_drom_prev ;
    Sys.rename share_drom_next share_drom_current ;
  end ;
  ()


open Ezcmd.V2
open EZCMD.TYPES

let cmd =
  let update_opam = ref true in
  let update_opam_bin = ref true in
  let self = ref false in
  let args = [

    [ "not-opam" ], Arg.Clear update_opam,
    EZCMD.info
      ~env:(EZCMD.env "OCAMLUP_NO_OPAM_UPDATE")
      "Do not update opam repository";

    [ "not-opam-bin" ], Arg.Clear update_opam_bin,
    EZCMD.info
      ~env:(EZCMD.env "OCAMLUP_NO_OPAMBIN_UPDATE")
      "Do not update opam-bin relocation patches";

    [ "self" ], Arg.Unit (fun () ->
        update_opam_bin := false ;
        update_opam := false ;
        self := true
      ),

    EZCMD.info
      "Use this executable to upgrade instead of downloading";

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
         ~self:!self
         ())
    ~args
    ~doc
    ~version:Version.version
    ~man
