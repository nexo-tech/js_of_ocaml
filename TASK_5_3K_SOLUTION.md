# Task 5.3k - Solution Strategy
**Date**: 2025-10-15
**Status**: Root cause FULLY understood, fix strategy identified

## The Real Problem

**Trace Evidence**: [572][573][572][573]... infinite loop

**Root Cause**: Switch statement runs on EVERY while loop iteration, overwriting `_next_block`.

### Current Structure (BROKEN)
```lua
while true do
  -- Entry: type check, return if integer
  v405 = v481[1]

  -- Switch on tag (RUNS EVERY ITERATION!)
  if v405 == 0 then create_closure(); return end
  elseif v405 == 8 then _next_block = 573 end  -- Sets _next_block
  ...

  -- Continuation dispatch
  if _next_block == 572 then _next_block = 578 end
  elseif _next_block == 573 then _next_block = 574 end  -- Executes, sets 574
  ... (chain completes)

  -- Loop iterates, switch runs AGAIN, overwrites 574 with 573!
end
```

**Why %d Works**: Case 4 returns immediately, never reaches continuation.
**Why %f Fails**: Case 8 sets `_next_block`, loop continues, switch overwrites it.

## Solution

### Option 1: Guard Switch with _next_block Check (RECOMMENDED)
Only run switch when `_next_block` is not set:

```ocaml
(* In compile_data_driven_dispatch *)
let switch_with_guard =
  (* Only run switch on first iteration, not when continuing from continuation *)
  let guard_condition = L.BinOp (L.Eq, L.Ident "_next_block", L.Nil) in
  [ L.If (guard_condition, switch_stmt, None) ]
in

let loop_body = entry_dispatcher_stmts @ switch_with_guard @ continuation_dispatch in
```

Initialize `_next_block = nil` before loop, switch sets it, continuation uses it.

### Option 2: Use Local Variable for First Iteration Flag
```lua
local first_iteration = true
while true do
  if first_iteration then
    -- Entry and switch
    first_iteration = false
  else
    -- Continuation dispatch only
  end
end
```

### Option 3: Restructure as Nested While Loops
```lua
-- Outer: Entry logic
while true do
  v405 = v481[1]
  if v405 == 8 then
    -- Inner: Continuation dispatch
    local _next_block = 573
    while _next_block do
      if _next_block == 572 then ...
    end
  end
end
```

### Option 4: Match JS Inline Pattern (COMPLEX)
JS uses labeled break to exit switch and continue inline. We'd need to inline the continuation logic instead of using dispatch loop.

## Recommended Approach

**Option 1** with nil check:

```ocaml
(* Initialize _next_block to nil before loop *)
let init_next_block = [ L.Assign ([L.Ident "_next_block"], [L.Nil]) ] in

(* Guard switch: only run when _next_block is nil *)
let switch_guarded =
  match switch_stmt with
  | [] -> []
  | _ ->
      let condition = L.BinOp (L.Eq, L.Ident "_next_block", L.Nil) in
      [ L.If (condition, switch_stmt, None) ]
in

let loop_body = entry_dispatcher_stmts @ switch_guarded @ continuation_dispatch in
let dispatch_loop = [ L.While (L.Bool true, loop_body) ] in

hoist_stmts @ param_copy_stmts @ entry_arg_stmts @ init_next_block @ dispatch_loop
```

**Why this works**:
1. First iteration: `_next_block = nil`, switch runs, case 8 sets `_next_block = 573`
2. Continuation dispatch: Executes block 573, sets `_next_block = 574`
3. Second iteration: `_next_block = 574` (not nil!), switch SKIPPED, continuation runs block 574
4. Continues until a block returns or loops properly

**Matches js_of_ocaml**: JS uses labeled break to skip switch on continuation, we use nil check.

## Implementation

File: `compiler/lib-lua/lua_generate.ml`
Function: `compile_data_driven_dispatch`
Lines: ~2280-2292

## Test Plan

```bash
just build-lua-all
just quick-test test_int.ml  # Should still work
just quick-test test_float.ml  # Should print 3.140000 or error about unimplemented formatter
```

## Alternative If Option 1 Fails

Check address-based dispatch to see how it handles similar patterns, or examine js_of_ocaml's code generation for Printf case 8 more carefully.
