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
  ; provides : string list
  ; requires : string list
  ; code : string
  }

type state =
  { fragments : fragment StringMap.t
  ; required : StringSet.t [@warning "-69"]
  }

let init () = { fragments = StringMap.empty; required = StringSet.empty }

(* Parse provides header: "--// Provides: foo, bar" -> ["foo"; "bar"] *)
let parse_provides (line : string) : string list =
  let prefix = "--// Provides:" in
  let prefix_len = String.length prefix in
  if String.length line >= prefix_len
     && String.equal (String.sub line ~pos:0 ~len:prefix_len) prefix
  then
    let rest = String.sub line ~pos:prefix_len ~len:(String.length line - prefix_len) in
    let symbols = String.split_on_char ~sep:',' rest in
    List.filter_map
      ~f:(fun s ->
        let trimmed = String.trim s in
        if String.length trimmed > 0 then Some trimmed else None)
      symbols
  else []

(* Parse requires header: "--// Requires: foo, bar" -> ["foo"; "bar"] *)
let parse_requires (line : string) : string list =
  let prefix = "--// Requires:" in
  let prefix_len = String.length prefix in
  if String.length line >= prefix_len
     && String.equal (String.sub line ~pos:0 ~len:prefix_len) prefix
  then
    let rest = String.sub line ~pos:prefix_len ~len:(String.length line - prefix_len) in
    let symbols = String.split_on_char ~sep:',' rest in
    List.filter_map
      ~f:(fun s ->
        let trimmed = String.trim s in
        if String.length trimmed > 0 then Some trimmed else None)
      symbols
  else []

(* Parse version constraint: "--// Version: >= 4.14" -> true/false *)
let parse_version (line : string) : bool =
  let prefix = "--// Version:" in
  let prefix_len = String.length prefix in
  if String.length line >= prefix_len
     && String.equal (String.sub line ~pos:0 ~len:prefix_len) prefix
  then
    let rest = String.sub line ~pos:prefix_len ~len:(String.length line - prefix_len) in
    let trimmed = String.trim rest in
    (* Parse operator and version: ">= 4.14", "= 5.0", etc. *)
    let parse_constraint s =
      if String.length s < 2 then None
      else
        let op_str, ver_str =
          if String.length s >= 2 && String.equal (String.sub s ~pos:0 ~len:2) ">="
          then ">=", String.sub s ~pos:2 ~len:(String.length s - 2)
          else if String.length s >= 2 && String.equal (String.sub s ~pos:0 ~len:2) "<="
          then "<=", String.sub s ~pos:2 ~len:(String.length s - 2)
          else if String.length s >= 1 && String.equal (String.sub s ~pos:0 ~len:1) ">"
          then ">", String.sub s ~pos:1 ~len:(String.length s - 1)
          else if String.length s >= 1 && String.equal (String.sub s ~pos:0 ~len:1) "<"
          then "<", String.sub s ~pos:1 ~len:(String.length s - 1)
          else if String.length s >= 1 && String.equal (String.sub s ~pos:0 ~len:1) "="
          then "=", String.sub s ~pos:1 ~len:(String.length s - 1)
          else "", s
        in
        if String.length op_str = 0 then None
        else
          let ver_str = String.trim ver_str in
          let op = match op_str with
            | ">=" -> (>=)
            | "<=" -> (<=)
            | ">" -> (>)
            | "<" -> (<)
            | "=" -> (=)
            | _ -> (=)
          in
          Some (op, ver_str)
    in
    match parse_constraint trimmed with
    | None -> true (* No valid constraint means accept all *)
    | Some (op, ver_str) ->
        op Ocaml_version.(compare current (split ver_str)) 0
  else true (* No version header means accept all *)

(* Parse complete fragment header from code string *)
let parse_fragment_header ~name (code : string) : fragment =
  let lines = String.split_on_char ~sep:'\n' code in
  let rec parse_headers provides requires version_ok = function
    | [] -> provides, requires, version_ok
    | line :: rest ->
        let trimmed = String.trim line in
        (* Stop at first non-comment line *)
        if String.length trimmed > 0
           && not (String.length trimmed >= 2
                   && String.equal (String.sub trimmed ~pos:0 ~len:2) "--")
        then provides, requires, version_ok
        (* Parse header directives *)
        else if String.length trimmed >= 4
                && String.equal (String.sub trimmed ~pos:0 ~len:4) "--//"
        then
          let new_provides =
            let p = parse_provides trimmed in
            if List.length p > 0 then p else provides
          in
          let new_requires =
            let r = parse_requires trimmed in
            if List.length r > 0 then r @ requires else requires
          in
          let new_version_ok = version_ok && parse_version trimmed in
          parse_headers new_provides new_requires new_version_ok rest
        else
          (* Regular comment, continue *)
          parse_headers provides requires version_ok rest
  in
  let provides, requires, version_ok = parse_headers [] [] true lines in
  (* If version constraint not satisfied, return empty provides/requires *)
  if not version_ok
  then { name; provides = []; requires = []; code }
  else
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
      |> List.filter ~f:(fun f -> Filename.check_suffix f ".lua")
      |> List.map ~f:(fun f -> Filename.concat dirname f)
    in
    List.map ~f:load_runtime_file files)
  else []

let add_fragment state fragment =
  { state with fragments = StringMap.add fragment.name fragment state.fragments }

(* Build provides map: symbol name → fragment name *)
let build_provides_map (fragments : fragment StringMap.t) : string StringMap.t =
  StringMap.fold
    (fun _frag_name fragment acc ->
      List.fold_left
        ~f:(fun map symbol ->
          match StringMap.find_opt symbol map with
          | None -> StringMap.add symbol fragment.name map
          | Some existing_frag ->
              if not (String.equal existing_frag fragment.name)
              then
                Warning.warn
                  `Overriding_primitive
                  "symbol %S provided by both fragment %S and fragment %S@."
                  symbol
                  existing_frag
                  fragment.name;
              map)
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
  let sorted, _cycles = topological_sort filtered_dep_graph filtered_in_degrees in

  (* Find missing dependencies *)
  let missing_set = find_missing_deps state.fragments provides_map in
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
  Buffer.add_string buf "-- Module loader\n";
  List.iter
    ~f:(fun frag ->
      Buffer.add_string buf ("-- " ^ frag.name ^ "\n");
      Buffer.add_string buf frag.code;
      Buffer.add_char buf '\n')
    fragments;
  Buffer.contents buf

let link ~state ~program ~linkall:_ =
  (* TODO: use linkall flag to determine which fragments to include *)
  let fragments_list = StringMap.fold (fun _ frag acc -> frag :: acc) state.fragments [] in
  let loader_code = generate_loader fragments_list in
  let loader_statement = Lua_ast.Comment loader_code in
  loader_statement :: program
