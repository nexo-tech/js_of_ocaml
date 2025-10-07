-- Lua_of_ocaml runtime support
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

--- String and Bytes Operations Module
--
-- This module provides OCaml string and bytes operations for Lua.
-- In OCaml, strings are immutable and bytes are mutable sequences of bytes.
-- In Lua:
-- - Strings are represented as native Lua strings (immutable)
-- - Bytes are represented as tables with byte values (mutable)

local core = require("core")
local bit = require("compat_bit")
local M = {}

--- Create a new bytes object from a string
-- @param s string Lua string
-- @return table Mutable bytes object
function M.bytes_of_string(s)
  local len = #s
  local bytes = { length = len }
  for i = 1, len do
    bytes[i - 1] = string.byte(s, i)  -- 0-indexed
  end
  return bytes
end

--- Convert bytes object to string
-- @param b table Bytes object
-- @return string Lua string
function M.string_of_bytes(b)
  local len = b.length
  local chars = {}
  for i = 0, len - 1 do
    chars[i + 1] = string.char(b[i] or 0)
  end
  return table.concat(chars)
end

--- Create a new empty bytes of given length
-- @param len number Length in bytes
-- @param fill number Optional fill byte (default 0)
-- @return table Bytes object
function M.create(len, fill)
  fill = fill or 0
  local bytes = { length = len }
  for i = 0, len - 1 do
    bytes[i] = fill
  end
  return bytes
end

--- Get byte at index (unsafe, no bounds check)
-- @param b table|string Bytes or string
-- @param i number Index (0-based)
-- @return number Byte value (0-255)
function M.unsafe_get(b, i)
  if type(b) == "string" then
    return string.byte(b, i + 1)
  else
    return b[i] or 0
  end
end

--- Set byte at index (unsafe, no bounds check)
-- @param b table Bytes object
-- @param i number Index (0-based)
-- @param c number Byte value
function M.unsafe_set(b, i, c)
  if type(b) == "table" then
    b[i] = bit.band(c, 0xFF)  -- Mask to 0-255
  else
    error("Cannot set byte in immutable string")
  end
end

--- Get byte at index with bounds checking
-- @param b table|string Bytes or string
-- @param i number Index (0-based)
-- @return number Byte value
function M.get(b, i)
  local len = type(b) == "string" and #b or b.length
  if i < 0 or i >= len then
    error("index out of bounds")
  end
  return M.unsafe_get(b, i)
end

--- Set byte at index with bounds checking
-- @param b table Bytes object
-- @param i number Index (0-based)
-- @param c number Byte value
function M.set(b, i, c)
  if type(b) ~= "table" then
    error("Cannot set byte in immutable string")
  end
  if i < 0 or i >= b.length then
    error("index out of bounds")
  end
  M.unsafe_set(b, i, c)
end

--- Get length of bytes or string
-- @param s table|string Bytes or string
-- @return number Length
function M.length(s)
  if type(s) == "string" then
    return #s
  else
    return s.length
  end
end

--- Copy bytes
-- @param src table|string Source
-- @param src_off number Source offset (0-based)
-- @param dst table Destination bytes
-- @param dst_off number Destination offset (0-based)
-- @param len number Number of bytes to copy
function M.blit(src, src_off, dst, dst_off, len)
  if type(dst) ~= "table" then
    error("Destination must be mutable bytes")
  end

  for i = 0, len - 1 do
    dst[dst_off + i] = M.unsafe_get(src, src_off + i)
  end
end

--- Fill bytes with a value
-- @param b table Bytes object
-- @param off number Offset (0-based)
-- @param len number Length
-- @param c number Fill byte value
function M.fill(b, off, len, c)
  if type(b) ~= "table" then
    error("Cannot fill immutable string")
  end
  c = bit.band(c, 0xFF)
  for i = 0, len - 1 do
    b[off + i] = c
  end
end

--- Create a sub-bytes
-- @param b table|string Source bytes or string
-- @param off number Offset (0-based)
-- @param len number Length
-- @return table New bytes object
function M.sub(b, off, len)
  local result = M.create(len)
  for i = 0, len - 1 do
    result[i] = M.unsafe_get(b, off + i)
  end
  return result
end

--- Compare two byte sequences
-- @param s1 table|string First sequence
-- @param s2 table|string Second sequence
-- @return number -1, 0, or 1
function M.compare(s1, s2)
  local len1 = M.length(s1)
  local len2 = M.length(s2)
  local min_len = math.min(len1, len2)

  for i = 0, min_len - 1 do
    local b1 = M.unsafe_get(s1, i)
    local b2 = M.unsafe_get(s2, i)
    if b1 < b2 then
      return -1
    elseif b1 > b2 then
      return 1
    end
  end

  if len1 < len2 then
    return -1
  elseif len1 > len2 then
    return 1
  else
    return 0
  end
end

--- Check if two byte sequences are equal
-- @param s1 table|string First sequence
-- @param s2 table|string Second sequence
-- @return boolean True if equal
function M.equal(s1, s2)
  return M.compare(s1, s2) == 0
end

--- Concatenate byte sequences
-- @param sep table|string Separator
-- @param list table List of byte sequences
-- @return table Concatenated bytes
function M.concat(sep, list)
  if #list == 0 then
    return M.create(0)
  end

  local sep_len = M.length(sep)
  local total_len = 0

  -- Calculate total length
  for i, item in ipairs(list) do
    total_len = total_len + M.length(item)
    if i < #list then
      total_len = total_len + sep_len
    end
  end

  -- Build result
  local result = M.create(total_len)
  local pos = 0

  for i, item in ipairs(list) do
    local item_len = M.length(item)
    M.blit(item, 0, result, pos, item_len)
    pos = pos + item_len

    if i < #list then
      M.blit(sep, 0, result, pos, sep_len)
      pos = pos + sep_len
    end
  end

  return result
end

--- Convert bytes to uppercase
-- @param b table|string Input bytes or string
-- @return table Uppercase bytes
function M.uppercase(b)
  local len = M.length(b)
  local result = M.create(len)

  for i = 0, len - 1 do
    local c = M.unsafe_get(b, i)
    -- Convert a-z to A-Z
    if c >= 97 and c <= 122 then
      c = c - 32
    end
    result[i] = c
  end

  return result
end

--- Convert bytes to lowercase
-- @param b table|string Input bytes or string
-- @return table Lowercase bytes
function M.lowercase(b)
  local len = M.length(b)
  local result = M.create(len)

  for i = 0, len - 1 do
    local c = M.unsafe_get(b, i)
    -- Convert A-Z to a-z
    if c >= 65 and c <= 90 then
      c = c + 32
    end
    result[i] = c
  end

  return result
end

--- Check if byte sequence contains a substring
-- @param haystack table|string String to search in
-- @param needle table|string String to search for
-- @return number Index of first occurrence (0-based), or -1
function M.index(haystack, needle)
  local hay_len = M.length(haystack)
  local needle_len = M.length(needle)

  if needle_len == 0 then
    return 0
  end
  if needle_len > hay_len then
    return -1
  end

  for i = 0, hay_len - needle_len do
    local match = true
    for j = 0, needle_len - 1 do
      if M.unsafe_get(haystack, i + j) ~= M.unsafe_get(needle, j) then
        match = false
        break
      end
    end
    if match then
      return i
    end
  end

  return -1
end

--- Get 16-bit value (little-endian)
-- @param b table|string Bytes or string
-- @param i number Index (0-based)
-- @return number 16-bit value
function M.get16(b, i)
  local b1 = M.unsafe_get(b, i)
  local b2 = M.unsafe_get(b, i + 1)
  return bit.bor(b1, bit.lshift(b2, 8))
end

--- Get 32-bit value (little-endian)
-- @param b table|string Bytes or string
-- @param i number Index (0-based)
-- @return number 32-bit value
function M.get32(b, i)
  local b1 = M.unsafe_get(b, i)
  local b2 = M.unsafe_get(b, i + 1)
  local b3 = M.unsafe_get(b, i + 2)
  local b4 = M.unsafe_get(b, i + 3)
  return bit.bor(bit.bor(bit.bor(b1, bit.lshift(b2, 8)), bit.lshift(b3, 16)), bit.lshift(b4, 24))
end

--- Set 16-bit value (little-endian)
-- @param b table Bytes object
-- @param i number Index (0-based)
-- @param v number 16-bit value
function M.set16(b, i, v)
  M.unsafe_set(b, i, bit.band(v, 0xFF))
  M.unsafe_set(b, i + 1, bit.band(bit.rshift(v, 8), 0xFF))
end

--- Set 32-bit value (little-endian)
-- @param b table Bytes object
-- @param i number Index (0-based)
-- @param v number 32-bit value
function M.set32(b, i, v)
  M.unsafe_set(b, i, bit.band(v, 0xFF))
  M.unsafe_set(b, i + 1, bit.band(bit.rshift(v, 8), 0xFF))
  M.unsafe_set(b, i + 2, bit.band(bit.rshift(v, 16), 0xFF))
  M.unsafe_set(b, i + 3, bit.band(bit.rshift(v, 24), 0xFF))
end

-- Register primitives
core.register("caml_create_bytes", M.create)
core.register("caml_bytes_of_string", M.bytes_of_string)
core.register("caml_string_of_bytes", M.string_of_bytes)
core.register("caml_bytes_get", M.get)
core.register("caml_bytes_set", M.set)
core.register("caml_bytes_unsafe_get", M.unsafe_get)
core.register("caml_bytes_unsafe_set", M.unsafe_set)
core.register("caml_ml_bytes_length", M.length)
core.register("caml_ml_string_length", M.length)
core.register("caml_blit_bytes", M.blit)
core.register("caml_blit_string", M.blit)
core.register("caml_fill_bytes", M.fill)
core.register("caml_bytes_compare", M.compare)
core.register("caml_bytes_equal", M.equal)
core.register("caml_bytes_get16", M.get16)
core.register("caml_bytes_get32", M.get32)
core.register("caml_bytes_set16", M.set16)
core.register("caml_bytes_set32", M.set32)
core.register("caml_string_get", M.get)
core.register("caml_string_unsafe_get", M.unsafe_get)
core.register("caml_string_get16", M.get16)
core.register("caml_string_get32", M.get32)
core.register("caml_string_compare", M.compare)
core.register("caml_string_equal", M.equal)

-- Register module
core.register_module("mlBytes", M)

return M
