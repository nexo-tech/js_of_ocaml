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


--Provides: caml_int32_xor
--Requires: caml_bit_and
function caml_int32_xor(a, b)
  local result = 0
  local bit_val = 1
  local a_work = a < 0 and (a + 0x100000000) or a
  local b_work = b < 0 and (b + 0x100000000) or b

  while a_work > 0 or b_work > 0 do
    local a_bit = a_work % 2
    local b_bit = b_work % 2
    if a_bit ~= b_bit then
      result = result + bit_val
    end
    a_work = math.floor(a_work / 2)
    b_work = math.floor(b_work / 2)
    bit_val = bit_val * 2
  end

  local n = result % 0x100000000
  if n >= 0x80000000 then
    return n - 0x100000000
  else
    return n
  end
end

--Provides: caml_int32_not
function caml_int32_not(n)
  local unsigned = n < 0 and (n + 0x100000000) or n
  local result = 0
  local bit_val = 1

  for i = 0, 31 do
    if unsigned % 2 == 0 then
      result = result + bit_val
    end
    unsigned = math.floor(unsigned / 2)
    bit_val = bit_val * 2
  end

  if result >= 0x80000000 then
    return result - 0x100000000
  else
    return result
  end
end

--Provides: caml_to_int32
function caml_to_int32(n)
  n = math.floor(n + 0)
  n = n % 0x100000000
  if n < 0 then
    n = n + 0x100000000
  end
  if n >= 0x80000000 then
    return n - 0x100000000
  else
    return n
  end
end

--Provides: caml_int32_add
--Requires: caml_to_int32
function caml_int32_add(a, b)
  return caml_to_int32(a + b)
end

--Provides: caml_int32_sub
--Requires: caml_to_int32
function caml_int32_sub(a, b)
  return caml_to_int32(a - b)
end

--Provides: caml_int32_mul
--Requires: caml_to_int32
function caml_int32_mul(a, b)
  return caml_to_int32(a * b)
end

--Provides: caml_int32_div
--Requires: caml_to_int32
function caml_int32_div(a, b)
  if b == 0 then
    error("Division by zero")
  end
  local result = a / b
  return caml_to_int32(result >= 0 and math.floor(result) or math.ceil(result))
end

--Provides: caml_int32_mod
--Requires: caml_to_int32
function caml_int32_mod(a, b)
  if b == 0 then
    error("Division by zero")
  end
  local r = a % b
  if (a < 0) ~= (b < 0) and r ~= 0 then
    r = r - b
  end
  return caml_to_int32(r)
end

--Provides: caml_int32_neg
--Requires: caml_to_int32
function caml_int32_neg(n)
  return caml_to_int32(-n)
end

--Provides: caml_int32_and
--Requires: caml_to_int32, caml_bit_and
function caml_int32_and(a, b)
  local ua = a < 0 and (a + 0x100000000) or a
  local ub = b < 0 and (b + 0x100000000) or b
  return caml_to_int32(caml_bit_and(ua, ub))
end

--Provides: caml_int32_or
--Requires: caml_to_int32, caml_bit_or
function caml_int32_or(a, b)
  local ua = a < 0 and (a + 0x100000000) or a
  local ub = b < 0 and (b + 0x100000000) or b
  return caml_to_int32(caml_bit_or(ua, ub))
end

--Provides: caml_int32_shift_left
--Requires: caml_to_int32, caml_bit_lshift
function caml_int32_shift_left(n, count)
  count = count % 32
  local unsigned = n < 0 and (n + 0x100000000) or n
  return caml_to_int32(caml_bit_lshift(unsigned, count))
end

--Provides: caml_int32_shift_right_unsigned
--Requires: caml_to_int32, caml_bit_rshift
function caml_int32_shift_right_unsigned(n, count)
  count = count % 32
  local unsigned = n < 0 and (n + 0x100000000) or n
  return caml_to_int32(caml_bit_rshift(unsigned, count))
end

--Provides: caml_int32_shift_right
--Requires: caml_to_int32
function caml_int32_shift_right(n, count)
  count = count % 32
  if count == 0 then
    return n
  end

  local sign = n < 0 and 1 or 0
  local unsigned = n < 0 and (n + 0x100000000) or n

  local result = math.floor(unsigned / (2 ^ count))

  if sign == 1 then
    local sign_extend = 0xFFFFFFFF - math.floor((2 ^ (32 - count)) - 1)
    result = result + sign_extend
  end

  return caml_to_int32(result)
end

--Provides: caml_int32_compare
function caml_int32_compare(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--Provides: caml_int32_unsigned_compare
function caml_int32_unsigned_compare(a, b)
  local ua = a < 0 and (a + 0x100000000) or a
  local ub = b < 0 and (b + 0x100000000) or b

  if ua < ub then
    return -1
  elseif ua > ub then
    return 1
  else
    return 0
  end
end

--Provides: caml_int32_bswap
--Requires: caml_to_int32, caml_bit_and, caml_bit_lshift, caml_bit_rshift, caml_bit_or
function caml_int32_bswap(n)
  n = caml_to_int32(n)
  local unsigned = n < 0 and (n + 0x100000000) or n
  local b0 = caml_bit_lshift(caml_bit_and(unsigned, 0x000000FF), 24)
  local b1 = caml_bit_lshift(caml_bit_and(unsigned, 0x0000FF00), 8)
  local b2 = caml_bit_rshift(caml_bit_and(unsigned, 0x00FF0000), 8)
  local b3 = caml_bit_rshift(caml_bit_and(unsigned, 0xFF000000), 24)
  return caml_to_int32(caml_bit_or(caml_bit_or(caml_bit_or(b0, b1), b2), b3))
end

--Provides: caml_int32_clz
--Requires: caml_bit_and
function caml_int32_clz(n)
  if n == 0 then
    return 32
  end

  local unsigned = n < 0 and (n + 0x100000000) or n

  local count = 0
  local mask = 0x80000000

  for i = 0, 31 do
    if caml_bit_and(unsigned, mask) ~= 0 then
      break
    end
    count = count + 1
    mask = math.floor(mask / 2)
  end

  return count
end

--Provides: caml_int32_ctz
--Requires: caml_bit_and
function caml_int32_ctz(n)
  if n == 0 then
    return 32
  end

  local unsigned = n < 0 and (n + 0x100000000) or n
  local count = 0
  local mask = 1

  for i = 0, 31 do
    if caml_bit_and(unsigned, mask) ~= 0 then
      break
    end
    count = count + 1
    mask = mask * 2
  end

  return count
end

--Provides: caml_int32_popcnt
--Requires: caml_bit_and, caml_bit_rshift
function caml_int32_popcnt(n)
  local unsigned = n < 0 and (n + 0x100000000) or n

  local count = 0
  for i = 0, 31 do
    if caml_bit_and(unsigned, 1) ~= 0 then
      count = count + 1
    end
    unsigned = caml_bit_rshift(unsigned, 1)
  end

  return count
end
