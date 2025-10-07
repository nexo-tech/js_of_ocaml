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
  ; optimize_variant_match : bool  (** Enable variant matching optimization *)
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
  ; optimize_variant_match = true
  }

(** Create a context with program for closure generation *)
let make_context_with_program ~debug program =
  { vars = make_var_context ()
  ; _debug = debug
  ; program = Some program
  ; optimize_field_access = true
  ; optimize_variant_match = true
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
          let prim_func = L.Ident ("caml_" ^ name) in
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

(** Optimize variant discrimination in switch statements
    Uses tag field for efficient dispatching
    @param ctx Code generation context
    @param switch_var Variable being switched on
    @return Optimized expression for switch variable (extracts tag if block)
*)
let optimize_variant_discriminator ctx switch_var =
  if ctx.optimize_variant_match
  then
    (* For variant matching, we check both:
       - Direct integer tag (for constant constructors)
       - Block tag field (for constructors with arguments)
       Generate: (type(v) == "table" and v.tag or v) *)
    let type_check = L.BinOp (L.Eq, L.Call (L.Ident "type", [ switch_var ]), L.String "table")
    in
    let tag_access = L.Dot (switch_var, "tag") in
    L.BinOp (L.Or, L.BinOp (L.And, type_check, tag_access), switch_var)
  else switch_var

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
      (* Generate local variable declaration with initialization *)
      let var_name = var_name ctx var in
      let lua_expr = generate_expr ctx expr in
      L.Local ([ var_name ], Some [ lua_expr ])
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
  | Code.Event _ ->
      (* Events are debugging information, generate empty block *)
      L.Block []

(** Generate Lua statements from a list of Code instructions
    @param ctx Code generation context
    @param instrs List of IR instructions
    @return List of Lua statements
*)
and generate_instrs ctx instrs =
  List.map ~f:(generate_instr ctx) instrs

(** {2 Control Flow Generation} *)

(** Generate Lua statement(s) from Code last (terminator)
    This version handles control flow by generating inline statements.
    For more complex control flow graphs, we would need to generate labels and gotos.

    @param ctx Code generation context
    @param program Full IR program (for block lookup)
    @param last IR terminator
    @return List of Lua statements
*)
and generate_last_with_program ctx program last =
  match last with
  | Code.Return var ->
      (* Generate return statement *)
      let lua_expr = var_ident ctx var in
      [ L.Return [ lua_expr ] ]
  | Code.Raise (var, _raise_kind) ->
      (* Generate error call *)
      let lua_expr = var_ident ctx var in
      [ L.Call_stat (L.Call (L.Ident "error", [ lua_expr ])) ]
  | Code.Stop ->
      (* Program termination - return nil *)
      [ L.Return [ L.Nil ] ]
  | Code.Branch (addr, _args) ->
      (* Branch to another block - generate goto for now *)
      let label = "block_" ^ Code.Addr.to_string addr in
      [ L.Goto label ]
  | Code.Cond (var, (addr_true, _args_true), (addr_false, _args_false)) ->
      (* Conditional branch - generate if statement *)
      let cond_expr = var_ident ctx var in
      (* For simple conditionals, try to inline the blocks *)
      let true_block = Code.Addr.Map.find_opt addr_true program.Code.blocks in
      let false_block = Code.Addr.Map.find_opt addr_false program.Code.blocks in
      (match true_block, false_block with
      | Some tb, Some fb ->
          (* Generate inline if-then-else *)
          let true_stmts = generate_block_with_program ctx program tb in
          let false_stmts = generate_block_with_program ctx program fb in
          [ L.If (cond_expr, true_stmts, Some false_stmts) ]
      | Some tb, None ->
          (* Only true branch *)
          let true_stmts = generate_block_with_program ctx program tb in
          [ L.If (cond_expr, true_stmts, None) ]
      | None, Some fb ->
          (* Only false branch - invert condition *)
          let false_stmts = generate_block_with_program ctx program fb in
          let not_cond = L.UnOp (L.Not, cond_expr) in
          [ L.If (not_cond, false_stmts, None) ]
      | None, None ->
          (* No blocks found - generate gotos *)
          let true_label = "block_" ^ Code.Addr.to_string addr_true in
          let false_label = "block_" ^ Code.Addr.to_string addr_false in
          [ L.If (cond_expr, [ L.Goto true_label ], Some [ L.Goto false_label ]) ])
  | Code.Switch (var, conts) ->
      (* Switch statement - generate if-elseif chain with optimized variant discrimination *)
      let switch_var = var_ident ctx var in
      let discriminator = optimize_variant_discriminator ctx switch_var in
      generate_switch ctx program discriminator conts 0
  | Code.Pushtrap (_cont, _var, _handler) ->
      (* Exception handling - simplified for now *)
      [ L.Block [] ]
  | Code.Poptrap _cont ->
      (* Exception handling - simplified for now *)
      [ L.Block [] ]

(** Generate switch as if-elseif chain
    @param ctx Code generation context
    @param program Full IR program
    @param switch_var Variable being switched on
    @param conts Array of continuations
    @param idx Current index
    @return List of Lua statements
*)
and generate_switch ctx program switch_var conts idx =
  if idx >= Array.length conts
  then []
  else
    let addr, _args = conts.(idx) in
    let block_opt = Code.Addr.Map.find_opt addr program.Code.blocks in
    match block_opt with
    | None ->
        (* Block not found, skip *)
        generate_switch ctx program switch_var conts (idx + 1)
    | Some blk ->
        let block_stmts = generate_block_with_program ctx program blk in
        if idx = 0
        then
          (* First case *)
          let cond = L.BinOp (L.Eq, switch_var, L.Number (string_of_int idx)) in
          if idx = Array.length conts - 1
          then (* Only one case *)
            [ L.If (cond, block_stmts, None) ]
          else
            let rest = generate_switch ctx program switch_var conts (idx + 1) in
            [ L.If (cond, block_stmts, Some rest) ]
        else if idx = Array.length conts - 1
        then (* Default case *)
          block_stmts
        else
          (* Middle case - part of elseif chain *)
          let cond = L.BinOp (L.Eq, switch_var, L.Number (string_of_int idx)) in
          let rest = generate_switch ctx program switch_var conts (idx + 1) in
          [ L.If (cond, block_stmts, Some rest) ]

(** Generate Lua block from Code block (with program context)
    @param ctx Code generation context
    @param program Full IR program
    @param block IR block
    @return List of Lua statements
*)
and generate_block_with_program ctx program block =
  let body_stmts = generate_instrs ctx block.Code.body in
  let last_stmts = generate_last_with_program ctx program block.Code.branch in
  body_stmts @ last_stmts

(** {2 Function/Closure Generation} *)

(** Detect if a last is a tail call to the given address
    @param last Last instruction
    @param target_pc Target address to check for tail recursion
    @return true if this is a tail call to target_pc
*)
and is_tail_call_to last target_pc =
  match last with
  | Code.Branch (pc, _) when pc = target_pc -> true
  | _ -> false

(** Generate Lua function from closure with tail call optimization
    @param ctx Code generation context
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
      | Some block ->
          (* Generate function with parameters *)
          let param_names = List.map ~f:(var_name ctx) params in
          (* Check if this function has tail recursion *)
          let has_tail_recursion = is_tail_call_to block.Code.branch pc in
          let body_stmts =
            if has_tail_recursion
            then
              (* Wrap body in while true loop with tail_call label *)
              let label_stmt = L.Label "tail_call" in
              let inner_body = generate_block_with_program ctx program block in
              let while_loop = L.While (L.Bool true, label_stmt :: inner_body) in
              [ while_loop ]
            else generate_block_with_program ctx program block
          in
          L.Function (param_names, false, body_stmts))

(** Backward compatibility: generate_last without program
    This version generates placeholder blocks for control flow
*)
let generate_last ctx last =
  match last with
  | Code.Return var ->
      let lua_expr = var_ident ctx var in
      [ L.Return [ lua_expr ] ]
  | Code.Raise (var, _raise_kind) ->
      let lua_expr = var_ident ctx var in
      [ L.Call_stat (L.Call (L.Ident "error", [ lua_expr ])) ]
  | Code.Stop -> [ L.Return [ L.Nil ] ]
  | Code.Branch _cont -> [ L.Block [] ]
  | Code.Cond (_var, _cont_true, _cont_false) -> [ L.Block [] ]
  | Code.Switch (_var, _conts) -> [ L.Block [] ]
  | Code.Pushtrap (_cont, _var, _handler) -> [ L.Block [] ]
  | Code.Poptrap _cont -> [ L.Block [] ]

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

(** Generate module initialization code
    This creates the entry point that initializes the module

    @param ctx Code generation context
    @param program OCaml IR program
    @return Lua statements for module initialization
*)
let generate_module_init ctx program =
  (* Get the entry block *)
  let entry_block =
    match Code.Addr.Map.find_opt program.Code.start program.Code.blocks with
    | Some block -> block
    | None -> failwith "Program entry block not found"
  in

  (* Generate code for the entry block *)
  let entry_stmts = generate_block_with_program ctx program entry_block in

  (* Wrap in a module initialization function *)
  let init_func =
    L.Function_decl
      ( "__caml_init__"
      , []
      , false
      , [ L.Comment "Module initialization code" ] @ entry_stmts )
  in

  [ init_func; L.Call_stat (L.Call (L.Ident "__caml_init__", [])) ]

(** Generate standalone program
    Creates a complete Lua program that can be executed directly

    @param ctx Code generation context
    @param program OCaml IR program
    @return Lua statements for standalone program
*)
let generate_standalone ctx program =
  (* Generate module initialization *)
  let init_code = generate_module_init ctx program in

  (* Add runtime setup if needed *)
  let runtime_setup = [ L.Comment "Runtime initialized by require statements" ] in

  runtime_setup @ init_code

(** Generate module code for separate compilation
    Creates module code that can be loaded via require()

    @param ctx Code generation context
    @param program OCaml IR program
    @param module_name Module name for exports
    @return Lua statements for module
*)
let generate_module ctx program module_name =
  (* Get the entry block *)
  let entry_block =
    match Code.Addr.Map.find_opt program.Code.start program.Code.blocks with
    | Some block -> block
    | None -> failwith "Program entry block not found"
  in

  (* Generate code for the entry block *)
  let entry_stmts = generate_block_with_program ctx program entry_block in

  (* Create module table *)
  let module_var = "M" in
  let module_init = [ L.Local ([ module_var ], Some [ L.Table [] ]) ] in

  (* Add initialization code *)
  let init_code = entry_stmts in

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
