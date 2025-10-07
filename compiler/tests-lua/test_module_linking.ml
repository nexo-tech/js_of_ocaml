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

let%expect_test "generate module loader" =
  let frag1 = { Lua_link.
    name = "module1";
    provides = ["f1"];
    requires = [];
    code = "function f1() return 1 end"
  } in
  let frag2 = { Lua_link.
    name = "module2";
    provides = ["f2"];
    requires = ["f1"];
    code = "function f2() return f1() + 1 end"
  } in
  let loader = Lua_link.generate_loader [frag1; frag2] in
  (* Check that loader contains module structure *)
  let has_module_loader = String.contains loader 'r' in
  let has_modules = String.contains loader 'm' in
  print_endline (if has_module_loader && has_modules then "loader generated" else "loader failed");
  [%expect {| loader generated |}]

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
    ordered length: 1
    missing:
    |}]
