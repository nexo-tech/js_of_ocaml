# Task 5.3k.3 - Buffer Issue Investigation
**Date**: 2025-10-15
**Status**: ROOT CAUSE IDENTIFIED - v14 called with wrong parameter

## Problem

Printf.printf "%f\n" 3.14 completes but outputs nothing.

## Investigation Results

### Key Discovery: v14 Called with Wrong Parameter

**Traces Show**:
- `[v14-CLOSURE-CALLED: v214_type=string, v214=""]` - v14 IS called
- `[v14-CALL-v336]` - Called with v336, NOT v358
- `[caml_ml_output: len=0]` - Empty string passed to output

**Code Analysis**:
```lua
-- Block 817 (NEVER EXECUTED):
_V.v326 = _V.v14(_V.v300, _V.v358)  -- Should call with v358 (formatted string)

-- Different path (ACTUALLY EXECUTED):
_V.v339 = _V.v14(_V.v300, _V.v336)  -- Calls with v336 (format spec element!)
```

### Why v336 is Wrong

**v336 source** (line 26503):
```lua
_V.v336 = _V.v359[3]  -- Extracts element [3] from format spec
```

v359 is the format spec tuple, and v359[3] is a FORMAT PARAMETER (like width or precision), NOT the formatted float string!

### Why Block 817 Not Executed

**Execution Trace**: `[572][573][574][575][576][577][578][579][580][581][582][583][584][585][586][587]`

Block 817 never appears! So the code that calls `v14(_V.v300, _V.v358)` with the correct parameter is never reached.

### Control Flow Issue

**Blocks 572-587**: Create closure chains for float formatting
- Block 575: Creates closure v412 that calls v161 (formatter)
- Block 576: Creates closure v413
- ...
- Block 587: Creates closure v428 and RETURNS it

**The Problem**: These closures are created and returned but NEVER INVOKED.

The Printf chain should:
1. Create closure chain (blocks 572-587) ✅
2. Return closure v428 ✅
3. **Invoke v428** with format params ❌ NOT HAPPENING
4. v428 invocation eventually calls v161 to format ❌
5. Formatted result flows through chain to v14 ❌
6. v14 calls caml_ml_output ❌

**What Actually Happens**:
1. Create closure chain ✅
2. Return from continuation blocks ✅
3. **Different code path executes** (v353 == 2 or 4)
4. That path calls v14(v300, v336) where v336 is empty/wrong ❌

## Comparison: %d vs %f

### %d (Working)
```lua
-- Case 4: Returns immediately, no continuation blocks
if v405 == 4 then
  create_closure()
  return  -- Outputs during this return chain
end
```

Output happens immediately, no continuation dispatch needed.

### %f (Broken)
```lua
-- Case 8: Sets _next_block for continuation
if v405 == 8 then
  v353 = v481[2]  -- Format spec
  _next_block = 573  -- Go to continuation
end

-- Continuation blocks 572-587:
-- Create closures, return them
-- But closures never invoked!

-- Different path executes:
if v353 == 2 then  -- Wrong branch!
  v336 = v359[3]  -- Format param, not formatted string
  v14(v300, v336)  -- Outputs EMPTY
end
```

## Root Cause

**v353 value is wrong or the dispatch based on v353 is incorrect.**

v353 should determine which Printf format case to execute (e.g., %f vs %e vs %g). But it's selecting case 2 or 4, which doesn't format the float - it just extracts format params and calls output with empty/wrong value.

### Why This Happens

**Hypothesis 1**: v353 is not initialized correctly before the v353 == 2 check
- v353 is extracted in case 8: `v353 = v481[2]`
- v353 should be the format conversion type
- But when the v353 == 2 check runs, v353 might be from a DIFFERENT closure context

**Hypothesis 2**: The v353 == 2 branch is for a different format operation, not the float
- The code at line 26502 is NOT part of the v177 closure (blocks 572-817)
- It's part of a different closure that also uses v353
- The v177 closure (with blocks 572-817) never completes its chain

**Hypothesis 3**: Return value confusion
- Blocks 572-587 return a closure
- That closure should be stored somewhere and invoked
- But instead, control flow exits to a different code path

## Next Steps

### 1. Check v353 Value
Add trace to see what v353 is when the v353 == 2 check runs:
```lua
if _V.v353 == 2 then
  io.stderr:write("[v353=2, v336=" .. tostring(v336) .. "]")
```

### 2. Find Where v177 Result Goes
When v177 closure returns v412/v413/etc., where does that go?
Should it be invoked to complete the format-and-output chain?

### 3. Compare with JS
Examine js_of_ocaml Printf case 8 more carefully:
- How does JS handle the continuation?
- What calls the closure chain?
- Where does the formatted string flow to output?

### 4. Check if This is the Guard Issue
Maybe the guard `if _next_block == nil` is preventing proper flow?
Test without guard to see if different code path executes.

## Files to Examine

- Generated code around line 26500-26520 (v353 == 2 branch)
- v177 closure (lines 26421+) - where blocks 572-817 live
- How these two interact and which is supposed to execute

## Expected Fix

Need to ensure that:
1. Closure chain from blocks 572-587 is invoked (not just returned)
2. v161 is called to format the float
3. Formatted result flows to v14
4. v14 is called with the formatted string, not format spec

OR:

The v353 == 2 path IS correct, but v336 should be set to the formatted string,not format spec element.
