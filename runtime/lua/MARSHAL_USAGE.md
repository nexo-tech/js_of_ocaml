# Marshal Module - User Guide

Complete guide to using the Marshal module in lua_of_ocaml runtime for value serialization and deserialization.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [API Reference](#api-reference)
4. [Usage Examples](#usage-examples)
5. [Advanced Features](#advanced-features)
6. [Compatibility Notes](#compatibility-notes)
7. [Performance Tips](#performance-tips)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The Marshal module provides binary serialization and deserialization of Lua values, compatible with OCaml's Marshal format. Use it for:

- **Data persistence**: Save application state to files
- **Inter-process communication**: Exchange data between processes
- **Network protocols**: Serialize data for transmission
- **Caching**: Store computed results for later reuse

### Key Features

- ✅ Full OCaml Marshal format compatibility
- ✅ Support for cyclic structures and object sharing
- ✅ Custom block types (Int64, Int32, Bigarray)
- ✅ String and channel-based I/O
- ✅ Configurable marshalling flags
- ✅ Comprehensive error handling

---

## Quick Start

### Basic Usage

```lua
local marshal = require("marshal")

-- Serialize a value to string
local value = {tag = 0, [1] = 42, [2] = "hello"}
local serialized = marshal.to_string(value)

-- Deserialize back to value
local restored = marshal.from_bytes(serialized, 0)
-- restored == {tag = 0, [1] = 42, [2] = "hello"}
```

### File I/O Example

```lua
local marshal = require("marshal")
local io_module = require("io")

-- Save to file
local data = {tag = 0, [1] = "state", [2] = {tag = 0, [1] = 1, [2] = 2}}
local fd = io_module.caml_sys_open("data.marshal", {1, 3, 4, 6}, 438)
local ch = io_module.caml_ml_open_descriptor_out(fd)
marshal.to_channel(ch, data)
io_module.caml_ml_close_channel(ch)

-- Load from file
local fd2 = io_module.caml_sys_open("data.marshal", {0}, 0)
local ch2 = io_module.caml_ml_open_descriptor_in(fd2)
local restored = marshal.from_channel(ch2)
io_module.caml_ml_close_channel(ch2)
```

---

## API Reference

### String-Based API

#### `marshal.to_string(value, flags)`

Serialize a value to a binary string.

**Parameters:**
- `value` (any): The value to marshal (table, number, string, etc.)
- `flags` (table, optional): Array of marshal flags (default: empty)

**Returns:**
- `string`: Binary string containing marshalled data

**Example:**
```lua
local str = marshal.to_string(42)
local str_no_sharing = marshal.to_string(data, {marshal.No_sharing})
```

#### `marshal.from_bytes(str, offset)`

Deserialize a value from a binary string.

**Parameters:**
- `str` (string): Binary string containing marshalled data
- `offset` (number): Byte offset to start reading (0-based)

**Returns:**
- `any`: The unmarshalled value

**Example:**
```lua
local value = marshal.from_bytes(str, 0)
local second = marshal.from_bytes(str, marshal.total_size(str, 0))
```

#### `marshal.to_bytes(value, flags)`

Alias for `to_string`.

#### `marshal.from_string(str, offset)`

Alias for `from_bytes`.

### Metadata API

#### `marshal.total_size(str, offset)`

Get total size of marshalled data including header.

**Parameters:**
- `str` (string): Binary string containing marshalled data
- `offset` (number): Byte offset (0-based)

**Returns:**
- `number`: Total size in bytes (header + data)

**Example:**
```lua
local size = marshal.total_size(str, 0)  -- Returns 20 + data_length
```

#### `marshal.data_size(str, offset)`

Get size of marshalled data excluding header.

**Parameters:**
- `str` (string): Binary string containing marshalled data
- `offset` (number): Byte offset (0-based)

**Returns:**
- `number`: Data size in bytes (excluding 20-byte header)

**Example:**
```lua
local data_len = marshal.data_size(str, 0)
```

### Channel-Based API

#### `marshal.to_channel(chanid, value, flags)`

Write marshalled value to an output channel.

**Parameters:**
- `chanid` (number): Channel ID from io module
- `value` (any): The value to marshal
- `flags` (table, optional): Array of marshal flags

**Returns:**
- None (writes to channel)

**Example:**
```lua
local io_module = require("io")
local fd = io_module.caml_sys_open("output.dat", {1, 3, 4, 6}, 438)
local ch = io_module.caml_ml_open_descriptor_out(fd)
marshal.to_channel(ch, {tag = 0, [1] = "data"})
io_module.caml_ml_close_channel(ch)
```

#### `marshal.from_channel(chanid)`

Read marshalled value from an input channel.

**Parameters:**
- `chanid` (number): Channel ID from io module

**Returns:**
- `any`: The unmarshalled value

**Example:**
```lua
local io_module = require("io")
local fd = io_module.caml_sys_open("input.dat", {0}, 0)
local ch = io_module.caml_ml_open_descriptor_in(fd)
local value = marshal.from_channel(ch)
io_module.caml_ml_close_channel(ch)
```

### Marshal Flags

#### `marshal.No_sharing`

Disable object sharing (value: 0).

When set, identical objects are marshalled separately instead of using shared references. Increases size but may improve compatibility.

**Example:**
```lua
local flags = {marshal.No_sharing}
local str = marshal.to_string(value, flags)
```

#### `marshal.Closures`

Enable closure marshalling (value: 1).

**Not supported** - will raise an error if used.

#### `marshal.Compat_32`

32-bit compatibility mode (value: 2).

Accepted but currently has no effect.

---

## Usage Examples

### Example 1: Simple Value Serialization

```lua
local marshal = require("marshal")

-- Integers
local int_str = marshal.to_string(42)
assert(marshal.from_bytes(int_str, 0) == 42)

-- Strings
local str_str = marshal.to_string("hello")
assert(marshal.from_bytes(str_str, 0) == "hello")

-- Floats
local float_str = marshal.to_string(3.14159)
assert(marshal.from_bytes(float_str, 0) == 3.14159)
```

### Example 2: OCaml Blocks (Records/Tuples)

```lua
local marshal = require("marshal")

-- OCaml tuple: (1, "two", 3.0)
local tuple = {tag = 0, [1] = 1, [2] = "two", [3] = 3.0}
local str = marshal.to_string(tuple)
local restored = marshal.from_bytes(str, 0)

assert(restored.tag == 0)
assert(restored[1] == 1)
assert(restored[2] == "two")
assert(restored[3] == 3.0)
```

### Example 3: Lists

```lua
local marshal = require("marshal")

-- OCaml list: [1; 2; 3]
-- Represented as nested cons cells: 1 :: (2 :: (3 :: []))
local list = {
  tag = 0,
  [1] = 1,
  [2] = {
    tag = 0,
    [1] = 2,
    [2] = {
      tag = 0,
      [1] = 3,
      [2] = 0  -- [] (empty list)
    }
  }
}

local str = marshal.to_string(list)
local restored = marshal.from_bytes(str, 0)
```

### Example 4: Options and Results

```lua
local marshal = require("marshal")

-- Option type
local none = 0  -- None
local some = {tag = 0, [1] = 42}  -- Some 42

-- Result type
local ok = {tag = 0, [1] = "success"}  -- Ok "success"
local err = {tag = 1, [1] = "error"}   -- Error "error"

local str_some = marshal.to_string(some)
local restored = marshal.from_bytes(str_some, 0)
assert(restored[1] == 42)
```

### Example 5: Cyclic Structures

```lua
local marshal = require("marshal")

-- Create cyclic structure
local node = {tag = 0, [1] = "data"}
node[2] = node  -- Self-reference

local str = marshal.to_string(node)
local restored = marshal.from_bytes(str, 0)

-- Cycle is preserved
assert(restored[2] == restored)  -- Points to itself
```

### Example 6: Shared References

```lua
local marshal = require("marshal")

-- Create shared structure
local shared = {tag = 0, [1] = "shared"}
local container = {tag = 0, [1] = shared, [2] = shared}

-- With sharing (default)
local str_shared = marshal.to_string(container)
local restored_shared = marshal.from_bytes(str_shared, 0)
assert(restored_shared[1] == restored_shared[2])  -- Same object

-- Without sharing
local str_no_share = marshal.to_string(container, {marshal.No_sharing})
local restored_no_share = marshal.from_bytes(str_no_share, 0)
-- Objects are separate copies
```

### Example 7: Custom Blocks (Int64)

```lua
local marshal = require("marshal")

-- Int64 value
local int64 = {
  caml_custom = "_j",
  bytes = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2A}  -- 42 in big-endian
}

local str = marshal.to_string(int64)
local restored = marshal.from_bytes(str, 0)

assert(restored.caml_custom == "_j")
assert(#restored.bytes == 8)
```

### Example 8: Multiple Values in Sequence

```lua
local marshal = require("marshal")

-- Marshal multiple values to single string
local v1 = 42
local v2 = "hello"
local v3 = {tag = 0, [1] = 1, [2] = 2}

local s1 = marshal.to_string(v1)
local s2 = marshal.to_string(v2)
local s3 = marshal.to_string(v3)
local combined = s1 .. s2 .. s3

-- Unmarshal in sequence
local offset = 0
local r1 = marshal.from_bytes(combined, offset)
offset = offset + marshal.total_size(combined, offset)

local r2 = marshal.from_bytes(combined, offset)
offset = offset + marshal.total_size(combined, offset)

local r3 = marshal.from_bytes(combined, offset)

assert(r1 == 42)
assert(r2 == "hello")
```

### Example 9: Error Handling

```lua
local marshal = require("marshal")

-- Handle truncated data
local str = marshal.to_string(42)
local truncated = string.sub(str, 1, 10)  -- Only 10 bytes

local success, err = pcall(function()
  marshal.from_bytes(truncated, 0)
end)

if not success then
  print("Error:", err)
  -- Error: Marshal.from_bytes: truncated data (expected 20 bytes, got 10)
end

-- Handle corrupted data
local corrupted = string.char(0xFF, 0xFF, 0xFF, 0xFF) .. string.sub(str, 5)
local success2, err2 = pcall(function()
  marshal.from_bytes(corrupted, 0)
end)

if not success2 then
  print("Error:", err2)
  -- Error: Marshal.from_bytes: invalid magic number
end
```

---

## Advanced Features

### Object Sharing

By default, Marshal tracks objects during marshalling. If the same table appears multiple times, it's marshalled once and referenced elsewhere using shared codes.

**Benefits:**
- Smaller output size for structures with shared data
- Preserves object identity on unmarshalling
- Essential for cyclic structures

**Disable sharing:**
```lua
local str = marshal.to_string(value, {marshal.No_sharing})
```

### Custom Blocks

Custom blocks represent OCaml's custom types (Int64, Int32, Bigarray).

**Structure:**
```lua
{
  caml_custom = "_j",  -- Identifier ("_j" = Int64, "_i" = Int32)
  bytes = {...}        -- Byte array (big-endian)
}
```

**Supported types:**
- `_j`: Int64 (8 bytes)
- `_i`: Int32 (4 bytes)
- `_bigarray`: Bigarray structures

### Working with Channels

Channels provide buffered I/O for efficient reading/writing of marshal data.

**Create output channel:**
```lua
local io_module = require("io")
local fd = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 438)  -- wronly, creat, trunc, binary
local ch = io_module.caml_ml_open_descriptor_out(fd)
```

**Create input channel:**
```lua
local fd = io_module.caml_sys_open(filename, {0}, 0)  -- rdonly
local ch = io_module.caml_ml_open_descriptor_in(fd)
```

**Always close channels:**
```lua
io_module.caml_ml_close_channel(ch)
```

---

## Compatibility Notes

### OCaml Compatibility

✅ **Fully compatible** with OCaml's Marshal format:
- Byte-for-byte identical output for same inputs
- Can read data marshalled by OCaml
- Can write data readable by OCaml

✅ **Tested against OCaml-generated data** (42 compatibility tests)

### Lua Version Compatibility

| Feature | Lua 5.1 | Lua 5.4 | LuaJIT |
|---------|---------|---------|--------|
| Basic marshal/unmarshal | ✅ | ✅ | ✅ |
| String I/O | ✅ | ✅ | ✅ |
| Channel I/O | ✅ | ✅ | ✅ |
| Custom blocks | ✅ | ✅ | ✅ |
| Sharing/cycles | ✅ | ✅ | ✅ |

**Performance:**
- LuaJIT: ~8-13x faster (with JIT compilation)
- Lua 5.4: Baseline performance
- Lua 5.1: Baseline performance

### Value Representation

**OCaml → Lua mapping:**

| OCaml Type | Lua Representation |
|------------|-------------------|
| `int` | `number` |
| `float` | `number` |
| `string` | `string` |
| `unit` | `0` |
| `bool` | `0` (false) or `1` (true) |
| `tuple (a,b,c)` | `{tag=0, [1]=a, [2]=b, [3]=c}` |
| `record {x;y}` | `{tag=0, [1]=x, [2]=y}` |
| `variant C of t` | `{tag=N, [1]=t}` (N = constructor index) |
| `list []` | `0` |
| `list hd::tl` | `{tag=0, [1]=hd, [2]=tl}` |
| `option None` | `0` |
| `option Some v` | `{tag=0, [1]=v}` |
| `Int64.t` | `{caml_custom="_j", bytes={...}}` |
| `Int32.t` | `{caml_custom="_i", bytes={...}}` |

### Limitations

❌ **Not supported:**
- Closures (functions) - will raise error
- Code pointers - will raise error
- Infix pointers - will raise error
- Compression (without external library)

⚠️ **Platform-specific:**
- 64-bit block headers (BLOCK64) - error on 32-bit platforms
- Endianness handled automatically (big-endian and little-endian doubles)

---

## Performance Tips

### 1. Use Sharing for Large Structures

```lua
-- Good: sharing enabled (default)
local big_shared = create_large_table()
local container = {big_shared, big_shared, big_shared}
local str = marshal.to_string(container)  -- big_shared marshalled once

-- Avoid: disabling sharing unnecessarily
local str = marshal.to_string(container, {marshal.No_sharing})  -- 3x larger!
```

### 2. Reuse Channels for Multiple Values

```lua
-- Good: write multiple values to same channel
local ch = io_module.caml_ml_open_descriptor_out(fd)
for i = 1, 1000 do
  marshal.to_channel(ch, data[i])
end
io_module.caml_ml_close_channel(ch)

-- Avoid: opening/closing channel for each value
for i = 1, 1000 do
  local ch = io_module.caml_ml_open_descriptor_out(fd)
  marshal.to_channel(ch, data[i])
  io_module.caml_ml_close_channel(ch)  -- Expensive!
end
```

### 3. Use LuaJIT for Performance

```bash
# 8-13x faster with JIT
luajit your_script.lua
```

### 4. Pre-allocate Tables

```lua
-- Good: known structure
local value = {tag = 0, [1] = nil, [2] = nil, [3] = nil}
value[1] = compute_field1()
value[2] = compute_field2()
value[3] = compute_field3()

-- Less optimal: dynamic growth
local value = {tag = 0}
table.insert(value, compute_field1())  -- Slower
```

### 5. Batch Small Values

```lua
-- Good: marshal container with all values
local batch = {tag = 0}
for i = 1, 100 do
  batch[i] = small_values[i]
end
local str = marshal.to_string(batch)  -- One marshal operation

-- Less optimal: marshal each value separately
for i = 1, 100 do
  local str = marshal.to_string(small_values[i])  -- 100 marshal operations
end
```

---

## Troubleshooting

### Common Errors

#### "truncated data"

**Cause:** String is shorter than expected based on header.

**Solution:**
- Check file read completely
- Verify offset is correct
- Ensure binary mode for file I/O

```lua
-- Correct: use binary mode flags
local fd = io_module.caml_sys_open(filename, {0, 6}, 0)  -- rdonly, binary
```

#### "invalid magic number"

**Cause:** Data is corrupted or not marshal format.

**Solution:**
- Verify file contains marshal data
- Check for text mode corruption (newline translation)
- Ensure offset points to start of marshal data

#### "closure blocks not supported"

**Cause:** Attempted to marshal a function.

**Solution:**
- Don't marshal functions
- Use data-only structures

```lua
-- Wrong
local value = {tag = 0, [1] = function() end}

-- Correct
local value = {tag = 0, [1] = "data"}
```

#### "data block too large"

**Cause:** 64-bit block on 32-bit platform.

**Solution:**
- Use smaller data structures
- Split into multiple values

### Debugging Tips

#### 1. Check Magic Number

```lua
local function check_magic(str)
  local b1, b2, b3, b4 = string.byte(str, 1, 4)
  local magic = (b1 << 24) | (b2 << 16) | (b3 << 8) | b4
  if magic == 0x8495A6BE then
    print("Valid marshal data")
  else
    print(string.format("Invalid magic: 0x%08X", magic))
  end
end
```

#### 2. Inspect Header

```lua
local size = marshal.total_size(str, 0)
local data_len = marshal.data_size(str, 0)
print(string.format("Total: %d bytes, Data: %d bytes, Header: 20 bytes", size, data_len))
```

#### 3. Test Roundtrip

```lua
local original = {tag = 0, [1] = 42}
local marshalled = marshal.to_string(original)
local restored = marshal.from_bytes(marshalled, 0)

-- Deep equality check
local function deep_equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not deep_equal(v, b[k]) then return false end
  end
  return true
end

assert(deep_equal(original, restored), "Roundtrip failed!")
```

---

## See Also

- [MARSHAL.md](MARSHAL.md) - Implementation plan and internal documentation
- [DEEP_IO.md](DEEP_IO.md) - I/O integration details
- [Test Files](test_marshal.lua) - Comprehensive examples and test cases

For questions or issues, refer to the test suite in `runtime/lua/test_marshal*.lua` for working examples.
