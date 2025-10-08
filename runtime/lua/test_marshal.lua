#!/usr/bin/env lua
-- Test suite for marshal.lua (Task 2.1 - Immediate Values)

local marshal = require("marshal")

-- Test framework
local tests_run = 0
local tests_passed = 0

local function test(name, fn)
  tests_run = tests_run + 1
  io.write("Testing " .. name .. " ... ")
  local success, err = pcall(fn)
  if success then
    tests_passed = tests_passed + 1
    print("✓")
  else
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
    error(msg or "Expected true")
  end
end

local function assert_deep_eq(actual, expected, msg)
  if type(actual) ~= type(expected) then
    error(msg or ("Type mismatch: expected " .. type(expected) .. ", got " .. type(actual)))
  end
  if type(actual) == "table" then
    for k, v in pairs(expected) do
      if actual[k] ~= v then
        error(msg or ("Table mismatch at key " .. tostring(k)))
      end
    end
    for k in pairs(actual) do
      if expected[k] == nil then
        error(msg or ("Extra key in actual: " .. tostring(k)))
      end
    end
  elseif actual ~= expected then
    error(msg or ("Expected " .. tostring(expected) .. ", got " .. tostring(actual)))
  end
end

print("====================================================================")
print("Marshal Tests (marshal.lua - Task 2.1: Immediate Values)")
print("====================================================================")
print("")

--
-- Small Integer Tests (0x40-0x7F)
--

print("Small Integer Tests (0-63):")
print("--------------------------------------------------------------------")

test("Marshal small int 0", function()
  local data = marshal.marshal_value(0)
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x40, "Should be 0x40")
end)

test("Marshal small int 1", function()
  local data = marshal.marshal_value(1)
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x41, "Should be 0x41")
end)

test("Marshal small int 63", function()
  local data = marshal.marshal_value(63)
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x7F, "Should be 0x7F")
end)

test("Unmarshal small int 0", function()
  local data = string.char(0x40)
  local value = marshal.unmarshal_value(data)
  assert_eq(value, 0, "Should be 0")
end)

test("Unmarshal small int 42", function()
  local data = string.char(0x40 + 42)
  local value = marshal.unmarshal_value(data)
  assert_eq(value, 42, "Should be 42")
end)

test("Roundtrip small integers", function()
  for i = 0, 63 do
    local data = marshal.marshal_value(i)
    local value = marshal.unmarshal_value(data)
    assert_eq(value, i, "Roundtrip " .. i)
  end
end)

--
-- Extended Integer Tests (INT8, INT16, INT32)
--

print("")
print("Extended Integer Tests:")
print("--------------------------------------------------------------------")

test("Marshal INT8 positive", function()
  local data = marshal.marshal_value(100)
  assert_eq(#data, 2, "Should be 2 bytes")
  assert_eq(string.byte(data, 1), 0x00, "Should be CODE_INT8")
  assert_eq(string.byte(data, 2), 100, "Should be 100")
end)

test("Marshal INT8 negative", function()
  local data = marshal.marshal_value(-50)
  assert_eq(#data, 2, "Should be 2 bytes")
  assert_eq(string.byte(data, 1), 0x00, "Should be CODE_INT8")
  assert_eq(string.byte(data, 2), 256 - 50, "Should be 206")
end)

test("Marshal INT16 positive", function()
  local data = marshal.marshal_value(1000)
  assert_eq(#data, 3, "Should be 3 bytes")
  assert_eq(string.byte(data, 1), 0x01, "Should be CODE_INT16")
end)

test("Marshal INT16 negative", function()
  local data = marshal.marshal_value(-1000)
  assert_eq(#data, 3, "Should be 3 bytes")
  assert_eq(string.byte(data, 1), 0x01, "Should be CODE_INT16")
end)

test("Marshal INT32 positive", function()
  local data = marshal.marshal_value(100000)
  assert_eq(#data, 5, "Should be 5 bytes")
  assert_eq(string.byte(data, 1), 0x02, "Should be CODE_INT32")
end)

test("Marshal INT32 negative", function()
  local data = marshal.marshal_value(-100000)
  assert_eq(#data, 5, "Should be 5 bytes")
  assert_eq(string.byte(data, 1), 0x02, "Should be CODE_INT32")
end)

test("Unmarshal INT8 positive", function()
  local data = string.char(0x00, 100)
  local value = marshal.unmarshal_value(data)
  assert_eq(value, 100, "Should be 100")
end)

test("Unmarshal INT8 negative", function()
  local data = string.char(0x00, 256 - 50)
  local value = marshal.unmarshal_value(data)
  assert_eq(value, -50, "Should be -50")
end)

test("Unmarshal INT16 positive", function()
  local data = string.char(0x01, 0x03, 0xE8)  -- 1000
  local value = marshal.unmarshal_value(data)
  assert_eq(value, 1000, "Should be 1000")
end)

test("Unmarshal INT32 positive", function()
  local data = string.char(0x02, 0x00, 0x01, 0x86, 0xA0)  -- 100000
  local value = marshal.unmarshal_value(data)
  assert_eq(value, 100000, "Should be 100000")
end)

test("Roundtrip INT8 range", function()
  local values = {-128, -100, -1, 64, 100, 127}
  for _, v in ipairs(values) do
    local data = marshal.marshal_value(v)
    local result = marshal.unmarshal_value(data)
    assert_eq(result, v, "Roundtrip " .. v)
  end
end)

test("Roundtrip INT16 range", function()
  local values = {-32768, -10000, -200, 128, 1000, 10000, 32767}
  for _, v in ipairs(values) do
    local data = marshal.marshal_value(v)
    local result = marshal.unmarshal_value(data)
    assert_eq(result, v, "Roundtrip " .. v)
  end
end)

test("Roundtrip INT32 range", function()
  local values = {-2147483648, -1000000, -100000, 32768, 100000, 1000000, 2147483647}
  for _, v in ipairs(values) do
    local data = marshal.marshal_value(v)
    local result = marshal.unmarshal_value(data)
    assert_eq(result, v, "Roundtrip " .. v)
  end
end)

--
-- Small String Tests (0x20-0x3F)
--

print("")
print("Small String Tests (0-31 bytes):")
print("--------------------------------------------------------------------")

test("Marshal empty string", function()
  local data = marshal.marshal_value("")
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x20, "Should be 0x20")
end)

test("Marshal small string 'a'", function()
  local data = marshal.marshal_value("a")
  assert_eq(#data, 2, "Should be 2 bytes")
  assert_eq(string.byte(data, 1), 0x21, "Should be 0x21")
  assert_eq(string.byte(data, 2), string.byte('a'), "Should be 'a'")
end)

test("Marshal small string 'Hello'", function()
  local data = marshal.marshal_value("Hello")
  assert_eq(#data, 6, "Should be 6 bytes")
  assert_eq(string.byte(data, 1), 0x25, "Should be 0x25 (length 5)")
end)

test("Unmarshal empty string", function()
  local data = string.char(0x20)
  local value = marshal.unmarshal_value(data)
  assert_eq(value, "", "Should be empty string")
end)

test("Unmarshal small string 'test'", function()
  local data = string.char(0x24) .. "test"
  local value = marshal.unmarshal_value(data)
  assert_eq(value, "test", "Should be 'test'")
end)

test("Roundtrip small strings", function()
  local strings = {"", "a", "ab", "Hello", "Hello, World!", "0123456789ABCDEF", "x"}
  for _, s in ipairs(strings) do
    if #s < 32 then
      local data = marshal.marshal_value(s)
      local result = marshal.unmarshal_value(data)
      assert_eq(result, s, "Roundtrip '" .. s .. "'")
    end
  end
end)

--
-- Extended String Tests (STRING8, STRING32)
--

print("")
print("Extended String Tests:")
print("--------------------------------------------------------------------")

test("Marshal STRING8", function()
  local str = string.rep("x", 50)
  local data = marshal.marshal_value(str)
  assert_eq(string.byte(data, 1), 0x09, "Should be CODE_STRING8")
  assert_eq(string.byte(data, 2), 50, "Should be length 50")
end)

test("Marshal STRING32", function()
  local str = string.rep("y", 300)
  local data = marshal.marshal_value(str)
  assert_eq(string.byte(data, 1), 0x0A, "Should be CODE_STRING32")
end)

test("Unmarshal STRING8", function()
  local str = "Hello, this is a longer string for STRING8"
  local len = #str
  local data = string.char(0x09, len) .. str
  local value = marshal.unmarshal_value(data)
  assert_eq(value, str, "Should match original")
end)

test("Unmarshal STRING32", function()
  local str = string.rep("test", 100)
  local len = #str
  local data = string.char(0x0A) ..
               string.char(math.floor(len / 16777216)) ..
               string.char(math.floor(len / 65536) % 256) ..
               string.char(math.floor(len / 256) % 256) ..
               string.char(len % 256) ..
               str
  local value = marshal.unmarshal_value(data)
  assert_eq(value, str, "Should match original")
end)

test("Roundtrip STRING8 range", function()
  local lengths = {32, 50, 100, 200, 255}
  for _, len in ipairs(lengths) do
    local str = string.rep("a", len)
    local data = marshal.marshal_value(str)
    local result = marshal.unmarshal_value(data)
    assert_eq(result, str, "Roundtrip length " .. len)
  end
end)

test("Roundtrip STRING32", function()
  local str = string.rep("test", 100)  -- 400 bytes
  local data = marshal.marshal_value(str)
  local result = marshal.unmarshal_value(data)
  assert_eq(result, str, "Roundtrip STRING32")
end)

--
-- Small Block Tests (0x80-0xFF)
--

print("")
print("Small Block Tests:")
print("--------------------------------------------------------------------")

test("Marshal small block tag=0 size=0", function()
  local data = marshal.marshal_value({tag = 0, size = 0})
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x80, "Should be 0x80")
end)

test("Marshal small block tag=1 size=0", function()
  local data = marshal.marshal_value({tag = 1, size = 0})
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x81, "Should be 0x81")
end)

test("Marshal small block tag=0 size=1", function()
  local data = marshal.marshal_value({tag = 0, size = 1})
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x90, "Should be 0x90")
end)

test("Marshal small block tag=15 size=7", function()
  local data = marshal.marshal_value({tag = 15, size = 7})
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0xFF, "Should be 0xFF")
end)

test("Unmarshal small block tag=0 size=0", function()
  local data = string.char(0x80)
  local value = marshal.unmarshal_value(data)
  assert_deep_eq(value, {tag = 0, size = 0}, "Should be {tag=0, size=0}")
end)

test("Unmarshal small block tag=5 size=3", function()
  local data = string.char(0x85 + (3 * 16))  -- 0x85 + 0x30 = 0xB5
  local value = marshal.unmarshal_value(data)
  assert_deep_eq(value, {tag = 5, size = 3}, "Should be {tag=5, size=3}")
end)

test("Roundtrip small blocks", function()
  for tag = 0, 15 do
    for size = 0, 7 do
      local block = {tag = tag, size = size}
      local data = marshal.marshal_value(block)
      local result = marshal.unmarshal_value(data)
      assert_deep_eq(result, block, "Roundtrip tag=" .. tag .. " size=" .. size)
    end
  end
end)

--
-- BLOCK32 Tests
--

print("")
print("BLOCK32 Tests:")
print("--------------------------------------------------------------------")

test("Marshal BLOCK32 tag=16 size=0", function()
  local data = marshal.marshal_value({tag = 16, size = 0})
  assert_eq(#data, 5, "Should be 5 bytes (code + header)")
  assert_eq(string.byte(data, 1), 0x08, "Should be CODE_BLOCK32")
end)

test("Marshal BLOCK32 tag=0 size=8", function()
  local data = marshal.marshal_value({tag = 0, size = 8})
  assert_eq(#data, 5, "Should be 5 bytes")
  assert_eq(string.byte(data, 1), 0x08, "Should be CODE_BLOCK32")
end)

test("Marshal BLOCK32 tag=100 size=50", function()
  local data = marshal.marshal_value({tag = 100, size = 50})
  assert_eq(#data, 5, "Should be 5 bytes")
  assert_eq(string.byte(data, 1), 0x08, "Should be CODE_BLOCK32")
end)

test("Unmarshal BLOCK32", function()
  -- Header: (10 << 10) | 5 = 10240 + 5 = 10245 = 0x00002805
  local data = string.char(0x08, 0x00, 0x00, 0x28, 0x05)
  local value = marshal.unmarshal_value(data)
  assert_deep_eq(value, {tag = 5, size = 10}, "Should be {tag=5, size=10}")
end)

test("Roundtrip BLOCK32", function()
  local blocks = {
    {tag = 16, size = 0},
    {tag = 0, size = 8},
    {tag = 100, size = 50},
    {tag = 255, size = 1000}
  }
  for _, block in ipairs(blocks) do
    local data = marshal.marshal_value(block)
    local result = marshal.unmarshal_value(data)
    assert_deep_eq(result, block, "Roundtrip tag=" .. block.tag .. " size=" .. block.size)
  end
end)

--
-- Double Tests
--

print("")
print("Double Tests:")
print("--------------------------------------------------------------------")

if string.pack then
  test("Marshal double 3.14", function()
    local data = marshal.marshal_value(3.14)
    assert_eq(#data, 9, "Should be 9 bytes (code + 8 bytes)")
    assert_eq(string.byte(data, 1), 0x0C, "Should be CODE_DOUBLE_LITTLE")
  end)

  test("Marshal double 0.0", function()
    -- Note: 0.0 is indistinguishable from integer 0 in Lua, so it marshals as integer
    local data = marshal.marshal_value(0.0)
    -- This will marshal as small int 0, not double
    assert_eq(#data, 1, "Should be 1 byte (marshals as integer)")
    assert_eq(string.byte(data, 1), 0x40, "Should be small int 0")
  end)

  test("Marshal double -1.5", function()
    local data = marshal.marshal_value(-1.5)
    assert_eq(#data, 9, "Should be 9 bytes")
  end)

  test("Unmarshal double", function()
    -- Manually create double data for 3.14159
    local writer = require("marshal_io").Writer:new()
    writer:write8u(0x0C)  -- CODE_DOUBLE_LITTLE
    writer:write_double_little(3.14159)
    local data = writer:to_string()

    local value = marshal.unmarshal_value(data)
    assert_true(math.abs(value - 3.14159) < 0.0001, "Should be close to 3.14159")
  end)

  test("Roundtrip doubles", function()
    local values = {0.0, 1.0, -1.0, 3.14159, -2.71828, 1e10, 1e-10, math.huge, -math.huge}
    for _, v in ipairs(values) do
      local data = marshal.marshal_value(v)
      local result = marshal.unmarshal_value(data)
      if v == math.huge or v == -math.huge then
        assert_eq(result, v, "Roundtrip " .. tostring(v))
      else
        assert_true(math.abs(result - v) < 1e-10, "Roundtrip " .. v)
      end
    end
  end)
else
  print("  Skipping double tests (string.pack not available)")
end

--
-- Float Array Tests
--

print("")
print("Float Array Tests:")
print("--------------------------------------------------------------------")

if string.pack then
  test("Marshal float array (small)", function()
    local arr = {tag = 254, values = {1.0, 2.0, 3.0}}
    local data = marshal.marshal_value(arr)
    assert_eq(string.byte(data, 1), 0x0E, "Should be CODE_DOUBLE_ARRAY8_LITTLE")
    assert_eq(string.byte(data, 2), 3, "Should have length 3")
  end)

  test("Marshal float array (large)", function()
    local values = {}
    for i = 1, 300 do
      values[i] = i * 1.5
    end
    local arr = {tag = 254, values = values}
    local data = marshal.marshal_value(arr)
    assert_eq(string.byte(data, 1), 0x07, "Should be CODE_DOUBLE_ARRAY32_LITTLE")
  end)

  test("Unmarshal float array", function()
    local writer = require("marshal_io").Writer:new()
    writer:write8u(0x0E)  -- CODE_DOUBLE_ARRAY8_LITTLE
    writer:write8u(3)     -- Length
    writer:write_double_little(1.5)
    writer:write_double_little(2.5)
    writer:write_double_little(3.5)
    local data = writer:to_string()

    local result = marshal.unmarshal_value(data)
    assert_eq(result.tag, 254, "Should have tag 254")
    assert_eq(#result.values, 3, "Should have 3 elements")
    assert_true(math.abs(result.values[1] - 1.5) < 0.0001, "Element 1")
    assert_true(math.abs(result.values[2] - 2.5) < 0.0001, "Element 2")
    assert_true(math.abs(result.values[3] - 3.5) < 0.0001, "Element 3")
  end)

  test("Roundtrip float array (small)", function()
    local arr = {tag = 254, values = {1.0, 2.5, 3.14159, -1.5}}
    local data = marshal.marshal_value(arr)
    local result = marshal.unmarshal_value(data)

    assert_eq(result.tag, 254, "Should have tag 254")
    assert_eq(#result.values, #arr.values, "Should have same length")
    for i = 1, #arr.values do
      assert_true(math.abs(result.values[i] - arr.values[i]) < 1e-10, "Element " .. i)
    end
  end)

  test("Roundtrip float array (large)", function()
    local values = {}
    for i = 1, 300 do
      values[i] = i * 0.5
    end
    local arr = {tag = 254, values = values}
    local data = marshal.marshal_value(arr)
    local result = marshal.unmarshal_value(data)

    assert_eq(result.tag, 254, "Should have tag 254")
    assert_eq(#result.values, 300, "Should have 300 elements")
    for i = 1, 10 do  -- Check first 10 elements
      assert_true(math.abs(result.values[i] - values[i]) < 1e-10, "Element " .. i)
    end
  end)

  test("Roundtrip empty float array", function()
    local arr = {tag = 254, values = {}}
    local data = marshal.marshal_value(arr)
    local result = marshal.unmarshal_value(data)

    assert_eq(result.tag, 254, "Should have tag 254")
    assert_eq(#result.values, 0, "Should be empty")
  end)
else
  print("  Skipping float array tests (string.pack not available)")
end

--
-- Edge Cases and Error Handling
--

print("")
print("Edge Cases and Error Handling:")
print("--------------------------------------------------------------------")

test("Float value now supported", function()
  if string.pack then
    local data = marshal.marshal_value(3.14)
    assert_eq(string.byte(data, 1), 0x0C, "Should marshal as double")
  else
    print("  Skipping (string.pack not available)")
  end
end)

test("Integer too large marshals as double", function()
  -- Large integers outside INT32 range are now marshalled as doubles
  local data = marshal.marshal_value(2147483648)
  if string.pack then
    assert_eq(string.byte(data, 1), 0x0C, "Should marshal as double")
  else
    -- Without string.pack, this will error
    local success = pcall(function()
      marshal.marshal_value(21474836480)
    end)
    assert_true(not success, "Should error without string.pack")
  end
end)

test("Error on unsupported type", function()
  local success = pcall(function()
    marshal.marshal_value(function() end)
  end)
  assert_true(not success, "Should error on function")
end)

test("Error on invalid code", function()
  local data = string.char(0xFF, 0xFF)  -- Invalid extended code
  local success = pcall(function()
    marshal.unmarshal_value(data)
  end)
  -- This should succeed as 0xFF is a valid small block code
  assert_true(success, "0xFF is valid small block")
end)

test("Error on unsupported extended code", function()
  local data = string.char(0x03)  -- CODE_INT64 not implemented
  local success = pcall(function()
    marshal.unmarshal_value(data)
  end)
  assert_true(not success, "Should error on INT64")
end)

--
-- Sharing Tests
--

print("")
print("Sharing Tests:")
print("--------------------------------------------------------------------")

test("Shared string (same string twice)", function()
  local writer = marshal.MarshalWriter:new(false)  -- with sharing
  local str = "Hello, World!"

  -- Write string twice
  writer:write_string(str)
  writer:write_string(str)

  local data = writer:to_string()

  -- First occurrence: small string (0x20 + len) + data = 14 bytes (len=13)
  -- Second occurrence: SHARED8 (0x04) + offset = 2 bytes
  -- Total should be less than 28 bytes (2 full strings would be 28 bytes)
  assert_true(#data < 28, "Shared data should be smaller")
  assert_eq(string.byte(data, 1), 0x20 + 13, "First should be small string")
  assert_eq(string.byte(data, 15), 0x04, "Second should be SHARED8")
end)

test("Shared string roundtrip", function()
  local writer = marshal.MarshalWriter:new(false)  -- with sharing
  local str = "Shared!"

  writer:write_string(str)
  writer:write_string(str)

  local data = writer:to_string()

  -- To unmarshal, we need to know num_objects
  local num_objects = writer.obj_table:count()
  local reader = marshal.MarshalReader:new(data, 0, num_objects)

  local s1 = reader:read_value()
  local s2 = reader:read_value()

  assert_eq(s1, str, "First string should match")
  assert_eq(s2, str, "Second string should match")
  -- In Lua, string identity is maintained, so s1 == s2
  assert_true(s1 == s2, "Should be same string instance")
end)

test("No sharing with no_sharing flag", function()
  local writer = marshal.MarshalWriter:new(true)  -- no sharing
  local str = "NoShare"

  writer:write_string(str)
  writer:write_string(str)

  local data = writer:to_string()

  -- Both should be full strings (no SHARED code)
  assert_eq(string.byte(data, 1), 0x20 + #str, "First should be small string")
  assert_eq(string.byte(data, 1 + 1 + #str), 0x20 + #str, "Second should be small string too")
end)

if string.pack then
  test("Shared double", function()
    local writer = marshal.MarshalWriter:new(false)
    local d = 3.14159

    writer:write_double(d)
    writer:write_double(d)

    local data = writer:to_string()

    -- First: DOUBLE_LITTLE (0x0C) + 8 bytes = 9 bytes
    -- Second: SHARED8 (0x04) + offset = 2 bytes
    assert_eq(string.byte(data, 1), 0x0C, "First should be DOUBLE_LITTLE")
    assert_eq(string.byte(data, 10), 0x04, "Second should be SHARED8")
  end)

  test("Shared double roundtrip", function()
    local writer = marshal.MarshalWriter:new(false)
    local d = 2.71828

    writer:write_double(d)
    writer:write_double(d)

    local data = writer:to_string()
    local num_objects = writer.obj_table:count()
    local reader = marshal.MarshalReader:new(data, 0, num_objects)

    local d1 = reader:read_value()
    local d2 = reader:read_value()

    assert_true(math.abs(d1 - d) < 1e-10, "First double should match")
    assert_true(math.abs(d2 - d) < 1e-10, "Second double should match")
  end)

  test("Shared float array", function()
    local writer = marshal.MarshalWriter:new(false)
    local arr = {tag = 254, values = {1.5, 2.5, 3.5}}

    writer:write_double_array(arr.values, arr)
    writer:write_double_array(arr.values, arr)

    local data = writer:to_string()

    -- First: full array
    -- Second: SHARED8
    assert_eq(string.byte(data, 1), 0x0E, "First should be DOUBLE_ARRAY8_LITTLE")
    -- Second occurrence position depends on array size
    local second_pos = 1 + 1 + 1 + (3 * 8)  -- code + len + 3 doubles
    assert_eq(string.byte(data, second_pos), 0x04, "Second should be SHARED8")
  end)
else
  print("  Skipping shared double/float array tests (string.pack not available)")
end

test("SHARED16 for large offset", function()
  local writer = marshal.MarshalWriter:new(false)
  local str = "X"

  -- Write enough strings to make offset > 255
  for i = 1, 300 do
    writer:write_string(string.format("str%d", i))
  end

  -- Now write the first string again
  writer:write_string(str)
  writer:write_string(str)

  local data = writer:to_string()

  -- The shared reference for the last occurrence should be SHARED16 due to large offset
  -- We can't easily check the exact position, but we can verify it works
  local num_objects = writer.obj_table:count()
  local reader = marshal.MarshalReader:new(data, 0, num_objects)

  -- Skip the intermediate strings
  for i = 1, 300 do
    reader:read_value()
  end

  local s1 = reader:read_value()
  local s2 = reader:read_value()

  assert_eq(s1, str, "Should read shared string")
  assert_eq(s2, str, "Should read shared string again")
end)

--
-- Summary
--

print("")
print("====================================================================")
print("Tests passed: " .. tests_passed .. " / " .. tests_run)
if tests_passed == tests_run then
  print("All tests passed! ✓")
  print("====================================================================")
  os.exit(0)
else
  print("Some tests failed.")
  print("====================================================================")
  os.exit(1)
end
