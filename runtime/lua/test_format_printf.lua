#!/usr/bin/env lua
-- Test Printf-style formatting functions

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
    error(msg or ("Expected '" .. tostring(expected) .. "', got '" .. tostring(actual) .. "'"))
  end
end

-- Helper to convert OCaml string (byte array) to Lua string
local function ocaml_string_to_lua(bytes)
  local chars = {}
  for i = 1, #bytes do
    table.insert(chars, string.char(bytes[i]))
  end
  return table.concat(chars)
end

print("====================================================================")
print("Printf-style Formatting Tests")
print("====================================================================")
print()

print("Integer Formatting Tests:")
print("--------------------------------------------------------------------")

-- Basic integer formatting
test("format_int: %d with positive integer", function()
  local result = caml_format_int("%d", 42)
  assert_eq(ocaml_string_to_lua(result), "42")
end)

test("format_int: %d with negative integer", function()
  local result = caml_format_int("%d", -42)
  assert_eq(ocaml_string_to_lua(result), "-42")
end)

test("format_int: %d with zero", function()
  local result = caml_format_int("%d", 0)
  assert_eq(ocaml_string_to_lua(result), "0")
end)

test("format_int: %i format", function()
  local result = caml_format_int("%i", 123)
  assert_eq(ocaml_string_to_lua(result), "123")
end)

-- Unsigned format
test("format_int: %u with positive", function()
  local result = caml_format_int("%u", 42)
  assert_eq(ocaml_string_to_lua(result), "42")
end)

-- Hexadecimal format
test("format_int: %x lowercase hex", function()
  local result = caml_format_int("%x", 255)
  assert_eq(ocaml_string_to_lua(result), "ff")
end)

test("format_int: %X uppercase hex", function()
  local result = caml_format_int("%X", 255)
  assert_eq(ocaml_string_to_lua(result), "FF")
end)

test("format_int: %x with large number", function()
  local result = caml_format_int("%x", 4095)
  assert_eq(ocaml_string_to_lua(result), "fff")
end)

-- Octal format
test("format_int: %o octal", function()
  local result = caml_format_int("%o", 64)
  assert_eq(ocaml_string_to_lua(result), "100")
end)

test("format_int: %o with 8", function()
  local result = caml_format_int("%o", 8)
  assert_eq(ocaml_string_to_lua(result), "10")
end)

-- Width
test("format_int: %5d with width", function()
  local result = caml_format_int("%5d", 42)
  assert_eq(ocaml_string_to_lua(result), "   42")
end)

test("format_int: %10d with width", function()
  local result = caml_format_int("%10d", 123)
  assert_eq(ocaml_string_to_lua(result), "       123")
end)

test("format_int: %-5d left justify", function()
  local result = caml_format_int("%-5d", 42)
  assert_eq(ocaml_string_to_lua(result), "42   ")
end)

-- Zero padding
test("format_int: %05d zero padding", function()
  local result = caml_format_int("%05d", 42)
  assert_eq(ocaml_string_to_lua(result), "00042")
end)

test("format_int: %08d zero padding", function()
  local result = caml_format_int("%08d", 123)
  assert_eq(ocaml_string_to_lua(result), "00000123")
end)

-- Sign
test("format_int: %+d with positive (force sign)", function()
  local result = caml_format_int("%+d", 42)
  assert_eq(ocaml_string_to_lua(result), "+42")
end)

test("format_int: %+d with negative", function()
  local result = caml_format_int("%+d", -42)
  assert_eq(ocaml_string_to_lua(result), "-42")
end)

test("format_int: % d with positive (space)", function()
  local result = caml_format_int("% d", 42)
  assert_eq(ocaml_string_to_lua(result), " 42")
end)

test("format_int: % d with negative", function()
  local result = caml_format_int("% d", -42)
  assert_eq(ocaml_string_to_lua(result), "-42")
end)

-- Alternate form
test("format_int: %#x hex with prefix", function()
  local result = caml_format_int("%#x", 255)
  assert_eq(ocaml_string_to_lua(result), "0xff")
end)

test("format_int: %#X hex with prefix uppercase", function()
  local result = caml_format_int("%#X", 255)
  assert_eq(ocaml_string_to_lua(result), "0XFF")
end)

test("format_int: %#o octal with prefix", function()
  local result = caml_format_int("%#o", 64)
  assert_eq(ocaml_string_to_lua(result), "0100")
end)

-- Precision
test("format_int: %.5d precision", function()
  local result = caml_format_int("%.5d", 42)
  assert_eq(ocaml_string_to_lua(result), "00042")
end)

test("format_int: %.10d precision", function()
  local result = caml_format_int("%.10d", 123)
  assert_eq(ocaml_string_to_lua(result), "0000000123")
end)

test("format_int: %.3d precision (number already longer)", function()
  local result = caml_format_int("%.3d", 12345)
  assert_eq(ocaml_string_to_lua(result), "12345")
end)

-- Combined flags
test("format_int: %+8d sign and width", function()
  local result = caml_format_int("%+8d", 42)
  assert_eq(ocaml_string_to_lua(result), "     +42")
end)

test("format_int: %+08d sign, zero pad, and width", function()
  local result = caml_format_int("%+08d", 42)
  assert_eq(ocaml_string_to_lua(result), "+0000042")
end)

test("format_int: %-+8d left, sign, and width", function()
  local result = caml_format_int("%-+8d", 42)
  assert_eq(ocaml_string_to_lua(result), "+42     ")
end)

test("format_int: %#10x alternate and width", function()
  local result = caml_format_int("%#10x", 255)
  assert_eq(ocaml_string_to_lua(result), "      0xff")
end)

test("format_int: %#010x alternate, zero pad, and width", function()
  local result = caml_format_int("%#010x", 255)
  assert_eq(ocaml_string_to_lua(result), "0x000000ff")
end)

print()
print("Float Formatting Tests:")
print("--------------------------------------------------------------------")

-- Basic float formatting
test("format_float: %f basic", function()
  local result = caml_format_float("%f", 3.14159)
  assert_eq(ocaml_string_to_lua(result), "3.141590")
end)

test("format_float: %f with negative", function()
  local result = caml_format_float("%f", -2.5)
  assert_eq(ocaml_string_to_lua(result), "-2.500000")
end)

test("format_float: %f with zero", function()
  local result = caml_format_float("%f", 0.0)
  assert_eq(ocaml_string_to_lua(result), "0.000000")
end)

-- Precision
test("format_float: %.2f precision 2", function()
  local result = caml_format_float("%.2f", 3.14159)
  assert_eq(ocaml_string_to_lua(result), "3.14")
end)

test("format_float: %.0f precision 0", function()
  local result = caml_format_float("%.0f", 3.14159)
  assert_eq(ocaml_string_to_lua(result), "3")
end)

test("format_float: %.10f high precision", function()
  local result = caml_format_float("%.10f", 3.14159)
  -- Check that result starts with "3.1415900000"
  local str = ocaml_string_to_lua(result)
  assert_eq(str:sub(1, 12), "3.1415900000")
end)

-- Exponential format
test("format_float: %e exponential", function()
  local result = caml_format_float("%e", 1234.5)
  local str = ocaml_string_to_lua(result)
  -- Should be something like "1.234500e+03"
  assert_eq(str:match("^%d%.%d+e[+-]%d+$") ~= nil, true)
end)

test("format_float: %E uppercase exponential", function()
  local result = caml_format_float("%E", 1234.5)
  local str = ocaml_string_to_lua(result)
  -- Should be uppercase E
  assert_eq(str:match("E") ~= nil, true)
end)

-- Special values
test("format_float: NaN", function()
  local result = caml_format_float("%f", 0/0)
  assert_eq(ocaml_string_to_lua(result), "nan")
end)

test("format_float: Infinity", function()
  local result = caml_format_float("%f", math.huge)
  assert_eq(ocaml_string_to_lua(result), "inf")
end)

test("format_float: -Infinity", function()
  local result = caml_format_float("%f", -math.huge)
  assert_eq(ocaml_string_to_lua(result), "-inf")
end)

-- Width and sign
test("format_float: %10f with width", function()
  local result = caml_format_float("%10f", 3.14)
  local str = ocaml_string_to_lua(result)
  assert_eq(#str, 10)
  assert_eq(str:match("%s+3%.14") ~= nil, true)
end)

test("format_float: %+f with sign", function()
  local result = caml_format_float("%+f", 3.14)
  local str = ocaml_string_to_lua(result)
  assert_eq(str:sub(1, 1), "+")
end)

test("format_float: % f with space", function()
  local result = caml_format_float("% f", 3.14)
  local str = ocaml_string_to_lua(result)
  assert_eq(str:sub(1, 1), " ")
end)

print()
print("String Formatting Tests:")
print("--------------------------------------------------------------------")

-- Basic string formatting
test("format_string: %s basic", function()
  local result = caml_format_string("%s", "hello")
  assert_eq(ocaml_string_to_lua(result), "hello")
end)

test("format_string: %s empty string", function()
  local result = caml_format_string("%s", "")
  assert_eq(ocaml_string_to_lua(result), "")
end)

-- Width
test("format_string: %10s with width", function()
  local result = caml_format_string("%10s", "hello")
  assert_eq(ocaml_string_to_lua(result), "     hello")
end)

test("format_string: %-10s left justify", function()
  local result = caml_format_string("%-10s", "hello")
  assert_eq(ocaml_string_to_lua(result), "hello     ")
end)

test("format_string: %3s width shorter than string", function()
  local result = caml_format_string("%3s", "hello")
  assert_eq(ocaml_string_to_lua(result), "hello")
end)

-- Precision (max length)
test("format_string: %.3s precision truncates", function()
  local result = caml_format_string("%.3s", "hello")
  assert_eq(ocaml_string_to_lua(result), "hel")
end)

test("format_string: %.10s precision longer than string", function()
  local result = caml_format_string("%.10s", "hello")
  assert_eq(ocaml_string_to_lua(result), "hello")
end)

test("format_string: %8.3s width and precision", function()
  local result = caml_format_string("%8.3s", "hello")
  assert_eq(ocaml_string_to_lua(result), "     hel")
end)

print()
print("Character Formatting Tests:")
print("--------------------------------------------------------------------")

-- Basic character formatting
test("format_char: %c with char code", function()
  local result = caml_format_char("%c", 65)
  assert_eq(ocaml_string_to_lua(result), "A")
end)

test("format_char: %c with string", function()
  local result = caml_format_char("%c", "X")
  assert_eq(ocaml_string_to_lua(result), "X")
end)

-- Width
test("format_char: %5c with width", function()
  local result = caml_format_char("%5c", 65)
  assert_eq(ocaml_string_to_lua(result), "    A")
end)

test("format_char: %-5c left justify", function()
  local result = caml_format_char("%-5c", 65)
  assert_eq(ocaml_string_to_lua(result), "A    ")
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
