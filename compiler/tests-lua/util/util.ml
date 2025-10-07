(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

open Js_of_ocaml_compiler.Stdlib
module Jsoo = Js_of_ocaml_compiler
module Lua_generate = Lua_of_ocaml_compiler__Lua_generate
module Lua_output = Lua_of_ocaml_compiler__Lua_output

let exe =
  match Sys.os_type with
  | "Cygwin" | "Win32" -> fun x -> x ^ ".exe"
  | "Unix" | _ -> fun x -> x

let ocamlc = try Sys.getenv "OCAMLC" with Not_found -> exe "ocamlc"

let ocamlrun = try Sys.getenv "OCAMLRUN" with Not_found -> exe "ocamlrun"

let lua = try Sys.getenv "LUA" with Not_found -> "lua"

let js_of_ocaml_root =
  try
    let dir = Sys.getenv "PROJECT_ROOT" in
    if Filename.is_relative dir then Filename.concat (Sys.getcwd ()) dir else dir
  with Not_found -> (
    let regex_text = "_build" in
    let regex = Str.regexp regex_text in
    match Sys.getcwd () |> Str.split regex with
    | left :: _ :: _ -> Filename.concat (Filename.concat left regex_text) "default"
    | _ -> failwith "unable to find project root")

let prng = lazy (Random.State.make_self_init ())

let temp_file_name temp_dir prefix suffix =
  let rnd = Random.State.bits (Stdlib.Lazy.force prng) land 0xFFFFFF in
  Filename.concat temp_dir (Printf.sprintf "%s%06x%s" prefix rnd suffix)

let remove_dir =
  let rec loop_files dir handle =
    match Unix.readdir handle with
    | ".." | "." -> loop_files dir handle
    | f ->
        let dir_or_file = Filename.concat dir f in
        if Sys.is_directory dir_or_file
        then remove_dir dir_or_file
        else Sys.remove dir_or_file;
        loop_files dir handle
    | exception End_of_file -> ()
  and remove_dir dir =
    let handle = Unix.opendir dir in
    loop_files dir handle;
    Unix.closedir handle;
    Unix.rmdir dir
  in
  remove_dir

let with_temp_dir ~f =
  let old_cwd = Sys.getcwd () in
  let temp = Filename.get_temp_dir_name () in
  let dir = temp_file_name temp "lua-test" "" in
  Unix.mkdir dir 0o700;
  Sys.chdir dir;
  let x = f () in
  Sys.chdir old_cwd;
  remove_dir dir;
  x

let read_file file =
  let ic = open_in_bin file in
  let n = in_channel_length ic in
  let s = Bytes.create n in
  really_input ic s 0 n;
  close_in ic;
  Bytes.to_string s

let write_file ~name ~contents =
  let oc = open_out_bin name in
  output_string oc contents;
  close_out oc

(* Compile OCaml source to bytecode *)
let compile_ocaml_to_bytecode ~ocaml_file ~output =
  let cmd =
    Printf.sprintf "%s -g -o %s %s 2>&1" ocamlc output ocaml_file
  in
  let ic = Unix.open_process_in cmd in
  let result = read_file "/dev/stdin" in
  match Unix.close_process_in ic with
  | Unix.WEXITED 0 -> Ok ()
  | _ -> Error result

(* Compile bytecode to Lua *)
let compile_bytecode_to_lua ~bytecode_file ~output ?(compact = false) ?(source_map = false) () =
  let lua_of_ocaml_exe =
    Filename.concat
      js_of_ocaml_root
      "compiler/bin-lua_of_ocaml/lua_of_ocaml.exe"
  in
  let compact_flag = if compact then "--compact" else "" in
  let source_map_flag = if source_map then "--source-map" else "" in
  let cmd =
    Printf.sprintf
      "%s compile %s %s %s -o %s 2>&1"
      lua_of_ocaml_exe
      compact_flag
      source_map_flag
      bytecode_file
      output
  in
  let ic = Unix.open_process_in cmd in
  let stderr_output =
    let buf = Buffer.create 1024 in
    (try
       while true do
         Buffer.add_string buf (input_line ic);
         Buffer.add_char buf '\n'
       done
     with End_of_file -> ());
    Buffer.contents buf
  in
  match Unix.close_process_in ic with
  | Unix.WEXITED 0 -> Ok ()
  | _ -> Error stderr_output

(* Run Lua code and capture output *)
let run_lua ~lua_file =
  let cmd = Printf.sprintf "%s %s 2>&1" lua lua_file in
  let ic = Unix.open_process_in cmd in
  let output =
    let buf = Buffer.create 1024 in
    (try
       while true do
         Buffer.add_string buf (input_line ic);
         Buffer.add_char buf '\n'
       done
     with End_of_file -> ());
    Buffer.contents buf
  in
  let exit_status = Unix.close_process_in ic in
  (output, exit_status)

(* High-level: compile OCaml source to Lua and return the Lua code *)
let compile_ocaml_to_lua ?(compact = false) ?(source_map = false) ocaml_source =
  with_temp_dir ~f:(fun () ->
      let ocaml_file = "test.ml" in
      let bytecode_file = "test.byte" in
      let lua_file = "test.lua" in
      write_file ~name:ocaml_file ~contents:ocaml_source;
      match compile_ocaml_to_bytecode ~ocaml_file ~output:bytecode_file with
      | Error msg -> failwith (Printf.sprintf "OCaml compilation failed: %s" msg)
      | Ok () -> (
          match compile_bytecode_to_lua ~bytecode_file ~output:lua_file ~compact ~source_map () with
          | Error msg -> failwith (Printf.sprintf "Lua compilation failed: %s" msg)
          | Ok () -> read_file lua_file))

(* High-level: compile and run OCaml source as Lua, return output *)
let compile_and_run ?(compact = false) ocaml_source =
  with_temp_dir ~f:(fun () ->
      let ocaml_file = "test.ml" in
      let bytecode_file = "test.byte" in
      let lua_file = "test.lua" in
      write_file ~name:ocaml_file ~contents:ocaml_source;
      match compile_ocaml_to_bytecode ~ocaml_file ~output:bytecode_file with
      | Error msg ->
          Printf.printf "OCaml compilation failed:\n%s\n" msg;
          flush stdout
      | Ok () -> (
          match compile_bytecode_to_lua ~bytecode_file ~output:lua_file ~compact () with
          | Error msg ->
              Printf.printf "Lua compilation failed:\n%s\n" msg;
              flush stdout
          | Ok () ->
              let output, _exit_status = run_lua ~lua_file in
              print_string output;
              flush stdout))

(* Parse bytecode and generate Lua AST *)
let compile_to_lua_ast ?(debug = false) ocaml_source =
  with_temp_dir ~f:(fun () ->
      let ocaml_file = "test.ml" in
      let bytecode_file = "test.byte" in
      write_file ~name:ocaml_file ~contents:ocaml_source;
      match compile_ocaml_to_bytecode ~ocaml_file ~output:bytecode_file with
      | Error msg -> failwith (Printf.sprintf "OCaml compilation failed: %s" msg)
      | Ok () ->
          let ic = open_in_bin bytecode_file in
          let bytecode_result =
            Jsoo.Parse_bytecode.from_exe
              ~includes:[]
              ~linkall:false
              ~link_info:false
              ~include_cmis:false
              ~debug
              ic
          in
          close_in ic;
          Lua_generate.generate ~debug bytecode_result.code)

(* Extract a specific function from Lua code *)
let extract_function lua_code func_name =
  let lines = String.split_on_char ~sep:'\n' lua_code in
  let rec find_function acc = function
    | [] -> None
    | line :: rest ->
        if String.contains line '(' &&
           (Str.string_match (Str.regexp (".*function " ^ func_name ^ " *(.*")) line 0 ||
            Str.string_match (Str.regexp (".*local " ^ func_name ^ " *= *function *(.*")) line 0)
        then collect_until_end (line :: acc) rest 0
        else find_function acc rest
  and collect_until_end acc lines depth =
    match lines with
    | [] -> Some (String.concat ~sep:"\n" (List.rev acc))
    | line :: rest ->
        let new_depth =
          depth +
          (if Str.string_match (Str.regexp ".*\\bfunction\\b.*") line 0 then 1 else 0) +
          (if Str.string_match (Str.regexp ".*\\bdo\\b.*") line 0 then 1 else 0) +
          (if Str.string_match (Str.regexp ".*\\bif\\b.*") line 0 then 1 else 0) +
          (if Str.string_match (Str.regexp ".*\\bwhile\\b.*") line 0 then 1 else 0) -
          (if Str.string_match (Str.regexp ".*\\bend\\b.*") line 0 then 1 else 0)
        in
        if new_depth < 0
        then Some (String.concat ~sep:"\n" (List.rev (line :: acc)))
        else collect_until_end (line :: acc) rest new_depth
  in
  find_function [] lines

(* Print a specific function from compiled Lua code *)
let print_function ocaml_source func_name =
  let lua_code = compile_ocaml_to_lua ocaml_source in
  match extract_function lua_code func_name with
  | Some func -> print_endline func
  | None -> Printf.printf "Function %s not found\n" func_name
