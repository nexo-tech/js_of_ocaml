(* Tests for Lua statement generation *)

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
let make_ctx () = Lua_generate.make_context ~debug:false

let var_of_int i = Code.Var.of_idx i

let stat_to_string s = Lua_output.stat_to_string s

(* Let binding tests *)

let%expect_test "generate instr - let with constant" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let expr = Code.Constant (Code.Int32 42l) in
  let instr = Code.Let (v, expr) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  let lua_str = stat_to_string lua_stmt in
  print_endline lua_str;
  [%expect {| local v0 = 42 |}]

let%expect_test "generate instr - let with string" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let expr = Code.Constant (Code.String "hello") in
  let instr = Code.Let (v, expr) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  let lua_str = stat_to_string lua_stmt in
  print_endline lua_str;
  [%expect {| local v0 = "hello" |}]

let%expect_test "generate instr - let with variable" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  (* First, ensure v1 has a name *)
  let _ = Lua_generate.var_name ctx v1 in
  let expr = Code.Apply { f = v1; args = []; exact = true } in
  let instr = Code.Let (v2, expr) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  let lua_str = stat_to_string lua_stmt in
  print_endline lua_str;
  [%expect {| local v1 = v0() |}]

let%expect_test "generate instr - let with block" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let v1 = var_of_int 2 in
  let v2 = var_of_int 3 in
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let expr = Code.Block (0, [| v1; v2 |], Code.NotArray, Code.Immutable) in
  let instr = Code.Let (v, expr) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  let lua_str = stat_to_string lua_stmt in
  print_endline lua_str;
  [%expect {| local v2 = {tag = 0, v0, v1} |}]

(* Assignment tests *)

let%expect_test "generate instr - assign" =
  let ctx = make_ctx () in
  let target = var_of_int 1 in
  let source = var_of_int 2 in
  let _ = Lua_generate.var_name ctx target in
  let _ = Lua_generate.var_name ctx source in
  let instr = Code.Assign (target, source) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  let lua_str = stat_to_string lua_stmt in
  print_endline lua_str;
  [%expect {| v0 = v1 |}]

(* Field operations tests *)

let%expect_test "generate instr - set_field" =
  let ctx = make_ctx () in
  let obj = var_of_int 1 in
  let value = var_of_int 2 in
  let _ = Lua_generate.var_name ctx obj in
  let _ = Lua_generate.var_name ctx value in
  let instr = Code.Set_field (obj, 0, Code.Non_float, value) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  let lua_str = stat_to_string lua_stmt in
  print_endline lua_str;
  [%expect {| v0[1] = v1 |}]

let%expect_test "generate instr - set_field index 2" =
  let ctx = make_ctx () in
  let obj = var_of_int 1 in
  let value = var_of_int 2 in
  let _ = Lua_generate.var_name ctx obj in
  let _ = Lua_generate.var_name ctx value in
  let instr = Code.Set_field (obj, 2, Code.Non_float, value) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  let lua_str = stat_to_string lua_stmt in
  print_endline lua_str;
  [%expect {| v0[3] = v1 |}]

let%expect_test "generate instr - offset_ref positive" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let instr = Code.Offset_ref (v, 5) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  let lua_str = stat_to_string lua_stmt in
  print_endline lua_str;
  [%expect {| v0[1] = v0[1] + 5 |}]

let%expect_test "generate instr - offset_ref negative" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let instr = Code.Offset_ref (v, -3) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  let lua_str = stat_to_string lua_stmt in
  print_endline lua_str;
  [%expect {| v0[1] = v0[1] + -3 |}]

let%expect_test "generate instr - array_set" =
  let ctx = make_ctx () in
  let arr = var_of_int 1 in
  let idx = var_of_int 2 in
  let value = var_of_int 3 in
  let _ = Lua_generate.var_name ctx arr in
  let _ = Lua_generate.var_name ctx idx in
  let _ = Lua_generate.var_name ctx value in
  let instr = Code.Array_set (arr, idx, value) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  let lua_str = stat_to_string lua_stmt in
  print_endline lua_str;
  [%expect {| v0[v1 + 1] = v2 |}]

(* Sequence tests *)

let%expect_test "generate instrs - multiple let bindings" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let v3 = var_of_int 3 in
  let instrs =
    [ Code.Let (v1, Code.Constant (Code.Int32 1l))
    ; Code.Let (v2, Code.Constant (Code.Int32 2l))
    ; Code.Let (v3, Code.Constant (Code.Int32 3l))
    ]
  in
  let lua_stmts = Lua_generate.generate_instrs ctx instrs in
  List.iter (fun s -> print_endline (stat_to_string s)) lua_stmts;
  [%expect {|
    local v0 = 1
    local v1 = 2
    local v2 = 3 |}]

let%expect_test "generate instrs - let and assign sequence" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let instrs =
    [ Code.Let (v1, Code.Constant (Code.Int32 10l))
    ; Code.Let (v2, Code.Constant (Code.Int32 20l))
    ; Code.Assign (v1, v2)
    ]
  in
  let lua_stmts = Lua_generate.generate_instrs ctx instrs in
  List.iter (fun s -> print_endline (stat_to_string s)) lua_stmts;
  [%expect {|
    local v0 = 10
    local v1 = 20
    v0 = v1 |}]

(* Terminator tests *)

let%expect_test "generate last - return" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let last = Code.Return v in
  let lua_stmts = Lua_generate.generate_last ctx last in
  List.iter (fun s -> print_endline (stat_to_string s)) lua_stmts;
  [%expect {| return v0 |}]

let%expect_test "generate last - raise" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let last = Code.Raise (v, `Normal) in
  let lua_stmts = Lua_generate.generate_last ctx last in
  List.iter (fun s -> print_endline (stat_to_string s)) lua_stmts;
  [%expect {| error(v0) |}]

let%expect_test "generate last - stop" =
  let ctx = make_ctx () in
  let last = Code.Stop in
  let lua_stmts = Lua_generate.generate_last ctx last in
  List.iter (fun s -> print_endline (stat_to_string s)) lua_stmts;
  [%expect {| return nil |}]

(* Block tests *)

let%expect_test "generate block - simple" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let block =
    { Code.params = []
    ; body =
        [ Code.Let (v1, Code.Constant (Code.Int32 42l))
        ; Code.Let (v2, Code.Constant (Code.String "test"))
        ]
    ; branch = Code.Return v2
    }
  in
  let lua_stmts = Lua_generate.generate_block ctx block in
  List.iter (fun s -> print_endline (stat_to_string s)) lua_stmts;
  [%expect {|
    local v0 = 42
    local v1 = "test"
    return v1 |}]

let%expect_test "generate block - with assignment" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let block =
    { Code.params = []
    ; body =
        [ Code.Let (v1, Code.Constant (Code.Int32 100l))
        ; Code.Let (v2, Code.Constant (Code.Int32 200l))
        ; Code.Assign (v1, v2)
        ]
    ; branch = Code.Return v1
    }
  in
  let lua_stmts = Lua_generate.generate_block ctx block in
  List.iter (fun s -> print_endline (stat_to_string s)) lua_stmts;
  [%expect {|
    local v0 = 100
    local v1 = 200
    v0 = v1
    return v0 |}]

let%expect_test "generate block - with field operations" =
  let ctx = make_ctx () in
  let obj = var_of_int 1 in
  let val1 = var_of_int 2 in
  let val2 = var_of_int 3 in
  let result = var_of_int 4 in
  let block =
    { Code.params = []
    ; body =
        [ Code.Let (obj, Code.Block (0, [||], Code.NotArray, Code.Maybe_mutable))
        ; Code.Let (val1, Code.Constant (Code.Int32 10l))
        ; Code.Let (val2, Code.Constant (Code.Int32 20l))
        ; Code.Set_field (obj, 0, Code.Non_float, val1)
        ; Code.Set_field (obj, 1, Code.Non_float, val2)
        ; Code.Let (result, Code.Field (obj, 0, Code.Non_float))
        ]
    ; branch = Code.Return result
    }
  in
  let lua_stmts = Lua_generate.generate_block ctx block in
  List.iter (fun s -> print_endline (stat_to_string s)) lua_stmts;
  [%expect {|
    local v0 = {tag = 0}
    local v1 = 10
    local v2 = 20
    v0[1] = v1
    v0[2] = v2
    local v3 = v0[1]
    return v3 |}]

let%expect_test "generate block - empty body" =
  let ctx = make_ctx () in
  let v = var_of_int 1 in
  let _ = Lua_generate.var_name ctx v in
  let block =
    { Code.params = []; body = []; branch = Code.Stop }
  in
  let lua_stmts = Lua_generate.generate_block ctx block in
  List.iter (fun s -> print_endline (stat_to_string s)) lua_stmts;
  [%expect {| return nil |}]

(* Variable scoping tests *)

let%expect_test "variable scoping - shadowing" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  Code.Var.set_name v1 "x";
  Code.Var.set_name v2 "x";
  let name1 = Lua_generate.var_name ctx v1 in
  let name2 = Lua_generate.var_name ctx v2 in
  Printf.printf "First x: %s\n" name1;
  Printf.printf "Second x: %s\n" name2;
  Printf.printf "Names are unique: %b\n" (name1 <> name2);
  [%expect {|
    First x: x
    Second x: x1
    Names are unique: true |}]

let%expect_test "variable scoping - nested lets" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let v3 = var_of_int 3 in
  let instrs =
    [ Code.Let (v1, Code.Constant (Code.Int32 1l))
    ; Code.Let (v2, Code.Apply { f = v1; args = []; exact = true })
    ; Code.Let (v3, Code.Apply { f = v2; args = [ v1 ]; exact = true })
    ]
  in
  let lua_stmts = Lua_generate.generate_instrs ctx instrs in
  List.iter (fun s -> print_endline (stat_to_string s)) lua_stmts;
  [%expect {|
    local x = 1
    local x1 = x()
    local v0 = x1(x)
    |}]
