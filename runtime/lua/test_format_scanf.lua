#!/usr/bin/env lua
-- Test Scanf-style parsing functions

-- Load format.lua directly (it defines global caml_* functions)
dofile("format.lua")

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
  io.write("Test: " .. name .. " ... ")
  local success, err = pcall(fn)
  if success then
    tests_passed = tests_passed + 1
    print("✓")
  else
    tests_failed = tests_failed + 1
    print("✗")
    print("  Error: " .. tostring(err))
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(msg or ("Expected " .. tostring(expected) .. ", got " .. tostring(actual)))
  end
end

local function assert_nil(value, msg)
  if value ~= nil then
    error(msg or "Expected nil, got " .. tostring(value))
  end
end

print("====================================================================")
print("Scanf-style Parsing Tests")
print("====================================================================")
print()

print("Integer Scanning Tests:")
print("--------------------------------------------------------------------")

-- Basic integer scanning
test("scan_int: decimal integer", function()
  local value, pos = caml_scan_int("42")
  assert_eq(value, 42)
  assert_eq(pos, 3)
end)

test("scan_int: negative integer", function()
  local value, pos = caml_scan_int("-123")
  assert_eq(value, -123)
  assert_eq(pos, 5)
end)

test("scan_int: positive sign", function()
  local value, pos = caml_scan_int("+456")
  assert_eq(value, 456)
  assert_eq(pos, 5)
end)

test("scan_int: with leading whitespace", function()
  local value, pos = caml_scan_int("  42")
  assert_eq(value, 42)
  assert_eq(pos, 5)
end)

test("scan_int: stops at non-digit", function()
  local value, pos = caml_scan_int("42abc")
  assert_eq(value, 42)
  assert_eq(pos, 3)
end)

-- Hexadecimal scanning
test("scan_int: hex with %x format", function()
  local value, pos = caml_scan_int("ff", 1, "%x")
  assert_eq(value, 255)
  assert_eq(pos, 3)
end)

test("scan_int: hex with 0x prefix", function()
  local value, pos = caml_scan_int("0xff", 1, "%x")
  assert_eq(value, 255)
  assert_eq(pos, 5)
end)

test("scan_int: hex uppercase", function()
  local value, pos = caml_scan_int("0XFF", 1, "%x")
  assert_eq(value, 255)
  assert_eq(pos, 5)
end)

test("scan_int: hex mixed case", function()
  local value, pos = caml_scan_int("0xAbCd", 1, "%x")
  assert_eq(value, 43981)
  assert_eq(pos, 7)
end)

-- Octal scanning
test("scan_int: octal with %o format", function()
  local value, pos = caml_scan_int("77", 1, "%o")
  assert_eq(value, 63)
  assert_eq(pos, 3)
end)

test("scan_int: octal with 0o prefix", function()
  local value, pos = caml_scan_int("0o100", 1, "%o")
  assert_eq(value, 64)
  assert_eq(pos, 6)
end)

-- Position tracking
test("scan_int: from middle of string", function()
  local value, pos = caml_scan_int("abc 123 def", 5)
  assert_eq(value, 123)
  assert_eq(pos, 8)
end)

-- Error cases
test("scan_int: empty string", function()
  local value, pos = caml_scan_int("")
  assert_nil(value)
end)

test("scan_int: no digits", function()
  local value, pos = caml_scan_int("abc")
  assert_nil(value)
end)

test("scan_int: only sign", function()
  local value, pos = caml_scan_int("+")
  assert_nil(value)
end)

print()
print("Float Scanning Tests:")
print("--------------------------------------------------------------------")

-- Basic float scanning
test("scan_float: simple decimal", function()
  local value, pos = caml_scan_float("3.14")
  assert_eq(value, 3.14)
  assert_eq(pos, 5)
end)

test("scan_float: integer part only", function()
  local value, pos = caml_scan_float("42")
  assert_eq(value, 42.0)
  assert_eq(pos, 3)
end)

test("scan_float: fractional part only", function()
  local value, pos = caml_scan_float(".5")
  assert_eq(value, 0.5)
  assert_eq(pos, 3)
end)

test("scan_float: negative", function()
  local value, pos = caml_scan_float("-2.5")
  assert_eq(value, -2.5)
  assert_eq(pos, 5)
end)

test("scan_float: positive sign", function()
  local value, pos = caml_scan_float("+1.5")
  assert_eq(value, 1.5)
  assert_eq(pos, 5)
end)

-- Exponential notation
test("scan_float: with exponent", function()
  local value, pos = caml_scan_float("1.23e4")
  assert_eq(value, 12300.0)
  assert_eq(pos, 7)
end)

test("scan_float: with negative exponent", function()
  local value, pos = caml_scan_float("1.5e-2")
  assert_eq(value, 0.015)
  assert_eq(pos, 7)
end)

test("scan_float: uppercase E", function()
  local value, pos = caml_scan_float("2.0E3")
  assert_eq(value, 2000.0)
  assert_eq(pos, 6)
end)

-- Special values
test("scan_float: NaN", function()
  local value, pos = caml_scan_float("nan")
  assert_eq(value ~= value, true)  -- NaN != NaN
  assert_eq(pos, 4)
end)

test("scan_float: Infinity", function()
  local value, pos = caml_scan_float("inf")
  assert_eq(value, math.huge)
  assert_eq(pos, 4)
end)

test("scan_float: -Infinity", function()
  local value, pos = caml_scan_float("-infinity")
  assert_eq(value, -math.huge)
  assert_eq(pos, 10)
end)

-- Whitespace handling
test("scan_float: with leading whitespace", function()
  local value, pos = caml_scan_float("  3.14")
  assert_eq(value, 3.14)
  assert_eq(pos, 7)
end)

-- Error cases
test("scan_float: empty string", function()
  local value, pos = caml_scan_float("")
  assert_nil(value)
end)

test("scan_float: no number", function()
  local value, pos = caml_scan_float("abc")
  assert_nil(value)
end)

print()
print("String Scanning Tests:")
print("--------------------------------------------------------------------")

-- Basic string scanning
test("scan_string: simple word", function()
  local value, pos = caml_scan_string("hello")
  assert_eq(value, "hello")
  assert_eq(pos, 6)
end)

test("scan_string: stops at whitespace", function()
  local value, pos = caml_scan_string("hello world")
  assert_eq(value, "hello")
  assert_eq(pos, 6)
end)

test("scan_string: with leading whitespace", function()
  local value, pos = caml_scan_string("  test")
  assert_eq(value, "test")
  assert_eq(pos, 7)
end)

test("scan_string: with width limit", function()
  local value, pos = caml_scan_string("hello", 1, 3)
  assert_eq(value, "hel")
  assert_eq(pos, 4)
end)

-- Error cases
test("scan_string: empty string", function()
  local value, pos = caml_scan_string("")
  assert_nil(value)
end)

test("scan_string: only whitespace", function()
  local value, pos = caml_scan_string("   ")
  assert_nil(value)
end)

print()
print("Character Scanning Tests:")
print("--------------------------------------------------------------------")

-- Basic character scanning
test("scan_char: single character", function()
  local value, pos = caml_scan_char("A")
  assert_eq(value, 65)
  assert_eq(pos, 2)
end)

test("scan_char: first of many", function()
  local value, pos = caml_scan_char("Hello")
  assert_eq(value, 72)  -- 'H'
  assert_eq(pos, 2)
end)

test("scan_char: with skip_ws", function()
  local value, pos = caml_scan_char("  X", 1, true)
  assert_eq(value, 88)  -- 'X'
  assert_eq(pos, 4)
end)

test("scan_char: from position", function()
  local value, pos = caml_scan_char("ABC", 2)
  assert_eq(value, 66)  -- 'B'
  assert_eq(pos, 3)
end)

-- Error cases
test("scan_char: empty string", function()
  local value, pos = caml_scan_char("")
  assert_nil(value)
end)

print()
print("Combined Scanf (sscanf) Tests:")
print("--------------------------------------------------------------------")

-- Single value parsing
test("sscanf: single integer", function()
  local results = caml_sscanf("42", "%d")
  assert_eq(#results, 1)
  assert_eq(results[1], 42)
end)

test("sscanf: single float", function()
  local results = caml_sscanf("3.14", "%f")
  assert_eq(#results, 1)
  assert_eq(results[1], 3.14)
end)

test("sscanf: single string", function()
  local results = caml_sscanf("hello", "%s")
  assert_eq(#results, 1)
  assert_eq(results[1], "hello")
end)

test("sscanf: single character", function()
  local results = caml_sscanf("A", "%c")
  assert_eq(#results, 1)
  assert_eq(results[1], 65)
end)

-- Multiple value parsing
test("sscanf: two integers", function()
  local results = caml_sscanf("42 123", "%d %d")
  assert_eq(#results, 2)
  assert_eq(results[1], 42)
  assert_eq(results[2], 123)
end)

test("sscanf: int and float", function()
  local results = caml_sscanf("10 3.14", "%d %f")
  assert_eq(#results, 2)
  assert_eq(results[1], 10)
  assert_eq(results[2], 3.14)
end)

test("sscanf: mixed types", function()
  local results = caml_sscanf("42 hello 3.14", "%d %s %f")
  assert_eq(#results, 3)
  assert_eq(results[1], 42)
  assert_eq(results[2], "hello")
  assert_eq(results[3], 3.14)
end)

-- With literal characters
test("sscanf: with comma separator", function()
  local results = caml_sscanf("10,20", "%d,%d")
  assert_eq(#results, 2)
  assert_eq(results[1], 10)
  assert_eq(results[2], 20)
end)

test("sscanf: with parentheses", function()
  local results = caml_sscanf("(42)", "(%d)")
  assert_eq(#results, 1)
  assert_eq(results[1], 42)
end)

test("sscanf: complex format", function()
  local results = caml_sscanf("x=10, y=20", "x=%d, y=%d")
  assert_eq(#results, 2)
  assert_eq(results[1], 10)
  assert_eq(results[2], 20)
end)

-- Hex and octal
test("sscanf: hexadecimal", function()
  local results = caml_sscanf("0xff", "%x")
  assert_eq(#results, 1)
  assert_eq(results[1], 255)
end)

test("sscanf: octal", function()
  local results = caml_sscanf("0o100", "%o")
  assert_eq(#results, 1)
  assert_eq(results[1], 64)
end)

-- Error cases
test("sscanf: format mismatch", function()
  local results = caml_sscanf("abc", "%d")
  assert_nil(results)
end)

test("sscanf: literal mismatch", function()
  local results = caml_sscanf("10-20", "%d,%d")
  assert_nil(results)
end)

test("sscanf: incomplete input", function()
  local results = caml_sscanf("42", "%d %d")
  assert_nil(results)
end)

print()
print(string.rep("=", 60))
print("Tests passed: " .. tests_passed)
print("Tests failed: " .. tests_failed)
if tests_failed == 0 then
  print("All tests passed! ✓")
  print(string.rep("=", 60))
  os.exit(0)
else
  print("Some tests failed.")
  print(string.rep("=", 60))
  os.exit(1)
end
