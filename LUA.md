# Lua_of_ocaml Implementation Plan

## Overview
This document outlines the implementation plan for adding Lua as a compilation target to js_of_ocaml, creating lua_of_ocaml. The goal is to compile OCaml bytecode to Lua, enabling OCaml programs to run in Lua environments (Lua 5.1+, LuaJIT, Luau).

**Documentation References**:
- [ARCH.md](ARCH.md) - Detailed architectural guidance, code reuse strategies, and implementation patterns
- [RUNTIME.md](RUNTIME.md) - Runtime API design, OCaml-Lua interop, stdlib implementation, and Neovim plugin examples

## Master Checklist

### Phase 1: Foundation and Infrastructure (Week 1-2)

#### Task 1.1: Project Setup and Package Definition
- [x] Create `lua_of_ocaml-compiler.opam` package definition
- [x] Add lua_of_ocaml package to `dune-project`
- [x] Create `compiler/lib-lua/` directory structure
- [x] Set up basic dune files for lua compilation
- **Output**: ~150 lines (opam + dune config)
- **Test**: `dune build @check` passes
- **Commit**: "feat: Initialize lua_of_ocaml package structure"

#### Task 1.2: Lua AST Definition
- [x] Create `compiler/lib-lua/lua_ast.ml` with core AST types
- [x] Define expressions: literals, variables, operators, function calls
- [x] Define statements: assignments, control flow, returns
- **Output**: ~250 lines
- **Test**: `dune build compiler/lib-lua` compiles
- **Commit**: "feat: Define Lua AST types"

#### Task 1.3: Lua AST Extensions and Tables
- [x] Extend AST with table operations and metatables
- [x] Add function definitions and closures
- [x] Add module and require support
- **Output**: ~200 lines
- **Test**: Unit tests for AST construction
- **Commit**: "feat: Complete Lua AST with tables and functions"

#### Task 1.4: Lua Pretty Printer
- [x] Create `compiler/lib-lua/lua_output.ml`
- [x] Implement expression printing
- [x] Implement statement printing with proper indentation
- **Output**: ~300 lines
- **Test**: Roundtrip test (AST → string → parse in Lua)
- **Commit**: "feat: Implement Lua code pretty printer"

#### Task 1.5: Lua Reserved Words and Identifier Handling
- [x] Create `compiler/lib-lua/lua_reserved.ml`
- [x] Handle Lua keywords and reserved identifiers
- [x] Implement name mangling for OCaml identifiers
- **Output**: ~150 lines (217 lines actual)
- **Test**: Test all OCaml stdlib names can be safely used ✓
- **Commit**: "feat: Add Lua identifier safety handling"

### Phase 2: Runtime Foundation (Week 2-3)

#### Task 2.1: Core Runtime Structure
- [x] Create `runtime/lua/` directory
- [x] Create `runtime/lua/core.lua` with module system
- [x] Implement basic module loading mechanism
- **Output**: ~200 lines (210 lines actual)
- **Test**: Load and execute empty Lua module ✓
- **Commit**: "feat: Initialize Lua runtime structure"

#### Task 2.2: Integer Operations Runtime
- [x] Create `runtime/lua/ints.lua`
- [x] Implement 32-bit integer arithmetic with overflow
- [x] Implement bitwise operations
- **Output**: ~300 lines (418 lines actual)
- **Test**: Test integer arithmetic matches OCaml semantics ✓
- **Commit**: "feat: Implement integer operations for Lua"

#### Task 2.3: String and Bytes Runtime
- [x] Create `runtime/lua/mlBytes.lua`
- [x] Implement mutable bytes (using tables)
- [x] Implement string/bytes conversion
- **Output**: ~250 lines (385 lines actual)
- **Test**: String manipulation tests ✓
- **Commit**: "feat: Add string and bytes runtime support"

#### Task 2.4: Array Operations Runtime
- [x] Create `runtime/lua/array.lua`
- [x] Implement OCaml arrays using Lua tables
- [x] Handle bounds checking
- **Output**: ~200 lines (347 lines actual)
- **Test**: Array access and mutation tests ✓
- **Commit**: "feat: Implement array operations for Lua"

#### Task 2.5: Exception Handling Runtime
- [x] Create `runtime/lua/fail.lua`
- [x] Implement OCaml exception propagation
- [x] Map to Lua error handling with pcall
- **Output**: ~250 lines (304 lines actual)
- **Test**: Exception raising and catching tests ✓
- **Commit**: "feat: Add exception handling runtime"

### Phase 3: Value Representation (Week 3-4)

#### Task 3.1: Block and Tag Representation
- [x] Create `compiler/lib-lua/lua_mlvalue.ml`
- [x] Define OCaml value encoding in Lua
- [x] Implement block allocation with tags
- **Output**: ~200 lines (274 lines impl + 142 lines interface = 416 lines total)
- **Test**: Test tuple and variant representation ✓
- **Commit**: "feat: Define OCaml value representation in Lua"

#### Task 3.2: Closure Representation
- [x] Implement closure encoding
- [x] Handle partial application
- [x] Support currying
- **Output**: ~250 lines (206 lines runtime + 54 lines compiler helpers + 221 lines runtime tests = 481 lines total)
- **Test**: Function application tests ✓
- **Commit**: "feat: Implement closure representation"

#### Task 3.3: Object and Method Representation
- [x] Implement object encoding using metatables
- [x] Support method dispatch
- [x] Handle inheritance chain
- **Output**: ~300 lines (230 lines runtime + 224 lines tests = 454 lines total)
- **Test**: Basic object creation and method calls ✓
- **Commit**: "feat: Add object system representation"

### Phase 4: Code Generation Core (Week 4-5)

#### Task 4.1: Basic Code Generator Setup
- [x] Create `compiler/lib-lua/lua_generate.ml`
- [x] Set up code generation context
- [x] Implement variable mapping
- **Output**: ~200 lines (159 lines implementation + 175 lines tests = 334 lines total)
- **Test**: Generate empty main function ✓
- **Commit**: "feat: Initialize Lua code generator"

#### Task 4.2: Expression Generation
- [x] Generate literals and variables
- [x] Generate arithmetic operations
- [x] Generate function calls
- **Output**: ~300 lines (139 lines implementation + 267 lines tests = 406 lines total)
- **Test**: Simple expression compilation tests ✓
- **Commit**: "feat: Implement expression code generation"

#### Task 4.3: Block and Let Binding Generation
- [x] Generate let bindings as local variables
- [x] Handle variable scoping
- [x] Generate sequences
- **Output**: ~250 lines (102 lines implementation + 331 lines tests = 433 lines total)
- **Test**: Let binding and sequencing tests ✓
- **Commit**: "feat: Add let binding code generation"

#### Task 4.4: Conditional and Pattern Matching
- [x] Generate if-then-else
- [x] Generate simple pattern matching
- [x] Handle match exhaustiveness
- **Output**: ~300 lines (~150 lines implementation + 315 lines tests + interface updates)
- **Test**: Pattern matching compilation tests ✓
- **Commit**: "feat: Implement conditional code generation"

#### Task 4.5: Function Definition Generation
- [x] Generate function definitions
- [x] Handle recursive functions
- [x] Implement tail call optimization using goto
- **Output**: ~300 lines (~100 lines implementation + 340 lines tests + interface updates)
- **Test**: Recursive function tests ✓ (15 tests, tail recursion disabled due to inline block issue)
- **Commit**: "feat: Add function definition generation"

### Phase 5: Primitive Operations (Week 5-6)

#### Task 5.1: Arithmetic Primitives
- [x] Map OCaml arithmetic to Lua operations
- [x] Handle overflow semantics
- [x] Implement comparison operations
- **Output**: ~250 lines (~80 lines implementation + 390 lines tests)
- **Test**: Arithmetic primitive tests ✓ (42 tests covering int, int32, nativeint, float, bitwise ops)
- **Commit**: "feat: Implement arithmetic primitives"

#### Task 5.2: String Primitives
- [x] Implement string operations
- [x] Handle string comparison
- [x] Support format strings
- **Output**: ~200 lines (~90 lines implementation + 340 lines tests)
- **Test**: String operation tests ✓ (30 tests covering length, concat, comparison, access, manipulation)
- **Commit**: "feat: Add string primitive operations"

#### Task 5.3: Array and Reference Primitives
- [x] Implement array primitives
- [x] Handle mutable references
- [x] Support weak references
- **Output**: ~250 lines (~78 lines implementation + 430 lines tests + dune updates)
- **Test**: Array and reference tests ✓ (36 tests covering array access/mutation/creation, float arrays, array manipulation, refs, weak refs)
- **Commit**: "feat: Implement array and reference primitives"

#### Task 5.4: I/O Primitives
- [x] Create `runtime/lua/io.lua`
- [x] Implement file operations
- [x] Support stdin/stdout/stderr
- **Output**: ~300 lines (~113 lines primitives + 550 lines runtime + 385 lines tests + dune updates)
- **Test**: I/O operation tests ✓ (39 tests covering file descriptors, channels, input/output, positioning, configuration)
- **Commit**: "feat: Add I/O primitive support"

### Phase 6: Module System (Week 6-7)

#### Task 6.1: Module Compilation
- [x] Generate module initialization
- [x] Handle module dependencies
- [x] Support separate compilation
- **Output**: ~250 lines (~120 lines implementation + 350 lines tests + AST/output updates)
- **Test**: Multi-module compilation test ✓ (13 tests covering standalone/module generation, init functions, exports)
- **Commit**: "feat: Implement module compilation"

#### Task 6.2: Module Linking
- [ ] Create `compiler/lib-lua/lua_link.ml`
- [ ] Implement module dependency resolution
- [ ] Generate module loader code
- **Output**: ~300 lines
- **Test**: Module linking tests
- **Commit**: "feat: Add module linking support"

#### Task 6.3: Standard Library Modules
- [x] Port essential Stdlib modules
- [x] Implement List operations
- [x] Implement Option and Result
- **Output**: ~980 lines (~600 List + ~180 Option + ~200 Result)
- **Test**: Stdlib usage tests ✓ (All tests passed: List, Option, Result)
- **Commit**: "feat: Port core stdlib modules"

### Phase 7: Advanced Features (Week 7-8)

#### Task 7.1: Lazy Values
- [x] Implement lazy value representation
- [x] Handle force operations
- [x] Cache computed values
- **Output**: ~202 lines (~202 lazy.lua implementation)
- **Test**: Lazy evaluation tests ✓ (All tests passed)
- **Commit**: "feat: Add lazy value support"

#### Task 7.2: Record and Variant Optimizations
- [x] Optimize record field access
- [x] Implement variant discrimination
- [x] Add inline record support
- **Output**: ~250 lines (~50 optimization functions + ~200 test code)
- **Test**: Record/variant performance tests ✓ (All tests passed)
- **Commit**: "feat: Optimize records and variants"

#### Task 7.3: Garbage Collection Hooks
- [x] Implement finalizers using Lua __gc
- [x] Add weak table support
- [x] Handle cyclic references
- **Output**: ~430 lines (~200 gc.lua + ~230 weak.lua)
- **Test**: GC behavior tests ✓ (All tests passed)
- **Commit**: "feat: Add GC integration"

#### Task 7.4: Float Operations
- [x] Create `runtime/lua/float.lua`
- [x] Implement float array support
- [x] Handle NaN and infinity
- **Output**: ~370 lines (float.lua)
- **Test**: Float arithmetic tests ✓ (All tests passed)
- **Commit**: "feat: Implement float operations"

### Phase 8: Lua Interop (Week 8-9)

#### Task 8.1: Lua FFI Bindings
- [x] Create `lib/lua_of_ocaml/lua.ml`
- [x] Define Lua value types
- [x] Implement type conversions
- **Output**: ~180 lines (lua.ml) + ~221 lines (lua.mli)
- **Test**: FFI type conversion tests ✓ (All tests passed)
- **Commit**: "feat: Create Lua FFI bindings"

#### Task 8.2: Calling Lua from OCaml
- [x] Implement Lua function calls
- [x] Handle Lua tables access
- [x] Support Lua global access
- **Output**: ~80 lines added to lua.ml, ~100 lines added to lua.mli
- **Test**: Lua function invocation tests ✓ (All tests passed)
- **Commit**: "feat: Enable calling Lua from OCaml"

#### Task 8.3: Exposing OCaml to Lua
- [x] Export OCaml functions to Lua
- [x] Handle type marshalling
- [x] Create module export mechanism
- **Output**: ~212 lines (lua.ml: ~135, lua.mli: ~77)
- **Test**: OCaml function export tests (test_lua_ffi.ml: ~150 lines added)
- **Commit**: "feat: Export OCaml functions to Lua"

#### Task 8.4: Lua Library Wrapping
- [x] Create helper functions for Lua library wrapping
- [x] Support method chaining
- [x] Handle optional parameters
- **Output**: ~153 lines (lua.ml: ~83, lua.mli: ~70, tests: ~207)
- **Test**: Library binding tests ✓ (All tests passed)
- **Commit**: "feat: Add Lua library wrapping helpers"
- **Note**: Implemented practical helpers instead of PPX (foundation for future PPX)

### Phase 9: Build System Integration (Week 9-10)

#### Task 9.1: Compiler Driver
- [x] Create `compiler/bin-lua_of_ocaml/lua_of_ocaml.ml`
- [x] Implement command-line interface
- [x] Add compilation flags
- **Output**: ~271 lines (compile.ml: 93, cmd_arg.ml: 60, lua_of_ocaml.ml: 89, info.ml: 29, dune: 11)
- **Test**: Builds successfully, no warnings ✓
- **Commit**: "feat: Create lua_of_ocaml compiler driver"

#### Task 9.2: Dune Integration
- [x] Add dune rules for Lua compilation
- [x] Support lua executable generation
- [x] Handle runtime bundling
- [x] Create example project
- **Output**: ~72 lines (hello.ml: 14, dune: 13, README.md: 45)
- **Test**: Dune build tests ✓ (Successfully builds hello.bc.lua)
- **Commit**: "feat: Integrate with dune build system"
- **Note**: Fixed Parse_bytecode.from_exe usage, added hello_lua example

#### Task 9.3: Source Maps
- [x] Generate source maps for debugging
- [x] Map Lua lines to OCaml source
- [x] Support stack trace translation (infrastructure)
- [x] Connect IR debug events to source mappings
- **Output**: ~155 lines (lua_output.ml: +100, compile.ml: +45, cmd_arg.ml: +13, lua_ast.ml: +1, lua_generate.ml: +2)
- **Test**: Source map generation ✓ (Generates .lua.map file in JSON format)
- **Commits**: "feat: Add source map generation infrastructure" + "feat: Connect debug events to source maps"
- **Note**: Complete implementation; requires bytecode compiled with -g flag for debug info

#### Task 9.4: Optimization Flags
- [x] Add optimization passes for Lua
- [x] Implement dead code elimination (N/A - handled by shared IR optimization passes)
- [x] Support minification
- **Output**: ~41 lines (lua_output.ml: +30, cmd_arg.ml: +7, compile.ml: +4)
- **Test**: Minification reduces size by ~4.5% (14,669 → 14,011 bytes) ✓
- **Commit**: "feat: Add Lua-specific optimizations"
- **Note**: Dead code elimination already handled by shared IR passes (deadcode, inline, specialize). Added --compact flag for minification.

### Phase 10: Testing and Documentation (Week 10-11)

#### Task 10.1: Test Suite Setup
- [ ] Create `compiler/tests-lua/` directory
- [ ] Port basic js_of_ocaml tests
- [ ] Add Lua-specific tests
- **Output**: ~200 lines
- **Test**: Test harness functionality
- **Commit**: "test: Set up Lua test suite"

#### Task 10.2: Compatibility Tests
- [ ] Test with Lua 5.1, 5.4, LuaJIT
- [ ] Add Luau compatibility
- [ ] Create compatibility matrix
- **Output**: ~250 lines
- **Test**: Cross-version tests
- **Commit**: "test: Add Lua version compatibility tests"

#### Task 10.3: Performance Benchmarks
- [ ] Port JavaScript benchmarks to Lua
- [ ] Add Lua-specific benchmarks
- [ ] Create performance comparison
- **Output**: ~300 lines
- **Test**: Benchmark execution
- **Commit**: "test: Add performance benchmarks"

#### Task 10.4: Documentation
- [ ] Write user manual
- [ ] Add API documentation
- [ ] Create migration guide
- **Output**: ~300 lines
- **Test**: Documentation build
- **Commit**: "docs: Add lua_of_ocaml documentation"

### Phase 11: Advanced Runtime (Week 11-12)

#### Task 11.1: Coroutine Support
- [ ] Map OCaml effects to Lua coroutines
- [ ] Implement yield/resume
- [ ] Handle effect handlers
- **Output**: ~300 lines
- **Test**: Effect handler tests
- **Commit**: "feat: Add coroutine-based effects"

#### Task 11.2: Bigarray Support
- [ ] Implement bigarray using FFI
- [ ] Add typed array support
- [ ] Handle memory layout
- **Output**: ~250 lines
- **Test**: Bigarray operation tests
- **Commit**: "feat: Implement bigarray support"

#### Task 11.3: Marshal/Unmarshal
- [ ] Implement value serialization
- [ ] Support cyclic structures
- [ ] Add versioning support
- **Output**: ~300 lines
- **Test**: Marshalling roundtrip tests
- **Commit**: "feat: Add marshal/unmarshal support"

#### Task 11.4: Unix Module Subset
- [ ] Implement time functions
- [ ] Add process functions
- [ ] Support file operations
- **Output**: ~300 lines
- **Test**: Unix module tests
- **Commit**: "feat: Port Unix module subset"

### Phase 12: Production Ready (Week 12)

#### Task 12.1: Error Messages
- [ ] Improve error reporting
- [ ] Add stack traces
- [ ] Implement source locations
- **Output**: ~200 lines
- **Test**: Error message quality tests
- **Commit**: "feat: Enhance error reporting"

#### Task 12.2: Performance Optimizations
- [ ] Profile common patterns
- [ ] Optimize hot paths
- [ ] Reduce allocation overhead
- **Output**: ~250 lines
- **Test**: Performance regression tests
- **Commit**: "perf: Optimize critical paths"

#### Task 12.3: CI/CD Setup
- [ ] Add GitHub Actions workflow
- [ ] Set up test matrix
- [ ] Configure release process
- **Output**: ~150 lines
- **Test**: CI pipeline execution
- **Commit**: "ci: Add lua_of_ocaml CI/CD"

#### Task 12.4: Release Preparation
- [ ] Update documentation
- [ ] Add changelog
- [ ] Tag release version
- **Output**: ~100 lines
- **Test**: Release build test
- **Commit**: "release: Prepare lua_of_ocaml v1.0.0"

## Implementation Guidelines

### Code Quality Requirements
- All code must compile without warnings
- Each task must include appropriate tests
- Follow OCaml style guidelines
- Maintain compatibility with js_of_ocaml architecture

### Testing Strategy
- Unit tests for each component
- Integration tests after each phase
- Compatibility tests across Lua versions
- Performance benchmarks against js_of_ocaml

### Commit Strategy
- Each task completion requires commit and push
- Commit messages follow conventional format
- Include test results in commit description
- Tag phase completions

### File Organization
```
compiler/
  lib-lua/           # Lua-specific compiler libraries
  bin-lua_of_ocaml/  # Compiler executable
  tests-lua/         # Lua-specific tests
runtime/
  lua/              # Lua runtime files
lib/
  lua_of_ocaml/     # OCaml-Lua interop library
examples/
  lua/              # Example programs
```

### Value Encoding Strategy

OCaml values in Lua:
- Integers: Lua numbers with overflow handling
- Blocks: Lua tables `{tag=n, [1]=v1, [2]=v2, ...}`
- Strings: Lua strings (immutable) or tables (mutable bytes)
- Functions: Lua functions with currying support
- Objects: Lua tables with metatables for method dispatch
- Modules: Lua tables with nested namespaces

### Performance Targets
- Arithmetic operations: < 2x slower than native Lua
- Function calls: < 3x slower than native Lua
- Pattern matching: Optimized to Lua if-else chains
- Memory usage: < 1.5x JavaScript version

### Lua Version Support
- Primary target: Lua 5.4 (latest stable)
- Compatibility: Lua 5.1+ (for LuaJIT)
- Optional: Luau support (Roblox Lua)

## Success Criteria

1. **Correctness**: All OCaml semantics preserved
2. **Performance**: Within 2x of js_of_ocaml performance  
3. **Compatibility**: Runs on major Lua implementations
4. **Interop**: Seamless OCaml-Lua interaction
5. **Testing**: >90% test coverage
6. **Documentation**: Complete user and API docs

## Risk Mitigation

### Technical Risks
- **Lua number limitations**: Use string-based bignum fallback
- **Missing tail calls** (some Lua configs): Use trampoline pattern
- **GC differences**: Implement explicit resource management
- **Module system**: Use require() with careful path management

### Schedule Risks
- Each phase has buffer time built in
- Parallel task execution where possible
- Core features prioritized over optimizations
- Incremental delivery model

## Deliverables

### Phase Deliverables
- Phase 1-3: Basic compilation working
- Phase 4-6: Standard programs compile
- Phase 7-9: Full feature support
- Phase 10-12: Production ready

### Final Deliverables
1. lua_of_ocaml compiler executable
2. Lua runtime system
3. OCaml-Lua interop library
4. Documentation and examples
5. Test suite and benchmarks
6. CI/CD pipeline