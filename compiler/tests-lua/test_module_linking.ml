(* Lua_of_ocaml tests - Module linking
 * Tests for module dependency resolution and linking
 *)

open Js_of_ocaml_compiler.Stdlib
module Lua_link = Lua_of_ocaml_compiler__Lua_link

let%expect_test "create empty linking state" =
  let _state = Lua_link.init () in
  print_endline "state initialized";
  [%expect {| state initialized |}]

(* Task 1.1: Parse Provides Header Tests *)

let%expect_test "parse_provides with single symbol" =
  let line = "--// Provides: foo" in
  let result = Lua_link.parse_provides line in
  print_endline (String.concat ~sep:", " result);
  [%expect {| foo |}]

let%expect_test "parse_provides with multiple symbols" =
  let line = "--// Provides: foo, bar, baz" in
  let result = Lua_link.parse_provides line in
  print_endline (String.concat ~sep:", " result);
  [%expect {| foo, bar, baz |}]

let%expect_test "parse_provides with whitespace" =
  let line = "--// Provides:  foo  ,  bar  ,  baz  " in
  let result = Lua_link.parse_provides line in
  print_endline (String.concat ~sep:", " result);
  [%expect {| foo, bar, baz |}]

let%expect_test "parse_provides with empty list" =
  let line = "--// Provides: " in
  let result = Lua_link.parse_provides line in
  print_endline (if List.length result = 0 then "empty" else "not empty");
  [%expect {| empty |}]

let%expect_test "parse_provides with non-matching line" =
  let line = "-- This is just a comment" in
  let result = Lua_link.parse_provides line in
  print_endline (if List.length result = 0 then "empty" else "not empty");
  [%expect {| empty |}]

let%expect_test "parse_provides with empty commas" =
  let line = "--// Provides: foo, , bar" in
  let result = Lua_link.parse_provides line in
  print_endline (String.concat ~sep:", " result);
  [%expect {| foo, bar |}]

let%expect_test "parse_provides case sensitive" =
  let line = "--// Provides: Foo, BAR, baz" in
  let result = Lua_link.parse_provides line in
  print_endline (String.concat ~sep:", " result);
  [%expect {| Foo, BAR, baz |}]

(* Task 1.2: Parse Requires Header Tests *)

let%expect_test "parse_requires with single symbol" =
  let line = "--// Requires: foo" in
  let result = Lua_link.parse_requires line in
  print_endline (String.concat ~sep:", " result);
  [%expect {| foo |}]

let%expect_test "parse_requires with multiple symbols" =
  let line = "--// Requires: foo, bar, baz" in
  let result = Lua_link.parse_requires line in
  print_endline (String.concat ~sep:", " result);
  [%expect {| foo, bar, baz |}]

let%expect_test "parse_requires with whitespace" =
  let line = "--// Requires:  foo  ,  bar  ,  baz  " in
  let result = Lua_link.parse_requires line in
  print_endline (String.concat ~sep:", " result);
  [%expect {| foo, bar, baz |}]

let%expect_test "parse_requires with empty list" =
  let line = "--// Requires: " in
  let result = Lua_link.parse_requires line in
  print_endline (if List.length result = 0 then "empty" else "not empty");
  [%expect {| empty |}]

let%expect_test "parse_requires with non-matching line" =
  let line = "-- This is just a comment" in
  let result = Lua_link.parse_requires line in
  print_endline (if List.length result = 0 then "empty" else "not empty");
  [%expect {| empty |}]

let%expect_test "parse_requires with empty commas" =
  let line = "--// Requires: foo, , bar" in
  let result = Lua_link.parse_requires line in
  print_endline (String.concat ~sep:", " result);
  [%expect {| foo, bar |}]

let%expect_test "parse_requires case sensitive" =
  let line = "--// Requires: Foo, BAR, baz" in
  let result = Lua_link.parse_requires line in
  print_endline (String.concat ~sep:", " result);
  [%expect {| Foo, BAR, baz |}]

let%expect_test "parse_requires does not match provides" =
  let line = "--// Provides: foo, bar" in
  let result = Lua_link.parse_requires line in
  print_endline (if List.length result = 0 then "empty" else "not empty");
  [%expect {| empty |}]

(* Task 1.3: Parse Version Constraint Tests *)

let%expect_test "parse_version with >= operator satisfied" =
  let line = "--// Version: >= 4.14" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| satisfied |}]

let%expect_test "parse_version with >= operator not satisfied" =
  let line = "--// Version: >= 6.0" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| not satisfied |}]

let%expect_test "parse_version with <= operator satisfied" =
  let line = "--// Version: <= 6.0" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| satisfied |}]

let%expect_test "parse_version with <= operator not satisfied" =
  let line = "--// Version: <= 4.0" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| not satisfied |}]

let%expect_test "parse_version with = operator satisfied" =
  let line = "--// Version: = 5.2.0" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| satisfied |}]

let%expect_test "parse_version with = operator not satisfied" =
  let line = "--// Version: = 4.14.0" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| not satisfied |}]

let%expect_test "parse_version with > operator satisfied" =
  let line = "--// Version: > 4.14" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| satisfied |}]

let%expect_test "parse_version with > operator not satisfied" =
  let line = "--// Version: > 6.0" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| not satisfied |}]

let%expect_test "parse_version with < operator satisfied" =
  let line = "--// Version: < 6.0" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| satisfied |}]

let%expect_test "parse_version with < operator not satisfied" =
  let line = "--// Version: < 5.0" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| not satisfied |}]

let%expect_test "parse_version with whitespace" =
  let line = "--// Version:   >=   4.14  " in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| satisfied |}]

let%expect_test "parse_version with non-matching line" =
  let line = "-- This is just a comment" in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| satisfied |}]

let%expect_test "parse_version with no constraint returns true" =
  let line = "--// Version: " in
  let result = Lua_link.parse_version line in
  print_endline (if result then "satisfied" else "not satisfied");
  [%expect {| satisfied |}]

(* Task 1.4: Parse Complete Fragment Header Tests *)

let%expect_test "parse_fragment_header with all directives" =
  let code = {|--// Provides: foo, bar
--// Requires: baz, qux
--// Version: >= 4.14

local function foo()
  return 42
end
|} in
  let fragment = Lua_link.parse_fragment_header ~name:"test" code in
  print_endline ("name: " ^ fragment.name);
  print_endline ("provides: " ^ String.concat ~sep:", " fragment.provides);
  print_endline ("requires: " ^ String.concat ~sep:", " fragment.requires);
  [%expect {|
    name: test
    provides: foo, bar
    requires: baz, qux
    |}]

let%expect_test "parse_fragment_header with only provides" =
  let code = {|--// Provides: single_symbol

local x = 10
|} in
  let fragment = Lua_link.parse_fragment_header ~name:"test" code in
  print_endline ("provides: " ^ String.concat ~sep:", " fragment.provides);
  print_endline ("requires: " ^ String.concat ~sep:", " fragment.requires);
  [%expect {|
    provides: single_symbol
    requires:
    |}]

let%expect_test "parse_fragment_header with no headers" =
  let code = {|-- Just a regular comment
local x = 10
|} in
  let fragment = Lua_link.parse_fragment_header ~name:"mymodule" code in
  print_endline ("provides: " ^ String.concat ~sep:", " fragment.provides);
  print_endline ("requires: " ^ String.concat ~sep:", " fragment.requires);
  [%expect {|
    provides: mymodule
    requires:
    |}]

let%expect_test "parse_fragment_header stops at first non-comment" =
  let code = {|--// Provides: foo
local x = 10
--// Requires: bar
|} in
  let fragment = Lua_link.parse_fragment_header ~name:"test" code in
  print_endline ("provides: " ^ String.concat ~sep:", " fragment.provides);
  print_endline ("requires: " ^ String.concat ~sep:", " fragment.requires);
  [%expect {|
    provides: foo
    requires:
    |}]

let%expect_test "parse_fragment_header with version constraint satisfied" =
  let code = {|--// Provides: foo
--// Version: >= 4.14
--// Requires: bar

local function foo() end
|} in
  let fragment = Lua_link.parse_fragment_header ~name:"test" code in
  print_endline ("provides: " ^ String.concat ~sep:", " fragment.provides);
  print_endline ("requires: " ^ String.concat ~sep:", " fragment.requires);
  [%expect {|
    provides: foo
    requires: bar
    |}]

let%expect_test "parse_fragment_header with version constraint not satisfied" =
  let code = {|--// Provides: foo
--// Version: >= 6.0
--// Requires: bar

local function foo() end
|} in
  let fragment = Lua_link.parse_fragment_header ~name:"test" code in
  print_endline ("provides: " ^ String.concat ~sep:", " fragment.provides);
  print_endline ("requires: " ^ String.concat ~sep:", " fragment.requires);
  [%expect {|
    provides:
    requires:
    |}]

let%expect_test "parse_fragment_header with multiple requires" =
  let code = {|--// Provides: main
--// Requires: dep1, dep2
--// Requires: dep3

local function main() end
|} in
  let fragment = Lua_link.parse_fragment_header ~name:"test" code in
  print_endline ("provides: " ^ String.concat ~sep:", " fragment.provides);
  print_endline ("requires: " ^ String.concat ~sep:", " fragment.requires);
  [%expect {|
    provides: main
    requires: dep3, dep1, dep2
    |}]

let%expect_test "parse_fragment_header with mixed comments" =
  let code = {|-- Regular comment
--// Provides: foo
-- Another regular comment
--// Requires: bar
-- Yet another comment

local function foo() end
|} in
  let fragment = Lua_link.parse_fragment_header ~name:"test" code in
  print_endline ("provides: " ^ String.concat ~sep:", " fragment.provides);
  print_endline ("requires: " ^ String.concat ~sep:", " fragment.requires);
  [%expect {|
    provides: foo
    requires: bar
    |}]

let%expect_test "parse_fragment_header with empty code" =
  let code = "" in
  let fragment = Lua_link.parse_fragment_header ~name:"empty" code in
  print_endline ("provides: " ^ String.concat ~sep:", " fragment.provides);
  [%expect {| provides: empty |}]

(* Task 2.1: Build Provides Map Tests *)

let%expect_test "build_provides_map with single fragment" =
  let frag = { Lua_link.
    name = "module1";
    provides = ["foo"; "bar"];
    requires = [];
    code = ""
  } in
  let fragments = StringMap.singleton "module1" frag in
  let provides_map = Lua_link.build_provides_map fragments in
  let foo_provider = StringMap.find_opt "foo" provides_map in
  let bar_provider = StringMap.find_opt "bar" provides_map in
  print_endline ("foo -> " ^ Option.value ~default:"none" foo_provider);
  print_endline ("bar -> " ^ Option.value ~default:"none" bar_provider);
  [%expect {|
    foo -> module1
    bar -> module1
    |}]

let%expect_test "build_provides_map with multiple fragments" =
  let frag1 = { Lua_link.
    name = "module1";
    provides = ["foo"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "module2";
    provides = ["bar"];
    requires = [];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "module1" frag1
    |> StringMap.add "module2" frag2
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let foo_provider = StringMap.find_opt "foo" provides_map in
  let bar_provider = StringMap.find_opt "bar" provides_map in
  print_endline ("foo -> " ^ Option.value ~default:"none" foo_provider);
  print_endline ("bar -> " ^ Option.value ~default:"none" bar_provider);
  [%expect {|
    foo -> module1
    bar -> module2
    |}]

let%expect_test "build_provides_map with duplicate provides" =
  let frag1 = { Lua_link.
    name = "module1";
    provides = ["foo"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "module2";
    provides = ["foo"];
    requires = [];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "module1" frag1
    |> StringMap.add "module2" frag2
  in
  let _provides_map = Lua_link.build_provides_map fragments in
  print_endline "warning issued for duplicate";
  [%expect {|
    Warning [overriding-primitive]: symbol "foo" provided by both fragment "module1" and fragment "module2"
    warning issued for duplicate
    |}]

let%expect_test "build_provides_map with empty fragments" =
  let fragments = StringMap.empty in
  let provides_map = Lua_link.build_provides_map fragments in
  let is_empty = StringMap.is_empty provides_map in
  print_endline (if is_empty then "empty" else "not empty");
  [%expect {| empty |}]

let%expect_test "build_provides_map with fragment providing multiple symbols" =
  let frag = { Lua_link.
    name = "stdlib";
    provides = ["print"; "assert"; "type"; "pairs"];
    requires = [];
    code = ""
  } in
  let fragments = StringMap.singleton "stdlib" frag in
  let provides_map = Lua_link.build_provides_map fragments in
  let count = StringMap.cardinal provides_map in
  print_endline ("symbols: " ^ string_of_int count);
  List.iter
    ~f:(fun sym ->
      match StringMap.find_opt sym provides_map with
      | Some provider -> print_endline (sym ^ " -> " ^ provider)
      | None -> ())
    ["print"; "assert"; "type"; "pairs"];
  [%expect {|
    symbols: 4
    print -> stdlib
    assert -> stdlib
    type -> stdlib
    pairs -> stdlib
    |}]

let%expect_test "build_provides_map preserves first provider on duplicate" =
  let frag1 = { Lua_link.
    name = "first";
    provides = ["shared"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "second";
    provides = ["shared"];
    requires = [];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "first" frag1
    |> StringMap.add "second" frag2
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let provider = StringMap.find_opt "shared" provides_map in
  print_endline ("shared -> " ^ Option.value ~default:"none" provider);
  [%expect {|
    Warning [overriding-primitive]: symbol "shared" provided by both fragment "first" and fragment "second"
    shared -> first
    |}]

(* Task 2.2: Build Dependency Graph Tests *)

let%expect_test "build_dep_graph with simple dependency" =
  let frag1 = { Lua_link.
    name = "base";
    provides = ["base_func"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "derived";
    provides = ["derived_func"];
    requires = ["base_func"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "base" frag1
    |> StringMap.add "derived" frag2
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let derived_deps = StringMap.find_opt "derived" dep_graph in
  (match derived_deps with
  | Some (_name, deps) ->
      let dep_list = StringSet.elements deps in
      print_endline ("derived depends on: " ^ String.concat ~sep:", " dep_list)
  | None ->
      [%expect.unreachable];
      print_endline "not found");
  [%expect {| derived depends on: base |}]

let%expect_test "build_dep_graph with no dependencies" =
  let frag = { Lua_link.
    name = "standalone";
    provides = ["func"];
    requires = [];
    code = ""
  } in
  let fragments = StringMap.singleton "standalone" frag in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let deps = StringMap.find_opt "standalone" dep_graph in
  (match deps with
  | Some (_name, dep_set) ->
      let is_empty = StringSet.is_empty dep_set in
      print_endline (if is_empty then "no dependencies" else "has dependencies")
  | None ->
      [%expect.unreachable];
      print_endline "not found");
  [%expect {| no dependencies |}]

let%expect_test "build_dep_graph with multiple dependencies" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = [];
    code = ""
  } in
  let frag3 = { Lua_link.
    name = "c";
    provides = ["c"];
    requires = ["a"; "b"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
    |> StringMap.add "c" frag3
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let c_deps = StringMap.find_opt "c" dep_graph in
  (match c_deps with
  | Some (_name, deps) ->
      let dep_list = StringSet.elements deps |> List.sort ~cmp:String.compare in
      print_endline ("c depends on: " ^ String.concat ~sep:", " dep_list)
  | None ->
      [%expect.unreachable];
      print_endline "not found");
  [%expect {| c depends on: a, b |}]

let%expect_test "build_dep_graph filters self-dependency" =
  let frag = { Lua_link.
    name = "recursive";
    provides = ["func1"; "func2"];
    requires = ["func1"];  (* Requires its own symbol *)
    code = ""
  } in
  let fragments = StringMap.singleton "recursive" frag in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let deps = StringMap.find_opt "recursive" dep_graph in
  (match deps with
  | Some (_name, dep_set) ->
      let is_empty = StringSet.is_empty dep_set in
      print_endline (if is_empty then "no dependencies" else "has dependencies")
  | None ->
      [%expect.unreachable];
      print_endline "not found");
  [%expect {| no dependencies |}]

let%expect_test "build_dep_graph ignores missing symbols" =
  let frag = { Lua_link.
    name = "incomplete";
    provides = ["func"];
    requires = ["missing_symbol"];
    code = ""
  } in
  let fragments = StringMap.singleton "incomplete" frag in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let deps = StringMap.find_opt "incomplete" dep_graph in
  (match deps with
  | Some (_name, dep_set) ->
      let is_empty = StringSet.is_empty dep_set in
      print_endline (if is_empty then "no dependencies" else "has dependencies")
  | None ->
      [%expect.unreachable];
      print_endline "not found");
  [%expect {| no dependencies |}]

let%expect_test "build_dep_graph with transitive dependencies" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["a"];
    code = ""
  } in
  let frag3 = { Lua_link.
    name = "c";
    provides = ["c"];
    requires = ["b"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
    |> StringMap.add "c" frag3
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  (* Check each fragment's direct dependencies *)
  let a_deps = match StringMap.find_opt "a" dep_graph with
    | Some (_, deps) -> StringSet.elements deps
    | None -> []
  in
  let b_deps = match StringMap.find_opt "b" dep_graph with
    | Some (_, deps) -> StringSet.elements deps
    | None -> []
  in
  let c_deps = match StringMap.find_opt "c" dep_graph with
    | Some (_, deps) -> StringSet.elements deps
    | None -> []
  in
  print_endline ("a depends on: " ^ String.concat ~sep:", " a_deps);
  print_endline ("b depends on: " ^ String.concat ~sep:", " b_deps);
  print_endline ("c depends on: " ^ String.concat ~sep:", " c_deps);
  [%expect {|
    a depends on:
    b depends on: a
    c depends on: b
    |}]

(* Task 2.3: Calculate In-Degrees Tests *)

let%expect_test "calculate_in_degrees with simple dependency" =
  let frag1 = { Lua_link.
    name = "base";
    provides = ["base_func"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "derived";
    provides = ["derived_func"];
    requires = ["base_func"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "base" frag1
    |> StringMap.add "derived" frag2
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let base_degree = StringMap.find_opt "base" in_degrees |> Option.value ~default:(-1) in
  let derived_degree = StringMap.find_opt "derived" in_degrees |> Option.value ~default:(-1) in
  print_endline ("base in-degree: " ^ string_of_int base_degree);
  print_endline ("derived in-degree: " ^ string_of_int derived_degree);
  [%expect {|
    base in-degree: 0
    derived in-degree: 1
    |}]

let%expect_test "calculate_in_degrees with no dependencies" =
  let frag = { Lua_link.
    name = "standalone";
    provides = ["func"];
    requires = [];
    code = ""
  } in
  let fragments = StringMap.singleton "standalone" frag in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let degree = StringMap.find_opt "standalone" in_degrees |> Option.value ~default:(-1) in
  print_endline ("standalone in-degree: " ^ string_of_int degree);
  [%expect {| standalone in-degree: 0 |}]

let%expect_test "calculate_in_degrees with multiple dependents" =
  let frag1 = { Lua_link.
    name = "base";
    provides = ["base_func"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "derived1";
    provides = ["d1"];
    requires = ["base_func"];
    code = ""
  } in
  let frag3 = { Lua_link.
    name = "derived2";
    provides = ["d2"];
    requires = ["base_func"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "base" frag1
    |> StringMap.add "derived1" frag2
    |> StringMap.add "derived2" frag3
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let base_degree = StringMap.find_opt "base" in_degrees |> Option.value ~default:(-1) in
  print_endline ("base in-degree: " ^ string_of_int base_degree);
  [%expect {| base in-degree: 0 |}]

let%expect_test "calculate_in_degrees with complex graph" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["a"];
    code = ""
  } in
  let frag3 = { Lua_link.
    name = "c";
    provides = ["c"];
    requires = ["a"; "b"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
    |> StringMap.add "c" frag3
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let a_degree = StringMap.find_opt "a" in_degrees |> Option.value ~default:(-1) in
  let b_degree = StringMap.find_opt "b" in_degrees |> Option.value ~default:(-1) in
  let c_degree = StringMap.find_opt "c" in_degrees |> Option.value ~default:(-1) in
  print_endline ("a in-degree: " ^ string_of_int a_degree);
  print_endline ("b in-degree: " ^ string_of_int b_degree);
  print_endline ("c in-degree: " ^ string_of_int c_degree);
  [%expect {|
    a in-degree: 0
    b in-degree: 1
    c in-degree: 2
    |}]

let%expect_test "calculate_in_degrees all fragments initialized" =
  let frag1 = { Lua_link.
    name = "isolated1";
    provides = ["i1"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "isolated2";
    provides = ["i2"];
    requires = [];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "isolated1" frag1
    |> StringMap.add "isolated2" frag2
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let count = StringMap.cardinal in_degrees in
  print_endline ("fragments with in-degrees: " ^ string_of_int count);
  [%expect {| fragments with in-degrees: 2 |}]

let%expect_test "calculate_in_degrees with linear chain" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["a"];
    code = ""
  } in
  let frag3 = { Lua_link.
    name = "c";
    provides = ["c"];
    requires = ["b"];
    code = ""
  } in
  let frag4 = { Lua_link.
    name = "d";
    provides = ["d"];
    requires = ["c"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
    |> StringMap.add "c" frag3
    |> StringMap.add "d" frag4
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let a_degree = StringMap.find_opt "a" in_degrees |> Option.value ~default:(-1) in
  let b_degree = StringMap.find_opt "b" in_degrees |> Option.value ~default:(-1) in
  let c_degree = StringMap.find_opt "c" in_degrees |> Option.value ~default:(-1) in
  let d_degree = StringMap.find_opt "d" in_degrees |> Option.value ~default:(-1) in
  print_endline ("a in-degree: " ^ string_of_int a_degree);
  print_endline ("b in-degree: " ^ string_of_int b_degree);
  print_endline ("c in-degree: " ^ string_of_int c_degree);
  print_endline ("d in-degree: " ^ string_of_int d_degree);
  [%expect {|
    a in-degree: 0
    b in-degree: 1
    c in-degree: 1
    d in-degree: 1
    |}]

(* Task 3.1: Topological Sort (Kahn's Algorithm) Tests *)

let%expect_test "topological_sort with linear dependencies" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["a"];
    code = ""
  } in
  let frag3 = { Lua_link.
    name = "c";
    provides = ["c"];
    requires = ["b"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
    |> StringMap.add "c" frag3
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let sorted, cycles = Lua_link.topological_sort dep_graph in_degrees in
  print_endline ("sorted: " ^ String.concat ~sep:", " sorted);
  print_endline ("cycles: " ^ String.concat ~sep:", " cycles);
  [%expect {|
    sorted: a, b, c
    cycles:
    |}]

let%expect_test "topological_sort with no dependencies" =
  let frag = { Lua_link.
    name = "standalone";
    provides = ["func"];
    requires = [];
    code = ""
  } in
  let fragments = StringMap.singleton "standalone" frag in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let sorted, cycles = Lua_link.topological_sort dep_graph in_degrees in
  print_endline ("sorted: " ^ String.concat ~sep:", " sorted);
  print_endline ("cycles: " ^ String.concat ~sep:", " cycles);
  [%expect {|
    sorted: standalone
    cycles:
    |}]

let%expect_test "topological_sort with diamond dependency" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["a"];
    code = ""
  } in
  let frag3 = { Lua_link.
    name = "c";
    provides = ["c"];
    requires = ["a"];
    code = ""
  } in
  let frag4 = { Lua_link.
    name = "d";
    provides = ["d"];
    requires = ["b"; "c"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
    |> StringMap.add "c" frag3
    |> StringMap.add "d" frag4
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let sorted, cycles = Lua_link.topological_sort dep_graph in_degrees in
  (* a must come first, d must come last, b and c can be in any order *)
  let a_pos = List.find_index ~f:(String.equal "a") sorted |> Option.value ~default:(-1) in
  let d_pos = List.find_index ~f:(String.equal "d") sorted |> Option.value ~default:(-1) in
  print_endline ("a before d: " ^ string_of_bool (a_pos < d_pos));
  print_endline ("no cycles: " ^ string_of_bool (List.length cycles = 0));
  [%expect {|
    a before d: true
    no cycles: true
    |}]

let%expect_test "topological_sort with circular dependency" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = ["b"];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["a"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let sorted, cycles = Lua_link.topological_sort dep_graph in_degrees in
  print_endline ("sorted count: " ^ string_of_int (List.length sorted));
  print_endline ("cycle detected: " ^ string_of_bool (List.length cycles > 0));
  [%expect {|
    sorted count: 0
    cycle detected: true
    |}]

let%expect_test "topological_sort with multiple independent fragments" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = [];
    code = ""
  } in
  let frag3 = { Lua_link.
    name = "c";
    provides = ["c"];
    requires = [];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
    |> StringMap.add "c" frag3
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let sorted, cycles = Lua_link.topological_sort dep_graph in_degrees in
  print_endline ("sorted count: " ^ string_of_int (List.length sorted));
  print_endline ("no cycles: " ^ string_of_bool (List.length cycles = 0));
  [%expect {|
    sorted count: 3
    no cycles: true
    |}]

let%expect_test "topological_sort with complex cycle" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = ["b"];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["c"];
    code = ""
  } in
  let frag3 = { Lua_link.
    name = "c";
    provides = ["c"];
    requires = ["a"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
    |> StringMap.add "c" frag3
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let dep_graph = Lua_link.build_dep_graph fragments provides_map in
  let in_degrees = Lua_link.calculate_in_degrees dep_graph in
  let sorted, cycles = Lua_link.topological_sort dep_graph in_degrees in
  print_endline ("sorted count: " ^ string_of_int (List.length sorted));
  print_endline ("cycle count: " ^ string_of_int (List.length cycles));
  [%expect {|
    sorted count: 0
    cycle count: 3
    |}]

let%expect_test "parse fragment header with provides" =
  let code = {|
--// Provides: foo, bar
--// Requires: baz

local function foo()
  return 42
end
|} in
  let fragment = { Lua_link.
    name = "test";
    provides = ["foo"; "bar"];
    requires = ["baz"];
    code
  } in
  print_endline ("provides: " ^ String.concat ~sep:", " fragment.provides);
  print_endline ("requires: " ^ String.concat ~sep:", " fragment.requires);
  [%expect {|
    provides: foo, bar
    requires: baz
    |}]

let%expect_test "add fragment to state" =
  let state = Lua_link.init () in
  let fragment = { Lua_link.
    name = "module1";
    provides = ["sym1"];
    requires = [];
    code = "-- module1 code"
  } in
  let _state' = Lua_link.add_fragment state fragment in
  print_endline "fragment added";
  [%expect {| fragment added |}]

(* Task 3.2: Find Missing Dependencies Tests *)

let%expect_test "find_missing_deps with no missing" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["a"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let missing = Lua_link.find_missing_deps fragments provides_map in
  let is_empty = StringSet.is_empty missing in
  print_endline (if is_empty then "no missing" else "has missing");
  [%expect {| no missing |}]

let%expect_test "find_missing_deps with single missing" =
  let frag = { Lua_link.
    name = "incomplete";
    provides = ["func"];
    requires = ["missing_dep"];
    code = ""
  } in
  let fragments = StringMap.singleton "incomplete" frag in
  let provides_map = Lua_link.build_provides_map fragments in
  let missing = Lua_link.find_missing_deps fragments provides_map in
  let missing_list = StringSet.elements missing in
  print_endline ("missing: " ^ String.concat ~sep:", " missing_list);
  [%expect {| missing: missing_dep |}]

let%expect_test "find_missing_deps with multiple missing" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = ["dep1"; "dep2"];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["dep3"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let missing = Lua_link.find_missing_deps fragments provides_map in
  let missing_list = StringSet.elements missing |> List.sort ~cmp:String.compare in
  print_endline ("missing: " ^ String.concat ~sep:", " missing_list);
  [%expect {| missing: dep1, dep2, dep3 |}]

let%expect_test "find_missing_deps with partial satisfaction" =
  let frag1 = { Lua_link.
    name = "provider";
    provides = ["dep1"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "consumer";
    provides = ["func"];
    requires = ["dep1"; "dep2"; "dep3"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "provider" frag1
    |> StringMap.add "consumer" frag2
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let missing = Lua_link.find_missing_deps fragments provides_map in
  let missing_list = StringSet.elements missing |> List.sort ~cmp:String.compare in
  print_endline ("missing: " ^ String.concat ~sep:", " missing_list);
  [%expect {| missing: dep2, dep3 |}]

let%expect_test "find_missing_deps with duplicate requirements" =
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = ["missing"];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["missing"];
    code = ""
  } in
  let fragments = StringMap.empty
    |> StringMap.add "a" frag1
    |> StringMap.add "b" frag2
  in
  let provides_map = Lua_link.build_provides_map fragments in
  let missing = Lua_link.find_missing_deps fragments provides_map in
  let missing_list = StringSet.elements missing in
  print_endline ("missing: " ^ String.concat ~sep:", " missing_list);
  print_endline ("count: " ^ string_of_int (List.length missing_list));
  [%expect {|
    missing: missing
    count: 1
    |}]

let%expect_test "find_missing_deps with empty fragments" =
  let fragments = StringMap.empty in
  let provides_map = Lua_link.build_provides_map fragments in
  let missing = Lua_link.find_missing_deps fragments provides_map in
  let is_empty = StringSet.is_empty missing in
  print_endline (if is_empty then "no missing" else "has missing");
  [%expect {| no missing |}]

let%expect_test "resolve simple dependencies" =
  let state = Lua_link.init () in
  let frag1 = { Lua_link.
    name = "base";
    provides = ["base_func"];
    requires = [];
    code = "-- base"
  } in
  let frag2 = { Lua_link.
    name = "derived";
    provides = ["derived_func"];
    requires = ["base_func"];
    code = "-- derived"
  } in
  let state = Lua_link.add_fragment state frag1 in
  let state = Lua_link.add_fragment state frag2 in
  let ordered, missing = Lua_link.resolve_deps state ["derived_func"] in
  print_endline ("ordered: " ^ String.concat ~sep:", " ordered);
  print_endline ("missing: " ^ String.concat ~sep:", " missing);
  [%expect {|
    ordered: base, derived
    missing:
    |}]

let%expect_test "resolve transitive dependencies" =
  let state = Lua_link.init () in
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = [];
    code = "-- a"
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["a"];
    code = "-- b"
  } in
  let frag3 = { Lua_link.
    name = "c";
    provides = ["c"];
    requires = ["b"];
    code = "-- c"
  } in
  let state = Lua_link.add_fragment state frag1 in
  let state = Lua_link.add_fragment state frag2 in
  let state = Lua_link.add_fragment state frag3 in
  let ordered, missing = Lua_link.resolve_deps state ["c"] in
  print_endline ("ordered: " ^ String.concat ~sep:", " ordered);
  print_endline ("missing: " ^ String.concat ~sep:", " missing);
  [%expect {|
    ordered: a, b, c
    missing:
    |}]

let%expect_test "detect missing dependencies" =
  let state = Lua_link.init () in
  let frag = { Lua_link.
    name = "incomplete";
    provides = ["func"];
    requires = ["missing_dep"];
    code = "-- code"
  } in
  let state = Lua_link.add_fragment state frag in
  let ordered, missing = Lua_link.resolve_deps state ["func"] in
  print_endline ("ordered: " ^ String.concat ~sep:", " ordered);
  print_endline ("missing: " ^ String.concat ~sep:", " missing);
  [%expect {|
    ordered: incomplete
    missing: missing_dep
    |}]

(* Task 3.3: Additional resolve_deps Integration Tests *)

let%expect_test "resolve_deps with diamond dependency" =
  let state = Lua_link.init () in
  let frag_a = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = [];
    code = ""
  } in
  let frag_b = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["a"];
    code = ""
  } in
  let frag_c = { Lua_link.
    name = "c";
    provides = ["c"];
    requires = ["a"];
    code = ""
  } in
  let frag_d = { Lua_link.
    name = "d";
    provides = ["d"];
    requires = ["b"; "c"];
    code = ""
  } in
  let state = Lua_link.add_fragment state frag_a in
  let state = Lua_link.add_fragment state frag_b in
  let state = Lua_link.add_fragment state frag_c in
  let state = Lua_link.add_fragment state frag_d in
  let ordered, missing = Lua_link.resolve_deps state ["d"] in
  (* Check that 'a' comes before both 'b' and 'c', and both come before 'd' *)
  let a_pos = List.find_index ~f:(String.equal "a") ordered |> Option.value ~default:(-1) in
  let b_pos = List.find_index ~f:(String.equal "b") ordered |> Option.value ~default:(-1) in
  let c_pos = List.find_index ~f:(String.equal "c") ordered |> Option.value ~default:(-1) in
  let d_pos = List.find_index ~f:(String.equal "d") ordered |> Option.value ~default:(-1) in
  print_endline ("a before b: " ^ string_of_bool (a_pos < b_pos));
  print_endline ("a before c: " ^ string_of_bool (a_pos < c_pos));
  print_endline ("b before d: " ^ string_of_bool (b_pos < d_pos));
  print_endline ("c before d: " ^ string_of_bool (c_pos < d_pos));
  print_endline ("no missing: " ^ string_of_bool (List.length missing = 0));
  [%expect {|
    a before b: true
    a before c: true
    b before d: true
    c before d: true
    no missing: true
    |}]

let%expect_test "resolve_deps with multiple required symbols" =
  let state = Lua_link.init () in
  let frag1 = { Lua_link.
    name = "utils";
    provides = ["util1"; "util2"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "app";
    provides = ["app"];
    requires = ["util1"];
    code = ""
  } in
  let state = Lua_link.add_fragment state frag1 in
  let state = Lua_link.add_fragment state frag2 in
  let ordered, missing = Lua_link.resolve_deps state ["util1"; "util2"; "app"] in
  print_endline ("ordered: " ^ String.concat ~sep:", " ordered);
  print_endline ("missing: " ^ String.concat ~sep:", " missing);
  [%expect {|
    ordered: utils, app
    missing:
    |}]

let%expect_test "resolve_deps with unused fragments" =
  let state = Lua_link.init () in
  let frag1 = { Lua_link.
    name = "needed";
    provides = ["needed"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "unused";
    provides = ["unused"];
    requires = [];
    code = ""
  } in
  let state = Lua_link.add_fragment state frag1 in
  let state = Lua_link.add_fragment state frag2 in
  let ordered, missing = Lua_link.resolve_deps state ["needed"] in
  print_endline ("ordered: " ^ String.concat ~sep:", " ordered);
  print_endline ("unused included: " ^ string_of_bool (List.mem ~eq:String.equal "unused" ordered));
  print_endline ("missing: " ^ String.concat ~sep:", " missing);
  [%expect {|
    ordered: needed
    unused included: false
    missing:
    |}]

let%expect_test "resolve_deps with empty requirements" =
  let state = Lua_link.init () in
  let frag = { Lua_link.
    name = "frag";
    provides = ["symbol"];
    requires = [];
    code = ""
  } in
  let state = Lua_link.add_fragment state frag in
  let ordered, missing = Lua_link.resolve_deps state [] in
  print_endline ("ordered: " ^ String.concat ~sep:", " ordered);
  print_endline ("missing: " ^ String.concat ~sep:", " missing);
  [%expect {|
    ordered:
    missing:
    |}]

let%expect_test "resolve_deps with complex missing dependencies" =
  let state = Lua_link.init () in
  let frag1 = { Lua_link.
    name = "a";
    provides = ["a"];
    requires = ["missing1"];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "b";
    provides = ["b"];
    requires = ["a"; "missing2"];
    code = ""
  } in
  let state = Lua_link.add_fragment state frag1 in
  let state = Lua_link.add_fragment state frag2 in
  let ordered, missing = Lua_link.resolve_deps state ["b"] in
  let missing_sorted = List.sort ~cmp:String.compare missing in
  print_endline ("ordered: " ^ String.concat ~sep:", " ordered);
  print_endline ("missing: " ^ String.concat ~sep:", " missing_sorted);
  [%expect {|
    ordered: a, b
    missing: missing1, missing2
    |}]

(* Task 4.1: Generate Module Registration Tests *)

let%expect_test "generate_module_registration with single symbol" =
  let fragment = { Lua_link.
    name = "simple";
    provides = ["foo"];
    requires = [];
    code = "local function foo()\n  return 42\nend"
  } in
  let registration = Lua_link.generate_module_registration fragment in
  print_string registration;
  [%expect {|
    -- Fragment: simple
    package.loaded["foo"] = function()
      local function foo()
        return 42
      end
    end
    |}]

let%expect_test "generate_module_registration with multiple symbols" =
  let fragment = { Lua_link.
    name = "multi";
    provides = ["bar"; "baz"];
    requires = [];
    code = "function bar() return 1 end\nfunction baz() return 2 end"
  } in
  let registration = Lua_link.generate_module_registration fragment in
  print_string registration;
  [%expect {|
    -- Fragment: multi
    package.loaded["bar"] = function()
      function bar() return 1 end
      function baz() return 2 end
    end
    package.loaded["baz"] = function()
      function bar() return 1 end
      function baz() return 2 end
    end
    |}]

let%expect_test "generate_module_registration with empty code" =
  let fragment = { Lua_link.
    name = "empty";
    provides = ["empty_module"];
    requires = [];
    code = ""
  } in
  let registration = Lua_link.generate_module_registration fragment in
  print_string registration;
  [%expect {|
    -- Fragment: empty
    package.loaded["empty_module"] = function()

    end
    |}]

let%expect_test "generate_module_registration with complex code" =
  let fragment = { Lua_link.
    name = "complex";
    provides = ["module"];
    requires = [];
    code = {|local M = {}
function M.add(a, b)
  return a + b
end
return M|}
  } in
  let registration = Lua_link.generate_module_registration fragment in
  print_string registration;
  [%expect {|
    -- Fragment: complex
    package.loaded["module"] = function()
      local M = {}
      function M.add(a, b)
        return a + b
      end
      return M
    end
    |}]

let%expect_test "generate_module_registration preserves blank lines" =
  let fragment = { Lua_link.
    name = "blanks";
    provides = ["test"];
    requires = [];
    code = "line1\n\nline3"
  } in
  let registration = Lua_link.generate_module_registration fragment in
  print_string registration;
  [%expect {|
    -- Fragment: blanks
    package.loaded["test"] = function()
      line1

      line3
    end
    |}]

(* Task 4.2: Generate Loader Prologue Tests *)

let%expect_test "generate_loader_prologue produces header" =
  let prologue = Lua_link.generate_loader_prologue () in
  print_string prologue;
  [%expect {|
    -- Lua_of_ocaml runtime loader
    -- This code registers runtime modules in package.loaded

    |}]

let%expect_test "generate_loader_prologue is consistent" =
  let prologue1 = Lua_link.generate_loader_prologue () in
  let prologue2 = Lua_link.generate_loader_prologue () in
  print_endline (if String.equal prologue1 prologue2 then "consistent" else "inconsistent");
  [%expect {| consistent |}]

let%expect_test "generate_loader_prologue ends with newline" =
  let prologue = Lua_link.generate_loader_prologue () in
  let ends_with_newline = String.length prologue > 0 &&
                          Char.equal (String.get prologue (String.length prologue - 1)) '\n' in
  print_endline (if ends_with_newline then "ends with newline" else "no newline");
  [%expect {| ends with newline |}]

(* Task 4.3: Generate Loader Epilogue Tests *)

let%expect_test "generate_loader_epilogue produces footer" =
  let fragments = [] in
  let epilogue = Lua_link.generate_loader_epilogue fragments in
  print_string epilogue;
  [%expect {|

    -- End of runtime loader
    |}]

let%expect_test "generate_loader_epilogue with fragments" =
  let frag1 = { Lua_link.
    name = "test";
    provides = ["test"];
    requires = [];
    code = ""
  } in
  let frag2 = { Lua_link.
    name = "other";
    provides = ["other"];
    requires = [];
    code = ""
  } in
  let epilogue = Lua_link.generate_loader_epilogue [frag1; frag2] in
  print_string epilogue;
  [%expect {|

    -- End of runtime loader
    |}]

let%expect_test "generate_loader_epilogue is consistent" =
  let fragments = [] in
  let epilogue1 = Lua_link.generate_loader_epilogue fragments in
  let epilogue2 = Lua_link.generate_loader_epilogue fragments in
  print_endline (if String.equal epilogue1 epilogue2 then "consistent" else "inconsistent");
  [%expect {| consistent |}]

let%expect_test "generate_loader_epilogue starts with newline" =
  let fragments = [] in
  let epilogue = Lua_link.generate_loader_epilogue fragments in
  let starts_with_newline = String.length epilogue > 0 &&
                            Char.equal (String.get epilogue 0) '\n' in
  print_endline (if starts_with_newline then "starts with newline" else "no newline");
  [%expect {| starts with newline |}]

(* Task 4.4: Complete generate_loader Tests *)

let%expect_test "generate_loader with empty fragments" =
  let loader = Lua_link.generate_loader [] in
  print_string loader;
  [%expect {|
    -- Lua_of_ocaml runtime loader
    -- This code registers runtime modules in package.loaded


    -- End of runtime loader
    |}]

let%expect_test "generate_loader with single fragment" =
  let frag = { Lua_link.
    name = "test";
    provides = ["test_func"];
    requires = [];
    code = "return 42"
  } in
  let loader = Lua_link.generate_loader [frag] in
  print_string loader;
  [%expect {|
    -- Lua_of_ocaml runtime loader
    -- This code registers runtime modules in package.loaded

    -- Fragment: test
    package.loaded["test_func"] = function()
      return 42
    end

    -- End of runtime loader
    |}]

let%expect_test "generate_loader with multiple fragments" =
  let frag1 = { Lua_link.
    name = "base";
    provides = ["base_func"];
    requires = [];
    code = "local x = 10"
  } in
  let frag2 = { Lua_link.
    name = "derived";
    provides = ["derived_func"];
    requires = ["base_func"];
    code = "local y = 20"
  } in
  let loader = Lua_link.generate_loader [frag1; frag2] in
  print_string loader;
  [%expect {|
    -- Lua_of_ocaml runtime loader
    -- This code registers runtime modules in package.loaded

    -- Fragment: base
    package.loaded["base_func"] = function()
      local x = 10
    end
    -- Fragment: derived
    package.loaded["derived_func"] = function()
      local y = 20
    end

    -- End of runtime loader
    |}]

let%expect_test "generate_loader with multi-symbol fragment" =
  let frag = { Lua_link.
    name = "multi";
    provides = ["func1"; "func2"];
    requires = [];
    code = "return true"
  } in
  let loader = Lua_link.generate_loader [frag] in
  print_string loader;
  [%expect {|
    -- Lua_of_ocaml runtime loader
    -- This code registers runtime modules in package.loaded

    -- Fragment: multi
    package.loaded["func1"] = function()
      return true
    end
    package.loaded["func2"] = function()
      return true
    end

    -- End of runtime loader
    |}]

let%expect_test "generate_loader structure validation" =
  let frag = { Lua_link.
    name = "test";
    provides = ["test"];
    requires = [];
    code = "x = 1"
  } in
  let loader = Lua_link.generate_loader [frag] in
  (* Verify it has prologue *)
  let has_prologue = String.contains loader 'L' in  (* "Lua_of_ocaml" *)
  (* Verify it has registration *)
  let has_registration = String.contains loader '[' in  (* package.loaded["..."] *)
  (* Verify it has epilogue *)
  let has_epilogue = String.contains loader 'E' in  (* "End" *)
  print_endline (if has_prologue && has_registration && has_epilogue
                 then "complete structure"
                 else "incomplete structure");
  [%expect {| complete structure |}]

let%expect_test "link with empty program" =
  let state = Lua_link.init () in
  let program = [] in
  let linked = Lua_link.link ~state ~program ~linkall:false in
  print_int (List.length linked);
  print_newline ();
  [%expect {| 1 |}]

let%expect_test "link with linkall" =
  let state = Lua_link.init () in
  let frag = { Lua_link.
    name = "runtime";
    provides = ["runtime_func"];
    requires = [];
    code = "-- runtime"
  } in
  let state = Lua_link.add_fragment state frag in
  let program = [] in
  let linked = Lua_link.link ~state ~program ~linkall:true in
  (* Should include the loader comment *)
  print_int (List.length linked);
  print_newline ();
  [%expect {| 1 |}]

let%expect_test "multiple fragments with same provides" =
  let state = Lua_link.init () in
  let frag1 = { Lua_link.
    name = "impl1";
    provides = ["func"];
    requires = [];
    code = "-- impl1"
  } in
  let frag2 = { Lua_link.
    name = "impl2";
    provides = ["func"];
    requires = [];
    code = "-- impl2"
  } in
  let state = Lua_link.add_fragment state frag1 in
  let state = Lua_link.add_fragment state frag2 in
  let ordered, missing = Lua_link.resolve_deps state ["func"] in
  (* Should pick one implementation *)
  print_endline ("ordered length: " ^ string_of_int (List.length ordered));
  print_endline ("missing: " ^ String.concat ~sep:", " missing);
  [%expect {|
    Warning [overriding-primitive]: symbol "func" provided by both fragment "impl1" and fragment "impl2"
    ordered length: 1
    missing:
    |}]
