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

### Task 2.3: Calculate In-Degrees ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `calculate_in_degrees : (string * StringSet.t) StringMap.t -> int StringMap.t`
- **Logic**:
  - Map: fragment name → count of dependencies
  - Iterate dependency graph
  - Count incoming edges for each node
- **Test**: Fragment with 2 dependents → in-degree = 2
- **Status**: COMPLETED - Commit f2b3c1c7

**Checkpoint**: ✅ Phase 2 Complete - Dependency graph properly constructed

## Phase 3: Topological Sort (100 lines)

### Task 3.1: Implement Kahn's Algorithm ✅
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
- **Status**: COMPLETED - Commit 667d96e8

### Task 3.2: Detect Missing Dependencies ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~20
- **Function**: `find_missing_deps : fragment StringMap.t -> string StringMap.t -> StringSet.t`
- **Logic**:
  - Collect all required symbols
  - Check each against provides_map
  - Return set of missing symbols
- **Test**: Fragment requiring unknown symbol → symbol in missing set
- **Status**: COMPLETED - Commit b645006f

### Task 3.3: Implement resolve_deps ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~56
- **Function**: `resolve_deps : state -> string list -> string list * string list`
- **Logic**:
  - Build provides map
  - Find fragments providing required symbols
  - Build dependency graph
  - Calculate in-degrees
  - Collect all needed fragments (required + transitive dependencies)
  - Filter graph to only include needed fragments
  - Run topological sort
  - Find missing dependencies
  - Return (ordered_fragments, missing_symbols)
- **Test**: Complete integration test with multiple fragments
- **Status**: COMPLETED - Commit 6d7aa5bd

**Checkpoint**: ✅ Dependency resolution fully working

## Phase 4: Module Loader Generation (120 lines)

### Task 4.1: Generate Module Registration ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~25
- **Function**: `generate_module_registration : fragment -> string`
- **Logic**:
  - Add comment header with fragment name
  - For each provided symbol:
    ```lua
    package.loaded["symbol"] = function()
      -- fragment code (indented)
    end
    ```
  - Wrap fragment code in function
  - Indent fragment code by 2 spaces
  - Register in package.loaded
- **Test**: Single fragment → valid Lua registration code
- **Status**: COMPLETED - Commit 0c9e104e

### Task 4.2: Generate Loader Prologue ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~7
- **Function**: `generate_loader_prologue : unit -> string`
- **Logic**:
  ```lua
  -- Lua_of_ocaml runtime loader
  -- This code registers runtime modules in package.loaded

  ```
- **Test**: Generated code is syntactically valid Lua
- **Status**: COMPLETED - Commit 0fe7e57b

### Task 4.3: Generate Loader Epilogue ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~5
- **Function**: `generate_loader_epilogue : fragment list -> string`
- **Logic**:
  ```lua

  -- End of runtime loader
  ```
- **Test**: Generated code provides proper closing comment
- **Status**: COMPLETED - Commit ea1f2c5d

### Task 4.4: Complete generate_loader ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~15
- **Function**: `generate_loader : fragment list -> string`
- **Logic**:
  - Generate prologue
  - For each fragment in order:
    - Generate module registration
  - Generate epilogue
  - Concatenate all parts
  - Return complete loader code
- **Test**: Multiple fragments → complete, valid Lua loader
- **Status**: COMPLETED - Commit 44e3bec2

**Checkpoint**: ✅ Module loader generation complete

## Phase 5: Linking Integration (60 lines)

### Task 5.1: Handle linkall Flag ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~12
- **Function**: `select_fragments : state -> linkall:bool -> string list -> fragment list`
- **Logic**:
  - If linkall=true: return all fragments
  - Otherwise: return only resolved dependencies using resolve_deps
  - Converts fragment names to fragments in dependency order
  - Version constraints already applied during fragment parsing
- **Test**: linkall=true → all fragments; linkall=false → only needed
- **Status**: COMPLETED - Commit 78c82d16

### Task 5.2: Implement Complete link Function ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~6 (efficient implementation reusing existing functions)
- **Function**: `link : state:state -> program:Lua_ast.stat list -> linkall:bool -> Lua_ast.stat list`
- **Logic**:
  - Select fragments based on linkall (via select_fragments)
  - Resolve dependencies (inside select_fragments → resolve_deps)
  - Sort topologically (inside resolve_deps → topological_sort)
  - Generate loader code (via generate_loader)
  - Convert loader string to Lua_ast.Comment
  - Prepend loader to program
  - Return linked program
- **Test**: Link empty program → loader + program; link with deps → correct order
- **Status**: COMPLETED - Commit f65558d3

**Checkpoint**: ✅ Complete linking pipeline working

## Phase 6: Error Handling and Edge Cases (80 lines)

### Task 6.1: Circular Dependency Detection ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~16
- **Function**: `format_cycle_error : string list -> string`
- **Logic**:
  - Format cycle for user-friendly error message
  - Show chain: A → B → C → ...
  - Returns empty string if no cycles
  - Updated resolve_deps to check for cycles and raise Failure with formatted message
- **Test**: Circular deps → clear error message
- **Status**: COMPLETED - Commit 4989d7f2

### Task 6.2: Missing Dependency Reporting ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~28
- **Function**: `format_missing_error : StringSet.t -> fragment StringMap.t -> string`
- **Logic**:
  - List all missing symbols
  - Show which fragments require them (iterates fragments to find requirers)
  - Suggest possible solutions (add fragments, check typos, load runtime files)
  - Updated resolve_deps to check for missing dependencies and raise Failure
- **Test**: Missing deps → helpful error message
- **Status**: COMPLETED - Commit 2c91839b

### Task 6.3: Duplicate Provides Handling ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~30
- **Function**: `check_duplicate_provides : fragment StringMap.t -> unit`
- **Logic**:
  - Build map from symbol to list of fragments providing it
  - Check each symbol for duplicates (2+ providers)
  - Issue warnings listing all providers for duplicate symbols
  - Updated build_provides_map to use last provider (override behavior)
  - Called from resolve_deps to ensure warnings are issued
- **Test**: Duplicate provides → warning with all fragment names
- **Status**: COMPLETED - Commit 0d64ced0

### Task 6.4: Version Constraint Validation ✅
- **File**: `compiler/lib-lua/lua_link.ml`
- **Lines**: ~25
- **Function**: `check_version_constraints : fragment -> bool`
- **Logic**:
  - Re-parse version constraints from fragment code
  - Check each "--// Version:" directive using parse_version
  - Return false if any constraint fails
  - Return true if all constraints satisfied or no constraints found
  - Stops at first non-comment line
- **Test**: Various version constraints → correct filtering
- **Status**: COMPLETED - Commit a0005ec5

**Checkpoint**: ✅ All error cases handled gracefully

## Phase 7: Testing (Complete Coverage)

### Task 7.1: Unit Tests for Header Parsing ✅
- **File**: `compiler/tests-lua/test_module_linking.ml`
- **Tests**:
  - Parse empty headers
  - Parse single provides/requires
  - Parse multiple provides/requires
  - Parse version constraints
  - Parse malformed headers (error cases)
  - Empty code and code without headers
  - Mixed header types and duplicate headers
  - Trailing/leading commas in symbol lists
  - Case sensitivity in header directives
  - Header parsing stops at first code line
- **Status**: COMPLETED - Commit 52a5c9dc

### Task 7.2: Unit Tests for Dependency Resolution ✅
- **File**: `compiler/tests-lua/test_module_linking.ml`
- **Tests**:
  - Simple linear dependency chains (a→b→c→d)
  - Complex DAG with multiple paths and shared dependencies
  - Multiple independent entry points
  - Deep DAG (7 levels) to verify algorithm handles depth
  - Wide DAG (many parallel dependencies)
  - Circular dependencies with multiple entry points (should fail)
  - Missing dependencies across multiple entry points (should report)
  - Partial satisfaction (some satisfied, some missing)
  - Empty requirements (should return empty list)
- **Status**: COMPLETED - Commit 228da76f

### Task 7.3: Unit Tests for Loader Generation ✅
- **File**: `compiler/tests-lua/test_module_linking.ml`
- **Tests**:
  - Single fragment with single symbol (basic structure)
  - Multiple fragments in dependency order
  - Fragment with multiple symbols (all registered)
  - Lua syntax validity verification (keywords, operators)
  - Registration order with complex DAG
  - Empty fragments list produces minimal loader
  - Code indentation preservation
  - Special characters handling (quotes, backslashes, digits)
  - Large fragment set (10 fragments)
  - Registration happens before code execution
- **Status**: COMPLETED - Commit 3e7088c2

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
