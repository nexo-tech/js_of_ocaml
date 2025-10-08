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

-- Polymorphic hashing implementation
-- Based on MurmurHash3 mixing functions
-- Compatible with OCaml's polymorphic hash

local M = {}

-- Bit manipulation helpers for 32-bit operations
local function bit_and(a, b)
  return a & b
end

local function bit_or(a, b)
  return a | b
end

local function bit_xor(a, b)
  return a ~ b
end

local function bit_lshift(a, n)
  return (a << n) & 0xFFFFFFFF
end

local function bit_rshift(a, n)
  return (a >> n) & 0xFFFFFFFF
end

local function to_int32(n)
  -- Convert to signed 32-bit integer
  n = n & 0xFFFFFFFF
  if n >= 0x80000000 then
    return n - 0x100000000
  end
  return n
end

local function mul32(a, b)
  -- 32-bit multiplication
  local result = (a * b) & 0xFFFFFFFF
  return to_int32(result)
end

-- Mix a 32-bit integer into the hash
-- Uses MurmurHash3 mixing
function M.caml_hash_mix_int(h, d)
  d = mul32(d, 0xcc9e2d51)
  d = bit_or(bit_lshift(d, 15), bit_rshift(d, 17))  -- ROTL32(d, 15)
  d = mul32(d, 0x1b873593)
  h = bit_xor(h, d)
  h = bit_or(bit_lshift(h, 13), bit_rshift(h, 19))  -- ROTL32(h, 13)
  h = to_int32(bit_or(mul32(h + mul32(h, 4), 1), 0xe6546b64))
  return h
end

-- Final mixing step
function M.caml_hash_mix_final(h)
  h = bit_xor(h, bit_rshift(h, 16))
  h = mul32(h, 0x85ebca6b)
  h = bit_xor(h, bit_rshift(h, 13))
  h = mul32(h, 0xc2b2ae35)
  h = bit_xor(h, bit_rshift(h, 16))
  return h
end

-- Mix a float into the hash
function M.caml_hash_mix_float(hash, v)
  -- Convert float to byte representation
  local bytes = string.pack("d", v)

  -- Extract low and high 32-bit words
  local lo = string.unpack("<I4", bytes, 1)
  local hi = string.unpack("<I4", bytes, 5)

  -- Normalize NaNs: all NaNs hash to the same value
  local exp = bit_and(bit_rshift(hi, 20), 0x7ff)
  if exp == 0x7ff then
    local frac_hi = bit_and(hi, 0xfffff)
    if frac_hi ~= 0 or lo ~= 0 then
      -- This is a NaN
      hi = 0x7ff00000
      lo = 0x00000001
    end
  elseif hi == 0x80000000 and lo == 0 then
    -- Normalize -0.0 to +0.0
    hi = 0
  end

  hash = M.caml_hash_mix_int(hash, to_int32(lo))
  hash = M.caml_hash_mix_int(hash, to_int32(hi))
  return hash
end

-- Mix a string (OCaml byte array) into the hash
function M.caml_hash_mix_string(h, s)
  local len = #s
  local i = 1
  local w

  -- Process 4 bytes at a time
  while i + 3 <= len do
    w = bit_or(
      bit_or(s[i], bit_lshift(s[i + 1], 8)),
      bit_or(bit_lshift(s[i + 2], 16), bit_lshift(s[i + 3], 24))
    )
    h = M.caml_hash_mix_int(h, to_int32(w))
    i = i + 4
  end

  -- Process remaining bytes
  w = 0
  local remaining = len - i + 1
  if remaining == 3 then
    w = bit_lshift(s[i + 2], 16)
    w = bit_or(w, bit_lshift(s[i + 1], 8))
    w = bit_or(w, s[i])
    h = M.caml_hash_mix_int(h, to_int32(w))
  elseif remaining == 2 then
    w = bit_or(bit_lshift(s[i + 1], 8), s[i])
    h = M.caml_hash_mix_int(h, to_int32(w))
  elseif remaining == 1 then
    w = s[i]
    h = M.caml_hash_mix_int(h, to_int32(w))
  end

  h = bit_xor(h, len)
  return h
end

-- Check if a value is an OCaml string (byte array)
local function is_ocaml_string(v)
  if type(v) ~= "table" then
    return false
  end
  -- OCaml strings are tables with numeric indices
  -- Check if it has numeric keys only
  for k, val in pairs(v) do
    if type(k) ~= "number" or type(val) ~= "number" then
      return false
    end
  end
  return #v > 0
end

-- Check if a value is an OCaml block (tagged array)
local function is_ocaml_block(v)
  if type(v) ~= "table" then
    return false
  end
  -- OCaml blocks have a tag field
  return v.tag ~= nil
end

-- Polymorphic hash function
-- count: maximum number of meaningful nodes to process
-- limit: maximum queue size
-- seed: initial hash seed
-- obj: value to hash
function M.caml_hash(count, limit, seed, obj)
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
      -- Check if it's an integer or float
      if math.type(v) == "integer" or (v == math.floor(v) and v >= -0x40000000 and v < 0x40000000) then
        -- Integer: hash as (v + v + 1)
        h = M.caml_hash_mix_int(h, to_int32(v + v + 1))
        num = num - 1
      else
        -- Float
        h = M.caml_hash_mix_float(h, v)
        num = num - 1
      end
    elseif type(v) == "string" then
      -- Lua string
      local bytes = {string.byte(v, 1, -1)}
      h = M.caml_hash_mix_string(h, bytes)
      num = num - 1
    elseif is_ocaml_string(v) then
      -- OCaml string (byte array)
      h = M.caml_hash_mix_string(h, v)
      num = num - 1
    elseif is_ocaml_block(v) then
      -- OCaml block with tag
      local tag_value = bit_or(bit_lshift(#v, 10), v.tag)
      h = M.caml_hash_mix_int(h, to_int32(tag_value))

      -- Add block fields to queue (up to size limit)
      for i = 1, #v do
        if wr >= sz then
          break
        end
        queue[wr] = v[i]
        wr = wr + 1
      end
    elseif type(v) == "table" then
      -- Generic table - hash as array
      -- Mix in the table size
      h = M.caml_hash_mix_int(h, to_int32(#v))

      -- Add array elements to queue
      for i = 1, #v do
        if wr >= sz then
          break
        end
        queue[wr] = v[i]
        wr = wr + 1
      end
    end
  end

  h = M.caml_hash_mix_final(h)
  return bit_and(h, 0x3fffffff)
end

-- Convenience function: hash with default parameters
-- Equivalent to Hashtbl.hash in OCaml
function M.caml_hash_default(obj)
  return M.caml_hash(10, 100, 0, obj)
end

return M
