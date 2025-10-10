-- Lua_of_ocaml runtime support
-- Digest: MD5 cryptographic hashing (Task 10.3)
--
-- Implements OCaml Digest module for MD5 hashing of strings and channels.

local M = {}

-- MD5 constants
local INIT_A = 0x67452301
local INIT_B = 0xEFCDAB89
local INIT_C = 0x98BADCFE
local INIT_D = 0x10325476

-- Per-round shift amounts
local S11, S12, S13, S14 = 7, 12, 17, 22
local S21, S22, S23, S24 = 5, 9, 14, 20
local S31, S32, S33, S34 = 4, 11, 16, 23
local S41, S42, S43, S44 = 6, 10, 15, 21

-- Bitwise operations for Lua 5.3+
local band = function(a, b) return a & b end
local bor = function(a, b) return a | b end
local bxor = function(a, b) return a ~ b end
local bnot = function(a) return ~a end
local lshift = function(a, n) return (a << n) & 0xFFFFFFFF end
local rshift = function(a, n) return (a >> n) & 0xFFFFFFFF end

-- 32-bit addition with overflow
local function add32(a, b)
  return (a + b) & 0xFFFFFFFF
end

-- 32-bit left rotate
local function rotl32(x, n)
  return ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF
end

-- MD5 auxiliary functions
local function F(x, y, z)
  return bor(band(x, y), band(bnot(x), z))
end

local function G(x, y, z)
  return bor(band(x, z), band(y, bnot(z)))
end

local function H(x, y, z)
  return bxor(x, bxor(y, z))
end

local function I(x, y, z)
  return bxor(y, bor(x, bnot(z)))
end

-- Generic MD5 step
local function md5_step(func, a, b, c, d, x, s, ac)
  a = add32(a, add32(add32(func(b, c, d), x), ac))
  a = add32(rotl32(a, s), b)
  return a
end

-- MD5 transform block (64 bytes)
local function md5_transform(state, block)
  local a, b, c, d = state[1], state[2], state[3], state[4]

  -- Decode block into 16 32-bit words (little-endian)
  local x = {}
  for i = 0, 15 do
    local offset = i * 4 + 1
    x[i + 1] = bor(
      bor(block[offset], lshift(block[offset + 1], 8)),
      bor(lshift(block[offset + 2], 16), lshift(block[offset + 3], 24))
    )
  end

  -- Round 1
  a = md5_step(F, a, b, c, d, x[1], S11, 0xD76AA478)
  d = md5_step(F, d, a, b, c, x[2], S12, 0xE8C7B756)
  c = md5_step(F, c, d, a, b, x[3], S13, 0x242070DB)
  b = md5_step(F, b, c, d, a, x[4], S14, 0xC1BDCEEE)
  a = md5_step(F, a, b, c, d, x[5], S11, 0xF57C0FAF)
  d = md5_step(F, d, a, b, c, x[6], S12, 0x4787C62A)
  c = md5_step(F, c, d, a, b, x[7], S13, 0xA8304613)
  b = md5_step(F, b, c, d, a, x[8], S14, 0xFD469501)
  a = md5_step(F, a, b, c, d, x[9], S11, 0x698098D8)
  d = md5_step(F, d, a, b, c, x[10], S12, 0x8B44F7AF)
  c = md5_step(F, c, d, a, b, x[11], S13, 0xFFFF5BB1)
  b = md5_step(F, b, c, d, a, x[12], S14, 0x895CD7BE)
  a = md5_step(F, a, b, c, d, x[13], S11, 0x6B901122)
  d = md5_step(F, d, a, b, c, x[14], S12, 0xFD987193)
  c = md5_step(F, c, d, a, b, x[15], S13, 0xA679438E)
  b = md5_step(F, b, c, d, a, x[16], S14, 0x49B40821)

  -- Round 2
  a = md5_step(G, a, b, c, d, x[2], S21, 0xF61E2562)
  d = md5_step(G, d, a, b, c, x[7], S22, 0xC040B340)
  c = md5_step(G, c, d, a, b, x[12], S23, 0x265E5A51)
  b = md5_step(G, b, c, d, a, x[1], S24, 0xE9B6C7AA)
  a = md5_step(G, a, b, c, d, x[6], S21, 0xD62F105D)
  d = md5_step(G, d, a, b, c, x[11], S22, 0x02441453)
  c = md5_step(G, c, d, a, b, x[16], S23, 0xD8A1E681)
  b = md5_step(G, b, c, d, a, x[5], S24, 0xE7D3FBC8)
  a = md5_step(G, a, b, c, d, x[10], S21, 0x21E1CDE6)
  d = md5_step(G, d, a, b, c, x[15], S22, 0xC33707D6)
  c = md5_step(G, c, d, a, b, x[4], S23, 0xF4D50D87)
  b = md5_step(G, b, c, d, a, x[9], S24, 0x455A14ED)
  a = md5_step(G, a, b, c, d, x[14], S21, 0xA9E3E905)
  d = md5_step(G, d, a, b, c, x[3], S22, 0xFCEFA3F8)
  c = md5_step(G, c, d, a, b, x[8], S23, 0x676F02D9)
  b = md5_step(G, b, c, d, a, x[13], S24, 0x8D2A4C8A)

  -- Round 3
  a = md5_step(H, a, b, c, d, x[6], S31, 0xFFFA3942)
  d = md5_step(H, d, a, b, c, x[9], S32, 0x8771F681)
  c = md5_step(H, c, d, a, b, x[12], S33, 0x6D9D6122)
  b = md5_step(H, b, c, d, a, x[15], S34, 0xFDE5380C)
  a = md5_step(H, a, b, c, d, x[2], S31, 0xA4BEEA44)
  d = md5_step(H, d, a, b, c, x[5], S32, 0x4BDECFA9)
  c = md5_step(H, c, d, a, b, x[8], S33, 0xF6BB4B60)
  b = md5_step(H, b, c, d, a, x[11], S34, 0xBEBFBC70)
  a = md5_step(H, a, b, c, d, x[14], S31, 0x289B7EC6)
  d = md5_step(H, d, a, b, c, x[1], S32, 0xEAA127FA)
  c = md5_step(H, c, d, a, b, x[4], S33, 0xD4EF3085)
  b = md5_step(H, b, c, d, a, x[7], S34, 0x04881D05)
  a = md5_step(H, a, b, c, d, x[10], S31, 0xD9D4D039)
  d = md5_step(H, d, a, b, c, x[13], S32, 0xE6DB99E5)
  c = md5_step(H, c, d, a, b, x[16], S33, 0x1FA27CF8)
  b = md5_step(H, b, c, d, a, x[3], S34, 0xC4AC5665)

  -- Round 4
  a = md5_step(I, a, b, c, d, x[1], S41, 0xF4292244)
  d = md5_step(I, d, a, b, c, x[8], S42, 0x432AFF97)
  c = md5_step(I, c, d, a, b, x[15], S43, 0xAB9423A7)
  b = md5_step(I, b, c, d, a, x[6], S44, 0xFC93A039)
  a = md5_step(I, a, b, c, d, x[13], S41, 0x655B59C3)
  d = md5_step(I, d, a, b, c, x[4], S42, 0x8F0CCC92)
  c = md5_step(I, c, d, a, b, x[11], S43, 0xFFEFF47D)
  b = md5_step(I, b, c, d, a, x[2], S44, 0x85845DD1)
  a = md5_step(I, a, b, c, d, x[9], S41, 0x6FA87E4F)
  d = md5_step(I, d, a, b, c, x[16], S42, 0xFE2CE6E0)
  c = md5_step(I, c, d, a, b, x[7], S43, 0xA3014314)
  b = md5_step(I, b, c, d, a, x[14], S44, 0x4E0811A1)
  a = md5_step(I, a, b, c, d, x[5], S41, 0xF7537E82)
  d = md5_step(I, d, a, b, c, x[12], S42, 0xBD3AF235)
  c = md5_step(I, c, d, a, b, x[3], S43, 0x2AD7D2BB)
  b = md5_step(I, b, c, d, a, x[10], S44, 0xEB86D391)

  -- Add to state
  state[1] = add32(state[1], a)
  state[2] = add32(state[2], b)
  state[3] = add32(state[3], c)
  state[4] = add32(state[4], d)
end

-- Initialize MD5 context
local function md5_init()
  return {
    state = {INIT_A, INIT_B, INIT_C, INIT_D},
    count = 0,  -- Total bytes processed
    buffer = {}  -- Pending bytes (up to 63)
  }
end

-- Update MD5 context with data
local function md5_update(ctx, data)
  local data_len = #data
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
    md5_transform(ctx.state, ctx.buffer)
    ctx.buffer = {}
    pos = needed + 1
  end

  -- Process complete 64-byte blocks
  while pos + 63 <= data_len do
    local block = {}
    for i = 0, 63 do
      block[i + 1] = bytes[pos + i]
    end
    md5_transform(ctx.state, block)
    pos = pos + 64
  end

  -- Store remaining bytes in buffer
  while pos <= data_len do
    table.insert(ctx.buffer, bytes[pos])
    pos = pos + 1
  end
end

-- Finalize MD5 and produce digest
local function md5_final(ctx)
  -- Padding
  local buf_len = #ctx.buffer
  table.insert(ctx.buffer, 0x80)

  -- Pad to 56 bytes (leaving 8 for length)
  if buf_len >= 56 then
    -- Need to add another block
    while #ctx.buffer < 64 do
      table.insert(ctx.buffer, 0)
    end
    md5_transform(ctx.state, ctx.buffer)
    ctx.buffer = {}
  end

  -- Pad to 56 bytes
  while #ctx.buffer < 56 do
    table.insert(ctx.buffer, 0)
  end

  -- Append length in bits (little-endian 64-bit)
  local bit_len = ctx.count * 8
  for i = 0, 7 do
    local byte = (bit_len >> (i * 8)) & 0xFF
    table.insert(ctx.buffer, byte)
  end

  -- Final transform
  md5_transform(ctx.state, ctx.buffer)

  -- Produce digest (little-endian)
  local digest = {}
  for i = 1, 4 do
    local word = ctx.state[i]
    for j = 0, 3 do
      table.insert(digest, string.char((word >> (j * 8)) & 0xFF))
    end
  end

  return table.concat(digest)
end

-- Convert digest to hex string
local function digest_to_hex(digest)
  local hex = {}
  for i = 1, #digest do
    table.insert(hex, string.format("%02x", string.byte(digest, i)))
  end
  return table.concat(hex)
end

-- OCaml API: caml_md5_string
-- Hash a substring of a string
function M.caml_md5_string(str, offset, len)
  local ctx = md5_init()
  local substring = string.sub(str, offset + 1, offset + len)
  md5_update(ctx, substring)
  return md5_final(ctx)
end

-- OCaml API: caml_md5_chan
-- Hash data from a channel
-- toread: -1 for entire channel, or specific number of bytes
function M.caml_md5_chan(chanid, toread)
  local io_module = require("io")
  local ctx = md5_init()
  local buffer_size = 4096

  if toread < 0 then
    -- Read entire channel
    while true do
      local buf = {}
      local bytes_read = io_module.caml_ml_input(chanid, buf, 0, buffer_size)
      if bytes_read == 0 then
        break
      end
      -- Convert byte array to string
      local chars = {}
      for i = 1, bytes_read do
        table.insert(chars, string.char(buf[i]))
      end
      md5_update(ctx, table.concat(chars))
    end
  else
    -- Read specific number of bytes
    local remaining = toread
    while remaining > 0 do
      local to_read = math.min(remaining, buffer_size)
      local buf = {}
      local bytes_read = io_module.caml_ml_input(chanid, buf, 0, to_read)
      if bytes_read == 0 then
        error("End_of_file")
      end
      -- Convert byte array to string
      local chars = {}
      for i = 1, bytes_read do
        table.insert(chars, string.char(buf[i]))
      end
      md5_update(ctx, table.concat(chars))
      remaining = remaining - bytes_read
    end
  end

  return md5_final(ctx)
end

-- Export module
M.md5_init = md5_init
M.md5_update = md5_update
M.md5_final = md5_final
M.digest_to_hex = digest_to_hex

return M
