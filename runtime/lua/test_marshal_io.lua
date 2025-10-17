#!/usr/bin/env lua
-- Test suite for marshal_io.lua

dofile("marshal_io.lua")

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

local function assert_close(actual, expected, epsilon, msg)
  if math.abs(actual - expected) > epsilon then
    error(msg or ("Expected " .. tostring(expected) .. ", got " .. tostring(actual)))
  end
end

print("====================================================================")
print("Marshal I/O Tests")
print("====================================================================")
print()

print("Buffer Creation Tests:")
print("--------------------------------------------------------------------")

test("buffer_create: creates empty buffer", function()
  local buf = caml_marshal_buffer_create()
  assert_eq(buf.length, 0)
  assert_true(buf.bytes ~= nil)
end)

print()
print("Write 8-bit Tests:")
print("--------------------------------------------------------------------")

test("write8u: single byte", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x42)
  assert_eq(buf.length, 1)
  assert_eq(buf.bytes[1], 0x42)
end)

test("write8u: multiple bytes", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x01)
  caml_marshal_buffer_write8u(buf, 0x02)
  caml_marshal_buffer_write8u(buf, 0x03)
  assert_eq(buf.length, 3)
  assert_eq(buf.bytes[1], 0x01)
  assert_eq(buf.bytes[2], 0x02)
  assert_eq(buf.bytes[3], 0x03)
end)

test("write8u: boundary values", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x00)
  caml_marshal_buffer_write8u(buf, 0xFF)
  assert_eq(buf.bytes[1], 0x00)
  assert_eq(buf.bytes[2], 0xFF)
end)

print()
print("Write 16-bit Tests:")
print("--------------------------------------------------------------------")

test("write16u: zero", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write16u(buf, 0x0000)
  assert_eq(buf.length, 2)
  assert_eq(buf.bytes[1], 0x00)
  assert_eq(buf.bytes[2], 0x00)
end)

test("write16u: big-endian order", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write16u(buf, 0x1234)
  assert_eq(buf.length, 2)
  assert_eq(buf.bytes[1], 0x12)  -- High byte first
  assert_eq(buf.bytes[2], 0x34)  -- Low byte second
end)

test("write16u: max value", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write16u(buf, 0xFFFF)
  assert_eq(buf.bytes[1], 0xFF)
  assert_eq(buf.bytes[2], 0xFF)
end)

print()
print("Write 32-bit Tests:")
print("--------------------------------------------------------------------")

test("write32u: zero", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write32u(buf, 0x00000000)
  assert_eq(buf.length, 4)
  assert_eq(buf.bytes[1], 0x00)
  assert_eq(buf.bytes[2], 0x00)
  assert_eq(buf.bytes[3], 0x00)
  assert_eq(buf.bytes[4], 0x00)
end)

test("write32u: big-endian order", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write32u(buf, 0x12345678)
  assert_eq(buf.length, 4)
  assert_eq(buf.bytes[1], 0x12)  -- Highest byte first
  assert_eq(buf.bytes[2], 0x34)
  assert_eq(buf.bytes[3], 0x56)
  assert_eq(buf.bytes[4], 0x78)  -- Lowest byte last
end)

test("write32u: large value", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write32u(buf, 0xDEADBEEF)
  assert_eq(buf.bytes[1], 0xDE)
  assert_eq(buf.bytes[2], 0xAD)
  assert_eq(buf.bytes[3], 0xBE)
  assert_eq(buf.bytes[4], 0xEF)
end)

print()
print("Write Bytes Tests:")
print("--------------------------------------------------------------------")

test("write_bytes: empty string", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write_bytes(buf, "")
  assert_eq(buf.length, 0)
end)

test("write_bytes: single character", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write_bytes(buf, "A")
  assert_eq(buf.length, 1)
  assert_eq(buf.bytes[1], string.byte("A"))
end)

test("write_bytes: multiple characters", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write_bytes(buf, "Hello")
  assert_eq(buf.length, 5)
  assert_eq(buf.bytes[1], string.byte("H"))
  assert_eq(buf.bytes[2], string.byte("e"))
  assert_eq(buf.bytes[3], string.byte("l"))
  assert_eq(buf.bytes[4], string.byte("l"))
  assert_eq(buf.bytes[5], string.byte("o"))
end)

print()
print("Buffer to String Tests:")
print("--------------------------------------------------------------------")

test("to_string: empty buffer", function()
  local buf = caml_marshal_buffer_create()
  local str = caml_marshal_buffer_to_string(buf)
  assert_eq(str, "")
end)

test("to_string: single byte", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x41)  -- 'A'
  local str = caml_marshal_buffer_to_string(buf)
  assert_eq(str, "A")
end)

test("to_string: multiple bytes", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write_bytes(buf, "Test")
  local str = caml_marshal_buffer_to_string(buf)
  assert_eq(str, "Test")
end)

test("to_string: mixed writes", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x48)  -- 'H'
  caml_marshal_buffer_write8u(buf, 0x69)  -- 'i'
  local str = caml_marshal_buffer_to_string(buf)
  assert_eq(str, "Hi")
end)

print()
print("Read 8-bit Tests:")
print("--------------------------------------------------------------------")

test("read8u: single byte", function()
  local str = string.char(0x42)
  local value = caml_marshal_read8u(str, 0)
  assert_eq(value, 0x42)
end)

test("read8u: at offset", function()
  local str = string.char(0x01, 0x02, 0x03)
  assert_eq(caml_marshal_read8u(str, 0), 0x01)
  assert_eq(caml_marshal_read8u(str, 1), 0x02)
  assert_eq(caml_marshal_read8u(str, 2), 0x03)
end)

test("read8u: boundary values", function()
  local str = string.char(0x00, 0xFF)
  assert_eq(caml_marshal_read8u(str, 0), 0x00)
  assert_eq(caml_marshal_read8u(str, 1), 0xFF)
end)

print()
print("Read 16-bit Tests:")
print("--------------------------------------------------------------------")

test("read16u: zero", function()
  local str = string.char(0x00, 0x00)
  local value = caml_marshal_read16u(str, 0)
  assert_eq(value, 0x0000)
end)

test("read16u: big-endian order", function()
  local str = string.char(0x12, 0x34)
  local value = caml_marshal_read16u(str, 0)
  assert_eq(value, 0x1234)
end)

test("read16u: max value", function()
  local str = string.char(0xFF, 0xFF)
  local value = caml_marshal_read16u(str, 0)
  assert_eq(value, 0xFFFF)
end)

test("read16u: at offset", function()
  local str = string.char(0xFF, 0x12, 0x34)
  local value = caml_marshal_read16u(str, 1)
  assert_eq(value, 0x1234)
end)

print()
print("Read 32-bit Tests:")
print("--------------------------------------------------------------------")

test("read32u: zero", function()
  local str = string.char(0x00, 0x00, 0x00, 0x00)
  local value = caml_marshal_read32u(str, 0)
  assert_eq(value, 0x00000000)
end)

test("read32u: big-endian order", function()
  local str = string.char(0x12, 0x34, 0x56, 0x78)
  local value = caml_marshal_read32u(str, 0)
  assert_eq(value, 0x12345678)
end)

test("read32u: large value", function()
  local str = string.char(0xDE, 0xAD, 0xBE, 0xEF)
  local value = caml_marshal_read32u(str, 0)
  assert_eq(value, 0xDEADBEEF)
end)

test("read32u: at offset", function()
  local str = string.char(0xFF, 0xFF, 0x12, 0x34, 0x56, 0x78)
  local value = caml_marshal_read32u(str, 2)
  assert_eq(value, 0x12345678)
end)

print()
print("Read Signed Tests:")
print("--------------------------------------------------------------------")

test("read16s: positive value", function()
  local str = string.char(0x00, 0x7F)
  local value = caml_marshal_read16s(str, 0)
  assert_eq(value, 127)
end)

test("read16s: negative value", function()
  local str = string.char(0xFF, 0xFF)
  local value = caml_marshal_read16s(str, 0)
  assert_eq(value, -1)
end)

test("read16s: boundary", function()
  local str = string.char(0x80, 0x00)
  local value = caml_marshal_read16s(str, 0)
  assert_eq(value, -32768)
end)

test("read32s: positive value", function()
  local str = string.char(0x00, 0x00, 0x00, 0x7F)
  local value = caml_marshal_read32s(str, 0)
  assert_eq(value, 127)
end)

test("read32s: negative value", function()
  local str = string.char(0xFF, 0xFF, 0xFF, 0xFF)
  local value = caml_marshal_read32s(str, 0)
  assert_eq(value, -1)
end)

test("read32s: boundary", function()
  local str = string.char(0x80, 0x00, 0x00, 0x00)
  local value = caml_marshal_read32s(str, 0)
  assert_eq(value, -2147483648)
end)

print()
print("Read Bytes Tests:")
print("--------------------------------------------------------------------")

test("read_bytes: empty", function()
  local str = "Hello"
  local bytes = caml_marshal_read_bytes(str, 0, 0)
  assert_eq(bytes, "")
end)

test("read_bytes: full string", function()
  local str = "Hello"
  local bytes = caml_marshal_read_bytes(str, 0, 5)
  assert_eq(bytes, "Hello")
end)

test("read_bytes: substring", function()
  local str = "Hello, World!"
  local bytes = caml_marshal_read_bytes(str, 7, 5)
  assert_eq(bytes, "World")
end)

test("read_bytes: at offset", function()
  local str = "0123456789"
  local bytes = caml_marshal_read_bytes(str, 5, 3)
  assert_eq(bytes, "567")
end)

print()
print("Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("roundtrip: 16-bit values", function()
  local values = {0, 1, 255, 256, 1000, 32767, 65535}
  for _, v in ipairs(values) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_buffer_write16u(buf, v)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read16u(str, 0)
    assert_eq(result, v, "Roundtrip " .. v)
  end
end)

test("roundtrip: 32-bit values", function()
  local values = {0, 1, 255, 256, 65536, 16777216, 0xDEADBEEF}
  for _, v in ipairs(values) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_buffer_write32u(buf, v)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read32u(str, 0)
    assert_eq(result, v, "Roundtrip " .. v)
  end
end)

test("roundtrip: byte sequences", function()
  local strings = {"", "A", "Hello", "Hello, World!", string.rep("x", 100)}
  for _, s in ipairs(strings) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_buffer_write_bytes(buf, s)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_bytes(str, 0, #s)
    assert_eq(result, s, "Roundtrip '" .. s:sub(1, 20) .. "'")
  end
end)

print()
print("Double Tests (Lua 5.3+ only):")
print("--------------------------------------------------------------------")

if string.pack and string.unpack then
  test("write_double_little: positive value", function()
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_double_little(buf, 3.14159)
    assert_eq(buf.length, 8)
  end)

  test("write_double_little: negative value", function()
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_double_little(buf, -2.71828)
    assert_eq(buf.length, 8)
  end)

  test("write_double_little: zero", function()
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_double_little(buf, 0.0)
    assert_eq(buf.length, 8)
  end)

  test("read_double_little: positive value", function()
    -- Create known little-endian representation of 3.14159
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_double_little(buf, 3.14159)
    local str = caml_marshal_buffer_to_string(buf)
    local value = caml_marshal_read_double_little(str, 0)
    assert_close(value, 3.14159, 1e-10)
  end)

  test("read_double_little: at offset", function()
    local buf = caml_marshal_buffer_create()
    caml_marshal_buffer_write8u(buf, 0xFF)
    caml_marshal_buffer_write8u(buf, 0xFF)
    caml_marshal_write_double_little(buf, 2.71828)
    local str = caml_marshal_buffer_to_string(buf)
    local value = caml_marshal_read_double_little(str, 2)
    assert_close(value, 2.71828, 1e-10)
  end)

  test("roundtrip: double values", function()
    local values = {0.0, 1.0, -1.0, 3.14159, -2.71828, 1e10, 1e-10, math.huge, -math.huge}
    for _, v in ipairs(values) do
      local buf = caml_marshal_buffer_create()
      caml_marshal_write_double_little(buf, v)
      local str = caml_marshal_buffer_to_string(buf)
      local result = caml_marshal_read_double_little(str, 0)
      if v == math.huge or v == -math.huge then
        assert_eq(result, v, "Roundtrip " .. tostring(v))
      else
        assert_close(result, v, 1e-10, "Roundtrip " .. v)
      end
    end
  end)
else
  print("  Skipping double tests (string.pack/unpack not available in Lua 5.1)")
end

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
