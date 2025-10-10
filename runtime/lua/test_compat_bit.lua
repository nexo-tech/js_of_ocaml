#!/usr/bin/env lua
-- Tests for compat_bit module

local bit = require("compat_bit")

local test_count = 0
local pass_count = 0

local function test(name, fn)
  test_count = test_count + 1
  local success, err = pcall(fn)
  if success then
    pass_count = pass_count + 1
    print("✓ " .. name)
  else
    print("✗ " .. name)
    print("  Error: " .. tostring(err))
  end
end

-- Test band
test("band: basic operation", function()
  assert(bit.band(0xFF, 0x0F) == 0x0F)
  assert(bit.band(0xAAAA, 0x5555) == 0)
  assert(bit.band(0xFFFF, 0xFFFF) == 0xFFFF)
end)

-- Test bor
test("bor: basic operation", function()
  assert(bit.bor(0xF0, 0x0F) == 0xFF)
  assert(bit.bor(0xAAAA, 0x5555) == 0xFFFF)
  assert(bit.bor(0, 0) == 0)
end)

-- Test bxor
test("bxor: basic operation", function()
  assert(bit.bxor(0xFF, 0x0F) == 0xF0)
  assert(bit.bxor(0xAAAA, 0x5555) == 0xFFFF)
  assert(bit.bxor(0xFFFF, 0xFFFF) == 0)
end)

-- Test bnot
test("bnot: basic operation", function()
  local result = bit.bnot(0)
  assert(result == 0xFFFFFFFF or result == -1, "bnot(0) failed")
  assert(bit.bnot(0xFFFFFFFF) == 0 or bit.bnot(-1) == 0)
end)

-- Test lshift
test("lshift: basic operation", function()
  assert(bit.lshift(1, 0) == 1)
  assert(bit.lshift(1, 4) == 16)
  assert(bit.lshift(1, 8) == 256)
  assert(bit.lshift(0xFF, 8) == 0xFF00)
end)

-- Test rshift
test("rshift: basic operation", function()
  assert(bit.rshift(16, 4) == 1)
  assert(bit.rshift(256, 8) == 1)
  assert(bit.rshift(0xFF00, 8) == 0xFF)
  assert(bit.rshift(0, 4) == 0)
end)

-- Test arshift
test("arshift: arithmetic right shift", function()
  assert(bit.arshift(16, 4) == 1)
  assert(bit.arshift(256, 8) == 1)
  -- Negative numbers should sign-extend
  local result = bit.arshift(-16, 2)
  assert(result < 0, "arshift should preserve sign")
end)

-- Test complex operations
test("Complex: multiple operations", function()
  local a = 0x12345678
  local b = 0xABCDEF00
  local result = bit.bxor(bit.band(a, 0xFF00FF00), bit.bor(b, 0x00FF00FF))
  assert(type(result) == "number")
end)

-- Test edge cases
test("Edge cases: zero", function()
  assert(bit.band(0, 0xFFFFFFFF) == 0)
  assert(bit.bor(0, 0) == 0)
  assert(bit.bxor(0, 0) == 0)
  assert(bit.lshift(0, 10) == 0)
  assert(bit.rshift(0, 10) == 0)
end)

-- Test edge cases: all bits set
test("Edge cases: 0xFFFFFFFF", function()
  local val = 0xFFFFFFFF
  -- Note: LuaJIT's bit library returns signed values, so 0xFFFFFFFF becomes -1
  -- Both representations are semantically equivalent in 32-bit two's complement
  local result = bit.band(val, val)
  assert(result == val or result == -1, "band(0xFFFFFFFF, 0xFFFFFFFF) failed")

  result = bit.bor(val, 0)
  assert(result == val or result == -1, "bor(0xFFFFFFFF, 0) failed")
end)

-- Test shift overflow
test("Shift: overflow behavior", function()
  -- Shift by 32 is implementation-defined
  -- Some implementations return 0, some return the original value, some wrap
  local lshift_result = bit.lshift(1, 32)
  assert(lshift_result == 0 or lshift_result == 1, "lshift(1, 32) unexpected result")

  -- Right shift by 32 with 0xFFFFFFFF
  local rshift_result = bit.rshift(0xFFFFFFFF, 32)
  -- LuaJIT returns signed -1, others may return 0 or 0xFFFFFFFF
  assert(rshift_result == 0 or rshift_result == 0xFFFFFFFF or rshift_result == -1,
         "rshift(0xFFFFFFFF, 32) unexpected result")
end)

-- Test implementation detection
test("Implementation: detected correctly", function()
  assert(bit.implementation ~= nil, "implementation not set")
  assert(type(bit.implementation) == "string", "implementation should be string")
  local valid = bit.implementation == "native" or
                bit.implementation == "bit32" or
                bit.implementation == "luajit" or
                bit.implementation == "arithmetic"
  assert(valid, "unknown implementation: " .. bit.implementation)
  print("  Implementation: " .. bit.implementation)
end)

-- Print summary
print("")
print(string.rep("=", 50))
print(string.format("Tests passed: %d", pass_count))
print(string.format("Tests failed: %d", test_count - pass_count))
print(string.rep("=", 50))

if pass_count == test_count then
  print("\nAll tests passed!")
  os.exit(0)
else
  os.exit(1)
end
