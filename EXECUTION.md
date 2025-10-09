# Lua_of_ocaml Program Execution Implementation Plan

This document details tasks to implement full program execution in lua_of_ocaml, addressing the limitations found in Task 4.2.

## Master Checklist

**Phase 5: Core Execution Infrastructure**
- [ ] Task 5.1: Add block compilation framework (~120 lines)
- [ ] Task 5.2: Implement instruction translation (~100 lines)
- [ ] Task 5.3: Implement control flow translation (~80 lines)

**Phase 6: Expression and Value Translation**
- [ ] Task 6.1: Implement value reference translation (~50 lines)
- [ ] Task 6.2: Implement expression translation (~120 lines)
- [ ] Task 6.3: Implement primitive operation translation (~80 lines)

**Phase 7: Program Entry Point Integration**
- [ ] Task 7.1: Replace generate_module_init with full compilation (~50 lines)
- [ ] Task 7.2: Add main execution wrapper (~50 lines)

**Phase 8: Runtime Primitive Implementation**
- [ ] Task 8.1: Implement I/O primitives (~100 lines)
- [ ] Task 8.2: Implement string primitives (~100 lines)

**Total**: 10 implementation tasks = **~850 lines new code**

---

## Current State (After LINKING.md Completion)

✅ **Working**:
- Module linking infrastructure complete
- Runtime primitive resolution (naming convention + Export directives)
- Primitive usage tracking
- Runtime module embedding
- Global wrapper generation
- Module initialization code generation (constants only)

❌ **Missing** (This Document):
- Actual program execution code generation
- Function call translation
- Control flow translation (if/match/loops)
- Expression translation
- Primitive operation calls

## Architecture Analysis

### How JS/Wasm Backends Work

Both JS and Wasm backends follow the same pattern:

1. **Entry Point**: `Generate.f` (JS) / `Code_generation.f` (Wasm)
2. **Core Function**: `compile_program ctx p.start`
   - Starts from program entry point (`p.start`)
   - Recursively compiles all reachable blocks
   - Generates actual execution code
3. **Block Compilation**: `compile_closure` → `compile_block`
   - Translates Code IR instructions to target AST
   - Handles control flow, expressions, function calls

### Current Lua Backend State

Currently `lua_generate.ml` only implements:
- `generate_module_init` - Generates constants from entry block
- Does NOT call equivalent of `compile_program`
- Missing: block traversal, instruction translation, control flow

## Code Reuse Strategy

### Reusable from compiler/lib/ (100%)
- `Code` IR types - All blocks, instructions, expressions
- Block traversal patterns from JS backend
- Control flow analysis already done by optimizer

### Reusable from lib-wasm/ (80% - as reference)
- Overall structure of code generation
- Instruction translation patterns
- Control flow handling
- Expression compilation

### Lua-Specific (20%)
- Lua AST construction (already exists in `lua_ast.ml`)
- Lua-specific idioms (tables, 1-based indexing, etc.)
- Lua output formatting (already exists in `lua_output.ml`)

## Implementation Phases

---

## Phase 5: Core Execution Infrastructure (~300 lines)

**Objective**: Implement basic block compilation and control flow

### Task 5.1: Add Block Compilation Framework (~120 lines)

Create the core block compilation function that mirrors `Generate.compile_block`.

**File**: `compiler/lib-lua/lua_generate.ml`

**Reference**:
- `compiler/lib/generate.ml:1647-1850` (compile_block)
- `compiler/lib-wasm/code_generation.ml:800-950` (compile_block)

**Implementation**:
```ocaml
(* Add to lua_generate.ml after generate_module_init *)

(** Context for code generation - tracks state during compilation *)
type compile_ctx = {
  program : Code.program;
  blocks : Code.block Code.Addr.Map.t;
  mutable var_count : int;
  (* Add fields as needed: live_vars, trampolined_calls, etc. *)
}

(** Generate unique variable name *)
let fresh_var ctx prefix =
  ctx.var_count <- ctx.var_count + 1;
  Printf.sprintf "%s_%d" prefix ctx.var_count

(** Compile a single block into Lua statements

    Recursively compiles blocks reachable from this one.
    Handles control flow (branches, returns, loops).

    @param ctx Compilation context
    @param block_addr Address of block to compile
    @return List of Lua statements
*)
let rec compile_block ctx block_addr =
  match Code.Addr.Map.find_opt block_addr ctx.blocks with
  | None -> failwith (Printf.sprintf "Block not found: %d" (Code.Addr.to_int block_addr))
  | Some block ->
      (* Compile block parameters as local variables *)
      let param_stmts = compile_params block.Code.params in

      (* Compile block body (instructions) *)
      let body_stmts = List.concat_map (compile_instruction ctx) block.Code.body in

      (* Compile block branch (control flow) *)
      let branch_stmts = compile_branch ctx block.Code.branch in

      param_stmts @ body_stmts @ branch_stmts

(** Compile all blocks starting from entry point

    Main entry point for program compilation.
    Mirrors Generate.compile_program.

    @param ctx Compilation context
    @param entry_addr Address of program entry block
    @return List of Lua statements for entire program
*)
and compile_program ctx entry_addr =
  compile_block ctx entry_addr
```

**Test Cases** (in `test_lua_generate.ml`):
1. Empty block compilation
2. Block with single instruction
3. Block with control flow (if/branch)
4. Block with multiple instructions

**Success Criteria**:
- ✅ `compile_block` function compiles
- ✅ `compile_program` entry point works
- ✅ Can traverse simple blocks
- ✅ Zero warnings
- ✅ Tests pass

**Output**: ~120 lines in `lua_generate.ml`

**Commit**: `feat(lua): Add block compilation framework`

---

### Task 5.2: Implement Instruction Translation (~100 lines)

Translate Code IR instructions to Lua statements.

**File**: `compiler/lib-lua/lua_generate.ml`

**Reference**:
- `compiler/lib/generate.ml:1463-1640` (compile_block for instruction handling)
- `compiler/lib-wasm/code_generation.ml:600-750` (instruction translation)

**Implementation**:
```ocaml
(** Compile parameters to local variable declarations *)
and compile_params params =
  if List.length params = 0 then []
  else
    let param_names = List.map (fun (var, _loc) -> var_name var) params in
    [ L.Local (param_names, None) ]

(** Compile a single instruction

    @param ctx Compilation context
    @param instr Code IR instruction
    @return List of Lua statements
*)
and compile_instruction ctx = function
  | Code.Let (var, expr) ->
      let lua_expr = compile_expression ctx expr in
      let var_name = fresh_var ctx "v" in
      [ L.Local ([var_name], Some [lua_expr]) ]

  | Code.Assign (var, val_ref) ->
      let rhs = compile_value_ref ctx val_ref in
      [ L.Assign ([L.Ident (var_name var)], [rhs]) ]

  | Code.Set_field (obj, field, _field_type, value) ->
      let obj_expr = compile_value_ref ctx obj in
      let val_expr = compile_value_ref ctx value in
      [ L.Assign (
          [L.Index (obj_expr, L.Number (string_of_int (field + 1)))],
          [val_expr]
        )]

  | Code.Offset_ref (var, offset) ->
      (* r := !r + offset *)
      let var_expr = L.Ident (var_name var) in
      let curr_val = L.Index (var_expr, L.Number "1") in
      let new_val = L.BinOp (L.Add, curr_val, L.Number (string_of_int offset)) in
      [ L.Assign ([L.Index (var_expr, L.Number "1")], [new_val]) ]

  | Code.Array_set (arr, idx, val_ref) ->
      let arr_expr = compile_value_ref ctx arr in
      let idx_expr = compile_value_ref ctx idx in
      let val_expr = compile_value_ref ctx val_ref in
      (* Arrays are 0-indexed in OCaml, 1-indexed in Lua *)
      let lua_idx = L.BinOp (L.Add, idx_expr, L.Number "1") in
      [ L.Assign ([L.Index (arr_expr, lua_idx)], [val_expr]) ]

  | Code.Event _ ->
      (* Debug events - skip for now *)
      []
```

**Test Cases**:
1. Let binding compilation
2. Assignment compilation
3. Field set compilation
4. Array set compilation

**Success Criteria**:
- ✅ All Code instruction types handled
- ✅ Lua statements generated correctly
- ✅ Tests pass
- ✅ Zero warnings

**Output**: ~100 lines in `lua_generate.ml`

**Commit**: `feat(lua): Add instruction translation`

---

### Task 5.3: Implement Control Flow Translation (~80 lines)

Translate Code IR branches (if/return/switch) to Lua control flow.

**File**: `compiler/lib-lua/lua_generate.ml`

**Reference**:
- `compiler/lib/generate.ml:1790-1850` (branch compilation)
- `compiler/lib-wasm/code_generation.ml:900-950` (control flow)

**Implementation**:
```ocaml
(** Compile branch (control flow)

    @param ctx Compilation context
    @param branch Code IR branch
    @return List of Lua statements
*)
and compile_branch ctx (branch, _loc) = match branch with
  | Code.Return val_ref ->
      let expr = compile_value_ref ctx val_ref in
      [ L.Return [expr] ]

  | Code.Raise (val_ref, _bt) ->
      let expr = compile_value_ref ctx val_ref in
      [ L.Call_stat (L.Call (L.Ident "error", [expr])) ]

  | Code.Stop ->
      (* End of block - no branching *)
      []

  | Code.Branch (cond_addr, _loc) ->
      (* Unconditional jump - compile target block inline *)
      compile_block ctx cond_addr

  | Code.Cond (cond_var, then_addr, else_addr) ->
      let cond_expr = L.Ident (var_name cond_var) in
      let then_stmts = compile_block ctx then_addr in
      let else_stmts = compile_block ctx else_addr in
      [ L.If (cond_expr, then_stmts, Some else_stmts) ]

  | Code.Switch (switch_var, cases, default) ->
      (* Multi-way branch - translate to if-elseif chain *)
      compile_switch ctx switch_var cases default

  | Code.Pushtrap _ | Code.Poptrap _ ->
      (* Exception handling - implement in Phase 7 *)
      failwith "Exception handling not yet implemented"

(** Compile switch as if-elseif-else chain *)
and compile_switch ctx switch_var cases default =
  let var_expr = L.Ident (var_name switch_var) in

  (* Build if-elseif chain for cases *)
  let rec build_chain = function
    | [] ->
        (* No more cases - compile default *)
        (match default with
         | None -> []
         | Some default_addr -> compile_block ctx default_addr)
    | (tag, target_addr) :: rest ->
        let cond = L.BinOp (L.Eq, var_expr, L.Number (string_of_int tag)) in
        let then_stmts = compile_block ctx target_addr in
        let else_stmts = build_chain rest in
        [ L.If (cond, then_stmts, if List.length else_stmts = 0 then None else Some else_stmts) ]
  in
  build_chain (Array.to_list cases)
```

**Test Cases**:
1. Return statement
2. Conditional branch (if-else)
3. Switch statement
4. Unconditional branch

**Success Criteria**:
- ✅ All branch types handled
- ✅ Control flow correct
- ✅ Tests pass
- ✅ Zero warnings

**Output**: ~80 lines in `lua_generate.ml`

**Commit**: `feat(lua): Add control flow translation`

---

## Phase 6: Expression and Value Translation (~250 lines)

**Objective**: Translate Code IR expressions and values to Lua

### Task 6.1: Implement Value Reference Translation (~50 lines)

Translate Code.Var references to Lua identifiers.

**File**: `compiler/lib-lua/lua_generate.ml`

**Reference**: `compiler/lib/generate.ml:1190-1250` (value translation)

**Implementation**:
```ocaml
(** Map from Code.Var to Lua variable name *)
let var_name_map : (Code.Var.t, string) Hashtbl.t = Hashtbl.create 100

(** Get or create Lua variable name for Code.Var *)
let var_name var =
  match Hashtbl.find_opt var_name_map var with
  | Some name -> name
  | None ->
      let name = Printf.sprintf "v%d" (Code.Var.idx var) in
      Hashtbl.add var_name_map var name;
      name

(** Compile value reference (variable or constant)

    @param ctx Compilation context
    @param val_ref Code value reference
    @return Lua expression
*)
and compile_value_ref ctx = function
  | Code.Pv var -> L.Ident (var_name var)
  | Code.Pc const -> compile_constant ctx const

(** Compile constant value

    @param ctx Compilation context
    @param const Code constant
    @return Lua expression
*)
and compile_constant ctx = function
  | Code.Int i -> L.Number (Targetint.to_string i)
  | Code.Float f -> L.Number (Float.to_string f)
  | Code.String s -> L.String (Bytes.to_string s)
  | Code.IString s -> L.String s
  | Code.Float_array arr -> compile_float_array ctx arr
  | Code.Int64 i -> L.Number (Int64.to_string i)
  | Code.Tuple (tag, fields, _) -> compile_block_constant ctx tag fields
  | Code.NativeString s -> L.String s
```

**Test Cases**:
1. Variable reference
2. Integer constant
3. String constant
4. Float constant

**Success Criteria**:
- ✅ All value types handled
- ✅ Variables mapped correctly
- ✅ Constants translated correctly
- ✅ Tests pass

**Output**: ~50 lines

**Commit**: `feat(lua): Add value reference translation`

---

### Task 6.2: Implement Expression Translation (~120 lines)

Translate Code IR expressions (operations, calls) to Lua expressions.

**File**: `compiler/lib-lua/lua_generate.ml`

**Reference**: `compiler/lib/generate.ml:1300-1600` (expression compilation)

**Implementation**:
```ocaml
(** Compile expression

    @param ctx Compilation context
    @param expr Code expression
    @return Lua expression
*)
and compile_expression ctx = function
  | Code.Const const ->
      compile_constant ctx const

  | Code.Apply { f; args; exact = _; loc = _ } ->
      let func_expr = compile_value_ref ctx f in
      let arg_exprs = List.map (compile_value_ref ctx) args in
      L.Call (func_expr, arg_exprs)

  | Code.Block (tag, fields, _array_or_not, _mut) ->
      (* OCaml block = Lua table with tag field *)
      let field_exprs = Array.to_list (Array.map (compile_value_ref ctx) fields) in
      let tag_field = ("tag", L.Number (string_of_int tag)) in
      let field_kvs = List.mapi (fun i expr -> (string_of_int (i + 1), expr)) field_exprs in
      L.Table (tag_field :: field_kvs)

  | Code.Field (obj, field, _) ->
      let obj_expr = compile_value_ref ctx obj in
      L.Index (obj_expr, L.Number (string_of_int (field + 1)))

  | Code.Closure (params, body_blocks) ->
      (* Function closure *)
      compile_closure ctx params body_blocks

  | Code.Prim (prim, args) ->
      compile_primitive ctx prim args

  | Code.Special _ ->
      failwith "Special expressions not yet implemented"
```

**Test Cases**:
1. Constant expression
2. Function application
3. Block construction (record/variant)
4. Field access
5. Primitive operation

**Success Criteria**:
- ✅ All expression types handled
- ✅ Lua expressions generated correctly
- ✅ Tests pass
- ✅ Zero warnings

**Output**: ~120 lines

**Commit**: `feat(lua): Add expression translation`

---

### Task 6.3: Implement Primitive Operation Translation (~80 lines)

Translate Code primitive operations to Lua operations or runtime calls.

**File**: `compiler/lib-lua/lua_generate.ml`

**Reference**:
- `compiler/lib/generate.ml:400-700` (primitive translation)
- `compiler/lib/primitive.ml` (primitive registry)

**Implementation**:
```ocaml
(** Compile primitive operation

    Many primitives map directly to Lua operators.
    Others require runtime calls.

    @param ctx Compilation context
    @param prim Primitive operation
    @param args Argument list
    @return Lua expression
*)
and compile_primitive ctx prim args = match prim with
  (* Integer arithmetic - direct Lua operators *)
  | Code.Extern "caml_add_int" | Code.Extern "+" ->
      (match args with
       | [a; b] -> L.BinOp (L.Add, compile_value_ref ctx a, compile_value_ref ctx b)
       | _ -> failwith "add_int: wrong arity")

  | Code.Extern "caml_sub_int" | Code.Extern "-" ->
      (match args with
       | [a; b] -> L.BinOp (L.Sub, compile_value_ref ctx a, compile_value_ref ctx b)
       | _ -> failwith "sub_int: wrong arity")

  | Code.Extern "caml_mul_int" | Code.Extern "*" ->
      (match args with
       | [a; b] -> L.BinOp (L.Mul, compile_value_ref ctx a, compile_value_ref ctx b)
       | _ -> failwith "mul_int: wrong arity")

  | Code.Extern "caml_div_int" | Code.Extern "/" ->
      (match args with
       | [a; b] -> L.BinOp (L.Div, compile_value_ref ctx a, compile_value_ref ctx b)
       | _ -> failwith "div_int: wrong arity")

  (* Comparisons - direct Lua operators *)
  | Code.Extern "caml_eq" | Code.Extern "==" ->
      (match args with
       | [a; b] -> L.BinOp (L.Eq, compile_value_ref ctx a, compile_value_ref ctx b)
       | _ -> failwith "eq: wrong arity")

  | Code.Extern "caml_lt" | Code.Extern "<" ->
      (match args with
       | [a; b] -> L.BinOp (L.Lt, compile_value_ref ctx a, compile_value_ref ctx b)
       | _ -> failwith "lt: wrong arity")

  (* I/O - runtime calls *)
  | Code.Extern name when String.starts_with ~prefix:"caml_ml_" name ->
      let arg_exprs = List.map (compile_value_ref ctx) args in
      L.Call (L.Ident name, arg_exprs)

  (* Generic external primitive - runtime call *)
  | Code.Extern name ->
      let prim_name = if String.starts_with ~prefix:"caml_" name then name else "caml_" ^ name in
      let arg_exprs = List.map (compile_value_ref ctx) args in
      L.Call (L.Ident prim_name, arg_exprs)

  (* Built-in primitives *)
  | _ ->
      failwith (Printf.sprintf "Primitive not implemented: %s" (Code.Primitive.to_string prim))
```

**Test Cases**:
1. Arithmetic operations (+, -, *, /)
2. Comparison operations (=, <, >)
3. External primitive calls
4. Runtime primitive calls

**Success Criteria**:
- ✅ Common primitives mapped to Lua operators
- ✅ External primitives call runtime
- ✅ Tests pass
- ✅ Zero warnings

**Output**: ~80 lines

**Commit**: `feat(lua): Add primitive operation translation`

---

## Phase 7: Program Entry Point Integration (~100 lines)

**Objective**: Connect new execution code to existing infrastructure

### Task 7.1: Replace generate_module_init with Full Compilation (~50 lines)

Modify `generate_standalone` to use `compile_program` instead of `generate_module_init`.

**File**: `compiler/lib-lua/lua_generate.ml`

**Changes**:
```ocaml
(* Before - line 1194 *)
let program_code = generate_module_init ctx program in

(* After *)
let ctx = {
  program = program;
  blocks = program.Code.blocks;
  var_count = 0;
} in
let program_code = compile_program ctx program.Code.start in
```

**Test**: Rebuild hello_lua and verify execution code is generated

**Success Criteria**:
- ✅ hello_lua compiles
- ✅ Execution code generated (not just constants)
- ✅ Function calls present in output
- ✅ Tests pass

**Output**: ~50 lines modified

**Commit**: `feat(lua): Switch to full program compilation`

---

### Task 7.2: Add Main Execution Wrapper (~50 lines)

Wrap generated code in proper initialization and execution sequence.

**File**: `compiler/lib-lua/lua_generate.ml`

**Implementation**:
```ocaml
(* After generating program_code in generate_standalone *)

(* Wrap execution code in main function *)
let main_function =
  L.Function_decl
    ( "__caml_main__"
    , []
    , false
    , program_code )
in

(* Generate final code: runtime + modules + wrappers + program + main call *)
inline_runtime
@ [ L.Comment "" ]
@ embedded_modules
@ wrappers
@ [ L.Comment "" ]
@ [ main_function ]
@ [ L.Call_stat (L.Call (L.Ident "__caml_main__", [])) ]
```

**Test**: hello_lua should execute and produce output

**Success Criteria**:
- ✅ Main function generated
- ✅ Main function called automatically
- ✅ hello_lua produces output (if Lua installed)
- ✅ Tests pass

**Output**: ~50 lines

**Commit**: `feat(lua): Add main execution wrapper`

---

## Phase 8: Runtime Primitive Implementation (~200 lines)

**Objective**: Implement missing runtime primitives needed for hello_lua

### Task 8.1: Implement I/O Primitives (~100 lines)

Add print_endline, Printf.printf support.

**Files**:
- `runtime/lua/io.lua` (modifications)
- Add Export directives

**Implementation**:
```lua
-- runtime/lua/io.lua

-- Add at top:
--// Export: output_char as caml_ml_output_char
--// Export: output_string as caml_ml_output
--// Export: flush as caml_ml_flush

function M.output_char(ch, c)
  -- Output single character
  io.write(string.char(c))
end

function M.output_string(ch, s)
  -- Output string (OCaml bytes array or Lua string)
  if type(s) == "table" then
    -- OCaml bytes array
    local chars = {}
    for i = 1, #s do
      table.insert(chars, string.char(s[i]))
    end
    io.write(table.concat(chars))
  else
    io.write(s)
  end
end

function M.flush(ch)
  io.flush()
end
```

**Test**: hello_lua should print output

**Success Criteria**:
- ✅ print_endline works
- ✅ Printf.printf works
- ✅ Output visible in Lua
- ✅ Tests pass

**Output**: ~100 lines

**Commit**: `feat(lua): Add I/O runtime primitives`

---

### Task 8.2: Implement String Primitives (~100 lines)

Add String module primitives (length, uppercase, etc).

**Files**:
- `runtime/lua/string.lua` (modifications)
- Add Export directives

**Implementation**:
```lua
-- runtime/lua/string.lua

--// Export: length as caml_string_length
--// Export: unsafe_get as caml_string_unsafe_get
--// Export: compare as caml_string_compare

function M.length(s)
  if type(s) == "string" then
    return #s
  else
    -- OCaml bytes array
    return #s
  end
end

function M.unsafe_get(s, i)
  -- Get character at index i (0-based from OCaml)
  if type(s) == "string" then
    return string.byte(s, i + 1)
  else
    return s[i + 1]
  end
end

function M.compare(s1, s2)
  if s1 < s2 then return -1
  elseif s1 > s2 then return 1
  else return 0
  end
end

function M.uppercase_ascii(s)
  return string.upper(s)
end
```

**Test**: String operations in hello_lua work

**Success Criteria**:
- ✅ String.length works
- ✅ String.uppercase_ascii works
- ✅ Tests pass

**Output**: ~100 lines

**Commit**: `feat(lua): Add string runtime primitives`

---

## Task Summary

| Phase | Tasks | Lines | Complexity |
|-------|-------|-------|------------|
| 5: Core Execution | 3 | ~300 | Medium |
| 6: Expressions | 3 | ~250 | Medium |
| 7: Integration | 2 | ~100 | Low |
| 8: Runtime | 2 | ~200 | Low |
| **Total** | **10** | **~850** | **Medium** |

## Success Criteria

After completing all phases:

✅ **hello_lua example executes**:
```bash
$ lua _build/default/examples/hello_lua/hello.bc.lua
Hello from Lua_of_ocaml!
Factorial of 5 is: 120
Testing string operations...
Length of 'lua_of_ocaml': 13
Uppercase: LUA_OF_OCAML
```

✅ **Code generator produces**:
- Block compilation with control flow
- Expression translation
- Primitive operations (inlined + runtime calls)
- Function calls and closures
- Proper execution sequence

✅ **All phases compile** with zero warnings

✅ **All tests pass** including new execution tests

## Dependencies

- Phases 5-6 can be done in parallel (5 first recommended)
- Phase 7 depends on Phases 5-6
- Phase 8 can be done in parallel with others

## Code Reuse Maximization

- **95% IR reuse**: All Code IR handling from compiler/lib
- **80% pattern reuse**: Follow Generate.ml structure exactly
- **60% logic reuse**: Control flow patterns from Wasm backend
- **40% runtime reuse**: Adapt patterns from JS runtime

## Notes

- Follow CLAUDE.md task completion protocol for each task
- Each task must be complete (no TODOs), tested, warning-free
- Maximum 300 lines per task
- Update EXECUTION.md checklist after each task
- Commit after each completed task
