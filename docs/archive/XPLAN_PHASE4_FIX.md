# XPLAN Phase 4: Bug Fix - Loop Block Parameters

## Status: ✅ PARTIAL SUCCESS

## Bug Discovered

**Root Cause**: Loop block parameters were being classified as FREE variables when they should be LOCAL.

### The Problem

`collect_block_variables` computes:
- **defined_vars**: Variables assigned by `Let` or `Assign` instructions
- **free_vars**: Variables used but not defined: `free_vars = used_vars - defined_vars - entry_params`

**Loop block parameters** are variables that are parameters to loop header blocks. They are:
1. Used in the block (appear in expressions)
2. NOT assigned by `Let` or `Assign` (they're block parameters)
3. Therefore classified as **FREE** variables

But loop block parameters are NOT free - they're LOCAL to the closure!

### The Fix

**File**: `compiler/lib-lua/lua_generate.ml`

**Lines**: 1702-1709 (`setup_hoisted_variables`) and 2060-2067 (`compile_address_based_dispatch`)

```ocaml
(* CRITICAL FIX: Loop block params may have been classified as free_vars
   by collect_block_variables (since they're used but not assigned by Let/Assign).
   But they're actually LOCAL to this closure, not free! Reclassify them. *)
let free_vars = StringSet.diff free_vars loop_block_params in
let defined_vars = StringSet.union defined_vars loop_block_params in

(* All hoisted vars = defined (including loop params) + free *)
let all_hoisted_vars = StringSet.union defined_vars free_vars in
```

**Effect**: Loop block parameters are now:
- Removed from `free_vars`
- Added to `defined_vars`
- Will be initialized in nested closures (not captured from parent)

### Evidence

**Before Fix**:
```lua
-- Hoisted variables (10 total: 7 defined, 3 free, 1 loop params)
```
Breakdown: 7 (defined) + 3 (free includes the loop param) = 10

**After Fix**:
```lua
-- Hoisted variables (10 total: 8 defined, 2 free, 1 loop params)
```
Breakdown: 8 (defined includes the loop param) + 2 (free excludes loop param) = 10

## Test Results

### ✅ Tests That Now Work

1. **print_endline "Hello"**
   - **Result**: ✅ PASS
   - Output: "Hello"

2. **Simple nested closure**
   ```ocaml
   let make_closure x = fun () -> x
   let () =
     let f = make_closure 42 in
     let result = f () in
     print_int result
   ```
   - **Result**: ✅ PASS
   - Output: "42"

3. **Printf simple string**
   ```ocaml
   let () = Printf.printf "Hello, World!\n"
   ```
   - **Result**: ✅ PASS
   - Output: "Hello, World!"

### ❌ Tests That Still Fail

1. **Printf with format specifier**
   ```ocaml
   let () = Printf.printf "Value: %d\n" 42
   ```
   - **Result**: ❌ HANG (infinite loop)
   - No output, timeout after 5 seconds

2. **Simple nested closure with arithmetic**
   ```ocaml
   let outer x = let f y = x + y in f
   let () =
     let add10 = outer 10 in
     Printf.printf "%d\n" (add10 5)
   ```
   - **Result**: ❌ HANG (infinite loop)
   - No output, timeout after 5 seconds

## Analysis

### What Works vs What Doesn't

**Pattern**: Programs that use Printf with format specifiers hang.

**Working**:
- Basic I/O (print_endline, print_int)
- Simple closures without Printf format specifiers
- Printf without format specifiers

**Hanging**:
- Printf with %d, %s, or other format specifiers
- Any program that eventually calls Printf with format specifiers

### Hypothesis

The issue is NOT with:
- Variable shadowing (fixed)
- Loop block parameter classification (fixed)
- Basic closure creation (works)

The issue IS with:
- Printf's complex CPS (Continuation-Passing Style) closure chain
- Format specifier processing closures
- Something specific to how format converters are created/called

### Next Steps for Debugging

1. **Trace execution with debug output**
   - Add print statements to generated Lua
   - Find exact point where it hangs

2. **Compare Printf simple vs Printf %d**
   - Simple string: `Printf.printf "Hello\n"`
   - Format spec: `Printf.printf "%d\n" 42`
   - Identify what's different in generated code

3. **Check format converter closures**
   - Printf %d creates closure for integer formatting
   - This closure might have variable capture issues

4. **Test incremental complexity**
   - Try `Printf.printf "%s\n" "test"` (string format)
   - Try `Printf.sprintf "%d" 42` (returns string, no I/O)
   - Isolate which part of Printf causes hang

## Files Changed

```
M  compiler/lib-lua/lua_generate.ml  (+14 lines, -8 lines)
   - Added loop_block_params reclassification (lines 1702-1709, 2060-2067)
   - Simplified vars_to_init logic (no longer need union with loop_block_params)
```

## Conclusion

**Progress**: ✅ **SIGNIFICANT**
- Fixed critical bug in loop block parameter classification
- Simple closures now work
- Printf without format specifiers works

**Remaining Issue**: Printf with format specifiers still hangs
- Root cause is elsewhere (not variable shadowing or loop params)
- Likely in Printf's format converter closure chain
- Need more targeted debugging

**Overall Assessment**: The variable shadowing fix was correct and necessary. The loop param reclassification was also correct. But there's an additional issue specific to Printf format specifiers that needs investigation.
