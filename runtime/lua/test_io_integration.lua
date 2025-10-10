#!/usr/bin/env lua
-- Test suite for I/O integration
-- Comprehensive tests for marshal + channels + files

-- Load our runtime modules (all refactored to use global functions)
dofile("core.lua")
dofile("fail.lua")
dofile("marshal.lua")
dofile("format.lua")
dofile("io.lua")

local test_count = 0
local pass_count = 0
local fail_count = 0

local function test(name, fn)
  test_count = test_count + 1
  io.write(string.format("Test %d: %s ... ", test_count, name))
  io.flush()

  local ok, err = pcall(fn)
  if ok then
    pass_count = pass_count + 1
    print("PASS")
  else
    fail_count = fail_count + 1
    print("FAIL")
    print("  Error: " .. tostring(err))
  end
end

local function assert_equal(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s",
      msg or "assertion failed",
      tostring(expected),
      tostring(actual)))
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "expected true")
  end
end

local function assert_error(fn, msg)
  local ok = pcall(fn)
  if ok then
    error(msg or "expected error but function succeeded")
  end
end

-- Helper: create OCaml list from Lua table
local function make_list(tbl)
  local list = 0  -- Empty list is 0
  for i = #tbl, 1, -1 do
    list = {tag = 0, [1] = tbl[i], [2] = list}
  end
  return list
end

-- Helper: convert OCaml list to Lua table
local function list_to_table(list)
  local result = {}
  while type(list) == "table" and list.tag == 0 and list[1] do
    table.insert(result, list[1])
    list = list[2] or 0
  end
  return result
end

-- Helper: cleanup test file
local function cleanup_file(path)
  os.remove(path)
end

-- Helper: open file for writing and get channel
local function open_write(filename, binary)
  local flags = make_list(binary and {1, 3, 4, 6} or {1, 3, 4})  -- WRONLY, CREAT, TRUNC, [BINARY]
  local fd = caml_sys_open(filename, flags, 420)  -- 0644 octal = 420 decimal
  return caml_ml_open_descriptor_out(fd)
end

-- Helper: open file for reading and get channel
local function open_read(filename, binary)
  local flags = make_list(binary and {0, 6} or {0})  -- RDONLY, [BINARY]
  local fd = caml_sys_open(filename, flags, 0)
  return caml_ml_open_descriptor_in(fd)
end

-- Helper: write string to channel
local function output_string(chan, str)
  caml_ml_output(chan, str, 0, #str)
end

-- Helper: input string from channel
local function input_string(chan, len)
  local buf = {}
  local bytes_read = caml_ml_input(chan, buf, 0, len)
  local chars = {}
  for i = 1, bytes_read do
    table.insert(chars, string.char(buf[i]))
  end
  return table.concat(chars)
end

-- Helper: input line from channel (simulate input_line)
local function input_line(chan)
  local chars = {}
  while true do
    local ok, c = pcall(caml_ml_input_char, chan)
    if not ok then
      if #chars == 0 then
        error("End_of_file")
      end
      break
    end
    if c == string.byte("\n") then
      break
    end
    table.insert(chars, string.char(c))
  end
  return table.concat(chars)
end

print("=== I/O Integration Tests ===\n")

-- Test 1-5: Marshal + Channels + Files
test("marshal int to file and read back", function()
  local filename = "/tmp/test_marshal_int.dat"

  -- Write
  local chan_out = open_write(filename, true)
  marshal.to_channel(chan_out, 42, {tag = 0})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read
  local chan_in = open_read(filename, true)
  local value = marshal.from_channel(chan_in)
  caml_ml_close_channel(chan_in)

  assert_equal(value, 42, "should read back 42")
  cleanup_file(filename)
end)

test("marshal string to file and read back", function()
  local filename = "/tmp/test_marshal_string.dat"

  -- Write
  local chan_out = open_write(filename, true)
  marshal.to_channel(chan_out, "hello world", {tag = 0})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read
  local chan_in = open_read(filename, true)
  local value = marshal.from_channel(chan_in)
  caml_ml_close_channel(chan_in)

  assert_equal(value, "hello world", "should read back string")
  cleanup_file(filename)
end)

test("marshal list to file and read back", function()
  local filename = "/tmp/test_marshal_list.dat"
  local list = make_list({1, 2, 3, 4, 5})

  -- Write
  local chan_out = open_write(filename, true)
  marshal.to_channel(chan_out, list, {tag = 0})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read
  local chan_in = open_read(filename, true)
  local value = marshal.from_channel(chan_in)
  caml_ml_close_channel(chan_in)

  local result = list_to_table(value)
  assert_equal(#result, 5)
  assert_equal(result[1], 1)
  assert_equal(result[5], 5)
  cleanup_file(filename)
end)

test("marshal multiple values to same file", function()
  local filename = "/tmp/test_marshal_multiple.dat"

  -- Write multiple values
  local chan_out = open_write(filename, true)
  marshal.to_channel(chan_out, 42, {tag = 0})
  marshal.to_channel(chan_out, "hello", {tag = 0})
  marshal.to_channel(chan_out, make_list({1, 2, 3}), {tag = 0})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Read back in order
  local chan_in = open_read(filename, true)
  local v1 = marshal.from_channel(chan_in)
  local v2 = marshal.from_channel(chan_in)
  local v3 = marshal.from_channel(chan_in)
  caml_ml_close_channel(chan_in)

  assert_equal(v1, 42)
  assert_equal(v2, "hello")
  local list_result = list_to_table(v3)
  assert_equal(#list_result, 3)
  cleanup_file(filename)
end)

test("marshal value sizes", function()
  local filename = "/tmp/test_marshal_sizes.dat"

  -- Write a value
  local chan_out = open_write(filename, true)
  marshal.to_channel(chan_out, 12345, {tag = 0})
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  -- Get file size
  local f = io.open(filename, "rb")
  local size = f:seek("end")
  f:close()

  assert_true(size > 0, "marshal should write data")
  cleanup_file(filename)
end)

-- Test 6-10: Printf with channels
test("fprintf to file", function()
  local filename = "/tmp/test_fprintf.txt"

  local chan = open_write(filename, true)
  format.caml_fprintf(chan, "Number: %d, String: %s\n", 42, "hello")
  caml_ml_flush(chan)
  caml_ml_close_channel(chan)

  -- Read back and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_equal(content, "Number: 42, String: hello\n")
  cleanup_file(filename)
end)

test("fprintf multiple lines", function()
  local filename = "/tmp/test_fprintf_multi.txt"

  local chan = open_write(filename, true)
  format.caml_fprintf(chan, "Line 1: %d\n", 1)
  format.caml_fprintf(chan, "Line 2: %d\n", 2)
  format.caml_fprintf(chan, "Line 3: %d\n", 3)
  caml_ml_flush(chan)
  caml_ml_close_channel(chan)

  -- Read and verify
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_true(content:match("Line 1: 1"))
  assert_true(content:match("Line 2: 2"))
  assert_true(content:match("Line 3: 3"))
  cleanup_file(filename)
end)

test("fprintf with float", function()
  local filename = "/tmp/test_fprintf_float.txt"

  local chan = open_write(filename, true)
  format.caml_fprintf(chan, "Pi: %.2f", 3.14159)
  caml_ml_flush(chan)
  caml_ml_close_channel(chan)

  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_equal(content, "Pi: 3.14")
  cleanup_file(filename)
end)

test("fprintf with multiple formats", function()
  local filename = "/tmp/test_fprintf_multi_fmt.txt"

  local chan = open_write(filename, true)
  format.caml_fprintf(chan, "%s = %d (0x%x)", "answer", 42, 42)
  caml_ml_flush(chan)
  caml_ml_close_channel(chan)

  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_true(content:match("answer"))
  assert_true(content:match("42"))
  cleanup_file(filename)
end)

test("fprintf with percent escape", function()
  local filename = "/tmp/test_fprintf_percent.txt"

  local chan = open_write(filename, true)
  format.caml_fprintf(chan, "100%% complete")
  caml_ml_flush(chan)
  caml_ml_close_channel(chan)

  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_equal(content, "100% complete")
  cleanup_file(filename)
end)

-- Test 11-15: Binary vs Text mode
test("binary mode preserves all bytes", function()
  local filename = "/tmp/test_binary_mode.dat"

  -- Write binary data including null bytes and special characters
  local data = "\x00\x01\x02\xFF\xFE"
  local chan = open_write(filename, true)
  output_string(chan, data)
  caml_ml_flush(chan)
  caml_ml_close_channel(chan)

  -- Read back
  local chan_in = open_read(filename, true)
  local result = input_string(chan_in, #data)
  caml_ml_close_channel(chan_in)

  assert_equal(result, data, "binary data should be preserved")
  cleanup_file(filename)
end)

test("text mode handles newlines", function()
  local filename = "/tmp/test_text_mode.txt"

  -- Write text with newlines
  local chan = open_write(filename, false)
  output_string(chan, "line1\nline2\nline3\n")
  caml_ml_flush(chan)
  caml_ml_close_channel(chan)

  -- Read back
  local chan_in = open_read(filename, false)
  local line1 = input_line(chan_in)
  local line2 = input_line(chan_in)
  local line3 = input_line(chan_in)
  caml_ml_close_channel(chan_in)

  assert_equal(line1, "line1")
  assert_equal(line2, "line2")
  assert_equal(line3, "line3")
  cleanup_file(filename)
end)

test("binary write/read char", function()
  local filename = "/tmp/test_binary_char.dat"

  local chan_out = open_write(filename, true)
  caml_ml_output_char(chan_out, 65)  -- 'A'
  caml_ml_output_char(chan_out, 0)   -- null byte
  caml_ml_output_char(chan_out, 255) -- max byte
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  local chan_in = open_read(filename, true)
  local c1 = caml_ml_input_char(chan_in)
  local c2 = caml_ml_input_char(chan_in)
  local c3 = caml_ml_input_char(chan_in)
  caml_ml_close_channel(chan_in)

  assert_equal(c1, 65)
  assert_equal(c2, 0)
  assert_equal(c3, 255)
  cleanup_file(filename)
end)

test("text mode input_line strips newline", function()
  local filename = "/tmp/test_input_line.txt"

  -- Write with explicit newlines
  local f = io.open(filename, "w")
  f:write("first\nsecond\nthird")
  f:close()

  local chan = open_read(filename, false)
  local l1 = input_line(chan)
  local l2 = input_line(chan)

  assert_equal(l1, "first")
  assert_equal(l2, "second")

  caml_ml_close_channel(chan)
  cleanup_file(filename)
end)

test("binary mode exact byte count", function()
  local filename = "/tmp/test_byte_count.dat"
  local data = string.rep("X", 1000)

  local chan_out = open_write(filename, true)
  output_string(chan_out, data)
  caml_ml_flush(chan_out)
  caml_ml_close_channel(chan_out)

  local chan_in = open_read(filename, true)
  local result = input_string(chan_in, 1000)
  caml_ml_close_channel(chan_in)

  assert_equal(#result, 1000)
  assert_equal(result, data)
  cleanup_file(filename)
end)

-- Test 16-20: Buffering behavior
test("flush forces write", function()
  local filename = "/tmp/test_flush.txt"

  local chan = open_write(filename, true)
  output_string(chan, "before flush")
  caml_ml_flush(chan)

  -- Read while channel still open (should see flushed data)
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_equal(content, "before flush")

  caml_ml_close_channel(chan)
  cleanup_file(filename)
end)

test("close flushes buffer", function()
  local filename = "/tmp/test_close_flush.txt"

  local chan = open_write(filename, true)
  output_string(chan, "data")
  caml_ml_close_channel(chan)  -- Should flush

  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_equal(content, "data")
  cleanup_file(filename)
end)

test("multiple flushes", function()
  local filename = "/tmp/test_multi_flush.txt"

  local chan = open_write(filename, true)
  output_string(chan, "part1")
  caml_ml_flush(chan)
  output_string(chan, "part2")
  caml_ml_flush(chan)
  output_string(chan, "part3")
  caml_ml_close_channel(chan)

  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_equal(content, "part1part2part3")
  cleanup_file(filename)
end)

test("flush on output_value", function()
  local filename = "/tmp/test_marshal_flush.dat"

  local chan = open_write(filename, true)
  marshal.to_channel(chan, 42, {tag = 0})
  caml_ml_flush(chan)

  -- Verify data was written
  local f = io.open(filename, "rb")
  local size = f:seek("end")
  f:close()

  assert_true(size > 0, "marshal should write data")

  caml_ml_close_channel(chan)
  cleanup_file(filename)
end)

test("channel buffer independence", function()
  local filename1 = "/tmp/test_buf1.txt"
  local filename2 = "/tmp/test_buf2.txt"

  local chan1 = open_write(filename1, true)
  local chan2 = open_write(filename2, true)

  output_string(chan1, "channel1")
  output_string(chan2, "channel2")

  caml_ml_flush(chan1)
  caml_ml_flush(chan2)

  caml_ml_close_channel(chan1)
  caml_ml_close_channel(chan2)

  local f1 = io.open(filename1, "rb")
  local c1 = f1:read("*all")
  f1:close()

  local f2 = io.open(filename2, "rb")
  local c2 = f2:read("*all")
  f2:close()

  assert_equal(c1, "channel1")
  assert_equal(c2, "channel2")

  cleanup_file(filename1)
  cleanup_file(filename2)
end)

-- Test 21-25: Seeking in files
test("seek to beginning", function()
  local filename = "/tmp/test_seek_begin.txt"

  local f = io.open(filename, "wb")
  f:write("0123456789")
  f:close()

  local chan = open_read(filename, true)

  -- Read first char
  local c1 = caml_ml_input_char(chan)
  assert_equal(c1, string.byte("0"))

  -- Seek to beginning
  caml_ml_seek_in(chan, 0)

  -- Read again
  local c2 = caml_ml_input_char(chan)
  assert_equal(c2, string.byte("0"))

  caml_ml_close_channel(chan)
  cleanup_file(filename)
end)

test("seek forward", function()
  local filename = "/tmp/test_seek_forward.txt"

  local f = io.open(filename, "wb")
  f:write("0123456789")
  f:close()

  local chan = open_read(filename, true)

  -- Seek to position 5
  caml_ml_seek_in(chan, 5)

  local c = caml_ml_input_char(chan)
  assert_equal(c, string.byte("5"))

  caml_ml_close_channel(chan)
  cleanup_file(filename)
end)

test("pos_in reports position", function()
  local filename = "/tmp/test_pos_in.txt"

  local f = io.open(filename, "wb")
  f:write("0123456789")
  f:close()

  local chan = open_read(filename, true)

  assert_equal(caml_ml_pos_in(chan), 0)

  caml_ml_input_char(chan)
  assert_equal(caml_ml_pos_in(chan), 1)

  caml_ml_input_char(chan)
  caml_ml_input_char(chan)
  assert_equal(caml_ml_pos_in(chan), 3)

  caml_ml_close_channel(chan)
  cleanup_file(filename)
end)

test("seek and read after seek", function()
  local filename = "/tmp/test_seek_read.txt"

  local f = io.open(filename, "wb")
  f:write("abcdefghij")
  f:close()

  local chan = open_read(filename, true)

  caml_ml_seek_in(chan, 3)
  local data = input_string(chan, 3)

  assert_equal(data, "def")

  caml_ml_close_channel(chan)
  cleanup_file(filename)
end)

test("seek to end with channel_size", function()
  local filename = "/tmp/test_seek_end.txt"

  local f = io.open(filename, "wb")
  f:write("0123456789")
  f:close()

  local chan = open_read(filename, true)

  local size = caml_ml_channel_size(chan)
  assert_equal(size, 10)

  caml_ml_seek_in(chan, size - 1)
  local c = caml_ml_input_char(chan)
  assert_equal(c, string.byte("9"))

  caml_ml_close_channel(chan)
  cleanup_file(filename)
end)

-- Test 26-30: Channel lifecycle
test("open and close input channel", function()
  local filename = "/tmp/test_lifecycle_in.txt"

  local f = io.open(filename, "wb")
  f:write("test")
  f:close()

  local chan = open_read(filename, true)
  assert_true(chan ~= nil)

  caml_ml_close_channel(chan)

  -- Channel should be closed now
  assert_error(function()
    caml_ml_input_char(chan)
  end, "should not read from closed channel")

  cleanup_file(filename)
end)

test("open and close output channel", function()
  local filename = "/tmp/test_lifecycle_out.txt"

  local chan = open_write(filename, true)
  assert_true(chan ~= nil)

  output_string(chan, "data")
  caml_ml_close_channel(chan)

  -- Verify data was written
  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_equal(content, "data")
  cleanup_file(filename)
end)

test("flush before close", function()
  local filename = "/tmp/test_flush_close.txt"

  local chan = open_write(filename, true)
  output_string(chan, "test")
  caml_ml_flush(chan)
  caml_ml_flush(chan)  -- Flush twice is safe
  caml_ml_close_channel(chan)

  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_equal(content, "test")
  cleanup_file(filename)
end)

test("channel reopen after close", function()
  local filename = "/tmp/test_reopen.txt"

  -- First open/close cycle
  local chan1 = open_write(filename, true)
  output_string(chan1, "first")
  caml_ml_close_channel(chan1)

  -- Second open/close cycle (append mode)
  local flags = make_list({1, 2, 6})  -- WRONLY, APPEND, BINARY
  local fd = caml_sys_open(filename, flags, 420)  -- 0644 octal = 420 decimal
  local chan2 = caml_ml_open_descriptor_out(fd)
  output_string(chan2, "second")
  caml_ml_close_channel(chan2)

  local f = io.open(filename, "rb")
  local content = f:read("*all")
  f:close()

  assert_equal(content, "firstsecond")
  cleanup_file(filename)
end)

test("multiple channels to same file", function()
  local filename = "/tmp/test_multi_channel.txt"

  -- Write with first channel
  local chan1 = open_write(filename, true)
  output_string(chan1, "data1")
  caml_ml_close_channel(chan1)

  -- Read with second channel
  local chan2 = open_read(filename, true)
  local content = input_string(chan2, 5)
  caml_ml_close_channel(chan2)

  assert_equal(content, "data1")
  cleanup_file(filename)
end)

-- Test 31-35: Error conditions
test("read from closed channel raises error", function()
  local filename = "/tmp/test_error_closed_read.txt"

  local f = io.open(filename, "wb")
  f:write("test")
  f:close()

  local chan = open_read(filename, true)
  caml_ml_close_channel(chan)

  assert_error(function()
    caml_ml_input_char(chan)
  end, "should raise error on closed channel")

  cleanup_file(filename)
end)

test("write to closed channel raises error", function()
  local filename = "/tmp/test_error_closed_write.txt"

  local chan = open_write(filename, true)
  caml_ml_close_channel(chan)

  assert_error(function()
    output_string(chan, "data")
  end, "should raise error on closed channel")

  cleanup_file(filename)
end)

test("read past EOF raises End_of_file", function()
  local filename = "/tmp/test_error_eof.txt"

  local f = io.open(filename, "wb")
  f:write("x")
  f:close()

  local chan = open_read(filename, true)
  caml_ml_input_char(chan)  -- Read the only char

  assert_error(function()
    caml_ml_input_char(chan)  -- Should raise End_of_file
  end, "should raise End_of_file")

  caml_ml_close_channel(chan)
  cleanup_file(filename)
end)

test("input_line at EOF raises End_of_file", function()
  local filename = "/tmp/test_error_line_eof.txt"

  local f = io.open(filename, "wb")
  f:write("line1\n")
  f:close()

  local chan = open_read(filename, false)
  input_line(chan)  -- Read the only line

  assert_error(function()
    input_line(chan)  -- Should raise End_of_file
  end, "should raise End_of_file")

  caml_ml_close_channel(chan)
  cleanup_file(filename)
end)

test("invalid file descriptor raises error", function()
  assert_error(function()
    caml_ml_open_descriptor_in(9999)  -- Invalid FD
  end, "should raise error on invalid FD")
end)

-- Summary
print("\n=== Test Summary ===")
print(string.format("Total: %d", test_count))
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", fail_count))

if fail_count == 0 then
  print("\n✓ All tests passed!")
  os.exit(0)
else
  print(string.format("\n✗ %d test(s) failed", fail_count))
  os.exit(1)
end
