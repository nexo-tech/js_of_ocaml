# Marshal Implementation Plan

Comprehensive plan for implementing OCaml Marshal module in lua_of_ocaml runtime.

## Overview

The Marshal module provides serialization and deserialization of OCaml values to/from byte sequences. This is critical for:
- Data persistence
- Inter-process communication
- Network protocols
- Value sharing between environments

## Reference Implementation

- **JavaScript**: `runtime/js/marshal.js` (831 lines)
- **OCaml Source**: `stdlib/marshal.ml` and `runtime/intern.c`, `runtime/extern.c`

## Marshal Format Specification

### Magic Numbers

```
0x8495A6BE - Intext_magic_number_small (standard, 32-bit)
0x8495A6BD - Intext_magic_number_compressed (with compression)
0x8495A6BF - Intext_magic_number_big (64-bit, error on 32-bit)
```

### Header Format

**Small format (20 bytes)**:
- 4 bytes: magic number
- 4 bytes: data length
- 4 bytes: number of objects (for sharing)
- 4 bytes: size_32
- 4 bytes: size_64

**Compressed format (variable)**:
- 4 bytes: magic number
- 1 byte: header length (with flags)
- VLQ: data length
- VLQ: uncompressed data length
- VLQ: number of objects
- VLQ: size_32
- VLQ: size_64

### Value Codes

**Immediate values**:
- `0x40-0x7F`: Small integers (6-bit, 0-63)
- `0x20-0x3F`: Small strings (5-bit length, 0-31 bytes)
- `0x80-0xFF`: Small blocks (4-bit tag + 3-bit size)

**Extended codes**:
- `0x00`: INT8 (8-bit signed integer)
- `0x01`: INT16 (16-bit signed integer)
- `0x02`: INT32 (32-bit signed integer)
- `0x03`: INT64 (64-bit integer)
- `0x04`: SHARED8 (8-bit object reference)
- `0x05`: SHARED16 (16-bit object reference)
- `0x06`: SHARED32 (32-bit object reference)
- `0x07`: DOUBLE_ARRAY32_LITTLE (32-bit length, little-endian doubles)
- `0x08`: BLOCK32 (32-bit header: tag + size)
- `0x09`: STRING8 (8-bit length string)
- `0x0A`: STRING32 (32-bit length string)
- `0x0B`: DOUBLE_BIG (big-endian double)
- `0x0C`: DOUBLE_LITTLE (little-endian double)
- `0x0D`: DOUBLE_ARRAY8_BIG (8-bit length, big-endian doubles)
- `0x0E`: DOUBLE_ARRAY8_LITTLE (8-bit length, little-endian doubles)
- `0x0F`: DOUBLE_ARRAY32_BIG (32-bit length, big-endian doubles)
- `0x10`: CODEPOINTER (code pointer - error in runtime)
- `0x11`: INFIXPOINTER (infix pointer)
- `0x12`: CUSTOM (custom block with operations)
- `0x13`: BLOCK64 (64-bit header - error on 32-bit)
- `0x18`: CUSTOM_LEN (custom with explicit length)
- `0x19`: CUSTOM_FIXED (custom with fixed length)

---

## Master Checklist

### Phase 1: Core Infrastructure (Foundation)

#### Task 1.1: Binary Reader/Writer ✅
- [x] Implement byte buffer reader
  - read8u/read8s (unsigned/signed 8-bit)
  - read16u/read16s (unsigned/signed 16-bit)
  - read32u/read32s (unsigned/signed 32-bit)
  - readstr(len) (string of length)
  - Position tracking and bounds checking
- [x] Implement byte buffer writer
  - write8u (unsigned 8-bit)
  - write16u (unsigned 16-bit)
  - write32u (unsigned 32-bit)
  - writestr(str) (string bytes)
  - Buffer management and resizing
- [x] Handle endianness
  - Big-endian encoding (default for OCaml marshal)
  - Little-endian encoding (for doubles)
  - IEEE 754 double support (both endiannesses)
- **Output**: 890 lines total (442 code + 448 tests)
- **Test**: ✅ 29/29 tests pass (Lua 5.4), 23/23 (Lua 5.1/LuaJIT - no float tests)
- **Commit**: "feat(marshal): Add binary reader/writer"

#### Task 1.2: Magic Number and Header ✅
- [x] Implement header reading
  - Parse magic number
  - Read standard header (20 bytes)
  - Read compressed header (VLQ encoding)
  - Validate header length
- [x] Implement header writing
  - Write magic number (small format)
  - Write data length
  - Write object count
  - Write size fields
- [x] Variable-Length Quantity (VLQ) encoding
  - Read VLQ with overflow detection
  - Write VLQ for compression
- **Output**: 413 lines total (208 code + 205 tests)
- **Test**: ✅ 26/26 tests pass (Lua 5.4, Lua 5.1, LuaJIT)
- **Commit**: "feat(marshal): Add header parsing"

### Phase 2: Value Marshalling (Serialization)

#### Task 2.1: Immediate Values ✅
- [x] Marshal small integers (0x40-0x7F)
- [x] Marshal small strings (0x20-0x3F)
- [x] Marshal small blocks (0x80-0xFF)
- [x] Marshal extended integers
  - INT8 (0x00)
  - INT16 (0x01)
  - INT32 (0x02)
- [x] Marshal extended strings
  - STRING8 (0x09)
  - STRING32 (0x0A)
- **Output**: 734 lines total (390 code + 344 tests)
- **Test**: ✅ 43/43 tests pass (Lua 5.4, LuaJIT)
- **Commit**: "feat(marshal): Marshal immediate values"

#### Task 2.2: Structured Values ✅
- [x] Marshal blocks (BLOCK32)
  - Encode tag and size
  - Recursive field marshalling
  - Handle empty blocks
- [x] Marshal float arrays (tag 254)
  - DOUBLE_ARRAY8_LITTLE (0x0E)
  - DOUBLE_ARRAY32_LITTLE (0x07)
  - Big-endian variants
- [x] Marshal doubles
  - DOUBLE_LITTLE (0x0C)
  - DOUBLE_BIG (0x0B)
  - IEEE 754 encoding
- **Output**: 397 lines total (154 code + 243 tests)
- **Test**: ✅ 59/59 tests pass (Lua 5.4), 48/48 tests pass (LuaJIT - no float tests)
- **Commit**: "feat(marshal): Marshal structured values"

#### Task 2.3: Sharing and Cycles ✅
- [x] Implement object table
  - Track marshalled objects
  - Assign object IDs
  - Detect sharing opportunities
- [x] Detect cyclic references
  - Mark objects during traversal
  - Reference previously marshalled objects
- [x] Marshal shared references
  - SHARED8 (0x04)
  - SHARED16 (0x05)
  - SHARED32 (0x06)
- [x] Calculate object count
- **Output**: 257 lines total (152 code + 105 tests)
- **Test**: ✅ 66/66 tests pass (Lua 5.4), 54/54 tests pass (LuaJIT - no float tests)
- **Commit**: "feat(marshal): Add sharing support"

### Phase 3: Value Unmarshalling (Deserialization)

#### Task 3.1: Immediate Values ✅
- [x] Unmarshal small integers
- [x] Unmarshal small strings
- [x] Unmarshal small blocks
- [x] Unmarshal extended integers
- [x] Unmarshal extended strings
- [x] Handle immediate value edge cases
- **Output**: Already completed in Tasks 2.1-2.3
- **Test**: ✅ Covered by existing 66 tests (all roundtrip tests)
- **Note**: Unmarshalling was implemented alongside marshalling in Phase 2

#### Task 3.2: Structured Values ✅
- [x] Unmarshal blocks with stack-based algorithm
  - Parse BLOCK32 header
  - Build block incrementally
  - Handle nested structures
- [x] Unmarshal float arrays
  - Parse double array codes
  - Convert byte sequences to floats
  - Handle endianness
- [x] Unmarshal doubles
  - IEEE 754 decoding
  - Big/little endian
- **Output**: Already completed in Task 2.2
- **Test**: ✅ Covered by existing 66 tests (all roundtrip tests)
- **Note**: Unmarshalling was implemented alongside marshalling in Task 2.2

#### Task 3.3: Sharing Resolution ✅
- [x] Build intern object table
  - Store unmarshalled objects by ID
  - Handle forward references
- [x] Resolve shared references
  - SHARED8/16/32 lookup
  - Handle compressed vs uncompressed offsets
- [x] Reconstruct cyclic structures
- [x] Validate object references
- **Output**: Already completed in Task 2.3
- **Test**: ✅ Covered by existing 66 tests (all sharing/cycle tests)
- **Note**: Sharing resolution was implemented alongside marshalling in Task 2.3

### Phase 4: Custom Blocks

#### Task 4.1: Custom Block Infrastructure ✅
- [x] Define custom operations table
  - deserialize function
  - serialize function
  - compare function
  - hash function
  - fixed_length field
- [x] Register custom types
  - Int64 (_j)
  - Int32 (_i)
  - Nativeint (_n)
  - Bigarray (_bigarr02) - deferred to bigarray integration
- **Output**: 245 lines total (90 code + 137 tests + 18 I/O support)
- **Test**: ✅ 11 custom infrastructure tests pass (LuaJIT)
- **Commit**: "feat(marshal): Add custom block infrastructure"

#### Task 4.2: Custom Block Marshalling ✅
- [x] Marshal CUSTOM (0x12) - deprecated, not used
- [x] Marshal CUSTOM_LEN (0x18)
  - Write identifier (null-terminated)
  - Reserve header space (12 bytes)
  - Call custom serialize
  - Write size fields at reserved position
- [x] Marshal CUSTOM_FIXED (0x19)
  - Write identifier (null-terminated)
  - Call custom serialize
  - Verify size matches fixed_length
- [x] Handle Int64 marshalling
- [x] Handle Int32 marshalling
- [x] Handle Nativeint marshalling
- [x] Bigarray marshalling - deferred to bigarray integration
- **Output**: 291 lines total (102 code + 189 tests)
- **Test**: ✅ 11 custom marshalling tests pass (LuaJIT)
- **Commit**: "feat(marshal): Marshal custom blocks"

#### Task 4.3: Custom Block Unmarshalling ✅
- [x] Unmarshal CUSTOM blocks
  - Read null-terminated identifier
  - Lookup operations in M.custom_ops
  - Call custom deserialize
  - Verify size matches expected
  - Store in intern table
- [x] Handle size fields
  - CUSTOM (0x12): deprecated, no size checking
  - CUSTOM_FIXED (0x19): uses ops.fixed_length
  - CUSTOM_LEN (0x18): reads 12-byte size header
- [x] Unmarshal Int64 (via deserialize in Task 4.1)
- [x] Unmarshal Int32 (via deserialize in Task 4.1)
- [x] Unmarshal Nativeint (via deserialize in Task 4.1)
- [x] Bigarray unmarshalling - deferred to bigarray integration
- [x] Error handling for unknown customs
- **Output**: 279 lines total (65 code + 214 tests)
- **Test**: ✅ 12 custom unmarshalling tests pass (LuaJIT)
- **Commit**: "feat(marshal): Unmarshal custom blocks"

### Phase 5: Advanced Features

#### Task 5.1: Compression Support ✅
- [x] Detect compressed magic number (0x8495A6BD)
- [x] Implement decompression
  - Provided stub (M.decompress_input = nil)
  - Clear error message when compressed data encountered
  - Documented integration example with lua-zlib
- [x] Parse compressed headers (already in Task 1.2)
- [x] Handle compressed data
  - Added compressed flag to MarshalReader
  - Updated intern_recall for absolute vs relative offsets
  - Implemented from_bytes for full marshal format
- [x] Added utility functions (total_size, data_size)
- **Output**: 206 lines total (87 code + 119 tests)
- **Test**: ✅ 8 compression tests pass (LuaJIT)
- **Commit**: "feat(marshal): Add compression support"

#### Task 5.2: Marshal Flags ✅
- [x] Implement marshal flags
  - M.No_sharing (0) - disables sharing
  - M.Closures (1) - errors (not supported)
  - M.Compat_32 (2) - accepted but no-op
- [x] Respect flags during marshalling
  - parse_flags() helper function
  - to_string(value, flags) high-level API
  - Passes no_sharing to MarshalWriter
- [x] Validate flags during unmarshalling
  - Closures flag triggers error
  - Compat_32 silently accepted
- **Output**: 199 lines total (86 code + 113 tests)
- **Test**: ✅ 12 flag behavior tests pass (LuaJIT)
- **Commit**: "feat(marshal): Add marshal flags"

#### Task 5.3: Object Tags ✅
- [x] Handle special tags
  - Tag 248: Object blocks (need oo_id) ✅ Tracked and assigned oo_id
  - Tag 249: Lazy values ✅ Allowed (no special handling)
  - Tag 250: Forward blocks ✅ Allowed (no special handling)
  - Tag 251: Abstract tags ✅ Allowed (no special handling)
  - Tag 252: Closures (error) ✅ Errors on read
  - Tag 253: Infix pointers ✅ Allowed (no special handling)
  - Tag 254: Float arrays ✅ Already handled by DOUBLE_ARRAY codes
  - Tag 255: Custom blocks ✅ Already handled by CUSTOM codes
- [x] Set object IDs for tag 248
  - Global oo_last_id counter
  - set_oo_id() function
  - Objects tracked during read, finalized after
- [x] Error on unsupported tags
  - CODE_BLOCK64 (0x13): Errors with "data block too large"
  - CODE_CODEPOINTER (0x10): Errors with "code pointer not supported"
  - CODE_INFIXPOINTER (0x11): Errors with "infix pointer not supported"
  - Tag 252 (closures): Errors with "closure blocks not supported"
- **Output**: 293 lines total (91 code + 202 tests)
- **Test**: ✅ 11 special tag tests (tag constants, error cases, oo_id tracking)
- **Commit**: "feat(marshal): Handle special tags"

### Phase 6: API and Integration

#### Task 6.1: Public API ✅
- [x] Implement `Marshal.to_bytes(v, flags)` ✅ Alias for to_string
- [x] Implement `Marshal.from_bytes(s, ofs)` ✅ Unmarshals complete format
- [x] Implement `Marshal.to_string(v, flags)` ✅ Produces complete marshal format (header + data)
- [x] Implement `Marshal.from_string(s, ofs)` ✅ Alias for from_bytes
- [x] Implement `Marshal.total_size(s, ofs)` ✅ Returns total size (header + data)
- [x] Implement `Marshal.data_size(s, ofs)` ✅ Returns data size only
- [ ] Implement `Marshal.to_channel(ch, v, flags)` (deferred - I/O integration)
- [ ] Implement `Marshal.from_channel(ch)` (deferred - I/O integration)
- **Output**: 176 lines total (11 code + 165 tests)
- **Test**: ✅ 17 API usage tests (aliases, offsets, roundtrips, metadata)
- **Commit**: "feat(marshal): Complete public API"

#### Task 6.2: Block Field Marshalling ✅
- [x] Implement recursive field marshalling for blocks
  - ✅ Stack-based iteration to avoid recursion depth issues
  - ✅ Handle blocks with `tag` and `size` fields
  - ✅ Handle plain Lua tables as tag-0 blocks
  - ✅ Marshal block fields after block header
- [x] Support arbitrary Lua tables
  - ✅ Treat tables without `tag`/`size` as OCaml blocks (tag 0)
  - ✅ Use array part of table as block fields
  - ✅ Handle nil fields (marshal as unit/0)
- [x] Update unmarshal to reconstruct blocks with fields
  - ✅ Split `read_value` into `read_value_core` + stack loop
  - ✅ Use `{block = v, index = 1, size = v.size}` pattern
  - ✅ Read fields iteratively and store in `block[index]`
- **Output**: 204 lines total (~120 code + 84 tests)
- **Test**: ✅ 10/10 tests pass in test_marshal_blocks.lua (simple arrays, nested tables, complex structures, large arrays)
- **Commit**: "feat(marshal): Complete block field marshalling"

#### Task 6.3: Error Handling ✅
- [x] Validate input parameters
  - ✅ Type checking for value, flags, string, offset
  - ✅ Range validation for offsets (non-negative)
  - ✅ Nil value rejection in to_string
- [x] Handle truncated data
  - ✅ Minimum header size validation (20 bytes)
  - ✅ Data length verification against header claims
  - ✅ Protected header parsing with pcall
  - ✅ Clear error messages with byte counts
- [x] Handle corrupted data
  - ✅ Invalid magic number detection
  - ✅ Unknown value code detection (with hex display)
  - ✅ Invalid shared reference bounds checking
  - ✅ Protected read operations with pcall
- [x] Provide meaningful error messages
  - ✅ Specific error prefixes (Marshal.to_string, Marshal.from_bytes)
  - ✅ Include diagnostic info (byte counts, types, hex codes)
  - ✅ Distinguish between truncation and corruption
- [x] Handle unsupported features gracefully
  - ✅ Closures flag rejection with clear message
  - ✅ Code pointer rejection
  - ✅ 64-bit block rejection
  - ✅ Compression support check with helpful message
- **Output**: 65 lines (marshal.lua improvements)
- **Test**: ✅ 25/25 tests passed (test_marshal_errors.lua)
  - ✅ Input validation (5 tests)
  - ✅ Truncated data (4 tests)
  - ✅ Corrupted data (3 tests)
  - ✅ Unsupported features (3 tests)
  - ✅ Edge cases (3 tests)
  - ✅ Error message quality (3 tests)
  - ✅ Recovery and partial data (4 tests)
- **Commit**: "feat(marshal): Add comprehensive error handling"

### Phase 7: Testing and Validation

#### Task 7.1: Unit Tests
- [x] Test all value types
- [x] Test immediate values
- [x] Test structured values
- [x] Test sharing and cycles
- [x] Test custom blocks
- [x] Test edge cases
- **Output**: 423 lines (test_marshal_unit.lua)
- **Tests**: 62 comprehensive tests covering all marshal functionality
- **Commit**: "test(marshal): Add comprehensive unit tests"

#### Task 7.2: Roundtrip Tests
- [x] Test marshal → unmarshal roundtrips
- [x] Test various data structures
  - Lists (empty, single, multiple, long)
  - Trees (leaf, single node, balanced, deep)
  - Graphs with cycles (self-ref, 2-node, 3-node, DAG)
  - Records (simple, nested, optional fields, large)
  - Variants (None/Some, Ok/Error, complex constructors)
- [x] Test custom types (Int64, Int32, records with custom, lists of custom)
- [x] Test large data (1MB string, 1000-element arrays/lists, deep nesting, wide graphs)
- **Output**: 456 lines (test_marshal_roundtrip.lua)
- **Tests**: 35 comprehensive roundtrip tests for realistic OCaml data structures
- **Commit**: "test(marshal): Add roundtrip tests"

#### Task 7.3: Compatibility Tests
- [x] Test against OCaml-marshalled data
  - Generate test data with OCaml (gen_marshal_test_data.ml)
  - Unmarshal in Lua (test_marshal_compat.lua)
- [x] Test against js_of_ocaml
  - Verify format compatibility (same format as js_of_ocaml)
  - Test sharing and cycles
- [x] Test version compatibility (OCaml marshal format)
- **Output**: 103 lines (gen_marshal_test_data.ml) + 355 lines (test_marshal_compat.lua)
- **Tests**: 42 compatibility tests covering OCaml-generated marshal data
- **Commit**: "test(marshal): Add compatibility tests"

#### Task 7.4: Performance Tests
- [x] Benchmark marshalling speed
- [x] Benchmark unmarshalling speed
- [x] Compare with json encoding
- [x] Profile memory usage
- **Output**: 351 lines (benchmark_marshal.lua)
- **Benchmarks**: Marshalling, unmarshalling, roundtrip, JSON comparison, memory profiling
- **Commit**: "test(marshal): Add performance benchmarks"

### Phase 8: Documentation

#### Task 8.1: Implementation Documentation
- [x] Document marshal format (complete specification with all codes)
- [x] Document custom block interface (structure, encoding, examples)
- [x] Document limitations (unsupported features, platform-specific)
- [x] Document Lua-specific considerations (value representation, NaN handling, performance)
- **Output**: 192 lines (inline documentation in marshal.lua)
- **Coverage**: Format spec, encoding schemes, custom blocks, sharing/cycles, flags, limitations, compatibility, usage examples
- **Commit**: "docs(marshal): Add implementation documentation"

#### Task 8.2: User Documentation
- [ ] Write usage guide
- [ ] Provide examples
- [ ] Document API
- [ ] Document compatibility notes
- **Output**: ~150 lines
- **Commit**: "docs(marshal): Add user documentation"

---

## Implementation Summary

### Total Estimated Output
- Code: ~1900 lines (marshal.lua)
- Tests: ~530 lines (test_marshal.lua)
- Docs: ~350 lines (comments + MARSHAL.md)
- **Total**: ~2780 lines

### Critical Requirements

1. **Exact Format Compatibility**: Must match OCaml marshal format byte-for-byte
2. **Sharing Support**: Essential for cyclic structures and large data
3. **Custom Blocks**: Required for Int64, Bigarray, and extensibility
4. **Endianness**: Handle both big-endian and little-endian doubles
5. **Error Handling**: Graceful failures with clear error messages

### Lua-Specific Considerations

1. **No native typed arrays**: Use string.pack/unpack (Lua 5.3+) or manual byte manipulation
2. **No native compression**: Require external library or skip compression support
3. **Table as array**: OCaml arrays map to Lua tables (1-indexed or 0-indexed with metadata)
4. **Floating point**: Ensure IEEE 754 compatibility
5. **Integer limits**: Lua 5.1/5.2 have 53-bit precision, need careful handling

### Dependencies

- `mlBytes.lua`: For byte sequence manipulation
- `array.lua`: For array operations
- `bigarray.lua`: For bigarray custom blocks (Task 4.3)
- `io.lua`: Optional, for channel operations

### Testing Strategy

1. **Unit tests**: Test each code path individually
2. **Roundtrip tests**: Marshal → Unmarshal for all types
3. **Compatibility tests**: Against OCaml-generated data
4. **Edge cases**: Empty values, large values, deep nesting
5. **Error cases**: Invalid data, truncated data, unsupported features

---

## Getting Started

Begin with Phase 1 (Core Infrastructure):
1. Implement binary reader/writer (Task 1.1)
2. Implement header parsing (Task 1.2)
3. Test with simple integer marshalling

Then proceed through phases sequentially, ensuring each phase is complete before moving to the next.
