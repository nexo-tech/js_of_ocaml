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

(** Lua Code Generation from OCaml IR

    This module generates Lua code from the js_of_ocaml intermediate
    representation (Code.program). It follows a similar pattern to the
    JavaScript and WebAssembly code generators.
*)

open! Stdlib

module L = Lua_ast

(** {2 Code Generation Context} *)

(** Variable mapping context
    Maps OCaml IR variables (Code.Var.t) to Lua identifiers
*)
type var_context =
  { mutable var_map : string Code.Var.Map.t
        (** Maps IR variables to Lua variable names *)
  ; mutable var_counter : int  (** Counter for generating fresh variable names *)
  }

(** Code generation context
    Contains all state needed during code generation
*)
type context =
  { vars : var_context  (** Variable name mapping *)
  ; _debug : bool  (** Enable debug output *)
  }

(** {2 Context Operations} *)

(** Create a new variable context *)
let make_var_context () = { var_map = Code.Var.Map.empty; var_counter = 0 }

(** Create a new code generation context *)
let make_context ~debug = { vars = make_var_context (); _debug = debug }

(** Generate a fresh Lua variable name
    @param ctx Variable context
    @param prefix Optional prefix for the variable name
    @return Fresh variable name
*)
let fresh_var ctx ?(prefix = "v") () =
  let name = prefix ^ string_of_int ctx.var_counter in
  ctx.var_counter <- ctx.var_counter + 1;
  name

(** Get or create Lua variable name for an IR variable
    @param ctx Code generation context
    @param var IR variable
    @return Lua variable name

    Note: This function is not yet used but will be needed in tasks 4.2-4.3
    for expression and statement generation.
*)
let _var_name ctx var =
  match Code.Var.Map.find_opt var ctx.vars.var_map with
  | Some name -> name
  | None ->
      (* Generate fresh name *)
      let name =
        match Code.Var.get_name var with
        | Some n ->
            (* Use the OCaml variable name if available, making it Lua-safe *)
            let lua_safe_name = Lua_reserved.safe_identifier n in
            (* Ensure uniqueness by checking if already used *)
            let rec find_unique base counter =
              let candidate = if counter = 0 then base else base ^ string_of_int counter in
              if Code.Var.Map.exists (fun _ v -> String.equal v candidate) ctx.vars.var_map
              then find_unique base (counter + 1)
              else candidate
            in
            find_unique lua_safe_name 0
        | None -> fresh_var ctx.vars ()
      in
      ctx.vars.var_map <- Code.Var.Map.add var name ctx.vars.var_map;
      name

(** {2 Basic Code Generation} *)

(** Generate a minimal main function
    This creates an empty main function that can be expanded later

    @param ctx Code generation context
    @return Lua program with main function
*)
let generate_main ctx =
  let _ = ctx in
  (* Suppress unused warning *)
  let main_func =
    L.Function_decl ("main", [], false, [ L.Return [ L.Number "0" ] ])
  in
  let call_main = L.Call_stat (L.Call (L.Ident "main", [])) in
  [ main_func; call_main ]

(** {2 Code.program Generation} *)

(** Generate Lua code from OCaml IR program
    This is the main entry point for code generation

    @param program OCaml IR program
    @param debug Enable debug output
    @return Lua program (list of statements)
*)
let generate ~debug program =
  let ctx = make_context ~debug in

  (* For now, just generate minimal structure *)
  (* TODO: Implement full program generation in later tasks *)
  let _ = program in
  (* Suppress unused warning *)

  generate_main ctx

(** Generate Lua code and convert to string
    @param program OCaml IR program
    @param debug Enable debug output
    @return Lua code as string
*)
let generate_to_string ~debug program =
  let lua_program = generate ~debug program in
  Lua_output.program_to_string lua_program
