# XPLAN Phase 4: Printf %d Debugging Session

## Status: 🔍 IN PROGRESS

## Key Discovery: Not a Hang - Silent Completion!

### Initial Assumption: WRONG
- **Thought**: Program hangs in infinite loop
- **Reality**: Program completes successfully but produces NO OUTPUT

### Evidence

```bash
$ timeout 3 lua test_printf_d.lua
# Returns immediately (no timeout)
# Exit code: 0
# Output: (empty)
```

But:
```bash
$ lua test_simple.lua
Hello, World!
# Works fine
```

### What Works vs What Fails

| Test | Result | Output |
|------|--------|--------|
| `print_endline "Hello"` | ✅ WORKS | "Hello" |
| `print_int 42` | ✅ WORKS | "42" |
| `Printf.printf "Hello\n"` | ✅ WORKS | "Hello" |
| `Printf.printf "%d\n" 42` | ❌ SILENT | (none) |
| `Printf.sprintf "%d" 42` | ❌ CRASH | "[C]: ?" error |

### Analysis

**Pattern**: Format specifiers cause issues
- Simple string Printf: works (uses different code path?)
- Format specifier Printf: completes silently (no output)
- Format specifier sprintf: crashes

**Hypothesis**: The format processing closures are created but:
1. Either not called correctly
2. Or called but produce no output
3. Or produce output that gets lost

### Investigation Steps Taken

1. **Checked if file loads**: ✅ Loads fine with dofile()
2. **Checked if __caml_init__ completes**: ✅ Completes (added debug print)
3. **Checked exit code**: ✅ Returns 0 (success)
4. **Checked output**: ❌ Empty (no output produced)

### Code Flow Analysis

Printf %d execution (in test_printf_d.lua):
```lua
Line 20945: _V.v184 = 42                         -- The value
Line 20946: _V.v180 = _V.v185[2]                 -- Format structure
Line 20947: _V.v181 = 0                          -- State
Line 20948: _V.v182 = closure(v294)              -- Continuation
Line 20966: _V.v183 = _V.v166(v182, v181, v180) -- Printf formatter
Line 20969: _V.v183(v184)                        -- Call with 42
```

The call at line 20969 must complete (since __caml_init__ returns), but no output is produced.

### Removed Workaround

**Commit**: Removed fun.lua workaround (lines 84-101)
- This was Task 3.6.5.7 Option B
- Tried to call 2-arity functions with 1 arg + nil
- Didn't help - Printf %d still fails
- Simple Printf still works without it

### Next Steps

1. **Add debug output to generated Lua**
   - Print before/after Printf call
   - Check if caml_ml_output is actually called

2. **Compare generated code: simple vs %d**
   - Simple string: trace execution path
   - Format spec: trace execution path
   - Find where they diverge

3. **Check runtime Printf functions**
   - Is caml_format_int being called?
   - Is it receiving correct arguments?
   - Is it producing output?

4. **Compare with JS behavior**
   - How does JS handle Printf %d?
   - What's different in the generated code?

### Remaining Questions

1. Why does Printf complete but produce no output?
2. Why does sprintf crash with "[C]: ?" error?
3. Is the format processing closure chain correct?
4. Are the runtime functions being called at all?

## Files Changed

```
M  runtime/lua/fun.lua  (-19 lines)
   - Removed workaround from Task 3.6.5.7 Option B
   - Was not helping and potentially causing confusion
```

## Conclusion

This is NOT a closure variable capture issue (that's fixed). This is a Printf-specific runtime issue where format processing completes but produces no output. Need more targeted debugging to find where output is being lost or suppressed.
