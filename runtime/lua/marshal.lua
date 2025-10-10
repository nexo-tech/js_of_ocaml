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

-- Public API (stubs to be implemented in later tasks)

--Provides: caml_marshal_to_string
function caml_marshal_to_string(value, flags)
  error("caml_marshal_to_string: not yet implemented")
end

--Provides: caml_marshal_to_bytes
--Requires: caml_marshal_to_string
function caml_marshal_to_bytes(value, flags)
  return caml_marshal_to_string(value, flags)
end

--Provides: caml_marshal_from_bytes
function caml_marshal_from_bytes(str, offset)
  error("caml_marshal_from_bytes: not yet implemented")
end

--Provides: caml_marshal_from_string
--Requires: caml_marshal_from_bytes
function caml_marshal_from_string(str, offset)
  return caml_marshal_from_bytes(str, offset)
end

--Provides: caml_marshal_data_size
function caml_marshal_data_size(str, offset)
  error("caml_marshal_data_size: not yet implemented")
end

--Provides: caml_marshal_total_size
function caml_marshal_total_size(str, offset)
  error("caml_marshal_total_size: not yet implemented")
end
