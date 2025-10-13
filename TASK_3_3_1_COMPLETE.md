# Task 3.3.1: Extract Variable Management Functions - COMPLETE ✅

## Date: 2025-10-13

## Summary

**SUCCESS**: Extracted variable management into reusable helper functions and integrated into `compile_data_driven_dispatch`. Printf now has proper _V table, parameters, and entry block args!

**New Error**: "attempt to index field 'v343' (a number value)" - tag extraction happens before type check. This is Task 3.3.3.

## Implementation

### Extracted Helper Functions (~110 lines)

1. **setup_hoisted_variables** (lines 1526-1583)
   - Collects all variables needing hoisting
   - Detects loop headers and loop block parameters
   - Excludes entry block params (initialized separately)
   - Decides whether to use _V table (>180 vars threshold)
   - Generates _V table creation or local declarations
   - Returns (hoist_stmts, use_table)

2. **setup_function_parameters** (lines 1586-1592)
   - Copies function parameters to _V table if needed
   - Generates: `_V.param = param` for each parameter
   - Returns list of assignment statements

3. **setup_entry_block_arguments** (lines 1595-1628)
   - Initializes entry block parameters from entry_args (block_args from closure)
   - Distinguishes local params vs captured variables
   - Generates assignments with debug comments
   - Returns list of entry arg initialization statements

### Integration into compile_data_driven_dispatch

**Updated Function Signature** (line 1645):
```ocaml
(* Before *)
and compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var_opt switch_cases _params =

(* After *)
and compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var_opt switch_cases params func_params entry_args =
```

**Added Variable Setup** (lines 1646-1653):
```ocaml
(* 1. Setup hoisted variables *)
let hoist_stmts, use_table = setup_hoisted_variables ctx program entry_addr in

(* 2. Copy function parameters to _V table *)
let param_copy_stmts = setup_function_parameters ctx params use_table in

(* 3. Initialize entry block arguments *)
let entry_arg_stmts = setup_entry_block_arguments ctx program entry_addr entry_args func_params in
```

**Updated Return Statement** (line 1737):
```ocaml
(* Combine in correct order *)
hoist_stmts @ param_copy_stmts @ entry_arg_stmts @ dispatch_loop_stmts
```

### Updated Call Site (line 1761)

**Before**:
```ocaml
compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var switch_cases params
```

**After**:
```ocaml
compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var switch_cases params func_params entry_args
```

## Test Results

### File Size
```bash
$ wc -l /tmp/quick_test.lua
20590 /tmp/quick_test.lua  # Down from 24,372 (15% reduction)
```

### Generated Code Structure
```lua
_V.v184 = caml_make_closure(4, function(counter, v201, v202, v203)
  -- Hoisted variables (144 total, using inherited _V table) ✅
  _V.counter1 = nil
  _V.v204 = nil
  ...
  _V.v340 = nil

  -- Parameters copied ✅
  _V.counter = counter
  _V.v201 = v201
  _V.v202 = v202
  _V.v203 = v203

  -- Entry block args initialized ✅
  -- Entry block arg: v341 = v201 (local param)
  _V.v341 = v201
  -- Entry block arg: v342 = v202 (local param)
  _V.v342 = v202
  -- Entry block arg: v343 = v203 (local param)
  _V.v343 = v203

  -- Tag extraction (WRONG LOCATION!) ❌
  local v204 = _V.v343[1] or 0  ← Should be INSIDE loop, AFTER type check

  -- Dispatch loop
  while true do
    if v204 == 0 then  ← Case 0
      _V.v206 = _V.v343[2]
      ...
```

### Runtime Error
```bash
$ lua /tmp/quick_test.lua
lua: /tmp/quick_test.lua:19203: attempt to index field 'v343' (a number value)
```

**Line 19203**: `local v204 = _V.v343[1] or 0`

**Root Cause**: v343 is an integer (format string end marker), but we try to index it before checking the type.

## Progress: What Works Now ✅

1. ✅ **Variable hoisting**: All 144 variables declared in _V table
2. ✅ **Parameter copying**: counter, v201-v203 copied to _V
3. ✅ **Entry block args**: v341-v343 initialized from function params
4. ✅ **Data-driven detection**: Printf recognized as Cond-based dispatch
5. ✅ **Dispatch loop**: Value-based switch on v204 (not _next_block addresses)
6. ✅ **File size**: 20,590 lines (down from 24,372 - 15% smaller)

## What's Still Broken ❌

**Task 3.3.3 Needed**: Entry block logic missing

The entry block (800) has:
```
body: (empty or setup instructions)
term: Cond(v328, (block_463, []), (block_462, []))
  where v328 = type(v343) == "number" and v343 % 1 == 0
```

**Current generation**:
```lua
local v204 = _V.v343[1] or 0  ← Extract tag immediately (WRONG!)
while true do
  if v204 == 0 then ...
```

**Needed generation** (to match JS):
```lua
while true do
  -- Entry block: Type check FIRST
  _V.v328 = type(_V.v343) == "number" and _V.v343 % 1 == 0
  if _V.v328 then
    -- True branch (block 463): Return for integer case
    _V.v205 = caml_call_gen(_V.v341, {_V.v342})
    return _V.v205
  end

  -- False branch (block 462): Dispatcher
  _V.v204 = _V.v343[1] or 0  ← Extract tag ONLY if not number

  -- Switch on tag
  if _V.v204 == 0 then ...
```

## Comparison with JS

### JS (test_simple_printf_js.js)
```js
function(counter, k, acc, fmt){
  for(;;){
    if(typeof fmt === "number")    ← Type check FIRST
      return caml_call_gen(k, [acc]);

    var fmt_tag = fmt[0];  ← Extract tag ONLY in false branch
    switch(fmt_tag){ ... }
  }
}
```

### Our Lua (Current - Broken)
```lua
function(counter, v201, v202, v203)
  _V.v343 = v203
  local v204 = _V.v343[1] or 0  ← Extract tag BEFORE type check!
  while true do
    if v204 == 0 then ...  ← No type check!
```

### Our Lua (Needed - Matches JS)
```lua
function(counter, v201, v202, v203)
  _V.v343 = v203
  while true do
    if type(_V.v343) == "number" and _V.v343 % 1 == 0 then
      return ...  ← Integer case
    end
    _V.v204 = _V.v343[1] or 0  ← Extract tag in false branch
    if _V.v204 == 0 then ...
```

## Success Criteria

From Task 3.3.1:
- [x] Extract variable hoisting function ✅
- [x] Extract parameter setup function ✅
- [x] Extract entry block args function ✅
- [x] Integrate into compile_data_driven_dispatch ✅
- [x] Build succeeds ✅
- [x] Printf has _V table ✅
- [x] Printf has parameters initialized ✅
- [x] Printf has entry args initialized ✅
- [ ] Printf runs without errors ❌ (Need Task 3.3.3)

## Next: Task 3.3.3

**Goal**: Include entry block's body and Cond logic in the dispatch loop.

**Implementation**:
1. Get entry block from entry_addr
2. Generate entry block body instructions (if any)
3. Handle entry block's Cond terminator:
   - Get the type check variable and condition
   - True branch: Compile that block's code + return
   - False branch: Continue to dispatcher (tag extraction + switch)
4. Move tag extraction INSIDE the false branch (after type check)
5. Wrap entire structure in while loop

**Expected Result**: Printf checks type before extracting tag, matches JS behavior.

## Files Modified

- `compiler/lib-lua/lua_generate.ml`: ~110 lines added (helpers) + ~10 lines changed (integration)

## Commit Message

```
feat(dispatch): extract variable management for data-driven dispatch (Task 3.3.1)

Extracted variable management into reusable helper functions and integrated
into compile_data_driven_dispatch. Printf now has proper setup!

Helpers extracted (~110 lines):
- setup_hoisted_variables: Collect vars, create _V table, init to nil
- setup_function_parameters: Copy function params to _V
- setup_entry_block_arguments: Initialize entry block params from block_args

Integrated into compile_data_driven_dispatch:
- Added calls to all 3 helpers
- Updated function signature (+3 params)
- Updated call site in compile_blocks_with_labels
- Return statement combines: hoist + params + entry_args + dispatch_loop

Results:
✅ Printf has _V table (144 vars hoisted)
✅ Printf has parameters copied (counter, v201-v203)
✅ Printf has entry args initialized (v341-v343)
✅ File size: 20,590 lines (down from 24,372 - 15% reduction)
✅ Dispatch uses value-based switch (v204), not addresses

Current error:
❌ Tag extraction before type check causes "attempt to index number"

Generated code:
```lua
_V.v343 = v203
local v204 = _V.v343[1] or 0  ← WRONG! Should be after type check
while true do
  if v204 == 0 then ...
```

Needed (Task 3.3.3):
```lua
_V.v343 = v203
while true do
  if type(_V.v343) == "number" then return ... end  ← Type check FIRST
  _V.v204 = _V.v343[1] or 0  ← Then extract tag
  if _V.v204 == 0 then ...
```

Next: Task 3.3.3 - Include entry block logic (type check) in dispatch loop
```
