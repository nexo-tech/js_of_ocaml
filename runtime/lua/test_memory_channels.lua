#!/usr/bin/env lua
-- Test suite for in-memory channels (Task 10.1)
--
-- Tests string-based input channels, buffer-based output channels,
-- and marshal integration with memory channels.

-- Preload our runtime modules (they clash with standard Lua modules)
package.loaded.io = dofile("io.lua")
local io_module = package.loaded.io

local marshal = require("marshal")
local buffer = require("buffer")

-- Test counter
local test_count = 0
local pass_count = 0

-- Helper: assert with test name
local function test(name, condition, message)
  test_count = test_count + 1
  if condition then
    pass_count = pass_count + 1
    print(string.format("✓ Test %d: %s", test_count, name))
  else
    print(string.format("✗ Test %d: %s - %s", test_count, name, message or "assertion failed"))
    os.exit(1)
  end
end

-- Helper: create OCaml list
local function make_list(tbl)
  local list = 0
  for i = #tbl, 1, -1 do
    list = {tag = 0, [1] = tbl[i], [2] = list}
  end
  return list
end

print("========================================")
print("Memory Channels Test Suite")
print("========================================")
print("")

-- ========================================
-- String Input Channels
-- ========================================

print("String Input Channels")
print("----------------------------------------")

-- Test 1: Create string input channel
local str = "Hello, World!"
local chan_in = io_module.caml_ml_open_string_in(str)
test("Create string input channel", chan_in ~= nil, "Failed to create channel")

-- Test 2: Read single character from string
local c = io_module.caml_ml_input_char(chan_in)
test("Read single char from string", c == string.byte("H"),
  string.format("Expected %d, got %d", string.byte("H"), c))

-- Test 3: Read multiple characters
local buf = {}
local bytes_read = io_module.caml_ml_input(chan_in, buf, 0, 5)
local chars = {}
for i = 1, bytes_read do
  table.insert(chars, string.char(buf[i]))
end
local result = table.concat(chars)
test("Read 5 chars from string", result == "ello,",
  string.format("Expected 'ello,', got '%s'", result))

-- Test 4: Read remaining characters
buf = {}
bytes_read = io_module.caml_ml_input(chan_in, buf, 0, 100)
chars = {}
for i = 1, bytes_read do
  table.insert(chars, string.char(buf[i]))
end
result = table.concat(chars)
test("Read remaining chars", result == " World!",
  string.format("Expected ' World!', got '%s'", result))

-- Test 5: End of string detection
local ok, err = pcall(io_module.caml_ml_input_char, chan_in)
test("End of string error", not ok and string.find(err, "End_of_file"),
  "Should raise End_of_file error")

-- Test 6: Close string input channel
io_module.caml_ml_close_channel(chan_in)
test("Close string input channel", true)

-- Test 7: Read from closed channel
ok, err = pcall(io_module.caml_ml_input_char, chan_in)
test("Read from closed string channel", not ok and string.find(err, "closed"),
  "Should raise channel closed error")

print("")

-- ========================================
-- Buffer Output Channels
-- ========================================

print("Buffer Output Channels")
print("----------------------------------------")

-- Test 8: Create buffer output channel
local chan_out = io_module.caml_ml_open_buffer_out()
test("Create buffer output channel", chan_out ~= nil, "Failed to create channel")

-- Test 9: Write single character to buffer
io_module.caml_ml_output_char(chan_out, string.byte("A"))
local contents = io_module.caml_ml_buffer_contents(chan_out)
test("Write single char to buffer", contents == "A",
  string.format("Expected 'A', got '%s'", contents))

-- Test 10: Write string to buffer
io_module.caml_ml_output(chan_out, "BCD", 0, 3)
contents = io_module.caml_ml_buffer_contents(chan_out)
test("Write string to buffer", contents == "ABCD",
  string.format("Expected 'ABCD', got '%s'", contents))

-- Test 11: Reset buffer
io_module.caml_ml_buffer_reset(chan_out)
contents = io_module.caml_ml_buffer_contents(chan_out)
test("Reset buffer", contents == "",
  string.format("Expected empty string, got '%s'", contents))

-- Test 12: Write after reset
io_module.caml_ml_output(chan_out, "XYZ", 0, 3)
contents = io_module.caml_ml_buffer_contents(chan_out)
test("Write after reset", contents == "XYZ",
  string.format("Expected 'XYZ', got '%s'", contents))

-- Test 13: Close buffer output channel
io_module.caml_ml_close_channel(chan_out)
test("Close buffer output channel", true)

-- Test 14: Write to closed channel
ok, err = pcall(io_module.caml_ml_output_char, chan_out, string.byte("A"))
test("Write to closed buffer channel", not ok and string.find(err, "closed"),
  "Should raise channel closed error")

print("")

-- ========================================
-- Marshal Integration - Output
-- ========================================

print("Marshal Integration - Output")
print("----------------------------------------")

-- Test 15: Marshal integer to buffer
chan_out = io_module.caml_ml_open_buffer_out()
marshal.to_channel(chan_out, 42, {tag = 0})
contents = io_module.caml_ml_buffer_contents(chan_out)
test("Marshal integer to buffer", #contents > 0,
  "Buffer should contain marshalled data")

-- Test 16: Marshal string to buffer
io_module.caml_ml_buffer_reset(chan_out)
marshal.to_channel(chan_out, "Hello", {tag = 0})
contents = io_module.caml_ml_buffer_contents(chan_out)
test("Marshal string to buffer", #contents > 5,
  string.format("Buffer should contain marshalled string (got %d bytes)", #contents))

-- Test 17: Marshal list to buffer
io_module.caml_ml_buffer_reset(chan_out)
local list = make_list({1, 2, 3, 4, 5})
marshal.to_channel(chan_out, list, {tag = 0})
contents = io_module.caml_ml_buffer_contents(chan_out)
test("Marshal list to buffer", #contents > 0,
  string.format("Buffer should contain marshalled list (got %d bytes)", #contents))

-- Test 18: Marshal multiple values
io_module.caml_ml_buffer_reset(chan_out)
marshal.to_channel(chan_out, 10, {tag = 0})
marshal.to_channel(chan_out, 20, {tag = 0})
marshal.to_channel(chan_out, 30, {tag = 0})
contents = io_module.caml_ml_buffer_contents(chan_out)
test("Marshal multiple values", #contents > 0,
  string.format("Buffer should contain multiple marshalled values (got %d bytes)", #contents))

io_module.caml_ml_close_channel(chan_out)

print("")

-- ========================================
-- Marshal Integration - Input
-- ========================================

print("Marshal Integration - Input")
print("----------------------------------------")

-- Test 19: Unmarshal integer from string
local marshalled_int = marshal.to_string(42, {tag = 0})
chan_in = io_module.caml_ml_open_string_in(marshalled_int)
local value = marshal.from_channel(chan_in)
test("Unmarshal integer from string", value == 42,
  string.format("Expected 42, got %s", tostring(value)))
io_module.caml_ml_close_channel(chan_in)

-- Test 20: Unmarshal string from string
local marshalled_str = marshal.to_string("Hello, World!", {tag = 0})
chan_in = io_module.caml_ml_open_string_in(marshalled_str)
value = marshal.from_channel(chan_in)
test("Unmarshal string from string", value == "Hello, World!",
  string.format("Expected 'Hello, World!', got '%s'", tostring(value)))
io_module.caml_ml_close_channel(chan_in)

-- Test 21: Unmarshal list from string
local test_list = make_list({10, 20, 30})
local marshalled_list = marshal.to_string(test_list, {tag = 0})
chan_in = io_module.caml_ml_open_string_in(marshalled_list)
value = marshal.from_channel(chan_in)
test("Unmarshal list from string", value[1] == 10 and value[2][1] == 20 and value[2][2][1] == 30,
  "List structure should match")
io_module.caml_ml_close_channel(chan_in)

-- Test 22: Unmarshal multiple values from string
marshalled_int = marshal.to_string(100, {tag = 0})
local marshalled_str2 = marshal.to_string("test", {tag = 0})
local combined = marshalled_int .. marshalled_str2
chan_in = io_module.caml_ml_open_string_in(combined)
local v1 = marshal.from_channel(chan_in)
local v2 = marshal.from_channel(chan_in)
test("Unmarshal multiple values", v1 == 100 and v2 == "test",
  string.format("Expected 100 and 'test', got %s and %s", tostring(v1), tostring(v2)))
io_module.caml_ml_close_channel(chan_in)

print("")

-- ========================================
-- Round-trip Marshal Tests
-- ========================================

print("Round-trip Marshal Tests")
print("----------------------------------------")

-- Test 23: Integer round-trip
chan_out = io_module.caml_ml_open_buffer_out()
marshal.to_channel(chan_out, 999, {tag = 0})
contents = io_module.caml_ml_buffer_contents(chan_out)
io_module.caml_ml_close_channel(chan_out)

chan_in = io_module.caml_ml_open_string_in(contents)
value = marshal.from_channel(chan_in)
io_module.caml_ml_close_channel(chan_in)
test("Integer round-trip", value == 999,
  string.format("Expected 999, got %s", tostring(value)))

-- Test 24: String round-trip
chan_out = io_module.caml_ml_open_buffer_out()
marshal.to_channel(chan_out, "Round-trip test!", {tag = 0})
contents = io_module.caml_ml_buffer_contents(chan_out)
io_module.caml_ml_close_channel(chan_out)

chan_in = io_module.caml_ml_open_string_in(contents)
value = marshal.from_channel(chan_in)
io_module.caml_ml_close_channel(chan_in)
test("String round-trip", value == "Round-trip test!",
  string.format("Expected 'Round-trip test!', got '%s'", tostring(value)))

-- Test 25: List round-trip
chan_out = io_module.caml_ml_open_buffer_out()
list = make_list({5, 10, 15, 20, 25})
marshal.to_channel(chan_out, list, {tag = 0})
contents = io_module.caml_ml_buffer_contents(chan_out)
io_module.caml_ml_close_channel(chan_out)

chan_in = io_module.caml_ml_open_string_in(contents)
value = marshal.from_channel(chan_in)
io_module.caml_ml_close_channel(chan_in)
test("List round-trip",
  value[1] == 5 and value[2][1] == 10 and value[2][2][1] == 15 and
  value[2][2][2][1] == 20 and value[2][2][2][2][1] == 25,
  "List structure should match original")

-- Test 26: Complex structure round-trip
chan_out = io_module.caml_ml_open_buffer_out()
local complex = {tag = 0, [1] = 42, [2] = "test", [3] = make_list({1, 2, 3})}
marshal.to_channel(chan_out, complex, {tag = 0})
contents = io_module.caml_ml_buffer_contents(chan_out)
io_module.caml_ml_close_channel(chan_out)

chan_in = io_module.caml_ml_open_string_in(contents)
value = marshal.from_channel(chan_in)
io_module.caml_ml_close_channel(chan_in)
test("Complex structure round-trip",
  value.tag == 0 and value[1] == 42 and value[2] == "test" and value[3][1] == 1,
  "Complex structure should match original")

print("")

-- ========================================
-- Edge Cases
-- ========================================

print("Edge Cases")
print("----------------------------------------")

-- Test 27: Empty string input
chan_in = io_module.caml_ml_open_string_in("")
ok, err = pcall(io_module.caml_ml_input_char, chan_in)
test("Read from empty string", not ok and string.find(err, "End_of_file"),
  "Should raise End_of_file immediately")
io_module.caml_ml_close_channel(chan_in)

-- Test 28: Empty buffer output
chan_out = io_module.caml_ml_open_buffer_out()
contents = io_module.caml_ml_buffer_contents(chan_out)
test("Empty buffer contents", contents == "",
  string.format("Expected empty string, got '%s'", contents))
io_module.caml_ml_close_channel(chan_out)

-- Test 29: Large string input
local large_str = string.rep("X", 10000)
chan_in = io_module.caml_ml_open_string_in(large_str)
buf = {}
bytes_read = io_module.caml_ml_input(chan_in, buf, 0, 10000)
test("Read large string", bytes_read == 10000,
  string.format("Expected 10000 bytes, got %d", bytes_read))
io_module.caml_ml_close_channel(chan_in)

-- Test 30: Large buffer output
chan_out = io_module.caml_ml_open_buffer_out()
for i = 1, 1000 do
  io_module.caml_ml_output_char(chan_out, string.byte("Y"))
end
contents = io_module.caml_ml_buffer_contents(chan_out)
test("Large buffer output", #contents == 1000,
  string.format("Expected 1000 bytes, got %d", #contents))
io_module.caml_ml_close_channel(chan_out)

-- Test 31: Partial read from string
str = "ABCDEFGH"
chan_in = io_module.caml_ml_open_string_in(str)
buf = {}
bytes_read = io_module.caml_ml_input(chan_in, buf, 0, 3)
chars = {}
for i = 1, bytes_read do
  table.insert(chars, string.char(buf[i]))
end
result = table.concat(chars)
test("Partial read from string (first)", result == "ABC",
  string.format("Expected 'ABC', got '%s'", result))

buf = {}
bytes_read = io_module.caml_ml_input(chan_in, buf, 0, 3)
chars = {}
for i = 1, bytes_read do
  table.insert(chars, string.char(buf[i]))
end
result = table.concat(chars)
test("Partial read from string (second)", result == "DEF",
  string.format("Expected 'DEF', got '%s'", result))
io_module.caml_ml_close_channel(chan_in)

-- Test 33: Multiple reset operations
chan_out = io_module.caml_ml_open_buffer_out()
io_module.caml_ml_output(chan_out, "First", 0, 5)
io_module.caml_ml_buffer_reset(chan_out)
io_module.caml_ml_output(chan_out, "Second", 0, 6)
io_module.caml_ml_buffer_reset(chan_out)
io_module.caml_ml_output(chan_out, "Third", 0, 5)
contents = io_module.caml_ml_buffer_contents(chan_out)
test("Multiple reset operations", contents == "Third",
  string.format("Expected 'Third', got '%s'", contents))
io_module.caml_ml_close_channel(chan_out)

print("")

-- ========================================
-- Summary
-- ========================================

print("========================================")
print(string.format("Tests completed: %d/%d passed", pass_count, test_count))
print("========================================")

if pass_count == test_count then
  print("✓ All tests passed!")
  os.exit(0)
else
  print(string.format("✗ %d tests failed", test_count - pass_count))
  os.exit(1)
end
