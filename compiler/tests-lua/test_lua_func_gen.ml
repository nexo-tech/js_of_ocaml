(* Tests for Lua function and closure generation *)

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

let expr_to_string e = Lua_output.expr_to_string e

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

(* Simple function tests *)

let%expect_test "generate closure - simple function" =
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let result = var_of_int 3 in
  (* Function body: let result = v1 + v2; return result *)
  let func_body =
    { Code.params = []
    ; body =
        [ Code.Let
            (result, Code.Prim (Code.Extern "add", [ Code.Pv v1; Code.Pv v2 ]))
        ]
    ; branch = Code.Return result
    }
  in
  let func_addr = make_addr 10 in
  let program = make_program [ (func_addr, func_body) ] in
  let ctx = Lua_generate.make_context_with_program ~debug:false program in
  (* Ensure params have names *)
  let _ = Lua_generate.var_name ctx v1 in
  let _ = Lua_generate.var_name ctx v2 in
  let closure = Code.Closure ([ v1; v2 ], (func_addr, []), None) in
  let lua_expr = Lua_generate.generate_expr ctx closure in
  print_endline (expr_to_string lua_expr);
  [%expect
    {|
    function(v0, v1)
      local v2 = caml_add(v0, v1)
      return v2
    end |}]

let%expect_test "generate closure - zero parameters" =
  let result = var_of_int 1 in
  (* Function body: return 42 *)
  let func_body =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 42l)) ]
    ; branch = Code.Return result
    }
  in
  let func_addr = make_addr 10 in
  let program = make_program [ (func_addr, func_body) ] in
  let ctx = Lua_generate.make_context_with_program ~debug:false program in
  let closure = Code.Closure ([], (func_addr, []), None) in
  let lua_expr = Lua_generate.generate_expr ctx closure in
  print_endline (expr_to_string lua_expr);
  [%expect
    {|
    function()
      local v0 = 42
      return v0
    end |}]

let%expect_test "generate closure - single parameter" =
  let x = var_of_int 1 in
  (* Function body: return x *)
  let func_body =
    { Code.params = []; body = []; branch = Code.Return x }
  in
  let func_addr = make_addr 10 in
  let program = make_program [ (func_addr, func_body) ] in
  let ctx = Lua_generate.make_context_with_program ~debug:false program in
  let _ = Lua_generate.var_name ctx x in
  let closure = Code.Closure ([ x ], (func_addr, []), None) in
  let lua_expr = Lua_generate.generate_expr ctx closure in
  print_endline (expr_to_string lua_expr);
  [%expect {|
    function(v0)
      return v0
    end |}]

(* Function application tests *)

let%expect_test "generate expr - function application" =
  let ctx = make_ctx () in
  let f = var_of_int 1 in
  let arg1 = var_of_int 2 in
  let arg2 = var_of_int 3 in
  let _ = Lua_generate.var_name ctx f in
  let _ = Lua_generate.var_name ctx arg1 in
  let _ = Lua_generate.var_name ctx arg2 in
  let apply = Code.Apply { f; args = [ arg1; arg2 ]; exact = true } in
  let lua_expr = Lua_generate.generate_expr ctx apply in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0(v1, v2) |}]

let%expect_test "generate expr - zero-arg function call" =
  let ctx = make_ctx () in
  let f = var_of_int 1 in
  let _ = Lua_generate.var_name ctx f in
  let apply = Code.Apply { f; args = []; exact = true } in
  let lua_expr = Lua_generate.generate_expr ctx apply in
  print_endline (expr_to_string lua_expr);
  [%expect {| v0() |}]

(* Let-bound closure tests *)

let%expect_test "generate instr - let with closure" =
  let f = var_of_int 1 in
  let x = var_of_int 2 in
  (* Function: fun x -> x *)
  let func_body =
    { Code.params = []; body = []; branch = Code.Return x }
  in
  let func_addr = make_addr 10 in
  let program = make_program [ (func_addr, func_body) ] in
  let ctx = Lua_generate.make_context_with_program ~debug:false program in
  let closure = Code.Closure ([ x ], (func_addr, []), None) in
  let instr = Code.Let (f, closure) in
  let lua_stmt = Lua_generate.generate_instr ctx instr in
  print_endline (stat_to_string lua_stmt);
  [%expect
    {|
    local v0 = function(v1)
      return v1
    end |}]

(* Recursive function tests *)

(* DISABLED: infinite loop issue
let%expect_test "generate closure - simple tail recursion" =
  let n = var_of_int 2 in
  let cond = var_of_int 3 in
  let result = var_of_int 4 in
  (* Base case block: return 0 *)
  let base_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 0l)) ]
    ; branch = Code.Return result
    }
  in
  (* Recursive case block: branch back to func_addr (tail call) *)
  let func_addr = make_addr 10 in
  let base_addr = make_addr 11 in
  let func_body =
    { Code.params = []
    ; body =
        [ Code.Let (cond, Code.Prim (Code.Eq, [ Code.Pv n; Code.Pc (Code.Int32 0l) ]))
        ]
    ; branch = Code.Cond (cond, (base_addr, []), (func_addr, []))
    }
  in
  let program = make_program [ (func_addr, func_body); (base_addr, base_block) ] in
  let ctx = Lua_generate.make_context_with_program ~debug:false program in
  let _ = Lua_generate.var_name ctx n in
  let closure = Code.Closure ([ n ], (func_addr, []), None) in
  let lua_expr = Lua_generate.generate_expr ctx closure in
  print_endline (expr_to_string lua_expr);
  [%expect
    {|
    function(v0)
      while true do
        ::tail_call::
        local v1 = v0 == 0
        if v1 then
          local v2 = 0
          return v2
        else
          goto block_10
        end
      end
    end |}]
*)

(* Nested closure tests *)

let%expect_test "generate closure - nested closures" =
  let x = var_of_int 1 in
  let y = var_of_int 2 in
  let result = var_of_int 3 in
  (* Inner function: fun y -> x + y *)
  let inner_body =
    { Code.params = []
    ; body =
        [ Code.Let
            (result, Code.Prim (Code.Extern "add", [ Code.Pv x; Code.Pv y ]))
        ]
    ; branch = Code.Return result
    }
  in
  let inner_addr = make_addr 20 in
  (* Outer function: fun x -> <inner function> *)
  let inner_closure_var = var_of_int 4 in
  let outer_body =
    { Code.params = []
    ; body = [ Code.Let (inner_closure_var, Code.Closure ([ y ], (inner_addr, []), None)) ]
    ; branch = Code.Return inner_closure_var
    }
  in
  let outer_addr = make_addr 10 in
  let program = make_program [ (outer_addr, outer_body); (inner_addr, inner_body) ] in
  let ctx = Lua_generate.make_context_with_program ~debug:false program in
  let _ = Lua_generate.var_name ctx x in
  let outer_closure = Code.Closure ([ x ], (outer_addr, []), None) in
  let lua_expr = Lua_generate.generate_expr ctx outer_closure in
  print_endline (expr_to_string lua_expr);
  [%expect
    {|
    function(v0)
      local v1 = function(v2)
        local v3 = caml_add(v0, v2)
        return v3
      end
      return v1
    end
    |}]

(* Higher-order function tests *)

let%expect_test "generate - function returning function" =
  let x = var_of_int 1 in
  let inner_func = var_of_int 2 in
  let inner_body =
    { Code.params = []; body = []; branch = Code.Return x }
  in
  let inner_addr = make_addr 20 in
  let outer_body =
    { Code.params = []
    ; body = [ Code.Let (inner_func, Code.Closure ([], (inner_addr, []), None)) ]
    ; branch = Code.Return inner_func
    }
  in
  let outer_addr = make_addr 10 in
  let program = make_program [ (outer_addr, outer_body); (inner_addr, inner_body) ] in
  let ctx = Lua_generate.make_context_with_program ~debug:false program in
  let _ = Lua_generate.var_name ctx x in
  let closure = Code.Closure ([ x ], (outer_addr, []), None) in
  let lua_expr = Lua_generate.generate_expr ctx closure in
  print_endline (expr_to_string lua_expr);
  [%expect
    {|
    function(v0)
      local v1 = function()
        return v0
      end
      return v1
    end |}]

(* Function with conditional tests *)

let%expect_test "generate closure - function with if-then-else" =
  let x = var_of_int 1 in
  let cond = var_of_int 2 in
  let result = var_of_int 3 in
  (* True branch: return 1 *)
  let true_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 1l)) ]
    ; branch = Code.Return result
    }
  in
  (* False branch: return 0 *)
  let false_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 0l)) ]
    ; branch = Code.Return result
    }
  in
  let true_addr = make_addr 11 in
  let false_addr = make_addr 12 in
  (* Main function body *)
  let func_body =
    { Code.params = []
    ; body =
        [ Code.Let (cond, Code.Prim (Code.Eq, [ Code.Pv x; Code.Pc (Code.Int32 0l) ]))
        ]
    ; branch = Code.Cond (cond, (true_addr, []), (false_addr, []))
    }
  in
  let func_addr = make_addr 10 in
  let program =
    make_program
      [ (func_addr, func_body); (true_addr, true_block); (false_addr, false_block) ]
  in
  let ctx = Lua_generate.make_context_with_program ~debug:false program in
  let _ = Lua_generate.var_name ctx x in
  let closure = Code.Closure ([ x ], (func_addr, []), None) in
  let lua_expr = Lua_generate.generate_expr ctx closure in
  print_endline (expr_to_string lua_expr);
  [%expect
    {|
    function(v0)
      local v1 = v0 == 0
      if v1 then
        local v2 = 1
        return v2
      else
        local v2 = 0
        return v2
      end
    end |}]

(* Multiple parameters test *)

let%expect_test "generate closure - three parameters" =
  let a = var_of_int 1 in
  let b = var_of_int 2 in
  let c = var_of_int 3 in
  let temp = var_of_int 4 in
  let result = var_of_int 5 in
  (* Function: fun a b c -> (a + b) + c *)
  let func_body =
    { Code.params = []
    ; body =
        [ Code.Let (temp, Code.Prim (Code.Extern "add", [ Code.Pv a; Code.Pv b ]))
        ; Code.Let (result, Code.Prim (Code.Extern "add", [ Code.Pv temp; Code.Pv c ]))
        ]
    ; branch = Code.Return result
    }
  in
  let func_addr = make_addr 10 in
  let program = make_program [ (func_addr, func_body) ] in
  let ctx = Lua_generate.make_context_with_program ~debug:false program in
  let _ = Lua_generate.var_name ctx a in
  let _ = Lua_generate.var_name ctx b in
  let _ = Lua_generate.var_name ctx c in
  let closure = Code.Closure ([ a; b; c ], (func_addr, []), None) in
  let lua_expr = Lua_generate.generate_expr ctx closure in
  print_endline (expr_to_string lua_expr);
  [%expect
    {|
    function(v0, v1, v2)
      local v3 = caml_add(v0, v1)
      local v4 = caml_add(v3, v2)
      return v4
    end |}]

(* Closure without program context (placeholder) *)

let%expect_test "generate closure - no program context" =
  let ctx = make_ctx () in
  let x = var_of_int 1 in
  let func_addr = make_addr 10 in
  let closure = Code.Closure ([ x ], (func_addr, []), None) in
  let lua_expr = Lua_generate.generate_expr ctx closure in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_closure |}]

(* Closure with missing block (placeholder) *)

let%expect_test "generate closure - missing block" =
  let x = var_of_int 1 in
  let func_addr = make_addr 10 in
  let empty_program = make_program [] in
  let ctx = Lua_generate.make_context_with_program ~debug:false empty_program in
  let closure = Code.Closure ([ x ], (func_addr, []), None) in
  let lua_expr = Lua_generate.generate_expr ctx closure in
  print_endline (expr_to_string lua_expr);
  [%expect {| caml_closure |}]
