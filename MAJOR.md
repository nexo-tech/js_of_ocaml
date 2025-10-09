# MAJOR BLOCKER: Lua 200 Local Variable Limit

**Status**: CRITICAL - Blocks all real-world programs
**Created**: 2025-10-09
**Target**: Complete resolution in 1 session (~4 hours)

## Master Checklist

### Phase 0: Preparation (~30 min, ~50 lines)
- [x] Task 0.1: Add Variable Count Analysis (~15 min)
- [x] Task 0.2: Create Variable Table Utilities (~15 min)

### Phase 1: Modify Variable Access (~1 hour, ~100 lines)
- [x] Task 1.1: Thread Table Mode Through Context (~20 min)
- [x] Task 1.2: Update Variable References (~20 min)
- [x] Task 1.3: Update Variable Hoisting Logic (~20 min)

### Phase 2: Handle Nested Functions (~45 min, ~60 lines)
- [x] Task 2.1: Propagate Table Mode to Closures (~25 min)
- [x] Task 2.2: Handle Variable Capture (~20 min)

### Phase 3: Testing & Validation (~1.5 hours, ~150 lines)
- [x] Task 3.1: Create Table-Based Variable Tests (~40 min)
- [ ] Task 3.2: Test Real-World Examples (~30 min)
- [ ] Task 3.3: Benchmark Performance Impact (~20 min)

### Phase 4: Documentation & Cleanup (~30 min, ~40 lines)
- [ ] Task 4.1: Update Phase 0 Documentation (~10 min)
- [ ] Task 4.2: Add Implementation Comments (~10 min)
- [ ] Task 4.3: Update CLAUDE.md Gotchas (~10 min)

---

## Problem Statement

Lua has a hard limit of **200 local variables per function**. Phase 0's variable hoisting (Tasks 0.1-0.6) successfully fixed the goto/scope issue but introduced a new blocker:

**Current behavior**:
```lua
function __caml_init_chunk_0()
  -- Hoisted variables (1130 total, split into 8 chunks)
  do
    local v0, v1, v2, ... v149  -- 150 vars
  end
  do
    local v150, v151, ... v299  -- 150 vars
  end
  -- ERROR: Lua counts ALL locals in function = 1130 > 200 limit
  ::block_0::
  ...
end
```

**Root cause**: Splitting `local` declarations across `do...end` blocks doesn't help because Lua counts **all locals in the entire function**, not per block.

**Impact**:
- ❌ hello_lua fails: 1130 variables
- ❌ minimal_exec fails: 617 variables
- ❌ All stdlib-using programs fail
- ✅ Only trivial programs (<200 vars) work

## Solution: Table-Based Variable Storage

When a function needs >200 variables, use a **variables table** instead of locals:

**Before (current - fails)**:
```lua
function foo()
  local v0, v1, v2, ... v300  -- ERROR: >200 limit
  ::block_0::
  v0 = 42
  return v0
end
```

**After (table-based - works)**:
```lua
function foo()
  local _V = {}  -- Single local table
  ::block_0::
  _V.v0 = 42     -- Table field access
  return _V.v0
end
```

**Hybrid approach** (best performance):
- Use locals for functions with ≤180 variables (safe margin)
- Use table for functions with >180 variables
- Keep exception names (Out_of_memory, etc.) as locals for readability

## Implementation Plan

### Phase 0: Preparation (~30 min, ~50 lines)

#### Task 0.1: Add Variable Count Analysis
- **File**: `compiler/lib-lua/lua_generate.ml`
- **Changes**:
  - Add function `should_use_var_table : int -> bool`
  - Returns `true` if var_count > 180 (safety margin for other locals)
  - Document threshold rationale

#### Task 0.2: Create Variable Table Utilities
- **File**: `compiler/lib-lua/lua_generate.ml`
- **Changes**:
  - Add `var_table_name = "_V"` constant
  - Add `make_var_table_access : string -> L.expr` helper
  - Returns `L.Field (L.Ident "_V", field_name)`
  - Add `make_var_table_assign : string -> L.expr -> L.stat` helper
  - Returns `L.Assign ([L.Field (L.Ident "_V", field_name)], [expr])`

### Phase 1: Modify Variable Access (~1 hour, ~100 lines)

#### Task 1.1: Thread Table Mode Through Context
- **File**: `compiler/lib-lua/lua_generate.ml`
- **Changes**:
  - Add `use_var_table : bool` field to `ctx` record
  - Update `var_name` function to check `ctx.use_var_table`
  - If true, return table access; if false, return identifier
  - Update all `ctx` creation sites

#### Task 1.2: Update Variable References
- **File**: `compiler/lib-lua/lua_generate.ml`
- **Changes**:
  - Modify `generate_instr` for `Let` instruction:
    - Check `ctx.use_var_table`
    - If true: generate `_V.vN = expr` assignment
    - If false: keep current `local vN = expr` (error - shouldn't happen in hoisted code)
  - Modify `generate_instr` for `Assign` instruction:
    - Check `ctx.use_var_table`
    - If true: generate `_V.vN = expr`
    - If false: generate `vN = expr`

#### Task 1.3: Update Variable Hoisting Logic
- **File**: `compiler/lib-lua/lua_generate.ml`
- **Changes**:
  - Modify `compile_blocks_with_labels`:
    - Count hoisted variables
    - If count > 180, set `ctx.use_var_table = true`
    - Generate `local _V = {}` instead of `local v0, v1, ...`
    - If count ≤ 180, keep current local declarations
  - Keep exception names as locals regardless (special case)

### Phase 2: Handle Nested Functions (~45 min, ~60 lines)

#### Task 2.1: Propagate Table Mode to Closures
- **File**: `compiler/lib-lua/lua_generate.ml`
- **Changes**:
  - Modify `generate_expr` for `Closure` expressions:
    - Create new context for closure body
    - Run variable collection on closure blocks
    - Set `use_var_table` independently for each closure
    - Each function gets its own `_V` table if needed

#### Task 2.2: Handle Variable Capture
- **File**: `compiler/lib-lua/lua_generate.ml`
- **Changes**:
  - Document that table-based storage actually simplifies captures
  - Parent function's `_V` table is captured automatically (upvalue)
  - No special handling needed - Lua's upvalue system works with tables
  - Add test case for nested functions with >180 vars each

### Phase 3: Testing & Validation (~1.5 hours, ~150 lines)

#### Task 3.1: Create Table-Based Variable Tests
- **File**: `compiler/tests-lua/test_variable_table.ml` (NEW)
- **Tests**:
  - `small_function_uses_locals`: 50 vars → verify uses `local v0, v1...`
  - `large_function_uses_table`: 250 vars → verify uses `local _V = {}`
  - `table_access_correctness`: verify `_V.v0 = 42; return _V.v0` works
  - `nested_functions_independent`: outer 250 vars, inner 250 vars → each gets own `_V`
  - `mixed_table_and_locals`: verify exceptions remain as locals even in table mode

#### Task 3.2: Test Real-World Examples
- **Tests**:
  - Rebuild `examples/hello_lua/hello.bc.lua`
  - Run with `lua hello.bc.lua`
  - Expected: "Hello from Lua_of_ocaml!" printed
  - Verify generated code uses `_V` table
  - Count variables in generated code

#### Task 3.3: Benchmark Performance Impact
- **File**: `compiler/tests-lua/bench_lua_generate.ml`
- **Changes**:
  - Add benchmark for table-based variable access
  - Compare performance: locals vs table
  - Document acceptable overhead (<20% for table access)
  - Verify compilation time still <10ms

### Phase 4: Documentation & Cleanup (~30 min, ~40 lines)

#### Task 4.1: Update Phase 0 Documentation
- **File**: `SELF_HOSTING.md`
- **Changes**:
  - Document table-based solution in Phase 0 summary
  - Explain 180-variable threshold
  - Note hybrid approach for optimal performance

#### Task 4.2: Add Implementation Comments
- **File**: `compiler/lib-lua/lua_generate.ml`
- **Changes**:
  - Document `_V` table approach at module level
  - Explain why 180 threshold (200 limit - 20 buffer)
  - Add examples in comments showing both modes

#### Task 4.3: Update CLAUDE.md Gotchas
- **File**: `CLAUDE.md`
- **Changes**:
  - Add "Lua 200 Local Variable Limit" to Common Gotchas
  - Explain table-based solution
  - Document threshold and tradeoffs

## Success Criteria

- ✅ Functions with ≤180 variables use locals (fast)
- ✅ Functions with >180 variables use `_V` table (works)
- ✅ hello_lua compiles and runs successfully
- ✅ minimal_exec compiles and runs successfully
- ✅ All test_execution.ml tests still pass
- ✅ All test_variable_table.ml tests pass (NEW)
- ✅ Performance acceptable (<20% overhead for table mode)
- ✅ No compilation warnings
- ✅ All code documented and committed

## Technical Details

### Variable Table Structure

```lua
-- Table-based variable storage for functions with >180 vars
local _V = {}

::block_0::
-- Assignments become table field updates
_V.v0 = 42
_V.v1 = 100
_V.v2 = _V.v0 + _V.v1

-- Exception names stay as locals for readability
local Out_of_memory = {tag = 248, "Out_of_memory", -1}

-- Function calls work naturally
_V.v3 = some_function(_V.v2)

-- Returns work naturally
return _V.v0
```

### Performance Tradeoffs

**Locals (≤180 vars)**:
- ✅ Fastest (direct register access)
- ✅ LuaJIT optimizes well
- ❌ Hard 200 variable limit

**Table (_V for >180 vars)**:
- ✅ No variable limit (unlimited fields)
- ✅ Works with all Lua versions
- ❌ ~10-20% slower (table hash lookup)
- ✅ Still fast enough for compiler use

**Hybrid approach** gives us best of both worlds:
- Small functions stay fast with locals
- Large functions work correctly with table
- 180 threshold provides safety margin

### Why 180 Threshold?

- Lua hard limit: 200 locals
- Our hoisted vars: `local _V, Out_of_memory, Failure, ...` (~12 exception names)
- Other locals: loop vars, temps, parameters (~8)
- Safety margin: 20 variables
- **Threshold: 200 - 20 = 180 hoisted vars**

If hoisted vars > 180 → use table mode

### IR Impact

No IR changes needed! This is purely a code generation strategy:
- IR still uses `Code.Let` and `Code.Assign`
- Code generator decides locals vs table based on count
- Each function analyzed independently

## Timeline

- **Task 0.1-0.2**: 30 min (utilities)
- **Task 1.1-1.3**: 1 hour (core implementation)
- **Task 2.1-2.2**: 45 min (nested functions)
- **Task 3.1-3.3**: 1.5 hours (testing)
- **Task 4.1-4.3**: 30 min (documentation)
- **Total**: ~4 hours for complete resolution

## Implementation Order

1. ✅ Start with Task 0.1 (analysis)
2. ✅ Task 0.2 (utilities)
3. ✅ Task 1.1 (context threading)
4. ✅ Task 1.2 (variable references)
5. ✅ Task 1.3 (hoisting logic) - **CRITICAL PATH**
6. ✅ Task 3.1 (tests) - validate before proceeding
7. ✅ Task 3.2 (real-world examples) - **GATE CHECK**
8. ✅ Task 2.1-2.2 (nested functions)
9. ✅ Task 3.3 (benchmarks)
10. ✅ Task 4.1-4.3 (documentation & cleanup)

## Checklist

### Phase 0: Preparation
- [ ] Task 0.1: Add Variable Count Analysis (~15 min)
- [ ] Task 0.2: Create Variable Table Utilities (~15 min)

### Phase 1: Modify Variable Access
- [ ] Task 1.1: Thread Table Mode Through Context (~20 min)
- [ ] Task 1.2: Update Variable References (~20 min)
- [ ] Task 1.3: Update Variable Hoisting Logic (~20 min)

### Phase 2: Handle Nested Functions
- [ ] Task 2.1: Propagate Table Mode to Closures (~25 min)
- [ ] Task 2.2: Handle Variable Capture (~20 min)

### Phase 3: Testing & Validation
- [ ] Task 3.1: Create Table-Based Variable Tests (~40 min)
- [ ] Task 3.2: Test Real-World Examples (~30 min)
- [ ] Task 3.3: Benchmark Performance Impact (~20 min)

### Phase 4: Documentation & Cleanup
- [ ] Task 4.1: Update Phase 0 Documentation (~10 min)
- [ ] Task 4.2: Add Implementation Comments (~10 min)
- [ ] Task 4.3: Update CLAUDE.md Gotchas (~10 min)

## Notes

- This is a **CRITICAL** blocker - nothing works without this fix
- Table-based approach is proven (used by other Lua compilers)
- 180 threshold balances performance vs correctness
- Each function independently decides locals vs table
- No changes to IR or runtime - pure code generation
