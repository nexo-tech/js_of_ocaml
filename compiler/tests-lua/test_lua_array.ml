(* Tests for Lua array and reference generation *)

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

(* Array access operations *)

let%expect_test "generate prim - array_get" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let idx = var_of_int 2 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx idx in
  let prim = Code.Extern "array_get" in
  let args = [ Code.Pv arr; Code.Pv idx ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0[v1 + 1] |}]

let%expect_test "generate prim - array_get with constant index" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let _ = Lua_generate.var_name ctx arr in
  let prim = Code.Extern "array_get" in
  let args = [ Code.Pv arr; Code.Pc (Code.Int32 0l) ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0[0 + 1] |}]

let%expect_test "generate prim - array_unsafe_get" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let idx = var_of_int 2 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx idx in
  let prim = Code.Extern "array_unsafe_get" in
  let args = [ Code.Pv arr; Code.Pv idx ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0[v1 + 1] |}]

(* Array mutation operations *)

let%expect_test "generate prim - array_set" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let idx = var_of_int 2 in
  let value = var_of_int 3 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx idx in
  let _ = Lua_generate.var_name ctx value in
  let prim = Code.Extern "array_set" in
  let args = [ Code.Pv arr; Code.Pv idx; Code.Pv value ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_array_set(v0, v1, v2) |}]

let%expect_test "generate prim - array_unsafe_set" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let idx = var_of_int 2 in
  let value = var_of_int 3 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx idx in
  let _ = Lua_generate.var_name ctx value in
  let prim = Code.Extern "array_unsafe_set" in
  let args = [ Code.Pv arr; Code.Pv idx; Code.Pv value ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_array_unsafe_set(v0, v1, v2) |}]

(* Array creation operations *)

let%expect_test "generate prim - make_vect" =
  let ctx = make_ctx () in
  let len = var_of_int 1 in
  let init = var_of_int 2 in
  let _ = Lua_generate.var_name ctx len in
  let _ = Lua_generate.var_name ctx init in
  let prim = Code.Extern "make_vect" in
  let args = [ Code.Pv len; Code.Pv init ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_make_vect(v0, v1) |}]

let%expect_test "generate prim - make_vect with constant" =
  let ctx = make_ctx () in
  let prim = Code.Extern "make_vect" in
  let args = [ Code.Pc (Code.Int32 10l); Code.Pc (Code.Int32 0l) ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_make_vect(10, 0) |}]

let%expect_test "generate prim - array_make" =
  let ctx = make_ctx () in
  let len = var_of_int 1 in
  let init = var_of_int 2 in
  let _ = Lua_generate.var_name ctx len in
  let _ = Lua_generate.var_name ctx init in
  let prim = Code.Extern "array_make" in
  let args = [ Code.Pv len; Code.Pv init ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_array_make(v0, v1) |}]

let%expect_test "generate prim - array_length" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let _ = Lua_generate.var_name ctx arr in
  let prim = Code.Extern "array_length" in
  let args = [ Code.Pv arr ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| #v0 |}]

(* Float array operations *)

let%expect_test "generate prim - floatarray_get" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let idx = var_of_int 2 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx idx in
  let prim = Code.Extern "floatarray_get" in
  let args = [ Code.Pv arr; Code.Pv idx ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0[v1 + 1] |}]

let%expect_test "generate prim - floatarray_set" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let idx = var_of_int 2 in
  let value = var_of_int 3 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx idx in
  let _ = Lua_generate.var_name ctx value in
  let prim = Code.Extern "floatarray_set" in
  let args = [ Code.Pv arr; Code.Pv idx; Code.Pv value ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_floatarray_set(v0, v1, v2) |}]

let%expect_test "generate prim - floatarray_unsafe_get" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let idx = var_of_int 2 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx idx in
  let prim = Code.Extern "floatarray_unsafe_get" in
  let args = [ Code.Pv arr; Code.Pv idx ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0[v1 + 1] |}]

let%expect_test "generate prim - floatarray_unsafe_set" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let idx = var_of_int 2 in
  let value = var_of_int 3 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx idx in
  let _ = Lua_generate.var_name ctx value in
  let prim = Code.Extern "floatarray_unsafe_set" in
  let args = [ Code.Pv arr; Code.Pv idx; Code.Pv value ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_floatarray_unsafe_set(v0, v1, v2) |}]

let%expect_test "generate prim - floatarray_create" =
  let ctx = make_ctx () in
  let len = var_of_int 1 in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "floatarray_create" in
  let args = [ Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_floatarray_create(v0) |}]

let%expect_test "generate prim - make_float_vect" =
  let ctx = make_ctx () in
  let len = var_of_int 1 in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "make_float_vect" in
  let args = [ Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_make_float_vect(v0) |}]

(* Array manipulation operations *)

let%expect_test "generate prim - array_sub" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let offset = var_of_int 2 in
  let len = var_of_int 3 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx offset in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "array_sub" in
  let args = [ Code.Pv arr; Code.Pv offset; Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_array_sub(v0, v1, v2) |}]

let%expect_test "generate prim - array_append" =
  let ctx = make_ctx () in
  let arr1 = var_of_int 1 in
  let arr2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx arr1 in
  let _ = Lua_generate.var_name ctx arr2 in
  let prim = Code.Extern "array_append" in
  let args = [ Code.Pv arr1; Code.Pv arr2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_array_append(v0, v1) |}]

let%expect_test "generate prim - array_concat" =
  let ctx = make_ctx () in
  let arr_list = var_of_int 1 in
  let _ = Lua_generate.var_name ctx arr_list in
  let prim = Code.Extern "array_concat" in
  let args = [ Code.Pv arr_list ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_array_concat(v0) |}]

let%expect_test "generate prim - array_blit" =
  let ctx = make_ctx () in
  let src = var_of_int 1 in
  let src_pos = var_of_int 2 in
  let dst = var_of_int 3 in
  let dst_pos = var_of_int 4 in
  let len = var_of_int 5 in
  let _ = Lua_generate.var_name ctx src in
  let _ = Lua_generate.var_name ctx src_pos in
  let _ = Lua_generate.var_name ctx dst in
  let _ = Lua_generate.var_name ctx dst_pos in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "array_blit" in
  let args = [ Code.Pv src; Code.Pv src_pos; Code.Pv dst; Code.Pv dst_pos; Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_array_blit(v0, v1, v2, v3, v4) |}]

let%expect_test "generate prim - array_fill" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let offset = var_of_int 2 in
  let len = var_of_int 3 in
  let value = var_of_int 4 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx offset in
  let _ = Lua_generate.var_name ctx len in
  let _ = Lua_generate.var_name ctx value in
  let prim = Code.Extern "array_fill" in
  let args = [ Code.Pv arr; Code.Pv offset; Code.Pv len; Code.Pv value ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_array_fill(v0, v1, v2, v3) |}]

(* Reference operations *)

let%expect_test "generate prim - ref" =
  let ctx = make_ctx () in
  let value = var_of_int 1 in
  let _ = Lua_generate.var_name ctx value in
  let prim = Code.Extern "ref" in
  let args = [ Code.Pv value ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| {v0} |}]

let%expect_test "generate prim - ref with constant" =
  let ctx = make_ctx () in
  let prim = Code.Extern "ref" in
  let args = [ Code.Pc (Code.Int32 42l) ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| {42} |}]

let%expect_test "generate prim - ref_get" =
  let ctx = make_ctx () in
  let ref_var = var_of_int 1 in
  let _ = Lua_generate.var_name ctx ref_var in
  let prim = Code.Extern "ref_get" in
  let args = [ Code.Pv ref_var ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0[1] |}]

let%expect_test "generate prim - ref_set" =
  let ctx = make_ctx () in
  let ref_var = var_of_int 1 in
  let value = var_of_int 2 in
  let _ = Lua_generate.var_name ctx ref_var in
  let _ = Lua_generate.var_name ctx value in
  let prim = Code.Extern "ref_set" in
  let args = [ Code.Pv ref_var; Code.Pv value ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ref_set(v0, v1) |}]

(* Weak reference operations *)

let%expect_test "generate prim - weak_create" =
  let ctx = make_ctx () in
  let len = var_of_int 1 in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "weak_create" in
  let args = [ Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_weak_create(v0) |}]

let%expect_test "generate prim - weak_get" =
  let ctx = make_ctx () in
  let weak = var_of_int 1 in
  let idx = var_of_int 2 in
  let _ = Lua_generate.var_name ctx weak in
  let _ = Lua_generate.var_name ctx idx in
  let prim = Code.Extern "weak_get" in
  let args = [ Code.Pv weak; Code.Pv idx ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_weak_get(v0, v1) |}]

let%expect_test "generate prim - weak_set" =
  let ctx = make_ctx () in
  let weak = var_of_int 1 in
  let idx = var_of_int 2 in
  let value = var_of_int 3 in
  let _ = Lua_generate.var_name ctx weak in
  let _ = Lua_generate.var_name ctx idx in
  let _ = Lua_generate.var_name ctx value in
  let prim = Code.Extern "weak_set" in
  let args = [ Code.Pv weak; Code.Pv idx; Code.Pv value ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_weak_set(v0, v1, v2) |}]

let%expect_test "generate prim - weak_check" =
  let ctx = make_ctx () in
  let weak = var_of_int 1 in
  let idx = var_of_int 2 in
  let _ = Lua_generate.var_name ctx weak in
  let _ = Lua_generate.var_name ctx idx in
  let prim = Code.Extern "weak_check" in
  let args = [ Code.Pv weak; Code.Pv idx ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_weak_check(v0, v1) |}]

(* Edge cases *)

let%expect_test "generate prim - array_get with zero index" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let _ = Lua_generate.var_name ctx arr in
  let prim = Code.Extern "array_get" in
  let args = [ Code.Pv arr; Code.Pc (Code.Int32 0l) ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0[0 + 1] |}]

let%expect_test "generate prim - array_get with negative index" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let _ = Lua_generate.var_name ctx arr in
  let prim = Code.Extern "array_get" in
  let args = [ Code.Pv arr; Code.Pc (Code.Int32 (-1l)) ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0[-1 + 1] |}]

let%expect_test "generate prim - make_vect with zero length" =
  let ctx = make_ctx () in
  let prim = Code.Extern "make_vect" in
  let args = [ Code.Pc (Code.Int32 0l); Code.Pc (Code.Int32 0l) ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_make_vect(0, 0) |}]
