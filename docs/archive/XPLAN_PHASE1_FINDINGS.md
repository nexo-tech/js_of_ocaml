# XPLAN Phase 1 Findings

**Date**: 2025-10-14
**Phase**: Baseline Verification

---

## Task 1.1: Build State ✅

**Build Status**: Success
- Clean build completed with no errors
- Compiler: `lua_of_ocaml.exe` version 6.2.0 (23M)
- Location: `_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe`
- Runtime tests: All 6 modules pass (closure, fun, obj, format, io, effect)
- Warnings: 0 compilation warnings

**Runtime Modules Tested**:
1. ✅ closure.lua
2. ✅ fun.lua
3. ✅ obj.lua
4. ✅ format.lua
5. ✅ io.lua
6. ✅ effect.lua

---

## Task 1.2: Failure Mode Documentation ✅

### Test Case 1: Simple Printf (NO format specifiers)
**Code**: `Printf.printf "Hello, World!\n"`
**Result**: ✅ **WORKS**
**Output**: `Hello, World\!`

**Observation**: Simple string printing works correctly with current workaround in `runtime/lua/fun.lua` (Task 3.6.5.7 Option B)

### Test Case 2: Printf with Format Specifier (%d)
**Code**: `Printf.printf "Value: %d\n" 42`
**Result**: ❌ **HANGS** (infinite loop or waiting for input)

**Observation**: Process does not error out immediately but hangs indefinitely

### Test Case 3: Printf Multiple Format Specifiers
**Code**:
```ocaml
let () =
  Printf.printf "Test 1: Simple string\n";
  Printf.printf "Test 2: Int %d\n" 42;
  Printf.printf "Test 3: String %s\n" "hello";
  Printf.printf "Test 4: Multiple %d + %d = %d\n" 2 3 5;
  Printf.printf "Test 5: Float %.2f\n" 3.14159
```

**Result**: ❌ **RUNTIME ERROR**

**Error Details**:
```
lua: /tmp/quick_test.lua:4805: attempt to get length of local 's' (a nil value)
stack traceback:
	/tmp/quick_test.lua:4805: in function 'caml_ocaml_string_to_lua'
	/tmp/quick_test.lua:4265: in function 'caml_format_int'
	/tmp/quick_test.lua:18368: in function </tmp/quick_test.lua:18354>
	(tail call): ?
	(tail call): ?
	/tmp/quick_test.lua:20874: in function 'actual_f'
	/tmp/quick_test.lua:11560: in function </tmp/quick_test.lua:11514>
	(tail call): ?
	/tmp/quick_test.lua:21642: in function '__caml_init__'
	/tmp/quick_test.lua:21667: in main chunk
```

**Root Cause Analysis**:

1. **Error Location**: Line 4805 in `caml_ocaml_string_to_lua`
   ```lua
   for i = 1, #s do  -- Line 4805: #s fails because s is nil
   ```

2. **Call Chain**:
   - `caml_format_int(fmt, i)` at line 4265
   - Calls `caml_ocaml_string_to_lua(fmt)` to convert format string
   - But `fmt` parameter is **nil**!

3. **The Problem**: Partial application / closure is not passing the format string argument correctly

**Code at Error Site** (line 4265):
```lua
function caml_format_int(fmt, i)
  local fmt_str = caml_ocaml_string_to_lua(fmt)  -- fmt is nil here!
  -- ...
end
```

**Generated Code Stats**:
- Total lines: 21,597
- Total functions: 764
- This is for a simple multi-line Printf test!

---

## Key Discoveries

### Discovery 1: Runtime Implementation Difference

**JavaScript Runtime** (`runtime/js/format.js`):
- Only 2 Printf primitives:
  - `caml_parse_format`
  - `caml_finish_formatting`

**Lua Runtime** (`runtime/lua/format.lua`):
- 18 Printf primitives (9x more!):
  - `caml_parse_format`
  - `caml_finish_formatting`
  - `caml_ocaml_string_to_lua` ⚠️
  - `caml_lua_string_to_ocaml` ⚠️
  - `caml_str_repeat`
  - `caml_skip_whitespace`
  - `caml_format_int` ⚠️
  - `caml_format_int_special`
  - `caml_format_float`
  - `caml_format_string`
  - `caml_format_char`
  - `caml_scan_int`
  - `caml_scan_float`
  - `caml_scan_string`
  - `caml_scan_char`
  - `caml_sscanf`
  - `caml_fscanf`
  - `caml_scanf`

**Implication**: Lua implementation uses a different architecture - more runtime functions instead of relying on compiled OCaml stdlib code.

### Discovery 2: Partial Application Issue

The workaround in `runtime/lua/fun.lua` (Task 3.6.5.7 Option B) handles simple cases but **does not correctly handle multi-argument partial application** needed for Printf format specifiers.

**What Works**:
- `Printf.printf "Hello\n"` - No arguments after format string

**What Breaks**:
- `Printf.printf "Value: %d\n" 42` - One argument after format string
- Format string (`fmt`) is not being captured/passed correctly to `caml_format_int`

### Discovery 3: Compilation Warnings

**Persistent Warnings** (10 total):
1. `caml_float_compare` - provided by `compare` and `float`
2. `caml_floatarray_append` - provided by `array` and `float`
3. `caml_floatarray_blit` - provided by `array` and `float`
4. `caml_floatarray_concat` - provided by `array` and `float`
5. `caml_floatarray_get` - provided by `array` and `float`
6. `caml_floatarray_set` - provided by `array` and `float`
7. `caml_floatarray_sub` - provided by `array` and `float`
8. `caml_format_float` - provided by `float` and `format`
9. `caml_int32_compare` - provided by `compare` and `ints`
10. `caml_ocaml_string_to_lua` - provided by `buffer` and `format` ⚠️

**Impact**: Non-blocking but indicates duplicate runtime definitions

---

## Next Steps for Phase 2

Based on findings, Phase 2 should focus on:

1. **Study js_of_ocaml Printf compilation**:
   - How does JS handle Printf.printf with format specifiers?
   - Why does JS only need 2 runtime functions vs Lua's 18?
   - How are format arguments passed through closures in JS?

2. **Understand partial application in Printf**:
   - Printf.printf returns a function that takes format arguments
   - Example: `Printf.printf "Value: %d\n"` returns `int -> unit`
   - This closure must capture the format string
   - Current Lua implementation is losing this capture

3. **Compare generated code**:
   - Generate JS and Lua for same Printf test
   - Compare closure structures
   - Identify where Lua loses format string argument

4. **Fix caml_format_int calling convention**:
   - Either fix how format string is passed
   - Or fix how `caml_format_int` retrieves it
   - Must match js_of_ocaml's approach

---

## Baseline Metrics

### Code Generation Comparison (Lua vs JS)

| Test Case | Lua Lines | Lua Functions | JS Lines | JS Functions | Lua/JS Ratio |
|-----------|-----------|---------------|----------|--------------|--------------|
| Test 1: print_endline | 12,758 | 764 | 2,762 | 101 | 4.6x |
| Test 3: Printf simple | 21,587 | 764 | 6,639 | 287 | 3.3x |
| Test 4: Printf %d | 21,597 | 764 | 6,640 | 287 | 3.3x |

**Observations**:
- Lua generates 3-5x more code than JS for same program
- Lua function count (764) is constant across tests - suggests massive runtime inclusion
- JS scales function count with program complexity (101 → 287)
- Simple Printf vs Printf with %d: nearly identical size (both broken/hanging in Lua)

### Runtime Comparison

| Runtime | Total Lines | Printf Functions |
|---------|-------------|------------------|
| Lua | 38,879 | 18 functions |
| JS | 14,720 | 2 functions |

**Key Difference**: Lua runtime implements 9x more Printf functions than JS. This architectural difference suggests:
- JS relies on compiled OCaml stdlib code for Printf
- Lua implements Printf formatting in runtime instead
- Lua's approach increases runtime size but may reduce generated code size
- However, Lua still generates MORE total code (runtime + generated)

### Compiler Metrics

- **Compiler Binary**: 23M (lua_of_ocaml.exe version 6.2.0)
- **Build Time**: < 5 seconds (clean build)
- **Compilation Warnings**: 10 primitive override warnings (non-blocking)

---

## Status Summary

**What Works**: ✅
- Build system
- Runtime modules (load correctly)
- Simple Printf (no format specifiers)
- `print_endline` and basic I/O

**What's Broken**: ❌
- Printf with format specifiers
- Partial application of Printf functions
- Format string capture in closures

**Root Cause**:
Partial application in `runtime/lua/fun.lua` does not correctly handle Printf's multi-stage currying where format string must be captured and passed to formatting functions like `caml_format_int`.

**Priority Fix**:
Understand and fix closure variable capture for Printf-style CPS functions (see XPLAN Phase 2).
