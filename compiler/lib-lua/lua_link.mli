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
  { name : string  (** Fragment name (basename of .lua file) *)
  ; provides : string list  (** List of caml_* function names this fragment provides *)
  ; requires : string list  (** List of caml_* function names this fragment requires *)
  ; code : string  (** Lua code content *)
  }

(** Linking state *)
type state

(** Initialize linking state *)
val init : unit -> state

(** Parse provides header from a line *)
val parse_provides : string -> string option
(** [parse_provides line] extracts a single symbol from a "--Provides: symbol" header.
    Each line declares ONE function name (matching js_of_ocaml semantics).
    Returns Some symbol if line matches the format, None otherwise.

    Example:
      parse_provides "--Provides: caml_array_make"  (* Returns Some "caml_array_make" *)
      parse_provides "-- Regular comment"           (* Returns None *)
*)

(** Parse requires header from a line *)
val parse_requires : string -> string list
(** [parse_requires line] extracts symbols from a "--Requires: sym1, sym2" header.
    Multiple dependencies can be listed on one line, comma-separated.
    Returns empty list if line doesn't match the format.

    Example:
      parse_requires "--Requires: caml_foo, caml_bar"  (* Returns ["caml_foo"; "caml_bar"] *)
      parse_requires "-- Regular comment"              (* Returns [] *)
*)

(** Parse primitive name using naming convention *)
val parse_primitive_name : string -> (string * string) option
(** [parse_primitive_name prim] parses a primitive name like "caml_array_make" into
    (module_name, func_name) using naming convention. Strips "caml_" prefix, splits
    on first underscore. Returns Some (module, func) on success, None if parsing fails.
    Defaults to ("core", func) for single-part names. *)

(** Find primitive implementation using hybrid strategy *)
val find_primitive_implementation : string -> fragment list -> (fragment * string) option
(** [find_primitive_implementation prim_name fragments] finds the fragment and function
    that implements a primitive using a two-tier strategy:
    1. Try naming convention first (e.g., "caml_array_make" → array.lua, M.make)
    2. Fall back to Export directive if not found
    Returns Some (fragment, func_name) if found, None otherwise. *)

(** Embed runtime code directly *)
val embed_runtime_module : fragment -> string
(** [embed_runtime_module frag] embeds a runtime fragment's code directly with a header
    comment. The code is embedded verbatim without any module wrapping or variable creation.
    Functions are already global with caml_* prefix, no transformation needed. *)

(** DEPRECATED: Generate wrapper function for a specific primitive *)
val generate_wrapper_for_primitive : string -> fragment -> string -> string
(** [generate_wrapper_for_primitive prim_name frag func_name] is deprecated and returns
    empty string. After refactoring, runtime fragments contain direct caml_* functions,
    so no wrappers are needed. Kept for API compatibility. *)

(** No wrappers needed - primitives are already global *)
val generate_wrappers : StringSet.t -> fragment list -> string
(** [generate_wrappers used_primitives fragments] returns empty string. After refactoring,
    all runtime functions are direct caml_* global functions with no module wrapping.
    The linker simply includes the right fragment files. Kept for API compatibility. *)

(** Parse complete fragment header from code string *)
val parse_fragment_header : name:string -> string -> fragment
(** [parse_fragment_header ~name code] parses all header directives from a Lua code string.
    Extracts --Provides: and --Requires: directives. Returns fragment with parsed metadata.
    Stops parsing at first non-comment line. Defaults to [name] if no Provides header found. *)

(** Load a runtime Lua file as a fragment *)
val load_runtime_file : string -> fragment

(** Load runtime Lua files from a directory *)
val load_runtime_dir : string -> fragment list

(** Add a fragment to the linking state *)
val add_fragment : state -> fragment -> state

(** Check for duplicate provides and issue warnings *)
val check_duplicate_provides : fragment StringMap.t -> unit
(** [check_duplicate_provides fragments] checks for symbols provided by multiple fragments
    and issues warnings. Later fragments override earlier ones in the provides map. *)

(** Build provides map: symbol name → fragment name *)
val build_provides_map : fragment StringMap.t -> string StringMap.t
(** [build_provides_map fragments] creates a map from symbol names to fragment names.
    Later fragments override earlier ones if they provide the same symbol. *)

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

(** Format circular dependency error message *)
val format_cycle_error : string list -> string
(** [format_cycle_error cycle_nodes] formats a user-friendly error message for circular
    dependencies. Shows the fragments involved in the cycle chain. Returns empty string
    if cycle_nodes is empty. *)

(** Format missing dependency error message *)
val format_missing_error : StringSet.t -> fragment StringMap.t -> string
(** [format_missing_error missing_symbols fragments] formats a user-friendly error message
    for missing dependencies. Lists each missing symbol and which fragments require it.
    Includes suggestions for resolving the issue. Returns empty string if no missing symbols. *)

(** Find missing dependencies *)
val find_missing_deps : fragment StringMap.t -> string StringMap.t -> StringSet.t
(** [find_missing_deps fragments provides_map] returns the set of symbols that are required
    by fragments but not provided by any fragment. Collects all required symbols across all
    fragments and checks each against the provides_map. *)

(** Resolve dependencies and determine load order *)
val resolve_deps : state -> string list -> string list * string list
(** [resolve_deps state required] returns [(ordered, missing)] where:
    - [ordered] is the topologically sorted list of required modules
    - [missing] is the list of missing dependencies (always empty on success)
    Raises [Failure] with a formatted error message if:
    - Circular dependencies are detected
    - Missing dependencies are found *)

(** Generate module registration code for a fragment *)
val generate_module_registration : fragment -> string
(** [generate_module_registration fragment] generates Lua code that registers the fragment's
    provided symbols in package.loaded. Each symbol is wrapped in a function containing
    the fragment's code. *)

(** Generate loader prologue *)
val generate_loader_prologue : unit -> string
(** [generate_loader_prologue ()] generates the header comment for the module loader. *)

(** Generate loader epilogue *)
val generate_loader_epilogue : fragment list -> string
(** [generate_loader_epilogue fragments] generates the closing comment for the module loader. *)

(** Generate Lua module loader code *)
val generate_loader : fragment list -> string
(** Generates Lua code that registers all modules using Lua's module system *)

(** Select fragments based on linkall flag and required symbols *)
val select_fragments : state -> linkall:bool -> string list -> fragment list
(** [select_fragments state ~linkall required] selects which fragments to include in the link.
    If [linkall] is true, returns all fragments. Otherwise, returns only fragments needed to
    satisfy [required] symbols and their transitive dependencies, in dependency order. *)

(** Link fragments with a main program *)
val link :
     state:state
  -> program:Lua_ast.stat list
  -> linkall:bool
  -> Lua_ast.stat list
(** [link ~state ~program ~linkall] combines runtime fragments with the main program.
    If [linkall] is true, includes all fragments. Otherwise, only includes required ones. *)
