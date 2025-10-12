# ENV.md - Development Environment Setup for lua_of_ocaml

This file provides a master checklist for setting up a complete troubleshooting environment for lua_of_ocaml development with Claude Code.

## Prerequisites

- OCaml 5.2.0 via OPAM switch `lua_of_ocaml_52`
- Lua 5.1 (via Nix: `nix-env -iA nixpkgs.lua5_1`)
- `just` command runner (install: `cargo install just` or `brew install just`)

## Master Checklist

### Phase 0: Install Just Command Runner (< 50 lines)

**Goal**: Install the `just` command runner required for all other tasks.

- [x] **Task 0.1**: Install just via Homebrew (macOS/Linux)
  ```bash
  brew install just
  ```

- [x] **Task 0.2**: Or install just via Cargo (if Rust is installed)
  ```bash
  cargo install just
  ```

- [x] **Task 0.3**: Or download just binary directly
  ```bash
  # See: https://github.com/casey/just#installation
  # For macOS/Linux, download from releases page
  ```

- [x] **Task 0.4**: Verify just is installed
  ```bash
  just --version
  ```
  - Should show: just x.x.x or higher
  - ✅ Verified: just 1.43.0

### Phase 1: Environment Verification (< 100 lines)

**Goal**: Verify all required tools are installed and accessible.

- [x] **Task 1.1**: Verify OPAM switch is active
  ```bash
  just verify-opam
  ```
  - Should show: `lua_of_ocaml_52` and OCaml 5.2.0
  - ✅ Verified: lua_of_ocaml_52, OCaml 5.2.0

- [x] **Task 1.2**: Verify Lua 5.1 is installed
  ```bash
  just verify-lua
  ```
  - Should show: Lua 5.1.x
  - ✅ Verified: Lua 5.1.5

- [x] **Task 1.3**: Verify dune version
  ```bash
  just verify-dune
  ```
  - Should show: dune >= 3.17
  - ✅ Verified: dune 3.20.2

- [x] **Task 1.4**: Verify all dependencies installed
  ```bash
  just verify-deps
  ```
  - Lists all installed OPAM packages
  - ✅ Verified: All required packages installed

### Phase 2: Build System Setup (< 200 lines)

**Goal**: Build all lua_of_ocaml components cleanly.

- [x] **Task 2.1**: Clean build artifacts
  ```bash
  just clean
  ```
  - Removes all `_build/` artifacts
  - ✅ Verified: Build artifacts cleaned

- [x] **Task 2.2**: Build lua_of_ocaml compiler library
  ```bash
  just build-lua-compiler
  ```
  - Builds `compiler/lib-lua/lua_of_ocaml_compiler.cma`
  - ✅ Verified: Compiler library built successfully

- [x] **Task 2.3**: Build lua_of_ocaml runtime
  ```bash
  just build-lua-runtime
  ```
  - Builds all runtime Lua files
  - ✅ Verified: Runtime files built successfully

- [x] **Task 2.4**: Build all lua_of_ocaml components
  ```bash
  just build-lua-all
  ```
  - Full lua_of_ocaml build (excludes JS/Wasm)
  - ✅ Verified: lua_of_ocaml.exe (16M) built successfully

### Phase 3: Runtime Test Suite (< 250 lines)

**Goal**: Verify all Lua runtime functions work correctly.

- [ ] **Task 3.1**: Test closure runtime
  ```bash
  just test-runtime-closure
  ```
  - Tests `runtime/lua/closure.lua`

- [ ] **Task 3.2**: Test function call runtime
  ```bash
  just test-runtime-fun
  ```
  - Tests `runtime/lua/fun.lua` (caml_call_gen, partial application)

- [ ] **Task 3.3**: Test object runtime
  ```bash
  just test-runtime-obj
  ```
  - Tests `runtime/lua/obj.lua` (blocks, arrays)

- [ ] **Task 3.4**: Test format runtime
  ```bash
  just test-runtime-format
  ```
  - Tests `runtime/lua/format.lua` (Printf support)

- [ ] **Task 3.5**: Test I/O runtime
  ```bash
  just test-runtime-io
  ```
  - Tests `runtime/lua/io.lua` (channels, output)

- [ ] **Task 3.6**: Run all runtime tests
  ```bash
  just test-runtime-all
  ```
  - Runs all runtime test suites

### Phase 4: Code Generation Tests (< 250 lines)

**Goal**: Verify Lua code generation produces correct output.

- [ ] **Task 4.1**: Test basic code generation
  ```bash
  just test-codegen-basic
  ```
  - Tests constants, primitives, simple expressions

- [ ] **Task 4.2**: Test closure generation
  ```bash
  just test-codegen-closures
  ```
  - Tests closure capture, hoisting, nested closures

- [ ] **Task 4.3**: Test control flow generation
  ```bash
  just test-codegen-control
  ```
  - Tests loops, conditionals, pattern matching

- [ ] **Task 4.4**: Test entry block generation
  ```bash
  just test-codegen-entry-blocks
  ```
  - Tests entry block parameter initialization

- [ ] **Task 4.5**: Run all codegen tests
  ```bash
  just test-codegen-all
  ```
  - Runs complete code generation test suite

### Phase 5: Compilation Pipeline (< 300 lines)

**Goal**: Test end-to-end OCaml → Lua compilation.

- [ ] **Task 5.1**: Generate OCaml bytecode for analysis
  ```bash
  just make-bytecode <file.ml>
  ```
  - Compiles OCaml source to bytecode for inspection

- [ ] **Task 5.2**: Compile bytecode to Lua
  ```bash
  just compile-to-lua <file.bc> <output.lua>
  ```
  - Converts OCaml bytecode to Lua code

- [ ] **Task 5.3**: Compile bytecode to JS (comparison)
  ```bash
  just compile-to-js <file.bc> <output.js>
  ```
  - Converts bytecode to JS for behavior comparison

- [ ] **Task 5.4**: Compile OCaml to Lua (end-to-end)
  ```bash
  just compile-ml-to-lua <file.ml> <output.lua>
  ```
  - Full pipeline: OCaml → bytecode → Lua

- [ ] **Task 5.5**: Compile OCaml to JS (end-to-end)
  ```bash
  just compile-ml-to-js <file.ml> <output.js>
  ```
  - Full pipeline: OCaml → bytecode → JS

- [ ] **Task 5.6**: Run Lua output
  ```bash
  just run-lua <file.lua>
  ```
  - Executes Lua file with runtime loaded

- [ ] **Task 5.7**: Run JS output (comparison)
  ```bash
  just run-js <file.js>
  ```
  - Executes JS file with Node.js

- [ ] **Task 5.8**: Compare Lua and JS output
  ```bash
  just compare-outputs <file.ml>
  ```
  - Compiles to both Lua and JS, compares outputs

### Phase 6: Test Execution (< 200 lines)

**Goal**: Run specific test suites efficiently.

- [ ] **Task 6.1**: Run lua_of_ocaml tests only
  ```bash
  just test-lua
  ```
  - Runs only lua_of_ocaml test suite (excludes JS/Wasm)

- [ ] **Task 6.2**: Run specific test file
  ```bash
  just test-file <test_name>
  ```
  - Example: `just test-file test_closures`

- [ ] **Task 6.3**: Run test and promote output
  ```bash
  just test-promote <test_name>
  ```
  - Runs test and accepts new expected output

- [ ] **Task 6.4**: Watch tests (continuous)
  ```bash
  just test-watch
  ```
  - Watches for changes and re-runs tests

### Phase 7: Debugging Tools (< 250 lines)

**Goal**: Provide utilities for troubleshooting compilation issues.

- [ ] **Task 7.1**: Inspect OCaml bytecode
  ```bash
  just inspect-bytecode <file.bc>
  ```
  - Shows bytecode instructions and structure

- [ ] **Task 7.2**: Inspect OCaml lambda IR
  ```bash
  just inspect-lambda <file.ml>
  ```
  - Shows OCaml lambda intermediate representation

- [ ] **Task 7.3**: Generate Lua with debug info
  ```bash
  just compile-lua-debug <file.bc>
  ```
  - Compiles with full debug output

- [ ] **Task 7.4**: Compare Lua and JS ASTs
  ```bash
  just compare-ast <file.bc>
  ```
  - Shows side-by-side AST comparison

- [ ] **Task 7.5**: Trace Lua execution
  ```bash
  just trace-lua <file.lua>
  ```
  - Runs Lua with debug tracing enabled

- [ ] **Task 7.6**: Profile Lua execution
  ```bash
  just profile-lua <file.lua>
  ```
  - Profiles Lua execution performance

### Phase 8: Quick Workflows (< 150 lines)

**Goal**: Common workflows for rapid development.

- [ ] **Task 8.1**: Quick test cycle
  ```bash
  just quick-test <file.ml>
  ```
  - Compile to Lua, run, show output (one command)

- [ ] **Task 8.2**: Quick comparison
  ```bash
  just quick-compare <file.ml>
  ```
  - Compile to both Lua/JS, run both, diff outputs

- [ ] **Task 8.3**: Test Printf functionality
  ```bash
  just test-printf
  ```
  - Specific test for Printf.printf edge cases

- [ ] **Task 8.4**: Test closure capture
  ```bash
  just test-capture
  ```
  - Specific test for variable capture issues

- [ ] **Task 8.5**: Full rebuild and test
  ```bash
  just full-test
  ```
  - Clean, build, run all lua tests

## Usage Notes

### Running Commands

All commands use the `just` command runner. List all available commands:

```bash
just --list
```

Get help for a specific command:

```bash
just --show <command-name>
```

### Test Filtering

To run only lua_of_ocaml tests (skip JS/Wasm):

```bash
just test-lua
```

This internally uses: `dune build @runtest -p lua_of_ocaml-compiler`

### Debugging Failed Tests

When a test fails:

1. Run with verbose output: `just test-file-verbose <test_name>`
2. Inspect the generated Lua: `just show-lua <test_name>`
3. Compare with JS: `just compare-outputs-test <test_name>`
4. Check runtime loading: `just verify-runtime`

### Environment Variables

- `LUA_PATH`: Automatically set to include runtime files
- `LUA_DEBUG`: Set to enable debug output (used by trace commands)
- `OCAMLRUNPARAM`: Set for OCaml runtime debugging

## Troubleshooting Checklist

If compilation fails:

1. ✓ Verify OPAM switch: `just verify-opam`
2. ✓ Clean build: `just clean && just build-lua-all`
3. ✓ Check runtime: `just test-runtime-all`
4. ✓ Verify dependencies: `just verify-deps`

If tests fail:

1. ✓ Run specific test: `just test-file <test_name>`
2. ✓ Compare with JS: `just compare-outputs-test <test_name>`
3. ✓ Check generated Lua: `just show-lua <test_name>`
4. ✓ Trace execution: `just trace-lua-test <test_name>`

If runtime errors occur:

1. ✓ Test specific runtime: `just test-runtime-<module>`
2. ✓ Check Lua version: `just verify-lua`
3. ✓ Inspect bytecode: `just inspect-bytecode <file.bc>`
4. ✓ Debug compile: `just compile-lua-debug <file.bc>`

## References

- See `justfile` for command implementations
- See `CLAUDE.md` for development guidelines
- See `LUA.md` for lua_of_ocaml roadmap
- See `ARCH.md` for architecture details
- See `RUNTIME.md` for runtime API documentation
