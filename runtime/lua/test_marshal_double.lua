#!/usr/bin/env lua
-- Test suite for double/float marshaling (Task 6.1.4)

dofile("marshal_io.lua")
dofile("marshal.lua")

-- Check if Lua 5.3+ features are available
if not string.pack or not string.unpack then
  print("====================================================================")
  print("Double/Float Marshaling Tests (Task 6.1.4)")
  print("====================================================================")
  print()
  print("SKIPPED: string.pack/unpack not available (requires Lua 5.3+)")
  print("Current Lua version: " .. _VERSION)
  print("====================================================================")
  os.exit(0)
end

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
print("Double/Float Marshaling Tests (Task 6.1.4)")
print("====================================================================")
print()

print("Double Write Tests:")
print("--------------------------------------------------------------------")

test("write_double: 0.0", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, 0.0)
  assert_eq(buf.length, 9)  -- 1 code + 8 bytes
  assert_eq(buf.bytes[1], 0x0C)  -- CODE_DOUBLE_LITTLE
end)

test("write_double: 1.0", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, 1.0)
  assert_eq(buf.length, 9)
  assert_eq(buf.bytes[1], 0x0C)
end)

test("write_double: -1.0", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, -1.0)
  assert_eq(buf.length, 9)
  assert_eq(buf.bytes[1], 0x0C)
end)

test("write_double: 3.14159265358979", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, 3.14159265358979)
  assert_eq(buf.length, 9)
  assert_eq(buf.bytes[1], 0x0C)
end)

test("write_double: large number", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, 1.23456789e100)
  assert_eq(buf.length, 9)
  assert_eq(buf.bytes[1], 0x0C)
end)

test("write_double: small number", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, 1.23456789e-100)
  assert_eq(buf.length, 9)
  assert_eq(buf.bytes[1], 0x0C)
end)

test("write_double: infinity", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, math.huge)
  assert_eq(buf.length, 9)
  assert_eq(buf.bytes[1], 0x0C)
end)

test("write_double: negative infinity", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, -math.huge)
  assert_eq(buf.length, 9)
  assert_eq(buf.bytes[1], 0x0C)
end)

print()
print("Double Read Tests:")
print("--------------------------------------------------------------------")

test("read_double: 0.0", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, 0.0)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_double(str, 0)
  assert_eq(result.value, 0.0)
  assert_eq(result.bytes_read, 9)
end)

test("read_double: 1.0", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, 1.0)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_double(str, 0)
  assert_eq(result.value, 1.0)
  assert_eq(result.bytes_read, 9)
end)

test("read_double: -1.0", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, -1.0)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_double(str, 0)
  assert_eq(result.value, -1.0)
  assert_eq(result.bytes_read, 9)
end)

test("read_double: 3.14159265358979", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, 3.14159265358979)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_double(str, 0)
  assert_near(result.value, 3.14159265358979, 1e-15)
  assert_eq(result.bytes_read, 9)
end)

test("read_double: at offset", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0xFF)  -- Padding
  caml_marshal_buffer_write8u(buf, 0xFF)  -- Padding
  caml_marshal_write_double(buf, 42.5)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_double(str, 2)
  assert_near(result.value, 42.5, 1e-15)
  assert_eq(result.bytes_read, 9)
end)

test("read_double: infinity", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, math.huge)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_double(str, 0)
  assert_eq(result.value, math.huge)
end)

test("read_double: negative infinity", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_double(buf, -math.huge)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_double(str, 0)
  assert_eq(result.value, -math.huge)
end)

print()
print("Double Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("roundtrip: various doubles", function()
  local values = {0.0, 1.0, -1.0, 0.5, -0.5, 3.14159265358979, 2.71828182845905,
                  123.456, -789.012, 1e10, 1e-10, 1e100, 1e-100, math.huge, -math.huge}
  for _, v in ipairs(values) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_double(buf, v)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_double(str, 0)
    if v == math.huge or v == -math.huge then
      assert_eq(result.value, v, "Roundtrip " .. tostring(v))
    else
      assert_near(result.value, v, math.abs(v) * 1e-15 + 1e-15, "Roundtrip " .. tostring(v))
    end
  end
end)

print()
print("Float Array Write Tests:")
print("--------------------------------------------------------------------")

test("write_float_array: empty array (DOUBLE_ARRAY8)", function()
  local arr = {size = 0}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  assert_eq(buf.length, 2)  -- 1 code + 1 length
  assert_eq(buf.bytes[1], 0x0E)  -- DOUBLE_ARRAY8_LITTLE
  assert_eq(buf.bytes[2], 0)
end)

test("write_float_array: 1 element (DOUBLE_ARRAY8)", function()
  local arr = {size = 1, [1] = 3.14}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  assert_eq(buf.length, 10)  -- 1 code + 1 length + 8 bytes
  assert_eq(buf.bytes[1], 0x0E)
  assert_eq(buf.bytes[2], 1)
end)

test("write_float_array: 5 elements (DOUBLE_ARRAY8)", function()
  local arr = {size = 5, [1] = 1.0, [2] = 2.0, [3] = 3.0, [4] = 4.0, [5] = 5.0}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  assert_eq(buf.length, 42)  -- 1 code + 1 length + 5*8 bytes
  assert_eq(buf.bytes[1], 0x0E)
  assert_eq(buf.bytes[2], 5)
end)

test("write_float_array: 255 elements (DOUBLE_ARRAY8 max)", function()
  local arr = {size = 255}
  for i = 1, 255 do
    arr[i] = i * 1.0
  end
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  assert_eq(buf.length, 2 + 255 * 8)  -- 1 code + 1 length + 255*8 bytes
  assert_eq(buf.bytes[1], 0x0E)
  assert_eq(buf.bytes[2], 255)
end)

test("write_float_array: 256 elements (DOUBLE_ARRAY32)", function()
  local arr = {size = 256}
  for i = 1, 256 do
    arr[i] = i * 1.0
  end
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  assert_eq(buf.length, 5 + 256 * 8)  -- 1 code + 4 length + 256*8 bytes
  assert_eq(buf.bytes[1], 0x07)  -- DOUBLE_ARRAY32_LITTLE
end)

test("write_float_array: 300 elements (DOUBLE_ARRAY32)", function()
  local arr = {size = 300}
  for i = 1, 300 do
    arr[i] = i * 0.5
  end
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  assert_eq(buf.length, 5 + 300 * 8)
  assert_eq(buf.bytes[1], 0x07)
end)

test("write_float_array: infer size from #arr", function()
  local arr = {1.0, 2.0, 3.0}  -- size not specified, should use #arr
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  assert_eq(buf.length, 26)  -- 1 code + 1 length + 3*8 bytes
  assert_eq(buf.bytes[1], 0x0E)
  assert_eq(buf.bytes[2], 3)
end)

print()
print("Float Array Read Tests:")
print("--------------------------------------------------------------------")

test("read_float_array: empty array", function()
  local arr = {size = 0}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_float_array(str, 0)
  assert_eq(result.value.size, 0)
  assert_eq(result.bytes_read, 2)
end)

test("read_float_array: 1 element", function()
  local arr = {size = 1, [1] = 3.14}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_float_array(str, 0)
  assert_eq(result.value.size, 1)
  assert_near(result.value[1], 3.14, 1e-15)
  assert_eq(result.bytes_read, 10)
end)

test("read_float_array: 5 elements", function()
  local arr = {size = 5, [1] = 1.0, [2] = 2.0, [3] = 3.0, [4] = 4.0, [5] = 5.0}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_float_array(str, 0)
  assert_eq(result.value.size, 5)
  for i = 1, 5 do
    assert_near(result.value[i], i * 1.0, 1e-15)
  end
  assert_eq(result.bytes_read, 42)
end)

test("read_float_array: 255 elements (DOUBLE_ARRAY8 max)", function()
  local arr = {size = 255}
  for i = 1, 255 do
    arr[i] = i * 1.0
  end
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_float_array(str, 0)
  assert_eq(result.value.size, 255)
  assert_near(result.value[1], 1.0, 1e-15)
  assert_near(result.value[255], 255.0, 1e-15)
end)

test("read_float_array: 256 elements (DOUBLE_ARRAY32)", function()
  local arr = {size = 256}
  for i = 1, 256 do
    arr[i] = i * 1.0
  end
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_float_array(str, 0)
  assert_eq(result.value.size, 256)
  assert_near(result.value[1], 1.0, 1e-15)
  assert_near(result.value[256], 256.0, 1e-15)
end)

test("read_float_array: at offset", function()
  local arr = {size = 3, [1] = 1.5, [2] = 2.5, [3] = 3.5}
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0xFF)  -- Padding
  caml_marshal_buffer_write8u(buf, 0xFF)  -- Padding
  caml_marshal_write_float_array(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_float_array(str, 2)
  assert_eq(result.value.size, 3)
  assert_near(result.value[1], 1.5, 1e-15)
  assert_near(result.value[2], 2.5, 1e-15)
  assert_near(result.value[3], 3.5, 1e-15)
end)

print()
print("Float Array Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("roundtrip: DOUBLE_ARRAY8 boundary (0, 1, 255)", function()
  local sizes = {0, 1, 10, 100, 255}
  for _, size in ipairs(sizes) do
    local arr = {size = size}
    for i = 1, size do
      arr[i] = i * 0.1
    end
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_float_array(buf, arr)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_float_array(str, 0)
    assert_eq(result.value.size, size, "Size mismatch for " .. size)
    for i = 1, size do
      assert_near(result.value[i], i * 0.1, 1e-15, "Value mismatch at index " .. i)
    end
  end
end)

test("roundtrip: DOUBLE_ARRAY32 (256, 300)", function()
  local sizes = {256, 300}
  for _, size in ipairs(sizes) do
    local arr = {size = size}
    for i = 1, size do
      arr[i] = i * 0.25
    end
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_float_array(buf, arr)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_float_array(str, 0)
    assert_eq(result.value.size, size, "Size mismatch for " .. size)
    -- Check first, middle, and last elements
    assert_near(result.value[1], 0.25, 1e-15)
    assert_near(result.value[size], size * 0.25, 1e-14)
  end
end)

test("roundtrip: special values in array", function()
  local arr = {size = 5, [1] = 0.0, [2] = -1.0, [3] = math.huge, [4] = -math.huge, [5] = 3.14159}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_float_array(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_float_array(str, 0)
  assert_eq(result.value.size, 5)
  assert_eq(result.value[1], 0.0)
  assert_eq(result.value[2], -1.0)
  assert_eq(result.value[3], math.huge)
  assert_eq(result.value[4], -math.huge)
  assert_near(result.value[5], 3.14159, 1e-15)
end)

print()
print("Format Selection Tests:")
print("--------------------------------------------------------------------")

test("format: size < 256 uses DOUBLE_ARRAY8", function()
  for _, size in ipairs({0, 1, 10, 100, 255}) do
    local arr = {size = size}
    for i = 1, size do
      arr[i] = 0.0
    end
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_float_array(buf, arr)
    assert_eq(buf.bytes[1], 0x0E, "Size " .. size .. " should use DOUBLE_ARRAY8")
    assert_eq(buf.length, 2 + size * 8)
  end
end)

test("format: size >= 256 uses DOUBLE_ARRAY32", function()
  for _, size in ipairs({256, 300, 1000}) do
    local arr = {size = size}
    for i = 1, size do
      arr[i] = 0.0
    end
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_float_array(buf, arr)
    assert_eq(buf.bytes[1], 0x07, "Size " .. size .. " should use DOUBLE_ARRAY32")
    assert_eq(buf.length, 5 + size * 8)
  end
end)

print()
print("Error Handling Tests:")
print("--------------------------------------------------------------------")

test("read_double: invalid code", function()
  local str = string.char(0x99)  -- Invalid code
  local success = pcall(function()
    caml_marshal_read_double(str, 0)
  end)
  assert_true(not success, "Should error on invalid code")
end)

test("read_double: insufficient data", function()
  local str = string.char(0x0C, 0x00, 0x00, 0x00)  -- CODE_DOUBLE but only 3 bytes
  local success = pcall(function()
    caml_marshal_read_double(str, 0)
  end)
  assert_true(not success, "Should error on insufficient data")
end)

test("read_float_array: invalid code", function()
  local str = string.char(0x99)  -- Invalid code
  local success = pcall(function()
    caml_marshal_read_float_array(str, 0)
  end)
  assert_true(not success, "Should error on invalid code")
end)

test("read_float_array: insufficient data (DOUBLE_ARRAY8)", function()
  local str = string.char(0x0E, 10)  -- Length 10 but no data
  local success = pcall(function()
    caml_marshal_read_float_array(str, 0)
  end)
  assert_true(not success, "Should error on insufficient data")
end)

test("read_float_array: insufficient data (DOUBLE_ARRAY32)", function()
  local str = string.char(0x07, 0x00, 0x00, 0x01, 0x00)  -- Length 256 but no data
  local success = pcall(function()
    caml_marshal_read_float_array(str, 0)
  end)
  assert_true(not success, "Should error on insufficient data")
end)

test("write_float_array: non-number element", function()
  local arr = {size = 3, [1] = 1.0, [2] = "not a number", [3] = 3.0}
  local success = pcall(function()
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_float_array(buf, arr)
  end)
  assert_true(not success, "Should error on non-number element")
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
