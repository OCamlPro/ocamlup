(**************************************************************************)
(*                                                                        *)
(*    Copyright 2020 OCamlPro & Origin Labs                               *)
(*                                                                        *)
(*  All rights reserved. This file is distributed under the terms of the  *)
(*  GNU Lesser General Public License version 2.1, with the special       *)
(*  exception on linking described in the file LICENSE.                   *)
(*                                                                        *)
(**************************************************************************)

open Ez_file.V1
open EzConfig.OP

let config_filename = Globals.config_file
let config = EzConfig.create_config_file
    ( FileAbstract.of_string config_filename )

let save () =
  EzConfig.save_with_help config;
  Printf.eprintf "%s config saved in %s .\n%!"
    Globals.command Globals.config_file


let old_patches_url =
  "https://www.typerex.org/opam-bin/relocation-patches.tar.gz"
let new_patches_url =
  "https://github.com/OCamlPro/relocation-patches/tarball/master"

let base_url = EzConfig.create_option config
    [ "base_url" ]
    [
      "The `base url` of the website where the archives folder will be stored";
      "if you want to share your binary packages.";
      Printf.sprintf
        "Locally, the archives folder is stored in $HOME/.opam/%s/store ."
        Globals.command ;
    ]
    EzConfig.string_option
    "/change-this-option"

let rsync_url = EzConfig.create_option config
    [ "rsync_url" ]
    [
      Printf.sprintf
        "This is the argument passed to rsync when calling `%s push`."
        Globals.command ;
      "The directory should exist on the remote server.";
    ]
    (EzConfig.option_option EzConfig.string_option)
    None

let patches_url = EzConfig.create_option config
    [ "patches_url" ]
    [
      "The path to the repository containing relocation patches";
      "Either using GIT (git@), local (file://) or an http archive";
      "(https://.../x.tar.gz).";
      "Example: git@github.com:OCamlPro/relocation-patches";
    ]
    EzConfig.string_option new_patches_url

let title = EzConfig.create_option config
    [ "title" ]
    [
      "The title of the repository in the index.html generated by";
      Printf.sprintf
        "`opam-bin push`. Only used if %s is not defined."
        Globals.opambin_header_html;
    ]
    EzConfig.string_option
    "Repository of Binary Packages"

let enabled = EzConfig.create_option config
    [ "enabled" ]
    [ "Whether we do something or not. When [true], existing binary packages";
      "will be used instead of equivalent source packages";]
    EzConfig.bool_option
    true

let create_enabled = EzConfig.create_option config
    [ "create_enabled" ]
    [ "Whether we produce binary packages after installing source packages" ]
    EzConfig.bool_option
    true

let share_enabled = EzConfig.create_option config
    [ "share_enabled" ]
    [ "Whether we share binary files between switches (default: disabled)" ]
    EzConfig.bool_option
    false

let all_switches = EzConfig.create_option config
    [ "all_switches" ]
    [ "Whether we use a binary package for all switches. The config variable" ;
      "`switches` will only be used if this variable is false";
    ]
    EzConfig.bool_option
    true

let switches = EzConfig.create_option config
    [ "switches" ]
    [ "This list of switches (or regexp such as '*bin') for which" ;
      "creating/caching binary packages should be used" ]
    ( EzConfig.list_option EzConfig.string_option )
    []

let protected_switches = EzConfig.create_option config
    [ "protected_switches" ]
    [ "This list of switches (or regexp such as '*bin') for which" ;
      "creating/caching binary packages should NOT be used" ]
    ( EzConfig.list_option EzConfig.string_option )
    []

let exclude_dirs = EzConfig.create_option config
    [ "exclude_dirs" ]
    [ "The list of directories to exclude while computing the hash of sources.";
      "Can also be overwritten using OPAM_BIN_EXCLUDE";
    ]
    ( EzConfig.list_option EzConfig.string_option )
    [ ".git" ; ".hg" ; "_darcs" ]

let current_version = 2
(* This option should be used in the future to automatically upgrade
   configuration *)
let version = EzConfig.create_option config
    [ "version" ]
    [ "Version of the configuration file" ]
    EzConfig.int_option
    current_version

let () =
  try
    EzConfig.load config
  with _ ->
    Printf.eprintf "No configuration file.\n%!"

let () =
  let must_update = ref false in
  if !!version < 2 then begin
    must_update := true;
    version =:= 2;
    if !!patches_url = old_patches_url then
      patches_url =:= new_patches_url
  end;


  if !must_update then begin
    version =:= current_version ;
    save ()
  end
