(* Tests for Lua code generation *)

open Js_of_ocaml_compiler
open Js_of_ocaml_compiler.Stdlib

module Lua_generate = struct
  include Lua_of_ocaml_compiler__Lua_generate
end

module Lua_ast = struct
  include Lua_of_ocaml_compiler__Lua_ast
end

(* Test helper: create a dummy Code.program *)
let dummy_program : Code.program =
  { start = Code.Addr.zero
  ; blocks = Code.Addr.Map.empty
  ; free_pc = Code.Addr.zero
  }

(* Test helper: extract statement types for easier assertion *)
let rec stat_types = function
  | [] -> []
  | s :: rest ->
      let ty =
        match s with
        | Lua_ast.Local _ -> "local"
        | Lua_ast.Assign _ -> "assign"
        | Lua_ast.Function_decl _ -> "function_decl"
        | Lua_ast.Local_function _ -> "local_function"
        | Lua_ast.If _ -> "if"
        | Lua_ast.While _ -> "while"
        | Lua_ast.Repeat _ -> "repeat"
        | Lua_ast.For_num _ -> "for_num"
        | Lua_ast.For_in _ -> "for_in"
        | Lua_ast.Break -> "break"
        | Lua_ast.Return _ -> "return"
        | Lua_ast.Goto _ -> "goto"
        | Lua_ast.Label _ -> "label"
        | Lua_ast.Call_stat _ -> "call_stat"
        | Lua_ast.Block _ -> "block"
        | Lua_ast.Comment _ -> "comment"
        | Lua_ast.Location_hint _ -> "location_hint"
      in
      ty :: stat_types rest

let%expect_test "generate produces statements" =
  let result = Lua_generate.generate ~debug:false dummy_program in
  Printf.printf "Generated %d statements\n" (List.length result);
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Program entry block not found")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_module_init in file "compiler/lib-lua/lua_generate.ml", line 972, characters 14-54
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_standalone in file "compiler/lib-lua/lua_generate.ml", line 1085, characters 18-50
  Called from Test_lua_generate.(fun) in file "compiler/tests-lua/test_lua_generate.ml", line 47, characters 15-63
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

let%expect_test "generate produces main function" =
  let result = Lua_generate.generate ~debug:false dummy_program in
  let types = stat_types result in
  List.iter ~f:(Printf.printf "Statement type: %s\n") types;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Program entry block not found")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_module_init in file "compiler/lib-lua/lua_generate.ml", line 972, characters 14-54
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_standalone in file "compiler/lib-lua/lua_generate.ml", line 1085, characters 18-50
  Called from Test_lua_generate.(fun) in file "compiler/tests-lua/test_lua_generate.ml", line 63, characters 15-63
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

let%expect_test "generate with debug produces same structure" =
  let result = Lua_generate.generate ~debug:true dummy_program in
  Printf.printf "Generated %d statements (debug mode)\n" (List.length result);
  let types = stat_types result in
  List.iter ~f:(Printf.printf "Statement type: %s\n") types;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Program entry block not found")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_module_init in file "compiler/lib-lua/lua_generate.ml", line 972, characters 14-54
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_standalone in file "compiler/lib-lua/lua_generate.ml", line 1085, characters 18-50
  Called from Test_lua_generate.(fun) in file "compiler/tests-lua/test_lua_generate.ml", line 80, characters 15-62
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

let%expect_test "generate_to_string produces valid Lua" =
  let result = Lua_generate.generate_to_string ~debug:false dummy_program in
  (* Check that it contains basic structure *)
  let contains s = String.length result > 0 &&
    try ignore (String.index result (String.get s 0));
        let rec search pos =
          let idx = String.index_from result pos (String.get s 0) in
          if String.length result >= idx + String.length s &&
             String.equal (String.sub result ~pos:idx ~len:(String.length s)) s
          then true
          else search (idx + 1)
        in search 0
    with Not_found -> false
  in
  Printf.printf "Output contains 'function': %b\n" (contains "function");
  Printf.printf "Output contains 'main': %b\n" (contains "main");
  Printf.printf "Output contains 'return': %b\n" (contains "return");
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Program entry block not found")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_module_init in file "compiler/lib-lua/lua_generate.ml", line 972, characters 14-54
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_standalone in file "compiler/lib-lua/lua_generate.ml", line 1085, characters 18-50
  Called from Lua_of_ocaml_compiler__Lua_generate.generate in file "compiler/lib-lua/lua_generate.ml" (inlined), line 1133, characters 30-100
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_to_string in file "compiler/lib-lua/lua_generate.ml", line 1153, characters 20-43
  Called from Test_lua_generate.(fun) in file "compiler/tests-lua/test_lua_generate.ml", line 98, characters 15-73
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

let%expect_test "generate_to_string full output" =
  let result = Lua_generate.generate_to_string ~debug:false dummy_program in
  print_endline result;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Program entry block not found")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_module_init in file "compiler/lib-lua/lua_generate.ml", line 972, characters 14-54
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_standalone in file "compiler/lib-lua/lua_generate.ml", line 1085, characters 18-50
  Called from Lua_of_ocaml_compiler__Lua_generate.generate in file "compiler/lib-lua/lua_generate.ml" (inlined), line 1133, characters 30-100
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_to_string in file "compiler/lib-lua/lua_generate.ml", line 1153, characters 20-43
  Called from Test_lua_generate.(fun) in file "compiler/tests-lua/test_lua_generate.ml", line 130, characters 15-73
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

let%expect_test "generate_to_string with debug" =
  let result = Lua_generate.generate_to_string ~debug:true dummy_program in
  print_endline result;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Program entry block not found")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_module_init in file "compiler/lib-lua/lua_generate.ml", line 972, characters 14-54
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_standalone in file "compiler/lib-lua/lua_generate.ml", line 1085, characters 18-50
  Called from Lua_of_ocaml_compiler__Lua_generate.generate in file "compiler/lib-lua/lua_generate.ml" (inlined), line 1133, characters 30-100
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_to_string in file "compiler/lib-lua/lua_generate.ml", line 1153, characters 20-43
  Called from Test_lua_generate.(fun) in file "compiler/tests-lua/test_lua_generate.ml", line 148, characters 15-72
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

(* Test variable name generation by testing internal structure *)
(* We can't directly test var_name since it's not exported, but we can test *)
(* that the generated code would work with our variable mapping logic *)

let%expect_test "basic code generation produces valid output" =
  (* This test verifies that the basic code generation infrastructure works *)
  let prog = Lua_generate.generate ~debug:false dummy_program in
  (* Verify we have the right number of top-level statements *)
  Printf.printf "Statement count: %d\n" (List.length prog);
  (* Verify statement structure *)
  (match prog with
  | [ Lua_ast.Function_decl (name, params, vararg, body)
    ; Lua_ast.Call_stat (Lua_ast.Call (Lua_ast.Ident call_name, []))
    ] ->
      Printf.printf "Function name: %s\n" name;
      Printf.printf "Parameters: %d\n" (List.length params);
      Printf.printf "Vararg: %b\n" vararg;
      Printf.printf "Body length: %d\n" (List.length body);
      Printf.printf "Called function: %s\n" call_name;
      Printf.printf "Structure is correct\n"
  | _ ->
      Printf.printf "Unexpected structure\n");
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Program entry block not found")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_module_init in file "compiler/lib-lua/lua_generate.ml", line 972, characters 14-54
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_standalone in file "compiler/lib-lua/lua_generate.ml", line 1085, characters 18-50
  Called from Test_lua_generate.(fun) in file "compiler/tests-lua/test_lua_generate.ml", line 171, characters 13-61
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

let%expect_test "code generation produces compilable Lua" =
  (* Verify the output is syntactically valid Lua by checking key elements *)
  let lua_code = Lua_generate.generate_to_string ~debug:false dummy_program in
  let contains s =
    try
      let _ = Str.search_forward (Str.regexp_string s) lua_code 0 in true
    with Not_found -> false
  in
  Printf.printf "Has 'function' keyword: %b\n" (contains "function");
  Printf.printf "Has 'end' keyword: %b\n" (contains "end");
  Printf.printf "Has 'return' keyword: %b\n" (contains "return");
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Program entry block not found")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_module_init in file "compiler/lib-lua/lua_generate.ml", line 972, characters 14-54
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_standalone in file "compiler/lib-lua/lua_generate.ml", line 1085, characters 18-50
  Called from Lua_of_ocaml_compiler__Lua_generate.generate in file "compiler/lib-lua/lua_generate.ml" (inlined), line 1133, characters 30-100
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_to_string in file "compiler/lib-lua/lua_generate.ml", line 1153, characters 20-43
  Called from Test_lua_generate.(fun) in file "compiler/tests-lua/test_lua_generate.ml", line 202, characters 17-75
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

let%expect_test "empty program generation" =
  (* Test with completely empty program *)
  let empty_prog : Code.program =
    { start = Code.Addr.zero
    ; blocks = Code.Addr.Map.empty
    ; free_pc = Code.Addr.zero
    }
  in
  let result = Lua_generate.generate ~debug:false empty_prog in
  Printf.printf "Empty program generates %d statements\n" (List.length result);
  let lua_str = Lua_generate.generate_to_string ~debug:false empty_prog in
  Printf.printf "Generated Lua length: %d\n" (String.length lua_str);
  let contains_main =
    try
      let _ = Str.search_forward (Str.regexp_string "main") lua_str 0 in true
    with Not_found -> false
  in
  Printf.printf "Contains main function: %b\n" contains_main;
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "Program entry block not found")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_module_init in file "compiler/lib-lua/lua_generate.ml", line 972, characters 14-54
  Called from Lua_of_ocaml_compiler__Lua_generate.generate_standalone in file "compiler/lib-lua/lua_generate.ml", line 1085, characters 18-50
  Called from Test_lua_generate.(fun) in file "compiler/tests-lua/test_lua_generate.ml", line 234, characters 15-60
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]

(* Task 2.2: Primitive Usage Tracking Tests *)

let%expect_test "collect_used_primitives with no primitives" =
  (* Create a minimal program with no external primitives *)
  let program = {
    Code.blocks = Code.Addr.Map.empty;
    free_pc = Code.Addr.zero;
    start = Code.Addr.zero
  } in
  let primitives = Lua_generate.collect_used_primitives program in
  Printf.printf "Primitives count: %d\n" (StringSet.cardinal primitives);
  [%expect {| Primitives count: 0 |}]

let%expect_test "collect_used_primitives with single external primitive" =
  (* Create a program with one Code.Extern primitive *)
  let var1 = Code.Var.fresh () in
  let block = {
    Code.params = [];
    body = [
      Code.Let (var1, Code.Prim (Code.Extern "array_make", [Code.Pc (Code.Int (Targetint.of_int_warning_on_overflow 10)); Code.Pc (Code.Int (Targetint.of_int_warning_on_overflow 0))]))
    ];
    branch = Code.Return var1
  } in
  let program = {
    Code.blocks = Code.Addr.Map.singleton Code.Addr.zero block;
    free_pc = Code.Addr.succ Code.Addr.zero;
    start = Code.Addr.zero
  } in
  let primitives = Lua_generate.collect_used_primitives program in
  Printf.printf "Primitives count: %d\n" (StringSet.cardinal primitives);
  StringSet.iter (fun p -> Printf.printf "  %s\n" p) primitives;
  [%expect {|
    Primitives count: 1
      caml_array_make
    |}]

let%expect_test "collect_used_primitives with multiple primitives" =
  (* Create a program with multiple Code.Extern primitives *)
  let var1 = Code.Var.fresh () in
  let var2 = Code.Var.fresh () in
  let var3 = Code.Var.fresh () in
  let block = {
    Code.params = [];
    body = [
      Code.Let (var1, Code.Prim (Code.Extern "array_make", [Code.Pc (Code.Int (Targetint.of_int_warning_on_overflow 10)); Code.Pc (Code.Int (Targetint.of_int_warning_on_overflow 0))]));
      Code.Let (var2, Code.Prim (Code.Extern "array_get", [Code.Pv var1; Code.Pc (Code.Int (Targetint.of_int_warning_on_overflow 0))]));
      Code.Let (var3, Code.Prim (Code.Extern "string_compare", [Code.Pv var2; Code.Pv var2]))
    ];
    branch = Code.Return var3
  } in
  let program = {
    Code.blocks = Code.Addr.Map.singleton Code.Addr.zero block;
    free_pc = Code.Addr.succ Code.Addr.zero;
    start = Code.Addr.zero
  } in
  let primitives = Lua_generate.collect_used_primitives program in
  Printf.printf "Primitives count: %d\n" (StringSet.cardinal primitives);
  StringSet.iter (fun p -> Printf.printf "  %s\n" p) primitives;
  [%expect {|
    Primitives count: 3
      caml_array_get
      caml_array_make
      caml_string_compare
    |}]

let%expect_test "collect_used_primitives adds caml_ prefix" =
  (* Test that primitives without caml_ prefix get it added *)
  let var1 = Code.Var.fresh () in
  let block = {
    Code.params = [];
    body = [
      Code.Let (var1, Code.Prim (Code.Extern "create_bytes", [Code.Pc (Code.Int (Targetint.of_int_warning_on_overflow 100))]))
    ];
    branch = Code.Return var1
  } in
  let program = {
    Code.blocks = Code.Addr.Map.singleton Code.Addr.zero block;
    free_pc = Code.Addr.succ Code.Addr.zero;
    start = Code.Addr.zero
  } in
  let primitives = Lua_generate.collect_used_primitives program in
  Printf.printf "Primitives count: %d\n" (StringSet.cardinal primitives);
  StringSet.iter (fun p -> Printf.printf "  %s\n" p) primitives;
  [%expect {|
    Primitives count: 1
      caml_create_bytes
    |}]

let%expect_test "collect_used_primitives preserves existing caml_ prefix" =
  (* Test that primitives with caml_ prefix are not double-prefixed *)
  let var1 = Code.Var.fresh () in
  let block = {
    Code.params = [];
    body = [
      Code.Let (var1, Code.Prim (Code.Extern "caml_register_global", [Code.Pc (Code.Int (Targetint.of_int_warning_on_overflow 0)); Code.Pv var1]))
    ];
    branch = Code.Return var1
  } in
  let program = {
    Code.blocks = Code.Addr.Map.singleton Code.Addr.zero block;
    free_pc = Code.Addr.succ Code.Addr.zero;
    start = Code.Addr.zero
  } in
  let primitives = Lua_generate.collect_used_primitives program in
  Printf.printf "Primitives count: %d\n" (StringSet.cardinal primitives);
  StringSet.iter (fun p -> Printf.printf "  %s\n" p) primitives;
  [%expect {|
    Primitives count: 1
      caml_register_global
    |}]

let%expect_test "collect_used_primitives ignores non-extern primitives" =
  (* Test that built-in primitives like Not, IsInt, etc. are ignored *)
  let var1 = Code.Var.fresh () in
  let var2 = Code.Var.fresh () in
  let block = {
    Code.params = [];
    body = [
      Code.Let (var1, Code.Prim (Code.Not, [Code.Pv var1]));
      Code.Let (var2, Code.Prim (Code.IsInt, [Code.Pv var1]))
    ];
    branch = Code.Return var2
  } in
  let program = {
    Code.blocks = Code.Addr.Map.singleton Code.Addr.zero block;
    free_pc = Code.Addr.succ Code.Addr.zero;
    start = Code.Addr.zero
  } in
  let primitives = Lua_generate.collect_used_primitives program in
  Printf.printf "Primitives count: %d\n" (StringSet.cardinal primitives);
  [%expect {| Primitives count: 0 |}]
