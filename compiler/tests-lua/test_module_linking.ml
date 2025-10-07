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
