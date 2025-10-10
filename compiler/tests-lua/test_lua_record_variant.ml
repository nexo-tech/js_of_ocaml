(* Tests for record and variant optimizations *)

open Js_of_ocaml_compiler

(* Test helpers from existing test files *)
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
  let block_map = List.fold_left
    (fun map (addr, blk) -> Code.Addr.Map.add addr blk map)
    Code.Addr.Map.empty
    blocks
  in
  { Code.start = Code.Addr.zero
  ; blocks = block_map
  ; free_pc = List.length blocks
  }

(** Test record field access optimization *)

let%expect_test "record field access - simple" =
  (* Create a record access: let r = {x=1; y=2} in r.y *)
  let v_x = var_of_int 1 in
  let v_y = var_of_int 2 in
  let v_record = var_of_int 3 in
  let v_field = var_of_int 4 in

  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v_x, Code.Constant (Code.Int32 1l))
        ; Code.Let (v_y, Code.Constant (Code.Int32 2l))
        ; Code.Let (v_record, Code.Block (0, [| v_x; v_y |], Code.NotArray, Code.Immutable))
        ; Code.Let (v_field, Code.Field (v_record, 1, Code.Non_float))
        ]
    ; branch = Code.Return v_field
    }
  in

  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- === OCaml Runtime (Minimal Inline Version) ===
    -- Global storage for OCaml values
    local _OCAML_GLOBALS = {}
    --
    -- caml_register_global: Register a global OCaml value
    --   n: global index
    --   v: value to register
    --   name: optional string name for the global
    function caml_register_global(n, v, name)
      -- Store value at index n+1 (Lua 1-indexed)
      _OCAML_GLOBALS[n + 1] = v
      -- Also store by name if provided
      if name then
        _OCAML_GLOBALS[name] = v
      end
      -- Return the value for chaining
      return v
    end
    --
    -- === End Runtime ===
    --
    --
    function __caml_init__()
      -- Module initialization code
      -- Hoisted variables (4 total)
      local v0, v1, v2, v3
      ::block_0::
      v0 = 1
      v1 = 2
      v2 = {tag = 0, v0, v1}
      v3 = v2[2]
      return v3
    end
    __caml_init__()
    |}]

(** Test variant construction optimization *)

let%expect_test "variant construction - simple constructor" =
  (* type t = A | B of int *)
  (* Create: B 42 *)
  let v_arg = var_of_int 1 in
  let v_variant = var_of_int 2 in

  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v_arg, Code.Constant (Code.Int32 42l))
        ; Code.Let (v_variant, Code.Block (1, [| v_arg |], Code.NotArray, Code.Immutable))
        ]
    ; branch = Code.Return v_variant
    }
  in

  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- === OCaml Runtime (Minimal Inline Version) ===
    -- Global storage for OCaml values
    local _OCAML_GLOBALS = {}
    --
    -- caml_register_global: Register a global OCaml value
    --   n: global index
    --   v: value to register
    --   name: optional string name for the global
    function caml_register_global(n, v, name)
      -- Store value at index n+1 (Lua 1-indexed)
      _OCAML_GLOBALS[n + 1] = v
      -- Also store by name if provided
      if name then
        _OCAML_GLOBALS[name] = v
      end
      -- Return the value for chaining
      return v
    end
    --
    -- === End Runtime ===
    --
    --
    function __caml_init__()
      -- Module initialization code
      -- Hoisted variables (2 total)
      local v0, v1
      ::block_0::
      v0 = 42
      v1 = {tag = 1, v0}
      return v1
    end
    __caml_init__()
    |}]

(** Test variant discrimination optimization *)

let%expect_test "variant match - switch optimization" =
  (* Match on a variant with multiple cases *)
  let v_variant = var_of_int 1 in
  let v_result = var_of_int 2 in

  (* Create entry block that sets up variant *)
  let entry_block =
    { Code.params = []
    ; body = [ Code.Let (v_variant, Code.Constant (Code.Int32 0l)) ]
    ; branch =
        Code.Switch
          ( v_variant
          , [| (1, []); (2, []); (3, []) |]
          )
    }
  in

  (* Case 0: return 10 *)
  let case_0 =
    { Code.params = []
    ; body = [ Code.Let (v_result, Code.Constant (Code.Int32 10l)) ]
    ; branch = Code.Return v_result
    }
  in

  (* Case 1: return 20 *)
  let case_1 =
    { Code.params = []
    ; body = [ Code.Let (v_result, Code.Constant (Code.Int32 20l)) ]
    ; branch = Code.Return v_result
    }
  in

  (* Case 2: return 30 *)
  let case_2 =
    { Code.params = []
    ; body = [ Code.Let (v_result, Code.Constant (Code.Int32 30l)) ]
    ; branch = Code.Return v_result
    }
  in

  let program =
    make_simple_program
      [ (Code.Addr.zero, entry_block)
      ; (1, case_0)
      ; (2, case_1)
      ; (3, case_2)
      ]
  in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- === OCaml Runtime (Minimal Inline Version) ===
    -- Global storage for OCaml values
    local _OCAML_GLOBALS = {}
    --
    -- caml_register_global: Register a global OCaml value
    --   n: global index
    --   v: value to register
    --   name: optional string name for the global
    function caml_register_global(n, v, name)
      -- Store value at index n+1 (Lua 1-indexed)
      _OCAML_GLOBALS[n + 1] = v
      -- Also store by name if provided
      if name then
        _OCAML_GLOBALS[name] = v
      end
      -- Return the value for chaining
      return v
    end
    --
    -- === End Runtime ===
    --
    --
    function __caml_init__()
      -- Module initialization code
      -- Hoisted variables (2 total)
      local v0, v1
      ::block_0::
      v0 = 0
      if v0 == 0 then
        goto block_1
      else
        if v0 == 1 then
          goto block_2
        else
          if v0 == 2 then
            goto block_3
          else
            goto block_1
          end
        end
      end
      ::block_1::
      v1 = 10
      do
        return v1
      end
      ::block_2::
      v1 = 20
      do
        return v1
      end
      ::block_3::
      v1 = 30
      return v1
    end
    __caml_init__()
    |}]

(** Test multi-field record access *)

let%expect_test "record - multiple field accesses" =
  (* Create record {a=1; b=2; c=3} and access all fields *)
  let v_a = var_of_int 1 in
  let v_b = var_of_int 2 in
  let v_c = var_of_int 3 in
  let v_record = var_of_int 4 in
  let v_field_a = var_of_int 5 in
  let v_field_b = var_of_int 6 in
  let v_field_c = var_of_int 7 in

  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v_a, Code.Constant (Code.Int32 1l))
        ; Code.Let (v_b, Code.Constant (Code.Int32 2l))
        ; Code.Let (v_c, Code.Constant (Code.Int32 3l))
        ; Code.Let (v_record, Code.Block (0, [| v_a; v_b; v_c |], Code.NotArray, Code.Immutable))
        ; Code.Let (v_field_a, Code.Field (v_record, 0, Code.Non_float))
        ; Code.Let (v_field_b, Code.Field (v_record, 1, Code.Non_float))
        ; Code.Let (v_field_c, Code.Field (v_record, 2, Code.Non_float))
        ]
    ; branch = Code.Return v_field_a
    }
  in

  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- === OCaml Runtime (Minimal Inline Version) ===
    -- Global storage for OCaml values
    local _OCAML_GLOBALS = {}
    --
    -- caml_register_global: Register a global OCaml value
    --   n: global index
    --   v: value to register
    --   name: optional string name for the global
    function caml_register_global(n, v, name)
      -- Store value at index n+1 (Lua 1-indexed)
      _OCAML_GLOBALS[n + 1] = v
      -- Also store by name if provided
      if name then
        _OCAML_GLOBALS[name] = v
      end
      -- Return the value for chaining
      return v
    end
    --
    -- === End Runtime ===
    --
    --
    function __caml_init__()
      -- Module initialization code
      -- Hoisted variables (7 total)
      local v0, v1, v2, v3, v4, v5, v6
      ::block_0::
      v0 = 1
      v1 = 2
      v2 = 3
      v3 = {tag = 0, v0, v1, v2}
      v4 = v3[1]
      v5 = v3[2]
      v6 = v3[3]
      return v4
    end
    __caml_init__()
    |}]

(** Test variant with inline record *)

let%expect_test "variant with inline record" =
  (* type t = A of {x: int; y: int} *)
  (* Create: A {x=10; y=20} *)
  let v_x = var_of_int 1 in
  let v_y = var_of_int 2 in
  let v_variant = var_of_int 3 in

  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v_x, Code.Constant (Code.Int32 10l))
        ; Code.Let (v_y, Code.Constant (Code.Int32 20l))
        ; Code.Let (v_variant, Code.Block (0, [| v_x; v_y |], Code.NotArray, Code.Immutable))
        ]
    ; branch = Code.Return v_variant
    }
  in

  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- === OCaml Runtime (Minimal Inline Version) ===
    -- Global storage for OCaml values
    local _OCAML_GLOBALS = {}
    --
    -- caml_register_global: Register a global OCaml value
    --   n: global index
    --   v: value to register
    --   name: optional string name for the global
    function caml_register_global(n, v, name)
      -- Store value at index n+1 (Lua 1-indexed)
      _OCAML_GLOBALS[n + 1] = v
      -- Also store by name if provided
      if name then
        _OCAML_GLOBALS[name] = v
      end
      -- Return the value for chaining
      return v
    end
    --
    -- === End Runtime ===
    --
    --
    function __caml_init__()
      -- Module initialization code
      -- Hoisted variables (3 total)
      local v0, v1, v2
      ::block_0::
      v0 = 10
      v1 = 20
      v2 = {tag = 0, v0, v1}
      return v2
    end
    __caml_init__()
    |}]

(** Test nested record access *)

let%expect_test "nested record access" =
  (* Create nested record: {outer = {inner = 42}} *)
  let v_inner_val = var_of_int 1 in
  let v_inner = var_of_int 2 in
  let v_outer = var_of_int 3 in
  let v_field_outer = var_of_int 4 in
  let v_field_inner = var_of_int 5 in

  let entry_block =
    { Code.params = []
    ; body =
        [ Code.Let (v_inner_val, Code.Constant (Code.Int32 42l))
        ; Code.Let (v_inner, Code.Block (0, [| v_inner_val |], Code.NotArray, Code.Immutable))
        ; Code.Let (v_outer, Code.Block (0, [| v_inner |], Code.NotArray, Code.Immutable))
        ; Code.Let (v_field_outer, Code.Field (v_outer, 0, Code.Non_float))
        ; Code.Let (v_field_inner, Code.Field (v_field_outer, 0, Code.Non_float))
        ]
    ; branch = Code.Return v_field_inner
    }
  in

  let program = make_simple_program [ (Code.Addr.zero, entry_block) ] in
  let lua_code = Lua_generate.generate ~debug:false program in
  print_endline (program_to_string lua_code);
  [%expect
    {|
    -- === OCaml Runtime (Minimal Inline Version) ===
    -- Global storage for OCaml values
    local _OCAML_GLOBALS = {}
    --
    -- caml_register_global: Register a global OCaml value
    --   n: global index
    --   v: value to register
    --   name: optional string name for the global
    function caml_register_global(n, v, name)
      -- Store value at index n+1 (Lua 1-indexed)
      _OCAML_GLOBALS[n + 1] = v
      -- Also store by name if provided
      if name then
        _OCAML_GLOBALS[name] = v
      end
      -- Return the value for chaining
      return v
    end
    --
    -- === End Runtime ===
    --
    --
    function __caml_init__()
      -- Module initialization code
      -- Hoisted variables (5 total)
      local v0, v1, v2, v3, v4
      ::block_0::
      v0 = 42
      v1 = {tag = 0, v0}
      v2 = {tag = 0, v1}
      v3 = v2[1]
      v4 = v3[1]
      return v4
    end
    __caml_init__()
    |}]
