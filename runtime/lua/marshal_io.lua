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

-- Marshal: Binary I/O helper functions
-- Provides low-level binary read/write operations for marshal format

--Provides: caml_marshal_buffer_create
function caml_marshal_buffer_create()
  return {
    bytes = {},
    length = 0
  }
end

--Provides: caml_marshal_buffer_write8u
function caml_marshal_buffer_write8u(buf, byte)
  buf.length = buf.length + 1
  buf.bytes[buf.length] = byte
end

--Provides: caml_marshal_buffer_write16u
function caml_marshal_buffer_write16u(buf, value)
  -- Write 16-bit unsigned big-endian
  -- Big-endian: most significant byte first
  local hi = math.floor(value / 256) % 256  -- High byte
  local lo = value % 256                     -- Low byte

  buf.length = buf.length + 1
  buf.bytes[buf.length] = hi
  buf.length = buf.length + 1
  buf.bytes[buf.length] = lo
end

--Provides: caml_marshal_buffer_write32u
function caml_marshal_buffer_write32u(buf, value)
  -- Write 32-bit unsigned big-endian
  -- Big-endian: most significant byte first
  local b3 = math.floor(value / 16777216) % 256  -- Byte 3 (highest)
  local b2 = math.floor(value / 65536) % 256     -- Byte 2
  local b1 = math.floor(value / 256) % 256       -- Byte 1
  local b0 = value % 256                          -- Byte 0 (lowest)

  buf.length = buf.length + 1
  buf.bytes[buf.length] = b3
  buf.length = buf.length + 1
  buf.bytes[buf.length] = b2
  buf.length = buf.length + 1
  buf.bytes[buf.length] = b1
  buf.length = buf.length + 1
  buf.bytes[buf.length] = b0
end

--Provides: caml_marshal_buffer_write_bytes
function caml_marshal_buffer_write_bytes(buf, str)
  for i = 1, #str do
    buf.length = buf.length + 1
    buf.bytes[buf.length] = string.byte(str, i)
  end
end

--Provides: caml_marshal_buffer_to_string
function caml_marshal_buffer_to_string(buf)
  -- Convert byte array to string
  -- Use table.concat for efficiency with large buffers
  local chars = {}
  for i = 1, buf.length do
    chars[i] = string.char(buf.bytes[i])
  end
  return table.concat(chars)
end

--Provides: caml_marshal_read8u
function caml_marshal_read8u(str, offset)
  -- Read 8-bit unsigned from string at offset (0-indexed)
  -- Returns: byte value
  return string.byte(str, offset + 1)
end

--Provides: caml_marshal_read16u
function caml_marshal_read16u(str, offset)
  -- Read 16-bit unsigned big-endian from string at offset (0-indexed)
  -- Returns: 16-bit value
  local hi = string.byte(str, offset + 1)      -- High byte
  local lo = string.byte(str, offset + 2)      -- Low byte

  -- Combine bytes: hi * 256 + lo
  return hi * 256 + lo
end

--Provides: caml_marshal_read32u
function caml_marshal_read32u(str, offset)
  -- Read 32-bit unsigned big-endian from string at offset (0-indexed)
  -- Returns: 32-bit value
  local b3 = string.byte(str, offset + 1)  -- Byte 3 (highest)
  local b2 = string.byte(str, offset + 2)  -- Byte 2
  local b1 = string.byte(str, offset + 3)  -- Byte 1
  local b0 = string.byte(str, offset + 4)  -- Byte 0 (lowest)

  -- Combine bytes: b3 * 2^24 + b2 * 2^16 + b1 * 2^8 + b0
  return b3 * 16777216 + b2 * 65536 + b1 * 256 + b0
end

--Provides: caml_marshal_read16s
function caml_marshal_read16s(str, offset)
  -- Read 16-bit signed big-endian from string at offset (0-indexed)
  -- Returns: signed 16-bit value
  local value = caml_marshal_read16u(str, offset)

  -- Convert unsigned to signed: if >= 2^15, subtract 2^16
  if value >= 32768 then  -- 2^15
    value = value - 65536  -- 2^16
  end

  return value
end

--Provides: caml_marshal_read32s
function caml_marshal_read32s(str, offset)
  -- Read 32-bit signed big-endian from string at offset (0-indexed)
  -- Returns: signed 32-bit value
  local value = caml_marshal_read32u(str, offset)

  -- Convert unsigned to signed: if >= 2^31, subtract 2^32
  if value >= 2147483648 then  -- 2^31
    value = value - 4294967296  -- 2^32
  end

  return value
end

--Provides: caml_marshal_read_bytes
function caml_marshal_read_bytes(str, offset, len)
  -- Read len bytes from string at offset (0-indexed)
  -- Returns: substring
  return string.sub(str, offset + 1, offset + len)
end

--Provides: caml_marshal_write_double_little
function caml_marshal_write_double_little(buf, value)
  -- Write 64-bit IEEE 754 double little-endian (Lua 5.1 compatible)
  -- Manual implementation with fallback

  local bytes_to_write = {}

  -- Handle special cases first
  if value ~= value then
    -- NaN: exponent all 1s, mantissa non-zero
    -- Standard quiet NaN: 0x7FF8000000000000 (little-endian: 00 00 00 00 00 00 F8 7F)
    bytes_to_write = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF8, 0x7F}
  elseif value == math.huge then
    -- +Infinity: sign=0, exponent all 1s, mantissa=0
    -- 0x7FF0000000000000 (little-endian: 00 00 00 00 00 00 F0 7F)
    bytes_to_write = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x7F}
  elseif value == -math.huge then
    -- -Infinity: sign=1, exponent all 1s, mantissa=0
    -- 0xFFF0000000000000 (little-endian: 00 00 00 00 00 00 F0 FF)
    bytes_to_write = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0xFF}
  elseif value == 0 then
    -- +0.0
    bytes_to_write = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
  else
    -- Use string.pack if available (Lua 5.3+), otherwise use frexp decomposition
    if string.pack then
      local packed = string.pack("<d", value)
      for i = 1, 8 do
        bytes_to_write[i] = string.byte(packed, i)
      end
    else
      -- Fallback: Use math.frexp to decompose the number
      -- IEEE 754: sign (1 bit) | exponent (11 bits, biased by 1023) | mantissa (52 bits)
      local sign = 0
      if value < 0 then
        sign = 1
        value = -value
      end

      -- math.frexp returns mantissa in [0.5, 1) and exponent
      -- We need mantissa in [1, 2) for IEEE 754
      local mantissa, exp = math.frexp(value)
      mantissa = mantissa * 2  -- Convert [0.5, 1) to [1, 2)
      exp = exp - 1

      -- IEEE 754 exponent is biased by 1023
      local biased_exp = exp + 1023

      -- Mantissa in IEEE 754 is 52 bits, with implicit leading 1
      -- mantissa is in [1, 2), so we store (mantissa - 1) * 2^52
      mantissa = (mantissa - 1) * 4503599627370496  -- 2^52

      -- Extract 52-bit mantissa into bytes (little-endian)
      local m0 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m1 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m2 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m3 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m4 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m5 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m6 = mantissa % 16  -- Only 4 bits

      -- Combine exponent and top mantissa bits
      -- Byte 7 (index 7): low 4 bits of exponent + high 4 bits of mantissa (m6)
      -- Byte 8 (index 8): high 7 bits of exponent + sign bit
      local exp_low = biased_exp % 16  -- Low 4 bits of exponent
      local exp_high = math.floor(biased_exp / 16)  -- High 7 bits of exponent

      bytes_to_write[1] = m0
      bytes_to_write[2] = m1
      bytes_to_write[3] = m2
      bytes_to_write[4] = m3
      bytes_to_write[5] = m4
      bytes_to_write[6] = m5
      bytes_to_write[7] = m6 + exp_low * 16
      bytes_to_write[8] = exp_high + sign * 128
    end
  end

  -- Write all 8 bytes to buffer
  for i = 1, 8 do
    buf.length = buf.length + 1
    buf.bytes[buf.length] = bytes_to_write[i]
  end
end

--Provides: caml_marshal_read_double_little
function caml_marshal_read_double_little(str, offset)
  -- Read 64-bit IEEE 754 double little-endian (Lua 5.1 compatible)

  -- Use string.unpack if available (Lua 5.3+)
  if string.unpack then
    local bytes = string.sub(str, offset + 1, offset + 8)
    return string.unpack("<d", bytes)
  end

  -- Fallback: Manual IEEE 754 decoding for Lua 5.1
  -- Read 8 bytes
  local b1 = string.byte(str, offset + 1)
  local b2 = string.byte(str, offset + 2)
  local b3 = string.byte(str, offset + 3)
  local b4 = string.byte(str, offset + 4)
  local b5 = string.byte(str, offset + 5)
  local b6 = string.byte(str, offset + 6)
  local b7 = string.byte(str, offset + 7)
  local b8 = string.byte(str, offset + 8)

  -- Extract sign, exponent, mantissa from little-endian format
  -- Byte 8 (b8): sign (1 bit) + high 7 bits of exponent
  -- Byte 7 (b7): low 4 bits of exponent + high 4 bits of mantissa
  local sign = math.floor(b8 / 128)  -- Bit 63
  local exp_high = b8 % 128  -- Bits 56-62
  local exp_low = math.floor(b7 / 16)  -- Bits 52-55
  local biased_exp = exp_high * 16 + exp_low

  -- Mantissa: 52 bits across bytes 1-7
  local m6 = b7 % 16  -- Bits 48-51
  local mantissa = m6 * 281474976710656 + b6 * 1099511627776 + b5 * 4294967296 +
                   b4 * 16777216 + b3 * 65536 + b2 * 256 + b1

  -- Check for special cases
  if biased_exp == 0x7FF then
    -- Exponent all 1s: infinity or NaN
    if mantissa == 0 then
      return sign == 1 and -math.huge or math.huge
    else
      return 0/0  -- NaN
    end
  elseif biased_exp == 0 then
    -- Denormalized number or zero
    if mantissa == 0 then
      return 0.0  -- Positive or negative zero (treat as 0.0)
    else
      -- Denormalized: 2^(-1022) * (0 + mantissa/2^52)
      local frac = mantissa / 4503599627370496  -- 2^52
      local value = frac * math.pow(2, -1022)
      return sign == 1 and -value or value
    end
  end

  -- Normal number: (-1)^sign * 2^(exp-1023) * (1 + mantissa/2^52)
  local exp = biased_exp - 1023
  local frac = 1.0 + mantissa / 4503599627370496  -- 2^52
  local value = frac * math.pow(2, exp)

  return sign == 1 and -value or value
end
