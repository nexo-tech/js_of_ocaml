# Task 3.1: Debug caml_ml_bytes_length nil parameter - FINDINGS

## Date: 2025-10-13

## Summary

**Issue**: `caml_ml_bytes_length(s)` called with `s = nil` causing "attempt to index local 's' (a nil value)" error.

**Root Cause**: Task 2.8's fix (always start at closure entry block) is incomplete. Block 800 is the entry block, but other blocks (like 601) are reachable from 800 that depend on variables (v247) only initialized in specific predecessor blocks (475). Starting directly at 800 skips block 475, leaving v247 uninitialized.

##ERROR TRACE

```
lua: test_simple_printf.lua:1318: attempt to index local 's' (a nil value)
stack traceback:
	test_simple_printf.lua:1318: in function <test_simple_printf.lua:1314>
	                           ^^ caml_ml_bytes_length(s) does return s.length
	(tail call): ?
	test_simple_printf.lua:14089: in function <test_simple_printf.lua:14080>
	                            ^^ v203 = caml_ml_string_length(v202)
```

## Call Chain

1. **Line 14089**: `_V.v203 = caml_ml_string_length(_V.v202)`
   - Inside closure v143 (2 params: v201, v202)
   - v202 is nil

2. **Line 1324**: `caml_ml_string_length(s)` calls `caml_ml_bytes_length(s)`

3. **Line 1318**: `caml_ml_bytes_length(s)` does `return s.length`
   - ERROR: s is nil

## Where v143 is Called

Line 24229 (inside Printf main closure, block 601):
```lua
if _next_block == 601 then
  _V.v228 = _V.v247[3]   ← v247[3] is nil!
  _V.v229 = _V.v247[2]
  _V.v230 = _V.v193(_V.v201, _V.v229)
  _V.v231 = _V.v143(_V.v201, _V.v228)  ← v228 is nil because v247[3] was nil
  return _V.v231
```

## Why v247 is nil

Printf main closure (starts at line 21699):
- **Hoisting** (line 21748): `_V.v247 = nil`
- **Dispatch start** (line 21853): `local _next_block = 800`
- **Block 800** (line 22918): Checks v343 type, branches to 462 or 463
- **Block 601** (line 24225): Uses `v247[3]` but v247 is still nil!

**Where v247 SHOULD be set**: Block 475 (line 22277)
```lua
if _next_block == 475 then
  _V.v247 = _V.v343[3]  ← This initializes v247
  ...
  _next_block = 800      ← Then branches to 800
```

**The Problem**: Dispatch starts at 800, but 475 never runs, so v247 stays nil.

## Control Flow Issue

```
Closure entry → Start at block 800 (Task 2.8 fix)
                ↓
              Block 800: Check v343, branch to 462/463
                ↓
              ... various blocks ...
                ↓
              Block 601: Uses v247[3] ← ERROR! v247 was never set!
```

**Expected flow** (if starting at block 475):
```
Closure entry → Start at block 475
                ↓
              Block 475: Set v247 = v343[3]
                ↓
              Branch to block 800
                ↓
              Block 800: Check v343, branch to 462/463
                ↓
              ... various blocks ...
                ↓
              Block 601: Uses v247[3] ← OK! v247 was set by block 475
```

## Comparison with js_of_ocaml

```bash
$ node /tmp/test_simple_printf_js.js
Hello
```

✅ **JS version works!** Prints "Hello" correctly.

This confirms the issue is in our Lua code generation, not in the Printf logic itself.

## Task 2.8 Limitation

Task 2.8 fixed the "start at back-edge block 484" bug by always starting at the closure entry block (800). This was correct for avoiding back-edges, but it introduced a NEW bug:

- Block 800 is the entry block WITH PARAMETERS in the IR
- But block 800 is ALSO a loop header that gets re-entered
- When re-entered from blocks like 475, those blocks set up variables like v247
- When entered DIRECTLY from function entry, those setup blocks are skipped

## Why Task 2.7 Didn't Fix This

Task 2.7 tried to pre-initialize entry block dependencies, but it correctly determined that v247 is UNSAFE to pre-initialize because:
- v247 = v343[3]
- v343 is a block parameter that changes during dispatch
- Pre-initializing v247 before the loop would use the WRONG value of v343

Task 2.7's analysis was correct - we CAN'T pre-initialize v247.

## Root Cause Analysis

The fundamental issue is our **dispatch model mismatch**:

1. **IR model**: Block 800 is the entry block with parameters (counter, k, acc, fmt)
2. **Control flow reality**: Block 800 is a loop header that should be reached via setup blocks like 475
3. **Our implementation**: We jump directly to block 800, skipping setup blocks

The IR marks block 800 as "entry" because it has parameters, but in the actual control flow, you should enter via block 475 (or similar) which does initialization, THEN branch to 800.

## Proposed Fix Directions

### Option A: Start at First Initializer Block
Instead of starting at entry block (800), start at the first block that branches TO the entry with arguments.

For Printf: Start at block 474, 475, 476, or 481 (blocks that branch to 800 with args).

**Problem**: Which one? There are multiple. They might be for different code paths.

### Option B: Smarter Entry Point Detection
Distinguish between:
- **Entry blocks**: Have parameters, designed to be branched TO
- **First blocks**: Actually execute first when closure is called

For Printf: Entry is 800, but First should be 474/475/etc.

**Implementation**: Check if entry block is only reachable via branches WITH arguments. If so, find blocks that branch TO it from the "outside" (not back-edges).

### Option C: Inline Entry Block Setup
Before jumping to entry block (800), inline the code from blocks like 475 that initialize required variables.

**Problem**: Complex, error-prone, might break control flow.

### Option D: Revert Task 2.8, Improve find_entry_initializer
Task 2.8 removed find_entry_initializer. Bring it back but make it smarter:
- Distinguish back-edges from true initializers
- Back-edges have the entry block in their "path" (detected via loop detection)
- True initializers are "outside" the loop

## Comparison with Task 2.8

Task 2.8 fixed:
```lua
-- Before Task 2.8:
local _next_block = 484  -- WRONG! Back-edge block

-- After Task 2.8:
local _next_block = 800  -- Entry block, but incomplete fix
```

The issue is that both 484 AND 800 are wrong for different reasons:
- 484: Is a back-edge, assumes loop already running
- 800: Is entry block, but skips initialization blocks like 475

**Correct start**: Block 475 (or similar) that initializes v247, then branches to 800.

## Recommendation

**Option B** seems most correct:
1. Detect if entry block is a loop header (is target of back-edges)
2. If so, find blocks that branch to it from "outside" the loop (not back-edges)
3. Use one of those as the dispatch start
4. **Back-edge detection**: A block is a back-edge if the target is in the path to the source (loop detection we already have)

This gives us:
- Block 475: Branches to 800 (not a back-edge, is initializer) ✅ Use this!
- Block 484: Branches to 800 (is a back-edge from within loop) ❌ Skip this

## Next Steps (Task 3.2)

Implement Option B:
1. Enhance `find_entry_initializer` to filter out back-edges
2. Use loop detection to identify back-edges vs true initializers
3. Start dispatch at true initializer block, not entry block directly
4. Test Printf - should get past v247 nil error

## Files for Reference

- Generated Lua: `/tmp/test_simple_printf.lua`
- Main Printf closure: Lines 21699-24072
- Entry block 800: Line 22918
- Initializer block 475: Line 22275
- Problem block 601: Line 24225
- Error site: Line 1318 (caml_ml_bytes_length)

## Success Criteria for Task 3.2

✅ Printf gets past v247/v228 nil errors
✅ Dispatch starts at initializer block (475 or similar), not entry (800)
✅ Simple closures still work (no regressions)
✅ Test suite passes
