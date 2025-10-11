-- Js_of_ocaml runtime support
-- http://www.ocsigen.org/js_of_ocaml/
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, with linking exception;
-- either version 2.1 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

-- Marshal: OCaml Marshal format
-- Implements OCaml binary serialization format

-- Integer marshaling functions

--Provides: caml_marshal_write_int
--Requires: caml_marshal_buffer_write8u, caml_marshal_buffer_write16u, caml_marshal_buffer_write32u
function caml_marshal_write_int(buf, value)
  -- Encode integer with optimal format
  -- Small int (0-63): single byte 0x40-0x7F
  -- INT8 (-128 to 127 excluding 0-63): 0x00 + signed byte
  -- INT16 (-32768 to 32767 excluding INT8): 0x01 + signed 16-bit big-endian
  -- INT32 (else): 0x02 + signed 32-bit big-endian

  -- Check for small int (0-63)
  if value >= 0 and value <= 63 then
    -- Small int: 0x40 + value (0x40-0x7F)
    caml_marshal_buffer_write8u(buf, 0x40 + value)
    return
  end

  -- Check for INT8 range (-128 to 127)
  if value >= -128 and value <= 127 then
    -- CODE_INT8 (0x00) + signed byte
    caml_marshal_buffer_write8u(buf, 0x00)
    -- Convert signed to unsigned byte
    local byte_val = value
    if byte_val < 0 then
      byte_val = byte_val + 256
    end
    caml_marshal_buffer_write8u(buf, byte_val)
    return
  end

  -- Check for INT16 range (-32768 to 32767)
  if value >= -32768 and value <= 32767 then
    -- CODE_INT16 (0x01) + signed 16-bit big-endian
    caml_marshal_buffer_write8u(buf, 0x01)
    -- Convert signed to unsigned 16-bit
    local word_val = value
    if word_val < 0 then
      word_val = word_val + 65536
    end
    caml_marshal_buffer_write16u(buf, word_val)
    return
  end

  -- INT32: CODE_INT32 (0x02) + signed 32-bit big-endian
  caml_marshal_buffer_write8u(buf, 0x02)
  -- Convert signed to unsigned 32-bit
  local int_val = value
  if int_val < 0 then
    int_val = int_val + 4294967296
  end
  caml_marshal_buffer_write32u(buf, int_val)
end

--Provides: caml_marshal_read_int
--Requires: caml_marshal_read8u, caml_marshal_read16u, caml_marshal_read32u
function caml_marshal_read_int(str, offset)
  -- Decode integer and return {value, bytes_read}

  -- Read code byte
  local code = caml_marshal_read8u(str, offset)

  -- Small int (0x40-0x7F): value = code - 0x40
  if code >= 0x40 and code <= 0x7F then
    return {
      value = code - 0x40,
      bytes_read = 1
    }
  end

  -- CODE_INT8 (0x00): read signed byte
  if code == 0x00 then
    local byte_val = caml_marshal_read8u(str, offset + 1)
    -- Convert unsigned to signed byte
    local value = byte_val
    if value >= 128 then
      value = value - 256
    end
    return {
      value = value,
      bytes_read = 2
    }
  end

  -- CODE_INT16 (0x01): read signed 16-bit big-endian
  if code == 0x01 then
    local word_val = caml_marshal_read16u(str, offset + 1)
    -- Convert unsigned to signed 16-bit
    local value = word_val
    if value >= 32768 then
      value = value - 65536
    end
    return {
      value = value,
      bytes_read = 3
    }
  end

  -- CODE_INT32 (0x02): read signed 32-bit big-endian
  if code == 0x02 then
    local int_val = caml_marshal_read32u(str, offset + 1)
    -- Convert unsigned to signed 32-bit
    local value = int_val
    if value >= 2147483648 then
      value = value - 4294967296
    end
    return {
      value = value,
      bytes_read = 5
    }
  end

  error(string.format("caml_marshal_read_int: unknown code 0x%02X at offset %d", code, offset))
end

-- String marshaling functions

--Provides: caml_marshal_write_string
--Requires: caml_marshal_buffer_write8u, caml_marshal_buffer_write32u, caml_marshal_buffer_write_bytes
function caml_marshal_write_string(buf, str)
  -- Encode string with optimal format
  -- Small string (0-31 bytes): single byte 0x20-0x3F (0x20 + length) + bytes
  -- STRING8 (32-255 bytes): 0x09 + length byte + bytes
  -- STRING32 (256+ bytes): 0x0A + length (4 bytes big-endian) + bytes

  local len = #str

  -- Check for small string (0-31 bytes)
  if len <= 31 then
    -- Small string: 0x20 + length (0x20-0x3F)
    caml_marshal_buffer_write8u(buf, 0x20 + len)
    caml_marshal_buffer_write_bytes(buf, str)
    return
  end

  -- Check for STRING8 range (32-255 bytes)
  if len <= 255 then
    -- CODE_STRING8 (0x09) + length byte + bytes
    caml_marshal_buffer_write8u(buf, 0x09)
    caml_marshal_buffer_write8u(buf, len)
    caml_marshal_buffer_write_bytes(buf, str)
    return
  end

  -- STRING32: CODE_STRING32 (0x0A) + length (4 bytes big-endian) + bytes
  caml_marshal_buffer_write8u(buf, 0x0A)
  caml_marshal_buffer_write32u(buf, len)
  caml_marshal_buffer_write_bytes(buf, str)
end

--Provides: caml_marshal_read_string
--Requires: caml_marshal_read8u, caml_marshal_read32u, caml_marshal_read_bytes
function caml_marshal_read_string(str, offset)
  -- Decode string and return {value, bytes_read}

  -- Read code byte
  local code = caml_marshal_read8u(str, offset)

  -- Small string (0x20-0x3F): length = code - 0x20
  if code >= 0x20 and code <= 0x3F then
    local len = code - 0x20
    -- Validate sufficient data
    if #str < offset + 1 + len then
      error("caml_marshal_read_string: insufficient data for small string")
    end
    local value = caml_marshal_read_bytes(str, offset + 1, len)
    return {
      value = value,
      bytes_read = 1 + len
    }
  end

  -- CODE_STRING8 (0x09): read length byte + bytes
  if code == 0x09 then
    local len = caml_marshal_read8u(str, offset + 1)
    -- Validate sufficient data
    if #str < offset + 2 + len then
      error("caml_marshal_read_string: insufficient data for STRING8")
    end
    local value = caml_marshal_read_bytes(str, offset + 2, len)
    return {
      value = value,
      bytes_read = 2 + len
    }
  end

  -- CODE_STRING32 (0x0A): read 4-byte length + bytes
  if code == 0x0A then
    local len = caml_marshal_read32u(str, offset + 1)
    -- Validate sufficient data
    if #str < offset + 5 + len then
      error("caml_marshal_read_string: insufficient data for STRING32")
    end
    local value = caml_marshal_read_bytes(str, offset + 5, len)
    return {
      value = value,
      bytes_read = 5 + len
    }
  end

  error(string.format("caml_marshal_read_string: unknown code 0x%02X at offset %d", code, offset))
end

-- Block marshaling functions

--Provides: caml_marshal_write_block
--Requires: caml_marshal_buffer_write8u, caml_marshal_buffer_write32u
function caml_marshal_write_block(buf, block, write_value_fn)
  -- Encode block with fields
  -- Small block (tag 0-15, size 0-7): single byte 0x80 + (tag | (size << 4))
  -- BLOCK32 (else): 0x08 + header (4 bytes: (size << 10) | tag big-endian) + fields
  -- Block format: {tag = N, size = M, [1] = field1, [2] = field2, ...}

  local tag = block.tag or 0
  local size = block.size or #block

  -- Check for small block (tag 0-15, size 0-7)
  if tag >= 0 and tag <= 15 and size >= 0 and size <= 7 then
    -- Small block: 0x80 + (tag | (size << 4))
    -- Lua 5.1 compatible: use arithmetic instead of bitwise operators
    local byte = 0x80 + tag + (size * 16)  -- size << 4 = size * 16
    caml_marshal_buffer_write8u(buf, byte)
  else
    -- BLOCK32: 0x08 + header (4 bytes: (size << 10) | tag)
    caml_marshal_buffer_write8u(buf, 0x08)  -- CODE_BLOCK32
    -- Header: (size << 10) | tag
    -- Lua 5.1 compatible: size * 1024 + tag
    local header = size * 1024 + tag  -- size << 10 = size * 1024
    caml_marshal_buffer_write32u(buf, header)
  end

  -- Write fields recursively using provided write_value_fn
  for i = 1, size do
    write_value_fn(buf, block[i])
  end
end

--Provides: caml_marshal_read_block
--Requires: caml_marshal_read8u, caml_marshal_read32u
function caml_marshal_read_block(str, offset, read_value_fn)
  -- Decode block and return {value, bytes_read}
  -- Block format: {tag = N, size = M, [1] = field1, [2] = field2, ...}

  -- Read code byte
  local code = caml_marshal_read8u(str, offset)
  local bytes_consumed = 1
  local tag, size

  -- Small block (0x80-0xFF): extract tag and size from single byte
  if code >= 0x80 and code <= 0xFF then
    -- Small block: code = 0x80 + (tag | (size << 4))
    local val = code - 0x80
    -- Extract tag and size using Lua 5.1 compatible arithmetic
    tag = val % 16  -- val & 0x0F
    size = math.floor(val / 16)  -- (val >> 4)

  -- CODE_BLOCK32 (0x08): read 4-byte header
  elseif code == 0x08 then
    local header = caml_marshal_read32u(str, offset + 1)
    bytes_consumed = bytes_consumed + 4
    -- Extract tag and size: header = (size << 10) | tag
    tag = header % 1024  -- header & 0x3FF
    size = math.floor(header / 1024)  -- header >> 10
  else
    error(string.format("caml_marshal_read_block: unknown code 0x%02X at offset %d", code, offset))
  end

  -- Create block with tag and size
  local block = {
    tag = tag,
    size = size
  }

  -- Read fields recursively using provided read_value_fn
  local field_offset = offset + bytes_consumed
  for i = 1, size do
    local result = read_value_fn(str, field_offset)
    block[i] = result.value
    field_offset = field_offset + result.bytes_read
    bytes_consumed = bytes_consumed + result.bytes_read
  end

  return {
    value = block,
    bytes_read = bytes_consumed
  }
end

-- Double/float marshaling functions

--Provides: caml_marshal_write_double
--Requires: caml_marshal_buffer_write8u, caml_marshal_write_double_little
function caml_marshal_write_double(buf, value)
  -- Encode double with IEEE 754 little-endian format
  -- CODE_DOUBLE_LITTLE (0x0C): 1 byte code + 8 bytes IEEE 754 little-endian
  -- Uses caml_marshal_write_double_little (Lua 5.1 compatible)

  -- CODE_DOUBLE_LITTLE (0x0C)
  caml_marshal_buffer_write8u(buf, 0x0C)

  -- Write double using marshal_io function (handles Lua 5.1 fallback)
  caml_marshal_write_double_little(buf, value)
end

--Provides: caml_marshal_read_double
--Requires: caml_marshal_read8u, caml_marshal_read_double_little
function caml_marshal_read_double(str, offset)
  -- Decode double and return {value, bytes_read}
  -- CODE_DOUBLE_LITTLE (0x0C): 1 byte code + 8 bytes IEEE 754 little-endian
  -- Uses caml_marshal_read_double_little (Lua 5.1 compatible)

  -- Read code byte
  local code = caml_marshal_read8u(str, offset)

  -- CODE_DOUBLE_LITTLE (0x0C)
  if code == 0x0C then
    -- Validate sufficient data (8 bytes for double)
    if #str < offset + 1 + 8 then
      error("caml_marshal_read_double: insufficient data for double (need 8 bytes)")
    end

    -- Read double using marshal_io function (handles Lua 5.1 fallback)
    local value = caml_marshal_read_double_little(str, offset + 1)

    return {
      value = value,
      bytes_read = 9  -- 1 code + 8 data
    }
  end

  error(string.format("caml_marshal_read_double: unknown code 0x%02X at offset %d", code, offset))
end

--Provides: caml_marshal_write_float_array
--Requires: caml_marshal_buffer_write8u, caml_marshal_buffer_write32u, caml_marshal_write_double_little
function caml_marshal_write_float_array(buf, arr)
  -- Encode float array (OCaml block with tag 254)
  -- Float array format in OCaml Marshal:
  -- DOUBLE_ARRAY8_LITTLE (0x0E): code + length byte + doubles (if length < 256)
  -- DOUBLE_ARRAY32_LITTLE (0x07): code + length (4 bytes) + doubles (if length >= 256)
  -- Array should be Lua table: {[1] = v1, [2] = v2, ...} with length in arr.size or #arr
  -- Uses caml_marshal_write_double_little (Lua 5.1 compatible)

  -- Get array length
  local len = arr.size or #arr

  -- Check for DOUBLE_ARRAY8_LITTLE range (length < 256)
  if len < 256 then
    -- DOUBLE_ARRAY8_LITTLE (0x0E) + length byte + doubles
    caml_marshal_buffer_write8u(buf, 0x0E)
    caml_marshal_buffer_write8u(buf, len)
  else
    -- DOUBLE_ARRAY32_LITTLE (0x07) + length (4 bytes) + doubles
    caml_marshal_buffer_write8u(buf, 0x07)
    caml_marshal_buffer_write32u(buf, len)
  end

  -- Write each double in little-endian format using marshal_io function
  for i = 1, len do
    local value = arr[i]
    if type(value) ~= "number" then
      error(string.format("caml_marshal_write_float_array: array element %d is not a number", i))
    end
    caml_marshal_write_double_little(buf, value)
  end
end

--Provides: caml_marshal_read_float_array
--Requires: caml_marshal_read8u, caml_marshal_read32u, caml_marshal_read_double_little
function caml_marshal_read_float_array(str, offset)
  -- Decode float array and return {value, bytes_read}
  -- Float array value is Lua table: {size = N, [1] = v1, [2] = v2, ...}
  -- Uses caml_marshal_read_double_little (Lua 5.1 compatible)

  -- Read code byte
  local code = caml_marshal_read8u(str, offset)
  local bytes_consumed = 1
  local len

  -- DOUBLE_ARRAY8_LITTLE (0x0E): read length byte
  if code == 0x0E then
    len = caml_marshal_read8u(str, offset + 1)
    bytes_consumed = bytes_consumed + 1

  -- DOUBLE_ARRAY32_LITTLE (0x07): read 4-byte length
  elseif code == 0x07 then
    len = caml_marshal_read32u(str, offset + 1)
    bytes_consumed = bytes_consumed + 4

  else
    error(string.format("caml_marshal_read_float_array: unknown code 0x%02X at offset %d", code, offset))
  end

  -- Validate sufficient data (8 bytes per double)
  local data_size = len * 8
  if #str < offset + bytes_consumed + data_size then
    error(string.format("caml_marshal_read_float_array: insufficient data (need %d bytes for %d doubles)", data_size, len))
  end

  -- Create values array
  local values = {}

  -- Read each double using marshal_io function
  local data_offset = offset + bytes_consumed
  for i = 1, len do
    local value = caml_marshal_read_double_little(str, data_offset)
    values[i] = value
    data_offset = data_offset + 8
    bytes_consumed = bytes_consumed + 8
  end

  -- Return float array with both formats for compatibility:
  -- - size field for test_marshal_double.lua compatibility
  -- - tag=254 and values for test_io_marshal.lua compatibility
  -- - numeric indices [1], [2], ... for direct access
  local arr = {
    tag = 254,
    size = len,
    values = values
  }
  for i = 1, len do
    arr[i] = values[i]
  end

  return {
    value = arr,
    bytes_read = bytes_consumed
  }
end

-- Core value marshaling functions

--Provides: caml_marshal_write_value
--Requires: caml_marshal_write_int, caml_marshal_write_double, caml_marshal_write_string, caml_marshal_write_block, caml_marshal_write_float_array, caml_marshal_buffer_write8u, caml_marshal_buffer_write32u
function caml_marshal_write_value(buf, value, seen, object_table, next_id)
  -- Main marshaling dispatch function with cycle detection and object sharing
  -- Dispatch based on Lua type: number → int/double, string → string, table → block/float_array
  -- Recursive marshaling for block fields
  -- seen: table tracking visited tables to detect cycles (optional, created if nil)
  -- object_table: table mapping table → object_id for sharing (optional, created if nil)
  -- next_id: table with {value = N} for next object ID (optional, created if nil)

  -- Initialize tables on first call
  seen = seen or {}
  object_table = object_table or {}
  next_id = next_id or {value = 1}

  local value_type = type(value)

  if value_type == "number" then
    -- Number: try integer first, fall back to double
    -- Integer if in int32 range and no fractional part
    if value >= -2147483648 and value <= 2147483647 and value == math.floor(value) then
      caml_marshal_write_int(buf, value)
    else
      caml_marshal_write_double(buf, value)
    end

  elseif value_type == "string" then
    -- String
    caml_marshal_write_string(buf, value)

  elseif value_type == "table" then
    -- Cycle detection: check if this table is currently being visited
    if seen[value] then
      error("caml_marshal_write_value: cyclic data structure detected (object sharing not implemented yet)")
    end

    -- Mark table as being visited
    seen[value] = true

    -- Table: could be block or float array
    -- Check if it's a float array (tag 254 in OCaml)
    -- Float arrays have numeric indices and all number elements
    -- For simplicity: if table has .tag field, treat as block; else check if float array

    if value.tag == 254 and value.values then
      -- Float array with explicit tag 254 and values field: {tag = 254, values = {...}}
      -- Extract the values array and marshal it as a float array
      caml_marshal_write_float_array(buf, value.values)

    elseif value.tag ~= nil then
      -- Block: has tag field
      -- Use recursive write_value for fields, passing seen, object_table, next_id
      caml_marshal_write_block(buf, value, function(b, v)
        caml_marshal_write_value(b, v, seen, object_table, next_id)
      end)

    else
      -- Plain array without .tag field: treat as block with tag 0
      -- Note: We don't auto-detect float arrays from plain arrays of numbers
      -- Float arrays must be explicitly marked with {tag = 254, values = {...}}
      local len = value.size or #value
      local block = {
        tag = 0,
        size = len
      }
      for i = 1, len do
        block[i] = value[i]
      end
      caml_marshal_write_block(buf, block, function(b, v)
        caml_marshal_write_value(b, v, seen, object_table, next_id)
      end)
    end

    -- Unmark table after marshaling (allows sibling references in DAG)
    seen[value] = nil

  elseif value_type == "boolean" then
    -- Boolean: encode as integer 0 (false) or 1 (true)
    caml_marshal_write_int(buf, value and 1 or 0)

  elseif value_type == "nil" then
    -- Nil: encode as integer 0 (unit value in OCaml)
    caml_marshal_write_int(buf, 0)

  else
    error(string.format("caml_marshal_write_value: unsupported type %s", value_type))
  end
end

--Provides: caml_marshal_read_value
--Requires: caml_marshal_read8u, caml_marshal_read_int, caml_marshal_read_double, caml_marshal_read_string, caml_marshal_read_block, caml_marshal_read_float_array, caml_marshal_read32u
function caml_marshal_read_value(str, offset, objects_by_id, next_id)
  -- Main unmarshaling dispatch function with object sharing
  -- Read code byte and dispatch to appropriate reader
  -- Recursive unmarshaling for block fields
  -- objects_by_id: table mapping object_id → table for sharing (optional, created if nil)
  -- next_id: table with {value = N} for next object ID (optional, created if nil)
  -- Return {value, bytes_read}

  -- Initialize tables on first call
  objects_by_id = objects_by_id or {}
  next_id = next_id or {value = 1}

  -- Read code byte to determine type
  local code = caml_marshal_read8u(str, offset)

  -- CODE_SHARED (0x04): shared object reference
  if code == 0x04 then
    local obj_id = caml_marshal_read32u(str, offset + 1)
    local shared_obj = objects_by_id[obj_id]
    if not shared_obj then
      error(string.format("caml_marshal_read_value: invalid shared object reference %d at offset %d", obj_id, offset))
    end
    return {
      value = shared_obj,
      bytes_read = 5
    }

  -- Small int (0x40-0x7F): 0-63
  elseif code >= 0x40 and code <= 0x7F then
    return caml_marshal_read_int(str, offset)

  -- CODE_INT8 (0x00): signed byte
  elseif code == 0x00 then
    return caml_marshal_read_int(str, offset)

  -- CODE_INT16 (0x01): signed 16-bit
  elseif code == 0x01 then
    return caml_marshal_read_int(str, offset)

  -- CODE_INT32 (0x02): signed 32-bit
  elseif code == 0x02 then
    return caml_marshal_read_int(str, offset)

  -- Small string (0x20-0x3F): 0-31 bytes
  elseif code >= 0x20 and code <= 0x3F then
    return caml_marshal_read_string(str, offset)

  -- CODE_STRING8 (0x09): 32-255 bytes
  elseif code == 0x09 then
    return caml_marshal_read_string(str, offset)

  -- CODE_STRING32 (0x0A): 256+ bytes
  elseif code == 0x0A then
    return caml_marshal_read_string(str, offset)

  -- CODE_DOUBLE_LITTLE (0x0C): IEEE 754 double
  elseif code == 0x0C then
    return caml_marshal_read_double(str, offset)

  -- CODE_DOUBLE_ARRAY8_LITTLE (0x0E): float array with 8-bit length
  elseif code == 0x0E then
    local result = caml_marshal_read_float_array(str, offset)
    local obj_id = next_id.value
    objects_by_id[obj_id] = result.value
    next_id.value = next_id.value + 1
    return result

  -- CODE_DOUBLE_ARRAY32_LITTLE (0x07): float array with 32-bit length
  elseif code == 0x07 then
    local result = caml_marshal_read_float_array(str, offset)
    local obj_id = next_id.value
    objects_by_id[obj_id] = result.value
    next_id.value = next_id.value + 1
    return result

  -- Small block (0x80-0xFF): tag 0-15, size 0-7
  elseif code >= 0x80 and code <= 0xFF then
    -- Allocate object ID first (before reading fields, for cycles)
    local obj_id = next_id.value
    next_id.value = next_id.value + 1

    -- Create placeholder to be filled by read_block
    local placeholder = {}
    objects_by_id[obj_id] = placeholder

    -- Read block with fields
    local result = caml_marshal_read_block(str, offset, function(s, o)
      return caml_marshal_read_value(s, o, objects_by_id, next_id)
    end)

    -- Update placeholder with actual block content
    local block = result.value
    for k, v in pairs(block) do
      placeholder[k] = v
    end

    return {
      value = placeholder,
      bytes_read = result.bytes_read
    }

  -- CODE_BLOCK32 (0x08): large block
  elseif code == 0x08 then
    -- Allocate object ID first (before reading fields, for cycles)
    local obj_id = next_id.value
    next_id.value = next_id.value + 1

    -- Create placeholder to be filled by read_block
    local placeholder = {}
    objects_by_id[obj_id] = placeholder

    -- Read block with fields
    local result = caml_marshal_read_block(str, offset, function(s, o)
      return caml_marshal_read_value(s, o, objects_by_id, next_id)
    end)

    -- Update placeholder with actual block content
    local block = result.value
    for k, v in pairs(block) do
      placeholder[k] = v
    end

    return {
      value = placeholder,
      bytes_read = result.bytes_read
    }

  else
    error(string.format("caml_marshal_read_value: unknown code 0x%02X at offset %d", code, offset))
  end
end

-- Public API

--Provides: caml_marshal_to_string
--Requires: caml_marshal_buffer_create, caml_marshal_write_value, caml_marshal_buffer_to_string, caml_marshal_header_write, caml_marshal_buffer_write8u
function caml_marshal_to_string(value, flags)
  -- Marshal value to string with header
  -- flags parameter is optional (reserved for future use, not implemented)
  -- Returns: marshaled string with 20-byte header + data

  -- Create buffer for marshaling the value
  local data_buf = caml_marshal_buffer_create()

  -- Create object tracking tables for sharing
  local seen = {}
  local object_table = {}
  local next_id = {value = 1}

  -- Marshal the value to the data buffer with object sharing
  caml_marshal_write_value(data_buf, value, seen, object_table, next_id)

  -- Get data length and number of objects
  local data_len = data_buf.length
  local num_objects = next_id.value - 1

  -- Create buffer for header + data
  local buf = caml_marshal_buffer_create()

  -- Write 20-byte header
  -- Header format: magic (4) | data_len (4) | num_objects (4) | size_32 (4) | size_64 (4)
  -- num_objects: count of shared objects (tables/arrays)
  -- size_32/size_64: reserved (0)
  caml_marshal_header_write(buf, data_len, num_objects, 0, 0)

  -- Append data bytes
  for i = 1, data_len do
    buf.length = buf.length + 1
    buf.bytes[buf.length] = data_buf.bytes[i]
  end

  -- Convert to string
  return caml_marshal_buffer_to_string(buf)
end

--Provides: caml_marshal_to_bytes
--Requires: caml_marshal_to_string
function caml_marshal_to_bytes(value, flags)
  -- Alias for caml_marshal_to_string
  return caml_marshal_to_string(value, flags)
end

--Provides: caml_marshal_from_bytes
--Requires: caml_marshal_header_read, caml_marshal_header_size, caml_marshal_read_value
function caml_marshal_from_bytes(str, offset)
  -- Unmarshal value from string with header
  -- offset parameter is optional (defaults to 0)
  -- Returns: unmarshaled value

  -- Default offset to 0
  offset = offset or 0

  -- Read and validate header (20 bytes)
  local header = caml_marshal_header_read(str, offset)

  -- Header contains: magic, data_len, num_objects, size_32, size_64
  -- num_objects tells us how many shared objects to expect

  -- Calculate data offset (after header)
  local header_size = caml_marshal_header_size()
  local data_offset = offset + header_size

  -- Create object tracking tables for sharing
  local objects_by_id = {}
  local next_id = {value = 1}

  -- Unmarshal value from data section with object sharing
  local result = caml_marshal_read_value(str, data_offset, objects_by_id, next_id)

  -- Return the unmarshaled value (not the bytes_read)
  return result.value
end

--Provides: caml_marshal_from_string
--Requires: caml_marshal_from_bytes
function caml_marshal_from_string(str, offset)
  -- Alias for caml_marshal_from_bytes
  return caml_marshal_from_bytes(str, offset)
end

--Provides: caml_marshal_data_size
--Requires: caml_marshal_header_read
function caml_marshal_data_size(str, offset)
  -- Return data length from header (excludes header size)
  -- offset parameter is optional (defaults to 0)

  -- Default offset to 0
  offset = offset or 0

  -- Read header
  local header = caml_marshal_header_read(str, offset)

  -- Return data length
  return header.data_len
end

--Provides: caml_marshal_total_size
--Requires: caml_marshal_header_size, caml_marshal_data_size
function caml_marshal_total_size(str, offset)
  -- Return total size: header size (20) + data length
  -- offset parameter is optional (defaults to 0)

  -- Default offset to 0
  offset = offset or 0

  -- Get header size (always 20)
  local header_size = caml_marshal_header_size()

  -- Get data size
  local data_size = caml_marshal_data_size(str, offset)

  -- Return total
  return header_size + data_size
end
