(* Tests for Lua module compilation *)

open Js_of_ocaml_compiler

module Lua_generate = struct
  include Lua_of_ocaml_compiler__Lua_generate
end

module Lua_output = struct
  include Lua_of_ocaml_compiler__Lua_output
end

(* Test helpers *)
let var_of_int i = Code.Var.of_idx i

let program_to_string stmts = Lua_output.program_to_string stmts

let make_addr i = i

(* Helper to create a simple program with blocks *)
let make_program blocks_list =
  let blocks =
    List.fold_left
      (fun acc (addr, block) -> Code.Addr.Map.add addr block acc)
      Code.Addr.Map.empty
      blocks_list
  in
  { Code.start = Code.Addr.zero; Code.blocks = blocks; Code.free_pc = List.length blocks_list }

(* Simple program tests *)

let%expect_test "generate standalone - empty program" =
  let result = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 0l)) ]
    ; branch = Code.Return result
    }
  in
  let program = make_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = 0
      return v0
    end
    __caml_init__() |}]

let%expect_test "generate standalone - simple computation" =
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let result = var_of_int 3 in
  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v1, Code.Constant (Code.Int32 5l))
        ; Code.Let (v2, Code.Constant (Code.Int32 3l))
        ; Code.Let (result, Code.Prim (Code.Extern "add", [ Code.Pv v1; Code.Pv v2 ]))
        ]
    ; branch = Code.Return result
    }
  in
  let program = make_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = 5
      local v1 = 3
      local v2 = v0 + v1
      return v2
    end
    __caml_init__() |}]

let%expect_test "generate standalone - with function" =
  let x = var_of_int 1 in
  let f = var_of_int 2 in
  let result = var_of_int 3 in
  (* Function: fun x -> x *)
  let func_body =
    { Code.params = []; body = []; branch = Code.Return x }
  in
  let func_addr = make_addr 10 in
  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (x, Code.Constant (Code.Int32 42l))
        ; Code.Let (f, Code.Closure ([ x ], (func_addr, []), None))
        ]
    ; branch = Code.Return result
    }
  in
  let program = make_program [ (Code.Addr.zero, entry_block); (func_addr, func_body) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = 42
      local v1 = function(v0)
        return v0
      end
      return v2
    end
    __caml_init__()
    |}]

(* Module generation tests *)

let%expect_test "generate module - empty module" =
  let result = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 0l)) ]
    ; branch = Code.Return result
    }
  in
  let program = make_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate_module_code ~debug:false ~module_name:"Test" program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Module: Test
    local M = {}
    local v0 = 0
    return v0
    return M |}]

let%expect_test "generate module - with exports" =
  let v1 = var_of_int 1 in
  let v2 = var_of_int 2 in
  let result = var_of_int 3 in
  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v1, Code.Constant (Code.Int32 42l))
        ; Code.Let (v2, Code.Constant (Code.Int32 10l))
        ; Code.Let (result, Code.Prim (Code.Extern "add", [ Code.Pv v1; Code.Pv v2 ]))
        ]
    ; branch = Code.Return result
    }
  in
  let program = make_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate_module_code ~debug:false ~module_name:"Math" program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Module: Math
    local M = {}
    local v0 = 42
    local v1 = 10
    local v2 = v0 + v1
    return v2
    return M |}]

let%expect_test "generate module - with function definition" =
  let x = var_of_int 1 in
  let double_func = var_of_int 2 in
  let result = var_of_int 3 in
  (* Function: fun x -> x + x *)
  let func_body =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Prim (Code.Extern "add", [ Code.Pv x; Code.Pv x ])) ]
    ; branch = Code.Return result
    }
  in
  let func_addr = make_addr 10 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (double_func, Code.Closure ([ x ], (func_addr, []), None)) ]
    ; branch = Code.Return double_func
    }
  in
  let program = make_program [ (Code.Addr.zero, entry_block); (func_addr, func_body) ] in
  let lua_code = Lua_generate.generate_module_code ~debug:false ~module_name:"Utils" program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Module: Utils
    local M = {}
    local v0 = function(v1)
      local v2 = v1 + v1
      return v2
    end
    return v0
    return M |}]

(* Multi-block program tests *)

let%expect_test "generate standalone - conditional program" =
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
  let true_addr = make_addr 1 in
  let false_addr = make_addr 2 in
  (* Entry block: if x == 0 then true_block else false_block *)
  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (x, Code.Constant (Code.Int32 5l))
        ; Code.Let (cond, Code.Prim (Code.Eq, [ Code.Pv x; Code.Pc (Code.Int32 0l) ]))
        ]
    ; branch = Code.Cond (cond, (true_addr, []), (false_addr, []))
    }
  in
  let program =
    make_program
      [ (Code.Addr.zero, entry_block); (true_addr, true_block); (false_addr, false_block) ]
  in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = 5
      local v1 = v0 == 0
      if v1 then
        local v2 = 1
        return v2
      else
        local v2 = 0
        return v2
      end
    end
    __caml_init__() |}]

(* Module dependency simulation tests *)

let%expect_test "generate module - module name in comment" =
  let result = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 123l)) ]
    ; branch = Code.Return result
    }
  in
  let program = make_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code =
    Lua_generate.generate_module_code ~debug:false ~module_name:"MyModule" program
  in
  let code_str = program_to_string lua_code in
  (* Check that module name appears in comment *)
  let contains_module_name =
    try
      let _ = Str.search_forward (Str.regexp_string "-- Module: MyModule") code_str 0 in
      true
    with Not_found -> false
  in
  if contains_module_name
  then print_endline "Module name found in comment"
  else print_endline "Module name NOT found";
  [%expect {| Module name found in comment |}]

let%expect_test "generate module - returns module table" =
  let result = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 456l)) ]
    ; branch = Code.Return result
    }
  in
  let program = make_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate_module_code ~debug:false ~module_name:"Exports" program in
  let code_str = program_to_string lua_code in
  (* Check that module returns a table *)
  let returns_m =
    try
      let _ = Str.search_forward (Str.regexp_string "return M") code_str 0 in
      true
    with Not_found -> false
  in
  if returns_m
  then print_endline "Module returns table M"
  else print_endline "Module does NOT return table";
  [%expect {| Module returns table M |}]

let%expect_test "generate standalone - has init function" =
  let result = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 789l)) ]
    ; branch = Code.Return result
    }
  in
  let program = make_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  let code_str = program_to_string lua_code in
  (* Check that standalone has init function *)
  let has_init =
    try
      let _ = Str.search_forward (Str.regexp_string "function __caml_init__") code_str 0 in
      true
    with Not_found -> false
  in
  if has_init
  then print_endline "Init function found"
  else print_endline "Init function NOT found";
  [%expect {| Init function found |}]

let%expect_test "generate standalone - calls init function" =
  let result = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (result, Code.Constant (Code.Int32 999l)) ]
    ; branch = Code.Return result
    }
  in
  let program = make_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  let code_str = program_to_string lua_code in
  (* Check that standalone calls init function *)
  let calls_init =
    try
      let _ = Str.search_forward (Str.regexp_string "__caml_init__()") code_str 0 in
      true
    with Not_found -> false
  in
  if calls_init
  then print_endline "Init function called"
  else print_endline "Init function NOT called";
  [%expect {| Init function called |}]
