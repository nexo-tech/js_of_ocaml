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

(** Lua module linking and dependency resolution *)

(** Runtime fragment representing a Lua module or runtime file *)
type fragment =
  { name : string  (** Module name *)
  ; provides : string list  (** Symbols this module provides *)
  ; requires : string list  (** Symbols this module requires *)
  ; code : string  (** Lua code content *)
  }

(** Linking state *)
type state

(** Initialize linking state *)
val init : unit -> state

(** Parse provides header from a line *)
val parse_provides : string -> string list
(** [parse_provides line] extracts symbols from a "--// Provides: sym1, sym2" header.
    Returns empty list if line doesn't match the format. *)

(** Parse requires header from a line *)
val parse_requires : string -> string list
(** [parse_requires line] extracts symbols from a "--// Requires: sym1, sym2" header.
    Returns empty list if line doesn't match the format. *)

(** Load a runtime Lua file as a fragment *)
val load_runtime_file : string -> fragment

(** Load runtime Lua files from a directory *)
val load_runtime_dir : string -> fragment list

(** Add a fragment to the linking state *)
val add_fragment : state -> fragment -> state

(** Resolve dependencies and determine load order *)
val resolve_deps : state -> string list -> string list * string list
(** [resolve_deps state required] returns [(ordered, missing)] where:
    - [ordered] is the topologically sorted list of required modules
    - [missing] is the list of missing dependencies *)

(** Generate Lua module loader code *)
val generate_loader : fragment list -> string
(** Generates Lua code that registers all modules using Lua's module system *)

(** Link fragments with a main program *)
val link :
     state:state
  -> program:Lua_ast.stat list
  -> linkall:bool
  -> Lua_ast.stat list
(** [link ~state ~program ~linkall] combines runtime fragments with the main program.
    If [linkall] is true, includes all fragments. Otherwise, only includes required ones. *)
