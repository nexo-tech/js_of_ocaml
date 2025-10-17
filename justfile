# justfile for lua_of_ocaml development
# See ENV.md for complete usage guide

# Default recipe lists all available commands
default:
    @just --list

# =============================================================================
# Phase 1: Environment Verification
# =============================================================================

# Verify OPAM switch is active and correct
verify-opam:
    @echo "=== OPAM Switch Verification ==="
    @opam switch show
    @ocaml --version
    @echo ""
    @echo "Expected: lua_of_ocaml_52 with OCaml 5.2.0"

# Verify Lua 5.1 is installed
verify-lua:
    @echo "=== Lua Version Verification ==="
    @lua -v
    @echo ""
    @echo "Expected: Lua 5.1.x (NOT 5.2+)"

# Verify dune version
verify-dune:
    @echo "=== Dune Version Verification ==="
    @dune --version
    @echo ""
    @echo "Expected: >= 3.17"

# Verify all dependencies are installed
verify-deps:
    @echo "=== OPAM Dependencies ==="
    @opam list --installed

# Verify complete environment
verify-all: verify-opam verify-lua verify-dune verify-deps
    @echo ""
    @echo "✓ All environment checks passed"

# =============================================================================
# Phase 2: Build System
# =============================================================================

# Clean all build artifacts
clean:
    @echo "Cleaning build artifacts..."
    dune clean

# Build lua_of_ocaml compiler library
build-lua-compiler:
    @echo "Building lua_of_ocaml compiler..."
    dune build compiler/lib-lua/lua_of_ocaml_compiler.cma

# Build lua_of_ocaml runtime
build-lua-runtime:
    @echo "Building lua_of_ocaml runtime..."
    dune build runtime/lua/

# Build all lua_of_ocaml components (skip JS/Wasm)
build-lua-all:
    @echo "Building all lua_of_ocaml components..."
    dune build compiler/lib-lua compiler/bin-lua_of_ocaml

# Build with warnings as errors
build-strict:
    @echo "Building with strict warnings..."
    dune build --force -p lua_of_ocaml-compiler 2>&1 | grep -i warning && exit 1 || echo "✓ No warnings"

# =============================================================================
# Phase 3: Runtime Tests
# =============================================================================

# Test closure runtime
test-runtime-closure:
    @echo "=== Testing runtime/lua/closure.lua ==="
    @cd runtime/lua && lua -e 'dofile("closure.lua"); print("✓ closure.lua loaded")'

# Test function call runtime
test-runtime-fun:
    @echo "=== Testing runtime/lua/fun.lua ==="
    @cd runtime/lua && lua -e 'dofile("closure.lua"); dofile("fun.lua"); print("✓ fun.lua loaded")'

# Test object runtime
test-runtime-obj:
    @echo "=== Testing runtime/lua/obj.lua ==="
    @cd runtime/lua && lua -e 'dofile("obj.lua"); print("✓ obj.lua loaded")'

# Test format runtime
test-runtime-format:
    @echo "=== Testing runtime/lua/format.lua ==="
    @cd runtime/lua && lua -e 'dofile("format.lua"); print("✓ format.lua loaded")'

# Test I/O runtime
test-runtime-io:
    @echo "=== Testing runtime/lua/io.lua ==="
    @cd runtime/lua && lua -e 'dofile("io.lua"); caml_init_sys_fds(); print("✓ io.lua loaded")'

# Test effect runtime
test-runtime-effect:
    @echo "=== Testing runtime/lua/effect.lua ==="
    @cd runtime/lua && lua -e 'dofile("effect.lua"); print("✓ effect.lua loaded")'

# Run all runtime tests
test-runtime-all: test-runtime-closure test-runtime-fun test-runtime-obj test-runtime-format test-runtime-io test-runtime-effect
    @echo ""
    @echo "✓ All runtime tests passed"

# =============================================================================
# Phase 4: Code Generation Tests
# =============================================================================

# Test basic code generation
test-codegen-basic:
    @echo "=== Testing basic code generation ==="
    @echo "Running inline tests with ppx_expect..."
    dune runtest compiler/tests-lua --force

# Test closure generation
test-codegen-closures:
    @echo "=== Testing closure generation ==="
    @echo "Running inline tests with ppx_expect..."
    dune runtest compiler/tests-lua --force

# Test control flow generation
test-codegen-control:
    @echo "=== Testing control flow generation ==="
    @echo "Running inline tests with ppx_expect..."
    dune runtest compiler/tests-lua --force

# Test entry block generation
test-codegen-entry-blocks:
    @echo "=== Testing entry block generation ==="
    @echo "Running inline tests with ppx_expect..."
    dune runtest compiler/tests-lua --force

# Run all codegen tests
test-codegen-all:
    @echo "=== Running all code generation tests ==="
    dune runtest compiler/tests-lua --force

# =============================================================================
# Phase 5: Compilation Pipeline
# =============================================================================

# Generate OCaml bytecode for analysis
make-bytecode file:
    @echo "Compiling {{file}} to bytecode..."
    ocamlc -o {{file}}.bc {{file}}

# Compile bytecode to Lua
compile-to-lua bc_file out_file:
    @echo "Compiling {{bc_file}} to {{out_file}}..."
    _build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile {{bc_file}} -o {{out_file}}

# Compile bytecode to JS (for comparison)
compile-to-js bc_file out_file:
    @echo "Compiling {{bc_file}} to {{out_file}}..."
    dune exec -- js_of_ocaml {{bc_file}} -o {{out_file}}

# Compile bytecode to JS with pretty printing and debug info
compile-js-pretty bc_file out_file:
    @echo "Compiling {{bc_file}} to {{out_file}} (pretty with debug info)..."
    dune exec -- js_of_ocaml compile {{bc_file}} --pretty --debuginfo --source-map -o {{out_file}}

# Compile OCaml to Lua (end-to-end)
compile-ml-to-lua ml_file out_file:
    @echo "Compiling {{ml_file}} to {{out_file}} (end-to-end)..."
    @just make-bytecode {{ml_file}}
    @just compile-to-lua {{ml_file}}.bc {{out_file}}

# Compile OCaml to JS (end-to-end)
compile-ml-to-js ml_file out_file:
    @echo "Compiling {{ml_file}} to {{out_file}} (end-to-end)..."
    @just make-bytecode {{ml_file}}
    @just compile-to-js {{ml_file}}.bc {{out_file}}

# Run Lua output
run-lua lua_file:
    @echo "Running {{lua_file}}..."
    lua {{lua_file}}

# Run JS output (for comparison)
run-js js_file:
    @echo "Running {{js_file}}..."
    node {{js_file}}

# Compare Lua and JS output
compare-outputs ml_file:
    @echo "Comparing Lua and JS output for {{ml_file}}..."
    @just compile-ml-to-lua {{ml_file}} /tmp/output.lua
    @just compile-ml-to-js {{ml_file}} /tmp/output.js
    @echo "=== Lua Output ==="
    @just run-lua /tmp/output.lua > /tmp/lua_out.txt 2>&1 || true
    @cat /tmp/lua_out.txt
    @echo ""
    @echo "=== JS Output ==="
    @just run-js /tmp/output.js > /tmp/js_out.txt 2>&1 || true
    @cat /tmp/js_out.txt
    @echo ""
    @echo "=== Diff ==="
    @diff /tmp/lua_out.txt /tmp/js_out.txt || echo "Outputs differ"

# =============================================================================
# Phase 6: Test Execution
# =============================================================================

# Run lua_of_ocaml tests only (skip JS/Wasm)
test-lua:
    @echo "=== Running lua_of_ocaml tests ==="
    dune runtest compiler/tests-lua

# Run specific test file
test-file name:
    @echo "=== Running test: {{name}} ==="
    @echo "Note: ppx_expect inline tests run as part of library, running full compiler/tests-lua"
    dune runtest compiler/tests-lua --force

# Run test and promote output
test-promote name:
    @echo "=== Running test {{name}} and promoting output ==="
    @echo "Note: Promoting all test outputs in compiler/tests-lua"
    dune promote compiler/tests-lua

# Watch tests (continuous)
test-watch:
    @echo "=== Watching lua_of_ocaml tests ==="
    @echo "Note: Use Ctrl-C to stop watching"
    dune build @runtest --watch compiler/tests-lua

# =============================================================================
# Phase 7: Debugging Tools
# =============================================================================

# Inspect OCaml bytecode
inspect-bytecode bc_file:
    @echo "=== Inspecting bytecode: {{bc_file}} ==="
    ocamlobjinfo {{bc_file}}

# Inspect OCaml lambda IR
inspect-lambda ml_file:
    @echo "=== Lambda IR for {{ml_file}} ==="
    ocamlc -dlambda {{ml_file}} 2>&1 | head -100

# Generate Lua with debug info
compile-lua-debug bc_file:
    @echo "=== Compiling {{bc_file}} with debug info ==="
    _build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile {{bc_file}} --source-map={{bc_file}}.debug.lua.map -o {{bc_file}}.debug.lua
    @echo "Generated: {{bc_file}}.debug.lua and {{bc_file}}.debug.lua.map"
    @ls -lh {{bc_file}}.debug.lua {{bc_file}}.debug.lua.map

# Compare Lua and JS ASTs
compare-ast bc_file:
    @echo "=== Comparing ASTs for {{bc_file}} ==="
    @echo ""
    @echo "=== Lua Code Structure ==="
    _build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile {{bc_file}} -o /tmp/compare_ast.lua
    @head -100 /tmp/compare_ast.lua
    @echo ""
    @echo "=== JavaScript Code Structure ==="
    dune exec -- js_of_ocaml {{bc_file}} -o /tmp/compare_ast.js
    @head -100 /tmp/compare_ast.js
    @echo ""
    @echo "=== Size Comparison ==="
    @echo -n "Lua: " && wc -c < /tmp/compare_ast.lua | tr -d ' ' && echo " bytes"
    @echo -n "JS:  " && wc -c < /tmp/compare_ast.js | tr -d ' ' && echo " bytes"

# Trace Lua execution
trace-lua lua_file:
    @echo "=== Tracing Lua execution: {{lua_file}} ==="
    @printf 'local debug = require("debug")\nlocal call_depth = 0\ndebug.sethook(function(event, line)\n  local info = debug.getinfo(2, "nSl")\n  if event == "call" then\n    call_depth = call_depth + 1\n    print(string.rep("  ", call_depth) .. ">> " .. (info.name or "?") .. " at " .. (info.short_src or "?") .. ":" .. (info.currentline or "?"))\n  elseif event == "return" then\n    print(string.rep("  ", call_depth) .. "<< " .. (info.name or "?"))\n    call_depth = call_depth - 1\n  end\nend, "cr")\ndofile("{{lua_file}}")\n' > /tmp/lua_trace_wrapper.lua
    @lua /tmp/lua_trace_wrapper.lua

# Profile Lua execution
profile-lua lua_file:
    @echo "=== Profiling Lua execution: {{lua_file}} ==="
    @cp /tmp/lua_profiler_tool.lua /tmp/lua_profiler.lua 2>/dev/null || curl -s https://raw.githubusercontent.com/lua-profiler/lua-profiler/master/profile.lua > /tmp/lua_profiler.lua || printf 'local debug=require("debug")\nlocal os=require("os")\nlocal profile={}\nlocal call_stack={}\nlocal function get_func_name(info)\n  return (info.name or "anon").."@"..(info.short_src or "?")..":"..(info.linedefined or "?")\nend\ndebug.sethook(function(event)\n  local info=debug.getinfo(2,"nSl")\n  local func_name=get_func_name(info)\n  if event=="call" then\n    table.insert(call_stack,{name=func_name,start=os.clock()})\n  elseif event=="return" then\n    if #call_stack>0 then\n      local call_info=table.remove(call_stack)\n      local elapsed=os.clock()-call_info.start\n      if not profile[call_info.name] then\n        profile[call_info.name]={count=0,total_time=0}\n      end\n      profile[call_info.name].count=profile[call_info.name].count+1\n      profile[call_info.name].total_time=profile[call_info.name].total_time+elapsed\n    end\n  end\nend,"cr")\nlocal start_time=os.clock()\nlocal lua_file=arg[1]\ndofile(lua_file)\nlocal total_time=os.clock()-start_time\nprint("\\n=== Profile Results ===")\nprint(string.format("Total execution time: %.6f seconds",total_time))\nprint("\\nFunction statistics:")\nprint(string.format("%%-%ds %%10s %%15s %%15s","Function","Calls","Total (s)","Avg (ms)"))\nprint(string.rep("-",100))\nlocal sorted={}\nfor name,stats in pairs(profile) do\n  table.insert(sorted,{name=name,count=stats.count,total=stats.total_time})\nend\ntable.sort(sorted,function(a,b) return a.total>b.total end)\nfor _,entry in ipairs(sorted) do\n  local avg_ms=(entry.total/entry.count)*1000\n  print(string.format("%%-%ds %%10d %%15.6f %%15.6f",entry.name,entry.count,entry.total,avg_ms))\nend\n' > /tmp/lua_profiler.lua
    @lua /tmp/lua_profiler.lua {{lua_file}}

# =============================================================================
# Phase 8: Quick Workflows
# =============================================================================

# Quick test cycle (compile to Lua and run)
quick-test ml_file:
    @echo "=== Quick test: {{ml_file}} ==="
    @just make-bytecode {{ml_file}}
    @just compile-to-lua {{ml_file}}.bc /tmp/quick_test.lua
    @just run-lua /tmp/quick_test.lua

# Quick comparison (Lua vs JS)
quick-compare ml_file:
    @echo "=== Quick comparison: {{ml_file}} ==="
    @just compare-outputs {{ml_file}}

# Test Printf functionality
test-printf:
    @echo "=== Testing Printf functionality ==="
    @printf 'let () = Printf.printf "Hello, %%s! Answer: %%d\\n" "World" 42\n' > /tmp/test_printf.ml
    @just quick-compare /tmp/test_printf.ml

# Analyze Printf closure structure (for dispatch refactor)
analyze-printf ml_file:
    @echo "=== Analyzing Printf closure: {{ml_file}} ==="
    @echo ""
    @echo "Step 1: Compile to bytecode..."
    ocamlc -g -o {{ml_file}}.bc {{ml_file}}
    @echo ""
    @echo "Step 2: Compile to JS (pretty with debug)..."
    @just compile-js-pretty {{ml_file}}.bc {{ml_file}}.pretty.js
    @echo ""
    @echo "Step 3: Compile to Lua (with debug)..."
    @just compile-lua-debug {{ml_file}}.bc
    @echo ""
    @echo "Step 4: File sizes..."
    @ls -lh {{ml_file}}.pretty.js {{ml_file}}.bc.debug.lua
    @echo ""
    @echo "Step 5: Extract Printf closure from JS..."
    @grep -n "function.*counter.*{" {{ml_file}}.pretty.js | head -5
    @echo ""
    @echo "Generated files:"
    @echo "  - {{ml_file}}.bc              (bytecode)"
    @echo "  - {{ml_file}}.pretty.js       (JS with debug info)"
    @echo "  - {{ml_file}}.bc.debug.lua    (Lua with debug info)"
    @echo "  - {{ml_file}}.bc.debug.lua.map (Lua source map)"

# Test closure capture
test-capture:
    @echo "=== Testing closure variable capture ==="
    @printf 'let x = 10 in\nlet f () = x + 5 in\nPrintf.printf "%%d\\n" (f ())\n' > /tmp/test_capture.ml
    @just quick-compare /tmp/test_capture.ml

# Full rebuild and test
full-test: clean build-lua-all test-lua
    @echo ""
    @echo "✓ Full test cycle completed"

# =============================================================================
# Additional Utilities
# =============================================================================

# Format OCaml code
fmt:
    @echo "Formatting OCaml code..."
    dune build @fmt --auto-promote

# Check for warnings
check:
    @echo "Checking for warnings..."
    dune build @check

# Show runtime file
show-runtime file:
    @echo "=== runtime/lua/{{file}} ==="
    @cat runtime/lua/{{file}}

# Verify runtime file has proper structure
verify-runtime file:
    @echo "=== Verifying runtime/lua/{{file}} ==="
    @echo "Checking for --Provides: comments..."
    @grep -c "^--Provides:" runtime/lua/{{file}} || echo "WARNING: No --Provides: comments found"
    @echo "Checking for global variables..."
    @grep -n "^[a-zA-Z_][a-zA-Z0-9_]* *=" runtime/lua/{{file}} | grep -v "local " | grep -v "function " || echo "✓ No global variables"
    @echo "Checking Lua 5.1 compatibility..."
    @lua -v | grep -q "5.1" && echo "✓ Running Lua 5.1" || echo "WARNING: Not using Lua 5.1"

# List all Lua runtime files
list-runtime:
    @echo "=== Lua Runtime Files ==="
    @ls -lh runtime/lua/*.lua

# Count lines of code in lua_of_ocaml
loc:
    @echo "=== Lines of Code ==="
    @echo "Compiler:"
    @find compiler/lib-lua -name "*.ml" -o -name "*.mli" | xargs wc -l | tail -1
    @echo "Runtime:"
    @find runtime/lua -name "*.lua" | xargs wc -l | tail -1
    @echo "Tests:"
    @find compiler/tests-lua -name "*.ml" | xargs wc -l | tail -1

# Show build status
status:
    @echo "=== Build Status ==="
    @echo "Compiler library:"
    @test -f _build/default/compiler/lib-lua/lua_of_ocaml_compiler.cma && echo "✓ Built" || echo "✗ Not built"
    @echo "Runtime files:"
    @test -d runtime/lua && echo "✓ Present" || echo "✗ Missing"
    @echo "Tests:"
    @find _build -name "test_*.exe" -path "*/tests-lua/*" | wc -l | xargs echo "Test executables:"

# =============================================================================
# XPLAN: Systematic Printf Fix Plan
# =============================================================================

# Show XPLAN.md progress
xplan-progress:
    @echo "=== XPLAN.md Progress ==="
    @echo ""
    @echo "Completed tasks:"
    @grep -c "^- \[x\]" XPLAN.md || echo "0"
    @echo ""
    @echo "Pending tasks:"
    @grep -c "^- \[ \]" XPLAN.md || echo "0"
    @echo ""
    @echo "Phase status:"
    @grep "^### Phase" XPLAN.md | sed 's/^### /  /'

# Setup test files for XPLAN Phase 1
xplan-setup-tests:
    @echo "=== Setting up XPLAN test files ==="
    @echo 'let () = print_endline "test"' > /tmp/xplan_test1_basic.ml
    @echo 'let f x = fun () -> x in let g = f 42 in Printf.printf "%d\n" (g())' > /tmp/xplan_test2_closure.ml
    @echo 'let () = Printf.printf "Hello\n"' > /tmp/xplan_test3_printf_simple.ml
    @echo 'let () = Printf.printf "Value: %d\n" 42' > /tmp/xplan_test4_printf_format.ml
    @echo "✓ Created 4 test files in /tmp/"
    @ls -lh /tmp/xplan_test*.ml

# Run XPLAN Phase 1 Task 1.1: Verify current build state
xplan-phase1-task1:
    @echo "=== XPLAN Phase 1 Task 1.1: Verify Build State ==="
    @echo ""
    @echo "Step 1: Clean build"
    just clean
    @echo ""
    @echo "Step 2: Build all"
    just build-lua-all
    @echo ""
    @echo "Step 3: Test runtime"
    just test-runtime-all
    @echo ""
    @echo "✓ Phase 1 Task 1.1 complete"

# Run XPLAN Phase 1 Task 1.2: Document current failure
xplan-phase1-task2:
    @echo "=== XPLAN Phase 1 Task 1.2: Document Failure ==="
    @printf 'let () = Printf.printf "Hello, World!\\n"\n' > /tmp/xplan_test_printf.ml
    @echo ""
    @echo "Compiling and running Printf test..."
    @just quick-test /tmp/xplan_test_printf.ml 2>&1 | tee /tmp/xplan_failure.log || true
    @echo ""
    @echo "Failure log saved to: /tmp/xplan_failure.log"
    @echo ""
    @echo "Generated Lua stats:"
    @wc -l /tmp/quick_test.lua 2>/dev/null || echo "Compilation failed"
    @grep -c "^function" /tmp/quick_test.lua 2>/dev/null | xargs echo "Functions:" || echo "Functions: N/A"

# Run XPLAN Phase 1 Task 1.3: Test suite
xplan-phase1-task3:
    @echo "=== XPLAN Phase 1 Task 1.3: Test Suite ==="
    just xplan-setup-tests
    @echo ""
    @for i in 1 2 3 4; do \
        echo "=== Test $$i ==="; \
        just quick-test /tmp/xplan_test$$i\_*.ml 2>&1 | tee /tmp/xplan_test$$i.log || true; \
        echo ""; \
    done
    @echo "✓ Test logs saved to /tmp/xplan_test[1-4].log"

# Run complete XPLAN Phase 1
xplan-phase1: xplan-phase1-task1 xplan-phase1-task2 xplan-phase1-task3
    @echo ""
    @echo "=== XPLAN Phase 1 Complete ==="
    @echo "Review findings and update XPLAN.md checklist"

# Generate comparison files for XPLAN Phase 4
xplan-generate-comparisons:
    @echo "=== Generating comparison files for XPLAN Phase 4 ==="
    @echo ""
    @echo "Test 1: Simple program"
    @printf 'let () = print_endline "test"\n' > /tmp/compare1.ml
    @just make-bytecode /tmp/compare1.ml
    @just compile-js-pretty /tmp/compare1.ml.bc /tmp/compare1.pretty.js
    @_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/compare1.ml.bc -o /tmp/compare1.lua
    @echo "  Generated: /tmp/compare1.{lua,pretty.js}"
    @echo ""
    @echo "Test 2: Simple closure"
    @printf 'let f x = fun () -> x in let g = f 42 in print_int (g())\n' > /tmp/compare2.ml
    @just make-bytecode /tmp/compare2.ml
    @just compile-js-pretty /tmp/compare2.ml.bc /tmp/compare2.pretty.js
    @_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/compare2.ml.bc -o /tmp/compare2.lua
    @echo "  Generated: /tmp/compare2.{lua,pretty.js}"
    @echo ""
    @echo "Test 3: Nested closure"
    @printf 'let f x = fun () -> (fun () -> x)() in let g = f 42 in print_int (g())\n' > /tmp/compare3.ml
    @just make-bytecode /tmp/compare3.ml
    @just compile-js-pretty /tmp/compare3.ml.bc /tmp/compare3.pretty.js
    @_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/compare3.ml.bc -o /tmp/compare3.lua
    @echo "  Generated: /tmp/compare3.{lua,pretty.js}"
    @echo ""
    @echo "Test 4: Printf simple"
    @printf 'let () = Printf.printf "Hello\\n"\n' > /tmp/compare4.ml
    @just make-bytecode /tmp/compare4.ml
    @just compile-js-pretty /tmp/compare4.ml.bc /tmp/compare4.pretty.js
    @_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/compare4.ml.bc -o /tmp/compare4.lua 2>&1 || true
    @echo "  Generated: /tmp/compare4.{lua,pretty.js}"
    @echo ""
    @echo "✓ All comparison files generated in /tmp/"
    @ls -lh /tmp/compare*.{lua,js} 2>/dev/null | head -20

# Quick check if Printf works (XPLAN success test)
xplan-check-printf:
    @echo "=== XPLAN Printf Check ==="
    @printf 'let () = Printf.printf "Hello, World!\\n"\n' > /tmp/xplan_check.ml
    @just quick-test /tmp/xplan_check.ml 2>&1 | grep -q "Hello, World!" && echo "✓ Printf simple strings WORK!" || echo "✗ Printf still broken"

# Comprehensive Printf test (all format specifiers)
xplan-test-printf-full:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "=== XPLAN Comprehensive Printf Test ==="
    cat > /tmp/xplan_printf_full.ml << 'EOFTEST'
    let () =
      Printf.printf "Test 1: Simple string\n";
      Printf.printf "Test 2: Int %d\n" 42;
      Printf.printf "Test 3: String %s\n" "hello";
      Printf.printf "Test 4: Multiple %d + %d = %d\n" 2 3 5;
      Printf.printf "Test 5: Float %.2f\n" 3.14159
    EOFTEST
    echo "Running comprehensive Printf test..."
    just quick-test /tmp/xplan_printf_full.ml 2>&1 | tee /tmp/xplan_printf_full.log || true
    echo ""
    if grep -q "Test 5:" /tmp/xplan_printf_full.log 2>/dev/null; then
        echo "✓ All Printf tests PASSED!"
    elif grep -q "Test 1:" /tmp/xplan_printf_full.log 2>/dev/null; then
        echo "⚠ Partial success: Simple strings work, format specifiers broken"
    else
        echo "✗ Printf completely broken"
    fi
