# Task 2.5.2: IR Control Flow Analysis

## Date: 2025-10-12

## Executive Summary

Analyzed js_of_ocaml's IR (Intermediate Representation) to understand how control flow terminators map to JavaScript code generation. The key insight is that **Switch terminators on dispatch variables** combined with **loop detection** create the for-loop + switch pattern seen in Printf.

## IR Structure

### Block Terminators (Code.last)

```ocaml
type last =
  | Return of Var.t                            (* Return value *)
  | Raise of Var.t * exception_kind            (* Raise exception *)
  | Stop                                        (* Stop execution *)
  | Branch of cont                             (* Unconditional jump *)
  | Cond of Var.t * cont * cont                (* if var then c1 else c2 *)
  | Switch of Var.t * cont array               (* switch on var *)
  | Pushtrap of cont * Var.t * cont            (* Exception handling *)
  | Poptrap of cont                            (* Pop exception handler *)

and cont = Addr.t * Var.t list  (* continuation: (block_address, arguments) *)
```

**Key terminators for dispatch**:
- **Branch(pc, args)**: Unconditional jump to block pc with arguments args
- **Cond(v, c1, c2)**: Conditional branch based on variable v
- **Switch(v, conts)**: Multi-way branch based on variable v's value

### Block Structure

```ocaml
type block =
  { params : Var.t list     (* Block parameters - like function arguments *)
  ; body : instr list       (* Instructions in the block *)
  ; branch : last           (* Block terminator - how we exit *)
  }

type program =
  { start : Addr.t                 (* Entry block address *)
  ; blocks : block Addr.Map.t      (* Map from address to block *)
  ; free_pc : Addr.t               (* Next available block address *)
  }
```

## JS Code Generation Pipeline

### 1. Decision Tree (DTree) Intermediate

js_of_ocaml converts IR terminators to a decision tree before generating JS:

```ocaml
module DTree = struct
  type 'a t =
    | If of cond * 'a t * 'a t      (* Conditional branch *)
    | Switch of 'a branch array     (* Multi-way switch *)
    | Branch of 'a branch           (* Leaf: jump to continuation *)

  type cond =
    | IsTrue                        (* if var *)
    | CEq of Targetint.t           (* if var == n *)
    | CLt of Targetint.t           (* if var < n *)
    | CLe of Targetint.t           (* if var <= n *)
end
```

**Conversion**:
- `Code.Cond(v, c1, c2)` → `DTree.build_if` → `DTree.If(IsTrue, ...)`
- `Code.Switch(v, conts)` → `DTree.build_switch` → `DTree.Switch(...)` or optimized `DTree.If`

**Optimization**: `build_switch` optimizes small switches:
- All same target → Branch
- Only 2 branches → If with CEq or CLt
- ≤ max_cases → Switch
- Otherwise → Binary decision tree (split recursively)

### 2. Loop Detection

```ocaml
(* generate.ml:1924 *)
match Structure.is_loop_header st.structure pc with
| false -> compile_block_no_loop ...
| true  ->
    (* Generate for(;;) { ... } *)
    J.For_statement (J.Left None, None, None, Js_simpl.block body), loc
```

**Structure module** analyzes the control flow graph:
- Detects back edges (loops)
- Identifies loop headers
- Builds dominator tree

When a block is a loop header, js_of_ocaml generates:
```javascript
for(;;){
  // Loop body with switch/if inside
}
```

### 3. From Terminator to JS

**Branch** (generate.ml:2147):
```ocaml
| Branch cont -> compile_branch st loc queue cont scope_stack ~fall_through
```
→ Direct jump (may be optimized away if fall-through)

**Cond** (generate.ml:2194):
```ocaml
| Cond (x, c1, c2) ->
    compile_decision_tree "Bool" st scope_stack ~fall_through
      loc_before cx loc (DTree.build_if c1 c2)
```
→ JavaScript if-statement:
```javascript
if(condition){
  // c1 code
}
else{
  // c2 code
}
```

**Switch** (generate.ml:2212):
```ocaml
| Switch (x, a1) ->
    compile_decision_tree "Int" st scope_stack ~fall_through
      loc_before cx loc (DTree.build_switch a1)
```
→ JavaScript switch statement:
```javascript
switch(var){
  case 0: /* code */ break;
  case 1: /* code */ break;
  // ...
  default: /* code */
}
```

## Printf Closure Control Flow

### Inferred IR Structure

Based on the JS output analysis from Task 2.5.1, Printf's IR structure is:

**Entry Block** (loop header):
- **Parameters**: `[counter; k; acc; fmt]`
- **Body**:
  - Check if `typeof fmt === "number"` → return if true
- **Terminator**: `Switch(fmt_tag, cases)`
  - `fmt_tag = fmt[0]` (extract tag from variant)
  - `cases` = array of 25 continuations (cases 0-23 + default)

**Loop Structure**:
```
Block_entry (loop header):
  params: [counter, k, acc, fmt]
  body: []
  branch: Switch(fmt_tag, [
    case_0 -> Block_case_0,
    case_1 -> Block_case_1,
    ...
    case_23 -> Block_case_23,
    default -> Block_default
  ])

Block_case_0:
  // Handle format case 0 (String with no padding)
  branch: Branch(Block_after_loop_a, [args])

Block_case_10:
  // Handle format case 10 (Flush)
  body: [
    acc' = [7, acc]
    fmt' = fmt[1]
  ]
  branch: Branch(Block_entry, [counter, k, acc', fmt'])  (* Back edge! *)

Block_case_18:
  // Handle format case 18 (Meta-format - most complex)
  body: [
    /* Complex nested logic */
  ]
  branch: Cond(condition,
    Branch(Block_entry, [counter, k', acc', fmt']),  (* Back edge! *)
    Branch(Block_entry, [counter, k'', acc'', fmt'']))  (* Back edge! *)

// ... more case blocks ...

Block_after_loop_a:
  // Code that handles breaks to label 'a'
  // ...
```

**Key Observations**:
1. **Loop detection**: Back edges from case blocks to Block_entry
2. **Dispatch variable**: The variable in Switch terminator (fmt_tag)
3. **Continuations**: Some jump back (continue loop), some jump out (break)
4. **Nested labels**: Multiple "after loop" blocks for different break targets

### Control Flow Graph

```
                    Entry (loop header)
                           |
                    Switch(fmt_tag)
                    /    |    |    \
                   /     |    |     \
              case_0  case_1  ...  case_23  default
                 |       |           |         |
                 |       |     [modify vars]   |
                 |       |           |         |
          [break to a]   |      [back edge]   |
                 |       |       ↑   |         |
                 |       |       |   |         |
                 |  [break to b] |   |   [call other func]
                 |       |       |   |         |
                 |       ↓       |   ↓         ↓
           after_loop_a  after_loop_b  Entry  return
```

**Loop Pattern**:
- Entry block is loop header
- Back edges: Some cases jump back to Entry with modified variables
- Break edges: Some cases jump to after-loop blocks
- Fall-through: Some cases return directly

## Dispatch Variable Identification

### How to Find Dispatch Variables

1. **Look for Switch terminators** in the IR
2. **The first argument is the dispatch variable**: `Switch(v, conts)` → `v` is the dispatch variable
3. **In Printf**: The Switch is on the tag of the fmt variant

**In JS**:
```javascript
var k = k$2, acc = acc$4, fmt = fmt$2;  // Variables from parameters
for(;;){
  if(typeof fmt === "number") return ...;
  switch(fmt[0]){  // ← fmt[0] is the dispatch variable (tag)
    case 0: ...
    case 1: ...
    // ...
  }
}
```

**In IR** (inferred):
```ocaml
Block_entry:
  params: [counter; k_param; acc_param; fmt_param]
  body: [
    Let(k, Var(k_param));
    Let(acc, Var(acc_param));
    Let(fmt, Var(fmt_param));
    Let(fmt_tag, Prim(Field(fmt, 0)));  (* Extract tag *)
  ]
  branch: Switch(fmt_tag, cases)
```

### Multiple Dispatch Variables

Some closures may have multiple Switch terminators at different points:
- Each Switch has its own dispatch variable
- Variables may be modified between switches
- Printf primarily dispatches on `fmt`, but nested logic may switch on other vars

## Implications for Lua Refactor

### Current Lua Approach (Address-Based)

```lua
local _next_block = 484  -- Entry block address (WRONG!)

while true do
  if _next_block == 482 then
    _V.v270 = _V.v343[2]  -- Sets v270
    -- ...
    _next_block = 484
  elseif _next_block == 484 then
    _V.v278 = _V.v343[3]
    _V.v279 = _V.v270[2]  -- Uses v270 (nil if entered directly!)
    -- ...
  end
end
```

**Problem**:
- Entry block address hardcoded (484)
- No guarantee v270 is set before block 484 runs
- Address-based dispatch doesn't match IR semantics

### Correct Lua Approach (Data-Based)

Match the IR structure exactly:

```lua
function closure(counter, k_param, acc_param, fmt_param)
  local k = k_param
  local acc = acc_param
  local fmt = fmt_param

  while true do
    -- Check termination condition
    if type(fmt) == "number" then
      return caml_call1(k, acc)
    end

    -- Extract dispatch variable (tag)
    local fmt_tag = fmt[1]  -- Lua is 1-indexed, so tag is at [1]

    -- Switch on dispatch variable
    if fmt_tag == 0 then
      -- case 0: break to label 'a'
      local rest = fmt[3]
      local ign = fmt[2]
      -- ... handle case 0 ...

    elseif fmt_tag == 1 then
      -- case 1: break to label 'b'
      -- ... handle case 1 ...

    elseif fmt_tag == 10 then
      -- case 10: modify vars and continue loop
      acc = {7, acc}
      fmt = fmt[2]
      -- Loop continues (no break/return)

    elseif fmt_tag == 18 then
      -- case 18: complex nested logic
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
        -- ... other branch ...
      end

    -- ... more cases ...

    else
      -- default case
      -- ... handle default ...
    end
  end
end
```

**Key differences**:
- ✅ Variables initialized from parameters BEFORE loop
- ✅ Dispatch on DATA (fmt_tag) not addresses
- ✅ Switch structure matches IR Switch terminator
- ✅ No uninitialized variable bugs

## Summary

### Key Findings

1. **IR Terminators → JS Mapping**:
   - `Switch(v, conts)` → `switch(v[0]){ case 0: ...; case 1: ...; }`
   - `Cond(v, c1, c2)` → `if(v){ c1 } else { c2 }`
   - `Branch(pc, args)` → Direct jump (may be optimized away)

2. **Loop Generation**:
   - Structure module detects loops via back edges
   - Loop headers get `for(;;)` wrapper
   - Switch/Cond inside loop body

3. **Dispatch Variables**:
   - Identified from Switch terminator: `Switch(v, conts)` → v is dispatch var
   - In Printf: fmt_tag (extracted from fmt[0])
   - Variables must be initialized before dispatch

4. **Printf Control Flow**:
   - Entry block is loop header
   - Switch on fmt_tag (24 cases + default)
   - Some cases modify vars and loop back
   - Some cases break out to labeled blocks
   - Some cases return directly

### Files Analyzed

- `/home/snowbear/projects/js_of_ocaml/compiler/lib/code.ml` (IR definitions)
- `/home/snowbear/projects/js_of_ocaml/compiler/lib/generate.ml` (JS generation)
  - Lines 823-938: DTree module (decision tree intermediate)
  - Lines 1924-1954: Loop detection and for-loop generation
  - Lines 2002-2097: compile_decision_tree (DTree → JS)
  - Lines 2147-2229: Terminator compilation (Branch/Cond/Switch)
  - Lines 2319-2339: compile_closure (entry point)

### Recommendations for Lua

1. **Match IR structure**: Generate Lua code that mirrors the IR, not the addresses
2. **Initialize variables**: All dispatch variables must be set before entering dispatch loop
3. **Data-driven dispatch**: Use if-elseif chain on variable values, not block numbers
4. **Preserve semantics**: Each IR block becomes an if-branch, not an address case

## Next Steps (Task 2.5.3+)

Task 2.5.3 will design the Lua data-driven dispatch:
- Convert Switch terminator to if-elseif chain
- Map cont (pc, args) to Lua code blocks
- Handle variable initialization correctly
- Preserve loop semantics (back edges)

The key insight: **Follow the IR terminators, not the block addresses!**
