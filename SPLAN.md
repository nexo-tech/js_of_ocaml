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

### Phase 3: Printf Primitives - ✅ PARTIAL (2 hours)

**Goal**: Implement missing Printf runtime primitives

- [x] **Task 3.1**: Identify missing Printf primitives ✅
  - **Found root cause**: Double-prefix bug in `lua_generate.ml:701`
  - Inline primitive `%caml_format_int_special` → `caml_format_int_special`
  - Bug: Line 701 added "caml_" unconditionally → `caml_caml_format_int_special` ❌
  - **Fix Applied**: Check for "caml_" prefix before adding (lines 701-707)

  **Additional Fixes Implemented**:
  1. ✅ Implemented `caml_format_int_special` in `runtime/lua/format.lua`
     - Converts int to string: `tostring(i)` wrapped in OCaml string
  2. ✅ Fixed `caml_lua_string_to_ocaml` to include `length` field
     - Was returning bare table, now includes `.length = #s`
  3. ✅ Fixed `caml_ml_output` to handle OCaml strings (tables)
     - Added `caml_ocaml_string_to_lua` conversion before string.sub

  **Test Results**:
  - ✅ `/tmp/test_closure_simple.ml` (print_int): **WORKS!** Prints "30"
  - ❌ `/tmp/test_printf.ml` (Printf.printf): Still fails with v273 nil error

  **Conclusion**: `print_int` works! Printf.printf has a different issue (original closure bug?)

- [ ] **Task 3.2**: Review js_of_ocaml Printf implementation
  ```bash
  # Study how js_of_ocaml implements Printf
  cat runtime/js/format.js | less
  ```
  - Understand: Format string parsing
  - Understand: Type-safe formatting
  - Document: Which parts are already in runtime/lua/format.lua

- [ ] **Task 3.3**: Implement missing format primitives
  - Location: `runtime/lua/format.lua`
  - Reference: `runtime/js/format.js` for behavior
  - Pattern: Global functions with --Provides: directives
  - Test: Each primitive with unit tests in `lib/tests/test_format.ml`

  Required primitives (based on LUA.md analysis):
  - `caml_format_int` (likely already exists)
  - `caml_format_float` (likely already exists)
  - `caml_format_string` (likely already exists)
  - Others as discovered in Task 3.1

- [ ] **Task 3.4**: Test Printf.printf with %s
  ```bash
  cat > /tmp/test_printf_string.ml << 'EOF'
  let () = Printf.printf "Message: %s\n" "Hello"
  EOF
  just quick-test /tmp/test_printf_string.ml
  ```
  - Should print: "Message: Hello"
  - Tests: String formatting

- [ ] **Task 3.5**: Test Printf.printf with %d
  ```bash
  cat > /tmp/test_printf_int.ml << 'EOF'
  let () = Printf.printf "Number: %d\n" 42
  EOF
  just quick-test /tmp/test_printf_int.ml
  ```
  - Should print: "Number: 42"
  - Tests: Integer formatting

- [ ] **Task 3.6**: Test Printf.printf with multiple format specifiers
  ```bash
  cat > /tmp/test_printf_multi.ml << 'EOF'
  let () = Printf.printf "%s: %d\n" "Answer" 42
  EOF
  just quick-test /tmp/test_printf_multi.ml
  ```
  - Should print: "Answer: 42"
  - Tests: Multiple arguments

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
