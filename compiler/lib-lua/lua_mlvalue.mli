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
    accesses OCaml values.
*)

(** {2 Common Constants} *)

val zero : Lua_ast.expr
(** Literal 0 *)

val one : Lua_ast.expr
(** Literal 1 *)

val unit : Lua_ast.expr
(** OCaml unit value (0) *)

val false_val : Lua_ast.expr
(** OCaml false value (0) *)

val true_val : Lua_ast.expr
(** OCaml true value (1) *)

val none : Lua_ast.expr
(** OCaml None value (0) *)

(** {2 Type Predicates} *)

val is_block : Lua_ast.expr -> Lua_ast.expr
(** [is_block e] generates code to check if [e] is a block (table with tag) *)

val is_immediate : Lua_ast.expr -> Lua_ast.expr
(** [is_immediate e] generates code to check if [e] is an immediate value *)

(** {2 Block Operations} *)

module Block : sig
  val make : tag:int -> fields:Lua_ast.expr list -> Lua_ast.expr
  (** [make ~tag ~fields] creates a block with the given tag and fields.
      Generates: {tag = <tag>, [1] = field0, [2] = field1, ...} *)

  val tag : Lua_ast.expr -> Lua_ast.expr
  (** [tag block] accesses the tag of a block.
      Generates: block.tag *)

  val field : Lua_ast.expr -> int -> Lua_ast.expr
  (** [field block idx] accesses field at 0-based index [idx].
      Generates: block[idx + 1] *)

  val field_dynamic : Lua_ast.expr -> Lua_ast.expr -> Lua_ast.expr
  (** [field_dynamic block idx_expr] accesses field at dynamic index.
      Generates: block[idx_expr + 1] *)

  val set_field : Lua_ast.expr -> int -> Lua_ast.expr -> Lua_ast.stat
  (** [set_field block idx value] sets field at index [idx] to [value].
      Generates: block[idx + 1] = value *)
end

(** {2 Array Operations} *)

module Array : sig
  val make : length:int -> fields:Lua_ast.expr list -> Lua_ast.expr
  (** [make ~length ~fields] creates an array with tag=0.
      Generates: {tag = 0, [0] = length, [1] = elem0, ...} *)

  val length : Lua_ast.expr -> Lua_ast.expr
  (** [length arr] accesses the array length.
      Generates: arr[0] *)

  val get : Lua_ast.expr -> int -> Lua_ast.expr
  (** [get arr idx] accesses element at 0-based index [idx].
      Generates: arr[idx + 1] *)

  val get_dynamic : Lua_ast.expr -> Lua_ast.expr -> Lua_ast.expr
  (** [get_dynamic arr idx_expr] accesses element at dynamic index.
      Generates: arr[idx_expr + 1] *)

  val set : Lua_ast.expr -> int -> Lua_ast.expr -> Lua_ast.stat
  (** [set arr idx value] sets element at index [idx] to [value].
      Generates: arr[idx + 1] = value *)
end

(** {2 Variant and Option Helpers} *)

val some : Lua_ast.expr -> Lua_ast.expr
(** [some value] creates Some(value).
    Generates: {tag = 0, [1] = value} *)

val const_constructor : int -> Lua_ast.expr
(** [const_constructor tag] creates a constant constructor.
    Returns: <tag> as a number *)

val constructor : int -> Lua_ast.expr list -> Lua_ast.expr
(** [constructor tag args] creates a constructor with arguments.
    Generates: {tag = <tag>, [1] = arg0, ...} *)

(** {2 Tuple Operations} *)

val tuple : Lua_ast.expr list -> Lua_ast.expr
(** [tuple elements] creates a tuple (block with tag 0).
    Generates: {tag = 0, [1] = elem0, ...} *)

(** {2 String Operations} *)

val string : string -> Lua_ast.expr
(** [string s] creates a string literal *)

(** {2 Numeric Literals} *)

val int : int -> Lua_ast.expr
(** [int n] creates an integer literal *)

val float : float -> Lua_ast.expr
(** [float f] creates a float literal *)

(** {2 Boolean Conversion} *)

val ml_bool_of_lua : Lua_ast.expr -> Lua_ast.expr
(** [ml_bool_of_lua lua_bool] converts Lua bool to ML bool (0 or 1).
    Generates: lua_bool and 1 or 0 *)

val lua_bool_of_ml : Lua_ast.expr -> Lua_ast.expr
(** [lua_bool_of_ml ml_bool] converts ML bool (0 or 1) to Lua bool.
    Generates: ml_bool ~= 0 *)
