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

open Stdlib

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

(** Parse version constraint from a line *)
val parse_version : string -> bool
(** [parse_version line] checks if the version constraint in a "--// Version: >= 4.14" header
    is satisfied by the current OCaml version. Returns true if constraint is satisfied or
    if line doesn't match the format. Supports operators: >=, <=, >, <, = *)

(** Parse complete fragment header from code string *)
val parse_fragment_header : name:string -> string -> fragment
(** [parse_fragment_header ~name code] parses all header directives from a Lua code string.
    Extracts Provides, Requires, and Version directives. Returns fragment with parsed metadata.
    Stops parsing at first non-comment line. If version constraint not satisfied, returns
    fragment with empty provides/requires. Defaults to [name] if no Provides header found. *)

(** Load a runtime Lua file as a fragment *)
val load_runtime_file : string -> fragment

(** Load runtime Lua files from a directory *)
val load_runtime_dir : string -> fragment list

(** Add a fragment to the linking state *)
val add_fragment : state -> fragment -> state

(** Build provides map: symbol name → fragment name *)
val build_provides_map : fragment StringMap.t -> string StringMap.t
(** [build_provides_map fragments] creates a map from symbol names to fragment names.
    Issues a warning if multiple fragments provide the same symbol. *)

(** Build dependency graph: fragment name → (fragment name * set of required fragment names) *)
val build_dep_graph :
     fragment StringMap.t
  -> string StringMap.t
  -> (string * StringSet.t) StringMap.t
(** [build_dep_graph fragments provides_map] creates a dependency graph mapping each fragment
    to the set of fragments it depends on. Uses provides_map to resolve symbol names to fragments.
    Filters out self-dependencies. Missing symbols are ignored (will be detected later). *)

(** Calculate in-degrees: fragment name → count of incoming edges *)
val calculate_in_degrees : (string * StringSet.t) StringMap.t -> int StringMap.t
(** [calculate_in_degrees dep_graph] computes the in-degree (number of dependents) for each
    fragment in the dependency graph. Returns a map from fragment name to its in-degree count.
    Used for topological sorting with Kahn's algorithm. *)

(** Topological sort using Kahn's algorithm *)
val topological_sort :
     (string * StringSet.t) StringMap.t
  -> int StringMap.t
  -> string list * string list
(** [topological_sort dep_graph in_degrees] performs topological sorting on the dependency graph.
    Returns [(sorted, cycles)] where:
    - [sorted] is the list of fragments in topologically sorted order (dependencies first)
    - [cycles] is the list of fragments involved in cycles (empty if no cycles).
    Uses Kahn's algorithm: starts with zero in-degree nodes, processes dependencies. *)

(** Find missing dependencies *)
val find_missing_deps : fragment StringMap.t -> string StringMap.t -> StringSet.t
(** [find_missing_deps fragments provides_map] returns the set of symbols that are required
    by fragments but not provided by any fragment. Collects all required symbols across all
    fragments and checks each against the provides_map. *)

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
