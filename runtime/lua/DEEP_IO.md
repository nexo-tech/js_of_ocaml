# Deep I/O Integration Plan

Comprehensive plan for completing full-featured I/O support in lua_of_ocaml runtime, including channels, marshaling, formatting, and advanced features.

## Overview

The I/O system is a critical part of the OCaml runtime, providing:
- Channel-based I/O (in_channel, out_channel)
- Marshal serialization/deserialization over channels
- Format module (Printf/Scanf-style formatting)
- Binary and text I/O modes
- Buffering and seeking
- Integration with filesystem operations

## Current Status

### Completed Modules
- **io.lua** (595 lines): Basic channel operations, file descriptors
  - ✅ File descriptor management (caml_sys_open, caml_sys_close)
  - ✅ Channel creation (caml_ml_open_descriptor_in/out)
  - ✅ Basic I/O (caml_ml_input_char, caml_ml_output_char)
  - ✅ Binary I/O (caml_ml_input, caml_ml_output)
  - ✅ Channel seeking (caml_ml_seek_in, caml_ml_pos_out, etc.)
  - ✅ Integer I/O (caml_ml_input_int, caml_ml_output_int)
  - ⚠️ Marshal I/O stubs (caml_input_value, caml_output_value)

- **marshal.lua** (1221 lines): Marshal format implementation
  - ✅ Complete marshal format (Task 5.2)
  - ✅ Special tag handling (Task 5.3)
  - ✅ Public API (Task 6.1)
  - ✅ to_string/from_string APIs
  - ⚠️ No channel integration

- **marshal_io.lua** (452 lines): Binary reader/writer
- **marshal_header.lua** (234 lines): Header parsing/writing

### Missing Components
1. **Marshal channel I/O**: Connect marshal.lua to io.lua channels
2. **Format module**: Printf/Scanf formatting
3. **Lexing module**: Token scanning support
4. **Parsing module**: Parser state management
5. **Compare module**: Deep structural comparison
6. **Hash module**: Polymorphic hashing
7. **Sys module**: System information and environment
8. **Filename module**: Path manipulation
9. **Buffer module**: Extensible string buffers
10. **Stream module**: Lazy stream operations
11. **Queue module**: FIFO queue operations
12. **Stack module**: LIFO stack operations
13. **Hashtbl module**: Mutable hash tables
14. **Map/Set modules**: Balanced binary trees

## Reference Implementations

- **JavaScript**: `runtime/js/io.js` (726 lines)
- **JavaScript**: `runtime/js/marshal.js` (831 lines)
- **JavaScript**: `runtime/js/format.js` (~500 lines)
- **JavaScript**: `runtime/js/lexing.js` (~300 lines)
- **JavaScript**: `runtime/js/parsing.js` (~200 lines)
- **OCaml Source**: `stdlib/` directory

---

## Master Checklist

### Phase 1: Marshal Channel Integration

#### Task 1.1: Marshal Input from Channels ✅
- [x] Implement `caml_input_value(chanid)` in io.lua
  - ✅ Read marshal header from channel (20 bytes)
  - ✅ Read data based on header.data_len
  - ✅ Call marshal.from_bytes() with complete data
  - ✅ Handle EOF and truncated data
- [x] Implement `caml_input_value_to_outside_heap(chanid)` (alias)
- [x] Handle buffered channel reads correctly
  - ✅ Uses caml_ml_input which handles buffering
- [x] Preserve channel offset tracking
  - ✅ caml_ml_input updates channel.offset
- **Output**: 457 lines total (60 code + 397 tests)
- **Test**: ✅ 14 roundtrip tests (integers, strings, floats, blocks, arrays, multiple values, EOF, truncation, binary mode)
- **Commit**: "feat(io): Implement marshal input from channels"

#### Task 1.2: Marshal Output to Channels ✅
- [x] Implement `caml_output_value(chanid, v, flags)` in io.lua
  - ✅ Call marshal.to_string(v, flags)
  - ✅ Write complete marshal data to channel
  - ✅ Flush channel buffer if needed
- [x] Handle channel buffering correctly
  - ✅ Uses caml_ml_output which handles buffering modes
  - ✅ Respects unbuffered (0), line-buffered (2), fully-buffered (1)
- [x] Update channel offset tracking
  - ✅ caml_ml_output updates channel.offset automatically
- **Output**: 309 lines total (25 code + 284 tests)
- **Test**: ✅ 12 tests (write values, flags, multiple values, complete roundtrips)
- **Commit**: "feat(io): Implement marshal output to channels"

#### Task 1.3: Marshal Channel API
- [ ] Add `marshal.to_channel(ch, v, flags)` in marshal.lua
  - Convert channel ID to internal format
  - Call caml_output_value()
  - Handle errors gracefully
- [ ] Add `marshal.from_channel(ch)` in marshal.lua
  - Convert channel ID to internal format
  - Call caml_input_value()
  - Return unmarshalled value
- **Output**: ~40 lines
- **Test**: High-level marshal channel API tests
- **Commit**: "feat(marshal): Add channel I/O API"

#### Task 1.4: Marshal Integration Tests
- [ ] Test marshal roundtrip through files
- [ ] Test marshal with large data structures
- [ ] Test marshal with sharing enabled/disabled
- [ ] Test error handling (truncated data, corrupted data)
- [ ] Test binary mode channels
- **Output**: ~150 lines (tests)
- **Test**: Comprehensive marshal I/O test suite
- **Commit**: "test(marshal): Add channel I/O integration tests"

### Phase 2: Format Module (Printf/Scanf)

#### Task 2.1: Format String Parsing
- [ ] Create `runtime/lua/format.lua`
- [ ] Implement format string tokenizer
  - Parse conversion specifiers (%d, %s, %f, etc.)
  - Parse flags (+, -, 0, space, #)
  - Parse width and precision
  - Handle %% escaping
- [ ] Build format specification AST
- **Output**: ~200 lines
- **Test**: Format string parsing tests
- **Commit**: "feat(format): Implement format string parser"

#### Task 2.2: Printf-style Formatting
- [ ] Implement caml_format_int (format integers with width/flags)
- [ ] Implement caml_format_float (format floats with precision)
- [ ] Implement caml_format_string (format strings with width)
- [ ] Implement caml_format_char (format characters)
- [ ] Handle special formats (%a, %t for custom formatters)
- [ ] Implement Printf.sprintf equivalent
- **Output**: ~250 lines
- **Test**: Printf formatting tests
- **Commit**: "feat(format): Implement Printf-style formatting"

#### Task 2.3: Scanf-style Parsing
- [ ] Implement input format parser
- [ ] Implement caml_scan_int (parse integers)
- [ ] Implement caml_scan_float (parse floats)
- [ ] Implement caml_scan_string (parse strings)
- [ ] Implement caml_scan_char (parse characters)
- [ ] Handle whitespace and delimiters
- [ ] Implement Scanf.sscanf equivalent
- **Output**: ~300 lines
- **Test**: Scanf parsing tests
- **Commit**: "feat(format): Implement Scanf-style parsing"

#### Task 2.4: Format Channel Integration
- [ ] Implement Printf.fprintf (format to output channel)
- [ ] Implement Printf.printf (format to stdout)
- [ ] Implement Printf.eprintf (format to stderr)
- [ ] Implement Scanf.fscanf (scan from input channel)
- [ ] Implement Scanf.scanf (scan from stdin)
- **Output**: ~100 lines
- **Test**: Format channel I/O tests
- **Commit**: "feat(format): Add channel formatting I/O"

### Phase 3: Core Data Structures

#### Task 3.1: Buffer Module
- [ ] Create `runtime/lua/buffer.lua`
- [ ] Implement extensible string buffer
  - caml_buffer_create
  - caml_buffer_add_char
  - caml_buffer_add_string
  - caml_buffer_add_substring
  - caml_buffer_contents
  - caml_buffer_length
  - caml_buffer_reset
  - caml_buffer_clear
- [ ] Implement efficient buffer growth strategy
- **Output**: ~150 lines
- **Test**: Buffer operations tests
- **Commit**: "feat(buffer): Implement extensible string buffers"

#### Task 3.2: Queue Module
- [ ] Create `runtime/lua/queue.lua`
- [ ] Implement FIFO queue operations
  - caml_queue_create
  - caml_queue_add (enqueue)
  - caml_queue_take (dequeue)
  - caml_queue_peek
  - caml_queue_is_empty
  - caml_queue_length
  - caml_queue_clear
- [ ] Handle Queue.Empty exception
- **Output**: ~120 lines
- **Test**: Queue operations tests
- **Commit**: "feat(queue): Implement FIFO queue operations"

#### Task 3.3: Stack Module
- [ ] Create `runtime/lua/stack.lua`
- [ ] Implement LIFO stack operations
  - caml_stack_create
  - caml_stack_push
  - caml_stack_pop
  - caml_stack_top
  - caml_stack_is_empty
  - caml_stack_length
  - caml_stack_clear
- [ ] Handle Stack.Empty exception
- **Output**: ~100 lines
- **Test**: Stack operations tests
- **Commit**: "feat(stack): Implement LIFO stack operations"

#### Task 3.4: Hashtbl Module
- [ ] Create `runtime/lua/hashtbl.lua`
- [ ] Implement mutable hash table
  - caml_hash_create (with initial size)
  - caml_hash_add
  - caml_hash_find
  - caml_hash_find_opt
  - caml_hash_remove
  - caml_hash_replace
  - caml_hash_mem
  - caml_hash_length
  - caml_hash_clear
  - caml_hash_iter
  - caml_hash_fold
- [ ] Implement resize and rehashing
- [ ] Use polymorphic hash function
- **Output**: ~300 lines
- **Test**: Hashtbl operations tests
- **Commit**: "feat(hashtbl): Implement mutable hash tables"

### Phase 4: Comparison and Hashing

#### Task 4.1: Deep Structural Comparison
- [ ] Create `runtime/lua/compare.lua`
- [ ] Implement caml_compare (polymorphic comparison)
  - Handle integers, floats, strings
  - Handle blocks (recursive comparison)
  - Handle custom blocks (use custom compare)
  - Handle cycles (with visited set)
  - Return -1, 0, 1 like OCaml
- [ ] Implement caml_equal (equality check)
- [ ] Implement caml_notequal
- [ ] Implement caml_lessthan, caml_lessequal, etc.
- **Output**: ~250 lines
- **Test**: Deep comparison tests with complex structures
- **Commit**: "feat(compare): Implement polymorphic comparison"

#### Task 4.2: Polymorphic Hashing
- [ ] Create `runtime/lua/hash.lua`
- [ ] Implement caml_hash (polymorphic hash function)
  - Hash integers, floats, strings
  - Hash blocks recursively
  - Hash custom blocks (use custom hash)
  - Handle cycles (with visited set)
  - Use mixing function for good distribution
- [ ] Implement caml_hash_mix_int
- [ ] Implement caml_hash_mix_string
- [ ] Compatible with Hashtbl module
- **Output**: ~200 lines
- **Test**: Hash distribution and collision tests
- **Commit**: "feat(hash): Implement polymorphic hashing"

### Phase 5: Lexing and Parsing Support

#### Task 5.1: Lexing Module
- [ ] Create `runtime/lua/lexing.lua`
- [ ] Implement lexbuf structure
  - Input buffer management
  - Position tracking (lex_start_p, lex_curr_p)
  - Token boundaries
- [ ] Implement caml_lex_engine (DFA-based lexer)
- [ ] Implement position tracking
  - Line numbers
  - Column numbers
  - Character offsets
- [ ] Handle input sources (string, channel, function)
- **Output**: ~300 lines
- **Test**: Lexer position tracking tests
- **Commit**: "feat(lexing): Implement lexer support"

#### Task 5.2: Parsing Module
- [ ] Create `runtime/lua/parsing.lua`
- [ ] Implement parse stack
- [ ] Implement caml_parse_engine (LR parser)
- [ ] Implement error recovery
- [ ] Track parse positions for errors
- [ ] Integrate with lexing module
- **Output**: ~250 lines
- **Test**: Parser state management tests
- **Commit**: "feat(parsing): Implement parser support"

### Phase 6: System and Filesystem

#### Task 6.1: Sys Module
- [ ] Create `runtime/lua/sys.lua`
- [ ] Implement caml_sys_argv (program arguments)
- [ ] Implement caml_sys_get_config (OCaml config)
- [ ] Implement caml_sys_getenv (environment variables)
- [ ] Implement caml_sys_time (elapsed time)
- [ ] Implement caml_sys_file_exists
- [ ] Implement caml_sys_is_directory
- [ ] Implement caml_sys_remove (delete file)
- [ ] Implement caml_sys_rename (rename file)
- [ ] Implement caml_sys_chdir (change directory)
- [ ] Implement caml_sys_getcwd (get current directory)
- [ ] Implement caml_sys_readdir (list directory)
- **Output**: ~350 lines
- **Test**: Filesystem operations tests
- **Commit**: "feat(sys): Implement system operations"

#### Task 6.2: Filename Module
- [ ] Create `runtime/lua/filename.lua`
- [ ] Implement caml_filename_concat (join paths)
- [ ] Implement caml_filename_basename
- [ ] Implement caml_filename_dirname
- [ ] Implement caml_filename_check_suffix
- [ ] Implement caml_filename_chop_suffix
- [ ] Implement caml_filename_chop_extension
- [ ] Implement caml_filename_is_relative
- [ ] Implement caml_filename_is_implicit
- [ ] Handle platform differences (Unix vs Windows paths)
- **Output**: ~200 lines
- **Test**: Path manipulation tests
- **Commit**: "feat(filename): Implement path operations"

### Phase 7: Advanced Collections

#### Task 7.1: Map Module (Balanced Trees)
- [ ] Create `runtime/lua/map.lua`
- [ ] Implement AVL tree or Red-Black tree
- [ ] Implement caml_map_empty
- [ ] Implement caml_map_add
- [ ] Implement caml_map_find
- [ ] Implement caml_map_find_opt
- [ ] Implement caml_map_remove
- [ ] Implement caml_map_mem
- [ ] Implement caml_map_iter
- [ ] Implement caml_map_fold
- [ ] Implement caml_map_for_all
- [ ] Implement tree balancing
- **Output**: ~400 lines
- **Test**: Map operations and balancing tests
- **Commit**: "feat(map): Implement balanced tree maps"

#### Task 7.2: Set Module (Balanced Trees)
- [ ] Create `runtime/lua/set.lua`
- [ ] Implement AVL tree or Red-Black tree (similar to Map)
- [ ] Implement caml_set_empty
- [ ] Implement caml_set_add
- [ ] Implement caml_set_remove
- [ ] Implement caml_set_mem
- [ ] Implement caml_set_union
- [ ] Implement caml_set_inter (intersection)
- [ ] Implement caml_set_diff (difference)
- [ ] Implement caml_set_iter
- [ ] Implement caml_set_fold
- **Output**: ~350 lines
- **Test**: Set operations tests
- **Commit**: "feat(set): Implement balanced tree sets"

### Phase 8: Stream Module

#### Task 8.1: Stream Operations
- [ ] Create `runtime/lua/stream.lua`
- [ ] Implement lazy stream structure
  - Stream.empty
  - Stream.cons (lazy cons cell)
  - Stream.of_list
  - Stream.of_channel
  - Stream.of_string
- [ ] Implement stream consumption
  - Stream.next (get and remove first element)
  - Stream.peek (get first without removing)
  - Stream.junk (remove first element)
  - Stream.npeek (peek N elements)
- [ ] Implement stream constructors
  - Stream.from (from function)
  - Stream.of_list
  - Stream.of_string
- [ ] Handle Stream.Failure exception
- **Output**: ~200 lines
- **Test**: Stream operations tests
- **Commit**: "feat(stream): Implement lazy streams"

### Phase 9: Integration and Testing

#### Task 9.1: Complete I/O Integration Tests
- [ ] Test marshal + channels + files
- [ ] Test Printf/Scanf with channels
- [ ] Test binary vs text mode
- [ ] Test buffering behavior
- [ ] Test seeking in files
- [ ] Test channel lifecycle (open/close/flush)
- [ ] Test error conditions
- **Output**: ~300 lines (tests)
- **Test**: End-to-end I/O test suite
- **Commit**: "test(io): Add comprehensive integration tests"

#### Task 9.2: Performance Benchmarks
- [ ] Benchmark marshal serialization speed
- [ ] Benchmark channel I/O throughput
- [ ] Benchmark buffer operations
- [ ] Benchmark hashtable operations
- [ ] Benchmark comparison/hashing
- [ ] Compare with JavaScript runtime
- **Output**: ~200 lines (benchmarks)
- **Test**: Performance regression tests
- **Commit**: "perf(io): Add performance benchmarks"

#### Task 9.3: Documentation
- [ ] Document channel API
- [ ] Document marshal channel integration
- [ ] Document format module usage
- [ ] Document data structure modules
- [ ] Add usage examples
- [ ] Document limitations and platform differences
- **Output**: ~400 lines (markdown)
- **Commit**: "docs(io): Add comprehensive I/O documentation"

### Phase 10: Advanced Features (Optional)

#### Task 10.1: In-Memory Channels
- [ ] Implement string-based input channels
- [ ] Implement buffer-based output channels
- [ ] Support marshal to/from memory
- **Output**: ~150 lines
- **Test**: In-memory channel tests
- **Commit**: "feat(io): Add in-memory channels"

#### Task 10.2: Custom Channel Backends
- [ ] Define channel backend interface
- [ ] Allow custom read/write implementations
- [ ] Support network channels (if applicable)
- [ ] Support compressed channels
- **Output**: ~200 lines
- **Test**: Custom channel backend tests
- **Commit**: "feat(io): Add custom channel backends"

#### Task 10.3: Digest Module (MD5/SHA)
- [ ] Create `runtime/lua/digest.lua`
- [ ] Implement MD5 hashing (or use LuaCrypto)
- [ ] Implement caml_md5_string
- [ ] Implement caml_md5_chan
- **Output**: ~300 lines (or ~50 if using library)
- **Test**: Digest tests
- **Commit**: "feat(digest): Add cryptographic hashing"

---

## Architecture Notes

### Channel Structure
```lua
channel = {
  file = <Lua file handle>,
  fd = <file descriptor number>,
  flags = {rdonly, wronly, binary, append, etc.},
  opened = true/false,
  out = true/false,  -- true for output, false for input
  buffer = "" or {},  -- string for input, array for output
  buffer_pos = 1,     -- current position in buffer
  offset = 0          -- current file position
}
```

### Marshal Channel Integration Pattern
```lua
-- Input (from channel)
function caml_input_value(chanid)
  -- 1. Read header (20 bytes for standard format)
  local header_bytes = caml_ml_input(chanid, header_buf, 0, 20)

  -- 2. Parse header to get data length
  local header = marshal_header.read_header(header_bytes, 0)

  -- 3. Read data based on header.data_len
  local data_bytes = caml_ml_input(chanid, data_buf, 0, header.data_len)

  -- 4. Unmarshal from complete bytes (header + data)
  local complete = header_bytes .. data_bytes
  return marshal.from_bytes(complete, 0)
end

-- Output (to channel)
function caml_output_value(chanid, v, flags)
  -- 1. Marshal value (produces header + data)
  local marshalled = marshal.to_string(v, flags)

  -- 2. Write to channel
  caml_ml_output(chanid, marshalled, 0, #marshalled)

  -- 3. Flush if needed
  caml_ml_flush(chanid)
end
```

### Format String Parsing
```lua
-- Format spec: %[flags][width][.precision]type
format_spec = {
  type = 'd',         -- d, s, f, c, etc.
  flags = {           -- +, -, 0, space, #
    plus = false,
    minus = false,
    zero = false,
    space = false,
    hash = false
  },
  width = nil,        -- field width (number or '*')
  precision = nil     -- precision (number or '*')
}
```

### Hashtbl Resize Strategy
```lua
-- Load factor threshold: 2.0 (resize when size > 2 * buckets)
-- Growth factor: 2x
-- Use prime bucket counts for better distribution
-- Rehash on resize to redistribute entries
```

### Comparison Algorithm
```lua
function caml_compare(a, b, visited)
  -- 1. Check visited set (cycle detection)
  -- 2. Compare by type
  -- 3. For blocks: compare tag, then size, then fields recursively
  -- 4. For custom blocks: use custom compare operation
  -- 5. Return -1 (less), 0 (equal), 1 (greater)
end
```

## Dependencies and Integration Points

### Internal Dependencies
- **marshal.lua** → **io.lua**: Marshal channel I/O
- **format.lua** → **io.lua**: Printf/Scanf channel operations
- **lexing.lua** → **io.lua**: Lexer input from channels
- **hashtbl.lua** → **hash.lua**: Polymorphic hashing
- **map.lua** → **compare.lua**: Element ordering
- **set.lua** → **compare.lua**: Element ordering

### External Libraries (Optional)
- **LuaFileSystem (lfs)**: Advanced filesystem operations
- **LuaCrypto**: MD5/SHA hashing
- **lua-zlib**: Compressed I/O
- **LuaSocket**: Network I/O (future)

## Testing Strategy

### Unit Tests
- Test each module independently
- Test error conditions and edge cases
- Test with different Lua versions (5.1, 5.4, LuaJIT)

### Integration Tests
- Test marshal + channels end-to-end
- Test format + channels
- Test complex data structures with comparison/hashing
- Test real-world scenarios (parse config files, save/load state)

### Performance Tests
- Benchmark against JavaScript runtime
- Optimize hot paths (comparison, hashing, I/O)
- Profile memory usage
- Test with large datasets

### Compatibility Tests
- Verify OCaml semantics match exactly
- Test with OCaml compiler output
- Cross-check with js_of_ocaml behavior

## Success Criteria

### Phase 1-2 (Essential)
- ✅ Marshal can read/write from/to channels
- ✅ Printf/Scanf formatting works
- ✅ Basic I/O operations complete

### Phase 3-4 (Core)
- ✅ All core data structures implemented
- ✅ Comparison and hashing work correctly
- ✅ Hashtbl performance is acceptable

### Phase 5-6 (Standard Library)
- ✅ Lexing/Parsing support for ocamllex/ocamlyacc
- ✅ Sys/Filename modules for file operations

### Phase 7-8 (Advanced)
- ✅ Map/Set balanced trees
- ✅ Stream operations

### Phase 9 (Quality)
- ✅ All tests pass on Lua 5.1, 5.4, LuaJIT
- ✅ Performance within 2x of JavaScript runtime
- ✅ Full documentation

## Timeline Estimate

- **Phase 1**: 2-3 days (Marshal channel integration)
- **Phase 2**: 5-7 days (Format module)
- **Phase 3**: 3-4 days (Core data structures)
- **Phase 4**: 3-4 days (Comparison and hashing)
- **Phase 5**: 4-5 days (Lexing and parsing)
- **Phase 6**: 3-4 days (Sys and Filename)
- **Phase 7**: 5-6 days (Map and Set)
- **Phase 8**: 2-3 days (Stream)
- **Phase 9**: 4-5 days (Integration and testing)
- **Phase 10**: 3-5 days (Optional features)

**Total**: ~35-50 days for complete implementation

## Notes

- Focus on correctness first, then optimize
- Maintain compatibility with OCaml semantics
- Reuse code patterns from js_of_ocaml where possible
- Document platform differences (Lua vs JavaScript)
- Consider Lua version compatibility (5.1 vs 5.4)
- Keep runtime size reasonable (target < 10KB for core modules)
