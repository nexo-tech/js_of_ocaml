#!/usr/bin/env lua
-- Test format string parsing

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

local function assert_true(value, msg)
  if not value then
    error(msg or "Expected true, got false")
  end
end

local function assert_false(value, msg)
  if value then
    error(msg or "Expected false, got true")
  end
end

-- Helper to convert OCaml string (byte array) to Lua string
-- Use the global caml_ocaml_string_to_lua from format.lua
local function ocaml_string_to_lua(bytes)
  return caml_ocaml_string_to_lua(bytes)
end

print("====================================================================")
print("Format String Parsing Tests")
print("====================================================================")
print()

-- Basic integer formats
test("Parse %d format", function()
  local f = caml_parse_format("d")
  assert_eq(f.base, 10)
  assert_true(f.signedconv)
  assert_eq(f.conv, "d")
  assert_eq(f.width, 0)
  assert_eq(f.prec, -1)
end)

test("Parse %i format", function()
  local f = caml_parse_format("i")
  assert_eq(f.base, 10)
  assert_true(f.signedconv)
  assert_eq(f.conv, "i")
end)

test("Parse %u format", function()
  local f = caml_parse_format("u")
  assert_eq(f.base, 10)
  assert_false(f.signedconv)
  assert_eq(f.conv, "u")
end)

test("Parse %x format", function()
  local f = caml_parse_format("x")
  assert_eq(f.base, 16)
  assert_false(f.signedconv)
  assert_false(f.uppercase)
  assert_eq(f.conv, "x")
end)

test("Parse %X format", function()
  local f = caml_parse_format("X")
  assert_eq(f.base, 16)
  assert_true(f.uppercase)
  assert_eq(f.conv, "x")
end)

test("Parse %o format", function()
  local f = caml_parse_format("o")
  assert_eq(f.base, 8)
  assert_eq(f.conv, "o")
end)

-- Float formats
test("Parse %f format", function()
  local f = caml_parse_format("f")
  assert_true(f.signedconv)
  assert_eq(f.conv, "f")
end)

test("Parse %e format", function()
  local f = caml_parse_format("e")
  assert_true(f.signedconv)
  assert_eq(f.conv, "e")
end)

test("Parse %g format", function()
  local f = caml_parse_format("g")
  assert_true(f.signedconv)
  assert_eq(f.conv, "g")
end)

test("Parse %E format (uppercase)", function()
  local f = caml_parse_format("E")
  assert_true(f.signedconv)
  assert_true(f.uppercase)
  assert_eq(f.conv, "e")
end)

test("Parse %F format (uppercase)", function()
  local f = caml_parse_format("F")
  assert_true(f.signedconv)
  assert_true(f.uppercase)
  assert_eq(f.conv, "f")
end)

test("Parse %G format (uppercase)", function()
  local f = caml_parse_format("G")
  assert_true(f.signedconv)
  assert_true(f.uppercase)
  assert_eq(f.conv, "g")
end)

-- String and char formats
test("Parse %s format", function()
  local f = caml_parse_format("s")
  assert_eq(f.conv, "s")
end)

test("Parse %c format", function()
  local f = caml_parse_format("c")
  assert_eq(f.conv, "c")
end)

-- Flags
test("Parse %-d (left justify)", function()
  local f = caml_parse_format("-d")
  assert_eq(f.justify, "-")
  assert_eq(f.base, 10)
end)

test("Parse %+d (force sign)", function()
  local f = caml_parse_format("+d")
  assert_eq(f.signstyle, "+")
  assert_eq(f.base, 10)
end)

test("Parse % d (space for positive)", function()
  local f = caml_parse_format(" d")
  assert_eq(f.signstyle, " ")
  assert_eq(f.base, 10)
end)

test("Parse %0d (zero padding)", function()
  local f = caml_parse_format("0d")
  assert_eq(f.filler, "0")
  assert_eq(f.base, 10)
end)

test("Parse %#x (alternate form)", function()
  local f = caml_parse_format("#x")
  assert_true(f.alternate)
  assert_eq(f.base, 16)
end)

test("Parse %#o (alternate form)", function()
  local f = caml_parse_format("#o")
  assert_true(f.alternate)
  assert_eq(f.base, 8)
end)

-- Width
test("Parse %5d (width 5)", function()
  local f = caml_parse_format("5d")
  assert_eq(f.width, 5)
  assert_eq(f.base, 10)
end)

test("Parse %10d (width 10)", function()
  local f = caml_parse_format("10d")
  assert_eq(f.width, 10)
end)

test("Parse %123d (width 123)", function()
  local f = caml_parse_format("123d")
  assert_eq(f.width, 123)
end)

-- Precision
test("Parse %.2f (precision 2)", function()
  local f = caml_parse_format(".2f")
  assert_eq(f.prec, 2)
  assert_eq(f.conv, "f")
end)

test("Parse %.5f (precision 5)", function()
  local f = caml_parse_format(".5f")
  assert_eq(f.prec, 5)
end)

test("Parse %.0f (precision 0)", function()
  local f = caml_parse_format(".0f")
  assert_eq(f.prec, 0)
end)

test("Parse %.10d (precision 10)", function()
  local f = caml_parse_format(".10d")
  assert_eq(f.prec, 10)
  assert_eq(f.base, 10)
end)

-- Combined flags and modifiers
test("Parse %+5d (sign + width)", function()
  local f = caml_parse_format("+5d")
  assert_eq(f.signstyle, "+")
  assert_eq(f.width, 5)
  assert_eq(f.base, 10)
end)

test("Parse %-10s (left justify + width)", function()
  local f = caml_parse_format("-10s")
  assert_eq(f.justify, "-")
  assert_eq(f.width, 10)
  assert_eq(f.conv, "s")
end)

test("Parse %05d (zero pad + width)", function()
  local f = caml_parse_format("05d")
  assert_eq(f.filler, "0")
  assert_eq(f.width, 5)
  assert_eq(f.base, 10)
end)

test("Parse %#8x (alternate + width)", function()
  local f = caml_parse_format("#8x")
  assert_true(f.alternate)
  assert_eq(f.width, 8)
  assert_eq(f.base, 16)
end)

test("Parse %8.2f (width + precision)", function()
  local f = caml_parse_format("8.2f")
  assert_eq(f.width, 8)
  assert_eq(f.prec, 2)
  assert_eq(f.conv, "f")
end)

test("Parse %+08d (sign + zero pad + width)", function()
  local f = caml_parse_format("+08d")
  assert_eq(f.signstyle, "+")
  assert_eq(f.filler, "0")
  assert_eq(f.width, 8)
  assert_eq(f.base, 10)
end)

test("Parse %-+10d (left + sign + width)", function()
  local f = caml_parse_format("-+10d")
  assert_eq(f.justify, "-")
  assert_eq(f.signstyle, "+")
  assert_eq(f.width, 10)
end)

test("Parse %#010x (alternate + zero + width)", function()
  local f = caml_parse_format("#010x")
  assert_true(f.alternate)
  assert_eq(f.filler, "0")
  assert_eq(f.width, 10)
  assert_eq(f.base, 16)
end)

test("Parse % 8.3f (space + width + precision)", function()
  local f = caml_parse_format(" 8.3f")
  assert_eq(f.signstyle, " ")
  assert_eq(f.width, 8)
  assert_eq(f.prec, 3)
end)

test("Parse %+10.5f (all modifiers)", function()
  local f = caml_parse_format("+10.5f")
  assert_eq(f.signstyle, "+")
  assert_eq(f.width, 10)
  assert_eq(f.prec, 5)
  assert_eq(f.conv, "f")
end)

print()
print("====================================================================")
print("Format Finishing Tests")
print("====================================================================")
print()

-- Basic finish_formatting tests
test("Format simple string", function()
  local f = {
    justify = "+",
    signstyle = "-",
    filler = " ",
    alternate = false,
    base = 10,
    signedconv = false,
    width = 0,
    uppercase = false,
    sign = 1,
    prec = -1,
    conv = "d"
  }
  local result = caml_finish_formatting(f, "123")
  assert_eq(ocaml_string_to_lua(result), "123")
end)

test("Format with width (right justify)", function()
  local f = caml_parse_format("5d")
  f.sign = 1
  local result = caml_finish_formatting(f, "42")
  assert_eq(ocaml_string_to_lua(result), "   42")
end)

test("Format with width (left justify)", function()
  local f = caml_parse_format("-5d")
  f.sign = 1
  local result = caml_finish_formatting(f, "42")
  assert_eq(ocaml_string_to_lua(result), "42   ")
end)

test("Format with zero padding", function()
  local f = caml_parse_format("05d")
  f.sign = 1
  local result = caml_finish_formatting(f, "42")
  assert_eq(ocaml_string_to_lua(result), "00042")
end)

test("Format negative number", function()
  local f = caml_parse_format("d")
  f.sign = -1
  local result = caml_finish_formatting(f, "42")
  assert_eq(ocaml_string_to_lua(result), "-42")
end)

test("Format with + sign", function()
  local f = caml_parse_format("+d")
  f.sign = 1
  local result = caml_finish_formatting(f, "42")
  assert_eq(ocaml_string_to_lua(result), "+42")
end)

test("Format with space sign", function()
  local f = caml_parse_format(" d")
  f.sign = 1
  local result = caml_finish_formatting(f, "42")
  assert_eq(ocaml_string_to_lua(result), " 42")
end)

test("Format hex with alternate form", function()
  local f = caml_parse_format("#x")
  f.sign = 1
  local result = caml_finish_formatting(f, "2a")
  assert_eq(ocaml_string_to_lua(result), "0x2a")
end)

test("Format HEX with alternate form (uppercase)", function()
  local f = caml_parse_format("#X")
  f.sign = 1
  local result = caml_finish_formatting(f, "2a")
  assert_eq(ocaml_string_to_lua(result), "0X2A")
end)

test("Format octal with alternate form", function()
  local f = caml_parse_format("#o")
  f.sign = 1
  local result = caml_finish_formatting(f, "52")
  assert_eq(ocaml_string_to_lua(result), "052")
end)

test("Format with sign and width", function()
  local f = caml_parse_format("+6d")
  f.sign = 1
  local result = caml_finish_formatting(f, "42")
  assert_eq(ocaml_string_to_lua(result), "   +42")
end)

test("Format with sign, zero pad, and width", function()
  local f = caml_parse_format("+06d")
  f.sign = 1
  local result = caml_finish_formatting(f, "42")
  assert_eq(ocaml_string_to_lua(result), "+00042")
end)

test("Format negative with zero pad", function()
  local f = caml_parse_format("06d")
  f.sign = -1
  local result = caml_finish_formatting(f, "42")
  assert_eq(ocaml_string_to_lua(result), "-00042")
end)

test("Format hex with alternate and width", function()
  local f = caml_parse_format("#8x")
  f.sign = 1
  local result = caml_finish_formatting(f, "1a2b")
  assert_eq(ocaml_string_to_lua(result), "  0x1a2b")
end)

test("Format hex with alternate, zero pad, and width", function()
  local f = caml_parse_format("#010x")
  f.sign = 1
  local result = caml_finish_formatting(f, "1a2b")
  assert_eq(ocaml_string_to_lua(result), "0x00001a2b")
end)

test("Format uppercase conversion", function()
  local f = caml_parse_format("X")
  f.sign = 1
  local result = caml_finish_formatting(f, "abcd")
  assert_eq(ocaml_string_to_lua(result), "ABCD")
end)

test("Format long number with width", function()
  local f = caml_parse_format("3d")
  f.sign = 1
  local result = caml_finish_formatting(f, "12345")
  assert_eq(ocaml_string_to_lua(result), "12345")  -- Width doesn't truncate
end)

-- Error handling
test("Format string too long (>31 chars)", function()
  local success = pcall(function()
    caml_parse_format("01234567890123456789012345678901")
  end)
  assert_false(success, "Should reject format string >31 chars")
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
