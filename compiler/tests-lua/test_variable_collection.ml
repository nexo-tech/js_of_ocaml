(* Test variable collection for Task 0.1 *)

open Js_of_ocaml_compiler
open Stdlib

(* Create a simple test program with multiple blocks and variables *)
let create_test_program () =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  let v3 = Var.fresh () in
  let v4 = Var.fresh () in
  (* Block 0: entry *)
  let block0 =
    { params = []
    ; body =
        [ Let (v1, Constant (Int32 42l)); Let (v2, Constant (Int32 100l)) ]
    ; branch = Cond (v1, (1, []), (2, []))
    }
  in
  (* Block 1: true branch *)
  let block1 =
    { params = []; body = [ Let (v3, Constant (Int32 1l)) ]; branch = Return v3 }
  in
  (* Block 2: false branch *)
  let block2 =
    { params = []; body = [ Let (v4, Constant (Int32 0l)) ]; branch = Return v4 }
  in
  let blocks =
    Addr.Map.empty
    |> Addr.Map.add 0 block0
    |> Addr.Map.add 1 block1
    |> Addr.Map.add 2 block2
  in
  { start = 0; blocks; free_pc = 3 }

(* Test: Collect variables from simple program *)
let%expect_test "collect_block_variables_simple" =
  let program = create_test_program () in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let vars =
    Lua_of_ocaml_compiler__Lua_generate.collect_block_variables ctx program 0
  in
  Printf.printf "Collected %d variables\n" (StringSet.cardinal vars);
  (* Print variables in sorted order *)
  let sorted_vars = vars |> StringSet.elements |> List.sort ~cmp:String.compare in
  List.iter ~f:(fun v -> Printf.printf "  %s\n" v) sorted_vars;
  [%expect {|
    Collected 4 variables
      v0
      v1
      v2
      v3
    |}]

(* Test: Empty program *)
let%expect_test "collect_block_variables_empty" =
  let program = Code.{ start = 0; blocks = Addr.Map.empty; free_pc = 1 } in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let vars =
    Lua_of_ocaml_compiler__Lua_generate.collect_block_variables ctx program 0
  in
  Printf.printf "Collected %d variables\n" (StringSet.cardinal vars);
  [%expect {| Collected 0 variables |}]

(* Test: Block with assignments *)
let%expect_test "collect_block_variables_assignments" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  let block0 =
    { params = []
    ; body =
        [ Let (v1, Constant (Int32 1l))
        ; Let (v2, Constant (Int32 2l))
        ; Assign (v1, v2)
        ]
    ; branch = Stop
    }
  in
  let program =
    { start = 0; blocks = Addr.Map.singleton 0 block0; free_pc = 1 }
  in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let vars =
    Lua_of_ocaml_compiler__Lua_generate.collect_block_variables ctx program 0
  in
  Printf.printf "Collected %d variables\n" (StringSet.cardinal vars);
  let sorted_vars = vars |> StringSet.elements |> List.sort ~cmp:String.compare in
  List.iter ~f:(fun v -> Printf.printf "  %s\n" v) sorted_vars;
  [%expect {|
    Collected 2 variables
      v0
      v1
    |}]

(* Test: Unreachable blocks are not collected *)
let%expect_test "collect_block_variables_unreachable" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  let v3 = Var.fresh () in
  (* Block 0: returns immediately *)
  let block0 =
    { params = []; body = [ Let (v1, Constant (Int32 42l)) ]; branch = Return v1 }
  in
  (* Block 1: unreachable *)
  let block1 =
    { params = []; body = [ Let (v2, Constant (Int32 100l)) ]; branch = Stop }
  in
  (* Block 2: also unreachable *)
  let block2 =
    { params = []; body = [ Let (v3, Constant (Int32 200l)) ]; branch = Stop }
  in
  let blocks =
    Addr.Map.empty
    |> Addr.Map.add 0 block0
    |> Addr.Map.add 1 block1
    |> Addr.Map.add 2 block2
  in
  let program = { start = 0; blocks; free_pc = 3 } in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let vars =
    Lua_of_ocaml_compiler__Lua_generate.collect_block_variables ctx program 0
  in
  Printf.printf "Collected %d variables (only from block 0)\n"
    (StringSet.cardinal vars);
  let sorted_vars = vars |> StringSet.elements in
  List.iter ~f:(fun v -> Printf.printf "  %s\n" v) sorted_vars;
  [%expect {|
    Collected 1 variables (only from block 0)
      v0
    |}]

(* Test: Switch statement with multiple branches *)
let%expect_test "collect_block_variables_switch" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  let v3 = Var.fresh () in
  let v4 = Var.fresh () in
  (* Block 0: switch *)
  let block0 =
    { params = []
    ; body = [ Let (v1, Constant (Int32 0l)) ]
    ; branch = Switch (v1, [| (1, []); (2, []); (3, []) |])
    }
  in
  (* Blocks 1, 2, 3: cases *)
  let block1 =
    { params = []; body = [ Let (v2, Constant (Int32 1l)) ]; branch = Stop }
  in
  let block2 =
    { params = []; body = [ Let (v3, Constant (Int32 2l)) ]; branch = Stop }
  in
  let block3 =
    { params = []; body = [ Let (v4, Constant (Int32 3l)) ]; branch = Stop }
  in
  let blocks =
    Addr.Map.empty
    |> Addr.Map.add 0 block0
    |> Addr.Map.add 1 block1
    |> Addr.Map.add 2 block2
    |> Addr.Map.add 3 block3
  in
  let program = { start = 0; blocks; free_pc = 4 } in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let vars =
    Lua_of_ocaml_compiler__Lua_generate.collect_block_variables ctx program 0
  in
  Printf.printf "Collected %d variables (from all switch branches)\n"
    (StringSet.cardinal vars);
  let sorted_vars = vars |> StringSet.elements |> List.sort ~cmp:String.compare in
  List.iter ~f:(fun v -> Printf.printf "  %s\n" v) sorted_vars;
  [%expect {|
    Collected 4 variables (from all switch branches)
      v0
      v1
      v2
      v3
    |}]

(* Test: Variable hoisting in compiled output *)
let%expect_test "variable_hoisting_simple" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  let v3 = Var.fresh () in
  (* Block 0: entry with variable definitions *)
  let block0 =
    { params = []
    ; body = [ Let (v1, Constant (Int32 42l)); Let (v2, Constant (Int32 100l)) ]
    ; branch = Cond (v1, (1, []), (2, []))
    }
  in
  (* Block 1: true branch *)
  let block1 =
    { params = []; body = [ Let (v3, Constant (Int32 1l)) ]; branch = Return v3 }
  in
  (* Block 2: false branch *)
  let block2 = { params = []; body = []; branch = Return v2 } in
  let blocks =
    Addr.Map.empty
    |> Addr.Map.add 0 block0
    |> Addr.Map.add 1 block1
    |> Addr.Map.add 2 block2
  in
  let program = { start = 0; blocks; free_pc = 3 } in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let stmts =
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0
  in
  (* Check that first statement is a comment about hoisted variables *)
  (match stmts with
  | Lua_of_ocaml_compiler__Lua_ast.Comment msg :: _ ->
      Printf.printf "Found: %s\n" msg
  | _ -> Printf.printf "No comment found\n");
  (* Check that second statement is a local declaration *)
  (match stmts with
  | _ :: Lua_of_ocaml_compiler__Lua_ast.Local (vars, None) :: _ ->
      Printf.printf "Hoisted %d variables\n" (List.length vars);
      List.iter ~f:(fun v -> Printf.printf "  %s\n" v) vars
  | _ -> Printf.printf "No local declaration found\n");
  [%expect
    {|
    Found: Hoisted variables (3 total)
    Hoisted 3 variables
      v0
      v1
      v2 |}]

(* Test: No hoisting for empty program *)
let%expect_test "variable_hoisting_empty" =
  let program = Code.{ start = 0; blocks = Addr.Map.empty; free_pc = 1 } in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let stmts =
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0
  in
  Printf.printf "Statement count: %d\n" (List.length stmts);
  [%expect {| Statement count: 0 |}]

(* Test: Hoisting with multiple blocks and variables *)
let%expect_test "variable_hoisting_complex" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  let v3 = Var.fresh () in
  let v4 = Var.fresh () in
  (* Block 0: switch *)
  let block0 =
    { params = []
    ; body = [ Let (v1, Constant (Int32 0l)) ]
    ; branch = Switch (v1, [| (1, []); (2, []); (3, []) |])
    }
  in
  (* Blocks 1, 2, 3: cases *)
  let block1 =
    { params = []; body = [ Let (v2, Constant (Int32 1l)) ]; branch = Stop }
  in
  let block2 =
    { params = []; body = [ Let (v3, Constant (Int32 2l)) ]; branch = Stop }
  in
  let block3 =
    { params = []; body = [ Let (v4, Constant (Int32 3l)) ]; branch = Stop }
  in
  let blocks =
    Addr.Map.empty
    |> Addr.Map.add 0 block0
    |> Addr.Map.add 1 block1
    |> Addr.Map.add 2 block2
    |> Addr.Map.add 3 block3
  in
  let program = { start = 0; blocks; free_pc = 4 } in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let stmts =
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0
  in
  (* Check hoisted variables *)
  (match stmts with
  | Lua_of_ocaml_compiler__Lua_ast.Comment msg
    :: Lua_of_ocaml_compiler__Lua_ast.Local (vars, None) :: _ ->
      Printf.printf "%s\n" msg;
      Printf.printf "Variables: %s\n" (String.concat ~sep:", " vars)
  | _ -> Printf.printf "Unexpected structure\n");
  [%expect
    {|
    Hoisted variables (4 total)
    Variables: v0, v1, v2, v3 |}]
