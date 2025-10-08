#!/usr/bin/env lua
-- Test suite for marshal channel I/O integration

-- Load modules
local marshal = require("marshal")
local io_module = require("io")

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

-- Helper: Create temporary file
local temp_file_counter = 0
local function make_temp_file()
  temp_file_counter = temp_file_counter + 1
  return "/tmp/test_io_marshal_" .. temp_file_counter .. ".dat"
end

-- Helper: Clean up temp file
local function cleanup_temp_file(filename)
  os.remove(filename)
end

print("====================================================================")
print("Marshal Channel I/O Tests (Task 1.1)")
print("====================================================================")
print("")

--
-- Basic Roundtrip Tests
--

print("Basic Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("Roundtrip integer through file", function()
  local filename = make_temp_file()
  local original = 42

  -- Write to file
  local f = io.open(filename, "wb")
  assert_true(f, "Should open file for writing")
  local marshalled = marshal.to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file using channels
  local fd = io_module.caml_sys_open(filename, {0}, 0)  -- O_RDONLY
  local chanid = io_module.caml_ml_open_descriptor_in(fd)
  local result = io_module.caml_input_value(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_eq(result, original, "Integer roundtrip")
  cleanup_temp_file(filename)
end)

test("Roundtrip string through file", function()
  local filename = make_temp_file()
  local original = "Hello, Marshal!"

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = marshal.to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file using channels
  local fd = io_module.caml_sys_open(filename, {0}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)
  local result = io_module.caml_input_value(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_eq(result, original, "String roundtrip")
  cleanup_temp_file(filename)
end)

test("Roundtrip float through file", function()
  local filename = make_temp_file()
  local original = 3.14159

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = marshal.to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file using channels
  local fd = io_module.caml_sys_open(filename, {0}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)
  local result = io_module.caml_input_value(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_close(result, original, 1e-10, "Float roundtrip")
  cleanup_temp_file(filename)
end)

test("Roundtrip block through file", function()
  local filename = make_temp_file()
  local original = {tag = 0, size = 2}

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = marshal.to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file using channels
  local fd = io_module.caml_sys_open(filename, {0}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)
  local result = io_module.caml_input_value(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_eq(result.tag, original.tag, "Block tag roundtrip")
  assert_eq(result.size, original.size, "Block size roundtrip")
  cleanup_temp_file(filename)
end)

test("Roundtrip float array through file", function()
  local filename = make_temp_file()
  local original = {tag = 254, values = {1.5, 2.5, 3.5}}

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = marshal.to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file using channels
  local fd = io_module.caml_sys_open(filename, {0}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)
  local result = io_module.caml_input_value(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_eq(result.tag, 254, "Float array tag")
  assert_eq(#result.values, 3, "Float array length")
  assert_close(result.values[1], 1.5, 1e-10, "Element 1")
  assert_close(result.values[2], 2.5, 1e-10, "Element 2")
  assert_close(result.values[3], 3.5, 1e-10, "Element 3")
  cleanup_temp_file(filename)
end)

--
-- Multiple Values Tests
--

print("")
print("Multiple Values Tests:")
print("--------------------------------------------------------------------")

test("Read multiple marshalled values from file", function()
  local filename = make_temp_file()

  -- Write multiple values
  local f = io.open(filename, "wb")
  f:write(marshal.to_string(100))
  f:write(marshal.to_string("test"))
  f:write(marshal.to_string(3.14))
  f:close()

  -- Read multiple values
  local fd = io_module.caml_sys_open(filename, {0}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)

  local v1 = io_module.caml_input_value(chanid)
  local v2 = io_module.caml_input_value(chanid)
  local v3 = io_module.caml_input_value(chanid)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_eq(v1, 100, "First value")
  assert_eq(v2, "test", "Second value")
  assert_close(v3, 3.14, 1e-10, "Third value")
  cleanup_temp_file(filename)
end)

--
-- Error Handling Tests
--

print("")
print("Error Handling Tests:")
print("--------------------------------------------------------------------")

test("EOF on empty file raises error", function()
  local filename = make_temp_file()

  -- Create empty file
  local f = io.open(filename, "wb")
  f:close()

  -- Try to read from empty file
  local fd = io_module.caml_sys_open(filename, {0}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)

  local success, err = pcall(function()
    io_module.caml_input_value(chanid)
  end)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_true(not success, "Should error on EOF")
  cleanup_temp_file(filename)
end)

test("Truncated header raises error", function()
  local filename = make_temp_file()

  -- Write incomplete header (only 10 bytes instead of 20)
  local f = io.open(filename, "wb")
  f:write("0123456789")
  f:close()

  -- Try to read truncated header
  local fd = io_module.caml_sys_open(filename, {0}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)

  local success, err = pcall(function()
    io_module.caml_input_value(chanid)
  end)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_true(not success, "Should error on truncated header")
  assert_true(string.find(tostring(err), "truncated"), "Error should mention truncation")
  cleanup_temp_file(filename)
end)

test("Truncated data raises error", function()
  local filename = make_temp_file()

  -- Write valid header but incomplete data
  local marshalled = marshal.to_string(12345)
  local f = io.open(filename, "wb")
  -- Write header + partial data
  f:write(string.sub(marshalled, 1, 23))  -- Header (20) + 3 bytes of data
  f:close()

  -- Try to read truncated data
  local fd = io_module.caml_sys_open(filename, {0}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)

  local success, err = pcall(function()
    io_module.caml_input_value(chanid)
  end)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_true(not success, "Should error on truncated data")
  assert_true(string.find(tostring(err), "truncated"), "Error should mention truncation")
  cleanup_temp_file(filename)
end)

--
-- Binary Mode Tests
--

print("")
print("Binary Mode Tests:")
print("--------------------------------------------------------------------")

test("Binary mode preserves exact bytes", function()
  local filename = make_temp_file()
  local original = "Binary\0Data\255"

  -- Write with binary mode
  local f = io.open(filename, "wb")
  local marshalled = marshal.to_string(original)
  f:write(marshalled)
  f:close()

  -- Read with binary mode
  local fd = io_module.caml_sys_open(filename, {0, 6}, 0)  -- O_RDONLY + O_BINARY
  local chanid = io_module.caml_ml_open_descriptor_in(fd)
  local result = io_module.caml_input_value(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_eq(result, original, "Binary data preserved")
  cleanup_temp_file(filename)
end)

--
-- caml_input_value_to_outside_heap Tests
--

print("")
print("Alias Function Tests:")
print("--------------------------------------------------------------------")

test("caml_input_value_to_outside_heap is alias", function()
  local filename = make_temp_file()
  local original = 999

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = marshal.to_string(original)
  f:write(marshalled)
  f:close()

  -- Read using alias function
  local fd = io_module.caml_sys_open(filename, {0}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)
  local result = io_module.caml_input_value_to_outside_heap(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_eq(result, original, "Alias function works")
  cleanup_temp_file(filename)
end)

--
-- Large Data Tests
--

print("")
print("Large Data Tests:")
print("--------------------------------------------------------------------")

test("Read large string from file", function()
  local filename = make_temp_file()
  local original = string.rep("A", 10000)  -- 10KB string

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = marshal.to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file
  local fd = io_module.caml_sys_open(filename, {0}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)
  local result = io_module.caml_input_value(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_eq(#result, #original, "Large string length")
  assert_eq(result, original, "Large string content")
  cleanup_temp_file(filename)
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
