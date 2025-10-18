# XPLAN Phase 4: Root Cause - Lua vs JS Truthiness Bug

## Status: 🎯 ROOT CAUSE FULLY IDENTIFIED

## The Bug

**Printf.printf "%d\n" 42** returns a closure with **arity 2** instead of **arity 1** because:
- **JavaScript** checks `if (width)` where width=0 is **falsy** → returns arity-1 closure ✅
- **Lua** checks `if _V.v284` where v284=0 is **truthy** → returns arity-2 closure ❌

### Truthiness Rules

**JavaScript (correct)**:
```javascript
0 ? "truthy" : "falsy"  // → "falsy"
```
Falsy values: `0`, `""`, `null`, `undefined`, `NaN`, `false`

**Lua (different)**:
```lua
0 and "truthy" or "falsy"  -- → "truthy"
```
Falsy values: **ONLY** `nil` and `false`

## Evidence

### JS Implementation (line 4816-4822)
```javascript
function A(g, f, e, h, d, c, b){
  if(typeof h === "number"){
    if(typeof d === "number")
      return d
        ? function(h, d){...}      // width ≠ 0: arity-2 (padding+value)
        : function(d){...};        // width = 0: arity-1 (value only)
```

**For "%d\n"**: width = 0 → JS sees falsy → returns arity-1 ✅

### Lua Implementation (line 20338-20405)
```lua
_V.v169 = caml_make_closure(7, function(v288, v287, v286, v285, v284, v283, v282)
  if _next_block == 548 then
    _V.v314 = type(_V.v284) == "number" and _V.v284 % 1 == 0
    if _V.v314 then
      _next_block = 549
    else
      _next_block = 552
    end
  else
    if _next_block == 549 then
      if _V.v284 then           -- ❌ BUG: 0 is truthy in Lua!
        _next_block = 550       -- Returns arity-2
      else
        _next_block = 551       -- Returns arity-1
      end
```

**For "%d\n"**: width = 0 → Lua sees truthy → returns arity-2 ❌

### Format Structure
For `Printf.printf "Value: %d\n" 42`:
```ocaml
format = {4, 0, 0, 0, {12, 10, 0}}
         ^   ^  ^  ^
         |   |  |  |
         |   |  |  +-- width = 0 (no padding specified)
         |   |  +----- precision
         |   +-------- pad_char
         +------------ tag 4 = integer format
```

v284 = width = 0

## The Flow

1. **v202** (format processor) sees case 4 (integer %d)
2. Calls **v169** with format parameters including width=0
3. **v169** checks `if _V.v284` (width)
   - **JS**: `if (0)` → false → block 551 → returns arity-1 closure ✅
   - **Lua**: `if 0` → true → block 550 → returns arity-2 closure ❌
4. **v166** trampolines result → v183
5. User code calls v183 with 1 arg (42)
6. caml_call_gen sees arity mismatch (expects 2, got 1) → creates partial application
7. Partial application waits forever for 2nd argument → no output ❌

## The Fix

**Option A: Fix code generation** (CORRECT)
```ocaml
(* In lua_generate.ml, when generating conditionals *)
(* Change: *)
let cond_lua = compile_expr cond
(* To: *)
let cond_lua =
  match cond with
  | Const (Int 0) -> "false"  (* Explicit 0 → false *)
  | _ ->
      (* For general case, compare explicitly *)
      sprintf "(%s ~= 0 and %s ~= false and %s ~= nil)"
        cond_lua cond_lua cond_lua
```

**Option B: Fix at call site** (WORKAROUND)
Manually change line 20339 in generated code:
```lua
-- Before:
if _V.v284 then

-- After:
if _V.v284 ~= 0 then
```

But this won't scale - need to fix code generation for all truthiness checks.

## Code Generation Issue

The bug is in how **if-then-else** expressions are compiled:

**OCaml IR**:
```ocaml
(if width then (closure_with_padding) else (simple_closure))
```

**JS codegen** (correct):
```javascript
width ? function(pad, val){...} : function(val){...}
```
JS semantics: `0 ? a : b` → evaluates to `b` ✅

**Lua codegen** (wrong):
```lua
if width then return closure2 else return closure1 end
```
Lua semantics: `if 0 then a else b end` → evaluates to `a` ❌

### Where to Fix

**File**: `compiler/lib-lua/lua_generate.ml`

**Function**: `compile_expr` handling `If` case:
```ocaml
| If (cond, then_expr, else_expr) ->
    (* Current: Directly translates cond to Lua boolean context *)
    (* Needed: Explicitly convert to boolean with JS semantics *)
```

## Test Case

```bash
cd /tmp
echo 'let () = Printf.printf "Value: %d\n" 42' > test.ml
just compile-lua-debug test.ml
lua test.lua
# Expected output: "Value: 42"
# Actual output: (nothing)
```

## Related Files

- `/tmp/test_printf_d.lua:20279-20405` - v169 with truthiness bug
- `/tmp/test_printf_d.js:4814-4856` - Equivalent JS (correct)
- `compiler/lib-lua/lua_generate.ml` - Code generator (needs fix)

## Conclusion

This is **NOT** a runtime bug. This is **NOT** an arity calculation bug.

This is a **semantic translation bug** where the code generator assumes Lua has JavaScript truthiness semantics.

**The fix must be in the code generator to explicitly convert values to boolean using JS semantics before using them in conditionals.**

## Fix Applied

**Status**: ✅ FIXED

**Implementation**: Modified `lua_generate.ml` line 2554-2574 to generate inline JS truthiness checks.

Instead of calling a runtime function, we generate:
```lua
if v ~= false and v ~= nil and v ~= 0 and v ~= "" then
  -- true branch
else
  -- false branch
end
```

**Result**:
- Printf now returns arity-1 closure (correct!)
- Printf formatter executes and tries to format the integer
- **New bug discovered**: format string parameter is nil (separate issue)

**Files changed**:
- `compiler/lib-lua/lua_generate.ml`: Added inline JS truthiness check for `Code.Cond`

**Test result**:
```
$ lua /tmp/test_simple.lua
lua: /tmp/test_simple.lua:4805: attempt to get length of local 's' (a nil value)
```

Progress: No longer hanging, actually executes Printf formatting code!
