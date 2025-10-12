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
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0 ()
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
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0 ()
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
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0 ()
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

(* ========================================================================= *)
(* Task 0.3: Assignment Generation Tests                                    *)
(* ========================================================================= *)

(* Test that Code.Let generates assignments instead of local declarations *)
let%expect_test "let_generates_assignment" =
  let open Code in
  let v1 = Var.fresh () in
  let ctx = Lua_of_ocaml_compiler__Lua_generate.make_context ~debug:false in
  (* Generate instruction for Let *)
  let stmt =
    Lua_of_ocaml_compiler__Lua_generate.generate_instr
      ctx
      (Let (v1, Constant (Int32 42l)))
  in
  (* Verify it's an assignment, not a local declaration *)
  (match stmt with
  | Lua_of_ocaml_compiler__Lua_ast.Assign
      ([ Lua_of_ocaml_compiler__Lua_ast.Ident name ], [ _expr ]) ->
      Printf.printf "Generated assignment for %s\n" name
  | Lua_of_ocaml_compiler__Lua_ast.Local _ ->
      Printf.printf "ERROR: Generated local declaration instead of assignment\n"
  | _ -> Printf.printf "ERROR: Unexpected statement type\n");
  [%expect {| Generated assignment for v0 |}]

(* Test that multiple Let instructions generate multiple assignments *)
let%expect_test "multiple_lets_generate_assignments" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  let v3 = Var.fresh () in
  let ctx = Lua_of_ocaml_compiler__Lua_generate.make_context ~debug:false in
  (* Generate instructions *)
  let instrs =
    [ Let (v1, Constant (Int32 1l))
    ; Let (v2, Constant (Int32 2l))
    ; Let (v3, Constant (Int32 3l))
    ]
  in
  let stmts =
    Lua_of_ocaml_compiler__Lua_generate.generate_instrs ctx instrs
  in
  (* Verify all are assignments *)
  Printf.printf "Generated %d statements\n" (List.length stmts);
  List.iter
    ~f:(fun stmt ->
      match stmt with
      | Lua_of_ocaml_compiler__Lua_ast.Assign
          ([ Lua_of_ocaml_compiler__Lua_ast.Ident name ], _) ->
          Printf.printf "Assignment: %s\n" name
      | _ -> Printf.printf "ERROR: Not an assignment\n")
    stmts;
  [%expect
    {|
    Generated 3 statements
    Assignment: v0
    Assignment: v1
    Assignment: v2 |}]

(* Test that assignments work correctly in compiled blocks *)
let%expect_test "assignments_in_compiled_blocks" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  (* Block 0: two assignments *)
  let block0 =
    { params = []
    ; body = [ Let (v1, Constant (Int32 42l)); Let (v2, Constant (Int32 100l)) ]
    ; branch = Return v1
    }
  in
  let blocks = Addr.Map.empty |> Addr.Map.add 0 block0 in
  let program = { start = 0; blocks; free_pc = 1 } in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let stmts =
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0 ()
  in
  (* Count assignments in block (skip hoisting statements) *)
  let rec count_assignments = function
    | [] -> 0
    | Lua_of_ocaml_compiler__Lua_ast.Comment _ :: rest -> count_assignments rest
    | Lua_of_ocaml_compiler__Lua_ast.Local _ :: rest -> count_assignments rest
    | Lua_of_ocaml_compiler__Lua_ast.Label _ :: rest -> count_assignments rest
    | Lua_of_ocaml_compiler__Lua_ast.Assign _ :: rest -> 1 + count_assignments rest
    | _ :: rest -> count_assignments rest
  in
  Printf.printf "Total assignments in block: %d\n" (count_assignments stmts);
  (* Verify no local declarations in block body (only at start) *)
  let rec has_local_in_body in_body = function
    | [] -> false
    | Lua_of_ocaml_compiler__Lua_ast.Local _ :: rest ->
        if in_body
        then (
          Printf.printf "ERROR: Found local declaration in block body\n";
          true)
        else has_local_in_body false rest
    | Lua_of_ocaml_compiler__Lua_ast.Label _ :: rest ->
        has_local_in_body true rest
    | _ :: rest -> has_local_in_body in_body rest
  in
  let has_error = has_local_in_body false stmts in
  if not has_error then Printf.printf "No local declarations in block body\n";
  [%expect
    {|
    Total assignments in block: 2
    No local declarations in block body |}]

(* ========================================================================= *)
(* Task 0.4: Fall-Through Optimization Tests                                *)
(* ========================================================================= *)

(* Test that sequential blocks fall through without goto *)
let%expect_test "fall_through_sequential_blocks" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  (* Block 0: branches to block 1 (addr + 1) *)
  let block0 =
    { params = []
    ; body = [ Let (v1, Constant (Int32 42l)) ]
    ; branch = Branch (1, [])
    }
  in
  (* Block 1: returns *)
  let block1 =
    { params = []; body = [ Let (v2, Constant (Int32 100l)) ]; branch = Return v2 }
  in
  let blocks = Addr.Map.empty |> Addr.Map.add 0 block0 |> Addr.Map.add 1 block1 in
  let program = { start = 0; blocks; free_pc = 2 } in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let stmts =
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0 ()
  in
  (* Count gotos - should be 0 for fall-through *)
  let rec count_gotos = function
    | [] -> 0
    | Lua_of_ocaml_compiler__Lua_ast.Goto _ :: rest -> 1 + count_gotos rest
    | _ :: rest -> count_gotos rest
  in
  Printf.printf "Total gotos: %d\n" (count_gotos stmts);
  (* Check that block 0 doesn't have a goto *)
  let has_block_0_goto =
    List.exists
      ~f:(function
        | Lua_of_ocaml_compiler__Lua_ast.Goto "block_1" -> true
        | _ -> false)
      stmts
  in
  Printf.printf "Has goto to block_1: %b\n" has_block_0_goto;
  [%expect {|
    Total gotos: 0
    Has goto to block_1: false |}]

(* Test that non-sequential blocks still use goto *)
let%expect_test "no_fall_through_non_sequential" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  (* Block 0: branches to block 2 (not addr + 1) *)
  let block0 =
    { params = []
    ; body = [ Let (v1, Constant (Int32 42l)) ]
    ; branch = Branch (2, [])
    }
  in
  (* Block 2: returns *)
  let block2 =
    { params = []; body = [ Let (v2, Constant (Int32 100l)) ]; branch = Return v2 }
  in
  let blocks = Addr.Map.empty |> Addr.Map.add 0 block0 |> Addr.Map.add 2 block2 in
  let program = { start = 0; blocks; free_pc = 3 } in
  let ctx =
    Lua_of_ocaml_compiler__Lua_generate.make_context_with_program
      ~debug:false
      program
  in
  let stmts =
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0 ()
  in
  (* Count gotos - should have 1 for non-sequential *)
  let rec count_gotos = function
    | [] -> 0
    | Lua_of_ocaml_compiler__Lua_ast.Goto _ :: rest -> 1 + count_gotos rest
    | _ :: rest -> count_gotos rest
  in
  Printf.printf "Total gotos: %d\n" (count_gotos stmts);
  (* Check that block 0 has a goto *)
  let has_block_2_goto =
    List.exists
      ~f:(function
        | Lua_of_ocaml_compiler__Lua_ast.Goto "block_2" -> true
        | _ -> false)
      stmts
  in
  Printf.printf "Has goto to block_2: %b\n" has_block_2_goto;
  [%expect {|
    Total gotos: 1
    Has goto to block_2: true |}]

(* Test fall-through with multiple sequential blocks *)
let%expect_test "fall_through_multiple_sequential" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  let v3 = Var.fresh () in
  (* Block 0: branches to 1 *)
  let block0 =
    { params = []
    ; body = [ Let (v1, Constant (Int32 1l)) ]
    ; branch = Branch (1, [])
    }
  in
  (* Block 1: branches to 2 *)
  let block1 =
    { params = []
    ; body = [ Let (v2, Constant (Int32 2l)) ]
    ; branch = Branch (2, [])
    }
  in
  (* Block 2: returns *)
  let block2 =
    { params = []; body = [ Let (v3, Constant (Int32 3l)) ]; branch = Return v3 }
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
  let stmts =
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0 ()
  in
  (* All three blocks are sequential, so no gotos *)
  let rec count_gotos = function
    | [] -> 0
    | Lua_of_ocaml_compiler__Lua_ast.Goto _ :: rest -> 1 + count_gotos rest
    | _ :: rest -> count_gotos rest
  in
  Printf.printf "Total gotos: %d\n" (count_gotos stmts);
  [%expect {| Total gotos: 0 |}]

(* Test that conditional branches still generate gotos *)
let%expect_test "conditional_still_has_gotos" =
  let open Code in
  let v1 = Var.fresh () in
  let v2 = Var.fresh () in
  (* Block 0: conditional branch *)
  let block0 =
    { params = []
    ; body = [ Let (v1, Constant (Int32 1l)) ]
    ; branch = Cond (v1, (1, []), (2, []))
    }
  in
  (* Block 1: returns *)
  let block1 =
    { params = []; body = [ Let (v2, Constant (Int32 10l)) ]; branch = Return v2 }
  in
  (* Block 2: returns *)
  let block2 =
    { params = []; body = [ Let (v2, Constant (Int32 20l)) ]; branch = Return v2 }
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
  let stmts =
    Lua_of_ocaml_compiler__Lua_generate.compile_blocks_with_labels ctx program 0 ()
  in
  (* Conditional should generate 2 gotos (true and false branches) *)
  let rec count_gotos_in_stmt = function
    | Lua_of_ocaml_compiler__Lua_ast.Goto _ -> 1
    | Lua_of_ocaml_compiler__Lua_ast.If (_, then_stmts, Some else_stmts) ->
        count_gotos_in_stmts then_stmts + count_gotos_in_stmts else_stmts
    | Lua_of_ocaml_compiler__Lua_ast.If (_, then_stmts, None) ->
        count_gotos_in_stmts then_stmts
    | _ -> 0
  and count_gotos_in_stmts stmts = List.fold_left ~f:(fun acc s -> acc + count_gotos_in_stmt s) ~init:0 stmts
  in
  Printf.printf "Total gotos: %d\n" (count_gotos_in_stmts stmts);
  [%expect {| Total gotos: 2 |}]
