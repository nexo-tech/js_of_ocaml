# SPLAN.md - Strategic Plan for lua_of_ocaml Hello World

This file provides a master checklist for getting lua_of_ocaml to successfully compile and run `Printf.printf "Hello, World!"` and making the compiler rock solid.

## Current Status (2025-10-12)

**Foundation**: ✅ Complete (Phases 1-11 from LUA.md)
- Compiler infrastructure: 100%
- Runtime system: 95%
- Test coverage: Excellent

**Critical Blocker**: Runtime integration incomplete
- Compiler generates code ✅
- Runtime functions implemented ✅
- **Missing**: Connection between generated code and runtime primitives ❌

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

### Phase 1: Assess Current State (< 2 hours)

**Goal**: Understand exactly what's broken and why

- [ ] **Task 1.1**: Create minimal test case
  ```bash
  cat > /tmp/test_minimal.ml << 'EOF'
  let () = print_endline "Hello from print_endline"
  EOF
  just quick-test /tmp/test_minimal.ml
  ```
  - Captures: What works vs what fails
  - Documents: First point of failure

- [ ] **Task 1.2**: Test Printf.printf
  ```bash
  cat > /tmp/test_printf.ml << 'EOF'
  let () = Printf.printf "Hello, World!\n"
  EOF
  just quick-test /tmp/test_printf.ml
  ```
  - Captures: Printf-specific failures
  - Identifies: Missing Printf primitives

- [ ] **Task 1.3**: Test Printf with format specifiers
  ```bash
  cat > /tmp/test_printf_format.ml << 'EOF'
  let () = Printf.printf "Answer: %d\n" 42
  EOF
  just quick-test /tmp/test_printf_format.ml
  ```
  - Tests: Format string parsing
  - Identifies: Format runtime primitives needed

- [ ] **Task 1.4**: Analyze generated Lua code
  ```bash
  just compile-ml-to-lua /tmp/test_printf.ml /tmp/test_printf.lua
  # Inspect the generated code
  less /tmp/test_printf.lua
  ```
  - Understand: What caml_* functions are generated
  - Verify: Runtime primitives are embedded
  - Check: Function calling conventions

- [ ] **Task 1.5**: Compare with working JS output
  ```bash
  just compare-outputs /tmp/test_printf.ml
  ```
  - Understand: How js_of_ocaml handles same code
  - Compare: Code structure and runtime calls
  - Document: Differences in approach

- [ ] **Task 1.6**: Document findings
  Create `/tmp/assessment.md` with:
  - List of missing/broken primitives
  - Generated code structure issues
  - Runtime loading problems
  - Priority order for fixes

### Phase 2: Runtime Integration (2-4 hours)

**Goal**: Fix the connection between generated code and runtime primitives

- [ ] **Task 2.1**: Verify runtime function visibility
  ```bash
  # Test that caml_* functions are globally accessible
  cat > /tmp/test_runtime_visibility.lua << 'EOF'
  dofile("runtime/lua/io.lua")
  dofile("runtime/lua/format.lua")
  print(type(caml_ml_output_char))
  print(type(caml_format_int))
  EOF
  lua /tmp/test_runtime_visibility.lua
  ```
  - Verify: All caml_* functions are global
  - Test: Functions can be called directly
  - Document: Any missing or incorrectly structured functions

- [ ] **Task 2.2**: Test linker extraction
  ```bash
  # Verify linker can extract caml_* functions from runtime files
  # This tests the --Provides: parsing in lua_linker.ml
  just inspect-lua-runtime
  ```
  - Verify: Linker finds all --Provides: directives
  - Check: Dependencies (--Requires:) are resolved correctly
  - Test: Function ordering in generated code

- [ ] **Task 2.3**: Fix runtime embedding in compiler
  - Location: `compiler/lib-lua/lua_generate.ml:1328-1390`
  - Task: Verify `embed_runtime_module` correctly extracts functions
  - Task: Verify `generate_global_wrappers` creates proper wrappers
  - Task: Test that generated code includes all needed primitives
  - Deliverable: Runtime primitives properly embedded in output

- [ ] **Task 2.4**: Test minimal embedded runtime
  ```bash
  # Compile minimal test case and verify embedded runtime
  ocamlc -o /tmp/minimal.bc /tmp/test_minimal.ml
  _build/default/compiler/bin-lua_of_ocaml/main_lua_of_ocaml.exe /tmp/minimal.bc -o /tmp/minimal.lua
  # Check embedded runtime
  grep -c "^function caml_" /tmp/minimal.lua
  grep -c "^--Provides:" /tmp/minimal.lua
  ```
  - Verify: Runtime functions are embedded
  - Count: Number of embedded primitives
  - Test: Generated file is self-contained

- [ ] **Task 2.5**: Run minimal test with embedded runtime
  ```bash
  lua /tmp/minimal.lua
  ```
  - Should print: "Hello from print_endline"
  - If fails: Debug with `just trace-lua /tmp/minimal.lua`
  - Deliverable: First successful OCaml→Lua execution!

### Phase 3: Printf Primitives (2-4 hours)

**Goal**: Implement missing Printf runtime primitives

- [ ] **Task 3.1**: Identify missing Printf primitives
  ```bash
  # Try to run Printf test and capture missing primitives
  just quick-test /tmp/test_printf.ml 2>&1 | grep "attempt to call.*nil"
  ```
  - List: All missing caml_* functions for Printf
  - Priority: Order by what's needed for "Hello, World!"
  - Document: Expected function signatures

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
- [ ] Phase 1: Current state assessed (< 2 hours) ⬅️ **NEXT**
- [ ] Phase 2: Runtime integration fixed (2-4 hours)
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
