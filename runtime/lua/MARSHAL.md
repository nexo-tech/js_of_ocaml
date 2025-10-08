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

#### Task 4.3: Custom Block Unmarshalling
- [ ] Unmarshal CUSTOM blocks
  - Read identifier
  - Lookup operations
  - Call custom deserialize
- [ ] Handle size fields
  - Fixed length
  - Variable length with VLQ
- [ ] Unmarshal Int64
- [ ] Unmarshal Bigarray
- [ ] Error handling for unknown customs
- **Output**: ~100 lines
- **Test**: Custom unmarshal tests
- **Commit**: "feat(marshal): Unmarshal custom blocks"

### Phase 5: Advanced Features

#### Task 5.1: Compression Support
- [ ] Detect compressed magic number
- [ ] Implement decompression
  - Integrate with Lua compression library if available
  - Or provide stub with error message
- [ ] Parse compressed headers
- [ ] Handle compressed data
- **Output**: ~80 lines
- **Test**: Compression tests (or skip tests)
- **Commit**: "feat(marshal): Add compression support"

#### Task 5.2: Marshal Flags
- [ ] Implement marshal flags
  - No_sharing flag
  - Closures flag (error)
  - Compat_32 flag
- [ ] Respect flags during marshalling
- [ ] Validate flags during unmarshalling
- **Output**: ~60 lines
- **Test**: Flag behavior tests
- **Commit**: "feat(marshal): Add marshal flags"

#### Task 5.3: Object Tags
- [ ] Handle special tags
  - Tag 248: Object blocks (need oo_id)
  - Tag 249: Lazy values
  - Tag 250: Forward blocks
  - Tag 251: Abstract tags
  - Tag 252: Closures (error)
  - Tag 253: Infix pointers
  - Tag 254: Float arrays
  - Tag 255: Custom blocks
- [ ] Set object IDs for tag 248
- [ ] Error on unsupported tags
- **Output**: ~70 lines
- **Test**: Special tag tests
- **Commit**: "feat(marshal): Handle special tags"

### Phase 6: API and Integration

#### Task 6.1: Public API
- [ ] Implement `Marshal.to_bytes(v, flags)`
- [ ] Implement `Marshal.from_bytes(s, ofs)`
- [ ] Implement `Marshal.to_string(v, flags)` (alias)
- [ ] Implement `Marshal.from_string(s, ofs)` (alias)
- [ ] Implement `Marshal.total_size(s, ofs)`
- [ ] Implement `Marshal.data_size(s, ofs)`
- [ ] Implement `Marshal.to_channel(ch, v, flags)` (if IO available)
- [ ] Implement `Marshal.from_channel(ch)` (if IO available)
- **Output**: ~80 lines
- **Test**: API usage tests
- **Commit**: "feat(marshal): Complete public API"

#### Task 6.2: Error Handling
- [ ] Validate input parameters
- [ ] Handle truncated data
- [ ] Handle corrupted data
- [ ] Provide meaningful error messages
- [ ] Handle unsupported features gracefully
- **Output**: ~50 lines
- **Test**: Error case tests
- **Commit**: "feat(marshal): Add comprehensive error handling"

### Phase 7: Testing and Validation

#### Task 7.1: Unit Tests
- [ ] Test all value types
- [ ] Test immediate values
- [ ] Test structured values
- [ ] Test sharing and cycles
- [ ] Test custom blocks
- [ ] Test edge cases
- **Output**: ~200 lines
- **Test**: Run unit tests
- **Commit**: "test(marshal): Add comprehensive unit tests"

#### Task 7.2: Roundtrip Tests
- [ ] Test marshal → unmarshal roundtrips
- [ ] Test various data structures
  - Lists
  - Trees
  - Graphs with cycles
  - Records
  - Variants
- [ ] Test custom types
- [ ] Test large data
- **Output**: ~150 lines
- **Test**: Roundtrip validation
- **Commit**: "test(marshal): Add roundtrip tests"

#### Task 7.3: Compatibility Tests
- [ ] Test against OCaml-marshalled data
  - Generate test data with OCaml
  - Unmarshal in Lua
- [ ] Test against js_of_ocaml
  - Compare behavior
  - Verify format compatibility
- [ ] Test version compatibility
- **Output**: ~100 lines
- **Test**: Cross-platform validation
- **Commit**: "test(marshal): Add compatibility tests"

#### Task 7.4: Performance Tests
- [ ] Benchmark marshalling speed
- [ ] Benchmark unmarshalling speed
- [ ] Compare with json encoding
- [ ] Profile memory usage
- **Output**: ~80 lines
- **Test**: Performance benchmarks
- **Commit**: "test(marshal): Add performance benchmarks"

### Phase 8: Documentation

#### Task 8.1: Implementation Documentation
- [ ] Document marshal format
- [ ] Document custom block interface
- [ ] Document limitations
- [ ] Document Lua-specific considerations
- **Output**: ~200 lines (comments + docs)
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
