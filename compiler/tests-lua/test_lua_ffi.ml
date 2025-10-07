(* Tests for Lua FFI bindings *)

open Js_of_ocaml_compiler

(* Test helpers *)
module Lua_ast = struct
  include Lua_of_ocaml_compiler__Lua_ast
end

module Lua_generate = struct
  include Lua_of_ocaml_compiler__Lua_generate
end

module Lua_output = struct
  include Lua_of_ocaml_compiler__Lua_output
end

(* Helper to convert program to string *)
let program_to_string stmts = Lua_output.program_to_string stmts

(* Helper to create a variable *)
let var_of_int i = Code.Var.of_idx i

(* Helper to create a simple program *)
let make_simple_program blocks =
  let block_map =
    List.fold_left
      (fun map (addr, blk) -> Code.Addr.Map.add addr blk map)
      Code.Addr.Map.empty
      blocks
  in
  { Code.start = Code.Addr.zero; blocks = block_map; free_pc = List.length blocks }

(** Test type representations **)

let%expect_test "lua value - nil representation" =
  (* Test that nil is represented as 0 in OCaml *)
  let v_nil = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (v_nil, Code.Constant (Code.Int32 0l)) ]
    ; branch = Code.Return v_nil
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
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

let%expect_test "lua value - boolean true" =
  (* Boolean true as 1 *)
  let v_bool = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (v_bool, Code.Constant (Code.Int32 1l)) ]
    ; branch = Code.Return v_bool
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = 1
      return v0
    end
    __caml_init__() |}]

let%expect_test "lua value - boolean false" =
  (* Boolean false as 0 *)
  let v_bool = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (v_bool, Code.Constant (Code.Int32 0l)) ]
    ; branch = Code.Return v_bool
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
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

let%expect_test "lua value - number" =
  (* Numbers are represented directly *)
  let v_num = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (v_num, Code.Constant (Code.Int32 42l)) ]
    ; branch = Code.Return v_num
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = 42
      return v0
    end
    __caml_init__() |}]

let%expect_test "lua value - string" =
  (* Strings are represented directly *)
  let v_str = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (v_str, Code.Constant (Code.String "hello")) ]
    ; branch = Code.Return v_str
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = "hello"
      return v0
    end
    __caml_init__() |}]

let%expect_test "lua value - table (OCaml record)" =
  (* Tables are represented as blocks with tag field *)
  let v_field1 = var_of_int 1 in
  let v_field2 = var_of_int 2 in
  let v_table = var_of_int 3 in
  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v_field1, Code.Constant (Code.Int32 10l))
        ; Code.Let (v_field2, Code.Constant (Code.String "test"))
        ; Code.Let
            (v_table, Code.Block (0, [| v_field1; v_field2 |], Code.NotArray, Code.Immutable))
        ]
    ; branch = Code.Return v_table
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = 10
      local v1 = "test"
      local v2 = {tag = 0, v0, v1}
      return v2
    end
    __caml_init__() |}]

let%expect_test "lua value - array" =
  (* Arrays are blocks with elements *)
  let v_elem1 = var_of_int 1 in
  let v_elem2 = var_of_int 2 in
  let v_elem3 = var_of_int 3 in
  let v_array = var_of_int 4 in
  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v_elem1, Code.Constant (Code.Int32 1l))
        ; Code.Let (v_elem2, Code.Constant (Code.Int32 2l))
        ; Code.Let (v_elem3, Code.Constant (Code.Int32 3l))
        ; Code.Let
            ( v_array
            , Code.Block (0, [| v_elem1; v_elem2; v_elem3 |], Code.Array, Code.Immutable) )
        ]
    ; branch = Code.Return v_array
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = 1
      local v1 = 2
      local v2 = 3
      local v3 = {tag = 0, v0, v1, v2}
      return v3
    end
    __caml_init__() |}]

let%expect_test "lua value - option None" =
  (* Option None is 0 *)
  let v_none = var_of_int 1 in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (v_none, Code.Constant (Code.Int32 0l)) ]
    ; branch = Code.Return v_none
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
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

let%expect_test "lua value - option Some" =
  (* Option Some is a block with tag 0 *)
  let v_value = var_of_int 1 in
  let v_some = var_of_int 2 in
  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v_value, Code.Constant (Code.Int32 42l))
        ; Code.Let (v_some, Code.Block (0, [| v_value |], Code.NotArray, Code.Immutable))
        ]
    ; branch = Code.Return v_some
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = 42
      local v1 = {tag = 0, v0}
      return v1
    end
    __caml_init__() |}]

let%expect_test "lua value - list" =
  (* Lists are represented as nested blocks *)
  (* [1; 2; 3] = Some (1, Some (2, Some (3, None))) *)
  let v_elem1 = var_of_int 1 in
  let v_elem2 = var_of_int 2 in
  let v_elem3 = var_of_int 3 in
  let v_nil = var_of_int 4 in
  let v_cons3 = var_of_int 5 in
  let v_cons2 = var_of_int 6 in
  let v_cons1 = var_of_int 7 in
  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v_elem1, Code.Constant (Code.Int32 1l))
        ; Code.Let (v_elem2, Code.Constant (Code.Int32 2l))
        ; Code.Let (v_elem3, Code.Constant (Code.Int32 3l))
        ; Code.Let (v_nil, Code.Constant (Code.Int32 0l))
        ; Code.Let (v_cons3, Code.Block (0, [| v_elem3; v_nil |], Code.NotArray, Code.Immutable))
        ; Code.Let
            (v_cons2, Code.Block (0, [| v_elem2; v_cons3 |], Code.NotArray, Code.Immutable))
        ; Code.Let
            (v_cons1, Code.Block (0, [| v_elem1; v_cons2 |], Code.NotArray, Code.Immutable))
        ]
    ; branch = Code.Return v_cons1
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = 1
      local v1 = 2
      local v2 = 3
      local v3 = 0
      local v4 = {tag = 0, v2, v3}
      local v5 = {tag = 0, v1, v4}
      local v6 = {tag = 0, v0, v5}
      return v6
    end
    __caml_init__() |}]

let%expect_test "lua value - closure representation" =
  (* Functions/closures are represented as blocks *)
  let v_func = var_of_int 1 in
  let v_arg = var_of_int 2 in
  let v_result = var_of_int 3 in
  (* Create a simple function that returns its argument *)
  let func_block =
    { Code.params = [ v_arg ]
    ; body = [ Code.Let (v_result, Code.Prim (Extern "id", [ Pv v_arg ])) ]
    ; branch = Code.Return v_result
    }
  in
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (v_func, Code.Closure ([], (1, []), None)) ]
    ; branch = Code.Return v_func
    }
  in
  let program = make_simple_program [ (Code.Addr.zero, entry_block); (1, func_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- Runtime initialized by require statements
    function __caml_init__()
      -- Module initialization code
      local v0 = function()
        local v1 = caml_id(v2)
        return v1
      end
      return v0
    end
    __caml_init__()
    |}]
