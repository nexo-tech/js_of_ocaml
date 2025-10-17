# Phase 2 Task 2.1: JavaScript Runtime Structure Analysis

**Date**: 2025-10-14
**Status**: Complete

---

## Runtime Function Registration Pattern

### Structure
All JS runtime functions follow this pattern:

```javascript
//Provides: function_name
//Requires: dependency1, dependency2
function function_name(args) {
  // implementation
}
```

**Key Points**:
- `//Provides:` comment declares the function name for the linker
- `//Requires:` comment lists dependencies (other runtime functions)
- Functions are plain JavaScript functions (no special wrapper)
- Linker parses these comments to build dependency graph
- Only required functions are included in final output

### Example: format.js

```javascript
//Provides: caml_parse_format
//Requires: caml_jsbytes_of_string, caml_invalid_argument
function caml_parse_format(fmt) {
  fmt = caml_jsbytes_of_string(fmt);
  var len = fmt.length;
  if (len > 31) caml_invalid_argument("format_int: format too long");
  var f = {
    justify: "+",
    signstyle: "-",
    filler: " ",
    alternate: false,
    base: 0,
    signedconv: false,
    width: 0,
    uppercase: false,
    sign: 1,
    prec: -1,
    conv: "f",
  };
  // ... parse format string into f object
  return f;
}

//Provides: caml_finish_formatting
//Requires: caml_string_of_jsbytes
function caml_finish_formatting(f, rawbuffer) {
  // ... apply formatting rules from f to rawbuffer
  return caml_string_of_jsbytes(buffer);
}
```

---

## Printf Runtime Architecture: JS vs Lua

### JavaScript Approach (2 runtime functions)

**Runtime functions** (runtime/js/format.js):
1. `caml_parse_format(fmt)` - Parse format string → format object
2. `caml_finish_formatting(f, rawbuffer)` - Apply format rules → final string

**Generated code** (from OCaml stdlib Printf module):
- `caml_format_int(fmt, i)` - Convert int to string (INLINED from stdlib)
- `caml_format_float(fmt, f)` - Convert float to string (INLINED from stdlib)
- Printf formatting logic - Full CPS state machine (INLINED from stdlib)

**Example from generated JS** (/tmp/test4.js:702-723):
```javascript
function caml_format_int(fmt, i){
  if(caml_jsbytes_of_string(fmt) === "%d")
    return caml_string_of_jsbytes("" + i);
  var f = caml_parse_format(fmt);  // Parse format
  if(i < 0)
    if(f.signedconv){
      f.sign = -1;
      i = -i;
    }
    else
      i >>>= 0;
  var s = i.toString(f.base);  // Convert to string
  if(f.prec >= 0){
    f.filler = " ";
    var n = f.prec - s.length;
    if(n > 0)
      s = caml_str_repeat(n, "0") + s;
  }
  return caml_finish_formatting(f, s);  // Apply formatting
}
```

**Key Insight**: The actual formatting logic (int→string, float→string) is in the GENERATED code from OCaml stdlib, NOT in the runtime!

### Lua Approach (18 runtime functions)

**Runtime functions** (runtime/lua/format.lua):
1. `caml_parse_format` - Parse format string
2. `caml_finish_formatting` - Apply formatting
3. **`caml_format_int`** - Convert int to string (IN RUNTIME!)
4. **`caml_format_float`** - Convert float to string (IN RUNTIME!)
5. `caml_format_string`, `caml_format_char` - Other formatters (IN RUNTIME!)
6. ... 12 more functions for scanf, etc.

**Generated code**:
- Printf formatting logic - CPS state machine (from stdlib)
- Calls runtime functions for formatting

**Key Difference**: Lua moves formatting functions INTO the runtime instead of inlining from stdlib.

**Why this matters for the bug**:
- In JS: Format string is passed directly to inlined `caml_format_int` in generated code
- In Lua: Format string must be passed through closure → partial application → runtime `caml_format_int`
- Current Lua partial application loses the format string parameter!

---

## Printf Call Structure in Generated JS

### The Call Site
From /tmp/test4.js (end of file):
```javascript
caml_call1
 (a
   (function(a){p(Q, a); return 0;},  // Continuation
    0,  // State
    [0, [11, "Value: ", [4, 0, 0, 0, [12, 10, 0]]], "Value: %d\n"][1]),  // Format
  42);  // Argument
```

**Breakdown**:
- `a` = Printf formatting function (CPS state machine)
- First call to `a` with:
  1. Continuation: `function(a){p(Q, a); return 0;}` - output result to stdout
  2. State: `0` - initial accumulator
  3. Format structure: `[11, "Value: ", [4, 0, 0, 0, [12, 10, 0]]]` - compiled format
- Returns a closure expecting integer argument
- `caml_call1(closure, 42)` - Apply closure to argument

**Format Structure**:
- `[11, "Value: ", ...]` = String literal "Value: "
- `[4, 0, 0, 0, ...]` = Integer format (%d) with no width/precision
- `[12, 10, 0]` = Character format (newline '\n')

**Key**: The format string `"Value: %d\n"` is compiled at OCaml compile time into a data structure!

---

## Printf Closure Creation (Function A)

From /tmp/test4.js:6523-6555:
```javascript
function A(g, f, e, h, d, c, b){
  // Simplest case (no width/precision):
  if(typeof h === "number"){
    if(typeof d === "number")
      return function(d){
        return a(g, [4, f, caml_call2(c, b, d)], e);
      };
  }
  // ... other cases with width/precision
}
```

**Parameters**:
- `g` = continuation function
- `f` = accumulator state
- `e` = rest of format structure
- `h` = width spec
- `d` = precision spec
- `c` = formatting function (e.g., caml_format_int)
- `b` = format string

**Key Behavior**:
1. Creates a closure: `function(d) { ... }`
2. Closure CAPTURES: `g`, `f`, `e`, `c`, `b` (format string!)
3. When called with argument `d` (e.g., 42):
   - Calls `caml_call2(c, b, d)` = `caml_format_int(format_string, 42)`
   - Format string `b` is available because it's captured in closure!
4. Continues processing with `a(g, [4, f, result], e)`

**This is the correct pattern**: Format string is captured in closure and passed to formatting function when argument arrives.

---

## How Generated Code Uses Runtime

### Runtime Inlining
Generated JS includes runtime functions inline at the beginning:
```javascript
// /tmp/test4.js:436-536
function caml_parse_format(fmt){...}
function caml_finish_formatting(f, rawbuffer){...}
```

Then stdlib-derived functions:
```javascript
// /tmp/test4.js:702-723
function caml_format_int(fmt, i){
  var f = caml_parse_format(fmt);  // Uses runtime
  var s = i.toString(f.base);
  return caml_finish_formatting(f, s);  // Uses runtime
}
```

**Linker Process**:
1. Parses `//Provides:` comments from runtime files
2. Builds dependency graph with `//Requires:`
3. Includes only needed runtime functions
4. Inlines them at top of generated file
5. Generated stdlib code can call them directly

---

## Key Findings

### 1. Architectural Difference
- **JS**: Minimal runtime (2 Printf functions), stdlib code inlined
- **Lua**: Large runtime (18 Printf functions), stdlib code separated

### 2. Closure Pattern
JS correctly captures format string in closure:
```javascript
function A(..., c, b) {  // c=formatter, b=format_string
  return function(d) {   // Closure capturing b
    caml_call2(c, b, d); // Format string available!
  };
}
```

### 3. Call Chain
```
Printf.printf "Value: %d\n" 42
  ↓
a(continuation, state, format_structure)
  ↓ (processes format_structure)
A(cont, state, rest, width, prec, caml_format_int, format_string)
  ↓ (creates closure)
function(arg) { caml_format_int(format_string, arg) }
  ↓ (returned closure)
caml_call1(closure, 42)
  ↓
caml_format_int("Value: %d\n", 42)
  ↓
caml_parse_format("%d") + i.toString(10) + caml_finish_formatting
  ↓
"42"
```

### 4. Why Lua Fails
Lua's `runtime/lua/fun.lua` partial application doesn't properly handle closures that need to capture and pass format strings through CPS chains. When `caml_format_int(fmt, i)` is called in Lua, `fmt` is `nil` because the closure didn't capture it.

---

## Next Steps

**Task 2.2**: Study JS code generation to understand how closures are compiled
**Task 2.3**: Study JS closure handling in detail
**Task 2.4**: Study complete Printf implementation flow
**Focus**: Understand HOW to fix Lua's partial application to match JS behavior
