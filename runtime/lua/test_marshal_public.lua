#!/usr/bin/env lua
-- Test suite for public Marshal API (Task 6.1.6)
-- Works on Lua 5.1+

dofile("marshal_io.lua")
dofile("marshal_header.lua")
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

local function assert_near(actual, expected, tolerance, msg)
  local diff = math.abs(actual - expected)
  if diff > tolerance then
    error(msg or string.format("Expected %g (±%g), got %g (diff: %g)", expected, tolerance, actual, diff))
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "Expected true, got false")
  end
end

print("====================================================================")
print("Public Marshal API Tests (Task 6.1.6)")
print("====================================================================")
print()

print("Basic Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("roundtrip: integer 42", function()
  local marshaled = caml_marshal_to_string(42)
  local value = caml_marshal_from_bytes(marshaled)
  assert_eq(value, 42)
end)

test("roundtrip: integer 0", function()
  local marshaled = caml_marshal_to_string(0)
  local value = caml_marshal_from_bytes(marshaled)
  assert_eq(value, 0)
end)

test("roundtrip: negative integer", function()
  local marshaled = caml_marshal_to_string(-12345)
  local value = caml_marshal_from_bytes(marshaled)
  assert_eq(value, -12345)
end)

test("roundtrip: double 3.14", function()
  local marshaled = caml_marshal_to_string(3.14)
  local value = caml_marshal_from_bytes(marshaled)
  assert_near(value, 3.14, 1e-15)
end)

test("roundtrip: string 'hello'", function()
  local marshaled = caml_marshal_to_string("hello")
  local value = caml_marshal_from_bytes(marshaled)
  assert_eq(value, "hello")
end)

test("roundtrip: empty string", function()
  local marshaled = caml_marshal_to_string("")
  local value = caml_marshal_from_bytes(marshaled)
  assert_eq(value, "")
end)

test("roundtrip: long string", function()
  local str = string.rep("abcdef", 100)  -- 600 chars
  local marshaled = caml_marshal_to_string(str)
  local value = caml_marshal_from_bytes(marshaled)
  assert_eq(value, str)
end)

test("roundtrip: block with integers", function()
  local block = {tag = 1, size = 3, [1] = 10, [2] = 20, [3] = 30}
  local marshaled = caml_marshal_to_string(block)
  local value = caml_marshal_from_bytes(marshaled)
  assert_eq(value.tag, 1)
  assert_eq(value.size, 3)
  assert_eq(value[1], 10)
  assert_eq(value[2], 20)
  assert_eq(value[3], 30)
end)

test("roundtrip: nested blocks", function()
  local inner = {tag = 2, size = 1, [1] = 99}
  local outer = {tag = 1, size = 2, [1] = 42, [2] = inner}
  local marshaled = caml_marshal_to_string(outer)
  local value = caml_marshal_from_bytes(marshaled)
  assert_eq(value.tag, 1)
  assert_eq(value.size, 2)
  assert_eq(value[1], 42)
  assert_eq(value[2].tag, 2)
  assert_eq(value[2][1], 99)
end)

test("roundtrip: float array", function()
  local arr = {size = 4, [1] = 1.5, [2] = 2.5, [3] = 3.5, [4] = 4.5}
  local marshaled = caml_marshal_to_string(arr)
  local value = caml_marshal_from_bytes(marshaled)
  assert_eq(value.size, 4)
  for i = 1, 4 do
    assert_near(value[i], i + 0.5, 1e-15)
  end
end)

test("roundtrip: mixed types block", function()
  local block = {tag = 10, size = 4,
                [1] = 42,
                [2] = 3.14,
                [3] = "hello",
                [4] = {tag = 0, size = 0}}
  local marshaled = caml_marshal_to_string(block)
  local value = caml_marshal_from_bytes(marshaled)
  assert_eq(value.tag, 10)
  assert_eq(value.size, 4)
  assert_eq(value[1], 42)
  assert_near(value[2], 3.14, 1e-15)
  assert_eq(value[3], "hello")
  assert_eq(value[4].tag, 0)
end)

print()
print("Alias Functions:")
print("--------------------------------------------------------------------")

test("caml_marshal_to_bytes is alias", function()
  local value = 12345
  local marshaled1 = caml_marshal_to_string(value)
  local marshaled2 = caml_marshal_to_bytes(value)
  assert_eq(marshaled1, marshaled2)
end)

test("caml_marshal_from_string is alias", function()
  local marshaled = caml_marshal_to_string(67890)
  local value1 = caml_marshal_from_bytes(marshaled)
  local value2 = caml_marshal_from_string(marshaled)
  assert_eq(value1, value2)
end)

print()
print("Size Functions:")
print("--------------------------------------------------------------------")

test("data_size: integer", function()
  local marshaled = caml_marshal_to_string(42)
  local data_size = caml_marshal_data_size(marshaled)
  assert_eq(data_size, 1)  -- Small int: 1 byte
end)

test("data_size: large integer", function()
  local marshaled = caml_marshal_to_string(100000)
  local data_size = caml_marshal_data_size(marshaled)
  assert_eq(data_size, 5)  -- INT32: 1 code + 4 bytes
end)

test("data_size: double", function()
  local marshaled = caml_marshal_to_string(3.14)
  local data_size = caml_marshal_data_size(marshaled)
  assert_eq(data_size, 9)  -- CODE_DOUBLE: 1 code + 8 bytes
end)

test("data_size: string 'hello'", function()
  local marshaled = caml_marshal_to_string("hello")
  local data_size = caml_marshal_data_size(marshaled)
  assert_eq(data_size, 6)  -- Small string: 1 code + 5 bytes
end)

test("data_size: block", function()
  local block = {tag = 0, size = 2, [1] = 10, [2] = 20}
  local marshaled = caml_marshal_to_string(block)
  local data_size = caml_marshal_data_size(marshaled)
  -- Small block: 1 byte header + 2 small ints (1 byte each) = 3 bytes
  assert_eq(data_size, 3)
end)

test("total_size: integer", function()
  local marshaled = caml_marshal_to_string(42)
  local total_size = caml_marshal_total_size(marshaled)
  assert_eq(total_size, 21)  -- 20 header + 1 data
  assert_eq(#marshaled, total_size)  -- Verify against actual length
end)

test("total_size: double", function()
  local marshaled = caml_marshal_to_string(3.14)
  local total_size = caml_marshal_total_size(marshaled)
  assert_eq(total_size, 29)  -- 20 header + 9 data
  assert_eq(#marshaled, total_size)
end)

test("total_size: string", function()
  local marshaled = caml_marshal_to_string("hello")
  local total_size = caml_marshal_total_size(marshaled)
  assert_eq(total_size, 26)  -- 20 header + 6 data
  assert_eq(#marshaled, total_size)
end)

test("total_size: block", function()
  local block = {tag = 0, size = 2, [1] = 10, [2] = 20}
  local marshaled = caml_marshal_to_string(block)
  local total_size = caml_marshal_total_size(marshaled)
  assert_eq(total_size, 23)  -- 20 header + 3 data
  assert_eq(#marshaled, total_size)
end)

print()
print("Offset Parameter Tests:")
print("--------------------------------------------------------------------")

test("from_bytes: with offset 0", function()
  local marshaled = caml_marshal_to_string(12345)
  local value = caml_marshal_from_bytes(marshaled, 0)
  assert_eq(value, 12345)
end)

test("from_bytes: with nil offset (default 0)", function()
  local marshaled = caml_marshal_to_string(67890)
  local value = caml_marshal_from_bytes(marshaled, nil)
  assert_eq(value, 67890)
end)

test("from_bytes: with padding before", function()
  local marshaled = caml_marshal_to_string(999)
  local padded = string.rep(string.char(0xFF), 10) .. marshaled
  local value = caml_marshal_from_bytes(padded, 10)
  assert_eq(value, 999)
end)

test("data_size: with offset", function()
  local marshaled = caml_marshal_to_string(42)
  local padded = string.rep(string.char(0x00), 5) .. marshaled
  local data_size = caml_marshal_data_size(padded, 5)
  assert_eq(data_size, 1)
end)

test("total_size: with offset", function()
  local marshaled = caml_marshal_to_string(42)
  local padded = string.rep(string.char(0x00), 5) .. marshaled
  local total_size = caml_marshal_total_size(padded, 5)
  assert_eq(total_size, 21)
end)

print()
print("Complex Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("roundtrip: array of integers", function()
  local values = {0, 1, 63, 64, 127, 128, 1000, 32767, 32768, 100000, -1, -100, -32768, -100000}
  for _, v in ipairs(values) do
    local marshaled = caml_marshal_to_string(v)
    local result = caml_marshal_from_bytes(marshaled)
    assert_eq(result, v, "Roundtrip " .. v)
  end
end)

test("roundtrip: array of doubles", function()
  local values = {0.0, 0.5, 1.0, 3.14159, 2.71828, 1e10, 1e-10, math.huge, -math.huge}
  for _, v in ipairs(values) do
    local marshaled = caml_marshal_to_string(v)
    local result = caml_marshal_from_bytes(marshaled)
    if v == math.huge or v == -math.huge then
      assert_eq(result, v, "Roundtrip " .. tostring(v))
    else
      assert_near(result, v, math.abs(v) * 1e-15 + 1e-15, "Roundtrip " .. v)
    end
  end
end)

test("roundtrip: array of strings", function()
  local values = {"", "a", "hello", "Hello, World!", string.rep("x", 100), string.rep("y", 300)}
  for _, v in ipairs(values) do
    local marshaled = caml_marshal_to_string(v)
    local result = caml_marshal_from_bytes(marshaled)
    assert_eq(result, v, "Roundtrip string len=" .. #v)
  end
end)

test("roundtrip: deeply nested structure", function()
  local level4 = {tag = 4, size = 1, [1] = "deep"}
  local level3 = {tag = 3, size = 2, [1] = 100, [2] = level4}
  local level2 = {tag = 2, size = 2, [1] = "mid", [2] = level3}
  local level1 = {tag = 1, size = 3, [1] = 42, [2] = 3.14, [3] = level2}
  local level0 = {tag = 0, size = 1, [1] = level1}

  local marshaled = caml_marshal_to_string(level0)
  local result = caml_marshal_from_bytes(marshaled)

  assert_eq(result.tag, 0)
  assert_eq(result[1].tag, 1)
  assert_eq(result[1][1], 42)
  assert_near(result[1][2], 3.14, 1e-15)
  assert_eq(result[1][3].tag, 2)
  assert_eq(result[1][3][1], "mid")
  assert_eq(result[1][3][2].tag, 3)
  assert_eq(result[1][3][2][1], 100)
  assert_eq(result[1][3][2][2].tag, 4)
  assert_eq(result[1][3][2][2][1], "deep")
end)

test("roundtrip: block with float array", function()
  local float_arr = {size = 3, [1] = 1.1, [2] = 2.2, [3] = 3.3}
  local block = {tag = 5, size = 3, [1] = 99, [2] = "text", [3] = float_arr}

  local marshaled = caml_marshal_to_string(block)
  local result = caml_marshal_from_bytes(marshaled)

  assert_eq(result.tag, 5)
  assert_eq(result.size, 3)
  assert_eq(result[1], 99)
  assert_eq(result[2], "text")
  assert_eq(result[3].size, 3)
  assert_near(result[3][1], 1.1, 1e-15)
  assert_near(result[3][2], 2.2, 1e-15)
  assert_near(result[3][3], 3.3, 1e-15)
end)

print()
print("Header Verification:")
print("--------------------------------------------------------------------")

test("header: contains correct magic", function()
  local marshaled = caml_marshal_to_string(42)
  -- Check that first 4 bytes are magic number (0x8495A6BE big-endian)
  local b1 = string.byte(marshaled, 1)
  local b2 = string.byte(marshaled, 2)
  local b3 = string.byte(marshaled, 3)
  local b4 = string.byte(marshaled, 4)
  -- Read as big-endian: b1 is most significant byte
  local magic = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
  assert_eq(magic, 0x8495A6BE, "Magic number should be MAGIC_SMALL")
end)

test("header: data_len matches actual", function()
  local value = {tag = 0, size = 5, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5}
  local marshaled = caml_marshal_to_string(value)
  local data_size = caml_marshal_data_size(marshaled)
  local total_size = caml_marshal_total_size(marshaled)
  assert_eq(total_size, 20 + data_size)
  assert_eq(#marshaled, total_size)
end)

test("header: size matches string length", function()
  local strings = {"", "a", "hello", string.rep("x", 100)}
  for _, s in ipairs(strings) do
    local marshaled = caml_marshal_to_string(s)
    local total_size = caml_marshal_total_size(marshaled)
    assert_eq(#marshaled, total_size, "Size mismatch for string len=" .. #s)
  end
end)

print()
print("Error Handling:")
print("--------------------------------------------------------------------")

test("from_bytes: invalid header magic", function()
  local bad_header = string.rep(string.char(0x00), 20) .. string.char(0x40)
  local success = pcall(function()
    caml_marshal_from_bytes(bad_header)
  end)
  assert_true(not success, "Should error on invalid magic")
end)

test("from_bytes: insufficient data", function()
  local marshaled = caml_marshal_to_string(42)
  local truncated = string.sub(marshaled, 1, 15)  -- Only 15 bytes, need at least 21
  local success = pcall(function()
    caml_marshal_from_bytes(truncated)
  end)
  assert_true(not success, "Should error on insufficient data")
end)

test("data_size: insufficient header", function()
  local short_string = string.rep(string.char(0x00), 10)
  local success = pcall(function()
    caml_marshal_data_size(short_string)
  end)
  assert_true(not success, "Should error on insufficient header")
end)

print()
print("Multiple Values in Sequence:")
print("--------------------------------------------------------------------")

test("sequence: two values back-to-back", function()
  local marshaled1 = caml_marshal_to_string(111)
  local marshaled2 = caml_marshal_to_string(222)
  local combined = marshaled1 .. marshaled2

  local value1 = caml_marshal_from_bytes(combined, 0)
  assert_eq(value1, 111)

  local offset2 = caml_marshal_total_size(combined, 0)
  local value2 = caml_marshal_from_bytes(combined, offset2)
  assert_eq(value2, 222)
end)

test("sequence: three different types", function()
  local m1 = caml_marshal_to_string(42)
  local m2 = caml_marshal_to_string("hello")
  local m3 = caml_marshal_to_string(3.14)
  local combined = m1 .. m2 .. m3

  local v1 = caml_marshal_from_bytes(combined, 0)
  assert_eq(v1, 42)

  local offset2 = caml_marshal_total_size(combined, 0)
  local v2 = caml_marshal_from_bytes(combined, offset2)
  assert_eq(v2, "hello")

  local offset3 = offset2 + caml_marshal_total_size(combined, offset2)
  local v3 = caml_marshal_from_bytes(combined, offset3)
  assert_near(v3, 3.14, 1e-15)
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
