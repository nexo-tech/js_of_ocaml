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
*)
let var_name ctx var =
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

(** Get Lua identifier expression for a variable
    @param ctx Code generation context
    @param var IR variable
    @return Lua identifier expression
*)
let var_ident ctx var = L.Ident (var_name ctx var)

(** {2 Expression Generation} *)

(** Generate Lua expression from Code constant
    @param const IR constant
    @return Lua expression
*)
let rec generate_constant const =
  match const with
  | Code.String s -> L.String s
  | Code.NativeString ns -> (
      match ns with
      | Code.Native_string.Byte s -> L.String s
      | Code.Native_string.Utf (Utf8_string.Utf8 s) -> L.String s)
  | Code.Float f ->
      (* Float is stored as Int64 bits, convert to float *)
      let fl = Int64.float_of_bits f in
      L.Number (Printf.sprintf "%.17g" fl)
  | Code.Float_array arr ->
      (* Generate array of floats *)
      let fields =
        Array.to_list arr
        |> List.map ~f:(fun f ->
               let fl = Int64.float_of_bits f in
               L.Array_field (L.Number (Printf.sprintf "%.17g" fl)))
      in
      L.Table fields
  | Code.Int i ->
      (* Targetint to string *)
      L.Number (Targetint.to_string i)
  | Code.Int32 i -> L.Number (Int32.to_string i)
  | Code.Int64 i -> L.Number (Int64.to_string i)
  | Code.NativeInt i ->
      (* NativeInt is Int32 on all backends *)
      L.Number (Int32.to_string i)
  | Code.Tuple (tag, arr, _array_or_not) ->
      (* Generate table with tag and fields *)
      let tag_field = L.Rec_field ("tag", L.Number (string_of_int tag)) in
      let fields =
        Array.to_list arr
        |> List.map ~f:(fun c -> L.Array_field (generate_constant c))
      in
      L.Table (tag_field :: fields)

(** Generate Lua expression from Code prim operation
    @param ctx Code generation context
    @param prim Primitive operation
    @param args Primitive arguments (variables or constants)
    @return Lua expression
*)
let generate_prim ctx prim args =
  let arg_exprs =
    List.map args ~f:(fun arg ->
        match arg with
        | Code.Pv v -> var_ident ctx v
        | Code.Pc c -> generate_constant c)
  in
  match prim, arg_exprs with
  (* Unary operations *)
  | Code.Not, [ e ] -> L.UnOp (L.Not, e)
  | Code.IsInt, [ e ] ->
      (* In Lua, check if value is a number with no fractional part *)
      L.BinOp
        ( L.And
        , L.BinOp (L.Eq, L.Call (L.Ident "type", [ e ]), L.String "number")
        , L.BinOp (L.Eq, L.BinOp (L.Mod, e, L.Number "1"), L.Number "0") )
  (* Binary comparison operations *)
  | Code.Eq, [ e1; e2 ] -> L.BinOp (L.Eq, e1, e2)
  | Code.Neq, [ e1; e2 ] -> L.BinOp (L.Neq, e1, e2)
  | Code.Lt, [ e1; e2 ] -> L.BinOp (L.Lt, e1, e2)
  | Code.Le, [ e1; e2 ] -> L.BinOp (L.Le, e1, e2)
  | Code.Ult, [ e1; e2 ] ->
      (* Unsigned less than - treat as signed for now *)
      L.BinOp (L.Lt, e1, e2)
  (* Array/table operations *)
  | Code.Vectlength, [ e ] ->
      (* Length operator in Lua *)
      L.UnOp (L.Len, e)
  | Code.Array_get, [ arr; idx ] ->
      (* Array access: arr[idx + 1] (Lua is 1-indexed) *)
      L.Index (arr, L.BinOp (L.Add, idx, L.Number "1"))
  (* External primitive call *)
  | Code.Extern name, args ->
      (* Call external primitive function *)
      let prim_func = L.Ident ("caml_" ^ name) in
      L.Call (prim_func, args)
  (* Fallback for other cases *)
  | _ ->
      (* Generate runtime call for unhandled primitives *)
      let prim_name =
        match prim with
        | Code.Vectlength -> "vectlength"
        | Code.Array_get -> "array_get"
        | Code.Extern s -> s
        | Code.Not -> "not"
        | Code.IsInt -> "is_int"
        | Code.Eq -> "eq"
        | Code.Neq -> "neq"
        | Code.Lt -> "lt"
        | Code.Le -> "le"
        | Code.Ult -> "ult"
      in
      L.Call (L.Ident ("caml_prim_" ^ prim_name), arg_exprs)

(** Generate Lua expression from Code expression
    @param ctx Code generation context
    @param expr IR expression
    @return Lua expression
*)
let generate_expr ctx expr =
  match expr with
  | Code.Constant c -> generate_constant c
  | Code.Apply { f; args; exact = _ } ->
      (* Function application *)
      let func_expr = var_ident ctx f in
      let arg_exprs = List.map ~f:(var_ident ctx) args in
      L.Call (func_expr, arg_exprs)
  | Code.Block (tag, arr, _array_or_not, _mutability) ->
      (* Block construction - create table with tag *)
      let tag_field = L.Rec_field ("tag", L.Number (string_of_int tag)) in
      let fields =
        Array.to_list arr
        |> List.map ~f:(fun v -> L.Array_field (var_ident ctx v))
      in
      L.Table (tag_field :: fields)
  | Code.Field (v, idx, _field_type) ->
      (* Field access: v[idx + 1] (adjust for Lua 1-indexing) *)
      let obj = var_ident ctx v in
      L.Index (obj, L.Number (string_of_int (idx + 1)))
  | Code.Closure _ ->
      (* Closure generation - placeholder for now *)
      (* Will be fully implemented when we handle function definitions *)
      L.Ident "caml_closure"
  | Code.Prim (prim, args) -> generate_prim ctx prim args
  | Code.Special _ ->
      (* Special forms - placeholder *)
      L.Ident "caml_special"

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
