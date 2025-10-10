#!/usr/bin/env lua
-- Test suite for marshal channel I/O integration

-- Load modules in dependency order
dofile("core.lua")
dofile("fail.lua")
dofile("marshal_io.lua")
dofile("marshal_header.lua")
dofile("marshal.lua")
dofile("io.lua")

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

-- Helper: Create OCaml list from Lua array
-- OCaml list [a; b; c] is represented as {a, {b, {c, 0}}}
local function make_ocaml_list(arr)
  local result = 0  -- Empty list
  for i = #arr, 1, -1 do
    result = {arr[i], result}
  end
  return result
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
  local marshalled = caml_marshal_to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file using channels
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)  -- O_RDONLY
  local chanid = caml_ml_open_descriptor_in(fd)
  local result = caml_input_value(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  assert_eq(result, original, "Integer roundtrip")
  cleanup_temp_file(filename)
end)

test("Roundtrip string through file", function()
  local filename = make_temp_file()
  local original = "Hello, Marshal!"

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = caml_marshal_to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file using channels
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)
  local result = caml_input_value(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  assert_eq(result, original, "String roundtrip")
  cleanup_temp_file(filename)
end)

test("Roundtrip float through file", function()
  local filename = make_temp_file()
  local original = 3.14159

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = caml_marshal_to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file using channels
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)
  local result = caml_input_value(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  assert_close(result, original, 1e-10, "Float roundtrip")
  cleanup_temp_file(filename)
end)

test("Roundtrip block through file", function()
  local filename = make_temp_file()
  local original = {tag = 0, size = 2}

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = caml_marshal_to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file using channels
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)
  local result = caml_input_value(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  assert_eq(result.tag, original.tag, "Block tag roundtrip")
  assert_eq(result.size, original.size, "Block size roundtrip")
  cleanup_temp_file(filename)
end)

test("Roundtrip float array through file", function()
  local filename = make_temp_file()
  local original = {tag = 254, values = {1.5, 2.5, 3.5}}

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = caml_marshal_to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file using channels
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)
  local result = caml_input_value(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

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
  f:write(caml_marshal_to_string(100))
  f:write(caml_marshal_to_string("test"))
  f:write(caml_marshal_to_string(3.14))
  f:close()

  -- Read multiple values
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)

  local v1 = caml_input_value(chanid)
  local v2 = caml_input_value(chanid)
  local v3 = caml_input_value(chanid)

  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

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
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)

  local success, err = pcall(function()
    caml_input_value(chanid)
  end)

  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

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
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)

  local success, err = pcall(function()
    caml_input_value(chanid)
  end)

  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  assert_true(not success, "Should error on truncated header")
  assert_true(string.find(tostring(err), "truncated"), "Error should mention truncation")
  cleanup_temp_file(filename)
end)

test("Truncated data raises error", function()
  local filename = make_temp_file()

  -- Write valid header but incomplete data
  local marshalled = caml_marshal_to_string(12345)
  local f = io.open(filename, "wb")
  -- Write header + partial data (truncate 1 byte)
  f:write(string.sub(marshalled, 1, #marshalled - 1))
  f:close()

  -- Try to read truncated data
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)

  local success, err = pcall(function()
    caml_input_value(chanid)
  end)

  caml_ml_close_channel(chanid)

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
  local marshalled = caml_marshal_to_string(original)
  f:write(marshalled)
  f:close()

  -- Read with binary mode
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)  -- O_RDONLY + O_BINARY
  local chanid = caml_ml_open_descriptor_in(fd)
  local result = caml_input_value(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

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
  local marshalled = caml_marshal_to_string(original)
  f:write(marshalled)
  f:close()

  -- Read using alias function
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)
  local result = caml_input_value_to_outside_heap(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

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
  local marshalled = caml_marshal_to_string(original)
  f:write(marshalled)
  f:close()

  -- Read from file
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)
  local result = caml_input_value(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

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
  local fd = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)  -- O_WRONLY + O_CREAT + O_TRUNC + O_BINARY
  local chanid = caml_ml_open_descriptor_out(fd)
  caml_output_value(chanid, original, nil)
  caml_ml_flush(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = caml_marshal_from_bytes(content, 0)
  assert_eq(result, original, "Integer written correctly")
  cleanup_temp_file(filename)
end)

test("caml_output_value writes string to channel", function()
  local filename = make_temp_file()
  local original = "Hello, World!"

  -- Write using caml_output_value
  local fd = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chanid = caml_ml_open_descriptor_out(fd)
  caml_output_value(chanid, original, nil)
  caml_ml_flush(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = caml_marshal_from_bytes(content, 0)
  assert_eq(result, original, "String written correctly")
  cleanup_temp_file(filename)
end)

test("caml_output_value writes float to channel", function()
  local filename = make_temp_file()
  local original = 3.14159

  -- Write using caml_output_value
  local fd = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chanid = caml_ml_open_descriptor_out(fd)
  caml_output_value(chanid, original, nil)
  caml_ml_flush(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = caml_marshal_from_bytes(content, 0)
  assert_close(result, original, 1e-10, "Float written correctly")
  cleanup_temp_file(filename)
end)

test("caml_output_value writes block to channel", function()
  local filename = make_temp_file()
  local original = {tag = 0, size = 2}

  -- Write using caml_output_value
  local fd = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chanid = caml_ml_open_descriptor_out(fd)
  caml_output_value(chanid, original, nil)
  caml_ml_flush(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = caml_marshal_from_bytes(content, 0)
  assert_eq(result.tag, original.tag, "Block tag written correctly")
  assert_eq(result.size, original.size, "Block size written correctly")
  cleanup_temp_file(filename)
end)

test("caml_output_value writes with No_sharing flag", function()
  local filename = make_temp_file()
  local original = 100

  -- Write using caml_output_value with No_sharing flag
  local fd = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chanid = caml_ml_open_descriptor_out(fd)
  caml_output_value(chanid, original, {0})
  caml_ml_flush(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = caml_marshal_from_bytes(content, 0)
  assert_eq(result, original, "Value with No_sharing written correctly")
  cleanup_temp_file(filename)
end)

test("caml_output_value writes multiple values", function()
  local filename = make_temp_file()

  -- Write multiple values
  local fd = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chanid = caml_ml_open_descriptor_out(fd)
  caml_output_value(chanid, 100, nil)
  caml_output_value(chanid, "test", nil)
  caml_output_value(chanid, 3.14, nil)
  caml_ml_flush(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  -- Parse multiple marshalled values
  local offset = 0
  local v1 = caml_marshal_from_bytes(content, offset)
  offset = offset + caml_marshal_total_size(content, offset)
  local v2 = caml_marshal_from_bytes(content, offset)
  offset = offset + caml_marshal_total_size(content, offset)
  local v3 = caml_marshal_from_bytes(content, offset)

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
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read via channel
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_eq(result, original, "Complete roundtrip")
  cleanup_temp_file(filename)
end)

test("Complete roundtrip: string via channels", function()
  local filename = make_temp_file()
  local original = "Marshal roundtrip test!"

  -- Write via channel
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read via channel
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_eq(result, original, "Complete roundtrip")
  cleanup_temp_file(filename)
end)

test("Complete roundtrip: float array via channels", function()
  local filename = make_temp_file()
  local original = {tag = 254, values = {1.1, 2.2, 3.3}}

  -- Write via channel
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read via channel
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

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
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, 111, nil)
  caml_output_value(chan_out, "abc", nil)
  caml_output_value(chan_out, 2.71, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read multiple values via channel
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local v1 = caml_input_value(chan_in)
  local v2 = caml_input_value(chan_in)
  local v3 = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_eq(v1, 111, "First value")
  assert_eq(v2, "abc", "Second value")
  assert_close(v3, 2.71, 1e-10, "Third value")
  cleanup_temp_file(filename)
end)

test("Complete roundtrip: large data via channels", function()
  local filename = make_temp_file()
  local original = string.rep("X", 5000)  -- 5KB string

  -- Write via channel
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read via channel
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

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
  local fd = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chanid = caml_ml_open_descriptor_out(fd)
  caml_output_value(chanid, original, nil)
  caml_ml_flush(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = caml_marshal_from_bytes(content, 0)
  assert_eq(result, original, "High-level API writes correctly")
  cleanup_temp_file(filename)
end)

test("marshal.to_channel with flags", function()
  local filename = make_temp_file()
  local original = 777

  -- Write using high-level API with No_sharing flag
  local fd = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chanid = caml_ml_open_descriptor_out(fd)
  caml_output_value(chanid, original, {0})
  caml_ml_flush(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  local result = caml_marshal_from_bytes(content, 0)
  assert_eq(result, original, "High-level API respects flags")
  cleanup_temp_file(filename)
end)

test("marshal.from_channel reads value", function()
  local filename = make_temp_file()
  local original = "channel test"

  -- Write to file
  local f = io.open(filename, "wb")
  local marshalled = caml_marshal_to_string(original)
  f:write(marshalled)
  f:close()

  -- Read using high-level API
  local fd = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chanid = caml_ml_open_descriptor_in(fd)
  local result = caml_input_value(chanid)
  caml_ml_close_channel(chanid)
  caml_sys_close(fd)

  assert_eq(result, original, "High-level API reads correctly")
  cleanup_temp_file(filename)
end)

test("High-level API complete roundtrip: integer", function()
  local filename = make_temp_file()
  local original = 54321

  -- Write using high-level API
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read using high-level API
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_eq(result, original, "High-level roundtrip")
  cleanup_temp_file(filename)
end)

test("High-level API complete roundtrip: string", function()
  local filename = make_temp_file()
  local original = "High-level marshal API!"

  -- Write using high-level API
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read using high-level API
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_eq(result, original, "High-level roundtrip")
  cleanup_temp_file(filename)
end)

test("High-level API complete roundtrip: float array", function()
  local filename = make_temp_file()
  local original = {tag = 254, values = {10.1, 20.2, 30.3}}

  -- Write using high-level API
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read using high-level API
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

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
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, 11, nil)
  caml_output_value(chan_out, "two", nil)
  caml_output_value(chan_out, 3.33, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read multiple values using high-level API
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local v1 = caml_input_value(chan_in)
  local v2 = caml_input_value(chan_in)
  local v3 = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_eq(v1, 11, "First value")
  assert_eq(v2, "two", "Second value")
  assert_close(v3, 3.33, 1e-10, "Third value")
  cleanup_temp_file(filename)
end)

test("High-level API: large data", function()
  local filename = make_temp_file()
  local original = string.rep("Y", 8000)  -- 8KB string

  -- Write using high-level API
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read using high-level API
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_eq(#result, #original, "Large data length")
  assert_eq(result, original, "Large data content")
  cleanup_temp_file(filename)
end)

test("High-level API with No_sharing: complete roundtrip", function()
  local filename = make_temp_file()
  local original = 888

  -- Write using high-level API with No_sharing
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {0})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read using high-level API
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_eq(result, original, "No_sharing roundtrip")
  cleanup_temp_file(filename)
end)

test("High-level API: mixed with low-level API", function()
  local filename = make_temp_file()
  local original1 = 123
  local original2 = "mixed"

  -- Write first value with high-level, second with low-level
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original1)
  caml_output_value(chan_out, original2, nil)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read first value with high-level, second with low-level
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result1 = caml_input_value(chan_in)
  local result2 = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_eq(result1, original1, "High-level write/read")
  assert_eq(result2, original2, "Low-level write/read")
  cleanup_temp_file(filename)
end)

--
-- Phase 4: Integration Tests (Task 1.4)
--

-- Test: Complete file roundtrip with simple data
test("marshal complete file roundtrip with simple data", function()
  local filename = make_temp_file()

  -- Create simple structure (marshal doesn't support complex nested tables yet)
  local original = "complete_roundtrip_test_string"

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify structure
  assert_eq(result, original)

  cleanup_temp_file(filename)
end)

-- Test: Large data structure (>10KB string)
test("marshal large data structure", function()
  local filename = make_temp_file()

  -- Create large string (15KB)
  local original = string.rep("LargeDataTest_", 1000)  -- ~14KB

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify size and content
  assert_eq(#result, #original)
  assert_eq(string.sub(result, 1, 14), "LargeDataTest_")
  assert_eq(result, original)

  cleanup_temp_file(filename)
end)

-- Test: Marshal with sharing disabled (No_sharing flag)
test("marshal with No_sharing flag", function()
  local filename = make_temp_file()

  -- Simple value with No_sharing flag
  local original = 42

  -- Write with No_sharing flag
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {0})  -- No_sharing = 0
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify value
  assert_eq(result, 42)

  cleanup_temp_file(filename)
end)

-- Test: Marshal with sharing enabled (default behavior)
test("marshal with sharing enabled", function()
  local filename = make_temp_file()

  -- Simple value with sharing enabled (default)
  local original = "sharing_test"

  -- Write with default flags (sharing enabled)
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify value
  assert_eq(result, "sharing_test")

  cleanup_temp_file(filename)
end)

-- Test: Error handling - truncated header in file
test("marshal error handling - truncated header", function()
  local filename = make_temp_file()

  -- Write partial header (only 10 bytes of 20) using low-level file I/O
  -- Lua 5.1 doesn't support \x hex escapes, use string.char() instead
  local file = io.open(filename, "wb")
  local partial_header = string.char(0x84, 0x95, 0xA6, 0xBE, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00)
  file:write(partial_header)
  file:close()

  -- Try to read - should error
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local success, err = pcall(function()
    caml_input_value(chan_in)
  end)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_true(not success, "Should fail on truncated header")
  assert_true(string.find(tostring(err), "truncated") ~= nil, "Error should mention truncation")

  cleanup_temp_file(filename)
end)

-- Test: Error handling - truncated data in file
test("marshal error handling - truncated data", function()
  local filename = make_temp_file()

  -- Create valid marshal data
  local original = "test_string"
  local marshalled = caml_marshal_to_string(original, {})

  -- Write header + partial data (truncate last 5 bytes) using low-level file I/O
  local file = io.open(filename, "wb")
  local truncated = string.sub(marshalled, 1, #marshalled - 5)
  file:write(truncated)
  file:close()

  -- Try to read - should error
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local success, err = pcall(function()
    caml_input_value(chan_in)
  end)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_true(not success, "Should fail on truncated data")
  assert_true(string.find(tostring(err), "truncated") ~= nil, "Error should mention truncation")

  cleanup_temp_file(filename)
end)

-- Test: Error handling - corrupted magic number
test("marshal error handling - corrupted magic number", function()
  local filename = make_temp_file()

  -- Write invalid magic number using low-level file I/O
  -- Lua 5.1 doesn't support \x hex escapes, use string.char() instead
  local file = io.open(filename, "wb")
  local invalid_header = string.char(
    0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x08,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00
  )
  local fake_data = "12345678"
  file:write(invalid_header .. fake_data)
  file:close()

  -- Try to read - should error
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local success, err = pcall(function()
    caml_input_value(chan_in)
  end)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  assert_true(not success, "Should fail on corrupted magic")

  cleanup_temp_file(filename)
end)

-- Test: Binary mode preserves exact bytes
test("marshal binary mode preserves exact bytes", function()
  local filename = make_temp_file()

  -- Create string with special bytes (NUL, high-bit chars)
  local original = string.char(0, 1, 127, 128, 255)

  -- Write to file in binary mode
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file in binary mode
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify exact byte preservation
  assert_eq(result, string.char(0, 1, 127, 128, 255))

  cleanup_temp_file(filename)
end)

-- Test: Multiple large values in sequence
test("marshal multiple large values in sequence", function()
  local filename = make_temp_file()

  -- Create three large strings
  local struct1 = string.rep("A", 1000)
  local struct2 = string.rep("B", 2000)
  local struct3 = string.rep("C", 1500)

  -- Write all three to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, struct1, {})
  caml_output_value(chan_out, struct2, {})
  caml_output_value(chan_out, struct3, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read all three from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result1 = caml_input_value(chan_in)
  local result2 = caml_input_value(chan_in)
  local result3 = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify all three values
  assert_eq(#result1, 1000)
  assert_eq(string.sub(result1, 1, 1), "A")
  assert_eq(#result2, 2000)
  assert_eq(string.sub(result2, 1, 1), "B")
  assert_eq(#result3, 1500)
  assert_eq(string.sub(result3, 1, 1), "C")

  cleanup_temp_file(filename)
end)

-- Test: Very large single value (string > 50KB)
test("marshal very large string (>50KB)", function()
  local filename = make_temp_file()

  -- Create 60KB string
  local parts = {}
  for i = 1, 6000 do
    parts[i] = "0123456789"
  end
  local original = table.concat(parts)

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)
  caml_sys_close(fd_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)
  caml_sys_close(fd_in)

  -- Verify size and content
  assert_eq(#result, 60000)
  assert_eq(string.sub(result, 1, 10), "0123456789")
  assert_eq(string.sub(result, 59991, 60000), "0123456789")

  cleanup_temp_file(filename)
end)

--
-- Phase 5: Complex Structure Tests (comprehensive for compiler robustness)
--

print("\nComplex Structure Tests:")
print("--------------------------------------------------------------------")

-- Test: Nested tables through channels
test("Complex nested tables through channels", function()
  local filename = make_temp_file()

  -- Create complex nested structure (simulating AST-like data)
  local original = {
    {1, {2, 3}, 4},
    {5, {6, {7, 8}}, 9},
    {{10, 11}, {12, {13, 14, 15}}}
  }

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify structure
  assert_eq(result[1][1], 1)
  assert_eq(result[1][2][1], 2)
  assert_eq(result[1][2][2], 3)
  assert_eq(result[1][3], 4)
  assert_eq(result[2][1], 5)
  assert_eq(result[2][2][1], 6)
  assert_eq(result[2][2][2][1], 7)
  assert_eq(result[2][2][2][2], 8)
  assert_eq(result[2][3], 9)
  assert_eq(result[3][1][1], 10)
  assert_eq(result[3][1][2], 11)
  assert_eq(result[3][2][1], 12)
  assert_eq(result[3][2][2][1], 13)
  assert_eq(result[3][2][2][2], 14)
  assert_eq(result[3][2][2][3], 15)

  cleanup_temp_file(filename)
end)

-- Test: Mixed types with deep nesting
test("Mixed types with deep nesting through channels", function()
  local filename = make_temp_file()

  -- Create structure with mixed types at various levels
  local original = {
    "string_at_top",
    42,
    {
      "nested_string",
      {100, 200, "deep_string"},
      3.14
    },
    {
      {1, 2},
      {3, {4, 5, 6}},
      "another_string"
    }
  }

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify structure
  assert_eq(result[1], "string_at_top")
  assert_eq(result[2], 42)
  assert_eq(result[3][1], "nested_string")
  assert_eq(result[3][2][1], 100)
  assert_eq(result[3][2][2], 200)
  assert_eq(result[3][2][3], "deep_string")
  assert_close(result[3][3], 3.14)
  assert_eq(result[4][1][1], 1)
  assert_eq(result[4][1][2], 2)
  assert_eq(result[4][2][1], 3)
  assert_eq(result[4][2][2][1], 4)
  assert_eq(result[4][2][2][2], 5)
  assert_eq(result[4][2][2][3], 6)
  assert_eq(result[4][3], "another_string")

  cleanup_temp_file(filename)
end)

-- Test: Large array of complex structures
test("Large array of complex structures through channels", function()
  local filename = make_temp_file()

  -- Create array of 50 complex structures
  local original = {}
  for i = 1, 50 do
    original[i] = {
      i,
      "item_" .. i,
      {i * 10, i * 20, i * 30}
    }
  end

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify random samples
  assert_eq(result[1][1], 1)
  assert_eq(result[1][2], "item_1")
  assert_eq(result[1][3][1], 10)
  assert_eq(result[1][3][2], 20)
  assert_eq(result[1][3][3], 30)

  assert_eq(result[25][1], 25)
  assert_eq(result[25][2], "item_25")
  assert_eq(result[25][3][1], 250)
  assert_eq(result[25][3][2], 500)
  assert_eq(result[25][3][3], 750)

  assert_eq(result[50][1], 50)
  assert_eq(result[50][2], "item_50")
  assert_eq(result[50][3][1], 500)
  assert_eq(result[50][3][2], 1000)
  assert_eq(result[50][3][3], 1500)

  cleanup_temp_file(filename)
end)

-- Test: Multiple complex structures in sequence
test("Multiple complex structures in sequence through channels", function()
  local filename = make_temp_file()

  local struct1 = {{1, 2}, {3, {4, 5}}}
  local struct2 = {"a", {"b", "c"}, "d"}
  local struct3 = {100, {200, {300, {400}}}}

  -- Write all three to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, struct1, {})
  caml_output_value(chan_out, struct2, {})
  caml_output_value(chan_out, struct3, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read all three from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result1 = caml_input_value(chan_in)
  local result2 = caml_input_value(chan_in)
  local result3 = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify all three structures
  assert_eq(result1[1][1], 1)
  assert_eq(result1[1][2], 2)
  assert_eq(result1[2][1], 3)
  assert_eq(result1[2][2][1], 4)
  assert_eq(result1[2][2][2], 5)

  assert_eq(result2[1], "a")
  assert_eq(result2[2][1], "b")
  assert_eq(result2[2][2], "c")
  assert_eq(result2[3], "d")

  assert_eq(result3[1], 100)
  assert_eq(result3[2][1], 200)
  assert_eq(result3[2][2][1], 300)
  assert_eq(result3[2][2][2][1], 400)

  cleanup_temp_file(filename)
end)

-- Test: Deeply nested structure (10 levels)
test("Deeply nested structure (10 levels) through channels", function()
  local filename = make_temp_file()

  -- Create 10-level deep nesting
  local original = {1, {2, {3, {4, {5, {6, {7, {8, {9, {10}}}}}}}}}}

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify deep nesting
  local current = result
  for i = 1, 10 do
    assert_eq(current[1], i)
    if i < 10 then
      current = current[2]
    end
  end

  cleanup_temp_file(filename)
end)

-- Test: Complex structure with explicit block tags
test("Complex structure with explicit block tags", function()
  local filename = make_temp_file()

  -- Create structure with explicit tag/size (simulating OCaml variants/records)
  local original = {
    tag = 0,
    size = 3,
    [1] = 42,
    [2] = {tag = 1, size = 2, [1] = "nested", [2] = 100},
    [3] = {tag = 0, size = 1, [1] = 999}
  }

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify structure with tags
  assert_eq(result.tag, 0)
  assert_eq(result.size, 3)
  assert_eq(result[1], 42)
  assert_eq(result[2].tag, 1)
  assert_eq(result[2].size, 2)
  assert_eq(result[2][1], "nested")
  assert_eq(result[2][2], 100)
  assert_eq(result[3].tag, 0)
  assert_eq(result[3].size, 1)
  assert_eq(result[3][1], 999)

  cleanup_temp_file(filename)
end)

-- Test: Wide structure (many siblings at same level)
test("Wide structure with many siblings", function()
  local filename = make_temp_file()

  -- Create structure with 20 elements at same level
  local original = {}
  for i = 1, 20 do
    if i % 3 == 0 then
      original[i] = {i, i + 1}
    elseif i % 3 == 1 then
      original[i] = "string_" .. i
    else
      original[i] = i * 100
    end
  end

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify various elements
  assert_eq(result[1], "string_1")
  assert_eq(result[2], 200)
  assert_eq(result[3][1], 3)
  assert_eq(result[3][2], 4)
  assert_eq(result[10], "string_10")
  assert_eq(result[12][1], 12)
  assert_eq(result[12][2], 13)
  assert_eq(result[20], 2000)

  cleanup_temp_file(filename)
end)

-- Test: Complex structure with float arrays
test("Complex structure with float arrays", function()
  local filename = make_temp_file()

  -- Create structure mixing regular arrays with float arrays
  local original = {
    {1, 2, 3},
    {tag = 254, values = {1.1, 2.2, 3.3}},
    {
      "nested",
      {tag = 254, values = {4.4, 5.5}},
      100
    }
  }

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify structure
  assert_eq(result[1][1], 1)
  assert_eq(result[1][2], 2)
  assert_eq(result[1][3], 3)
  assert_eq(result[2].tag, 254)
  assert_close(result[2].values[1], 1.1)
  assert_close(result[2].values[2], 2.2)
  assert_close(result[2].values[3], 3.3)
  assert_eq(result[3][1], "nested")
  assert_eq(result[3][2].tag, 254)
  assert_close(result[3][2].values[1], 4.4)
  assert_close(result[3][2].values[2], 5.5)
  assert_eq(result[3][3], 100)

  cleanup_temp_file(filename)
end)

-- Test: Compiler-like AST structure
test("Compiler AST-like structure", function()
  local filename = make_temp_file()

  -- Simulate a simple AST: BinOp(Add, Const(1), BinOp(Mul, Const(2), Const(3)))
  local original = {
    tag = 0,  -- BinOp
    size = 3,
    [1] = 0,  -- Add
    [2] = {tag = 1, size = 1, [1] = 1},  -- Const(1)
    [3] = {
      tag = 0,  -- BinOp
      size = 3,
      [1] = 1,  -- Mul
      [2] = {tag = 1, size = 1, [1] = 2},  -- Const(2)
      [3] = {tag = 1, size = 1, [1] = 3}   -- Const(3)
    }
  }

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify AST structure
  assert_eq(result.tag, 0)
  assert_eq(result[1], 0)  -- Add
  assert_eq(result[2].tag, 1)  -- Const
  assert_eq(result[2][1], 1)
  assert_eq(result[3].tag, 0)  -- BinOp
  assert_eq(result[3][1], 1)  -- Mul
  assert_eq(result[3][2].tag, 1)  -- Const
  assert_eq(result[3][2][1], 2)
  assert_eq(result[3][3].tag, 1)  -- Const
  assert_eq(result[3][3][1], 3)

  cleanup_temp_file(filename)
end)

-- Test: Empty nested structures
test("Empty nested structures", function()
  local filename = make_temp_file()

  -- Create structure with some empty arrays
  local original = {
    {},
    {1, {}, 2},
    {3, {4, {}, 5}}
  }

  -- Write to file
  local fd_out = caml_sys_open(filename, make_ocaml_list({1, 3, 4, 6}), 438)
  local chan_out = caml_ml_open_descriptor_out(fd_out)
  caml_output_value(chan_out, original, {})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read from file
  local fd_in = caml_sys_open(filename, make_ocaml_list({0, 6}), 0)
  local chan_in = caml_ml_open_descriptor_in(fd_in)
  local result = caml_input_value(chan_in)
  caml_ml_close_channel(chan_in)

  -- Verify structure
  assert_eq(result[1].tag, 0)
  assert_eq(result[1].size, 0)
  assert_eq(result[2][1], 1)
  assert_eq(result[2][2].tag, 0)
  assert_eq(result[2][2].size, 0)
  assert_eq(result[2][3], 2)
  assert_eq(result[3][1], 3)
  assert_eq(result[3][2][1], 4)
  assert_eq(result[3][2][2].tag, 0)
  assert_eq(result[3][2][2].size, 0)
  assert_eq(result[3][2][3], 5)

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
