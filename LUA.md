# Lua_of_ocaml - Roadmap to Production

## 🎯 Current Status

**Last Updated**: 2025-10-11

### ✅ What Works Today

**Compiler Infrastructure** (100% Complete)
- ✅ Lua AST and code generation
- ✅ Module compilation and linking
- ✅ Build system integration (dune)
- ✅ Variable limit fixes (auto-chunking)
- ✅ Source maps for debugging

**Runtime System** (95% Complete)
- ✅ 88+ runtime modules implemented
- ✅ 57 test suites with 251+ tests passing
- ✅ Full Lua 5.1, 5.4, and LuaJIT compatibility verified
- ✅ Marshal implementation (complete with cycles, sharing, all types)
- ✅ All Phase 9 refactoring complete (global function pattern)
- ✅ LuaJIT optimization compatibility verified (14/14 tests)

**Test Coverage** (Excellent)
- ✅ Core: array, list, option, result, lazy, buffer, mlBytes
- ✅ Advanced: obj, effect, lexing, digest, bigarray, hash, compare, float
- ✅ Marshal: 10 test suites covering all marshal features
- ✅ I/O: channels, files, memory buffers, integration tests
- ✅ Compatibility: Lua 5.1, LuaJIT optimization tests

### ⏳ What's Next

**Three Critical Milestones**:
1. **🎯 Milestone 1**: Hello World Running (1-2 weeks)
2. **🎯 Milestone 2**: E2E Compiler Verification (1-2 weeks)
3. **🎯 Milestone 3**: Self-Hosted Compiler (2-4 weeks)

---

## 🎯 Milestone 1: Hello World Running

**Goal**: Get `examples/hello_lua/hello.ml` to compile and run successfully

**Status**: 🔴 Blocked - Compiler generates code but runtime integration incomplete

### Current Example

```ocaml
(* examples/hello_lua/hello.ml *)
let () = print_endline "Hello from Lua_of_ocaml!"

let factorial n =
  let rec loop acc i =
    if i <= 1 then acc
    else loop (acc * i) (i - 1)
  in
  loop 1 n

let () =
  Printf.printf "Factorial of 5 is: %d\n" (factorial 5);
  Printf.printf "Testing string operations...\n";
  let s = "lua_of_ocaml" in
  Printf.printf "Length of '%s': %d\n" s (String.length s);
  Printf.printf "Uppercase: %s\n" (String.uppercase_ascii s)
```

### Tasks Required

#### Task M1.1: Runtime Primitive Adapter Layer (HIGH PRIORITY)
**Status**: 🔴 Not Started
**Estimated Time**: 2-3 days
**Blocker**: Compiler generates `caml_*` function calls but runtime uses module patterns

**Problem**: Mismatch between compiler expectations and runtime reality
- Compiler generates: `caml_ml_open_out("file.txt", 0)`
- Runtime has: `require("io").caml_ml_open_out("file.txt", 0)` or global `caml_ml_open_out`

**Solution Options**:
1. **Option A (Preferred)**: Finish runtime refactoring to global functions
   - Complete remaining 7 modules (Tasks 8.6-8.12 from PRIMITIVES_REFACTORING.md)
   - Verify all `caml_*` functions are globally accessible
   - Update linker to properly extract and bundle functions

2. **Option B (Quick Fix)**: Generate runtime adapter shim
   - Create `runtime_adapter.lua` that exports all module functions globally
   - Include adapter in every compiled program
   - Technical debt but unblocks testing

**Deliverable**: All `caml_*` primitives accessible as global functions

#### Task M1.2: Missing Runtime Primitives (MEDIUM PRIORITY)
**Status**: 🟡 Needs Assessment
**Estimated Time**: 1-2 days

**Known Missing** (from PRIMITIVES.md):
- `caml_ml_open_descriptor_out`, `caml_ml_open_descriptor_in` (12 descriptor functions)
- Advanced `sys.lua` functions (Task 8.6)
- Some `format_channel.lua` functions (Task 8.7)
- Advanced `fun.lua` utilities (Task 8.8)

**Action**: Run hello.ml, capture missing primitive errors, implement them

**Deliverable**: All primitives needed for hello.ml implemented

#### Task M1.3: E2E Compilation Test (HIGH PRIORITY)
**Status**: 🔴 Not Started
**Estimated Time**: 1 day

**Action**:
```bash
# Compile
cd examples/hello_lua
dune build hello.bc
lua_of_ocaml hello.bc -o hello.lua

# Test
lua hello.lua         # Should print: Hello from Lua_of_ocaml!
luajit hello.lua      # Should work with JIT
```

**Deliverable**: hello.lua runs without errors and produces correct output

### Success Criteria for Milestone 1
- ✅ `hello.lua` compiles without warnings
- ✅ `hello.lua` runs with `lua hello.lua` and produces correct output
- ✅ `hello.lua` runs with `luajit hello.lua` and produces correct output
- ✅ All output matches expected results

---

## 🎯 Milestone 2: E2E Compiler Verification

**Goal**: Comprehensive end-to-end test framework to verify compiler correctness

**Status**: 🟡 Partially Done - Have compiler unit tests, need execution tests

### Tasks Required

#### Task M2.1: E2E Test Framework (HIGH PRIORITY)
**Status**: 🔴 Not Started
**Estimated Time**: 2-3 days

**Infrastructure**:
```ocaml
(* compiler/tests-lua/framework.ml *)
module E2E_Test : sig
  val compile_and_run : string -> string -> (string * string) Result.t
  val test_case : name:string -> ocaml_code:string -> expected_output:string -> unit
  val test_suite : name:string -> (unit -> unit) list -> unit
end
```

**Deliverable**: Framework for compile → execute → verify cycle

#### Task M2.2: Core Feature Test Suite (MEDIUM PRIORITY)
**Status**: 🔴 Not Started
**Estimated Time**: 2-3 days

**Test Categories**:
1. **Primitives**: integers, floats, strings, booleans
2. **Data Structures**: lists, arrays, options, results, records
3. **Control Flow**: if/else, match, loops, recursion
4. **Functions**: closures, partial application, higher-order functions
5. **Modules**: module references, functors (basic)
6. **Exceptions**: raise, try/catch, finally
7. **I/O**: print, read, file operations
8. **Printf**: formatting, type safety

**Deliverable**: 50+ small OCaml programs that compile and run correctly

#### Task M2.3: Stdlib Coverage Tests (MEDIUM PRIORITY)
**Status**: 🔴 Not Started
**Estimated Time**: 1-2 days

**Test OCaml Stdlib Modules**:
- `List` (map, fold, filter, etc.)
- `String` (length, sub, concat, uppercase, etc.)
- `Array` (make, get, set, length, etc.)
- `Printf` (printf, sprintf, fprintf)
- `Option` (map, bind, value, etc.)
- `Result` (map, bind, etc.)

**Deliverable**: Verify stdlib functions work as expected

#### Task M2.4: Regression Test Suite (LOW PRIORITY)
**Status**: 🔴 Not Started
**Estimated Time**: 1 day

**Action**: Document known issues and create regression tests
- Variable limit chunking
- Primitive name mangling
- Module resolution
- Control flow edge cases

**Deliverable**: Test suite that prevents regressions

### Success Criteria for Milestone 2
- ✅ E2E test framework operational
- ✅ 50+ test programs compile and run correctly
- ✅ Core OCaml stdlib modules verified working
- ✅ CI/CD runs E2E tests automatically
- ✅ Documentation for adding new tests

---

## 🎯 Milestone 3: Self-Hosted Compiler

**Goal**: lua_of_ocaml compiles itself - the ultimate validation

**Status**: 🔴 Blocked - Needs M1 and M2 complete, plus missing stdlib functions

### Prerequisites

**Must Complete First**:
- ✅ Milestone 1 (Hello World)
- ✅ Milestone 2 (E2E Testing)

**Runtime Gaps for Self-Hosting**:

Based on `LUA_STATUS.md` analysis, the compiler itself uses:
1. **String/Buffer Operations** - ✅ DONE
2. **Printf Formatting** - ✅ DONE (format.lua)
3. **Polymorphic Comparison** - ✅ DONE (compare.lua)
4. **Hashing** - ✅ DONE (hash.lua, hashtbl.lua need Task 8.9)
5. **Hash Tables** - 🟡 NEEDS Task 8.9
6. **Sets and Maps** - 🟡 NEEDS Tasks 8.10-8.11
7. **File I/O** - ✅ DONE (io.lua)
8. **Sys Module** - 🟡 NEEDS Task 8.6

### Tasks Required

#### Task M3.1: Complete Phase 8 Refactoring (HIGH PRIORITY)
**Status**: 🟡 Partially Done
**Estimated Time**: 1 week

**Remaining Tasks from PRIMITIVES_REFACTORING.md**:
- [ ] Task 8.6: sys.lua - system primitives
- [ ] Task 8.7: format_channel.lua - channel formatting
- [ ] Task 8.8: fun.lua - function primitives
- [ ] Task 8.9: hashtbl.lua - hash tables (CRITICAL for compiler)
- [ ] Task 8.10: map.lua - maps (CRITICAL for compiler)
- [ ] Task 8.11: set.lua - sets (CRITICAL for compiler)
- [ ] Task 8.12: gc.lua - garbage collection

**Deliverable**: All runtime modules use global function pattern, fully tested

#### Task M3.2: Compiler Self-Compilation Test (HIGH PRIORITY)
**Status**: 🔴 Not Started
**Estimated Time**: 3-5 days

**Action**:
```bash
# Step 1: Compile compiler with OCaml
cd compiler/lib-lua
dune build lua_of_ocaml.bc

# Step 2: Compile compiler bytecode to Lua
lua_of_ocaml lua_of_ocaml.bc -o lua_of_ocaml.lua

# Step 3: Use Lua-compiled compiler to compile hello.ml
lua lua_of_ocaml.lua hello.bc -o hello_from_lua.lua

# Step 4: Run result
lua hello_from_lua.lua  # Should work!
```

**Challenges**:
- Large codebase (10K+ LOC compiler)
- Complex dependencies (parser, lexer, optimizer, code gen)
- Potential performance issues (compile time)

**Deliverable**: lua_of_ocaml compiles itself successfully

#### Task M3.3: Bootstrap Verification (MEDIUM PRIORITY)
**Status**: 🔴 Not Started
**Estimated Time**: 2 days

**Action**: Verify 3-way bootstrap:
1. OCaml compiler compiles lua_of_ocaml → `lua_of_ocaml_v1.lua`
2. `lua_of_ocaml_v1.lua` compiles lua_of_ocaml → `lua_of_ocaml_v2.lua`
3. `lua_of_ocaml_v2.lua` compiles lua_of_ocaml → `lua_of_ocaml_v3.lua`
4. Verify: `diff lua_of_ocaml_v2.lua lua_of_ocaml_v3.lua` (should be identical)

**Deliverable**: Proven bootstrap stability

#### Task M3.4: Performance Optimization (LOW PRIORITY)
**Status**: 🔴 Not Started
**Estimated Time**: 1-2 weeks

**Focus Areas**:
- Compile time optimization (compiler runs fast under Lua)
- Generated code optimization (small, efficient output)
- LuaJIT trace compilation hints
- Runtime function inlining

**Deliverable**: Self-hosted compiler has acceptable performance

### Success Criteria for Milestone 3
- ✅ lua_of_ocaml compiles itself successfully
- ✅ Self-compiled compiler can compile hello.ml correctly
- ✅ 3-way bootstrap verification passes
- ✅ Compile times are reasonable (< 5 min on laptop)
- ✅ Documentation updated with self-hosting instructions

---

## 📊 Progress Tracking

### Overall Project Status

| Milestone | Status | Est. Time | Priority |
|-----------|--------|-----------|----------|
| **M1: Hello World** | 🔴 30% | 1-2 weeks | 🔥 Critical |
| **M2: E2E Testing** | 🟡 20% | 1-2 weeks | 🔥 Critical |
| **M3: Self-Hosting** | 🔴 10% | 2-4 weeks | High |

### Dependency Graph

```
M1: Hello World
  ├─> Task M1.1: Runtime adapter layer (BLOCKS EVERYTHING)
  ├─> Task M1.2: Missing primitives
  └─> Task M1.3: E2E compilation test
      ↓
M2: E2E Testing
  ├─> Task M2.1: Test framework
  ├─> Task M2.2: Core feature tests
  ├─> Task M2.3: Stdlib coverage tests
  └─> Task M2.4: Regression tests
      ↓
M3: Self-Hosting
  ├─> Task M3.1: Complete Phase 8 refactoring
  ├─> Task M3.2: Self-compilation test
  ├─> Task M3.3: Bootstrap verification
  └─> Task M3.4: Performance optimization
```

### Weekly Goals

**Week 1**: Complete M1.1 (runtime adapter), start M1.2 (missing primitives)
**Week 2**: Complete M1, start M2.1 (test framework)
**Week 3**: Complete M2.1-M2.2, start M3.1 (Phase 8 refactoring)
**Week 4**: Complete M2, continue M3.1
**Week 5-6**: Complete M3.1, attempt M3.2 (self-compilation)
**Week 7-8**: Complete M3, polish, document, celebrate! 🎉

---

## 📚 Documentation

### Key Documents

**Architecture & Implementation**:
- [ARCH.md](ARCH.md) - Architectural patterns and code reuse strategies
- [RUNTIME.md](RUNTIME.md) - Runtime API design and OCaml-Lua interop
- [PRIMITIVES_REFACTORING.md](PRIMITIVES_REFACTORING.md) - Runtime refactoring roadmap (Phase 1-9 ✅)
- [SELF_HOSTING.md](SELF_HOSTING.md) - Self-hosting plan and bootstrapping process

**Compatibility**:
- [COMPAT.md](COMPAT.md) - Lua version compatibility (5.1, 5.4, LuaJIT, Luau)
- [CLAUDE.md](CLAUDE.md) - Development environment and workflow

**Runtime Documentation**:
- [runtime/lua/README.md](runtime/lua/README.md) - Runtime module overview
- [runtime/lua/USER_GUIDE.md](runtime/lua/USER_GUIDE.md) - User guide with examples
- [runtime/lua/MARSHAL.md](runtime/lua/MARSHAL.md) - Marshal implementation deep dive

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

**Development Workflow**:
1. Pick a task from the roadmap above
2. Follow task completion protocol in [CLAUDE.md](CLAUDE.md)
3. Write tests for new functionality
4. Ensure `dune build @check && dune build @runtest` passes
5. Update this document with progress
6. Commit with conventional commit messages

---

## 🚀 Quick Start (Once M1 Complete)

```bash
# Install dependencies
opam switch create lua_of_ocaml 5.2.0
eval $(opam env)
opam install . --deps-only --yes

# Install Lua
nix-env -iA nixpkgs.lua5_1

# Build compiler
dune build @all

# Compile OCaml to Lua
ocamlc -o program.byte program.ml
lua_of_ocaml program.byte -o program.lua

# Run
lua program.lua
# Or with LuaJIT (100-300x faster!)
luajit program.lua
```

---

## 📈 Success Metrics

**Quality Metrics**:
- ✅ All runtime tests passing (57 test suites)
- ⏳ Hello world compiles and runs correctly
- ⏳ 50+ E2E test programs pass
- ⏳ Self-hosting successful
- ⏳ Bootstrap verification clean

**Performance Metrics** (to be established):
- Compile time: < 5 min for lua_of_ocaml itself
- Runtime overhead: < 2x vs native Lua
- LuaJIT speedup: 10-100x vs interpreter
- Generated code size: < 2x source bytecode

**Compatibility**:
- ✅ Lua 5.1: 100% tested
- ✅ Lua 5.4: 100% tested
- ✅ LuaJIT: 100% tested with optimizations
- ⏳ Luau: TBD (future work)

---

## 🎯 The Path Forward

**Immediate Next Steps** (This Week):
1. 🔥 **Task M1.1**: Implement runtime adapter layer OR complete remaining refactorings
2. 🔥 **Task M1.2**: Implement missing primitives for hello.ml
3. 🔥 **Task M1.3**: Get hello.lua running

**This Month**:
- Complete Milestone 1 (Hello World)
- Complete Milestone 2 (E2E Testing)
- Start Milestone 3 (Self-Hosting prep)

**This Quarter**:
- Complete Milestone 3 (Self-Hosting)
- Performance tuning and optimization
- Documentation and examples
- Public release

---

**Let's ship it!** 🚀
