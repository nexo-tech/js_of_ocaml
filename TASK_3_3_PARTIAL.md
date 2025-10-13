# Task 3.3: Implement Value-Based Dispatch for Cond Patterns - PARTIAL

## Date: 2025-10-13

## Summary

**DETECTION WORKING ✅**: Successfully detects Printf's Cond-based dispatch pattern (entry Cond → dispatcher with tag extraction → Switch on tag).

**CODE GENERATION INCOMPLETE ❌**: Generated dispatch loop missing variable hoisting, parameter initialization, and proper tag variable setup.

## Implementation

### What Works

1. **Cond Pattern Detection** (lines 1362-1478)
   - `detect_cond_dispatch_pattern`: Recognizes Printf's pattern
   - Entry block: Cond (type check) → dispatcher_block / return_block
   - Dispatcher block: Extract tag via `%direct_obj_tag` prim
   - Dispatcher terminator: Switch on tag variable
   - **Detection triggers for Printf!** ✅

2. **Tag Extraction Recognition** (lines 1388-1414)
   - Recognizes `%direct_obj_tag`, `%int_of_tag`, `caml_get_tag`
   - Also handles Field expressions: `tag = fmt[idx]`
   - Checks both Cond branches (true and false) for dispatcher

3. **Enhanced detect_dispatch_mode** (lines 1490-1518)
   - First tries Cond-based detection (Task 3.3)
   - Falls back to Switch-based detection (Task 2.5.5)
   - Returns DataDriven with tag_var for Cond patterns

4. **Extended DataDriven Type** (lines 228-236)
   - Added `tag_var : Code.Var.t option` field
   - Some tag_var: Cond-based pattern (extract tag before loop)
   - None: Switch-based pattern (use dispatch_var directly)

### What's Missing

1. **Variable Hoisting** ❌
   - `compile_data_driven_dispatch` doesn't call `collect_block_variables`
   - No _V table creation
   - Variables used in cases are undefined

2. **Parameter Initialization** ❌
   - Function parameters not copied to _V table
   - Entry block arguments not initialized
   - Missing param_copy_stmts and entry_arg_stmts

3. **Tag Variable Setup** ⚠️ Partially implemented
   - Added tag extraction in `setup_stmts` (lines 1535-1551)
   - But uses wrong initialization (needs to check dispatch_var type first)
   - Should match entry block's Cond logic (type check before tag extraction)

## Test Results

### Printf Detection
```
DEBUG detect_cond_dispatch_pattern: entry=800
  Entry has Cond, true=463, false=462
  Checking block 462 as dispatcher
    Dispatcher block 462 has 1 body instructions
      Let v9643 = Prim(%direct_obj_tag, 1 args)
        → TAG EXTRACTION MATCHED!
    Found tag extraction: v9643 = v9494[idx]
    Dispatcher has Switch on tag_var with 25 cases
    TRIGGERED Cond-based data-driven dispatch (Switch variant)!
```
✅ **Detection successful!**

### Generated Code
```lua
_V.v184 = caml_make_closure(4, function(counter, v201, v202, v203)
  while true do
    if v204 == 0 then      ← v204 never declared!
      _V.v205 = _V.v204[2]  ← Wrong variable (_V.v204 instead of dispatch_var)
      ...
```

**Problems**:
1. v204 (tag variable) is never declared
2. Wrong variable used (_V.v204 instead of _V.v343)
3. No _V table setup
4. No parameter initialization

### File Size
- Before (address-based): 24,372 lines
- After (data-driven): 19,249 lines
- **Reduction**: 5,123 lines (21% smaller) ✅

### Execution
```bash
$ lua test_printf_datadriven.lua
Exit code: 0
```
✅ No output, but **no error!** (Silent failure - returns without printing)

This suggests the code runs but doesn't execute correctly because of missing variables.

## Comparison with js_of_ocaml

### JS Structure (from test_simple_printf_js.js)
```js
for(;;){
  if(typeof a === "number") return;  // Type check
  switch(a[0]){                      // Switch on tag
    case 0: ...                      // Cases inline
    case 1: ...
  }
}
```

### Our Generated Lua (Current - Broken)
```lua
while true do
  if v204 == 0 then   ← v204 undefined!
    ...
```

### Our Generated Lua (Needed)
```lua
function(counter, v201, v202, v203)
  -- Hoisted variables
  local _V = {}
  _V.v205 = nil
  ...

  -- Copy parameters
  _V.counter = counter
  _V.v201 = v201
  _V.v202 = v202
  _V.v203 = v203

  -- Initialize entry block args
  _V.v341 = v201
  _V.v342 = v202
  _V.v343 = v203

  -- Main dispatch loop (Task 3.3)
  while true do
    -- Type check (from entry block Cond)
    if type(_V.v343) == "number" and _V.v343 % 1 == 0 then
      return ...  -- Block 463 code
    end

    -- Extract tag
    local tag = _V.v343[1] or 0

    -- Switch on tag
    if tag == 0 then      ← Block 464
      ...
    elseif tag == 11 then ← Block 475
      _V.v247 = _V.v343[3]  -- Variables set naturally!
      _V.v343 = _V.v247     -- Update dispatch var
      -- Continue loop
    elseif tag == X then
      ... _V.v247[3] ...    -- v247 is set! ✅
    end
  end
end
```

## Root Cause Analysis

`compile_data_driven_dispatch` (Task 2.5.5) is a **PROTOTYPE** that only generates the switch loop structure. It was designed for simple test cases without complex variable management.

For Printf, we need ALL the infrastructure from `compile_address_based_dispatch`:
1. Variable collection and hoisting
2. _V table creation
3. Parameter copying
4. Entry block argument initialization
5. Loop block parameter detection
6. THEN the data-driven dispatch loop

## Required Refactor

### Phase 1: Add Variable Management (Task 3.3.1)
Extract variable management logic from `compile_address_based_dispatch` into shared functions:
- `setup_hoisted_variables`: Collect and hoist vars
- `setup_function_parameters`: Copy params to _V
- `setup_entry_block_args`: Initialize entry args

### Phase 2: Integrate into compile_data_driven_dispatch (Task 3.3.2)
Call setup functions before generating dispatch loop:
```ocaml
and compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var_opt switch_cases params func_params entry_args =
  (* 1. Variable hoisting *)
  let hoist_stmts, use_table = setup_hoisted_variables ctx program entry_addr in

  (* 2. Parameter copying *)
  let param_copy_stmts = setup_function_parameters ctx params use_table in

  (* 3. Entry block args *)
  let entry_arg_stmts = setup_entry_block_args ctx program entry_addr entry_args func_params in

  (* 4. Tag extraction and dispatch loop *)
  let dispatch_stmts = ... (* existing logic *)

  (* 5. Combine *)
  hoist_stmts @ param_copy_stmts @ entry_arg_stmts @ dispatch_stmts
```

### Phase 3: Fix Tag Variable Initialization (Task 3.3.3)
Current tag setup is wrong. Need to:
1. Include entry block's Cond logic (type check)
2. Then extract tag only if not integer
3. Match exact structure of entry Cond → dispatcher flow

### Phase 4: Handle Entry Block Code (Task 3.3.4)
Entry block (800) has body instructions before its Cond terminator.
These need to be executed before the type check.

## Detailed Comparison with JS

### JS Closure Structure (generate.ml:2319-2339)
```ocaml
let compile_closure ctx (pc, args) cloc =
  let st = build_graph ctx pc cloc in
  (* ... *)
  compile_branch st start_loc Q.empty (pc, args) scope_stack ~fall_through:Return
```

**Key**: `compile_branch` handles:
- Block compilation with context
- Argument passing via continuation
- Variable scoping
- All in one unified function

### Our Lua Structure (Current)
Two separate paths:
- `compile_address_based_dispatch`: Full variable management + address dispatch
- `compile_data_driven_dispatch`: Only dispatch loop (prototype)

**Problem**: Code duplication and data-driven path missing critical setup.

### Our Lua Structure (Needed)
Unified setup, branching only on dispatch style:
```ocaml
and compile_closure_with_dispatch ctx program entry_addr params entry_args func_params =
  (* Shared setup *)
  let hoist_stmts = ...
  let param_stmts = ...
  let entry_stmts = ...

  (* Detect dispatch mode *)
  match detect_dispatch_mode program entry_addr with
  | DataDriven { ... } ->
      let dispatch_stmts = compile_data_driven_loop ... in
      hoist_stmts @ param_stmts @ entry_stmts @ dispatch_stmts
  | AddressBased ->
      let dispatch_stmts = compile_address_based_loop ... in
      hoist_stmts @ param_stmts @ entry_stmts @ dispatch_stmts
```

## Success Criteria for Complete Task 3.3

- [x] Detect Cond-based dispatch patterns ✅
- [ ] Generate complete variable management (hoisting, params, entry args) ❌
- [ ] Generate correct tag extraction with type check ❌
- [ ] Generate data-driven dispatch loop ⚠️ (partial - structure correct, variables missing)
- [ ] Test Printf - outputs "Hello" ❌
- [ ] Test simple closures - no regressions ❓ (untested)
- [ ] Test suite passes ❓ (untested)

## Next Steps - Subtasks

### Task 3.3.1: Extract Variable Management Functions
Refactor `compile_address_based_dispatch` to use helper functions:
- Extract hoisting logic → `setup_hoisted_variables`
- Extract param copying → `setup_function_parameters`
- Extract entry args → `setup_entry_block_args`
- Test: Address-based dispatch still works

### Task 3.3.2: Add Variable Management to Data-Driven Dispatch
Call setup functions in `compile_data_driven_dispatch`:
- Add hoisting
- Add parameter copying
- Add entry block args
- Pass necessary parameters (params, entry_args, func_params)
- Update call site in `compile_blocks_with_labels`
- Test: Printf should declare v204

### Task 3.3.3: Fix Tag Extraction and Entry Block Logic
Include entry block's body and Cond logic:
- Execute entry block body instructions
- Generate type check from entry Cond
- Extract tag only for non-integer case
- Match exact JS structure

### Task 3.3.4: Test and Debug Printf
Test Printf progressively:
- Check v204 is declared ✓
- Check variables are hoisted ✓
- Check Printf outputs "Hello" ✓
- Debug any runtime errors
- Verify matches JS behavior

### Task 3.3.5: Verify No Regressions
- Test simple closures (test_simple_dep.ml)
- Run test suite (just test-lua)
- Verify data-driven dispatch doesn't break existing code
- Check file sizes are reasonable

## Files Modified

- `compiler/lib-lua/lua_generate.ml`: ~150 lines added
  - Lines 228-236: Extended DataDriven type (+1 field)
  - Lines 1323-1351: extract_cond_cases function (+29 lines)
  - Lines 1362-1478: detect_cond_dispatch_pattern function (+117 lines)
  - Lines 1490-1518: Updated detect_dispatch_mode (+3 lines)
  - Lines 1533-1551: Tag variable setup in compile_data_driven_dispatch (+19 lines)
  - Lines 1617-1619: Updated call site (+1 line)

## Commit Message

```
feat(dispatch): detect Cond-based data-driven dispatch patterns (Task 3.3 - PARTIAL)

Detection working! Code generation incomplete.

Implemented Cond-based dispatch pattern detection for Printf:
- Entry block: Cond (type check) → dispatcher / return
- Dispatcher: Extract tag via %direct_obj_tag primitive
- Dispatcher: Switch on tag variable (25 cases for Printf)
- Detects Printf and other format closures successfully

Detection results:
✅ Printf entry=800 detected as Cond-based data-driven dispatch
✅ 25 cases extracted from Switch terminator
✅ File size reduced 24372 → 19249 lines (21% smaller)

Code generation issues:
❌ No variable hoisting (_V table not created)
❌ No parameter initialization
❌ Tag variable (v204) not declared
❌ Wrong variables used in generated code

Current output:
```lua
while true do
  if v204 == 0 then  ← v204 undefined!
    _V.v205 = _V.v204[2]  ← Wrong var
```

Needed output:
```lua
function(counter, v201, v202, v203)
  local _V = {}
  _V.v343 = v203
  while true do
    if type(_V.v343) == "number" then return ... end
    local tag = _V.v343[1] or 0
    if tag == 0 then ...
```

Root cause:
compile_data_driven_dispatch (Task 2.5.5 prototype) only generates switch loop,
doesn't handle variable management. Need to add hoisting, param copying, and
entry args like compile_address_based_dispatch does.

Next steps (subtasks):
- Task 3.3.1: Extract variable management into helper functions
- Task 3.3.2: Add variable management to compile_data_driven_dispatch
- Task 3.3.3: Fix tag extraction with entry block logic
- Task 3.3.4: Test Printf
- Task 3.3.5: Verify no regressions

See TASK_3_3_PARTIAL.md for complete analysis and refactor plan.
```
