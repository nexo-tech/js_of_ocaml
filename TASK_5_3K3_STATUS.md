# Task 5.3k.3 - Printf Output Issue
**Date**: 2025-10-15
**Status**: IN PROGRESS - Root cause partially identified

## Problem

Printf.printf "%f\n" 3.14 completes successfully but produces NO output.

## What Works

✅ Dispatch infrastructure complete (Task 5.3k.1)
✅ Control flow guard prevents infinite loop (Task 5.3k.2)
✅ Blocks 570-587 execute and return successfully
✅ Program completes with exit code 0
✅ caml_format_float function works (returns "3.140000" as bytes)

## What's Broken

❌ No "3.140000" output to stdout (only newline)

## Investigation Findings

### Comparison: %d vs %f

**Generated Code**: IDENTICAL except for:
- Format string: `{4,0,0,0,{12,10,0}}` vs `{8,{0,0,0},0,0,{12,10,0}}`
- Value: `42` vs `3.14`

**Execution**:
- %d: caml_ml_output called with `len=2, bytes=[50]` → outputs "42" ✅
- %f: caml_ml_output called with `len=0` → outputs "" ❌

### Root Cause

**caml_ml_output is called with EMPTY STRING for %f!**

Trace output:
```
[caml_ml_output: len=0]
[OUTPUT-CHAR: 10]
```

This means:
1. The Printf chain executes
2. caml_ml_output is called to flush the buffer
3. But the buffer is EMPTY (no formatted float added)
4. Only the newline character (10) is output

### Why Buffer is Empty

**Hypothesis**: The formatter closure (v412 created at block 575) is never invoked, OR it's invoked but doesn't add to the buffer.

**Evidence**:
- Trace shows v161 (formatter function) is NEVER CALLED
- Block 575 creates closure v412 that would call v161
- But v412 itself may not be invoked with the float value

**Execution Flow** (block trace):
```
[572][573][574][575][576][577][578][579][580][581][582][583][584][585][586][587]
```

Blocks execute, closures are created and returned, but the final closure that formats and buffers the float is not called.

## Comparison with %d

For %d (working):
- Format tag 4 → different dispatch path
- Likely calls formatter directly, adds to buffer immediately
- Buffer has "42" when caml_ml_output is called

For %f (broken):
- Format tag 8 → continuation block path (572-587)
- Creates closure chains
- Returns closure that should format float
- But that closure is never invoked OR doesn't add to buffer

## Next Steps

### 1. Trace %d Printf Chain
Add traces to %d version to see WHEN caml_ml_output is called and what adds "42" to the buffer.

### 2. Compare Buffer Management
Check how buffer is managed for tag 4 vs tag 8:
- Where is formatted string added to buffer?
- What function adds it?
- Why does %f skip this step?

### 3. Check Closure Invocation
Verify if v412 (the closure returned from block 575) is ever called:
- Trace its creation
- Trace when/if it's invoked
- Check what arguments it receives

### 4. Reference js_of_ocaml
Examine JS Printf implementation for tag 8 (float):
- How does JS handle the buffer?
- What's the closure chain for floats?
- Compare with tag 4 (integer)

## Test Commands

```bash
# Trace caml_ml_output
lua /tmp/trace_ml_output.lua
timeout 3 lua /tmp/test_f_mloutput_trace.lua  # Shows len=0

# Trace formatter calls
lua /tmp/test_trace_v161.lua
timeout 3 lua /tmp/test_f_v161_trace.lua  # No output (v161 never called)

# Verify completion
timeout 3 lua /tmp/test_f.lua
echo $?  # Returns 0 (success)
```

## Files to Check

- `compiler/lib-lua/lua_generate.ml` - Data-driven dispatch generation
- `runtime/lua/format.lua:293` - caml_format_float implementation
- `runtime/lua/io.lua:593` - caml_ml_output implementation
- Generated code around blocks 575-587 - Closure creation and returns

## Expected Behavior

For Printf.printf "%f\n" 3.14:
1. Parse format string → tag 8
2. Create closure chain
3. Call with value 3.14
4. Formatter formats to "3.140000"
5. Add to buffer
6. Flush buffer to stdout
7. Output newline

**Current**: Steps 1-4 may be working, step 5 is MISSING (buffer stays empty), steps 6-7 execute with empty buffer.
