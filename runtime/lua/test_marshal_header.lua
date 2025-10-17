#!/usr/bin/env lua
-- Test suite for marshal_header.lua

dofile("marshal_io.lua")
dofile("marshal_header.lua")

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
print("Marshal Header Tests")
print("====================================================================")
print()

print("Header Size Tests:")
print("--------------------------------------------------------------------")

test("header_size: returns 20 bytes", function()
  local size = caml_marshal_header_size()
  assert_eq(size, 20)
end)

print()
print("Header Write Tests:")
print("--------------------------------------------------------------------")

test("header_write: basic header", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 100, 0, 100, 100)
  assert_eq(buf.length, 20)
end)

test("header_write: magic number", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 10, 0, 10, 10)
  local str = caml_marshal_buffer_to_string(buf)

  -- Check magic number is 0x8495A6BE (MAGIC_SMALL)
  local magic = caml_marshal_read32u(str, 0)
  assert_eq(magic, 0x8495A6BE)
end)

test("header_write: data length", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 12345, 0, 0, 0)
  local str = caml_marshal_buffer_to_string(buf)

  -- Check data length field
  local data_len = caml_marshal_read32u(str, 4)
  assert_eq(data_len, 12345)
end)

test("header_write: num objects", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 100, 42, 100, 100)
  local str = caml_marshal_buffer_to_string(buf)

  -- Check num_objects field
  local num_objects = caml_marshal_read32u(str, 8)
  assert_eq(num_objects, 42)
end)

test("header_write: size 32", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 100, 0, 999, 100)
  local str = caml_marshal_buffer_to_string(buf)

  -- Check size_32 field
  local size_32 = caml_marshal_read32u(str, 12)
  assert_eq(size_32, 999)
end)

test("header_write: size 64", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 100, 0, 100, 888)
  local str = caml_marshal_buffer_to_string(buf)

  -- Check size_64 field
  local size_64 = caml_marshal_read32u(str, 16)
  assert_eq(size_64, 888)
end)

test("header_write: all fields", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 1000, 50, 2000, 3000)
  local str = caml_marshal_buffer_to_string(buf)

  assert_eq(caml_marshal_read32u(str, 0), 0x8495A6BE)  -- magic
  assert_eq(caml_marshal_read32u(str, 4), 1000)        -- data_len
  assert_eq(caml_marshal_read32u(str, 8), 50)          -- num_objects
  assert_eq(caml_marshal_read32u(str, 12), 2000)       -- size_32
  assert_eq(caml_marshal_read32u(str, 16), 3000)       -- size_64
end)

print()
print("Header Read Tests:")
print("--------------------------------------------------------------------")

test("header_read: basic header", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 100, 0, 100, 100)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 0)
  assert_true(header ~= nil)
end)

test("header_read: magic number", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 10, 0, 10, 10)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 0)
  assert_eq(header.magic, 0x8495A6BE)
end)

test("header_read: data length", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 12345, 0, 0, 0)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 0)
  assert_eq(header.data_len, 12345)
end)

test("header_read: num objects", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 100, 42, 100, 100)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 0)
  assert_eq(header.num_objects, 42)
end)

test("header_read: size 32", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 100, 0, 999, 100)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 0)
  assert_eq(header.size_32, 999)
end)

test("header_read: size 64", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 100, 0, 100, 888)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 0)
  assert_eq(header.size_64, 888)
end)

test("header_read: all fields", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 1000, 50, 2000, 3000)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 0)
  assert_eq(header.magic, 0x8495A6BE)
  assert_eq(header.data_len, 1000)
  assert_eq(header.num_objects, 50)
  assert_eq(header.size_32, 2000)
  assert_eq(header.size_64, 3000)
end)

test("header_read: at offset", function()
  local buf = caml_marshal_buffer_create()
  -- Write some padding
  caml_marshal_buffer_write8u(buf, 0xFF)
  caml_marshal_buffer_write8u(buf, 0xFF)
  caml_marshal_buffer_write8u(buf, 0xFF)
  caml_marshal_buffer_write8u(buf, 0xFF)
  -- Write header at offset 4
  caml_marshal_header_write(buf, 555, 10, 666, 777)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 4)
  assert_eq(header.data_len, 555)
  assert_eq(header.num_objects, 10)
  assert_eq(header.size_32, 666)
  assert_eq(header.size_64, 777)
end)

print()
print("Error Handling Tests:")
print("--------------------------------------------------------------------")

test("header_read: insufficient data", function()
  local str = "short"
  local success = pcall(function()
    caml_marshal_header_read(str, 0)
  end)
  assert_true(not success, "Should error on short data")
end)

test("header_read: invalid magic number", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write32u(buf, 0xDEADBEEF)  -- Invalid magic
  caml_marshal_buffer_write32u(buf, 0)
  caml_marshal_buffer_write32u(buf, 0)
  caml_marshal_buffer_write32u(buf, 0)
  caml_marshal_buffer_write32u(buf, 0)
  local str = caml_marshal_buffer_to_string(buf)

  local success = pcall(function()
    caml_marshal_header_read(str, 0)
  end)
  assert_true(not success, "Should error on invalid magic")
end)

test("header_read: MAGIC_BIG accepted", function()
  -- Manually create header with MAGIC_BIG (0x8495A6BF)
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write32u(buf, 0x8495A6BF)  -- MAGIC_BIG
  caml_marshal_buffer_write32u(buf, 100)
  caml_marshal_buffer_write32u(buf, 0)
  caml_marshal_buffer_write32u(buf, 100)
  caml_marshal_buffer_write32u(buf, 100)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 0)
  assert_eq(header.magic, 0x8495A6BF)
  assert_eq(header.data_len, 100)
end)

print()
print("Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("roundtrip: zero values", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_header_write(buf, 0, 0, 0, 0)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 0)
  assert_eq(header.data_len, 0)
  assert_eq(header.num_objects, 0)
  assert_eq(header.size_32, 0)
  assert_eq(header.size_64, 0)
end)

test("roundtrip: max values", function()
  local buf = caml_marshal_buffer_create()
  local max32 = 0xFFFFFFFF
  caml_marshal_header_write(buf, max32, max32, max32, max32)
  local str = caml_marshal_buffer_to_string(buf)

  local header = caml_marshal_header_read(str, 0)
  assert_eq(header.data_len, max32)
  assert_eq(header.num_objects, max32)
  assert_eq(header.size_32, max32)
  assert_eq(header.size_64, max32)
end)

test("roundtrip: various values", function()
  local test_cases = {
    {data_len = 1, num_objects = 0, size_32 = 1, size_64 = 1},
    {data_len = 100, num_objects = 5, size_32 = 100, size_64 = 100},
    {data_len = 12345, num_objects = 100, size_32 = 20000, size_64 = 30000},
    {data_len = 1000000, num_objects = 500, size_32 = 999999, size_64 = 1111111},
  }

  for _, tc in ipairs(test_cases) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_header_write(buf, tc.data_len, tc.num_objects, tc.size_32, tc.size_64)
    local str = caml_marshal_buffer_to_string(buf)

    local header = caml_marshal_header_read(str, 0)
    assert_eq(header.data_len, tc.data_len)
    assert_eq(header.num_objects, tc.num_objects)
    assert_eq(header.size_32, tc.size_32)
    assert_eq(header.size_64, tc.size_64)
  end
end)

print()
print("Integration Tests:")
print("--------------------------------------------------------------------")

test("header with data: write and read", function()
  local buf = caml_marshal_buffer_create()

  -- Write header
  caml_marshal_header_write(buf, 5, 0, 5, 5)

  -- Write some data
  caml_marshal_buffer_write_bytes(buf, "Hello")

  local str = caml_marshal_buffer_to_string(buf)
  assert_eq(#str, 25)  -- 20 bytes header + 5 bytes data

  -- Read header
  local header = caml_marshal_header_read(str, 0)
  assert_eq(header.data_len, 5)

  -- Read data
  local data = caml_marshal_read_bytes(str, 20, 5)
  assert_eq(data, "Hello")
end)

test("multiple headers: sequential", function()
  local buf1 = caml_marshal_buffer_create()
  caml_marshal_header_write(buf1, 100, 0, 100, 100)
  local str1 = caml_marshal_buffer_to_string(buf1)

  local buf2 = caml_marshal_buffer_create()
  caml_marshal_header_write(buf2, 200, 5, 200, 200)
  local str2 = caml_marshal_buffer_to_string(buf2)

  -- Concatenate
  local combined = str1 .. str2

  -- Read both headers
  local header1 = caml_marshal_header_read(combined, 0)
  local header2 = caml_marshal_header_read(combined, 20)

  assert_eq(header1.data_len, 100)
  assert_eq(header2.data_len, 200)
  assert_eq(header2.num_objects, 5)
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
