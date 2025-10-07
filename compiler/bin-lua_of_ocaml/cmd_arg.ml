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

open Cmdliner

type t =
  { common : Jsoo_cmdline.Arg.t
  ; bytecode : string
  ; output_file : [ `Name of string | `Stdout ]
  ; params : (string * string) list
  ; include_dirs : string list
  ; linkall : bool
  ; source_map : [ `File of string | `Inline | `No ]
  }

(* Command-line argument definitions *)

let output_file =
  let doc = "Set output file name (default: stdout)" in
  let conv x =
    match x with
    | None -> `Stdout
    | Some f -> `Name f
  in
  Term.(const conv $ Arg.(value & opt (some string) None & info [ "o"; "output" ] ~docv:"FILE" ~doc))

let bytecode =
  let doc = "Bytecode executable to compile" in
  Arg.(required & pos 0 (some string) None & info [] ~docv:"FILE.byte" ~doc)

let params =
  let doc = "Set compiler option (name=value)" in
  let parse s =
    match String.split_on_char '=' s with
    | [ name; value ] -> (name, value)
    | _ -> failwith "Invalid parameter format, expected name=value"
  in
  Term.(const (List.map parse) $ Arg.(value & opt_all string [] & info [ "set" ] ~docv:"PARAM=VALUE" ~doc))

let include_dirs =
  let doc = "Add directory to include path" in
  Arg.(value & opt_all string [] & info [ "I" ] ~docv:"DIR" ~doc)

let linkall =
  let doc = "Include all compilation units from .cma files" in
  Arg.(value & flag & info [ "linkall" ] ~doc)

let source_map =
  let doc = "Generate source map for debugging. Use --source-map to generate FILE.lua.map, or --source-map=inline for inline source map" in
  let conv = function
    | None -> `No
    | Some "" -> `File ""  (* Will be auto-generated based on output file *)
    | Some "inline" -> `Inline
    | Some f -> `File f
  in
  Term.(const conv $ Arg.(value & opt (some string) None & info [ "source-map" ] ~docv:"FILE" ~doc))
