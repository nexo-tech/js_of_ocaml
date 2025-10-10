(* Tests for Lua I/O primitive generation *)

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

(* File descriptor operations *)

let%expect_test "generate prim - caml_sys_open" =
  let ctx = make_ctx () in
  let name = var_of_int 1 in
  let flags = var_of_int 2 in
  let perms = var_of_int 3 in
  let _ = Lua_generate.var_name ctx name in
  let _ = Lua_generate.var_name ctx flags in
  let _ = Lua_generate.var_name ctx perms in
  let prim = Code.Extern "caml_sys_open" in
  let args = [ Code.Pv name; Code.Pv flags; Code.Pv perms ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_sys_open(v0, v1, v2) |}]

let%expect_test "generate prim - caml_sys_close" =
  let ctx = make_ctx () in
  let fd = var_of_int 1 in
  let _ = Lua_generate.var_name ctx fd in
  let prim = Code.Extern "caml_sys_close" in
  let args = [ Code.Pv fd ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_sys_close(v0) |}]

(* Channel creation *)

let%expect_test "generate prim - caml_ml_open_descriptor_in" =
  let ctx = make_ctx () in
  let fd = var_of_int 1 in
  let _ = Lua_generate.var_name ctx fd in
  let prim = Code.Extern "caml_ml_open_descriptor_in" in
  let args = [ Code.Pv fd ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_open_descriptor_in(v0) |}]

let%expect_test "generate prim - caml_ml_open_descriptor_out" =
  let ctx = make_ctx () in
  let fd = var_of_int 1 in
  let _ = Lua_generate.var_name ctx fd in
  let prim = Code.Extern "caml_ml_open_descriptor_out" in
  let args = [ Code.Pv fd ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_open_descriptor_out(v0) |}]

let%expect_test "generate prim - caml_ml_open_descriptor_in_with_flags" =
  let ctx = make_ctx () in
  let fd = var_of_int 1 in
  let flags = var_of_int 2 in
  let _ = Lua_generate.var_name ctx fd in
  let _ = Lua_generate.var_name ctx flags in
  let prim = Code.Extern "caml_ml_open_descriptor_in_with_flags" in
  let args = [ Code.Pv fd; Code.Pv flags ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_open_descriptor_in_with_flags(v0, v1) |}]

let%expect_test "generate prim - caml_ml_open_descriptor_out_with_flags" =
  let ctx = make_ctx () in
  let fd = var_of_int 1 in
  let flags = var_of_int 2 in
  let _ = Lua_generate.var_name ctx fd in
  let _ = Lua_generate.var_name ctx flags in
  let prim = Code.Extern "caml_ml_open_descriptor_out_with_flags" in
  let args = [ Code.Pv fd; Code.Pv flags ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_open_descriptor_out_with_flags(v0, v1) |}]

let%expect_test "generate prim - caml_ml_close_channel" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_close_channel" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_close_channel(v0) |}]

let%expect_test "generate prim - caml_ml_flush" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_flush" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_flush(v0) |}]

(* Input operations *)

let%expect_test "generate prim - caml_ml_input_char" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_input_char" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_input_char(v0) |}]

let%expect_test "generate prim - caml_ml_input" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let buf = var_of_int 2 in
  let offset = var_of_int 3 in
  let len = var_of_int 4 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx buf in
  let _ = Lua_generate.var_name ctx offset in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "caml_ml_input" in
  let args = [ Code.Pv chan; Code.Pv buf; Code.Pv offset; Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_input(v0, v1, v2, v3) |}]

let%expect_test "generate prim - caml_ml_input_int" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_input_int" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_input_int(v0) |}]

let%expect_test "generate prim - caml_ml_input_scan_line" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_input_scan_line" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_input_scan_line(v0) |}]

let%expect_test "generate prim - caml_input_value" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_input_value" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_input_value(v0) |}]

let%expect_test "generate prim - caml_input_value_to_outside_heap" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_input_value_to_outside_heap" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_input_value_to_outside_heap(v0) |}]

(* Output operations *)

let%expect_test "generate prim - caml_ml_output_char" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let c = var_of_int 2 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx c in
  let prim = Code.Extern "caml_ml_output_char" in
  let args = [ Code.Pv chan; Code.Pv c ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_output_char(v0, v1) |}]

let%expect_test "generate prim - caml_ml_output" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let buf = var_of_int 2 in
  let offset = var_of_int 3 in
  let len = var_of_int 4 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx buf in
  let _ = Lua_generate.var_name ctx offset in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "caml_ml_output" in
  let args = [ Code.Pv chan; Code.Pv buf; Code.Pv offset; Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_output(v0, v1, v2, v3) |}]

let%expect_test "generate prim - caml_ml_output_bytes" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let buf = var_of_int 2 in
  let offset = var_of_int 3 in
  let len = var_of_int 4 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx buf in
  let _ = Lua_generate.var_name ctx offset in
  let _ = Lua_generate.var_name ctx len in
  let prim = Code.Extern "caml_ml_output_bytes" in
  let args = [ Code.Pv chan; Code.Pv buf; Code.Pv offset; Code.Pv len ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_output_bytes(v0, v1, v2, v3) |}]

let%expect_test "generate prim - caml_ml_output_int" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let i = var_of_int 2 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx i in
  let prim = Code.Extern "caml_ml_output_int" in
  let args = [ Code.Pv chan; Code.Pv i ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_output_int(v0, v1) |}]

let%expect_test "generate prim - caml_output_value" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let v = var_of_int 2 in
  let flags = var_of_int 3 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx v in
  let _ = Lua_generate.var_name ctx flags in
  let prim = Code.Extern "caml_output_value" in
  let args = [ Code.Pv chan; Code.Pv v; Code.Pv flags ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_output_value(v0, v1, v2) |}]

(* Channel positioning *)

let%expect_test "generate prim - caml_ml_seek_in" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let pos = var_of_int 2 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx pos in
  let prim = Code.Extern "caml_ml_seek_in" in
  let args = [ Code.Pv chan; Code.Pv pos ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_seek_in(v0, v1) |}]

let%expect_test "generate prim - caml_ml_seek_in_64" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let pos = var_of_int 2 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx pos in
  let prim = Code.Extern "caml_ml_seek_in_64" in
  let args = [ Code.Pv chan; Code.Pv pos ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_seek_in_64(v0, v1) |}]

let%expect_test "generate prim - caml_ml_seek_out" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let pos = var_of_int 2 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx pos in
  let prim = Code.Extern "caml_ml_seek_out" in
  let args = [ Code.Pv chan; Code.Pv pos ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_seek_out(v0, v1) |}]

let%expect_test "generate prim - caml_ml_seek_out_64" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let pos = var_of_int 2 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx pos in
  let prim = Code.Extern "caml_ml_seek_out_64" in
  let args = [ Code.Pv chan; Code.Pv pos ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_seek_out_64(v0, v1) |}]

let%expect_test "generate prim - caml_ml_pos_in" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_pos_in" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_pos_in(v0) |}]

let%expect_test "generate prim - caml_ml_pos_in_64" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_pos_in_64" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_pos_in_64(v0) |}]

let%expect_test "generate prim - caml_ml_pos_out" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_pos_out" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_pos_out(v0) |}]

let%expect_test "generate prim - caml_ml_pos_out_64" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_pos_out_64" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_pos_out_64(v0) |}]

let%expect_test "generate prim - caml_ml_channel_size" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_channel_size" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_channel_size(v0) |}]

let%expect_test "generate prim - caml_ml_channel_size_64" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_channel_size_64" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_channel_size_64(v0) |}]

(* Channel configuration *)

let%expect_test "generate prim - caml_ml_set_binary_mode" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let mode = var_of_int 2 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx mode in
  let prim = Code.Extern "caml_ml_set_binary_mode" in
  let args = [ Code.Pv chan; Code.Pv mode ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_set_binary_mode(v0, v1) |}]

let%expect_test "generate prim - caml_ml_is_binary_mode" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_is_binary_mode" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_is_binary_mode(v0) |}]

let%expect_test "generate prim - caml_ml_set_channel_name" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let name = var_of_int 2 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx name in
  let prim = Code.Extern "caml_ml_set_channel_name" in
  let args = [ Code.Pv chan; Code.Pv name ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_set_channel_name(v0, v1) |}]

let%expect_test "generate prim - caml_channel_descriptor" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_channel_descriptor" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_channel_descriptor(v0) |}]

let%expect_test "generate prim - caml_ml_out_channels_list" =
  let ctx = make_ctx () in
  let prim = Code.Extern "caml_ml_out_channels_list" in
  let args = [] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_out_channels_list() |}]

let%expect_test "generate prim - caml_ml_is_buffered" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let _ = Lua_generate.var_name ctx chan in
  let prim = Code.Extern "caml_ml_is_buffered" in
  let args = [ Code.Pv chan ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_is_buffered(v0) |}]

let%expect_test "generate prim - caml_ml_set_buffered" =
  let ctx = make_ctx () in
  let chan = var_of_int 1 in
  let v = var_of_int 2 in
  let _ = Lua_generate.var_name ctx chan in
  let _ = Lua_generate.var_name ctx v in
  let prim = Code.Extern "caml_ml_set_buffered" in
  let args = [ Code.Pv chan; Code.Pv v ] in
  let lua_expr = Lua_generate.generate_prim ctx prim args in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_ml_set_buffered(v0, v1) |}]
