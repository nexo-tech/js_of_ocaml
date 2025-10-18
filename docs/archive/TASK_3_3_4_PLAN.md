# Task 3.3.4: Fix _V Table Scoping for Nested Closures

## Date: 2025-10-13

## Summary

**CRITICAL FIX**: Each closure must create its own `local _V = {}`, never inherit parent's _V table.

## Root Cause

**Bug**: Line 105 in lua_generate.ml sets `inherit_var_table = parent_uses_table`, causing nested closures to share the SAME _V table.

**Impact**: Variable assignments in one closure overwrite variables in parent/sibling closures.

**Example**:
```lua
-- Module level: local _V = {}
v185 = function(v201, v202, v203)
  _V.v201 = v201  -- Sets _V.v201 = continuation
  local result = v184(_V.counter, _V.v201, _V.v202, _V.v203)
end

v184 = function(counter, v201, v202, v203)
  _V.v201 = v201  -- OVERWRITES v185's _V.v201!
  -- Bug: _V.v201 now has wrong value
end
```

## JavaScript Comparison

```js
// Each function automatically gets its own scope
function v185(v201, v202, v203) {
  var v201 = v201;  // Local to v185
  var result = v184(counter, v201, v202, v203);  // v184 gets its own scope
}

function v184(counter, v201, v202, v203) {
  var v201 = v201;  // Local to v184, doesn't affect v185's v201
}
```

**Key Insight**: JavaScript's `var` creates function-local variables. Our _V table must be function-local too!

## The Fix (Option A - RECOMMENDED)

**Change line 1567-1568** in `setup_hoisted_variables`:

```ocaml
(* Before *)
if ctx.inherit_var_table then
  L.Comment (..., "using inherited _V table") :: init_stmts

(* After *)
if ctx.inherit_var_table then
  [ L.Comment (..., "using own _V table for closure scope")
  ; L.Local ([ var_table_name ], Some [ L.Table [] ])
  ] @ init_stmts
```

**Result**: Every closure with >180 variables creates its own `local _V = {}`.

## Expected Behavior After Fix

```lua
-- Module level
local _V = {}
_V.v184 = caml_make_closure(4, function(counter, v201, v202, v203)
  local _V = {}  -- v184's own _V table ✅
  _V.v201 = v201
  _V.v341 = v201
  -- ... v184 code
end)

_V.v185 = caml_make_closure(3, function(v201, v202, v203)
  local _V = {}  -- v185's own _V table ✅
  _V.v201 = v201
  local result = _V.v184(_V.counter, _V.v201, _V.v202, _V.v203)
  -- ... v185 code
end)
```

Each closure has independent variable storage, just like JavaScript!

## Testing Strategy

1. **Build and compile**:
   ```bash
   just build-lua-all
   just compile-lua-debug /tmp/test_printf_simple.ml.bc
   ```

2. **Verify _V table generation**:
   ```bash
   grep -A5 "function(counter, v201, v202, v203)" /tmp/quick_test.lua | head -10
   # Should see: local _V = {}
   ```

3. **Test Printf**:
   ```bash
   just quick-test /tmp/test_printf_simple.ml
   # Expected: Hello
   ```

4. **Compare with JS**:
   ```bash
   just compare-outputs /tmp/test_printf_simple.ml
   # Both should output: Hello
   ```

5. **Run test suite**:
   ```bash
   just test-lua
   # Should pass with no new failures
   ```

## Success Criteria

- [x] Understanding of root cause (shared _V table)
- [x] Strategy documented (Option A: always create local _V)
- [ ] Fix implemented (1 line change in setup_hoisted_variables)
- [ ] Build succeeds with no warnings
- [ ] Generated code has `local _V = {}` in each closure
- [ ] Printf.printf "Hello\n" outputs "Hello"
- [ ] Test suite passes (just test-lua)
- [ ] No regressions in existing tests

## Files to Modify

- `compiler/lib-lua/lua_generate.ml`: Lines 1567-1568

## Estimated Effort

30 minutes - 1 hour (single line fix + thorough testing)

## Alternative Approaches (Not Recommended)

**Option B: Unique Variable Names**
- Generate v201_c1, v201_c2 per closure
- Complex, doesn't match JS semantics
- Rejected

**Option C: Metatable Inheritance**
- `local _V = setmetatable({}, {__index=parent_V})`
- Complex, performance overhead
- Rejected

**Winner**: Option A (always create local _V) - simple, correct, matches JS
