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

open! Stdlib

type fragment =
  { name : string
  ; provides : string list  (** List of caml_* function names this fragment provides *)
  ; requires : string list  (** List of caml_* function names this fragment requires *)
  ; code : string  (** Lua code content *)
  }

type state =
  { fragments : fragment StringMap.t
  ; required : StringSet.t [@warning "-69"]
  }

let init () = { fragments = StringMap.empty; required = StringSet.empty }

(* Parse provides header: "--Provides: caml_foo" -> Some "caml_foo"
   Unlike js_of_ocaml which uses "//Provides:", Lua uses "--Provides:"
   Each line declares ONE function name (matching js_of_ocaml semantics).

   Example:
     --Provides: caml_array_make
     function caml_array_make(len, init)
       ...
     end
*)
let parse_provides (line : string) : string option =
  let prefix = "--Provides:" in
  let prefix_len = String.length prefix in
  if String.length line >= prefix_len
     && String.equal (String.sub line ~pos:0 ~len:prefix_len) prefix
  then
    let rest = String.sub line ~pos:prefix_len ~len:(String.length line - prefix_len) in
    let symbol = String.trim rest in
    if String.length symbol > 0 then Some symbol else None
  else None

(* Parse requires header: "--Requires: caml_foo caml_bar" -> ["caml_foo"; "caml_bar"]
   Unlike js_of_ocaml which uses "//Requires:", Lua uses "--Requires:"
   Multiple dependencies can be listed on one line, space or comma-separated.

   Examples:
     --Requires: caml_make_vect caml_array_get
     --Requires: caml_make_vect, caml_array_get
*)
let parse_requires (line : string) : string list =
  let prefix = "--Requires:" in
  let prefix_len = String.length prefix in
  if String.length line >= prefix_len
     && String.equal (String.sub line ~pos:0 ~len:prefix_len) prefix
  then
    let rest = String.sub line ~pos:prefix_len ~len:(String.length line - prefix_len) in
    (* Split on both space and comma *)
    let normalized = String.map ~f:(function ',' -> ' ' | c -> c) rest in
    let symbols = String.split_on_char ~sep:' ' normalized in
    List.filter_map
      ~f:(fun s ->
        let trimmed = String.trim s in
        if String.length trimmed > 0 then Some trimmed else None)
      symbols
  else []

(* Parse complete fragment header from code string
   Parses all --Provides: and --Requires: comments from the beginning of the file.
   Each --Provides: declares one function. Multiple --Provides: lines can exist.

   Example fragment:
     --Provides: caml_array_make
     --Requires: caml_make_vect
     function caml_array_make(len, init)
       return caml_make_vect(len, init)
     end

     --Provides: caml_array_get
     function caml_array_get(arr, idx)
       ...
     end
*)
let parse_fragment_header ~name (code : string) : fragment =
  let lines = String.split_on_char ~sep:'\n' code in
  let rec parse_headers provides requires = function
    | [] -> provides, requires
    | line :: rest ->
        let trimmed = String.trim line in
        (* Parse --Provides: directive from anywhere in file *)
        if String.starts_with ~prefix:"--Provides:" trimmed
        then
          let new_provides =
            match parse_provides trimmed with
            | Some symbol -> symbol :: provides
            | None -> provides
          in
          parse_headers new_provides requires rest
        (* Parse --Requires: directive from anywhere in file *)
        else if String.starts_with ~prefix:"--Requires:" trimmed
        then
          let new_requires =
            let r = parse_requires trimmed in
            if List.length r > 0 then r @ requires else requires
          in
          parse_headers provides new_requires rest
        else
          (* Not a provides/requires comment, continue scanning *)
          parse_headers provides requires rest
  in
  let provides, requires = parse_headers [] [] lines in
  (* Reverse provides list to maintain declaration order *)
  let provides = List.rev provides in
  (* If no provides found, default to fragment name *)
  let provides = if List.length provides = 0 then [name] else provides in
  { name; provides; requires; code }

let load_runtime_file filename =
  let ic = open_in_bin filename in
  let code = really_input_string ic (in_channel_length ic) in
  close_in ic;
  let name = Filename.basename filename |> Filename.chop_extension in
  parse_fragment_header ~name code

let load_runtime_dir dirname =
  if Sys.file_exists dirname && Sys.is_directory dirname
  then (
    let files =
      Sys.readdir dirname
      |> Array.to_list
      |> List.filter ~f:(fun f ->
          (* Include only .lua files that are runtime fragments *)
          Filename.check_suffix f ".lua"
          (* Exclude test files *)
          && not (String.starts_with ~prefix:"test_" f)
          (* Exclude benchmark files *)
          && not (String.starts_with ~prefix:"benchmark_" f)
          && not (String.starts_with ~prefix:"benchmarks" f)
          (* Exclude library modules that use module patterns *)
          && not (String.equal f "compat_bit.lua")
          (* Exclude documentation/example files *)
          && not (String.starts_with ~prefix:"example_" f))
      |> List.map ~f:(fun f -> Filename.concat dirname f)
    in
    List.map ~f:load_runtime_file files)
  else []

let add_fragment state fragment =
  { state with fragments = StringMap.add fragment.name fragment state.fragments }

(* Check for duplicate provides and issue warnings *)
let check_duplicate_provides (fragments : fragment StringMap.t) : unit =
  (* Build a map from symbol to list of fragments providing it *)
  let symbol_providers =
    StringMap.fold
      (fun _frag_name fragment acc ->
        List.fold_left
          ~f:(fun map symbol ->
            let providers =
              StringMap.find_opt symbol map |> Option.value ~default:[]
            in
            StringMap.add symbol (fragment.name :: providers) map)
          ~init:acc
          fragment.provides)
      fragments
      StringMap.empty
  in
  (* Check each symbol for duplicates *)
  StringMap.iter
    (fun symbol providers ->
      match providers with
      | [] | [_] -> () (* No duplicates *)
      | _ :: _ :: _ ->
          (* Multiple providers - issue warning *)
          let providers_str = String.concat ~sep:", " (List.rev providers) in
          Warning.warn
            `Overriding_primitive
            "symbol %S provided by multiple fragments: %s (later fragments override earlier ones)@."
            symbol
            providers_str)
    symbol_providers

(* Build provides map: symbol name → fragment name *)
let build_provides_map (fragments : fragment StringMap.t) : string StringMap.t =
  StringMap.fold
    (fun _frag_name fragment acc ->
      List.fold_left
        ~f:(fun map symbol ->
          (* Later fragments override earlier ones *)
          StringMap.add symbol fragment.name map)
        ~init:acc
        fragment.provides)
    fragments
    StringMap.empty

(* Build dependency graph: fragment name → set of required fragment names *)
let build_dep_graph
    (fragments : fragment StringMap.t)
    (provides_map : string StringMap.t)
    : (string * StringSet.t) StringMap.t =
  StringMap.fold
    (fun frag_name fragment acc ->
      let deps =
        List.fold_left
          ~f:(fun dep_set required_symbol ->
            match StringMap.find_opt required_symbol provides_map with
            | Some provider_frag ->
                (* Don't add self-dependency *)
                if String.equal provider_frag frag_name
                then dep_set
                else StringSet.add provider_frag dep_set
            | None ->
                (* Symbol not provided by any fragment - will be caught later as missing *)
                dep_set)
          ~init:StringSet.empty
          fragment.requires
      in
      StringMap.add frag_name (frag_name, deps) acc)
    fragments
    StringMap.empty

(* Calculate in-degrees: fragment name → count of incoming edges *)
let calculate_in_degrees (dep_graph : (string * StringSet.t) StringMap.t) : int StringMap.t =
  (* First, initialize all nodes with in-degree 0 *)
  let in_degrees =
    StringMap.fold
      (fun frag_name _ acc -> StringMap.add frag_name 0 acc)
      dep_graph
      StringMap.empty
  in
  (* Then, count incoming edges for each node *)
  (* If fragment A depends on fragment B, then there's an edge B→A, so A's in-degree increases *)
  StringMap.fold
    (fun frag_name (_name, deps) acc ->
      (* frag_name depends on each element in deps *)
      (* So each dependency is a source, and frag_name is the target *)
      (* Therefore, frag_name's in-degree should equal the size of deps *)
      StringMap.add frag_name (StringSet.cardinal deps) acc)
    dep_graph
    in_degrees

(* Topological sort using Kahn's algorithm *)
let topological_sort
    (dep_graph : (string * StringSet.t) StringMap.t)
    (in_degrees : int StringMap.t)
    : string list * string list =
  (* Build reverse graph: fragment name → set of fragments that depend on it *)
  let reverse_graph =
    StringMap.fold
      (fun frag_name (_name, deps) acc ->
        StringSet.fold
          (fun dep reverse_acc ->
            let dependents =
              StringMap.find_opt dep reverse_acc
              |> Option.value ~default:StringSet.empty
            in
            StringMap.add dep (StringSet.add frag_name dependents) reverse_acc)
          deps
          acc)
      dep_graph
      StringMap.empty
  in
  (* Initialize queue with all nodes that have in-degree 0 *)
  let initial_queue =
    StringMap.fold
      (fun frag_name degree acc ->
        if degree = 0 then frag_name :: acc else acc)
      in_degrees
      []
  in
  (* Process nodes using Kahn's algorithm *)
  let rec process queue sorted remaining_in_degrees =
    match queue with
    | [] ->
        (* All nodes processed - check if all nodes were visited *)
        let total_nodes = StringMap.cardinal dep_graph in
        let sorted_count = List.length sorted in
        if sorted_count < total_nodes
        then
          (* Cycle detected - return sorted nodes and nodes still in graph *)
          let cycle_nodes =
            StringMap.fold
              (fun frag_name _ acc ->
                if List.mem ~eq:String.equal frag_name sorted
                then acc
                else frag_name :: acc)
              dep_graph
              []
          in
          List.rev sorted, cycle_nodes
        else List.rev sorted, []
    | node :: rest_queue ->
        (* Process current node *)
        let sorted' = node :: sorted in
        (* Get fragments that depend on current node *)
        let dependents =
          StringMap.find_opt node reverse_graph
          |> Option.value ~default:StringSet.empty
        in
        (* Update in-degrees and queue for all dependents *)
        let remaining_in_degrees', new_queue =
          StringSet.fold
            (fun dependent (in_deg_map, queue_acc) ->
              let current_degree =
                StringMap.find_opt dependent in_deg_map |> Option.value ~default:0
              in
              let new_degree = current_degree - 1 in
              let in_deg_map' = StringMap.add dependent new_degree in_deg_map in
              let queue_acc' =
                if new_degree = 0 then dependent :: queue_acc else queue_acc
              in
              in_deg_map', queue_acc')
            dependents
            (remaining_in_degrees, rest_queue)
        in
        process new_queue sorted' remaining_in_degrees'
  in
  process initial_queue [] in_degrees

(* Format circular dependency error message *)
let format_cycle_error (cycle_nodes : string list) : string =
  if List.length cycle_nodes = 0
  then ""
  else
    let buf = Buffer.create 256 in
    Buffer.add_string buf "Circular dependency detected:\n";

    (* Try to find an actual cycle path by following dependencies *)
    (* For now, just list the fragments involved in the cycle *)
    Buffer.add_string buf "  Fragments involved in cycle: ";
    Buffer.add_string buf (String.concat ~sep:" → " cycle_nodes);
    Buffer.add_string buf " → ...";
    Buffer.add_string buf "\n";
    Buffer.add_string buf "  Cannot resolve dependencies due to circular references.";

    Buffer.contents buf

(* Format missing dependency error message *)
let format_missing_error
    (missing_symbols : StringSet.t)
    (fragments : fragment StringMap.t)
    : string =
  if StringSet.is_empty missing_symbols
  then ""
  else
    let buf = Buffer.create 256 in
    Buffer.add_string buf "Missing dependencies detected:\n";

    (* For each missing symbol, find which fragments require it *)
    StringSet.iter
      (fun symbol ->
        Buffer.add_string buf ("  Symbol '" ^ symbol ^ "' required by:\n");
        StringMap.iter
          (fun _frag_name fragment ->
            if List.mem ~eq:String.equal symbol fragment.requires
            then Buffer.add_string buf ("    - " ^ fragment.name ^ "\n"))
          fragments)
      missing_symbols;

    Buffer.add_string buf "\n";
    Buffer.add_string buf "  Possible solutions:\n";
    Buffer.add_string buf "    - Add runtime fragments that provide these symbols\n";
    Buffer.add_string buf "    - Check for typos in symbol names\n";
    Buffer.add_string buf "    - Ensure all required runtime files are loaded";

    Buffer.contents buf

(* Find missing dependencies: symbols required but not provided *)
let find_missing_deps
    (fragments : fragment StringMap.t)
    (provides_map : string StringMap.t)
    : StringSet.t =
  (* Collect all required symbols from all fragments *)
  let all_required =
    StringMap.fold
      (fun _frag_name fragment acc ->
        List.fold_left
          ~f:(fun set symbol -> StringSet.add symbol set)
          ~init:acc
          fragment.requires)
      fragments
      StringSet.empty
  in
  (* Filter out symbols that are provided *)
  StringSet.filter
    (fun symbol -> not (StringMap.mem symbol provides_map))
    all_required

let resolve_deps state required =
  (* Check for duplicate provides and issue warnings *)
  check_duplicate_provides state.fragments;

  (* Build provides map: symbol name → fragment name *)
  let provides_map = build_provides_map state.fragments in

  (* Find which fragments provide the required symbols *)
  let required_fragments =
    List.fold_left
      ~f:(fun acc symbol ->
        match StringMap.find_opt symbol provides_map with
        | Some frag_name -> StringSet.add frag_name acc
        | None -> acc (* Missing symbols will be detected later *))
      ~init:StringSet.empty
      required
  in

  (* Build dependency graph *)
  let dep_graph = build_dep_graph state.fragments provides_map in

  (* Calculate in-degrees *)
  let in_degrees = calculate_in_degrees dep_graph in

  (* Collect all fragments needed (required + their transitive dependencies) *)
  let rec collect_deps acc to_visit =
    match to_visit with
    | [] -> acc
    | frag_name :: rest ->
        if StringSet.mem frag_name acc
        then collect_deps acc rest
        else
          let acc' = StringSet.add frag_name acc in
          (* Get dependencies of this fragment *)
          let deps =
            match StringMap.find_opt frag_name dep_graph with
            | Some (_name, dep_set) -> StringSet.elements dep_set
            | None -> []
          in
          collect_deps acc' (deps @ rest)
  in
  let all_needed = collect_deps StringSet.empty (StringSet.elements required_fragments) in

  (* Filter dep_graph and in_degrees to only include needed fragments *)
  let filtered_dep_graph =
    StringMap.filter (fun frag_name _ -> StringSet.mem frag_name all_needed) dep_graph
  in
  let filtered_in_degrees =
    StringMap.filter (fun frag_name _ -> StringSet.mem frag_name all_needed) in_degrees
  in

  (* Run topological sort on the filtered graph *)
  let sorted, cycles = topological_sort filtered_dep_graph filtered_in_degrees in

  (* Check for circular dependencies *)
  if List.length cycles > 0
  then
    let error_msg = format_cycle_error cycles in
    failwith error_msg
  else
    (* Find missing dependencies *)
    let missing_set = find_missing_deps state.fragments provides_map in

    (* Check for missing dependencies and report error *)
    if not (StringSet.is_empty missing_set)
    then
      let error_msg = format_missing_error missing_set state.fragments in
      failwith error_msg
    else
      let missing = StringSet.elements missing_set in
      (sorted, missing)

(* Generate module registration code for a fragment *)
let generate_module_registration (fragment : fragment) : string =
  let buf = Buffer.create 256 in

  (* Add comment header *)
  Buffer.add_string buf ("-- Fragment: " ^ fragment.name ^ "\n");

  (* Generate registration for each provided symbol *)
  List.iter
    ~f:(fun symbol ->
      Buffer.add_string buf ("package.loaded[\"" ^ symbol ^ "\"] = function()\n");

      (* Indent the fragment code *)
      let lines = String.split_on_char ~sep:'\n' fragment.code in
      List.iter
        ~f:(fun line ->
          if String.length line > 0
          then Buffer.add_string buf ("  " ^ line ^ "\n")
          else Buffer.add_char buf '\n')
        lines;

      Buffer.add_string buf "end\n")
    fragment.provides;

  Buffer.contents buf

(* Generate loader prologue *)
let generate_loader_prologue () : string =
  let buf = Buffer.create 128 in
  Buffer.add_string buf "-- Lua_of_ocaml runtime loader\n";
  Buffer.add_string buf "-- This code registers runtime modules in package.loaded\n";
  Buffer.add_string buf "\n";
  Buffer.contents buf

(* Generate loader epilogue *)
let generate_loader_epilogue (_fragments : fragment list) : string =
  let buf = Buffer.create 128 in
  Buffer.add_string buf "\n";
  Buffer.add_string buf "-- End of runtime loader\n";
  Buffer.contents buf

let generate_loader fragments =
  let buf = Buffer.create 1024 in

  (* Add prologue *)
  Buffer.add_string buf (generate_loader_prologue ());

  (* Add module registration for each fragment *)
  List.iter
    ~f:(fun frag ->
      Buffer.add_string buf (generate_module_registration frag))
    fragments;

  (* Add epilogue *)
  Buffer.add_string buf (generate_loader_epilogue fragments);

  Buffer.contents buf

(* Parse primitive name to find module and function by naming convention *)
let parse_primitive_name (prim : string) : (string * string) option =
  (* Strip caml_ prefix *)
  let name =
    if String.starts_with ~prefix:"caml_" prim
    then String.sub prim ~pos:5 ~len:(String.length prim - 5)
    else prim
  in
  (* Try splitting on first underscore *)
  match String.split_on_char ~sep:'_' name with
  | [] -> None
  | [ func ] -> Some ("core", func) (* Default to core module *)
  | module_name :: func_parts -> Some (module_name, String.concat ~sep:"_" func_parts)

(* Find primitive implementation using naming convention.
   After refactoring, all primitives use caml_* names directly.
   No more Export directives or module wrappers needed. *)
let find_primitive_implementation
    (_prim_name : string)
    (_fragments : fragment list)
    : (fragment * string) option
  =
  (* NOTE: This function is deprecated after refactoring.
     All primitives will be direct caml_* functions, no wrappers needed.
     Kept for compatibility during transition. *)
  None

(* Embed runtime module code directly (NOT wrapped in package.loaded) *)
let embed_runtime_module (frag : fragment) : string =
  let buf = Buffer.create 512 in
  (* Add comment header *)
  Buffer.add_string buf ("-- Runtime: " ^ frag.name ^ "\n");
  (* Embed code verbatim - no module wrapping needed *)
  Buffer.add_string buf frag.code;
  if not (String.ends_with ~suffix:"\n" frag.code)
  then Buffer.add_char buf '\n';
  Buffer.add_char buf '\n';
  Buffer.contents buf

(* DEPRECATED: No wrappers needed after refactoring to direct caml_* functions *)
let generate_wrapper_for_primitive
    (_prim_name : string)
    (_frag : fragment)
    (_func_name : string)
    : string
  =
  (* After refactoring, runtime fragments contain direct caml_* functions.
     No module wrapping means no wrappers needed. Kept for compatibility. *)
  ""

(* No wrappers needed - primitives are already global functions with caml_* prefix *)
let generate_wrappers (_used_primitives : StringSet.t) (_fragments : fragment list)
    : string
  =
  (* After refactoring, all runtime functions are direct caml_* global functions.
     No module wrapping, so no wrappers needed. Linker just includes the right fragments. *)
  ""

(* Select fragments based on linkall flag and required symbols *)
let select_fragments state ~linkall required =
  if linkall
  then
    (* Include all fragments *)
    StringMap.fold (fun _ frag acc -> frag :: acc) state.fragments []
  else
    (* Include only required fragments and their dependencies *)
    let sorted, _missing = resolve_deps state required in
    (* Convert fragment names to fragment list in dependency order *)
    List.filter_map
      ~f:(fun frag_name -> StringMap.find_opt frag_name state.fragments)
      sorted

let link ~state ~program ~linkall =
  (* For now, include all fragments since we don't analyze program for requirements yet *)
  let fragments_list = select_fragments state ~linkall [] in
  let loader_code = generate_loader fragments_list in
  let loader_statement = Lua_ast.Comment loader_code in
  loader_statement :: program
