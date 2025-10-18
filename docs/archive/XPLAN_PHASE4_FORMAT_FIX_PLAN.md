# XPLAN Phase 4: Format String Fix Plan

## Status: 🔧 READY TO FIX

## Bug Summary

**Problem**: `Printf.printf "%d\n" 42` calls `caml_format_int(nil, 42)` because format string selection is missing.

**Root Cause**: Switch statement for convert_int (v157) doesn't load format string constants before calling caml_format_int.

## Detailed Analysis

### JavaScript (Correct)

```javascript
function convert_int(iconv, n){
  switch(iconv){
    case 0:
    case 13:
      var a = Z; break;    // Z = "%d" - Load format string!
    case 1:
      var a = _; break;    // _ = "%+d" or similar
    case 2:
      var a = $; break;    // $ = "% d" or similar
    ...
  }
  return transform_int_alt(iconv, caml_format_int(a, n));
}
```

**Key**: Variable `a` is assigned in each case, then used after the switch.

### Lua (Broken)

**Lines 18121-18200 in test_simple.lua**:
```lua
_V.v157 = caml_make_closure(2, function(v260, v259)
  -- Hoisted variables (6 total: 2 defined, 4 free, 0 loop params)
  local parent_V = _V
  local _V = setmetatable({}, {__index = parent_V})
  _V.v314 = nil
  _V.v315 = nil
  _V.v260 = v260  -- iconv parameter
  _V.v259 = v259  -- n parameter
  while true do
    if _V.v260 == 0 then
      -- MISSING: _V.v316 = _V.v102  -- Should load "%d"!
      _V.v314 = caml_format_int(_V.v316, _V.v259)  -- v316 is nil!
      _V.v315 = _V.v156(_V.v260, _V.v314)
      return _V.v315
    else if _V.v260 == 1 then
      -- MISSING: _V.v316 = _V.v103  -- Should load different format!
      _V.v314 = caml_format_int(_V.v316, _V.v259)  -- v316 is nil!
      ...
```

**Issue**: No assignment to `v316` before the `caml_format_int` call in any case!

## What Should Be Generated

### Expected Lua Code

```lua
_V.v157 = caml_make_closure(2, function(v260, v259)
  local parent_V = _V
  local _V = setmetatable({}, {__index = parent_V})
  _V.v314 = nil
  _V.v315 = nil
  _V.v316 = nil  -- Declare variable for format string
  _V.v260 = v260
  _V.v259 = v259
  while true do
    if _V.v260 == 0 or _V.v260 == 13 then
      _V.v316 = _V.v102  -- Load "%d" format string
      _V.v314 = caml_format_int(_V.v316, _V.v259)
      _V.v315 = _V.v156(_V.v260, _V.v314)
      return _V.v315
    else if _V.v260 == 1 then
      _V.v316 = _V.v103  -- Load "%+d" or similar
      _V.v314 = caml_format_int(_V.v316, _V.v259)
      _V.v315 = _V.v156(_V.v260, _V.v314)
      return _V.v315
    else if _V.v260 == 2 then
      _V.v316 = _V.v104  -- Load "% d" or similar
      _V.v314 = caml_format_int(_V.v316, _V.v259)
      _V.v315 = _V.v156(_V.v260, _V.v314)
      return _V.v315
    ...
```

### Format String Constants (Already Defined)

**Line 13085** in test_simple.lua:
```lua
_V.v102 = "%d"
_V.v103 = "%+d"
_V.v104 = "% d"
_V.v106 = "%x"
_V.v107 = "%#x"
_V.v108 = "%X"
...
```

These constants ARE defined - they just need to be loaded into v316 before use!

## The Fix

### Option A: Fix Switch Case Bodies (RECOMMENDED)

Modify `compiler/lib-lua/lua_generate.ml` to emit a variable assignment at the start of each switch case body.

When compiling a switch case that jumps to a block, check if that block has instructions that load constants. Generate those load instructions at the start of the case body.

### Option B: Pass Format String as Argument

Modify switch compilation to pass the format string as an argument to each case block.

This would require:
1. Analyzing what constant is loaded in each case
2. Passing it as a block argument
3. Updating block to receive the argument

### Option C: Fix at IR Level

Ensure the OCaml IR has explicit load instructions for the constants in each case, then make sure lua_generate.ml compiles them correctly.

## Investigation Steps

1. **Examine IR/bytecode** to see if load instructions exist
   - If yes: lua_generate.ml is not compiling them correctly
   - If no: Need to understand why IR doesn't have them

2. **Find where v157 is generated**
   - Search lua_generate.ml for where switch statements are compiled
   - Identify why load instructions are missing

3. **Implement fix**
   - Add load instruction generation
   - Map case values to format string constants
   - Test with Printf %d

4. **Verify**
   - Compile test case
   - Run with Lua
   - Should print "42" successfully

## Key Code Locations

- **lua_generate.ml:2575-2596**: Switch compilation
- **test_simple.lua:18121**: v157 closure (convert_int equivalent)
- **test_simple.lua:13085**: Format string constants (v102, v103, etc.)
- **test_simple.ml.pretty.js:7226**: JS convert_int (reference implementation)

## Next Steps

1. Time box: 30 minutes to investigate IR and find where loads should come from
2. If clear: Implement fix
3. If unclear: Document findings and create simpler test case
4. Test and commit

## Success Criteria

```bash
$ echo 'let () = Printf.printf "%d\n" 42' > /tmp/test.ml
$ just quick-test /tmp/test.ml
42
```

Output: "42" printed successfully! ✅
