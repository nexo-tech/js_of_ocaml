(* Test for Lua AST traversal and free variable collection

   Tests the lua_traverse module to ensure it correctly identifies
   free variables in Lua code.

   Reference: Modeled after the algorithm in js_traverse.ml:1335-1468
*)

open Js_of_ocaml_compiler.Stdlib
module L = Lua_of_ocaml_compiler__Lua_ast
module Lua_traverse = Lua_of_ocaml_compiler__Lua_traverse

(* Test 1: Simple global variable reference *)
let%expect_test "free variable - simple global" =
  (* local x = foo() *)
  let ast = [
    L.Local (["x"], Some [L.Call (L.Ident "foo", [])])
  ] in
  let free = Lua_traverse.collect_free_vars ast in
  let free_list = StringSet.elements free |> List.sort ~cmp:String.compare in
  List.iter free_list ~f:(Printf.printf "%s\n");
  [%expect {|
    foo |}]

(* Test 2: Local variable is not free *)
let%expect_test "bound variable - local declaration" =
  (* local x = 42
     local y = x  -- x is bound, not free *)
  let ast = [
    L.Local (["x"], Some [L.Number "42"]);
    L.Local (["y"], Some [L.Ident "x"])
  ] in
  let free = Lua_traverse.collect_free_vars ast in
  let free_list = StringSet.elements free |> List.sort ~cmp:String.compare in
  List.iter free_list ~f:(Printf.printf "%s\n");
  [%expect {| |}]  (* Empty - no free variables *)

(* Test 3: Function parameter is not free *)
let%expect_test "bound variable - function parameter" =
  (* function foo(x) return x end
     local y = foo(z)  -- z is free, x is not *)
  let ast = [
    L.Function_decl ("foo", ["x"], false, [
      L.Return [L.Ident "x"]
    ]);
    L.Local (["y"], Some [L.Call (L.Ident "foo", [L.Ident "z"])])
  ] in
  let free = Lua_traverse.collect_free_vars ast in
  let free_list = StringSet.elements free |> List.sort ~cmp:String.compare in
  List.iter free_list ~f:(Printf.printf "%s\n");
  [%expect {|
    z |}]

(* Test 4: Nested scopes *)
let%expect_test "nested scopes" =
  (* local x = outer_var
     local function foo(y)
       local z = inner_var
       return x + y + z  -- only inner_var is free
     end *)
  let ast = [
    L.Local (["x"], Some [L.Ident "outer_var"]);
    L.Local_function ("foo", ["y"], false, [
      L.Local (["z"], Some [L.Ident "inner_var"]);
      L.Return [L.BinOp (L.Add, L.BinOp (L.Add, L.Ident "x", L.Ident "y"), L.Ident "z")]
    ])
  ] in
  let free = Lua_traverse.collect_free_vars ast in
  let free_list = StringSet.elements free |> List.sort ~cmp:String.compare in
  List.iter free_list ~f:(Printf.printf "%s\n");
  [%expect {|
    inner_var
    outer_var |}]

(* Test 5: For loop variable is not free in loop body *)
let%expect_test "for loop variable bound" =
  (* for i = 1, 10 do
       table[i] = i * 2  -- table is free, i is bound
     end *)
  let ast = [
    L.For_num ("i", L.Number "1", L.Number "10", None, [
      L.Assign (
        [L.Index (L.Ident "table", L.Ident "i")],
        [L.BinOp (L.Mul, L.Ident "i", L.Number "2")]
      )
    ])
  ] in
  let free = Lua_traverse.collect_free_vars ast in
  let free_list = StringSet.elements free |> List.sort ~cmp:String.compare in
  List.iter free_list ~f:(Printf.printf "%s\n");
  [%expect {|
    table |}]

(* Test 6: Multiple free variables from different scopes *)
let%expect_test "multiple free variables" =
  (* local result = caml_foo(caml_bar(x), y)
     return caml_baz(result) *)
  let ast = [
    L.Local (["result"], Some [
      L.Call (L.Ident "caml_foo", [
        L.Call (L.Ident "caml_bar", [L.Ident "x"]);
        L.Ident "y"
      ])
    ]);
    L.Return [L.Call (L.Ident "caml_baz", [L.Ident "result"])]
  ] in
  let free = Lua_traverse.collect_free_vars ast in
  let free_list = StringSet.elements free |> List.sort ~cmp:String.compare in
  List.iter free_list ~f:(Printf.printf "%s\n");
  [%expect {|
    caml_bar
    caml_baz
    caml_foo
    x
    y |}]

(* Test 7: Block scope *)
let%expect_test "block scope" =
  (* do
       local x = outer
     end
     local y = x  -- x is NOT in scope here, so it's free *)
  let ast = [
    L.Block [
      L.Local (["x"], Some [L.Ident "outer"])
    ];
    L.Local (["y"], Some [L.Ident "x"])
  ] in
  let free = Lua_traverse.collect_free_vars ast in
  let free_list = StringSet.elements free |> List.sort ~cmp:String.compare in
  List.iter free_list ~f:(Printf.printf "%s\n");
  [%expect {|
    outer
    x |}]

(* Test 8: Anonymous function (Lua closure) *)
let%expect_test "anonymous function" =
  (* local f = function(x) return caml_foo(x, global_var) end *)
  let ast = [
    L.Local (["f"], Some [
      L.Function (["x"], false, [
        L.Return [L.Call (L.Ident "caml_foo", [L.Ident "x"; L.Ident "global_var"])]
      ])
    ])
  ] in
  let free = Lua_traverse.collect_free_vars ast in
  let free_list = StringSet.elements free |> List.sort ~cmp:String.compare in
  List.iter free_list ~f:(Printf.printf "%s\n");
  [%expect {|
    caml_foo
    global_var |}]

(* Test 9: For-in loop *)
let%expect_test "for-in loop variables" =
  (* for k, v in pairs(tbl) do
       process(k, v)  -- k, v are bound; pairs, tbl, process are free
     end *)
  let ast = [
    L.For_in (["k"; "v"], [L.Call (L.Ident "pairs", [L.Ident "tbl"])], [
      L.Call_stat (L.Call (L.Ident "process", [L.Ident "k"; L.Ident "v"]))
    ])
  ] in
  let free = Lua_traverse.collect_free_vars ast in
  let free_list = StringSet.elements free |> List.sort ~cmp:String.compare in
  List.iter free_list ~f:(Printf.printf "%s\n");
  [%expect {|
    pairs
    process
    tbl |}]

(* Test 10: Realistic example - caml_ functions *)
let%expect_test "realistic - caml functions" =
  (* Simulates generated code pattern:
     local _V = setmetatable({}, {__index = parent_V})
     _V.v1 = caml_create_bytes(_V.v2)
     _V.v3 = caml_bytes_unsafe_get(_V.v1, 0)
     return caml_string_of_bytes(_V.v1)
  *)
  let ast = [
    L.Local (["_V"], Some [
      L.Call (L.Ident "setmetatable", [
        L.Table [];
        L.Table [L.Rec_field ("__index", L.Ident "parent_V")]
      ])
    ]);
    L.Assign (
      [L.Dot (L.Ident "_V", "v1")],
      [L.Call (L.Ident "caml_create_bytes", [L.Dot (L.Ident "_V", "v2")])]
    );
    L.Assign (
      [L.Dot (L.Ident "_V", "v3")],
      [L.Call (L.Ident "caml_bytes_unsafe_get", [
        L.Dot (L.Ident "_V", "v1");
        L.Number "0"
      ])]
    );
    L.Return [L.Call (L.Ident "caml_string_of_bytes", [L.Dot (L.Ident "_V", "v1")])]
  ] in
  let free = Lua_traverse.collect_free_vars ast in
  (* Filter to only caml_* functions *)
  let caml_funcs = StringSet.filter (String.starts_with ~prefix:"caml_") free in
  let caml_list = StringSet.elements caml_funcs |> List.sort ~cmp:String.compare in
  List.iter caml_list ~f:(Printf.printf "%s\n");
  [%expect {|
    caml_bytes_unsafe_get
    caml_create_bytes
    caml_string_of_bytes |}]
