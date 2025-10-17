# XPLAN Test Suite Results

**Created**: 2025-10-14
**Purpose**: Progressive complexity testing for Printf debugging

---

## Test Suite

### Test 1: Basic Working Case ✅
**File**: `/tmp/xplan_test1_basic.ml`
**Code**:
```ocaml
let () = print_endline "test"
```
**Result**: ✅ PASS
**Output**: `test`
**Notes**: Baseline - confirms basic I/O works

### Test 2: Closure with Printf ❌
**File**: `/tmp/xplan_test2_closure.ml`
**Code**:
```ocaml
let f x = fun () -> x in let g = f 42 in Printf.printf "%d\n" (g())
```
**Result**: ❌ HANG (infinite loop)
**Notes**: Combines closure with Printf format specifier - hangs indefinitely

### Test 3: Printf Simple String ✅
**File**: `/tmp/xplan_test3_printf_simple.ml`
**Code**:
```ocaml
let () = Printf.printf "Hello\n"
```
**Result**: ✅ PASS
**Output**: `Hello`
**Notes**: Simple Printf with no format specifiers works

### Test 4: Printf with Format Specifier ❌
**File**: `/tmp/xplan_test4_printf_format.ml`
**Code**:
```ocaml
let () = Printf.printf "Value: %d\n" 42
```
**Result**: ❌ HANG (infinite loop)
**Notes**: Printf with %d format specifier hangs indefinitely

---

## Pattern Analysis

**Success Pattern**:
- No format specifiers → Works
- Direct function calls → Works

**Failure Pattern**:
- Format specifiers (%d, %s, %.2f) → Hangs or crashes
- Partial application with format strings → Loses arguments

**Root Cause Hypothesis**:
The workaround in `runtime/lua/fun.lua` (Task 3.6.5.7 Option B) passes `nil` for missing arguments. When Printf's format function receives the format string and tries to apply it with arguments, the closure chain breaks because:

1. `Printf.printf "Value: %d\n"` creates a closure expecting `int`
2. When called with `42`, the closure should call format functions with both format string and value
3. Current implementation loses the format string parameter
4. `caml_format_int(fmt, i)` receives `fmt=nil, i=42`
5. Results in hang or crash when trying to process nil format string

---

## Recommended Next Action

Phase 2 must focus on studying how js_of_ocaml handles this exact case:
- Generate JS for Test 4
- Study the closure structure
- Compare with Lua closure structure
- Identify where format string is lost
- Fix the partial application mechanism
