#!/usr/bin/env lua
-- Test suite for string marshaling (Task 6.1.2)

dofile("marshal_io.lua")
dofile("marshal.lua")

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

print("====================================================================")
print("String Marshaling Tests (Task 6.1.2)")
print("====================================================================")
print()

print("Small String Write Tests (0-31 bytes):")
print("--------------------------------------------------------------------")

test("write_string: empty string", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, "")
  assert_eq(buf.length, 1)
  assert_eq(buf.bytes[1], 0x20)  -- 0x20 + 0
end)

test("write_string: 'a' (1 byte)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, "a")
  assert_eq(buf.length, 2)
  assert_eq(buf.bytes[1], 0x21)  -- 0x20 + 1
  assert_eq(buf.bytes[2], string.byte("a"))
end)

test("write_string: 'Hello' (5 bytes)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, "Hello")
  assert_eq(buf.length, 6)
  assert_eq(buf.bytes[1], 0x25)  -- 0x20 + 5
  local str = caml_marshal_buffer_to_string(buf)
  assert_eq(string.sub(str, 2, 6), "Hello")
end)

test("write_string: 'Hello, World!' (13 bytes)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, "Hello, World!")
  assert_eq(buf.length, 14)
  assert_eq(buf.bytes[1], 0x2D)  -- 0x20 + 13
end)

test("write_string: 31 bytes (small string max)", function()
  local s = string.rep("x", 31)
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  assert_eq(buf.length, 32)
  assert_eq(buf.bytes[1], 0x3F)  -- 0x20 + 31
end)

test("write_string: special characters", function()
  local s = "\0\1\2\255"
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  assert_eq(buf.length, 5)
  assert_eq(buf.bytes[1], 0x24)  -- 0x20 + 4
end)

print()
print("STRING8 Write Tests (32-255 bytes):")
print("--------------------------------------------------------------------")

test("write_string: 32 bytes (STRING8)", function()
  local s = string.rep("x", 32)
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  assert_eq(buf.length, 34)  -- 1 code + 1 length + 32 bytes
  assert_eq(buf.bytes[1], 0x09)  -- CODE_STRING8
  assert_eq(buf.bytes[2], 32)
end)

test("write_string: 50 bytes (STRING8)", function()
  local s = string.rep("y", 50)
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  assert_eq(buf.length, 52)  -- 1 code + 1 length + 50 bytes
  assert_eq(buf.bytes[1], 0x09)  -- CODE_STRING8
  assert_eq(buf.bytes[2], 50)
end)

test("write_string: 100 bytes (STRING8)", function()
  local s = string.rep("a", 100)
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  assert_eq(buf.length, 102)
  assert_eq(buf.bytes[1], 0x09)  -- CODE_STRING8
  assert_eq(buf.bytes[2], 100)
end)

test("write_string: 255 bytes (STRING8 max)", function()
  local s = string.rep("z", 255)
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  assert_eq(buf.length, 257)
  assert_eq(buf.bytes[1], 0x09)  -- CODE_STRING8
  assert_eq(buf.bytes[2], 255)
end)

print()
print("STRING32 Write Tests (256+ bytes):")
print("--------------------------------------------------------------------")

test("write_string: 256 bytes (STRING32)", function()
  local s = string.rep("x", 256)
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  assert_eq(buf.length, 261)  -- 1 code + 4 length + 256 bytes
  assert_eq(buf.bytes[1], 0x0A)  -- CODE_STRING32
  local str = caml_marshal_buffer_to_string(buf)
  local len = caml_marshal_read32u(str, 1)
  assert_eq(len, 256)
end)

test("write_string: 300 bytes (STRING32)", function()
  local s = string.rep("y", 300)
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  assert_eq(buf.length, 305)  -- 1 code + 4 length + 300 bytes
  assert_eq(buf.bytes[1], 0x0A)  -- CODE_STRING32
  local str = caml_marshal_buffer_to_string(buf)
  local len = caml_marshal_read32u(str, 1)
  assert_eq(len, 300)
end)

test("write_string: 1000 bytes (STRING32)", function()
  local s = string.rep("a", 1000)
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  assert_eq(buf.length, 1005)
  assert_eq(buf.bytes[1], 0x0A)  -- CODE_STRING32
end)

test("write_string: 10000 bytes (STRING32 large)", function()
  local s = string.rep("b", 10000)
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  assert_eq(buf.length, 10005)
  assert_eq(buf.bytes[1], 0x0A)  -- CODE_STRING32
end)

print()
print("Read String Tests:")
print("--------------------------------------------------------------------")

test("read_string: empty string", function()
  local str = string.char(0x20)  -- Length 0
  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, "")
  assert_eq(result.bytes_read, 1)
end)

test("read_string: 'a'", function()
  local str = string.char(0x21) .. "a"  -- Length 1
  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, "a")
  assert_eq(result.bytes_read, 2)
end)

test("read_string: 'test'", function()
  local str = string.char(0x24) .. "test"  -- Length 4
  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, "test")
  assert_eq(result.bytes_read, 5)
end)

test("read_string: 'Hello, World!'", function()
  local str = string.char(0x2D) .. "Hello, World!"  -- Length 13
  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, "Hello, World!")
  assert_eq(result.bytes_read, 14)
end)

test("read_string: 31 bytes (small max)", function()
  local s = string.rep("x", 31)
  local str = string.char(0x3F) .. s  -- Length 31
  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, s)
  assert_eq(result.bytes_read, 32)
end)

test("read_string: STRING8", function()
  local s = string.rep("y", 50)
  local str = string.char(0x09, 50) .. s
  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, s)
  assert_eq(result.bytes_read, 52)
end)

test("read_string: STRING8 255 bytes", function()
  local s = string.rep("z", 255)
  local str = string.char(0x09, 255) .. s
  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, s)
  assert_eq(result.bytes_read, 257)
end)

test("read_string: STRING32", function()
  local s = string.rep("a", 300)
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x0A)  -- CODE_STRING32
  caml_marshal_buffer_write32u(buf, 300)
  caml_marshal_buffer_write_bytes(buf, s)
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, s)
  assert_eq(result.bytes_read, 305)
end)

test("read_string: at offset", function()
  local str = string.char(0xFF, 0xFF, 0x25) .. "Hello"  -- Padding + "Hello"
  local result = caml_marshal_read_string(str, 2)
  assert_eq(result.value, "Hello")
  assert_eq(result.bytes_read, 6)
end)

test("read_string: special characters", function()
  local s = "\0\1\2\255"
  local str = string.char(0x24) .. s
  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, s)
  assert_eq(result.bytes_read, 5)
end)

print()
print("Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("roundtrip: empty string", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, "")
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, "")
end)

test("roundtrip: small strings (0-31 bytes)", function()
  local strings = {"", "a", "ab", "Hello", "Hello, World!", string.rep("x", 31)}
  for _, s in ipairs(strings) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_string(buf, s)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_string(str, 0)
    assert_eq(result.value, s, "Roundtrip '" .. s:sub(1, 20) .. "'")
  end
end)

test("roundtrip: STRING8 range (32-255 bytes)", function()
  local lengths = {32, 50, 100, 200, 255}
  for _, len in ipairs(lengths) do
    local s = string.rep("a", len)
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_string(buf, s)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_string(str, 0)
    assert_eq(result.value, s, "Roundtrip length " .. len)
    assert_eq(#result.value, len)
  end
end)

test("roundtrip: STRING32 range (256+ bytes)", function()
  local lengths = {256, 300, 1000, 5000}
  for _, len in ipairs(lengths) do
    local s = string.rep("b", len)
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_string(buf, s)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_string(str, 0)
    assert_eq(#result.value, len, "Roundtrip length " .. len)
  end
end)

test("roundtrip: boundary values", function()
  local lengths = {0, 1, 31, 32, 255, 256, 1000}
  for _, len in ipairs(lengths) do
    local s = string.rep("c", len)
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_string(buf, s)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_string(str, 0)
    assert_eq(#result.value, len, "Boundary length " .. len)
  end
end)

test("roundtrip: special characters", function()
  local strings = {
    "\0",
    "\0\1\2\3",
    string.char(255, 254, 253),
    "Mixed\0null\1byte\255test"
  }
  for _, s in ipairs(strings) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_string(buf, s)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_string(str, 0)
    assert_eq(result.value, s, "Roundtrip special chars")
  end
end)

test("roundtrip: UTF-8 compatible", function()
  -- Lua strings are byte sequences, UTF-8 works as-is
  local s = "Hello 世界 🌍"
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_string(buf, s)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_string(str, 0)
  assert_eq(result.value, s, "UTF-8 roundtrip")
end)

print()
print("Format Selection Tests:")
print("--------------------------------------------------------------------")

test("format: 0-31 bytes uses small string", function()
  for len = 0, 31 do
    local s = string.rep("x", len)
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_string(buf, s)
    assert_eq(buf.bytes[1], 0x20 + len, "Length " .. len .. " should use small string")
    assert_eq(buf.length, 1 + len, "Total size check")
  end
end)

test("format: 32-255 bytes uses STRING8", function()
  for _, len in ipairs({32, 50, 100, 200, 255}) do
    local s = string.rep("x", len)
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_string(buf, s)
    assert_eq(buf.bytes[1], 0x09, "Length " .. len .. " should use STRING8")
    assert_eq(buf.bytes[2], len, "Length byte check")
    assert_eq(buf.length, 2 + len, "Total size check")
  end
end)

test("format: 256+ bytes uses STRING32", function()
  for _, len in ipairs({256, 300, 1000, 10000}) do
    local s = string.rep("x", len)
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_string(buf, s)
    assert_eq(buf.bytes[1], 0x0A, "Length " .. len .. " should use STRING32")
    assert_eq(buf.length, 5 + len, "Total size check")
  end
end)

print()
print("Error Handling Tests:")
print("--------------------------------------------------------------------")

test("read_string: invalid code", function()
  local str = string.char(0x99)  -- Invalid code
  local success = pcall(function()
    caml_marshal_read_string(str, 0)
  end)
  assert_true(not success, "Should error on invalid code")
end)

test("read_string: insufficient data for small string", function()
  local str = string.char(0x25)  -- Length 5 but no data
  local success = pcall(function()
    caml_marshal_read_string(str, 0)
  end)
  assert_true(not success, "Should error on insufficient data")
end)

test("read_string: insufficient data for STRING8", function()
  local str = string.char(0x09, 50)  -- Length 50 but no data
  local success = pcall(function()
    caml_marshal_read_string(str, 0)
  end)
  assert_true(not success, "Should error on insufficient data")
end)

test("read_string: insufficient data for STRING32", function()
  local str = string.char(0x0A, 0, 0, 1, 0)  -- Length 256 but no data
  local success = pcall(function()
    caml_marshal_read_string(str, 0)
  end)
  assert_true(not success, "Should error on insufficient data")
end)

print()
print("====================================================================")
print("Tests passed: " .. tests_passed .. " / " .. (tests_passed + tests_failed))
if tests_failed == 0 then
  print("All tests passed! ✓")
  print("====================================================================")
  os.exit(0)
else
  print("Some tests failed.")
  print("====================================================================")
  os.exit(1)
end
