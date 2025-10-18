# XPLAN Phase 4: Root Cause - Printf Arity Bug

## Status: 🎯 ROOT CAUSE IDENTIFIED

## The Bug

**Printf.printf "%d\n" 42** returns a closure with **arity 2** instead of **arity 1**.

### Evidence

```lua
_V.v183 = _V.v166(_V.v182, _V.v181, _V.v180)  -- Call Printf formatter
-- v183 has arity 2 (should be 1)

_V.v186 = caml_call_gen(_V.v183, {_V.v184})    -- Call with 1 arg (42)
-- Creates partial application closure waiting for 2nd argument
-- But no 2nd argument ever comes!
```

**Debug output**:
```
DEBUG: v183 type: table
DEBUG: v183.l = 2        ← Should be 1!
DEBUG: v184 = 42
DEBUG: Taking caml_call_gen path
DEBUG caml_call_gen: f.l=2 #args=1
```

### Comparison: Working vs Broken

**Simple Printf (works)**:
```lua
Printf.printf "Hello\n"
v183 = v166(...)  -- Returns 0 or similar (not a closure)
v183.l = nil      -- Not a closure, prints directly
Output: "Hello"   ✅
```

**Printf with %d (broken)**:
```lua
Printf.printf "%d\n" 42
v183 = v166(...)  -- Returns closure with arity 2
v183.l = 2        -- ❌ Should be 1!
caml_call_gen creates partial application
No output         ❌
```

### JavaScript Comparison

**JS Code**:
```javascript
caml_call1(
  a(function(a){p(Q, a); return 0;}, 0, format[1]),
  42
)
```

`a(...)` (Printf formatter) with 3 args returns a closure that:
- Takes **1 argument** (the value to print)
- `caml_call1` calls it with 42
- Works correctly ✅

### Tracing the Bug

1. **v166** (line 19698): Printf formatter with arity 3
   - Called with 3 args: continuation, state, format
   - Returns result of `v202(...)`

2. **v202** (line 18948): Main format processor with arity 4
   - Processes format structure
   - Returns a closure
   - **This closure has arity 2** ❌

3. **v183**: The returned closure
   - Arity 2 (wrong!)
   - When called with 1 arg, creates partial application
   - Partial application never gets its 2nd argument

### Why Simple Strings Work

For format string `"Hello\n"`:
- Format structure: `{11, "Hello\n", 0}` (just a string)
- v202 processes it differently
- Returns 0 or completion value (not a closure)
- Prints directly during v166 execution
- No closure call needed ✅

For format string `"Value: %d\n"`:
- Format structure: `{11, "Value: ", {4, 0, 0, 0, {12, 10, 0}}}`
- Has format specifier `{4, ...}` for integer
- v202 must return a closure to accept the integer
- But returns arity-2 closure instead of arity-1 ❌

## The Real Question

**Why does v202 return an arity-2 closure?**

Possibilities:
1. **Code generation bug**: OCaml bytecode says arity 1, but lua_of_ocaml generates arity 2
2. **Printf implementation**: The closure genuinely needs 2 args (value + continuation?)
3. **Currying issue**: Should be curried (arity 1 returning arity 1) but got flattened to arity 2

### Checking JS Behavior

Need to verify what the JS version actually does:
- Does `a(...)` return arity-1 or arity-2 closure?
- How does JS handle the continuation?
- Is there explicit currying in JS that's missing in Lua?

## Next Steps

1. **Examine v202 implementation in generated Lua**
   - Find where the arity-2 closure is created
   - Check if it should be arity-1

2. **Compare with JS**
   - Find equivalent function in JS output
   - Check what arity it returns
   - Identify the difference

3. **Check bytecode**
   - Use `just inspect-bytecode` to see OCaml IR
   - Verify what arity the bytecode specifies

4. **Fix options**:
   - **Option A**: Fix caml_make_closure call (wrong arity specified)
   - **Option B**: Fix Printf format processor logic
   - **Option C**: Fix partial application handling in fun.lua

## Conclusion

The bug is **NOT** in closure variable capture (that's fixed).
The bug is **NOT** in execution flow (code executes fine).
The bug **IS** in **closure arity** - v202 returns arity-2 when it should return arity-1.

This causes partial application to wait for a second argument that never arrives, so the Printf never executes and produces no output.

**This is a code generation bug or Printf implementation bug, not a runtime bug.**
