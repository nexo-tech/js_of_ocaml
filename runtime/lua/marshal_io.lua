-- Js_of_ocaml runtime support
-- http://www.ocsigen.org/js_of_ocaml/
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Foundation, with linking exception;
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

-- Marshal: Binary Reader/Writer
--
-- Provides low-level binary I/O for marshal format parsing and generation.
-- Handles both big-endian and little-endian encoding.
--
-- Note: Reader and Writer classes are defined globally for use by marshal modules.
-- The linker will inline this entire file when marshal.lua is included.

--
-- Binary Reader
--

Reader = {}  -- Global class for binary reading
Reader.__index = Reader

-- Create new reader from byte string
-- @param str: string of bytes
-- @param offset: starting offset (0-indexed, default 0)
function Reader:new(str, offset)
  offset = offset or 0

  local bytes = {}
  for i = 1, #str do
    bytes[i] = string.byte(str, i)
  end

  local obj = {
    bytes = bytes,
    pos = offset + 1,  -- Lua is 1-indexed
    len = #bytes
  }
  setmetatable(obj, self)
  return obj
end

-- Get current position (0-indexed)
function Reader:position()
  return self.pos - 1
end

-- Set position (0-indexed)
function Reader:seek(pos)
  self.pos = pos + 1
end

-- Check if more data available
function Reader:has_more()
  return self.pos <= self.len
end

-- Remaining bytes
function Reader:remaining()
  return self.len - self.pos + 1
end

-- Read single byte (bounds check)
function Reader:read_byte()
  if self.pos > self.len then
    error("Marshal: unexpected end of input")
  end
  local b = self.bytes[self.pos]
  self.pos = self.pos + 1
  return b
end

-- Read unsigned 8-bit integer
function Reader:read8u()
  return self:read_byte()
end

-- Read signed 8-bit integer
function Reader:read8s()
  local b = self:read_byte()
  if b >= 128 then
    return b - 256  -- Sign extend
  end
  return b
end

-- Read unsigned 16-bit integer (big-endian)
function Reader:read16u()
  local b1 = self:read_byte()
  local b2 = self:read_byte()
  return (b1 * 256) + b2
end

-- Read signed 16-bit integer (big-endian)
function Reader:read16s()
  local n = self:read16u()
  if n >= 32768 then
    return n - 65536  -- Sign extend
  end
  return n
end

-- Read unsigned 32-bit integer (big-endian)
function Reader:read32u()
  local b1 = self:read_byte()
  local b2 = self:read_byte()
  local b3 = self:read_byte()
  local b4 = self:read_byte()
  -- Careful with arithmetic to avoid overflow
  local n = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
  return n
end

-- Read signed 32-bit integer (big-endian)
function Reader:read32s()
  local n = self:read32u()
  if n >= 2147483648 then
    return n - 4294967296  -- Sign extend
  end
  return n
end

-- Read string of specified length
function Reader:readstr(len)
  if self.pos + len - 1 > self.len then
    error("Marshal: unexpected end of input")
  end
  local chars = {}
  for i = 1, len do
    table.insert(chars, string.char(self.bytes[self.pos]))
    self.pos = self.pos + 1
  end
  return table.concat(chars)
end

-- Read byte array (for float conversion)
function Reader:readbytes(len)
  if self.pos + len - 1 > self.len then
    error("Marshal: unexpected end of input")
  end
  local arr = {}
  for i = 1, len do
    arr[i] = self.bytes[self.pos]
    self.pos = self.pos + 1
  end
  return arr
end

-- Read IEEE 754 double (8 bytes, little-endian)
function Reader:read_double_little()
  local bytes = self:readbytes(8)

  -- Use string.unpack if available (Lua 5.3+)
  if string.unpack then
    -- Reverse bytes for little-endian
    local str = ""
    for i = 1, 8 do
      str = str .. string.char(bytes[i])
    end
    return string.unpack("<d", str)
  else
    -- Fallback: manual IEEE 754 decoding
    return self:decode_ieee754(bytes, false)
  end
end

-- Read IEEE 754 double (8 bytes, big-endian)
function Reader:read_double_big()
  local bytes = self:readbytes(8)

  -- Use string.unpack if available (Lua 5.3+)
  if string.unpack then
    local str = ""
    for i = 1, 8 do
      str = str .. string.char(bytes[i])
    end
    return string.unpack(">d", str)
  else
    -- Fallback: manual IEEE 754 decoding
    return self:decode_ieee754(bytes, true)
  end
end

-- Decode IEEE 754 double from byte array (fallback for Lua 5.1/5.2)
function Reader:decode_ieee754(bytes, big_endian)
  -- Extract sign, exponent, mantissa
  local b = bytes
  local sign, exponent, mantissa

  if big_endian then
    sign = b[1] >= 128
    exponent = ((b[1] % 128) * 16) + math.floor(b[2] / 16)
    mantissa = ((b[2] % 16) * 281474976710656)  -- 2^48
              + (b[3] * 1099511627776)          -- 2^40
              + (b[4] * 4294967296)              -- 2^32
              + (b[5] * 16777216)                -- 2^24
              + (b[6] * 65536)                   -- 2^16
              + (b[7] * 256)
              + b[8]
  else
    sign = b[8] >= 128
    exponent = ((b[8] % 128) * 16) + math.floor(b[7] / 16)
    mantissa = ((b[7] % 16) * 281474976710656)
              + (b[6] * 1099511627776)
              + (b[5] * 4294967296)
              + (b[4] * 16777216)
              + (b[3] * 65536)
              + (b[2] * 256)
              + b[1]
  end

  -- Handle special cases
  if exponent == 0 then
    if mantissa == 0 then
      return sign and -0.0 or 0.0
    else
      -- Denormalized number
      local value = mantissa / (2^52) * (2^(-1022))
      return sign and -value or value
    end
  elseif exponent == 2047 then
    if mantissa == 0 then
      return sign and -math.huge or math.huge
    else
      return 0/0  -- NaN
    end
  else
    -- Normalized number
    local value = (1 + mantissa / (2^52)) * (2^(exponent - 1023))
    return sign and -value or value
  end
end

--
-- Binary Writer
--

Writer = {}  -- Global class for binary writing
Writer.__index = Writer

-- Create new writer
function Writer:new()
  local obj = {
    bytes = {},
    pos = 1
  }
  setmetatable(obj, self)
  return obj
end

-- Get current position (0-indexed)
function Writer:position()
  return self.pos - 1
end

-- Get total size
function Writer:size()
  return #self.bytes
end

-- Write single byte
function Writer:write_byte(b)
  self.bytes[self.pos] = b % 256
  self.pos = self.pos + 1
end

-- Write unsigned 8-bit integer
function Writer:write8u(n)
  self:write_byte(n)
end

-- Write unsigned 16-bit integer (big-endian)
function Writer:write16u(n)
  self:write_byte(math.floor(n / 256))
  self:write_byte(n % 256)
end

-- Write unsigned 32-bit integer (big-endian)
function Writer:write32u(n)
  self:write_byte(math.floor(n / 16777216))
  self:write_byte(math.floor(n / 65536) % 256)
  self:write_byte(math.floor(n / 256) % 256)
  self:write_byte(n % 256)
end

-- Write signed 32-bit integer (big-endian, two's complement)
function Writer:write32s(n)
  -- Convert negative to unsigned representation (two's complement)
  if n < 0 then
    n = n + 4294967296  -- 2^32
  end
  self:write32u(n)
end

-- Write string bytes
function Writer:writestr(str)
  for i = 1, #str do
    self:write_byte(string.byte(str, i))
  end
end

-- Write byte array
function Writer:writebytes(arr)
  for i = 1, #arr do
    self:write_byte(arr[i])
  end
end

-- Write IEEE 754 double (8 bytes, little-endian)
function Writer:write_double_little(value)
  -- Use string.pack if available (Lua 5.3+)
  if string.pack then
    local packed = string.pack("<d", value)
    self:writestr(packed)
  else
    -- Fallback: manual IEEE 754 encoding
    local bytes = self:encode_ieee754(value, false)
    self:writebytes(bytes)
  end
end

-- Write IEEE 754 double (8 bytes, big-endian)
function Writer:write_double_big(value)
  -- Use string.pack if available (Lua 5.3+)
  if string.pack then
    local packed = string.pack(">d", value)
    self:writestr(packed)
  else
    -- Fallback: manual IEEE 754 encoding
    local bytes = self:encode_ieee754(value, true)
    self:writebytes(bytes)
  end
end

-- Encode IEEE 754 double to byte array (fallback for Lua 5.1/5.2)
function Writer:encode_ieee754(value, big_endian)
  local sign = 0
  if value < 0 then
    sign = 1
    value = -value
  end

  local bytes = {}

  -- Handle special cases
  if value == 0 then
    for i = 1, 8 do bytes[i] = 0 end
    if sign == 1 then bytes[big_endian and 1 or 8] = 128 end
    return bytes
  elseif value ~= value then  -- NaN
    for i = 1, 8 do bytes[i] = 255 end
    return bytes
  elseif value == math.huge then
    for i = 1, 8 do bytes[i] = 0 end
    if big_endian then
      bytes[1] = sign == 1 and 255 or 127
      bytes[2] = 240
    else
      bytes[8] = sign == 1 and 255 or 127
      bytes[7] = 240
    end
    return bytes
  end

  -- Normalize and extract exponent
  local exponent = 0
  while value >= 2 do
    value = value / 2
    exponent = exponent + 1
  end
  while value < 1 do
    value = value * 2
    exponent = exponent - 1
  end

  -- Bias exponent
  exponent = exponent + 1023
  if exponent <= 0 then
    -- Denormalized
    exponent = 0
    value = value / (2^(-1022))
  else
    -- Normalized: remove implicit 1
    value = value - 1
  end

  -- Extract mantissa (52 bits)
  local mantissa = math.floor(value * (2^52) + 0.5)

  -- Build bytes
  if big_endian then
    bytes[1] = (sign * 128) + math.floor(exponent / 16)
    bytes[2] = ((exponent % 16) * 16) + math.floor(mantissa / 281474976710656)
    mantissa = mantissa % 281474976710656
    bytes[3] = math.floor(mantissa / 1099511627776)
    mantissa = mantissa % 1099511627776
    bytes[4] = math.floor(mantissa / 4294967296)
    mantissa = mantissa % 4294967296
    bytes[5] = math.floor(mantissa / 16777216)
    mantissa = mantissa % 16777216
    bytes[6] = math.floor(mantissa / 65536)
    mantissa = mantissa % 65536
    bytes[7] = math.floor(mantissa / 256)
    bytes[8] = mantissa % 256
  else
    bytes[8] = (sign * 128) + math.floor(exponent / 16)
    bytes[7] = ((exponent % 16) * 16) + math.floor(mantissa / 281474976710656)
    mantissa = mantissa % 281474976710656
    bytes[6] = math.floor(mantissa / 1099511627776)
    mantissa = mantissa % 1099511627776
    bytes[5] = math.floor(mantissa / 4294967296)
    mantissa = mantissa % 4294967296
    bytes[4] = math.floor(mantissa / 16777216)
    mantissa = mantissa % 16777216
    bytes[3] = math.floor(mantissa / 65536)
    mantissa = mantissa % 65536
    bytes[2] = math.floor(mantissa / 256)
    bytes[1] = mantissa % 256
  end

  return bytes
end

-- Write at specific position (0-indexed)
function Writer:write_at(pos, size, value)
  local old_pos = self.pos
  self.pos = pos + 1

  if size == 8 then
    self:write8u(value)
  elseif size == 16 then
    self:write16u(value)
  elseif size == 32 then
    self:write32u(value)
  else
    error("Marshal: invalid write size " .. size)
  end

  self.pos = old_pos
end

-- Convert to string
function Writer:to_string()
  local chars = {}
  for i = 1, #self.bytes do
    table.insert(chars, string.char(self.bytes[i]))
  end
  return table.concat(chars)
end
