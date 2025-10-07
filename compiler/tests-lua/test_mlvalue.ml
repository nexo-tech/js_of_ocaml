(* Test suite for lua_mlvalue.ml *)

(* Helper module to access wrapped submodules *)
module Lua_ast = struct
  include Lua_of_ocaml_compiler__Lua_ast
end

module Lua_mlvalue = struct
  include Lua_of_ocaml_compiler__Lua_mlvalue
end

module Lua_output = struct
  include Lua_of_ocaml_compiler__Lua_output
end

(* Helper to render Lua expression to string *)
let expr_to_string e =
  let buf = Buffer.create 256 in
  Lua_output.expr buf e;
  Buffer.contents buf

(* Helper to render Lua statement to string *)
let stmt_to_string s =
  let buf = Buffer.create 256 in
  Lua_output.stat buf s;
  Buffer.contents buf

(* Test constants *)
let%expect_test "constants" =
  print_endline (expr_to_string Lua_mlvalue.zero);
  [%expect {| 0 |}];
  print_endline (expr_to_string Lua_mlvalue.one);
  [%expect {| 1 |}];
  print_endline (expr_to_string Lua_mlvalue.unit);
  [%expect {| 0 |}];
  print_endline (expr_to_string Lua_mlvalue.false_val);
  [%expect {| 0 |}];
  print_endline (expr_to_string Lua_mlvalue.true_val);
  [%expect {| 1 |}];
  print_endline (expr_to_string Lua_mlvalue.none);
  [%expect {| 0 |}]

(* Test type predicates *)
let%expect_test "type predicates" =
  let var = Lua_ast.Ident "x" in
  print_endline (expr_to_string (Lua_mlvalue.is_block var));
  [%expect {| type(x) == "table" and x.tag ~= nil |}];
  print_endline (expr_to_string (Lua_mlvalue.is_immediate var));
  [%expect {| type(x) ~= "table" |}]

(* Test block creation *)
let%expect_test "block creation" =
  let fields = [ Lua_mlvalue.int 42; Lua_mlvalue.string "hello" ] in
  let block = Lua_mlvalue.Block.make ~tag:0 ~fields in
  print_endline (expr_to_string block);
  [%expect {| {tag = 0, [1] = 42, [2] = "hello"} |}]

(* Test block with different tag *)
let%expect_test "block with tag" =
  let fields = [ Lua_mlvalue.int 1; Lua_mlvalue.int 2; Lua_mlvalue.int 3 ] in
  let block = Lua_mlvalue.Block.make ~tag:5 ~fields in
  print_endline (expr_to_string block);
  [%expect {| {tag = 5, [1] = 1, [2] = 2, [3] = 3} |}]

(* Test empty block *)
let%expect_test "empty block" =
  let block = Lua_mlvalue.Block.make ~tag:0 ~fields:[] in
  print_endline (expr_to_string block);
  [%expect {| {tag = 0} |}]

(* Test block tag access *)
let%expect_test "block tag access" =
  let var = Lua_ast.Ident "block" in
  let tag_expr = Lua_mlvalue.Block.tag var in
  print_endline (expr_to_string tag_expr);
  [%expect {| block.tag |}]

(* Test block field access *)
let%expect_test "block field access" =
  let var = Lua_ast.Ident "block" in
  let field0 = Lua_mlvalue.Block.field var 0 in
  let field1 = Lua_mlvalue.Block.field var 1 in
  let field2 = Lua_mlvalue.Block.field var 2 in
  print_endline (expr_to_string field0);
  [%expect {| block[1] |}];
  print_endline (expr_to_string field1);
  [%expect {| block[2] |}];
  print_endline (expr_to_string field2);
  [%expect {| block[3] |}]

(* Test block field dynamic access *)
let%expect_test "block field dynamic access" =
  let var = Lua_ast.Ident "block" in
  let idx = Lua_ast.Ident "i" in
  let field_expr = Lua_mlvalue.Block.field_dynamic var idx in
  print_endline (expr_to_string field_expr);
  [%expect {| block[i + 1] |}]

(* Test block field assignment *)
let%expect_test "block field assignment" =
  let var = Lua_ast.Ident "block" in
  let value = Lua_mlvalue.int 100 in
  let stmt = Lua_mlvalue.Block.set_field var 0 value in
  print_endline (stmt_to_string stmt);
  [%expect {| block[1] = 100 |}]

(* Test array creation *)
let%expect_test "array creation" =
  let fields = [ Lua_mlvalue.int 10; Lua_mlvalue.int 20; Lua_mlvalue.int 30 ] in
  let array = Lua_mlvalue.Array.make ~length:3 ~fields in
  print_endline (expr_to_string array);
  [%expect {| {tag = 0, [0] = 3, [1] = 10, [2] = 20, [3] = 30} |}]

(* Test empty array *)
let%expect_test "empty array" =
  let array = Lua_mlvalue.Array.make ~length:0 ~fields:[] in
  print_endline (expr_to_string array);
  [%expect {| {tag = 0, [0] = 0} |}]

(* Test array length access *)
let%expect_test "array length access" =
  let var = Lua_ast.Ident "arr" in
  let len_expr = Lua_mlvalue.Array.length var in
  print_endline (expr_to_string len_expr);
  [%expect {| arr[0] |}]

(* Test array element access *)
let%expect_test "array element access" =
  let var = Lua_ast.Ident "arr" in
  let elem0 = Lua_mlvalue.Array.get var 0 in
  let elem1 = Lua_mlvalue.Array.get var 1 in
  let elem2 = Lua_mlvalue.Array.get var 2 in
  print_endline (expr_to_string elem0);
  [%expect {| arr[1] |}];
  print_endline (expr_to_string elem1);
  [%expect {| arr[2] |}];
  print_endline (expr_to_string elem2);
  [%expect {| arr[3] |}]

(* Test array element dynamic access *)
let%expect_test "array element dynamic access" =
  let var = Lua_ast.Ident "arr" in
  let idx = Lua_ast.Ident "i" in
  let elem_expr = Lua_mlvalue.Array.get_dynamic var idx in
  print_endline (expr_to_string elem_expr);
  [%expect {| arr[i + 1] |}]

(* Test array element assignment *)
let%expect_test "array element assignment" =
  let var = Lua_ast.Ident "arr" in
  let value = Lua_mlvalue.int 42 in
  let stmt = Lua_mlvalue.Array.set var 0 value in
  print_endline (stmt_to_string stmt);
  [%expect {| arr[1] = 42 |}]

(* Test Some variant *)
let%expect_test "Some variant" =
  let value = Lua_mlvalue.int 42 in
  let some_expr = Lua_mlvalue.some value in
  print_endline (expr_to_string some_expr);
  [%expect {| {tag = 0, [1] = 42} |}]

(* Test constant constructor *)
let%expect_test "constant constructor" =
  let constructor = Lua_mlvalue.const_constructor 5 in
  print_endline (expr_to_string constructor);
  [%expect {| 5 |}]

(* Test constructor with arguments *)
let%expect_test "constructor with arguments" =
  let args = [ Lua_mlvalue.int 1; Lua_mlvalue.string "test" ] in
  let constructor = Lua_mlvalue.constructor 2 args in
  print_endline (expr_to_string constructor);
  [%expect {| {tag = 2, [1] = 1, [2] = "test"} |}]

(* Test tuple creation *)
let%expect_test "tuple creation" =
  let elements = [ Lua_mlvalue.int 1; Lua_mlvalue.int 2; Lua_mlvalue.int 3 ] in
  let tuple = Lua_mlvalue.tuple elements in
  print_endline (expr_to_string tuple);
  [%expect {| {tag = 0, [1] = 1, [2] = 2, [3] = 3} |}]

(* Test pair tuple *)
let%expect_test "pair tuple" =
  let pair = Lua_mlvalue.tuple [ Lua_mlvalue.int 42; Lua_mlvalue.string "answer" ] in
  print_endline (expr_to_string pair);
  [%expect {| {tag = 0, [1] = 42, [2] = "answer"} |}]

(* Test string literal *)
let%expect_test "string literal" =
  let str = Lua_mlvalue.string "hello world" in
  print_endline (expr_to_string str);
  [%expect {| "hello world" |}]

(* Test integer literal *)
let%expect_test "integer literal" =
  let n = Lua_mlvalue.int 42 in
  print_endline (expr_to_string n);
  [%expect {| 42 |}];
  let negative = Lua_mlvalue.int (-10) in
  print_endline (expr_to_string negative);
  [%expect {| -10 |}]

(* Test float literal *)
let%expect_test "float literal" =
  let f = Lua_mlvalue.float 3.14 in
  print_endline (expr_to_string f);
  [%expect {| 3.14 |}];
  let negative = Lua_mlvalue.float (-2.5) in
  print_endline (expr_to_string negative);
  [%expect {| -2.5 |}]

(* Test ML bool from Lua bool *)
let%expect_test "ml_bool_of_lua" =
  let lua_bool = Lua_ast.Ident "lua_flag" in
  let ml_bool = Lua_mlvalue.ml_bool_of_lua lua_bool in
  print_endline (expr_to_string ml_bool);
  [%expect {| lua_flag and 1 |}]

(* Test Lua bool from ML bool *)
let%expect_test "lua_bool_of_ml" =
  let ml_bool = Lua_ast.Ident "ml_flag" in
  let lua_bool = Lua_mlvalue.lua_bool_of_ml ml_bool in
  print_endline (expr_to_string lua_bool);
  [%expect {| ml_flag ~= 0 |}]

(* Test complex nested structure *)
let%expect_test "nested structure" =
  (* Create: Some((42, "test")) *)
  let inner_tuple = Lua_mlvalue.tuple [ Lua_mlvalue.int 42; Lua_mlvalue.string "test" ] in
  let some_value = Lua_mlvalue.some inner_tuple in
  print_endline (expr_to_string some_value);
  [%expect {| {tag = 0, [1] = {tag = 0, [1] = 42, [2] = "test"}} |}]

(* Test variant with multiple fields *)
let%expect_test "variant with multiple fields" =
  (* Create: Point { x = 10; y = 20; z = 30 } with tag 1 *)
  let args = [ Lua_mlvalue.int 10; Lua_mlvalue.int 20; Lua_mlvalue.int 30 ] in
  let point = Lua_mlvalue.constructor 1 args in
  print_endline (expr_to_string point);
  [%expect {| {tag = 1, [1] = 10, [2] = 20, [3] = 30} |}]

(* Test list representation *)
let%expect_test "list representation" =
  (* OCaml list [1; 2; 3] is represented as:
     Cons(1, Cons(2, Cons(3, Nil)))
     where Nil = 0 and Cons has tag 0 *)
  let nil = Lua_mlvalue.int 0 in
  let cons3 = Lua_mlvalue.constructor 0 [ Lua_mlvalue.int 3; nil ] in
  let cons2 = Lua_mlvalue.constructor 0 [ Lua_mlvalue.int 2; cons3 ] in
  let cons1 = Lua_mlvalue.constructor 0 [ Lua_mlvalue.int 1; cons2 ] in
  print_endline (expr_to_string cons1);
  [%expect
    {| {tag = 0, [1] = 1, [2] = {tag = 0, [1] = 2, [2] = {tag = 0, [1] = 3, [2] = 0}}} |}]
