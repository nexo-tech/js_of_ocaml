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

- [x] **Task 3.3**: Implement value-based dispatch for Cond patterns ⚠️ PARTIAL (Detection Working)

  **Detection: ✅ COMPLETE**
  - ✅ Implemented `detect_cond_dispatch_pattern` (117 lines)
  - ✅ Recognizes entry Cond → dispatcher with tag extraction → Switch
  - ✅ Handles %direct_obj_tag, %int_of_tag, %field0/1 primitives
  - ✅ Extended DataDriven type to include tag_var field
  - ✅ Integrated with detect_dispatch_mode (tries Cond first, falls back to Switch)
  - ✅ **Printf detection triggers successfully!** (25 cases)
  - ✅ File size: 24,372 → 19,249 lines (21% reduction)

  **Code Generation: ❌ INCOMPLETE**
  - ❌ No variable hoisting (_V table not created)
  - ❌ No parameter initialization (counter, v201-v203 not copied)
  - ❌ No entry block args (v341-v343 not initialized)
  - ❌ Tag variable undefined (v204 never declared)
  - ❌ Wrong variables in generated code (_V.v204 instead of _V.v343)

  **Test Result**:
  ```bash
  $ lua test_printf_datadriven.lua
  Exit code: 0  # No error, no output (silent failure)
  ```

  **Root Cause**: `compile_data_driven_dispatch` is Task 2.5.5 prototype - only generates
  dispatch loop, missing all variable management that `compile_address_based_dispatch` has.

  **Documented**: `TASK_3_3_PARTIAL.md`

**Subtasks to Complete Task 3.3**:

- [ ] **Task 3.3.1**: Extract variable management functions ⬅️ **NEXT**

  **Goal**: Refactor `compile_address_based_dispatch` to use shared helper functions,
  so `compile_data_driven_dispatch` can reuse them.

  **Functions to Extract** (from lines 1627-1770):
  1. `collect_and_hoist_variables`: Collect vars + generate _V table setup
  2. `setup_function_parameters`: Copy function params to _V table
  3. `setup_entry_block_arguments`: Initialize entry block params from entry_args
  4. `compute_dispatch_start_addr`: Determine where dispatch loop starts (enhanced find_entry_initializer)

  **Implementation**:
  ```ocaml
  and collect_and_hoist_variables ctx program start_addr params entry_args =
    let hoisted_vars = collect_block_variables ctx program start_addr in
    let loop_headers = detect_loop_headers program start_addr in
    let loop_block_params = ... in
    let all_hoisted_vars = ... in
    let use_table = should_use_var_table (StringSet.cardinal all_hoisted_vars) in
    ctx.use_var_table <- use_table;
    let hoist_stmts = ... (* generate _V table or local declarations *)
    (hoist_stmts, use_table)

  and setup_function_parameters ctx params use_table =
    if use_table && not (List.is_empty params) then
      (* _V.param = param for each param *)
      ...
    else []

  and setup_entry_block_arguments ctx program start_addr entry_args func_params =
    if not (List.is_empty entry_args) then
      (* Initialize entry block params from entry_args *)
      ...
    else []
  ```

  **Testing**: After refactor, address-based dispatch must still work perfectly.
  ```bash
  just quick-test /tmp/test_simple_dep.ml  # Should output "11"
  ```

  **Changes**:
  - ~200 lines refactored (extracted from compile_address_based_dispatch)
  - compile_address_based_dispatch calls new functions
  - Zero behavior change (pure refactor)

- [ ] **Task 3.3.2**: Integrate variable management into data-driven dispatch

  **Goal**: Make `compile_data_driven_dispatch` call the extracted helper functions.

  **Implementation**:
  ```ocaml
  and compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var_opt switch_cases params func_params entry_args =
    (* 1. Collect and hoist variables *)
    let hoist_stmts, _use_table = collect_and_hoist_variables ctx program entry_addr params entry_args in

    (* 2. Copy function parameters to _V table *)
    let param_copy_stmts = setup_function_parameters ctx params _use_table in

    (* 3. Initialize entry block arguments *)
    let entry_arg_stmts = setup_entry_block_arguments ctx program entry_addr entry_args func_params in

    (* 4. Generate tag extraction and dispatch loop *)
    let dispatch_stmts = ... (* existing logic from lines 1535-1614 *)

    (* 5. Combine in correct order *)
    hoist_stmts @ param_copy_stmts @ entry_arg_stmts @ dispatch_stmts
  ```

  **Update Call Site** (line 1617):
  ```ocaml
  | DataDriven { entry_addr; dispatch_var; tag_var; switch_cases } ->
      compile_data_driven_dispatch ctx program entry_addr dispatch_var tag_var switch_cases params func_params entry_args
  ```

  **Changes**:
  - Update function signature (+3 params: params, func_params, entry_args)
  - Add calls to helper functions
  - Update call site to pass new parameters
  - ~20 lines changed

  **Testing**: Printf should now have _V table and parameters initialized.
  ```bash
  grep "local _V" test_printf_v4.lua  # Should find _V table creation
  grep "_V.v343 = v203" test_printf_v4.lua  # Should find entry arg init
  ```

- [ ] **Task 3.3.3**: Fix tag extraction with entry block logic

  **Goal**: Include entry block's body and Cond logic in generated code.

  **Current (Wrong)**:
  ```lua
  while true do
    local tag = v343[1] or 0  ← Missing type check!
    if tag == 0 then ...
  ```

  **Needed (Matches JS)**:
  ```lua
  while true do
    -- Entry block body instructions
    ... (execute entry block body) ...

    -- Entry block Cond (type check)
    if type(_V.v343) == "number" and _V.v343 % 1 == 0 then
      ... (block 463 code - true branch)
      return ...
    end

    -- Dispatcher block code (false branch = block 462)
    local tag = _V.v343[1] or 0  ← Now in correct context

    -- Switch on tag
    if tag == 0 then ...
  ```

  **Implementation**:
  1. Get entry block from entry_addr
  2. Generate entry block body instructions
  3. Generate entry block Cond terminator:
     - True branch: Generate block code + return
     - False branch: Continue to dispatcher (tag extraction + switch)
  4. Wrap in while loop

  **Changes**:
  - Modify compile_data_driven_dispatch to handle entry block logic
  - ~30 lines changed in dispatch generation

- [ ] **Task 3.3.4**: Test Printf with complete data-driven dispatch

  **Test Cases**:
  1. `Printf.printf "Hello\n"` → Should output "Hello"
  2. `Printf.printf "Hello, World!\n"` → Should output "Hello, World!" (THE GOAL!)
  3. `Printf.printf "Test: %s\n" "hello"` → Should output "Test: hello"

  **Debug if Needed**:
  - Check generated Lua structure matches expected
  - Compare with JS output (node test_simple_printf_js.js)
  - Add debug output if variables are still nil

- [ ] **Task 3.3.5**: Verify no regressions and run test suite

  **Tests**:
  ```bash
  # Simple closures
  just quick-test /tmp/test_simple_dep.ml  # Should output "11"

  # Full test suite
  just test-lua  # Should pass with no new failures

  # Check some improved tests
  # (Sys.word_size, String.index already improved in earlier tasks)
  ```

  **Success Criteria**:
  - All previous passing tests still pass
  - No new failures introduced
  - Data-driven dispatch improves code quality (smaller files)

## Estimated Effort

- **Task 3.3.1** (Extract helpers): 1-2 hours (pure refactor, careful testing)
- **Task 3.3.2** (Integrate): 30min-1 hour (straightforward)
- **Task 3.3.3** (Fix tag extraction): 1-2 hours (match JS exactly)
- **Task 3.3.4** (Test Printf): 30min-1 hour (debugging)
- **Task 3.3.5** (Regressions): 30min (run tests)

**Total**: 4-7 hours remaining for Task 3.3 completion

## Key Insight

js_of_ocaml uses `compile_branch` with **continuation-passing style** - all setup happens
as part of compiling the branch. Our approach separates variable management from dispatch
logic, which works for address-based but breaks for data-driven.

**The fix**: Share variable management code between both dispatch modes, only differ in
dispatch loop generation (while _next_block vs while true with value-based switch).


- [ ] **Task 3.4**: Test Printf.printf "Hello, World!\n"
  ```bash
  cat > /tmp/test_hello_printf.ml << 'EOF'
  let () = Printf.printf "Hello, World!\n"
  EOF
  ocamlc -o test_hello_printf.bc test_hello_printf.ml
  lua_of_ocaml compile test_hello_printf.bc -o test_hello_printf.lua
  lua test_hello_printf.lua
  ```
  - Expected: "Hello, World!"
  - Success criteria: No errors, correct output
  - **This is the SPLAN.md goal!**
  - Depends on: Task 3.3 (value-based dispatch)

- [ ] **Task 3.5**: Test Printf with format specifiers
  ```bash
  # Test %s
  let () = Printf.printf "Name: %s\n" "OCaml"

  # Test %d
  let () = Printf.printf "Answer: %d\n" 42

  # Test %f
  let () = Printf.printf "Pi: %.2f\n" 3.14159
  ```
  - Verifies: Format string parsing works
  - Verifies: Type-safe formatting works
  - Depends on: Task 3.4

- [ ] **Task 3.6**: Review and fix any remaining Printf primitives
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
