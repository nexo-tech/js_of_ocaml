# Phase 3 Task 3.1: Find Parameter Passing in lua_generate.ml

**Date**: 2025-10-14
**Status**: Complete

---

## Lua Code Generator Overview

**File**: `compiler/lib-lua/lua_generate.ml` (3,136 lines)

**Main Functions for Parameter Passing**:
1. `setup_hoisted_variables` (line 1666) - Initialize variables with hoisting
2. `setup_function_parameters` (line 1735) - Copy function params to `_V` table
3. `setup_entry_block_arguments` (line 1744) - Assign entry block arguments to parameters
4. `build_assignments` (line 1749) - Build assignment statements for parameters

---

## Parameter Passing Pipeline

### Execution Order (line 1951):
```ocaml
hoist_stmts @ param_copy_stmts @ entry_arg_stmts @ dispatch_loop_stmts
```

**Generated Code Structure**:
```lua
-- 1. hoist_stmts: Initialize variables
local _V = {}
_V.var1 = nil
_V.var2 = nil
-- ...

-- 2. param_copy_stmts: Copy function parameters to _V
_V.param1 = param1
_V.param2 = param2

-- 3. entry_arg_stmts: Initialize entry block parameters
-- Initialize entry block parameters from block_args (Fix for Printf bug!)
-- Entry block arg: entry_param1 = arg1 (local param)
_V.entry_param1 = arg1
_V.entry_param2 = arg2

-- 4. dispatch_loop_stmts: Actual function body
while true do
  -- Block execution
end
```

---

## Key Function: `setup_hoisted_variables` (line 1666)

```ocaml
and setup_hoisted_variables ctx program start_addr =
  let hoisted_vars = collect_block_variables ctx program start_addr in
  let loop_headers = detect_loop_headers program start_addr in

  let loop_block_params = ... in
  let entry_block_params = ... in

  let all_hoisted_vars = StringSet.union hoisted_vars loop_block_params in

  let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params in
  let init_stmts =
    StringSet.elements vars_to_init
    |> List.map ~f:(fun var ->
        L.Assign ([ L.Dot (L.Ident var_table_name, var) ], [ L.Nil ]))
  in
  ...
```

**Critical Line 1701**:
```ocaml
let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params in
```

This EXCLUDES entry_block_params from initialization!

**Result**: Entry block parameters are NOT initialized to nil in the hoisting step.

---

## Key Function: `setup_entry_block_arguments` (line 1744)

```ocaml
and setup_entry_block_arguments ctx program start_addr entry_args func_params =
  if not (List.is_empty entry_args) then
    match Code.Addr.Map.find_opt start_addr program.Code.blocks with
    | None -> []
    | Some block ->
        let rec build_assignments args params acc =
          match args, params with
          | [], [] -> List.rev acc
          | arg_var :: rest_args, param_var :: rest_params ->
              let arg_expr = var_ident ctx arg_var in
              let param_target = var_ident ctx param_var in
              let assignment = L.Assign ([param_target], [arg_expr]) in
              build_assignments rest_args rest_params (assignment :: acc)
        in
        let assignments = build_assignments entry_args block.Code.params [] in
        [ L.Comment "Initialize entry block parameters from block_args (Fix for Printf bug!)" ]
        @ assignments
```

**Key Line 1768**:
```ocaml
let assignment = L.Assign ([param_target], [arg_expr]) in
```

Generates: `_V.param_name = arg_value`

**Issue**: If `param_name` was excluded from hoisting (line 1701), this assignment creates the field dynamically in Lua (which is allowed).

---

## Variable Collection: `collect_block_variables` (line 1162)

```ocaml
and collect_block_variables ctx program start_addr =
  (* Collect DEFINED variables from all reachable blocks *)
  let defined_vars = ... in

  (* Collect USED variables from all reachable blocks *)
  let used_vars = ... in

  (* Get entry block parameters to exclude from free vars *)
  let entry_params = ... in

  (* Free variables = USED - DEFINED - PARAMETERS *)
  let free_vars =
    Code.Var.Set.diff (Code.Var.Set.diff used_vars defined_vars) entry_params
  in

  (* Return DEFINED ∪ FREE as StringSet *)
  let all_vars = Code.Var.Set.union defined_vars free_vars in
  ...
```

**Key Line 1237**:
```ocaml
let free_vars = Code.Var.Set.diff (Code.Var.Set.diff used_vars defined_vars) entry_params
```

Entry block parameters are explicitly EXCLUDED from free_vars!

**Result**: Entry block parameters are NOT included in `hoisted_vars`.

---

## The Problem: Entry Block Parameters Not Hoisted

### Flow

1. `collect_block_variables` returns: `DEFINED ∪ FREE` (line 1241)
   - Entry params are excluded from `FREE` (line 1237)
   - Result: Entry params NOT in hoisted_vars

2. `setup_hoisted_variables` creates: `all_hoisted_vars = hoisted_vars ∪ loop_block_params` (line 1690)
   - Entry params still NOT included

3. Variables to initialize: `vars_to_init = all_hoisted_vars - entry_block_params` (line 1701)
   - This diff does nothing since entry params weren't in all_hoisted_vars anyway
   - Result: Entry params NOT initialized

4. `setup_entry_block_arguments` generates assignments: `_V.param = arg` (line 1768)
   - This dynamically creates the field in Lua's `_V` table
   - **But**: If `arg` itself is an entry param from outer scope, it might not exist!

### Potential Bug Scenario

For Printf with nested closures:

```ocaml
(* Outer closure *)
let outer fmt =
  (* Entry param: fmt *)

  (* Inner closure *)
  fun arg ->
    (* Entry params: fmt (from outer), arg *)
    caml_format_int(fmt, arg)
```

**Generated Lua (current)**:
```lua
-- Outer closure
function(fmt)
  local _V = {}
  -- fmt NOT initialized (excluded as entry param)

  -- Entry block assignment
  _V.fmt = fmt  -- OK, fmt is function parameter

  -- Inner closure
  return function(arg)
    local parent_V = _V
    local _V = setmetatable({}, {__index = parent_V})
    -- arg NOT initialized

    -- Entry block assignment (THIS IS THE PROBLEM!)
    _V.fmt = fmt  -- ERROR: fmt not in inner _V, tries to access via __index
    _V.arg = arg  -- OK, arg is function parameter

    -- Call formatter
    caml_format_int(_V.fmt, _V.arg)  -- _V.fmt might be nil!
  end
end
```

**The Issue**: When inner closure tries to assign `_V.fmt = fmt`, it looks up `fmt` in the current scope, which uses `__index` to search parent_V. But if the assignment happens incorrectly, `fmt` might not be found.

---

## Comparison with JS

**JS (compiler/lib/generate.ml:981)**:
```ocaml
let parallel_renaming ctx loc back_edge params args continuation queue =
  (* Generate variable declarations BEFORE continuation *)
  let renaming =
    if back_edge
    then List.map renaming ~f:(fun (t, e) ->
            J.Expression_statement (J.EBin (J.Eq, J.EVar (J.V t), e)), loc)
    else List.map renaming ~f:(fun (t, e) ->
            J.variable_declaration [J.V t, (e, loc)], loc)
  in
  let never, code = continuation queue in
  never, List.rev_append before (List.rev_append renaming code)
```

**Key Difference**:
- JS: `J.variable_declaration` - Creates NEW variable declarations
- Lua: `L.Assign` - Only assigns to existing variables

**JS generates**:
```javascript
var param1 = arg1;  // NEW variable declaration
var param2 = arg2;  // NEW variable declaration
// ... then block body
```

**Lua generates**:
```lua
_V.param1 = arg1  -- Assignment (assumes param1 exists in _V)
_V.param2 = arg2  -- Assignment (assumes param2 exists in _V)
-- ... then block body
```

---

## Root Cause Hypothesis

**Issue**: Entry block parameters are not properly initialized in the hoisting phase, relying on dynamic field creation in `_V` table. This works for simple cases but may fail when:
1. Parameters from outer closures need to be passed through multiple levels
2. The `__index` metatable lookup chain is broken
3. Parameter names conflict or are looked up in wrong scope

**Next Task**: Generate comparison examples to verify this hypothesis with actual Printf code.

---

## Summary

Found Lua parameter passing mechanism:
- ✅ `setup_hoisted_variables` - Initializes vars (excludes entry params)
- ✅ `setup_entry_block_arguments` - Assigns entry args to params
- ✅ Execution order: hoist → param_copy → entry_args → dispatch

**Key Difference from JS**:
- JS: `var param = arg;` (declares new variable)
- Lua: `_V.param = arg` (assigns to existing field)

**Hypothesis**: Entry params not being hoisted causes issues with nested closures and Printf's CPS pattern.

**Next**: Generate comparison examples to verify.
