# XPLAN Phase 3 Task 3.7: Fix Implementation Design

## Status: ✅ COMPLETE

## Objective
Design the complete fix for variable shadowing bug in nested closures

## Fix Overview

**Problem**: Nested closures initialize ALL variables (including captured ones) to nil, shadowing parent values

**Solution**: Only initialize DEFINED variables in nested closures; let FREE variables be captured via __index

## Implementation Plan

### Step 1: Modify `collect_block_variables` Return Type

**File**: `compiler/lib-lua/lua_generate.ml`
**Location**: Lines 1162-1250
**Current**: Returns `StringSet.t` (all hoisted vars)
**New**: Returns `(StringSet.t * StringSet.t)` (defined_vars, free_vars)

```ocaml
(** Collect variables that need to be hoisted.
    Returns (defined_vars, free_vars) where:
    - defined_vars: variables assigned/defined in this closure
    - free_vars: variables used but not defined (captured from parent)
*)
and collect_block_variables ctx program start_addr : (StringSet.t * StringSet.t) =
  (* ... existing logic to compute defined_vars and free_vars ... *)

  (* Convert Code.Var.Set to StringSet *)
  let defined_names =
    Code.Var.Set.fold
      (fun var acc -> StringSet.add (var_name ctx var) acc)
      defined_vars
      StringSet.empty
  in
  let free_names =
    Code.Var.Set.fold
      (fun var acc -> StringSet.add (var_name ctx var) acc)
      free_vars
      StringSet.empty
  in
  (defined_names, free_names)
```

**Changes**:
- Line 1246: Replace `let all_vars = ...` with separate conversions
- Lines 1247-1250: Convert both `defined_vars` and `free_vars` to StringSets
- Return tuple instead of single set

### Step 2: Update `setup_hoisted_variables` to Use Separate Sets

**File**: `compiler/lib-lua/lua_generate.ml`
**Location**: Lines 1666-1732

```ocaml
and setup_hoisted_variables ctx program start_addr =
  (* NEW: Get defined and free vars separately *)
  let (defined_vars, free_vars) = collect_block_variables ctx program start_addr in

  let loop_headers = detect_loop_headers program start_addr in

  let loop_block_params =
    Code.Addr.Set.fold
      (fun addr acc ->
        match Code.Addr.Map.find_opt addr program.Code.blocks with
        | None -> acc
        | Some block ->
            List.fold_left block.Code.params ~init:acc ~f:(fun acc param ->
              StringSet.add (var_name ctx param) acc))
      loop_headers
      StringSet.empty
  in

  let entry_block_params =
    match Code.Addr.Map.find_opt start_addr program.Code.blocks with
    | None -> StringSet.empty
    | Some block ->
        List.fold_left block.Code.params ~init:StringSet.empty ~f:(fun acc param ->
          StringSet.add (var_name ctx param) acc)
  in

  (* All hoisted vars = defined + free + loop params *)
  let all_hoisted_vars =
    StringSet.union (StringSet.union defined_vars free_vars) loop_block_params
  in
  let total_vars = StringSet.cardinal all_hoisted_vars in
  let use_table =
    if ctx.inherit_var_table then ctx.use_var_table
    else should_use_var_table total_vars
  in
  ctx.use_var_table <- use_table;

  let hoist_stmts =
    if StringSet.is_empty all_hoisted_vars then []
    else if use_table then
      (* CRITICAL FIX: Different logic for nested vs top-level closures *)
      let vars_to_init =
        if ctx.inherit_var_table then
          (* NESTED CLOSURE: Only initialize DEFINED vars + loop params
             Exclude FREE vars - they'll be captured from parent via __index *)
          let local_vars = StringSet.union defined_vars loop_block_params in
          StringSet.diff local_vars entry_block_params
        else
          (* TOP-LEVEL: Initialize all vars (no parent to capture from) *)
          StringSet.diff all_hoisted_vars entry_block_params
      in

      let init_stmts =
        StringSet.elements vars_to_init
        |> List.map ~f:(fun var ->
            L.Assign ([ L.Dot (L.Ident var_table_name, var) ], [ L.Nil ]))
      in

      if ctx.inherit_var_table then
        (* Create new _V table with metatable for lexical scope *)
        [ L.Comment (Printf.sprintf "Hoisted variables (%d total: %d defined, %d free, %d loop params)"
            total_vars
            (StringSet.cardinal defined_vars)
            (StringSet.cardinal free_vars)
            (StringSet.cardinal loop_block_params))
        ; L.Local ([ "parent_V" ], Some [ L.Ident var_table_name ])
        ; L.Local ([ var_table_name ], Some [
            L.Call (L.Ident "setmetatable",
              [ L.Table []
              ; L.Table [ L.Rec_field ("__index", L.Ident "parent_V") ]
              ])
          ])
        ] @ init_stmts
      else
        [ L.Comment (Printf.sprintf "Hoisted variables (%d total)" total_vars)
        ; L.Local ([ var_table_name ], Some [ L.Table [] ])
        ] @ init_stmts
    else
      (* Not using _V table - use local variables *)
      let vars_to_init =
        if ctx.inherit_var_table then
          (* NESTED: Only define local vars, free vars come from outer scope *)
          StringSet.diff defined_vars entry_block_params
        else
          (* TOP-LEVEL: Define all *)
          StringSet.diff all_hoisted_vars entry_block_params
      in
      let var_list = StringSet.elements vars_to_init |> List.sort ~cmp:String.compare in
      if StringSet.is_empty vars_to_init then
        [ L.Comment (Printf.sprintf "Hoisted variables (%d total)" total_vars) ]
      else
        [ L.Comment (Printf.sprintf "Hoisted variables (%d total: %d defined, %d free)"
            total_vars
            (StringSet.cardinal defined_vars)
            (StringSet.cardinal free_vars))
        ; L.Local (var_list, None)
        ]
  in
  (hoist_stmts, use_table)
```

**Key Changes**:
- Line 1667: `collect_block_variables` now returns tuple, destructure it
- Line 1690: Compute `all_hoisted_vars` from separate sets
- Line 1701-1714: **CRITICAL FIX** - Different `vars_to_init` for nested vs top-level
  - Nested: `defined_vars + loop_block_params - entry_block_params` (excludes free_vars!)
  - Top-level: `all_hoisted_vars - entry_block_params` (includes free_vars)
- Lines 1709, 1726: Enhanced comments showing defined/free/loop split
- Line 1723-1729: Apply same logic to non-table case

### Step 3: Update Call Sites

**Call Site 1**: Line 1991 in `compile_func_decl`
```ocaml
(* Before *)
let hoisted_vars = collect_block_variables ctx program start_addr in

(* After *)
let (defined_vars, free_vars) = collect_block_variables ctx program start_addr in
let hoisted_vars = StringSet.union defined_vars free_vars in
```

**Call Site 2**: Any debug/logging code at line ~2025
```ocaml
(* Update to use separate sets if needed for debugging *)
Format.eprintf "DEBUG collect_block_variables at addr %d: %d defined, %d free@."
  start_addr
  (StringSet.cardinal defined_vars)
  (StringSet.cardinal free_vars)
```

Search for all occurrences:
```bash
grep -n "collect_block_variables" compiler/lib-lua/lua_generate.ml
```

### Step 4: Testing Strategy

#### Test 1: Printf with %d (Primary test case)
```bash
just quick-test /tmp/test4.ml
```

Expected output:
```
Value: 42
```

**Verification**: Look at generated Lua to confirm free vars NOT initialized:
```bash
grep -A 10 "Hoisted variables" /tmp/test4.lua | grep "v268\|v21"
```

Should see comment showing defined/free split, and `v268`/`v21` NOT in init statements.

#### Test 2: Nested closures without Printf
```ocaml
let outer x =
  fun y ->
    fun z -> x + y + z

let () =
  let f = outer 10 in
  let g = f 20 in
  let result = g 30 in
  Printf.printf "%d\n" result
```

Expected: `60`

#### Test 3: Multiple nesting levels
```ocaml
let level1 x =
  fun level2 y ->
    fun level3 z ->
      fun level4 w -> x + y + z + w

let () =
  Printf.printf "%d\n" (level1 1 2 3 4)
```

Expected: `10`

#### Test 4: Existing test suite
```bash
just test-lua
```

Should pass all existing tests without regression.

### Step 5: Expected Generated Code Comparison

#### Before Fix (BUG):
```lua
_V.v273 = caml_make_closure(1, function(v274)
  -- Hoisted variables (5 total, using own _V table for closure scope)
  local parent_V = _V
  local _V = setmetatable({}, {__index = parent_V})
  _V.v21 = nil        -- ❌ BUG: Shadows parent's stdout
  _V.v268 = nil       -- ❌ BUG: Shadows parent's format function
  _V.v274 = nil       -- Function parameter
  _V.v314 = nil       -- Local variable
  _V.v315 = nil       -- Local variable
  _V.v274 = v274
  -- ... rest of closure ...
end)
```

#### After Fix (CORRECT):
```lua
_V.v273 = caml_make_closure(1, function(v274)
  -- Hoisted variables (5 total: 3 defined, 2 free, 0 loop params)
  local parent_V = _V
  local _V = setmetatable({}, {__index = parent_V})
  _V.v274 = nil       -- ✅ Function parameter (will be assigned)
  _V.v314 = nil       -- ✅ Local variable
  _V.v315 = nil       -- ✅ Local variable
  -- v21 and v268 NOT initialized - captured from parent_V via __index ✅
  _V.v274 = v274
  -- ... rest of closure ...
  _V.v314 = _V.v268(_V.v21, _V.v274)  -- ✅ Now finds parent values!
end)
```

## Verification Checklist

- [ ] Modify `collect_block_variables` to return tuple
- [ ] Update `setup_hoisted_variables` with conditional logic
- [ ] Update call site at line 1991
- [ ] Check for other call sites
- [ ] Build: `just build-lua-all`
- [ ] Test Printf: `just quick-test /tmp/test4.ml`
- [ ] Test suite: `just test-lua`
- [ ] Verify generated code: Check that free vars not initialized in nested closures
- [ ] Commit with message: "fix(lua): prevent variable shadowing in nested closures"

## Risk Assessment

**Low Risk Changes**:
- `collect_block_variables` already computed defined/free separately
- Just changing return type to expose existing information
- Backward compatible (can reconstruct old behavior with union)

**Medium Risk Changes**:
- Conditional logic in `setup_hoisted_variables`
- Need to ensure top-level closures still work correctly
- Need to handle loop_block_params correctly

**Testing Required**:
- Printf test suite (primary target)
- Nested closure tests (various depths)
- Existing test suite (regression check)
- Edge cases: top-level closures, loops, exception handlers

## Expected Impact

**What Should Change**:
- Printf with format specifiers should work
- Nested closures accessing parent variables should work
- Generated Lua code will be cleaner (fewer nil initializations)

**What Should NOT Change**:
- Top-level closures (no parent scope) unchanged
- Non-closure code paths unchanged
- Existing working tests should continue to pass

## Next Steps

Proceed to Phase 4: Implementation of the fix based on this design.
