#!/usr/bin/env lua
-- Test suite for integer marshaling (Task 6.1.1)

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
print("Integer Marshaling Tests (Task 6.1.1)")
print("====================================================================")
print()

print("Small Int Write Tests (0-63):")
print("--------------------------------------------------------------------")

test("write_int: 0 (small int)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 0)
  assert_eq(buf.length, 1)
  assert_eq(buf.bytes[1], 0x40)  -- 0x40 + 0
end)

test("write_int: 1 (small int)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 1)
  assert_eq(buf.length, 1)
  assert_eq(buf.bytes[1], 0x41)  -- 0x40 + 1
end)

test("write_int: 42 (small int)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 42)
  assert_eq(buf.length, 1)
  assert_eq(buf.bytes[1], 0x40 + 42)
end)

test("write_int: 63 (small int max)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 63)
  assert_eq(buf.length, 1)
  assert_eq(buf.bytes[1], 0x7F)  -- 0x40 + 63
end)

print()
print("INT8 Write Tests (-128 to 127):")
print("--------------------------------------------------------------------")

test("write_int: 64 (INT8)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 64)
  assert_eq(buf.length, 2)
  assert_eq(buf.bytes[1], 0x00)  -- CODE_INT8
  assert_eq(buf.bytes[2], 64)
end)

test("write_int: 100 (INT8)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 100)
  assert_eq(buf.length, 2)
  assert_eq(buf.bytes[1], 0x00)  -- CODE_INT8
  assert_eq(buf.bytes[2], 100)
end)

test("write_int: 127 (INT8 max)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 127)
  assert_eq(buf.length, 2)
  assert_eq(buf.bytes[1], 0x00)  -- CODE_INT8
  assert_eq(buf.bytes[2], 127)
end)

test("write_int: -1 (INT8)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, -1)
  assert_eq(buf.length, 2)
  assert_eq(buf.bytes[1], 0x00)  -- CODE_INT8
  assert_eq(buf.bytes[2], 255)   -- -1 as unsigned byte
end)

test("write_int: -50 (INT8)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, -50)
  assert_eq(buf.length, 2)
  assert_eq(buf.bytes[1], 0x00)  -- CODE_INT8
  assert_eq(buf.bytes[2], 206)   -- -50 as unsigned byte (256 - 50)
end)

test("write_int: -128 (INT8 min)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, -128)
  assert_eq(buf.length, 2)
  assert_eq(buf.bytes[1], 0x00)  -- CODE_INT8
  assert_eq(buf.bytes[2], 128)   -- -128 as unsigned byte
end)

print()
print("INT16 Write Tests (-32768 to 32767):")
print("--------------------------------------------------------------------")

test("write_int: 128 (INT16)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 128)
  assert_eq(buf.length, 3)
  assert_eq(buf.bytes[1], 0x01)  -- CODE_INT16
  local str = caml_marshal_buffer_to_string(buf)
  local val = caml_marshal_read16u(str, 1)
  assert_eq(val, 128)
end)

test("write_int: 1000 (INT16)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 1000)
  assert_eq(buf.length, 3)
  assert_eq(buf.bytes[1], 0x01)  -- CODE_INT16
  local str = caml_marshal_buffer_to_string(buf)
  local val = caml_marshal_read16u(str, 1)
  assert_eq(val, 1000)
end)

test("write_int: 32767 (INT16 max)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 32767)
  assert_eq(buf.length, 3)
  assert_eq(buf.bytes[1], 0x01)  -- CODE_INT16
end)

test("write_int: -129 (INT16)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, -129)
  assert_eq(buf.length, 3)
  assert_eq(buf.bytes[1], 0x01)  -- CODE_INT16
end)

test("write_int: -1000 (INT16)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, -1000)
  assert_eq(buf.length, 3)
  assert_eq(buf.bytes[1], 0x01)  -- CODE_INT16
end)

test("write_int: -32768 (INT16 min)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, -32768)
  assert_eq(buf.length, 3)
  assert_eq(buf.bytes[1], 0x01)  -- CODE_INT16
end)

print()
print("INT32 Write Tests:")
print("--------------------------------------------------------------------")

test("write_int: 32768 (INT32)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 32768)
  assert_eq(buf.length, 5)
  assert_eq(buf.bytes[1], 0x02)  -- CODE_INT32
end)

test("write_int: 100000 (INT32)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 100000)
  assert_eq(buf.length, 5)
  assert_eq(buf.bytes[1], 0x02)  -- CODE_INT32
end)

test("write_int: 2147483647 (INT32 max)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, 2147483647)
  assert_eq(buf.length, 5)
  assert_eq(buf.bytes[1], 0x02)  -- CODE_INT32
end)

test("write_int: -32769 (INT32)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, -32769)
  assert_eq(buf.length, 5)
  assert_eq(buf.bytes[1], 0x02)  -- CODE_INT32
end)

test("write_int: -100000 (INT32)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, -100000)
  assert_eq(buf.length, 5)
  assert_eq(buf.bytes[1], 0x02)  -- CODE_INT32
end)

test("write_int: -2147483648 (INT32 min)", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_int(buf, -2147483648)
  assert_eq(buf.length, 5)
  assert_eq(buf.bytes[1], 0x02)  -- CODE_INT32
end)

print()
print("Read Int Tests:")
print("--------------------------------------------------------------------")

test("read_int: small int 0", function()
  local str = string.char(0x40)
  local result = caml_marshal_read_int(str, 0)
  assert_eq(result.value, 0)
  assert_eq(result.bytes_read, 1)
end)

test("read_int: small int 42", function()
  local str = string.char(0x40 + 42)
  local result = caml_marshal_read_int(str, 0)
  assert_eq(result.value, 42)
  assert_eq(result.bytes_read, 1)
end)

test("read_int: small int 63", function()
  local str = string.char(0x7F)
  local result = caml_marshal_read_int(str, 0)
  assert_eq(result.value, 63)
  assert_eq(result.bytes_read, 1)
end)

test("read_int: INT8 positive", function()
  local str = string.char(0x00, 100)
  local result = caml_marshal_read_int(str, 0)
  assert_eq(result.value, 100)
  assert_eq(result.bytes_read, 2)
end)

test("read_int: INT8 negative", function()
  local str = string.char(0x00, 206)  -- -50
  local result = caml_marshal_read_int(str, 0)
  assert_eq(result.value, -50)
  assert_eq(result.bytes_read, 2)
end)

test("read_int: INT16 positive", function()
  local str = string.char(0x01, 0x03, 0xE8)  -- 1000
  local result = caml_marshal_read_int(str, 0)
  assert_eq(result.value, 1000)
  assert_eq(result.bytes_read, 3)
end)

test("read_int: INT16 negative", function()
  local str = string.char(0x01, 0xFC, 0x18)  -- -1000
  local result = caml_marshal_read_int(str, 0)
  assert_eq(result.value, -1000)
  assert_eq(result.bytes_read, 3)
end)

test("read_int: INT32 positive", function()
  local str = string.char(0x02, 0x00, 0x01, 0x86, 0xA0)  -- 100000
  local result = caml_marshal_read_int(str, 0)
  assert_eq(result.value, 100000)
  assert_eq(result.bytes_read, 5)
end)

test("read_int: INT32 negative", function()
  local str = string.char(0x02, 0xFF, 0xFE, 0x79, 0x60)  -- -100000
  local result = caml_marshal_read_int(str, 0)
  assert_eq(result.value, -100000)
  assert_eq(result.bytes_read, 5)
end)

test("read_int: at offset", function()
  local str = string.char(0xFF, 0xFF, 0x40 + 10)  -- Padding + small int 10
  local result = caml_marshal_read_int(str, 2)
  assert_eq(result.value, 10)
  assert_eq(result.bytes_read, 1)
end)

print()
print("Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("roundtrip: small ints (0-63)", function()
  for i = 0, 63 do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_int(buf, i)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_int(str, 0)
    assert_eq(result.value, i, "Roundtrip " .. i)
  end
end)

test("roundtrip: INT8 range", function()
  local values = {-128, -100, -50, -1, 64, 100, 127}
  for _, v in ipairs(values) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_int(buf, v)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_int(str, 0)
    assert_eq(result.value, v, "Roundtrip " .. v)
  end
end)

test("roundtrip: INT16 range", function()
  local values = {-32768, -10000, -1000, -129, 128, 1000, 10000, 32767}
  for _, v in ipairs(values) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_int(buf, v)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_int(str, 0)
    assert_eq(result.value, v, "Roundtrip " .. v)
  end
end)

test("roundtrip: INT32 range", function()
  local values = {-2147483648, -1000000, -100000, -32769, 32768, 100000, 1000000, 2147483647}
  for _, v in ipairs(values) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_int(buf, v)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_int(str, 0)
    assert_eq(result.value, v, "Roundtrip " .. v)
  end
end)

test("roundtrip: boundary values", function()
  local values = {
    0, 63, 64, 127, 128, -1, -128, -129,
    32767, 32768, -32768, -32769,
    2147483647, -2147483648
  }
  for _, v in ipairs(values) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_int(buf, v)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_int(str, 0)
    assert_eq(result.value, v, "Roundtrip boundary " .. v)
  end
end)

print()
print("Error Handling Tests:")
print("--------------------------------------------------------------------")

test("read_int: invalid code", function()
  local str = string.char(0x99)  -- Invalid code
  local success = pcall(function()
    caml_marshal_read_int(str, 0)
  end)
  assert_true(not success, "Should error on invalid code")
end)

test("read_int: insufficient data for INT8", function()
  local str = string.char(0x00)  -- CODE_INT8 but no data
  local success = pcall(function()
    caml_marshal_read_int(str, 0)
  end)
  assert_true(not success, "Should error on insufficient data")
end)

test("read_int: insufficient data for INT16", function()
  local str = string.char(0x01, 0x00)  -- CODE_INT16 but only 1 byte
  local success = pcall(function()
    caml_marshal_read_int(str, 0)
  end)
  assert_true(not success, "Should error on insufficient data")
end)

test("read_int: insufficient data for INT32", function()
  local str = string.char(0x02, 0x00, 0x00, 0x00)  -- CODE_INT32 but only 3 bytes
  local success = pcall(function()
    caml_marshal_read_int(str, 0)
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
