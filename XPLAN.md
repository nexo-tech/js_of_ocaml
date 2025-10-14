# XPLAN.md - Systematic Study Plan for lua_of_ocaml Printf Fix

**Created**: 2025-10-14
**Goal**: Get `Printf.printf "Hello, World!\n"` working through comprehensive study and systematic fixes
**Approach**: Study js_of_ocaml thoroughly, verify every component, fix all inconsistencies

---

## Current Status (2025-10-14 08:20 UTC)

**What Works**: ✅
- `print_endline` - fully functional
- `Printf.printf "Hello, World!\n"` - works with simple strings (no format specifiers)
- Basic closures and nested closures
- Runtime modules load correctly

**What's Broken**: ❌
- `Printf.printf` with format specifiers (`%d`, `%s`, `%.2f`, etc.)
- Error: `attempt to get length of local 's' (a nil value)` in `caml_ocaml_string_to_lua`
- Called from `caml_format_int` when processing `%d`

**Recent Fix (Uncommitted)**:
- `runtime/lua/fun.lua` has workaround (Task 3.6.5.7 Option B)
- Passes nil for missing arguments in partial application
- This fixes simple Printf strings but NOT format specifiers

**Why XPLAN**:
SPLAN.md made partial progress but:
1. Current fix is a workaround, not root cause fix
2. Format specifiers still completely broken
3. Need systematic js_of_ocaml study to understand correct approach
4. Need to fix runtime functions like `caml_format_int`, `caml_ocaml_string_to_lua`

---

## Plan Revision (2025-10-14)

**Original Plan**: 7 phases, 42 tasks, systematic study of all components
**Revised Plan**: 5 phases, 31 tasks, focused on critical finding

**Why Revised**: Phase 2 Tasks 2.1-2.2 identified the critical function (`parallel_renaming` in JS generator) that ensures parameters are declared before block execution. No need for remaining generic JS study - directly compare with Lua generator and implement fix.

**Focus**: Find equivalent in `compiler/lib-lua/lua_generate.ml` or implement it

---

## Master Checklist

### Phase 1: Baseline Verification - [x] COMPLETE
- [x] Task 1.1: Verify current build state
- [x] Task 1.2: Document current failure mode
- [x] Task 1.3: Create test suite for verification
- [x] Task 1.4: Verify justfile commands work
- [x] Task 1.5: Document baseline metrics

**Results**: See `XPLAN_PHASE1_FINDINGS.md` and `XPLAN_TEST_SUITE.md`

**Key Metrics**:
- Test 1 (print_endline): Lua 12,758 lines / 764 functions vs JS 2,762 lines / 101 functions
- Test 4 (Printf %d): Lua 21,597 lines / 764 functions vs JS 6,640 lines / 287 functions
- Lua runtime: 38,879 lines total vs JS runtime: 14,720 lines total
- Code size ratio: Lua ~3.2x larger than JS

**Root Cause Identified**:
Printf with format specifiers hangs because `caml_format_int(fmt, i)` receives `fmt=nil`. The partial application in `runtime/lua/fun.lua` does not correctly capture/pass the format string through Printf's CPS closure chain.

### Phase 2: js_of_ocaml Deep Study - [x] COMPLETE (Critical findings obtained)
- [x] Task 2.1: Study JavaScript runtime structure
- [x] Task 2.2: Study JavaScript code generation
- [~] Task 2.3-2.7: SKIPPED (Critical function found, no need for generic study)

**Results**: See `XPLAN_PHASE2_TASK1.md` and `XPLAN_PHASE2_TASK2.md`

**Key Discoveries**:
- JS runtime has only 2 Printf functions vs Lua's 18 - different architecture
- JS inlines stdlib formatting code (caml_format_int) vs Lua puts it in runtime
- **CRITICAL**: `parallel_renaming` function (compiler/lib/generate.ml:981) declares parameters BEFORE block execution
- This ensures all arguments are available when closure body executes
- Format strings are captured in closures through JavaScript's lexical scoping
- Printf uses CPS with closures that capture format string + formatting function

**Root Cause Confirmed**:
Lua likely missing equivalent of `parallel_renaming` or not generating parameter declarations before block body. This causes format string parameter to be undefined/nil when `caml_format_int` is called.

### Phase 3: Direct Lua/JS Code Generator Comparison - [x] COMPLETE
- [x] Task 3.1: Find parameter passing in lua_generate.ml
- [x] Task 3.2: Compare with JS parallel_renaming pattern
- [x] Task 3.3: Identify exact discrepancy
- [~] Task 3.4-3.6: SKIPPED (Already have clear evidence and root cause)
- [x] Task 3.7: Design fix based on JS pattern

**Results**: See `XPLAN_PHASE3_TASK1.md`, `XPLAN_PHASE3_TASK2.md`, `XPLAN_PHASE3_TASK3.md`, and `XPLAN_PHASE3_TASK7.md`

**Key Findings from Task 3.1**:
- Found Lua parameter passing: `setup_hoisted_variables` → `setup_entry_block_arguments`
- Entry block parameters EXCLUDED from hoisting (line 1701 in lua_generate.ml)
- Lua generates `_V.param = arg` (assignment) vs JS `var param = arg;` (declaration)
- Execution order: hoist → param_copy → entry_args → dispatch_loop

**Key Findings from Task 3.2**:
- **ROOT CAUSE FOUND**: Variable shadowing in nested closures!
- JS: Captured variables accessed via lexical scoping (no re-declaration)
- Lua: Captured variables INITIALIZED TO NIL in child _V table (shadows parent!)
- Example: `_V.v268 = nil` in nested closure shadows parent's format function
- Bug location: `setup_hoisted_variables` doesn't distinguish captured vs local variables
- When nested closure accesses `_V.v268`, gets nil instead of parent's value
- Printf fails: `caml_format_int(nil, arg)` → crash

**Key Findings from Task 3.3**:
- **EXACT BUG LOCATION**: lua_generate.ml:1701-1705 in `setup_hoisted_variables`
- Current code: `let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params`
- This initializes ALL hoisted vars (including FREE/captured vars) to nil
- `collect_block_variables` (line 1162) already computes defined_vars vs free_vars
- **FIX**: Only initialize DEFINED vars in nested closures, not FREE vars
- FREE vars should be captured from parent via __index metatable
- Modify `collect_block_variables` to return `(defined, free)` tuple
- Update `setup_hoisted_variables` to exclude free_vars when `ctx.inherit_var_table = true`

**Key Findings from Task 3.7**:
- **COMPLETE FIX DESIGN**: Detailed implementation plan with code examples
- Change 1: `collect_block_variables` return type from `StringSet.t` to `(StringSet.t * StringSet.t)`
- Change 2: `setup_hoisted_variables` conditional logic - exclude free_vars in nested closures
- Change 3: Update call sites (line 1991 in `compile_func_decl`)
- Low risk: Just exposing already-computed information
- Expected: Printf with %d works, nested closures work, no regressions
- Generated code: "Hoisted variables (5 total: 3 defined, 2 free)" with only defined vars initialized

### Phase 4: Fix Implementation - [~] PARTIAL SUCCESS - Printf format specifiers still hang
- [x] Task 4.1: Implement parameter passing fix in lua_generate.ml
- [x] Task 4.2: Test fix with simple closure test - ✅ WORKS
- [x] Task 4.3: Test fix with Printf simple string - ✅ WORKS
- [~] Task 4.4: Test fix with Printf %d format specifier - ❌ HANGS
- [x] Task 4.5: Fixed loop block parameter classification bug
- [ ] Task 4.6: Debug Printf format specifier hanging issue
- [x] Task 4.7: Document fix implementation

**Status**: Two bugs fixed:
1. ✅ Variable shadowing in nested closures - FIXED
2. ✅ Loop block parameters misclassified as free - FIXED

**Working**: print_endline, simple closures, Printf without format specifiers
**Still Broken**: Printf with format specifiers (%d, %s, etc.) - hangs in infinite loop

See `XPLAN_PHASE4_IMPLEMENTATION.md` and `XPLAN_PHASE4_FIX.md` for details.

### Phase 5: Validation & Polish - [ ]
- [ ] Task 5.1: Test all Printf format specifiers (%d, %s, %f, etc.)
- [ ] Task 5.2: Test complex Printf patterns
- [ ] Task 5.3: Verify no regressions in existing tests
- [ ] Task 5.4: Run performance comparison
- [ ] Task 5.5: Clean up any workarounds (e.g., fun.lua Task 3.6.5.7)
- [ ] Task 5.6: Update documentation
- [ ] Task 5.7: Final commit and push

**Total Tasks**: 31 (reduced from 42 by consolidating and focusing)

---

## Phase 1: Baseline Verification

**Goal**: Establish clear baseline of current state

### Task 1.1: Verify current build state - [ ]

**Actions**:
```bash
just clean
just build-lua-all
just test-runtime-all
```

**Document**:
- Build status (success/failure)
- Compiler version built
- Runtime tests status
- Any warnings or errors

**Success Criteria**: Clean build with all runtime tests passing

### Task 1.2: Document current failure mode - [ ]

**Actions**:
```bash
# Create test file
echo 'let () = Printf.printf "Hello, World!\n"' > /tmp/xplan_test_printf.ml

# Compile and run
just quick-test /tmp/xplan_test_printf.ml 2>&1 | tee /tmp/xplan_failure.log
```

**Document**:
- Exact error message
- Stack trace
- Line numbers
- Variable names involved
- Size of generated Lua file
- Number of functions generated

**Success Criteria**: Complete documentation of failure in XPLAN_FINDINGS.md

### Task 1.3: Create test suite for verification - [ ]

**Actions**:
Create test files for progressive complexity:
```bash
# Test 1: Basic working case
echo 'let () = print_endline "test"' > /tmp/xplan_test1_basic.ml

# Test 2: Simple closure
echo 'let f x = fun () -> x in let g = f 42 in Printf.printf "%d\n" (g())' > /tmp/xplan_test2_closure.ml

# Test 3: Printf simple string
echo 'let () = Printf.printf "Hello\n"' > /tmp/xplan_test3_printf_simple.ml

# Test 4: Printf with format
echo 'let () = Printf.printf "Value: %d\n" 42' > /tmp/xplan_test4_printf_format.ml
```

**Test each**:
```bash
for i in 1 2 3 4; do
  echo "=== Test $i ==="
  just quick-test /tmp/xplan_test${i}_*.ml 2>&1 | tee /tmp/xplan_test${i}.log
  echo ""
done
```

**Document**: Which tests pass, which fail, error patterns

### Task 1.4: Verify justfile commands work - [ ]

**Actions**: Test all critical just commands:
```bash
just --list
just verify-all
just build-lua-all
just test-lua
just quick-test /tmp/xplan_test1_basic.ml
just compare-outputs /tmp/xplan_test1_basic.ml
just compile-lua-debug /tmp/xplan_test1_basic.ml.bc
```

**If any command is missing or broken**: Add/fix in justfile immediately

**Success Criteria**: All commands work correctly

### Task 1.5: Document baseline metrics - [ ]

**Actions**: Collect metrics for working vs failing cases:
```bash
# Working case (print_endline)
just quick-test /tmp/xplan_test1_basic.ml
wc -l /tmp/quick_test.lua
grep -c "^function" /tmp/quick_test.lua

# Failing case (Printf)
ocamlc -o /tmp/xplan_test3_printf_simple.ml.bc /tmp/xplan_test3_printf_simple.ml
_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/xplan_test3_printf_simple.ml.bc -o /tmp/printf_output.lua 2>&1
wc -l /tmp/printf_output.lua
grep -c "^function" /tmp/printf_output.lua

# Compare with JS
just compare-outputs /tmp/xplan_test1_basic.ml
just compare-outputs /tmp/xplan_test3_printf_simple.ml
```

**Document in XPLAN_FINDINGS.md**:
- Line counts (Lua vs JS)
- Function counts (Lua vs JS)
- Runtime size
- Generated code size

---

## Phase 2: js_of_ocaml Deep Study

**Goal**: Thoroughly understand how js_of_ocaml works

### Task 2.1: Study JavaScript runtime structure - [ ]

**Actions**:
```bash
# List all JS runtime files
ls -lh runtime/js/*.js

# Study key runtime files
cat runtime/js/core.js | head -200
cat runtime/js/format.js
cat runtime/js/io.js
```

**Analyze**:
1. How are runtime functions registered?
2. What naming convention is used?
3. How are primitives linked?
4. How does the linker find them?

**Document patterns in XPLAN_FINDINGS.md**

### Task 2.2: Study JavaScript code generation - [ ]

**Actions**:
```bash
# Generate pretty JS for analysis
echo 'let () = print_endline "test"' > /tmp/study_simple.ml
just compile-js-pretty /tmp/study_simple.ml.bc /tmp/study_simple.js

# Study the generated code
cat /tmp/study_simple.js
```

**Read source code**:
```bash
# Main code generator
grep -n "compile_block" compiler/lib/generate.ml | head -20
grep -n "compile_closure" compiler/lib/generate.ml | head -20
```

**Analyze**:
1. Overall structure of generated JS
2. How is runtime included?
3. How are functions defined?
4. How are closures created?
5. How are variables initialized?
6. How is control flow handled?

**Document in XPLAN_FINDINGS.md**

### Task 2.3: Study JavaScript closure handling - [ ]

**Actions**:
```bash
# Create closure test
echo 'let f x = fun () -> x in let g = f 42 in print_int (g())' > /tmp/study_closure.ml
just compile-js-pretty /tmp/study_closure.ml.bc /tmp/study_closure.js

# Analyze generated JS
cat /tmp/study_closure.js
```

**Read source**:
```bash
grep -A 50 "compile_closure" compiler/lib/generate.ml
grep -A 30 "parallel_renaming" compiler/lib/generate.ml
```

**Analyze**:
1. How are closure variables captured?
2. How are function parameters passed?
3. How are nested closures handled?
4. What is parallel_renaming doing?
5. How is variable scope managed?

**Document in XPLAN_FINDINGS.md**

### Task 2.4: Study JavaScript Printf implementation - [ ]

**Actions**:
```bash
# Generate Printf code
echo 'let () = Printf.printf "Hello\n"' > /tmp/study_printf.ml
just compile-js-pretty /tmp/study_printf.ml.bc /tmp/study_printf.js

# Study runtime Printf
cat runtime/js/format.js

# Analyze generated code
cat /tmp/study_printf.js | grep -A 100 "printf"
```

**Analyze**:
1. What Printf primitives are used?
2. How is the format string compiled?
3. How are continuations passed?
4. How does the CPS style work in JS?
5. What closure pattern does Printf use?

**Document in XPLAN_FINDINGS.md**

### Task 2.5: Study JavaScript block/variable handling - [ ]

**Actions**:
```bash
grep -A 50 "compile_block" compiler/lib/generate.ml
grep -A 30 "translate_instr" compiler/lib/generate.ml
grep -A 30 "Let.*=" compiler/lib/generate.ml
```

**Analyze**:
1. How are bytecode blocks translated?
2. How are variables declared?
3. How are variables assigned?
4. How are block arguments passed?
5. How are entry blocks handled?
6. When are variables initialized?

**Document in XPLAN_FINDINGS.md**

### Task 2.6: Study JavaScript function compilation - [ ]

**Actions**:
```bash
grep -A 100 "compile_function_body" compiler/lib/generate.ml
grep -A 50 "compile_branch" compiler/lib/generate.ml
```

**Analyze**:
1. How are function bodies compiled?
2. How are branches/blocks organized?
3. How is control flow managed?
4. How are entry points set up?
5. How are return values handled?

**Document in XPLAN_FINDINGS.md**

### Task 2.7: Document js_of_ocaml patterns - [ ]

**Actions**: Create comprehensive documentation in XPLAN_JS_PATTERNS.md

**Include**:
1. Runtime structure and conventions
2. Code generation pipeline
3. Closure compilation pattern
4. Variable initialization pattern
5. Block compilation pattern
6. Function compilation pattern
7. Printf-specific patterns
8. Key differences from expected patterns

---

## Phase 3: lua_of_ocaml Component Verification

**Goal**: Verify every component of lua_of_ocaml works correctly in isolation

### Task 3.1: Verify runtime module structure - [ ]

**Actions**:
```bash
# List all Lua runtime files
just list-runtime

# Verify each runtime file structure
for file in runtime/lua/*.lua; do
  echo "=== $(basename $file) ==="
  just verify-runtime $(basename $file)
done
```

**Check**:
1. All functions have `--Provides:` comments
2. No global variables (except `caml_*` functions)
3. No `require()` calls
4. Lua 5.1 compatible
5. No local helper functions (all must be `caml_*`)

**Document issues in XPLAN_FINDINGS.md**

### Task 3.2: Verify runtime function accessibility - [ ]

**Actions**:
```bash
# Create comprehensive runtime test
cat > /tmp/test_runtime_access.lua << 'EOF'
-- Test that all caml_* functions are globally accessible
dofile("runtime/lua/core.lua")
dofile("runtime/lua/array.lua")
dofile("runtime/lua/io.lua")
dofile("runtime/lua/format.lua")
dofile("runtime/lua/obj.lua")
dofile("runtime/lua/closure.lua")
dofile("runtime/lua/fun.lua")

-- Test core functions
assert(caml_make_vect, "caml_make_vect not found")
assert(caml_array_get, "caml_array_get not found")

-- Test I/O functions
assert(caml_ml_output, "caml_ml_output not found")
assert(caml_ml_output_char, "caml_ml_output_char not found")

-- Test format functions
assert(caml_format_float, "caml_format_float not found")
assert(caml_format_int, "caml_format_int not found")

-- Test Printf functions (if they exist)
if caml_caml_format_int_special then
  print("✓ caml_caml_format_int_special found")
else
  print("✗ caml_caml_format_int_special MISSING")
end

print("✓ Runtime function accessibility verified")
EOF

lua /tmp/test_runtime_access.lua
```

**Document**: Which functions are missing, which exist

### Task 3.3: Verify code generation structure - [ ]

**Actions**:
```bash
# Study Lua code generator
grep -n "generate_lua" compiler/lib-lua/lua_generate.ml | head -20
grep -n "compile_block" compiler/lib-lua/lua_generate.ml | head -20
```

**Read key functions**:
- `generate_lua`
- `compile_blocks_with_labels`
- `generate_closure`
- `hoist_variables`

**Compare with js_of_ocaml**:
- Are the patterns similar?
- What are the key differences?
- Is the control flow similar?

**Document in XPLAN_FINDINGS.md**

### Task 3.4: Verify closure generation - [ ]

**Actions**:
```bash
# Generate simple closure Lua
echo 'let f x = fun () -> x in let g = f 42 in print_int (g())' > /tmp/verify_closure.ml
ocamlc -o /tmp/verify_closure.ml.bc /tmp/verify_closure.ml
_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/verify_closure.ml.bc -o /tmp/verify_closure.lua

# Analyze generated Lua
cat /tmp/verify_closure.lua | grep -A 50 "function.*closure"
```

**Study source**:
```bash
grep -A 100 "generate_closure" compiler/lib-lua/lua_generate.ml
```

**Check**:
1. How are closures created?
2. How are captured variables handled?
3. Is `_V` table used? When?
4. Are parameters passed correctly?
5. Are variables initialized before use?

**Document in XPLAN_FINDINGS.md**

### Task 3.5: Verify block compilation - [ ]

**Actions**:
```bash
grep -A 100 "compile_blocks_with_labels" compiler/lib-lua/lua_generate.ml
```

**Check**:
1. How are blocks organized?
2. How is control flow managed? (dispatch loop?)
3. How are block parameters passed?
4. How are entry blocks handled?
5. Are variables initialized at the right time?

**Compare with js_of_ocaml**:
- Same structure?
- Key differences?

**Document in XPLAN_FINDINGS.md**

### Task 3.6: Verify variable initialization - [ ]

**Actions**:
```bash
grep -A 50 "hoist_variables" compiler/lib-lua/lua_generate.ml
grep -n "local _V" compiler/lib-lua/lua_generate.ml
```

**Check**:
1. When are variables hoisted?
2. What value are they initialized to?
3. When are they assigned actual values?
4. Is the order correct?
5. Are entry block parameters handled specially?

**Document in XPLAN_FINDINGS.md**

### Task 3.7: Document all discrepancies - [ ]

**Actions**: Create XPLAN_DISCREPANCIES.md

**List all differences found**:
1. Runtime structure differences
2. Code generation differences
3. Closure handling differences
4. Variable initialization differences
5. Block compilation differences
6. Printf-specific differences

**Prioritize**: Which differences could cause the bug?

---

## Phase 4: Systematic Comparison

**Goal**: Compare Lua and JS output for progressively complex programs

### Task 4.1: Compare simple program (print_endline) - [ ]

**Actions**:
```bash
echo 'let () = print_endline "test"' > /tmp/compare1.ml
just compare-outputs /tmp/compare1.ml

# Analyze side by side
just compile-js-pretty /tmp/compare1.ml.bc /tmp/compare1.pretty.js
_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/compare1.ml.bc -o /tmp/compare1.lua

# Count functions
grep -c "^function" /tmp/compare1.lua
grep -c "^function" /tmp/compare1.pretty.js
```

**Document differences in XPLAN_FINDINGS.md**

### Task 4.2: Compare simple closure - [ ]

**Actions**:
```bash
echo 'let f x = fun () -> x in let g = f 42 in print_int (g())' > /tmp/compare2.ml
just compare-outputs /tmp/compare2.ml

just compile-js-pretty /tmp/compare2.ml.bc /tmp/compare2.pretty.js
_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/compare2.ml.bc -o /tmp/compare2.lua
```

**Compare**:
1. How is the closure created? (JS vs Lua)
2. How is variable `x` captured? (JS vs Lua)
3. How is `g` called? (JS vs Lua)
4. Any structural differences?

**Document in XPLAN_FINDINGS.md**

### Task 4.3: Compare nested closure - [ ]

**Actions**:
```bash
echo 'let f x = fun () -> (fun () -> x)() in let g = f 42 in print_int (g())' > /tmp/compare3.ml
just compare-outputs /tmp/compare3.ml

just compile-js-pretty /tmp/compare3.ml.bc /tmp/compare3.pretty.js
_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/compare3.ml.bc -o /tmp/compare3.lua
```

**Compare**:
1. How are nested closures handled?
2. How is `x` passed through multiple levels?
3. Are variables initialized correctly at each level?

**Document in XPLAN_FINDINGS.md**

### Task 4.4: Compare Printf simple string - [ ]

**Actions**:
```bash
echo 'let () = Printf.printf "Hello\n"' > /tmp/compare4.ml

# JS version (should work)
just compile-js-pretty /tmp/compare4.ml.bc /tmp/compare4.pretty.js
node /tmp/compare4.pretty.js

# Lua version (currently fails)
_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/compare4.ml.bc -o /tmp/compare4.lua 2>&1 | tee /tmp/compare4_compile.log
lua /tmp/compare4.lua 2>&1 | tee /tmp/compare4_run.log
```

**Compare**:
1. Size difference (lines, functions)
2. Printf closure structure (JS vs Lua)
3. Variable initialization order
4. Block entry points
5. Where does Lua fail? Why?

**Document in XPLAN_FINDINGS.md**

### Task 4.5: Compare Printf with format specifier - [ ]

**Actions**:
```bash
echo 'let () = Printf.printf "Value: %d\n" 42' > /tmp/compare5.ml

just compile-js-pretty /tmp/compare5.ml.bc /tmp/compare5.pretty.js
_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/compare5.ml.bc -o /tmp/compare5.lua
```

**Compare**: Same as 4.4 but with format specifier complexity

**Document in XPLAN_FINDINGS.md**

### Task 4.6: Document compilation differences - [ ]

**Actions**: Create XPLAN_COMPARISON.md

**Include**:
1. Side-by-side code structure comparison
2. Size metrics comparison
3. Closure handling comparison
4. Variable initialization comparison
5. Printf-specific comparison

### Task 4.7: Identify root causes - [ ]

**Actions**: Analyze all findings and identify THE root cause(s)

**Questions to answer**:
1. What is THE bug that makes Printf fail?
2. Is it missing primitives?
3. Is it variable initialization order?
4. Is it closure generation?
5. Is it block entry handling?
6. Is it Printf-specific code generation?

**Document in XPLAN_ROOT_CAUSES.md with priority order**

---

## Phase 5: Fix Implementation

**Goal**: Fix issues one by one, starting with highest priority

### Task 5.1: Fix highest priority issue - [ ]

**Actions**:
1. Based on Phase 4 findings, identify #1 issue
2. Study js_of_ocaml implementation for that component
3. Implement fix in lua_of_ocaml
4. Build and test

**Template**:
```bash
# Make changes to compiler/lib-lua/*.ml
dune build compiler/lib-lua

# Test immediately
just quick-test /tmp/xplan_test3_printf_simple.ml
```

**Document fix in XPLAN_FIXES.md**

### Task 5.2: Verify fix with minimal test - [ ]

**Actions**:
```bash
# Test all progressive tests
for i in 1 2 3 4; do
  echo "=== Test $i after fix ==="
  just quick-test /tmp/xplan_test${i}_*.ml 2>&1 | tee /tmp/xplan_test${i}_after_fix.log
done
```

**Document**: Did fix help? Any regressions?

### Task 5.3: Fix next priority issue - [ ]

**Actions**: Repeat 5.1-5.2 for next issue

### Task 5.4: Iterative fixing until Printf works - [ ]

**Actions**: Keep fixing issues until:
```bash
just quick-test /tmp/xplan_test3_printf_simple.ml
# Output: Hello
```

**Document each fix in XPLAN_FIXES.md**

### Task 5.5: Document all fixes - [ ]

**Actions**: Create comprehensive fix documentation

**Include**:
1. What was broken
2. Why it was broken
3. How js_of_ocaml does it
4. What we changed
5. Why the fix works
6. Any side effects or considerations

---

## Phase 6: Validation

**Goal**: Ensure Printf works completely and no regressions

### Task 6.1: Test Printf "Hello, World!\n" - [ ]

**Actions**:
```bash
echo 'let () = Printf.printf "Hello, World!\n"' > /tmp/validate1.ml
just quick-test /tmp/validate1.ml
# Expected output: Hello, World!
```

**Success Criteria**: Exact output match, no errors

### Task 6.2: Test Printf with format specifiers - [ ]

**Actions**:
```bash
echo 'let () = Printf.printf "Answer: %d\n" 42' > /tmp/validate2.ml
just quick-test /tmp/validate2.ml
# Expected output: Answer: 42

echo 'let () = Printf.printf "String: %s\n" "test"' > /tmp/validate3.ml
just quick-test /tmp/validate3.ml
# Expected output: String: test
```

**Success Criteria**: All format specifiers work

### Task 6.3: Test Printf with multiple arguments - [ ]

**Actions**:
```bash
echo 'let () = Printf.printf "%d + %d = %d\n" 2 3 5' > /tmp/validate4.ml
just quick-test /tmp/validate4.ml
# Expected output: 2 + 3 = 5
```

**Success Criteria**: Multiple arguments handled correctly

### Task 6.4: Test complex Printf patterns - [ ]

**Actions**:
```bash
# Test from examples/hello_lua
just quick-test examples/hello_lua/hello.ml

# Test nested Printf
echo 'let () = List.iter (Printf.printf "%d\n") [1; 2; 3]' > /tmp/validate5.ml
just quick-test /tmp/validate5.ml
```

**Success Criteria**: All complex patterns work

### Task 6.5: Run full test suite - [ ]

**Actions**:
```bash
just test-lua
```

**Success Criteria**: No new test failures (or fewer than before)

### Task 6.6: Verify no regressions - [ ]

**Actions**:
```bash
# Test all working cases still work
just test-runtime-all

# Test print_endline still works
echo 'let () = print_endline "test"' > /tmp/regression1.ml
just quick-test /tmp/regression1.ml

# Test closures still work
echo 'let f x = fun () -> x in let g = f 42 in print_int (g())' > /tmp/regression2.ml
just quick-test /tmp/regression2.ml
```

**Success Criteria**: All previously working code still works

---

## Phase 7: Documentation

**Goal**: Document everything for future reference

### Task 7.1: Document root causes found - [ ]

**Actions**: Finalize XPLAN_ROOT_CAUSES.md with:
1. Complete list of bugs found
2. Why each bug existed
3. How each bug manifested

### Task 7.2: Document fixes implemented - [ ]

**Actions**: Finalize XPLAN_FIXES.md with:
1. Complete list of changes made
2. File-by-file change log
3. Before/after comparisons

### Task 7.3: Update CLAUDE.md if needed - [ ]

**Actions**: If any new patterns or guidelines discovered, add to CLAUDE.md

### Task 7.4: Update LUA.md checklist - [ ]

**Actions**: Mark Printf tasks as complete in LUA.md

### Task 7.5: Commit and push - [ ]

**Actions**:
```bash
git add .
git commit -m "feat(lua): Fix Printf - closure variable initialization and block entry handling

- Fixed closure variable initialization order
- Fixed block entry parameter passing
- Fixed Printf format string compilation
- All tests passing
- Printf.printf 'Hello, World!' now works

Closes: lua_of_ocaml Printf support
See: XPLAN.md for complete analysis and fix documentation"

git push origin lua
```

---

## Key Principles

1. **Study First, Fix Second**: Understand js_of_ocaml thoroughly before making changes
2. **Systematic Comparison**: Compare Lua and JS output at every level
3. **Document Everything**: Every finding, every attempt, every fix
4. **Use Justfile**: All commands through `just` for consistency
5. **Add Missing Commands**: If a useful command doesn't exist, add it to justfile
6. **Test Incrementally**: Test after every change
7. **No Assumptions**: Verify everything, assume nothing
8. **Follow js_of_ocaml**: When in doubt, do what js_of_ocaml does

---

## Success Criteria

**Phase 1**: Complete baseline documentation
**Phase 2**: Complete js_of_ocaml understanding documented
**Phase 3**: All lua_of_ocaml components verified
**Phase 4**: All comparisons documented, root causes identified
**Phase 5**: Printf works without errors
**Phase 6**: All tests pass, no regressions
**Phase 7**: Complete documentation, committed and pushed

**Final Success**:
```bash
echo 'let () = Printf.printf "Hello, World!\n"' | ocaml
# Output: Hello, World!

echo 'let () = Printf.printf "Hello, World!\n"' > /tmp/final_test.ml
just quick-test /tmp/final_test.ml
# Output: Hello, World!
```

---

## Notes

- This plan is iterative and adaptive
- Each phase may reveal new tasks - add them as Phase X Task X.Y
- Document all findings in XPLAN_*.md files
- Update this checklist as tasks are completed (- [ ] → - [x])
- If a task is blocked, document why and skip to next task
- If a new issue is found, add it to the appropriate phase

---

## Justfile Commands Reference

Essential commands for this plan:

```bash
# Building
just clean                    # Clean build artifacts
just build-lua-all           # Build all lua_of_ocaml components
just build-strict            # Build with warnings as errors

# Testing
just test-runtime-all        # Test all runtime modules
just test-lua                # Run lua_of_ocaml tests
just quick-test <file.ml>    # Compile and run OCaml file
just compare-outputs <file>  # Compare Lua vs JS output

# Compilation
just compile-lua-debug <bc>  # Compile with debug info
just compile-js-pretty <bc> <out>  # Compile to JS with --pretty

# Analysis
just analyze-printf <file>   # Full Printf analysis
just inspect-bytecode <bc>   # Inspect bytecode structure

# Verification
just verify-all              # Verify environment
just verify-runtime <file>   # Verify runtime file structure
```

Add more commands as needed during the plan execution.
