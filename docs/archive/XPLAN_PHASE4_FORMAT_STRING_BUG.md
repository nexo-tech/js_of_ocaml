# XPLAN Phase 4: Format String Bug - v316 is nil

## Status: 🔍 INVESTIGATING

## The Bug

**Printf.printf "%d\n" 42** executes formatting code but crashes with:
```
lua: /tmp/test_simple.lua:4805: attempt to get length of local 's' (a nil value)
stack traceback:
	/tmp/test_simple.lua:4805: in function 'caml_ocaml_string_to_lua'
	/tmp/test_simple.lua:4265: in function 'caml_format_int'
	/tmp/test_simple.lua:18131: in function </tmp/test_simple.lua:18121>
```

### Root Cause

**Line 18131**: `_V.v314 = caml_format_int(_V.v316, _V.v259)`
- `v316` should be the format string (`"%d"`)
- `v259` is the integer value (42)
- **v316 is nil!**

### Evidence

**Lua code structure**:
```lua
-- Line 17888: v156 creates and uses v316 internally
_V.v156 = caml_make_closure(2, function(v258, v257)
  -- Hoisted variables (49 total: 44 defined, 5 free, 4 loop params)
  local parent_V = _V
  local _V = setmetatable({}, {__index = parent_V})
  _V.v316 = nil  -- Line 17894: v316 initialized to nil
  ...
  _V.v316 = _V.v256[3]  -- Line 17728: v316 set from parameter
  ...
  -- v316 used for format string building (lines 17844, etc.)
end)

-- Line 18121: v157 tries to use v316 from parent scope
_V.v157 = caml_make_closure(2, function(v260, v259)
  -- Hoisted variables (6 total: 2 defined, 4 free, 0 loop params)
  local parent_V = _V
  local _V = setmetatable({}, {__index = parent_V})
  _V.v314 = nil
  _V.v315 = nil
  _V.v260 = v260
  _V.v259 = v259
  ...
  _V.v314 = caml_format_int(_V.v316, _V.v259)  -- Line 18131: v316 is nil!
  ...
end)
```

**Problem**: v157 is created in the SAME scope as v156, not inside v156. When v157 tries to access `_V.v316`, it looks up the metatable chain and finds v316 from v156's initialization (which set it to nil), NOT the v316 that was later set inside v156's body.

## JS Comparison

### JS Format String Constants

**Lines 4680-4687** in JS:
```javascript
aJ = "%lu",
ak = "%Ld",
an = cst_Li,
aw = "%Lu",
Z = "%d",        // Format string constant for decimal integer
aa = cst_i,
aj = cst_u,
fmt$0 = [0, [4, 0, 0, 0, [12, 10, 0]], "%d\n"];
```

### JS convert_int Function

**Lines 7240-7259**:
```javascript
function convert_int(iconv, n){
  switch(iconv){
    case 1: var a = _; break;
    case 2: var a = $; break;
    ...
    case 0:
    case 13: var a = Z; break;  // Z = "%d"
    ...
  }
  return transform_int_alt(iconv, caml_format_int(a, n));
}
```

The format string `a` is selected from GLOBAL CONSTANTS like `Z = "%d"`.

### Lua Format String Constants

**Line 13085**:
```lua
_V.v102 = "%d"
```

Format string constants ARE defined in Lua, in the `__caml_init__` function.

## The Issue

### Scoping Problem

In JS:
- Format string constants (`Z`, `$`, etc.) are global variables
- `convert_int` function accesses them directly
- Works correctly ✅

In Lua:
- Format string constants (`v102`, etc.) are in `_V` table in `__caml_init__`
- v157 closure tries to access `v316` which should be a format string
- But v316 is NOT the format string constant
- v316 is supposed to be passed/captured from somewhere else
- **v316 ends up being nil because it's captured from wrong scope** ❌

### Data Flow Analysis

1. `__caml_init__` defines format string constants like `v102 = "%d"`
2. Some closure should use v102 to build a closure that captures it
3. That closure should be v157 or passed to v157
4. Instead, v157 tries to access v316 from parent scope
5. v316 in parent scope was initialized to nil by v156
6. v316 was LATER set inside v156's body, but that's a DIFFERENT v316 (local to v156)
7. v157 cannot see the v316 inside v156's body

## The Fix

### Option A: Pass format string as parameter

v157 should receive the format string as a closure parameter or captured variable.

### Option B: Fix variable capture

v157 should be created INSIDE v156 so it can properly capture v316 after it's set.

### Option C: Use format string constant directly

v157 should access the format string constant (v102) directly from _V table, not try to use v316.

## Next Steps

1. **Examine IR/bytecode** to understand what the OCaml compiler intended
2. **Compare closure creation** in JS vs Lua for the equivalent code
3. **Identify the bug** in lua_generate.ml that causes this variable capture issue
4. **Fix code generation** to properly pass/capture format strings
5. **Test** Printf %d after fix

## Hypothesis

The bug is likely in how lua_generate.ml handles:
- Closure variable capture
- Variable scope and initialization
- Free variables in nested closures

This might be related to the previous variable shadowing fixes, but is a DIFFERENT issue where the variable isn't being captured from the right scope at all.

## Status

**ROOT CAUSE IDENTIFIED!**

## The Real Bug

### JS Structure (Correct)

```javascript
function convert_int(iconv, n){
  switch(iconv){
    case 0:
    case 13: var a = Z; break;    // Z = "%d"
    case 1: var a = _; break;     // Different format
    case 2: var a = $; break;     // Different format
    ...
  }
  return transform_int_alt(iconv, caml_format_int(a, n));
}
```

**Each case selects a DIFFERENT format string constant!**

### Lua Structure (Broken)

```lua
_V.v157 = caml_make_closure(2, function(v260, v259)
  -- v260 = iconv (conversion type)
  -- v259 = n (number to format)
  -- v316 = ??? (should be format string, but is nil!)

  if _V.v260 == 0 then
    _V.v314 = caml_format_int(_V.v316, _V.v259)  -- v316 is nil!
  else if _V.v260 == 1 then
    _V.v314 = caml_format_int(_V.v316, _V.v259)  -- Same v316 (nil)!
  else if _V.v260 == 2 then
    _V.v314 = caml_format_int(_V.v316, _V.v259)  -- Same v316 (nil)!
  ...
end)
```

**ALL cases use the SAME v316, which is nil!**

### What Should Happen

Lua should generate:
```lua
_V.v157 = caml_make_closure(2, function(v260, v259)
  local format_string
  if _V.v260 == 0 or _V.v260 == 13 then
    format_string = _V.v102  -- "%d"
  else if _V.v260 == 1 then
    format_string = _V.v103  -- "%+d" or similar
  else if _V.v260 == 2 then
    format_string = _V.v104  -- "% d" or similar
  ...
  end

  _V.v314 = caml_format_int(format_string, _V.v259)
  ...
end)
```

## Code Generation Bug

The bug is in **lua_generate.ml** where it compiles the `convert_int` function (or its equivalent).

The code generator is:
1. ❌ NOT generating the switch/if-chain to select format strings
2. ❌ Trying to use a captured variable `v316` that doesn't exist in the right scope
3. ❌ Not referencing the format string constants (v102, v103, v104, etc.)

### Where to Look

The IR probably has:
- A function with a switch on `iconv`
- Each case should load a different constant format string
- The Lua generator is compiling this incorrectly

**Next step**: Examine the IR/bytecode to see how `convert_int` is represented and compare with how it's being compiled to Lua.
