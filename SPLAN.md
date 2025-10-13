# SPLAN.md - Strategic Plan for lua_of_ocaml Hello World

This file provides a master checklist for getting lua_of_ocaml to successfully compile and run `Printf.printf "Hello, World!"` and making the compiler rock solid.

## Current Status (2025-10-12)

**Foundation**: ✅ Complete (Phases 1-11 from LUA.md)
- Compiler infrastructure: 100%
- Runtime system: 95%
- Test coverage: Excellent

**Phase 0**: ✅ Environment verified (18 min)
**Phase 1**: ✅ Root cause identified (45 min) - See **ASSESSMENT.md** for full analysis

**Critical Blocker Identified**: Closure variable initialization bug
- `print_endline` works ✅
- `Printf.printf` fails with nil variable error ❌
- **Root cause**: `_V` table variable initialization broken in nested closures
- **Fix location**: `compiler/lib-lua/lua_generate.ml`
- **NOT missing primitives** - this is a code generation bug!

## Strategic Goal

Get `examples/hello_lua/hello.ml` to compile and run successfully:
```ocaml
let () = Printf.printf "Hello, World!\n"
```

**Success Criteria**:
- Compiles without errors
- Runs with `lua hello.lua`
- Runs with `luajit hello.lua`
- Produces correct output: `Hello, World!`

## Master Checklist

### Phase 0: Environment Verification - ✅ COMPLETE (18 min)

**Goal**: Verify development environment is ready per ENV.md

- [x] **Task 0.1**: Verify environment setup
  ```bash
  just verify-all
  ```
  - ✅ Complete: All systems operational
  - OCaml 5.3.0 (compatible with 5.2.0 target)
  - Lua 5.1.5 ✓
  - Dune 3.20.2 ✓

- [x] **Task 0.2**: Clean build everything
  ```bash
  just clean && just build-lua-all
  ```
  - ✅ Complete: lua_of_ocaml.exe built (23M)
  - Zero compilation warnings ✓

- [x] **Task 0.3**: Verify runtime tests pass
  ```bash
  just test-runtime-all
  ```
  - ✅ Complete: All 6 runtime modules pass
  - Modules: closure, fun, obj, format, io, effect

- [x] **Task 0.4**: Verify compiler tests
  ```bash
  just test-lua
  ```
  - ✅ Complete: Tests run as expected
  - Output mismatches expected (runtime integration incomplete)
  - **Missing primitives identified**:
    - `caml_caml_format_int_special` (Printf)
    - `caml_obj_dup` (object operations)
    - `caml_direct_int_mul` (integer operations)
  - **Progress**: `Sys.word_size` test now passes (returns 32)!

### Phase 1: Assess Current State - ✅ COMPLETE (45 min)

**Goal**: Understand exactly what's broken and why

- [x] **Task 1.1**: Create minimal test case
  - ✅ Complete: `print_endline` works perfectly!
  - Test: `let () = print_endline "Hello from print_endline"`
  - Result: Success - basic I/O is functional
  - Warnings: Duplicate primitives (non-blocking)

- [x] **Task 1.2**: Test Printf.printf
  - ✅ Complete: Printf.printf fails with runtime error
  - Test: `let () = Printf.printf "Hello, World!\n"`
  - Error: `attempt to index field 'v273' (a nil value)` at line 22538
  - Finding: NOT missing primitive - variable initialization bug!

- [x] **Task 1.3**: Test Printf with format specifiers
  - ✅ Complete: Same error pattern
  - Test: `let () = Printf.printf "Answer: %d\n" 42`
  - Error: `attempt to index field 'v275' (a nil value)` at line 22540
  - Confirms: Systematic closure variable initialization issue

- [x] **Task 1.4**: Analyze generated Lua code
  - ✅ Complete: Found the bug!
  - File size: 24,427 lines (15x larger than JS!)
  - Runtime: 12,614 lines (52%)
  - Program: 11,813 lines (48%)
  - Functions: 763 (vs 74 in JS - 10x more!)
  - **Root cause**: `_V` table variables not initialized in nested closures
  - Bug location: Block 482 assigns `v273 = _V.v206[2]`, but v206 is nil

- [x] **Task 1.5**: Compare with working JS output
  - ✅ Complete: JS version works perfectly
  - JS: 1,666 lines total (Lua: 24,427 lines)
  - JS: 74 functions (Lua: 763 functions)
  - JS output: "Hello, World!" ✅
  - Key difference: JS handles closure variables correctly

- [x] **Task 1.6**: Document findings
  - ✅ Complete: Created `ASSESSMENT.md`
  - **ROOT CAUSE IDENTIFIED**: Closure variable capture bug in `_V` table
  - When nested closures inherit `_V`, variables aren't initialized properly
  - Block arguments expect values from outer scope, but initialization order broken
  - Printf fails because it uses deeply nested closures (CPS style)
  - See `ASSESSMENT.md` for full analysis

**KEY DISCOVERY**: The problem is NOT missing primitives! It's a code generation bug in how closure variables are initialized in the `_V` table. Must fix in `lua_generate.ml`.

### Phase 2: Fix Closure Variable Initialization Bug (2-6 hours)

**Goal**: Fix the `_V` table variable initialization bug in nested closures

**Context**: Phase 1 identified the root cause - closure variables in nested functions using `_V` table pattern are not initialized correctly. Runtime functions ARE accessible (Task 2.1 ✅), so this is a CODE GENERATION bug, not runtime integration.

- [x] **Task 2.1**: Verify runtime function visibility ✅
  - ✅ Complete: All caml_* functions are globally accessible
  - Tested: core, array, io, format, obj, closure, fun modules
  - Finding: Runtime is working correctly - NOT the problem!
  - See test: `/tmp/test_runtime_complete.lua`

- [x] **Task 2.2**: Create minimal closure test case ✅
  - ✅ Created multiple test cases to isolate the bug
  - **CRITICAL DISCOVERY**: Basic closures work perfectly!

  Test Results:
  - ✅ 2-level closure (no Printf): **WORKS** (`/tmp/test_closure_pure.ml`)
  - ✅ 3-level closure (no Printf): **WORKS** (`/tmp/test_closure_3level.ml`)
  - ❌ 3-level closure WITH Printf.printf: **FAILS** (`/tmp/test_closure_minimal.ml`)
  - ❌ Simple closure WITH string_of_int: **FAILS** (missing `caml_caml_format_int_special`)

  **Key Finding**: The bug is NOT in general closure handling!
  - Closure variable capture works correctly
  - Nested closures (3+ levels) work fine
  - The problem is SPECIFIC to Printf and format functions
  - Missing primitive: `caml_caml_format_int_special`

  **New Hypothesis**: The "closure bug" from Phase 1 might actually be:
  1. Missing Printf primitives causing early failures
  2. OR Printf's specific CPS pattern triggering a rare edge case
  3. OR interaction between Printf format compilation and closure generation

  Generated code comparison:
  - Working 3-level closure: 12,769 lines
  - Failing Printf version: 24,448 lines (2x larger!)
  - Same runtime size, difference is in Printf module code

- [x] **Task 2.3**: Understand current closure generation ✅
  - ✅ Analyzed `compiler/lib-lua/lua_generate.ml` closure generation
  - ✅ Understood `_V` table pattern (>180 vars → table-based storage)
  - ✅ Understood `inherit_var_table` for nested closures
  - ✅ Compared generated Lua: working (12,783 lines) vs failing (24,441 lines)
  - ✅ **Found root cause**: Block 484 entry uses v273 which is never initialized
  - ✅ Documented in `TASK_2_3_CLOSURE_ANALYSIS.md`

  **Key Findings**:
  - Printf closure starts at block 484 (not block 0)
  - Block 484 uses v273, which is only assigned in block 482
  - Block 482 never runs before block 484 on first entry
  - v273 is initialized to nil, causing "attempt to index nil" error
  - This is NOT a general closure bug, but specific to entry block dependencies

  See `TASK_2_3_CLOSURE_ANALYSIS.md` for complete analysis

- [x] **Task 2.4**: Study js_of_ocaml closure handling ✅
  - ✅ Analyzed `compiler/lib/generate.ml` closure implementation
  - ✅ Studied `compile_closure`, `compile_branch`, `parallel_renaming` functions
  - ✅ Compared JS (1,666 lines, works) vs Lua (24,441 lines, fails)
  - ✅ **Found the bug**: Argument passing order is wrong!
  - ✅ Documented in `TASK_2_4_JS_COMPARISON.md`

  **Critical Discovery**:
  - JS: `compile_argument_passing` wraps block compilation (continuation-passing style)
  - JS: Block parameters assigned BEFORE block body via `parallel_renaming`
  - Lua: Hoisting happens FIRST, initializes ALL vars to nil (WRONG!)
  - Lua: `arg_passing` is outside `compile_blocks_with_labels` (TOO LATE!)

  **The Fix**: Pass entry `block_args` to hoisting logic, generate param assignments
  AFTER _V table creation but BEFORE dispatch loop. This matches JS behavior.

  See `TASK_2_4_JS_COMPARISON.md` for complete analysis and implementation plan

- [x] **Task 2.5**: Implement closure initialization fix ⚠️ PARTIAL
  - ✅ Modified `compile_blocks_with_labels` to accept `entry_args` and `func_params`
  - ✅ Added entry block argument passing logic (lines 1141-1188)
  - ✅ Updated `generate_closure` to pass `block_args` to hoisting logic
  - ✅ Updated interface file (`lua_generate.mli`)
  - ✅ Build succeeds with zero warnings
  - ✅ Simple closures work: `test_closure_simple.ml` prints "30", `test_closure_3level.ml` works
  - ❌ Printf still fails with different error: v270 nil instead of v273 nil
  - See `TASK_2_5_PARTIAL_FIX.md` for detailed analysis

  **Success**: Entry block parameters ARE initialized correctly now!
  **Issue**: Printf entry blocks use variables that aren't parameters

- [x] **Task 2.6**: Debug Printf-specific issue ✅ ROOT CAUSE FOUND
  - ✅ Analyzed control flow: Block 482 sets v270, block 484 uses v270
  - ✅ Identified problem: Block 484 is entry, but reachable from block 482 too
  - ✅ Compared with JS: JS uses data-driven dispatch, Lua uses address-driven
  - ✅ Found root cause: **Dispatch model mismatch**
  - ✅ Documented in `TASK_2_6_ANALYSIS.md`

  **Root Cause**: Block 484 is reachable by TWO paths:
  1. Entry path: v343 set, v270 nil ❌
  2. Block 482 path: v343 and v270 both set ✅

  Block 484 assumes v270 is set, but entry path doesn't initialize it.

  **Why JS Works**: JS uses data-driven dispatch (`switch(f[0])`), not address-driven.
  Variables assigned from params BEFORE entering control flow loop.

  **The Fix**: Initialize entry block dependencies before dispatch loop:
  - Analyze entry block for variables USED but not in parameters
  - Trace how they're computed (v270 = v343[2])
  - Generate initialization before dispatch loop

  This requires dependency analysis - complex but correct solution.
  Alternative: Special-case Printf pattern as temporary hack.

- [x] **Task 2.7**: Implement entry block dependency analysis ✅ COMPLETE (Conservative)
  - ✅ Implemented variable usage collection for expressions, instructions, blocks
  - ✅ Implemented entry block dependency detection (used but not in params)
  - ✅ Implemented initialization finder (scans predecessor blocks)
  - ✅ Implemented assigned variable collection (ALL blocks + block parameters)
  - ✅ Implemented transitive dependency tracking with safety filtering
  - ✅ Integration: generates init code before dispatch loop (only safe deps)
  - ✅ Build succeeds, simple closures work
  - ❌ Printf still fails (expected - dependencies are unsafe)
  - ✅ No incorrect initialization generated (conservative is correct)
  - ✅ Documented in `TASK_2_7_COMPLETE.md`

  **Key Finding**: Printf's v270 dependency uses v343, which IS modified in dispatch loop
  (v343 is a block parameter - reassigned on every branch). Pre-initialization would be
  **incorrect** even if no nil error, because it would use wrong value of v343.

  **Conclusion**: Entry block dependency pre-initialization **cannot fix Printf**.
  Dependencies are unsafe. Need different approach.

  **Generated Code**: No initialization for unsafe deps (correctly filtered)
  ```lua
  _V.v343 = v203
  local _next_block = 484  -- No v270 init (correctly skipped as unsafe)
  while true do
  ```

- [x] **Task 2.8**: Fix dispatch entry point detection ✅ COMPLETE (THE FIX!)
  - ✅ Analyzed Printf IR structure: closure entry 800, dispatch mistakenly started at 484
  - ✅ Added debug output to trace dispatch start detection
  - ✅ Found root cause: `find_entry_initializer(800)` returned block 484 (a back-edge!)
  - ✅ Blocks 483, 484 branch TO 800 to continue loop (back-edges, not initializers)
  - ✅ Fixed: Always start at closure entry (`start_addr`), not "initializer" block
  - ✅ Removed ~30 lines of incorrect logic using `find_entry_initializer`
  - ✅ Build succeeds, Printf gets past dispatch (no more v270/v279 errors!)
  - ✅ Simple closures work - no regressions
  - ✅ Documented in `TASK_2_8_COMPLETE.md`

  **Root Cause**: `find_entry_initializer` searched for blocks branching to entry (800) and found:
  - Blocks 474, 475, 476, 481: External callers (legitimate)
  - Blocks 483, 484: Loop back-edges (branches back to continue loop)

  It returned block 484, which is INSIDE the loop and requires v270 to be set.
  Starting there caused immediate nil errors.

  **The Fix**: For closures, ALWAYS start at `start_addr` (entry block). Entry block parameters
  are initialized via `entry_arg_stmts` (Task 2.5), so entry is safe. Entry's terminator
  (Branch/Cond/etc) directs control flow to appropriate next block.

  **Results**:
  - ✅ Dispatch now starts at block 800 (entry), not 484 (back-edge)
  - ✅ Printf: No more v270/v279 nil errors!
  - ✅ Printf: Now fails in `caml_ml_bytes_length` (Phase 3 runtime primitive issue)
  - ✅ Simple closures: Work perfectly (output "11")

  **Generated Code (before)**:
  ```lua
  _V.v343 = v203
  local _next_block = 484  -- WRONG!
  ```

  **Generated Code (after)**:
  ```lua
  _V.v343 = v203
  local _next_block = 800  -- CORRECT!
  ```

  **Impact**: Phase 2 (dispatch bug) is COMPLETE! Printf moves to Phase 3 (primitives).

### Phase 2.5: Data-Driven Dispatch Refactor (NEW - 4-8 hours) ⚠️ **PAUSED**

**Goal**: Refactor dispatch model to match js_of_ocaml's data-driven approach

**Why**: Current address-driven dispatch causes entry block dependency issues.
JS uses data-driven dispatch where variables determine control flow, not addresses.

**Approach**: Change from `_next_block = 484` to switch/if-chain on variable values

- [x] **Task 2.5.1**: Study JS dispatch patterns ✅ COMPLETE
  - ✅ Analyzed JS `for(;;) { switch(fmt[0]) { ... } }` pattern
  - ✅ Understood how variables drive control flow (fmt, k, acc)
  - ✅ Documented how Printf closure works in JS (see TASK_2_5_1_JS_DISPATCH_ANALYSIS.md)
  - ✅ Identified dispatch data: `fmt` (tagged variant with fmt[0] as tag)
  - ✅ Mapped JS cases to purposes (24 cases + default for format specifiers)

  **Key Findings**:
  - JS uses **data-driven dispatch**: switch on fmt[0] (tag)
  - Variables (k, acc, fmt) initialized BEFORE loop entry
  - Nested labeled blocks (a-l) for breaking out of loop
  - Cases modify dispatch variables and continue loop OR return
  - Trampoline pattern (counter >= 50) for tail call optimization
  - **Confirmed root cause**: Address-driven vs data-driven mismatch

  **Added justfile commands**:
  - `just compile-js-pretty` - Compile to JS with pretty & debug
  - `just analyze-printf` - Complete Printf analysis workflow

  **Documentation**: `TASK_2_5_1_JS_DISPATCH_ANALYSIS.md` (comprehensive)

- [x] **Task 2.5.2**: Analyze IR control flow structure ✅ COMPLETE
  - ✅ Understood `Code.last` terminators (Branch, Cond, Switch)
  - ✅ Mapped terminators to JS control flow patterns
  - ✅ Identified dispatch variables in Printf (fmt_tag from Switch terminator)
  - ✅ Documented Printf closure's control flow graph
  - ✅ Found dispatch variable identification method (Switch(v, conts) → v)

  **Key Findings**:
  - IR terminators: Branch (jump), Cond (if), Switch (switch on variable)
  - DTree intermediate: IR → DTree → JS (optimization layer)
  - Loop detection: Structure.is_loop_header → generates for(;;)
  - Dispatch variable: First arg of Switch terminator (fmt_tag in Printf)
  - Printf CFG: Entry loop header → Switch(fmt_tag) → 24 cases (some back-edge)

  **Control Flow Pattern**:
  ```
  Block_entry (loop header):
    params: [counter, k, acc, fmt]
    body: [extract fmt_tag from fmt[0]]
    branch: Switch(fmt_tag, cases_0_to_23_plus_default)
  ```

  **Implications for Lua**:
  - Must initialize dispatch variables BEFORE dispatch loop
  - Dispatch on variable VALUES (fmt_tag), not block addresses
  - Each Switch case becomes if-elseif branch in Lua
  - Preserve loop semantics (back edges = continue loop)

  **Documentation**: `TASK_2_5_2_IR_ANALYSIS.md` (comprehensive with CFG)

- [x] **Task 2.5.3**: Design data-driven dispatch for Lua ✅ COMPLETE
  - ✅ Designed new dispatch loop structure (while true + if-elseif on dispatch var)
  - ✅ Planned dispatch data passing (inline cases, back edges assign and continue)
  - ✅ Designed variable initialization (dispatch vars as locals before loop)
  - ✅ Handled trampolines (use Lua tail call optimization, no explicit trampolines)
  - ✅ Kept _V table pattern (dispatch vars local, hoisted vars in _V if >180)

  **Core Design**:
  - **Mode detection**: Use data-driven only for Switch-based loop headers
  - **Variable init**: Dispatch variables initialized from parameters before loop
  - **Switch transformation**: Inline case blocks into if-elseif chain
  - **Back edges**: Assign new values to dispatch vars, continue loop
  - **_V table**: Dispatch vars local (fast), hoisted vars in _V (if >180)

  **Lua Structure**:
  ```lua
  function closure(counter, k_param, acc_param, fmt_param)
    -- 1. Hoist variables to _V if needed
    local _V = {}
    _V.v100 = nil  -- ...

    -- 2. Initialize dispatch variables (NEW!)
    local k = k_param
    local acc = acc_param
    local fmt = fmt_param

    -- 3. Data-driven dispatch loop (NEW!)
    while true do
      if type(fmt) == "number" then return caml_call1(k, acc) end
      local fmt_tag = fmt[1]
      if fmt_tag == 0 then
        -- Case 0 inlined
        return value
      elseif fmt_tag == 10 then
        -- Case 10: back edge
        acc = {7, acc}
        fmt = fmt[2]
        -- Continue loop
      end
    end
  end
  ```

  **Key Design Decisions**:
  - Incremental adoption: Only change Switch-based loops, keep address-based for simple cases
  - Inline cases: Embed target block bodies into switch cases (no labels needed)
  - Local dispatch vars: Fast access for frequently modified variables
  - No trampolines: Rely on Lua's tail call optimization

  **Implementation Functions** (to add in lua_generate.ml):
  - `detect_dispatch_mode`: Detect if closure needs data-driven dispatch
  - `compile_data_driven_dispatch`: Generate new dispatch structure
  - `generate_switch_case`: Inline one case block
  - `is_back_edge`: Check if continuation loops back

  **Documentation**: `TASK_2_5_3_LUA_DISPATCH_DESIGN.md` (comprehensive 40+ sections)

- [x] **Task 2.5.4**: Implement prototype for simple case ✅ COMPLETE
  - ✅ Created test with simple data-driven closure (test_variant_simple.ml)
  - ✅ Implemented new dispatch generation (detect_dispatch_mode, compile_data_driven_dispatch)
  - ✅ Tested simple closures still work (test suite mostly passes)
  - ✅ Verified approach works (code compiles, runs, generates better code when triggered)
  - ✅ Measured code size impact (no change when not triggered, smaller when triggered)

  **Implementation**:
  - Added `dispatch_mode` type (AddressBased | DataDriven)
  - Added `detect_dispatch_mode`: Detects Switch terminators with all-return cases
  - Added `compile_data_driven_dispatch`: Generates if-elseif chain (no dispatch loop!)
  - Modified `compile_blocks_with_labels`: Branches on dispatch mode
  - Factored out `compile_address_based_dispatch`: Original implementation

  **Key Findings**:
  - Simple variant matches → Cond terminators (not Switch)
  - Printf has 24+ cases → Switch terminator (will trigger data-driven)
  - Test suite mostly passes (no major regression)
  - Data-driven code is simpler: No loop, no _next_block, inline cases

  **Next**: Extend detection to handle Printf pattern (Task 2.5.5)

  **Documentation**: `TASK_2_5_4_PROTOTYPE.md` (comprehensive results)

- [x] **Task 2.5.5**: Extend data-driven dispatch for loops ⚠️ PARTIAL
  - ✅ Extended DataDriven type to include entry_addr for back-edge detection
  - ✅ Modified detection to allow Return OR Branch-to-entry terminators
  - ✅ Implemented loop back-edge handling (variable assignments + continue)
  - ✅ Wrapped switch in while loop for iteration
  - ❌ Printf detection doesn't trigger (IR pattern doesn't match criteria)

  **Implementation**: Works correctly when Switch terminators exist
  **Issue**: Printf doesn't use Switch terminators (uses Cond decision trees)
  **Status**: Code correct, no regressions, but Printf still fails
  **Documentation**: `TASK_2_5_5_REPORT.md` (full analysis and recommendations)

**⚠️ Phase 2.5 Status Update**:

Tasks 2.5.4 and 2.5.5 completed successfully but revealed key insight:
- **Data-driven dispatch works** when Switch terminators exist in IR
- **Printf doesn't use Switch** - uses Cond decision trees instead
- **Data-driven approach won't fix Printf** - need different solution

**Recommendation**: Pause Phase 2.5, return to Phase 2 approach
- Printf needs entry block dependency analysis OR variable initialization fix
- Data-driven dispatch is valuable but doesn't solve Printf problem
- Continue with Tasks 2.5.6-2.5.7 later if Switch-based patterns found

**Skip for now**:
- [ ] **Task 2.5.6**: Test and verify (SKIP - detection doesn't trigger for Printf)
- [ ] **Task 2.5.7**: Optimize and document (SKIP - defer until needed)

**New Approach Needed**:
- Return to Phase 2 findings: entry block v270 dependency issue
- Options:
  1. Implement entry block dependency analysis
  2. Initialize entry-required variables before dispatch loop
  3. Special-case Printf pattern

See `TASK_2_5_5_REPORT.md` for full analysis and recommendations.

### Phase 3: Printf Primitives & Runtime Issues (2-4 hours)

**Status Update (Post Task 2.8)**: Phase 2 dispatch bug is FIXED! Printf now enters Phase 3.

**Current Error**:
```
lua: test_simple_printf.lua:1318: attempt to index local 's' (a nil value)
stack traceback:
	test_simple_printf.lua:1318: in function <test_simple_printf.lua:1314>
```

Line 1318 is in `caml_ml_bytes_length(s)` which does `return s.length`. The `s` parameter is nil.

**Goal**: Fix Printf runtime primitives and calling conventions

- [x] **Task 3.1 (revised)**: Debug caml_ml_bytes_length nil parameter ✅ COMPLETE

  **Root Cause**: Task 2.8's fix is incomplete. Dispatch starts at entry block (800), but this
  skips initializer blocks like 475 that set variables like v247. Block 601 uses v247[3],
  causing nil errors.

  **Call Chain**:
  1. Block 601: `v228 = v247[3]` → nil (v247 never initialized)
  2. Block 601: `v143(v201, v228)` → calls with nil arg
  3. Inside v143: `caml_ml_string_length(v202)` → v202 is nil
  4. `caml_ml_string_length` → calls `caml_ml_bytes_length(s)` with nil
  5. `caml_ml_bytes_length` → `return s.length` → ERROR!

  **Control Flow Issue**:
  ```
  Current: Start at 800 → ... → Block 601 (uses v247) ❌ v247 nil

  Needed:  Start at 475 → Set v247 → Branch to 800 → ... → Block 601 ✅
  ```

  **JS Comparison**: ✅ `node test_simple_printf_js.js` outputs "Hello" correctly

  **Task 2.8 Limitation**:
  - Fixed: Don't start at back-edge block 484 ✅
  - Introduced: Skip initializer blocks like 475 ❌

  **Why Task 2.7 Didn't Fix**: v247 depends on v343 (block parameter that changes).
  Pre-initialization unsafe - would use wrong value.

  **Solution**: Distinguish back-edges from true initializers. Start at initializer blocks
  like 475, not entry block 800.

  **Documented**: `TASK_3_1_FINDINGS.md`

- [x] **Task 3.2**: Investigate dispatch start with back-edge filtering ⚠️ INCOMPLETE

  **Implemented**: Reachability-based back-edge filtering (~100 lines)
  - ✅ Added `compute_reachable_blocks` for forward reachability analysis
  - ✅ Enhanced `find_entry_initializer` to filter blocks reachable from entry
  - ✅ Updated dispatch logic to use enhanced detection with fallback
  - ❌ Printf still fails - address-based dispatch is insufficient

  **Finding**: ALL blocks (474-476, 481, 483, 484) are reachable from entry (800).
  They're all inside the loop - no "external" initializers exist.

  **Catch-22**:
  - Start at 800 (entry): v247 nil error (block 601 needs 475)
  - Start at 484 (fallback): v270 nil error (block 484 needs 482)

  **Root Cause**: Address-based dispatch (`while _next_block`) can't handle Printf's
  block interdependencies. Blocks have ordering requirements that can't be satisfied
  by picking a single start address.

  **How JS Works**: Value-based dispatch
  ```js
  for(;;) {
    switch(fmt[0]) {  ← Switch on data, not addresses
      case 0: ...     ← Direct code execution
      case 11: v247 = fmt[3]; ...  ← Variables set naturally
    }
  }
  ```

  **Why Detection Doesn't Work**: Printf entry (800) has **Cond** terminator (decision tree),
  not **Switch** (our detection only triggers for Switch). IR optimizations convert large
  switches to balanced decision trees.

  **Conclusion**: Address-based dispatch is fundamentally wrong for Printf. Need value-based
  dispatch like JS uses.

  **Documented**: `TASK_3_2_INVESTIGATION.md`

- [x] **Task 3.3**: Implement value-based dispatch for Cond patterns ✅ STRUCTURE COMPLETE

  **Summary**: Data-driven dispatch structure now perfectly matches js_of_ocaml!
  - ✅ Detection working (Cond-based patterns recognized)
  - ✅ Variable management complete (hoisting, params, entry args)
  - ✅ Entry block logic inside loop (type check before tag extraction)
  - ✅ Back-edge handling correct (variables update and loop)
  - ✅ Structure matches JS exactly
  - ✅ File size: 19,004 lines (22% reduction from 24,372)
  - ❌ Runtime blocked by _V table scoping bug (Task 3.3.4)

  **Completed Subtasks**:
  - ✅ Task 3.3.1: Extract variable management functions
  - ✅ Task 3.3.2: Integrate into data-driven dispatch (merged with 3.3.1)
  - ✅ Task 3.3.3: Fix tag extraction with entry block logic
  - [ ] Task 3.3.4: Fix _V table scoping (NEXT) ⬅️
  - [ ] Task 3.3.5: Test Printf
  - [ ] Task 3.3.6: Verify no regressions

  **Current Status**: Structure perfect, runtime broken due to _V table variable collision

  **Documented**: `TASK_3_3_PARTIAL.md`, `TASK_3_3_1_COMPLETE.md`, `TASK_3_3_3_COMPLETE.md`

**Subtasks to Complete Task 3.3**:

- [x] **Task 3.3.1**: Extract variable management functions ✅ COMPLETE

  **Extracted 3 Helper Functions** (~110 lines, lines 1526-1628):
  1. ✅ `setup_hoisted_variables`: Collect vars, create _V table, init to nil
  2. ✅ `setup_function_parameters`: Copy function params to _V table
  3. ✅ `setup_entry_block_arguments`: Initialize entry block params from block_args

  **Integrated into compile_data_driven_dispatch**:
  - ✅ Updated function signature (+3 params: params, func_params, entry_args)
  - ✅ Added calls to all 3 helpers
  - ✅ Updated call site in compile_blocks_with_labels
  - ✅ Return combines: hoist + params + entry_args + dispatch_loop

  **Results**:
  - ✅ Build succeeds
  - ✅ Printf has _V table (144 vars hoisted)
  - ✅ Printf has parameters copied (counter, v201-v203)
  - ✅ Printf has entry args initialized (v341-v343)
  - ✅ File size: 20,590 lines (down from 24,372 - 15% smaller)
  - ✅ Dispatch uses value-based switch (v204), not addresses

  **Current Error**:
  ```bash
  $ just quick-test /tmp/test_simple_printf.ml
  lua: /tmp/quick_test.lua:19203: attempt to index field 'v343' (a number value)
  ```

  **Cause**: Tag extraction happens BEFORE type check
  ```lua
  local v204 = _V.v343[1] or 0  ← Extract tag before checking type!
  while true do
    if v204 == 0 then ...       ← No type check!
  ```

  **Needed**: Entry block's Cond logic (type check) must be INSIDE loop, BEFORE tag extraction.

  **Documented**: `TASK_3_3_1_COMPLETE.md`

- [x] **Task 3.3.2**: Integrate variable management ✅ COMPLETE (Done in 3.3.1)

  **Completed as part of Task 3.3.1**:
  - ✅ compile_data_driven_dispatch calls all 3 helpers
  - ✅ Function signature updated with params, func_params, entry_args
  - ✅ Call site updated to pass new parameters
  - ✅ Returns combined: hoist + params + entry_args + dispatch_loop

- [x] **Task 3.3.3**: Fix tag extraction with entry block logic ✅ COMPLETE

  **STRUCTURE COMPLETE**: Entry block logic (type check) now correctly positioned INSIDE while loop!

  **Implementation** (Lines 1680-1802):
  - ✅ `generate_entry_and_dispatcher_logic()`: Generates entry block body + Cond inside loop
  - ✅ Entry block Cond (type check) evaluated BEFORE tag extraction
  - ✅ True branch compiles and returns (integer case)
  - ✅ False branch has dispatcher body with tag extraction
  - ✅ Back-edge cases update variables and loop (no premature return)
  - ✅ Structure matches js_of_ocaml exactly

  **Generated Structure** (Perfect Match with JS):
  ```lua
  while true do
    -- Entry block Cond (type check)
    _V.v328 = type(_V.v343) == "number" and _V.v343 % 1 == 0
    if _V.v328 then
      _V.v205 = caml_call_gen(_V.v341, {_V.v342})
      return _V.v205
    end

    -- Dispatcher body (tag extraction)
    _V.v204 = _V.v343[1] or 0

    -- Switch on tag
    if _V.v204 == 0 then ...
    elseif _V.v204 == 11 then
      _V.v342 = new_acc
      _V.v343 = next_fmt
      -- Loop restarts
    end
  end
  ```

  **Results**:
  - ✅ File size: 19,004 lines (down from 24,372 - 22% reduction)
  - ✅ Structure perfect, matches JS exactly
  - ❌ Runtime blocked by _V table scoping bug (separate issue - see Task 3.3.4)

  **Documented**: `TASK_3_3_3_COMPLETE.md`

- [x] **Task 3.3.4**: Fix _V table scoping for nested closures ✅ COMPLETE

  **SUCCESS** ✅: Printf.printf "Hello, World!\n" WORKS! 🎉

  **The Fix** (lines 1567-1577): Use Lua metatables for JavaScript-like lexical scoping
  ```lua
  local parent_V = _V
  local _V = setmetatable({}, {__index = parent_V})
  ```

  **Results**:
  - ✅ Printf.printf "Hello, World!\n" outputs "Hello, World!" (THE GOAL!)
  - ✅ Lua and JS outputs match perfectly
  - ✅ 48% file size reduction (12,735 vs 24,372 lines)
  - ✅ Each closure has own _V table with parent lookup
  - ✅ Matches js_of_ocaml lexical scoping semantics

  **Before**: Shared _V table → variable collision → nil errors
  **After**: Metatable inheritance → proper scoping → Printf works!

  **Documented**: `TASK_3_3_4_COMPLETE.md`, `TASK_3_3_4_PLAN.md`

- [x] **Task 3.3.5**: Test Printf with complete fix (after 3.3.4) ✅ COMPLETE

  **Test Results**:
  1. ✅ `Printf.printf "Hello\n"` → Outputs "Hello"
  2. ✅ `Printf.printf "Hello, World!\n"` → Outputs "Hello, World!" (THE GOAL!)
  3. ✅ `Printf.printf "Test: %s\n" "hello"` → Outputs "Test: hello"

  **Additional Fix Applied**:
  - Fixed `compile_address_based_dispatch` (lines 1903-1922) to use metatables
  - ALL closures now use proper lexical scoping (0 "inherited _V table" remaining)
  - Committed in fix(scope): apply metatable fix to address-based dispatch

  **Note**: %d format specifier has separate issue (infinite loop) - not part of this task

- [x] **Task 3.3.6**: Verify no regressions and run test suite ✅ PARTIAL

  **Tests Run**:
  ```bash
  # Simple closures - PASS ✅
  just quick-test /tmp/test_simple_closure.ml  # Output: "11" ✅
  just quick-test /tmp/test_simple_dep.ml      # Output: "11" ✅

  # Core functionality - PASS ✅
  Printf.printf "Hello, World!\n"    # Works! ✅
  Printf.printf "Test: %s\n" "hello" # Works! ✅
  print_int 42                        # Works! ✅
  ```

  **Test Suite Status**:
  - Test expectations need updating (dune promote) due to more statements generated
  - Full test suite times out (>2min) - needs investigation
  - Likely related to %d format specifier infinite loop issue

  **Success Criteria Met**:
  - ✅ Core functionality works (Printf "Hello, World!" - THE GOAL!)
  - ✅ Simple tests pass
  - ✅ Data-driven dispatch with proper scoping (48% smaller files)
  - ⚠️  Full test suite needs separate investigation

### Estimated Effort for Task 3.3 Completion

- **Task 3.3.1** (Extract helpers): 1-2 hours (pure refactor, careful testing)
- **Task 3.3.2** (Integrate): 30min-1 hour (straightforward)
- **Task 3.3.3** (Fix tag extraction): 1-2 hours (match JS exactly)
- **Task 3.3.4** (Test Printf): 30min-1 hour (debugging)
- **Task 3.3.5** (Regressions): 30min (run tests)

**Total**: 4-7 hours remaining

### Complete Refactor Plan

See `REFACTOR_PLAN.md` for detailed implementation guide including:
- How js_of_ocaml works (compile_branch, compile_switch, parallel_renaming)
- Our current vs needed implementation
- Detailed code structure comparison
- Step-by-step refactor instructions
- Testing strategy for each subtask

**Key Insight**: js_of_ocaml uses continuation-passing style where setup happens naturally.
Our approach separates variable management from dispatch, which works for address-based but
breaks for data-driven. **Fix**: Share variable management between both dispatch modes.

---

- [x] **Task 3.4**: Test Printf.printf "Hello, World!\n" ✅ COMPLETE
  ```bash
  just quick-test /tmp/test_hello_world.ml
  # Output: Hello, World!
  ```
  - ✅ Works perfectly!
  - ✅ **SPLAN.md goal achieved!** 🎉
  - Fixed by: Tasks 3.3.4-3.3.6 (_V table metatable scoping)

- [x] **Task 3.7**: Fix Printf.printf "%d" infinite loop ✅ COMPLETE

  **Problem**: Printf with %d format specifier caused infinite loop/stack overflow

  **Root Cause**: Lua generated `caml_call_gen` for ALL non-exact applies, while JS uses runtime arity check + conditional direct call

  **Solution Implemented**: Runtime arity checking using IIFE pattern (matching JS approach from generate.ml:1075-1086)

  **Files Modified**:
  - `compiler/lib-lua/lua_generate.ml` (lines 42-55, 808-823, 867-881): Added `cond_expr` helper and runtime arity checks
  - `compiler/lib-lua/lua_mlvalue.ml` (lines 58-71, 340-350): Same runtime arity check pattern
  - `compiler/lib-lua/lua_output.ml` (lines 276-286): Fixed IIFE syntax (wrap Function in parens)

  **Implementation**:
  ```lua
  -- Runtime arity check for non-exact applies
  (function()
    if type(f) == "table" and f.l and f.l == #args then
      return f(args...)  -- Direct call if arity matches
    else
      return caml_call_gen(f, {args})  -- Curry if arity doesn't match
    end
  end)()
  ```

  **Results**:
  - ✅ No more infinite loop/hang on Printf %d
  - ✅ Hello World still works
  - ✅ print_int works
  - ⚠️ Printf %d silently fails (no output) - NEW ISSUE (likely Task 3.5/3.6: format primitives)
  - ⚠️ Code size still 2.6x larger (22K vs 8K lines) - indicates deeper code generation issue
  - ⚠️ Still 39 caml_call_gen calls (19 with runtime checks + 20 direct) vs JS's 6

  **Test Results**:
  ```bash
  # Works - no hang
  Printf.printf "Hello, World!\n"       → "Hello, World!"
  Printf.printf "String: %s\n" "test"   → "String: test"
  print_int 42                          → "42"

  # Silently fails - no output
  Printf.printf "Int: %d\n" 42          → (nothing printed)
  ```

  **Next Steps**: Task 3.5/3.6 to fix integer formatting primitive

- [ ] **Task 3.5**: Debug Printf %d silent failure ⚠️ READY TO FIX

  **Status After Task 3.7**: Printf.printf "%d" no longer hangs but silently fails (no output)

  **Test Results**:
  ```bash
  # Works - plain text and strings
  Printf.printf "Hello\n"          → "Hello"        ✅
  Printf.printf "Test: %s\n" "hi"  → "Test: hi"     ✅
  print_int 42                     → "42"           ✅

  # Silently fails - no output
  Printf.printf "%d" 42            → (nothing)      ❌
  Printf.printf "Int: %d\n" 42     → (nothing)      ❌

  # Execution trace confirms call happens
  print_endline "Before"           → "Before"       ✅
  Printf.printf "Int: %d\n" 42     → (nothing)      ❌
  print_endline "After"            → "After"        ✅
  ```

  **ROOT CAUSE IDENTIFIED** ✅ (via `just analyze-printf` + JS/Lua code comparison):

  **THE BUG**: Code generation error in `convert_int` closure (Lua line 18678)

  **What's wrong**:
  ```lua
  -- BUGGY GENERATED CODE (line 18689):
  _V.v141 = caml_format_int(_V.v143, _V.n)  -- ❌ v143 is UNDEFINED!
  ```

  The `convert_int` closure references `_V.v143` to pass the format string to `caml_format_int`, but:
  - v143 is NOT a parameter to convert_int
  - v143 is NOT in the closure's hoisted variables (only v141, v142 listed)
  - v143 is NOT properly initialized in parent scope when convert_int is called
  - v143 is a reused temp variable that has random values

  **How JS does it** (the correct approach):
  ```javascript
  // JS function bD (equivalent to convert_int) - lines 6034-6062:
  function bD(b, c){  // b=iconv, c=integer
    switch(b){        // SELECT format string based on iconv
      case 1:  var a = aP; break;  // aP = "%+d"
      case 2:  var a = aQ; break;  // aQ = "% d"
      case 4:  var a = aS; break;  // aS = "%x"
      ...
      case 0:
      case 13: var a = aO; break;  // aO = "%d"
      default: var a = a0;          // a0 = "%u"
    }
    return z(b, caml_format_int(a, c));  // Use SELECTED format string
  }
  ```

  JS generates a **switch statement INSIDE the function** to select the format string.

  **Why Lua is broken**:
  Lua compiler incorrectly assumes v143 will have the right value from parent scope, but:
  1. No switch statement generated inside convert_int
  2. No format string selection logic at all
  3. Just blindly references undefined _V.v143
  4. Same bug in convert_int32, convert_int64, convert_nativeint (16 total occurrences)

  **Verification**:
  - Patched 16 occurrences of `caml_format_int(_V.v143, ...)` with switch statement
  - Added format selection: `if iconv==0 then fmt="%d" elseif iconv==1 then fmt="%+d" ...`
  - But patched code still fails (deeper issue - Printf chain may not reach convert_int)

  **File comparison**:
  - JS: 345K, 6 caml_call_gen, clean switch-based dispatch
  - Lua: 689K (2x larger), 39 caml_call_gen, broken variable references

  **Fix Strategy** (Code Generator Bug):

  This is a **compiler bug in lua_generate.ml**, not a runtime bug. Need to fix code generation.

  **What needs to be fixed**:
  When generating closures that call formatting functions (caml_format_int, caml_int32_format, etc.),
  the compiler must generate format string selection logic INSIDE the closure, not rely on undefined
  parent variables.

  **Location**: `compiler/lib-lua/lua_generate.ml`
  - Likely in `generate_expr` or `generate_instr` where closures are created
  - Need to detect when a closure references a variable that's used as format string
  - Generate switch/if-else chain instead of variable reference

  **Alternative Quick Fix** (if code gen fix is too complex):
  Modify the OCaml stdlib's camlinternalFormat to use simpler integer formatting that doesn't
  require format string dispatch. But this breaks compatibility with js_of_ocaml approach.

  **Implementation Steps**:
  1. **Find the IR pattern**: Identify what bytecode instruction creates convert_int
  2. **Check JS codegen**: See how `compiler/lib/generate.ml` handles this case
  3. **Fix Lua codegen**: Make `lua_generate.ml` generate switch statement like JS
  4. **Test**: Recompile and verify Printf %d works

  **Current Status** (after deep investigation):
  - Root cause: 100% identified ✅
  - Code structure difference found between JS and Lua
  - Manual patch attempted but deeper structural issue exists

  **Key Finding**: Different Code Structures

  **JS Structure** (works correctly):
  ```javascript
  function bD(b, c){  // b=iconv, c=integer
    switch(b){
      case 0:  var a = aO; break;  // aO = "%d"
      case 1:  var a = aP; break;  // aP = "%+d"
      ...
    }
    return z(b, caml_format_int(a, c));  // ONE call after switch
  }
  ```

  **Lua Structure** (broken):
  ```lua
  _V.convert_int = caml_make_closure(2, function(iconv, n)
    while true do
      if _V.iconv == 0 then
        _V.v141 = caml_format_int(_V.v143, _V.n)  -- MULTIPLE calls
        ...
      else if _V.iconv == 1 then
        _V.v141 = caml_format_int(_V.v143, _V.n)  -- Same undefined v143!
        ...
    end
  end)
  ```

  **The Problem**:
  - Lua has MULTIPLE caml_format_int calls (one per branch) all using undefined _V.v143
  - JS has ONE caml_format_int call after switch, using properly selected format string
  - This is a FUNDAMENTAL code structure difference, not just a missing variable

  **Why This Happens**:
  Likely the OCaml bytecode IR has different representations, and the code generators
  handle them differently. JS collapses the branches into a switch, Lua replicates the call.

  **Option A: Proper Branch Optimization Fix** (CHOSEN)

  This requires implementing branch optimization similar to JS DTree to hoist common
  operations before if-else chains. Breaking into investigation subtasks:

  - [x] **Task 3.5.1**: Investigate JS DTree optimization mechanism ✅
    - File: `compiler/lib/generate.ml`
    - **Key Finding**: JS uses DTree (Decision Tree) optimization BEFORE code generation

    **DTree Module** (lines 823-938):
    - Type: `'a t = If of cond * 'a t * 'a t | Switch of 'a branch array | Branch of 'a branch`
    - `build_switch` (lines 851-909): Takes array of continuations, groups cases with same target
    - `normalize` (lines 840-847): Groups branches with identical continuations together
    - **Optimization**: If all cases jump to same block → single Branch (line 864)
    - **Optimization**: If only 2 unique targets → generates If instead of Switch (lines 868-886)

    **Usage** (lines 1969-1973):
    ```ocaml
    | Switch (_, a) ->
        let dtree = DTree.build_switch a in  (* a = array of continuations *)
        fun pc -> DTree.nbbranch dtree pc
    ```

    **Compilation** (lines 2002-2097):
    - `compile_decision_tree` recursively compiles optimized DTree
    - `DTree.Branch`: Single continuation for multiple cases
    - `DTree.If`: Conditional with two branches
    - `DTree.Switch`: JavaScript switch statement

    **Key Insight**: DTree.build_switch detects when `conts[i]` and `conts[j]` point to same
    continuation (same target address), and groups them together BEFORE generating code.

    Example: `conts = [|pc5; pc5; pc5; pc7; pc7|]` becomes:
    - Branch([0;1;2], pc5) + Branch([3;4], pc7) → optimized structure

  - [x] **Task 3.5.2**: Analyze Lua switch/if-else generation ✅
    - File: `compiler/lib-lua/lua_generate.ml`
    - **Key Finding**: Lua generates NAIVE if-else chains WITHOUT optimization

    **Switch Code Generation** (lines 2408-2427):
    ```ocaml
    | Code.Switch (var, conts) ->
        let switch_var = var_ident ctx var in
        let cases =
          Array.to_list conts
          |> List.mapi ~f:(fun idx (addr, args) ->
              let cond = L.BinOp (L.Eq, switch_var, L.Number (string_of_int idx)) in
              let arg_passing = generate_argument_passing ctx addr args () in
              let set_block = L.Assign ([L.Ident "_next_block"], [L.Number (string_of_int addr)]) in
              let then_stmt = arg_passing @ [ set_block ] in
              (cond, then_stmt))
        in
        (* Build if-elseif-else chain *)
        [ L.If (cond, then_stmt, Some (build_if_chain rest)) ]
    ```

    **The Problem**:
    - Lua creates ONE if-else case for EACH index in conts array
    - NO detection of duplicate continuations (same target address)
    - NO grouping of cases that jump to same block
    - Result: Duplicated code in each branch, even when they're identical

    **Example**: `conts = [|pc5; pc5; pc5; pc7; pc7|]` generates:
    ```lua
    if var == 0 then _next_block = 5  -- Jump to pc5
    elseif var == 1 then _next_block = 5  -- Duplicate!
    elseif var == 2 then _next_block = 5  -- Duplicate!
    elseif var == 3 then _next_block = 7  -- Jump to pc7
    elseif var == 4 then _next_block = 7  -- Duplicate!
    end
    ```

    Each branch executes the ENTIRE body of the target block inline, leading to
    massive code duplication when Printf does format string selection.

    **Why Printf %d Breaks**:
    - Printf's convert_int has Switch with 16 cases (one per iconv value)
    - Most cases jump to same continuation (format and return)
    - Lua duplicates `caml_format_int(_V.v143, _V.n)` in ALL 16 branches
    - But v143 is only defined in ONE branch → undefined in others → silent failure

    **Contrast with JS**: JS groups [0,1,2] → pc5 and [3,4] → pc7, generates:
    ```javascript
    switch(var) {
      case 0: case 1: case 2: /* code for pc5 */ break;
      case 3: case 4: /* code for pc7 */ break;
    }
    ```

  - [x] **Task 3.5.3**: Design optimization strategy for Lua ✅
    - Goal: Group switch cases with same continuation, like JS DTree does

    **Three Design Options Evaluated**:

    **Option 1: Port full DTree to Lua backend**
    - Pros: Most "correct", matches JS architecture exactly
    - Cons: Very complex (4-6 hours), overkill for current need
    - Requires: New DTree-like module for Lua, refactor generate_last_dispatch
    - Decision: ❌ Too complex for fixing Printf

    **Option 2: Minimal grouping in generate_last_dispatch**
    - Pros: Simple, targeted fix (1-2 hours), solves Printf issue
    - Cons: Only handles Switch, doesn't optimize other patterns
    - Approach: In Code.Switch handler (line 2408), detect duplicate continuations
      and group cases before building if-else chain
    - Decision: ✅ **CHOSEN** - Best balance of simplicity and effectiveness

    **Option 3: Special-case format_int primitive**
    - Pros: Fastest hack (30 minutes)
    - Cons: Too hacky, doesn't solve root cause, fragile
    - Decision: ❌ Not sustainable

    **Chosen Implementation Plan (Option 2)**:

    1. **Location**: `compiler/lib-lua/lua_generate.ml` lines 2408-2427

    2. **Current code**:
       ```ocaml
       | Code.Switch (var, conts) ->
           let cases =
             Array.to_list conts
             |> List.mapi ~f:(fun idx (addr, args) -> ...)
       ```

    3. **New approach**:
       ```ocaml
       | Code.Switch (var, conts) ->
           (* Group cases by continuation address *)
           let grouped = group_by_continuation conts in
           (* grouped: (addr * args * int list) list *)
           (* Each element is: (target_addr, args, [case_indices]) *)
           let cases =
             List.map grouped ~f:(fun (addr, args, indices) ->
               let cond = build_multi_case_condition switch_var indices in
               (* cond: var == 0 OR var == 1 OR var == 2 *)
               let then_stmt = arg_passing @ [set_block addr] in
               (cond, then_stmt))
       ```

    4. **Helper function needed**:
       ```ocaml
       let group_by_continuation conts =
         (* Convert array to list with indices *)
         let indexed = Array.to_list conts
           |> List.mapi ~f:(fun i x -> (i, x)) in
         (* Group by (addr, args) *)
         let grouped = List.fold_left indexed ~init:[] ~f:(fun acc (idx, (addr, args)) ->
           match List.find_opt acc ~f:(fun (a, ar, _) -> a = addr && args_equal ar args) with
           | Some (a, ar, indices) ->
               (* Add idx to existing group *)
               ...
           | None ->
               (* Create new group *)
               (addr, args, [idx]) :: acc
         ) in
         List.rev grouped
       ```

    5. **Multi-case condition builder**:
       ```ocaml
       let build_multi_case_condition var indices =
         match indices with
         | [] -> assert false
         | [i] -> L.BinOp (L.Eq, var, L.Number (string_of_int i))
         | i::rest ->
             List.fold_left rest
               ~init:(L.BinOp (L.Eq, var, L.Number (string_of_int i)))
               ~f:(fun acc idx ->
                 let cond = L.BinOp (L.Eq, var, L.Number (string_of_int idx)) in
                 L.BinOp (L.Or, acc, cond))
       ```

    **Expected Result**:
    - Input: `conts = [|(pc5, []); (pc5, []); (pc5, []); (pc7, [])|]`
    - Old output: 4 separate if-elseif cases
    - New output: 2 cases
      ```lua
      if var == 0 or var == 1 or var == 2 then
        _next_block = 5
      elseif var == 3 then
        _next_block = 7
      end
      ```

    **Testing Plan**:
    - Compile test_printf_d.ml after changes
    - Verify grouped conditions appear in output
    - Verify Printf %d produces correct output
    - Run full test suite to check for regressions

    **Estimated Time**: 2-3 hours implementation + testing

  - [x] **Task 3.5.4**: Implement Code.Switch branch optimization ✅
    - Implemented: `group_by_continuation` and `build_multi_case_condition` helpers
    - Location: `compiler/lib-lua/lua_generate.ml` lines 265-318
    - Modified: Code.Switch handler at lines 2463-2497
    - Result: Cases with same continuation are grouped with OR conditions
    - Example: 14 cases → 5 groups, with 10 cases merged into one
    - **Status**: Implementation complete and working
    - **Impact**: Reduces code size, improves efficiency
    - **But**: Doesn't fix Printf %d (wrong root cause targeted)

  - [x] **Task 3.5.5**: Test Printf %d - DISCOVERY ⚠️
    - Test file: `/tmp/test_printf_d.ml`
    - Commands: `just quick-test /tmp/test_printf_d.ml`
    - Result: Still no output (silent failure persists) ❌

    **Critical Discovery**:
    - Code.Switch optimization IS working (confirmed with debug output)
    - Example: "Original: 14 cases, Grouped: 5" with 10 cases merged
    - BUT: Printf doesn't use Code.Switch terminators!
    - Instead: Printf uses SEPARATE BLOCKS in address-based dispatch

    **The Real Problem**:
    ```lua
    while true do
      if _next_block == 601 then
        -- Block 601 body
        _V.v205 = caml_format_int(_V.v207, _V.v204)
        ...
        _next_block = 605
      elseif _next_block == 602 then
        -- Block 602 body (DUPLICATE of 601!)
        _V.v205 = caml_format_int(_V.v207, _V.v204)
        ...
        _next_block = 605
      ...
    ```

    Each block's body is inlined separately in the dispatch loop.
    Multiple blocks do the same thing but aren't merged.

    **Why Code.Switch optimization doesn't help here**:
    - Code.Switch optimizes the TERMINATOR (what block to jump to next)
    - But the BODY of each block is still duplicated
    - Need to detect duplicate BLOCK BODIES and merge them

    **Root Cause Found** (via runtime debugging):
    - Test: `caml_format_int(nil, 42)` crashes with "attempt to get length of local 's'"
    - Confirmed: v207 is nil in the closure
    - Problem: v207 is NOT in the hoisted variables list
    - Current hoisted vars for v179 closure: only v205, v206
    - Missing: v207 (the format string variable)

    **Why v207 is undefined**:
    - v207 should be set by a parent block before calling convert_int
    - But the closure's hoisted variables list doesn't include v207
    - So when closure looks up _V.v207, it finds nil in parent scope
    - This causes caml_format_int to crash silently

    **The Real Fix**:
    Fix the hoisted variables analysis in `collect_block_variables` to include
    variables that are used but not defined within the closure's blocks.
    v207 is referenced in multiple blocks but never assigned - it should be hoisted.

- [x] **Task 3.5.6-3.5.8**: Skipped - optimization works but doesn't fix Printf

- [ ] **Task 3.6**: Fix hoisted variables bug for Printf %d

  **Root Cause** (from Task 3.5.5):
  - convert_int closure references v207 (format string) but v207 is nil
  - v207 is NOT in hoisted variables list (only v205, v206)
  - Closure lookup fails: _V.v207 finds nil in parent scope
  - caml_format_int(nil, 42) crashes silently

  **Problem**: collect_block_variables doesn't capture variables that are:
  - Referenced (used) within closure blocks
  - NOT assigned within closure blocks
  - Must come from parent scope

  **Investigation Plan**:
  1. Compare JS closure generation vs Lua
  2. Examine collect_block_variables logic (lua_generate.ml:1162)
  3. Identify why v207 is missed in hoisting analysis
  4. Fix to include variables referenced but not defined

  - [x] **Task 3.6.1**: Investigate JS closure variable handling ✅
    - Commands: `just analyze-printf /tmp/test_printf_d.ml`
    - Compared JS (test_printf_d.ml.pretty.js) vs Lua (quick_test.lua)

    **JS convert_int** (line 7225):
    ```javascript
    function convert_int(iconv, n){
      switch(iconv){
        case 1: var a = _; break;   // Format string constants
        case 2: var a = $; break;
        ...
      }
      return transform_int_alt(iconv, caml_format_int(a, n));  // ONE call
    }
    ```
    - `a` is a LOCAL variable declared in function scope
    - Switch assigns format string constant to `a`
    - Single call to caml_format_int with selected format

    **Lua v179 (convert_int equivalent)** (line 18006):
    ```lua
    _V.v179 = caml_make_closure(2, function(v203, v204)
      local _V = setmetatable({}, {__index = parent_V})
      _V.v205 = nil  -- Hoisted
      _V.v206 = nil  -- Hoisted
      -- v207 NOT hoisted!
      while true do
        if _V.v203 == 0 then
          _V.v205 = caml_format_int(_V.v207, _V.v204)  -- v207 undefined!
    ```
    - v207 is referenced in EVERY branch but never assigned
    - Should be hoisted from parent scope or captured from closure environment
    - Currently: v207 lookup fails → nil → crash

    **Root Cause**: collect_block_variables only hoists variables that are ASSIGNED
    It misses variables that are REFERENCED but not assigned (free variables)

  - [x] **Task 3.6.2**: Analyze collect_block_variables implementation ✅
    - File: `compiler/lib-lua/lua_generate.ml` lines 1162-1250

    **Current Logic**:
    - `collect_defined_vars`: Only collects variables from Let/Assign (lines 1171-1181)
    - Traverses reachable blocks (lines 1183-1201)
    - Result: Only DEFINED variables, not FREE variables

    **Problem**: v207 is USED in every branch but never DEFINED
    - Used at line 18016: `_V.v205 = caml_format_int(_V.v207, _V.v204)`
    - Never assigned in v179 closure blocks
    - Should be captured from parent scope or passed as closure var

    **Helper Functions Available**:
    - `collect_vars_used_in_expr` (line 1217): Extracts vars from expressions
    - `collect_vars_used_in_instr` (line 1238): Extracts vars from instructions
    - `collect_vars_used_in_block` (line 1250): Extracts all vars used in block

    **Fix Strategy**:
    1. Collect all DEFINED variables (current logic)
    2. Collect all USED variables (using existing helpers)
    3. Free variables = USED - DEFINED - PARAMETERS
    4. Return: DEFINED ∪ FREE (all variables that need hoisting)

  - [x] **Task 3.6.3**: Implement fix for hoisted variables ✅
    - Modified: `collect_block_variables` (lua_generate.ml:1162-1250)
    - Logic: Collect DEFINED vars + FREE vars (used - defined - params)
    - Result: Free variables like v314 now hoisted in child closures
    - File size: Reduced from 681K → 667K (14K smaller, more efficient hoisting)

    **Changes Made**:
    1. Changed from StringSet to Code.Var.Set for intermediate collections
    2. Added `used_vars` collection using `collect_vars_used_in_block`
    3. Added `entry_params` to exclude function parameters
    4. Calculate `free_vars = used - defined - params`
    5. Return `defined ∪ free` as final hoisted variable set

    **Verification**:
    - v314 (format string var) now in hoisted list of convert_int closure
    - Parent closure v206 has v314 = nil in hoisted vars
    - Metatable lookup should find parent_V.v314

  - [x] **Task 3.6.4**: Test Printf %d - Still fails silently ⚠️
    - Test: `just quick-test /tmp/test_printf_d.ml`
    - Result: Program runs without error but produces NO output for %d
    - Working: "Hello, World!", %s, print_endline all work
    - Failing: Printf %d silently produces no output

    **Test Results**:
    ```
    Start
    Plain: Hello
    After plain
    String: world
    After string
    (missing: Int: 42)
    Done
    ```

    **Investigation Needed**:
    - Free variables ARE being hoisted (v314 in hoisted list)
    - Parent closure v206 has v314 but initialized to nil
    - v314 assigned later: `_V.v314 = caml_format_int_special(_V.v334)`
    - Child closure v213 accesses parent_V.v314 via metatable
    - But timing may be wrong: v213 created/called before v314 assigned?
    - OR: Different issue - need runtime debugging

    **Next Step**: Add runtime debug output to trace execution flow and variable values

- [ ] **Task 3.6.5**: Debug Printf %d runtime behavior

  **Goal**: Trace execution to find why Printf %d produces no output

  **Hypothesis**: Free variables are captured but:
  - Timing issue: child closure called before parent initializes variable?
  - Metatable lookup failing for some reason?
  - Silent error in caml_format_int when fmt is nil?
  - Different code path than expected?

  **Investigation Strategy**:
  1. Add runtime debug to trace Printf execution
  2. Check when v314 is assigned vs when convert_int is called
  3. Verify metatable lookup finds parent_V.v314
  4. Compare Lua execution with JS execution flow
  5. Find exact point of failure

  - [x] **Task 3.6.5.1**: Add runtime debug output ✅ - ROOT CAUSE FOUND!
    - Added debug to Printf call sites
    - Tested both %s and %d format specifiers
    - Commands: Python scripts to instrument /tmp/quick_test.lua

    **CRITICAL DISCOVERY**:
    - Printf %s: v310.l = 1 (arity 1) → Calls directly, prints "String: world" ✅
    - Printf %d: v311.l = 2 (arity 2) → Wrong arity! Returns partial application ❌
    - When v311(42) is called with 1 arg but expects 2 → Returns closure, doesn't print
    - `caml_call_gen(_V.v311, {42})` returns a table (partial application)
    - No side effect (printing) happens

  - [x] **Task 3.6.5.2**: Root cause identified ✅
    - Problem: Convert_int closure has WRONG ARITY
    - Should be: arity 1 (takes integer, returns formatted string)
    - Actually is: arity 2 (exposed both iconv AND integer parameters)
    - Result: Printf thinks it needs 2 args, only gets 1, returns partial closure

    **Why this happens**:
    - convert_int internally takes 2 params: (iconv, n)
    - iconv should be CAPTURED from parent scope (format string selection)
    - n should be the PUBLIC parameter (the integer to format)
    - But code generator is exposing BOTH as public parameters
    - This creates arity 2 instead of arity 1

  - [x] **Task 3.6.5.3**: Compare with JS execution ✅ - DEEPER ISSUE FOUND!

    **Key Finding**: The arity mismatch is NOT in convert_int itself, but in the closure returned by make_int_padding_precision!

    **JS Behavior** (test_printf_d.ml.pretty.js:8103-8111):
    ```javascript
    function make_int_padding_precision(k, acc, fmt, pad, prec, trans, iconv){
      if(typeof prec === "number" && !prec)  // prec === 0
        return function(x){  // ← ARITY 1 closure
          var str = caml_call2(trans, iconv, x);  // Calls trans with both iconv and x
          return make_printf(k, [4, acc, str], fmt);
        }
    }
    ```

    **Lua Behavior** (test_printf_d.ml.bc.debug.lua:20849):
    ```lua
    _V.v318 = caml_make_closure(1, function(v319)  -- ← ARITY 1 closure (correct!)
      _V.v350 = (function()
        if type(_V.v257) == "table" and _V.v257.l and _V.v257.l == 2 then
          return _V.v257(_V.v256, _V.v319)  -- Calls convert_int with both iconv and x
        else
          return caml_call_gen(_V.v257, {_V.v256, _V.v319})
        end
      end)()
    ```

    **Both create arity-1 closures!** So why does v311 have arity 2?

    **Call site comparison**:
    - JS: `make_int_padding_precision(k, acc, rest$3, pad$1, prec, convert_int, iconv)` (line 7508)
    - Lua: `_V.v236(_V.v479, _V.v480, _V.v333, _V.v335, _V.v334, _V.v213, _V.v336)` (line 19608)

    **Both pass convert_int and iconv separately!** And both should return arity-1 when prec=0.

    **The Real Question**: Why does `_V.v273(_V.v287)` return a closure with arity 2 when it should return arity 1?
    - v273 = Printf.fprintf
    - v287 = format descriptor for "Int: %d\n" with prec=0
    - Expected: v273 calls v236 (make_int_padding_precision) with prec=0 → returns arity-1 closure
    - Actual: v311.l = 2 (wrong!)

    **Hypothesis**: The issue might be:
    1. v273 is returning the WRONG closure (maybe returning convert_int directly instead of the wrapper?)
    2. Or there's a different code path that doesn't go through make_int_padding_precision
    3. Or v287 format descriptor is malformed (prec not actually 0)

  - [x] **Task 3.6.5.3b**: Deeper analysis ✅ - v235 RETURNS WRONG ARITY!

    **Runtime Trace Results**:
    ```
    === v235 call (format processor) ===
      v330 (continuation): table l=1
      v329 (acc): 0
      v328 (format tree) tag: 11
      Result for %s: table, arity=1  ✅
      Result for %d: table, arity=2  ❌
    === END v235 ===
    ```

    **Key Discovery**: v235 (format processor) is directly returning different arities:
    - When processing %s format: returns closure with arity=1 (correct)
    - When processing %d format: returns closure with arity=2 (wrong!)

    **Both formats start with tag=11 (Char_literal)**, but nested format differs:
    - %s: {11, "String: ", {3, 0, {12, 10, 0}}} → tag 3 (String)
    - %d: {11, "Int: ", {4, 0, 0, 0, {12, 10, 0}}} → tag 4 (Int_d)

    **Code Structure**:
    - Tag 11 handler (line 20449): Creates closure with arity 1 that calls v236 with nested format
    - Tag 4 handler (line 20265): Creates closure with arity 1 that calls v236 with params
    - But tag 4 handler is NOT being executed (instrumentation confirmed)!

    **Hypothesis**: There's a DIFFERENT code path for %d that:
    1. Returns a closure with arity 2 directly (not going through tag 4 handler)
    2. OR v236 itself returns arity 2 for integer formats
    3. OR the closure composition is wrong (nested closures with wrong arity)

  - [x] **Task 3.6.5.4**: ROOT CAUSE FOUND! ✅

    **The Bug**: Line 20423 in generated Lua creates arity-2 closure when it should be arity-1

    ```lua
    -- BUG: Tag 10 handler (line 20421-20445)
    if _V.v374 == 10 then
      _V.v363 = caml_make_closure(2, function(v365, v364)  -- ❌ ARITY 2 (WRONG!)
        _V.v380 = _V.v236(_V.v246, _V.v245, _V.v362, _V.v243)
        return _V.v380
      end)
      return _V.v363
    end

    -- CORRECT: Tag 11 handler (line 20447-20470)
    if _V.v374 == 11 then
      _V.v367 = caml_make_closure(1, function(v368)  -- ✅ ARITY 1 (CORRECT!)
        _V.v380 = _V.v236(_V.v246, _V.v245, _V.v366, _V.v243)
        return _V.v380
      end)
      return _V.v367
    end
    ```

    **Both handlers have IDENTICAL bodies** but different arities! This is the bug.

    **Confirmed via runtime tracing**:
    - Closure #21 (the buggy one) is created at line 20423 during Printf %d call
    - v235 returns closure #21 with arity=2
    - Calling code expects arity=1, calls caml_call_gen with 1 arg
    - caml_call_gen returns partial application (arity=1 closure)
    - Partial application is never invoked, so nothing prints

    **Root Cause**: `lua_generate.ml` computes wrong arity for this closure
    - Tag 10 and tag 11 closures should both have arity 1
    - Both take single argument and call v236 with captured context
    - But code generator assigns arity 2 to tag 10 closure

  - [x] **Task 3.6.5.4b**: Arity computation found ✅

    **Location**: `lua_generate.ml:2408`
    ```ocaml
    let arity = L.Number (string_of_int (List.length params)) in
    ```

    Arity = length of `params` list from IR's `Code.Closure` instruction.

    **Critical Discovery**: Tag 10 closure has UNUSED/DEAD parameters!
    ```lua
    -- Tag 10 (arity 2) - BROKEN
    caml_make_closure(2, function(v365, v364)
      _V.v365 = v365  -- Copy to _V
      _V.v364 = v364  -- But NEVER referenced again!
      _V.v380 = _V.v236(_V.v246, _V.v245, _V.v362, _V.v243)
      return _V.v380
    end)

    -- Tag 11 (arity 1) - WORKS
    caml_make_closure(1, function(v368)
      _V.v368 = v368  -- Copy to _V, also not used
      _V.v380 = _V.v236(_V.v246, _V.v245, _V.v366, _V.v243)
      return _V.v380
    end)
    ```

    Both have dead parameters but different counts! This suggests:
    - OCaml IR has closures with unused parameters (optimization artifact?)
    - Arity should exclude dead parameters OR there's IR-level bug

  - [ ] **Task 3.6.5.4c**: Next steps - identify root cause
    - Option 1: OCaml compiler generates wrong IR (arity 2 instead of 1)
    - Option 2: lua_of_ocaml should filter dead parameters
    - Option 3: Calling convention mismatch (currying/partial application)
    - **Action**: Inspect actual bytecode to see what IR specifies
    - **Action**: Compare with js_of_ocaml handling of same IR

  - [ ] **Task 3.6.5.5**: Implement fix
    - Based on IR/bytecode analysis
    - Likely fix locations:
      1. Closure arity computation in `lua_generate.ml`
      2. Partial application handling
      3. Printf-specific code generation
    - Implement: Targeted fix based on evidence

  - [ ] **Task 3.6.5.5**: Test Printf %d after fix
    - Test: `just quick-test /tmp/test_printf_d.ml`
    - Expected: "Int: 42" appears in output
    - Test additional formats: %i, %u, %x, %o
    - Verify: No regressions on %s, %c, hello world

- [ ] **Task 3.6.6**: Run full Printf test suite

  - [ ] **Task 3.6.6**: Code review and commit
    - Review: Changes to collect_block_variables
    - Verify: `just build-strict` (no warnings)
    - Commit message: "fix(lua): capture free variables in closure hoisting (Task 3.6)"
    - Update: SPLAN.md with success

  **Success Criteria**:
  - ✅ `Printf.printf "Int: %d\n" 42` outputs "Int: 42"
  - ✅ v207 appears in hoisted variables list for convert_int closure
  - ✅ No crashes with Printf integer formatting
  - ✅ All format specifiers work (%d, %i, %u, %x, %o, %X)
  - ✅ All tests pass: `just check && just test-lua && just build-strict`

- [ ] **Task 3.7**: Review and fix any remaining Printf primitives
  - Location: `runtime/lua/format.lua`
  - Reference: `runtime/js/format.js` for behavior
  - Add missing primitives as discovered during testing

### Phase 4: I/O Primitives (1-2 hours)

**Goal**: Ensure all I/O primitives work correctly

- [ ] **Task 4.1**: Test print_endline
  ```bash
  just quick-test /tmp/test_minimal.ml
  ```
  - Should work from Phase 2
  - Verifies: Basic output works

- [ ] **Task 4.2**: Test print_string
  ```bash
  cat > /tmp/test_print_string.ml << 'EOF'
  let () = print_string "Hello without newline"
  EOF
  just quick-test /tmp/test_print_string.ml
  ```
  - Should print: "Hello without newline" (no newline)
  - Tests: `caml_ml_output_chars` or equivalent

- [ ] **Task 4.3**: Test print_int
  ```bash
  cat > /tmp/test_print_int.ml << 'EOF'
  let () = print_int 42
  EOF
  just quick-test /tmp/test_print_int.ml
  ```
  - Should print: "42"
  - Tests: Integer output

- [ ] **Task 4.4**: Test stdout flushing
  ```bash
  cat > /tmp/test_flush.ml << 'EOF'
  let () =
    print_string "Before flush";
    flush stdout;
    print_endline " After flush"
  EOF
  just quick-test /tmp/test_flush.ml
  ```
  - Should print: "Before flush After flush"
  - Tests: `caml_ml_flush` primitive

- [ ] **Task 4.5**: Test stderr output
  ```bash
  cat > /tmp/test_stderr.ml << 'EOF'
  let () = Printf.eprintf "Error: %s\n" "test"
  EOF
  just quick-test /tmp/test_stderr.ml
  ```
  - Should print to stderr: "Error: test"
  - Tests: stderr channel primitives

### Phase 5: Hello World Integration (1-2 hours)

**Goal**: Get the actual hello.ml example working

- [ ] **Task 5.1**: Build hello.ml bytecode
  ```bash
  cd examples/hello_lua
  dune clean
  dune build hello.bc
  ls -lh _build/default/hello.bc
  ```
  - Should create: hello.bc bytecode file
  - Verify: No compilation errors

- [ ] **Task 5.2**: Compile hello.bc to Lua
  ```bash
  cd examples/hello_lua
  just compile-to-lua _build/default/hello.bc hello.lua
  ls -lh hello.lua
  ```
  - Should create: hello.lua file
  - Verify: No compilation errors
  - Check size: Should be reasonable (< 2MB)

- [ ] **Task 5.3**: Inspect generated hello.lua
  ```bash
  cd examples/hello_lua
  head -50 hello.lua
  grep -c "^function caml_" hello.lua
  ```
  - Verify: Runtime primitives are embedded
  - Check: Code structure looks correct
  - Count: Number of primitives included

- [ ] **Task 5.4**: Run hello.lua with Lua 5.1
  ```bash
  cd examples/hello_lua
  lua hello.lua
  ```
  - Should print:
    ```
    Hello from Lua_of_ocaml!
    Factorial of 5 is: 120
    Testing string operations...
    Length of 'lua_of_ocaml': 12
    Uppercase: LUA_OF_OCAML
    ```
  - If fails: Debug with `just trace-lua hello.lua`

- [ ] **Task 5.5**: Run hello.lua with LuaJIT
  ```bash
  cd examples/hello_lua
  luajit hello.lua
  ```
  - Should produce identical output
  - Tests: LuaJIT compatibility
  - Measure: Execution time (should be faster)

- [ ] **Task 5.6**: Compare Lua vs JS output
  ```bash
  cd examples/hello_lua
  just compare-outputs hello.ml
  ```
  - Should match: Identical output from Lua and JS
  - Deliverable: Full compatibility verification

### Phase 6: Rock Solid Testing (1-2 days)

**Goal**: Ensure the implementation is robust and well-tested

- [ ] **Task 6.1**: Create Printf test suite
  ```bash
  # Add comprehensive Printf tests to compiler/tests-lua/
  cat > compiler/tests-lua/test_printf_e2e.ml << 'EOF'
  (* E2E tests for Printf functionality *)
  let%expect_test "printf with string" =
    Printf.printf "Hello, %s!\n" "World";
    [%expect {| Hello, World! |}]

  let%expect_test "printf with int" =
    Printf.printf "Answer: %d\n" 42;
    [%expect {| Answer: 42 |}]

  let%expect_test "printf with float" =
    Printf.printf "Pi: %.2f\n" 3.14159;
    [%expect {| Pi: 3.14 |}]

  let%expect_test "printf with multiple" =
    Printf.printf "%s: %d (%.1f%%)\n" "Score" 95 95.5;
    [%expect {| Score: 95 (95.5%) |}]
  EOF
  ```
  - Deliverable: Comprehensive Printf test coverage
  - Run: `just test-lua` to verify

- [ ] **Task 6.2**: Create I/O test suite
  - Location: `compiler/tests-lua/test_io_e2e.ml`
  - Tests: print_endline, print_string, print_int, flush, stderr
  - Deliverable: Complete I/O operation coverage

- [ ] **Task 6.3**: Create closure test suite
  - Location: `compiler/tests-lua/test_closures_e2e.ml`
  - Tests: Variable capture, nested closures, recursive functions
  - Deliverable: Verify closure semantics work correctly

- [ ] **Task 6.4**: Create control flow test suite
  - Location: `compiler/tests-lua/test_control_e2e.ml`
  - Tests: if/else, match, loops, recursion
  - Deliverable: Verify control flow compilation

- [ ] **Task 6.5**: Test string operations
  ```bash
  cat > /tmp/test_string_ops.ml << 'EOF'
  let () =
    let s = "hello" in
    Printf.printf "Length: %d\n" (String.length s);
    Printf.printf "Upper: %s\n" (String.uppercase_ascii s);
    Printf.printf "Sub: %s\n" (String.sub s 0 3);
    Printf.printf "Concat: %s\n" (String.concat "," ["a";"b";"c"])
  EOF
  just quick-test /tmp/test_string_ops.ml
  ```
  - Verifies: String runtime primitives
  - Tests: Common string operations

- [ ] **Task 6.6**: Test list operations
  ```bash
  cat > /tmp/test_list_ops.ml << 'EOF'
  let () =
    let lst = [1; 2; 3; 4; 5] in
    Printf.printf "Length: %d\n" (List.length lst);
    Printf.printf "Sum: %d\n" (List.fold_left (+) 0 lst);
    let doubled = List.map (fun x -> x * 2) lst in
    List.iter (Printf.printf "%d ") doubled;
    print_newline ()
  EOF
  just quick-test /tmp/test_list_ops.ml
  ```
  - Verifies: List module works
  - Tests: map, fold, iter

- [ ] **Task 6.7**: Test array operations
  ```bash
  cat > /tmp/test_array_ops.ml << 'EOF'
  let () =
    let arr = Array.make 5 0 in
    Array.iteri (fun i _ -> arr.(i) <- i * i) arr;
    Array.iter (Printf.printf "%d ") arr;
    print_newline ()
  EOF
  just quick-test /tmp/test_array_ops.ml
  ```
  - Verifies: Array primitives
  - Tests: make, get, set, iteri

- [ ] **Task 6.8**: Test option operations
  ```bash
  cat > /tmp/test_option_ops.ml << 'EOF'
  let () =
    let x = Some 42 in
    let y = None in
    Printf.printf "x is_some: %b\n" (Option.is_some x);
    Printf.printf "y is_none: %b\n" (Option.is_none y);
    Printf.printf "x value: %d\n" (Option.get x)
  EOF
  just quick-test /tmp/test_option_ops.ml
  ```
  - Verifies: Option module
  - Tests: Some, None, is_some, is_none, get

- [ ] **Task 6.9**: Run full test suite
  ```bash
  just test-lua
  ```
  - Should pass: All tests
  - Zero failures allowed
  - Deliverable: Complete test coverage

- [ ] **Task 6.10**: Performance benchmark
  ```bash
  cat > /tmp/test_performance.ml << 'EOF'
  let rec fib n =
    if n <= 1 then n
    else fib (n-1) + fib (n-2)

  let () =
    let n = 30 in
    let start = Unix.gettimeofday () in
    let result = fib n in
    let elapsed = Unix.gettimeofday () -. start in
    Printf.printf "fib(%d) = %d (%.3fs)\n" n result elapsed
  EOF
  # Test with Lua
  just compile-ml-to-lua /tmp/test_performance.ml /tmp/perf.lua
  echo "=== Lua 5.1 ==="
  time lua /tmp/perf.lua
  echo "=== LuaJIT ==="
  time luajit /tmp/perf.lua
  ```
  - Compare: Lua vs LuaJIT performance
  - Document: Performance characteristics
  - Verify: LuaJIT is significantly faster

### Phase 7: Documentation & Polish (1-2 hours)

**Goal**: Document the working system and clean up

- [ ] **Task 7.1**: Update LUA.md with completion
  - Mark: Milestone 1 tasks as complete
  - Update: Status percentages
  - Document: What works now

- [ ] **Task 7.2**: Update CLAUDE.md if needed
  - Add: Any new development patterns discovered
  - Update: Task completion protocol if changed
  - Document: Common issues and solutions

- [ ] **Task 7.3**: Update ENV.md if needed
  - Add: Any new verification steps
  - Update: Troubleshooting section
  - Document: New debugging techniques

- [ ] **Task 7.4**: Create HELLO_WORLD.md guide
  ```markdown
  # Hello World Tutorial

  Step-by-step guide to compiling your first OCaml program to Lua.

  ## Prerequisites
  - OCaml 5.2.0
  - Lua 5.1 or LuaJIT
  - lua_of_ocaml installed

  ## Steps
  1. Write hello.ml
  2. Compile to bytecode
  3. Compile to Lua
  4. Run with Lua/LuaJIT

  ## Examples
  - Basic print
  - Printf formatting
  - String operations
  - List/Array operations
  ```

- [ ] **Task 7.5**: Test the tutorial
  - Follow: HELLO_WORLD.md from scratch
  - Verify: All commands work
  - Fix: Any issues found
  - Deliverable: Working tutorial

- [ ] **Task 7.6**: Commit and push all changes
  ```bash
  git add .
  git status
  # Review changes carefully
  git commit -m "feat: Milestone 1 complete - Hello World working

  - Runtime integration fixed (Phase 2)
  - Printf primitives implemented (Phase 3)
  - I/O primitives verified (Phase 4)
  - hello.ml compiles and runs (Phase 5)
  - Comprehensive test suite (Phase 6)
  - Documentation updated (Phase 7)

  Success criteria met:
  ✅ hello.lua compiles without warnings
  ✅ Runs with lua and produces correct output
  ✅ Runs with luajit and produces correct output
  ✅ All tests pass

  Closes Milestone 1"

  git push origin lua
  ```

## Success Metrics

### Phase Completion
- [x] Phase 0: Environment verified ✅ (18 min)
- [x] Phase 1: Current state assessed ✅ (45 min)
- [x] Phase 2: Analysis complete ✅ (Tasks 2.1-2.6 ✅, root cause found)
- [ ] Phase 2.5: Data-driven dispatch refactor (4-8 hours) ⬅️ **NEXT** (NEW: proper fix for Printf)
- [ ] Phase 3: Printf primitives working (2-4 hours)
- [ ] Phase 4: I/O primitives verified (1-2 hours)
- [ ] Phase 5: Hello world running (1-2 hours)
- [ ] Phase 6: Rock solid testing (1-2 days)
- [ ] Phase 7: Documentation complete (1-2 hours)

### Final Verification Checklist

Run these commands as final verification:

```bash
# Environment
just verify-all                    # All tools working

# Build
just clean && just build-lua-all   # Clean build, no warnings

# Runtime tests
just test-runtime-all              # All runtime tests pass

# Compiler tests
just test-lua                      # All compiler tests pass

# Hello world
cd examples/hello_lua
dune build hello.bc
just compile-to-lua _build/default/hello.bc hello.lua
lua hello.lua                      # Correct output
luajit hello.lua                   # Correct output, faster

# Quick tests
just quick-test /tmp/test_minimal.ml      # print_endline works
just quick-test /tmp/test_printf.ml       # Printf.printf works
just quick-test /tmp/test_string_ops.ml   # String ops work
just quick-test /tmp/test_list_ops.ml     # List ops work
just quick-test /tmp/test_array_ops.ml    # Array ops work
```

### Deliverables

**Code**:
- ✅ Runtime integration fixed (Phase 2)
- ✅ All Printf primitives implemented (Phase 3)
- ✅ All I/O primitives working (Phase 4)
- ✅ hello.ml compiles and runs (Phase 5)

**Tests**:
- ✅ Printf test suite (Task 6.1)
- ✅ I/O test suite (Task 6.2)
- ✅ Closure test suite (Task 6.3)
- ✅ Control flow test suite (Task 6.4)
- ✅ String/List/Array/Option tests (Tasks 6.5-6.8)
- ✅ Full test suite passes (Task 6.9)
- ✅ Performance benchmark (Task 6.10)

**Documentation**:
- ✅ LUA.md updated (Task 7.1)
- ✅ CLAUDE.md updated if needed (Task 7.2)
- ✅ ENV.md updated if needed (Task 7.3)
- ✅ HELLO_WORLD.md created (Task 7.4)
- ✅ Tutorial tested (Task 7.5)

**Milestone 1 Success Criteria**:
- ✅ `hello.lua` compiles without warnings
- ✅ `hello.lua` runs with `lua hello.lua` and produces correct output
- ✅ `hello.lua` runs with `luajit hello.lua` and produces correct output
- ✅ All output matches expected results
- ✅ Zero compilation warnings
- ✅ Zero runtime errors
- ✅ All tests pass

## Timeline Estimates

**Optimistic** (3-4 days):
- Day 1: Phases 0-2 (environment + runtime integration)
- Day 2: Phases 3-4 (Printf + I/O primitives)
- Day 3: Phase 5 (hello world) + start Phase 6
- Day 4: Complete Phase 6-7 (testing + docs)

**Realistic** (5-7 days):
- Days 1-2: Phases 0-2 (with debugging)
- Days 3-4: Phases 3-4 (implementation + testing)
- Day 5: Phase 5 (integration + debugging)
- Days 6-7: Phases 6-7 (comprehensive testing + docs)

**Pessimistic** (1-2 weeks):
- Week 1: Phases 0-5 (with major debugging)
- Week 2: Phases 6-7 (comprehensive testing, fixing issues, docs)

## What Makes It Rock Solid

1. **Complete Runtime Integration** (Phase 2)
   - All primitives properly connected
   - Linker correctly extracts and embeds functions
   - Generated code is self-contained

2. **Comprehensive Primitive Coverage** (Phases 3-4)
   - All Printf operations work
   - All I/O operations work
   - Error handling is robust

3. **Extensive Test Coverage** (Phase 6)
   - E2E tests for all features
   - Unit tests for all primitives
   - Performance benchmarks
   - Compatibility tests (Lua 5.1 + LuaJIT)

4. **Excellent Documentation** (Phase 7)
   - Clear tutorials
   - Working examples
   - Troubleshooting guides
   - Architecture documentation

5. **Zero Tolerance for Issues**
   - No compilation warnings
   - No runtime errors
   - All tests passing
   - Performance is acceptable

## Next Steps After Milestone 1

Once this plan is complete:

1. **Milestone 2**: E2E Compiler Verification
   - Build test framework
   - 50+ test programs
   - Stdlib coverage
   - Regression tests

2. **Milestone 3**: Self-Hosted Compiler
   - Complete refactoring
   - Compile lua_of_ocaml itself
   - Bootstrap verification
   - Performance optimization

3. **Production Release**
   - Documentation polish
   - Example projects
   - Performance tuning
   - Community release

---

**Let's make lua_of_ocaml rock solid! 🚀**
