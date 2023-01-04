(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_opam_file.V1
open Ezcmd.TYPES
open EzConfig.OP
open Ez_file.V1
open EzFile.OP
module StringMap = EzCompat.StringMap

module OpamParserTypes = OpamParserTypes.FullPos
module OpamParser = OpamParser.FullPos

type info = {
  depends : string list ;
  nbytes : int ;
  nfiles : int ;
}

type package = {
  package : string ;
  version : string ;
  has_install : bool ;
  source : ( string * int ) option ;
  info : info option ;
}

let map_of_packages repo_dir =
  let map = ref StringMap.empty in

  Misc.iter_repos ~cont:ignore
    [ repo_dir ]
    (fun ~repo ~package ~version ->
       let version_dir = repo // "packages" // package // version in
       let opam = OpamParser.file ( version_dir // "opam" ) in
       let has_install = ref false in
       let source = ref None in
       List.iter OpamParserTypes.(function
           | { pelem = Variable ({pelem = "install"; _}, _ ); _} -> has_install := true
           | { pelem = Section { section_kind = { pelem = "url"; _} ; section_items ; _ }; _} ->
             List.iter (function
                 | { pelem = Variable ({ pelem = "src"; _}, { pelem = String src; _}); _}  ->
                   let archive_size =
                     let st = Unix.lstat ( repo_dir //
                                           "../archives" //
                                           ( version ^ "-bin.tar.gz" ) )
                     in
                     st.Unix.st_size
                   in
                   source := Some ( src, archive_size )
                 | _ -> ()
               ) section_items.pelem
           | _ -> ()
         ) opam.file_contents ;

       let info =
         let info_file =  version_dir // "files" // "bin-package.info" in
         if Sys.file_exists info_file then begin

           let deps = ref [] in
           let nbytes = ref 0 in
           let nfiles = ref 0 in
           EzFile.iter_lines (fun line ->
               match EzString.split line ':' with
               | "depend" :: name :: versions ->
                 deps := (Printf.sprintf "%s.%s"
                            name ( String.concat ":" versions ) ) :: !deps
               | [ "total" ; n ; "nbytes" ] -> nbytes := int_of_string n
               | [ "total" ; n ; "nfiles" ] -> nfiles := int_of_string n
               | _ -> ()
             ) ( version_dir // "files" // "bin-package.info" );
           let depends = List.sort compare !deps in
           Some {
             depends ;
             nbytes = !nbytes ;
             nfiles = !nfiles
           }
         end else
           None
       in
       let (_, version_only ) = EzString.cut_at version '.' in
       let p = {
         package ;
         version =  version_only;
         info ;
         has_install = !has_install ;
         source = !source ;
       } in
       let submap = match StringMap.find package !map with
         | exception Not_found -> StringMap.empty
         | submap -> submap
       in
       let submap = StringMap.add version_only p submap in
       map := StringMap.add package submap !map ;
       false
    );
  !map

let string_of_size nbytes =
  let nbytes = float_of_int nbytes in
  if nbytes > 1_000_000. then
    Printf.sprintf "%.2f MB" ( nbytes /. 1_000_000.)
  else
    Printf.sprintf "%.2f kB" ( nbytes /. 1_024.)

let generate_html_index repo_dir =
  let b = Buffer.create 10_000 in
  let header_html = repo_dir // "_site/header.html" in

  begin
    if Sys.file_exists header_html then
      Buffer.add_string b ( EzFile.read_file header_html )
    else
    if Sys.file_exists Globals.opambin_header_html then
      Buffer.add_string b ( EzFile.read_file Globals.opambin_header_html )
    else begin
      let s = Printf.sprintf {|
<!DOCTYPE html>
<head>
 <meta charset="utf-8">
 <title>%s</title>
</head>
<body>
 <h1>%s</h1>
 <p>Generated by <code><a href="https://ocamlpro.github.io/opam-bin">opam-bin</a> push</code>.</p>
 <p>Example of use:</p>
<pre>
export OPAMROOT=$HOME/opam-root
opam init --bare -n %s/repo
opam switch create alt-ergo 4.07.1 --packages alt-ergo
</pre>
<h2>Available Packages:</h2>
<ul>
|} !!Config.title
          !!Config.title
          !!Config.base_url
      in
      EzFile.write_file ( Globals.opambin_header_html ^ ".template" ) s;
      Buffer.add_string b s
    end;
  end;

  let current_package = ref None in
  let new_package p =
    if !current_package <> p then begin
      begin
        match !current_package with
        | None -> ()
        | Some _ ->
          Printf.bprintf b " </ul></li>\n"
      end;
      current_package := p ;
      begin
        match p with
        | None -> ()
        | Some package ->
          Printf.bprintf b {|
   <li><p>Package <b>%s</b>:</p><ul>
|} package
      end
    end
  in

  Misc.iter_repos ~cont:ignore
    [ repo_dir ]
    (fun ~repo ~package ~version ->
       new_package (Some package);
       let version_dir = repo // "packages" // package // version in
       let opam = OpamParser.file ( version_dir // "opam" ) in
       let install = ref false in
       let src = ref None in
       List.iter OpamParserTypes.(function
           | { pelem = Variable ({ pelem = "install"; _}, _ ); _} -> install := true
           | { pelem = Section ({ section_kind = { pelem = "url"; _}; section_items ; _ }); _} ->
               List.iter (function
                   | { pelem = Variable ({ pelem = "src"; _}, { pelem = String s; _}); _} ->
                       src := Some s
                   | _ -> ()
                 ) section_items.pelem
           | _ -> ()
         ) opam.file_contents ;
       let src =
         match !src with
         | None -> "[ no content ]"
         | Some src ->

           let archive_size =
             let st = Unix.lstat ( repo_dir //
                                   "../archives" //
                                   ( version ^ "-bin.tar.gz" ) )
             in
             st.Unix.st_size
           in

           Printf.sprintf {| [ <a href="%s"> DOWNLOAD </a> ( %s )] |}
             src
             ( string_of_size archive_size )
       in

       let info =
         let info_file =  version_dir // "files" // "bin-package.info" in
         if Sys.file_exists info_file then begin

           let deps = ref [] in
           let nbytes = ref 0 in
           let nfiles = ref 0 in
           EzFile.iter_lines (fun line ->
               match EzString.split line ':' with
               | "depend" :: name :: versions ->
                 deps := (Printf.sprintf "%s.%s"
                            name ( String.concat ":" versions ) ) :: !deps
               | [ "total" ; n ; "nbytes" ] -> nbytes := int_of_string n
               | [ "total" ; n ; "nfiles" ] -> nfiles := int_of_string n
               | _ -> ()
             ) ( version_dir // "files" // "bin-package.info" );
           match !deps, !nbytes with
           | [], 0 -> ""
           | [ nv ], 0 ->
             Printf.sprintf {| depend: %s |} nv
           | _ ->
             let deps = List.sort compare !deps in
             Printf.sprintf {| <br/>
 <a href="packages/%s/%s/files/bin-package.info"> INFO </a>: %s, %d files,
 depends: %s
|}
               package version
               ( string_of_size ! nbytes )
               !nfiles
               (String.concat " " deps)
         end else
           ""
       in

       Printf.bprintf b {|
       <li>Package <b>%s</b> : [ <a href="packages/%s/%s/opam"> OPAM </a> ]%s%s</li>
|} version
         package version
         src
         info ;
       false
    );
  new_package None;
  begin
    let trailer_html = repo_dir // "_site/trailer.html" in
    if Sys.file_exists trailer_html then
      Buffer.add_string b ( EzFile.read_file trailer_html )
    else
    if Sys.file_exists Globals.opambin_trailer_html then
      Buffer.add_string b ( EzFile.read_file Globals.opambin_trailer_html )
    else begin
      let s = Printf.sprintf {|
    </ul>
      <hr>
<p>
        Generated by <code>opam-bin</code>, &copy; Copyright 2020, OCamlPro SAS &amp; Origin Labs SAS. &lt;contact@ocamlpro.com&gt;
    </p>
</body>
|}
      in
      Buffer.add_string b s ;
      EzFile.write_file ( Globals.opambin_trailer_html ^ ".template") s;
    end ;
  end;

  let html = Buffer.contents b in
  EzFile.write_file ( repo_dir // "index.html" ) html

let generate_files repo_dir =
  Unix.chdir repo_dir;
  Misc.call ~nvo:None [| "opam" ; "admin" ; "index" |];
  Unix.chdir Globals.curdir ;

  generate_html_index repo_dir

let cut_at_string ~sep s =
  let seplen = String.length sep in
  if seplen = 0 then failwith "cut_at_string: empty sep argument";
  let len = String.length s in
  let c = sep.[0] in
  let rec iter pos =
    if pos + seplen > len then
      ( s, "" )
    else
      match String.index_from s pos c with
      | exception Not_found -> ( s, "" )
      | pos ->
        iter_found pos 1

  and iter_found pos i =
    if i = seplen then
      ( String.sub s 0 pos, String.sub s (pos+seplen) (len-pos-seplen) )
    else
    if sep.[i] = s.[pos+i] then
      iter_found pos (i+1)
    else
      iter (pos+1)
  in
  iter 0

let () =
  List.iter (fun (s, sep, res) ->
      assert ( cut_at_string s ~sep = res )
    ) [
    "bonjour a tous", "a", ( "bonjour ", " tous" );
    "bonjour a tous", " a ", ( "bonjour", "tous" );
    "bonjour a tous", " a", ( "bonjour", " tous" );
    "bonjour a tous", "ou", ( "bonj", "r a tous" )
  ]

let extract_packages s delete =
  let (repo, prefix) = EzString.cut_at s ':' in
  let src_dir = Globals.opambin_store_repo_dir in
  let dst_dir = Globals.opambin_store_dir // repo in
  let map = map_of_packages src_dir in
  let package, prefix_version = EzString.cut_at prefix '.' in

  let needed = ref [] in
  let map = StringMap.map (fun submap ->
      StringMap.map (fun p ->
          if p.package = package then
            if EzString.starts_with p.version ~prefix:prefix_version then
              needed := ( p.package, p.version ) :: !needed ;
          ( ref `ToCheck, p )
        ) submap
    ) map
  in

  let rec iter_needed ( package, version ) =
    let submap = StringMap.find package map in
    let ( ok, p ) = StringMap.find version submap in
    match !ok with
    | `ToCheck ->
      ok := `Needed;
      iter_needed (p.package, p.version)
    | `Needed -> ()
    | _ -> assert false
  in
  List.iter iter_needed !needed ;

  StringMap.iter (fun package submap ->

      let has_needed = ref None in
      StringMap.iter (fun _version ( ok, p ) ->
          match !ok with
          | `Needed -> has_needed := Some p
          | _ -> ()
        ) submap ;

      match !has_needed with
      | None -> ()
      | Some pp ->
        StringMap.iter (fun _version ( ok, p ) ->
            if p != pp then
              match !ok with
              | `Needed ->
                Printf.kprintf failwith
                  "Packages %s.%s and %s.%s are both needed but conflicting"
                  package pp.version package p.version
              | _ ->
                ok := `Conflict
          ) submap
    ) map ;

  let rec check_deps ( ok, p ) =
    let res =
      match p.info with
      | None -> `Ok
      | Some info ->
        let deps = info.depends in
        if
          List.for_all (fun nv ->
              let ( n, v ) = EzString.cut_at nv '.' in
              let ( ok, p ) =
                match StringMap.find n map with
                | exception Not_found ->
                  Printf.kprintf failwith
                    "%s: %s not found in map"
                    nv n
                | submap ->
                  match StringMap.find v submap with
                  | exception Not_found ->
                    Printf.kprintf failwith
                      "%s: %s not found in submap for %s"
                      nv v n
                  | v -> v
              in
              match !ok with
              | `Ok -> true
              | `Conflict -> false
              | `Needed -> true
              | `ToCheck ->
                check_deps ( ok, p );
                match !ok with
                | `Ok -> true
                | `Conflict -> false
                | _ -> assert false
            ) deps
        then
          `Ok
        else
          `Conflict
    in
    ok := res
  in
  StringMap.iter (fun _package submap ->
      StringMap.iter (fun _version ( ok, p ) ->
          match !ok with
          | `Needed -> ()
          | `ToCheck -> check_deps ( ok, p )
          | `Conflict -> ()
          | `Ok -> ()
        ) submap
    ) map;

  EzFile.make_dir ~p:true dst_dir ;
  if delete then
    Misc.call ~nvo:None [| "rm"; "-rf"; dst_dir // "packages" |];
  StringMap.iter (fun package submap ->
      if EzString.ends_with package ~suffix:"+bin" then
        ()
      else
        StringMap.iter (fun _version ( ok, p ) ->
            match !ok with
            | `Needed
            | `Ok ->
              let nv = Printf.sprintf "%s.%s" package p.version in
              let package_dir = dst_dir // "packages" // package // nv in
              EzFile.make_dir ~p:true package_dir ;
              Misc.call ~nvo:None [|
                "rsync"; "-auv"; "--delete" ;
                src_dir // "packages" // package // nv // "." ;
                package_dir
              |];
              let (old_version, _ ) = cut_at_string p.version ~sep:"+bin" in
              CommandPostInstall.write_bin_stub
                ~name:p.package ~version:old_version
                ~new_version:p.version
                ~repo_dir:dst_dir
            | `Conflict -> ()
            | `ToCheck -> assert false
          ) submap
    ) map;

  generate_files dst_dir ;
  ()

let generate_all_files () =
  let files = Sys.readdir Globals.opambin_store_dir in
  Array.iter (fun file ->
      let file = Globals.opambin_store_dir // file in
      if Sys.is_directory file
         && Sys.file_exists ( file // "repo" )
         && Sys.file_exists ( file // "packages" )
      then
        generate_files file
    ) files

let action ~merge ~local_only ~extract ~delete () =
  match !extract with
  | Some s ->
    extract_packages s !delete
  | None ->
    if !local_only then
      generate_all_files ()
    else
      match !!Config.rsync_url with
      | None ->
        Printf.eprintf
          "Error: you must define the remote url with `%s config \
           --rsync-url`\n%!"
          Globals.command ;
        exit 2
      | Some rsync_url ->

        if not !merge then generate_all_files () ;

        let args = [ "rsync"; "-auv" ; "--progress" ] in
        let args = if !merge then args else args @ [ "--delete" ] in
        let args = args @ [
            Globals.opambin_store_dir // "." ;
            rsync_url
          ] in
        Printf.eprintf "Calling '%s'\n%!"
          (String.concat " " args);
        Misc.call ~nvo:None (Array.of_list args);
        Printf.eprintf "Done.\n%!";
        ()

let cmd =
  let extract = ref None in
  let merge = ref false in
  let local_only = ref false in
  let delete = ref false in
  {
    cmd_name = "push" ;
    cmd_action = action ~merge ~local_only ~extract ~delete ;
    cmd_args = [

      [ "merge" ], Arg.Set merge,
      Ezcmd.info "Merge instead of deleting non-existent files on the \
                  remote side (do not generate index.tar.gz and \
                  index.html)";

      [ "local-only" ], Arg.Set local_only,
      Ezcmd.info "Generate index.tar.gz and index.html without \
                  upstreaming (for testing purpose)";

      [ "extract" ] , Arg.String (fun s -> extract := Some s),
      Ezcmd.info "NAME:PACKAGE Extract all packages compatible with \
                  PACKAGE from stores/repo to stores/NAME. PACKAGE is \
                  a prefix, such as ocaml.4.07.";

      [ "delete" ] , Arg.Set delete,
      Ezcmd.info "Delete previous packages with --extract";
    ];
    cmd_man = [];
    cmd_doc = "push binary packages to the remote server";
  }