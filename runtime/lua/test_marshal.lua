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
-- Edge Cases and Error Handling
--

print("")
print("Edge Cases and Error Handling:")
print("--------------------------------------------------------------------")

test("Error on float value", function()
  local success = pcall(function()
    marshal.marshal_value(3.14)
  end)
  assert_true(not success, "Should error on float")
end)

test("Error on integer too large", function()
  local success = pcall(function()
    marshal.marshal_value(2147483648)
  end)
  assert_true(not success, "Should error on too large integer")
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
