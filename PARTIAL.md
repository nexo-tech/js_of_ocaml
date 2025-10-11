# Partial Application Support in Lua_of_ocaml

This document outlines the implementation plan for proper partial application (currying) support in the Lua code generator.

## Problem Statement

OCaml supports partial application where functions can be called with fewer arguments than expected, returning a closure. The current Lua generator doesn't handle this correctly, causing Printf and other stdlib functions to fail.

**Current Issues**:
1. All functions wrapped as `{l = arity, f = function}` breaks primitives
2. Channel IDs passed as blocks instead of integers
3. Some functions not wrapped, causing `caml_call_gen` to fail
4. No distinction between exact calls and partial application

## JavaScript Approach (Reference)

js_of_ocaml handles this elegantly:
- Functions have `.l` property indicating arity
- When `exact` is true: call directly `f(args...)`
- When `exact` is false: check arity and either call directly or use `caml_call_gen`
- External primitives are NOT wrapped
- Runtime `caml_call_gen` handles under-application (partial), exact application, and over-application

## Proposed Approach

**Key Insight**: Don't wrap everything. Use a hybrid approach:
1. **Direct calls** for exact applications with known arity
2. **Conditional calls** for non-exact applications (check arity at runtime)
3. **No wrapping** for external primitives and built-in functions
4. **Selective wrapping** only for user-defined closures that need it

---

## Master Checklist

### Phase 1: Analysis and Design
- [x] Task 1.1: Analyze js_of_ocaml's function calling conventions
- [x] Task 1.2: Document OCaml function representation requirements
- [x] Task 1.3: Design Lua function calling strategy
- [ ] Task 1.4: Design arity tracking system

### Phase 2: Core Infrastructure
- [ ] Task 2.1: Implement function metadata tracking in code generator
- [ ] Task 2.2: Add arity annotation to generated closures
- [ ] Task 2.3: Create runtime helper for arity checking
- [ ] Task 2.4: Update caml_call_gen to handle all cases

### Phase 3: Code Generation Refactoring
- [ ] Task 3.1: Revert universal function wrapping
- [ ] Task 3.2: Implement conditional wrapping for closures
- [ ] Task 3.3: Fix function application generation
- [ ] Task 3.4: Handle exact vs non-exact calls correctly

### Phase 4: Primitive Handling
- [ ] Task 4.1: Identify all external primitives
- [ ] Task 4.2: Ensure primitives are never wrapped
- [ ] Task 4.3: Fix primitive function calls
- [ ] Task 4.4: Test primitive operations

### Phase 5: Format/Printf Fix
- [ ] Task 5.1: Trace Format module channel passing
- [ ] Task 5.2: Fix channel ID representation
- [ ] Task 5.3: Remove channel ID workarounds
- [ ] Task 5.4: Verify Printf works correctly

### Phase 6: Integration and Testing
- [ ] Task 6.1: Run hello.ml with all Printf statements
- [ ] Task 6.2: Create partial application test suite
- [ ] Task 6.3: Test curried function composition
- [ ] Task 6.4: Verify no TODOs or hacks remain
- [ ] Task 6.5: Update LUA.md Task M1.2 as complete

---

## Detailed Task Breakdown

### Phase 1: Analysis and Design

#### Task 1.1: Analyze js_of_ocaml's function calling conventions ✅
**Estimated Lines**: 50 (analysis/documentation)
**Deliverable**: Document analyzing `compiler/lib/generate.ml` function application

**Actions**:
1. Read `apply_fun_raw` in `compiler/lib/generate.ml`
2. Document how `exact` flag is used
3. Document when `caml_call_gen` is called
4. Note how function arity is checked (`.l` property)
5. Document the conditional logic for direct vs indirect calls

**Success Criteria**: Clear understanding of JS approach documented in PARTIAL.md

---

## Analysis Results (Task 1.1)

### Function Application in js_of_ocaml

**Location**: `compiler/lib/generate.ml:1048-1126` (`apply_fun_raw` function)

#### Key Components:

1. **The `exact` flag** (lines 1071-1096):
   - When `exact = true`: Direct function call without arity check
     ```javascript
     // Generated: f(a1, a2, a3)
     apply_directly real_closure params
     ```
   - When `exact = false`: Conditional call with runtime arity check
     ```javascript
     // Generated:
     // (f.l >= 0 ? f.l : f.l === f.length) === params.length
     //   ? f(a1, a2, a3)
     //   : caml_call_gen(f, [a1, a2, a3])
     ```

2. **Function arity representation** (lines 1074-1084):
   - Functions have a `.l` property indicating their arity
   - Arity check logic:
     - `f.l >= 0` → Direct arity stored
     - `f.l === f.length` → Arity equals JS function length (fallback)
     - Compare against `params.length`
   - **Critical insight**: Not all functions have `.l` property! The check handles both cases.

3. **When `caml_call_gen` is called** (lines 1087-1096):
   - Called when: `exact = false` AND arity doesn't match parameter count
   - Handles three cases:
     - **Under-application** (partial application): fewer args than arity
     - **Exact application**: args match arity (but took slow path)
     - **Over-application**: more args than arity (curry then apply)
   - Signature: `caml_call_gen(f, [arg1, arg2, ...])`
   - CPS variant: `caml_call_gen_cps(f, [args])` when effects are enabled

4. **Direct vs indirect calls** (lines 1051-1058):
   - **Direct calls**: Simple `f(args)`
   - **Method call workaround**: When `f` is `obj.method` or `obj[key]`:
     ```javascript
     f.call(null, args)  // Ensure 'this' is not bound
     ```

5. **CPS handling** (lines 1059-1111):
   - Functions can have `.cps` property (for effect handlers)
   - When `cps = true` and effects enabled: use `f.cps` instead of `f`
   - Double translation mode: check if `.cps` exists at runtime

6. **Trampolined calls** (lines 1112-1126):
   - For tail call optimization with effects
   - Check stack depth: `caml_stack_check_depth()`
   - If deep: bounce to trampoline: `caml_trampoline_return(f, [args], is_cps)`
   - Otherwise: regular apply

### Key Patterns for Lua Implementation:

1. **Three-tier strategy confirmed**:
   - Tier 1: `exact = true` → Direct call (fastest)
   - Tier 2: `exact = false` + arity match → Direct call after check
   - Tier 3: `exact = false` + arity mismatch → `caml_call_gen`

2. **Arity encoding flexibility**:
   - Can use `.l` property OR function length
   - JavaScript checks `f.l >= 0 ? f.l : f.l === f.length`
   - Lua equivalent: check for `.l` field in function table

3. **No universal wrapping**:
   - Functions are NOT automatically wrapped in `{l=..., f=...}` tables
   - Wrapping is selective based on need for partial application
   - Primitives appear to be unwrapped (checking from context)

4. **Runtime `caml_call_gen` contract**:
   - Must handle variable argument count
   - Must detect under/exact/over application
   - Must build closures for partial application
   - Returns result for exact/over, returns closure for under

5. **Effect handler integration**:
   - Optional `.cps` variant of functions
   - Compile-time knowledge (`in_cps` flag) from Effects.ml pass
   - Runtime dispatch based on `.cps` presence

### Implications for Lua:

1. **Don't wrap all functions** - Only wrap when needed for currying
2. **Use table field for arity** - `{l = arity, f = function}` when wrapped
3. **Implement arity check helper** - Conditional application needs this
4. **Runtime `caml_call_gen` is critical** - Must handle all edge cases
5. **Preserve `exact` flag semantics** - Optimization opportunity
6. **Keep primitives unwrapped** - Direct Lua function calls for performance

---

#### Task 1.2: Document OCaml function representation requirements ✅
**Estimated Lines**: 30 (documentation)
**Deliverable**: Specification of OCaml function format in Lua

**Actions**:
1. Document required function structure: `{l = arity, f = function}`
2. List which functions need wrapping vs direct representation
3. Document how closures capture variables
4. Specify when to use `.f` vs direct call
5. Document arity checking requirements

**Success Criteria**: Clear spec that can guide implementation

---

## OCaml Function Representation in Lua (Task 1.2)

### Function Representations

**Reference**: `runtime/js/stdlib.js:20-63` (`caml_call_gen` implementation)

OCaml functions in Lua can be represented in **two ways**:

#### 1. **Plain Lua Functions** (Direct representation)

Used for:
- External primitives (e.g., `caml_ml_output`, `caml_string_get`)
- Functions that are only called with exact arity
- Performance-critical code paths
- Functions where currying is not needed

```lua
-- Plain Lua function
local function add_three(a, b, c)
  return a + b + c
end

-- Called directly:
local result = add_three(1, 2, 3)
```

**Characteristics**:
- No `.l` property (arity determined by introspection if needed)
- Called directly: `f(arg1, arg2, arg3)`
- Cannot be partially applied without runtime support
- **Fastest** representation

#### 2. **Wrapped Functions** (With arity metadata)

Used for:
- User-defined functions that support partial application
- Functions in non-exact calls (`exact = false`)
- Closures that may be curried

```lua
-- Wrapped function with arity
local add_three = {
  l = 3,  -- Arity
  f = function(a, b, c)
    return a + b + c
  end
}

-- OR: Arity as property of function itself (JavaScript style)
local function add_three(a, b, c)
  return a + b + c
end
add_three.l = 3

-- Called via wrapper:
local result = add_three.f(1, 2, 3)
-- OR if arity stored as property:
local result = add_three(1, 2, 3)
```

**Characteristics**:
- Has `.l` property indicating arity
- Can be partially applied via `caml_call_gen`
- Runtime checks arity before calling
- Slightly slower due to indirection

### Arity Representation

**From analysis of `caml_call_gen` (stdlib.js:24)**:

```javascript
var n = f.l >= 0 ? f.l : (f.l = f.length);
```

**Strategy**:
1. Check if `.l` property exists and is non-negative
2. If not, fall back to function's intrinsic arity (`.length` in JS)
3. Cache the arity in `.l` for future calls

**Lua equivalent**:
```lua
local function get_arity(f)
  if type(f) == "table" and f.l then
    return f.l
  elseif type(f) == "function" then
    -- Lua has no native way to get function arity
    -- Must be stored at function definition time
    return f.l or error("Function arity unknown")
  else
    error("Not a function")
  end
end
```

### Closure Variable Capture

**From analysis of `compiler/lib/generate.ml:2319-2339` (`compile_closure`)**

Closures capture free variables from their environment. In JavaScript:
```javascript
function make_adder(x) {
  return function(y) { return x + y; };
}
```

In Lua (compiled from OCaml):
```lua
local function make_adder(x)
  local closure = function(y)
    return x + y  -- 'x' captured from environment
  end
  closure.l = 1  -- Arity of returned function
  return closure
end
```

**Key points**:
- Free variables are captured in Lua's natural closure mechanism
- No special wrapping needed for captured variables
- Lua handles lexical scoping automatically
- Wrapped closures still have access to captured variables

### When to Use `.f` vs Direct Call

**Decision tree** (based on code generation context):

#### Scenario 1: Exact call (`exact = true`)
```lua
-- Code generation pattern:
if is_wrapped(f) then
  -- Call through wrapper
  result = f.f(arg1, arg2, arg3)
else
  -- Direct call
  result = f(arg1, arg2, arg3)
end
```

#### Scenario 2: Non-exact call (`exact = false`)
```lua
-- Always use caml_call_gen for runtime dispatch
result = caml_call_gen(f, {arg1, arg2, arg3})
```

**Simplified approach** (recommended for Lua):
- Store arity as property: `f.l = arity`
- Functions remain callable: `f(args)` not `f.f(args)`
- Check for `.l` property to determine if wrapped
- Use `caml_call_gen` for all non-exact calls

### Arity Checking Requirements

**From `compiler/lib/generate.ml:1074-1085`**

When `exact = false`, runtime must:

1. **Get function arity**: `n = f.l or function_length(f)`
2. **Count arguments**: `argsLen = #args`
3. **Calculate difference**: `d = n - argsLen`
4. **Three cases**:

   **Case A: `d == 0` (Exact match)**
   ```lua
   return f(table.unpack(args))
   ```

   **Case B: `d < 0` (Over-application)**
   ```lua
   -- Call with first n args, then apply remaining to result
   local g = f(table.unpack(args, 1, n))
   if type(g) ~= "function" then
     return g  -- Result is not a function
   end
   return caml_call_gen(g, table.slice(args, n + 1))
   ```

   **Case C: `d > 0` (Under-application / Partial application)**
   ```lua
   -- Build closure that captures current args
   local captured = args
   local closure = function(...)
     local new_args = {...}
     return caml_call_gen(f, table.concat(captured, new_args))
   end
   closure.l = d  -- Remaining arity
   return closure
   ```

### Which Functions Need Wrapping

**Based on analysis of generate.ml and stdlib.js**:

| Function Type | Wrapping | Reason |
|---------------|----------|--------|
| **External primitives** | ❌ No | Performance, always exact calls |
| **Runtime functions** | ❌ No | Direct calls only |
| **Known exact calls** | ❌ No | Compiler knows exact arity match |
| **User closures** | ✅ Yes (sometimes) | May be partially applied |
| **Exported functions** | ✅ Yes (sometimes) | Unknown call sites |
| **Higher-order args** | ✅ Yes (maybe) | May be curried |

**Decision criteria** (to be implemented in Phase 3):
```ocaml
let needs_wrapping ctx var =
  (* Is it a primitive? *)
  if is_primitive var then false
  (* Is it only called with exact arity? *)
  else if all_calls_exact ctx var then false
  (* Is it in a non-exact application? *)
  else if has_non_exact_call ctx var then true
  (* Default: wrap if might be partially applied *)
  else might_be_curried ctx var
```

### Effect Handler Representation (Optional `.cps` field)

**From `compiler/lib/generate.ml:1061-1066`** and stdlib.js effect handling:

Functions in CPS mode can have a `.cps` variant:
```lua
local function example(a, b)
  return a + b
end
example.l = 2

-- CPS variant (added when effects enabled)
example.cps = function(a, b, k)
  return k(a + b)  -- Call continuation with result
end
example.cps.l = 3  -- Arity includes continuation
```

**When used**:
- `Config.effects() = 'Double_translation'` AND `in_cps = true`
- Call `f.cps` instead of `f` when in CPS context
- Otherwise, use regular `f`

**Note**: This is for Phase 8+ (Effect handlers), not needed for basic implementation.

---

### Summary: Lua Function Representation Spec

1. **Two representations**: Plain functions vs wrapped functions with `.l` property
2. **Arity stored in `.l` field** when wrapping needed
3. **Plain functions for primitives** and known-exact calls (performance)
4. **Wrapped functions for currying** and unknown call sites
5. **Closure capture uses Lua's native lexical scoping**
6. **`caml_call_gen` handles all partial application** cases at runtime
7. **Arity check: get `.l` or function length**, compare with arg count
8. **Three cases**: exact (call), over (call + recurse), under (build closure)
9. **Optional `.cps` field** for effect handlers (future work)

---

#### Task 1.3: Design Lua function calling strategy ✅
**Estimated Lines**: 50 (design document)
**Deliverable**: Calling convention design document

**Actions**:
1. Design 3-tier strategy:
   - Tier 1: Direct calls for exact applications (no wrapper)
   - Tier 2: Conditional calls for non-exact with arity check
   - Tier 3: caml_call_gen for complex cases
2. Define when each tier is used
3. Design arity tracking mechanism
4. Plan backwards compatibility

**Success Criteria**: Clear decision tree for function calls

---

## Lua Function Calling Strategy (Task 1.3)

### Overview

Based on analysis of js_of_ocaml's `apply_fun_raw` (generate.ml:1048-1126), we design a **three-tier strategy** that balances performance and correctness.

### Three-Tier Strategy

#### **Tier 1: Direct Call (Fastest)**

**When to use**:
- `exact = true` (compiler knows arity matches)
- Function is NOT wrapped (plain Lua function)
- No arity check needed

**Generated code**:
```lua
-- Simple direct call
local result = f(arg1, arg2, arg3)
```

**Performance**: ✅✅✅ Fastest (no overhead)

**Use cases**:
- Primitive function calls: `caml_ml_output(chan, str)`
- Known-arity local calls: `add(1, 2)`
- Tail calls within known functions

---

#### **Tier 2: Conditional Call with Arity Check (Fast path)**

**When to use**:
- `exact = false` (compiler uncertain about arity match)
- Function MAY have `.l` property
- Want to optimize for the common case (arity matches)

**Generated code pattern** (matches generate.ml:1074-1096):
```lua
-- Check if function has correct arity, then call directly or fall back
local function get_arity(f)
  if type(f) == "table" and f.l then
    return f.l
  elseif type(f) == "function" and f.l then
    return f.l
  else
    -- Unknown arity, assume it matches (risky) or error
    return #args  -- Optimistic assumption
  end
end

local n = get_arity(f)
if n == 3 then  -- Expected arity
  result = f(arg1, arg2, arg3)
else
  result = caml_call_gen(f, {arg1, arg2, arg3})
end
```

**Optimized version** (inline arity check):
```lua
-- Inline the common case
local result
if f.l == 3 or f.l == nil then
  -- Arity matches or unknown (optimistic)
  result = f(arg1, arg2, arg3)
else
  -- Wrong arity, need generic handler
  result = caml_call_gen(f, {arg1, arg2, arg3})
end
```

**Performance**: ✅✅ Fast when arity matches (common case)

**Use cases**:
- Higher-order function calls: `List.map f list`
- Function passed as argument: `apply_twice f x`
- Callback invocations

---

#### **Tier 3: Generic Call via `caml_call_gen` (Correct)**

**When to use**:
- `exact = false` AND arity check failed
- Unknown function with unknown arity
- Guaranteed to handle all cases correctly

**Generated code**:
```lua
-- Always use runtime dispatch
local result = caml_call_gen(f, {arg1, arg2, arg3})
```

**Runtime behavior** (from stdlib.js:20-63):
```lua
function caml_call_gen(f, args)
  local n = f.l or error("Function arity unknown")
  local argsLen = #args
  local d = n - argsLen

  if d == 0 then
    -- Exact match: call directly
    return f(table.unpack(args))
  elseif d < 0 then
    -- Over-application: call with first n args, recurse with rest
    local g = f(table.unpack(args, 1, n))
    if type(g) ~= "function" then
      return g  -- Result is not a function
    end
    local rest_args = {table.unpack(args, n + 1)}
    return caml_call_gen(g, rest_args)
  else
    -- Under-application: build partial closure
    local closure = function(...)
      local extra = {...}
      local combined = {}
      for _, v in ipairs(args) do
        table.insert(combined, v)
      end
      for _, v in ipairs(extra) do
        table.insert(combined, v)
      end
      return caml_call_gen(f, combined)
    end
    closure.l = d  -- Remaining arity
    return closure
  end
end
```

**Performance**: ✅ Correct but slower (function call overhead)

**Use cases**:
- Partial application: `let add5 = add 5`
- Over-application: `f 1 2 3 4 5` where `f` has arity 2
- Unknown arity at compile time

---

### Decision Tree

**Code generation decision flow**:

```
┌─────────────────────────────────┐
│ Code.Apply { f; args; exact }   │
└────────────┬────────────────────┘
             │
             v
      ┌──────────────┐
      │ exact = ?    │
      └──┬────────┬──┘
         │        │
    true │        │ false
         v        v
   ┌──────────┐ ┌─────────────────┐
   │ Is f     │ │ Optimize with   │
   │ wrapped? │ │ arity check?    │
   └─┬────┬───┘ └───┬─────────┬───┘
     │    │         │         │
  yes│    │no    yes│         │no
     │    │         │         │
     v    v         v         v
   ┌──────────┐ ┌────────┐ ┌──────────────┐
   │ f.f(...)  │ │ f(...) │ │ if f.l==n    │
   │          │ │        │ │   f(...)     │
   │ Tier 1   │ │ Tier 1 │ │ else         │
   │          │ │        │ │   caml_call  │
   └──────────┘ └────────┘ │              │
                           │ Tier 2       │
                           └──────┬───────┘
                                  │
                                  v (slow path)
                           ┌──────────────┐
                           │ caml_call_   │
                           │ gen(f, args) │
                           │              │
                           │ Tier 3       │
                           └──────────────┘
```

---

### Arity Tracking Mechanism

#### At Function Definition

**Where arity is determined**:
1. **From IR**: `Code.Closure (params, cont, loc)` → `#params` is arity
2. **From primitives**: Primitive registry has arity info
3. **From external**: Manually specified or inferred

**How arity is stored**:

**Option A: Table wrapper** (explicit):
```lua
local f = {
  l = 3,
  f = function(a, b, c) return a + b + c end
}
```

**Option B: Property on function** (simpler):
```lua
local function f(a, b, c)
  return a + b + c
end
f.l = 3
```

**Recommendation**: Use **Option B** for simplicity, fallback to table when needed for CPS.

#### At Call Site

**Compile-time knowledge**:
- IR contains `exact` flag from compiler analysis
- If `exact = true`, we know arity matches
- If `exact = false`, we need runtime check

**Runtime lookup**:
```lua
-- Get arity safely
local function safe_arity(f)
  if type(f) == "function" then
    return f.l
  elseif type(f) == "table" and f.l then
    return f.l
  else
    return nil  -- Unknown
  end
end
```

---

### Code Generation Patterns

#### Pattern 1: Primitive Call (Always Direct)

**OCaml IR**:
```
Apply { f = Prim(Extern "caml_ml_output"); args = [chan; str]; exact = true }
```

**Generated Lua**:
```lua
caml_ml_output(chan, str)
```

**Rationale**: Primitives are never wrapped, always exact calls.

---

#### Pattern 2: Known Function, Exact Call

**OCaml IR**:
```
Apply { f = Var f_123; args = [x; y]; exact = true }
-- where f_123 is known local closure with arity 2
```

**Generated Lua**:
```lua
f_123(x, y)
```

**Rationale**: Compiler verified arity matches, direct call.

---

#### Pattern 3: Higher-Order, Non-Exact Call

**OCaml IR**:
```
Apply { f = Var func; args = [a; b]; exact = false }
-- where func might be partially applied
```

**Generated Lua (optimized Tier 2)**:
```lua
-- Inline arity check for common case
local _r
if func.l == 2 or func.l == nil then
  _r = func(a, b)
else
  _r = caml_call_gen(func, {a, b})
end
```

**Rationale**: Optimize for exact match (common), fallback to generic.

---

#### Pattern 4: Partial Application

**OCaml IR**:
```
Apply { f = Var add; args = [5]; exact = false }
-- where add has arity 2, only providing 1 arg
```

**Generated Lua (Tier 3)**:
```lua
local add5 = caml_call_gen(add, {5})
-- Returns closure with arity 1
```

**Rationale**: Must use `caml_call_gen` to build partial closure.

---

#### Pattern 5: Over-Application

**OCaml IR**:
```
Apply { f = Var make_adder; args = [10; 20]; exact = false }
-- where make_adder has arity 1, returns function with arity 1
```

**Generated Lua (Tier 3)**:
```lua
local result = caml_call_gen(make_adder, {10, 20})
-- Calls make_adder(10), gets closure, calls it with 20
```

**Rationale**: Over-application requires recursion, handled by `caml_call_gen`.

---

### Backwards Compatibility

#### Compatibility with Existing Runtime

**JavaScript runtime compatibility**:
- Same `.l` property convention
- Same `caml_call_gen` semantics
- Compatible function representation

**Lua-specific adaptations**:
- Use `table.unpack` instead of spread `...`
- Use `table.insert` for array building
- Handle 1-indexed arrays (or use 0-indexed like OCaml blocks)

#### Migration Strategy

**Phase 1**: Implement Tier 3 only (always use `caml_call_gen`)
- Simple, correct, but slow
- Validates runtime semantics

**Phase 2**: Add Tier 1 for primitives and exact calls
- Optimize common cases
- Significant performance improvement

**Phase 3**: Add Tier 2 for conditional optimization
- Handle non-exact calls efficiently
- Final optimization pass

---

### Performance Optimization Strategy

#### Inline Thresholds

**When to inline arity checks**:
- Small number of arguments (1-3): inline
- Large number of arguments (4+): use helper function
- Repeated calls: hoist check outside loop

**Example optimizations**:

**Before** (naive):
```lua
for i = 1, n do
  result = caml_call_gen(f, {i})
end
```

**After** (optimized):
```lua
if f.l == 1 then
  -- Fast path: direct calls
  for i = 1, n do
    result = f(i)
  end
else
  -- Slow path: generic calls
  for i = 1, n do
    result = caml_call_gen(f, {i})
  end
end
```

#### Special Cases

**Arity 1 optimization** (very common):
```lua
-- Instead of creating array {x}
if f.l == 1 or f.l == nil then
  result = f(x)
else
  result = caml_call_gen(f, {x})
end
```

**Arity 2 optimization** (also common):
```lua
if f.l == 2 or f.l == nil then
  result = f(x, y)
else
  result = caml_call_gen(f, {x, y})
end
```

---

### Implementation Guidelines

#### Code Generation Helpers

**Helper functions in `lua_generate.ml`**:

```ocaml
(* Determine call tier *)
let call_tier ctx f args exact =
  if exact && is_primitive f then Tier1_Direct
  else if exact then Tier1_Direct
  else if should_optimize_arity ctx then Tier2_Conditional
  else Tier3_Generic

(* Generate call based on tier *)
let generate_apply ctx f args exact =
  match call_tier ctx f args exact with
  | Tier1_Direct ->
      L.Call (f, args)  (* Direct call *)
  | Tier2_Conditional ->
      let n = List.length args in
      L.If (
        L.BinOp(Or,
          L.BinOp(Eq, L.Dot(f, "l"), L.Number n),
          L.BinOp(Eq, L.Dot(f, "l"), L.Nil)),
        L.Call(f, args),
        Some (L.Call(L.Ident "caml_call_gen", [f; L.Table args]))
      )
  | Tier3_Generic ->
      L.Call (L.Ident "caml_call_gen", [f; L.Table args])
```

#### Runtime Helpers

**Required in `runtime/lua/fun.lua`**:

```lua
--Provides: caml_call_gen
function caml_call_gen(f, args)
  -- Full implementation as documented above
end

--Provides: caml_check_arity
function caml_check_arity(f, n)
  return f.l == n or f.l == nil
end
```

---

### Decision Matrix

| Scenario | `exact` | Known Arity? | Strategy | Code Pattern |
|----------|---------|--------------|----------|--------------|
| Primitive call | true | Yes | Tier 1 | `f(...)` |
| Local exact call | true | Yes | Tier 1 | `f(...)` |
| Higher-order exact | true | Maybe | Tier 1 | `f(...)` |
| HOF non-exact | false | Maybe | Tier 2 | `if f.l==n then f(...) else caml_call_gen` |
| Partial app | false | Maybe | Tier 3 | `caml_call_gen(f, {...})` |
| Over-app | false | Maybe | Tier 3 | `caml_call_gen(f, {...})` |
| Unknown function | false | No | Tier 3 | `caml_call_gen(f, {...})` |

---

### Summary: Lua Calling Convention

1. **Three tiers**: Direct (fast) → Conditional (balanced) → Generic (correct)
2. **Tier 1**: Use for `exact = true` and primitives (no overhead)
3. **Tier 2**: Inline arity check for non-exact with fast path
4. **Tier 3**: Always use `caml_call_gen` for correctness
5. **Arity tracking**: Store in `.l` property on functions
6. **Backwards compatible**: Matches js_of_ocaml conventions
7. **Optimization strategy**: Start simple (Tier 3), add fast paths incrementally
8. **Performance**: Tier 1 for 90% of calls (hot path), Tier 3 for flexibility

---

#### Task 1.4: Design arity tracking system
**Estimated Lines**: 40 (design)
**Deliverable**: Arity tracking design

**Actions**:
1. Design how to track function arity in IR
2. Plan how to propagate arity through compiler
3. Design metadata structure for functions
4. Plan how to distinguish user functions from primitives

**Success Criteria**: Design that enables proper arity-based decisions

---

### Phase 2: Core Infrastructure

#### Task 2.1: Implement function metadata tracking in code generator
**Estimated Lines**: 150
**Deliverable**: Enhanced context with function metadata

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Add `function_arities` map to context
2. Implement `register_function_arity` helper
3. Add `lookup_function_arity` helper
4. Populate arities during closure generation
5. Add helper to check if function is primitive

**Success Criteria**: Context tracks function arities, compiles without errors

---

#### Task 2.2: Add arity annotation to generated closures
**Estimated Lines**: 80
**Deliverable**: Closures with `.l` property

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Modify `generate_closure` to add `.l` property
2. Keep function as direct Lua function (not wrapped in table yet)
3. Add arity as metadata comment in generated code
4. Ensure arity matches parameter count

**Success Criteria**: Generated closures have arity information

---

#### Task 2.3: Create runtime helper for arity checking
**Estimated Lines**: 80
**Deliverable**: `caml_check_arity` function

**File**: `runtime/lua/fun.lua`

**Actions**:
1. Create `caml_check_arity(func, n_args)` that:
   - Returns true if function has arity n_args
   - Handles both wrapped and unwrapped functions
   - Returns false for non-functions
2. Add `--Provides: caml_check_arity` comment
3. Write tests in `test_fun.lua`

**Success Criteria**: Runtime can check function arity, tests pass

---

#### Task 2.4: Update caml_call_gen to handle all cases
**Estimated Lines**: 100
**Deliverable**: Robust caml_call_gen

**File**: `runtime/lua/fun.lua`

**Actions**:
1. Handle functions with `.l` property
2. Handle plain Lua functions (assign arity from params)
3. Handle primitives (never wrapped)
4. Add better error messages
5. Optimize common cases (1-2 arg partial application)

**Success Criteria**: caml_call_gen handles wrapped and unwrapped functions

---

### Phase 3: Code Generation Refactoring

#### Task 3.1: Revert universal function wrapping
**Estimated Lines**: 50
**Deliverable**: Closures not automatically wrapped

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Remove `{l = arity, f = function}` wrapper from `generate_closure`
2. Return plain `L.Function` instead
3. Keep arity tracking in place
4. Add comment explaining why not wrapped

**Success Criteria**: Generates plain functions, compiles successfully

---

#### Task 3.2: Implement conditional wrapping for closures
**Estimated Lines**: 120
**Deliverable**: Selective wrapping logic

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Add `needs_wrapping` predicate:
   - True for closures that can be partially applied
   - False for primitives
   - False for functions only called with exact arity
2. Modify `generate_closure` to wrap only when needed
3. Add wrapping helper function
4. Track wrapped vs unwrapped functions in context

**Success Criteria**: Only necessary functions wrapped, code compiles

---

#### Task 3.3: Fix function application generation
**Estimated Lines**: 200
**Deliverable**: Correct function calls

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Modify `Code.Apply` handling:
   ```ocaml
   | Code.Apply { f; args; exact } ->
       if exact then
         (* Exact call - check if wrapped *)
         if is_wrapped then
           L.Call (L.Index (func, L.String "f"), args)
         else
           L.Call (func, args)
       else
         (* Non-exact - use caml_call_gen *)
         L.Call (L.Ident "caml_call_gen", [func; L.Table args])
   ```
2. Add `is_wrapped_function` helper
3. Handle primitives specially (never wrapped)
4. Optimize common cases

**Success Criteria**: Generated calls are correct, compiles

---

#### Task 3.4: Handle exact vs non-exact calls correctly
**Estimated Lines**: 150
**Deliverable**: Proper exact call optimization

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. When `exact` is true:
   - Call function directly if unwrapped
   - Call `.f` if wrapped
2. When `exact` is false:
   - Always use `caml_call_gen`
   - Let runtime handle arity mismatch
3. Add fast path for known-arity functions
4. Add comments explaining logic

**Success Criteria**: Exact calls optimized, partial application works

---

### Phase 4: Primitive Handling

#### Task 4.1: Identify all external primitives
**Estimated Lines**: 80
**Deliverable**: Primitive registry

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Create `is_external_primitive` function
2. Add set of all primitive names (caml_*, runtime functions)
3. Check primitive list from `generate_prim`
4. Document which functions are primitives

**Success Criteria**: Can identify all primitives programmatically

---

#### Task 4.2: Ensure primitives are never wrapped
**Estimated Lines**: 60
**Deliverable**: Primitives always unwrapped

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Modify `needs_wrapping` to return false for primitives
2. Add assertion to prevent primitive wrapping
3. Document why primitives aren't wrapped
4. Test that primitives compile correctly

**Success Criteria**: No primitives wrapped, all primitive calls work

---

#### Task 4.3: Fix primitive function calls
**Estimated Lines**: 100
**Deliverable**: Correct primitive application

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Modify `generate_prim` to return unwrapped calls
2. Ensure primitive calls never use `.f`
3. Primitives always called directly
4. Handle special cases (caml_ml_output, etc.)

**Success Criteria**: All primitives called correctly

---

#### Task 4.4: Test primitive operations
**Estimated Lines**: 150 (tests)
**Deliverable**: Primitive test suite

**File**: `compiler/tests-lua/test_primitives.ml`

**Actions**:
1. Test string operations (caml_string_get, etc.)
2. Test array operations
3. Test I/O operations (caml_ml_output)
4. Test arithmetic operations
5. Verify all tests pass

**Success Criteria**: All primitive tests pass

---

### Phase 5: Format/Printf Fix

#### Task 5.1: Trace Format module channel passing
**Estimated Lines**: 80 (analysis + debugging)
**Deliverable**: Understanding of channel flow

**Actions**:
1. Add debug output to generated Format code
2. Trace how stdout channel is created
3. Trace how it's passed to Format functions
4. Identify where channel becomes block
5. Document the exact call chain

**Success Criteria**: Know exactly where channel ID becomes block

---

#### Task 5.2: Fix channel ID representation
**Estimated Lines**: 120
**Deliverable**: Proper channel ID passing

**File**: `compiler/lib-lua/lua_generate.ml` or runtime

**Actions**:
1. Based on Task 5.1 findings, fix the root cause
2. Ensure channels stay as integers through call chain
3. Fix any field access bugs related to channels
4. Remove any incorrect block wrapping

**Success Criteria**: Channel IDs are integers end-to-end

---

#### Task 5.3: Remove channel ID workarounds
**Estimated Lines**: 40
**Deliverable**: Clean runtime code

**File**: `runtime/lua/io.lua`

**Actions**:
1. Remove HACK comment and workaround in `caml_unwrap_chanid`
2. Remove stdin→stdout remapping logic
3. Restore proper error handling
4. Add assertion that channel is integer

**Success Criteria**: No hacks or workarounds in io.lua

---

#### Task 5.4: Verify Printf works correctly
**Estimated Lines**: 100 (tests)
**Deliverable**: Printf test suite

**File**: `compiler/tests-lua/test_printf.ml`

**Actions**:
1. Test Printf.printf with various format strings
2. Test Printf.fprintf to stdout/stderr
3. Test Printf.sprintf
4. Test format string with multiple arguments
5. Verify output is correct

**Success Criteria**: All Printf tests pass

---

### Phase 6: Integration and Testing

#### Task 6.1: Run hello.ml with all Printf statements
**Estimated Lines**: 20 (testing)
**Deliverable**: hello.ml runs completely

**Actions**:
1. Run `lua _build/default/examples/hello_lua/hello.bc.lua`
2. Verify all output is correct:
   - "Hello from Lua_of_ocaml!"
   - "Factorial of 5 is: 120"
   - "Testing string operations..."
   - "Length of 'lua_of_ocaml': 12"
   - "Uppercase: LUA_OF_OCAML"
3. Verify no errors or crashes

**Success Criteria**: hello.ml runs to completion with correct output

---

#### Task 6.2: Create partial application test suite
**Estimated Lines**: 200
**Deliverable**: Comprehensive partial application tests

**File**: `compiler/tests-lua/test_partial_application.ml`

**Actions**:
1. Test simple partial application: `let add x y = x + y; let add5 = add 5`
2. Test multi-level currying: `let f a b c = a + b + c; let g = f 1; let h = g 2`
3. Test over-application: passing too many args
4. Test exact application
5. Test composition of partial applications
6. Verify all tests pass

**Success Criteria**: 20+ partial application tests, all passing

---

#### Task 6.3: Test curried function composition
**Estimated Lines**: 150
**Deliverable**: Composition tests

**File**: `compiler/tests-lua/test_composition.ml`

**Actions**:
1. Test `let compose f g x = f (g x)`
2. Test pipeline: `x |> f |> g |> h`
3. Test List.map with partial application
4. Test List.fold_left with currying
5. Test function returning function

**Success Criteria**: Complex currying patterns work

---

#### Task 6.4: Verify no TODOs or hacks remain
**Estimated Lines**: 20 (verification)
**Deliverable**: Clean codebase

**Actions**:
1. `grep -r "HACK\|TODO\|FIXME\|WORKAROUND" compiler/lib-lua/`
2. `grep -r "HACK\|TODO\|FIXME\|WORKAROUND" runtime/lua/`
3. Remove or document any remaining TODOs
4. Ensure all hacks are removed
5. Clean up debug output

**Success Criteria**: Zero hacks/todos related to partial application

---

#### Task 6.5: Update LUA.md Task M1.2 as complete
**Estimated Lines**: 10
**Deliverable**: LUA.md updated

**Actions**:
1. Mark Task M1.2 as `- [x]` completed
2. Update status from 🟡 to ✅
3. Add note about partial application support
4. Commit changes with proper message

**Success Criteria**: LUA.md reflects completion

---

## Implementation Notes

### Key Principles

1. **Minimize Wrapping**: Only wrap functions that absolutely need it
2. **Optimize Common Case**: Direct calls for exact applications
3. **Runtime Checks**: Use caml_call_gen only when necessary
4. **No Breaking Changes**: Existing working code should continue working
5. **Follow js_of_ocaml**: Mirror their proven approach

### Testing Strategy

Each phase should:
1. Compile without errors
2. Pass existing tests
3. Add new tests for the feature
4. Verify no regressions

### Debugging Approach

For each bug:
1. Add minimal reproduction
2. Trace through generated code
3. Compare with js_of_ocaml behavior
4. Fix root cause, not symptoms
5. Add test to prevent regression

---

## Success Criteria

The implementation is complete when:

✅ All tasks marked complete
✅ hello.ml runs with all Printf calls
✅ No hacks or workarounds remain
✅ No TODOs related to partial application
✅ 50+ tests for partial application pass
✅ Code follows js_of_ocaml patterns
✅ LUA.md Task M1.2 marked complete
✅ Partial application works for all OCaml patterns

---

## Timeline Estimate

- **Phase 1** (Analysis): 2-3 hours
- **Phase 2** (Infrastructure): 4-5 hours
- **Phase 3** (Refactoring): 6-8 hours
- **Phase 4** (Primitives): 3-4 hours
- **Phase 5** (Printf): 4-5 hours
- **Phase 6** (Testing): 3-4 hours

**Total**: 22-29 hours of focused work

---

## References

- `compiler/lib/generate.ml`: JavaScript code generation (reference)
- `compiler/lib-lua/lua_generate.ml`: Lua code generation (to be fixed)
- `runtime/js/fun.js`: JavaScript function utilities (reference)
- `runtime/lua/fun.lua`: Lua function utilities (to be enhanced)
- OCaml manual on currying and partial application
