(* Lua_of_ocaml compiler
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
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

open! Stdlib

type fragment =
  { name : string
  ; provides : string list
  ; requires : string list
  ; code : string
  }

type state =
  { fragments : fragment StringMap.t
  ; required : StringSet.t [@warning "-69"]
  }

let init () = { fragments = StringMap.empty; required = StringSet.empty }

(* Parse provides header: "--// Provides: foo, bar" -> ["foo"; "bar"] *)
let parse_provides (line : string) : string list =
  let prefix = "--// Provides:" in
  let prefix_len = String.length prefix in
  if String.length line >= prefix_len
     && String.equal (String.sub line ~pos:0 ~len:prefix_len) prefix
  then
    let rest = String.sub line ~pos:prefix_len ~len:(String.length line - prefix_len) in
    let symbols = String.split_on_char ~sep:',' rest in
    List.filter_map
      ~f:(fun s ->
        let trimmed = String.trim s in
        if String.length trimmed > 0 then Some trimmed else None)
      symbols
  else []

let load_runtime_file filename =
  let ic = open_in_bin filename in
  let code = really_input_string ic (in_channel_length ic) in
  close_in ic;
  let name = Filename.basename filename |> Filename.chop_extension in
  (* Simplified: no header parsing for now *)
  { name; provides = [name]; requires = []; code }

let load_runtime_dir dirname =
  if Sys.file_exists dirname && Sys.is_directory dirname
  then (
    let files =
      Sys.readdir dirname
      |> Array.to_list
      |> List.filter ~f:(fun f -> Filename.check_suffix f ".lua")
      |> List.map ~f:(fun f -> Filename.concat dirname f)
    in
    List.map ~f:load_runtime_file files)
  else []

let add_fragment state fragment =
  { state with fragments = StringMap.add fragment.name fragment state.fragments }

let resolve_deps state _required =
  (* Simplified: return all fragments in arbitrary order *)
  (* TODO: implement proper dependency resolution based on required *)
  let all_names = StringMap.fold (fun name _ acc -> name :: acc) state.fragments [] in
  (all_names, [])

let generate_loader fragments =
  let buf = Buffer.create 1024 in
  Buffer.add_string buf "-- Module loader\n";
  List.iter
    ~f:(fun frag ->
      Buffer.add_string buf ("-- " ^ frag.name ^ "\n");
      Buffer.add_string buf frag.code;
      Buffer.add_char buf '\n')
    fragments;
  Buffer.contents buf

let link ~state ~program ~linkall:_ =
  (* TODO: use linkall flag to determine which fragments to include *)
  let fragments_list = StringMap.fold (fun _ frag acc -> frag :: acc) state.fragments [] in
  let loader_code = generate_loader fragments_list in
  let loader_statement = Lua_ast.Comment loader_code in
  loader_statement :: program
