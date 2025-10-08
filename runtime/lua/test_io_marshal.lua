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
-- Marshal Output Tests (Task 1.2)
--

print("")
print("Marshal Output Tests (Task 1.2):")
print("--------------------------------------------------------------------")

test("caml_output_value writes integer to channel", function()
  local filename = make_temp_file()
  local original = 42

  -- Write using caml_output_value
  local fd = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)  -- O_WRONLY + O_CREAT + O_TRUNC + O_BINARY
  local chanid = io_module.caml_ml_open_descriptor_out(fd)
  io_module.caml_output_value(chanid, original, nil)
  io_module.caml_ml_flush(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = marshal.from_bytes(content, 0)
  assert_eq(result, original, "Integer written correctly")
  cleanup_temp_file(filename)
end)

test("caml_output_value writes string to channel", function()
  local filename = make_temp_file()
  local original = "Hello, World!"

  -- Write using caml_output_value
  local fd = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)
  io_module.caml_output_value(chanid, original, nil)
  io_module.caml_ml_flush(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = marshal.from_bytes(content, 0)
  assert_eq(result, original, "String written correctly")
  cleanup_temp_file(filename)
end)

test("caml_output_value writes float to channel", function()
  local filename = make_temp_file()
  local original = 3.14159

  -- Write using caml_output_value
  local fd = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)
  io_module.caml_output_value(chanid, original, nil)
  io_module.caml_ml_flush(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = marshal.from_bytes(content, 0)
  assert_close(result, original, 1e-10, "Float written correctly")
  cleanup_temp_file(filename)
end)

test("caml_output_value writes block to channel", function()
  local filename = make_temp_file()
  local original = {tag = 0, size = 2}

  -- Write using caml_output_value
  local fd = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)
  io_module.caml_output_value(chanid, original, nil)
  io_module.caml_ml_flush(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = marshal.from_bytes(content, 0)
  assert_eq(result.tag, original.tag, "Block tag written correctly")
  assert_eq(result.size, original.size, "Block size written correctly")
  cleanup_temp_file(filename)
end)

test("caml_output_value writes with No_sharing flag", function()
  local filename = make_temp_file()
  local original = 100

  -- Write using caml_output_value with No_sharing flag
  local fd = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)
  io_module.caml_output_value(chanid, original, {marshal.No_sharing})
  io_module.caml_ml_flush(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = marshal.from_bytes(content, 0)
  assert_eq(result, original, "Value with No_sharing written correctly")
  cleanup_temp_file(filename)
end)

test("caml_output_value writes multiple values", function()
  local filename = make_temp_file()

  -- Write multiple values
  local fd = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)
  io_module.caml_output_value(chanid, 100, nil)
  io_module.caml_output_value(chanid, "test", nil)
  io_module.caml_output_value(chanid, 3.14, nil)
  io_module.caml_ml_flush(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  -- Parse multiple marshalled values
  local offset = 0
  local v1 = marshal.from_bytes(content, offset)
  offset = offset + marshal.total_size(content, offset)
  local v2 = marshal.from_bytes(content, offset)
  offset = offset + marshal.total_size(content, offset)
  local v3 = marshal.from_bytes(content, offset)

  assert_eq(v1, 100, "First value")
  assert_eq(v2, "test", "Second value")
  assert_close(v3, 3.14, 1e-10, "Third value")
  cleanup_temp_file(filename)
end)

--
-- Complete Roundtrip Tests (Task 1.2)
--

print("")
print("Complete Roundtrip Tests (Write + Read via channels):")
print("--------------------------------------------------------------------")

test("Complete roundtrip: integer via channels", function()
  local filename = make_temp_file()
  local original = 12345

  -- Write via channel
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  io_module.caml_output_value(chan_out, original, nil)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read via channel
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local result = io_module.caml_input_value(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(result, original, "Complete roundtrip")
  cleanup_temp_file(filename)
end)

test("Complete roundtrip: string via channels", function()
  local filename = make_temp_file()
  local original = "Marshal roundtrip test!"

  -- Write via channel
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  io_module.caml_output_value(chan_out, original, nil)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read via channel
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local result = io_module.caml_input_value(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(result, original, "Complete roundtrip")
  cleanup_temp_file(filename)
end)

test("Complete roundtrip: float array via channels", function()
  local filename = make_temp_file()
  local original = {tag = 254, values = {1.1, 2.2, 3.3}}

  -- Write via channel
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  io_module.caml_output_value(chan_out, original, nil)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read via channel
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local result = io_module.caml_input_value(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(result.tag, 254, "Float array tag")
  assert_eq(#result.values, 3, "Float array length")
  assert_close(result.values[1], 1.1, 1e-10, "Element 1")
  assert_close(result.values[2], 2.2, 1e-10, "Element 2")
  assert_close(result.values[3], 3.3, 1e-10, "Element 3")
  cleanup_temp_file(filename)
end)

test("Complete roundtrip: multiple values via channels", function()
  local filename = make_temp_file()

  -- Write multiple values via channel
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  io_module.caml_output_value(chan_out, 111, nil)
  io_module.caml_output_value(chan_out, "abc", nil)
  io_module.caml_output_value(chan_out, 2.71, nil)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read multiple values via channel
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local v1 = io_module.caml_input_value(chan_in)
  local v2 = io_module.caml_input_value(chan_in)
  local v3 = io_module.caml_input_value(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(v1, 111, "First value")
  assert_eq(v2, "abc", "Second value")
  assert_close(v3, 2.71, 1e-10, "Third value")
  cleanup_temp_file(filename)
end)

test("Complete roundtrip: large data via channels", function()
  local filename = make_temp_file()
  local original = string.rep("X", 5000)  -- 5KB string

  -- Write via channel
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  io_module.caml_output_value(chan_out, original, nil)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read via channel
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local result = io_module.caml_input_value(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(#result, #original, "Large data length")
  assert_eq(result, original, "Large data content")
  cleanup_temp_file(filename)
end)

--
-- High-Level Channel API Tests (Task 1.3)
--

print("")
print("High-Level Channel API Tests (Task 1.3):")
print("--------------------------------------------------------------------")

test("marshal.to_channel writes integer", function()
  local filename = make_temp_file()
  local original = 999

  -- Write using high-level API
  local fd = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)
  marshal.to_channel(chanid, original)
  io_module.caml_ml_flush(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = marshal.from_bytes(content, 0)
  assert_eq(result, original, "High-level API writes correctly")
  cleanup_temp_file(filename)
end)

test("marshal.to_channel with flags", function()
  local filename = make_temp_file()
  local original = 777

  -- Write using high-level API with No_sharing flag
  local fd = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)
  marshal.to_channel(chanid, original, {marshal.No_sharing})
  io_module.caml_ml_flush(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = marshal.from_bytes(content, 0)
  assert_eq(result, original, "High-level API respects flags")
  cleanup_temp_file(filename)
end)

test("marshal.from_channel reads value", function()
  local filename = make_temp_file()
  local original = "channel test"

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = marshal.to_string(original)
  f:write(marshalled)
  f:close()

  -- Read using high-level API
  local fd = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)
  local result = marshal.from_channel(chanid)
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  assert_eq(result, original, "High-level API reads correctly")
  cleanup_temp_file(filename)
end)

test("High-level API complete roundtrip: integer", function()
  local filename = make_temp_file()
  local original = 54321

  -- Write using high-level API
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  marshal.to_channel(chan_out, original)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read using high-level API
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local result = marshal.from_channel(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(result, original, "High-level roundtrip")
  cleanup_temp_file(filename)
end)

test("High-level API complete roundtrip: string", function()
  local filename = make_temp_file()
  local original = "High-level marshal API!"

  -- Write using high-level API
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  marshal.to_channel(chan_out, original)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read using high-level API
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local result = marshal.from_channel(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(result, original, "High-level roundtrip")
  cleanup_temp_file(filename)
end)

test("High-level API complete roundtrip: float array", function()
  local filename = make_temp_file()
  local original = {tag = 254, values = {10.1, 20.2, 30.3}}

  -- Write using high-level API
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  marshal.to_channel(chan_out, original)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read using high-level API
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local result = marshal.from_channel(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(result.tag, 254, "Float array tag")
  assert_eq(#result.values, 3, "Float array length")
  assert_close(result.values[1], 10.1, 1e-10, "Element 1")
  assert_close(result.values[2], 20.2, 1e-10, "Element 2")
  assert_close(result.values[3], 30.3, 1e-10, "Element 3")
  cleanup_temp_file(filename)
end)

test("High-level API: multiple values", function()
  local filename = make_temp_file()

  -- Write multiple values using high-level API
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  marshal.to_channel(chan_out, 11)
  marshal.to_channel(chan_out, "two")
  marshal.to_channel(chan_out, 3.33)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read multiple values using high-level API
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local v1 = marshal.from_channel(chan_in)
  local v2 = marshal.from_channel(chan_in)
  local v3 = marshal.from_channel(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(v1, 11, "First value")
  assert_eq(v2, "two", "Second value")
  assert_close(v3, 3.33, 1e-10, "Third value")
  cleanup_temp_file(filename)
end)

test("High-level API: large data", function()
  local filename = make_temp_file()
  local original = string.rep("Y", 8000)  -- 8KB string

  -- Write using high-level API
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  marshal.to_channel(chan_out, original)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read using high-level API
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local result = marshal.from_channel(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(#result, #original, "Large data length")
  assert_eq(result, original, "Large data content")
  cleanup_temp_file(filename)
end)

test("High-level API with No_sharing: complete roundtrip", function()
  local filename = make_temp_file()
  local original = 888

  -- Write using high-level API with No_sharing
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  marshal.to_channel(chan_out, original, {marshal.No_sharing})
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read using high-level API
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local result = marshal.from_channel(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(result, original, "No_sharing roundtrip")
  cleanup_temp_file(filename)
end)

test("High-level API: mixed with low-level API", function()
  local filename = make_temp_file()
  local original1 = 123
  local original2 = "mixed"

  -- Write first value with high-level, second with low-level
  local fd_out = io_module.caml_sys_open(filename, {1, 3, 4, 6}, 0)
  local chan_out = io_module.caml_ml_open_descriptor_out(fd_out)
  marshal.to_channel(chan_out, original1)
  io_module.caml_output_value(chan_out, original2, nil)
  io_module.caml_ml_flush(chan_out)
  io_module.caml_ml_close_channel(chan_out)
  io_module.caml_sys_close(fd_out)

  -- Read first value with high-level, second with low-level
  local fd_in = io_module.caml_sys_open(filename, {0, 6}, 0)
  local chan_in = io_module.caml_ml_open_descriptor_in(fd_in)
  local result1 = marshal.from_channel(chan_in)
  local result2 = io_module.caml_input_value(chan_in)
  io_module.caml_ml_close_channel(chan_in)
  io_module.caml_sys_close(fd_in)

  assert_eq(result1, original1, "High-level write/read")
  assert_eq(result2, original2, "Low-level write/read")
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
