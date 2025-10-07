# Lua Module Linking and Dependency Resolution - Implementation Plan

This document provides a detailed implementation plan for completing Task 6.2 (Module Linking) from LUA.md. The implementation is based on studying both js_of_ocaml's 802-line `compiler/lib/linker.ml` and wasm_of_ocaml's 2460-line `compiler/lib-wasm/wasm_link.ml`.

## Overview

The Lua linker will resolve dependencies between runtime fragments and generate proper module loader code using Lua's `require()` system. Unlike JavaScript (which uses special comment syntax) or WebAssembly (which uses binary sections), Lua will use special comment headers that are easy to parse.

## Key Design Decisions

### 1. Fragment Format
Lua fragments will use comment headers similar to js_of_ocaml:
```lua
--// Provides: symbol1, symbol2
--// Requires: dep1, dep2
--// Version: >= 4.14

local function symbol1()
  return dep1() + 42
end
```

### 2. Dependency Resolution Algorithm
Use Kahn's algorithm for topological sorting:
- Build dependency graph from provides/requires
- Detect cycles (error condition)
- Detect missing dependencies (report to user)
- Output fragments in correct load order

### 3. Module Loader Strategy
Generate Lua code that:
- Pre-registers all modules in `package.loaded`
- Executes fragments in dependency order
- Handles the main program last

## Phase 1: Fragment Header Parsing (80 lines)

### Task 1.1: Parse Provides Header ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `parse_provides : string -> string list`
- **Logic**:
  - Split on commas
  - Trim whitespace
  - Return list of provided symbols
- **Test**: Parse "foo, bar" → ["foo"; "bar"]
- **Status**: COMPLETED - Commit 8b5f04ed

### Task 1.2: Parse Requires Header ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `parse_requires : string -> string list`
- **Logic**: Same as parse_provides
- **Test**: Parse "baz, qux" → ["baz"; "qux"]
- **Status**: COMPLETED - Commit e13d1650

### Task 1.3: Parse Version Constraint ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~44
- **Function**: `parse_version : string -> bool`
- **Logic**:
  - Extract version string
  - Compare with `Ocaml_version.current`
  - Support operators: >=, <=, =, >, <
- **Test**: Parse ">= 4.14" with OCaml 5.2.0 → true
- **Status**: COMPLETED - Commit 032b0d16

### Task 1.4: Parse Complete Fragment Header ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~38
- **Function**: `parse_fragment_header : name:string -> string -> fragment`
- **Logic**:
  - Read lines until first non-comment
  - Extract all `--//` directives
  - Parse each directive type
  - Return complete fragment metadata
- **Test**: Parse multi-line header → complete fragment record
- **Status**: COMPLETED - Commit b595dff0

**Checkpoint**: ✅ Phase 1 Complete - All header parsing functions tested and working

## Phase 2: Dependency Graph Construction (60 lines)

### Task 2.1: Build Provides Map ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~22
- **Function**: `build_provides_map : fragment StringMap.t -> string StringMap.t`
- **Logic**:
  - Map: symbol name → fragment name
  - Iterate all fragments
  - For each provides list, map symbol → fragment
  - Detect duplicate provides (warning)
- **Test**: Two fragments providing same symbol → warning
- **Status**: COMPLETED - Commit 49980c93

### Task 2.2: Build Dependency Graph ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~25
- **Function**: `build_dep_graph : fragment StringMap.t -> string StringMap.t -> (string * StringSet.t) StringMap.t`
- **Logic**:
  - Map: fragment name → set of required fragment names
  - For each fragment's requires
  - Resolve symbol to fragment using provides_map
  - Build adjacency list
- **Test**: Fragment requiring "foo" → depends on fragment providing "foo"
- **Status**: COMPLETED - Commit 443a1cc7

### Task 2.3: Calculate In-Degrees
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `calculate_in_degrees : (string * StringSet.t) StringMap.t -> int StringMap.t`
- **Logic**:
  - Map: fragment name → count of dependencies
  - Iterate dependency graph
  - Count incoming edges for each node
- **Test**: Fragment with 2 dependents → in-degree = 2

**Checkpoint**: Dependency graph properly constructed

## Phase 3: Topological Sort (100 lines)

### Task 3.1: Implement Kahn's Algorithm
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~60
- **Function**: `topological_sort : (string * StringSet.t) StringMap.t -> int StringMap.t -> string list * string list`
- **Logic**:
  - Initialize queue with zero in-degree nodes
  - While queue not empty:
    - Dequeue node
    - Add to result list
    - For each dependent:
      - Decrement in-degree
      - If in-degree = 0, enqueue
  - If result length < total nodes → cycle detected
  - Return (sorted_list, cycle_nodes)
- **Test**: Linear deps → correct order; circular deps → cycle detected

### Task 3.2: Detect Missing Dependencies
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `find_missing_deps : fragment StringMap.t -> string StringMap.t -> StringSet.t`
- **Logic**:
  - Collect all required symbols
  - Check each against provides_map
  - Return set of missing symbols
- **Test**: Fragment requiring unknown symbol → symbol in missing set

### Task 3.3: Implement resolve_deps
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~40
- **Function**: `resolve_deps : state -> string list -> string list * string list`
- **Logic**:
  - Build provides map
  - Build dependency graph
  - Calculate in-degrees
  - Run topological sort
  - Find missing dependencies
  - Return (ordered_fragments, missing_symbols)
- **Test**: Complete integration test with multiple fragments

**Checkpoint**: Dependency resolution fully working

## Phase 4: Module Loader Generation (120 lines)

### Task 4.1: Generate Module Registration
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~30
- **Function**: `generate_module_registration : fragment -> string`
- **Logic**:
  - For each provided symbol:
    ```lua
    package.loaded["symbol"] = function()
      -- fragment code
    end
    ```
  - Wrap fragment code in function
  - Register in package.loaded
- **Test**: Single fragment → valid Lua registration code

### Task 4.2: Generate Loader Prologue
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `generate_loader_prologue : unit -> string`
- **Logic**:
  ```lua
  -- Lua_of_ocaml runtime loader
  local _runtime_modules = {}
  ```
- **Test**: Generated code is syntactically valid Lua

### Task 4.3: Generate Loader Epilogue
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `generate_loader_epilogue : fragment list -> string`
- **Logic**:
  ```lua
  -- Initialize all runtime modules
  for _, init in ipairs(_runtime_modules) do
    init()
  end
  ```
- **Test**: Generated code properly calls initializers

### Task 4.4: Complete generate_loader
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~50
- **Function**: `generate_loader : fragment list -> string`
- **Logic**:
  - Generate prologue
  - For each fragment in order:
    - Generate module registration
  - Generate epilogue
  - Concatenate all parts
  - Return complete loader code
- **Test**: Multiple fragments → complete, valid Lua loader

**Checkpoint**: Module loader generation complete

## Phase 5: Linking Integration (60 lines)

### Task 5.1: Handle linkall Flag
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `select_fragments : state -> linkall:bool -> string list -> fragment list`
- **Logic**:
  - If linkall=true: return all fragments
  - Otherwise: return only resolved dependencies
  - Apply version constraints
  - Filter by target environment
- **Test**: linkall=true → all fragments; linkall=false → only needed

### Task 5.2: Implement Complete link Function
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~40
- **Function**: `link : state:state -> program:Lua_ast.stat list -> linkall:bool -> Lua_ast.stat list`
- **Logic**:
  - Select fragments based on linkall
  - Resolve dependencies
  - Sort topologically
  - Generate loader code
  - Convert loader string to Lua_ast.Comment or Lua_ast.Chunk
  - Prepend loader to program
  - Return linked program
- **Test**: Link empty program → loader + program; link with deps → correct order

**Checkpoint**: Complete linking pipeline working

## Phase 6: Error Handling and Edge Cases (80 lines)

### Task 6.1: Circular Dependency Detection
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `format_cycle_error : string list -> string`
- **Logic**:
  - Format cycle for user-friendly error
  - Show chain: A → B → C → A
  - Include fragment locations
- **Test**: Circular deps → clear error message

### Task 6.2: Missing Dependency Reporting
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `format_missing_error : StringSet.t -> string`
- **Logic**:
  - List all missing symbols
  - Show which fragments require them
  - Suggest possible solutions
- **Test**: Missing deps → helpful error message

### Task 6.3: Duplicate Provides Handling
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `check_duplicate_provides : fragment StringMap.t -> unit`
- **Logic**:
  - Check for symbols provided by multiple fragments
  - Issue warnings with locations
  - Later fragments override earlier ones
- **Test**: Duplicate provides → warning with both locations

### Task 6.4: Version Constraint Validation
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `check_version_constraints : fragment -> bool`
- **Logic**:
  - Parse version constraint
  - Compare with current OCaml version
  - Return true if constraint satisfied
- **Test**: Various version constraints → correct filtering

**Checkpoint**: All error cases handled gracefully

## Phase 7: Testing (Complete Coverage)

### Task 7.1: Unit Tests for Header Parsing
- **File**: `compiler/tests-lua/test_module_linking.ml`
- **Tests**:
  - Parse empty headers
  - Parse single provides/requires
  - Parse multiple provides/requires
  - Parse version constraints
  - Parse malformed headers (error cases)

### Task 7.2: Unit Tests for Dependency Resolution
- **File**: `compiler/tests-lua/test_module_linking.ml`
- **Tests**:
  - Simple linear dependencies
  - Complex DAG dependencies
  - Circular dependencies (should fail)
  - Missing dependencies (should report)
  - Multiple entry points

### Task 7.3: Unit Tests for Loader Generation
- **File**: `compiler/tests-lua/test_module_linking.ml`
- **Tests**:
  - Single fragment loader
  - Multiple fragment loader
  - Loader with dependencies
  - Verify generated Lua is syntactically valid
  - Verify registration order

### Task 7.4: Integration Tests
- **File**: `compiler/tests-lua/test_module_linking.ml`
- **Tests**:
  - Complete link with empty program
  - Complete link with linkall=true
  - Complete link with linkall=false
  - Link with complex dependency tree
  - Link with runtime directory loading

**Checkpoint**: All tests passing

## Implementation Order

### Step-by-step execution plan:

1. **Phase 1** (80 lines): Implement header parsing
   - Start with simple string parsing
   - Test each function independently
   - Commit: "feat: Add Lua fragment header parsing"

2. **Phase 2** (60 lines): Build dependency graph
   - Create data structures
   - Test graph construction
   - Commit: "feat: Add dependency graph construction"

3. **Phase 3** (100 lines): Topological sort
   - Implement Kahn's algorithm
   - Add cycle detection
   - Add missing dep detection
   - Commit: "feat: Add topological sort for dependency resolution"

4. **Phase 4** (120 lines): Loader generation
   - Generate Lua module registration code
   - Build complete loader
   - Commit: "feat: Add Lua module loader generation"

5. **Phase 5** (60 lines): Integration
   - Connect all pieces
   - Implement link function
   - Commit: "feat: Integrate module linking pipeline"

6. **Phase 6** (80 lines): Error handling
   - Add all error cases
   - Format error messages
   - Commit: "feat: Add comprehensive error handling for linker"

7. **Phase 7** (Testing): Complete test coverage
   - All unit tests
   - All integration tests
   - Commit: "test: Add comprehensive module linking tests"

## Total Estimated Lines: 500 lines

- Phase 1: 80 lines (header parsing)
- Phase 2: 60 lines (graph construction)
- Phase 3: 100 lines (topological sort)
- Phase 4: 120 lines (loader generation)
- Phase 5: 60 lines (integration)
- Phase 6: 80 lines (error handling)
- Tests: Additional lines in test file

## File Structure

```
compiler/lib-lua/
  lua_link.ml        (main implementation: ~500 lines)
  lua_link.mli       (interface: already exists)

compiler/tests-lua/
  test_module_linking.ml  (tests: ~400 lines)
```

## Key Dependencies

- `Js_of_ocaml_compiler.Stdlib` - StringMap, StringSet, labeled arguments
- `Ocaml_version` - Version constraint checking
- `Lua_ast` - AST types for Lua output

## Success Criteria

1. ✅ All fragment headers parse correctly
2. ✅ Dependency graph builds correctly
3. ✅ Topological sort produces correct order
4. ✅ Circular dependencies detected and reported
5. ✅ Missing dependencies detected and reported
6. ✅ Module loader generates valid Lua code
7. ✅ Integration with main compilation pipeline works
8. ✅ All tests pass
9. ✅ No compiler warnings
10. ✅ Follows js_of_ocaml code style

## References

- `compiler/lib/linker.ml` - 802 lines, Fragment module, dependency resolution
- `compiler/lib-wasm/wasm_link.ml` - 2460 lines, binary linking, import resolution
- Kahn's algorithm: https://en.wikipedia.org/wiki/Topological_sorting#Kahn's_algorithm
- Lua modules: https://www.lua.org/manual/5.4/manual.html#6.3

## Notes

- Keep each phase under 150 lines to maintain code clarity
- Test after each phase before proceeding
- Follow js_of_ocaml patterns for consistency
- Use labeled arguments throughout (following Stdlib conventions)
- Handle all error cases explicitly (no failwith "TODO")
- Comment complex algorithms (especially topological sort)
