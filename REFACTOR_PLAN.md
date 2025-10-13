# Data-Driven Dispatch Refactor Plan - Complete Implementation

## Executive Summary

**Status**: Detection works ✅, Code generation incomplete ❌

**What Works**: Successfully detects Printf's Cond-based dispatch pattern (25 cases), file size reduced 21%.

**What's Missing**: Variable hoisting, parameter initialization, entry block args, proper tag extraction.

**Effort**: 4-7 hours across 5 subtasks (3.3.1 through 3.3.5)

**Goal**: Make `Printf.printf "Hello, World!\n"` work by completing data-driven dispatch code generation.

---

## How js_of_ocaml Works (The Reference Implementation)

### JS Generation Flow (compiler/lib/generate.ml)

**Entry Point** (line 2319):
```ocaml
and compile_closure ctx (pc, args) cloc =
  let st = build_graph ctx pc cloc in
  compile_branch st start_loc Q.empty (pc, args) scope_stack ~fall_through:Return
```

**Key Function** - `compile_branch` (line 1100-1700):
- Compiles a block with its arguments
- Handles argument passing via **parallel_renaming** (assigns args to params)
- Compiles block body
- Compiles terminator (recursively calls compile_branch for successors)
- **Continuation-passing style**: Everything flows naturally

**For Printf's Switch**:
```ocaml
| Switch (x, [| (a1, y1); (a2, y2); ... |]) ->
    compile_switch st loc context x [| (a1, y1); (a2, y2); ... |] scope_stack fall_through
```

**compile_switch** (lines 1849-1950):
- Generates `for(;;) { switch(x) { case 0: ...; case 1: ...; } }`
- Each case body calls `compile_branch` with that case's target and args
- **Arguments flow naturally** - compile_branch handles param assignment

### Generated JS (test_simple_printf_js.js)
```js
// Entry to Printf closure (4 params)
function(counter, k, acc, fmt){
  for(;;){
    // Type check (from entry Cond)
    if(typeof fmt === "number")
      return caml_call_gen(k, [acc]);

    // Extract tag
    var fmt_tag = fmt[0];  ← Tag extraction from dispatcher block

    // Switch on tag
    switch(fmt_tag){
      case 0:  // Block 464
        var rest = fmt[2];
        return function(arg){...};

      case 11: // Block 475
        var rest = fmt[3];
        var prev = fmt[2];
        var fmt_new = {2, acc, prev};  ← Create new fmt
        k = k; acc = fmt_new; fmt = rest;  ← Update loop vars
        break;  ← Continue loop

      // ... more cases ...
    }
  }
}
```

**Key Observations**:
1. **All variables declared**: counter, k, acc, fmt (function params), fmt_tag (local), rest/prev (case locals)
2. **Type check INSIDE loop**: `if(typeof fmt === "number")` before switch
3. **Tag extraction**: `var fmt_tag = fmt[0]` from dispatcher block body
4. **Case bodies inline**: Direct code, not jumps to other blocks
5. **Back-edges**: Update loop variables (k, acc, fmt), then break (continue loop)
6. **Natural flow**: Variables set in execution order, no dependency issues

---

## Our Current Implementation

### Detection (WORKS ✅)

**Function**: `detect_cond_dispatch_pattern` (lines 1362-1478)

**Pattern Recognized**:
```
Entry block (800):
  body: (empty or setup code)
  term: Cond(type_check_var, (true_block, true_args), (dispatcher_block, dispatcher_args))

Dispatcher block (462):
  body: [Let(tag_var, Prim(%direct_obj_tag, [dispatch_var]))]
  term: Switch(tag_var, cases) OR Cond(tag_var, ...) chain
```

**For Printf**:
- Entry 800: Cond → blocks 463 (true) / 462 (false)
- Block 462: Let v204 = %direct_obj_tag(v343); Switch(v204, 25 cases)
- Detected: dispatch_var = v343, tag_var = v204, 25 cases ✅

### Code Generation (INCOMPLETE ❌)

**Function**: `compile_data_driven_dispatch` (lines 1533-1614)

**What It Generates** (current):
```lua
function(counter, v201, v202, v203)
  while true do
    if v204 == 0 then      ← v204 undefined!
      _V.v205 = _V.v204[2]  ← Wrong var!
```

**What It Should Generate** (to match JS):
```lua
function(counter, v201, v202, v203)
  -- 1. Hoisted variables
  local _V = {}
  _V.v205 = nil
  _V.v206 = nil
  ... (all 144 hoisted vars)

  -- 2. Copy function parameters
  _V.counter = counter
  _V.v201 = v201
  _V.v202 = v202
  _V.v203 = v203

  -- 3. Initialize entry block arguments
  _V.v341 = v201
  _V.v342 = v202
  _V.v343 = v203

  -- 4. Main dispatch loop
  while true do
    -- 4a. Entry block body (if any)
    ... (entry block instructions) ...

    -- 4b. Entry block Cond (type check)
    _V.v328 = type(_V.v343) == "number" and _V.v343 % 1 == 0
    if _V.v328 then
      -- True branch (block 463): return path
      _V.v205 = caml_call_gen(_V.v341, {_V.v342})
      return _V.v205
    end

    -- 4c. False branch (block 462): dispatcher
    -- Extract tag
    _V.v204 = _V.v343[1] or 0

    -- 4d. Switch on tag
    if _V.v204 == 0 then       -- Block 464
      _V.v206 = _V.v343[2]
      ...
      return ...
    elseif _V.v204 == 11 then  -- Block 475
      _V.v247 = _V.v343[3]
      _V.v248 = _V.v343[2]
      ...
      -- Back-edge: update vars and continue
      _V.v341 = _V.v341
      _V.v342 = {2, _V.v342, _V.v248}
      _V.v343 = _V.v247
      -- Falls through to continue loop
    elseif ...
    end
  end
end
```

---

## Refactor Plan - Detailed Breakdown

### Task 3.3.1: Extract Variable Management Functions

**Goal**: Create reusable helper functions for variable management.

**Current Code to Extract** (from compile_address_based_dispatch, lines 1627-1770):
- Variable collection (lines 1629-1660)
- Loop detection and loop block params (lines 1662-1680)
- Entry block param exclusion (lines 1682-1691)
- _V table creation (lines 1693-1760)
- Parameter copying (lines 1762-1773)
- Entry block arguments (lines 1775-1823)

**New Functions**:

```ocaml
(** Collect and hoist variables for a closure.
    Returns hoist statements and whether to use _V table.

    This matches js_of_ocaml's variable collection but adapted for Lua's
    local variable limit and _V table pattern.
*)
and collect_and_hoist_variables ctx program start_addr params entry_args =
  (* Collect all variables *)
  let hoisted_vars = collect_block_variables ctx program start_addr in

  (* Detect loops and collect loop block parameters *)
  let loop_headers = detect_loop_headers program start_addr in
  let loop_block_params = ...  (* lines 1664-1680 *)

  (* Get entry block params to exclude from hoisting *)
  let entry_block_params = ... (* lines 1682-1691 *)

  (* Combine and decide on _V table *)
  let all_hoisted_vars = StringSet.union hoisted_vars loop_block_params in
  let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params in
  let use_table = should_use_var_table (StringSet.cardinal all_hoisted_vars) in
  ctx.use_var_table <- use_table;

  (* Generate hoist statements *)
  let hoist_stmts = if StringSet.is_empty vars_to_init then ...
                    else if use_table then ...
                    else ... (* lines 1693-1760 *)
  in
  (hoist_stmts, use_table)

(** Setup function parameters (copy to _V table if needed) *)
and setup_function_parameters ctx params use_table =
  if use_table && not (List.is_empty params) then
    List.map params ~f:(fun param ->
      let param_name = var_name ctx param in
      L.Assign ([L.Dot (L.Ident var_table_name, param_name)], [L.Ident param_name]))
  else
    []

(** Setup entry block arguments from closure block_args *)
and setup_entry_block_arguments ctx program start_addr entry_args func_params use_table =
  if not (List.is_empty entry_args) then
    match Code.Addr.Map.find_opt start_addr program.Code.blocks with
    | None -> []
    | Some block ->
        (* Build assignments from entry_args to block.params *)
        (* Lines 1787-1823 logic *)
        ...
  else
    []
```

**Testing After Task 3.3.1**:
```bash
# Address-based dispatch MUST still work
just quick-test /tmp/test_simple_dep.ml  # Should output "11"
just test-lua  # Should pass same tests as before
```

**Success Criteria**:
- Extracted functions are pure (no side effects except ctx.use_var_table)
- compile_address_based_dispatch calls new functions
- Zero behavior change (outputs identical Lua code)
- All tests pass exactly as before

---

### Task 3.3.2: Integrate Variable Management into Data-Driven Dispatch

**Goal**: Make data-driven dispatch use the extracted helper functions.

**Update Function Signature**:
```ocaml
(* Before *)
and compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var_opt switch_cases _params =

(* After *)
and compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var_opt switch_cases params func_params entry_args =
```

**Add Variable Setup Calls**:
```ocaml
and compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var_opt switch_cases params func_params entry_args =
  (* 1. Collect and hoist variables *)
  let hoist_stmts, use_table = collect_and_hoist_variables ctx program entry_addr params entry_args in

  (* 2. Copy function parameters to _V table *)
  let param_copy_stmts = setup_function_parameters ctx params use_table in

  (* 3. Initialize entry block arguments *)
  let entry_arg_stmts = setup_entry_block_arguments ctx program entry_addr entry_args func_params use_table in

  (* 4. Generate tag extraction and dispatch loop *)
  let tag_setup_stmts, switch_var_name = ... (* existing lines 1535-1551 *)
  let dispatch_loop_stmts = ... (* existing lines 1561-1612 *)

  (* 5. Combine in correct order (matches compile_address_based_dispatch) *)
  hoist_stmts @ param_copy_stmts @ entry_arg_stmts @ tag_setup_stmts @ dispatch_loop_stmts
```

**Update Call Site** (line 1617 in compile_blocks_with_labels):
```ocaml
(* Before *)
| DataDriven { entry_addr; dispatch_var; tag_var; switch_cases } ->
    compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var switch_cases params

(* After *)
| DataDriven { entry_addr; dispatch_var; tag_var; switch_cases } ->
    compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var switch_cases params func_params entry_args
```

**Testing After Task 3.3.2**:
```bash
# Check Printf has variable setup
cd /tmp
~/projects/.../lua_of_ocaml.exe compile test_simple_printf.bc -o test_v2.lua
grep "local _V = {}" test_v2.lua  # Should find _V creation
grep "_V.v343 = v203" test_v2.lua  # Should find entry arg
grep "_V.counter = counter" test_v2.lua  # Should find param copy

# Test (might still fail, but with different error)
lua test_v2.lua
```

**Success Criteria**:
- Generated code has _V table
- Parameters copied to _V
- Entry block args initialized
- May still fail in dispatch loop, but setup is correct

---

### Task 3.3.3: Fix Tag Extraction with Entry Block Logic

**Goal**: Include entry block's body instructions and Cond logic in the dispatch loop.

**Current Problem**:
Tag extraction happens immediately in loop:
```lua
while true do
  local tag = v343[1] or 0  ← Assumes v343 is always a block!
  if tag == 0 then ...
```

**JS Behavior**:
```js
for(;;){
  if(typeof fmt === "number")   ← Type check FIRST
    return caml_call_gen(k, [acc]);

  var fmt_tag = fmt[0];  ← Extract tag ONLY if not integer
  switch(fmt_tag){ ... }
}
```

**Needed Implementation**:

1. **Detect Entry Block Structure**:
   - Entry block may have body instructions (execute before type check)
   - Entry block has Cond terminator: true_branch / false_branch
   - True branch: Usually return path (integer case)
   - False branch: Dispatcher block (block/variant case)

2. **Generate Entry Block Logic**:
   ```ocaml
   (* Get entry block *)
   let entry_block = Code.Addr.Map.find entry_addr program.Code.blocks in

   (* Generate entry block body *)
   let entry_body_stmts = generate_instrs ctx entry_block.Code.body in

   (* Generate entry Cond terminator *)
   match entry_block.Code.branch with
   | Code.Cond (type_var, (true_target, true_args), (false_target, false_args)) ->
       (* Generate type check *)
       let type_check_expr = var_ident ctx type_var in
       let true_block_code = ... (* compile true_target block - usually return *) in
       let false_block_code = ... (* dispatcher: tag extraction + switch *) in

       (* Generate if-else *)
       [ L.While (L.Bool true, [
           entry_body_stmts @
           [ L.If (type_check_expr, true_block_code, Some false_block_code) ]
         ])]
   ```

3. **Move Tag Extraction Into False Branch**:
   - Tag extraction (current lines 1535-1551) moves inside false branch
   - Only execute if dispatch_var is not an integer
   - Matches JS: type check guards tag extraction

**Implementation Changes**:
- Modify compile_data_driven_dispatch to get entry and dispatcher blocks
- Generate entry block body + Cond → true_block / dispatcher_code
- Move tag extraction + switch into dispatcher branch
- ~50 lines changed

**Testing After Task 3.3.3**:
```bash
# Generated code should match JS structure
cd /tmp
~/projects/.../lua_of_ocaml.exe compile test_simple_printf.bc -o test_v3.lua

# Check structure
grep -A 5 "while true do" test_v3.lua | head -20
# Should see:
#   while true do
#     if type(...) == "number" then
#       return ...
#     end
#     local tag = ...[1] or 0

# Test
lua test_v3.lua  # Might work or have new error
```

---

### Task 3.3.4: Test and Debug Printf

**Test Cases**:

1. **Simple Printf** (test_simple_printf.ml):
   ```ocaml
   let () = Printf.printf "Hello\n"
   ```
   Expected output: `Hello`

2. **Hello World** (test_hello_world.ml):
   ```ocaml
   let () = Printf.printf "Hello, World!\n"
   ```
   Expected output: `Hello, World!` ← **THIS IS THE GOAL!**

3. **Format Specifier** (test_printf_format.ml):
   ```ocaml
   let () = Printf.printf "Test: %s\n" "value"
   ```
   Expected output: `Test: value`

**Debug Process**:

If Printf fails:
1. **Check generated structure**: Compare test_printf_final.lua with test_simple_printf_js.js
2. **Check variable initialization**: grep for v343, v341, v342 assignments
3. **Check type check**: Should see `type(_V.v343) == "number"`
4. **Check tag extraction**: Should see `_V.v204 = _V.v343[1] or 0`
5. **Check case bodies**: Should see blocks inlined, not jumps
6. **Add debug output**: If still failing, add print statements

**Common Issues**:
- Missing primitive implementations (runtime errors)
- Incorrect variable scoping (_V vs local)
- Wrong dispatch variable (v204 vs v343)
- Back-edge logic incorrect (variables not updated)

**Tools**:
```bash
# Compare outputs
node test_simple_printf_js.js  # JS version (works)
lua test_printf_final.lua      # Lua version (should work)
diff <(node ...) <(lua ...)     # Should be identical

# Debug runtime
just compile-lua-debug /tmp/test_simple_printf.bc
# Adds source map for better error messages
```

---

### Task 3.3.5: Verify No Regressions

**Test Suite**:
```bash
# Simple closure (uses address-based dispatch)
just quick-test /tmp/test_simple_dep.ml
# Expected: 11

# Variant test (may use data-driven if Switch present)
just quick-test /tmp/test_variant_simple.ml
# Expected: 6

# Full test suite
just test-lua
# Expected: Same pass/fail as before Task 3.3
```

**Check Data-Driven Dispatch Stats**:
```bash
# How many closures use data-driven dispatch?
grep -c "TRIGGERED.*data-driven" compilation_output.txt

# File size improvements
ls -lh test_printf_*.lua
# Address-based: ~1.1MB (24k lines)
# Data-driven: ~850KB (19k lines) ← 23% smaller
```

**Success Criteria**:
- ✅ Printf works (outputs "Hello, World!")
- ✅ Simple closures work (no regressions)
- ✅ Test suite: no new failures
- ✅ Data-driven dispatch reduces code size
- ✅ All optimizations (Tasks 2.1-3.3) combined work correctly

---

## Detailed Code Structure Comparison

### JS (compiler/lib/generate.ml + generated .js)

**Closure Compilation**:
```
compile_closure (pc, args)
  ↓
build_graph (creates state with blocks, visited set)
  ↓
compile_branch state (pc, args) stack
  ↓
compile_block (generates body)
  ↓
compile_terminator (Branch/Cond/Switch/Return)
  ↓
  For Switch: compile_switch
    ↓
    for(;;) { switch(x) { case 0: compile_branch(...); case 1: ...; } }
```

**Variable Management**:
- Handled in compile_branch via `parallel_renaming`
- Arguments assigned to parameters before block body
- All inline, no separate setup phase

**Control Flow**:
- Natural recursion through compile_branch
- Each case calls compile_branch with target and args
- Continuation-passing ensures correct order

### Our Lua (Current - Address-Based)

**Closure Compilation**:
```
compile_blocks_with_labels (start_addr, params, entry_args)
  ↓
detect_dispatch_mode
  ↓
compile_address_based_dispatch
  ↓
  1. collect_block_variables (collect all vars)
  2. setup_hoisted_variables (create _V table)
  3. setup_function_parameters (copy params)
  4. setup_entry_block_arguments (initialize entry args)
  5. compile_reachable_blocks (generate dispatch loop)
     ↓
     for each block: generate_block_body + generate_last_dispatch
     ↓
     while _next_block do
       if _next_block == 462 then ... end
       if _next_block == 464 then ... end
     end
```

**Variable Management**:
- Separate setup phase before dispatch loop
- All variables hoisted upfront
- Parameters copied after hoisting
- Entry args initialized after parameters

**Control Flow**:
- Iterative (collect all blocks, generate dispatch loop)
- Address-based jumping (_next_block = 464)
- Order determined by block addresses

### Our Lua (Needed - Data-Driven)

**Closure Compilation**:
```
compile_blocks_with_labels (start_addr, params, entry_args)
  ↓
detect_dispatch_mode → DataDriven
  ↓
compile_data_driven_dispatch
  ↓
  1. collect_and_hoist_variables (SAME as address-based)
  2. setup_function_parameters (SAME as address-based)
  3. setup_entry_block_arguments (SAME as address-based)
  4. generate_value_based_dispatch_loop (NEW - matches JS)
     ↓
     while true do
       -- Entry block body + Cond
       if type(fmt) == "number" then return ... end
       local tag = fmt[1] or 0

       -- Switch on tag (matches JS switch statement)
       if tag == 0 then ... (inline block 464 body) ...
       elseif tag == 1 then ... (inline block 465 body) ...
       ...
     end
```

**Variable Management**: IDENTICAL to address-based (use extracted helpers)

**Control Flow**: Value-based dispatch (like JS) instead of address-based

---

## Key Differences: Address-Based vs Data-Driven

| Aspect | Address-Based | Data-Driven (JS-like) |
|--------|---------------|------------------------|
| **Dispatch Variable** | `_next_block` (address) | `tag` (data value) |
| **Loop Structure** | `while true do if _next_block == 462 then` | `while true do if tag == 0 then` |
| **Case Bodies** | Block code at each address | Inline case code |
| **Variable Setup** | Same (hoist, params, entry args) | Same (hoist, params, entry args) |
| **Control Flow** | Jump to addresses | Switch on values |
| **Entry Point** | First block to execute | Entry block + type check |
| **Back-Edges** | `_next_block = 800` | Update loop vars, continue |
| **Code Size** | Larger (24k lines) | Smaller (19k lines, 21% reduction) |
| **Matches JS** | No (JS doesn't use addresses) | Yes (JS uses switch) |

---

## Why This Refactor is Critical

### Problem 1: Code Duplication
Currently:
- compile_address_based_dispatch: Full implementation (~600 lines)
- compile_data_driven_dispatch: Incomplete prototype (~80 lines)
- Duplication: Variable management logic

Solution:
- Shared helpers: Variable management (~200 lines)
- Address-based: Helpers + address dispatch loop (~400 lines)
- Data-driven: Helpers + value dispatch loop (~150 lines)
- **Total**: Same lines, but shared and maintainable

### Problem 2: Printf Doesn't Work
Current implementation can't handle Printf because:
- Detection works but code generation incomplete
- Missing variables cause silent failures or nil errors

Solution:
- Complete code generation with proper variable management
- Printf will work like it does in JS

### Problem 3: Not Matching js_of_ocaml
Our address-based approach is fundamentally different from JS's value-based approach.
This causes:
- Harder to debug (can't compare with JS)
- Block dependency issues (Tasks 2.7, 2.8, 3.1, 3.2)
- Larger code size

Solution:
- Data-driven dispatch matches JS structure
- Direct comparison possible
- Natural variable flow, no dependency issues

---

## Success Metrics

### After Task 3.3 Complete

**Printf Works**:
```bash
$ cat > /tmp/hello.ml << 'EOF'
let () = Printf.printf "Hello, World!\n"
EOF
$ ocamlc -o hello.bc hello.ml
$ lua_of_ocaml compile hello.bc -o hello.lua
$ lua hello.lua
Hello, World!  ← SUCCESS!
```

**Code Quality**:
- Data-driven files: 21% smaller
- Matches JS structure
- No block dependency issues
- Clean, readable dispatch loops

**Test Suite**:
- All previous tests pass
- Printf tests now work
- No regressions

**Milestone**: Phase 3 (Printf primitives) can begin because Printf dispatch works!

---

## Next Task

**Task 3.3.1** - Extract variable management functions

This is a pure refactor (no behavior change) that enables Tasks 3.3.2-3.3.5.
