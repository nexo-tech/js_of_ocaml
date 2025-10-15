# Task 5.3k.1 - Printf Float Format Hang - Complete Summary
**Date**: 2025-10-14
**Status**: FIX IMPLEMENTED - Compilation issue blocking test

## Problem
`Printf.printf "%f\n" 3.14` causes infinite loop in generated Lua code.

## Investigation Timeline

### Phase 1: Initial Analysis (Tasks 5.3a-j)
- Identified blocks 572/573 referenced but not generated
- Initially thought fix would be complex (6-12 hours)
- User redirected to debug actual root cause

### Phase 2: Debug Investigation (Task 5.3k)
- Added comprehensive debug tracing
- Found blocks 572-597 ARE collected by continuation logic
- But blocks 594, 595, 598-602 referenced by block 592 are MISSING

### Phase 3: Root Cause Discovery
**Key Finding**: Block 592 has Switch terminator branching to blocks 594, 595, 598-602.
These blocks **DON'T EXIST** in `program.Code.blocks` map.

**Evidence from generated Lua** (`/tmp/quick_test.lua:24063`):
```lua
if _next_block == 592 then
  _V.v353 = _V.v359[1] or 0
  if _V.v353 == 0 then
    _next_block = 594  -- ❌ No dispatch case for 594
  else if _V.v353 == 1 then
    _next_block = 595  -- ❌ No dispatch case for 595
  ...
  else if _V.v353 == 2 or _V.v353 == 4 then
    _next_block = 601  -- ❌ No dispatch case for 601
```

**Why This Happens**:

1. **Address-based dispatch** (`compile_address_based_dispatch`):
   ```ocaml
   let rec collect_reachable visited addr =
     match Code.Addr.Map.find_opt addr program.Code.blocks with
     | None -> visited  -- Silently skips missing blocks!
     | Some block ->
         let successors = match block.Code.branch with
           | Code.Switch (_, conts) -> Array.to_list conts |> List.map ~f:fst
   ```

2. **Later, generate_last_dispatch** generates code for ALL Switch targets:
   ```ocaml
   | Code.Switch (var, conts) ->
       let grouped = group_by_continuation conts in
       let cases = List.map grouped ~f:(fun (addr, args, indices) ->
         (* Generates: if v353 == 0 then _next_block = 594 *)
   ```

3. **Result**: Code sets `_next_block = 601` but no `if _next_block == 601` exists → infinite loop

## The Fix

**Location**: `compiler/lib-lua/lua_generate.ml:2816-2854`

**Strategy**: Filter out Switch targets that don't exist before generating dispatch code.

**Implementation**:
```ocaml
(* After grouping Switch cases, filter non-existent blocks *)
let grouped_filtered =
  match ctx.program with
  | None -> grouped
  | Some program ->
      List.filter grouped ~f:(fun (addr, _args, _indices) ->
        Code.Addr.Map.mem addr program.Code.blocks)
in

(* Use filtered list for case generation *)
let cases = List.map grouped_filtered ~f:(fun (addr, args, indices) ->
```

**Rationale**:
- Matches behavior of `collect_reachable` which skips non-existent blocks
- Prevents generating `_next_block = X` for blocks that have no dispatch case
- Aligns with JS compiler behavior where unreachable blocks are simply not generated

## Current Blocker

**Compilation Error**: `Sys_error("Invalid argument")` when compiling ANY file.

**Symptoms**:
```bash
$ echo 'let x = 42' > /tmp/test.ml
$ ocamlc -c /tmp/test.ml
$ lua_of_ocaml.exe compile /tmp/test.cmo -o /tmp/test.lua
Error: Sys_error("Invalid argument")
```

**Investigation**:
- Error exists even WITHOUT the Switch filter fix
- Likely introduced in earlier debugging commits (a7f4a9b9 to fc9f7db0)
- Need to bisect to find the breaking change

## Files Modified

### Implemented Fix (not yet committed)
- `compiler/lib-lua/lua_generate.ml` lines 2816-2854
  - Added `grouped_filtered` with non-existent block filtering
  - Changed `List.map grouped` to `List.map grouped_filtered`

### Already Committed
- `3c9b4c85`: Fixed test signatures for `collect_block_variables` tuple return
- `e2d7c829`: Added debug infrastructure (disabled by default)
- `fc9f7db0`: Created root cause analysis document

## Testing Plan (Once Compilation Fixed)

### 1. Verify Compilation Works
```bash
echo 'let x = 42' > /tmp/test.ml
ocamlc -c /tmp/test.ml
lua_of_ocaml compile /tmp/test.cmo -o /tmp/test.lua
lua /tmp/test.lua  # Should complete without error
```

### 2. Test Float Format
```bash
# Should complete in <1 second, print "3.140000"
timeout 5 just quick-test /tmp/test_float.ml
```

### 3. Regression Tests
```bash
# All Printf formats should work
just test-lua  # Should pass all tests
```

### 4. Verify Generated Code
```bash
# Check that non-existent blocks are NOT in dispatch
grep "if _next_block == 601" /tmp/quick_test.lua  # Should find nothing
grep "if _next_block == 594" /tmp/quick_test.lua  # Should find nothing
```

## Alternative Approaches (if needed)

### Option B: Generate Break Stubs
Instead of filtering, generate stub cases that break:
```lua
if _next_block == 601 then
  -- Block doesn't exist in IR
  break
end
```

### Option C: Modify Switch Code Generation
Change how Switch generates `_next_block` assignments to skip non-existent blocks entirely.

### Option D: Deep Investigation
Examine OCaml Printf stdlib source to understand why Switch references non-existent blocks.

## Key Insights

1. **Same bug in both dispatch modes**: Address-based AND data-driven have identical issue
2. **Collection vs Generation mismatch**: Collection skips, generation doesn't
3. **Fix is simple**: Just filter before generating (10 lines of code)
4. **Not a closure issue**: Blocks truly don't exist anywhere in IR

## References

- Root cause analysis: `task_5_3k_root_cause.md`
- Fix plan: `task_5_3k_fix_plan.md`
- Generated Lua example: `/tmp/quick_test.lua` line 24063
- Test case: `/tmp/test_float.ml`

## Next Actions

1. ✅ Root cause identified
2. ✅ Fix implemented
3. ⏳ Fix compilation issue (current priority)
4. ⏳ Test fix
5. ⏳ Update XPLAN.md
6. ⏳ Commit and document
