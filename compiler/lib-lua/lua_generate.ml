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
  ; program : Code.program option  (** Full program for closure generation *)
  ; optimize_field_access : bool  (** Enable field access optimization *)
  ; mutable use_var_table : bool
        (** Use table-based variable storage instead of locals.
            Set to true when function needs >180 hoisted variables.
            When true: generates _V.v0 = expr
            When false: generates v0 = expr *)
  }

(** {2 Context Operations} *)

(** Create a new variable context *)
let make_var_context () = { var_map = Code.Var.Map.empty; var_counter = 0 }

(** Create a new code generation context *)
let make_context ~debug =
  { vars = make_var_context ()
  ; _debug = debug
  ; program = None
  ; optimize_field_access = true
  ; use_var_table = false  (* Default to locals, set to true in hoisting logic if needed *)
  }

(** Create a context with program for closure generation *)
let make_context_with_program ~debug program =
  { vars = make_var_context ()
  ; _debug = debug
  ; program = Some program
  ; optimize_field_access = true
  ; use_var_table = false  (* Default to locals, set to true in hoisting logic if needed *)
  }

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

(** {2 Variable Table Utilities} *)

(** Name of the variable table used for functions with >180 locals

    Lua has a hard limit of 200 local variables per function. When we need more
    than 180 hoisted variables (leaving room for ~20 other locals like exception
    names, loop vars, etc.), we use a single table to store all variables instead.

    This bypasses Lua's limit since table fields are unlimited.
*)
let var_table_name = "_V"

(** Threshold for switching to table-based variable storage

    Lua limit: 200 locals per function
    Reserved for: exception names (~12), loop vars/temps (~8)
    Safety margin: 20
    Therefore: 200 - 20 = 180 max hoisted variables before using table
*)
let var_table_threshold = 180

(** Determine if a function should use table-based variable storage

    @param var_count Number of variables that need to be hoisted
    @return true if var_count > 180 (should use _V table), false otherwise

    When true: Generate `local _V = {}; _V.v0 = 42`
    When false: Generate `local v0, v1, ...; v0 = 42`
*)
let should_use_var_table var_count = var_count > var_table_threshold

(** Create table field access expression for a variable

    @param var_name The variable name (e.g., "v0")
    @return Lua expression `_V.var_name` (e.g., `_V.v0`)

    Used when function has >180 variables and needs table-based storage.
*)
let make_var_table_access var_name = L.Dot (L.Ident var_table_name, var_name)

(** Get Lua identifier expression for a variable
    @param ctx Code generation context
    @param var IR variable
    @return Lua identifier expression (or table field access if use_var_table=true)
*)
let var_ident ctx var =
  let name = var_name ctx var in
  if ctx.use_var_table then
    make_var_table_access name
  else
    L.Ident name

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
  (* External primitive call - map common operations to Lua operators *)
  | Code.Extern name, args -> (
      match name, args with
      (* Integer arithmetic operations *)
      | "add", [ e1; e2 ] -> L.BinOp (L.Add, e1, e2)
      | "sub", [ e1; e2 ] -> L.BinOp (L.Sub, e1, e2)
      | "mul", [ e1; e2 ] -> L.BinOp (L.Mul, e1, e2)
      | "div", [ e1; e2 ] ->
          (* Integer division in Lua 5.3+ *)
          L.BinOp (L.IDiv, e1, e2)
      | "mod", [ e1; e2 ] -> L.BinOp (L.Mod, e1, e2)
      (* Int32/NativeInt operations (aliases for int operations) *)
      | "int32_add", [ e1; e2 ] -> L.BinOp (L.Add, e1, e2)
      | "int32_sub", [ e1; e2 ] -> L.BinOp (L.Sub, e1, e2)
      | "int32_mul", [ e1; e2 ] -> L.BinOp (L.Mul, e1, e2)
      | "int32_div", [ e1; e2 ] -> L.BinOp (L.IDiv, e1, e2)
      | "int32_mod", [ e1; e2 ] -> L.BinOp (L.Mod, e1, e2)
      | "nativeint_add", [ e1; e2 ] -> L.BinOp (L.Add, e1, e2)
      | "nativeint_sub", [ e1; e2 ] -> L.BinOp (L.Sub, e1, e2)
      | "nativeint_mul", [ e1; e2 ] -> L.BinOp (L.Mul, e1, e2)
      | "nativeint_div", [ e1; e2 ] -> L.BinOp (L.IDiv, e1, e2)
      | "nativeint_mod", [ e1; e2 ] -> L.BinOp (L.Mod, e1, e2)
      (* Floating point arithmetic *)
      | "float_add", [ e1; e2 ] -> L.BinOp (L.Add, e1, e2)
      | "float_sub", [ e1; e2 ] -> L.BinOp (L.Sub, e1, e2)
      | "float_mul", [ e1; e2 ] -> L.BinOp (L.Mul, e1, e2)
      | "float_div", [ e1; e2 ] -> L.BinOp (L.Div, e1, e2)
      | "float_mod", [ e1; e2 ] -> L.BinOp (L.Mod, e1, e2)
      | "float_pow", [ e1; e2 ] -> L.BinOp (L.Pow, e1, e2)
      (* Unary operations *)
      | "neg", [ e ] -> L.UnOp (L.Neg, e)
      | "int32_neg", [ e ] -> L.UnOp (L.Neg, e)
      | "nativeint_neg", [ e ] -> L.UnOp (L.Neg, e)
      | "float_neg", [ e ] -> L.UnOp (L.Neg, e)
      (* Bitwise operations (Lua 5.3+) *)
      | "and", [ e1; e2 ] -> L.BinOp (L.BAnd, e1, e2)
      | "or", [ e1; e2 ] -> L.BinOp (L.BOr, e1, e2)
      | "xor", [ e1; e2 ] -> L.BinOp (L.BXor, e1, e2)
      | "lsl", [ e1; e2 ] -> L.BinOp (L.Shl, e1, e2)
      | "lsr", [ e1; e2 ] -> L.BinOp (L.Shr, e1, e2)
      | "asr", [ e1; e2 ] -> L.BinOp (L.Shr, e1, e2) (* arithmetic shift right *)
      | "int32_and", [ e1; e2 ] -> L.BinOp (L.BAnd, e1, e2)
      | "int32_or", [ e1; e2 ] -> L.BinOp (L.BOr, e1, e2)
      | "int32_xor", [ e1; e2 ] -> L.BinOp (L.BXor, e1, e2)
      | "int32_lsl", [ e1; e2 ] -> L.BinOp (L.Shl, e1, e2)
      | "int32_lsr", [ e1; e2 ] -> L.BinOp (L.Shr, e1, e2)
      | "int32_asr", [ e1; e2 ] -> L.BinOp (L.Shr, e1, e2)
      | "nativeint_and", [ e1; e2 ] -> L.BinOp (L.BAnd, e1, e2)
      | "nativeint_or", [ e1; e2 ] -> L.BinOp (L.BOr, e1, e2)
      | "nativeint_xor", [ e1; e2 ] -> L.BinOp (L.BXor, e1, e2)
      | "nativeint_lsl", [ e1; e2 ] -> L.BinOp (L.Shl, e1, e2)
      | "nativeint_lsr", [ e1; e2 ] -> L.BinOp (L.Shr, e1, e2)
      | "nativeint_asr", [ e1; e2 ] -> L.BinOp (L.Shr, e1, e2)
      (* Integer comparison *)
      | "int_compare", [ e1; e2 ] ->
          (* Returns -1, 0, or 1 *)
          L.Call
            ( L.Ident "caml_int_compare"
            , [ e1; e2 ] )
      | "int32_compare", [ e1; e2 ] ->
          L.Call (L.Ident "caml_int32_compare", [ e1; e2 ])
      | "nativeint_compare", [ e1; e2 ] ->
          L.Call (L.Ident "caml_nativeint_compare", [ e1; e2 ])
      (* Float comparison *)
      | "float_compare", [ e1; e2 ] ->
          L.Call (L.Ident "caml_float_compare", [ e1; e2 ])
      (* Greater than comparisons *)
      | "gt", [ e1; e2 ] -> L.BinOp (L.Gt, e1, e2)
      | "ge", [ e1; e2 ] -> L.BinOp (L.Ge, e1, e2)
      (* Type conversions *)
      | "int_of_float", [ e ] ->
          L.Call (L.Ident "math.floor", [ e ])
      | "float_of_int", [ e ] ->
          (* In Lua, numbers are already float-compatible *)
          e
      (* String operations *)
      | "ml_string_length", [ e ] ->
          (* String length in Lua *)
          L.UnOp (L.Len, e)
      | "string_concat", [ e1; e2 ] ->
          (* String concatenation *)
          L.BinOp (L.Concat, e1, e2)
      | "string_compare", [ e1; e2 ] ->
          (* String comparison returns -1, 0, or 1 *)
          L.Call (L.Ident "caml_string_compare", [ e1; e2 ])
      | "string_equal", [ e1; e2 ] ->
          (* String equality *)
          L.BinOp (L.Eq, e1, e2)
      | "string_notequal", [ e1; e2 ] ->
          (* String inequality *)
          L.BinOp (L.Neq, e1, e2)
      | "string_lessthan", [ e1; e2 ] ->
          (* String less than *)
          L.BinOp (L.Lt, e1, e2)
      | "string_lessequal", [ e1; e2 ] ->
          (* String less than or equal *)
          L.BinOp (L.Le, e1, e2)
      | "string_greaterthan", [ e1; e2 ] ->
          (* String greater than *)
          L.BinOp (L.Gt, e1, e2)
      | "string_greaterequal", [ e1; e2 ] ->
          (* String greater than or equal *)
          L.BinOp (L.Ge, e1, e2)
      | "string_unsafe_get", [ str; idx ] ->
          (* Get character at index - Lua uses string.byte *)
          L.Call (L.Ident "string.byte", [ str; L.BinOp (L.Add, idx, L.Number "1") ])
      | "string_get", [ str; idx ] ->
          (* Get character at index with bounds check *)
          L.Call (L.Ident "caml_string_get", [ str; idx ])
      | "string_unsafe_set", [ str; idx; char ] ->
          (* String set - immutable in Lua, needs runtime support *)
          L.Call (L.Ident "caml_string_unsafe_set", [ str; idx; char ])
      | "string_set", [ str; idx; char ] ->
          (* String set with bounds check *)
          L.Call (L.Ident "caml_string_set", [ str; idx; char ])
      | "bytes_unsafe_get", [ bytes; idx ] ->
          (* Bytes get - similar to string *)
          L.Call (L.Ident "string.byte", [ bytes; L.BinOp (L.Add, idx, L.Number "1") ])
      | "bytes_get", [ bytes; idx ] ->
          (* Bytes get with bounds check *)
          L.Call (L.Ident "caml_bytes_get", [ bytes; idx ])
      | "bytes_unsafe_set", [ bytes; idx; char ] ->
          (* Bytes set *)
          L.Call (L.Ident "caml_bytes_unsafe_set", [ bytes; idx; char ])
      | "bytes_set", [ bytes; idx; char ] ->
          (* Bytes set with bounds check *)
          L.Call (L.Ident "caml_bytes_set", [ bytes; idx; char ])
      | "create_string", [ len ] ->
          (* Create string of given length *)
          L.Call (L.Ident "caml_create_string", [ len ])
      | "create_bytes", [ len ] ->
          (* Create bytes of given length *)
          L.Call (L.Ident "caml_create_bytes", [ len ])
      | "bytes_to_string", [ bytes ] ->
          (* Convert bytes to string - identity in Lua *)
          bytes
      | "bytes_of_string", [ str ] ->
          (* Convert string to bytes - identity in Lua *)
          str
      (* String manipulation *)
      | "string_sub", [ str; offset; len ] ->
          (* Substring extraction *)
          L.Call
            ( L.Ident "string.sub"
            , [ str; L.BinOp (L.Add, offset, L.Number "1"); L.BinOp (L.Add, L.BinOp (L.Add, offset, len), L.Number "0") ] )
      | "bytes_sub", [ bytes; offset; len ] ->
          (* Bytes substring *)
          L.Call
            ( L.Ident "string.sub"
            , [ bytes; L.BinOp (L.Add, offset, L.Number "1"); L.BinOp (L.Add, L.BinOp (L.Add, offset, len), L.Number "0") ] )
      | "fill_bytes", [ bytes; offset; len; char ] ->
          (* Fill bytes with character *)
          L.Call (L.Ident "caml_fill_bytes", [ bytes; offset; len; char ])
      | "blit_string", [ src; src_pos; dst; dst_pos; len ] ->
          (* Copy from string to bytes *)
          L.Call (L.Ident "caml_blit_string", [ src; src_pos; dst; dst_pos; len ])
      | "blit_bytes", [ src; src_pos; dst; dst_pos; len ] ->
          (* Copy from bytes to bytes *)
          L.Call (L.Ident "caml_blit_bytes", [ src; src_pos; dst; dst_pos; len ])
      (* Array operations *)
      | "array_get", [ arr; idx ] ->
          (* Array access with 1-based indexing *)
          L.Index (arr, L.BinOp (L.Add, idx, L.Number "1"))
      | "array_set", [ arr; idx; value ] ->
          (* Array set - needs to return unit, use runtime call *)
          L.Call (L.Ident "caml_array_set", [ arr; idx; value ])
      | "array_unsafe_get", [ arr; idx ] ->
          (* Unsafe array access *)
          L.Index (arr, L.BinOp (L.Add, idx, L.Number "1"))
      | "array_unsafe_set", [ arr; idx; value ] ->
          (* Unsafe array set *)
          L.Call (L.Ident "caml_array_unsafe_set", [ arr; idx; value ])
      | "make_vect", [ len; init ] ->
          (* Create array of given length initialized with value *)
          L.Call (L.Ident "caml_make_vect", [ len; init ])
      | "array_make", [ len; init ] ->
          (* Create array - alias for make_vect *)
          L.Call (L.Ident "caml_array_make", [ len; init ])
      | "make_float_vect", [ len ] ->
          (* Create float array *)
          L.Call (L.Ident "caml_make_float_vect", [ len ])
      | "floatarray_create", [ len ] ->
          (* Create float array (OCaml 5.3+) *)
          L.Call (L.Ident "caml_floatarray_create", [ len ])
      | "array_length", [ arr ] ->
          (* Array length - use Lua length operator *)
          L.UnOp (L.Len, arr)
      | "array_sub", [ arr; offset; len ] ->
          (* Array slice *)
          L.Call (L.Ident "caml_array_sub", [ arr; offset; len ])
      | "array_append", [ arr1; arr2 ] ->
          (* Array concatenation *)
          L.Call (L.Ident "caml_array_append", [ arr1; arr2 ])
      | "array_concat", [ arrs ] ->
          (* Concatenate list of arrays *)
          L.Call (L.Ident "caml_array_concat", [ arrs ])
      | "array_blit", [ src; src_pos; dst; dst_pos; len ] ->
          (* Copy array slice *)
          L.Call (L.Ident "caml_array_blit", [ src; src_pos; dst; dst_pos; len ])
      | "array_fill", [ arr; offset; len; value ] ->
          (* Fill array with value *)
          L.Call (L.Ident "caml_array_fill", [ arr; offset; len; value ])
      | "floatarray_get", [ arr; idx ] ->
          (* Float array get *)
          L.Index (arr, L.BinOp (L.Add, idx, L.Number "1"))
      | "floatarray_set", [ arr; idx; value ] ->
          (* Float array set *)
          L.Call (L.Ident "caml_floatarray_set", [ arr; idx; value ])
      | "floatarray_unsafe_get", [ arr; idx ] ->
          (* Unsafe float array get *)
          L.Index (arr, L.BinOp (L.Add, idx, L.Number "1"))
      | "floatarray_unsafe_set", [ arr; idx; value ] ->
          (* Unsafe float array set *)
          L.Call (L.Ident "caml_floatarray_unsafe_set", [ arr; idx; value ])
      (* Reference operations - refs are represented as single-element arrays/tables *)
      | "ref", [ value ] ->
          (* Create reference - table with one field *)
          L.Table [ L.Array_field value ]
      | "ref_get", [ ref ] ->
          (* Dereference - get field 1 *)
          L.Index (ref, L.Number "1")
      | "ref_set", [ ref; value ] ->
          (* Reference assignment - needs runtime call to return unit *)
          L.Call (L.Ident "caml_ref_set", [ ref; value ])
      (* Weak reference operations *)
      | "weak_create", [ len ] ->
          (* Create weak array *)
          L.Call (L.Ident "caml_weak_create", [ len ])
      | "weak_get", [ weak; idx ] ->
          (* Get from weak array *)
          L.Call (L.Ident "caml_weak_get", [ weak; idx ])
      | "weak_set", [ weak; idx; value ] ->
          (* Set in weak array *)
          L.Call (L.Ident "caml_weak_set", [ weak; idx; value ])
      | "weak_check", [ weak; idx ] ->
          (* Check if weak reference is alive *)
          L.Call (L.Ident "caml_weak_check", [ weak; idx ])
      (* I/O operations - file descriptors and channels *)
      | "caml_sys_open", [ name; flags; perms ] ->
          (* Open file and return file descriptor *)
          L.Call (L.Ident "caml_sys_open", [ name; flags; perms ])
      | "caml_sys_close", [ fd ] ->
          (* Close file descriptor *)
          L.Call (L.Ident "caml_sys_close", [ fd ])
      | "caml_ml_open_descriptor_in", [ fd ] ->
          (* Create input channel from file descriptor *)
          L.Call (L.Ident "caml_ml_open_descriptor_in", [ fd ])
      | "caml_ml_open_descriptor_out", [ fd ] ->
          (* Create output channel from file descriptor *)
          L.Call (L.Ident "caml_ml_open_descriptor_out", [ fd ])
      | "caml_ml_open_descriptor_in_with_flags", [ fd; flags ] ->
          (* Create input channel from file descriptor with flags (OCaml 5.1+) *)
          L.Call (L.Ident "caml_ml_open_descriptor_in_with_flags", [ fd; flags ])
      | "caml_ml_open_descriptor_out_with_flags", [ fd; flags ] ->
          (* Create output channel from file descriptor with flags (OCaml 5.1+) *)
          L.Call (L.Ident "caml_ml_open_descriptor_out_with_flags", [ fd; flags ])
      | "caml_ml_close_channel", [ chan ] ->
          (* Close channel *)
          L.Call (L.Ident "caml_ml_close_channel", [ chan ])
      | "caml_ml_flush", [ chan ] ->
          (* Flush output channel *)
          L.Call (L.Ident "caml_ml_flush", [ chan ])
      (* Input operations *)
      | "caml_ml_input_char", [ chan ] ->
          (* Read single character from input channel *)
          L.Call (L.Ident "caml_ml_input_char", [ chan ])
      | "caml_ml_input", [ chan; buf; offset; len ] ->
          (* Read bytes into buffer *)
          L.Call (L.Ident "caml_ml_input", [ chan; buf; offset; len ])
      | "caml_ml_input_int", [ chan ] ->
          (* Read binary integer *)
          L.Call (L.Ident "caml_ml_input_int", [ chan ])
      | "caml_ml_input_scan_line", [ chan ] ->
          (* Scan for newline in input buffer *)
          L.Call (L.Ident "caml_ml_input_scan_line", [ chan ])
      | "caml_input_value", [ chan ] ->
          (* Read marshaled value *)
          L.Call (L.Ident "caml_input_value", [ chan ])
      | "caml_input_value_to_outside_heap", [ chan ] ->
          (* Read marshaled value (OCaml 5.0+) *)
          L.Call (L.Ident "caml_input_value_to_outside_heap", [ chan ])
      (* Output operations *)
      | "caml_ml_output_char", [ chan; c ] ->
          (* Write single character to output channel *)
          L.Call (L.Ident "caml_ml_output_char", [ chan; c ])
      | "caml_ml_output", [ chan; buf; offset; len ] ->
          (* Write string to output channel *)
          L.Call (L.Ident "caml_ml_output", [ chan; buf; offset; len ])
      | "caml_ml_output_bytes", [ chan; buf; offset; len ] ->
          (* Write bytes to output channel *)
          L.Call (L.Ident "caml_ml_output_bytes", [ chan; buf; offset; len ])
      | "caml_ml_output_int", [ chan; i ] ->
          (* Write binary integer *)
          L.Call (L.Ident "caml_ml_output_int", [ chan; i ])
      | "caml_output_value", [ chan; v; flags ] ->
          (* Write marshaled value *)
          L.Call (L.Ident "caml_output_value", [ chan; v; flags ])
      (* Channel positioning *)
      | "caml_ml_seek_in", [ chan; pos ] ->
          (* Seek in input channel *)
          L.Call (L.Ident "caml_ml_seek_in", [ chan; pos ])
      | "caml_ml_seek_in_64", [ chan; pos ] ->
          (* Seek in input channel (64-bit) *)
          L.Call (L.Ident "caml_ml_seek_in_64", [ chan; pos ])
      | "caml_ml_seek_out", [ chan; pos ] ->
          (* Seek in output channel *)
          L.Call (L.Ident "caml_ml_seek_out", [ chan; pos ])
      | "caml_ml_seek_out_64", [ chan; pos ] ->
          (* Seek in output channel (64-bit) *)
          L.Call (L.Ident "caml_ml_seek_out_64", [ chan; pos ])
      | "caml_ml_pos_in", [ chan ] ->
          (* Get input channel position *)
          L.Call (L.Ident "caml_ml_pos_in", [ chan ])
      | "caml_ml_pos_in_64", [ chan ] ->
          (* Get input channel position (64-bit) *)
          L.Call (L.Ident "caml_ml_pos_in_64", [ chan ])
      | "caml_ml_pos_out", [ chan ] ->
          (* Get output channel position *)
          L.Call (L.Ident "caml_ml_pos_out", [ chan ])
      | "caml_ml_pos_out_64", [ chan ] ->
          (* Get output channel position (64-bit) *)
          L.Call (L.Ident "caml_ml_pos_out_64", [ chan ])
      | "caml_ml_channel_size", [ chan ] ->
          (* Get channel size *)
          L.Call (L.Ident "caml_ml_channel_size", [ chan ])
      | "caml_ml_channel_size_64", [ chan ] ->
          (* Get channel size (64-bit) *)
          L.Call (L.Ident "caml_ml_channel_size_64", [ chan ])
      (* Channel configuration *)
      | "caml_ml_set_binary_mode", [ chan; mode ] ->
          (* Set binary mode *)
          L.Call (L.Ident "caml_ml_set_binary_mode", [ chan; mode ])
      | "caml_ml_is_binary_mode", [ chan ] ->
          (* Check if channel is in binary mode (OCaml 5.2+) *)
          L.Call (L.Ident "caml_ml_is_binary_mode", [ chan ])
      | "caml_ml_set_channel_name", [ chan; name ] ->
          (* Set channel name *)
          L.Call (L.Ident "caml_ml_set_channel_name", [ chan; name ])
      | "caml_channel_descriptor", [ chan ] ->
          (* Get file descriptor from channel *)
          L.Call (L.Ident "caml_channel_descriptor", [ chan ])
      | "caml_ml_out_channels_list", [] ->
          (* Get list of all output channels *)
          L.Call (L.Ident "caml_ml_out_channels_list", [])
      | "caml_ml_is_buffered", [ chan ] ->
          (* Check if channel is buffered *)
          L.Call (L.Ident "caml_ml_is_buffered", [ chan ])
      | "caml_ml_set_buffered", [ chan; v ] ->
          (* Set channel buffering *)
          L.Call (L.Ident "caml_ml_set_buffered", [ chan; v ])
      (* Default: call external primitive function *)
      | _, args ->
          (* Don't add caml_ prefix if name already starts with caml_ *)
          let prim_name =
            if String.starts_with ~prefix:"caml_" name then
              name
            else
              "caml_" ^ name
          in
          let prim_func = L.Ident prim_name in
          L.Call (prim_func, args))
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

(** {2 Record and Variant Optimizations} *)

(** Optimize field access for records
    Instead of using numeric indexing, use direct field access when beneficial
    @param ctx Code generation context
    @param obj Object expression
    @param idx Field index
    @return Optimized Lua expression
*)
let optimize_field_access ctx obj idx =
  if ctx.optimize_field_access
  then
    (* Use direct array indexing (Lua arrays are 1-indexed) *)
    L.Index (obj, L.Number (string_of_int (idx + 1)))
  else L.Index (obj, L.Number (string_of_int (idx + 1)))

(** Generate optimized block construction
    @param tag Block tag
    @param fields Field values
    @return Lua table expression
*)
let optimize_block_construction tag fields =
  (* Always use tag field for efficient variant discrimination *)
  let tag_field = L.Rec_field ("tag", L.Number (string_of_int tag)) in
  L.Table (tag_field :: fields)

(** {2 Expression and Statement Generation (mutually recursive with control flow)} *)

(** Generate Lua expression from Code expression
    @param ctx Code generation context
    @param expr IR expression
    @return Lua expression
*)
let rec generate_expr ctx expr =
  match expr with
  | Code.Constant c -> generate_constant c
  | Code.Apply { f; args; exact = _ } ->
      (* Function application *)
      let func_expr = var_ident ctx f in
      let arg_exprs = List.map ~f:(var_ident ctx) args in
      L.Call (func_expr, arg_exprs)
  | Code.Block (tag, arr, _array_or_not, _mutability) ->
      (* Block construction - create table with tag (optimized) *)
      let fields =
        Array.to_list arr
        |> List.map ~f:(fun v -> L.Array_field (var_ident ctx v))
      in
      optimize_block_construction tag fields
  | Code.Field (v, idx, _field_type) ->
      (* Field access - optimized for efficient access *)
      let obj = var_ident ctx v in
      optimize_field_access ctx obj idx
  | Code.Closure (params, (pc, _args), _loc) ->
      (* Generate function closure *)
      generate_closure ctx params pc
  | Code.Prim (prim, args) -> generate_prim ctx prim args
  | Code.Special _ ->
      (* Special forms - placeholder *)
      L.Ident "caml_special"

(** {2 Statement Generation} *)

(** Generate Lua statement from Code instruction
    @param ctx Code generation context
    @param instr IR instruction
    @return Lua statement
*)
and generate_instr ctx instr =
  match instr with
  | Code.Let (var, expr) ->
      (* Generate assignment (variables are hoisted at function start or in _V table) *)
      let target = var_ident ctx var in
      let lua_expr = generate_expr ctx expr in
      L.Assign ([ target ], [ lua_expr ])
  | Code.Assign (target, source) ->
      (* Generate assignment statement *)
      let target_ident = var_ident ctx target in
      let source_ident = var_ident ctx source in
      L.Assign ([ target_ident ], [ source_ident ])
  | Code.Set_field (obj, idx, _field_type, value) ->
      (* Generate field assignment: obj[idx+1] = value *)
      let obj_expr = var_ident ctx obj in
      let idx_expr = L.Number (string_of_int (idx + 1)) in
      let field_expr = L.Index (obj_expr, idx_expr) in
      let value_expr = var_ident ctx value in
      L.Assign ([ field_expr ], [ value_expr ])
  | Code.Offset_ref (var, offset) ->
      (* Generate reference offset: var[1] = var[1] + offset *)
      let var_expr = var_ident ctx var in
      let field_expr = L.Index (var_expr, L.Number "1") in
      let current_val = L.Index (var_expr, L.Number "1") in
      let offset_expr = L.Number (string_of_int offset) in
      let new_val = L.BinOp (L.Add, current_val, offset_expr) in
      L.Assign ([ field_expr ], [ new_val ])
  | Code.Array_set (arr, idx, value) ->
      (* Generate array assignment: arr[idx+1] = value *)
      let arr_expr = var_ident ctx arr in
      let idx_var = var_ident ctx idx in
      let idx_adjusted = L.BinOp (L.Add, idx_var, L.Number "1") in
      let elem_expr = L.Index (arr_expr, idx_adjusted) in
      let value_expr = var_ident ctx value in
      L.Assign ([ elem_expr ], [ value_expr ])
  | Code.Event info ->
      (* Events are debugging information - emit as location hint *)
      L.Location_hint info

(** Generate Lua statements from a list of Code instructions
    @param ctx Code generation context
    @param instrs List of IR instructions
    @return List of Lua statements
*)
and generate_instrs ctx instrs =
  List.map ~f:(generate_instr ctx) instrs

(** {2 Unified Block Compilation with Labels} *)

(** Collect all variables used in reachable blocks
    Returns set of variable names that need to be hoisted to avoid Lua goto/scope issues.

    This function traverses all reachable blocks and collects variables from Let and Assign
    instructions. These variables will be hoisted to the function start to allow safe
    goto statements without violating Lua's scoping rules.

    @param ctx Code generation context
    @param program Full IR program
    @param start_addr Starting block address
    @return Set of variable names (v_N format) that need hoisting
*)
and collect_block_variables ctx program start_addr =
  (* Collect variables from a single instruction *)
  let collect_instr_vars acc = function
    | Code.Let (var, _expr) ->
        (* Let introduces a new variable *)
        StringSet.add (var_name ctx var) acc
    | Code.Assign (var, _expr) ->
        (* Assign may introduce a variable if not already defined *)
        StringSet.add (var_name ctx var) acc
    | Code.Set_field _ | Code.Offset_ref _ | Code.Array_set _ | Code.Event _ ->
        (* These don't introduce new variables *)
        acc
  in
  (* Collect all reachable blocks (reuse existing logic) *)
  let rec collect_reachable visited addr =
    if Code.Addr.Set.mem addr visited
    then visited
    else
      match Code.Addr.Map.find_opt addr program.Code.blocks with
      | None -> visited
      | Some block ->
          let visited = Code.Addr.Set.add addr visited in
          let successors =
            match block.Code.branch with
            | Code.Branch (next, _) -> [ next ]
            | Code.Cond (_, (t, _), (f, _)) -> [ t; f ]
            | Code.Switch (_, conts) -> Array.to_list conts |> List.map ~f:fst
            | Code.Pushtrap ((c, _), _, (h, _)) -> [ c; h ]
            | Code.Poptrap (a, _) -> [ a ]
            | Code.Return _ | Code.Raise _ | Code.Stop -> []
          in
          List.fold_left ~f:collect_reachable ~init:visited successors
  in
  let reachable = collect_reachable Code.Addr.Set.empty start_addr in
  (* Collect variables from all reachable blocks *)
  Code.Addr.Set.fold
    (fun addr acc ->
      match Code.Addr.Map.find_opt addr program.Code.blocks with
      | None -> acc
      | Some block -> List.fold_left ~f:collect_instr_vars ~init:acc block.Code.body)
    reachable
    StringSet.empty

(** Compile all reachable blocks with labels and gotos (unified approach)
    This is the single unified function that all code generation paths use.

    @param ctx Code generation context
    @param program Full IR program
    @param start_addr Starting block address
    @return List of Lua statements with labels and gotos
*)
and compile_blocks_with_labels ctx program start_addr =
  (* Collect all variables that need hoisting *)
  let hoisted_vars = collect_block_variables ctx program start_addr in

  (* Determine if we need table-based storage and set context accordingly *)
  let total_vars = StringSet.cardinal hoisted_vars in
  let use_table = should_use_var_table total_vars in
  ctx.use_var_table <- use_table;

  (* Generate variable declaration statements *)
  let hoist_stmts =
    if StringSet.is_empty hoisted_vars
    then []
    else if use_table then
      (* Use table-based storage for >180 variables *)
      [ L.Comment (Printf.sprintf "Hoisted variables (%d total, using table due to Lua's 200 local limit)" total_vars)
      ; L.Local ([ var_table_name ], Some [ L.Table [] ])  (* local _V = {} *)
      ]
    else
      (* Use local declarations for ≤180 variables *)
      let var_list = StringSet.elements hoisted_vars |> List.sort ~cmp:String.compare in
      [ L.Comment (Printf.sprintf "Hoisted variables (%d total)" total_vars)
      ; L.Local (var_list, None)
      ]
  in

  (* Collect all reachable blocks from start *)
  let rec collect_reachable visited addr =
    if Code.Addr.Set.mem addr visited
    then visited
    else
      match Code.Addr.Map.find_opt addr program.Code.blocks with
      | None -> visited
      | Some block ->
          let visited = Code.Addr.Set.add addr visited in
          let successors =
            match block.Code.branch with
            | Code.Branch (next, _) -> [ next ]
            | Code.Cond (_, (t, _), (f, _)) -> [ t; f ]
            | Code.Switch (_, conts) -> Array.to_list conts |> List.map ~f:fst
            | Code.Pushtrap ((c, _), _, (h, _)) -> [ c; h ]
            | Code.Poptrap (a, _) -> [ a ]
            | Code.Return _ | Code.Raise _ | Code.Stop -> []
          in
          List.fold_left ~f:collect_reachable ~init:visited successors
  in
  let reachable = collect_reachable Code.Addr.Set.empty start_addr in

  (* Build list of blocks sorted by address *)
  let sorted_blocks = reachable |> Code.Addr.Set.elements |> List.sort ~cmp:compare in

  (* Generate code for each block with fall-through optimization *)
  let block_stmts =
    sorted_blocks
    |> List.mapi ~f:(fun idx addr ->
         match Code.Addr.Map.find_opt addr program.Code.blocks with
         | None -> []
         | Some block ->
             let label = L.Label ("block_" ^ Code.Addr.to_string addr) in
             let body = generate_instrs ctx block.Code.body in
             (* Check if this block can fall through to the next *)
             let can_fall_through =
               match block.Code.branch with
               | Code.Branch (next, _) ->
                   (* Fall through if next block is sequential (addr + 1) *)
                   next = addr + 1
                   && (* And the next block is in our sorted list at the next position *)
                   idx + 1 < List.length sorted_blocks
                   && List.nth sorted_blocks (idx + 1) = next
               | _ -> false
             in
             let terminator =
               if can_fall_through
               then [] (* Omit goto, let it fall through *)
               else generate_last ctx block.Code.branch
             in
             [ label ] @ body @ terminator)
    |> List.concat
  in

  (* Return hoisted declarations + blocks *)
  hoist_stmts @ block_stmts

(** {2 Function/Closure Generation} *)

(** Generate Lua function from closure using unified block compilation

    Each closure gets its own independent context to decide whether to use
    table-based storage or locals. This allows nested functions with >180 vars
    to use _V tables while their parents use locals (or vice versa).

    @param ctx Code generation context (parent)
    @param params Parameter list
    @param pc Program counter pointing to function body
    @return Lua function expression
*)
and generate_closure ctx params pc =
  match ctx.program with
  | None ->
      (* No program context - return placeholder *)
      L.Ident "caml_closure"
  | Some program -> (
      match Code.Addr.Map.find_opt pc program.Code.blocks with
      | None ->
          (* Block not found - return placeholder *)
          L.Ident "caml_closure"
      | Some _block ->
          (* Create new context for closure - each closure is independent *)
          let closure_ctx = make_context_with_program ~debug:ctx._debug program in

          (* Generate parameter names using the closure's context *)
          let param_names = List.map ~f:(var_name closure_ctx) params in

          (* compile_blocks_with_labels will:
             1. Collect variables in this closure's blocks
             2. Decide independently if use_var_table should be set
             3. Generate either `local _V = {}` or `local v0, v1, ...`
             Each closure gets its own _V table if needed (>180 vars) *)
          let body_stmts = compile_blocks_with_labels closure_ctx program pc in

          L.Function (param_names, false, body_stmts))

(** Generate Lua last statement from Code last (terminator) using gotos
    @param ctx Code generation context
    @param last IR terminator
    @return List of Lua statements
*)
and generate_last ctx last =
  match last with
  | Code.Return var ->
      let lua_expr = var_ident ctx var in
      [ L.Return [ lua_expr ] ]
  | Code.Raise (var, _raise_kind) ->
      let lua_expr = var_ident ctx var in
      [ L.Call_stat (L.Call (L.Ident "error", [ lua_expr ])) ]
  | Code.Stop -> [ L.Return [ L.Nil ] ]
  | Code.Branch (addr, _args) ->
      let label = "block_" ^ Code.Addr.to_string addr in
      [ L.Goto label ]
  | Code.Cond (var, (addr_true, _), (addr_false, _)) ->
      let cond_expr = var_ident ctx var in
      let true_label = "block_" ^ Code.Addr.to_string addr_true in
      let false_label = "block_" ^ Code.Addr.to_string addr_false in
      [ L.If (cond_expr, [ L.Goto true_label ], Some [ L.Goto false_label ]) ]
  | Code.Switch (var, conts) ->
      let switch_var = var_ident ctx var in
      let cases =
        Array.to_list conts
        |> List.mapi ~f:(fun idx (addr, _) ->
            let label = "block_" ^ Code.Addr.to_string addr in
            let cond = L.BinOp (L.Eq, switch_var, L.Number (string_of_int idx)) in
            (cond, [ L.Goto label ]))
      in
      (match cases with
      | [] -> []
      | (cond, then_stmt) :: rest ->
          let rec build_if_chain = function
            | [] -> then_stmt
            | (c, t) :: rest -> [ L.If (c, t, Some (build_if_chain rest)) ]
          in
          [ L.If (cond, then_stmt, Some (build_if_chain rest)) ])
  | Code.Pushtrap ((cont_addr, _), _var, (_handler_addr, _)) ->
      (* For now, just goto continuation - proper exception handling TODO *)
      let label = "block_" ^ Code.Addr.to_string cont_addr in
      [ L.Goto label ]
  | Code.Poptrap (addr, _) ->
      let label = "block_" ^ Code.Addr.to_string addr in
      [ L.Goto label ]

(** Generate Lua block from Code block
    @param ctx Code generation context
    @param block IR block
    @return List of Lua statements
*)
let generate_block ctx block =
  let body_stmts = generate_instrs ctx block.Code.body in
  let last_stmts = generate_last ctx block.Code.branch in
  body_stmts @ last_stmts

(** {2 Code.program Generation} *)

(** Count local variable declarations in a list of statements

    @param stmts List of statements
    @return Number of local variable declarations
*)
let rec count_locals stmts =
  let count_in_block block = count_locals block in
  List.fold_left
    ~f:(fun acc stmt ->
      match stmt with
      | L.Local (vars, _) -> acc + List.length vars
      | L.If (_, then_block, Some else_block) ->
          acc + count_in_block then_block + count_in_block else_block
      | L.If (_, then_block, None) -> acc + count_in_block then_block
      | L.While (_, block) -> acc + count_in_block block
      | L.Repeat (block, _) -> acc + count_in_block block
      | L.For_num (_, _, _, _, block) -> acc + count_in_block block
      | L.For_in (_, _, block) -> acc + count_in_block block
      | L.Function_decl (_, _, _, block) -> acc + count_in_block block
      | L.Local_function (_, _, _, block) -> acc + count_in_block block
      | L.Block block -> acc + count_in_block block
      | _ -> acc)
    ~init:0
    stmts

(** Split statements into chunks based on local variable count
    Lua has a limit of 200 local variables per function. We chunk at 150
    to provide a safety margin.

    @param stmts List of statements to chunk
    @param max_locals Maximum locals per chunk (default: 150)
    @return List of statement chunks
*)
let chunk_statements ?(max_locals = 150) stmts =
  let rec chunk_helper current_chunk current_count remaining =
    match remaining with
    | [] ->
        (match current_chunk with
        | [] -> []
        | _ -> [List.rev current_chunk])
    | stmt :: rest ->
        let stmt_locals =
          match stmt with
          | L.Local (vars, _) -> List.length vars
          | _ -> 0
        in
        (* If adding this statement would exceed limit, start new chunk *)
        if current_count > 0 && current_count + stmt_locals > max_locals then
          List.rev current_chunk :: chunk_helper [stmt] stmt_locals rest
        else
          chunk_helper (stmt :: current_chunk) (current_count + stmt_locals) rest
  in
  chunk_helper [] 0 stmts

(** Generate module initialization code with variable chunking
    This creates the entry point that initializes the module.
    If there are more than 150 local variables, splits them across multiple
    __caml_init_chunk_N functions to avoid Lua's 200 local variable limit.
    Uses unified block compilation strategy.

    @param ctx Code generation context
    @param program OCaml IR program
    @return Lua statements for module initialization
*)
let generate_module_init ctx program =
  (* Use unified block compilation starting from entry point *)
  let all_stmts = compile_blocks_with_labels ctx program program.Code.start in

  (* Count local variables in generated code *)
  let local_count = count_locals all_stmts in

  (* If under limit, generate single function *)
  if local_count <= 150 then
    let init_func =
      L.Function_decl
        ( "__caml_init__"
        , []
        , false
        , [ L.Comment "Module initialization code" ] @ all_stmts )
    in
    [ init_func; L.Call_stat (L.Call (L.Ident "__caml_init__", [])) ]
  else begin
    (* Too many locals - need to chunk *)
    let chunks = chunk_statements ~max_locals:150 all_stmts in
    let num_chunks = List.length chunks in

    (* Generate chunk functions *)
    let chunk_funcs =
      List.mapi ~f:
        (fun i chunk_stmts ->
          let chunk_name = Printf.sprintf "__caml_init_chunk_%d" i in
          let comment =
            if i = 0 then
              Printf.sprintf "Module initialization code (chunk %d/%d)" (i + 1) num_chunks
            else
              Printf.sprintf "Module initialization code (chunk %d/%d, continued)" (i + 1) num_chunks
          in
          L.Function_decl
            ( chunk_name
            , []
            , false
            , [ L.Comment comment ] @ chunk_stmts ))
        chunks
    in

    (* Generate main init function that calls all chunks *)
    let chunk_calls =
      List.init ~len:num_chunks ~f:(fun i ->
        let chunk_name = Printf.sprintf "__caml_init_chunk_%d" i in
        L.Call_stat (L.Call (L.Ident chunk_name, [])))
    in

    let main_init_func =
      L.Function_decl
        ( "__caml_init__"
        , []
        , false
        , [ L.Comment
              (Printf.sprintf
                 "Module initialization (calling %d chunks to avoid 200 local variable limit)"
                 num_chunks) ]
          @ chunk_calls )
    in

    (* Return all chunk functions, main init, and call to main init *)
    chunk_funcs @ [ main_init_func; L.Call_stat (L.Call (L.Ident "__caml_init__", [])) ]
  end

(** Generate minimal inline runtime
    Provides essential runtime functions for standalone execution

    @return List of Lua statements defining runtime functions
*)

(** Collect all primitives used in a program

    Traverses the program IR to find all external primitives (Code.Extern)
    that are called. These primitives will need runtime implementations or wrappers.

    @param program OCaml IR program
    @return Set of primitive names (with caml_ prefix)
*)
let collect_used_primitives (program : Code.program) : StringSet.t =
  (* Collect primitives from an expression *)
  let collect_expr acc = function
    | Code.Constant _ -> acc
    | Code.Apply { f = _; args = _; _ } ->
        (* Function application - no primitives to collect *)
        acc
    | Code.Block (_, _arr, _, _) ->
        (* Block construction - no primitives to collect *)
        acc
    | Code.Field (_, _, _) -> acc
    | Code.Closure _ -> acc
    | Code.Prim (prim, _args) ->
        (* This is where we find external primitives *)
        (match prim with
        | Code.Extern name ->
            (* External primitive - add to set with caml_ prefix if needed *)
            let prim_name =
              if String.starts_with ~prefix:"caml_" name
              then name
              else "caml_" ^ name
            in
            StringSet.add prim_name acc
        | _ -> acc)
    | Code.Special _ -> acc
  in
  (* Collect primitives from an instruction *)
  let collect_instr acc = function
    | Code.Let (_, expr) -> collect_expr acc expr
    | Code.Assign _ -> acc
    | Code.Set_field (_, _, _, _) -> acc
    | Code.Offset_ref (_, _) -> acc
    | Code.Array_set (_, _, _) -> acc
    | Code.Event _ -> acc
  in
  (* Traverse all blocks in the program *)
  Code.Addr.Map.fold
    (fun _ block acc -> List.fold_left ~f:collect_instr ~init:acc block.Code.body)
    program.Code.blocks
    StringSet.empty

(** Debug: Print Code.program IR structure for debugging

    This function prints detailed information about the IR that the code generator
    receives, helping diagnose why execution code might be missing.

    @param program Code IR program to debug
*)
let debug_print_program program =
  if Debug.find "ir" () then begin
    Printf.eprintf "\n=== Code.program IR Debug ===\n";
    Printf.eprintf "Entry block: %s\n" (Code.Addr.to_string program.Code.start);
    Printf.eprintf "Total blocks: %d\n" (Code.Addr.Map.cardinal program.Code.blocks);

    (* Print entry block details *)
    (match Code.Addr.Map.find_opt program.Code.start program.Code.blocks with
    | Some block ->
        Printf.eprintf "\nEntry block instructions (%d):\n" (List.length block.Code.body);
        List.iteri ~f:(fun i instr ->
          let buf = Buffer.create 100 in
          let fmt = Format.formatter_of_buffer buf in
          Code.Print.instr fmt instr;
          Format.pp_print_flush fmt ();
          Printf.eprintf "  %d: %s\n" i (Buffer.contents buf)
        ) block.Code.body;

        let term_buf = Buffer.create 100 in
        let term_fmt = Format.formatter_of_buffer term_buf in
        Code.Print.last term_fmt block.Code.branch;
        Format.pp_print_flush term_fmt ();
        Printf.eprintf "Entry block terminator: %s\n" (Buffer.contents term_buf)
    | None ->
        Printf.eprintf "ERROR: Entry block not found!\n");

    (* Print all blocks summary *)
    Printf.eprintf "\nAll blocks summary:\n";
    Code.Addr.Map.iter (fun addr block ->
      let term_buf = Buffer.create 100 in
      let term_fmt = Format.formatter_of_buffer term_buf in
      Code.Print.last term_fmt block.Code.branch;
      Format.pp_print_flush term_fmt ();
      Printf.eprintf "  Block %s: %d instrs, term: %s\n"
        (Code.Addr.to_string addr)
        (List.length block.Code.body)
        (Buffer.contents term_buf)
    ) program.Code.blocks;
    Printf.eprintf "=== End IR Debug ===\n\n"
  end

let generate_inline_runtime () =
  [
    L.Comment "=== OCaml Runtime (Minimal Inline Version) ===";
    L.Comment "Global storage for OCaml values";
    L.Local ([ "_OCAML_GLOBALS" ], Some [ L.Table [] ]);
    L.Comment "";
    L.Comment "caml_register_global: Register a global OCaml value";
    L.Comment "  n: global index";
    L.Comment "  v: value to register";
    L.Comment "  name: optional string name for the global";
    L.Function_decl
      ( "caml_register_global"
      , [ "n"; "v"; "name" ]
      , false
      , [ L.Comment "Store value at index n+1 (Lua 1-indexed)";
          L.Assign
            ( [ L.Index (L.Ident "_OCAML_GLOBALS", L.BinOp (L.Add, L.Ident "n", L.Number "1")) ]
            , [ L.Ident "v" ] );
          L.Comment "Also store by name if provided";
          L.If
            ( L.Ident "name"
            , [ L.Assign
                  ( [ L.Index (L.Ident "_OCAML_GLOBALS", L.Ident "name") ]
                  , [ L.Ident "v" ] )
              ]
            , None );
          L.Comment "Return the value for chaining";
          L.Return [ L.Ident "v" ]
        ] );
    L.Comment "";
    L.Comment "=== End Runtime ==="
  ]

(** Generate standalone program
    Creates a complete Lua program that can be executed directly

    @param ctx Code generation context
    @param program OCaml IR program
    @return Lua statements for standalone program
*)
let generate_standalone ctx program =
  (* Debug: Print IR structure if debug flag enabled *)
  debug_print_program program;
  (* 1. Track which primitives are used *)
  let used_primitives = collect_used_primitives program in

  (* 2. Load runtime modules *)
  let runtime_dir = "runtime/lua" in
  let fragments =
    try Lua_link.load_runtime_dir runtime_dir
    with Sys_error _ ->
      (* Runtime directory not found - continue without runtime modules *)
      []
  in

  (* 3. Find fragments that provide used primitives (using hybrid strategy) *)
  let needed_fragments_set =
    StringSet.fold
      (fun prim_name acc ->
        match Lua_link.find_primitive_implementation prim_name fragments with
        | Some (frag, _func_name) -> StringSet.add frag.Lua_link.name acc
        | None -> acc  (* Primitive not found - might be inlined *)
      )
      used_primitives
      StringSet.empty
  in

  (* 4. Resolve dependencies between needed fragments *)
  let sorted_fragments =
    if List.length fragments = 0 || StringSet.is_empty needed_fragments_set
    then []
    else
      let state =
        List.fold_left
          ~f:Lua_link.add_fragment
          ~init:(Lua_link.init ())
          fragments
      in
      let sorted_fragment_names, _missing =
        Lua_link.resolve_deps state (StringSet.elements needed_fragments_set)
      in
      List.filter_map
        ~f:(fun name ->
          List.find_opt ~f:(fun f -> String.equal f.Lua_link.name name) fragments)
        sorted_fragment_names
  in

  (* 5. Generate code in order:
     - Inline runtime (caml_register_global)
     - Runtime modules (embedded)
     - Global wrappers (generated from used_primitives)
     - Program code *)
  let inline_runtime = generate_inline_runtime () in
  let embedded_modules =
    List.map ~f:Lua_link.embed_runtime_module sorted_fragments
    |> List.map ~f:(fun code -> L.Comment code)
  in
  let wrappers_code = Lua_link.generate_wrappers used_primitives fragments in
  let wrappers =
    if String.length wrappers_code = 0
    then []
    else [ L.Comment wrappers_code ]
  in
  let program_code = generate_module_init ctx program in

  inline_runtime @ [ L.Comment "" ] @ embedded_modules @ wrappers @ [ L.Comment "" ] @ program_code

(** Generate module code for separate compilation
    Creates module code that can be loaded via require()
    Uses unified block compilation strategy.

    @param ctx Code generation context
    @param program OCaml IR program
    @param module_name Module name for exports
    @return Lua statements for module
*)
let generate_module ctx program module_name =
  (* Use unified block compilation starting from entry point *)
  let init_code = compile_blocks_with_labels ctx program program.Code.start in

  (* Create module table *)
  let module_var = "M" in
  let module_init = [ L.Local ([ module_var ], Some [ L.Table [] ]) ] in

  (* Export module table *)
  let module_export = [ L.Return [ L.Ident module_var ] ] in

  [ L.Comment ("Module: " ^ module_name) ]
  @ module_init
  @ init_code
  @ module_export

(** Generate Lua code from OCaml IR program
    This is the main entry point for code generation

    @param program OCaml IR program
    @param debug Enable debug output
    @return Lua program (list of statements)
*)
let generate ~debug program = generate_standalone (make_context_with_program ~debug program) program

(** Generate Lua module code
    Entry point for separate module compilation

    @param program OCaml IR program
    @param debug Enable debug output
    @param module_name Module name
    @return Lua program (list of statements)
*)
let generate_module_code ~debug ~module_name program =
  let ctx = make_context_with_program ~debug program in
  generate_module ctx program module_name

(** Generate Lua code and convert to string
    @param program OCaml IR program
    @param debug Enable debug output
    @return Lua code as string
*)
let generate_to_string ~debug program =
  let lua_program = generate ~debug program in
  Lua_output.program_to_string lua_program
