#!/usr/bin/env lua
-- Test suite for ints.lua integer operations module

local ints = require("ints")

local tests_passed = 0
local tests_failed = 0

-- Test helper
local function test(name, func)
  local success, err = pcall(func)
  if success then
    tests_passed = tests_passed + 1
    print("✓ " .. name)
  else
    tests_failed = tests_failed + 1
    print("✗ " .. name)
    print("  Error: " .. tostring(err))
  end
end

-- Test arithmetic operations
test("Addition without overflow", function()
  assert(ints.add(100, 200) == 300, "100 + 200 should be 300")
  assert(ints.add(0, 0) == 0, "0 + 0 should be 0")
  assert(ints.add(-50, 50) == 0, "-50 + 50 should be 0")
end)

test("Addition with overflow", function()
  -- Max + 1 should wrap to min
  assert(ints.add(0x7FFFFFFF, 1) == -0x80000000, "Max + 1 should wrap to min")
  -- Large positive overflow
  assert(ints.add(0x7FFFFFFF, 0x7FFFFFFF) == -2, "Max + Max should overflow")
end)

test("Subtraction without overflow", function()
  assert(ints.sub(300, 200) == 100, "300 - 200 should be 100")
  assert(ints.sub(0, 0) == 0, "0 - 0 should be 0")
  assert(ints.sub(50, -50) == 100, "50 - (-50) should be 100")
end)

test("Subtraction with overflow", function()
  -- Min - 1 should wrap to max
  assert(ints.sub(-0x80000000, 1) == 0x7FFFFFFF, "Min - 1 should wrap to max")
end)

test("Multiplication without overflow", function()
  assert(ints.mul(10, 20) == 200, "10 * 20 should be 200")
  assert(ints.mul(0, 100) == 0, "0 * 100 should be 0")
  assert(ints.mul(-5, 6) == -30, "-5 * 6 should be -30")
  assert(ints.mul(-4, -7) == 28, "-4 * -7 should be 28")
end)

test("Multiplication with overflow", function()
  -- Large multiplication should overflow
  assert(ints.mul(0x10000, 0x10000) == 0, "0x10000 * 0x10000 should overflow to 0")
  assert(ints.mul(0x7FFFFFFF, 2) == -2, "Max * 2 should overflow")
end)

test("Division", function()
  assert(ints.div(20, 3) == 6, "20 / 3 should be 6 (truncated)")
  assert(ints.div(100, 10) == 10, "100 / 10 should be 10")
  assert(ints.div(-20, 3) == -6, "-20 / 3 should be -6 (truncated toward zero)")
  assert(ints.div(20, -3) == -6, "20 / -3 should be -6")
  assert(ints.div(-20, -3) == 6, "-20 / -3 should be 6")
end)

test("Division by zero", function()
  local success = pcall(function()
    ints.div(10, 0)
  end)
  assert(not success, "Division by zero should raise error")
end)

test("Modulo", function()
  assert(ints.mod(20, 3) == 2, "20 % 3 should be 2")
  assert(ints.mod(100, 10) == 0, "100 % 10 should be 0")
  assert(ints.mod(-20, 3) == -2, "-20 % 3 should be -2")
  assert(ints.mod(20, -3) == 2, "20 % -3 should be 2")
end)

test("Modulo by zero", function()
  local success = pcall(function()
    ints.mod(10, 0)
  end)
  assert(not success, "Modulo by zero should raise error")
end)

test("Negation", function()
  assert(ints.neg(42) == -42, "neg(42) should be -42")
  assert(ints.neg(-42) == 42, "neg(-42) should be 42")
  assert(ints.neg(0) == 0, "neg(0) should be 0")
  -- Min value negation overflows
  assert(ints.neg(-0x80000000) == -0x80000000, "neg(min) should overflow to min")
end)

-- Test bitwise operations
test("Bitwise AND", function()
  assert(ints.band(0xFF, 0x0F) == 0x0F, "0xFF & 0x0F should be 0x0F")
  assert(ints.band(0xAAAA, 0x5555) == 0, "0xAAAA & 0x5555 should be 0")
  assert(ints.band(0xFFFF, 0xFFFF) == 0xFFFF, "0xFFFF & 0xFFFF should be 0xFFFF")
  assert(ints.band(-1, 0x0F) == 0x0F, "-1 & 0x0F should be 0x0F")
end)

test("Bitwise OR", function()
  assert(ints.bor(0xF0, 0x0F) == 0xFF, "0xF0 | 0x0F should be 0xFF")
  assert(ints.bor(0xAAAA, 0x5555) == 0xFFFF, "0xAAAA | 0x5555 should be 0xFFFF")
  assert(ints.bor(0, 0) == 0, "0 | 0 should be 0")
end)

test("Bitwise XOR", function()
  assert(ints.bxor(0xFF, 0x0F) == 0xF0, "0xFF ^ 0x0F should be 0xF0")
  assert(ints.bxor(0xAAAA, 0x5555) == 0xFFFF, "0xAAAA ^ 0x5555 should be 0xFFFF")
  assert(ints.bxor(0xFFFF, 0xFFFF) == 0, "0xFFFF ^ 0xFFFF should be 0")
end)

test("Bitwise NOT", function()
  assert(ints.bnot(0) == -1, "~0 should be -1")
  assert(ints.bnot(-1) == 0, "~(-1) should be 0")
  assert(ints.bnot(0x0F0F0F0F) == -0x0F0F0F10, "~0x0F0F0F0F should match")
end)

test("Left shift", function()
  assert(ints.lsl(1, 0) == 1, "1 << 0 should be 1")
  assert(ints.lsl(1, 8) == 256, "1 << 8 should be 256")
  assert(ints.lsl(5, 2) == 20, "5 << 2 should be 20")
  -- Overflow
  assert(ints.lsl(1, 31) == -0x80000000, "1 << 31 should be min int")
  -- Shift amount wraps mod 32
  assert(ints.lsl(1, 33) == 2, "1 << 33 should be same as 1 << 1")
end)

test("Logical right shift", function()
  assert(ints.lsr(256, 8) == 1, "256 >>> 8 should be 1")
  assert(ints.lsr(20, 2) == 5, "20 >>> 2 should be 5")
  -- Unsigned shift of negative number
  assert(ints.lsr(-1, 1) == 0x7FFFFFFF, "-1 >>> 1 should be 0x7FFFFFFF")
  assert(ints.lsr(-256, 8) == 0xFFFFFF, "-256 >>> 8 should be 0xFFFFFF")
end)

test("Arithmetic right shift", function()
  assert(ints.asr(256, 8) == 1, "256 >> 8 should be 1")
  assert(ints.asr(20, 2) == 5, "20 >> 2 should be 5")
  -- Sign-extending shift of negative number
  assert(ints.asr(-256, 8) == -1, "-256 >> 8 should be -1")
  assert(ints.asr(-1, 16) == -1, "-1 >> 16 should be -1")
end)

-- Test comparison operations
test("Compare", function()
  assert(ints.compare(10, 20) == -1, "10 < 20")
  assert(ints.compare(20, 10) == 1, "20 > 10")
  assert(ints.compare(15, 15) == 0, "15 == 15")
  assert(ints.compare(-10, 5) == -1, "-10 < 5")
end)

test("Unsigned compare", function()
  assert(ints.unsigned_compare(10, 20) == -1, "10 < 20 (unsigned)")
  assert(ints.unsigned_compare(20, 10) == 1, "20 > 10 (unsigned)")
  -- Negative numbers are larger when treated as unsigned
  assert(ints.unsigned_compare(-1, 1) == 1, "-1 > 1 (unsigned)")
  assert(ints.unsigned_compare(-10, -5) == -1, "-10 < -5 (unsigned)")
end)

-- Test special operations
test("Byte swap", function()
  assert(ints.bswap(0x12345678) == 0x78563412, "Byte swap should reverse bytes")
  -- 0x00FF00FF swapped is 0xFF00FF00 (signed: -16711936)
  local result = ints.bswap(0x00FF00FF)
  local expected = -16711936  -- 0xFF00FF00 as signed int32
  assert(result == expected, string.format("Byte swap test 2: got %d, expected %d", result, expected))
  assert(ints.bswap(0) == 0, "Byte swap of 0 is 0")
end)

test("Count leading zeros", function()
  assert(ints.clz(0) == 32, "clz(0) should be 32")
  assert(ints.clz(1) == 31, "clz(1) should be 31")
  assert(ints.clz(0x80000000) == 0, "clz(0x80000000) should be 0")
  assert(ints.clz(0xFF) == 24, "clz(0xFF) should be 24")
  assert(ints.clz(0x00010000) == 15, "clz(0x00010000) should be 15")
end)

test("Count trailing zeros", function()
  assert(ints.ctz(0) == 32, "ctz(0) should be 32")
  assert(ints.ctz(1) == 0, "ctz(1) should be 0")
  assert(ints.ctz(2) == 1, "ctz(2) should be 1")
  assert(ints.ctz(8) == 3, "ctz(8) should be 3")
  assert(ints.ctz(0x80000000) == 31, "ctz(0x80000000) should be 31")
end)

test("Population count", function()
  assert(ints.popcnt(0) == 0, "popcnt(0) should be 0")
  assert(ints.popcnt(1) == 1, "popcnt(1) should be 1")
  assert(ints.popcnt(7) == 3, "popcnt(7) should be 3")
  assert(ints.popcnt(0xFF) == 8, "popcnt(0xFF) should be 8")
  assert(ints.popcnt(-1) == 32, "popcnt(-1) should be 32")
end)

-- Test primitive registration
test("Primitives are registered", function()
  local core = require("core")
  assert(core.get_primitive("caml_int32_add") == ints.add, "caml_int32_add registered")
  assert(core.get_primitive("caml_int32_mul") == ints.mul, "caml_int32_mul registered")
  assert(core.get_primitive("caml_int32_div") == ints.div, "caml_int32_div registered")
end)

-- Test module registration
test("Module is registered", function()
  local core = require("core")
  local ints_mod = core.get_module("ints")
  assert(ints_mod == ints, "ints module should be registered")
end)

-- Print summary
print("\n" .. string.rep("=", 50))
print("Tests passed: " .. tests_passed)
print("Tests failed: " .. tests_failed)
print(string.rep("=", 50))

if tests_failed > 0 then
  os.exit(1)
else
  print("\nAll tests passed!")
  os.exit(0)
end
