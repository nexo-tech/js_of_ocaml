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

(** OCaml Value Representation in Lua

    This module provides helpers for generating Lua code that creates and
    accesses OCaml values. It defines how OCaml values are encoded in Lua.

    OCaml Value Encoding:
    - Immediates (int, bool, unit, None): Lua numbers
      - unit: 0
      - false: 0
      - true: 1
      - None: 0
      - int: Lua number
    - Blocks (tuples, variants, records, Some, etc.): Lua tables with tags
      - Structure: {tag = <tag>, [1] = field0, [2] = field1, ...}
      - Fields are 1-indexed in Lua but accessed as 0-indexed from OCaml
      - tag field stores the OCaml block tag
    - Arrays: Special blocks with tag=0, length at [0]
      - Structure: {tag = 0, [0] = length, [1] = elem0, [2] = elem1, ...}
    - Strings: Lua strings (immutable)
    - Floats: Lua numbers

    This matches the runtime representation in runtime/lua/core.lua.
*)

open! Stdlib
module L = Lua_ast

(** Literal values for common OCaml constants *)

let zero = L.Number "0"

let one = L.Number "1"

(** Unit value (0) *)
let unit = zero

(** Boolean encoding *)
let false_val = zero

let true_val = one

(** None value (0) *)
let none = zero

(** {2 Type Predicates} *)

(** Check if a value is a block (table with tag field).
    In Lua: type(x) == "table" and x.tag ~= nil *)
let is_block e =
  L.BinOp
    ( L.And
    , L.BinOp (L.Eq, L.Call (L.Ident "type", [ e ]), L.String "table")
    , L.BinOp (L.Neq, L.Dot (e, "tag"), L.Nil) )

(** Check if a value is an immediate (not a table, typically a number).
    In Lua: type(x) ~= "table" *)
let is_immediate e = L.BinOp (L.Neq, L.Call (L.Ident "type", [ e ]), L.String "table")

(** {2 Block Operations} *)

module Block = struct
  (** Create a block with a tag and fields.
      Generates: {tag = <tag>, [1] = field0, [2] = field1, ...}

      @param tag The OCaml block tag
      @param fields List of field values
      @return Lua table constructor expression
  *)
  let make ~tag ~fields =
    let tag_field = L.Rec_field ("tag", L.Number (string_of_int tag)) in
    let fields_with_indices =
      List.mapi fields ~f:(fun i expr -> L.General_field (L.Number (string_of_int (i + 1)), expr))
    in
    L.Table (tag_field :: fields_with_indices)

  (** Get the tag of a block.
      Generates: block.tag

      @param block The block expression
      @return Expression accessing the tag field
  *)
  let tag block = L.Dot (block, "tag")

  (** Get a field from a block.
      Generates: block[idx + 1]

      OCaml uses 0-based indexing, but Lua tables store fields at 1-based indices.

      @param block The block expression
      @param idx The 0-based field index
      @return Expression accessing the field
  *)
  let field block idx =
    let lua_idx = L.Number (string_of_int (idx + 1)) in
    L.Index (block, lua_idx)

  (** Get a field with dynamic index.
      Generates: block[idx + 1]

      @param block The block expression
      @param idx_expr Expression computing the index
      @return Expression accessing the field
  *)
  let field_dynamic block idx_expr = L.Index (block, L.BinOp (L.Add, idx_expr, one))

  (** Set a field in a block.
      Generates: block[idx + 1] = value

      @param block The block expression
      @param idx The 0-based field index
      @param value The value to set
      @return Assignment statement
  *)
  let set_field block idx value =
    let lua_idx = L.Number (string_of_int (idx + 1)) in
    L.Assign ([ L.Index (block, lua_idx) ], [ value ])
end

(** {2 Array Operations} *)

module Array = struct
  (** Create an array with tag=0.
      Arrays store length at index [0]: {tag = 0, [0] = length, [1] = elem0, ...}

      @param length The array length
      @param fields List of array elements
      @return Lua table constructor expression
  *)
  let make ~length ~fields =
    let tag_field = L.Rec_field ("tag", zero) in
    let length_field = L.General_field (zero, L.Number (string_of_int length)) in
    let fields_with_indices =
      List.mapi fields ~f:(fun i expr -> L.General_field (L.Number (string_of_int (i + 1)), expr))
    in
    L.Table (tag_field :: length_field :: fields_with_indices)

  (** Get array length.
      Generates: arr[0]

      @param arr The array expression
      @return Expression accessing the length
  *)
  let length arr = L.Index (arr, zero)

  (** Get an array element.
      Generates: arr[idx + 1]

      @param arr The array expression
      @param idx The 0-based element index
      @return Expression accessing the element
  *)
  let get arr idx =
    let lua_idx = L.Number (string_of_int (idx + 1)) in
    L.Index (arr, lua_idx)

  (** Get an array element with dynamic index.
      Generates: arr[idx + 1]

      @param arr The array expression
      @param idx_expr Expression computing the index
      @return Expression accessing the element
  *)
  let get_dynamic arr idx_expr = L.Index (arr, L.BinOp (L.Add, idx_expr, one))

  (** Set an array element.
      Generates: arr[idx + 1] = value

      @param arr The array expression
      @param idx The 0-based element index
      @param value The value to set
      @return Assignment statement
  *)
  let set arr idx value =
    let lua_idx = L.Number (string_of_int (idx + 1)) in
    L.Assign ([ L.Index (arr, lua_idx) ], [ value ])
end

(** {2 Variant and Option Helpers} *)

(** Create Some(x) variant.
    Generates: {tag = 0, [1] = x}

    @param value The wrapped value
    @return Block expression for Some
*)
let some value = Block.make ~tag:0 ~fields:[ value ]

(** Create a constant constructor (no arguments).
    These are encoded as immediate integers.

    @param tag The constructor tag
    @return Number expression
*)
let const_constructor tag = L.Number (string_of_int tag)

(** Create a constructor with arguments.
    Generates: {tag = <tag>, [1] = arg0, [2] = arg1, ...}

    @param tag The constructor tag
    @param args List of constructor arguments
    @return Block expression
*)
let constructor tag args = Block.make ~tag ~fields:args

(** {2 Tuple Operations} *)

(** Create a tuple.
    Tuples are blocks with tag 0.
    Generates: {tag = 0, [1] = elem0, [2] = elem1, ...}

    @param elements List of tuple elements
    @return Block expression for tuple
*)
let tuple elements = Block.make ~tag:0 ~fields:elements

(** {2 String Operations} *)

(** Create a string literal.
    Lua strings are used directly for OCaml strings.

    @param s The string content
    @return String literal expression
*)
let string s = L.String s

(** {2 Numeric Literals} *)

(** Create an integer literal.
    @param n The integer value
    @return Number expression
*)
let int n = L.Number (string_of_int n)

(** Create a float literal.
    @param f The float value
    @return Number expression
*)
let float f = L.Number (string_of_float f)

(** {2 Boolean Conversion} *)

(** Convert OCaml bool to Lua value (0 or 1).
    Generates: lua_bool and 1 or 0

    @param lua_bool Lua boolean expression
    @return Expression that evaluates to 0 or 1
*)
let ml_bool_of_lua lua_bool = L.BinOp (L.And, lua_bool, one)

(** Convert ML bool value (0 or 1) to Lua bool.
    Generates: ml_bool ~= 0

    @param ml_bool ML boolean expression (0 or 1)
    @return Lua boolean expression
*)
let lua_bool_of_ml ml_bool = L.BinOp (L.Neq, ml_bool, zero)
