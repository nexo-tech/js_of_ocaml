#!/usr/bin/env lua
-- Test Buffer module

local buffer = require("buffer")

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

-- Helper to convert OCaml string (byte array) to Lua string
local function ocaml_string_to_lua(bytes)
  if type(bytes) == "string" then
    return bytes
  end
  local chars = {}
  for i = 1, #bytes do
    table.insert(chars, string.char(bytes[i]))
  end
  return table.concat(chars)
end

print("====================================================================")
print("Buffer Module Tests")
print("====================================================================")
print()

print("Buffer Creation Tests:")
print("--------------------------------------------------------------------")

test("create: default buffer", function()
  local buf = buffer.caml_buffer_create()
  assert_eq(buffer.caml_buffer_length(buf), 0)
end)

test("create: buffer with initial size", function()
  local buf = buffer.caml_buffer_create(100)
  assert_eq(buffer.caml_buffer_length(buf), 0)
  assert_eq(buf.capacity, 100)
end)

print()
print("Add Character Tests:")
print("--------------------------------------------------------------------")

test("add_char: single character (number)", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_char(buf, 65)  -- 'A'
  assert_eq(buffer.caml_buffer_length(buf), 1)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "A")
end)

test("add_char: single character (string)", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_char(buf, "X")
  assert_eq(buffer.caml_buffer_length(buf), 1)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "X")
end)

test("add_char: multiple characters", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_char(buf, 72)  -- 'H'
  buffer.caml_buffer_add_char(buf, 105) -- 'i'
  assert_eq(buffer.caml_buffer_length(buf), 2)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "Hi")
end)

print()
print("Add String Tests:")
print("--------------------------------------------------------------------")

test("add_string: empty string", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_string(buf, "")
  assert_eq(buffer.caml_buffer_length(buf), 0)
end)

test("add_string: simple string", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_string(buf, "hello")
  assert_eq(buffer.caml_buffer_length(buf), 5)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "hello")
end)

test("add_string: multiple strings", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_string(buf, "Hello")
  buffer.caml_buffer_add_string(buf, " ")
  buffer.caml_buffer_add_string(buf, "World")
  assert_eq(buffer.caml_buffer_length(buf), 11)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "Hello World")
end)

test("add_string: long string", function()
  local buf = buffer.caml_buffer_create()
  local long_str = string.rep("abc", 100)
  buffer.caml_buffer_add_string(buf, long_str)
  assert_eq(buffer.caml_buffer_length(buf), 300)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, long_str)
end)

print()
print("Add Substring Tests:")
print("--------------------------------------------------------------------")

test("add_substring: full string", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_substring(buf, "hello", 0, 5)
  assert_eq(buffer.caml_buffer_length(buf), 5)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "hello")
end)

test("add_substring: prefix", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_substring(buf, "hello", 0, 3)
  assert_eq(buffer.caml_buffer_length(buf), 3)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "hel")
end)

test("add_substring: suffix", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_substring(buf, "hello", 2, 3)
  assert_eq(buffer.caml_buffer_length(buf), 3)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "llo")
end)

test("add_substring: middle", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_substring(buf, "hello", 1, 3)
  assert_eq(buffer.caml_buffer_length(buf), 3)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "ell")
end)

test("add_substring: single char", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_substring(buf, "hello", 0, 1)
  assert_eq(buffer.caml_buffer_length(buf), 1)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "h")
end)

print()
print("Contents and Length Tests:")
print("--------------------------------------------------------------------")

test("contents: empty buffer", function()
  local buf = buffer.caml_buffer_create()
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "")
end)

test("contents: preserves data", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_string(buf, "test")
  local result1 = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  local result2 = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result1, "test")
  assert_eq(result2, "test")
end)

test("length: tracks correctly", function()
  local buf = buffer.caml_buffer_create()
  assert_eq(buffer.caml_buffer_length(buf), 0)

  buffer.caml_buffer_add_char(buf, 65)
  assert_eq(buffer.caml_buffer_length(buf), 1)

  buffer.caml_buffer_add_string(buf, "test")
  assert_eq(buffer.caml_buffer_length(buf), 5)

  buffer.caml_buffer_add_substring(buf, "hello", 0, 2)
  assert_eq(buffer.caml_buffer_length(buf), 7)
end)

print()
print("Reset and Clear Tests:")
print("--------------------------------------------------------------------")

test("reset: clears buffer", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_string(buf, "hello")
  assert_eq(buffer.caml_buffer_length(buf), 5)

  buffer.caml_buffer_reset(buf)
  assert_eq(buffer.caml_buffer_length(buf), 0)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "")
end)

test("reset: can reuse buffer", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_string(buf, "first")
  buffer.caml_buffer_reset(buf)
  buffer.caml_buffer_add_string(buf, "second")

  assert_eq(buffer.caml_buffer_length(buf), 6)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "second")
end)

test("clear: same as reset", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_string(buf, "test")
  buffer.caml_buffer_clear(buf)
  assert_eq(buffer.caml_buffer_length(buf), 0)
end)

print()
print("Mixed Operations Tests:")
print("--------------------------------------------------------------------")

test("mixed: char + string + substring", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_char(buf, 72)      -- 'H'
  buffer.caml_buffer_add_string(buf, "ello")
  buffer.caml_buffer_add_char(buf, 32)      -- ' '
  buffer.caml_buffer_add_substring(buf, "World!", 0, 5)

  assert_eq(buffer.caml_buffer_length(buf), 11)
  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "Hello World")
end)

test("mixed: build sentence", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_string(buf, "The")
  buffer.caml_buffer_add_char(buf, 32)  -- space
  buffer.caml_buffer_add_string(buf, "quick")
  buffer.caml_buffer_add_char(buf, 32)
  buffer.caml_buffer_add_string(buf, "brown")
  buffer.caml_buffer_add_char(buf, 32)
  buffer.caml_buffer_add_string(buf, "fox")

  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "The quick brown fox")
end)

print()
print("Printf Integration Tests:")
print("--------------------------------------------------------------------")

test("add_printf: simple integer", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_printf(buf, "Number: %d", 42)

  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "Number: 42")
end)

test("add_printf: multiple values", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_printf(buf, "x=%d, y=%d", 10, 20)

  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "x=10, y=20")
end)

test("add_printf: mixed types", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_printf(buf, "%s: %d items at $%.2f", "Order", 5, 12.99)

  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "Order: 5 items at $12.99")
end)

test("add_printf: multiple calls", function()
  local buf = buffer.caml_buffer_create()
  buffer.caml_buffer_add_printf(buf, "Line %d\n", 1)
  buffer.caml_buffer_add_printf(buf, "Line %d\n", 2)
  buffer.caml_buffer_add_printf(buf, "Line %d\n", 3)

  local result = ocaml_string_to_lua(buffer.caml_buffer_contents(buf))
  assert_eq(result, "Line 1\nLine 2\nLine 3\n")
end)

print()
print("Performance Tests:")
print("--------------------------------------------------------------------")

test("performance: many small additions", function()
  local buf = buffer.caml_buffer_create()
  for i = 1, 1000 do
    buffer.caml_buffer_add_char(buf, 65)
  end
  assert_eq(buffer.caml_buffer_length(buf), 1000)
end)

test("performance: large string accumulation", function()
  local buf = buffer.caml_buffer_create()
  for i = 1, 100 do
    buffer.caml_buffer_add_string(buf, "0123456789")
  end
  assert_eq(buffer.caml_buffer_length(buf), 1000)
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
