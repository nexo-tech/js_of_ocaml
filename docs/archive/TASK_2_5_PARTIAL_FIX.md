# Task 2.5: Closure Initialization Fix - PARTIAL SUCCESS

## Date: 2025-10-12

## Summary

**STATUS**: Partial fix implemented - simple closures work, Printf still fails

### What Was Fixed

Implemented entry block argument passing in `compile_blocks_with_labels` (lines 1141-1188):
- Entry block parameters now initialized from `block_args`
- Initialization happens AFTER _V table creation but BEFORE dispatch loop
- Matches js_of_ocaml's `parallel_renaming` behavior

### Test Results

✅ **Working**:
- `/tmp/test_closure_simple.ml` (print_int): Prints "30" correctly
- `/tmp/test_closure_3level.ml` (3-level nested closure): Prints "OK"
- All simple closure patterns work

❌ **Still Failing**:
- `/tmp/test_printf.ml`: `attempt to index field 'v270' (a nil value)`
- `/tmp/test_printf_minimal.ml` ("Hello\n"): Same error
- `/tmp/test_printf_int.ml` ("%d\n" 42): Same error

### Progress Made

**Before Fix**:
- Error: `attempt to index field 'v273' (a nil value)` at line 22552
- NO entry block parameters initialized

**After Fix**:
- Error: `attempt to index field 'v270' (a nil value)` at line 22554
- Entry block parameters v341, v342, v343 ARE initialized (lines 21919-21923)
- Simple closures work perfectly

**Conclusion**: We fixed the entry block parameter initialization, but Printf has a DIFFERENT issue with v270.

## The Remaining Problem

### Current Situation

Looking at the generated Lua for the Printf closure (function at line 21771):

```lua
_V.v184 = caml_make_closure(4, function(counter, v201, v202, v203)
  -- Hoisted variables (144 total, using inherited _V table)
  _V.v270 = nil  -- Line ~21846: v270 initialized to nil
  ...
  _V.counter = counter
  _V.v201 = v201
  _V.v202 = v202
  _V.v203 = v203
  -- Initialize entry block parameters from block_args (Fix for Printf bug!)
  -- Entry block arg: v341 = v201 (local param)
  _V.v341 = v201
  -- Entry block arg: v342 = v202 (local param)
  _V.v342 = v202
  -- Entry block arg: v343 = v203 (local param)
  _V.v343 = v203
  local _next_block = 484  -- Entry block
  while true do
    if _next_block == 484 then
      _V.v278 = _V.v343[3]
      _V.v279 = _V.v270[2]  -- ❌ ERROR: v270 is nil!
```

### The Issue

1. Entry block is block 484
2. Entry block parameters are v341, v342, v343 (correctly initialized ✅)
3. Block 484 ALSO uses v270 (line 22554)
4. v270 is NOT a parameter of block 484
5. v270 is initialized to nil in hoisting
6. v270 is NEVER assigned before block 484 runs

### Why This Happens

Block 484 expects v270 to have a value, but:
- v270 is not in `block.params` for block 484
- v270 is not passed via `block_args`
- v270 is a local variable of THIS closure
- v270 should be assigned by an earlier block, but block 484 is the ENTRY

This means **block 484 should NOT be the entry block**, OR there's missing initialization logic for variables used by entry blocks.

### Possible Causes

1. **Wrong entry block selection**: Maybe the closure should start at a different block that initializes v270
2. **Missing block parameters**: Maybe the IR has v270 as a block parameter but we're not seeing it
3. **Control flow assumption**: The OCaml compiler assumes some blocks run before others
4. **Printf-specific pattern**: Printf uses complex CPS transformations that create unusual control flow

## Next Steps

### Investigation Needed

1. **Examine the IR**: Look at the actual `Code.Closure` instruction to see:
   - What is `pc` (entry block address)?
   - What are `block_args` (arguments to pass to entry block)?
   - What are the entry block's `params`?

2. **Check block dependencies**: For the entry block, what variables does it USE vs what variables are in its PARAMS?

3. **Compare with JS**: How does js_of_ocaml handle this same closure? Does it use a different entry block?

4. **Check for initializer blocks**: Does the IR have a separate initialization block that runs before the entry block?

### Potential Fixes

**Option A: Find correct entry block**
- Maybe there's a block that initializes v270 and should be the entry
- Check if there's a `find_entry_initializer` equivalent

**Option B: Initialize missing variables**
- Detect variables used by entry block but not in parameters
- Initialize them to some default value or error early

**Option C: Defer to expert**
- This might require understanding OCaml compiler's CPS transformations
- May need to look at how Printf is compiled to IR

## Files Modified

- ✅ `compiler/lib-lua/lua_generate.ml`: Added entry block arg passing (lines 1141-1302)
- ✅ `compiler/lib-lua/lua_generate.mli`: Updated signature (lines 126-144)

## Changes Made

### lua_generate.ml

1. **Updated `compile_blocks_with_labels` signature** (line 1026):
   ```ocaml
   and compile_blocks_with_labels ctx program start_addr
         ?(params = []) ?(entry_args = []) ?(func_params = []) () =
   ```

2. **Added entry block argument passing** (lines 1141-1188):
   ```ocaml
   let entry_arg_stmts =
     if not (List.is_empty entry_args) then
       (* Generate argument passing for entry block *)
       ...
       build_assignments entry_args block.Code.params []
     else []
   in
   ```

3. **Updated return statement** (line 1302):
   ```ocaml
   hoist_stmts @ param_copy_stmts @ entry_arg_stmts @ dispatch_loop
   ```

4. **Updated `generate_closure`** (lines 1336-1345):
   ```ocaml
   let body_stmts = compile_blocks_with_labels closure_ctx program pc
                      ~params ~entry_args:block_args ~func_params:params () in
   let full_body = body_stmts in
   ```

### lua_generate.mli

Updated `compile_blocks_with_labels` signature to include new optional parameters.

## Test Commands

```bash
# Working tests
just quick-test /tmp/test_closure_simple.ml  # ✅ Prints "30"
just quick-test /tmp/test_closure_3level.ml  # ✅ Prints "OK"

# Failing tests
just quick-test /tmp/test_printf.ml           # ❌ v270 nil error
just quick-test /tmp/test_printf_minimal.ml   # ❌ v270 nil error
just quick-test /tmp/test_printf_int.ml       # ❌ v270 nil error
```

## Conclusion

We successfully implemented the fix identified in Task 2.4:
- ✅ Entry block parameters are now initialized from `block_args`
- ✅ Initialization happens at the correct time (after _V, before dispatch)
- ✅ Simple closures work perfectly

However, Printf reveals a deeper issue:
- ❌ Entry blocks can use variables that aren't parameters
- ❌ These variables aren't initialized before the entry block runs
- ❌ This is specific to Printf's complex CPS structure

**Recommendation**: Commit this partial fix as it improves simple cases, then investigate the Printf-specific issue separately. The fix is correct for its intended purpose, but Printf exposes a different problem in the IR or control flow analysis.
