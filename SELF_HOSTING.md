# Lua_of_ocaml Self-Hosting Plan

**Goal**: Ensure lua_of_ocaml compiler can compile itself and run as a Neovim plugin, with rock-solid reliability for live compilation.

**Critical Requirement**: The compiled-to-Lua compiler must be able to compile OCaml code on-demand in a Lua environment (Neovim).

---

## Self-Hosting Workflow

```
OCaml Source (lua_of_ocaml compiler)
    ↓
[Native lua_of_ocaml] (bootstrap compiler)
    ↓
Lua Code (lua_of_ocaml.lua)
    ↓
[Load in Lua/Neovim]
    ↓
[Compile OCaml bytecode → Lua] (live compilation)
    ↓
[Execute generated Lua] (plugin code)
```

---

## Testing Phases

### Phase 1: Basic Execution (URGENT)
**Verify generated Lua can run at all**

- [ ] Task 1.1: Test hello_lua execution
  ```bash
  dune build examples/hello_lua/hello.bc.lua
  lua _build/default/examples/hello_lua/hello.bc.lua
  ```
  Expected: "Hello from Lua_of_ocaml!" printed

- [ ] Task 1.2: Test minimal_exec execution
  ```bash
  dune build compiler/tests-lua/minimal_exec.bc.lua
  lua _build/default/compiler/tests-lua/minimal_exec.bc.lua
  ```
  Expected: "test" printed

- [ ] Task 1.3: Identify runtime loading issues
  - Check for missing `caml_*` functions
  - Verify runtime module loading
  - Document any primitive mismatches

### Phase 2: Compiler Primitive Analysis
**Identify what the compiler itself needs**

- [ ] Task 2.1: Extract all primitives used by compiler
  ```bash
  # Analyze compiler/*.ml for primitive usage
  grep -r "external\|##" compiler/bin-lua_of_ocaml compiler/lib-lua
  ```

- [ ] Task 2.2: Cross-reference with runtime implementation
  - Compare against runtime/lua/*.lua
  - List missing primitives
  - Prioritize by criticality

- [ ] Task 2.3: Test compiler dependencies
  - Compile a simple .ml file that uses:
    * String operations
    * Printf/Format
    * Hashtbl
    * List/Array operations
    * File I/O (reading bytecode)

### Phase 3: Incremental Self-Hosting Test
**Test progressively complex compilation**

- [ ] Task 3.1: Compile trivial OCaml module
  ```ocaml
  (* test_simple.ml *)
  let x = 42
  let f y = y + 1
  ```
  Compile with Lua-based compiler, verify output

- [ ] Task 3.2: Compile module using stdlib
  ```ocaml
  (* test_stdlib.ml *)
  let () =
    let s = "hello" in
    Printf.printf "%s\n" (String.uppercase_ascii s)
  ```

- [ ] Task 3.3: Compile module using compiler primitives
  ```ocaml
  (* test_compiler_deps.ml *)
  open Js_of_ocaml_compiler
  let () =
    let h = Hashtbl.create 10 in
    Hashtbl.add h "key" "value";
    print_endline (Hashtbl.find h "key")
  ```

- [ ] Task 3.4: Compile small compiler module
  ```ocaml
  (* test_lua_ast.ml *)
  module Lua_ast = Lua_of_ocaml_compiler__Lua_ast
  (* Use Lua_ast types and functions *)
  ```

### Phase 4: Full Compiler Self-Hosting
**Compile entire lua_of_ocaml compiler to Lua**

- [ ] Task 4.1: Build lua_of_ocaml.bc (bytecode)
  ```bash
  dune build compiler/bin-lua_of_ocaml/lua_of_ocaml.bc
  ```

- [ ] Task 4.2: Compile to Lua
  ```bash
  lua_of_ocaml compile \
    _build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.bc \
    -o lua_of_ocaml_self.lua
  ```

- [ ] Task 4.3: Test self-compiled compiler
  ```bash
  # Use Lua-compiled compiler to compile hello.ml
  lua lua_of_ocaml_self.lua compile hello.bc -o hello_from_self.lua

  # Verify output
  lua hello_from_self.lua
  ```

- [ ] Task 4.4: Bootstrap cycle verification
  ```bash
  # Stage 0: Native compiler
  # Stage 1: Lua compiler (compiled by native)
  # Stage 2: Lua compiler (compiled by stage 1)
  # Verify stage1 output == stage2 output (bit-identical)
  ```

### Phase 5: Live Compilation Test
**Test on-demand compilation in Lua environment**

- [ ] Task 5.1: Create Lua REPL test
  ```lua
  -- test_live_compile.lua
  local compiler = require('lua_of_ocaml_self')

  -- Compile OCaml source on-the-fly
  local bytecode = compile_ocaml_source("let x = 1 + 2")
  local lua_code = compiler.compile(bytecode)

  -- Execute generated Lua
  load(lua_code)()
  ```

- [ ] Task 5.2: Memory stress test
  ```lua
  -- Compile 100 small modules in a loop
  for i = 1, 100 do
    local code = generate_test_module(i)
    local lua = compiler.compile(code)
    -- Verify no memory leaks
  end
  ```

- [ ] Task 5.3: Performance test
  ```lua
  -- Measure compilation speed
  local start = os.clock()
  for i = 1, 10 do
    compiler.compile(test_bytecode)
  end
  local elapsed = os.clock() - start
  print("Average: " .. (elapsed / 10) .. "s per compilation")
  ```
  **Target**: <1s per typical module

### Phase 6: Neovim Integration Test
**Test in real Neovim environment**

- [ ] Task 6.1: Load compiler in Neovim
  ```lua
  -- init.lua
  local compiler = dofile('lua_of_ocaml_self.lua')
  ```

- [ ] Task 6.2: Compile OCaml plugin on-demand
  ```lua
  -- When user opens .ml file, compile it
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.ml",
    callback = function()
      local bytecode = read_bytecode(vim.fn.expand("%:r") .. ".bc")
      local lua_code = compiler.compile(bytecode)
      load(lua_code)()  -- Execute plugin
    end
  })
  ```

- [ ] Task 6.3: Error handling test
  - Compile invalid OCaml code
  - Verify error messages are clear
  - Ensure Neovim doesn't crash

---

## Critical Runtime Primitives Needed

Based on LUA_STATUS.md analysis, these are **required** for self-hosting:

### Must-Have (Compiler Won't Work Without These)

1. **String/Buffer Operations** (HIGH)
   - [x] Basic string ops ✅
   - [x] Buffer module ✅
   - [ ] Printf advanced formats (`%a`, `%t`)
   - [ ] Format type checking

2. **I/O Operations** (HIGH)
   - [x] Basic file read/write ✅
   - [ ] **Binary I/O for bytecode reading** (CRITICAL)
   - [ ] Channel operations
   - [ ] Buffered I/O

3. **Hashtbl Operations** (HIGH)
   - [x] Create, add, find, iter ✅
   - [x] Hash function ✅
   - [ ] Hashtbl statistics (if compiler uses)

4. **Polymorphic Comparison** (HIGH)
   - [x] compare, equal, <, >, <=, >= ✅

5. **Sys Module** (MEDIUM)
   - [x] argv, getenv, file_exists ✅
   - [ ] sys_remove (file deletion)
   - [ ] sys_rename
   - [ ] sys_command (shell execution)

6. **Arg Module** (MEDIUM)
   - [ ] Command-line parsing (compiler uses this)
   - ~200-300 lines to implement

7. **Marshal/Serialization** (MEDIUM)
   - [x] Basic marshal/unmarshal ✅
   - [ ] Marshal from/to channels
   - [ ] Compatibility with OCaml marshal format

### Nice-to-Have (For Better Error Messages)

8. **Printexc Module** (LOW)
   - [x] Basic exception printing ✅
   - [ ] Stack traces with source locations
   - [ ] Backtrace support

9. **Unix Module** (LOW)
   - [ ] Process management (if compiler shells out)
   - [ ] File stat operations

---

## Success Criteria

**Phase 1 Success**: ✅ Hello world Lua executes
**Phase 2 Success**: ✅ All compiler primitives catalogued
**Phase 3 Success**: ✅ Can compile simple modules with Lua compiler
**Phase 4 Success**: ✅ Compiler compiles itself (bootstrap)
**Phase 5 Success**: ✅ Live compilation works in Lua
**Phase 6 Success**: ✅ Neovim plugin can compile and load OCaml code

**Rock-Solid Criteria**:
- ✅ Zero crashes during compilation
- ✅ Clear error messages for all failures
- ✅ <1s compilation time for typical modules
- ✅ <10MB memory usage per compilation
- ✅ No memory leaks over 100+ compilations
- ✅ Bit-identical output between native and Lua compiler

---

## Current Blockers (Priority Order)

### ❌ BLOCKER 1: GOTO/SCOPE BUG (CRITICAL - PREVENTS ALL EXECUTION)
**Status**: Generated Lua code violates Lua's goto/label scoping rules
**Discovery Date**: 2025-10-09
**Error**: `<goto block_4> at line 374 jumps into the scope of local 'v318'`

**Root Cause**:
The current code generation strategy generates code like:
```lua
::block_2::
if condition then
  goto block_4  -- Line 374: tries to jump forward
end
::block_3::
local v318 = ...  -- Line 379: local declared
-- ... more code ...
::block_4::      -- Line 441: target is AFTER v318 declaration
```

**Lua Restriction**: Cannot jump forward with `goto` into a scope where a local variable has been declared. This is a fundamental Lua language rule (PUC-Rio Lua 5.1+).

**Impact**: **NOTHING EXECUTES** - hello_lua, minimal_exec, ALL generated code fails with this error.

**Fix Required**: Restructure code generation to avoid forward jumps across local declarations.

**Possible Solutions**:

1. **Solution A: Hoist All Locals to Function Top** (RECOMMENDED)
   ```lua
   -- Declare ALL locals at function start
   local v318, v319, v320  -- All vars hoisted

   ::block_2::
   if condition then goto block_4 end

   ::block_3::
   v318 = caml_%direct_obj_tag(v316)  -- Assignment, not declaration

   ::block_4::
   v319 = 0  -- Assignment, not declaration
   ```
   **Pros**: Simple, matches Lua best practices, no scope issues
   **Cons**: All variables visible everywhere (but OCaml already has block-scoped analysis)

2. **Solution B: Use do...end Blocks for Scoping**
   ```lua
   ::block_2::
   if condition then goto block_4 end

   do  -- Isolate block_3 scope
     ::block_3::
     local v318 = caml_%direct_obj_tag(v316)
     -- Use v318 here
   end  -- v318 scope ends

   ::block_4::  -- Now safe to jump here
   local v319 = 0
   ```
   **Pros**: Preserves variable scoping
   **Cons**: Complex, need to analyze which blocks can jump where

3. **Solution C: Convert to if/else Chain** (FALLBACK)
   ```lua
   if at_block_2 then
     if condition then
       at_block_4 = true
     else
       at_block_3 = true
     end
   elseif at_block_3 then
     -- ...
   elseif at_block_4 then
     -- ...
   end
   ```
   **Pros**: Always works
   **Cons**: Slow, defeats purpose of goto optimization

**Recommended Fix**: Solution A (hoist all locals)

**Implementation Location**: `compiler/lib-lua/lua_generate.ml`
- Function: `generate_module_init` (line ~967)
- Need to:
  1. Collect all local variables used in all blocks
  2. Generate `local v1, v2, v3, ...` at function start
  3. Change `local vN = expr` to `vN = expr` in block bodies

**Estimated Effort**: ~100-150 lines, 1-2 hours

**Priority**: **URGENT** - blocks ALL execution testing

---

### Blocker 2: EXECUTION NOT VERIFIED (BLOCKED BY BLOCKER 1)
**Status**: Cannot test until goto/scope bug is fixed
**Action**: Complete EXECUTION.md Phase 9 Tasks 9.1-9.2 after Blocker 1
**Timeline**: After Blocker 1 fix

### Blocker 2: Runtime Primitive Gaps (HIGH)
**Status**: Missing ~12 primitives needed by compiler
**Action**: Implement missing primitives (see LUA_STATUS.md)
**Timeline**: After Phase 9

### Blocker 3: Binary I/O for Bytecode (HIGH)
**Status**: Compiler needs to read .bc files
**Action**: Implement binary file I/O in runtime
**Timeline**: After primitive gap analysis

### Blocker 4: Arg Module (MEDIUM)
**Status**: Compiler uses Arg for CLI parsing
**Action**: Implement Arg module (~300 lines)
**Timeline**: After binary I/O

---

## Recommended Next Steps

1. **IMMEDIATE**: Complete EXECUTION.md Phase 9
   - Verify hello_lua executes with Lua
   - Fix any runtime loading issues
   - Test minimal_exec

2. **Day 1**: Primitive Coverage Analysis
   - Run Task 2.1: Extract compiler primitives
   - Run Task 2.2: Cross-reference with runtime
   - Document gaps in this file

3. **Day 2-3**: Implement Critical Missing Primitives
   - Binary I/O for bytecode reading
   - Any missing Hashtbl operations
   - Printf advanced formats (if needed)

4. **Day 4**: Incremental Self-Hosting Tests (Phase 3)
   - Test Tasks 3.1-3.4
   - Identify any new missing primitives

5. **Week 2**: Full Self-Hosting (Phase 4)
   - Compile compiler to Lua
   - Bootstrap verification
   - Performance validation

6. **Week 3**: Live Compilation (Phase 5-6)
   - Lua REPL tests
   - Neovim integration
   - Stress testing

---

## Testing Infrastructure Needed

### Test Files to Create

1. `compiler/tests-lua/test_self_hosting.ml`
   - Automated self-hosting tests
   - Primitive coverage checks
   - Bootstrap verification

2. `examples/self_hosting/`
   - Example self-compiled compiler
   - Demo scripts for live compilation
   - Neovim plugin template

3. `runtime/lua/test_primitives.lua`
   - Runtime primitive test suite
   - Coverage verification
   - Performance benchmarks

### CI Integration

Add to `.github/workflows/`:
```yaml
- name: Self-Hosting Test
  run: |
    # Compile compiler to Lua
    dune exec lua_of_ocaml -- compile lua_of_ocaml.bc -o compiler.lua

    # Test self-compiled compiler
    lua compiler.lua compile hello.bc -o hello.lua
    lua hello.lua
```

---

## Performance Targets for Self-Hosting

Based on Task 8.2 results (native compiler: 6.31ms for 269 blocks):

| Metric | Native | Lua (Target) | Lua (Acceptable) |
|--------|--------|--------------|------------------|
| Small module (<100 blocks) | 6ms | <100ms | <500ms |
| Medium module (100-500 blocks) | 20ms | <500ms | <2000ms |
| Compiler itself (~1000+ blocks) | 50ms | <2000ms | <5000ms |
| Memory per compilation | 1.66MB | <10MB | <50MB |

**Rationale for Lua slowdown**:
- 10-50x slowdown is typical for interpreted vs native
- Neovim users expect subsecond plugin loading
- <5s for compiler self-compilation is acceptable for development

---

## Risk Mitigation

### Risk 1: Missing Primitives Cause Silent Failures
**Mitigation**:
- Implement runtime primitive checking
- Fail fast with clear error on missing primitive
- Log all primitive calls in debug mode

### Risk 2: Performance Too Slow for Live Compilation
**Mitigation**:
- Profile Lua execution (not just native)
- Optimize hot paths in Lua runtime
- Consider caching compiled modules

### Risk 3: Memory Leaks in Long-Running Lua Process
**Mitigation**:
- Implement proper GC integration
- Test 1000+ compilation cycles
- Monitor memory usage over time

### Risk 4: Bytecode Format Incompatibility
**Mitigation**:
- Test marshal/unmarshal round-trips
- Verify bytecode version compatibility
- Document supported OCaml versions

---

## Success Metrics

**Self-Hosting is "Rock Solid" when**:

✅ **Correctness**: Bootstrap produces bit-identical compiler
✅ **Performance**: Lua compiler compiles itself in <5s
✅ **Reliability**: 0 crashes in 1000 compilation cycles
✅ **Memory**: <50MB peak, no leaks over time
✅ **Usability**: Clear errors, <1s for typical plugin compilation
✅ **Compatibility**: Works in Lua 5.1, 5.4, LuaJIT, Neovim

---

## Open Questions

1. **Bytecode Reading**: Can Lua runtime read .bc files?
   - Need binary I/O implementation
   - Or pass bytecode as string/table?

2. **Linker**: Does Lua compiler need linking support?
   - Single-file or multi-module compilation?
   - Dynamic loading of compiled modules?

3. **Source Maps**: Are they needed for debugging?
   - Lua error messages with OCaml source locations?
   - Integration with Neovim's diagnostic system?

4. **Compilation Cache**: Cache compiled modules?
   - Where to store cache (filesystem/memory)?
   - Cache invalidation strategy?

---

## Next Task: EXECUTION.md Phase 9

**Before proceeding with self-hosting**, we MUST verify basic execution works.

➡️ **Immediate Action**: Execute Task 9.1 - Verify hello_lua runs
➡️ **Then**: Execute Task 9.2 - Add execution tests

Once Phase 9 is complete, return to this document and proceed with Phase 2 (Primitive Analysis).
