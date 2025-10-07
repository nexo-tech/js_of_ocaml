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

--- Integer Operations Module
--
-- This module provides 32-bit integer arithmetic with proper overflow semantics
-- matching OCaml's Int32 and native int behavior, along with bitwise operations.

local core = require("core")
local bit = require("compat_bit")
local M = {}

-- Constants
local MIN_INT32 = -0x80000000  -- -2^31
local MAX_INT32 = 0x7FFFFFFF   -- 2^31 - 1
local UINT32_MAX = 0xFFFFFFFF  -- 2^32 - 1

--- Convert a number to signed 32-bit integer with wrapping
-- @param n number The number to convert
-- @return number Signed 32-bit integer
local function to_int32(n)
  -- Ensure we're working with a number
  n = n + 0

  if core.has_bitops then
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

--- Add two 32-bit integers with overflow
-- @param a number First operand
-- @param b number Second operand
-- @return number Result with 32-bit overflow semantics
function M.add(a, b)
  return to_int32(a + b)
end

--- Subtract two 32-bit integers with overflow
-- @param a number First operand
-- @param b number Second operand
-- @return number Result with 32-bit overflow semantics
function M.sub(a, b)
  return to_int32(a - b)
end

--- Multiply two 32-bit integers with overflow
-- @param a number First operand
-- @param b number Second operand
-- @return number Result with 32-bit overflow semantics
function M.mul(a, b)
  return to_int32(a * b)
end

--- Divide two 32-bit integers (truncated toward zero)
-- @param a number Dividend
-- @param b number Divisor
-- @return number Quotient (truncated)
function M.div(a, b)
  if b == 0 then
    error("Division by zero")
  end
  -- OCaml division truncates toward zero
  local result = a / b
  return to_int32(result >= 0 and math.floor(result) or math.ceil(result))
end

--- Modulo operation for 32-bit integers
-- OCaml semantics: result has sign of dividend
-- @param a number Dividend
-- @param b number Divisor
-- @return number Remainder
function M.mod(a, b)
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

--- Negate a 32-bit integer
-- @param n number The number to negate
-- @return number Negated value
function M.neg(n)
  return to_int32(-n)
end

--- Bitwise AND
-- @param a number First operand
-- @param b number Second operand
-- @return number Result of a & b
function M.band(a, b)
  return to_int32(bit.band(a, b))
end

--- Bitwise OR
-- @param a number First operand
-- @param b number Second operand
-- @return number Result of a | b
function M.bor(a, b)
  return to_int32(bit.bor(a, b))
end

--- Bitwise XOR
-- @param a number First operand
-- @param b number Second operand
-- @return number Result of a ^ b
function M.bxor(a, b)
  return to_int32(bit.bxor(a, b))
end

--- Bitwise NOT
-- @param n number The operand
-- @return number Result of ~n
function M.bnot(n)
  return to_int32(bit.bnot(n))
end

--- Left shift
-- @param n number Value to shift
-- @param count number Number of bits to shift (0-31)
-- @return number Result of n << count
function M.lsl(n, count)
  count = count % 32
  return to_int32(bit.lshift(n, count))
end

--- Logical right shift (zero-fill)
-- @param n number Value to shift
-- @param count number Number of bits to shift (0-31)
-- @return number Result of n >>> count
function M.lsr(n, count)
  count = count % 32
  -- Convert to unsigned, shift, then back to signed
  local unsigned = n < 0 and (n + 0x100000000) or n
  return to_int32(bit.rshift(unsigned, count))
end

--- Arithmetic right shift (sign-extend)
-- @param n number Value to shift
-- @param count number Number of bits to shift (0-31)
-- @return number Result of n >> count
function M.asr(n, count)
  count = count % 32
  return to_int32(bit.arshift(n, count))
end

--- Compare two integers
-- @param a number First operand
-- @param b number Second operand
-- @return number -1 if a<b, 0 if a==b, 1 if a>b
function M.compare(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--- Unsigned compare
-- @param a number First operand (treated as unsigned)
-- @param b number Second operand (treated as unsigned)
-- @return number -1 if a<b, 0 if a==b, 1 if a>b (unsigned comparison)
function M.unsigned_compare(a, b)
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

--- Byte swap (reverse byte order)
-- @param n number 32-bit integer
-- @return number Integer with bytes reversed
function M.bswap(n)
  n = to_int32(n)
  -- Convert to unsigned for bit manipulation
  local unsigned = n < 0 and (n + 0x100000000) or n
  local b0 = bit.lshift(bit.band(unsigned, 0x000000FF), 24)
  local b1 = bit.lshift(bit.band(unsigned, 0x0000FF00), 8)
  local b2 = bit.rshift(bit.band(unsigned, 0x00FF0000), 8)
  local b3 = bit.rshift(bit.band(unsigned, 0xFF000000), 24)
  return to_int32(bit.bor(bit.bor(bit.bor(b0, b1), b2), b3))
end

--- Count leading zeros
-- @param n number 32-bit integer
-- @return number Number of leading zero bits
function M.clz(n)
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

--- Count trailing zeros
-- @param n number 32-bit integer
-- @return number Number of trailing zero bits
function M.ctz(n)
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

--- Population count (count set bits)
-- @param n number 32-bit integer
-- @return number Number of 1 bits
function M.popcnt(n)
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

-- Register primitives with the runtime
core.register("caml_int32_add", M.add)
core.register("caml_int32_sub", M.sub)
core.register("caml_int32_mul", M.mul)
core.register("caml_int32_div", M.div)
core.register("caml_int32_mod", M.mod)
core.register("caml_int32_neg", M.neg)
core.register("caml_int32_and", M.band)
core.register("caml_int32_or", M.bor)
core.register("caml_int32_xor", M.bxor)
core.register("caml_int32_shift_left", M.lsl)
core.register("caml_int32_shift_right", M.asr)
core.register("caml_int32_shift_right_unsigned", M.lsr)
core.register("caml_int32_bswap", M.bswap)

-- Register module
core.register_module("ints", M)

return M
