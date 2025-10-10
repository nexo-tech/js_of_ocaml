(* Tests for Lua string primitive generation *)

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

(* String length tests *)

let%expect_test "generate prim - ml_string_length" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let prim = Code.Extern "ml_string_length" in
  let args = [ Code.Pv v ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| #v0 |}]

(* String concatenation tests *)

let%expect_test "generate prim - string_concat" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "string_concat" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 .. v1 |}]

let%expect_test "generate prim - string_concat with constant" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let prim = Code.Extern "string_concat" in
  let args = [ Code.Pv v; Code.Pc (Code.String " world") ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 .. " world" |}]

(* String comparison tests *)

let%expect_test "generate prim - string_compare" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "string_compare" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_string_compare(v0, v1) |}]

let%expect_test "generate prim - string_equal" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "string_equal" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 == v1 |}]

let%expect_test "generate prim - string_notequal" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "string_notequal" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 ~= v1 |}]

let%expect_test "generate prim - string_lessthan" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "string_lessthan" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 < v1 |}]

let%expect_test "generate prim - string_lessequal" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "string_lessequal" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 <= v1 |}]

let%expect_test "generate prim - string_greaterthan" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "string_greaterthan" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 > v1 |}]

let%expect_test "generate prim - string_greaterequal" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let prim = Code.Extern "string_greaterequal" in
  let args = [ Code.Pv v1; Code.Pv v2 ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 >= v1 |}]

(* String access tests *)

let%expect_test "generate prim - string_unsafe_get" =
  let ctx = make_ctx () in
  let str = var_of_int 1 in
  let idx = var_of_int 2 in
  let _ = Lua_generate.var_name ctx str in
  let _ = Lua_generate.var_name ctx idx in
  let prim = Code.Extern "string_unsafe_get" in
  let args = [ Code.Pv str; Code.Pv idx ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| string.byte(v0, v1 + 1) |}]

let%expect_test "generate prim - string_get" =
  let ctx = make_ctx () in
  let str = var_of_int 1 in
  let idx = var_of_int 2 in
  let _ = Lua_generate.var_name ctx str in
  let _ = Lua_generate.var_name ctx idx in
  let prim = Code.Extern "string_get" in
  let args = [ Code.Pv str; Code.Pv idx ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_string_get(v0, v1) |}]

let%expect_test "generate prim - string_unsafe_get with constant index" =
  let ctx = make_ctx () in
  let str = var_of_int 1 in
  let _ = Lua_generate.var_name ctx str in
  let prim = Code.Extern "string_unsafe_get" in
  let args = [ Code.Pv str; Code.Pc (Code.Int32 0l) ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| string.byte(v0, 0 + 1) |}]

(* String mutation tests *)

let%expect_test "generate prim - string_unsafe_set" =
  let ctx = make_ctx () in
  let str = var_of_int 1 in
  let idx = var_of_int 2 in
  let char = var_of_int 3 in
  let _ = Lua_generate.var_name ctx str in
  let _ = Lua_generate.var_name ctx idx in
  let _ = Lua_generate.var_name ctx char in
  let prim = Code.Extern "string_unsafe_set" in
  let args = [ Code.Pv str; Code.Pv idx; Code.Pv char ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_string_unsafe_set(v0, v1, v2) |}]

let%expect_test "generate prim - string_set" =
  let ctx = make_ctx () in
  let str = var_of_int 1 in
  let idx = var_of_int 2 in
  let char = var_of_int 3 in
  let _ = Lua_generate.var_name ctx str in
  let _ = Lua_generate.var_name ctx idx in
  let _ = Lua_generate.var_name ctx char in
  let prim = Code.Extern "string_set" in
  let args = [ Code.Pv str; Code.Pv idx; Code.Pv char ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_string_set(v0, v1, v2) |}]

(* Bytes operations *)

let%expect_test "generate prim - bytes_unsafe_get" =
  let ctx = make_ctx () in
  let bytes = var_of_int 1 in
  let idx = var_of_int 2 in
  let _ = Lua_generate.var_name ctx bytes in
  let _ = Lua_generate.var_name ctx idx in
  let prim = Code.Extern "bytes_unsafe_get" in
  let args = [ Code.Pv bytes; Code.Pv idx ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| string.byte(v0, v1 + 1) |}]

let%expect_test "generate prim - bytes_get" =
  let ctx = make_ctx () in
  let bytes = var_of_int 1 in
  let idx = var_of_int 2 in
  let _ = Lua_generate.var_name ctx bytes in
  let _ = Lua_generate.var_name ctx idx in
  let prim = Code.Extern "bytes_get" in
  let args = [ Code.Pv bytes; Code.Pv idx ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_bytes_get(v0, v1) |}]

let%expect_test "generate prim - bytes_unsafe_set" =
  let ctx = make_ctx () in
  let bytes = var_of_int 1 in
  let idx = var_of_int 2 in
  let char = var_of_int 3 in
  let _ = Lua_generate.var_name ctx bytes in
  let _ = Lua_generate.var_name ctx idx in
  let _ = Lua_generate.var_name ctx char in
  let prim = Code.Extern "bytes_unsafe_set" in
  let args = [ Code.Pv bytes; Code.Pv idx; Code.Pv char ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_bytes_unsafe_set(v0, v1, v2) |}]

let%expect_test "generate prim - bytes_set" =
  let ctx = make_ctx () in
  let bytes = var_of_int 1 in
  let idx = var_of_int 2 in
  let char = var_of_int 3 in
  let _ = Lua_generate.var_name ctx bytes in
  let _ = Lua_generate.var_name ctx idx in
  let _ = Lua_generate.var_name ctx char in
  let prim = Code.Extern "bytes_set" in
  let args = [ Code.Pv bytes; Code.Pv idx; Code.Pv char ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_bytes_set(v0, v1, v2) |}]

(* String creation *)

let%expect_test "generate prim - create_string" =
  let ctx = make_ctx () in
  let len = var_of_int 1 in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "create_string" in
  let args = [ Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_create_string(v0) |}]

let%expect_test "generate prim - create_bytes" =
  let ctx = make_ctx () in
  let len = var_of_int 1 in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "create_bytes" in
  let args = [ Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_create_bytes(v0) |}]

(* String/bytes conversion *)

let%expect_test "generate prim - bytes_to_string" =
  let ctx = make_ctx () in
  let bytes = var_of_int 1 in
  let _ = Lua_generate.var_name ctx bytes in
  let prim = Code.Extern "bytes_to_string" in
  let args = [ Code.Pv bytes ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 |}]

let%expect_test "generate prim - bytes_of_string" =
  let ctx = make_ctx () in
  let str = var_of_int 1 in
  let _ = Lua_generate.var_name ctx str in
  let prim = Code.Extern "bytes_of_string" in
  let args = [ Code.Pv str ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0 |}]

(* String manipulation *)

let%expect_test "generate prim - string_sub" =
  let ctx = make_ctx () in
  let str = var_of_int 1 in
  let offset = var_of_int 2 in
  let len = var_of_int 3 in
  let _ = Lua_generate.var_name ctx str in
  let _ = Lua_generate.var_name ctx offset in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "string_sub" in
  let args = [ Code.Pv str; Code.Pv offset; Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| string.sub(v0, v1 + 1, v1 + v2 + 0) |}]

let%expect_test "generate prim - bytes_sub" =
  let ctx = make_ctx () in
  let bytes = var_of_int 1 in
  let offset = var_of_int 2 in
  let len = var_of_int 3 in
  let _ = Lua_generate.var_name ctx bytes in
  let _ = Lua_generate.var_name ctx offset in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "bytes_sub" in
  let args = [ Code.Pv bytes; Code.Pv offset; Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| string.sub(v0, v1 + 1, v1 + v2 + 0) |}]

let%expect_test "generate prim - fill_bytes" =
  let ctx = make_ctx () in
  let bytes = var_of_int 1 in
  let offset = var_of_int 2 in
  let len = var_of_int 3 in
  let char = var_of_int 4 in
  let _ = Lua_generate.var_name ctx bytes in
  let _ = Lua_generate.var_name ctx offset in
  let _ = Lua_generate.var_name ctx len in
  let _ = Lua_generate.var_name ctx char in
  let prim = Code.Extern "fill_bytes" in
  let args = [ Code.Pv bytes; Code.Pv offset; Code.Pv len; Code.Pv char ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_fill_bytes(v0, v1, v2, v3) |}]

let%expect_test "generate prim - blit_string" =
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
  let prim = Code.Extern "blit_string" in
  let args = [ Code.Pv src; Code.Pv src_pos; Code.Pv dst; Code.Pv dst_pos; Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_blit_string(v0, v1, v2, v3, v4) |}]

let%expect_test "generate prim - blit_bytes" =
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
  let prim = Code.Extern "blit_bytes" in
  let args = [ Code.Pv src; Code.Pv src_pos; Code.Pv dst; Code.Pv dst_pos; Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_blit_bytes(v0, v1, v2, v3, v4) |}]
