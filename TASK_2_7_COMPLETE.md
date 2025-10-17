# Task 2.7: Entry Block Dependency Analysis - COMPLETE

## Date: 2025-10-13

## Summary

Implemented comprehensive entry block dependency analysis with transitive tracking and safety filtering. The implementation correctly identifies and filters unsafe dependencies, proving that **Printf's dependencies cannot be safely pre-initialized** because they use variables modified during dispatch.

## Implementation

### Core Features

1. **Variable Usage Collection** (lines 1029-1064)
   - `collect_vars_used_in_expr`: Tracks variables used in expressions
   - `collect_vars_used_in_instr`: Tracks variables in instructions
   - `collect_vars_used_in_block`: Aggregates block-level usage

2. **Entry Block Dependency Detection** (lines 1073-1097)
   - `analyze_entry_block_deps`: Finds vars USED but not in parameters
   - Returns set of variables needing initialization

3. **Initialization Finder** (lines 1107-1146)
   - `find_var_initialization`: Scans predecessor blocks
   - Finds where dependent variables are assigned
   - Returns (target, expr) for initialization

4. **Assigned Variable Collection** (lines 1148-1175)
   - `collect_assigned_vars`: Scans ALL blocks in closure
   - Collects Let/Assign instructions AND block parameters
   - **Critical**: Block parameters count as "assigned" (they change on branch)

5. **Transitive Dependency Tracking** (lines 1177-1250)
   - `collect_transitive_inits`: Recursively finds dependencies
   - Checks if any dependency uses modified variables
   - **Safety filter**: Skips dependencies using assigned vars
   - Returns list in dependency order (deps before dependents)

6. **Code Generation Integration** (lines 1527-1620)
   - Computes actual dispatch start address
   - Analyzes entry block dependencies
   - Generates initialization code (only for safe dependencies)
   - Inserts before dispatch loop

## Test Results

### Simple Closures
```bash
$ lua test_simple_dep_final.lua
11
```
✅ Works correctly (simple closure with captured variables)

### Printf
```bash
$ lua test_printf_clean.lua
lua: test_printf_clean.lua:22485: attempt to index field 'v279' (a nil value)
```
❌ Still fails, but **no incorrect initialization generated**

**Generated code** (line 21850-21854):
```lua
_V.v343 = v203
local _next_block = 484
while true do
```

**No initialization comment!** The unsafe `_V.v270 = _V.v343[2]` was correctly filtered out.

## Key Findings

### 1. Printf Dependencies Are Unsafe

Debug output for block 484:
```
DEBUG analyze_entry_block_deps: Entry block 484
  Used vars: 4, Params: 0, Deps: 4
  Dep var: v9494 (v343 in generated code)
  Dep var: v9592 (v270 in generated code)
  Dep var: v9604
  Dep var: v9607
  Found 4 direct dependencies, collecting transitive deps
  Collected 2192 assigned vars across all blocks (includes block params)

Checking dep v9592...
  Found! v9592 = expr in block 482
  Init uses 1 vars: v9494
  Any modified: true  ← v343 (v9494) IS modified in dispatch!

Transitive: v9592 uses modified variable, SKIPPING (unsafe)
```

### 2. Why v343 Is Modified

v343 is a **block parameter** - it gets reassigned when branching to blocks:
- Entry: `_V.v343 = v203` (function parameter)
- Block transitions: `_V.v343 = _V.v245`, `_V.v343 = _V.v247`, etc.

In address-based dispatch, blocks aren't connected via IR successors (they use Return + _next_block). So v343 is assigned in MANY blocks throughout the closure.

### 3. Conservative Approach is Correct

Pre-initializing `v270 = v343[2]` before dispatch would be **incorrect** because:
- Uses v343's value at entry (v203)
- But block 482 uses v343's value AFTER modification
- Would generate wrong results even if no nil error

## Success Criteria

From Task 2.7 investigation:
- [x] Analyze entry block for dependencies ✅
- [x] Implement transitive dependency tracking ✅
- [x] Filter unsafe dependencies ✅
- [x] Generate initialization code for safe deps ✅
- [x] No regressions in simple closures ✅
- [ ] Fix Printf ❌ (not possible with this approach)

## Conclusion

**Task 2.7 is complete and correct**, but it proves that entry block dependency pre-initialization **cannot fix Printf**. The dependencies are unsafe because they use variables that change during dispatch.

## Next Steps

The Printf bug requires a **different fix**. Based on findings:

### Root Cause (Refined)
- Block 484 is detected as dispatch start, but it's NOT safe to enter directly
- Block 484 requires block 482 to run first (to set v270)
- Current entry point detection is incorrect for Printf's pattern

### Recommended Approach

**Task 2.8: Fix Dispatch Entry Point Detection**

Printf's closure entry is block 800 (4 params: counter, v201, v202, v203).
Current logic finds block 484 as dispatch start (where _next_block = 484 is set).
But block 484 has dependencies that make it unsafe as entry.

**Options**:
1. **Find true entry block**: Scan for block reachable from closure entry that has NO entry dependencies
2. **Initialize missing path**: Add code path from entry that sets v270 before branching to 484
3. **Restructure dispatch**: Start at closure entry (800), let it flow to proper initialization block

Need to investigate Printf's IR structure to find the right entry point.

## Files Modified

- `compiler/lib-lua/lua_generate.ml` (~200 lines added, functions 1029-1620)

## Commit Message

```
feat(dispatch): implement entry block dependency analysis (Task 2.7)

Comprehensive dependency analysis with safety filtering:
- Collects variables used in entry block but not in parameters
- Traces initialization through predecessor blocks
- Tracks transitive dependencies recursively
- Filters unsafe dependencies (using variables modified in dispatch)
- Includes block parameters as assigned variables

Result: Conservative and correct - no incorrect initialization generated.
Proves Printf cannot be fixed by pre-initialization approach.

Tests:
- Simple closures work correctly
- Printf still fails (expected - needs different fix)
- No regressions

See TASK_2_7_COMPLETE.md for full analysis.

Next: Task 2.8 - Fix dispatch entry point detection
```
