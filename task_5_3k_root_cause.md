# Task 5.3k.1 - Root Cause Analysis
**Date**: 2025-10-14
**Status**: ROOT CAUSE IDENTIFIED - Ready for fix implementation

## Problem Summary
Printf `%f` format causes infinite loop in generated Lua code.

## Root Cause Discovered

### Evidence from Generated Lua
Block 592 exists and has dispatch case:
```lua
if _next_block == 592 then
  _V.v353 = _V.v359[1] or 0
  if _V.v353 == 0 then
    _next_block = 594  -- ❌ Block 594 has NO dispatch case
  else if _V.v353 == 1 then
    _next_block = 595  -- ❌ Block 595 has NO dispatch case
  ...
  else if _V.v353 == 2 or _V.v353 == 4 then
    _next_block = 601  -- ❌ Block 601 has NO dispatch case
```

Verified: Blocks 594, 595, 598-602 have NO dispatch cases (`if _next_block == X`)

### Why This Happens

1. **Block 592 IS collected** - has dispatch case at line 24063
2. **Block 592's IR has Switch terminator** - branches to: 594, 595, 598-602
3. **These target blocks DON'T EXIST in program.Code.blocks map**
4. **Collection logic silently skips non-existent blocks**:
   ```ocaml
   match Code.Addr.Map.find_opt addr program.Code.blocks with
   | None -> collect_continuation_blocks visited rest  -- Skips!
   ```
5. **Code generator still generates `_next_block = X` assignments** from Switch
6. **While loop continues, finds NO matching case** → infinite loop

## Why Blocks Missing from IR

Blocks 594, 595, 598-602 don't exist as standalone blocks because they're:
- Pseudo-blocks (Switch targets that don't have block bodies)
- Optimized away by OCaml compiler
- Inlined into the Switch logic
- Part of a different scope/closure

## Fix Strategy

### Option 1: Filter Non-Existent Blocks (Quick Fix)
When generating Switch dispatch code, skip targets that don't exist:
```ocaml
let valid_targets = targets |> List.filter ~f:(fun addr ->
  Code.Addr.Map.mem addr program.Code.blocks
) in
```

**Problem**: Might break semantics if those blocks should execute

### Option 2: Generate Stub Dispatch Cases
For missing blocks, generate stub cases that break/continue:
```lua
if _next_block == 594 then
  -- Stub for missing block
  break
```

**Problem**: Might not match intended behavior

### Option 3: Deep Investigation
1. Check if blocks exist in parent/child closure
2. Examine OCaml Printf stdlib source to understand block structure
3. Compare with JS implementation's handling

**Problem**: Time-consuming (several hours)

### Option 4: Change Switch Code Generation
Instead of generating `_next_block = X`, generate inline code or direct break:
```lua
if _V.v353 == 0 then
  break  -- or return, or fall through
```

**Recommended**: Option 1 first (quick test), then Option 4 if needed

## Next Steps

1. **Implement Option 1**: Filter non-existent blocks when generating Switch
2. **Test**: Compile test_float.ml and verify it doesn't hang
3. **If still hangs**: Implement Option 4 (change Switch generation)
4. **Verify**: All Printf formats work (%d, %s, %f, %e, %g)
5. **Commit**: Document fix and test results

## Code Locations

- Collection logic: `compiler/lib-lua/lua_generate.ml:1841` (`collect_continuation_blocks`)
- Switch generation: `compiler/lib-lua/lua_generate.ml:~2150` (`generate_last_dispatch`)
- Test case: `/tmp/test_float.ml` - `Printf.printf "%f\n" 3.14`
