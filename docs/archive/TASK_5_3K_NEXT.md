# Task 5.3k - Next Investigation Required
**Date**: 2025-10-15
**Status**: Dispatch infrastructure COMPLETE, but new issue found

## Current Status

✅ **Fixed**: All dispatch blocks have cases (0 missing)
✅ **Working**: Printf %d, %s formats
❌ **Still Hangs**: Printf %f format

## New Issue Discovered

**Symptom**: Printf %f causes infinite loop between blocks 572 ↔ 573

**Evidence from Execution Trace**:
```
[572][573][572][573][572][573][572][573]...
```

**Expected Flow** (from generated code):
```lua
Case 8 (float):
  if type(v352) == "number" then
    _next_block = 573
  else
    _next_block = 572
  end

Block 572:
  if v352[1] == 0 then
    _next_block = 578
  else
    _next_block = 583
  end

Block 573:
  if is_integer(v351) then
    _next_block = 574
  else
    _next_block = 577
  end
```

**All Target Blocks Verified to Have Dispatch Cases**:
- Block 574: ✓ (1 dispatch case)
- Block 577: ✓ (1 dispatch case)
- Block 578: ✓ (1 dispatch case)
- Block 583: ✓ (1 dispatch case)

## Hypothesis

Blocks 572/573 are executing and setting `_next_block` to their successors (574, 577, 578, 583), but instead of continuing to those blocks, the while loop is restarting from the top.

**Possible Causes**:
1. **Missing continuation after case 8**: Case 8 runs, sets `_next_block`, but then loop restarts instead of continuing
2. **Incorrect loop structure**: Continuation dispatch might not include blocks 572/573 properly
3. **Entry logic re-runs**: After block 572/573 executes, entry dispatcher logic runs again

## Investigation Plan

### 1. Check Loop Structure
Verify that blocks 572/573 are in the continuation dispatch section (with `_next_block` checks), not regenerated in entry logic.

```bash
# Find which section contains blocks 572/573
awk '/_next_block = -1/ { section="entry" }
     /if _V.v405 ==/ { section="switch" }
     /if _next_block == 572/ { print "Block 572 in: " section }
     /if _next_block == 573/ { print "Block 573 in: " section }' generated.lua
```

### 2. Check What Happens After Block 573 Sets _next_block
Add trace AFTER the `_next_block = 574` assignment to see if it continues or loops.

### 3. Compare with JS
The JS uses labeled breaks (`break f`) while Lua uses `_next_block` dispatch. Need to verify the translation is correct.

**JS Pattern**:
```javascript
case 8:
  // Extract format fields
  var k = f[4], m = f[3], p = f[2], j = f[1];
  break d;  // Break to label d, continue inline

// After switch (inline continuation):
d: {
  // ... complex logic ...
  return function(b){return a(i, [4, h, o(j, C(j), b)], k);};
}
```

**Lua Pattern** (expected):
```lua
if v405 == 8 then
  v350 = v481[5]  -- k (continuation)
  v351 = v481[4]  -- m (precision)
  v352 = v481[3]  -- p (padding)
  v353 = v481[2]  -- j (format spec)
  _next_block = 573 or 572  -- Jump to continuation
end

-- Continuation blocks should process and RETURN closure
```

### 4. Check for Back-Edges
Verify that blocks 572-583 don't have back-edges to entry that would restart the loop.

```ocaml
(* In collect_continuation_blocks, check successors *)
| Code.Branch (next, _) when next = entry_addr ->
    (* This is a back-edge! Should not set _next_block *)
```

## Quick Test

Simplify the test to isolate the issue:

```ocaml
(* Test just float formatting, no Printf *)
let () =
  let fmt_spec = [0, 0, 0] in  (* Minimal format spec *)
  let prec = 6 in
  let value = 3.14 in
  (* Try to call formatter directly if possible *)
  ()
```

## Files to Check

- `compiler/lib-lua/lua_generate.ml:2247-2316` - Continuation dispatch generation
- `compiler/lib-lua/lua_generate.ml:2098-2157` - Switch case generation
- `/tmp/test_float_GOOD.lua:23250-26260` - The actual dispatch loop with blocks 572/573

## Likely Fix

Based on pattern, likely need to ensure blocks 572/573 are NOT generating back-edges to entry and that the continuation dispatch properly chains to successor blocks.

May need to check if blocks 574, 577, 578, 583 are actually being reached or if there's a structural issue preventing control flow from continuing.

## Test Command

```bash
# Add manual trace
sed -i 's/if _next_block == 572 then/io.stderr:write("[ENTER-572]\\n") if _next_block == 572 then/' test.lua
sed -i 's/_next_block = 578/_next_block = 578 io.stderr:write("[SET-578]\\n")/' test.lua
timeout 1 lua test.lua 2>&1 | head -50
```
