(* Tests for Lua arithmetic primitive generation *)

open Js_of_ocaml_compiler

module Lua_generate = struct
  include Lua_of_ocaml_compiler__Lua_generate
end

module Lua_output = struct
  include Lua_of_ocaml_compiler__Lua_output
end

(* Test helpers *)
let make_ctx () = Lua_generate.make_context ~debug:false

let var_of_int i = Code.Var.of_idx i

let expr_to_string e = Lua_output.expr_to_string e

(* Integer arithmetic tests *)

let%expect_test "generate prim - add" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "add" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 + v1 |}]

let%expect_test "generate prim - sub" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "sub" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 - v1 |}]

let%expect_test "generate prim - mul" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "mul" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 * v1 |}]

let%expect_test "generate prim - div (integer division)" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "div" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 // v1 |}]

let%expect_test "generate prim - mod" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "mod" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 % v1 |}]

let%expect_test "generate prim - neg (unary)" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let prim = Code.Extern "neg" in
  let args = [ Code.Pv v ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| -v0 |}]

(* Int32 operations *)

let%expect_test "generate prim - int32_add" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "int32_add" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 + v1 |}]

let%expect_test "generate prim - int32_mul" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "int32_mul" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 * v1 |}]

let%expect_test "generate prim - int32_div" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "int32_div" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 // v1 |}]

(* NativeInt operations *)

let%expect_test "generate prim - nativeint_sub" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "nativeint_sub" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 - v1 |}]

let%expect_test "generate prim - nativeint_mod" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "nativeint_mod" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 % v1 |}]

(* Float operations *)

let%expect_test "generate prim - float_add" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "float_add" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 + v1 |}]

let%expect_test "generate prim - float_div" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "float_div" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 / v1 |}]

let%expect_test "generate prim - float_pow" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "float_pow" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 ^ v1 |}]

let%expect_test "generate prim - float_neg" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let prim = Code.Extern "float_neg" in
  let args = [ Code.Pv v ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| -v0 |}]

(* Bitwise operations *)

let%expect_test "generate prim - and (bitwise)" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "and" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 & v1 |}]

let%expect_test "generate prim - or (bitwise)" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "or" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 | v1 |}]

let%expect_test "generate prim - xor" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "xor" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 ~ v1 |}]

let%expect_test "generate prim - lsl (left shift)" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "lsl" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 << v1 |}]

let%expect_test "generate prim - lsr (logical shift right)" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "lsr" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 >> v1 |}]

let%expect_test "generate prim - asr (arithmetic shift right)" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "asr" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 >> v1 |}]

(* Int32 bitwise operations *)

let%expect_test "generate prim - int32_and" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "int32_and" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 & v1 |}]

let%expect_test "generate prim - int32_xor" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "int32_xor" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 ~ v1 |}]

let%expect_test "generate prim - int32_lsl" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "int32_lsl" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 << v1 |}]

(* Comparison operations *)

let%expect_test "generate prim - gt (greater than)" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "gt" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 > v1 |}]

let%expect_test "generate prim - ge (greater equal)" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "ge" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 >= v1 |}]

let%expect_test "generate prim - int_compare" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "int_compare" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_int_compare(v0, v1) |}]

let%expect_test "generate prim - float_compare" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "float_compare" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_float_compare(v0, v1) |}]

(* Type conversion *)

let%expect_test "generate prim - int_of_float" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let prim = Code.Extern "int_of_float" in
  let args = [ Code.Pv v ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| math.floor(v0) |}]

let%expect_test "generate prim - float_of_int" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let prim = Code.Extern "float_of_int" in
  let args = [ Code.Pv v ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 |}]

(* Arithmetic with constants *)

let%expect_test "generate prim - add with constant" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let prim = Code.Extern "add" in
  let args = [ Code.Pv v; Code.Pc (Code.Int32 10l) ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 + 10 |}]

let%expect_test "generate prim - mul with constant" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let prim = Code.Extern "mul" in
  let args = [ Code.Pc (Code.Int32 2l); Code.Pv v ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| 2 * v0 |}]

let%expect_test "generate prim - sub with both constants" =
  let ctx = make_ctx () in
  let prim = Code.Extern "sub" in
  let args = [ Code.Pc (Code.Int32 100l); Code.Pc (Code.Int32 30l) ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| 100 - 30 |}]

(* Unknown primitive fallback *)

let%expect_test "generate prim - unknown extern" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "custom_primitive" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_custom_primitive(v0, v1) |}]
