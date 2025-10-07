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

--- Bitwise Operations Compatibility Layer
--
-- Provides a unified API for bitwise operations across all Lua versions:
-- - Lua 5.3+: Uses native bitwise operators
-- - Lua 5.2: Uses bit32 library
-- - LuaJIT: Uses bit library
-- - Lua 5.1: Uses arithmetic fallback

local M = {}

-- Detect Lua version and available bit libraries
local has_native_bitops = _VERSION >= "Lua 5.3"
local has_bit32 = bit32 ~= nil
local has_bit = bit ~= nil

if has_native_bitops then
  -- Lua 5.3+ with native bitwise operators
  -- Use load() to avoid syntax errors in Lua 5.1/5.2
  local load_fn = load or loadstring
  M.band = load_fn("return function(a, b) return a & b end")()
  M.bor = load_fn("return function(a, b) return a | b end")()
  M.bxor = load_fn("return function(a, b) return a ~ b end")()
  M.bnot = load_fn("return function(a) return ~a end")()
  M.lshift = load_fn("return function(a, n) return a << n end")()
  M.rshift = load_fn("return function(a, n) return a >> n end")()
  M.arshift = load_fn("return function(a, n) return a >> n end")() -- Arithmetic right shift

elseif has_bit32 then
  -- Lua 5.2 with bit32 library
  M.band = bit32.band
  M.bor = bit32.bor
  M.bxor = bit32.bxor
  M.bnot = bit32.bnot
  M.lshift = bit32.lshift
  M.rshift = bit32.rshift
  M.arshift = bit32.arshift

elseif has_bit then
  -- LuaJIT with bit library
  M.band = bit.band
  M.bor = bit.bor
  M.bxor = bit.bxor
  M.bnot = bit.bnot
  M.lshift = bit.lshift
  M.rshift = bit.rshift
  M.arshift = bit.arshift

else
  -- Lua 5.1 fallback using arithmetic operations
  -- These implementations work with 32-bit unsigned integers

  --- Bitwise AND
  M.band = function(a, b)
    local result = 0
    local bit = 1
    a = math.floor(a)
    b = math.floor(b)

    -- Handle negative numbers by converting to unsigned 32-bit
    if a < 0 then a = a + 0x100000000 end
    if b < 0 then b = b + 0x100000000 end

    while a > 0 and b > 0 do
      local a_bit = a % 2
      local b_bit = b % 2
      if a_bit == 1 and b_bit == 1 then
        result = result + bit
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit = bit * 2
    end
    return result
  end

  --- Bitwise OR
  M.bor = function(a, b)
    local result = 0
    local bit = 1
    a = math.floor(a)
    b = math.floor(b)

    if a < 0 then a = a + 0x100000000 end
    if b < 0 then b = b + 0x100000000 end

    while a > 0 or b > 0 do
      local a_bit = a % 2
      local b_bit = b % 2
      if a_bit == 1 or b_bit == 1 then
        result = result + bit
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit = bit * 2
    end
    return result
  end

  --- Bitwise XOR
  M.bxor = function(a, b)
    local result = 0
    local bit = 1
    a = math.floor(a)
    b = math.floor(b)

    if a < 0 then a = a + 0x100000000 end
    if b < 0 then b = b + 0x100000000 end

    while a > 0 or b > 0 do
      local a_bit = a % 2
      local b_bit = b % 2
      if a_bit ~= b_bit then
        result = result + bit
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit = bit * 2
    end
    return result
  end

  --- Bitwise NOT (32-bit)
  M.bnot = function(a)
    a = math.floor(a)
    if a < 0 then a = a + 0x100000000 end
    return 0xFFFFFFFF - a
  end

  --- Left shift
  M.lshift = function(a, n)
    a = math.floor(a)
    n = math.floor(n)
    if a < 0 then a = a + 0x100000000 end

    -- Clamp shift amount
    if n < 0 then return 0 end
    if n >= 32 then return 0 end

    local result = a * (2 ^ n)
    -- Mask to 32 bits
    return result % 0x100000000
  end

  --- Logical right shift (unsigned)
  M.rshift = function(a, n)
    a = math.floor(a)
    n = math.floor(n)
    if a < 0 then a = a + 0x100000000 end

    -- Clamp shift amount
    if n < 0 then return 0 end
    if n >= 32 then return 0 end

    return math.floor(a / (2 ^ n))
  end

  --- Arithmetic right shift (signed)
  M.arshift = function(a, n)
    a = math.floor(a)
    n = math.floor(n)

    -- Clamp shift amount
    if n < 0 then return a end
    if n >= 32 then
      -- Sign extend
      return a < 0 and -1 or 0
    end

    -- For negative numbers, need to preserve sign
    if a < 0 then
      -- Convert to unsigned, shift, then convert back
      local unsigned = a + 0x100000000
      local shifted = math.floor(unsigned / (2 ^ n))
      -- Fill in 1s from the left
      local fill = 0xFFFFFFFF - math.floor(0xFFFFFFFF / (2 ^ n))
      shifted = shifted + fill
      -- Convert back to signed if needed
      if shifted >= 0x80000000 then
        return shifted - 0x100000000
      end
      return shifted
    else
      return math.floor(a / (2 ^ n))
    end
  end
end

-- Export information about which implementation is being used
M.implementation = has_native_bitops and "native" or
                   has_bit32 and "bit32" or
                   has_bit and "luajit" or
                   "arithmetic"

return M
