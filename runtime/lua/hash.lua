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


--Provides: caml_hash_bit_xor
function caml_hash_bit_xor(a, b)
  a = a % 0x100000000
  b = b % 0x100000000
  local result = 0
  local bit_val = 1
  for i = 0, 31 do
    local a_bit = a % 2
    local b_bit = b % 2
    if a_bit ~= b_bit then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result % 0x100000000
end

--Provides: caml_hash_bit_lshift
function caml_hash_bit_lshift(a, n)
  a = a % 0x100000000
  n = n % 32
  local result = a * (2 ^ n)
  return math.floor(result % 0x100000000)
end

--Provides: caml_hash_bit_rshift
function caml_hash_bit_rshift(a, n)
  a = a % 0x100000000
  n = n % 32
  local result = a / (2 ^ n)
  return math.floor(result % 0x100000000)
end

--Provides: caml_hash_bit_and
function caml_hash_bit_and(a, b)
  a = a % 0x100000000
  b = b % 0x100000000
  local result = 0
  local bit_val = 1
  for i = 0, 31 do
    if a % 2 == 1 and b % 2 == 1 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result % 0x100000000
end

--Provides: caml_hash_bit_or
function caml_hash_bit_or(a, b)
  a = a % 0x100000000
  b = b % 0x100000000
  local result = 0
  local bit_val = 1
  for i = 0, 31 do
    if a % 2 == 1 or b % 2 == 1 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result % 0x100000000
end

--Provides: caml_hash_mul32
function caml_hash_mul32(a, b)
  a = a % 0x100000000
  b = b % 0x100000000
  local result = a * b
  return math.floor(result % 0x100000000)
end

--Provides: caml_hash_to_int32
function caml_hash_to_int32(n)
  n = math.floor(n % 0x100000000)
  if n >= 0x80000000 then
    return n - 0x100000000
  end
  return n
end

--Provides: caml_hash_mix_int
--Requires: caml_hash_mul32, caml_hash_bit_or, caml_hash_bit_lshift, caml_hash_bit_rshift, caml_hash_bit_xor, caml_hash_to_int32
function caml_hash_mix_int(h, d)
  d = caml_hash_mul32(d, 0xcc9e2d51)
  d = caml_hash_bit_or(caml_hash_bit_lshift(d, 15), caml_hash_bit_rshift(d, 17))  -- ROTL32(d, 15)
  d = caml_hash_mul32(d, 0x1b873593)
  h = caml_hash_bit_xor(h, d)
  h = caml_hash_bit_or(caml_hash_bit_lshift(h, 13), caml_hash_bit_rshift(h, 19))  -- ROTL32(h, 13)
  h = caml_hash_to_int32(caml_hash_to_int32(h + caml_hash_bit_lshift(h, 2)) + 0xe6546b64)
  return h
end

--Provides: caml_hash_mix_final
--Requires: caml_hash_bit_xor, caml_hash_bit_rshift, caml_hash_mul32
function caml_hash_mix_final(h)
  h = caml_hash_bit_xor(h, caml_hash_bit_rshift(h, 16))
  h = caml_hash_mul32(h, 0x85ebca6b)
  h = caml_hash_bit_xor(h, caml_hash_bit_rshift(h, 13))
  h = caml_hash_mul32(h, 0xc2b2ae35)
  h = caml_hash_bit_xor(h, caml_hash_bit_rshift(h, 16))
  return h
end

--Provides: caml_hash_mix_float
--Requires: caml_hash_bit_and, caml_hash_bit_rshift, caml_hash_bit_lshift, caml_hash_bit_or, caml_hash_mix_int, caml_hash_to_int32
function caml_hash_mix_float(hash, v)
  local lo, hi

  if v == 0 then
    if 1/v == -math.huge then
      lo, hi = 0, 0x80000000
    else
      lo, hi = 0, 0
    end
  elseif v ~= v then
    lo, hi = 0x00000001, 0x7ff00000
  elseif v == math.huge then
    lo, hi = 0, 0x7ff00000
  elseif v == -math.huge then
    lo, hi = 0, 0xfff00000
  else
    local sign = v < 0 and 1 or 0
    v = math.abs(v)

    local exp = math.floor(math.log(v) / math.log(2))
    local frac = v / (2 ^ exp) - 1

    exp = exp + 1023
    if exp <= 0 then
      exp = 0
      frac = v / (2 ^ -1022)
    elseif exp >= 0x7ff then
      exp = 0x7ff
      frac = 0
    end

    local frac_hi = math.floor(frac * (2 ^ 20))
    local frac_lo = math.floor((frac * (2 ^ 52)) % (2 ^ 32))

    hi = caml_hash_bit_or(caml_hash_bit_lshift(sign, 31), caml_hash_bit_or(caml_hash_bit_lshift(exp, 20), frac_hi))
    lo = frac_lo
  end

  local exp = caml_hash_bit_and(caml_hash_bit_rshift(hi, 20), 0x7ff)
  if exp == 0x7ff then
    local frac_hi = caml_hash_bit_and(hi, 0xfffff)
    if frac_hi ~= 0 or lo ~= 0 then
      hi = 0x7ff00000
      lo = 0x00000001
    end
  elseif hi == 0x80000000 and lo == 0 then
    hi = 0
  end

  hash = caml_hash_mix_int(hash, caml_hash_to_int32(lo))
  hash = caml_hash_mix_int(hash, caml_hash_to_int32(hi))
  return hash
end

--Provides: caml_hash_mix_string
--Requires: caml_hash_bit_or, caml_hash_bit_lshift, caml_hash_mix_int, caml_hash_to_int32, caml_hash_bit_xor
function caml_hash_mix_string(h, s)
  local len = #s
  local i = 1
  local w

  while i + 3 <= len do
    w = caml_hash_bit_or(
      caml_hash_bit_or(s[i], caml_hash_bit_lshift(s[i + 1], 8)),
      caml_hash_bit_or(caml_hash_bit_lshift(s[i + 2], 16), caml_hash_bit_lshift(s[i + 3], 24))
    )
    h = caml_hash_mix_int(h, caml_hash_to_int32(w))
    i = i + 4
  end

  w = 0
  local remaining = len - i + 1
  if remaining == 3 then
    w = caml_hash_bit_lshift(s[i + 2], 16)
    w = caml_hash_bit_or(w, caml_hash_bit_lshift(s[i + 1], 8))
    w = caml_hash_bit_or(w, s[i])
    h = caml_hash_mix_int(h, caml_hash_to_int32(w))
  elseif remaining == 2 then
    w = caml_hash_bit_or(caml_hash_bit_lshift(s[i + 1], 8), s[i])
    h = caml_hash_mix_int(h, caml_hash_to_int32(w))
  elseif remaining == 1 then
    w = s[i]
    h = caml_hash_mix_int(h, caml_hash_to_int32(w))
  end

  h = caml_hash_bit_xor(h, len)
  return h
end

--Provides: caml_hash
--Requires: caml_hash_mix_int, caml_hash_mix_float, caml_hash_mix_string, caml_hash_mix_final, caml_is_ocaml_string, caml_is_ocaml_block, caml_hash_bit_or, caml_hash_bit_lshift, caml_hash_to_int32, caml_hash_bit_and
function caml_hash(count, limit, seed, obj)
  local sz = limit
  if sz < 0 or sz > 256 then
    sz = 256
  end

  local num = count
  local h = seed
  local queue = {obj}
  local rd = 1
  local wr = 2

  while rd < wr and num > 0 do
    local v = queue[rd]
    rd = rd + 1

    if type(v) == "number" then
      if math.type(v) == "integer" or (v == math.floor(v) and v >= -0x40000000 and v < 0x40000000) then
        h = caml_hash_mix_int(h, caml_hash_to_int32(v + v + 1))
        num = num - 1
      else
        h = caml_hash_mix_float(h, v)
        num = num - 1
      end
    elseif type(v) == "string" then
      local bytes = {string.byte(v, 1, -1)}
      h = caml_hash_mix_string(h, bytes)
      num = num - 1
    elseif caml_is_ocaml_string(v) then
      h = caml_hash_mix_string(h, v)
      num = num - 1
    elseif caml_is_ocaml_block(v) then
      local tag_value = caml_hash_bit_or(caml_hash_bit_lshift(#v, 10), v.tag)
      h = caml_hash_mix_int(h, caml_hash_to_int32(tag_value))

      for i = 1, #v do
        if wr >= sz then
          break
        end
        queue[wr] = v[i]
        wr = wr + 1
      end
    elseif type(v) == "table" then
      h = caml_hash_mix_int(h, caml_hash_to_int32(#v))

      for i = 1, #v do
        if wr >= sz then
          break
        end
        queue[wr] = v[i]
        wr = wr + 1
      end
    end
  end

  h = caml_hash_mix_final(h)
  return caml_hash_bit_and(h, 0x3fffffff)
end

--Provides: caml_hash_default
--Requires: caml_hash
function caml_hash_default(obj)
  return caml_hash(10, 100, 0, obj)
end
