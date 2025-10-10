#!/usr/bin/env lua
-- Test suite for ints.lua integer operations primitives

-- Load ints.lua directly (it defines global caml_* functions)
dofile("ints.lua")

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
  assert(caml_int32_add(100, 200) == 300, "100 + 200 should be 300")
  assert(caml_int32_add(0, 0) == 0, "0 + 0 should be 0")
  assert(caml_int32_add(-50, 50) == 0, "-50 + 50 should be 0")
end)

test("Addition with overflow", function()
  -- Max + 1 should wrap to min
  assert(caml_int32_add(0x7FFFFFFF, 1) == -0x80000000, "Max + 1 should wrap to min")
  -- Large positive overflow
  assert(caml_int32_add(0x7FFFFFFF, 0x7FFFFFFF) == -2, "Max + Max should overflow")
end)

test("Subtraction without overflow", function()
  assert(caml_int32_sub(300, 200) == 100, "300 - 200 should be 100")
  assert(caml_int32_sub(0, 0) == 0, "0 - 0 should be 0")
  assert(caml_int32_sub(50, -50) == 100, "50 - (-50) should be 100")
end)

test("Subtraction with overflow", function()
  -- Min - 1 should wrap to max
  assert(caml_int32_sub(-0x80000000, 1) == 0x7FFFFFFF, "Min - 1 should wrap to max")
end)

test("Multiplication without overflow", function()
  assert(caml_int32_mul(10, 20) == 200, "10 * 20 should be 200")
  assert(caml_int32_mul(0, 100) == 0, "0 * 100 should be 0")
  assert(caml_int32_mul(-5, 6) == -30, "-5 * 6 should be -30")
  assert(caml_int32_mul(-4, -7) == 28, "-4 * -7 should be 28")
end)

test("Multiplication with overflow", function()
  -- Large multiplication should overflow
  assert(caml_int32_mul(0x10000, 0x10000) == 0, "0x10000 * 0x10000 should overflow to 0")
  assert(caml_int32_mul(0x7FFFFFFF, 2) == -2, "Max * 2 should overflow")
end)

test("Division", function()
  assert(caml_int32_div(20, 3) == 6, "20 / 3 should be 6 (truncated)")
  assert(caml_int32_div(100, 10) == 10, "100 / 10 should be 10")
  assert(caml_int32_div(-20, 3) == -6, "-20 / 3 should be -6 (truncated toward zero)")
  assert(caml_int32_div(20, -3) == -6, "20 / -3 should be -6")
  assert(caml_int32_div(-20, -3) == 6, "-20 / -3 should be 6")
end)

test("Division by zero", function()
  local success = pcall(function()
    caml_int32_div(10, 0)
  end)
  assert(not success, "Division by zero should raise error")
end)

test("Modulo", function()
  assert(caml_int32_mod(20, 3) == 2, "20 % 3 should be 2")
  assert(caml_int32_mod(100, 10) == 0, "100 % 10 should be 0")
  assert(caml_int32_mod(-20, 3) == -2, "-20 % 3 should be -2")
  assert(caml_int32_mod(20, -3) == 2, "20 % -3 should be 2")
end)

test("Modulo by zero", function()
  local success = pcall(function()
    caml_int32_mod(10, 0)
  end)
  assert(not success, "Modulo by zero should raise error")
end)

test("Negation", function()
  assert(caml_int32_neg(42) == -42, "neg(42) should be -42")
  assert(caml_int32_neg(-42) == 42, "neg(-42) should be 42")
  assert(caml_int32_neg(0) == 0, "neg(0) should be 0")
  -- Min value negation overflows
  assert(caml_int32_neg(-0x80000000) == -0x80000000, "neg(min) should overflow to min")
end)

-- Test bitwise operations
test("Bitwise AND", function()
  assert(caml_int32_and(0xFF, 0x0F) == 0x0F, "0xFF & 0x0F should be 0x0F")
  assert(caml_int32_and(0xAAAA, 0x5555) == 0, "0xAAAA & 0x5555 should be 0")
  assert(caml_int32_and(0xFFFF, 0xFFFF) == 0xFFFF, "0xFFFF & 0xFFFF should be 0xFFFF")
  assert(caml_int32_and(-1, 0x0F) == 0x0F, "-1 & 0x0F should be 0x0F")
end)

test("Bitwise OR", function()
  assert(caml_int32_or(0xF0, 0x0F) == 0xFF, "0xF0 | 0x0F should be 0xFF")
  assert(caml_int32_or(0xAAAA, 0x5555) == 0xFFFF, "0xAAAA | 0x5555 should be 0xFFFF")
  assert(caml_int32_or(0, 0) == 0, "0 | 0 should be 0")
end)

test("Bitwise XOR", function()
  assert(caml_int32_xor(0xFF, 0x0F) == 0xF0, "0xFF ^ 0x0F should be 0xF0")
  assert(caml_int32_xor(0xAAAA, 0x5555) == 0xFFFF, "0xAAAA ^ 0x5555 should be 0xFFFF")
  assert(caml_int32_xor(0xFFFF, 0xFFFF) == 0, "0xFFFF ^ 0xFFFF should be 0")
end)

test("Bitwise NOT", function()
  assert(caml_int32_not(0) == -1, "~0 should be -1")
  assert(caml_int32_not(-1) == 0, "~(-1) should be 0")
  assert(caml_int32_not(0x0F0F0F0F) == -0x0F0F0F10, "~0x0F0F0F0F should match")
end)

test("Left shift", function()
  assert(caml_int32_shift_left(1, 0) == 1, "1 << 0 should be 1")
  assert(caml_int32_shift_left(1, 8) == 256, "1 << 8 should be 256")
  assert(caml_int32_shift_left(5, 2) == 20, "5 << 2 should be 20")
  -- Overflow
  assert(caml_int32_shift_left(1, 31) == -0x80000000, "1 << 31 should be min int")
  -- Shift amount wraps mod 32
  assert(caml_int32_shift_left(1, 33) == 2, "1 << 33 should be same as 1 << 1")
end)

test("Logical right shift", function()
  assert(caml_int32_shift_right_unsigned(256, 8) == 1, "256 >>> 8 should be 1")
  assert(caml_int32_shift_right_unsigned(20, 2) == 5, "20 >>> 2 should be 5")
  -- Unsigned shift of negative number
  assert(caml_int32_shift_right_unsigned(-1, 1) == 0x7FFFFFFF, "-1 >>> 1 should be 0x7FFFFFFF")
  assert(caml_int32_shift_right_unsigned(-256, 8) == 0xFFFFFF, "-256 >>> 8 should be 0xFFFFFF")
end)

test("Arithmetic right shift", function()
  assert(caml_int32_shift_right(256, 8) == 1, "256 >> 8 should be 1")
  assert(caml_int32_shift_right(20, 2) == 5, "20 >> 2 should be 5")
  -- Sign-extending shift of negative number
  assert(caml_int32_shift_right(-256, 8) == -1, "-256 >> 8 should be -1")
  assert(caml_int32_shift_right(-1, 16) == -1, "-1 >> 16 should be -1")
end)

-- Test comparison operations
test("Compare", function()
  assert(caml_int32_compare(10, 20) == -1, "10 < 20")
  assert(caml_int32_compare(20, 10) == 1, "20 > 10")
  assert(caml_int32_compare(15, 15) == 0, "15 == 15")
  assert(caml_int32_compare(-10, 5) == -1, "-10 < 5")
end)

test("Unsigned compare", function()
  assert(caml_int32_unsigned_compare(10, 20) == -1, "10 < 20 (unsigned)")
  assert(caml_int32_unsigned_compare(20, 10) == 1, "20 > 10 (unsigned)")
  -- Negative numbers are larger when treated as unsigned
  assert(caml_int32_unsigned_compare(-1, 1) == 1, "-1 > 1 (unsigned)")
  assert(caml_int32_unsigned_compare(-10, -5) == -1, "-10 < -5 (unsigned)")
end)

-- Test special operations
test("Byte swap", function()
  assert(caml_int32_bswap(0x12345678) == 0x78563412, "Byte swap should reverse bytes")
  -- 0x00FF00FF swapped is 0xFF00FF00 (signed: -16711936)
  local result = caml_int32_bswap(0x00FF00FF)
  local expected = -16711936  -- 0xFF00FF00 as signed int32
  assert(result == expected, string.format("Byte swap test 2: got %d, expected %d", result, expected))
  assert(caml_int32_bswap(0) == 0, "Byte swap of 0 is 0")
end)

test("Count leading zeros", function()
  assert(caml_int32_clz(0) == 32, "clz(0) should be 32")
  assert(caml_int32_clz(1) == 31, "clz(1) should be 31")
  assert(caml_int32_clz(0x80000000) == 0, "clz(0x80000000) should be 0")
  assert(caml_int32_clz(0xFF) == 24, "clz(0xFF) should be 24")
  assert(caml_int32_clz(0x00010000) == 15, "clz(0x00010000) should be 15")
end)

test("Count trailing zeros", function()
  assert(caml_int32_ctz(0) == 32, "ctz(0) should be 32")
  assert(caml_int32_ctz(1) == 0, "ctz(1) should be 0")
  assert(caml_int32_ctz(2) == 1, "ctz(2) should be 1")
  assert(caml_int32_ctz(8) == 3, "ctz(8) should be 3")
  assert(caml_int32_ctz(0x80000000) == 31, "ctz(0x80000000) should be 31")
end)

test("Population count", function()
  assert(caml_int32_popcnt(0) == 0, "popcnt(0) should be 0")
  assert(caml_int32_popcnt(1) == 1, "popcnt(1) should be 1")
  assert(caml_int32_popcnt(7) == 3, "popcnt(7) should be 3")
  assert(caml_int32_popcnt(0xFF) == 8, "popcnt(0xFF) should be 8")
  assert(caml_int32_popcnt(-1) == 32, "popcnt(-1) should be 32")
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
