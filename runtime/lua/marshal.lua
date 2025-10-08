-- Lua_of_ocaml runtime support
-- Marshal: Value Marshalling/Unmarshalling (Task 2.1)
--
-- Implements OCaml Marshal module for serialization/deserialization.
-- This file covers immediate values (integers, strings, small blocks).

local marshal_io = require("marshal_io")
local marshal_header = require("marshal_header")
local Reader = marshal_io.Reader
local Writer = marshal_io.Writer

local M = {}

-- Value type codes
M.PREFIX_SMALL_BLOCK = 0x80
M.PREFIX_SMALL_INT = 0x40
M.PREFIX_SMALL_STRING = 0x20
M.CODE_INT8 = 0x00
M.CODE_INT16 = 0x01
M.CODE_INT32 = 0x02
M.CODE_INT64 = 0x03
M.CODE_SHARED8 = 0x04
M.CODE_SHARED16 = 0x05
M.CODE_SHARED32 = 0x06
M.CODE_DOUBLE_ARRAY32_LITTLE = 0x07
M.CODE_BLOCK32 = 0x08
M.CODE_STRING8 = 0x09
M.CODE_STRING32 = 0x0A
M.CODE_DOUBLE_BIG = 0x0B
M.CODE_DOUBLE_LITTLE = 0x0C
M.CODE_DOUBLE_ARRAY8_BIG = 0x0D
M.CODE_DOUBLE_ARRAY8_LITTLE = 0x0E
M.CODE_DOUBLE_ARRAY32_BIG = 0x0F
M.CODE_CODEPOINTER = 0x10
M.CODE_INFIXPOINTER = 0x11
M.CODE_CUSTOM = 0x12
M.CODE_BLOCK64 = 0x13
M.CODE_CUSTOM_LEN = 0x18
M.CODE_CUSTOM_FIXED = 0x19

--
-- Custom Block Operations
--

-- Custom operations table
-- Each entry maps a custom identifier to operations:
--   deserialize(reader, size_array): Unmarshal custom block
--   serialize(writer, value, sizes_array): Marshal custom block
--   compare(v1, v2): Compare two custom values
--   hash(v): Hash custom value
--   fixed_length: Size in bytes (if fixed), or nil for variable
M.custom_ops = {}

-- Helper: Int64 unmarshal (8 bytes big-endian)
local function int64_unmarshal(reader, size_array)
  local bytes = {}
  for i = 1, 8 do
    bytes[i] = reader:read8u()
  end
  size_array[1] = 8

  -- Return as table with custom marker
  return {
    caml_custom = "_j",
    bytes = bytes
  }
end

-- Helper: Int64 marshal (8 bytes big-endian)
local function int64_marshal(writer, value, sizes_array)
  if type(value) ~= "table" or value.caml_custom ~= "_j" then
    error("Marshal: expected Int64 custom block")
  end

  for i = 1, 8 do
    writer:write8u(value.bytes[i])
  end

  sizes_array[1] = 8  -- size_32
  sizes_array[2] = 8  -- size_64
end

-- Helper: Int32 unmarshal (4 bytes big-endian)
local function int32_unmarshal(reader, size_array)
  size_array[1] = 4
  local value = reader:read32s()

  return {
    caml_custom = "_i",
    value = value
  }
end

-- Helper: Nativeint unmarshal (4 bytes big-endian on 32-bit platforms)
local function nativeint_unmarshal(reader, size_array)
  size_array[1] = 4
  local value = reader:read32s()

  return {
    caml_custom = "_n",
    value = value
  }
end

-- Register custom operations
M.custom_ops["_j"] = {
  deserialize = int64_unmarshal,
  serialize = int64_marshal,
  fixed_length = 8,
  compare = nil,  -- Not needed for marshalling
  hash = nil      -- Not needed for marshalling
}

M.custom_ops["_i"] = {
  deserialize = int32_unmarshal,
  serialize = nil,  -- Will be implemented in Task 4.2
  fixed_length = 4,
  compare = nil,
  hash = nil
}

M.custom_ops["_n"] = {
  deserialize = nativeint_unmarshal,
  serialize = nil,  -- Will be implemented in Task 4.2
  fixed_length = 4,
  compare = nil,
  hash = nil
}

-- Note: Bigarray (_bigarr02, _bigarray) will be added when bigarray support is complete

--
-- Marshal Writer
--

--
-- Object Table for Sharing
--

local ObjectTable = {}
ObjectTable.__index = ObjectTable

function ObjectTable:new()
  local obj = {
    objs = {},       -- Array of objects in order
    lookup = {}      -- Map from object to index
  }
  setmetatable(obj, self)
  return obj
end

-- Store an object and return its index
function ObjectTable:store(v)
  local idx = #self.objs + 1
  table.insert(self.objs, v)
  self.lookup[v] = idx
  return idx
end

-- Recall an object's relative offset (for sharing)
-- Returns nil if not found, or relative offset (objs.length - stored_index)
function ObjectTable:recall(v)
  local idx = self.lookup[v]
  if idx == nil then
    return nil
  end
  return #self.objs - idx  -- Relative offset from current position
end

-- Get total count of objects
function ObjectTable:count()
  return #self.objs
end

--
-- Marshal Writer
--

local MarshalWriter = {}
MarshalWriter.__index = MarshalWriter

function MarshalWriter:new(no_sharing)
  local obj = {
    writer = Writer:new(),
    size_32 = 0,
    size_64 = 0,
    obj_counter = 0,
    no_sharing = no_sharing or false,
    obj_table = no_sharing and nil or ObjectTable:new()
  }
  setmetatable(obj, self)
  return obj
end

-- Check if object should be shared, and write shared reference if already seen
-- Returns true if shared reference was written, false if this is first occurrence
function MarshalWriter:memo(v)
  if self.no_sharing or self.obj_table == nil then
    return false
  end

  -- Only share strings, tables (blocks, float arrays), and numbers (doubles)
  local vtype = type(v)
  if vtype ~= "string" and vtype ~= "table" and vtype ~= "number" then
    return false
  end

  -- For numbers, only share if it's a double (not an integer)
  if vtype == "number" and v == math.floor(v) and v >= -2147483648 and v <= 2147483647 then
    return false  -- Don't share integers
  end

  local offset = self.obj_table:recall(v)
  if offset then
    -- Already seen, write shared reference
    self:write_shared(offset)
    return true
  else
    -- First occurrence, store it
    self.obj_table:store(v)
    return false
  end
end

-- Write shared reference (SHARED8, SHARED16, or SHARED32)
function MarshalWriter:write_shared(offset)
  if offset < 256 then
    -- SHARED8
    self.writer:write8u(M.CODE_SHARED8)
    self.writer:write8u(offset)
  elseif offset < 65536 then
    -- SHARED16
    self.writer:write8u(M.CODE_SHARED16)
    self.writer:write16u(offset)
  else
    -- SHARED32
    self.writer:write8u(M.CODE_SHARED32)
    self.writer:write32u(offset)
  end
end

-- Marshal small integer (0-63)
function MarshalWriter:write_small_int(n)
  if n < 0 or n >= 64 then
    error("Marshal: small int out of range (0-63)")
  end
  self.writer:write8u(M.PREFIX_SMALL_INT + n)
end

-- Marshal INT8 (-128 to 127)
function MarshalWriter:write_int8(n)
  if n < -128 or n > 127 then
    error("Marshal: INT8 out of range")
  end
  self.writer:write8u(M.CODE_INT8)
  self.writer:write8u(n < 0 and (n + 256) or n)
end

-- Marshal INT16 (-32768 to 32767)
function MarshalWriter:write_int16(n)
  if n < -32768 or n > 32767 then
    error("Marshal: INT16 out of range")
  end
  self.writer:write8u(M.CODE_INT16)
  local u = n < 0 and (n + 65536) or n
  self.writer:write16u(u)
end

-- Marshal INT32 (-2147483648 to 2147483647)
function MarshalWriter:write_int32(n)
  if n < -2147483648 or n > 2147483647 then
    error("Marshal: INT32 out of range")
  end
  self.writer:write8u(M.CODE_INT32)
  local u = n < 0 and (n + 4294967296) or n
  self.writer:write32u(u)
end

-- Marshal integer (chooses optimal encoding)
function MarshalWriter:write_int(n)
  -- Check if n is an integer
  if n ~= math.floor(n) then
    error("Marshal: expected integer, got float")
  end

  if n >= 0 and n < 64 then
    -- Small int (6 bits)
    self:write_small_int(n)
  elseif n >= -128 and n < 128 then
    -- INT8
    self:write_int8(n)
  elseif n >= -32768 and n < 32768 then
    -- INT16
    self:write_int16(n)
  elseif n >= -2147483648 and n <= 2147483647 then
    -- INT32
    self:write_int32(n)
  else
    error("Marshal: integer too large (use Int64)")
  end
end

-- Marshal small string (0-31 bytes)
function MarshalWriter:write_small_string(str)
  if self:memo(str) then return end  -- Check for sharing

  local len = #str
  if len < 0 or len >= 32 then
    error("Marshal: small string out of range (0-31)")
  end
  self.writer:write8u(M.PREFIX_SMALL_STRING + len)
  self.writer:writestr(str)

  -- Update size fields
  self.size_32 = self.size_32 + 1 + math.floor((len + 4) / 4)
  self.size_64 = self.size_64 + 1 + math.floor((len + 8) / 8)
end

-- Marshal STRING8 (up to 255 bytes)
function MarshalWriter:write_string8(str)
  if self:memo(str) then return end  -- Check for sharing

  local len = #str
  if len < 0 or len >= 256 then
    error("Marshal: STRING8 out of range (0-255)")
  end
  self.writer:write8u(M.CODE_STRING8)
  self.writer:write8u(len)
  self.writer:writestr(str)

  -- Update size fields
  self.size_32 = self.size_32 + 1 + math.floor((len + 4) / 4)
  self.size_64 = self.size_64 + 1 + math.floor((len + 8) / 8)
end

-- Marshal STRING32 (large strings)
function MarshalWriter:write_string32(str)
  if self:memo(str) then return end  -- Check for sharing

  local len = #str
  self.writer:write8u(M.CODE_STRING32)
  self.writer:write32u(len)
  self.writer:writestr(str)

  -- Update size fields
  self.size_32 = self.size_32 + 1 + math.floor((len + 4) / 4)
  self.size_64 = self.size_64 + 1 + math.floor((len + 8) / 8)
end

-- Marshal string (chooses optimal encoding)
function MarshalWriter:write_string(str)
  if type(str) ~= "string" then
    error("Marshal: expected string")
  end

  local len = #str
  if len < 32 then
    self:write_small_string(str)
  elseif len < 256 then
    self:write_string8(str)
  else
    self:write_string32(str)
  end
end

-- Marshal small block (tag 0-15, size 0-7)
function MarshalWriter:write_small_block(tag, size)
  if tag < 0 or tag >= 16 then
    error("Marshal: small block tag out of range (0-15)")
  end
  if size < 0 or size >= 8 then
    error("Marshal: small block size out of range (0-7)")
  end
  local code = M.PREFIX_SMALL_BLOCK + tag + (size * 16)
  self.writer:write8u(code)

  -- Update size fields
  self.size_32 = self.size_32 + (size + 1)
  self.size_64 = self.size_64 + (size + 1)
end

-- Marshal BLOCK32 (large blocks)
function MarshalWriter:write_block32(tag, size)
  if tag < 0 or tag >= 256 then
    error("Marshal: BLOCK32 tag out of range (0-255)")
  end
  if size < 0 then
    error("Marshal: BLOCK32 size must be non-negative")
  end

  -- Write CODE_BLOCK32
  self.writer:write8u(M.CODE_BLOCK32)

  -- Write header: (size << 10) | tag
  local header = (size * 1024) + tag  -- size << 10 | tag
  self.writer:write32u(header)

  -- Update size fields
  self.size_32 = self.size_32 + (size + 1)
  self.size_64 = self.size_64 + (size + 1)
end

-- Marshal block (chooses optimal encoding)
function MarshalWriter:write_block(tag, size)
  if tag < 16 and size < 8 then
    self:write_small_block(tag, size)
  else
    self:write_block32(tag, size)
  end
end

-- Marshal double (DOUBLE_LITTLE)
function MarshalWriter:write_double(value)
  if type(value) ~= "number" then
    error("Marshal: expected number for double")
  end

  if not string.pack then
    error("Marshal: float/double marshalling requires Lua 5.3+ (string.pack)")
  end

  if self:memo(value) then return end  -- Check for sharing

  self.writer:write8u(M.CODE_DOUBLE_LITTLE)
  self.writer:write_double_little(value)

  -- Update size fields
  self.size_32 = self.size_32 + 3  -- 1 word for header + 2 words for double
  self.size_64 = self.size_64 + 2  -- 1 word for header + 1 word for double
end

-- Marshal double with specific endianness
function MarshalWriter:write_double_big(value)
  if type(value) ~= "number" then
    error("Marshal: expected number for double")
  end

  self.writer:write8u(M.CODE_DOUBLE_BIG)
  self.writer:write_double_big(value)

  -- Update size fields
  self.size_32 = self.size_32 + 3
  self.size_64 = self.size_64 + 2
end

-- Marshal float array (DOUBLE_ARRAY8_LITTLE)
function MarshalWriter:write_double_array8(values)
  if type(values) ~= "table" then
    error("Marshal: expected table for double array")
  end

  -- Note: memo check happens in the caller (write_double_array)
  -- to check the whole array, not just the values table

  local len = #values
  if len < 0 or len >= 256 then
    error("Marshal: DOUBLE_ARRAY8 length out of range (0-255)")
  end

  self.writer:write8u(M.CODE_DOUBLE_ARRAY8_LITTLE)
  self.writer:write8u(len)

  for i = 1, len do
    if type(values[i]) ~= "number" then
      error("Marshal: float array element " .. i .. " is not a number")
    end
    self.writer:write_double_little(values[i])
  end

  -- Update size fields
  self.size_32 = self.size_32 + 1 + (len * 2)
  self.size_64 = self.size_64 + 1 + len
end

-- Marshal float array (DOUBLE_ARRAY32_LITTLE)
function MarshalWriter:write_double_array32(values)
  if type(values) ~= "table" then
    error("Marshal: expected table for double array")
  end

  -- Note: memo check happens in the caller (write_double_array)

  local len = #values

  self.writer:write8u(M.CODE_DOUBLE_ARRAY32_LITTLE)
  self.writer:write32u(len)

  for i = 1, len do
    if type(values[i]) ~= "number" then
      error("Marshal: float array element " .. i .. " is not a number")
    end
    self.writer:write_double_little(values[i])
  end

  -- Update size fields
  self.size_32 = self.size_32 + 1 + (len * 2)
  self.size_64 = self.size_64 + 1 + len
end

-- Marshal float array (chooses optimal encoding)
function MarshalWriter:write_double_array(values, float_array_obj)
  -- float_array_obj is the {tag=254, values=values} wrapper for memo check
  if float_array_obj and self:memo(float_array_obj) then return end

  local len = #values
  if len < 256 then
    self:write_double_array8(values)
  else
    self:write_double_array32(values)
  end
end

-- Get marshalled data as string
function MarshalWriter:to_string()
  return self.writer:to_string()
end

--
-- Marshal Reader
--

local MarshalReader = {}
MarshalReader.__index = MarshalReader

function MarshalReader:new(str, offset, num_objects)
  offset = offset or 0
  num_objects = num_objects or 0
  local obj = {
    reader = Reader:new(str, offset),
    obj_counter = 0,
    intern_obj_table = num_objects > 0 and {} or nil
  }
  setmetatable(obj, self)
  return obj
end

-- Store object in intern table (for sharing during unmarshalling)
function MarshalReader:intern_store(v)
  if self.intern_obj_table then
    self.obj_counter = self.obj_counter + 1
    self.intern_obj_table[self.obj_counter] = v
  end
end

-- Recall shared object by offset
function MarshalReader:intern_recall(offset)
  if not self.intern_obj_table then
    error("Marshal: shared reference without object table")
  end
  -- Convert relative offset to absolute index
  local idx = self.obj_counter - offset
  local v = self.intern_obj_table[idx]
  if v == nil then
    error(string.format("Marshal: invalid shared reference offset %d (counter=%d)", offset, self.obj_counter))
  end
  return v
end

-- Read next value code
function MarshalReader:peek_code()
  local pos = self.reader:position()
  local code = self.reader:read8u()
  self.reader:seek(pos)
  return code
end

-- Unmarshal small integer (0-63)
function MarshalReader:read_small_int(code)
  return code % 64  -- code & 0x3F
end

-- Unmarshal INT8
function MarshalReader:read_int8()
  return self.reader:read8s()
end

-- Unmarshal INT16
function MarshalReader:read_int16()
  return self.reader:read16s()
end

-- Unmarshal INT32
function MarshalReader:read_int32()
  return self.reader:read32s()
end

-- Unmarshal small string (0-31 bytes)
function MarshalReader:read_small_string(code)
  local len = code % 32  -- code & 0x1F
  local v = self.reader:readstr(len)
  self:intern_store(v)
  return v
end

-- Unmarshal STRING8
function MarshalReader:read_string8()
  local len = self.reader:read8u()
  local v = self.reader:readstr(len)
  self:intern_store(v)
  return v
end

-- Unmarshal STRING32
function MarshalReader:read_string32()
  local len = self.reader:read32u()
  local v = self.reader:readstr(len)
  self:intern_store(v)
  return v
end

-- Unmarshal small block (tag 0-15, size 0-7)
function MarshalReader:read_small_block(code)
  local tag = code % 16  -- code & 0x0F
  local size = math.floor((code / 16)) % 8  -- (code >> 4) & 0x07
  return {tag = tag, size = size}
end

-- Unmarshal BLOCK32
function MarshalReader:read_block32()
  local header = self.reader:read32u()
  local tag = header % 256  -- header & 0xFF
  local size = math.floor(header / 1024)  -- header >> 10
  return {tag = tag, size = size}
end

-- Unmarshal double (DOUBLE_LITTLE)
function MarshalReader:read_double_little()
  local v = self.reader:read_double_little()
  self:intern_store(v)
  return v
end

-- Unmarshal double (DOUBLE_BIG)
function MarshalReader:read_double_big()
  local v = self.reader:read_double_big()
  self:intern_store(v)
  return v
end

-- Unmarshal float array (DOUBLE_ARRAY8_LITTLE)
function MarshalReader:read_double_array8_little()
  local len = self.reader:read8u()
  local v = {tag = 254, values = {}}
  self:intern_store(v)  -- Store before filling (for cycles)
  for i = 1, len do
    v.values[i] = self.reader:read_double_little()
  end
  return v
end

-- Unmarshal float array (DOUBLE_ARRAY8_BIG)
function MarshalReader:read_double_array8_big()
  local len = self.reader:read8u()
  local v = {tag = 254, values = {}}
  self:intern_store(v)
  for i = 1, len do
    v.values[i] = self.reader:read_double_big()
  end
  return v
end

-- Unmarshal float array (DOUBLE_ARRAY32_LITTLE)
function MarshalReader:read_double_array32_little()
  local len = self.reader:read32u()
  local v = {tag = 254, values = {}}
  self:intern_store(v)
  for i = 1, len do
    v.values[i] = self.reader:read_double_little()
  end
  return v
end

-- Unmarshal float array (DOUBLE_ARRAY32_BIG)
function MarshalReader:read_double_array32_big()
  local len = self.reader:read32u()
  local v = {tag = 254, values = {}}
  self:intern_store(v)
  for i = 1, len do
    v.values[i] = self.reader:read_double_big()
  end
  return v
end

-- Unmarshal value (main entry point)
function MarshalReader:read_value()
  local code = self.reader:read8u()

  -- Check for PREFIX_SMALL_INT (0x40-0x7F)
  if code >= M.PREFIX_SMALL_INT then
    if code >= M.PREFIX_SMALL_BLOCK then
      -- Small block (0x80-0xFF)
      return self:read_small_block(code)
    else
      -- Small int (0x40-0x7F)
      return self:read_small_int(code)
    end
  end

  -- Check for PREFIX_SMALL_STRING (0x20-0x3F)
  if code >= M.PREFIX_SMALL_STRING then
    return self:read_small_string(code)
  end

  -- Extended codes (0x00-0x1F)
  if code == M.CODE_INT8 then
    return self:read_int8()
  elseif code == M.CODE_INT16 then
    return self:read_int16()
  elseif code == M.CODE_INT32 then
    return self:read_int32()
  elseif code == M.CODE_INT64 then
    error("Marshal: INT64 not yet implemented")
  elseif code == M.CODE_SHARED8 then
    local offset = self.reader:read8u()
    return self:intern_recall(offset)
  elseif code == M.CODE_SHARED16 then
    local offset = self.reader:read16u()
    return self:intern_recall(offset)
  elseif code == M.CODE_SHARED32 then
    local offset = self.reader:read32u()
    return self:intern_recall(offset)
  elseif code == M.CODE_BLOCK32 then
    return self:read_block32()
  elseif code == M.CODE_STRING8 then
    return self:read_string8()
  elseif code == M.CODE_STRING32 then
    return self:read_string32()
  elseif code == M.CODE_DOUBLE_LITTLE then
    return self:read_double_little()
  elseif code == M.CODE_DOUBLE_BIG then
    return self:read_double_big()
  elseif code == M.CODE_DOUBLE_ARRAY8_LITTLE then
    return self:read_double_array8_little()
  elseif code == M.CODE_DOUBLE_ARRAY8_BIG then
    return self:read_double_array8_big()
  elseif code == M.CODE_DOUBLE_ARRAY32_LITTLE then
    return self:read_double_array32_little()
  elseif code == M.CODE_DOUBLE_ARRAY32_BIG then
    return self:read_double_array32_big()
  else
    error(string.format("Marshal: unsupported code 0x%02X", code))
  end
end

--
-- Public API
--

-- Marshal a value to bytes (without header for now)
function M.marshal_value(value)
  local writer = MarshalWriter:new()

  local value_type = type(value)
  if value_type == "number" then
    -- Check if it's a valid integer (not infinity, not too large)
    if value == math.floor(value) and value ~= math.huge and value ~= -math.huge
       and value >= -2147483648 and value <= 2147483647 then
      writer:write_int(value)
    else
      -- Float value, infinity, or out of int range
      writer:write_double(value)
    end
  elseif value_type == "string" then
    writer:write_string(value)
  elseif value_type == "table" then
    -- Check if it's a float array (tag 254)
    if value.tag == 254 and value.values then
      writer:write_double_array(value.values, value)  -- Pass value for sharing
    -- Check if it's a block representation
    elseif value.tag ~= nil and value.size ~= nil then
      writer:write_block(value.tag, value.size)
    else
      error("Marshal: complex blocks not yet implemented")
    end
  else
    error("Marshal: unsupported type " .. value_type)
  end

  return writer:to_string()
end

-- Unmarshal a value from bytes (without header for now)
function M.unmarshal_value(str, offset)
  local reader = MarshalReader:new(str, offset)
  return reader:read_value()
end

--
-- Module Exports
--

M.MarshalWriter = MarshalWriter
M.MarshalReader = MarshalReader

return M
