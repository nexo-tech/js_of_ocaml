# Task 2.3: Understanding Current Closure Generation

## Analysis Date: 2025-10-12

## Executive Summary

**ROOT CAUSE IDENTIFIED**: The Printf bug is NOT a general closure problem. It's a specific bug in how entry blocks with parameters are initialized when a closure starts at a non-zero block address.

### The Problem

When a closure's entry point is a block other than block 0, and that entry block has parameters that should come from `block_args`, those parameters are:
1. Initialized to `nil` by the hoisting logic
2. NEVER assigned their actual values from `block_args`
3. Accessed by the block code, causing "attempt to index nil" errors

## Code Generation Architecture

### 1. The `_V` Table Pattern

**Location**: `compiler/lib-lua/lua_generate.ml:156`

```ocaml
let var_table_name = "_V"
```

**Purpose**: When a function has >180 hoisted variables, Lua's 200 local limit is approached. To avoid this, all variables are stored in a single table `_V` instead of as locals.

**Threshold**: 180 variables (lines 163-174)
- Lua limit: 200 locals per function
- Reserve: ~20 for other locals (exception handlers, dispatch variables)
- Safe threshold: 200 - 20 = 180

### 2. Context Structure

**Location**: `compiler/lib-lua/lua_generate.ml:44-57`

```ocaml
type context =
  { vars : var_context
  ; _debug : bool
  ; program : Code.program option
  ; optimize_field_access : bool
  ; mutable use_var_table : bool  (* Set to true when >180 vars *)
  ; inherit_var_table : bool      (* Nested closure inherits parent's _V *)
  }
```

**Key Fields**:
- `use_var_table`: When true, generates `_V.v0 = expr` instead of `v0 = expr`
- `inherit_var_table`: When true, nested closure doesn't create new `local _V = {}`, but uses parent's _V as upvalue

### 3. Closure Generation Flow

**Location**: `compiler/lib-lua/lua_generate.ml:1246-1298`

```ocaml
and generate_closure ctx params pc block_args =
  (* 1. Create child context that inherits parent's variable mappings *)
  let closure_ctx = make_child_context ctx program in

  (* 2. Generate parameter names *)
  let param_names = List.map ~f:(var_name closure_ctx) params in

  (* 3. CRITICAL: Pass block_args to entry block *)
  let arg_passing = generate_argument_passing closure_ctx pc block_args ~func_params:params () in

  (* 4. Generate body with hoisting *)
  let body_stmts = compile_blocks_with_labels closure_ctx program pc ~params () in

  (* 5. Prepend argument passing *)
  let full_body = arg_passing @ body_stmts in

  (* 6. Wrap in OCaml closure format *)
  let lua_func = L.Function (param_names, false, full_body) in
  L.Call (L.Ident "caml_make_closure", [ arity; lua_func ])
```

**The Bug**: `arg_passing` is prepended to `body_stmts`, but `body_stmts` contains the hoisting logic that initializes all vars to nil. The `arg_passing` statements come BEFORE the hoisting, which should be correct. But something is still wrong...

### 4. Variable Collection & Hoisting

**Location**: `compiler/lib-lua/lua_generate.ml:962-1012, 1023-1244`

**Flow**:
1. `collect_block_variables` - collects all variables assigned in reachable blocks
2. `compile_blocks_with_labels` - generates hoisting statements
3. If using `_V` table: initializes ALL variables to nil (except entry block params)
4. Generates dispatch loop for all blocks

**Critical Code** (lines 1086-1091):
```ocaml
let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params in
let init_stmts =
  StringSet.elements vars_to_init
  |> List.map ~f:(fun var ->
      (* _V.var = nil - initialize in parent's table *)
      L.Assign ([ L.Dot (L.Ident var_table_name, var) ], [ L.Nil ]))
```

This excludes `entry_block_params` from nil initialization, which is correct.

## Concrete Example from Printf

### Generated Code Structure

```lua
_V.v184 = caml_make_closure(4, function(counter, v201, v202, v203)
  -- Hoisted variables (200+ total, using inherited _V table)
  _V.v204 = nil
  _V.v205 = nil
  ...
  _V.v273 = nil  -- Line 21848: Initialized to nil
  ...
  _V.counter = counter  -- Copy function params to _V
  _V.v201 = v201
  _V.v202 = v202
  _V.v203 = v203

  local _next_block = 484  -- Line 21923: START AT BLOCK 484 (not block 0!)

  while true do
    if _next_block == 462 then
      -- ... other blocks ...
    else
      if _next_block == 482 then
        _V.v273 = _V.v206[2]  -- Line 22510: Block 482 assigns v273
        -- ...
        if condition then
          _next_block = 483
        else
          _next_block = 484  -- Line 22516: Jump to 484
        end
      else
        if _next_block == 484 then
          _V.v281 = _V.v206[3]
          _V.v282 = _V.v273[2]  -- Line 22552: ERROR! v273 is nil
```

### The Problem in Detail

1. **Closure entry point**: Block 484 (`local _next_block = 484` at line 21923)
2. **Variable dependency**: Block 484 uses `v273` (line 22552: `_V.v282 = _V.v273[2]`)
3. **Variable initialization**: `v273` is initialized to nil at line 21848
4. **Missing assignment**: Block 482 assigns v273 (line 22510), but it's never executed before block 484
5. **Control flow**: There are TWO paths to block 484:
   - Direct entry at function start (line 21923) ❌ v273 is nil
   - From block 482 conditional (line 22516) ✅ v273 would have value

### Why This Happens

**v273 is NOT a block parameter of block 484!**

Looking at the generated code, I don't see any block parameter assignment for v273 in block 484. This means v273 is a variable that:
- Is USED by block 484
- Is ASSIGNED by block 482
- But block 482 is not guaranteed to run before block 484

This suggests the OCaml compiler's IR is creating a closure with:
- Entry point: Block 484
- Block 484 depends on: v273 (should be in block_args)
- But v273 is NOT in block_args OR block 484's parameters

## Root Cause Hypothesis

The issue is likely one of:

1. **Missing block parameter**: Block 484 should have v273 as a parameter, but it doesn't
2. **Wrong entry block**: The closure should start at an earlier block (e.g., block 482) that initializes v273
3. **Missing block_args**: The closure should pass v273 in block_args, but it's not being passed
4. **Control flow assumption**: The IR assumes block 482 always runs before 484, but the generated code starts at 484

## Next Steps for Task 2.4

Need to examine the actual IR to determine:
1. What is the closure's `(pc, block_args)` in the IR?
2. What are block 484's parameters in the IR?
3. Does block 482 come before block 484 in the IR's control flow?
4. How does js_of_ocaml handle this same case?

## Key Findings

1. ✅ Closure generation uses `_V` table for functions with >180 variables
2. ✅ Nested closures inherit parent's `_V` via Lua upvalues
3. ✅ Variables are hoisted and initialized to nil at function start
4. ✅ Entry block parameters are excluded from nil initialization
5. ✅ `arg_passing` is placed BEFORE hoisting in the generated code (line 1292: `arg_passing @ body_stmts`)
6. ❌ **BUG**: Block 484 uses v273 which is not an entry parameter and not initialized by block_args
7. ❌ **BUG**: v273 is only assigned in block 482, which may not run before block 484

## Comparison: Working vs Failing Cases

### Working: test_closure_3level.ml
- 12,783 lines generated
- Simple closure structure
- Entry blocks don't have complex dependencies
- All variables initialized properly

### Failing: test_printf.ml
- 24,441 lines generated
- Complex Printf CPS structure
- Entry block 484 depends on variables from block 482
- Variables not properly initialized at entry

## Files Examined

- `compiler/lib-lua/lua_generate.ml`: Lines 44-57, 156-180, 962-1012, 1023-1298
- `/tmp/test_printf_out.lua`: Lines 12631, 21770-21925, 22500-22560
- `/tmp/test_closure_3level.lua`: Working comparison case

## Conclusion

The bug is NOT a general closure problem. It's specific to:
- Closures with entry blocks at non-zero addresses (e.g., block 484)
- Entry blocks that use variables not in their parameter list
- Variables that should be initialized by earlier blocks that don't run
- Missing initialization of variables needed by entry blocks

**The fix will require either:**
1. Ensuring block_args properly initialize all variables used by entry blocks
2. Selecting different entry blocks that don't have such dependencies
3. Adding fallback initialization for variables used but not defined in entry blocks
4. Analyzing control flow to detect this pattern and insert proper initialization

**Next**: Task 2.4 will compare with js_of_ocaml to see how JavaScript handles this case.
