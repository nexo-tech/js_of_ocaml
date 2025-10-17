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

(** Lua AST Traversal

    Visitor classes for traversing and analyzing Lua AST.
    Modeled after compiler/lib/js_traverse.mli.
*)

module L = Lua_of_ocaml_compiler__Lua_ast

(** {2 Iterator Interface} *)

(** Base iterator interface for visiting Lua AST nodes *)
class type iterator = object
  method ident : L.ident -> unit
  method expression : L.expr -> unit
  method expression_list : L.expr list -> unit
  method table_field : L.table_field -> unit
  method statement : L.stat -> unit
  method statements : L.block -> unit
  method program : L.program -> unit
end

(** {2 Base Iterator} *)

(** Generic Lua AST iterator

    Visits all nodes in a Lua AST. Subclasses can override specific methods
    to customize behavior.

    Example usage:
    {[
      let counter = ref 0 in
      let visitor = object
        inherit iter
        method! ident name =
          incr counter;
          Printf.printf "Found identifier: %s\n" name
      end in
      visitor#program lua_ast
    ]}
*)
class iter : iterator

(** {2 Free Variable Collection} *)

(** Fast free variable collector

    Collects all free (undeclared) variables in a Lua program.
    Uses scope tracking to distinguish bound vs free variables.

    Modeled after js_traverse.ml:1335-1468 (fast_freevar class).

    Example usage:
    {[
      let free_vars = ref StringSet.empty in
      let visitor = new fast_freevar (fun name ->
        free_vars := StringSet.add name !free_vars
      ) in
      visitor#program lua_ast;
      !free_vars  (* Set of all free variables *)
    ]}

    @param f Callback function called for each free variable name
*)
class fast_freevar : (string -> unit) -> iterator

(** Collect all free variables from a Lua program

    Convenience function that creates a fast_freevar visitor and
    collects all free variables into a StringSet.

    @param lua_ast Lua AST (program)
    @return StringSet of all free variable names
*)
val collect_free_vars : L.program -> Js_of_ocaml_compiler.Stdlib.StringSet.t
