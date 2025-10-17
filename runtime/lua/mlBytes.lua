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


--Provides: caml_bit_and
function caml_bit_and(a, b)
  local result = 0
  local bit_val = 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--Provides: caml_bit_or
function caml_bit_or(a, b)
  local result = 0
  local bit_val = 1
  while a > 0 or b > 0 do
    if a % 2 == 1 or b % 2 == 1 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--Provides: caml_bit_lshift
function caml_bit_lshift(a, n)
  return math.floor(a * (2 ^ n))
end

--Provides: caml_bit_rshift
function caml_bit_rshift(a, n)
  return math.floor(a / (2 ^ n))
end

--Provides: caml_bytes_of_string
function caml_bytes_of_string(s)
  local len = #s
  local bytes = { length = len }
  for i = 1, len do
    bytes[i - 1] = string.byte(s, i)
  end
  return bytes
end

--Provides: caml_string_of_bytes
function caml_string_of_bytes(b)
  local len = b.length
  local chars = {}
  for i = 0, len - 1 do
    chars[i + 1] = string.char(b[i] or 0)
  end
  return table.concat(chars)
end

--Provides: caml_create_bytes
function caml_create_bytes(len, fill)
  fill = fill or 0
  local bytes = { length = len }
  for i = 0, len - 1 do
    bytes[i] = fill
  end
  return bytes
end

--Provides: caml_bytes_unsafe_get
function caml_bytes_unsafe_get(b, i)
  if type(b) == "string" then
    return string.byte(b, i + 1)
  else
    return b[i] or 0
  end
end

--Provides: caml_string_unsafe_get
--Requires: caml_bytes_unsafe_get
function caml_string_unsafe_get(b, i)
  return caml_bytes_unsafe_get(b, i)
end

--Provides: caml_bytes_unsafe_set
--Requires: caml_bit_and
function caml_bytes_unsafe_set(b, i, c)
  if type(b) == "table" then
    b[i] = caml_bit_and(c, 0xFF)
  else
    error("Cannot set byte in immutable string")
  end
end

--Provides: caml_bytes_get
--Requires: caml_bytes_unsafe_get, caml_ml_bytes_length
function caml_bytes_get(b, i)
  local len = caml_ml_bytes_length(b)
  if i < 0 or i >= len then
    error("index out of bounds")
  end
  return caml_bytes_unsafe_get(b, i)
end

--Provides: caml_string_get
--Requires: caml_bytes_get
function caml_string_get(b, i)
  return caml_bytes_get(b, i)
end

--Provides: caml_bytes_set
--Requires: caml_bytes_unsafe_set
function caml_bytes_set(b, i, c)
  if type(b) ~= "table" then
    error("Cannot set byte in immutable string")
  end
  if i < 0 or i >= b.length then
    error("index out of bounds")
  end
  caml_bytes_unsafe_set(b, i, c)
end

--Provides: caml_ml_bytes_length
function caml_ml_bytes_length(s)
  if type(s) == "string" then
    return #s
  else
    return s.length
  end
end

--Provides: caml_ml_string_length
function caml_ml_string_length(s)
  return caml_ml_bytes_length(s)
end

--Provides: caml_blit_bytes
--Requires: caml_bytes_unsafe_get
function caml_blit_bytes(src, src_off, dst, dst_off, len)
  if type(dst) ~= "table" then
    error("Destination must be mutable bytes")
  end

  for i = 0, len - 1 do
    dst[dst_off + i] = caml_bytes_unsafe_get(src, src_off + i)
  end
end

--Provides: caml_blit_string
function caml_blit_string(src, src_off, dst, dst_off, len)
  return caml_blit_bytes(src, src_off, dst, dst_off, len)
end

--Provides: caml_fill_bytes
--Requires: caml_bit_and
function caml_fill_bytes(b, off, len, c)
  if type(b) ~= "table" then
    error("Cannot fill immutable string")
  end
  c = caml_bit_and(c, 0xFF)
  for i = 0, len - 1 do
    b[off + i] = c
  end
end

--Provides: caml_bytes_sub
--Requires: caml_create_bytes, caml_bytes_unsafe_get
function caml_bytes_sub(b, off, len)
  local result = caml_create_bytes(len)
  for i = 0, len - 1 do
    result[i] = caml_bytes_unsafe_get(b, off + i)
  end
  return result
end

--Provides: caml_bytes_compare
--Requires: caml_ml_bytes_length, caml_bytes_unsafe_get
function caml_bytes_compare(s1, s2)
  local len1 = caml_ml_bytes_length(s1)
  local len2 = caml_ml_bytes_length(s2)
  local min_len = math.min(len1, len2)

  for i = 0, min_len - 1 do
    local b1 = caml_bytes_unsafe_get(s1, i)
    local b2 = caml_bytes_unsafe_get(s2, i)
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

--Provides: caml_string_compare
--Requires: caml_bytes_compare
function caml_string_compare(s1, s2)
  return caml_bytes_compare(s1, s2)
end

--Provides: caml_bytes_equal
--Requires: caml_bytes_compare
function caml_bytes_equal(s1, s2)
  return caml_bytes_compare(s1, s2) == 0
end

--Provides: caml_string_equal
--Requires: caml_bytes_equal
function caml_string_equal(s1, s2)
  return caml_bytes_equal(s1, s2)
end

--Provides: caml_bytes_concat
--Requires: caml_ml_bytes_length, caml_create_bytes, caml_blit_bytes
function caml_bytes_concat(sep, list)
  if #list == 0 then
    return caml_create_bytes(0)
  end

  local sep_len = caml_ml_bytes_length(sep)
  local total_len = 0

  for i, item in ipairs(list) do
    total_len = total_len + caml_ml_bytes_length(item)
    if i < #list then
      total_len = total_len + sep_len
    end
  end

  local result = caml_create_bytes(total_len)
  local pos = 0

  for i, item in ipairs(list) do
    local item_len = caml_ml_bytes_length(item)
    caml_blit_bytes(item, 0, result, pos, item_len)
    pos = pos + item_len

    if i < #list then
      caml_blit_bytes(sep, 0, result, pos, sep_len)
      pos = pos + sep_len
    end
  end

  return result
end

--Provides: caml_bytes_uppercase
--Requires: caml_ml_bytes_length, caml_create_bytes, caml_bytes_unsafe_get
function caml_bytes_uppercase(b)
  local len = caml_ml_bytes_length(b)
  local result = caml_create_bytes(len)

  for i = 0, len - 1 do
    local c = caml_bytes_unsafe_get(b, i)
    -- Only uppercase lowercase letters (a-z = 97-122)
    -- Must check both bounds to avoid uppercasing characters like '_' (95)
    if c >= 97 and c <= 122 then
      c = c - 32
    end
    result[i] = c
  end

  return result
end

--Provides: caml_bytes_lowercase
--Requires: caml_ml_bytes_length, caml_create_bytes, caml_bytes_unsafe_get
function caml_bytes_lowercase(b)
  local len = caml_ml_bytes_length(b)
  local result = caml_create_bytes(len)

  for i = 0, len - 1 do
    local c = caml_bytes_unsafe_get(b, i)
    if c >= 65 and c <= 90 then
      c = c + 32
    end
    result[i] = c
  end

  return result
end

--Provides: caml_bytes_index
--Requires: caml_ml_bytes_length, caml_bytes_unsafe_get
function caml_bytes_index(haystack, needle)
  local hay_len = caml_ml_bytes_length(haystack)
  local needle_len = caml_ml_bytes_length(needle)

  if needle_len == 0 then
    return 0
  end
  if needle_len > hay_len then
    return -1
  end

  for i = 0, hay_len - needle_len do
    local match = true
    for j = 0, needle_len - 1 do
      if caml_bytes_unsafe_get(haystack, i + j) ~= caml_bytes_unsafe_get(needle, j) then
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

--Provides: caml_bytes_get16
--Requires: caml_bytes_unsafe_get, caml_bit_or, caml_bit_lshift
function caml_bytes_get16(b, i)
  local b1 = caml_bytes_unsafe_get(b, i)
  local b2 = caml_bytes_unsafe_get(b, i + 1)
  return caml_bit_or(b1, caml_bit_lshift(b2, 8))
end

--Provides: caml_string_get16
--Requires: caml_bytes_get16
function caml_string_get16(b, i)
  return caml_bytes_get16(b, i)
end

--Provides: caml_bytes_get32
--Requires: caml_bytes_unsafe_get, caml_bit_or, caml_bit_lshift
function caml_bytes_get32(b, i)
  local b1 = caml_bytes_unsafe_get(b, i)
  local b2 = caml_bytes_unsafe_get(b, i + 1)
  local b3 = caml_bytes_unsafe_get(b, i + 2)
  local b4 = caml_bytes_unsafe_get(b, i + 3)
  return caml_bit_or(caml_bit_or(caml_bit_or(b1, caml_bit_lshift(b2, 8)), caml_bit_lshift(b3, 16)), caml_bit_lshift(b4, 24))
end

--Provides: caml_string_get32
--Requires: caml_bytes_get32
function caml_string_get32(b, i)
  return caml_bytes_get32(b, i)
end

--Provides: caml_bytes_set16
--Requires: caml_bytes_unsafe_set, caml_bit_and, caml_bit_rshift
function caml_bytes_set16(b, i, v)
  caml_bytes_unsafe_set(b, i, caml_bit_and(v, 0xFF))
  caml_bytes_unsafe_set(b, i + 1, caml_bit_and(caml_bit_rshift(v, 8), 0xFF))
end

--Provides: caml_bytes_set32
--Requires: caml_bytes_unsafe_set, caml_bit_and, caml_bit_rshift
function caml_bytes_set32(b, i, v)
  caml_bytes_unsafe_set(b, i, caml_bit_and(v, 0xFF))
  caml_bytes_unsafe_set(b, i + 1, caml_bit_and(caml_bit_rshift(v, 8), 0xFF))
  caml_bytes_unsafe_set(b, i + 2, caml_bit_and(caml_bit_rshift(v, 16), 0xFF))
  caml_bytes_unsafe_set(b, i + 3, caml_bit_and(caml_bit_rshift(v, 24), 0xFF))
end
