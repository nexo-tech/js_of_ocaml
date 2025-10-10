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

-- Marshal: Header Parsing
--
-- Handles magic number validation and header parsing for marshal format.
-- Supports both standard (20-byte) and compressed (VLQ) headers.

dofile("marshal_io.lua")

-- Magic numbers (global for use by marshal.lua)
MARSHAL_MAGIC_SMALL = 0x8495A6BE       -- Standard 32-bit format
MARSHAL_MAGIC_COMPRESSED = 0x8495A6BD  -- Compressed format with VLQ
MARSHAL_MAGIC_BIG = 0x8495A6BF         -- 64-bit format (error on 32-bit)

--
-- VLQ (Variable-Length Quantity) Encoding
--

-- Read VLQ from reader
-- Returns: value, overflow_detected
-- Helper function for marshal_header
function marshal_header_read_vlq(reader)
  local c = reader:read8u()
  local n = c % 128  -- c & 0x7F

  local overflow = false

  while c >= 128 do  -- c & 0x80 != 0
    c = reader:read8u()
    local n7 = n * 128  -- n << 7

    -- Check for overflow (if shift didn't preserve value)
    if n ~= math.floor(n7 / 128) then
      overflow = true
    end

    n = n7 + (c % 128)  -- n7 | (c & 0x7F)
  end

  return n, overflow
end

-- Write VLQ to writer
-- Helper function for marshal_header
function marshal_header_write_vlq(writer, n)
  if n < 0 then
    error("Marshal: VLQ cannot encode negative values")
  end

  -- Collect bytes from least to most significant
  local bytes = {}

  -- Last byte (no continuation bit)
  table.insert(bytes, n % 128)
  n = math.floor(n / 128)

  -- Remaining bytes (with continuation bit, from LSB to MSB)
  while n > 0 do
    table.insert(bytes, 128 + (n % 128))  -- 0x80 | (n & 0x7F)
    n = math.floor(n / 128)
  end

  -- Write in reverse order (most significant byte first)
  for i = #bytes, 1, -1 do
    writer:write8u(bytes[i])
  end
end

--
-- Header Structure
--

-- Header contains:
--   magic: magic number (identifies format)
--   header_len: total header length in bytes
--   data_len: length of marshalled data (after header)
--   uncompressed_data_len: uncompressed length (for compressed format)
--   num_objects: number of objects in intern table
--   size_32: size field for 32-bit compatibility
--   size_64: size field for 64-bit compatibility
--   compressed: boolean flag

-- Read header from byte string
-- Returns header table or throws error
-- Helper function for marshal
--Requires: get_Reader_class
function marshal_header_read_header(str, offset)
  offset = offset or 0
  local Reader = get_Reader_class()
  local reader = Reader:new(str, offset)

  local old_pos = reader:position()
  local magic = reader:read32u()

  local header = {
    magic = magic,
    compressed = false
  }

  if magic == MARSHAL_MAGIC_SMALL then
    -- Standard 20-byte header
    header.header_len = 20
    header.compressed = false
    header.data_len = reader:read32u()
    header.uncompressed_data_len = header.data_len
    header.num_objects = reader:read32u()
    header.size_32 = reader:read32u()
    header.size_64 = reader:read32u()

  elseif magic == MARSHAL_MAGIC_COMPRESSED then
    -- Compressed header with VLQ encoding
    local len_byte = reader:read8u()
    header.header_len = len_byte % 64  -- len_byte & 0x3F
    header.compressed = true

    local overflow = false
    local data_len, ovf1 = marshal_header_read_vlq(reader)
    local uncompressed_data_len, ovf2 = marshal_header_read_vlq(reader)
    local num_objects, ovf3 = marshal_header_read_vlq(reader)
    local size_32, ovf4 = marshal_header_read_vlq(reader)
    local size_64, ovf5 = marshal_header_read_vlq(reader)

    overflow = ovf1 or ovf2 or ovf3 or ovf4 or ovf5

    if overflow then
      error("Marshal: object too large to be read back on this platform")
    end

    header.data_len = data_len
    header.uncompressed_data_len = uncompressed_data_len
    header.num_objects = num_objects
    header.size_32 = size_32
    header.size_64 = size_64

  elseif magic == MARSHAL_MAGIC_BIG then
    error("Marshal: object too large to be read back on a 32-bit platform")

  else
    error(string.format("Marshal: bad magic number 0x%08X", magic))
  end

  -- Validate header length
  local actual_header_len = reader:position() - old_pos
  if header.header_len ~= actual_header_len then
    error(string.format("Marshal: invalid header (expected %d bytes, got %d)",
                       header.header_len, actual_header_len))
  end

  return header
end

-- Write standard header (20 bytes)
-- data_len: length of marshalled data
-- num_objects: number of objects in intern table
-- size_32, size_64: size fields (usually 0)
-- Returns: byte string
-- Helper function for marshal
--Requires: get_Writer_class
function marshal_header_write_header(data_len, num_objects, size_32, size_64)
  num_objects = num_objects or 0
  size_32 = size_32 or 0
  size_64 = size_64 or 0

  local Writer = get_Writer_class()
  local writer = Writer:new()

  -- Write magic number
  writer:write32u(MARSHAL_MAGIC_SMALL)

  -- Write header fields
  writer:write32u(data_len)
  writer:write32u(num_objects)
  writer:write32u(size_32)
  writer:write32u(size_64)

  return writer:to_string()
end

-- Write compressed header (VLQ format)
-- Note: This is for future compression support
-- Helper function for marshal
--Requires: get_Writer_class
function marshal_header_write_compressed_header(data_len, uncompressed_data_len, num_objects, size_32, size_64)
  num_objects = num_objects or 0
  size_32 = size_32 or 0
  size_64 = size_64 or 0

  local Writer = get_Writer_class()
  local writer = Writer:new()

  -- Write magic number
  writer:write32u(MARSHAL_MAGIC_COMPRESSED)

  -- Temporarily write header length byte (will update later)
  local len_pos = writer:position()
  writer:write8u(0)

  -- Write VLQ fields
  marshal_header_write_vlq(writer, data_len)
  marshal_header_write_vlq(writer, uncompressed_data_len)
  marshal_header_write_vlq(writer, num_objects)
  marshal_header_write_vlq(writer, size_32)
  marshal_header_write_vlq(writer, size_64)

  -- Update header length
  local header_len = writer:position()
  writer:write_at(len_pos, 8, header_len)

  return writer:to_string()
end

-- Parse total size from marshal data (without full parsing)
-- This reads just the header to determine total size
-- Returns: header_len + data_len
-- Helper function for marshal
function marshal_header_total_size(str, offset)
  local header = marshal_header_read_header(str, offset)
  return header.header_len + header.data_len
end

-- Parse data size from marshal data (data length only)
-- Returns: data_len
-- Helper function for marshal
function marshal_header_data_size(str, offset)
  local header = marshal_header_read_header(str, offset)
  return header.data_len
end
