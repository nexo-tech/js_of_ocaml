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

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler
module Lua_generate = Lua_of_ocaml_compiler__Lua_generate
module Lua_output = Lua_of_ocaml_compiler__Lua_output

let times = Debug.find "times"

let () = Sys.catch_break true

let run { Cmd_arg.common; bytecode; output_file; params; include_dirs; linkall; source_map; compact } =
  Config.set_target `Wasm;
  Jsoo_cmdline.Arg.eval common;
  Linker.reset ();
  List.iter params ~f:(fun (s, v) -> Config.Param.set s v);

  let t = Timer.make () in
  let include_dirs = List.filter_map include_dirs ~f:(fun d -> Findlib.find [] d) in

  (* Check if we need debug info *)
  let enable_source_map = match source_map with `No -> false | _ -> true in
  let need_debug = enable_source_map || Config.Flag.debuginfo () in

  (* Load and link bytecode *)
  let one =
    let ic = open_in_bin bytecode in
    let result =
      Parse_bytecode.from_exe
        ~includes:include_dirs
        ~linkall
        ~link_info:false
        ~include_cmis:false
        ~debug:need_debug
        ic
    in
    close_in ic;
    result
  in
  if times () then Format.eprintf "parsing: %a@." Timer.print t;

  (* Get the program from the bytecode *)
  let p = one.code in

  (* Generate Lua code with debug info if needed *)
  let lua_code = Lua_generate.generate ~debug:need_debug p in
  if times () then Format.eprintf "generation: %a@." Timer.print t;
  let (lua_string, source_map_info_opt) =
    if enable_source_map
    then (
      let code, sm_info = Lua_output.program_to_string_with_source_map ~minify:compact lua_code in
      (code, Some sm_info))
    else (Lua_output.program_to_string ~minify:compact lua_code, None)
  in

  (* Output Lua code *)
  let output_name =
    match output_file with
    | `Stdout ->
        Pretty_print.string (Pretty_print.to_out_channel stdout) lua_string;
        None
    | `Name name ->
        Filename.gen_file name (fun chan ->
            Pretty_print.string (Pretty_print.to_out_channel chan) lua_string);
        Some name
  in

  (* Output source map if enabled *)
  (match (source_map_info_opt, source_map, output_name) with
  | Some sm_info, `File sm_file, Some out_name ->
      let sm_filename = match sm_file with "" -> out_name ^ ".map" | f -> f in
      let sm = Source_map.Standard.{
        version = 3;
        file = Some (Filename.basename out_name);
        sourceroot = None;
        sources = sm_info.sources;
        sources_content = None;
        names = sm_info.names;
        mappings = Source_map.Mappings.encode sm_info.mappings;
        ignore_list = [];
      } in
      Source_map.to_file (Source_map.Standard sm) sm_filename;
      if times () then Format.eprintf "source map written to: %s@." sm_filename
  | Some sm_info, `Inline, _ ->
      (* For inline source maps, we'd append a comment with base64 encoded map *)
      let sm = Source_map.Standard.{
        version = 3;
        file = None;
        sourceroot = None;
        sources = sm_info.sources;
        sources_content = None;
        names = sm_info.names;
        mappings = Source_map.Mappings.encode sm_info.mappings;
        ignore_list = [];
      } in
      let sm_json = Source_map.to_string (Source_map.Standard sm) in
      Format.eprintf "Warning: Inline source maps not yet implemented. Map JSON: %d bytes@." (String.length sm_json)
  | _ -> ());

  if times () then Format.eprintf "output: %a@." Timer.print t

let info =
  Info.make
    ~name:"compile"
    ~doc:"Compile OCaml bytecode to Lua"
    ~description:
      "lua_of_ocaml compile compiles bytecode executables to Lua. By default, \
       compilation is performed in a single pass for both linking and code generation."

let term =
  let f bytecode output_file params include_dirs linkall source_map compact =
    run
      { Cmd_arg.common =
          { Jsoo_cmdline.Arg.debug = { enable = []; disable = [] }
          ; optim = { enable = []; disable = [] }
          ; quiet = false
          ; werror = false
          ; warnings = []
          ; custom_header = None
          }
      ; bytecode
      ; output_file
      ; params
      ; include_dirs = include_dirs @ [ "+stdlib/" ]
      ; linkall
      ; source_map
      ; compact
      }
  in
  Cmdliner.Term.(
    const f $ Cmd_arg.bytecode $ Cmd_arg.output_file
    $ Cmd_arg.params $ Cmd_arg.include_dirs $ Cmd_arg.linkall
    $ Cmd_arg.source_map $ Cmd_arg.compact)

let command = Cmdliner.Cmd.v info term
