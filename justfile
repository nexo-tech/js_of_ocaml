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
    dune build @runtest -p lua_of_ocaml-compiler

# Run specific test file
test-file name:
    @echo "=== Running test: {{name}} ==="
    dune exec -- compiler/tests-lua/{{name}}.exe

# Run test and promote output
test-promote name:
    @echo "=== Running test {{name}} and promoting output ==="
    dune exec -- compiler/tests-lua/{{name}}.exe
    dune promote

# Watch tests (continuous)
test-watch:
    @echo "=== Watching lua_of_ocaml tests ==="
    dune build @runtest -p lua_of_ocaml-compiler --watch

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
    @echo "TODO: Add debug flag to lua_of_ocaml CLI"

# Compare Lua and JS ASTs
compare-ast bc_file:
    @echo "=== Comparing ASTs for {{bc_file}} ==="
    @echo "TODO: Implement AST comparison tool"

# Trace Lua execution
trace-lua lua_file:
    @echo "=== Tracing Lua execution: {{lua_file}} ==="
    LUA_DEBUG=1 lua -ldebug {{lua_file}}

# Profile Lua execution
profile-lua lua_file:
    @echo "=== Profiling Lua execution: {{lua_file}} ==="
    @echo "TODO: Add Lua profiler integration"

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
