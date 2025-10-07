(* Tests for Lua conditional and pattern matching generation *)

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

let make_addr i = i

(* Helper to create a simple program with blocks *)
let make_program blocks_list =
  let blocks =
    List.fold_left
      (fun acc (addr, block) -> Code.Addr.Map.add addr block acc)
      Code.Addr.Map.empty
      blocks_list
  in
  { Code.start = Code.Addr.zero
  ; Code.blocks = blocks
  ; Code.free_pc = List.length blocks_list
  }

(* Simple conditional tests *)

let%expect_test "generate cond - if-then-else inline" =
  let ctx = make_ctx () in
  let cond_var = var_of_int 1 in
  let result_var = var_of_int 2 in
  (* Create true and false blocks *)
  let true_block =
    { Code.params = []
    ; body = [ Code.Let (result_var, Code.Constant (Code.Int32 1l)) ]
    ; branch = Code.Return result_var
    }
  in
  let false_block =
    { Code.params = []
    ; body = [ Code.Let (result_var, Code.Constant (Code.Int32 0l)) ]
    ; branch = Code.Return result_var
    }
  in
  let addr_true = make_addr 1 in
  let addr_false = make_addr 2 in
  let program = make_program [ (addr_true, true_block); (addr_false, false_block) ] in
  let last = Code.Cond (cond_var, (addr_true, []), (addr_false, [])) in
  let stmts = Lua_generate.generate_last_with_program ctx program last in
  List.iter (fun s -> print_endline (stat_to_string s)) stmts;
  [%expect {|
    if v0 then
      local v1 = 1
      return v1
    else
      local v1 = 0
      return v1
    end |}]

let%expect_test "generate cond - if-then only" =
  let ctx = make_ctx () in
  let cond_var = var_of_int 1 in
  let action_var = var_of_int 2 in
  (* Create true block only *)
  let true_block =
    { Code.params = []
    ; body = [ Code.Let (action_var, Code.Constant (Code.String "done")) ]
    ; branch = Code.Stop
    }
  in
  let addr_true = make_addr 1 in
  let addr_false = make_addr 999 in (* Non-existent block *)
  let program = make_program [ (addr_true, true_block) ] in
  let last = Code.Cond (cond_var, (addr_true, []), (addr_false, [])) in
  let stmts = Lua_generate.generate_last_with_program ctx program last in
  List.iter (fun s -> print_endline (stat_to_string s)) stmts;
  [%expect {|
    if v0 then
      local v1 = "done"
      return nil
    end |}]

let%expect_test "generate cond - nested conditionals" =
  let ctx = make_ctx () in
  let outer_cond = var_of_int 1 in
  let inner_cond = var_of_int 2 in
  let result = var_of_int 3 in
  (* Inner true block *)
  let inner_true_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 1l)) ]
    ; branch = Code.Return result
    }
  in
  (* Inner false block *)
  let inner_false_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 2l)) ]
    ; branch = Code.Return result
    }
  in
  let addr_inner_true = make_addr 10 in
  let addr_inner_false = make_addr 11 in
  (* Outer true block contains inner conditional *)
  let outer_true_block =
    { Code.params = []
    ; body = []
    ; branch = Code.Cond (inner_cond, (addr_inner_true, []), (addr_inner_false, []))
    }
  in
  (* Outer false block *)
  let outer_false_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 0l)) ]
    ; branch = Code.Return result
    }
  in
  let addr_outer_true = make_addr 1 in
  let addr_outer_false = make_addr 2 in
  let program =
    make_program
      [ (addr_outer_true, outer_true_block)
      ; (addr_outer_false, outer_false_block)
      ; (addr_inner_true, inner_true_block)
      ; (addr_inner_false, inner_false_block)
      ]
  in
  let last = Code.Cond (outer_cond, (addr_outer_true, []), (addr_outer_false, [])) in
  let stmts = Lua_generate.generate_last_with_program ctx program last in
  List.iter (fun s -> print_endline (stat_to_string s)) stmts;
  [%expect {|
    if v0 then
      if v1 then
        local v2 = 1
        return v2
      else
        local v2 = 2
        return v2
      end
    else
      local v2 = 0
      return v2
    end |}]

(* Switch/pattern matching tests *)

let%expect_test "generate switch - simple 2-way" =
  let ctx = make_ctx () in
  let switch_var = var_of_int 1 in
  let result = var_of_int 2 in
  (* Case 0 *)
  let case0_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.String "zero")) ]
    ; branch = Code.Return result
    }
  in
  (* Case 1 *)
  let case1_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.String "one")) ]
    ; branch = Code.Return result
    }
  in
  let addr0 = make_addr 10 in
  let addr1 = make_addr 11 in
  let program = make_program [ (addr0, case0_block); (addr1, case1_block) ] in
  let conts = [| (addr0, []); (addr1, []) |] in
  let last = Code.Switch (switch_var, conts) in
  let stmts = Lua_generate.generate_last_with_program ctx program last in
  List.iter (fun s -> print_endline (stat_to_string s)) stmts;
  [%expect {|
    if (type(v0) == "table" and v0.tag or v0) == 0 then
      local v1 = "zero"
      return v1
    else
      local v1 = "one"
      return v1
    end
    |}]

let%expect_test "generate switch - 3-way with default" =
  let ctx = make_ctx () in
  let switch_var = var_of_int 1 in
  let result = var_of_int 2 in
  (* Case 0 *)
  let case0_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.String "case0")) ]
    ; branch = Code.Return result
    }
  in
  (* Case 1 *)
  let case1_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.String "case1")) ]
    ; branch = Code.Return result
    }
  in
  (* Default case *)
  let default_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.String "default")) ]
    ; branch = Code.Return result
    }
  in
  let addr0 = make_addr 10 in
  let addr1 = make_addr 11 in
  let addr_default = make_addr 12 in
  let program =
    make_program
      [ (addr0, case0_block); (addr1, case1_block); (addr_default, default_block) ]
  in
  let conts = [| (addr0, []); (addr1, []); (addr_default, []) |] in
  let last = Code.Switch (switch_var, conts) in
  let stmts = Lua_generate.generate_last_with_program ctx program last in
  List.iter (fun s -> print_endline (stat_to_string s)) stmts;
  [%expect {|
    if (type(v0) == "table" and v0.tag or v0) == 0 then
      local v1 = "case0"
      return v1
    else
      if (type(v0) == "table" and v0.tag or v0) == 1 then
        local v1 = "case1"
        return v1
      else
        local v1 = "default"
        return v1
      end
    end
    |}]

let%expect_test "generate switch - single case" =
  let ctx = make_ctx () in
  let switch_var = var_of_int 1 in
  let result = var_of_int 2 in
  let case_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.String "only")) ]
    ; branch = Code.Return result
    }
  in
  let addr = make_addr 10 in
  let program = make_program [ (addr, case_block) ] in
  let conts = [| (addr, []) |] in
  let last = Code.Switch (switch_var, conts) in
  let stmts = Lua_generate.generate_last_with_program ctx program last in
  List.iter (fun s -> print_endline (stat_to_string s)) stmts;
  [%expect {|
    if (type(v0) == "table" and v0.tag or v0) == 0 then
      local v1 = "only"
      return v1
    end
    |}]

(* Branch tests *)

let%expect_test "generate branch - goto" =
  let ctx = make_ctx () in
  let addr = make_addr 42 in
  let last = Code.Branch (addr, []) in
  let program = make_program [] in
  let stmts = Lua_generate.generate_last_with_program ctx program last in
  List.iter (fun s -> print_endline (stat_to_string s)) stmts;
  [%expect {| goto block_42 |}]

(* Block with program context *)

let%expect_test "generate block with cond" =
  let ctx = make_ctx () in
  let v1 = var_of_int 1 in
  let cond_var = var_of_int 2 in
  let result = var_of_int 3 in
  (* Setup blocks for conditional *)
  let true_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 100l)) ]
    ; branch = Code.Return result
    }
  in
  let false_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 200l)) ]
    ; branch = Code.Return result
    }
  in
  let addr_true = make_addr 10 in
  let addr_false = make_addr 11 in
  (* Main block *)
  let main_block =
    { Code.params = []
    ; body =
        [ Code.Let (v1, Code.Constant (Code.Int32 1l))
        ; Code.Let (cond_var, Code.Prim (Code.IsInt, [ Code.Pv v1 ]))
        ]
    ; branch = Code.Cond (cond_var, (addr_true, []), (addr_false, []))
    }
  in
  let program =
    make_program [ (addr_true, true_block); (addr_false, false_block) ]
  in
  let stmts = Lua_generate.generate_block_with_program ctx program main_block in
  List.iter (fun s -> print_endline (stat_to_string s)) stmts;
  [%expect {|
    local v0 = 1
    local v1 = type(v0) == "number" and v0 % 1 == 0
    if v1 then
      local v2 = 100
      return v2
    else
      local v2 = 200
      return v2
    end |}]

(* Exhaustiveness - all paths return *)

let%expect_test "match exhaustiveness - all branches return" =
  let ctx = make_ctx () in
  let tag_var = var_of_int 1 in
  let result = var_of_int 2 in
  (* Each case returns *)
  let case0 =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.String "A")) ]
    ; branch = Code.Return result
    }
  in
  let case1 =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.String "B")) ]
    ; branch = Code.Return result
    }
  in
  let case2 =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.String "C")) ]
    ; branch = Code.Return result
    }
  in
  let addr0 = make_addr 1 in
  let addr1 = make_addr 2 in
  let addr2 = make_addr 3 in
  let program = make_program [ (addr0, case0); (addr1, case1); (addr2, case2) ] in
  let conts = [| (addr0, []); (addr1, []); (addr2, []) |] in
  let last = Code.Switch (tag_var, conts) in
  let stmts = Lua_generate.generate_last_with_program ctx program last in
  (* Check all paths have returns *)
  let has_return stmt =
    match stmt with
    | Lua_ast.If (_, then_branch, Some else_branch) ->
        let rec check_return stmts =
          List.exists
            (fun s ->
              match s with
              | Lua_ast.Return _ -> true
              | Lua_ast.If (_, tb, Some eb) -> check_return tb && check_return eb
              | Lua_ast.If (_, tb, None) -> check_return tb
              | _ -> false)
            stmts
        in
        check_return then_branch && check_return else_branch
    | _ -> false
  in
  let exhaustive = List.for_all has_return stmts in
  Printf.printf "All branches return: %b\n" exhaustive;
  [%expect {| All branches return: true |}]
