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
  ; inherit_var_table : bool
        (** If true, this is a nested closure that inherits parent's _V table.
            When true: don't create 'local _V = {}', use parent's _V as upvalue *)
  }

(** {2 Debug Flags} *)

(** Enable debug output for variable collection *)
let debug_var_collect = ref false

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
  ; inherit_var_table = false  (* Top-level context doesn't inherit *)
  }

(** Create a context with program for closure generation *)
let make_context_with_program ~debug program =
  { vars = make_var_context ()
  ; _debug = debug
  ; program = Some program
  ; optimize_field_access = true
  ; use_var_table = false  (* Default to locals, set to true in hoisting logic if needed *)
  ; inherit_var_table = false  (* Top-level function doesn't inherit *)
  }

(** Create a child context for closure generation that inherits parent's variable mappings
    This allows closures to reference variables from enclosing scopes (captured as upvalues in Lua)
    @param parent_ctx Parent context to inherit variable mappings from
    @param program Program for the child context
    @return New context with inherited variable mappings
*)
let make_child_context parent_ctx program =
  let parent_uses_table = parent_ctx.use_var_table in
  { vars =
      { var_map = parent_ctx.vars.var_map  (* Inherit parent's variable mappings *)
      ; var_counter = parent_ctx.vars.var_counter  (* Continue parent's counter *)
      }
  ; _debug = parent_ctx._debug
  ; program = Some program
  ; optimize_field_access = parent_ctx.optimize_field_access
  ; use_var_table = parent_uses_table  (* Inherit parent's table usage *)
  ; inherit_var_table = parent_uses_table  (* If parent uses table, inherit it *)
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

(** Optimize field access for block fields
    @param ctx Code generation context
    @param obj Object expression
    @param idx Field index
    @return Optimized Lua expression
*)
let optimize_field_access ctx obj idx =
  if ctx.optimize_field_access
  then
    (* Block fields are at index idx+2 (Lua 1-indexed, tag at index 1) *)
    L.Index (obj, L.Number (string_of_int (idx + 2)))
  else L.Index (obj, L.Number (string_of_int (idx + 2)))

(** Optimize block construction by converting to array-like table
    @param tag Block tag (for variants/constructors)
    @param fields List of field expressions
    @return Lua table expression
*)
let optimize_block_construction tag fields =
  (* Create array-like table with tag at index 1, matching JavaScript representation *)
  (* In JavaScript: [tag, field1, field2, ...]
     In Lua: {tag, field1, field2, ...} (1-indexed) *)
  let tag_element = L.Array_field (L.Number (string_of_int tag)) in
  L.Table (tag_element :: fields)

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
      (* Generate array-like table with tag at index 1 *)
      (* Matching JavaScript: [tag, field1, field2, ...] *)
      let tag_element = L.Array_field (L.Number (string_of_int tag)) in
      let fields =
        Array.to_list arr
        |> List.map ~f:(fun c -> L.Array_field (generate_constant c))
      in
      L.Table (tag_element :: fields)

(** Generate Lua expression from Code prim operation
    @param ctx Code generation context
    @param prim Primitive operation
    @param args Primitive arguments (variables or constants)
    @return Lua expression
*)
and generate_prim ctx prim args =
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
          (* Check if this is an inline primitive (starts with %) *)
          if String.starts_with ~prefix:"%" name then
            (* Inline primitives - generate direct Lua code instead of function calls *)
            let inline_name = String.sub name ~pos:1 ~len:(String.length name - 1) in
            (match inline_name, args with
            (* Integer arithmetic inline operations *)
            | "int_add", [ e1; e2 ] -> L.BinOp (L.Add, e1, e2)
            | "int_sub", [ e1; e2 ] -> L.BinOp (L.Sub, e1, e2)
            | "int_mul", [ e1; e2 ] -> L.BinOp (L.Mul, e1, e2)
            | "int_div", [ e1; e2 ] ->
                (* Integer division - use math.floor(a/b) for Lua 5.1 *)
                L.Call (L.Ident "math.floor", [ L.BinOp (L.Div, e1, e2) ])
            | "int_mod", [ e1; e2 ] -> L.BinOp (L.Mod, e1, e2)
            | "int_neg", [ e ] -> L.UnOp (L.Neg, e)
            (* Bitwise inline operations *)
            (* For Lua 5.1 compatibility, we implement these using math operations *)
            | "int_and", [ e1; e2 ] ->
                (* Bitwise AND using modulo trick for small values *)
                (* TODO: Move to runtime for full 32-bit support *)
                L.Call (L.Ident "caml_int_and", [ e1; e2 ])
            | "int_or", [ e1; e2 ] ->
                L.Call (L.Ident "caml_int_or", [ e1; e2 ])
            | "int_xor", [ e1; e2 ] ->
                L.Call (L.Ident "caml_int_xor", [ e1; e2 ])
            | "int_lsl", [ e1; e2 ] ->
                (* Left shift: a << b = a * (2^b) *)
                L.BinOp (L.Mul, e1, L.BinOp (L.Pow, L.Number "2", e2))
            | "int_lsr", [ e1; e2 ] ->
                (* Logical right shift: a >> b = floor(a / (2^b)) *)
                L.Call (L.Ident "math.floor",
                  [ L.BinOp (L.Div, e1, L.BinOp (L.Pow, L.Number "2", e2)) ])
            | "int_asr", [ e1; e2 ] ->
                (* Arithmetic right shift - for now same as logical *)
                L.Call (L.Ident "math.floor",
                  [ L.BinOp (L.Div, e1, L.BinOp (L.Pow, L.Number "2", e2)) ])
            (* Direct object operations *)
            | "direct_obj_tag", [ e ] ->
                (* Get tag from block: block[1] or 0 if not a block *)
                (* Blocks are arrays with tag at index 1 *)
                L.BinOp (L.Or,
                  L.Index (e, L.Number "1"),
                  L.Number "0")
            (* Fallback for unknown inline primitives *)
            | _ ->
                (* Generate call with caml_ prefix *)
                L.Call (L.Ident ("caml_" ^ inline_name), args))
          else
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

(** {2 Expression and Statement Generation (mutually recursive with control flow)} *)

(** Generate Lua expression from Code expression
    @param ctx Code generation context
    @param expr IR expression
    @return Lua expression
*)
and generate_expr ctx expr =
  match expr with
  | Code.Constant c -> generate_constant c
  | Code.Apply { f; args; exact } ->
      (* Function application - handle partial application like js_of_ocaml *)
      let func_expr = var_ident ctx f in
      let arg_exprs = List.map ~f:(var_ident ctx) args in
      if exact
      then
        (* Direct call (exact=true) - we know we have the right number of arguments
           Call function directly: f(args)
           Works for both:
           - Wrapped closures via __call metatable: {l=arity, [1]=fn} callable as f(args)
           - Primitive runtime functions: plain Lua functions callable as f(args) *)
        L.Call (func_expr, arg_exprs)
      else
        (* Non-exact call - use caml_call_gen to handle partial application
           Note: Conditional optimization (Tier 2) is handled at statement level
           in generate_instr for Let instructions *)
        L.Call (L.Ident "caml_call_gen", [ func_expr; L.Table (List.map ~f:(fun e -> L.Array_field e) arg_exprs) ])
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
  | Code.Closure (params, (pc, block_args), _loc) ->
      (* Generate function closure with entry block arguments *)
      generate_closure ctx params pc block_args
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
  | Code.Let (var, Code.Apply { f; args; exact = false }) ->
      (* Non-exact Apply: always use caml_call_gen

         The "fast path" optimization (caml_call1/2/3) doesn't work because
         the IR sometimes has argument order issues where blocks/channels are
         passed instead of functions. caml_call_gen handles all cases correctly
         including currying, under-application, and over-application.

         Note: JS backend can use caml_callN because it has different IR processing.
         For Lua, conservative approach is safer until IR issues are resolved.
      *)
      let target = var_ident ctx var in
      let func_expr = var_ident ctx f in
      let arg_exprs = List.map ~f:(var_ident ctx) args in

      (* Always use caml_call_gen for safety *)
      let call_expr =
        L.Call
          ( L.Ident "caml_call_gen"
          , [ func_expr; L.Table (List.map ~f:(fun e -> L.Array_field e) arg_exprs) ] )
      in
      L.Assign ([ target ], [ call_expr ])
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

(** {2 Loop Detection} *)

(** Find blocks that provide initial values for entry block parameters
    When an entry block has parameters, we need to find where those parameters
    get their initial values from. This is typically a block that jumps to the
    entry with arguments.

    @param program The Code.program
    @param entry_addr The entry block address
    @return Option of (initializer_addr, args) or None
*)
and find_entry_initializer program entry_addr =
  (* Look for blocks that jump to entry_addr with arguments *)
  Code.Addr.Map.fold (fun addr block acc ->
    (* Skip the entry block itself *)
    if addr = entry_addr then acc
    else
      match block.Code.branch with
      | Code.Branch (target, args) when target = entry_addr && not (List.is_empty args) ->
          (* Found a branch to entry with arguments *)
          Some (addr, args)
      | Code.Cond (_, (t1, args1), (t2, args2)) ->
          if t1 = entry_addr && not (List.is_empty args1) then
            Some (addr, args1)
          else if t2 = entry_addr && not (List.is_empty args2) then
            Some (addr, args2)
          else acc
      | Code.Switch (_, cases) ->
          (* Check switch cases for jumps to entry with args *)
          Array.fold_left cases ~init:acc ~f:(fun acc (target, args) ->
            if target = entry_addr && not (List.is_empty args) then
              Some (addr, args)
            else acc)
      | _ -> acc
  ) program.Code.blocks None

(** Detect loop headers by finding back edges in the control flow graph.
    A back edge is when a block jumps to a block that's already in the path to it.
    Returns a set of loop header addresses (blocks that are jump targets of back edges).

    This matches js_of_ocaml's approach in generate.ml where loops are detected
    during traversal to handle block argument initialization properly. *)
and detect_loop_headers program entry_addr =
  let rec find_back_edges visited path current_addr acc =
    if Code.Addr.Set.mem current_addr path then
      (* Found a back edge - current_addr is a loop header *)
      Code.Addr.Set.add current_addr acc
    else if Code.Addr.Set.mem current_addr visited then
      (* Already processed this block *)
      acc
    else
      let visited = Code.Addr.Set.add current_addr visited in
      match Code.Addr.Map.find_opt current_addr program.Code.blocks with
      | None -> acc
      | Some block ->
          (* Add current block to path for detecting back edges *)
          let path = Code.Addr.Set.add current_addr path in
          (* Get successor blocks from branch instruction *)
          let successors =
            match block.Code.branch with
            | Code.Return _ | Code.Raise _ | Code.Stop -> []
            | Code.Branch (addr, _) -> [addr]
            | Code.Cond (_, (addr1, _), (addr2, _)) -> [addr1; addr2]
            | Code.Switch (_, cases) ->
                List.map ~f:(fun (addr, _) -> addr) (Array.to_list cases)
            | Code.Pushtrap ((addr1, _), _, (addr2, _)) -> [addr1; addr2]
            | Code.Poptrap (addr, _) -> [addr]
          in
          List.fold_left successors ~init:acc ~f:(fun acc addr ->
            find_back_edges visited path addr acc)
  in
  find_back_edges Code.Addr.Set.empty Code.Addr.Set.empty entry_addr Code.Addr.Set.empty

(** {2 Unified Block Compilation with Labels} *)

(** Collect all variables used in reachable blocks
    Returns set of variable names that need to be hoisted to avoid Lua goto/scope issues.

    IMPORTANT: For optimized IR with forward references, this must collect:
    1. Variables ASSIGNED in this function (Let/Assign)
    2. Variables REFERENCED in expressions (for closure capture)
    3. Variables used by ALL descendant closures (recursive collection)

    CRITICAL CHANGE: This function is now RECURSIVE across closure boundaries.
    When encountering nested closures, it recursively collects variables from
    their bodies. This ensures parent functions collect ALL variables needed by
    ANY descendant closure, solving the "sibling closure" problem where closure A
    references variables assigned by sibling closure B.

    @param ctx Code generation context
    @param program Full IR program
    @param start_addr Starting block address
    @return Set of variable names (v_N format) that need hoisting
*)
and collect_block_variables ctx program start_addr =
  (* FIXED: Only collect variables DEFINED in this function's blocks.
     DO NOT collect:
     - Captured variables from closures (they come from parent scope)
     - Variables from nested closure bodies (they have their own scope)

     This matches JavaScript's behavior where each function has its own scope. *)

  (* Only collect variables DEFINED by instructions *)
  let collect_defined_vars acc = function
    | Code.Let (var, _expr) ->
        (* Variable is defined by Let - add it *)
        StringSet.add (var_name ctx var) acc
    | Code.Assign (var, _source) ->
        (* Variable is defined by assignment - add left side only *)
        StringSet.add (var_name ctx var) acc
    | Code.Set_field _ | Code.Array_set _ | Code.Offset_ref _ | Code.Event _ ->
        (* These don't define new variables *)
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
  (* Collect variables from all reachable blocks (body AND branch) *)
  Code.Addr.Set.fold
    (fun addr acc ->
      match Code.Addr.Map.find_opt addr program.Code.blocks with
      | None -> acc
      | Some block ->
          (* Only collect variables DEFINED in this block *)
          List.fold_left ~f:collect_defined_vars ~init:acc block.Code.body)
    reachable
    StringSet.empty

(** Compile all reachable blocks with dispatch loop (Lua 5.1 compatible)
    This is the single unified function that all code generation paths use.
    Uses a while loop with numeric dispatch instead of goto/labels for Lua 5.1 compatibility.

    @param ctx Code generation context
    @param program Full IR program
    @param start_addr Starting block address
    @return List of Lua statements with dispatch loop
*)
and compile_blocks_with_labels ctx program start_addr ?(params = []) () =
  (* Collect all variables that need hoisting *)
  let hoisted_vars = collect_block_variables ctx program start_addr in

  (* Detect loop headers to identify block arguments that need initialization *)
  let loop_headers = detect_loop_headers program start_addr in

  (* Collect block parameters from loop headers that need initialization
     These are variables that are accessed before being defined in loops *)
  let loop_block_params =
    Code.Addr.Set.fold
      (fun addr acc ->
        match Code.Addr.Map.find_opt addr program.Code.blocks with
        | None -> acc
        | Some block ->
            (* Add all block parameters from loop headers to hoisted vars *)
            List.fold_left block.Code.params ~init:acc ~f:(fun acc param ->
              StringSet.add (var_name ctx param) acc))
      loop_headers
      StringSet.empty
  in

  (* Get the entry block's parameters - these will be initialized by argument passing *)
  let entry_block_params =
    match Code.Addr.Map.find_opt start_addr program.Code.blocks with
    | None -> StringSet.empty
    | Some block ->
        List.fold_left block.Code.params ~init:StringSet.empty ~f:(fun acc param ->
          StringSet.add (var_name ctx param) acc)
  in

  (* Combine regular hoisted vars with loop block parameters *)
  let all_hoisted_vars = StringSet.union hoisted_vars loop_block_params in

  (* DEBUG: Print collected variables *)
  if !debug_var_collect then
    Format.eprintf "DEBUG collect_block_variables at addr %d: collected %d vars, %d loop params: %s@."
      start_addr
      (StringSet.cardinal hoisted_vars)
      (StringSet.cardinal loop_block_params)
      (String.concat ~sep:", " (StringSet.elements all_hoisted_vars));

  (* Determine if we need table-based storage and set context accordingly *)
  let total_vars = StringSet.cardinal all_hoisted_vars in
  let use_table =
    if ctx.inherit_var_table then
      (* If inheriting parent's _V table, keep parent's use_var_table setting *)
      ctx.use_var_table
    else
      (* Otherwise, decide based on this function's variable count *)
      should_use_var_table total_vars
  in
  ctx.use_var_table <- use_table;

  (* Generate variable declaration statements *)
  let hoist_stmts =
    if StringSet.is_empty all_hoisted_vars
    then []
    else if use_table then
      if ctx.inherit_var_table then
        (* Inheriting parent's _V table - still need to initialize new variables
           This is REQUIRED for loop block parameters and forward references
           BUT exclude entry block params which will be initialized by argument passing *)
        let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params in
        let init_stmts =
          StringSet.elements vars_to_init
          |> List.map ~f:(fun var ->
              (* _V.var = nil - initialize in parent's table *)
              L.Assign ([ L.Dot (L.Ident var_table_name, var) ], [ L.Nil ]))
        in
        L.Comment (Printf.sprintf "Hoisted variables (%d total, using inherited _V table)" total_vars)
        :: init_stmts
      else
        (* Create new _V table for this function and initialize all fields to nil
           This is REQUIRED for optimized IR which may have forward references where
           closures are created before variables they reference are assigned.
           See PARTIAL.md Task 6.1.2 for full analysis.
           BUT exclude entry block params which will be initialized by argument passing *)
        let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params in
        let init_stmts =
          StringSet.elements vars_to_init
          |> List.map ~f:(fun var ->
              (* _V.var = nil *)
              L.Assign ([ L.Dot (L.Ident var_table_name, var) ], [ L.Nil ]))
        in
        [ L.Comment (Printf.sprintf "Hoisted variables (%d total, using table due to Lua's 200 local limit)" total_vars)
        ; L.Local ([ var_table_name ], Some [ L.Table [] ])  (* local _V = {} *)
        ] @ init_stmts
    else
      (* Use local declarations for ≤180 variables
         BUT exclude entry block params which will be initialized by argument passing *)
      let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params in
      let var_list = StringSet.elements vars_to_init |> List.sort ~cmp:String.compare in
      if StringSet.is_empty vars_to_init then
        [ L.Comment (Printf.sprintf "Hoisted variables (%d total)" total_vars) ]
      else
        [ L.Comment (Printf.sprintf "Hoisted variables (%d total)" total_vars)
        ; L.Local (var_list, None)
        ]
  in

  (* Generate parameter copy statements if using _V table *)
  let param_copy_stmts =
    if use_table && not (List.is_empty params) then
      (* Copy parameters from function locals to _V table *)
      List.map params ~f:(fun param ->
          let param_name = var_name ctx param in
          (* _V.param_name = param_name *)
          L.Assign
            ( [ L.Dot (L.Ident var_table_name, param_name) ]
            , [ L.Ident param_name ] ))
    else
      []
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

  (* Generate code for each block with dispatch-based control flow (Lua 5.1 compatible) *)
  let block_cases =
    sorted_blocks
    |> List.map ~f:(fun addr ->
         match Code.Addr.Map.find_opt addr program.Code.blocks with
         | None -> (addr, [])
         | Some block ->
             let body = generate_instrs ctx block.Code.body in
             let terminator = generate_last_dispatch ctx block.Code.branch in
             (addr, body @ terminator))
  in

  (* Build dispatch loop using if-elseif chain *)
  let dispatch_loop =
    match block_cases with
    | [] -> []
    | _ ->
        (* Check if entry block has parameters that need initialization *)
        let entry_block_opt = Code.Addr.Map.find_opt start_addr program.Code.blocks in
        let entry_has_params =
          match entry_block_opt with
          | Some block -> not (List.is_empty block.Code.params)
          | None -> false
        in

        (* Determine the actual starting block *)
        let actual_start_addr, extra_init_stmts =
          if entry_has_params then
            (* Entry block has parameters - need special handling *)
            match find_entry_initializer program start_addr with
            | Some (init_addr, _) ->
                (* Found an initializer block - start there instead *)
                if !debug_var_collect then
                  Format.eprintf "Entry block %d has params, starting at initializer block %d@."
                    start_addr init_addr;
                (init_addr, [])
            | None ->
                (* No initializer found - start at entry but initialize params to nil *)
                if !debug_var_collect then
                  Format.eprintf "Entry block %d has params but no initializer found, initializing to nil@."
                    start_addr;
                match entry_block_opt with
                | Some block ->
                    let param_inits = List.map block.Code.params ~f:(fun param ->
                      let param_name = var_name ctx param in
                      if use_table then
                        L.Assign ([L.Dot (L.Ident var_table_name, param_name)], [L.Nil])
                      else
                        L.Assign ([L.Ident param_name], [L.Nil])
                    ) in
                    (start_addr, param_inits)
                | None -> (start_addr, [])
          else
            (* Normal case - no parameters, start at entry *)
            (start_addr, [])
        in

        (* Initialize dispatch variable to start address *)
        let init_stmt = L.Local (["_next_block"], Some [L.Number (string_of_int actual_start_addr)]) in

        (* Build if-elseif chain for block dispatch *)
        let rec build_dispatch_chain = function
          | [] -> [ L.Break ]  (* No matching block, exit loop *)
          | [(addr, body)] ->
              (* Last block - no else needed *)
              let cond = L.BinOp (L.Eq, L.Ident "_next_block", L.Number (string_of_int addr)) in
              [ L.If (cond, body, Some [ L.Break ]) ]
          | (addr, body) :: rest ->
              let cond = L.BinOp (L.Eq, L.Ident "_next_block", L.Number (string_of_int addr)) in
              [ L.If (cond, body, Some (build_dispatch_chain rest)) ]
        in

        let dispatch_body = build_dispatch_chain block_cases in

        (* Wrap in while true do ... end loop *)
        extra_init_stmts @ [ init_stmt
        ; L.While (L.Bool true, dispatch_body)
        ]
  in

  (* Return hoisted declarations + parameter copies + dispatch loop *)
  hoist_stmts @ param_copy_stmts @ dispatch_loop

and generate_closure ctx params pc block_args =
  match ctx.program with
  | None ->
      (* No program context - return placeholder *)
      L.Ident "caml_closure"
  | Some program -> (
      match Code.Addr.Map.find_opt pc program.Code.blocks with
      | None ->
          (* Block not found - return placeholder *)
          L.Ident "caml_closure"
      | Some _ ->
          (* Generate closure following js_of_ocaml approach (generate.ml:1487-1497, 2319-2339):

             Code.Closure (params, (pc, block_args), _) where:
             - params: Function parameters (function signature)
             - pc: Entry block address
             - block_args: Arguments to pass to entry block
               CRITICAL: block_args can be EITHER:
               1. Function parameters from `params` (use plain identifier)
               2. Captured variables from outer scope (use var_ident -> _V.xxx)

             In JS: compile_closure calls compile_branch with (pc, args) to pass args to block.
             In Lua with _V table: Need to pass block_args to entry_block.params.
          *)

          (* Create child context for closure that inherits parent's variable mappings
             This allows closures to capture parent _V via Lua upvalues *)
          let closure_ctx = make_child_context ctx program in

          (* Generate parameter names using the closure's context *)
          let param_names = List.map ~f:(var_name closure_ctx) params in

          (* CRITICAL FIX: Pass block_args to entry block.
             block_args may reference function params OR captured variables.
             Need to pass params list to generate_argument_passing so it knows
             which args are local params vs captured variables. *)
          let arg_passing = generate_argument_passing closure_ctx pc block_args ~func_params:params () in

          (* compile_blocks_with_labels will:
             1. Collect variables in this closure's blocks
             2. Create _V table if needed (>180 vars) or use parent's _V
             3. Copy function params to _V table if needed
             4. Generate block dispatch loop *)
          let body_stmts = compile_blocks_with_labels closure_ctx program pc ~params () in

          (* Prepend argument passing before block compilation *)
          let full_body = arg_passing @ body_stmts in

          (* Wrap the function in OCaml function format using caml_make_closure
             Creates: {l = arity, [1] = function} with __call metatable *)
          let lua_func = L.Function (param_names, false, full_body) in
          let arity = L.Number (string_of_int (List.length params)) in
          L.Call (L.Ident "caml_make_closure", [ arity; lua_func ]))

(** Generate argument passing code for block continuation
    When jumping to a block with parameters, assign the arguments to the parameters

    CRITICAL: args can be EITHER function parameters (local variables) OR captured
    variables from outer scope (_V table). We need to distinguish between them.

    @param ctx Code generation context
    @param addr Target block address
    @param args Arguments to pass
    @param func_params Optional list of function parameters (for closure entry only)
    @return List of assignment statements
*)
and generate_argument_passing ctx addr args ?(func_params = []) () =
  match ctx.program with
  | None -> []
  | Some program -> (
      match Code.Addr.Map.find_opt addr program.Code.blocks with
      | None -> []
      | Some block ->
          (* Match args with block params and generate assignments

             CRITICAL DISTINCTION:
             - If arg is in func_params: it's a LOCAL function parameter -> use plain identifier
             - If arg is NOT in func_params: it's a captured variable -> use var_ident (respects _V table)

             This matches how JS handles it: function parameters are in local scope,
             but captured variables are accessed through the appropriate scope chain.
          *)
          let rec build_assignments args params acc =
            match args, params with
            | [], [] -> List.rev acc
            | arg_var :: rest_args, param_var :: rest_params ->
                (* Source: Check if arg_var is a function parameter or captured variable *)
                let arg_name = var_name ctx arg_var in
                let arg_expr =
                  if List.mem ~eq:Code.Var.equal arg_var func_params
                  then (
                    (* Function parameter - use plain local identifier *)
                    L.Ident arg_name)
                  else (
                    (* Captured variable - use var_ident which respects _V table setting *)
                    var_ident ctx arg_var)
                in
                (* Target: use var_ident which respects use_var_table setting *)
                let param_name = var_name ctx param_var in
                let param_target = var_ident ctx param_var in
                (* DEBUG: Add comment showing the mapping *)
                let is_local = List.mem ~eq:Code.Var.equal arg_var func_params in
                let source_desc = if is_local then "local" else "captured" in
                let debug_comment =
                  L.Comment (Printf.sprintf "Block arg: %s = %s (%s)" param_name arg_name source_desc)
                in
                let assignment = L.Assign ([param_target], [arg_expr]) in
                build_assignments rest_args rest_params (assignment :: debug_comment :: acc)
            | _, _ ->
                (* Argument count mismatch - this shouldn't happen in valid IR *)
                List.rev acc
          in
          build_assignments args block.Code.params [])

(** Generate Lua last statement from Code last (terminator) using dispatch
    Sets _next_block variable for dispatch loop (Lua 5.1 compatible)
    @param ctx Code generation context
    @param last IR terminator
    @return List of Lua statements
*)
and generate_last_dispatch ctx last =
  match last with
  | Code.Return var ->
      let lua_expr = var_ident ctx var in
      [ L.Return [ lua_expr ] ]
  | Code.Raise (var, _raise_kind) ->
      let lua_expr = var_ident ctx var in
      [ L.Call_stat (L.Call (L.Ident "error", [ lua_expr ])) ]
  | Code.Stop -> [ L.Return [ L.Nil ] ]
  | Code.Branch (addr, args) ->
      (* Generate argument passing, then set next block *)
      let arg_passing = generate_argument_passing ctx addr args () in
      let set_block = L.Assign ([L.Ident "_next_block"], [L.Number (string_of_int addr)]) in
      arg_passing @ [ set_block ]
  | Code.Cond (var, (addr_true, args_true), (addr_false, args_false)) ->
      let cond_expr = var_ident ctx var in
      (* Generate argument passing for both branches *)
      let pass_true = generate_argument_passing ctx addr_true args_true () in
      let pass_false = generate_argument_passing ctx addr_false args_false () in
      let set_true = L.Assign ([L.Ident "_next_block"], [L.Number (string_of_int addr_true)]) in
      let set_false = L.Assign ([L.Ident "_next_block"], [L.Number (string_of_int addr_false)]) in
      let then_stmts = pass_true @ [ set_true ] in
      let else_stmts = pass_false @ [ set_false ] in
      [ L.If (cond_expr, then_stmts, Some else_stmts) ]
  | Code.Switch (var, conts) ->
      let switch_var = var_ident ctx var in
      let cases =
        Array.to_list conts
        |> List.mapi ~f:(fun idx (addr, args) ->
            let cond = L.BinOp (L.Eq, switch_var, L.Number (string_of_int idx)) in
            (* Generate argument passing *)
            let arg_passing = generate_argument_passing ctx addr args () in
            let set_block = L.Assign ([L.Ident "_next_block"], [L.Number (string_of_int addr)]) in
            let then_stmt = arg_passing @ [ set_block ] in
            (cond, then_stmt))
      in
      (match cases with
      | [] -> []
      | (cond, then_stmt) :: rest ->
          let rec build_if_chain = function
            | [] -> then_stmt
            | (c, t) :: rest -> [ L.If (c, t, Some (build_if_chain rest)) ]
          in
          [ L.If (cond, then_stmt, Some (build_if_chain rest)) ])
  | Code.Pushtrap ((cont_addr, args), _var, (_handler_addr, _handler_args)) ->
      (* Jump to continuation with argument passing.
         Exception handler setup is handled by runtime caml_push_trap. *)
      let arg_passing = generate_argument_passing ctx cont_addr args () in
      let set_block = L.Assign ([L.Ident "_next_block"], [L.Number (string_of_int cont_addr)]) in
      arg_passing @ [ set_block ]
  | Code.Poptrap (addr, args) ->
      let arg_passing = generate_argument_passing ctx addr args () in
      let set_block = L.Assign ([L.Ident "_next_block"], [L.Number (string_of_int addr)]) in
      arg_passing @ [ set_block ]

(** Alias for backward compatibility *)
and generate_last ctx last =
  generate_last_dispatch ctx last

(** Generate Lua block from Code block
    @param ctx Code generation context
    @param block IR block
    @return List of Lua statements
*)
and generate_block ctx block =
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
  let all_stmts = compile_blocks_with_labels ctx program program.Code.start () in

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
    L.Comment "Initialize global OCaml namespace (required before loading runtime modules)";
    L.Assign ([L.Dot (L.Ident "_G", "_OCAML")], [L.Table []]);
    L.Comment "";
    L.Comment "NOTE: core.lua provides caml_register_global for primitives (name, func).";
    L.Comment "This inline version is for registering OCaml global VALUES (used by generated code).";
    L.Comment "TODO: Rename one of them to avoid confusion.";
    L.Local ([ "_OCAML_GLOBALS" ], Some [ L.Table [] ]);
    L.Function_decl
      ( "caml_register_global"
      , [ "n"; "v"; "name" ]
      , false
      , [ L.Assign
            ( [ L.Index (L.Ident "_OCAML_GLOBALS", L.BinOp (L.Add, L.Ident "n", L.Number "1")) ]
            , [ L.Ident "v" ] );
          L.If
            ( L.Ident "name"
            , [ L.Assign
                  ( [ L.Index (L.Ident "_OCAML_GLOBALS", L.Ident "name") ]
                  , [ L.Ident "v" ] )
              ]
            , None );
          L.Return [ L.Ident "v" ]
        ] );
    L.Function_decl
      ( "caml_register_named_value"
      , [ "name"; "value" ]
      , false
      , [ L.Assign
            ( [ L.Index (L.Ident "_OCAML_GLOBALS", L.Ident "name") ]
            , [ L.Ident "value" ] );
          L.Return [ L.Ident "value" ]
        ] );
    L.Comment "";
    L.Comment "Bitwise operations for Lua 5.1 (simplified implementations)";
    L.Function_decl
      ( "caml_int_and"
      , [ "a"; "b" ]
      , false
      , [ L.Comment "Simplified bitwise AND for common cases";
          L.Comment "For full implementation, see runtime/lua/ints.lua";
          L.Local ([ "result"; "bit" ], Some [ L.Number "0"; L.Number "1" ]);
          L.Assign ([ L.Ident "a" ], [ L.Call (L.Ident "math.floor", [ L.Ident "a" ]) ]);
          L.Assign ([ L.Ident "b" ], [ L.Call (L.Ident "math.floor", [ L.Ident "b" ]) ]);
          L.While
            ( L.BinOp (L.And, L.BinOp (L.Gt, L.Ident "a", L.Number "0"), L.BinOp (L.Gt, L.Ident "b", L.Number "0"))
            , [ L.If
                  ( L.BinOp (L.And,
                      L.BinOp (L.Eq, L.BinOp (L.Mod, L.Ident "a", L.Number "2"), L.Number "1"),
                      L.BinOp (L.Eq, L.BinOp (L.Mod, L.Ident "b", L.Number "2"), L.Number "1"))
                  , [ L.Assign ([ L.Ident "result" ], [ L.BinOp (L.Add, L.Ident "result", L.Ident "bit") ]) ]
                  , None );
                L.Assign ([ L.Ident "a" ], [ L.Call (L.Ident "math.floor", [ L.BinOp (L.Div, L.Ident "a", L.Number "2") ]) ]);
                L.Assign ([ L.Ident "b" ], [ L.Call (L.Ident "math.floor", [ L.BinOp (L.Div, L.Ident "b", L.Number "2") ]) ]);
                L.Assign ([ L.Ident "bit" ], [ L.BinOp (L.Mul, L.Ident "bit", L.Number "2") ])
              ] );
          L.Return [ L.Ident "result" ]
        ] );
    L.Function_decl
      ( "caml_int_or"
      , [ "a"; "b" ]
      , false
      , [ L.Local ([ "result"; "bit" ], Some [ L.Number "0"; L.Number "1" ]);
          L.Assign ([ L.Ident "a" ], [ L.Call (L.Ident "math.floor", [ L.Ident "a" ]) ]);
          L.Assign ([ L.Ident "b" ], [ L.Call (L.Ident "math.floor", [ L.Ident "b" ]) ]);
          L.While
            ( L.BinOp (L.Or, L.BinOp (L.Gt, L.Ident "a", L.Number "0"), L.BinOp (L.Gt, L.Ident "b", L.Number "0"))
            , [ L.If
                  ( L.BinOp (L.Or,
                      L.BinOp (L.Eq, L.BinOp (L.Mod, L.Ident "a", L.Number "2"), L.Number "1"),
                      L.BinOp (L.Eq, L.BinOp (L.Mod, L.Ident "b", L.Number "2"), L.Number "1"))
                  , [ L.Assign ([ L.Ident "result" ], [ L.BinOp (L.Add, L.Ident "result", L.Ident "bit") ]) ]
                  , None );
                L.Assign ([ L.Ident "a" ], [ L.Call (L.Ident "math.floor", [ L.BinOp (L.Div, L.Ident "a", L.Number "2") ]) ]);
                L.Assign ([ L.Ident "b" ], [ L.Call (L.Ident "math.floor", [ L.BinOp (L.Div, L.Ident "b", L.Number "2") ]) ]);
                L.Assign ([ L.Ident "bit" ], [ L.BinOp (L.Mul, L.Ident "bit", L.Number "2") ])
              ] );
          L.Return [ L.Ident "result" ]
        ] );
    L.Function_decl
      ( "caml_int_xor"
      , [ "a"; "b" ]
      , false
      , [ L.Local ([ "result"; "bit" ], Some [ L.Number "0"; L.Number "1" ]);
          L.Assign ([ L.Ident "a" ], [ L.Call (L.Ident "math.floor", [ L.Ident "a" ]) ]);
          L.Assign ([ L.Ident "b" ], [ L.Call (L.Ident "math.floor", [ L.Ident "b" ]) ]);
          L.While
            ( L.BinOp (L.Or, L.BinOp (L.Gt, L.Ident "a", L.Number "0"), L.BinOp (L.Gt, L.Ident "b", L.Number "0"))
            , [ L.Local ([ "a_bit"; "b_bit" ], Some [ L.BinOp (L.Mod, L.Ident "a", L.Number "2"); L.BinOp (L.Mod, L.Ident "b", L.Number "2") ]);
                L.If
                  ( L.BinOp (L.Neq, L.Ident "a_bit", L.Ident "b_bit")
                  , [ L.Assign ([ L.Ident "result" ], [ L.BinOp (L.Add, L.Ident "result", L.Ident "bit") ]) ]
                  , None );
                L.Assign ([ L.Ident "a" ], [ L.Call (L.Ident "math.floor", [ L.BinOp (L.Div, L.Ident "a", L.Number "2") ]) ]);
                L.Assign ([ L.Ident "b" ], [ L.Call (L.Ident "math.floor", [ L.BinOp (L.Div, L.Ident "b", L.Number "2") ]) ]);
                L.Assign ([ L.Ident "bit" ], [ L.BinOp (L.Mul, L.Ident "bit", L.Number "2") ])
              ] );
          L.Return [ L.Ident "result" ]
        ] );
    L.Comment "";
    L.Comment "Int64/Float bit conversion stubs (TODO: proper implementation)";
    L.Function_decl
      ( "caml_int64_float_of_bits"
      , [ "i" ]
      , false
      , [ L.Comment "Convert int64 bits to float - stub implementation";
          L.Comment "In Lua, numbers are already IEEE 754 doubles";
          L.Return [ L.Ident "i" ]
        ] );
    L.Comment "=== End Inline Runtime ==="
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

  (* 2. Load runtime modules from compile-time embedded path *)
  (* The runtime directory path should be resolved at compile time, not runtime.
     We use Sys.executable_name to find the compiler location and then
     look for runtime files relative to that. *)
  let find_runtime_dir () =
    let exe_dir = Filename.dirname Sys.executable_name in
    (* Try multiple possible locations relative to the executable *)
    let possible_paths = [
      (* If running from _build directory *)
      Filename.concat exe_dir "../../../../runtime/lua";
      (* If installed *)
      Filename.concat exe_dir "../share/lua_of_ocaml/runtime";
      (* Development: direct path from project root *)
      "runtime/lua";
      (* Fallback: environment variable *)
      (try Sys.getenv "LUA_OF_OCAML_RUNTIME" with Not_found -> "")
    ] in
    List.find_opt ~f:(fun path ->
      not (String.equal path "") && Sys.file_exists path && Sys.is_directory path
    ) possible_paths
  in
  let fragments =
    match find_runtime_dir () with
    | Some runtime_dir ->
        Lua_link.load_runtime_dir runtime_dir
    | None ->
        (* Runtime directory not found - issue warning and continue *)
        if not (StringSet.is_empty used_primitives) then
          Printf.eprintf "Warning: Runtime directory not found. Generated code may not work.\n\
                          Set LUA_OF_OCAML_RUNTIME environment variable to runtime/lua directory.\n";
        []
  in

  (* 3. Find fragments that provide used primitives *)
  (* Build provides map: primitive name -> fragment *)
  let provides_map =
    List.fold_left
      ~f:(fun acc frag ->
        List.fold_left
          ~f:(fun m prim -> StringMap.add prim frag.Lua_link.name m)
          ~init:acc
          frag.Lua_link.provides)
      ~init:StringMap.empty
      fragments
  in
  (* NOTE: We used to find which fragments provide needed primitives here,
     but we now use linkall behavior since codegen adds primitives not in IR. *)
  let _ = provides_map in  (* Suppress unused warning *)
  let _ = used_primitives in  (* Suppress unused warning *)

  (* 4. Resolve dependencies between needed fragments *)
  (* TEMPORARY: Use linkall behavior - include ALL runtime modules.
     This is needed because code generation adds primitive calls (like caml_fresh_oo_id)
     that aren't in the original IR, so collect_used_primitives misses them.
     TODO: Either (1) track primitives during codegen, or (2) analyze generated AST. *)
  let sorted_fragments =
    if List.length fragments = 0
    then []
    else
      let state =
        List.fold_left
          ~f:Lua_link.add_fragment
          ~init:(Lua_link.init ())
          fragments
      in
      (* resolve_deps expects SYMBOL names, not fragment names.
         NOTE: We don't include core.lua because it conflicts with our inline runtime.
         Specifically, core.lua's caml_register_global is for primitives (name, func)
         while our inline version is for values (index, value, name).
         The inline runtime already initializes _G._OCAML. *)
      (* FORCE linkall behavior until we track primitives added during codegen *)
      let needed_symbols =
        (* Include all symbols from all fragments (linkall) *)
        List.fold_left
          ~f:(fun acc frag ->
            (* Skip core.lua to avoid conflicts *)
            if String.equal frag.Lua_link.name "core" then acc
            else
              List.fold_left
                ~f:(fun acc2 sym -> StringSet.add sym acc2)
                ~init:acc
                frag.Lua_link.provides)
          ~init:StringSet.empty
          fragments
      in
      let sorted_fragment_names, _missing =
        Lua_link.resolve_deps state (StringSet.elements needed_symbols)
      in
      (* Filter out core.lua from the sorted list to avoid conflicts *)
      let sorted_fragment_names = List.filter ~f:(fun name -> not (String.equal name "core")) sorted_fragment_names in
      List.filter_map
        ~f:(fun name -> List.find_opt ~f:(fun f -> String.equal f.Lua_link.name name) fragments)
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
    |> List.map ~f:(fun code -> L.Raw code)
  in
  let wrappers_code = Lua_link.generate_wrappers used_primitives fragments in
  let wrappers =
    if String.length wrappers_code = 0
    then []
    else [ L.Raw wrappers_code ]
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
  let init_code = compile_blocks_with_labels ctx program program.Code.start () in

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

(** Generate runtime inline code as string
    Returns the minimal runtime needed for basic operations
    @return Runtime code as string
*)
let generate_runtime_inline () =
  (* Load runtime files from the Lua runtime directory *)
  let runtime_dir = "runtime/lua" in
  let fragments =
    try Lua_link.load_runtime_dir runtime_dir
    with _ ->
      (* If runtime directory not found, return empty list *)
      []
  in

  (* Create a map of fragment name to fragment *)
  let fragment_map =
    List.fold_left ~f:(fun acc frag ->
      let basename = Filename.remove_extension frag.Lua_link.name in
      StringMap.add basename frag acc
    ) ~init:StringMap.empty fragments
  in

  (* Essential runtime modules in dependency order *)
  let basic_runtime = [
    "core";
    "ints";
    "closure";  (* Add closure for caml_make_closure *)
    "weak";
    "obj";
    "array";
    "io";
    "sys";
    "format";
    "effect";
    "trampoline";
    "domain"
  ] in

  (* Collect runtime code for essential modules *)
  let runtime_code =
    List.filter_map ~f:(fun name ->
      StringMap.find_opt name fragment_map
    ) basic_runtime
    |> List.map ~f:(fun fragment ->
      Printf.sprintf "-- Runtime: %s\n%s" fragment.Lua_link.name fragment.Lua_link.code)
    |> String.concat ~sep:"\n"
  in

  (* Get inline runtime statements and convert to string *)
  let inline_runtime_stmts = generate_inline_runtime () in
  let inline_runtime_str = Lua_output.program_to_string inline_runtime_stmts in

  (* Combine inline runtime and module runtime *)
  inline_runtime_str ^ "\n-- \n" ^ runtime_code
