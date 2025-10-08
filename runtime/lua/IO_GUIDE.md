# Lua_of_ocaml I/O System Guide

This guide provides comprehensive documentation for the I/O system in lua_of_ocaml, covering channels, marshalling, formatting, and data structures.

## Table of Contents

1. [Channel API](#channel-api)
2. [Marshal Channel Integration](#marshal-channel-integration)
3. [Format Module (Printf/Scanf)](#format-module-printfscanf)
4. [Data Structure Modules](#data-structure-modules)
5. [Usage Examples](#usage-examples)
6. [Limitations and Platform Differences](#limitations-and-platform-differences)

---

## Channel API

The channel API provides OCaml-compatible I/O operations through file descriptors and channels.

### File Descriptor Operations

#### `caml_sys_open(filename, flags, perms)`

Opens a file and returns a file descriptor.

**Parameters:**
- `filename` (string): Path to the file
- `flags` (OCaml list): Open flags as OCaml list
  - `0` = O_RDONLY (read only)
  - `1` = O_WRONLY (write only)
  - `2` = O_APPEND (append mode)
  - `3` = O_CREAT (create if not exists)
  - `4` = O_TRUNC (truncate to zero)
  - `5` = O_EXCL (exclusive creation)
  - `6` = O_BINARY (binary mode)
  - `7` = O_TEXT (text mode)
- `perms` (number): File permissions (e.g., 420 for 0644)

**Returns:** File descriptor (integer)

**Example:**
```lua
local io_module = require("io")

-- Open for writing, create if not exists, truncate, binary mode
local flags = {tag = 0, [1] = 1, [2] = {tag = 0, [1] = 3, [2] = {tag = 0, [1] = 4, [2] = {tag = 0, [1] = 6, [2] = 0}}}}
local fd = io_module.caml_sys_open("output.dat", flags, 420)
```

#### `caml_sys_close(fd)`

Closes a file descriptor.

**Parameters:**
- `fd` (number): File descriptor to close

**Returns:** 0 on success

### Channel Creation

#### `caml_ml_open_descriptor_in(fd)`

Creates an input channel from a file descriptor.

**Parameters:**
- `fd` (number): File descriptor

**Returns:** Channel ID (integer)

#### `caml_ml_open_descriptor_out(fd)`

Creates an output channel from a file descriptor.

**Parameters:**
- `fd` (number): File descriptor

**Returns:** Channel ID (integer)

**Example:**
```lua
-- Open file for reading
local flags = {tag = 0, [1] = 0, [2] = {tag = 0, [1] = 6, [2] = 0}}  -- RDONLY, BINARY
local fd = io_module.caml_sys_open("input.dat", flags, 0)
local chan_in = io_module.caml_ml_open_descriptor_in(fd)
```

### Channel Operations

#### Input Operations

##### `caml_ml_input_char(chanid)`

Reads a single byte from a channel.

**Parameters:**
- `chanid` (number): Channel ID

**Returns:** Byte value (0-255)

**Raises:** Error on EOF or closed channel

##### `caml_ml_input(chanid, buf, offset, len)`

Reads bytes into a buffer.

**Parameters:**
- `chanid` (number): Channel ID
- `buf` (table): Buffer to fill (Lua table indexed by integers)
- `offset` (number): Starting offset in buffer
- `len` (number): Number of bytes to read

**Returns:** Number of bytes actually read

**Example:**
```lua
local buf = {}
local bytes_read = io_module.caml_ml_input(chan_in, buf, 0, 1024)
-- buf now contains bytes at buf[1], buf[2], ..., buf[bytes_read]
```

#### Output Operations

##### `caml_ml_output_char(chanid, c)`

Writes a single byte to a channel.

**Parameters:**
- `chanid` (number): Channel ID
- `c` (number): Byte value (0-255)

##### `caml_ml_output(chanid, str, offset, len)`

Writes a string to a channel.

**Parameters:**
- `chanid` (number): Channel ID
- `str` (string): String to write
- `offset` (number): Starting offset in string
- `len` (number): Number of bytes to write

**Example:**
```lua
local str = "Hello, World!"
io_module.caml_ml_output(chan_out, str, 0, #str)
```

##### `caml_ml_flush(chanid)`

Flushes the output buffer of a channel.

**Parameters:**
- `chanid` (number): Channel ID

##### `caml_ml_close_channel(chanid)`

Closes a channel (automatically flushes output channels).

**Parameters:**
- `chanid` (number): Channel ID

### Seeking Operations

#### `caml_ml_seek_in(chanid, pos)`

Seeks to a position in an input channel.

**Parameters:**
- `chanid` (number): Channel ID
- `pos` (number): Absolute position (0-based)

#### `caml_ml_pos_in(chanid)`

Returns the current position in an input channel.

**Parameters:**
- `chanid` (number): Channel ID

**Returns:** Current position (0-based)

#### `caml_ml_channel_size(chanid)`

Returns the size of the file associated with a channel.

**Parameters:**
- `chanid` (number): Channel ID

**Returns:** File size in bytes

### Channel Configuration

#### `caml_ml_set_binary_mode(chanid, mode)`

Sets the binary/text mode of a channel.

**Parameters:**
- `chanid` (number): Channel ID
- `mode` (number): 0 = text mode, non-zero = binary mode

**Returns:** 0

---

## Marshal Channel Integration

The marshal module provides OCaml-compatible serialization with channel integration.

### Core Functions

#### `marshal.to_channel(chanid, value, flags)`

Serializes a value directly to a channel.

**Parameters:**
- `chanid` (number): Output channel ID
- `value` (any): Value to serialize
- `flags` (OCaml list): Marshaling flags (usually `{tag = 0}` for no flags)

**Example:**
```lua
local marshal = require("marshal")

-- Serialize to channel
marshal.to_channel(chan_out, 42, {tag = 0})
marshal.to_channel(chan_out, "hello", {tag = 0})
marshal.to_channel(chan_out, {tag = 0, [1] = 1, [2] = {tag = 0, [1] = 2, [2] = 0}}, {tag = 0})
io_module.caml_ml_flush(chan_out)
```

#### `marshal.from_channel(chanid)`

Deserializes a value from a channel.

**Parameters:**
- `chanid` (number): Input channel ID

**Returns:** Deserialized value

**Example:**
```lua
local v1 = marshal.from_channel(chan_in)  -- 42
local v2 = marshal.from_channel(chan_in)  -- "hello"
local v3 = marshal.from_channel(chan_in)  -- list [1; 2]
```

### String-Based Marshaling

#### `marshal.to_string(value, flags)`

Serializes a value to a string.

**Parameters:**
- `value` (any): Value to serialize
- `flags` (OCaml list): Marshaling flags

**Returns:** Serialized string

#### `marshal.from_bytes(str, offset)`

Deserializes a value from a string.

**Parameters:**
- `str` (string): Serialized data
- `offset` (number): Starting offset (0-based)

**Returns:** Deserialized value

**Example:**
```lua
local data = marshal.to_string({tag = 0, [1] = 1, [2] = 0}, {tag = 0})
local value = marshal.from_bytes(data, 0)
```

### Marshal Format

The marshal format follows OCaml's standard:
- **Header**: 4 bytes containing data length
- **Data**: Serialized value representation
- **Magic numbers**: Prefixed to identify value types
- **Sharing**: Preserves object identity and cyclic structures

---

## Format Module (Printf/Scanf)

The format module provides OCaml-compatible formatted I/O.

### Printf-Style Formatting

#### `format.caml_fprintf(chanid, fmt, ...)`

Writes formatted output to a channel.

**Parameters:**
- `chanid` (number): Output channel ID
- `fmt` (string): Format string
- `...` (varargs): Values to format

**Format specifiers:**
- `%d` - Integer
- `%i` - Integer (same as %d)
- `%u` - Unsigned integer
- `%x` - Hexadecimal (lowercase)
- `%X` - Hexadecimal (uppercase)
- `%o` - Octal
- `%s` - String
- `%c` - Character
- `%f` - Float
- `%e` - Scientific notation (lowercase)
- `%E` - Scientific notation (uppercase)
- `%g` - Shortest representation
- `%b` - Boolean
- `%%` - Literal %

**Width and precision:**
- `%5d` - Minimum width 5
- `%05d` - Zero-padded width 5
- `%.2f` - 2 decimal places
- `%8.2f` - Width 8, 2 decimal places

**Example:**
```lua
local format = require("format")

format.caml_fprintf(chan_out, "Number: %d\n", 42)
format.caml_fprintf(chan_out, "Float: %.2f\n", 3.14159)
format.caml_fprintf(chan_out, "String: %s\n", "hello")
format.caml_fprintf(chan_out, "Hex: 0x%x\n", 255)
format.caml_fprintf(chan_out, "%s = %d (0x%x)\n", "value", 42, 42)
```

#### Standard Output Functions

```lua
format.caml_printf(fmt, ...)      -- Print to stdout
format.caml_eprintf(fmt, ...)     -- Print to stderr
```

### Scanf-Style Parsing

#### `format.caml_sscanf(str, fmt)`

Parses a string according to a format.

**Parameters:**
- `str` (string): Input string
- `fmt` (string): Format string

**Returns:** OCaml list of parsed values

**Example:**
```lua
local result = format.caml_sscanf("42 hello 3.14", "%d %s %f")
-- result is list [42; "hello"; 3.14]
```

---

## Data Structure Modules

### Map Module

AVL tree-based balanced maps with O(log n) operations.

#### Creating Maps

```lua
local map_module = require("map")

-- Create empty map with comparator
local empty = {tag = 0}  -- Empty map

-- Add elements
local m1 = map_module.caml_map_add(core.caml_compare, 1, "one", empty)
local m2 = map_module.caml_map_add(core.caml_compare, 2, "two", m1)
local m3 = map_module.caml_map_add(core.caml_compare, 3, "three", m2)
```

#### Map Operations

```lua
-- Find value by key
local value = map_module.caml_map_find(core.caml_compare, 2, m3)  -- "two"

-- Check membership
local exists = map_module.caml_map_mem(core.caml_compare, 2, m3)  -- true

-- Remove key
local m4 = map_module.caml_map_remove(core.caml_compare, 2, m3)

-- Check if empty
local is_empty = map_module.caml_map_is_empty(m4)  -- false

-- Get size
local size = map_module.caml_map_cardinal(m3)  -- 3

-- Iterate over elements
map_module.caml_map_iter(function(k, v)
  print(k, v)
end, m3)
```

### Set Module

AVL tree-based balanced sets with O(log n) operations.

#### Creating Sets

```lua
local set_module = require("set")

-- Create empty set
local empty = {tag = 0}

-- Add elements
local s1 = set_module.caml_set_add(core.caml_compare, 1, empty)
local s2 = set_module.caml_set_add(core.caml_compare, 2, s1)
local s3 = set_module.caml_set_add(core.caml_compare, 3, s2)
```

#### Set Operations

```lua
-- Check membership
local contains = set_module.caml_set_mem(core.caml_compare, 2, s3)  -- true

-- Remove element
local s4 = set_module.caml_set_remove(core.caml_compare, 2, s3)

-- Union
local s5 = set_module.caml_set_union(core.caml_compare, s3, s4)

-- Intersection
local s6 = set_module.caml_set_inter(core.caml_compare, s3, s4)

-- Difference
local s7 = set_module.caml_set_diff(core.caml_compare, s3, s4)

-- Subset test
local is_subset = set_module.caml_set_subset(core.caml_compare, s4, s3)

-- Size
local size = set_module.caml_set_cardinal(s3)
```

### Hashtable Module

Mutable hash tables with O(1) average operations.

#### Creating Hashtables

```lua
local hashtbl = require("hashtbl")

-- Create hashtable with initial size
local tbl = hashtbl.caml_hash_create(16)
```

#### Hashtable Operations

```lua
-- Add key-value pair
hashtbl.caml_hash_add(tbl, "key1", "value1")
hashtbl.caml_hash_add(tbl, "key2", "value2")

-- Find value by key
local value = hashtbl.caml_hash_find(tbl, "key1")  -- "value1"

-- Check membership
local exists = hashtbl.caml_hash_mem(tbl, "key1")  -- true

-- Remove key
hashtbl.caml_hash_remove(tbl, "key1")

-- Replace value
hashtbl.caml_hash_replace(tbl, "key2", "new_value")

-- Get size
local size = hashtbl.caml_hash_length(tbl)

-- Clear all entries
hashtbl.caml_hash_clear(tbl)

-- Iterate over entries
hashtbl.caml_hash_iter(function(k, v)
  print(k, v)
end, tbl)
```

### Buffer Module

Efficient string building with amortized O(1) append.

#### Creating Buffers

```lua
local buffer = require("buffer")

-- Create buffer with initial size
local buf = buffer.caml_buffer_create(256)
```

#### Buffer Operations

```lua
-- Add character
buffer.caml_buffer_add_char(buf, 65)  -- 'A'

-- Add string
buffer.caml_buffer_add_string(buf, "Hello, World!")

-- Add substring
buffer.caml_buffer_add_substring(buf, "extract", 2, 4)  -- "trac"

-- Get contents
local str = buffer.caml_buffer_contents(buf)

-- Get length
local len = buffer.caml_buffer_length(buf)

-- Reset (keep capacity)
buffer.caml_buffer_reset(buf)

-- Clear (same as reset)
buffer.caml_buffer_clear(buf)
```

### Stream Module

Lazy streams with on-demand evaluation.

#### Creating Streams

```lua
local stream = require("stream")

-- From list
local list = {tag = 0, [1] = 1, [2] = {tag = 0, [1] = 2, [2] = {tag = 0, [1] = 3, [2] = 0}}}
local s = stream.caml_stream_of_list(list)

-- From string
local s = stream.caml_stream_of_string("hello")

-- From function
local i = 0
local s = stream.caml_stream_from(function()
  i = i + 1
  if i <= 10 then
    return i
  else
    return nil
  end
end)
```

#### Stream Operations

```lua
-- Peek at first element (non-destructive)
local first = stream.caml_stream_peek(s)

-- Get and remove first element
local value = stream.caml_stream_next(s)

-- Remove first element without returning
stream.caml_stream_junk(s)

-- Peek at N elements
local list = stream.caml_stream_npeek(5, s)

-- Check if empty
local empty = stream.caml_stream_is_empty(s)

-- Iterate over stream
stream.caml_stream_iter(function(x)
  print(x)
end, s)
```

---

## Usage Examples

### Example 1: Writing and Reading Structured Data

```lua
-- Preload modules
package.loaded.io = dofile("io.lua")
local io_module = package.loaded.io
local marshal = require("marshal")

-- Helper to create OCaml list
local function make_list(tbl)
  local list = 0
  for i = #tbl, 1, -1 do
    list = {tag = 0, [1] = tbl[i], [2] = list}
  end
  return list
end

-- Open file for writing
local flags = make_list({1, 3, 4, 6})  -- WRONLY, CREAT, TRUNC, BINARY
local fd_out = io_module.caml_sys_open("data.bin", flags, 420)
local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)

-- Write structured data
local data = {
  count = 42,
  message = "Hello, World!",
  items = make_list({1, 2, 3, 4, 5})
}

marshal.to_channel(chan_out, data.count, {tag = 0})
marshal.to_channel(chan_out, data.message, {tag = 0})
marshal.to_channel(chan_out, data.items, {tag = 0})

io_module.caml_ml_flush(chan_out)
io_module.caml_ml_close_channel(chan_out)

-- Open file for reading
flags = make_list({0, 6})  -- RDONLY, BINARY
local fd_in = io_module.caml_sys_open("data.bin", flags, 0)
local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)

-- Read structured data back
local count = marshal.from_channel(chan_in)
local message = marshal.from_channel(chan_in)
local items = marshal.from_channel(chan_in)

io_module.caml_ml_close_channel(chan_in)

print("Count:", count)       -- 42
print("Message:", message)   -- "Hello, World!"
-- items is list [1; 2; 3; 4; 5]
```

### Example 2: Formatted Output to File

```lua
package.loaded.io = dofile("io.lua")
local io_module = package.loaded.io
local format = require("format")

-- Open file for writing
local flags = {tag = 0, [1] = 1, [2] = {tag = 0, [1] = 3, [2] = {tag = 0, [1] = 4, [2] = 0}}}
local fd = io_module.caml_sys_open("report.txt", flags, 420)
local chan = io_module.caml_ml_open_descriptor_out(fd)

-- Write formatted report
format.caml_fprintf(chan, "Performance Report\n")
format.caml_fprintf(chan, "==================\n\n")
format.caml_fprintf(chan, "Tests run: %d\n", 150)
format.caml_fprintf(chan, "Passed: %d\n", 148)
format.caml_fprintf(chan, "Failed: %d\n", 2)
format.caml_fprintf(chan, "Success rate: %.1f%%\n", 98.67)
format.caml_fprintf(chan, "\nAverage time: %.3f seconds\n", 0.042)

io_module.caml_ml_flush(chan)
io_module.caml_ml_close_channel(chan)
```

### Example 3: Building Complex Strings

```lua
local buffer = require("buffer")

-- Create buffer
local buf = buffer.caml_buffer_create(1024)

-- Build HTML document
buffer.caml_buffer_add_string(buf, "<!DOCTYPE html>\n")
buffer.caml_buffer_add_string(buf, "<html>\n")
buffer.caml_buffer_add_string(buf, "<head><title>Report</title></head>\n")
buffer.caml_buffer_add_string(buf, "<body>\n")

for i = 1, 10 do
  buffer.caml_buffer_add_string(buf, "  <p>Item ")
  -- Convert number to string
  buffer.caml_buffer_add_string(buf, tostring(i))
  buffer.caml_buffer_add_string(buf, "</p>\n")
end

buffer.caml_buffer_add_string(buf, "</body>\n</html>\n")

-- Get final string
local html = buffer.caml_buffer_contents(buf)
```

### Example 4: Using Maps for Configuration

```lua
local map_module = require("map")
local core = require("core")

-- Build configuration map
local empty = {tag = 0}
local config = empty

config = map_module.caml_map_add(core.caml_compare, "host", "localhost", config)
config = map_module.caml_map_add(core.caml_compare, "port", 8080, config)
config = map_module.caml_map_add(core.caml_compare, "timeout", 30, config)
config = map_module.caml_map_add(core.caml_compare, "debug", true, config)

-- Read configuration
local host = map_module.caml_map_find(core.caml_compare, "host", config)
local port = map_module.caml_map_find(core.caml_compare, "port", config)

print("Server:", host, port)  -- Server: localhost 8080

-- Check if key exists
local has_ssl = map_module.caml_map_mem(core.caml_compare, "ssl", config)
print("SSL enabled:", has_ssl)  -- SSL enabled: false
```

### Example 5: Processing Stream Data

```lua
local stream = require("stream")

-- Create stream of numbers
local function make_counter(limit)
  local i = 0
  return stream.caml_stream_from(function()
    i = i + 1
    if i <= limit then
      return i
    else
      return nil
    end
  end)
end

local numbers = make_counter(100)

-- Process stream lazily
local sum = 0
stream.caml_stream_iter(function(n)
  sum = sum + n
end, numbers)

print("Sum:", sum)  -- Sum: 5050
```

---

## Limitations and Platform Differences

### Lua Version Requirements

**Lua 5.3+ Required:**
- The runtime uses bitwise operators (`<<`, `>>`, `&`, `|`, `~`) introduced in Lua 5.3
- Lua 5.2 and earlier are not supported for the I/O modules
- LuaJIT support depends on version (LuaJIT 2.1+ has bitwise operators)

### Module Loading

**I/O Module Clash:**
- The `io` module name conflicts with Lua's standard `io` library
- Must preload with: `package.loaded.io = dofile("io.lua")`
- This ensures the lua_of_ocaml io module is loaded instead of the standard library

```lua
-- Required preload pattern
package.loaded.io = dofile("io.lua")
local io_module = package.loaded.io
```

### OCaml List Representation

**Empty List:**
- In OCaml runtime, empty list is represented as `0` (not `{tag = 0}`)
- Non-empty list: `{tag = 0, [1] = head, [2] = tail}`
- Tail should be another list or `0` for end

```lua
-- Correct list [1; 2; 3]
local list = {tag = 0, [1] = 1, [2] = {tag = 0, [1] = 2, [2] = {tag = 0, [1] = 3, [2] = 0}}}

-- Incorrect (will cause errors)
local bad_list = {tag = 0, [1] = 1, [2] = {tag = 0}}  -- Wrong!
```

### File Permissions

**Unix vs Windows:**
- File permission parameter is Unix-style (e.g., 0644 = 420 decimal)
- Windows ignores the permission parameter
- For portability, use 420 (0644) for standard files

### Binary vs Text Mode

**Line Endings:**
- Binary mode (`O_BINARY` flag = 6): No translation, preserves all bytes
- Text mode (`O_TEXT` flag = 7): May translate `\n` to `\r\n` on Windows
- Always use binary mode for marshal data
- Text mode is mainly for interop with text editors

### Channel Buffer Behavior

**Buffering:**
- Output channels buffer writes for performance
- Must call `caml_ml_flush()` to force immediate write
- Channels are flushed automatically on `caml_ml_close_channel()`
- Input channels also buffer for efficiency

### Marshal Format Compatibility

**Platform Independence:**
- Marshal format is platform-independent (same on all systems)
- Can serialize on Lua and deserialize on OCaml JavaScript runtime
- **But:** Not guaranteed compatible across OCaml versions
- **Best practice:** Use for temporary storage, not long-term archival

### Performance Considerations

**File I/O Bottleneck:**
- Channel operations are fast (~25K ops/sec for 1KB writes)
- File system access is the main bottleneck
- Buffering significantly improves performance
- Batch writes when possible

**Memory Usage:**
- Maps and Sets are immutable, creating new structures on modification
- Hashtables are mutable and more memory-efficient for frequent updates
- Streams are lazy and memory-efficient for large sequences
- Buffers dynamically resize, growing by doubling capacity

### Comparison Functions

**Custom Comparators:**
- Map and Set require a comparator function
- Use `core.caml_compare` for standard OCaml comparison
- Can provide custom comparators for special orderings
- Comparator must return -1 (less), 0 (equal), or 1 (greater)

```lua
-- Custom comparator (reverse order)
local function reverse_compare(a, b)
  if a < b then return 1
  elseif a > b then return -1
  else return 0
  end
end

local set = set_module.caml_set_add(reverse_compare, 5, empty)
```

### Error Handling

**Exceptions vs Errors:**
- OCaml exceptions are translated to Lua errors
- Use `pcall()` to catch errors safely
- Common errors:
  - `End_of_file`: Reading past EOF
  - `Not_found`: Key not found in map/hashtable
  - `Invalid_argument`: Invalid parameters
  - Channel closed errors

```lua
-- Safe reading
local ok, value = pcall(io_module.caml_ml_input_char, chan)
if ok then
  print("Read:", value)
else
  print("Error:", value)  -- error message
end
```

### Thread Safety

**Single-Threaded:**
- The runtime is single-threaded
- No thread-safety guarantees
- Do not share channels between Lua coroutines without synchronization

### Limitations Summary

| Feature | Limitation | Workaround |
|---------|-----------|------------|
| Lua Version | Requires 5.3+ | Use Lua 5.3 or later |
| Module Name | `io` conflicts with stdlib | Preload with `package.loaded.io` |
| Lists | Empty list is `0` not `{tag=0}` | Use correct representation |
| File Perms | Unix-style only | Use 420 for portability |
| Marshal Compat | Not guaranteed across versions | Use for temporary storage only |
| Threading | Single-threaded only | No concurrent access |
| Buffering | Must flush explicitly | Call `caml_ml_flush()` |

---

## Additional Resources

- **Test Files**: See `test_io_integration.lua` for comprehensive examples
- **Benchmarks**: See `benchmark_io.lua` for performance characteristics
- **Source Code**: All modules in `runtime/lua/` directory
- **Deep Dive**: See `DEEP_IO.md` for implementation details

---

*This guide covers the lua_of_ocaml I/O system as of the Phase 9 implementation. For updates and additional features, see the project repository.*
