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

--- Integer Operations Primitives
-- matching OCaml's Int32 and native int behavior, along with bitwise operations.

local bit = require("compat_bit")

local MIN_INT32 = -0x80000000  -- -2^31
local MAX_INT32 = 0x7FFFFFFF   -- 2^31 - 1
local UINT32_MAX = 0xFFFFFFFF  -- 2^32 - 1

local lua_version = tonumber(_VERSION:match("%d+%.%d+"))
local has_bitops = lua_version >= 5.3

--- Convert a number to signed 32-bit integer with wrapping
-- @param n number The number to convert
-- @return number Signed 32-bit integer
local function to_int32(n)
  -- Ensure we're working with a number
  n = n + 0

  if has_bitops then
    -- Lua 5.3+ has native integers and bitwise ops
    -- Mask to 32 bits and convert to signed via arithmetic shift
    n = bit.band(math.floor(n), 0xFFFFFFFF)
    -- Sign extend from bit 31
    if n >= 0x80000000 then
      return n - 0x100000000
    else
      return n
    end
  else
    -- Fallback for Lua 5.1/5.2 (everything is a float)
    n = math.floor(n)
    -- Reduce to 32-bit range using modulo
    n = n % 0x100000000
    -- Handle negative wraparound
    if n < 0 then
      n = n + 0x100000000
    end
    -- Convert unsigned to signed
    if n >= 0x80000000 then
      return n - 0x100000000
    else
      return n
    end
  end
end

--Provides: caml_int32_add
function caml_int32_add(a, b)
  return to_int32(a + b)
end

--Provides: caml_int32_sub
function caml_int32_sub(a, b)
  return to_int32(a - b)
end

--Provides: caml_int32_mul
function caml_int32_mul(a, b)
  return to_int32(a * b)
end

--Provides: caml_int32_div
function caml_int32_div(a, b)
  if b == 0 then
    error("Division by zero")
  end
  -- OCaml division truncates toward zero
  local result = a / b
  return to_int32(result >= 0 and math.floor(result) or math.ceil(result))
end

--Provides: caml_int32_mod
function caml_int32_mod(a, b)
  if b == 0 then
    error("Division by zero")
  end
  -- OCaml mod has the sign of the dividend
  -- Lua's % has the sign of the divisor, so we need to adjust
  local r = a % b
  -- If signs differ and remainder is non-zero, adjust
  if (a < 0) ~= (b < 0) and r ~= 0 then
    r = r - b
  end
  return to_int32(r)
end

--Provides: caml_int32_neg
function caml_int32_neg(n)
  return to_int32(-n)
end

--Provides: caml_int32_and
function caml_int32_and(a, b)
  return to_int32(bit.band(a, b))
end

--Provides: caml_int32_or
function caml_int32_or(a, b)
  return to_int32(bit.bor(a, b))
end

--Provides: caml_int32_xor
function caml_int32_xor(a, b)
  return to_int32(bit.bxor(a, b))
end

--Provides: caml_int32_not
function caml_int32_not(n)
  return to_int32(bit.bnot(n))
end

--Provides: caml_int32_shift_left
function caml_int32_shift_left(n, count)
  count = count % 32
  return to_int32(bit.lshift(n, count))
end

--Provides: caml_int32_shift_right_unsigned
function caml_int32_shift_right_unsigned(n, count)
  count = count % 32
  -- Convert to unsigned, shift, then back to signed
  local unsigned = n < 0 and (n + 0x100000000) or n
  return to_int32(bit.rshift(unsigned, count))
end

--Provides: caml_int32_shift_right
function caml_int32_shift_right(n, count)
  count = count % 32
  return to_int32(bit.arshift(n, count))
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
  -- Convert to unsigned for comparison
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
function caml_int32_bswap(n)
  n = to_int32(n)
  -- Convert to unsigned for bit manipulation
  local unsigned = n < 0 and (n + 0x100000000) or n
  local b0 = bit.lshift(bit.band(unsigned, 0x000000FF), 24)
  local b1 = bit.lshift(bit.band(unsigned, 0x0000FF00), 8)
  local b2 = bit.rshift(bit.band(unsigned, 0x00FF0000), 8)
  local b3 = bit.rshift(bit.band(unsigned, 0xFF000000), 24)
  return to_int32(bit.bor(bit.bor(bit.bor(b0, b1), b2), b3))
end

--Provides: caml_int32_clz
function caml_int32_clz(n)
  if n == 0 then
    return 32
  end

  -- Convert to unsigned
  local unsigned = n < 0 and (n + 0x100000000) or n

  local count = 0
  local mask = 0x80000000

  for i = 0, 31 do
    if bit.band(unsigned, mask) ~= 0 then
      break
    end
    count = count + 1
    mask = math.floor(mask / 2)
  end

  return count
end

--Provides: caml_int32_ctz
function caml_int32_ctz(n)
  if n == 0 then
    return 32
  end

  local count = 0
  local mask = 1

  for i = 0, 31 do
    if bit.band(n, mask) ~= 0 then
      break
    end
    count = count + 1
    mask = mask * 2
  end

  return count
end

--Provides: caml_int32_popcnt
function caml_int32_popcnt(n)
  -- Convert to unsigned
  local unsigned = n < 0 and (n + 0x100000000) or n

  local count = 0
  for i = 0, 31 do
    if bit.band(unsigned, 1) ~= 0 then
      count = count + 1
    end
    unsigned = bit.rshift(unsigned, 1)
  end

  return count
end
