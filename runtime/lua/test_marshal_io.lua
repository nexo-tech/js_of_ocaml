#!/usr/bin/env lua
-- Test suite for marshal_io.lua (Binary Reader/Writer - Task 1.1)

local marshal_io = require("marshal_io")
local Reader = marshal_io.Reader
local Writer = marshal_io.Writer

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

local function assert_close(actual, expected, epsilon, msg)
  epsilon = epsilon or 1e-10
  if math.abs(actual - expected) > epsilon then
    error(msg or ("Expected " .. tostring(expected) .. ", got " .. tostring(actual)))
  end
end

print("====================================================================")
print("Marshal I/O Tests (marshal_io.lua - Task 1.1)")
print("====================================================================")
print("")

--
-- Writer Tests
--

print("Writer Tests:")
print("--------------------------------------------------------------------")

test("Writer creation", function()
  local writer = Writer:new()
  assert_true(writer ~= nil, "Should create writer")
  assert_eq(writer:position(), 0, "Should start at position 0")
  assert_eq(writer:size(), 0, "Should start with size 0")
end)

test("Writer write8u", function()
  local writer = Writer:new()
  writer:write8u(42)
  writer:write8u(255)
  writer:write8u(0)

  assert_eq(writer:size(), 3, "Should have 3 bytes")
  local str = writer:to_string()
  assert_eq(string.byte(str, 1), 42, "First byte")
  assert_eq(string.byte(str, 2), 255, "Second byte")
  assert_eq(string.byte(str, 3), 0, "Third byte")
end)

test("Writer write16u", function()
  local writer = Writer:new()
  writer:write16u(0x1234)
  writer:write16u(0xABCD)

  local str = writer:to_string()
  assert_eq(string.byte(str, 1), 0x12, "First byte of 0x1234")
  assert_eq(string.byte(str, 2), 0x34, "Second byte of 0x1234")
  assert_eq(string.byte(str, 3), 0xAB, "First byte of 0xABCD")
  assert_eq(string.byte(str, 4), 0xCD, "Second byte of 0xABCD")
end)

test("Writer write32u", function()
  local writer = Writer:new()
  writer:write32u(0x12345678)
  writer:write32u(0xABCDEF01)

  local str = writer:to_string()
  assert_eq(string.byte(str, 1), 0x12, "Byte 1")
  assert_eq(string.byte(str, 2), 0x34, "Byte 2")
  assert_eq(string.byte(str, 3), 0x56, "Byte 3")
  assert_eq(string.byte(str, 4), 0x78, "Byte 4")
  assert_eq(string.byte(str, 5), 0xAB, "Byte 5")
  assert_eq(string.byte(str, 6), 0xCD, "Byte 6")
  assert_eq(string.byte(str, 7), 0xEF, "Byte 7")
  assert_eq(string.byte(str, 8), 0x01, "Byte 8")
end)

test("Writer writestr", function()
  local writer = Writer:new()
  writer:writestr("Hello")

  local str = writer:to_string()
  assert_eq(str, "Hello", "Should write string")
end)

test("Writer write_at", function()
  local writer = Writer:new()
  writer:write32u(0x12345678)
  writer:write_at(0, 32, 0xABCDEF01)

  local str = writer:to_string()
  assert_eq(string.byte(str, 1), 0xAB, "Should overwrite at position")
  assert_eq(string.byte(str, 2), 0xCD, "Should overwrite at position")
end)

--
-- Reader Tests
--

print("")
print("Reader Tests:")
print("--------------------------------------------------------------------")

test("Reader creation", function()
  local str = "Hello"
  local reader = Reader:new(str)
  assert_true(reader ~= nil, "Should create reader")
  assert_eq(reader:position(), 0, "Should start at position 0")
  assert_eq(reader:remaining(), 5, "Should have 5 bytes remaining")
end)

test("Reader read8u", function()
  local writer = Writer:new()
  writer:write8u(42)
  writer:write8u(255)
  writer:write8u(0)

  local reader = Reader:new(writer:to_string())
  assert_eq(reader:read8u(), 42, "First byte")
  assert_eq(reader:read8u(), 255, "Second byte")
  assert_eq(reader:read8u(), 0, "Third byte")
end)

test("Reader read8s", function()
  local writer = Writer:new()
  writer:write8u(127)   -- Positive
  writer:write8u(128)   -- -128
  writer:write8u(255)   -- -1

  local reader = Reader:new(writer:to_string())
  assert_eq(reader:read8s(), 127, "Positive value")
  assert_eq(reader:read8s(), -128, "Negative value (128)")
  assert_eq(reader:read8s(), -1, "Negative value (255)")
end)

test("Reader read16u", function()
  local writer = Writer:new()
  writer:write16u(0x1234)
  writer:write16u(0xABCD)

  local reader = Reader:new(writer:to_string())
  assert_eq(reader:read16u(), 0x1234, "First value")
  assert_eq(reader:read16u(), 0xABCD, "Second value")
end)

test("Reader read16s", function()
  local writer = Writer:new()
  writer:write16u(32767)  -- Max positive
  writer:write16u(32768)  -- -32768
  writer:write16u(65535)  -- -1

  local reader = Reader:new(writer:to_string())
  assert_eq(reader:read16s(), 32767, "Positive value")
  assert_eq(reader:read16s(), -32768, "Negative value (32768)")
  assert_eq(reader:read16s(), -1, "Negative value (65535)")
end)

test("Reader read32u", function()
  local writer = Writer:new()
  writer:write32u(0x12345678)
  writer:write32u(0xABCDEF01)

  local reader = Reader:new(writer:to_string())
  assert_eq(reader:read32u(), 0x12345678, "First value")
  assert_eq(reader:read32u(), 0xABCDEF01, "Second value")
end)

test("Reader read32s", function()
  local writer = Writer:new()
  writer:write32u(2147483647)  -- Max positive
  writer:write32u(2147483648)  -- -2147483648
  writer:write32u(4294967295)  -- -1

  local reader = Reader:new(writer:to_string())
  assert_eq(reader:read32s(), 2147483647, "Positive value")
  assert_eq(reader:read32s(), -2147483648, "Negative value")
  assert_eq(reader:read32s(), -1, "Negative value (-1)")
end)

test("Reader readstr", function()
  local writer = Writer:new()
  writer:writestr("Hello")

  local reader = Reader:new(writer:to_string())
  assert_eq(reader:readstr(5), "Hello", "Should read string")
end)

--
-- Roundtrip Tests
--

print("")
print("Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("Roundtrip 8-bit values", function()
  local writer = Writer:new()
  for i = 0, 255 do
    writer:write8u(i)
  end

  local reader = Reader:new(writer:to_string())
  for i = 0, 255 do
    assert_eq(reader:read8u(), i, "Roundtrip " .. i)
  end
end)

test("Roundtrip 16-bit values", function()
  local writer = Writer:new()
  local values = {0, 1, 255, 256, 32767, 32768, 65535}
  for _, v in ipairs(values) do
    writer:write16u(v)
  end

  local reader = Reader:new(writer:to_string())
  for _, v in ipairs(values) do
    assert_eq(reader:read16u(), v, "Roundtrip " .. v)
  end
end)

test("Roundtrip 32-bit values", function()
  local writer = Writer:new()
  local values = {0, 1, 255, 256, 65535, 65536, 16777215, 16777216, 2147483647, 2147483648, 4294967295}
  for _, v in ipairs(values) do
    writer:write32u(v)
  end

  local reader = Reader:new(writer:to_string())
  for _, v in ipairs(values) do
    assert_eq(reader:read32u(), v, "Roundtrip " .. v)
  end
end)

test("Roundtrip strings", function()
  local writer = Writer:new()
  local strings = {"", "a", "Hello", "Hello, World!", "Special: \0\1\2\255"}
  for _, s in ipairs(strings) do
    writer:write8u(#s)
    writer:writestr(s)
  end

  local reader = Reader:new(writer:to_string())
  for _, s in ipairs(strings) do
    local len = reader:read8u()
    local str = reader:readstr(len)
    assert_eq(str, s, "Roundtrip string")
  end
end)

--
-- Float/Double Tests (if string.pack available)
--

print("")
print("Float/Double Tests:")
print("--------------------------------------------------------------------")

if string.pack then
  test("Writer write_double_little", function()
    local writer = Writer:new()
    writer:write_double_little(3.14159)
    writer:write_double_little(-2.71828)
    writer:write_double_little(0.0)

    assert_eq(writer:size(), 24, "Should write 24 bytes")
  end)

  test("Writer write_double_big", function()
    local writer = Writer:new()
    writer:write_double_big(3.14159)
    writer:write_double_big(-2.71828)
    writer:write_double_big(0.0)

    assert_eq(writer:size(), 24, "Should write 24 bytes")
  end)

  test("Reader read_double_little", function()
    local writer = Writer:new()
    writer:write_double_little(3.14159)
    writer:write_double_little(-2.71828)
    writer:write_double_little(0.0)

    local reader = Reader:new(writer:to_string())
    assert_close(reader:read_double_little(), 3.14159, 1e-5, "First double")
    assert_close(reader:read_double_little(), -2.71828, 1e-5, "Second double")
    assert_eq(reader:read_double_little(), 0.0, "Third double")
  end)

  test("Reader read_double_big", function()
    local writer = Writer:new()
    writer:write_double_big(3.14159)
    writer:write_double_big(-2.71828)
    writer:write_double_big(0.0)

    local reader = Reader:new(writer:to_string())
    assert_close(reader:read_double_big(), 3.14159, 1e-5, "First double")
    assert_close(reader:read_double_big(), -2.71828, 1e-5, "Second double")
    assert_eq(reader:read_double_big(), 0.0, "Third double")
  end)

  test("Roundtrip doubles (little-endian)", function()
    local writer = Writer:new()
    local values = {0.0, 1.0, -1.0, 3.14159, -2.71828, 1e10, 1e-10, math.huge, -math.huge}
    for _, v in ipairs(values) do
      writer:write_double_little(v)
    end

    local reader = Reader:new(writer:to_string())
    for _, v in ipairs(values) do
      local read_v = reader:read_double_little()
      if v == math.huge or v == -math.huge then
        assert_eq(read_v, v, "Roundtrip " .. tostring(v))
      else
        assert_close(read_v, v, 1e-10, "Roundtrip " .. v)
      end
    end
  end)

  test("Roundtrip doubles (big-endian)", function()
    local writer = Writer:new()
    local values = {0.0, 1.0, -1.0, 3.14159, -2.71828, 1e10, 1e-10, math.huge, -math.huge}
    for _, v in ipairs(values) do
      writer:write_double_big(v)
    end

    local reader = Reader:new(writer:to_string())
    for _, v in ipairs(values) do
      local read_v = reader:read_double_big()
      if v == math.huge or v == -math.huge then
        assert_eq(read_v, v, "Roundtrip " .. tostring(v))
      else
        assert_close(read_v, v, 1e-10, "Roundtrip " .. v)
      end
    end
  end)
else
  print("  Skipping float tests (string.pack not available)")
end

--
-- Error Handling Tests
--

print("")
print("Error Handling:")
print("--------------------------------------------------------------------")

test("Reader bounds check", function()
  local reader = Reader:new("AB")

  reader:read8u()
  reader:read8u()

  local success = pcall(function()
    reader:read8u()
  end)
  assert_true(not success, "Should error on reading past end")
end)

test("Reader readstr bounds check", function()
  local reader = Reader:new("AB")

  local success = pcall(function()
    reader:readstr(5)
  end)
  assert_true(not success, "Should error on reading past end")
end)

--
-- Position Tests
--

print("")
print("Position/Seek Tests:")
print("--------------------------------------------------------------------")

test("Reader position tracking", function()
  local reader = Reader:new("ABCDE")

  assert_eq(reader:position(), 0, "Initial position")
  reader:read8u()
  assert_eq(reader:position(), 1, "After read")
  reader:read8u()
  assert_eq(reader:position(), 2, "After second read")
end)

test("Reader seek", function()
  local reader = Reader:new("ABCDE")

  reader:seek(2)
  assert_eq(reader:read8u(), string.byte('C'), "Should read from position 2")

  reader:seek(0)
  assert_eq(reader:read8u(), string.byte('A'), "Should read from position 0")
end)

test("Reader has_more", function()
  local reader = Reader:new("AB")

  assert_true(reader:has_more(), "Should have more")
  reader:read8u()
  assert_true(reader:has_more(), "Should have more")
  reader:read8u()
  assert_true(not reader:has_more(), "Should not have more")
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
