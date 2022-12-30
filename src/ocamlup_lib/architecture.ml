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

let err fmt =
  Printf.kprintf (fun s -> Printf.eprintf "Error: %s\n%!" s; exit 2) fmt

let check_proc() =
  (*
     Check for /proc by looking for the /proc/self/exe link
     This is only run on Linux
*)
    if not ( Sys.file_exists "/proc/self/exe" ) then
      err "fatal: Unable to find /proc/self/exe.  Is /proc mounted?  Installation cannot proceed without /proc."

let get_proc_self_exe n =
  let current_exe_head = Bytes.create n in
  let ic = open_in_bin "/proc/self/exe" in
  really_input ic current_exe_head 0 n ;
  close_in ic;
  Bytes.to_string current_exe_head

let get_bitness() =
  (*
     Architecture detection without dependencies beyond coreutils.
     ELF files start out "\x7fELF", and the following byte is
       0x01 for 32-bit and
       0x02 for 64-bit.
     The printf builtin on some shells like dash only supports octal
     escape sequences, so we use those.
*)
  let current_exe_head = get_proc_self_exe 5 in
  if current_exe_head = "\x7fELF\001" then 32
  else
  if current_exe_head = "\x7fELF\002" then 64
  else
    err "unknown platform bitness %S" current_exe_head

let is_host_amd64_elf () =
(*
     ELF e_machine detection without dependencies beyond coreutils.
     Two-byte field at offset 0x12 indicates the CPU,
     but we're interested in it being 0x3E to indicate amd64, or not that.
*)
  let current_exe_machine = get_proc_self_exe 19 in
  current_exe_machine.[18] = '\x3e'

let get_endianness ~cputype ~eb ~el =
  (*     detect endianness without od/hexdump, like get_bitness() does. *)

  let current_exe_endianness = get_proc_self_exe 6 in
  let current_exe_endianness = current_exe_endianness.[5] in

  if current_exe_endianness = '\001' then
    cputype ^ el
  else
  if current_exe_endianness = '\002' then
    cputype ^ eb
  else
    err "unknown platform endianness"

let uname list =
  Call.call_stdout_string ("uname" :: list) |> String.trim

let call_match ?stderr cmd ~re =
  let lines = Call.call_stdout_lines ?stderr cmd in
  let re = match re with
    | `String re -> Str.regexp_string re
    | `STRING re -> Str.regexp_string_case_fold re
    | `Regexp re -> Str.regexp re
    | `REGEXP re -> Str.regexp_case_fold re
  in
  let rec iter lines =
    match lines with
    | [] -> false
    | line :: tail ->
        match Str.search_forward re line 0 with
        | exception Not_found -> iter tail
        | _ -> true
  in
  iter lines

let get () =
  let ostype = uname  [ "-s" ] in
  let cputype = uname [ "-m" ] in

  let bitness = ref 0 in
  let ostype = ref ostype in
  let cputype = ref cputype in
  let clibtype = ref "gnu" in

  if !ostype = "Linux" then begin
    let s = uname [ "-o" ] in

    if s = "Android" then
      ostype := "Android" ;

    if call_match ~stderr:true [ "ldd" ; "--version" ] ~re:(`STRING "musl") then
      clibtype := "musl" ;

  end;

  if !ostype = "Darwin" && !cputype = "i386" then begin
    (* Darwin `uname -m` lies *)
    if call_match [ "sysctl" ; "hw.optional.x86_64" ] ~re:(`STRING ": 1") then
      cputype := "x86_64";
  end;

  if !ostype = "SunOS" then begin
    (*
         Both Solaris and illumos presently announce as "SunOS" in "uname -s"
         so use "uname -o" to disambiguate.  We use the full path to the
         system uname in case the user has coreutils uname end ;rst in PATH,
         which has historically sometimes printed the wrong value here.
*)
    if Call.call_stdout_string [ "/usr/bin/uname" ; "-o" ]
       = "illumos" then begin
      ostype := "illumos"
    end ;

    (*
         illumos systems have multi-arch userlands, and "uname -m" reports the
         machine hardware name; e.g., "i86pc" on both 32- and 64-bit x86
         systems.  Check for the native (widest) instruction set on the
         running kernel:
*)
    if !cputype = "i86pc" then begin
      cputype := Call.call_stdout_string [ "isainfo" ; "-n" ]
    end ;
  end ;

  begin
    match String.lowercase_ascii !ostype with

    | "android" ->
        ostype := "linux-android"
    | "linux" ->
        check_proc ();
        ostype := "unknown-linux-" ^ !clibtype ;
        bitness := get_bitness ()
    | "freebsd" ->
        ostype := "unknown-freebsd"
    | "netbsd" ->
        ostype := "unknown-netbsd"
    | "dragonfly" ->
        ostype := "unknown-dragonfly"
    | "darwin" ->
        ostype := "apple-darwin"
    | "illumos" ->
        ostype := "unknown-illumos"

    | "windows_nt" | "mingw" | "msys" | "cygwin" ->
        ostype := "pc-windows-gnu"
    | os ->
        match
          if String.length os > 4 then
            String.sub os 0 4
          else
            os
        with
        | "ming"
        | "msys"
        | "cygw" ->
            ostype := "pc-windows-gnu"
        | _ ->
            err "unrecognized OS type: %s" !ostype
  end ;

  begin
    match String.lowercase_ascii !cputype with

    | "i386" | "i486" | "i686" | "i786" | "x86" ->
        cputype := "i686"

    | "xscale" | "arm" ->
        cputype := "arm" ;
        if !ostype = "linux-android" then begin
          ostype := "linux-androideabi"
        end ;

    | "armv6l" ->
        cputype := "arm" ;
        if !ostype = "linux-android" then begin
          ostype := "linux-androideabi"
        end else begin
          ostype := !ostype ^ "eabihf"
        end ;

    | "armv7l" | "armv8l" ->
        cputype := "armv7" ;
        if !ostype = "linux-android" then begin
          ostype := "linux-androideabi"
        end else begin
          ostype := !ostype ^ "eabihf"
        end ;

    | "aarch64" | "arm64" ->
        cputype := "aarch64"

    | "x86_64" | "x86-64" | "x64" | "amd64" ->
        cputype := "x86_64"

    | "mips" ->
        cputype := get_endianness ~cputype:"mips" ~eb:"" ~el:"el";

    | "mips64" ->
        if !bitness = 64 then begin
          (*  only n64 ABI is supported for now *)
          ostype := !ostype ^ "abi64" ;
          cputype := get_endianness ~cputype:"mips64" ~eb:"" ~el:"el" ;
        end ;

    | "ppc" ->
        cputype := "powerpc"

    | "ppc64" ->
        cputype := "powerpc64"

    | "ppc64le" ->
        cputype := "powerpc64le"

    | "s390x" ->
        cputype := "s390x"

    | "riscv64" ->
        cputype := "riscv64gc"

    | _ ->
        err "unknown CPU type: %s" !cputype

  end ;

(*
     Detect 64-bit linux with 32-bit userland
*)

  if !ostype = "unknown-linux-gnu"  &&  !bitness = 32 then begin
    match !cputype with
    | "x86_64" ->

        begin
          match Sys.getenv "OCAMLUP_CPUTYPE" with
          | s -> cputype := s
          | exception Not_found ->
              (*
                32-bit executable for amd64 = x32
               *)
              if is_host_amd64_elf () then begin

                err
                  "This host is running an x32 userland on a 64-bit processor. Re-run the script with the OCAMLUP_CPUTYPE environment variable set to i686 or x86_64, respectively."

              end else begin
                cputype := "i686"
              end ;
        end ;

    | "mips64" ->
        cputype := get_endianness ~cputype:"mips" ~eb:"" ~el:"el"

    | "powerpc64" ->
        cputype := "powerpc"

    | "aarch64" ->
        cputype := "armv7" ;
        if !ostype = "linux-android" then begin
          ostype := "linux-androideabi"
        end else begin
          ostype := !ostype ^ "eabihf"
        end ;

    | _ -> ()
  end ;

  Printf.eprintf "ostype: %s\n%!" !ostype ;
  Printf.eprintf "cputype: %s\n%!" !cputype ;
  Printf.eprintf "clibtype: %s\n%!" !clibtype ;
  Printf.eprintf "bitness: %d\n%!" !bitness ;

  Printf.sprintf "%s-%s"
    !cputype !ostype
