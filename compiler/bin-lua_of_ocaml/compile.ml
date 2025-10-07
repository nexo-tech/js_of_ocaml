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

let run { Cmd_arg.common; bytecode; output_file; params; include_dirs; linkall } =
  Config.set_target `Wasm;
  Jsoo_cmdline.Arg.eval common;
  Linker.reset ();
  List.iter params ~f:(fun (s, v) -> Config.Param.set s v);

  let t = Timer.make () in
  let include_dirs = List.filter_map include_dirs ~f:(fun d -> Findlib.find [] d) in

  (* Load and link bytecode *)
  let ic = open_in_bin bytecode in
  let bc = Parse_bytecode.from_exe ~includes:include_dirs ic in
  close_in ic;
  let one = bc ~linkall ~link_info:false ~include_cmis:false in
  if times () then Format.eprintf "parsing: %a@." Timer.print t;

  (* Get the program from the bytecode *)
  let p = one.code in

  (* Generate Lua code *)
  let lua_code = Lua_generate.generate ~debug:false p in
  if times () then Format.eprintf "generation: %a@." Timer.print t;

  (* Output to file or stdout *)
  let output formatter =
    Pretty_print.string formatter (Lua_output.program_to_string lua_code)
  in
  (match output_file with
  | `Stdout -> output (Pretty_print.to_out_channel stdout)
  | `Name name ->
      Filename.gen_file name (fun chan ->
          output (Pretty_print.to_out_channel chan)));

  if times () then Format.eprintf "output: %a@." Timer.print t

let info =
  Info.make
    ~name:"compile"
    ~doc:"Compile OCaml bytecode to Lua"
    ~description:
      "lua_of_ocaml compile compiles bytecode executables to Lua. By default, \
       compilation is performed in a single pass for both linking and code generation."

let term =
  let f bytecode output_file params include_dirs linkall =
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
      }
  in
  Cmdliner.Term.(
    const f $ Cmd_arg.bytecode $ Cmd_arg.output_file
    $ Cmd_arg.params $ Cmd_arg.include_dirs $ Cmd_arg.linkall)

let command = Cmdliner.Cmd.v info term
