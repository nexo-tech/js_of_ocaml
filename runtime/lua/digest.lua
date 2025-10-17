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

-- Digest: MD5 cryptographic hashing primitives

-- Bitwise operations (Lua 5.1 compatible)

--Provides: caml_digest_bit_and
function caml_digest_bit_and(a, b)
  -- 32-bit AND using arithmetic (Lua 5.1 compatible)
  local result = 0
  local bit_val = 1
  for i = 1, 32 do
    if (a % 2 == 1) and (b % 2 == 1) then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--Provides: caml_digest_bit_or
function caml_digest_bit_or(a, b)
  -- 32-bit OR using arithmetic (Lua 5.1 compatible)
  local result = 0
  local bit_val = 1
  for i = 1, 32 do
    if (a % 2 == 1) or (b % 2 == 1) then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--Provides: caml_digest_bit_xor
function caml_digest_bit_xor(a, b)
  -- 32-bit XOR using arithmetic (Lua 5.1 compatible)
  local result = 0
  local bit_val = 1
  for i = 1, 32 do
    local a_bit = a % 2
    local b_bit = b % 2
    if a_bit ~= b_bit then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--Provides: caml_digest_bit_not
function caml_digest_bit_not(a)
  -- 32-bit NOT using arithmetic (Lua 5.1 compatible)
  -- NOT is: 0xFFFFFFFF - a
  local max_u32 = 4294967295
  return max_u32 - a
end

--Provides: caml_digest_bit_lshift
function caml_digest_bit_lshift(a, n)
  -- 32-bit left shift with masking (Lua 5.1 compatible)
  local result = a
  for i = 1, n do
    result = result * 2
  end
  -- Mask to 32 bits
  return result % 4294967296
end

--Provides: caml_digest_bit_rshift
function caml_digest_bit_rshift(a, n)
  -- 32-bit right shift (Lua 5.1 compatible)
  local result = a
  for i = 1, n do
    result = math.floor(result / 2)
  end
  return result
end

--Provides: caml_digest_add32
function caml_digest_add32(a, b)
  -- 32-bit addition with overflow (Lua 5.1 compatible)
  local result = a + b
  return result % 4294967296
end

--Provides: caml_digest_rotl32
--Requires: caml_digest_bit_or, caml_digest_bit_lshift, caml_digest_bit_rshift
function caml_digest_rotl32(x, n)
  -- 32-bit left rotate (Lua 5.1 compatible)
  local left = caml_digest_bit_lshift(x, n)
  local right = caml_digest_bit_rshift(x, 32 - n)
  return caml_digest_bit_or(left, right)
end

-- MD5 auxiliary functions

--Provides: caml_digest_md5_F
--Requires: caml_digest_bit_and, caml_digest_bit_or, caml_digest_bit_not
function caml_digest_md5_F(x, y, z)
  -- F(x, y, z) = (x & y) | (~x & z)
  return caml_digest_bit_or(
    caml_digest_bit_and(x, y),
    caml_digest_bit_and(caml_digest_bit_not(x), z)
  )
end

--Provides: caml_digest_md5_G
--Requires: caml_digest_bit_and, caml_digest_bit_or, caml_digest_bit_not
function caml_digest_md5_G(x, y, z)
  -- G(x, y, z) = (x & z) | (y & ~z)
  return caml_digest_bit_or(
    caml_digest_bit_and(x, z),
    caml_digest_bit_and(y, caml_digest_bit_not(z))
  )
end

--Provides: caml_digest_md5_H
--Requires: caml_digest_bit_xor
function caml_digest_md5_H(x, y, z)
  -- H(x, y, z) = x ^ y ^ z
  return caml_digest_bit_xor(x, caml_digest_bit_xor(y, z))
end

--Provides: caml_digest_md5_I
--Requires: caml_digest_bit_xor, caml_digest_bit_or, caml_digest_bit_not
function caml_digest_md5_I(x, y, z)
  -- I(x, y, z) = y ^ (x | ~z)
  return caml_digest_bit_xor(y, caml_digest_bit_or(x, caml_digest_bit_not(z)))
end

--Provides: caml_digest_md5_step
--Requires: caml_digest_add32, caml_digest_rotl32
function caml_digest_md5_step(func, a, b, c, d, x, s, ac)
  -- MD5 step: a = b + rotl32(a + func(b, c, d) + x + ac, s)
  a = caml_digest_add32(a, caml_digest_add32(caml_digest_add32(func(b, c, d), x), ac))
  a = caml_digest_add32(caml_digest_rotl32(a, s), b)
  return a
end

--Provides: caml_digest_md5_transform
--Requires: caml_digest_md5_step, caml_digest_md5_F, caml_digest_md5_G, caml_digest_md5_H, caml_digest_md5_I, caml_digest_bit_or, caml_digest_bit_lshift, caml_digest_add32
function caml_digest_md5_transform(state, block)
  -- Transform MD5 state with one 64-byte block
  local a = state[1]
  local b = state[2]
  local c = state[3]
  local d = state[4]

  -- Decode block into 16 32-bit words (little-endian)
  local x = {}
  for i = 0, 15 do
    local offset = i * 4 + 1
    x[i + 1] = caml_digest_bit_or(
      caml_digest_bit_or(block[offset], caml_digest_bit_lshift(block[offset + 1], 8)),
      caml_digest_bit_or(caml_digest_bit_lshift(block[offset + 2], 16), caml_digest_bit_lshift(block[offset + 3], 24))
    )
  end

  -- Round 1 (constants: S11=7, S12=12, S13=17, S14=22)
  a = caml_digest_md5_step(caml_digest_md5_F, a, b, c, d, x[1], 7, 0xD76AA478)
  d = caml_digest_md5_step(caml_digest_md5_F, d, a, b, c, x[2], 12, 0xE8C7B756)
  c = caml_digest_md5_step(caml_digest_md5_F, c, d, a, b, x[3], 17, 0x242070DB)
  b = caml_digest_md5_step(caml_digest_md5_F, b, c, d, a, x[4], 22, 0xC1BDCEEE)
  a = caml_digest_md5_step(caml_digest_md5_F, a, b, c, d, x[5], 7, 0xF57C0FAF)
  d = caml_digest_md5_step(caml_digest_md5_F, d, a, b, c, x[6], 12, 0x4787C62A)
  c = caml_digest_md5_step(caml_digest_md5_F, c, d, a, b, x[7], 17, 0xA8304613)
  b = caml_digest_md5_step(caml_digest_md5_F, b, c, d, a, x[8], 22, 0xFD469501)
  a = caml_digest_md5_step(caml_digest_md5_F, a, b, c, d, x[9], 7, 0x698098D8)
  d = caml_digest_md5_step(caml_digest_md5_F, d, a, b, c, x[10], 12, 0x8B44F7AF)
  c = caml_digest_md5_step(caml_digest_md5_F, c, d, a, b, x[11], 17, 0xFFFF5BB1)
  b = caml_digest_md5_step(caml_digest_md5_F, b, c, d, a, x[12], 22, 0x895CD7BE)
  a = caml_digest_md5_step(caml_digest_md5_F, a, b, c, d, x[13], 7, 0x6B901122)
  d = caml_digest_md5_step(caml_digest_md5_F, d, a, b, c, x[14], 12, 0xFD987193)
  c = caml_digest_md5_step(caml_digest_md5_F, c, d, a, b, x[15], 17, 0xA679438E)
  b = caml_digest_md5_step(caml_digest_md5_F, b, c, d, a, x[16], 22, 0x49B40821)

  -- Round 2 (constants: S21=5, S22=9, S23=14, S24=20)
  a = caml_digest_md5_step(caml_digest_md5_G, a, b, c, d, x[2], 5, 0xF61E2562)
  d = caml_digest_md5_step(caml_digest_md5_G, d, a, b, c, x[7], 9, 0xC040B340)
  c = caml_digest_md5_step(caml_digest_md5_G, c, d, a, b, x[12], 14, 0x265E5A51)
  b = caml_digest_md5_step(caml_digest_md5_G, b, c, d, a, x[1], 20, 0xE9B6C7AA)
  a = caml_digest_md5_step(caml_digest_md5_G, a, b, c, d, x[6], 5, 0xD62F105D)
  d = caml_digest_md5_step(caml_digest_md5_G, d, a, b, c, x[11], 9, 0x02441453)
  c = caml_digest_md5_step(caml_digest_md5_G, c, d, a, b, x[16], 14, 0xD8A1E681)
  b = caml_digest_md5_step(caml_digest_md5_G, b, c, d, a, x[5], 20, 0xE7D3FBC8)
  a = caml_digest_md5_step(caml_digest_md5_G, a, b, c, d, x[10], 5, 0x21E1CDE6)
  d = caml_digest_md5_step(caml_digest_md5_G, d, a, b, c, x[15], 9, 0xC33707D6)
  c = caml_digest_md5_step(caml_digest_md5_G, c, d, a, b, x[4], 14, 0xF4D50D87)
  b = caml_digest_md5_step(caml_digest_md5_G, b, c, d, a, x[9], 20, 0x455A14ED)
  a = caml_digest_md5_step(caml_digest_md5_G, a, b, c, d, x[14], 5, 0xA9E3E905)
  d = caml_digest_md5_step(caml_digest_md5_G, d, a, b, c, x[3], 9, 0xFCEFA3F8)
  c = caml_digest_md5_step(caml_digest_md5_G, c, d, a, b, x[8], 14, 0x676F02D9)
  b = caml_digest_md5_step(caml_digest_md5_G, b, c, d, a, x[13], 20, 0x8D2A4C8A)

  -- Round 3 (constants: S31=4, S32=11, S33=16, S34=23)
  a = caml_digest_md5_step(caml_digest_md5_H, a, b, c, d, x[6], 4, 0xFFFA3942)
  d = caml_digest_md5_step(caml_digest_md5_H, d, a, b, c, x[9], 11, 0x8771F681)
  c = caml_digest_md5_step(caml_digest_md5_H, c, d, a, b, x[12], 16, 0x6D9D6122)
  b = caml_digest_md5_step(caml_digest_md5_H, b, c, d, a, x[15], 23, 0xFDE5380C)
  a = caml_digest_md5_step(caml_digest_md5_H, a, b, c, d, x[2], 4, 0xA4BEEA44)
  d = caml_digest_md5_step(caml_digest_md5_H, d, a, b, c, x[5], 11, 0x4BDECFA9)
  c = caml_digest_md5_step(caml_digest_md5_H, c, d, a, b, x[8], 16, 0xF6BB4B60)
  b = caml_digest_md5_step(caml_digest_md5_H, b, c, d, a, x[11], 23, 0xBEBFBC70)
  a = caml_digest_md5_step(caml_digest_md5_H, a, b, c, d, x[14], 4, 0x289B7EC6)
  d = caml_digest_md5_step(caml_digest_md5_H, d, a, b, c, x[1], 11, 0xEAA127FA)
  c = caml_digest_md5_step(caml_digest_md5_H, c, d, a, b, x[4], 16, 0xD4EF3085)
  b = caml_digest_md5_step(caml_digest_md5_H, b, c, d, a, x[7], 23, 0x04881D05)
  a = caml_digest_md5_step(caml_digest_md5_H, a, b, c, d, x[10], 4, 0xD9D4D039)
  d = caml_digest_md5_step(caml_digest_md5_H, d, a, b, c, x[13], 11, 0xE6DB99E5)
  c = caml_digest_md5_step(caml_digest_md5_H, c, d, a, b, x[16], 16, 0x1FA27CF8)
  b = caml_digest_md5_step(caml_digest_md5_H, b, c, d, a, x[3], 23, 0xC4AC5665)

  -- Round 4 (constants: S41=6, S42=10, S43=15, S44=21)
  a = caml_digest_md5_step(caml_digest_md5_I, a, b, c, d, x[1], 6, 0xF4292244)
  d = caml_digest_md5_step(caml_digest_md5_I, d, a, b, c, x[8], 10, 0x432AFF97)
  c = caml_digest_md5_step(caml_digest_md5_I, c, d, a, b, x[15], 15, 0xAB9423A7)
  b = caml_digest_md5_step(caml_digest_md5_I, b, c, d, a, x[6], 21, 0xFC93A039)
  a = caml_digest_md5_step(caml_digest_md5_I, a, b, c, d, x[13], 6, 0x655B59C3)
  d = caml_digest_md5_step(caml_digest_md5_I, d, a, b, c, x[4], 10, 0x8F0CCC92)
  c = caml_digest_md5_step(caml_digest_md5_I, c, d, a, b, x[11], 15, 0xFFEFF47D)
  b = caml_digest_md5_step(caml_digest_md5_I, b, c, d, a, x[2], 21, 0x85845DD1)
  a = caml_digest_md5_step(caml_digest_md5_I, a, b, c, d, x[9], 6, 0x6FA87E4F)
  d = caml_digest_md5_step(caml_digest_md5_I, d, a, b, c, x[16], 10, 0xFE2CE6E0)
  c = caml_digest_md5_step(caml_digest_md5_I, c, d, a, b, x[7], 15, 0xA3014314)
  b = caml_digest_md5_step(caml_digest_md5_I, b, c, d, a, x[14], 21, 0x4E0811A1)
  a = caml_digest_md5_step(caml_digest_md5_I, a, b, c, d, x[5], 6, 0xF7537E82)
  d = caml_digest_md5_step(caml_digest_md5_I, d, a, b, c, x[12], 10, 0xBD3AF235)
  c = caml_digest_md5_step(caml_digest_md5_I, c, d, a, b, x[3], 15, 0x2AD7D2BB)
  b = caml_digest_md5_step(caml_digest_md5_I, b, c, d, a, x[10], 21, 0xEB86D391)

  -- Add to state
  state[1] = caml_digest_add32(state[1], a)
  state[2] = caml_digest_add32(state[2], b)
  state[3] = caml_digest_add32(state[3], c)
  state[4] = caml_digest_add32(state[4], d)
end

--Provides: caml_md5_init
function caml_md5_init()
  -- Initialize MD5 context
  -- MD5 initial state (constants: INIT_A, INIT_B, INIT_C, INIT_D)
  return {
    state = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476},
    count = 0,
    buffer = {}
  }
end

--Provides: caml_md5_update
--Requires: caml_digest_md5_transform
function caml_md5_update(ctx, data)
  -- Update MD5 context with data
  local data_len = string.len(data)
  ctx.count = ctx.count + data_len

  -- Convert string to byte array
  local bytes = {}
  for i = 1, data_len do
    bytes[i] = string.byte(data, i)
  end

  local pos = 1
  local buf_len = #ctx.buffer

  -- Fill buffer if partially filled
  if buf_len > 0 then
    local needed = 64 - buf_len
    if data_len < needed then
      -- Not enough to complete a block
      for i = 1, data_len do
        table.insert(ctx.buffer, bytes[i])
      end
      return
    end
    -- Complete the block
    for i = 1, needed do
      table.insert(ctx.buffer, bytes[i])
    end
    caml_digest_md5_transform(ctx.state, ctx.buffer)
    ctx.buffer = {}
    pos = needed + 1
  end

  -- Process complete 64-byte blocks
  while pos + 63 <= data_len do
    local block = {}
    for i = 0, 63 do
      block[i + 1] = bytes[pos + i]
    end
    caml_digest_md5_transform(ctx.state, block)
    pos = pos + 64
  end

  -- Store remaining bytes in buffer
  while pos <= data_len do
    table.insert(ctx.buffer, bytes[pos])
    pos = pos + 1
  end
end

--Provides: caml_md5_final
--Requires: caml_digest_md5_transform, caml_digest_bit_rshift
function caml_md5_final(ctx)
  -- Finalize MD5 and produce digest
  table.insert(ctx.buffer, 0x80)

  -- Pad to 56 bytes (leaving 8 for length)
  if #ctx.buffer > 56 then
    -- Need to add another block
    while #ctx.buffer < 64 do
      table.insert(ctx.buffer, 0)
    end
    caml_digest_md5_transform(ctx.state, ctx.buffer)
    ctx.buffer = {}
  end

  -- Pad to 56 bytes
  while #ctx.buffer < 56 do
    table.insert(ctx.buffer, 0)
  end

  -- Append length in bits (little-endian 64-bit)
  local bit_len = ctx.count * 8
  for i = 0, 7 do
    local byte_val = math.floor(caml_digest_bit_rshift(bit_len, i * 8)) % 256
    table.insert(ctx.buffer, byte_val)
  end

  -- Final transform
  caml_digest_md5_transform(ctx.state, ctx.buffer)

  -- Produce digest (little-endian)
  local digest = {}
  for i = 1, 4 do
    local word = ctx.state[i]
    for j = 0, 3 do
      local byte_val = math.floor(caml_digest_bit_rshift(word, j * 8)) % 256
      table.insert(digest, string.char(byte_val))
    end
  end

  return table.concat(digest)
end

--Provides: caml_digest_to_hex
function caml_digest_to_hex(digest)
  -- Convert digest to hex string
  local hex = {}
  for i = 1, string.len(digest) do
    table.insert(hex, string.format("%02x", string.byte(digest, i)))
  end
  return table.concat(hex)
end

--Provides: caml_md5_string
--Requires: caml_md5_init, caml_md5_update, caml_md5_final
function caml_md5_string(str, offset, len)
  -- Hash a substring of a string
  local ctx = caml_md5_init()
  local substring = string.sub(str, offset + 1, offset + len)
  caml_md5_update(ctx, substring)
  return caml_md5_final(ctx)
end

--Provides: caml_md5_chan
--Requires: caml_md5_init, caml_md5_update, caml_md5_final
function caml_md5_chan(chanid, toread)
  -- Hash data from a channel
  -- toread: -1 for entire channel, or specific number of bytes
  local ctx = caml_md5_init()
  local buffer_size = 4096

  if toread < 0 then
    -- Read entire channel
    while true do
      local buf = {}
      local bytes_read = caml_ml_input(chanid, buf, 0, buffer_size)
      if bytes_read == 0 then
        break
      end
      -- Convert byte array to string
      local chars = {}
      for i = 1, bytes_read do
        table.insert(chars, string.char(buf[i]))
      end
      caml_md5_update(ctx, table.concat(chars))
    end
  else
    -- Read specific number of bytes
    local remaining = toread
    while remaining > 0 do
      local to_read = math.min(remaining, buffer_size)
      local buf = {}
      local bytes_read = caml_ml_input(chanid, buf, 0, to_read)
      if bytes_read == 0 then
        error("End_of_file")
      end
      -- Convert byte array to string
      local chars = {}
      for i = 1, bytes_read do
        table.insert(chars, string.char(buf[i]))
      end
      caml_md5_update(ctx, table.concat(chars))
      remaining = remaining - bytes_read
    end
  end

  return caml_md5_final(ctx)
end
