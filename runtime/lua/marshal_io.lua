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
  -- Write 64-bit IEEE 754 double little-endian
  -- Requires Lua 5.3+ string.pack
  if not string.pack then
    error("caml_marshal_write_double_little requires Lua 5.3+ (string.pack not available)")
  end

  -- Pack as little-endian double ("<d")
  local bytes = string.pack("<d", value)

  -- Write all 8 bytes
  for i = 1, 8 do
    buf.length = buf.length + 1
    buf.bytes[buf.length] = string.byte(bytes, i)
  end
end

--Provides: caml_marshal_read_double_little
function caml_marshal_read_double_little(str, offset)
  -- Read 64-bit IEEE 754 double little-endian
  -- Requires Lua 5.3+ string.unpack
  if not string.unpack then
    error("caml_marshal_read_double_little requires Lua 5.3+ (string.unpack not available)")
  end

  -- Extract 8 bytes starting at offset (0-indexed)
  local bytes = string.sub(str, offset + 1, offset + 8)

  -- Unpack as little-endian double ("<d")
  local value = string.unpack("<d", bytes)

  return value
end
