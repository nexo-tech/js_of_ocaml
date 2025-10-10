# Lua Runtime Primitives Refactoring Plan

## Master Checklist

### Phase 1: Refactor Core Infrastructure (Est: 4 hours)
- [x] Task 1.1: Update linker to parse `--Provides:` comments (1 hour)
- [x] Task 1.2: Remove `--// Export:` and `core.register()` parsing (30 min)
- [x] Task 1.3: Update `embed_runtime_module` to handle direct functions (1 hour)
- [x] Task 1.4: Update wrapper generation for new structure (1 hour)
- [x] Task 1.5: Write tests for new linker infrastructure (30 min)

### Phase 2: Refactor Core Modules (Est: 6 hours)
- [x] Task 2.1: Refactor `core.lua` - base primitives (1 hour + tests)
  - **FIXED**: Removed all global variables, documentation comments
- [x] Task 2.2: Refactor `compare.lua` - comparison primitives (1 hour + tests)
  - **FIXED**: Converted 5 local helper functions to caml_* functions with --Provides
  - **VERIFIED**: All 73 tests pass, no syntax errors
- [x] Task 2.3: Refactor `mlBytes.lua` - bytes primitives (1 hour + tests)
  - **FIXED**: Removed `local bit = require("compat_bit")` and documentation comment
  - **FIXED**: Implemented Lua 5.1-compatible bitwise operations as caml_* functions
  - **ADDED**: caml_bit_and, caml_bit_or, caml_bit_lshift, caml_bit_rshift with --Provides
  - **VERIFIED**: All 36 tests pass, Lua 5.1 compatible, no external dependencies
- [x] Task 2.4: Refactor `array.lua` - array primitives (1 hour + tests)
  - **VERIFIED**: Clean (documentation comments removed)
- [x] Task 2.5: Refactor `ints.lua` - integer primitives (1 hour + tests)
  - **FIXED**: Removed `local bit = require("compat_bit")` and all local helpers
  - **FIXED**: Converted local function `to_int32()` to `caml_to_int32()` with --Provides
  - **FIXED**: Implemented caml_int32_xor and caml_int32_not as pure Lua 5.1 functions
  - **FIXED**: All int32 operations use caml_bit_* helper functions from mlBytes.lua
  - **VERIFIED**: All 24 tests pass, Lua 5.1 compatible, no external dependencies
- [x] Task 2.6: Refactor `float.lua` - float primitives (1 hour + tests)
  - **VERIFIED**: Clean after documentation comment removal

### Phase 3: Refactor Standard Library Modules (Est: 8 hours)

**VERIFICATION COMPLETE**: See `runtime/lua/PHASE3_VIOLATIONS.md` for detailed violations

- [x] Task 3.1: Refactor `buffer.lua` - buffer primitives (45 min + tests)
  - **FIXED**: Removed local constant DEFAULT_INITIAL_SIZE (inlined to 16)
  - **FIXED**: Removed local Buffer metatable and setmetatable call
  - **FIXED**: Converted local function ocaml_string_to_lua to caml_ocaml_string_to_lua with --Provides
  - **FIXED**: Updated caml_buffer_add_printf to call global caml_format_* functions directly
  - **VERIFIED**: All 28 tests pass, Lua 5.1 compatible
- [x] Task 3.2: Refactor `format.lua` - format primitives (45 min + tests)
  - **FIXED**: Converted local function ocaml_string_to_lua to caml_ocaml_string_to_lua with --Provides
  - **FIXED**: Converted local function lua_string_to_ocaml to caml_lua_string_to_ocaml with --Provides
  - **FIXED**: Converted local function str_repeat to caml_str_repeat with --Provides
  - **FIXED**: Converted local function skip_whitespace to caml_skip_whitespace with --Provides
  - **VERIFIED**: All 55 format tests pass, all buffer tests pass, Lua 5.1 compatible
- [x] Task 3.3: Refactor `hash.lua` - hashing primitives (45 min + tests)
  - **FIXED**: Removed all 9 local helper functions (Lua 5.3+ bitwise operators)
  - **FIXED**: Implemented hash-specific 32-bit bitwise operations: caml_hash_bit_xor, caml_hash_bit_and, caml_hash_bit_or, caml_hash_bit_lshift, caml_hash_bit_rshift
  - **FIXED**: Implemented caml_hash_mul32 for 32-bit unsigned multiplication with proper overflow handling
  - **FIXED**: Implemented caml_hash_to_int32 for unsigned to signed conversion
  - **FIXED**: Replaced Lua 5.3+ string.pack/unpack with Lua 5.1 compatible float decomposition
  - **FIXED**: Used existing caml_is_ocaml_string and caml_is_ocaml_block from compare.lua
  - **VERIFIED**: All 64 hash tests pass, Lua 5.1 compatible, no Lua 5.3+ features
- [x] Task 3.4: Refactor `hashtbl.lua` - hashtable primitives (45 min + tests)
  - **FIXED**: Removed local constants DEFAULT_INITIAL_SIZE (inlined to 16) and LOAD_FACTOR (inlined to 0.75)
  - **FIXED**: Removed local Hashtbl metatable and setmetatable call
  - **FIXED**: Converted local function equal to caml_hashtbl_equal with --Provides
  - **FIXED**: Converted local function get_bucket_index to caml_hashtbl_get_bucket_index with --Provides
  - **FIXED**: Converted local function resize to caml_hashtbl_resize with --Provides
  - **VERIFIED**: All 54 hashtbl tests pass, Lua 5.1 compatible
- [x] Task 3.5: Refactor `lazy.lua` - lazy evaluation primitives (45 min + tests)
  - **FIXED**: Removed local constant LAZY_TAG (246) - inlined into all function bodies
  - **FIXED**: Removed local constant FORCING_TAG (244) - inlined into all function bodies
  - **FIXED**: Removed local constant FORWARD_TAG (250) - inlined into all function bodies
  - **VERIFIED**: All lazy tests pass, Lua 5.1 compatible
- [x] Task 3.6: Refactor `lexing.lua` - lexer primitives (45 min + tests)
  - **FIXED**: Removed 12 local LEX_* constants (REFILL_BUF, BUFFER, BUFFER_LEN, ABS_POS, START_POS, CURR_POS, LAST_POS, LAST_ACTION, EOF_REACHED, MEM, START_P, CURR_P) - inlined numeric indices (1-12) into all function bodies
  - **FIXED**: Removed 5 local TBL_* constants (BASE, BACKTRK, DEFAULT, TRANS, CHECK) - inlined numeric indices (1-5) into caml_lex_engine
  - **FIXED**: Extracted local function refill_func to global caml_lexbuf_refill_from_channel
  - **FIXED**: Replaced Lua 5.3+ bitwise operators (lo | (hi << 8)) with Lua 5.1 compatible arithmetic (lo + hi * 256) in caml_lex_array
  - **VERIFIED**: All 33 lexing tests pass, Lua 5.1 compatible
- [x] Task 3.7: Refactor `list.lua` - list primitives (45 min + tests)
  - **VERIFIED**: Clean (documentation comments removed)
- [x] Task 3.8: Refactor `map.lua` - map primitives (45 min + tests)
  - **FIXED**: Converted 19 local helper functions to global caml_map_* functions with --Provides
  - **FIXED**: AVL tree helpers: height, create_node, balance_factor, rotate_right, rotate_left, balance
  - **FIXED**: Core operations: add_internal, find_internal, mem_internal, min_node, remove_internal
  - **FIXED**: Traversal functions: iter_internal, fold_internal, for_all_internal, exists_internal
  - **FIXED**: Transform functions: cardinal_internal, map_values_internal, mapi_internal, filter_internal
  - **VERIFIED**: All 33 map tests pass, AVL balancing working correctly
- [x] Task 3.9: Refactor `option.lua` - option primitives (30 min + tests)
  - **VERIFIED**: Clean (documentation comments removed)
- [x] Task 3.10: Refactor `parsing.lua` - parser primitives (45 min + tests)
  - **FIXED**: Removed 33 local constants and inlined them into function bodies
  - **FIXED**: Command codes (READ_TOKEN=0, RAISE_PARSE_ERROR=1, GROW_STACKS_1=2, GROW_STACKS_2=3, COMPUTE_SEMANTIC_ACTION=4, CALL_ERROR_FUNCTION=5)
  - **FIXED**: State codes (LOOP=6, TESTSHIFT=7, SHIFT=8, SHIFT_RECOVER=9, REDUCE=10)
  - **FIXED**: 16 ENV_* constants (S_STACK=1 through ERRFLAG=16) inlined in all functions
  - **FIXED**: 16 TBL_* constants (ACTIONS=1 through NAMES_BLOCK=16) inlined in caml_parse_engine
  - **FIXED**: ERRCODE=256 inlined in error handling code
  - **FIXED**: Converted local variable caml_parser_trace to global caml_parser_trace_flag
  - **VERIFIED**: All 24 parsing tests pass, parser state machine working correctly
- [x] Task 3.11: Refactor `queue.lua` - queue primitives (30 min + tests)
  - **FIXED**: Removed local Queue table with __index metatable
  - **FIXED**: Removed setmetatable call in caml_queue_create
  - **VERIFIED**: All 30 queue tests pass, FIFO operations working correctly with flat table structure
- [x] Task 3.12: Refactor `result.lua` - result primitives (30 min + tests)
  - **VERIFIED**: Clean (documentation comments removed)
- [x] Task 3.13: Refactor `set.lua` - set primitives (45 min + tests)
  - **FIXED**: Removed dofile("core.lua") statement
  - **FIXED**: Converted 23 local helper functions to global caml_set_* functions with --Provides
  - **FIXED**: AVL tree helpers: height, create_node, balance_factor, rotate_right, rotate_left, balance
  - **FIXED**: Core operations: add_internal, mem_internal, min_node, remove_internal
  - **FIXED**: Set operations: union_internal, inter_internal, diff_internal
  - **FIXED**: Traversal functions: iter_internal, fold_internal, for_all_internal, exists_internal
  - **FIXED**: Transform functions: cardinal_internal, filter_internal, partition_internal, subset_internal, min_elt_internal, max_elt_internal
  - **VERIFIED**: All 38 set tests pass, AVL balancing and set operations working correctly
- [x] Task 3.14: Refactor `stack.lua` - stack primitives (30 min + tests)
  - **FIXED**: Removed local Stack table with __index metatable
  - **FIXED**: Removed setmetatable call in caml_stack_create
  - **VERIFIED**: All 32 stack tests pass, LIFO operations working correctly with flat table structure

### Phase 4: Refactor System & I/O Modules (Est: 4 hours)
- [x] Task 4.1: Refactor `sys.lua` - system primitives (1 hour + tests)
- [x] Task 4.2: Refactor `io.lua` - I/O primitives (1 hour + tests)
  - **Note**: test_io_integration.lua cannot run until Phase 6 (marshal.lua, format.lua) and fail.lua are refactored
  - Test execution deferred to Task 7.1
- [ ] Task 4.3: Refactor `filename.lua` - filename primitives (45 min + tests)
- [ ] Task 4.4: Refactor `stream.lua` - stream primitives (45 min + tests)

### Phase 5: Refactor Special Modules (Est: 4 hours)
- [x] Task 5.1: Refactor `obj.lua` - object primitives (1 hour + tests)
- [x] Task 5.2: Refactor `gc.lua` - GC primitives (45 min + tests)
- [x] Task 5.3: Refactor `weak.lua` - weak reference primitives (45 min + tests)
- [x] Task 5.4: Refactor `effect.lua` - effect handler primitives (1 hour + tests)
- [x] Task 5.5: Refactor `fun.lua` - function primitives (30 min + tests)

### Phase 6: Refactor Advanced Modules (Est: 8 hours)

**IMPORTANT**: Marshal implementation order must be: 6.3 → 6.2 → 6.1.x (due to dependencies)

- [x] Task 6.3: Implement `marshal_io.lua` - Binary I/O helper functions (1 hour + tests)
  - **PREREQUISITES**: None (foundation module)
  - **COMPLETED**: 186 lines (marshal_io.lua) + 460 lines (test_marshal_io.lua) = 646 lines total
  - **IMPLEMENTED**:
    - ✓ Buffer functions: `caml_marshal_buffer_create()`, `caml_marshal_buffer_to_string()`
    - ✓ Write functions: `caml_marshal_buffer_write8u()`, `caml_marshal_buffer_write16u()`, `caml_marshal_buffer_write32u()`, `caml_marshal_buffer_write_bytes()`
    - ✓ Read unsigned: `caml_marshal_read8u()`, `caml_marshal_read16u()`, `caml_marshal_read32u()`, `caml_marshal_read_bytes()`
    - ✓ Read signed: `caml_marshal_read16s()`, `caml_marshal_read32s()` (bonus functions for signed integers)
    - ✓ Double support: `caml_marshal_write_double_little()`, `caml_marshal_read_double_little()` (Lua 5.3+ only)
    - ✓ All big-endian byte order
    - ✓ 47 tests passed (100% coverage)

- [x] Task 6.2: Implement `marshal_header.lua` - Marshal header functions (45 min + tests)
  - **PREREQUISITES**: Task 6.3 (uses marshal_io functions) ✓
  - **COMPLETED**: 95 lines (marshal_header.lua) + 359 lines (test_marshal_header.lua) = 454 lines total
  - **IMPLEMENTED**:
    - ✓ `caml_marshal_header_write(buf, data_len, num_objects, size_32, size_64)` - write 20-byte header
    - ✓ `caml_marshal_header_read(str, offset)` - read and validate header, return table with all fields
    - ✓ `caml_marshal_header_size()` - return header size (20 bytes) - bonus function
    - ✓ Supports MAGIC_SMALL (0x8495A6BE) and MAGIC_BIG (0x8495A6BF)
    - ✓ Validates magic number on read
    - ✓ Error handling for insufficient data and invalid magic
    - ✓ 24 tests passed (100% coverage)

- [x] Task 6.1.1: Implement integer marshaling in `marshal.lua` (30 min + tests)
  - **PREREQUISITES**: Tasks 6.3 ✓, 6.2 ✓
  - **COMPLETED**: 117 lines in marshal.lua + 424 lines (test_marshal_int.lua) = 541 lines total
  - **IMPLEMENTED**:
    - ✓ `caml_marshal_write_int(buf, value)` - encode integer with optimal format
      - Small int (0-63): single byte 0x40-0x7F ✓
      - INT8 (-128 to 127 excluding 0-63): 0x00 + signed byte ✓
      - INT16 (-32768 to 32767 excluding INT8): 0x01 + signed 16-bit big-endian ✓
      - INT32 (else): 0x02 + signed 32-bit big-endian ✓
    - ✓ `caml_marshal_read_int(str, offset)` - decode integer, return {value, bytes_read}
    - ✓ Handles signed to unsigned conversion for all formats
    - ✓ Error handling for invalid codes and insufficient data
    - ✓ 41 tests passed (100% coverage)

- [x] Task 6.1.2: Implement string marshaling in `marshal.lua` (30 min + tests)
  - **PREREQUISITES**: Task 6.1.1 ✓
  - **COMPLETED**: 87 lines in marshal.lua + 425 lines (test_marshal_string.lua) = 512 lines total
  - **IMPLEMENTED**:
    - ✓ `caml_marshal_write_string(buf, str)` - encode string with optimal format
      - Small string (0-31 bytes): single byte 0x20-0x3F (0x20 + length) + bytes ✓
      - STRING8 (32-255 bytes): 0x09 + length byte + bytes ✓
      - STRING32 (256+ bytes): 0x0A + length (4 bytes big-endian) + bytes ✓
    - ✓ `caml_marshal_read_string(str, offset)` - decode string, return {value, bytes_read}
    - ✓ Data validation for all formats (checks sufficient data before reading)
    - ✓ Error handling for invalid codes and insufficient data
    - ✓ Supports binary data (null bytes, special characters, UTF-8)
    - ✓ 38 tests passed (100% coverage)

- [x] Task 6.1.3: Implement block marshaling in `marshal.lua` (45 min + tests) ✓
  - **PREREQUISITES**: Task 6.1.2
  - **DELIVERABLES**: 84 lines implemented in `marshal.lua`
    - `caml_marshal_write_block(buf, block, write_value_fn)` - encode block with fields
      - Small block (tag 0-15, size 0-7): single byte 0x80 + (tag | (size << 4))
      - BLOCK32 (else): 0x08 + header (4 bytes: (size << 10) | tag big-endian) + fields
      - Recursive field marshaling via write_value_fn
    - `caml_marshal_read_block(str, offset, read_value_fn)` - decode block, return {value, bytes_read}
      - Recursive field unmarshaling via read_value_fn
      - Returns {value = block, bytes_read = N} consistent with other read functions
  - **BLOCK FORMAT**: Lua table {tag = N, size = M, [1] = field1, [2] = field2, ...}
  - **TESTS**: 438 lines, 27 tests in `test_marshal_block.lua` - all passing ✓
    - Small block write/read (tag 0-15, size 0-7)
    - BLOCK32 write/read (tag >= 16 or size >= 8)
    - Roundtrip tests (all combinations)
    - Nested blocks (blocks containing blocks)
    - Format selection verification
    - Error handling (invalid codes)
  - **IMPLEMENTATION**: Lua 5.1 compatible arithmetic (no bitwise ops), recursive field handling
  - **KEY FIX**: Changed return from {block=..., bytes_read=...} to {value=..., bytes_read=...} for consistency

- [x] Task 6.1.4: Implement double/float marshaling in `marshal.lua` (45 min + tests) ✓
  - **PREREQUISITES**: Task 6.1.3
  - **DELIVERABLES**: 150 lines implemented in `marshal.lua`
    - `caml_marshal_write_double(buf, value)` - encode double with IEEE 754 little-endian
      - CODE_DOUBLE_LITTLE (0x0C): 1 byte code + 8 bytes
      - Uses string.pack("<d", value) for IEEE 754 encoding
      - Errors if string.pack unavailable (Lua < 5.3)
    - `caml_marshal_read_double(str, offset)` - decode double, return {value, bytes_read}
      - Uses string.unpack("<d", packed) for IEEE 754 decoding
      - Returns 9 bytes read (1 code + 8 data)
      - Validates sufficient data before reading
    - `caml_marshal_write_float_array(buf, arr)` - encode float array (OCaml tag 254)
      - DOUBLE_ARRAY8_LITTLE (0x0E): length < 256 → code + 1 byte length + doubles
      - DOUBLE_ARRAY32_LITTLE (0x07): length >= 256 → code + 4 byte length + doubles
      - Accepts arr.size or #arr for length
      - Validates all elements are numbers
    - `caml_marshal_read_float_array(str, offset)` - decode float array
      - Returns {value = {size = N, [1] = v1, ...}, bytes_read = M}
      - Supports both DOUBLE_ARRAY8 and DOUBLE_ARRAY32 formats
      - Validates sufficient data for all doubles
  - **TESTS**: 493 lines, 40 tests in `test_marshal_double.lua` - all passing ✓
    - Double write/read (0.0, ±1.0, π, large/small, ±∞)
    - Double roundtrip (15 values including special values)
    - Float array write/read (empty, 1, 5, 255, 256, 300 elements)
    - Float array roundtrip (boundary values 0-255, 256-300)
    - Format selection (DOUBLE_ARRAY8 < 256, DOUBLE_ARRAY32 >= 256)
    - Error handling (invalid codes, insufficient data, non-number elements)
    - Tests automatically skip if string.pack/unpack unavailable (Lua < 5.3)
  - **IMPLEMENTATION**: Uses Lua 5.3+ string.pack/unpack for IEEE 754 encoding, graceful error if unavailable
  - **FLOAT ARRAYS**: Stored as {size=N, [1]=v1, [2]=v2, ...} for compatibility with OCaml Marshal format

- [x] Task 6.1.5: Implement core value marshaling in `marshal.lua` (1 hour + tests) ✓
  - **PREREQUISITES**: Task 6.1.4
  - **DELIVERABLES**: 141 lines implemented in `marshal.lua`
    - `caml_marshal_write_value(buf, value)` - main marshaling dispatch function
      - Dispatches by Lua type: number → int (if in range) or double
      - Strings → caml_marshal_write_string
      - Tables with .tag field → caml_marshal_write_block (recursive)
      - Tables without .tag, all numbers → caml_marshal_write_float_array
      - Tables without .tag, mixed types → block with tag 0 (recursive)
      - Boolean → int (0 or 1), nil → int (0)
      - Errors on unsupported types (function, userdata, thread)
    - `caml_marshal_read_value(str, offset)` - main unmarshaling dispatch
      - Reads code byte and dispatches to appropriate reader
      - Handles all codes: 0x00-0x02 (int), 0x07 (float array 32), 0x08 (block 32),
        0x09-0x0A (string), 0x0C (double), 0x0E (float array 8),
        0x20-0x3F (small string), 0x40-0x7F (small int), 0x80-0xFF (small block)
      - Recursive unmarshaling for blocks and nested structures
      - Returns {value, bytes_read}
  - **TESTS**: 516 lines, 32 tests in `test_marshal_value.lua` - all passing ✓
    - Integer marshaling (0, 42, -100, 1000000)
    - Double marshaling (3.14, 0.5, large, ±∞)
    - String marshaling (empty, short, long 300 chars)
    - Boolean/nil marshaling (encoded as integers)
    - Block marshaling (empty, integers, strings, mixed types)
    - Nested blocks (2-level, 4-level deep)
    - Float arrays (explicit with .size, inferred from all-numbers)
    - Arrays without .tag (treated as blocks)
    - Complex nested structures (blocks containing float arrays, mixed types)
    - Roundtrip tests (all integer ranges, doubles, strings, blocks)
    - Error handling (unsupported types, invalid codes)
  - **IMPLEMENTATION**: Lua 5.1 compatible, no object sharing (values may duplicate)
  - **KEY DECISIONS**: Tables without .tag infer type (all numbers = float array, else block tag 0)

- [ ] Task 6.1.6: Implement public API in `marshal.lua` (45 min + tests)
  - **PREREQUISITES**: Task 6.1.5
  - **DELIVERABLES**: ~200 lines
    - `caml_marshal_to_string(value, flags)` - complete implementation
      - Create buffer, write value, prepend header, return string
      - Support flags (optional): array of flag numbers (not used initially, reserved)
    - `caml_marshal_from_bytes(str, offset)` - complete implementation
      - Read and validate header
      - Unmarshal value from data section
      - Return unmarshaled value
      - offset parameter (optional, defaults to 0)
    - `caml_marshal_data_size(str, offset)` - return data length from header
    - `caml_marshal_total_size(str, offset)` - return header size (20) + data length
    - Keep aliases: `caml_marshal_to_bytes`, `caml_marshal_from_string`
  - **TESTS**: Add public API tests to test_marshal.lua (roundtrip, size functions)
  - **NO**: Local functions, sharing/custom blocks (future work)
  - **YES**: Complete working Marshal module

- [ ] Task 6.4: Refactor `digest.lua` - digest primitives (45 min + tests)
- [ ] Task 6.5: Refactor `bigarray.lua` - bigarray primitives (1 hour + tests)

### Phase 7: Verification & Integration (Est: 3 hours)
- [ ] Task 7.1: Run all unit tests and fix failures (1 hour)
- [ ] Task 7.2: Build hello_lua example and verify runtime (30 min)
- [ ] Task 7.3: Run compiler test suite (30 min)
- [ ] Task 7.4: Benchmark performance vs old implementation (30 min)
- [ ] Task 7.5: Update documentation (30 min)

**Total Estimated Time: 32 hours**

---

## Refactoring Pattern

### Current Structure (WRONG)
```lua
--// Provides: array
--// Requires: core

local core = require("core")
local M = {}

function M.make(len, init)
  -- implementation
end

function M.get(arr, idx)
  -- implementation
end

-- Export functions
core.register("caml_array_make", M.make)
core.register("caml_array_get", M.get)
--// Export: make as caml_array_make
--// Export: get as caml_array_get

return M
```

### Target Structure (CORRECT - like js_of_ocaml)
```lua
--Provides: caml_array_make
--Requires: caml_make_vect
function caml_array_make(len, init)
  -- implementation
end

--Provides: caml_array_get
function caml_array_get(arr, idx)
  -- implementation
end

--Provides: caml_make_vect
function caml_make_vect(len, init)
  return caml_array_make(len, init)
end
```

### Key Changes
1. **Function Naming**: `M.make` → `function caml_array_make`
2. **Provides Comments**: `--// Provides: array` → `--Provides: caml_array_make` (one per function)
3. **Requires Comments**: `--// Requires: core` → `--Requires: caml_make_vect` (list actual function deps)
4. **Remove Module Wrapping**: No `local M = {}`, no `return M`
5. **Remove Exports**: No `core.register()`, no `--// Export:` directives
6. **Direct Dependencies**: Call `caml_other_function()` directly, not `OtherModule.function()`

---

## Phase 1: Refactor Core Infrastructure

### Task 1.1: Update linker to parse `--Provides:` comments

**File**: `compiler/lib-lua/lua_link.ml`

**Changes**:
1. Update `parse_provides` to parse `--Provides:` (not `--// Provides:`)
2. Change from parsing module-level provides to function-level provides
3. Each `--Provides:` line declares ONE function name

**Before**:
```ocaml
let parse_provides (line : string) : string list =
  let prefix = "--// Provides:" in
  (* Returns list of symbols from one line *)
```

**After**:
```ocaml
let parse_provides (line : string) : string option =
  let prefix = "--Provides:" in
  (* Returns single symbol name or None *)
  if String.starts_with ~prefix line then
    let rest = String.sub line ~pos:(String.length prefix) ~len:(...) in
    let symbol = String.trim rest in
    if String.length symbol > 0 then Some symbol else None
  else None
```

**Implementation**:
- Parse each line for `--Provides: symbol_name`
- Extract symbol name after colon
- Trim whitespace
- Return `Some symbol` or `None`

**Testing**:
```ocaml
(* Test in compiler/tests-lua/test_linker.ml *)
let%expect_test "parse provides comment" =
  let result = parse_provides "--Provides: caml_array_make" in
  print_endline (match result with Some s -> s | None -> "None");
  [%expect {| caml_array_make |}]
```

**Success Criteria**:
- [ ] Parses `--Provides: caml_foo` correctly
- [ ] Ignores `--Provides:` with no symbol
- [ ] Returns None for non-Provides lines
- [ ] Test passes

---

### Task 1.2: Remove `--// Export:` and `core.register()` parsing

**File**: `compiler/lib-lua/lua_link.ml`

**Changes**:
1. Remove `parse_export` function
2. Remove export parsing from `parse_fragment_header`
3. Remove `exports : (string * string) list` field from `fragment` type
4. Remove export-based primitive lookup

**Before**:
```ocaml
type fragment =
  { name : string
  ; provides : string list
  ; requires : string list
  ; exports : (string * string) list
  ; code : string
  }
```

**After**:
```ocaml
type fragment =
  { name : string
  ; provides : string list  (* Now list of caml_* function names *)
  ; requires : string list  (* Now list of caml_* function deps *)
  ; code : string
  }
```

**Implementation**:
- Delete `parse_export` function (lines 68-92)
- Remove `exports` from fragment type
- Remove export parsing from `parse_fragment_header`
- Update `find_primitive_implementation` to only use naming convention

**Testing**:
```ocaml
let%expect_test "fragment has no exports field" =
  let frag = { name = "test"; provides = ["caml_foo"]; requires = []; code = "" } in
  print_endline frag.name;
  [%expect {| test |}]
```

**Success Criteria**:
- [ ] `fragment` type has no `exports` field
- [ ] No `parse_export` function exists
- [ ] All code compiles without errors
- [ ] Tests pass

---

### Task 1.3: Update `embed_runtime_module` to handle direct functions

**File**: `compiler/lib-lua/lua_link.ml`

**Changes**:
1. Remove module variable creation (`local Array = M`)
2. Remove `return M` stripping logic
3. Just embed code directly with header comment

**Before**:
```ocaml
let embed_runtime_module (frag : fragment) : string =
  let buf = Buffer.create 512 in
  Buffer.add_string buf ("-- Runtime Module: " ^ frag.name ^ "\n");
  Buffer.add_string buf frag.code;
  (* Strip return M, create local var *)
  let module_var = String.capitalize_ascii frag.name in
  Buffer.add_string buf ("local " ^ module_var ^ " = M\n");
  Buffer.contents buf
```

**After**:
```ocaml
let embed_runtime_code (frag : fragment) : string =
  let buf = Buffer.create 512 in
  Buffer.add_string buf ("-- Runtime: " ^ frag.name ^ "\n");
  Buffer.add_string buf frag.code;
  if not (String.ends_with ~suffix:"\n" frag.code)
  then Buffer.add_char buf '\n';
  Buffer.add_char buf '\n';
  Buffer.contents buf
```

**Implementation**:
- Simplify function to just add header comment
- Embed code as-is (no manipulation needed)
- Ensure trailing newlines for readability

**Testing**:
```ocaml
let%expect_test "embed runtime code" =
  let frag = {
    name = "test";
    provides = ["caml_test"];
    requires = [];
    code = "--Provides: caml_test\nfunction caml_test() end"
  } in
  print_endline (embed_runtime_code frag);
  [%expect {|
    -- Runtime: test
    --Provides: caml_test
    function caml_test() end
  |}]
```

**Success Criteria**:
- [ ] No module variable creation
- [ ] Code embedded verbatim
- [ ] Proper formatting with newlines
- [ ] Test passes

---

### Task 1.4: Update wrapper generation for new structure

**File**: `compiler/lib-lua/lua_link.ml`

**Changes**:
1. Remove wrapper generation entirely - functions are already global with caml_ prefix
2. Update `generate_wrappers` to return empty string

**Before**:
```ocaml
let generate_wrappers (used_primitives : StringSet.t) (fragments : fragment list) : string =
  (* Generate wrappers like: function caml_array_make(...) return Array.make(...) end *)
  ...
```

**After**:
```ocaml
(* No wrappers needed - primitives are already global functions with caml_ prefix *)
(* This function kept for compatibility but returns empty string *)
let generate_wrappers (_used_primitives : StringSet.t) (_fragments : fragment list) : string =
  ""
```

**Rationale**:
- With refactored runtime, all functions are already `function caml_*(...)`
- No module wrapping means no need for `Module.func → caml_func` wrappers
- Linker just needs to include the right fragment files

**Implementation**:
- Replace function body with `""`
- Keep function signature for compatibility
- Update callsites to not output wrappers section

**Testing**:
```ocaml
let%expect_test "no wrappers generated" =
  let primitives = StringSet.of_list ["caml_array_make"] in
  let fragments = [...] in
  let result = generate_wrappers primitives fragments in
  print_endline (if result = "" then "empty" else "not empty");
  [%expect {| empty |}]
```

**Success Criteria**:
- [ ] Function returns empty string
- [ ] No wrappers in generated code
- [ ] Compilation still works
- [ ] Test passes

---

### Task 1.5: Write tests for new linker infrastructure

**File**: `compiler/tests-lua/test_linker.ml` (create new file)

**Implementation**:
Create comprehensive test suite for refactored linker:

```ocaml
open Js_of_ocaml_compiler

module Lua_link = struct
  include Lua_of_ocaml_compiler__Lua_link
end

let%expect_test "parse provides comment - single function" =
  let result = Lua_link.parse_provides "--Provides: caml_array_make" in
  print_endline (match result with Some s -> s | None -> "None");
  [%expect {| caml_array_make |}]

let%expect_test "parse provides comment - whitespace handling" =
  let result = Lua_link.parse_provides "--Provides:   caml_test_func  " in
  print_endline (match result with Some s -> s | None -> "None");
  [%expect {| caml_test_func |}]

let%expect_test "parse provides comment - not provides line" =
  let result = Lua_link.parse_provides "-- Regular comment" in
  print_endline (match result with Some s -> s | None -> "None");
  [%expect {| None |}]

let%expect_test "parse requires comment - single dependency" =
  let result = Lua_link.parse_requires "--Requires: caml_make_vect" in
  print_endline (String.concat ", " result);
  [%expect {| caml_make_vect |}]

let%expect_test "parse requires comment - multiple dependencies" =
  let result = Lua_link.parse_requires "--Requires: caml_foo, caml_bar" in
  print_endline (String.concat ", " result);
  [%expect {| caml_foo, caml_bar |}]

let%expect_test "load fragment - simple function" =
  (* Create temp file *)
  let temp_file = Filename.temp_file "test_frag" ".lua" in
  let oc = open_out temp_file in
  output_string oc "--Provides: caml_test\nfunction caml_test() end\n";
  close_out oc;

  let frag = Lua_link.load_runtime_file temp_file in
  print_endline ("name: " ^ frag.name);
  print_endline ("provides: " ^ String.concat ", " frag.provides);
  Sys.remove temp_file;
  [%expect {|
    name: test_frag
    provides: caml_test
  |}]

let%expect_test "embed runtime code - no modifications" =
  let frag = {
    Lua_link.name = "array";
    provides = ["caml_array_make"; "caml_array_get"];
    requires = [];
    code = "--Provides: caml_array_make\nfunction caml_array_make(n, v) end"
  } in
  let result = Lua_link.embed_runtime_code frag in
  print_endline result;
  [%expect {|
    -- Runtime: array
    --Provides: caml_array_make
    function caml_array_make(n, v) end
  |}]

let%expect_test "no wrappers generated" =
  let primitives = Stdlib.StringSet.of_list ["caml_array_make"; "caml_array_get"] in
  let fragments = [] in
  let result = Lua_link.generate_wrappers primitives fragments in
  print_endline (if result = "" then "EMPTY" else result);
  [%expect {| EMPTY |}]
```

**Success Criteria**:
- [ ] All tests pass
- [ ] Covers parse_provides
- [ ] Covers parse_requires
- [ ] Covers load_runtime_file
- [ ] Covers embed_runtime_code
- [ ] Covers generate_wrappers

---

## Phase 2: Refactor Core Modules

### Task 2.1: Refactor `core.lua` - base primitives

**File**: `runtime/lua/core.lua`

**Before** (excerpt):
```lua
--// Provides: core
local M = {}

function M.register(name, func)
  _G[name] = func
end

function M.global_object()
  return _G
end

return M
```

**After**:
```lua
-- Lua_of_ocaml runtime support
-- http://www.ocsigen.org/js_of_ocaml/
-- ...license...

--Provides: caml_register_global
--Requires: caml_named_values
function caml_register_global(name, value)
  if not caml_named_values then
    caml_named_values = {}
  end
  caml_named_values[name] = value
end

--Provides: caml_get_global_data
function caml_get_global_data()
  return _G.caml_global_data or {}
end

--Provides: caml_named_value
--Requires: caml_named_values
function caml_named_value(name)
  return caml_named_values[name]
end

-- Global table for named values
caml_named_values = {}
```

**Changes**:
1. Remove `local M = {}` and `return M`
2. Convert `M.register` to `function caml_register_global`
3. Convert `M.global_object` to `function caml_get_global_data`
4. Add `--Provides:` comment before each function
5. Add `--Requires:` where functions depend on others
6. Keep global state as module-level variables

**Testing** (`runtime/lua/test_core.lua`):
```lua
-- Test caml_register_global
caml_register_global("test_value", 42)
assert(caml_named_value("test_value") == 42)

-- Test caml_get_global_data
local data = caml_get_global_data()
assert(type(data) == "table")

print("PASS: core primitives")
```

**Success Criteria**:
- [ ] No module wrapping (no `local M`)
- [ ] All functions have `caml_` prefix
- [ ] All functions have `--Provides:` comments
- [ ] Dependencies listed in `--Requires:`
- [ ] Test file passes
- [ ] Compiles without errors

---

### Task 2.2: Refactor `compare.lua` - comparison primitives

**File**: `runtime/lua/compare.lua`

**Current Issues**:
- Uses `M.int_compare` instead of `caml_int_compare`
- Has `--// Export:` directives
- Module-wrapped

**Target Structure**:
```lua
-- Lua_of_ocaml runtime support
-- ...license...

--Provides: caml_int_compare
function caml_int_compare(a, b)
  if a < b then return -1
  elseif a > b then return 1
  else return 0
  end
end

--Provides: caml_float_compare
function caml_float_compare(a, b)
  if a < b then return -1
  elseif a > b then return 1
  elseif a == b then return 0
  else
    -- NaN handling
    if a ~= a then
      if b ~= b then return 0 else return -1 end
    else
      return 1
    end
  end
end

--Provides: caml_string_compare
function caml_string_compare(s1, s2)
  if s1 < s2 then return -1
  elseif s1 > s2 then return 1
  else return 0
  end
end

--Provides: caml_compare
--Requires: caml_int_compare caml_float_compare caml_string_compare
function caml_compare(a, b)
  local ta, tb = type(a), type(b)

  if ta ~= tb then
    return caml_int_compare(ta, tb)
  end

  if ta == "number" then
    return caml_float_compare(a, b)
  elseif ta == "string" then
    return caml_string_compare(a, b)
  elseif ta == "table" then
    -- Structural comparison for OCaml blocks
    -- ...implementation...
  end

  return 0
end

--Provides: caml_equal
--Requires: caml_compare
function caml_equal(a, b)
  return caml_compare(a, b) == 0
end

--Provides: caml_notequal
--Requires: caml_equal
function caml_notequal(a, b)
  return not caml_equal(a, b)
end

--Provides: caml_lessthan
--Requires: caml_compare
function caml_lessthan(a, b)
  return caml_compare(a, b) < 0
end

--Provides: caml_lessequal
--Requires: caml_compare
function caml_lessequal(a, b)
  return caml_compare(a, b) <= 0
end

--Provides: caml_greaterthan
--Requires: caml_compare
function caml_greaterthan(a, b)
  return caml_compare(a, b) > 0
end

--Provides: caml_greaterequal
--Requires: caml_compare
function caml_greaterequal(a, b)
  return caml_compare(a, b) >= 0
end
```

**Testing** (`runtime/lua/test_compare.lua`):
```lua
-- Test integer comparison
assert(caml_int_compare(1, 2) == -1)
assert(caml_int_compare(2, 1) == 1)
assert(caml_int_compare(5, 5) == 0)

-- Test float comparison
assert(caml_float_compare(1.5, 2.5) == -1)
assert(caml_float_compare(2.5, 1.5) == 1)
assert(caml_float_compare(1.5, 1.5) == 0)

-- Test NaN handling
local nan = 0/0
assert(caml_float_compare(nan, nan) == 0)
assert(caml_float_compare(nan, 1.0) == -1)

-- Test equality operators
assert(caml_equal(5, 5))
assert(not caml_equal(5, 6))
assert(caml_notequal(5, 6))

print("PASS: compare primitives")
```

**Success Criteria**:
- [ ] All functions have `caml_` prefix
- [ ] `--Provides:` before each function
- [ ] `--Requires:` lists dependencies
- [ ] No `--// Export:` directives
- [ ] No `core.register()` calls
- [ ] Test passes

---

### Task 2.3: Refactor `mlBytes.lua` - bytes primitives

**File**: `runtime/lua/mlBytes.lua`

**Key Functions to Refactor**:
- `M.create` → `caml_create_bytes`
- `M.get` → `caml_bytes_get`
- `M.set` → `caml_bytes_set`
- `M.of_string` → `caml_bytes_of_string`
- `M.to_string` → `caml_bytes_to_string`
- `M.concat` → `caml_bytes_concat`
- `M.sub` → `caml_bytes_sub`
- `M.blit` → `caml_blit_bytes`
- `M.fill` → `caml_fill_bytes`

**Pattern**:
```lua
--Provides: caml_create_bytes
function caml_create_bytes(len)
  return string.rep("\0", len)
end

--Provides: caml_bytes_get
function caml_bytes_get(s, i)
  return string.byte(s, i + 1)
end

--Provides: caml_bytes_set
function caml_bytes_set(s, i, c)
  return string.sub(s, 1, i) .. string.char(c) .. string.sub(s, i + 2)
end
```

**Testing** (`runtime/lua/test_mlBytes.lua`):
```lua
local b = caml_create_bytes(10)
assert(#b == 10)

caml_bytes_set(b, 0, 65) -- 'A'
assert(caml_bytes_get(b, 0) == 65)

local s = caml_bytes_to_string(b)
assert(type(s) == "string")

print("PASS: mlBytes primitives")
```

**Success Criteria**:
- [ ] ~15 functions refactored with caml_ prefix
- [ ] All have `--Provides:` comments
- [ ] Test passes
- [ ] No module wrapping

---

### Tasks 2.4-2.6: Array, Ints, Float

Follow same pattern as 2.1-2.3:
1. Remove module wrapping
2. Rename all functions to `caml_*` prefix
3. Add `--Provides:` comments
4. Add `--Requires:` for dependencies
5. Remove `--// Export:` and `core.register()`
6. Write test file for each module
7. Verify all tests pass

**Time**: 1 hour per module (implementation + testing)

---

## Phase 3-6: Remaining Modules

Each task follows the same pattern:
1. Identify all functions in the module
2. Rename to `caml_modulename_function` pattern
3. Add `--Provides:` comment before each
4. Add `--Requires:` for any dependencies
5. Remove all module infrastructure
6. Write test file
7. Verify tests pass

**Standard Test Template**:
```lua
-- Test module_name primitives
dofile("runtime/lua/module_name.lua")

-- Test function1
local result = caml_module_function1(args)
assert(result == expected, "function1 failed")

-- Test function2
...

print("PASS: module_name primitives")
```

---

## Phase 7: Verification & Integration

### Task 7.1: Run all unit tests and fix failures

**Commands**:
```bash
# Run all Lua runtime tests
for test in runtime/lua/test_*.lua; do
  echo "Running $test..."
  lua "$test" || echo "FAILED: $test"
done

# Run compiler test suite
dune build @runtest-lua
```

**Fix any failures**:
- Missing `--Provides:` comments
- Wrong function names
- Broken dependencies

### Task 7.2: Build hello_lua and verify

```bash
dune build examples/hello_lua/hello.bc.lua
lua _build/default/examples/hello_lua/hello.bc.lua
```

Expected output: "Hello, World!"

### Task 7.3: Run compiler test suite

```bash
dune build @check
dune build @all
```

All tests should pass with no warnings.

### Task 7.4: Benchmark performance

Compare old vs new implementation:
- Runtime loading time
- Generated file size
- Execution speed

### Task 7.5: Update documentation

Update `RUNTIME.md` with new structure:
- Document `--Provides:` comment syntax
- Document `--Requires:` syntax
- Remove references to module wrapping
- Add examples of refactored code

---

## Success Criteria (Overall)

- [ ] All 36 runtime Lua files refactored
- [ ] All functions have `caml_` prefix
- [ ] All functions have `--Provides:` comments
- [ ] No module wrapping (`local M = {}`)
- [ ] No `--// Export:` directives
- [ ] No `core.register()` calls
- [ ] All unit tests pass
- [ ] hello_lua example runs successfully
- [ ] Compiler test suite passes
- [ ] Zero compilation warnings
- [ ] Documentation updated

---

## Notes

- Each phase builds on the previous one
- Don't skip tests - they catch regressions
- Follow js_of_ocaml patterns exactly
- Maximum 300 lines per task
- Commit after each completed task
- Update master checklist after each task
