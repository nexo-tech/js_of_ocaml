# XPLAN Phase 3 Task 3.2: JS vs Lua Parameter Passing Comparison

## Status: ✅ COMPLETE

## Objective
Compare how js_of_ocaml's `parallel_renaming` handles closure parameters vs lua_of_ocaml's approach

## Test Case: Printf with Format Specifier

Using `/tmp/test4.ml`:
```ocaml
let () =
  Printf.printf "Value: %d\n" 42
```

### Generated Code Comparison

#### JavaScript Approach (test4.js)

**Function A - Printf Closure Creator (line 6523-6533):**
```javascript
function A(g, f, e, h, d, c, b){
  if(typeof h === "number"){
    if(typeof d === "number")
      return d
        ? function (h, d){
            return a(g, [4, f, s(h, caml_call2(c, b, d))], e);
          }
        : function(d){return a(g, [4, f, caml_call2(c, b, d)], e);};
    var m = d[1];
    return function(d){return a(g, [4, f, s(m, caml_call2(c, b, d))], e);};
  }
  // ... more cases
}
```

**Key Observations:**
1. Function A takes parameters: `g, f, e, h, d, c, b`
2. Returns nested functions that capture parent parameters
3. Nested function at line 6531: `function(d){return a(g, [4, f, caml_call2(c, b, d)], e);}`
   - Has its own parameter: `d`
   - Captures from parent: `g, f, e, c, b`
   - **NO re-declaration** of captured variables
4. Variables captured via **JavaScript's lexical scoping**
5. `parallel_renaming` (generate.ml:981) generates `var param = arg;` for NEW variables only

#### Lua Approach (test4.lua)

**Format Structure Initialization (lines 12866, 13116):**
```lua
-- Line 12866: Hoisted initialization
_V.v277 = nil

-- Line 13116: Actual format structure assignment
_V.v277 = {0, {11, "Value: ", {4, 0, 0, 0, {12, 10, 0}}}, "Value: %d\n"}
```

**Printf Closure Creation (lines 21395, 21550-21579):**
```lua
-- Line 21395: Create format processing closure
_V.v268 = caml_make_closure(2, function(v296, v297)
  -- ... format processing logic
end)

-- Line 13909: stdout initialized
_V.v21 = caml_ml_open_descriptor_out(1)

-- Lines 21550-21579: User code - Printf call
_V.v276 = 42                    -- The value to print
_V.v271 = _V.v277[2]            -- Extract format from v277
_V.v272 = 0
_V.v273 = caml_make_closure(1, function(v274)
  -- ⚠️ BUG LOCATION: Hoisted variable initialization
  local parent_V = _V
  local _V = setmetatable({}, {__index = parent_V})
  _V.v21 = nil        -- ❌ SHADOWS parent's stdout!
  _V.v268 = nil       -- ❌ SHADOWS parent's format closure!
  _V.v274 = nil       -- ✅ OK - function parameter
  _V.v314 = nil       -- ✅ OK - local variable
  _V.v315 = nil       -- ✅ OK - local variable

  _V.v274 = v274      -- Assign function parameter

  local _next_block = 796
  while true do
    if _next_block == 796 then
      -- ❌ BUG: v268 and v21 are nil due to shadowing above!
      _V.v314 = _V.v268(_V.v21, _V.v274)
      _V.v315 = 0
      return _V.v315
    end
  end
end)
```

**Key Observations:**
1. Parent scope sets: `v21` (stdout), `v268` (format closure), `v277` (format structure)
2. Nested closure creates new `_V` table with `__index = parent_V` metatable
3. **BUG:** Hoisted variables initialize `_V.v21 = nil` and `_V.v268 = nil`
4. These nil initializations **create new entries** in child's _V table
5. Child's nil entries **shadow** parent's valid values
6. When accessing `_V.v268` or `_V.v21`, gets `nil` instead of parent values
7. Printf call fails: `caml_format_int(nil, arg)` → crash

### Root Cause Analysis

#### JavaScript: Variable Scoping
```javascript
// Outer function
function outer(captured_param) {
  // Inner function
  return function(own_param) {
    // Uses captured_param directly - lexical scoping
    // Uses own_param - function parameter
    use(captured_param, own_param);
  };
}
```
- `captured_param`: NOT redeclared, accessed via lexical scope
- `own_param`: Declared as function parameter
- No variable shadowing issues

#### Lua: Variable Shadowing Bug
```lua
-- Outer function
_V.captured_var = "value from parent"

-- Inner function
closure = function(own_param)
  local parent_V = _V
  local _V = setmetatable({}, {__index = parent_V})

  _V.captured_var = nil  -- ❌ BUG: Creates new entry, shadows parent!
  _V.own_param = nil     -- ✅ OK: Will be assigned

  _V.own_param = own_param  -- Assign parameter

  -- Tries to use captured_var
  use(_V.captured_var)  -- ❌ Gets nil instead of parent value!
end
```

The problem is in `setup_hoisted_variables` (lua_generate.ml:1666-1733):

**Line 1701 - The Critical Line:**
```ocaml
let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params
```

This line EXCLUDES entry block parameters from hoisting, but it should ALSO exclude variables that are captured from parent scope!

Currently:
- `all_hoisted_vars` = all variables used in the function
- `entry_block_params` = function parameters (e.g., `v274`)
- `vars_to_init` = `all_hoisted_vars - entry_block_params`

This means `v21` and `v268` (captured variables) are IN `vars_to_init`, so they get initialized to `nil`, shadowing the parent!

### The Fix

Variables should be categorized as:
1. **Function parameters** (e.g., `v274`) - assigned from function args
2. **Local variables** (e.g., `v314`, `v315`) - initialized to nil
3. **Captured variables** (e.g., `v21`, `v268`, `v271`) - accessed from parent via __index

The fix: **Don't initialize captured variables in nested closures!**

Only initialize truly local variables. Let captured variables fall through to parent via `__index` metatable.

## Evidence Files

- `/tmp/test4.js` - JavaScript output (6,640 lines)
- `/tmp/test4.lua` - Lua output (21,597 lines)
- Key JS location: line 6523-6550 (Function A)
- Key Lua location: line 21553-21573 (nested closure with bug)
- Bug line: 21557-21558 (`_V.v21 = nil`, `_V.v268 = nil`)

## Next Steps

See Phase 3 Task 3.3: Identify the exact fix in lua_generate.ml's hoisting logic
