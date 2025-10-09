# OCaml Runtime Primitives - Lua Implementation Status

This document catalogs all runtime primitives that the lua_of_ocaml compiler can generate, their implementation status, and calling conventions.

## Overview

The compiler generates calls to `caml_*` functions for primitive operations. These primitives must be available as global functions in the generated Lua code.

**Current Status**:
- ✅ **Implemented**: 1/70 primitives (1%)
- ⚠️ **Module Functions Exist**: Many operations have runtime/lua/ module implementations but aren't exposed as caml_* globals
- ❌ **Missing**: 69/70 primitives need implementation

## Primitive Categories

### Global/Registry Operations (1 primitive)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_register_global` | ✅ Inline | N/A | Register global value by index and optional name |

**Implementation**: Inlined in generated code (Task 14.1)

### Integer Comparison (3 primitives)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_int_compare` | ❌ Missing | compare.lua? | Compare two integers (-1, 0, 1) |
| `caml_int32_compare` | ❌ Missing | int32.lua? | Compare two int32 values |
| `caml_nativeint_compare` | ❌ Missing | nativeint.lua? | Compare two nativeint values |

**Calling Convention**: `compare(a, b)` → `-1` (a < b), `0` (a == b), `1` (a > b)

### Float Operations (1 primitive)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_float_compare` | ❌ Missing | float.lua? | Compare two floats with OCaml semantics |

**Note**: Must handle NaN correctly (NaN != NaN in OCaml)

### String Operations (6 primitives)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_string_compare` | ⚠️ Module | string.lua | Lexicographic string comparison |
| `caml_string_get` | ⚠️ Module | string.lua (M.get) | Get character at index |
| `caml_string_set` | ⚠️ Module | bytes.lua (M.set) | Set character with bounds check |
| `caml_string_unsafe_set` | ⚠️ Module | bytes.lua (M.unsafe_set) | Set character without bounds check |
| `caml_create_string` | ⚠️ Module | string.lua (M.make?) | Create string of given length |
| `caml_blit_string` | ⚠️ Module | string.lua (M.blit) | Copy substring to bytes |

**Calling Convention**:
- `caml_string_get(str, idx)` → character (0-indexed from OCaml)
- `caml_string_set(str, idx, char)` → unit (modifies bytes in place)
- `caml_create_string(len)` → new string/bytes
- `caml_blit_string(src, src_pos, dst, dst_pos, len)` → unit

### Bytes Operations (7 primitives)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_bytes_get` | ⚠️ Module | bytes.lua (M.get) | Get byte at index |
| `caml_bytes_set` | ⚠️ Module | bytes.lua (M.set) | Set byte with bounds check |
| `caml_bytes_unsafe_set` | ⚠️ Module | bytes.lua (M.unsafe_set) | Set byte without bounds check |
| `caml_create_bytes` | ⚠️ Module | bytes.lua (M.create) | Create bytes of given length |
| `caml_fill_bytes` | ⚠️ Module | bytes.lua (M.fill) | Fill bytes range with character |
| `caml_blit_bytes` | ⚠️ Module | bytes.lua (M.blit) | Copy bytes range |

**Calling Convention**:
- Indices are 0-based from OCaml, 1-based in Lua
- Bytes represented as Lua string or table depending on mutability

### Array Operations (11 primitives)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_array_set` | ⚠️ Module | array.lua (M.set) | Set array element with bounds check |
| `caml_array_unsafe_set` | ⚠️ Module | array.lua (M.unsafe_set) | Set array element without bounds check |
| `caml_make_vect` | ⚠️ Module | array.lua (M.make) | Create array filled with value |
| `caml_array_make` | ⚠️ Module | array.lua (M.make) | Alias for make_vect |
| `caml_make_float_vect` | ⚠️ Module | array.lua | Create float array |
| `caml_floatarray_create` | ⚠️ Module | array.lua | Create uninitialized float array |
| `caml_array_sub` | ⚠️ Module | array.lua (M.sub) | Extract subarray |
| `caml_array_append` | ⚠️ Module | array.lua (M.append) | Concatenate two arrays |
| `caml_array_concat` | ⚠️ Module | array.lua (M.concat) | Concatenate list of arrays |
| `caml_array_blit` | ⚠️ Module | array.lua (M.blit) | Copy array range |
| `caml_array_fill` | ⚠️ Module | array.lua (M.fill) | Fill array range with value |

**Calling Convention**:
- Arrays are Lua tables with 1-based indexing internally
- OCaml passes 0-based indices that must be converted

### Float Array Operations (2 primitives)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_floatarray_set` | ⚠️ Module | array.lua | Set float array element with bounds check |
| `caml_floatarray_unsafe_set` | ⚠️ Module | array.lua | Set float array element without bounds check |

### Reference Operations (1 primitive)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_ref_set` | ❌ Missing | N/A | Set reference value |

**Calling Convention**: `caml_ref_set(ref, value)` → unit
**Note**: References are `{tag=0, [1]=value}` in OCaml encoding

### I/O Channel Operations (30 primitives)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_ml_open_descriptor_in` | ⚠️ Module | io.lua | Open input channel from fd |
| `caml_ml_open_descriptor_in_with_flags` | ⚠️ Module | io.lua | Open input channel with flags |
| `caml_ml_open_descriptor_out` | ⚠️ Module | io.lua | Open output channel from fd |
| `caml_ml_open_descriptor_out_with_flags` | ⚠️ Module | io.lua | Open output channel with flags |
| `caml_ml_out_channels_list` | ⚠️ Module | io.lua | Get list of open output channels |
| `caml_ml_flush` | ⚠️ Module | io.lua | Flush output channel |
| `caml_ml_output` | ⚠️ Module | io.lua | Output string to channel |
| `caml_ml_output_bytes` | ⚠️ Module | io.lua | Output bytes to channel |
| `caml_ml_output_char` | ⚠️ Module | io.lua | Output single character |
| `caml_ml_output_int` | ⚠️ Module | io.lua | Output integer (binary) |
| `caml_ml_input` | ⚠️ Module | io.lua | Read bytes from channel |
| `caml_ml_input_char` | ⚠️ Module | io.lua | Read single character |
| `caml_ml_input_int` | ⚠️ Module | io.lua | Read integer (binary) |
| `caml_ml_input_scan_line` | ⚠️ Module | io.lua | Scan for newline position |
| `caml_ml_close_channel` | ⚠️ Module | io.lua | Close channel |
| `caml_ml_channel_size` | ⚠️ Module | io.lua | Get channel size (int) |
| `caml_ml_channel_size_64` | ⚠️ Module | io.lua | Get channel size (int64) |
| `caml_ml_set_binary_mode` | ⚠️ Module | io.lua | Set binary/text mode |
| `caml_ml_is_binary_mode` | ⚠️ Module | io.lua | Check if binary mode |
| `caml_ml_set_buffered` | ⚠️ Module | io.lua | Set buffering mode |
| `caml_ml_is_buffered` | ⚠️ Module | io.lua | Check if buffered |
| `caml_ml_set_channel_name` | ⚠️ Module | io.lua | Set channel name |
| `caml_channel_descriptor` | ⚠️ Module | io.lua | Get file descriptor |
| `caml_ml_pos_in` | ⚠️ Module | io.lua | Get input position (int) |
| `caml_ml_pos_in_64` | ⚠️ Module | io.lua | Get input position (int64) |
| `caml_ml_pos_out` | ⚠️ Module | io.lua | Get output position (int) |
| `caml_ml_pos_out_64` | ⚠️ Module | io.lua | Get output position (int64) |
| `caml_ml_seek_in` | ⚠️ Module | io.lua | Seek input (int) |
| `caml_ml_seek_in_64` | ⚠️ Module | io.lua | Seek input (int64) |
| `caml_ml_seek_out` | ⚠️ Module | io.lua | Seek output (int) |
| `caml_ml_seek_out_64` | ⚠️ Module | io.lua | Seek output (int64) |

**Note**: I/O primitives in runtime/lua/io.lua but need adapter layer

### Marshal Operations (2 primitives)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_output_value` | ⚠️ Module | marshal.lua (M.to_bytes) | Serialize value to channel |
| `caml_input_value` | ⚠️ Module | marshal.lua (M.from_bytes) | Deserialize value from channel |
| `caml_input_value_to_outside_heap` | ⚠️ Module | marshal.lua | Deserialize (no heap alloc) |

### System Operations (2 primitives)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_sys_open` | ❌ Missing | sys.lua? | Open file descriptor |
| `caml_sys_close` | ❌ Missing | sys.lua? | Close file descriptor |

### Weak Reference Operations (3 primitives)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_weak_create` | ❌ Missing | weak.lua? | Create weak array |
| `caml_weak_set` | ❌ Missing | weak.lua? | Set weak array element |
| `caml_weak_get` | ❌ Missing | weak.lua? | Get weak array element |

**Note**: Lua 5.1+ has weak tables (`__mode` metatable)

### Special/Internal (2 primitives)

| Primitive | Status | Runtime Module | Description |
|-----------|--------|----------------|-------------|
| `caml_closure` | ❌ Missing | N/A | Create closure (internal) |
| `caml_special` | ❌ Missing | N/A | Special operations (internal) |

## Summary Statistics

| Category | Total | Implemented | Module Exists | Missing |
|----------|-------|-------------|---------------|---------|
| Global/Registry | 1 | 1 | 0 | 0 |
| Integer Comparison | 3 | 0 | 0 | 3 |
| Float Operations | 1 | 0 | 0 | 1 |
| String Operations | 6 | 0 | 6 | 0 |
| Bytes Operations | 7 | 0 | 7 | 0 |
| Array Operations | 11 | 0 | 11 | 0 |
| Float Array | 2 | 0 | 2 | 0 |
| References | 1 | 0 | 0 | 1 |
| I/O Channels | 30 | 0 | 30 | 0 |
| Marshal | 3 | 0 | 3 | 0 |
| System | 2 | 0 | 0 | 2 |
| Weak References | 3 | 0 | 0 | 3 |
| Special/Internal | 2 | 0 | 0 | 2 |
| **TOTAL** | **70** | **1** | **59** | **12** |

## Key Findings

### 1. Module vs. Global Function Mismatch

**Problem**: Runtime modules export functions as `M.function_name` but generated code expects global `caml_function_name`.

**Example**:
```lua
-- Generated code calls:
local result = caml_array_make(10, 0)

-- But runtime provides:
local Array = require("array")
local result = Array.make(10, 0)
```

**Solutions** (Task 14.3):
1. **Adapter Layer**: Create global `caml_*` wrappers that call module functions
2. **Inline Primitives**: Inline commonly-used primitives in generated code
3. **Code Generator Update**: Generate module-aware calls instead of global calls

### 2. Index Convention

**Issue**: OCaml uses 0-based indexing, Lua uses 1-based indexing.

**Current Handling**:
- Code generator adds 1 to indices: `arr[idx + 1]`
- Runtime modules expect 1-based indices
- Primitives must convert if accepting OCaml indices

### 3. Value Representation

**OCaml Values in Lua**:
- **Integers**: Lua numbers
- **Blocks**: Tables with `tag` field: `{tag=0, [1]=v1, [2]=v2}`
- **Strings**: Lua strings (immutable)
- **Bytes**: Lua strings or tables (mutable)
- **Arrays**: Tables with integer keys (1-based internally)
- **References**: `{tag=0, [1]=value}`

### 4. Missing Core Primitives

**Must Implement** (12 primitives):
- Integer comparisons (int, int32, nativeint)
- Float comparison
- Reference operations
- System operations (open, close)
- Weak references (Lua supports these)
- Internal operations (closure, special)

### 5. I/O Complexity

**Challenge**: 30 I/O primitives need adaptation.

**Strategy**:
- Most functionality exists in runtime/lua/io.lua
- Need thin adapter layer: `caml_ml_*` → `io.lua` module calls
- Handle buffering, binary mode, seeking correctly

## Implementation Priority (Task 14.3)

### Phase 1: Critical Primitives (hello_lua)
- ✅ `caml_register_global` (done)

### Phase 2: Basic Operations
- `caml_int_compare`
- `caml_float_compare`
- `caml_string_compare`
- `caml_ref_set`

### Phase 3: String/Bytes Adapters
- 6 string primitives → string.lua/bytes.lua
- 7 bytes primitives → bytes.lua

### Phase 4: Array Adapters
- 11 array primitives → array.lua
- 2 float array primitives → array.lua

### Phase 5: I/O Adapters
- 30 I/O primitives → io.lua
- Most complex, lowest initial priority

### Phase 6: Advanced Features
- Marshal adapters → marshal.lua
- System operations
- Weak references

## Calling Convention Standard

All `caml_*` primitives follow OCaml C API conventions:

1. **Arguments**: OCaml values (Lua tables/numbers/strings)
2. **Return**: OCaml value or `nil` for unit
3. **Errors**: Raise Lua error (will be caught as OCaml exception)
4. **Indexing**: Accept 0-based OCaml indices, convert to 1-based Lua internally
5. **Side Effects**: Modify arguments in place where appropriate

## Next Steps

See **Task 14.3** in LUA.md for implementation of missing primitives.

**Strategy**:
1. Create runtime adapter module (runtime/lua/primitives.lua)
2. Export all 70 `caml_*` functions as globals
3. Most will be thin wrappers around existing runtime modules
4. Inline adapter in generated code for standalone executables

## References

- OCaml C API: https://ocaml.org/manual/intfc.html
- js_of_ocaml runtime: runtime/js/*.js
- Lua runtime modules: runtime/lua/*.lua
- Code generator: compiler/lib-lua/lua_generate.ml
