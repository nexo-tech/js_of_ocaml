# Task 2.5.3: Lua Data-Driven Dispatch Design

## Date: 2025-10-12

## Executive Summary

Design for refactoring lua_of_ocaml's closure generation to use **data-driven dispatch** matching js_of_ocaml's approach. This fixes the Printf bug and aligns Lua generation with IR semantics.

## Problem Statement

**Current Lua approach** (address-based):
```lua
function closure(param1, param2, param3)
  local _V = {}
  -- Variables hoisted to _V table
  _V.v270 = nil
  _V.v343 = nil
  -- ...

  local _next_block = 484  -- Entry block ADDRESS

  while true do
    if _next_block == 482 then
      _V.v270 = _V.v343[2]  -- Sets v270
      -- ...
      _next_block = 484
    elseif _next_block == 484 then
      _V.v278 = _V.v343[3]
      _V.v279 = _V.v270[2]  -- ERROR: v270 may be nil!
      -- ...
    end
  end
end
```

**Problems**:
1. Entry block hardcoded (484) - not semantic
2. Variables not initialized from parameters before dispatch
3. Address-based dispatch doesn't match IR semantics
4. Printf bug: v270 used before initialization on entry path

## Design Goals

1. **Match IR semantics**: Dispatch based on data (variables), not addresses
2. **Match JS approach**: Variables initialized before dispatch loop
3. **Fix Printf bug**: No uninitialized variables in entry path
4. **Preserve compatibility**: Keep _V table pattern, support >180 vars
5. **Incremental adoption**: Only change closures that need it

## Data-Driven Dispatch Design

### Core Concept

**Key insight from IR analysis** (Task 2.5.2):
- Switch terminators have a **dispatch variable**: `Switch(v, conts)`
- Printf entry block: `Switch(fmt_tag, cases)` where fmt_tag drives control flow
- Loop detection: Back edges from cases to entry block

**Transformation**:
```
IR:  Entry block → Switch(dispatch_var, cases) → case blocks (some loop back)
        ↓
Lua: function() → init vars → while true do → if dispatch_var == X then ... end
```

### New Lua Structure

```lua
function closure(counter, k_param, acc_param, fmt_param)
  -- Step 1: Variable hoisting (UNCHANGED)
  local _V = {}
  _V.v100 = nil
  -- ... (existing hoisting logic)

  -- Step 2: Initialize dispatch variables from parameters (NEW!)
  local k = k_param
  local acc = acc_param
  local fmt = fmt_param

  -- Step 3: Data-driven dispatch loop (NEW!)
  while true do
    -- Termination check
    if type(fmt) == "number" then
      return caml_call1(k, acc)
    end

    -- Extract dispatch variable (tag from variant)
    local fmt_tag = fmt[1]  -- Lua 1-indexed

    -- Dispatch on data, not addresses
    if fmt_tag == 0 then
      -- Case 0: Handle format type 0
      local rest = fmt[3]
      local ign = fmt[2]
      -- ... case 0 logic ...
      -- Break or return (exit loop)
      return some_value

    elseif fmt_tag == 1 then
      -- Case 1: Handle format type 1
      -- ...
      return some_value

    elseif fmt_tag == 10 then
      -- Case 10: Modify variables and continue loop
      acc = {7, acc}
      fmt = fmt[2]
      -- No break/return - loop continues!

    elseif fmt_tag == 18 then
      -- Case 18: Complex nested logic
      local a = fmt[2]
      if a[1] == 0 then
        local rest = fmt[3]
        local fmt_inner = a[2][2]
        k = function(kacc)
          return make_printf(k, {1, acc, {0, kacc}}, rest)
        end
        acc = 0
        fmt = fmt_inner
        -- Loop continues
      else
        -- Other branch
        -- ...
      end

    -- ... more cases ...

    else
      -- Default case
      -- ...
    end
  end
end
```

### Key Differences from Current Approach

| Aspect | Current (Address-Based) | New (Data-Driven) |
|--------|------------------------|-------------------|
| **Dispatch variable** | `_next_block` (block address) | Dispatch variable from IR (e.g., `fmt_tag`) |
| **Variable init** | Not guaranteed before dispatch | Always before dispatch loop |
| **Loop structure** | `while true do if _next_block == X` | `while true do if dispatch_var == X` |
| **Terminator handling** | Set `_next_block = addr` | Modify dispatch vars, continue loop |
| **Semantics** | Address-based (implementation detail) | Data-driven (matches IR) |
| **Printf bug** | YES (entry path skips init) | NO (vars always initialized) |

## Dispatch Mode Detection

Not all closures need data-driven dispatch. Detect when to use it:

### Decision Algorithm

```ocaml
type dispatch_mode =
  | AddressBased  (* Current approach - simple cases *)
  | DataDriven of {
      dispatch_var : Code.Var.t;      (* Variable that drives dispatch *)
      entry_block : Code.Addr.t;       (* Entry block address *)
      loop_blocks : Code.Addr.Set.t;   (* Blocks in the loop *)
    }

let detect_dispatch_mode program start_addr =
  match Code.Addr.Map.find_opt start_addr program.Code.blocks with
  | None -> AddressBased
  | Some entry_block ->
      (* Check if entry block is a loop header *)
      let loop_headers = detect_loop_headers program start_addr in
      if not (Code.Addr.Set.mem start_addr loop_headers) then
        AddressBased  (* Not a loop header - use address-based *)
      else
        (* Entry block is loop header - check terminator *)
        match entry_block.Code.branch with
        | Code.Switch (dispatch_var, conts) ->
            (* Has Switch terminator - use data-driven! *)
            let loop_blocks = collect_loop_blocks program start_addr conts in
            DataDriven { dispatch_var; entry_block = start_addr; loop_blocks }
        | Code.Cond (dispatch_var, cont_true, cont_false) ->
            (* Has Cond terminator - could use data-driven if complex *)
            (* For now: Only use data-driven for Switch *)
            AddressBased
        | _ ->
            AddressBased  (* Other terminators - use address-based *)
```

**Heuristic**: Use data-driven dispatch if:
1. Entry block is a loop header (has back edges)
2. Entry block has Switch terminator
3. Switch has multiple cases (≥ 3)

### Implementation Strategy

**Phase 1** (Task 2.5.4-2.5.5):
- Implement data-driven dispatch for Switch-based loops only
- Keep address-based for everything else
- Add mode detection logic

**Phase 2** (Future):
- Extend to Cond-based loops if needed
- Optimize mixed dispatch (some blocks data-driven, some address-based)

## Variable Initialization Strategy

### Dispatch Variables

Variables that control dispatch must be initialized BEFORE loop:

```lua
-- From IR: Entry block params: [counter, k, acc, fmt]
function closure(counter, k_param, acc_param, fmt_param)
  local _V = {}

  -- Initialize dispatch variables from parameters
  local k = k_param
  local acc = acc_param
  local fmt = fmt_param

  -- Now enter dispatch loop - variables are ready!
  while true do
    -- Can safely use k, acc, fmt
    if type(fmt) == "number" then
      return caml_call1(k, acc)
    end
    -- ...
  end
end
```

### With _V Table (>180 vars)

When using _V table, dispatch variables should be LOCAL, not in _V:

```lua
function closure(counter, k_param, acc_param, fmt_param)
  -- _V table for hoisted variables
  local _V = {}
  _V.v100 = nil
  _V.v101 = nil
  -- ... (many variables)

  -- Dispatch variables are LOCAL (frequently modified in loop)
  local k = k_param
  local acc = acc_param
  local fmt = fmt_param

  while true do
    -- Dispatch on locals (fast access)
    local fmt_tag = fmt[1]
    if fmt_tag == 0 then
      -- Can mix local and _V access
      local rest = fmt[3]
      _V.temp = rest  -- Hoisted var
      -- ...
    elseif fmt_tag == 10 then
      -- Modify local dispatch var
      acc = {7, acc}
      fmt = fmt[2]
      -- Loop continues
    end
  end
end
```

**Rationale**:
- Dispatch variables modified frequently in loop
- Local access faster than table access
- Only use _V for variables that hit 200 local limit

### Initialization Order (CRITICAL!)

```lua
function closure(...params...)
  -- 1. Hoist declarations (existing logic)
  local _V = {}
  _V.var1 = nil
  _V.var2 = nil
  -- ...

  -- 2. Copy function parameters to _V if needed (existing logic)
  if use_var_table then
    _V.param1 = param1
    _V.param2 = param2
  end

  -- 3. Initialize dispatch variables (NEW!)
  --    These are LOCAL, initialized from parameters or _V
  local dispatch_var1 = param1  -- or _V.param1 if in table
  local dispatch_var2 = param2

  -- 4. Dispatch loop (modified)
  while true do
    -- Dispatch logic using dispatch_var1, dispatch_var2
  end
end
```

## Switch Terminator Transformation

### IR Switch Structure

```ocaml
Code.Switch (var, conts)
where:
  var : Code.Var.t           (* Dispatch variable *)
  conts : cont array         (* Array of continuations *)
  cont = (Addr.t * Var.t list)  (* (target_block, arguments) *)
```

### Current Lua Generation (Address-Based)

From `generate_last_dispatch` (lua_generate.ml:1443-1462):

```lua
-- Current: Switch on var, then set _next_block
if var == 0 then
  -- Argument passing
  target_param1 = source_var1
  target_param2 = source_var2
  _next_block = target_addr
elseif var == 1 then
  -- Argument passing
  _next_block = other_addr
-- ...
end
```

**Problem**: Still uses address-based dispatch after Switch!

### New Lua Generation (Data-Driven)

```lua
-- New: Switch on var, handle case inline
if var == 0 then
  -- Case 0 logic (from target block body)
  -- ... block body statements ...

  -- Block terminator determines next action:
  -- Option 1: Return (exit loop)
  return some_value

  -- Option 2: Continue loop with modified vars
  dispatch_var = new_value
  -- (no break - loop continues)

  -- Option 3: Break to outer label (future: nested structure)
  -- For now: Handle as return or error

elseif var == 1 then
  -- Case 1 logic
  -- ...
end
```

**Key changes**:
1. Inline target block body into case
2. Transform target block terminator:
   - `Return x` → `return x`
   - `Branch (entry, new_vars)` → Assign new_vars, continue loop
   - `Branch (other, _)` → Return or error (breaking out)

### Inlining vs Separate Blocks

**Design choice**: Inline case blocks into switch, or keep separate?

**Option A: Inline** (RECOMMENDED):
```lua
if fmt_tag == 0 then
  -- Case 0 code inlined here
  local rest = fmt[3]
  -- ... case logic ...
  return value
elseif fmt_tag == 10 then
  -- Case 10 code inlined here
  acc = {7, acc}
  fmt = fmt[2]
  -- Continue loop
end
```

**Pros**:
- Simpler code generation
- Matches JS structure (switch with inline cases)
- No label/goto needed (Lua 5.1 doesn't have goto)
- Clearer control flow

**Cons**:
- Code duplication if block reached from multiple places
- Need to handle blocks shared by multiple switches

**Option B: Separate blocks with dispatch chain**:
```lua
while true do
  if dispatch_state == "switch_at_entry" then
    local fmt_tag = fmt[1]
    if fmt_tag == 0 then
      dispatch_state = "block_500"
    -- ...
    end
  elseif dispatch_state == "block_500" then
    -- Block 500 code
    -- ...
  end
end
```

**Pros**:
- Handles shared blocks easily
- Closer to current implementation

**Cons**:
- Still address-based (dispatch_state = "block_500")
- Doesn't fix the root problem
- More complex

**Decision**: Use **Option A (Inline)** with fallback to address-based for complex cases.

## Loop Back-Edge Handling

### Detecting Back Edges

A continuation is a back edge if it jumps to the entry block (or loop header):

```ocaml
match block.Code.branch with
| Code.Switch (var, conts) ->
    Array.iteri conts ~f:(fun idx (target_addr, args) ->
      if target_addr = entry_block_addr then
        (* Back edge! This case loops back *)
        (* Generate: Assign args to dispatch vars, continue loop *)
      else
        (* Forward edge: Exit loop or jump to other block *)
    )
```

### Generating Back Edges

**Back edge = Modify dispatch variables and continue loop**:

```lua
elseif fmt_tag == 10 then
  -- Case 10: Back edge to entry block
  -- Arguments to entry block become new dispatch var values

  -- From IR: Branch (entry_addr, [new_k, new_acc, new_fmt])
  -- Generate:
  k = new_k_value
  acc = new_acc_value
  fmt = new_fmt_value
  -- No break/return - loop continues to next iteration
```

### Argument Mapping for Back Edges

```ocaml
(* From IR *)
Branch (entry_addr, [arg1, arg2, arg3])

(* Entry block params *)
entry_block.params = [param1, param2, param3]

(* Generate Lua *)
param1 = arg1_expr
param2 = arg2_expr
param3 = arg3_expr
(* Continue loop *)
```

**Example from Printf**:
```
IR: Case 10 → Branch (entry, [counter, k, {7, acc}, fmt[1]])

Lua:
elseif fmt_tag == 10 then
  -- counter unchanged
  -- k unchanged
  acc = {7, acc}      -- Modify acc
  fmt = fmt[2]        -- Modify fmt
  -- Loop continues
end
```

## Trampolines, Tail Calls, and Returns

### Current Lua Approach

No trampolines in current Lua generation - relies on Lua's tail call optimization:

```lua
return some_function(args)  -- Lua optimizes tail calls
```

### JS Trampoline Pattern

From Task 2.5.1 analysis (JS Printf):

```javascript
if(counter >= 50)
  return caml_trampoline_return(make_custom$0, [0, k, acc, rest, arity, b]);
var counter$0 = counter + 1 | 0;
return make_custom$0(counter$0, k, acc, rest, arity, b);
```

**Purpose**: Prevent stack overflow in deeply nested recursive calls.

### Lua Design

**Option 1: No trampolines** (RECOMMENDED for now):
- Lua has proper tail call optimization (when calls are in tail position)
- Printf cases mostly return directly or loop (already stack-safe)
- Simpler implementation

**Option 2: Emulate JS trampolines** (Future optimization):
```lua
local counter = 0

while true do
  -- Dispatch logic

  if fmt_tag == 24 then  -- default case
    -- Call other function
    if counter >= 50 then
      -- Return trampoline object
      return {
        func = make_custom,
        args = {k, acc, rest, arity, b}
      }
    end
    counter = counter + 1
    return make_custom(k, acc, rest, arity, b)
  end
end
```

**Decision**: Start with **Option 1** (no trampolines), add later if needed.

### Return Handling

**Direct returns** (from switch cases):
```lua
if fmt_tag == 0 then
  -- Case that returns directly
  return some_value  -- Exit function
end
```

**Returns after function calls**:
```lua
if fmt_tag == 3 then
  -- Call helper function and return result
  return make_padding(k, acc, rest, pad, converter)
end
```

Both work fine with Lua's tail call optimization.

## Preserving _V Table Pattern

### Why _V Table Matters

Lua 5.1 has a **200 local variable limit** per function. Printf closures have 180+ variables, requiring table storage.

### _V Table with Data-Driven Dispatch

**Key insight**: Dispatch variables should be LOCAL, hoisted variables in _V:

```lua
function closure(counter, k_param, acc_param, fmt_param)
  -- _V table for 180+ hoisted variables
  local _V = {}
  _V.v100 = nil
  _V.v101 = nil
  -- ... up to v280

  -- Dispatch variables are LOCAL (modified in loop, need fast access)
  local counter = counter_param  -- Or just use parameter directly
  local k = k_param
  local acc = acc_param
  local fmt = fmt_param

  -- Dispatch loop
  while true do
    -- Fast local access for dispatch
    if type(fmt) == "number" then
      return caml_call1(k, acc)
    end

    local fmt_tag = fmt[1]

    if fmt_tag == 0 then
      -- Can access both locals and _V
      local rest = fmt[3]  -- Local
      _V.temp_var = rest   -- Hoisted var in table
      -- ...
    end
  end
end
```

**Variable Classification**:
1. **Dispatch variables**: Local (k, acc, fmt) - modified in loop
2. **Hoisted variables**: _V table (v100, v101, ...) - used occasionally
3. **Function parameters**: Local or _V depending on count

### Variable Count Threshold

Current threshold: **180 variables** → use _V table

**Adjustment for data-driven dispatch**:
- Dispatch variables (typically 3-5) are LOCAL
- Remaining variables go in _V if total > 180
- Effective threshold: If (total_vars - dispatch_vars) > 175 → use _V

**Example**:
- Printf: 185 total variables
- Dispatch: 4 (counter, k, acc, fmt)
- Hoisted: 181
- Decision: Use _V table for hoisted (181 > 175)

## Implementation Plan

### Modified Functions

**lua_generate.ml** changes:

1. **detect_dispatch_mode** (NEW):
   ```ocaml
   val detect_dispatch_mode : Code.program -> Code.Addr.t -> dispatch_mode
   ```
   - Detect if closure needs data-driven dispatch
   - Return AddressBased or DataDriven with dispatch info

2. **compile_blocks_with_labels** (MODIFY):
   ```ocaml
   (* Current signature - unchanged *)
   val compile_blocks_with_labels :
     ctx -> Code.program -> Code.Addr.t ->
     ?params:Var.t list -> ?entry_args:Var.t list ->
     ?func_params:Var.t list -> unit -> L.stmt list
   ```

   **Changes**:
   - Call detect_dispatch_mode at start
   - Branch based on mode:
     - AddressBased: Keep current logic
     - DataDriven: Use new logic

3. **compile_data_driven_dispatch** (NEW):
   ```ocaml
   val compile_data_driven_dispatch :
     ctx -> Code.program -> Code.Addr.t -> dispatch_info -> L.stmt list
   ```
   - Generate data-driven dispatch loop
   - Initialize dispatch variables from parameters
   - Generate switch cases inline
   - Handle back edges

4. **generate_switch_case** (NEW):
   ```ocaml
   val generate_switch_case :
     ctx -> Code.program ->
     entry_addr:Code.Addr.t ->
     case_idx:int ->
     target_addr:Code.Addr.t ->
     args:Var.t list ->
     L.stmt list
   ```
   - Generate code for one switch case
   - Inline target block body
   - Transform terminator (return vs continue loop)

5. **is_back_edge** (NEW):
   ```ocaml
   val is_back_edge :
     entry_addr:Code.Addr.t ->
     target_addr:Code.Addr.t ->
     loop_blocks:Addr.Set.t ->
     bool
   ```
   - Check if continuation is a back edge

### Code Structure

```ocaml
and compile_blocks_with_labels ctx program start_addr
    ?(params = []) ?(entry_args = []) ?(func_params = []) () =

  (* Detect dispatch mode *)
  let dispatch_mode = detect_dispatch_mode program start_addr in

  match dispatch_mode with
  | AddressBased ->
      (* Keep current implementation *)
      compile_address_based_dispatch ctx program start_addr params entry_args func_params

  | DataDriven dispatch_info ->
      (* Use new data-driven dispatch *)
      compile_data_driven_dispatch ctx program start_addr dispatch_info params entry_args func_params

and compile_data_driven_dispatch ctx program start_addr dispatch_info params entry_args func_params =
  (* 1. Hoist variables (existing logic) *)
  let hoist_stmts = ... in

  (* 2. Initialize dispatch variables from parameters *)
  let dispatch_var_inits =
    generate_dispatch_var_inits ctx params dispatch_info.dispatch_vars
  in

  (* 3. Generate dispatch loop *)
  let dispatch_loop =
    generate_data_driven_loop ctx program start_addr dispatch_info
  in

  hoist_stmts @ dispatch_var_inits @ dispatch_loop
```

## Testing Strategy

### Unit Tests

1. **test_detect_dispatch_mode**: Test mode detection
   - Simple closures → AddressBased
   - Printf-like closures → DataDriven
   - Edge cases

2. **test_dispatch_var_init**: Test variable initialization
   - From parameters
   - With _V table
   - With mixed locals/_V

3. **test_switch_case_inline**: Test case inlining
   - Simple return cases
   - Back edge cases
   - Complex nested cases

### Integration Tests

1. **test_simple_closure**: Existing simple closures still work
2. **test_printf_fix**: Printf.printf works correctly
3. **test_complex_switch**: Complex switch with multiple back edges
4. **test_var_table**: Closures with >180 vars still work

### Comparison Tests

Compare Lua output with JS output for same OCaml code:
```bash
just compare-outputs test_printf.ml
```

Expected: Same behavior (both print "Hello 42")

## Rollout Plan

### Phase 1: Task 2.5.4 (Prototype)
- Implement basic data-driven dispatch for simple test case
- Test with minimal switch (2-3 cases)
- Verify approach works

### Phase 2: Task 2.5.5 (Full Implementation)
- Implement complete dispatch mode detection
- Refactor compile_blocks_with_labels
- Handle all Printf cases
- Test with full Printf

### Phase 3: Task 2.5.6 (Testing & Verification)
- Run full test suite
- Compare Lua vs JS outputs
- Fix any edge cases
- Performance testing

### Phase 4: Task 2.5.7 (Optimization & Documentation)
- Optimize generated code size
- Add code comments
- Update architecture docs
- Commit and push

## Success Criteria

✅ Printf.printf "Hello, World!\n" works
✅ Printf.printf "Answer: %d\n" 42 works
✅ All existing simple closures still work
✅ Generated code is readable and efficient
✅ No warnings or errors in compilation
✅ Test suite passes (just test-lua)

## Appendix: Design Alternatives Considered

### Alternative 1: Fix Entry Block Dependencies Only

**Approach**: Keep address-based dispatch, but initialize v270 before dispatch loop.

**Rejected because**:
- Band-aid fix, doesn't address root cause
- Fragile (breaks if IR changes)
- Doesn't match IR semantics

### Alternative 2: Lua Goto with Labels

**Approach**: Use Lua 5.2+ goto for labeled breaks.

**Rejected because**:
- Lua 5.1 doesn't have goto
- LuaJIT based on Lua 5.1 (requirement)
- Breaking compatibility

### Alternative 3: Coroutines for Dispatch

**Approach**: Use Lua coroutines to simulate continuation passing.

**Rejected because**:
- Overly complex
- Performance overhead
- Doesn't match JS approach

## Summary

**Core design principles**:
1. **Data-driven dispatch**: Match IR semantics (Switch on variables, not addresses)
2. **Variable initialization**: Dispatch vars initialized before loop (no nil bugs)
3. **Incremental adoption**: Only change closures that need it (minimize risk)
4. **Preserve _V table**: Keep Lua 5.1 compatibility for >180 vars
5. **Match JS structure**: Follow proven working js_of_ocaml approach

**Next steps**: Implement prototype in Task 2.5.4.
