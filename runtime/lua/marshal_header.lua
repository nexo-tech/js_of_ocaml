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

-- Marshal: Header read/write functions
-- Handles 20-byte OCaml marshal format headers

--Provides: caml_marshal_header_write
--Requires: caml_marshal_buffer_write32u
function caml_marshal_header_write(buf, data_len, num_objects, size_32, size_64)
  -- Write 20-byte marshal header
  -- Format:
  --   Magic number (4 bytes): 0x8495A6BE (MAGIC_SMALL) or 0x8495A6BF (MAGIC_BIG)
  --   Data length (4 bytes): length of marshaled data excluding header
  --   Number of objects (4 bytes): for sharing support
  --   Size 32-bit (4 bytes): size when read on 32-bit platform
  --   Size 64-bit (4 bytes): size when read on 64-bit platform

  -- Magic number: 0x8495A6BE for small (32-bit safe)
  caml_marshal_buffer_write32u(buf, 0x8495A6BE)  -- MAGIC_SMALL

  -- Data length (excluding header)
  caml_marshal_buffer_write32u(buf, data_len)

  -- Number of objects (for sharing)
  caml_marshal_buffer_write32u(buf, num_objects)

  -- Size on 32-bit platform
  caml_marshal_buffer_write32u(buf, size_32)

  -- Size on 64-bit platform
  caml_marshal_buffer_write32u(buf, size_64)
end

--Provides: caml_marshal_header_read
--Requires: caml_marshal_read32u
function caml_marshal_header_read(str, offset)
  -- Read and validate 20-byte marshal header
  -- Returns: {magic, data_len, num_objects, size_32, size_64} or nil on error

  -- Check minimum length
  local available = #str - offset
  if available < 20 then
    error(string.format("caml_marshal_header_read: data too short (need 20 bytes, got %d bytes)", available))
  end

  -- Read magic number (4 bytes)
  local magic = caml_marshal_read32u(str, offset)

  -- Validate magic number
  -- 0x8495A6BE = MAGIC_SMALL (32-bit safe)
  -- 0x8495A6BF = MAGIC_BIG (64-bit values)
  if magic ~= 0x8495A6BE and magic ~= 0x8495A6BF then
    error(string.format("caml_marshal_header_read: invalid header magic 0x%08X", magic))
  end

  -- Read data length (4 bytes)
  local data_len = caml_marshal_read32u(str, offset + 4)

  -- Read number of objects (4 bytes)
  local num_objects = caml_marshal_read32u(str, offset + 8)

  -- Read size on 32-bit platform (4 bytes)
  local size_32 = caml_marshal_read32u(str, offset + 12)

  -- Read size on 64-bit platform (4 bytes)
  local size_64 = caml_marshal_read32u(str, offset + 16)

  return {
    magic = magic,
    data_len = data_len,
    num_objects = num_objects,
    size_32 = size_32,
    size_64 = size_64
  }
end

--Provides: caml_marshal_header_size
function caml_marshal_header_size()
  -- Return the size of the marshal header in bytes
  return 20
end
