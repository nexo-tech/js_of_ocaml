(* Tests for Lua expression generation *)

open Js_of_ocaml_compiler

module Lua_generate = struct
  include Lua_of_ocaml_compiler__Lua_generate
end

module Lua_ast = struct
  include Lua_of_ocaml_compiler__Lua_ast
end

module Lua_output = struct
  include Lua_of_ocaml_compiler__Lua_output
end

(* Test helpers *)
let make_ctx () =
  let ctx = Lua_generate.make_context ~debug:false in
  ctx

let var_of_int i = Code.Var.of_idx i

let%expect_test "generate constant - string" =
  let const = Code.String "hello" in
  let expr = Lua_generate.generate_constant const in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| "hello" |}]

let%expect_test "generate constant - int32" =
  let const = Code.Int32 42l in
  let expr = Lua_generate.generate_constant const in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| 42 |}]

let%expect_test "generate constant - int64" =
  let const = Code.Int64 456L in
  let expr = Lua_generate.generate_constant const in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| 456 |}]

let%expect_test "generate constant - float" =
  let fl = 3.14 in
  let bits = Int64.bits_of_float fl in
  let const = (Code.Float bits : Code.constant) in
  let expr = Lua_generate.generate_constant const in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| 3.1400000000000001 |}]

let%expect_test "generate constant - native string utf8" =
  let const = Code.NativeString (Code.Native_string.of_string "test") in
  let expr = Lua_generate.generate_constant const in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| "test" |}]

let%expect_test "generate constant - tuple" =
  let const =
    Code.Tuple (0, [| Code.Int32 1l; Code.Int32 2l |], Code.NotArray)
  in
  let expr = Lua_generate.generate_constant const in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| {tag = 0, 1, 2} |}]

let%expect_test "generate constant - float array" =
  let arr = [| Int64.bits_of_float 1.5; Int64.bits_of_float 2.5 |] in
  let const = Code.Float_array arr in
  let expr = Lua_generate.generate_constant const in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| {1.5, 2.5} |}]

let%expect_test "generate prim - not" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let prim = Code.Not in
  let args = [ Code.Pv v ] in
  let expr = Lua_generate.generate_prim ctx prim args in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| not v0 |}]

let%expect_test "generate prim - eq" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let prim = Code.Eq in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let expr = Lua_generate.generate_prim ctx prim args in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| v0 == v1 |}]

let%expect_test "generate prim - lt" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let prim = Code.Lt in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let expr = Lua_generate.generate_prim ctx prim args in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| v0 < v1 |}]

let%expect_test "generate prim - le" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let prim = Code.Le in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let expr = Lua_generate.generate_prim ctx prim args in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| v0 <= v1 |}]

let%expect_test "generate prim - vectlength" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let prim = Code.Vectlength in
  let args = [ Code.Pv v ] in
  let expr = Lua_generate.generate_prim ctx prim args in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| #v0 |}]

let%expect_test "generate prim - array_get" =
  let ctx = make_ctx () in
  let v_arr = var_of_int 1 in
  let v_idx = var_of_int 2 in
  let prim = Code.Array_get in
  let args = [ Code.Pv v_arr; Code.Pv v_idx ] in
  let expr = Lua_generate.generate_prim ctx prim args in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| v0[v1 + 1] |}]

let%expect_test "generate prim - is_int" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let prim = Code.IsInt in
  let args = [ Code.Pv v ] in
  let expr = Lua_generate.generate_prim ctx prim args in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| type(v0) == "number" and v0 % 1 == 0 |}]

let%expect_test "generate prim - extern" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let prim = Code.Extern "add_int" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let expr = Lua_generate.generate_prim ctx prim args in
  let lua_str = Lua_output.expr_to_string expr in
  print_endline lua_str;
  [%expect {| caml_add_int(v0, v1) |}]

let%expect_test "generate expr - constant" =
  let ctx = make_ctx () in
  let expr = Code.Constant (Code.Int32 99l) in
  let lua_expr = Lua_generate.generate_expr ctx expr in
  let lua_str = Lua_output.expr_to_string lua_expr in
  print_endline lua_str;
  [%expect {| 99 |}]

let%expect_test "generate expr - apply" =
  let ctx = make_ctx () in
  let f = var_of_int 1 in
  let args = [ var_of_int 2; var_of_int 3 ] in
  let expr = Code.Apply { f; args; exact = true } in
  let lua_expr = Lua_generate.generate_expr ctx expr in
  let lua_str = Lua_output.expr_to_string lua_expr in
  print_endline lua_str;
  [%expect {| v0(v1, v2) |}]

let%expect_test "generate expr - block" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let expr = Code.Block (0, [| v1; v2 |], Code.NotArray, Code.Immutable) in
  let lua_expr = Lua_generate.generate_expr ctx expr in
  let lua_str = Lua_output.expr_to_string lua_expr in
  print_endline lua_str;
  [%expect {| {tag = 0, v0, v1} |}]

let%expect_test "generate expr - field" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let expr = Code.Field (v, 0, Code.Non_float) in
  let lua_expr = Lua_generate.generate_expr ctx expr in
  let lua_str = Lua_output.expr_to_string lua_expr in
  print_endline lua_str;
  [%expect {| v0[1] |}]

let%expect_test "generate expr - field index 2" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let expr = Code.Field (v, 2, Code.Non_float) in
  let lua_expr = Lua_generate.generate_expr ctx expr in
  let lua_str = Lua_output.expr_to_string lua_expr in
  print_endline lua_str;
  [%expect {| v0[3] |}]

let%expect_test "generate expr - prim with constants" =
  let ctx = make_ctx () in
  let prim_arg1 = Code.Pc (Code.Int32 5l) in
  let prim_arg2 = Code.Pc (Code.Int32 10l) in
  let expr = Code.Prim (Code.Lt, [ prim_arg1; prim_arg2 ]) in
  let lua_expr = Lua_generate.generate_expr ctx expr in
  let lua_str = Lua_output.expr_to_string lua_expr in
  print_endline lua_str;
  [%expect {| 5 < 10 |}]

let%expect_test "generate expr - prim neq" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let expr = Code.Prim (Code.Neq, [ Code.Pv v1; Code.Pv v2 ]) in
  let lua_expr = Lua_generate.generate_expr ctx expr in
  let lua_str = Lua_output.expr_to_string lua_expr in
  print_endline lua_str;
  [%expect {| v0 ~= v1 |}]

let%expect_test "variable name preservation" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  (* Set a name for the variable *)
  Code.Var.set_name v "myvar";
  let name = Lua_generate.var_name ctx v in
  Printf.printf "Variable name: %s\n" name;
  [%expect {| Variable name: myvar |}]

let%expect_test "variable name uniqueness" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  (* Set same name for both variables *)
  Code.Var.set_name v1 "x";
  Code.Var.set_name v2 "x";
  let name1 = Lua_generate.var_name ctx v1 in
  let name2 = Lua_generate.var_name ctx v2 in
  Printf.printf "Variable 1: %s\n" name1;
  Printf.printf "Variable 2: %s\n" name2;
  Printf.printf "Names are different: %b\n" (not (String.equal name1 name2));
  [%expect {|
    Variable 1: x
    Variable 2: x1
    Names are different: true |}]

let%expect_test "reserved word handling" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  (* Use a Lua reserved word *)
  Code.Var.set_name v "function";
  let name = Lua_generate.var_name ctx v in
  Printf.printf "Variable name: %s\n" name;
  (* Should be mangled to avoid keyword *)
  Printf.printf "Is different from 'function': %b\n" (not (String.equal name "function"));
  [%expect {|
    Variable name: function__dollar__
    Is different from 'function': true
    |}]
