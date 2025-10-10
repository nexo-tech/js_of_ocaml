# Lua Runtime Primitives - Implementation Guide

This document catalogs all OCaml runtime primitives for lua_of_ocaml, their implementation status, and tracks what remains to be implemented.

## Architecture Overview

### Module-Based Runtime with Linking

Lua_of_ocaml uses a **module-based runtime** that gets **transformed and inlined** into generated code. This approach provides:

- ✅ **Zero code duplication**: Runtime modules maintain `M.*` pattern for testing
- ✅ **Automatic linking**: Hybrid naming convention + Export directive resolution
- ✅ **Self-contained output**: Generated Lua files embed only needed primitives
- ✅ **Performance**: Zero-overhead wrapper functions via naming convention

**How It Works** (see LINKING.md for details):

```
OCaml Bytecode → IR → Lua AST (calls caml_* functions)
                           ↓
                    Linking Phase:
                    1. Track used primitives
                    2. Load runtime modules
                    3. Resolve via naming convention or Export directive
                    4. Embed modules + generate wrappers
                           ↓
Final Lua Code:
  -- Runtime modules embedded
  local M = {}
  function M.make(...) ... end
  local Array = M

  -- Global wrappers generated
  function caml_array_make(...)
    return Array.make(...)
  end

  -- Program code
  local v0 = caml_array_make(10, 0)
```

### Hybrid Primitive Resolution

**Primary: Naming Convention** (90% of primitives, zero annotations)

```
caml_<module>_<function> → <module>.lua exports M.<function>
```

Examples:
- `caml_array_make` → `array.lua`, `M.make` ✓
- `caml_weak_create` → `weak.lua`, `M.create` ✓
- `caml_int_compare` → `compare.lua`, `M.int_compare` ✓

**Fallback: Export Directive** (10% of primitives, explicit annotations)

For primitives that don't follow naming convention:

```lua
--// Export: create as caml_create_bytes
--// Export: create as caml_create_string
```

Examples:
- `caml_ml_open_descriptor_in` → needs Export (prefix mismatch)
- `caml_create_bytes` and `caml_create_string` → both map to `mlBytes.lua`, `M.create` (aliasing)

---

## Master Checklist

### Category Status Summary

| Category | Total | Resolvable | Unresolvable | % Complete |
|----------|-------|------------|--------------|------------|
| Global/Registry | 1 | 0 | 1 | 0% |
| Integer Comparison | 3 | 3 | 0 | 100% ✓ |
| Float Operations | 1 | 1 | 0 | 100% ✓ |
| String Operations | 6 | 0 | 6 | 0% |
| Bytes Operations | 6 | 0 | 6 | 0% |
| Array Operations | 11 | 8 | 3 | 73% |
| Float Array | 2 | 0 | 2 | 0% |
| References | 1 | 0 | 1 | 0% |
| I/O Channels | 30 | 0 | 30 | 0% |
| Marshal | 3 | 0 | 3 | 0% |
| System | 2 | 2 | 0 | 100% ✓ |
| Weak References | 3 | 3 | 0 | 100% ✓ |
| Special/Internal | 2 | 2 | 0 | 100% ✓ |
| **TOTAL** | **72** | **19** | **53** | **26%** |

### Implementation Phases

**Phase 1: Core Infrastructure** (COMPLETE ✓)
- [x] Linking system with hybrid resolution (LINKING.md)
- [x] Naming convention resolver (caml_X_Y → X.lua, M.Y)
- [x] Export directive parser
- [x] Module embedding and wrapper generation

**Phase 2: Core Primitives** (PARTIAL - 10/17 = 59%)
- [x] Comparison primitives (int, float)
- [x] Weak references (create, set, get)
- [x] System stubs (open, close)
- [x] Special/Internal (closure, special)
- [ ] String operations (0/6)
- [ ] Bytes operations (0/6)
- [ ] Reference operations (0/1)

**Phase 3: Array Primitives** (PARTIAL - 8/13 = 62%)
- [x] Basic array operations (make, set, unsafe_set, sub, append, concat, blit, fill)
- [ ] Array operation aliases (make_vect)
- [ ] Float array operations (0/4)

**Phase 4: I/O Primitives** (0/30 = 0%)
- [ ] Descriptor operations
- [ ] Channel operations
- [ ] Input/Output operations
- [ ] Position/Seek operations

**Phase 5: Advanced Primitives** (0/4 = 0%)
- [ ] Marshal operations (0/3)
- [ ] Global registry (0/1)

---

## Detailed Primitive Catalog

### Global/Registry Operations (0/1 = 0%)

| Primitive | Status | Resolution | Action Needed |
|-----------|--------|------------|---------------|
| `caml_register_global` | ❌ Unresolvable | Inline | Add to inline runtime or core.lua with Export |

**Why Unresolvable**: Not in any module currently. Special primitive inlined in generated code.

**Implementation Options**:
1. Keep as inline runtime (current approach, works)
2. Add to `core.lua` with `--// Export: register_global as caml_register_global`

**Priority**: LOW (already working via inline runtime)

---

### Integer Comparison (3/3 = 100% ✓)

| Primitive | Status | Runtime Module | Function |
|-----------|--------|----------------|----------|
| `caml_int_compare` | ✅ Resolved | `compare.lua` | `M.int_compare` |
| `caml_int32_compare` | ✅ Resolved | `compare.lua` | `M.int_compare` (Export alias) |
| `caml_nativeint_compare` | ✅ Resolved | `compare.lua` | `M.int_compare` (Export alias) |

**Status**: COMPLETE ✓ (LINKING.md Task 3.1)

**Implementation**: `runtime/lua/compare.lua` with Export directives for aliases.

**Calling Convention**: `compare(a, b)` → `-1` (a < b), `0` (a == b), `1` (a > b)

---

### Float Operations (1/1 = 100% ✓)

| Primitive | Status | Runtime Module | Function |
|-----------|--------|----------------|----------|
| `caml_float_compare` | ✅ Resolved | `float.lua` | `M.compare` |

**Status**: COMPLETE ✓

**Implementation**: `runtime/lua/float.lua` exports `M.compare` with NaN handling.

**Special Handling**: NaN != NaN in OCaml semantics.

---

### String Operations (0/6 = 0%)

| Primitive | Status | Runtime Module | Action Needed |
|-----------|--------|----------------|---------------|
| `caml_string_compare` | ❌ Unresolvable | `mlBytes.lua`? | Add Export directive |
| `caml_string_get` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `get as caml_string_get` |
| `caml_string_set` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `set as caml_string_set` |
| `caml_string_unsafe_set` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `unsafe_set as caml_string_unsafe_set` |
| `caml_create_string` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `create as caml_create_string` |
| `caml_blit_string` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `blit as caml_blit_string` |

**Why Unresolvable**: Naming convention looks for `string.lua` but OCaml strings are immutable (implementation in `mlBytes.lua`).

**Action Required**: Add Export directives to `runtime/lua/mlBytes.lua`:

```lua
--// Export: compare as caml_string_compare
--// Export: get as caml_string_get
--// Export: set as caml_string_set
--// Export: unsafe_set as caml_string_unsafe_set
--// Export: create as caml_create_string
--// Export: blit as caml_blit_string
```

**Priority**: HIGH (needed for string operations in hello_lua)

**Estimated Work**: ~10 lines of Export directives (if functions already exist)

---

### Bytes Operations (0/6 = 0%)

| Primitive | Status | Runtime Module | Action Needed |
|-----------|--------|----------------|---------------|
| `caml_bytes_get` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `get as caml_bytes_get` |
| `caml_bytes_set` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `set as caml_bytes_set` |
| `caml_bytes_unsafe_set` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `unsafe_set as caml_bytes_unsafe_set` |
| `caml_create_bytes` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `create as caml_create_bytes` |
| `caml_fill_bytes` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `fill as caml_fill_bytes` |
| `caml_blit_bytes` | ❌ Unresolvable | `mlBytes.lua` | Add Export: `blit as caml_blit_bytes` |

**Why Unresolvable**: Naming convention looks for `bytes.lua` but implementation is in `mlBytes.lua`.

**Action Required**: Add Export directives to `runtime/lua/mlBytes.lua`:

```lua
--// Export: get as caml_bytes_get
--// Export: set as caml_bytes_set
--// Export: unsafe_set as caml_bytes_unsafe_set
--// Export: create as caml_create_bytes
--// Export: fill as caml_fill_bytes
--// Export: blit as caml_blit_bytes
```

**Note**: Some exports may overlap with string operations if `mlBytes.lua` handles both.

**Priority**: HIGH (needed for bytes operations)

**Estimated Work**: ~10 lines of Export directives

---

### Array Operations (8/11 = 73%)

| Primitive | Status | Runtime Module | Function | Action Needed |
|-----------|--------|----------------|----------|---------------|
| `caml_array_set` | ✅ Resolved | `array.lua` | `M.set` | None |
| `caml_array_unsafe_set` | ✅ Resolved | `array.lua` | `M.unsafe_set` | None |
| `caml_make_vect` | ❌ Unresolvable | `array.lua` | - | Add Export: `make as caml_make_vect` |
| `caml_array_make` | ✅ Resolved | `array.lua` | `M.make` | None |
| `caml_make_float_vect` | ❌ Unresolvable | `array.lua` | - | Implement `M.make_float_vect` or Export alias |
| `caml_floatarray_create` | ❌ Unresolvable | `array.lua` | - | Implement `M.floatarray_create` |
| `caml_array_sub` | ✅ Resolved | `array.lua` | `M.sub` | None |
| `caml_array_append` | ✅ Resolved | `array.lua` | `M.append` | None |
| `caml_array_concat` | ✅ Resolved | `array.lua` | `M.concat` | None |
| `caml_array_blit` | ✅ Resolved | `array.lua` | `M.blit` | None |
| `caml_array_fill` | ✅ Resolved | `array.lua` | `M.fill` | None |

**Action Required**:

1. Add Export directive to `runtime/lua/array.lua`:
   ```lua
   --// Export: make as caml_make_vect
   ```

2. Check if `make_float_vect` and `floatarray_create` exist. If not, implement or add Export aliases.

**Priority**: MEDIUM (most array operations work)

**Estimated Work**: ~5 lines Export directives + possibly 10-20 lines implementation

---

### Float Array Operations (0/2 = 0%)

| Primitive | Status | Runtime Module | Action Needed |
|-----------|--------|----------------|---------------|
| `caml_floatarray_set` | ❌ Unresolvable | `array.lua` | Implement or add Export |
| `caml_floatarray_unsafe_set` | ❌ Unresolvable | `array.lua` | Implement or add Export |

**Why Unresolvable**: Naming convention looks for `floatarray.lua` (doesn't exist).

**Action Required**: Add Export directives to `runtime/lua/array.lua` (if functions exist) OR implement float array functions.

**Priority**: LOW (specialized feature)

**Estimated Work**: ~10-30 lines depending on existing implementation

---

### Reference Operations (0/1 = 0%)

| Primitive | Status | Runtime Module | Action Needed |
|-----------|--------|----------------|---------------|
| `caml_ref_set` | ❌ Unresolvable | `core.lua` | Implement `M.ref_set` |

**Why Unresolvable**: No `ref.lua` module, not in `core.lua`.

**Action Required**: Add to `runtime/lua/core.lua`:

```lua
function M.ref_set(ref, value)
  -- References are {tag=0, [1]=value}
  ref[1] = value
end
```

**Priority**: HIGH (basic operation)

**Estimated Work**: ~5 lines

---

### I/O Channel Operations (0/30 = 0%)

All 30 I/O primitives are **unresolvable** because they use `caml_ml_*` prefix which doesn't match the `io.lua` module name.

**Examples**:
- `caml_ml_open_descriptor_in` → naming looks for `ml.lua` (doesn't exist)
- `caml_ml_flush` → naming looks for `ml.lua` (doesn't exist)
- Implementation exists in `runtime/lua/io.lua`

**Why Unresolvable**: OCaml C API uses `caml_ml_*` prefix for I/O operations, but runtime module is `io.lua`.

**Action Required**: Add Export directives to `runtime/lua/io.lua` for all 30 functions. Example:

```lua
--// Export: open_descriptor_in as caml_ml_open_descriptor_in
--// Export: open_descriptor_in_with_flags as caml_ml_open_descriptor_in_with_flags
--// Export: flush as caml_ml_flush
--// Export: output as caml_ml_output
--// Export: output_char as caml_ml_output_char
-- ... (25 more)
```

**Priority**: MEDIUM (needed for I/O operations but hello_lua doesn't use them yet)

**Estimated Work**: ~30 lines of Export directives (1 per primitive)

**Note**: Check if all 30 functions exist in `io.lua`. May need to implement missing ones.

---

### Marshal Operations (0/3 = 0%)

| Primitive | Status | Runtime Module | Action Needed |
|-----------|--------|----------------|---------------|
| `caml_output_value` | ❌ Unresolvable | `marshal.lua` | Add Export: `to_bytes as caml_output_value`? |
| `caml_input_value` | ❌ Unresolvable | `marshal.lua` | Add Export: `from_bytes as caml_input_value`? |
| `caml_input_value_to_outside_heap` | ❌ Unresolvable | `marshal.lua` | Implement or add Export |

**Why Unresolvable**: Naming convention looks for `output.lua` and `input.lua` (don't exist), implementation is in `marshal.lua`.

**Action Required**: Add Export directives to `runtime/lua/marshal.lua`:

```lua
--// Export: to_bytes as caml_output_value
--// Export: from_bytes as caml_input_value
--// Export: from_bytes_no_heap as caml_input_value_to_outside_heap
```

**Priority**: LOW (advanced feature, not needed for basic programs)

**Estimated Work**: ~10 lines Export directives + check if functions exist

---

### System Operations (2/2 = 100% ✓)

| Primitive | Status | Runtime Module | Function |
|-----------|--------|----------------|----------|
| `caml_sys_open` | ✅ Resolved | `sys.lua` | `M.open` |
| `caml_sys_close` | ✅ Resolved | `sys.lua` | `M.close` |

**Status**: COMPLETE ✓ (LINKING.md Task 3.2)

**Implementation**: `runtime/lua/sys.lua` with stub implementations.

---

### Weak Reference Operations (3/3 = 100% ✓)

| Primitive | Status | Runtime Module | Function |
|-----------|--------|----------------|----------|
| `caml_weak_create` | ✅ Resolved | `weak.lua` | `M.create` |
| `caml_weak_set` | ✅ Resolved | `weak.lua` | `M.set` |
| `caml_weak_get` | ✅ Resolved | `weak.lua` | `M.get` |

**Status**: COMPLETE ✓ (LINKING.md Task 3.2)

**Implementation**: `runtime/lua/weak.lua` using Lua's weak tables.

---

### Special/Internal Operations (2/2 = 100% ✓)

| Primitive | Status | Runtime Module | Function |
|-----------|--------|----------------|----------|
| `caml_closure` | ✅ Resolved | `core.lua` | `M.closure` |
| `caml_special` | ✅ Resolved | `core.lua` | `M.special` |

**Status**: COMPLETE ✓

**Implementation**: `runtime/lua/core.lua`

---

## Implementation Priority

Based on what hello_lua and real programs need:

### Priority 1: Critical for hello_lua (0% → 100%)

**String Operations** (6 primitives):
- Action: Add Export directives to `mlBytes.lua`
- Estimated: ~10 lines, 15 minutes
- Impact: Enables string operations in hello_lua

**Bytes Operations** (6 primitives):
- Action: Add Export directives to `mlBytes.lua`
- Estimated: ~10 lines, 15 minutes
- Impact: Enables bytes operations

**Reference Operations** (1 primitive):
- Action: Implement `M.ref_set` in `core.lua`
- Estimated: ~5 lines, 10 minutes
- Impact: Enables mutable references

**Array Operations** (3 missing):
- Action: Add Export directives + possibly implement
- Estimated: ~15 lines, 20 minutes
- Impact: Complete array support

**Total Priority 1**: ~40 lines, ~1 hour work → +16 primitives (22% → 49%)

---

### Priority 2: Common Operations (49% → 87%)

**Float Array Operations** (2 primitives):
- Action: Add Export or implement in `array.lua`
- Estimated: ~15 lines, 20 minutes
- Impact: Float array support

**I/O Operations** (30 primitives):
- Action: Add Export directives to `io.lua` (check implementations exist)
- Estimated: ~30 lines Export + possibly 50-100 lines implementation, 2 hours
- Impact: Full I/O support

**Total Priority 2**: ~45-145 lines, ~2.5 hours → +32 primitives (49% → 87%)

---

### Priority 3: Advanced Features (87% → 100%)

**Marshal Operations** (3 primitives):
- Action: Add Export directives to `marshal.lua`
- Estimated: ~10 lines, 15 minutes
- Impact: Serialization support

**Global Registry** (1 primitive):
- Action: Keep inline or add Export to `core.lua`
- Estimated: ~3 lines, 10 minutes
- Impact: None (already working)

**Total Priority 3**: ~13 lines, ~25 minutes → +4 primitives (87% → 100%)

---

## Implementation Tasks

### Task P1: String and Bytes Export Directives (~30 minutes)

**File**: `runtime/lua/mlBytes.lua`

**Add Export directives** (~20 lines):

```lua
-- String operation exports
--// Export: compare as caml_string_compare
--// Export: get as caml_string_get
--// Export: set as caml_string_set
--// Export: unsafe_set as caml_string_unsafe_set
--// Export: create as caml_create_string
--// Export: blit as caml_blit_string

-- Bytes operation exports
--// Export: get as caml_bytes_get
--// Export: set as caml_bytes_set
--// Export: unsafe_set as caml_bytes_unsafe_set
--// Export: create as caml_create_bytes
--// Export: fill as caml_fill_bytes
--// Export: blit as caml_blit_bytes
```

**Verification**:
- Run `dune build compiler/tests-lua/test_primitive_coverage.exe`
- Should show +12 resolvable primitives

---

### Task P2: Reference and Array Operations (~30 minutes)

**File 1**: `runtime/lua/core.lua` (~5 lines)

```lua
function M.ref_set(ref, value)
  ref[1] = value
end
```

**File 2**: `runtime/lua/array.lua` (~10 lines)

```lua
--// Export: make as caml_make_vect
--// Export: make as caml_make_float_vect  -- If make() handles floats
-- OR implement separate make_float_vect if needed
```

Check if float array functions exist, add Export or implement.

**Verification**:
- Run test_primitive_coverage
- Should show +4 resolvable primitives

---

### Task P3: I/O Export Directives (~2 hours)

**File**: `runtime/lua/io.lua`

**Add Export directives** (~30 lines):

```lua
--// Export: open_descriptor_in as caml_ml_open_descriptor_in
--// Export: open_descriptor_in_with_flags as caml_ml_open_descriptor_in_with_flags
--// Export: open_descriptor_out as caml_ml_open_descriptor_out
--// Export: open_descriptor_out_with_flags as caml_ml_open_descriptor_out_with_flags
--// Export: out_channels_list as caml_ml_out_channels_list
--// Export: flush as caml_ml_flush
--// Export: output as caml_ml_output
--// Export: output_bytes as caml_ml_output_bytes
--// Export: output_char as caml_ml_output_char
--// Export: output_int as caml_ml_output_int
--// Export: input as caml_ml_input
--// Export: input_char as caml_ml_input_char
--// Export: input_int as caml_ml_input_int
--// Export: input_scan_line as caml_ml_input_scan_line
--// Export: close_channel as caml_ml_close_channel
--// Export: channel_size as caml_ml_channel_size
--// Export: channel_size_64 as caml_ml_channel_size_64
--// Export: set_binary_mode as caml_ml_set_binary_mode
--// Export: is_binary_mode as caml_ml_is_binary_mode
--// Export: set_buffered as caml_ml_set_buffered
--// Export: is_buffered as caml_ml_is_buffered
--// Export: set_channel_name as caml_ml_set_channel_name
--// Export: channel_descriptor as caml_channel_descriptor
--// Export: pos_in as caml_ml_pos_in
--// Export: pos_in_64 as caml_ml_pos_in_64
--// Export: pos_out as caml_ml_pos_out
--// Export: pos_out_64 as caml_ml_pos_out_64
--// Export: seek_in as caml_ml_seek_in
--// Export: seek_in_64 as caml_ml_seek_in_64
--// Export: seek_out as caml_ml_seek_out
--// Export: seek_out_64 as caml_ml_seek_out_64
```

**Important**: Check if all function names match what's in `io.lua`. May need to implement missing functions.

**Verification**:
- Run test_primitive_coverage
- Should show +30 resolvable primitives

---

### Task P4: Marshal Export Directives (~15 minutes)

**File**: `runtime/lua/marshal.lua`

**Add Export directives** (~5 lines):

```lua
--// Export: to_bytes as caml_output_value
--// Export: from_bytes as caml_input_value
--// Export: from_bytes_no_heap as caml_input_value_to_outside_heap
```

Check function names match what's in `marshal.lua`.

**Verification**:
- Run test_primitive_coverage
- Should show +3 resolvable primitives

---

## Testing Strategy

After each task, run the primitive coverage test:

```bash
dune build compiler/tests-lua/test_primitive_coverage.exe
dune exec compiler/tests-lua/test_primitive_coverage.exe
```

Expected progression:
- **Baseline**: 19/72 primitives (26%)
- **After P1**: 31/72 primitives (43%) - String/Bytes
- **After P2**: 35/72 primitives (49%) - Ref/Array
- **After P3**: 65/72 primitives (90%) - I/O
- **After P4**: 68/72 primitives (94%) - Marshal
- **Final**: 72/72 primitives (100%) - Polish

---

## Success Criteria

- ✅ All 72 primitives resolvable via linking system
- ✅ Test `test_primitive_coverage.ml` shows 100% coverage
- ✅ hello_lua example runs successfully
- ✅ All existing Lua tests continue passing
- ✅ Zero code duplication (Export directives only)
- ✅ Module runtime files remain testable standalone

---

## Calling Convention

All `caml_*` primitives follow OCaml C API conventions:

1. **Arguments**: OCaml values (Lua tables/numbers/strings)
2. **Return**: OCaml value or `nil` for unit
3. **Errors**: Raise Lua error (caught as OCaml exception)
4. **Indexing**: Accept 0-based OCaml indices, convert to 1-based Lua internally
5. **Side Effects**: Modify arguments in place where appropriate

---

## Value Representation

**OCaml Values in Lua**:
- **Integers**: Lua numbers
- **Blocks**: Tables with `tag` field: `{tag=0, [1]=v1, [2]=v2}`
- **Strings**: Lua strings (immutable)
- **Bytes**: Lua tables (mutable) or strings
- **Arrays**: Tables with integer keys (1-based internally, 0-based from OCaml)
- **References**: `{tag=0, [1]=value}`

---

## References

- **LINKING.md**: Detailed linking system architecture
- **test_primitive_coverage.ml**: Current status and verification
- **OCaml C API**: https://ocaml.org/manual/intfc.html
- **runtime/lua/**: All runtime module implementations
