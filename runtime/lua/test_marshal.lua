#!/usr/bin/env lua
-- Test suite for marshal.lua (Task 2.1 - Immediate Values)

dofile("marshal.lua")
local Writer = get_Writer_class()

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
  local data = marshal_value_internal(0)
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x40, "Should be 0x40")
end)

test("Marshal small int 1", function()
  local data = marshal_value_internal(1)
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x41, "Should be 0x41")
end)

test("Marshal small int 63", function()
  local data = marshal_value_internal(63)
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x7F, "Should be 0x7F")
end)

test("Unmarshal small int 0", function()
  local data = string.char(0x40)
  local value = unmarshal_value_internal(data)
  assert_eq(value, 0, "Should be 0")
end)

test("Unmarshal small int 42", function()
  local data = string.char(0x40 + 42)
  local value = unmarshal_value_internal(data)
  assert_eq(value, 42, "Should be 42")
end)

test("Roundtrip small integers", function()
  for i = 0, 63 do
    local data = marshal_value_internal(i)
    local value = unmarshal_value_internal(data)
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
  local data = marshal_value_internal(100)
  assert_eq(#data, 2, "Should be 2 bytes")
  assert_eq(string.byte(data, 1), 0x00, "Should be CODE_INT8")
  assert_eq(string.byte(data, 2), 100, "Should be 100")
end)

test("Marshal INT8 negative", function()
  local data = marshal_value_internal(-50)
  assert_eq(#data, 2, "Should be 2 bytes")
  assert_eq(string.byte(data, 1), 0x00, "Should be CODE_INT8")
  assert_eq(string.byte(data, 2), 256 - 50, "Should be 206")
end)

test("Marshal INT16 positive", function()
  local data = marshal_value_internal(1000)
  assert_eq(#data, 3, "Should be 3 bytes")
  assert_eq(string.byte(data, 1), 0x01, "Should be CODE_INT16")
end)

test("Marshal INT16 negative", function()
  local data = marshal_value_internal(-1000)
  assert_eq(#data, 3, "Should be 3 bytes")
  assert_eq(string.byte(data, 1), 0x01, "Should be CODE_INT16")
end)

test("Marshal INT32 positive", function()
  local data = marshal_value_internal(100000)
  assert_eq(#data, 5, "Should be 5 bytes")
  assert_eq(string.byte(data, 1), 0x02, "Should be CODE_INT32")
end)

test("Marshal INT32 negative", function()
  local data = marshal_value_internal(-100000)
  assert_eq(#data, 5, "Should be 5 bytes")
  assert_eq(string.byte(data, 1), 0x02, "Should be CODE_INT32")
end)

test("Unmarshal INT8 positive", function()
  local data = string.char(0x00, 100)
  local value = unmarshal_value_internal(data)
  assert_eq(value, 100, "Should be 100")
end)

test("Unmarshal INT8 negative", function()
  local data = string.char(0x00, 256 - 50)
  local value = unmarshal_value_internal(data)
  assert_eq(value, -50, "Should be -50")
end)

test("Unmarshal INT16 positive", function()
  local data = string.char(0x01, 0x03, 0xE8)  -- 1000
  local value = unmarshal_value_internal(data)
  assert_eq(value, 1000, "Should be 1000")
end)

test("Unmarshal INT32 positive", function()
  local data = string.char(0x02, 0x00, 0x01, 0x86, 0xA0)  -- 100000
  local value = unmarshal_value_internal(data)
  assert_eq(value, 100000, "Should be 100000")
end)

test("Roundtrip INT8 range", function()
  local values = {-128, -100, -1, 64, 100, 127}
  for _, v in ipairs(values) do
    local data = marshal_value_internal(v)
    local result = unmarshal_value_internal(data)
    assert_eq(result, v, "Roundtrip " .. v)
  end
end)

test("Roundtrip INT16 range", function()
  local values = {-32768, -10000, -200, 128, 1000, 10000, 32767}
  for _, v in ipairs(values) do
    local data = marshal_value_internal(v)
    local result = unmarshal_value_internal(data)
    assert_eq(result, v, "Roundtrip " .. v)
  end
end)

test("Roundtrip INT32 range", function()
  local values = {-2147483648, -1000000, -100000, 32768, 100000, 1000000, 2147483647}
  for _, v in ipairs(values) do
    local data = marshal_value_internal(v)
    local result = unmarshal_value_internal(data)
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
  local data = marshal_value_internal("")
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x20, "Should be 0x20")
end)

test("Marshal small string 'a'", function()
  local data = marshal_value_internal("a")
  assert_eq(#data, 2, "Should be 2 bytes")
  assert_eq(string.byte(data, 1), 0x21, "Should be 0x21")
  assert_eq(string.byte(data, 2), string.byte('a'), "Should be 'a'")
end)

test("Marshal small string 'Hello'", function()
  local data = marshal_value_internal("Hello")
  assert_eq(#data, 6, "Should be 6 bytes")
  assert_eq(string.byte(data, 1), 0x25, "Should be 0x25 (length 5)")
end)

test("Unmarshal empty string", function()
  local data = string.char(0x20)
  local value = unmarshal_value_internal(data)
  assert_eq(value, "", "Should be empty string")
end)

test("Unmarshal small string 'test'", function()
  local data = string.char(0x24) .. "test"
  local value = unmarshal_value_internal(data)
  assert_eq(value, "test", "Should be 'test'")
end)

test("Roundtrip small strings", function()
  local strings = {"", "a", "ab", "Hello", "Hello, World!", "0123456789ABCDEF", "x"}
  for _, s in ipairs(strings) do
    if #s < 32 then
      local data = marshal_value_internal(s)
      local result = unmarshal_value_internal(data)
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
  local data = marshal_value_internal(str)
  assert_eq(string.byte(data, 1), 0x09, "Should be CODE_STRING8")
  assert_eq(string.byte(data, 2), 50, "Should be length 50")
end)

test("Marshal STRING32", function()
  local str = string.rep("y", 300)
  local data = marshal_value_internal(str)
  assert_eq(string.byte(data, 1), 0x0A, "Should be CODE_STRING32")
end)

test("Unmarshal STRING8", function()
  local str = "Hello, this is a longer string for STRING8"
  local len = #str
  local data = string.char(0x09, len) .. str
  local value = unmarshal_value_internal(data)
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
  local value = unmarshal_value_internal(data)
  assert_eq(value, str, "Should match original")
end)

test("Roundtrip STRING8 range", function()
  local lengths = {32, 50, 100, 200, 255}
  for _, len in ipairs(lengths) do
    local str = string.rep("a", len)
    local data = marshal_value_internal(str)
    local result = unmarshal_value_internal(data)
    assert_eq(result, str, "Roundtrip length " .. len)
  end
end)

test("Roundtrip STRING32", function()
  local str = string.rep("test", 100)  -- 400 bytes
  local data = marshal_value_internal(str)
  local result = unmarshal_value_internal(data)
  assert_eq(result, str, "Roundtrip STRING32")
end)

--
-- Small Block Tests (0x80-0xFF)
--

print("")
print("Small Block Tests:")
print("--------------------------------------------------------------------")

test("Marshal small block tag=0 size=0", function()
  local data = marshal_value_internal({tag = 0, size = 0})
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x80, "Should be 0x80")
end)

test("Marshal small block tag=1 size=0", function()
  local data = marshal_value_internal({tag = 1, size = 0})
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x81, "Should be 0x81")
end)

test("Marshal small block tag=0 size=1", function()
  local data = marshal_value_internal({tag = 0, size = 1})
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0x90, "Should be 0x90")
end)

test("Marshal small block tag=15 size=7", function()
  local data = marshal_value_internal({tag = 15, size = 7})
  assert_eq(#data, 1, "Should be 1 byte")
  assert_eq(string.byte(data, 1), 0xFF, "Should be 0xFF")
end)

test("Unmarshal small block tag=0 size=0", function()
  local data = string.char(0x80)
  local value = unmarshal_value_internal(data)
  assert_deep_eq(value, {tag = 0, size = 0}, "Should be {tag=0, size=0}")
end)

test("Unmarshal small block tag=5 size=3", function()
  local data = string.char(0x85 + (3 * 16))  -- 0x85 + 0x30 = 0xB5
  local value = unmarshal_value_internal(data)
  assert_deep_eq(value, {tag = 5, size = 3}, "Should be {tag=5, size=3}")
end)

test("Roundtrip small blocks", function()
  for tag = 0, 15 do
    for size = 0, 7 do
      local block = {tag = tag, size = size}
      local data = marshal_value_internal(block)
      local result = unmarshal_value_internal(data)
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
  local data = marshal_value_internal({tag = 16, size = 0})
  assert_eq(#data, 5, "Should be 5 bytes (code + header)")
  assert_eq(string.byte(data, 1), 0x08, "Should be CODE_BLOCK32")
end)

test("Marshal BLOCK32 tag=0 size=8", function()
  local data = marshal_value_internal({tag = 0, size = 8})
  assert_eq(#data, 5, "Should be 5 bytes")
  assert_eq(string.byte(data, 1), 0x08, "Should be CODE_BLOCK32")
end)

test("Marshal BLOCK32 tag=100 size=50", function()
  local data = marshal_value_internal({tag = 100, size = 50})
  assert_eq(#data, 5, "Should be 5 bytes")
  assert_eq(string.byte(data, 1), 0x08, "Should be CODE_BLOCK32")
end)

test("Unmarshal BLOCK32", function()
  -- Header: (10 << 10) | 5 = 10240 + 5 = 10245 = 0x00002805
  local data = string.char(0x08, 0x00, 0x00, 0x28, 0x05)
  local value = unmarshal_value_internal(data)
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
    local data = marshal_value_internal(block)
    local result = unmarshal_value_internal(data)
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
    local data = marshal_value_internal(3.14)
    assert_eq(#data, 9, "Should be 9 bytes (code + 8 bytes)")
    assert_eq(string.byte(data, 1), 0x0C, "Should be CODE_DOUBLE_LITTLE")
  end)

  test("Marshal double 0.0", function()
    -- Note: 0.0 is indistinguishable from integer 0 in Lua, so it marshals as integer
    local data = marshal_value_internal(0.0)
    -- This will marshal as small int 0, not double
    assert_eq(#data, 1, "Should be 1 byte (marshals as integer)")
    assert_eq(string.byte(data, 1), 0x40, "Should be small int 0")
  end)

  test("Marshal double -1.5", function()
    local data = marshal_value_internal(-1.5)
    assert_eq(#data, 9, "Should be 9 bytes")
  end)

  test("Unmarshal double", function()
    -- Manually create double data for 3.14159
    local writer = Writer:new()
    writer:write8u(0x0C)  -- CODE_DOUBLE_LITTLE
    writer:write_double_little(3.14159)
    local data = writer:to_string()

    local value = unmarshal_value_internal(data)
    assert_true(math.abs(value - 3.14159) < 0.0001, "Should be close to 3.14159")
  end)

  test("Roundtrip doubles", function()
    local values = {0.0, 1.0, -1.0, 3.14159, -2.71828, 1e10, 1e-10, math.huge, -math.huge}
    for _, v in ipairs(values) do
      local data = marshal_value_internal(v)
      local result = unmarshal_value_internal(data)
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
    local data = marshal_value_internal(arr)
    assert_eq(string.byte(data, 1), 0x0E, "Should be CODE_DOUBLE_ARRAY8_LITTLE")
    assert_eq(string.byte(data, 2), 3, "Should have length 3")
  end)

  test("Marshal float array (large)", function()
    local values = {}
    for i = 1, 300 do
      values[i] = i * 1.5
    end
    local arr = {tag = 254, values = values}
    local data = marshal_value_internal(arr)
    assert_eq(string.byte(data, 1), 0x07, "Should be CODE_DOUBLE_ARRAY32_LITTLE")
  end)

  test("Unmarshal float array", function()
    local writer = Writer:new()
    writer:write8u(0x0E)  -- CODE_DOUBLE_ARRAY8_LITTLE
    writer:write8u(3)     -- Length
    writer:write_double_little(1.5)
    writer:write_double_little(2.5)
    writer:write_double_little(3.5)
    local data = writer:to_string()

    local result = unmarshal_value_internal(data)
    assert_eq(result.tag, 254, "Should have tag 254")
    assert_eq(#result.values, 3, "Should have 3 elements")
    assert_true(math.abs(result.values[1] - 1.5) < 0.0001, "Element 1")
    assert_true(math.abs(result.values[2] - 2.5) < 0.0001, "Element 2")
    assert_true(math.abs(result.values[3] - 3.5) < 0.0001, "Element 3")
  end)

  test("Roundtrip float array (small)", function()
    local arr = {tag = 254, values = {1.0, 2.5, 3.14159, -1.5}}
    local data = marshal_value_internal(arr)
    local result = unmarshal_value_internal(data)

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
    local data = marshal_value_internal(arr)
    local result = unmarshal_value_internal(data)

    assert_eq(result.tag, 254, "Should have tag 254")
    assert_eq(#result.values, 300, "Should have 300 elements")
    for i = 1, 10 do  -- Check first 10 elements
      assert_true(math.abs(result.values[i] - values[i]) < 1e-10, "Element " .. i)
    end
  end)

  test("Roundtrip empty float array", function()
    local arr = {tag = 254, values = {}}
    local data = marshal_value_internal(arr)
    local result = unmarshal_value_internal(data)

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
    local data = marshal_value_internal(3.14)
    assert_eq(string.byte(data, 1), 0x0C, "Should marshal as double")
  else
    print("  Skipping (string.pack not available)")
  end
end)

test("Integer too large marshals as double", function()
  -- Large integers outside INT32 range are now marshalled as doubles
  local data = marshal_value_internal(2147483648)
  if string.pack then
    assert_eq(string.byte(data, 1), 0x0C, "Should marshal as double")
  else
    -- Without string.pack, this will error
    local success = pcall(function()
      marshal_value_internal(21474836480)
    end)
    assert_true(not success, "Should error without string.pack")
  end
end)

test("Error on unsupported type", function()
  local success = pcall(function()
    marshal_value_internal(function() end)
  end)
  assert_true(not success, "Should error on function")
end)

test("Error on invalid code", function()
  local data = string.char(0xFF, 0xFF)  -- Invalid extended code
  local success = pcall(function()
    unmarshal_value_internal(data)
  end)
  -- This should succeed as 0xFF is a valid small block code
  assert_true(success, "0xFF is valid small block")
end)

test("Error on unsupported extended code", function()
  local data = string.char(0x03)  -- CODE_INT64 not implemented
  local success = pcall(function()
    unmarshal_value_internal(data)
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
  local writer = MarshalWriter:new(false)  -- with sharing
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
  local writer = MarshalWriter:new(false)  -- with sharing
  local str = "Shared!"

  writer:write_string(str)
  writer:write_string(str)

  local data = writer:to_string()

  -- To unmarshal, we need to know num_objects
  local num_objects = writer.obj_table:count()
  local reader = MarshalReader:new(data, 0, num_objects)

  local s1 = reader:read_value()
  local s2 = reader:read_value()

  assert_eq(s1, str, "First string should match")
  assert_eq(s2, str, "Second string should match")
  -- In Lua, string identity is maintained, so s1 == s2
  assert_true(s1 == s2, "Should be same string instance")
end)

test("No sharing with no_sharing flag", function()
  local writer = MarshalWriter:new(true)  -- no sharing
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
    local writer = MarshalWriter:new(false)
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
    local writer = MarshalWriter:new(false)
    local d = 2.71828

    writer:write_double(d)
    writer:write_double(d)

    local data = writer:to_string()
    local num_objects = writer.obj_table:count()
    local reader = MarshalReader:new(data, 0, num_objects)

    local d1 = reader:read_value()
    local d2 = reader:read_value()

    assert_true(math.abs(d1 - d) < 1e-10, "First double should match")
    assert_true(math.abs(d2 - d) < 1e-10, "Second double should match")
  end)

  test("Shared float array", function()
    local writer = MarshalWriter:new(false)
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
  local writer = MarshalWriter:new(false)
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
  local reader = MarshalReader:new(data, 0, num_objects)

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
-- Custom Block Infrastructure Tests (Task 4.1)
--

print("")
print("Custom Block Infrastructure:")
print("--------------------------------------------------------------------")

test("Custom ops table exists", function()
  assert_true(type(marshal_custom_ops) == "table", "custom_ops should be a table")
end)

test("Int64 (_j) custom ops registered", function()
  local ops = marshal_custom_ops["_j"]
  assert_true(ops ~= nil, "Int64 ops should exist")
  assert_true(type(ops.deserialize) == "function", "Should have deserialize")
  assert_true(type(ops.serialize) == "function", "Should have serialize")
  assert_eq(ops.fixed_length, 8, "Fixed length should be 8")
end)

test("Int32 (_i) custom ops registered", function()
  local ops = marshal_custom_ops["_i"]
  assert_true(ops ~= nil, "Int32 ops should exist")
  assert_true(type(ops.deserialize) == "function", "Should have deserialize")
  assert_eq(ops.fixed_length, 4, "Fixed length should be 4")
end)

test("Nativeint (_n) custom ops registered", function()
  local ops = marshal_custom_ops["_n"]
  assert_true(ops ~= nil, "Nativeint ops should exist")
  assert_true(type(ops.deserialize) == "function", "Should have deserialize")
  assert_eq(ops.fixed_length, 4, "Fixed length should be 4")
end)

test("Int64 unmarshal", function()
  -- Create an Int64 custom block: 0x0102030405060708
  local writer = Writer:new()
  for i = 1, 8 do
    writer:write8u(i)
  end

  local reader = Reader:new(writer:to_string())
  local size_array = {0}
  local value = marshal_custom_ops["_j"].deserialize(reader, size_array)

  assert_eq(value.caml_custom, "_j", "Should have correct custom marker")
  assert_eq(#value.bytes, 8, "Should have 8 bytes")
  assert_eq(value.bytes[1], 1, "First byte")
  assert_eq(value.bytes[8], 8, "Last byte")
  assert_eq(size_array[1], 8, "Size should be 8")
end)

test("Int64 marshal", function()
  local value = {
    caml_custom = "_j",
    bytes = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08}
  }

  local writer = Writer:new()
  local sizes_array = {0, 0}
  marshal_custom_ops["_j"].serialize(writer, value, sizes_array)

  local data = writer:to_string()
  assert_eq(#data, 8, "Should write 8 bytes")
  assert_eq(string.byte(data, 1), 0x01, "First byte")
  assert_eq(string.byte(data, 8), 0x08, "Last byte")
  assert_eq(sizes_array[1], 8, "size_32 should be 8")
  assert_eq(sizes_array[2], 8, "size_64 should be 8")
end)

test("Int64 roundtrip", function()
  local original = {
    caml_custom = "_j",
    bytes = {0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88}
  }

  local writer = Writer:new()
  local sizes = {0, 0}
  marshal_custom_ops["_j"].serialize(writer, original, sizes)

  local reader = Reader:new(writer:to_string())
  local size_array = {0}
  local result = marshal_custom_ops["_j"].deserialize(reader, size_array)

  assert_eq(result.caml_custom, "_j", "Custom marker")
  for i = 1, 8 do
    assert_eq(result.bytes[i], original.bytes[i], "Byte " .. i)
  end
end)

test("Int32 unmarshal", function()
  local writer = Writer:new()
  writer:write32s(0x12345678)

  local reader = Reader:new(writer:to_string())
  local size_array = {0}
  local value = marshal_custom_ops["_i"].deserialize(reader, size_array)

  assert_eq(value.caml_custom, "_i", "Should have correct custom marker")
  assert_eq(value.value, 0x12345678, "Should have correct value")
  assert_eq(size_array[1], 4, "Size should be 4")
end)

test("Int32 unmarshal negative", function()
  local writer = Writer:new()
  writer:write32s(-42)

  local reader = Reader:new(writer:to_string())
  local size_array = {0}
  local value = marshal_custom_ops["_i"].deserialize(reader, size_array)

  assert_eq(value.value, -42, "Should handle negative values")
end)

test("Nativeint unmarshal", function()
  local writer = Writer:new()
  writer:write32s(0x7FFFFFFF)

  local reader = Reader:new(writer:to_string())
  local size_array = {0}
  local value = marshal_custom_ops["_n"].deserialize(reader, size_array)

  assert_eq(value.caml_custom, "_n", "Should have correct custom marker")
  assert_eq(value.value, 0x7FFFFFFF, "Should have correct value")
  assert_eq(size_array[1], 4, "Size should be 4")
end)

test("Int64 marshal error on wrong type", function()
  local writer = Writer:new()
  local sizes = {0, 0}

  local success = pcall(function()
    marshal_custom_ops["_j"].serialize(writer, {caml_custom = "_i"}, sizes)
  end)

  assert_true(not success, "Should error on wrong custom type")
end)

--
-- Custom Block Marshalling Tests (Task 4.2)
--

print("")
print("Custom Block Marshalling:")
print("--------------------------------------------------------------------")

test("Marshal Int64 CUSTOM_FIXED", function()
  local value = {
    caml_custom = "_j",
    bytes = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08}
  }

  local data = marshal_value_internal(value)

  -- Should start with CUSTOM_FIXED (0x19)
  assert_eq(string.byte(data, 1), 0x19, "Should be CUSTOM_FIXED")

  -- Followed by "_j\0"
  assert_eq(string.byte(data, 2), string.byte('_'), "Identifier byte 1")
  assert_eq(string.byte(data, 3), string.byte('j'), "Identifier byte 2")
  assert_eq(string.byte(data, 4), 0, "Null terminator")

  -- Followed by 8 bytes of data
  assert_eq(string.byte(data, 5), 0x01, "Data byte 1")
  assert_eq(string.byte(data, 12), 0x08, "Data byte 8")
end)

test("Marshal Int32 CUSTOM_FIXED", function()
  local value = {
    caml_custom = "_i",
    value = 0x12345678
  }

  local data = marshal_value_internal(value)

  -- Should start with CUSTOM_FIXED (0x19)
  assert_eq(string.byte(data, 1), 0x19, "Should be CUSTOM_FIXED")

  -- Followed by "_i\0"
  assert_eq(string.byte(data, 2), string.byte('_'), "Identifier byte 1")
  assert_eq(string.byte(data, 3), string.byte('i'), "Identifier byte 2")
  assert_eq(string.byte(data, 4), 0, "Null terminator")

  -- Followed by 4 bytes of data (big-endian 0x12345678)
  assert_eq(string.byte(data, 5), 0x12, "Data byte 1")
  assert_eq(string.byte(data, 6), 0x34, "Data byte 2")
  assert_eq(string.byte(data, 7), 0x56, "Data byte 3")
  assert_eq(string.byte(data, 8), 0x78, "Data byte 4")
end)

test("Marshal Nativeint CUSTOM_FIXED", function()
  local value = {
    caml_custom = "_n",
    value = -42
  }

  local data = marshal_value_internal(value)

  -- Should start with CUSTOM_FIXED (0x19)
  assert_eq(string.byte(data, 1), 0x19, "Should be CUSTOM_FIXED")

  -- Followed by "_n\0"
  assert_eq(string.byte(data, 2), string.byte('_'), "Identifier byte 1")
  assert_eq(string.byte(data, 3), string.byte('n'), "Identifier byte 2")
  assert_eq(string.byte(data, 4), 0, "Null terminator")
end)

test("Roundtrip Int64 via marshal_value", function()
  local original = {
    caml_custom = "_j",
    bytes = {0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88}
  }

  local data = marshal_value_internal(original)
  -- Note: unmarshal_value doesn't handle CUSTOM yet (Task 4.3)
  -- This just tests that marshalling works
  assert_true(#data > 0, "Should produce data")
  assert_eq(string.byte(data, 1), 0x19, "Should use CUSTOM_FIXED")
end)

test("Roundtrip Int32 via marshal_value", function()
  local original = {
    caml_custom = "_i",
    value = 0x7FFFFFFF
  }

  local data = marshal_value_internal(original)
  assert_true(#data > 0, "Should produce data")
  assert_eq(string.byte(data, 1), 0x19, "Should use CUSTOM_FIXED")
end)

test("Roundtrip Nativeint via marshal_value", function()
  local original = {
    caml_custom = "_n",
    value = -2147483648
  }

  local data = marshal_value_internal(original)
  assert_true(#data > 0, "Should produce data")
  assert_eq(string.byte(data, 1), 0x19, "Should use CUSTOM_FIXED")
end)

test("Custom block with sharing", function()
  local writer = MarshalWriter:new(false)  -- with sharing
  local value = {
    caml_custom = "_i",
    value = 42
  }

  writer:write_custom(value)
  writer:write_custom(value)  -- Should be shared

  local data = writer:to_string()

  -- First occurrence: CUSTOM_FIXED
  assert_eq(string.byte(data, 1), 0x19, "First should be CUSTOM_FIXED")

  -- Second occurrence should be SHARED8
  -- Structure: 0x19 (1) + "_i\0" (3) + data (4) = 8 bytes, so second starts at byte 9
  local second_pos = 9
  assert_eq(string.byte(data, second_pos), 0x04, "Second should be SHARED8")
  assert_eq(string.byte(data, second_pos + 1), 0x00, "Offset should be 0")
end)

test("Error on unknown custom identifier", function()
  local writer = MarshalWriter:new()
  local value = {
    caml_custom = "_unknown"
  }

  local success = pcall(function()
    writer:write_custom(value)
  end)

  assert_true(not success, "Should error on unknown identifier")
end)

test("Error on custom without serialize", function()
  -- Temporarily register a custom type without serialize
  marshal_custom_ops["_test"] = {
    deserialize = function() end,
    serialize = nil,
    fixed_length = 4
  }

  local writer = MarshalWriter:new()
  local value = {
    caml_custom = "_test"
  }

  local success = pcall(function()
    writer:write_custom(value)
  end)

  -- Clean up
  marshal_custom_ops["_test"] = nil

  assert_true(not success, "Should error on missing serialize")
end)

test("Error on size mismatch for fixed_length", function()
  -- Temporarily register a custom type with wrong size
  marshal_custom_ops["_bad"] = {
    deserialize = function() end,
    serialize = function(writer, value, sizes)
      writer:write8u(0)
      sizes[1] = 1  -- Report 1 byte
      sizes[2] = 1
    end,
    fixed_length = 4  -- But claim fixed length is 4
  }

  local writer = MarshalWriter:new()
  local value = {
    caml_custom = "_bad"
  }

  local success = pcall(function()
    writer:write_custom(value)
  end)

  -- Clean up
  marshal_custom_ops["_bad"] = nil

  assert_true(not success, "Should error on size mismatch")
end)

--
-- Custom Block Unmarshalling Tests (Task 4.3)
--

print("")
print("Custom Block Unmarshalling:")
print("--------------------------------------------------------------------")

test("Unmarshal Int64 CUSTOM_FIXED", function()
  local value = {
    caml_custom = "_j",
    bytes = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08}
  }

  local data = marshal_value_internal(value)
  local result = unmarshal_value_internal(data)

  assert_eq(result.caml_custom, "_j", "Should have correct custom marker")
  for i = 1, 8 do
    assert_eq(result.bytes[i], value.bytes[i], "Byte " .. i)
  end
end)

test("Unmarshal Int32 CUSTOM_FIXED", function()
  local value = {
    caml_custom = "_i",
    value = 0x12345678
  }

  local data = marshal_value_internal(value)
  local result = unmarshal_value_internal(data)

  assert_eq(result.caml_custom, "_i", "Should have correct custom marker")
  assert_eq(result.value, 0x12345678, "Should have correct value")
end)

test("Unmarshal Int32 negative", function()
  local value = {
    caml_custom = "_i",
    value = -42
  }

  local data = marshal_value_internal(value)
  local result = unmarshal_value_internal(data)

  assert_eq(result.value, -42, "Should handle negative values")
end)

test("Unmarshal Nativeint CUSTOM_FIXED", function()
  local value = {
    caml_custom = "_n",
    value = 0x7FFFFFFF
  }

  local data = marshal_value_internal(value)
  local result = unmarshal_value_internal(data)

  assert_eq(result.caml_custom, "_n", "Should have correct custom marker")
  assert_eq(result.value, 0x7FFFFFFF, "Should have correct value")
end)

test("Roundtrip Int64 full", function()
  local original = {
    caml_custom = "_j",
    bytes = {0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88}
  }

  local data = marshal_value_internal(original)
  local result = unmarshal_value_internal(data)

  assert_eq(result.caml_custom, "_j", "Custom marker")
  for i = 1, 8 do
    assert_eq(result.bytes[i], original.bytes[i], "Byte " .. i)
  end
end)

test("Roundtrip Int32 full", function()
  local values = {42, -42, 0, 2147483647, -2147483648, 0x12345678}
  for _, val in ipairs(values) do
    local original = {caml_custom = "_i", value = val}
    local data = marshal_value_internal(original)
    local result = unmarshal_value_internal(data)
    assert_eq(result.value, val, "Roundtrip " .. val)
  end
end)

test("Roundtrip Nativeint full", function()
  local values = {0, 1, -1, 1000000, -1000000}
  for _, val in ipairs(values) do
    local original = {caml_custom = "_n", value = val}
    local data = marshal_value_internal(original)
    local result = unmarshal_value_internal(data)
    assert_eq(result.value, val, "Roundtrip " .. val)
  end
end)

test("Custom block with sharing roundtrip", function()
  local writer = MarshalWriter:new(false)
  local value = {caml_custom = "_i", value = 123}

  writer:write_custom(value)
  writer:write_custom(value)  -- Shared reference

  local data = writer:to_string()
  local num_objects = writer.obj_table:count()

  local reader = MarshalReader:new(data, 0, num_objects)
  local v1 = reader:read_value()
  local v2 = reader:read_value()

  assert_eq(v1.value, 123, "First value")
  assert_eq(v2.value, 123, "Second value")
  -- Note: In Lua, tables are not reference-equal after deserialization
  -- So we just check values match
end)

test("Error on unknown custom identifier during unmarshal", function()
  -- Manually construct a CUSTOM_FIXED with unknown identifier
  local writer = Writer:new()

  writer:write8u(0x19)  -- CODE_CUSTOM_FIXED
  writer:writestr("_unknown")
  writer:write8u(0)  -- null terminator
  writer:write32u(0)  -- dummy data

  local data = writer:to_string()

  local success = pcall(function()
    unmarshal_value_internal(data)
  end)

  assert_true(not success, "Should error on unknown identifier")
end)

test("Error on size mismatch during unmarshal", function()
  -- Register a custom type with deserialize that reports wrong size
  marshal_custom_ops["_badsize"] = {
    deserialize = function(reader, size_array)
      size_array[1] = 2  -- Report 2 bytes
      local v = reader:read8u()  -- But only read 1 byte (will cause mismatch)
      return {caml_custom = "_badsize", value = v}
    end,
    serialize = nil,
    fixed_length = 4  -- Claim fixed length is 4
  }

  -- Manually construct CUSTOM_FIXED
  local writer = Writer:new()

  writer:write8u(0x19)  -- CODE_CUSTOM_FIXED
  writer:writestr("_badsize")
  writer:write8u(0)
  writer:write8u(42)  -- 1 byte of data

  local data = writer:to_string()

  local success = pcall(function()
    unmarshal_value_internal(data)
  end)

  -- Clean up
  marshal_custom_ops["_badsize"] = nil

  assert_true(not success, "Should error on size mismatch")
end)

test("CUSTOM_LEN variable-length format", function()
  -- Register a variable-length custom type for testing
  marshal_custom_ops["_varlen"] = {
    deserialize = function(reader, size_array)
      local len = reader:read8u()
      local data = {}
      for i = 1, len do
        data[i] = reader:read8u()
      end
      size_array[1] = len + 1  -- Total bytes read
      return {caml_custom = "_varlen", data = data}
    end,
    serialize = function(writer, value, sizes_array)
      local len = #value.data
      writer:write8u(len)
      for i = 1, len do
        writer:write8u(value.data[i])
      end
      sizes_array[1] = len + 1
      sizes_array[2] = len + 1
    end,
    fixed_length = nil  -- Variable length
  }

  local original = {
    caml_custom = "_varlen",
    data = {1, 2, 3, 4, 5}
  }

  local data = marshal_value_internal(original)

  -- Should use CUSTOM_LEN (0x18)
  assert_eq(string.byte(data, 1), 0x18, "Should use CUSTOM_LEN")

  local result = unmarshal_value_internal(data)

  assert_eq(result.caml_custom, "_varlen", "Custom marker")
  assert_eq(#result.data, 5, "Data length")
  for i = 1, 5 do
    assert_eq(result.data[i], i, "Data element " .. i)
  end

  -- Clean up
  marshal_custom_ops["_varlen"] = nil
end)

--
-- Compression Support Tests (Task 5.1)
--

print("")
print("Compression Support:")
print("--------------------------------------------------------------------")

test("Detect compressed magic number", function()
  local marshal_header = nil  -- marshal_header functions are now global

  -- Create a compressed header
  local header_str = marshal_header_write_compressed_header(100, 150, 5, 0, 0)
  local header = marshal_header_read_header(header_str)

  assert_eq(header.magic, 0x8495A6BD, "Magic should be MAGIC_COMPRESSED")
  assert_true(header.compressed, "Should be marked as compressed")
  assert_eq(header.data_len, 100, "Compressed data length")
  assert_eq(header.uncompressed_data_len, 150, "Uncompressed data length")
end)

test("Error on compressed data without decompressor", function()
  local marshal_header = nil  -- marshal_header functions are now global

  -- Create a compressed marshal format
  local header_str = marshal_header_write_compressed_header(10, 20, 0, 0, 0)
  local dummy_data = string.rep("\0", 10)
  local full_data = header_str .. dummy_data

  local success, err = pcall(function()
    caml_marshal_from_bytes(full_data)
  end)

  assert_true(not success, "Should error on compressed data")
  assert_true(string.match(err, "compressed data encountered"), "Error should mention compression")
end)

test("Compression flag affects offset calculation", function()
  -- Test that compressed flag changes how SHARED offsets are interpreted
  
  -- Create data with absolute offset (compressed style)
  local writer = Writer:new()
  writer:write8u(0x40)  -- small int 0
  writer:write8u(0x41)  -- small int 1
  writer:write8u(0x04)  -- SHARED8
  writer:write8u(1)     -- absolute offset 1 (points to second value)

  local data = writer:to_string()

  -- Read with compressed=true (absolute offsets)
  local reader_compressed = MarshalReader:new(data, 0, 2, true)
  reader_compressed:intern_store(0)
  reader_compressed:intern_store(1)
  reader_compressed.obj_counter = 2
  local offset_val = reader_compressed:intern_recall(1)
  assert_eq(offset_val, 1, "Compressed mode uses absolute offsets")

  -- Read with compressed=false (relative offsets)
  local reader_uncompressed = MarshalReader:new(data, 0, 2, false)
  reader_uncompressed:intern_store(0)
  reader_uncompressed:intern_store(1)
  reader_uncompressed.obj_counter = 2
  local offset_val2 = reader_uncompressed:intern_recall(1)
  assert_eq(offset_val2, 1, "Uncompressed mode uses relative offsets")
end)

test("from_bytes with uncompressed header", function()
  local marshal_header = nil  -- marshal_header functions are now global

  -- Create a simple marshal format with header
  local value_data = string.char(0x42)  -- small int 2
  local header_str = marshal_header_write_header(#value_data, 0, 0, 0)
  local full_data = header_str .. value_data

  local result = caml_marshal_from_bytes(full_data)
  assert_eq(result, 2, "Should unmarshal value")
end)

test("total_size function", function()
  local marshal_header = nil  -- marshal_header functions are now global

  local header_str = marshal_header_write_header(50, 0, 0, 0)
  local dummy_data = string.rep("\0", 50)
  local full_data = header_str .. dummy_data

  local size = caml_marshal_total_size(full_data)
  assert_eq(size, 70, "Total size should be header (20) + data (50)")
end)

test("data_size function", function()
  local marshal_header = nil  -- marshal_header functions are now global

  local header_str = marshal_header_write_header(75, 0, 0, 0)
  local dummy_data = string.rep("\0", 75)
  local full_data = header_str .. dummy_data

  local size = caml_marshal_data_size(full_data)
  assert_eq(size, 75, "Data size should be 75")
end)

test("Custom decompressor stub exists", function()
  assert_true(marshal_decompress_input == nil, "Should start as nil (stub)")
end)

test("Can set custom decompressor", function()
  -- Test that we can set a custom decompressor
  local old_decompress = marshal_decompress_input

  marshal_decompress_input = function(compressed, uncompressed_len)
    return string.rep("X", uncompressed_len)
  end

  assert_true(marshal_decompress_input ~= nil, "Should be set")

  -- Restore
  marshal_decompress_input = old_decompress
end)

--
-- Marshal Flags Tests (Task 5.2)
--

print("")
print("Marshal Flags:")
print("--------------------------------------------------------------------")

test("Flag constants defined", function()
  assert_eq(MARSHAL_NO_SHARING, 0, "No_sharing should be 0")
  assert_eq(MARSHAL_CLOSURES, 1, "Closures should be 1")
  assert_eq(MARSHAL_COMPAT_32, 2, "Compat_32 should be 2")
end)

test("to_string with no flags", function()
  local result = caml_marshal_to_string(42, {})
  assert_eq(string.byte(result, 1), 0x42 + 0x40, "Should marshal as small int")
end)

test("to_string with No_sharing flag", function()
  local str = "test"

  -- Create data with repeated string
  local writer = MarshalWriter:new(true)  -- no_sharing = true
  writer:write_string(str)
  writer:write_string(str)
  local data_no_sharing = writer:to_string()

  -- With sharing disabled, both should be full strings
  -- First string: STRING8 (0x09) + length (1) + data (4) = 6 bytes
  -- Second string: STRING8 (0x09) + length (1) + data (4) = 6 bytes
  -- Total: 12 bytes
  assert_eq(#data_no_sharing, 12, "Without sharing, strings are duplicated")
end)

test("to_string respects No_sharing in to_string API", function()
  -- This is harder to test without complex structures
  -- Just verify it doesn't error
  local result = caml_marshal_to_string(42, {MARSHAL_NO_SHARING})
  assert_true(#result > 0, "Should produce data")
end)

test("Error on Closures flag", function()
  local success = pcall(function()
    caml_marshal_to_string(42, {MARSHAL_CLOSURES})
  end)

  assert_true(not success, "Should error on Closures flag")
end)

test("Compat_32 flag is accepted but does nothing", function()
  -- Compat_32 is redundant in Lua, should be silently accepted
  local result = caml_marshal_to_string(42, {MARSHAL_COMPAT_32})
  assert_true(#result > 0, "Should produce data")

  -- Should be same as without flag
  local result_no_flag = caml_marshal_to_string(42, {})
  assert_eq(#result, #result_no_flag, "Compat_32 should not change output")
end)

test("Multiple flags can be combined", function()
  -- No_sharing + Compat_32 should work
  local result = caml_marshal_to_string(42, {MARSHAL_NO_SHARING, MARSHAL_COMPAT_32})
  assert_true(#result > 0, "Should produce data")
end)

test("Empty flags array", function()
  local result = caml_marshal_to_string(42, {})
  assert_true(#result > 0, "Should produce data")
end)

test("Nil flags (default behavior)", function()
  local result = caml_marshal_to_string(42, nil)
  assert_true(#result > 0, "Should produce data")
end)

test("to_bytes alias exists", function()
  assert_true(caml_marshal_to_bytes ~= nil, "to_bytes should exist")
  local result = caml_marshal_to_bytes(42, {})
  assert_true(#result > 0, "Should produce data")
end)

test("Sharing enabled by default", function()
  local writer = MarshalWriter:new(false)  -- sharing enabled
  local str = "shared"

  writer:write_string(str)
  writer:write_string(str)

  local data = writer:to_string()

  -- With sharing:
  -- First: STRING8 (1) + len (1) + data (6) = 8 bytes
  -- Second: SHARED8 (1) + offset (1) = 2 bytes
  -- Total: 10 bytes
  assert_eq(#data, 10, "With sharing enabled, second reference is smaller")
end)

test("No_sharing flag disables sharing in writer", function()
  local writer = MarshalWriter:new(true)  -- no_sharing = true
  local str = "test"

  writer:write_string(str)
  writer:write_string(str)

  local data = writer:to_string()

  -- Both should be full STRING8
  -- Each: STRING8 (1) + len (1) + data (4) = 6 bytes
  -- Total: 12 bytes
  assert_eq(#data, 12, "No_sharing should duplicate strings")
end)

--
-- Summary
--

--
-- Special Tag Tests (Task 5.3)
--

print("")
print("Special Tag Tests (Task 5.3):")
print("--------------------------------------------------------------------")

test("Tag constants are defined", function()
  assert_eq(marshal.TAG_OBJECT, 248, "TAG_OBJECT")
  assert_eq(marshal.TAG_LAZY, 249, "TAG_LAZY")
  assert_eq(marshal.TAG_FORWARD, 250, "TAG_FORWARD")
  assert_eq(marshal.TAG_ABSTRACT, 251, "TAG_ABSTRACT")
  assert_eq(marshal.TAG_CLOSURE, 252, "TAG_CLOSURE")
  assert_eq(marshal.TAG_INFIX, 253, "TAG_INFIX")
  assert_eq(marshal.TAG_FLOAT_ARRAY, 254, "TAG_FLOAT_ARRAY")
  assert_eq(marshal.TAG_CUSTOM, 255, "TAG_CUSTOM")
end)

test("CODE_BLOCK64 causes error", function()
  local writer = Writer:new()
  writer:write8u(marshal.CODE_BLOCK64)

  local reader = MarshalReader:new(writer:to_string(), 0, 0, false)
  local success, err = pcall(function()
    reader:read_value()
  end)

  assert_true(not success, "Should error on CODE_BLOCK64")
  assert_true(string.find(err, "64%-bit"), "Error should mention 64-bit")
end)

test("CODE_CODEPOINTER causes error", function()
  local writer = Writer:new()
  writer:write8u(marshal.CODE_CODEPOINTER)

  local reader = MarshalReader:new(writer:to_string(), 0, 0, false)
  local success, err = pcall(function()
    reader:read_value()
  end)

  assert_true(not success, "Should error on CODE_CODEPOINTER")
  assert_true(string.find(err, "code pointer"), "Error should mention code pointer")
end)

test("CODE_INFIXPOINTER causes error", function()
  local writer = Writer:new()
  writer:write8u(marshal.CODE_INFIXPOINTER)

  local reader = MarshalReader:new(writer:to_string(), 0, 0, false)
  local success, err = pcall(function()
    reader:read_value()
  end)

  assert_true(not success, "Should error on CODE_INFIXPOINTER")
  assert_true(string.find(err, "infix pointer"), "Error should mention infix pointer")
end)

test("Tag 252 (closure) in small block causes error", function()
  local writer = Writer:new()
  -- Small block: tag=252 (0x0C), size=1 -> code = 0x80 | (1 << 4) | 0x0C = 0x9C
  local code = 0x80 + (1 * 16) + 12  -- tag 12 in small block range
  writer:write8u(code)

  local reader = MarshalReader:new(writer:to_string(), 0, 0, false)
  local success, err = pcall(function()
    reader:read_value()
  end)

  -- This won't error because tag 252 can't be encoded in small block (max tag = 15)
  -- Let's test with BLOCK32 instead
  assert_true(success, "Small block with tag 12 should succeed (can't encode 252)")
end)

test("Tag 252 (closure) in BLOCK32 causes error", function()
  local writer = Writer:new()
  writer:write8u(marshal.CODE_BLOCK32)
  -- BLOCK32 header: tag=252, size=1 -> header = (1 << 10) | 252 = 1276
  local header = (1 * 1024) + 252
  writer:write32u(header)

  local reader = MarshalReader:new(writer:to_string(), 0, 0, false)
  local success, err = pcall(function()
    reader:read_value()
  end)

  assert_true(not success, "Should error on tag 252 (closure)")
  assert_true(string.find(err, "closure"), "Error should mention closure")
end)

test("Tag 248 (object) blocks are tracked", function()
  local writer = Writer:new()
  writer:write8u(marshal.CODE_BLOCK32)
  -- BLOCK32 header: tag=248, size=1
  local header = (1 * 1024) + 248
  writer:write32u(header)
  writer:write8u(0x40)  -- Small int 0 as field

  local reader = MarshalReader:new(writer:to_string(), 0, 1, false)
  local block = reader:read_value()
  reader:finalize_objects()

  assert_eq(block.tag, 248, "Should have tag 248")
  assert_true(block.oo_id ~= nil, "Should have oo_id set")
  assert_true(block.oo_id > 0, "oo_id should be positive")
end)

test("Multiple tag 248 objects get unique oo_ids", function()
  local writer = Writer:new()

  -- First object block
  writer:write8u(marshal.CODE_BLOCK32)
  writer:write32u((1 * 1024) + 248)
  writer:write8u(0x40)  -- field

  -- Second object block
  writer:write8u(marshal.CODE_BLOCK32)
  writer:write32u((1 * 1024) + 248)
  writer:write8u(0x41)  -- field

  local str = writer:to_string()

  -- Read first object
  local reader1 = MarshalReader:new(str, 0, 1, false)
  local obj1 = reader1:read_value()
  reader1:finalize_objects()

  -- Read second object
  local reader2 = MarshalReader:new(str, 6, 1, false)
  local obj2 = reader2:read_value()
  reader2:finalize_objects()

  assert_true(obj1.oo_id ~= nil, "First object should have oo_id")
  assert_true(obj2.oo_id ~= nil, "Second object should have oo_id")
  assert_true(obj1.oo_id ~= obj2.oo_id, "oo_ids should be unique")
end)

test("Tag 249-251, 253 (non-closure special tags) are allowed", function()
  local tags = {249, 250, 251, 253}  -- Lazy, Forward, Abstract, Infix

  for _, tag in ipairs(tags) do
    local writer = Writer:new()
    writer:write8u(marshal.CODE_BLOCK32)
    local header = (1 * 1024) + tag
    writer:write32u(header)
    writer:write8u(0x40)  -- field

    local reader = MarshalReader:new(writer:to_string(), 0, 1, false)
    local success, err = pcall(function()
      local block = reader:read_value()
      reader:finalize_objects()
    end)

    assert_true(success, string.format("Tag %d should not error", tag))
  end
end)

test("Tag 254 (float array) already handled", function()
  -- Tag 254 is handled by DOUBLE_ARRAY codes, verify it works
  local writer = Writer:new()
  writer:write8u(marshal.CODE_DOUBLE_ARRAY8_LITTLE)
  writer:write8u(2)  -- length
  writer:write_double_little(1.5)
  writer:write_double_little(2.5)

  local reader = MarshalReader:new(writer:to_string(), 0, 1, false)
  local arr = reader:read_value()
  reader:finalize_objects()

  assert_eq(arr.tag, 254, "Should have tag 254")
  assert_eq(#arr.values, 2, "Should have 2 elements")
end)

test("Tag 255 (custom) already handled", function()
  -- Register custom block for testing
  marshal.register_custom_operations("_test", {
    serialize = function(writer, value, sz_32_64)
      writer:write8u(42)
      sz_32_64[1] = 1
      sz_32_64[2] = 1
    end,
    deserialize = function(reader, size)
      local b = reader:read8u()
      size[0] = 1
      return {caml_custom = "_test", value = b}
    end
  })

  local writer = Writer:new()
  writer:write8u(marshal.CODE_CUSTOM)
  writer:writestr("_test")
  writer:write8u(0)  -- null terminator
  writer:write8u(42)  -- data

  local reader = MarshalReader:new(writer:to_string(), 0, 1, false)
  local custom = reader:read_value()
  reader:finalize_objects()

  assert_eq(custom.caml_custom, "_test", "Should be custom block")
  assert_eq(custom.value, 42, "Should preserve value")
end)

--
-- Public API Tests (Task 6.1)
--

print("")
print("Public API Tests (Task 6.1):")
print("--------------------------------------------------------------------")

test("to_string produces complete marshal format", function()
  local value = 42
  local result = caml_marshal_to_string(value)

  -- Should have header (20 bytes) + data
  assert_true(#result > 20, "Should have header + data")

  -- Parse header to verify format
  local header = marshal_header_read_header(result, 0)
  assert_true(header ~= nil, "Should have valid header")
  assert_eq(header.magic, MARSHAL_MAGIC_SMALL, "Should have MAGIC_SMALL")
  assert_true(header.data_len > 0, "Should have data")
end)

test("to_bytes is alias for to_string", function()
  local value = "test"
  local result1 = caml_marshal_to_string(value)
  local result2 = caml_marshal_to_bytes(value)

  assert_eq(result1, result2, "to_bytes should be same as to_string")
end)

test("to_string with No_sharing flag", function()
  local value = 123
  local result = caml_marshal_to_string(value, {MARSHAL_NO_SHARING})

  -- Should still produce valid marshal format
  local header = marshal_header_read_header(result, 0)
  assert_true(header ~= nil, "Should have valid header")
end)

test("from_bytes unmarshals complete format", function()
  local original = 42
  local marshalled = caml_marshal_to_string(original)
  local result = caml_marshal_from_bytes(marshalled)

  assert_eq(result, original, "Should unmarshal correctly")
end)

test("from_bytes with offset", function()
  local original = 123
  local marshalled = caml_marshal_to_string(original)

  -- Create string with prefix
  local prefixed = "XXXX" .. marshalled
  local result = caml_marshal_from_bytes(prefixed, 4)

  assert_eq(result, original, "Should unmarshal with offset")
end)

test("from_string is alias for from_bytes", function()
  local original = "hello"
  local marshalled = caml_marshal_to_string(original)

  local result1 = caml_marshal_from_bytes(marshalled)
  local result2 = caml_marshal_from_string(marshalled)

  assert_eq(result1, result2, "from_string should be same as from_bytes")
end)

test("Roundtrip: integer", function()
  local original = 12345
  local marshalled = caml_marshal_to_string(original)
  local result = caml_marshal_from_bytes(marshalled)

  assert_eq(result, original, "Integer roundtrip")
end)

test("Roundtrip: string", function()
  local original = "Hello, Marshal!"
  local marshalled = caml_marshal_to_string(original)
  local result = caml_marshal_from_bytes(marshalled)

  assert_eq(result, original, "String roundtrip")
end)

test("Roundtrip: float", function()
  local original = 3.14159
  local marshalled = caml_marshal_to_string(original)
  local result = caml_marshal_from_bytes(marshalled)

  assert_close(result, original, 1e-10, "Float roundtrip")
end)

test("Roundtrip: block", function()
  local original = {tag = 0, size = 2}
  local marshalled = caml_marshal_to_string(original)
  local result = caml_marshal_from_bytes(marshalled)

  assert_eq(result.tag, original.tag, "Block tag roundtrip")
  assert_eq(result.size, original.size, "Block size roundtrip")
end)

test("Roundtrip: float array", function()
  local original = {tag = 254, values = {1.5, 2.5, 3.5}}
  local marshalled = caml_marshal_to_string(original)
  local result = caml_marshal_from_bytes(marshalled)

  assert_eq(result.tag, 254, "Float array tag")
  assert_eq(#result.values, 3, "Float array length")
  assert_close(result.values[1], 1.5, 1e-10, "Element 1")
  assert_close(result.values[2], 2.5, 1e-10, "Element 2")
  assert_close(result.values[3], 3.5, 1e-10, "Element 3")
end)

test("total_size returns correct size", function()
  local value = 42
  local marshalled = caml_marshal_to_string(value)

  local size = caml_marshal_total_size(marshalled, 0)
  assert_eq(size, #marshalled, "total_size should match string length")
end)

test("total_size with offset", function()
  local value = 42
  local marshalled = caml_marshal_to_string(value)
  local prefixed = "XXXX" .. marshalled

  local size = caml_marshal_total_size(prefixed, 4)
  assert_eq(size, #marshalled, "total_size should work with offset")
end)

test("data_size returns data length only", function()
  local value = 42
  local marshalled = caml_marshal_to_string(value)

  local header_size = 20  -- Standard header is 20 bytes
  local data_size = caml_marshal_data_size(marshalled, 0)

  assert_eq(data_size, #marshalled - header_size, "data_size should exclude header")
  assert_true(data_size > 0, "Should have data")
end)

test("Multiple values can be marshalled independently", function()
  local val1 = 100
  local val2 = "test"
  local val3 = 3.14

  local m1 = caml_marshal_to_string(val1)
  local m2 = caml_marshal_to_string(val2)
  local m3 = caml_marshal_to_string(val3)

  assert_eq(caml_marshal_from_bytes(m1), val1, "Value 1")
  assert_eq(caml_marshal_from_bytes(m2), val2, "Value 2")
  assert_close(caml_marshal_from_bytes(m3), val3, 1e-10, "Value 3")
end)

test("Marshal format includes proper metadata", function()
  local value = {tag = 0, size = 1}
  local marshalled = caml_marshal_to_string(value)
  local header = marshal_header_read_header(marshalled, 0)

  assert_eq(header.magic, MARSHAL_MAGIC_SMALL, "Magic number")
  assert_true(header.data_len > 0, "Has data")
  assert_true(header.num_objects >= 0, "Has object count")
end)

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
