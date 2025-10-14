# XPLAN Phase 4: Fix Implementation

## Status: ⚠️ IMPLEMENTED BUT NEEDS DEBUGGING

## Tasks Completed

### Task 4.1: Implement Fix in lua_generate.ml ✅

**Files Modified**:
- `compiler/lib-lua/lua_generate.ml`
- `compiler/lib-lua/lua_generate.mli`

**Changes Made**:

1. **Modified `collect_block_variables` return type** (lines 1160-1258):
   - Changed from `StringSet.t` to `(StringSet.t * StringSet.t)`
   - Returns tuple of `(defined_vars, free_vars)`
   - Updated documentation to explain the separation

2. **Updated `setup_hoisted_variables`** (lines 1677-1771):
   - Uses tuple from `collect_block_variables`
   - Implements conditional logic for nested vs top-level closures
   - **NESTED CLOSURES**: Only initialize `defined_vars + loop_block_params`, exclude `free_vars`
   - **TOP-LEVEL**: Initialize all variables (no parent to capture from)
   - Enhanced comments show "X total: Y defined, Z free, W loop params"

3. **Updated `compile_address_based_dispatch`** (lines 2028-2144):
   - Same fix applied to this code path
   - Destructures tuple from `collect_block_variables`
   - Implements same conditional logic for vars_to_init
   - Handles both table-based and local variable cases

4. **Updated interface file** (`lua_generate.mli` line 117):
   - Changed signature to match new return type
   - Updated documentation

**Build Status**: ✅ **SUCCESSFUL**
- No compilation errors
- No warnings related to changes

### Task 4.2-4.4: Testing ⚠️

**Tests Performed**:

1. **print_endline** test:
   ```ocaml
   let () = print_endline "Hello"
   ```
   - **Result**: ✅ **WORKS** - Outputs "Hello"
   - Confirms basic code generation is functional

2. **Printf with %d** test:
   ```ocaml
   let () = Printf.printf "Value: %d\n" 42
   ```
   - **Result**: ❌ **HANGS** - Infinite loop, no output
   - Timeout after 10 seconds

3. **Simple nested closure** test:
   ```ocaml
   let outer x =
     let f y = x + y in
     f

   let () =
     let add10 = outer 10 in
     let result = add10 5 in
     Printf.printf "%d\n" result
   ```
   - **Result**: ❌ **HANGS** - Infinite loop, no output
   - Timeout after 10 seconds

**Generated Code Verification**:
- ✅ New comment format appears: "Hoisted variables (X total: Y defined, Z free, W loop params)"
- ✅ Fix is being applied (conditional logic is working)
- ❌ Programs still hang - indicates implementation bug, not design flaw

## Problem Analysis

### What Works
- Build system compiles successfully
- Basic non-closure code (print_endline) works
- Generated code shows the fix is active (comments prove it)

### What Doesn't Work
- Programs with closures hang (infinite loop)
- Both Printf and non-Printf closures affected
- Not a Printf-specific issue

### Root Cause Hypothesis

The hanging suggests an infinite loop, likely in:
1. **Dispatch loop**: Variable lookup might be failing, causing wrong control flow
2. **Closure creation**: Something in the partial application logic might be broken
3. **Free variable lookup**: The __index metatable might not be working correctly

**NOT** a crash or nil error - those would fail immediately. The hanging suggests:
- Code is running
- Loop condition never becomes false
- OR recursive call never returns

### Key Observations

1. **Old comment format still appears in some places**:
   - Grep showed "9 total, using own _V table for closure scope" (old format)
   - This was in `compile_address_based_dispatch` which I fixed
   - After fix, all comments use new format

2. **Fix is definitely applied**:
   - Generated code shows "X defined, Y free, Z loop params"
   - This proves conditional logic is executing
   - Variables ARE being separated correctly

3. **Issue is runtime, not compile-time**:
   - No Lua syntax errors
   - Code loads and starts executing
   - Hangs during execution

## Next Steps for Debugging

### Debug Strategy

1. **Add debug output to generated Lua**:
   - Print when entering/exiting blocks
   - Print variable values before/after assignment
   - Track dispatch loop iterations

2. **Simplify test case**:
   - Try closure without Printf
   - Try closure without arithmetic
   - Minimal: `let f x = fun () -> x`

3. **Check generated Lua directly**:
   - Look at dispatch loop for user code (not stdlib)
   - Check if free variables are being looked up correctly
   - Verify __index metatable is set properly

4. **Compare with JS output**:
   - Generate JS for same test
   - Compare control flow structure
   - Look for missing initialization

### Specific Things to Check

1. **Entry block parameters**:
   - Are they being excluded correctly?
   - Are they assigned before use?

2. **Loop block parameters**:
   - Should they be in defined_vars or free_vars?
   - Current logic: `StringSet.union defined_vars loop_block_params`
   - Is this correct for nested closures?

3. **Metatable setup**:
   - Is __index working?
   - Test with simple Lua: `_V.undefined_var` should look up in parent_V

4. **Partial application (runtime/lua/fun.lua)**:
   - Workaround at Task 3.6.5.7 might interfere
   - Try removing it temporarily

## Files Changed Summary

```
M  compiler/lib-lua/lua_generate.ml     (168 lines changed: +125, -43)
M  compiler/lib-lua/lua_generate.mli    (11 lines changed: +10, -1)
```

## Comparison: Before vs After

### Before (Buggy)
```lua
-- Nested closure
local _V = setmetatable({}, {__index = parent_V})
_V.captured_var = nil  -- ❌ Shadows parent!
_V.local_var = nil
```

### After (Intended)
```lua
-- Nested closure
local _V = setmetatable({}, {__index = parent_V})
-- captured_var NOT initialized - comes from parent_V
_V.local_var = nil  -- ✅ Only local vars
```

### What Actually Happens
Generated code shows the fix IS applied, but programs hang. Need to investigate why.

## References

- Design: `XPLAN_PHASE3_TASK7.md`
- Root cause: `XPLAN_PHASE3_TASK2.md` and `XPLAN_PHASE3_TASK3.md`
- JS comparison: `compiler/lib/generate.ml:981` (parallel_renaming)

## Conclusion

**Implementation Status**: Code changes are complete and compile successfully

**Testing Status**: Tests reveal the fix doesn't work as intended - programs hang

**Next Action**: Debug why programs hang despite fix being applied. The root cause analysis was correct, but the implementation has a subtle bug causing infinite loops.

The fix prevents variable shadowing as designed, but something else is now broken. Likely candidates:
- Variable initialization order
- Metatable lookup
- Entry/loop parameter handling
- Interaction with existing closure code
