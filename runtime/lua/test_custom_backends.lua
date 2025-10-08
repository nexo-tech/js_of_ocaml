#!/usr/bin/env lua
-- Test suite for custom channel backends (Task 10.2)
--
-- Tests the custom backend interface with example implementations:
-- - Counter backend: Counts bytes read/written
-- - Transform backend: Uppercases/lowercases text
-- - Compress backend: Simple run-length encoding

-- Preload our runtime modules (they clash with standard Lua modules)
package.loaded.io = dofile("io.lua")
local io_module = package.loaded.io

local marshal = require("marshal")

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
print("Custom Channel Backends Test Suite")
print("========================================")
print("")

-- ========================================
-- Example Backend 1: Counter
-- ========================================

print("Counter Backend")
print("----------------------------------------")

-- Counter input backend: reads from string and counts bytes
local function make_counter_input_backend(data)
  return {
    data = data,
    pos = 1,
    bytes_read = 0,

    read = function(self, n)
      if self.pos > #self.data then
        return nil
      end
      local available = #self.data - self.pos + 1
      local to_read = math.min(n, available)
      local chunk = string.sub(self.data, self.pos, self.pos + to_read - 1)
      self.pos = self.pos + to_read
      self.bytes_read = self.bytes_read + to_read
      return chunk
    end,

    get_count = function(self)
      return self.bytes_read
    end
  }
end

-- Counter output backend: accumulates writes and counts bytes
local function make_counter_output_backend()
  return {
    buffer = {},
    bytes_written = 0,

    write = function(self, str)
      table.insert(self.buffer, str)
      self.bytes_written = self.bytes_written + #str
      return #str
    end,

    flush = function(self)
      -- No-op for this backend
    end,

    get_count = function(self)
      return self.bytes_written
    end,

    get_data = function(self)
      return table.concat(self.buffer)
    end
  }
end

-- Test 1: Counter input backend
local backend = make_counter_input_backend("Hello, World!")
local chan = io_module.caml_ml_open_custom_in(backend)
test("Create counter input channel", chan ~= nil)

-- Test 2: Read and count bytes
local c = io_module.caml_ml_input_char(chan)
test("Read first char", c == string.byte("H"))
test("Counter tracks input", backend:get_count() == 1)

-- Test 3: Read multiple bytes
local buf = {}
local bytes_read = io_module.caml_ml_input(chan, buf, 0, 5)
test("Read 5 bytes", bytes_read == 5)
test("Counter updated", backend:get_count() == 6)

io_module.caml_ml_close_channel(chan)

-- Test 5: Counter output backend
backend = make_counter_output_backend()
chan = io_module.caml_ml_open_custom_out(backend)
test("Create counter output channel", chan ~= nil)

-- Test 6: Write and count bytes
io_module.caml_ml_output_char(chan, string.byte("A"))
io_module.caml_ml_flush(chan)
test("Counter tracks output", backend:get_count() == 1)

-- Test 7: Write more data
io_module.caml_ml_output(chan, "BCDEFG", 0, 6)
io_module.caml_ml_flush(chan)
test("Counter tracks multiple writes", backend:get_count() == 7)
test("Data accumulated correctly", backend:get_data() == "ABCDEFG")

io_module.caml_ml_close_channel(chan)

print("")

-- ========================================
-- Example Backend 2: Transform
-- ========================================

print("Transform Backend")
print("----------------------------------------")

-- Transform input backend: uppercases input
local function make_uppercase_input_backend(data)
  return {
    data = string.upper(data),
    pos = 1,

    read = function(self, n)
      if self.pos > #self.data then
        return nil
      end
      local available = #self.data - self.pos + 1
      local to_read = math.min(n, available)
      local chunk = string.sub(self.data, self.pos, self.pos + to_read - 1)
      self.pos = self.pos + to_read
      return chunk
    end
  }
end

-- Transform output backend: lowercases output
local function make_lowercase_output_backend()
  return {
    buffer = {},

    write = function(self, str)
      table.insert(self.buffer, string.lower(str))
      return #str
    end,

    flush = function(self)
      -- No-op
    end,

    get_data = function(self)
      return table.concat(self.buffer)
    end
  }
end

-- Test 9: Uppercase input transform
backend = make_uppercase_input_backend("hello")
chan = io_module.caml_ml_open_custom_in(backend)

buf = {}
bytes_read = io_module.caml_ml_input(chan, buf, 0, 5)
local chars = {}
for i = 1, bytes_read do
  table.insert(chars, string.char(buf[i]))
end
local result = table.concat(chars)
test("Uppercase transform", result == "HELLO")

io_module.caml_ml_close_channel(chan)

-- Test 10: Lowercase output transform
backend = make_lowercase_output_backend()
chan = io_module.caml_ml_open_custom_out(backend)

io_module.caml_ml_output(chan, "WORLD", 0, 5)
io_module.caml_ml_flush(chan)
test("Lowercase transform", backend:get_data() == "world")

io_module.caml_ml_close_channel(chan)

print("")

-- ========================================
-- Example Backend 3: Run-Length Encoding
-- ========================================

print("Run-Length Encoding Backend")
print("----------------------------------------")

-- Simple RLE encoder: "AAA" -> "3A"
local function rle_encode(str)
  if #str == 0 then return "" end

  local result = {}
  local i = 1
  while i <= #str do
    local char = string.sub(str, i, i)
    local count = 1
    while i + count <= #str and string.sub(str, i + count, i + count) == char do
      count = count + 1
    end
    table.insert(result, tostring(count) .. char)
    i = i + count
  end
  return table.concat(result)
end

-- Simple RLE decoder: "3A" -> "AAA"
local function rle_decode(str)
  local result = {}
  local i = 1
  while i <= #str do
    -- Read count (digits)
    local count_str = ""
    while i <= #str and string.sub(str, i, i):match("%d") do
      count_str = count_str .. string.sub(str, i, i)
      i = i + 1
    end
    -- Read character
    if i <= #str then
      local char = string.sub(str, i, i)
      local count = tonumber(count_str) or 1
      for j = 1, count do
        table.insert(result, char)
      end
      i = i + 1
    end
  end
  return table.concat(result)
end

-- RLE input backend
local function make_rle_input_backend(encoded_data)
  local decoded = rle_decode(encoded_data)
  return {
    data = decoded,
    pos = 1,

    read = function(self, n)
      if self.pos > #self.data then
        return nil
      end
      local available = #self.data - self.pos + 1
      local to_read = math.min(n, available)
      local chunk = string.sub(self.data, self.pos, self.pos + to_read - 1)
      self.pos = self.pos + to_read
      return chunk
    end
  }
end

-- RLE output backend
local function make_rle_output_backend()
  return {
    buffer = {},

    write = function(self, str)
      table.insert(self.buffer, str)
      return #str
    end,

    flush = function(self)
      -- No-op
    end,

    get_encoded = function(self)
      local data = table.concat(self.buffer)
      return rle_encode(data)
    end,

    get_data = function(self)
      return table.concat(self.buffer)
    end
  }
end

-- Test 11: RLE encoding
local encoded = rle_encode("AAABBBCCC")
test("RLE encode simple", encoded == "3A3B3C")

-- Test 12: RLE decoding
local decoded = rle_decode("3A3B3C")
test("RLE decode simple", decoded == "AAABBBCCC")

-- Test 13: RLE encode with different lengths
encoded = rle_encode("AABCCCC")
test("RLE encode varied", encoded == "2A1B4C")

-- Test 14: RLE input backend
backend = make_rle_input_backend("5X3Y")
chan = io_module.caml_ml_open_custom_in(backend)

buf = {}
bytes_read = io_module.caml_ml_input(chan, buf, 0, 8)
chars = {}
for i = 1, bytes_read do
  table.insert(chars, string.char(buf[i]))
end
result = table.concat(chars)
test("RLE input backend", result == "XXXXXYYY")

io_module.caml_ml_close_channel(chan)

-- Test 15: RLE output backend
backend = make_rle_output_backend()
chan = io_module.caml_ml_open_custom_out(backend)

io_module.caml_ml_output(chan, "ZZZZZ", 0, 5)
io_module.caml_ml_flush(chan)
test("RLE output backend", backend:get_encoded() == "5Z")

io_module.caml_ml_close_channel(chan)

print("")

-- ========================================
-- Marshal Integration
-- ========================================

print("Marshal Integration with Custom Backends")
print("----------------------------------------")

-- Test 16: Marshal to custom backend
backend = make_counter_output_backend()
chan = io_module.caml_ml_open_custom_out(backend)

marshal.to_channel(chan, 42, {tag = 0})
io_module.caml_ml_close_channel(chan)
test("Marshal to counter backend", backend:get_count() > 0)

-- Test 17: Unmarshal from custom backend
local marshalled_data = backend:get_data()
backend = make_counter_input_backend(marshalled_data)
chan = io_module.caml_ml_open_custom_in(backend)

local value = marshal.from_channel(chan)
test("Unmarshal from counter backend", value == 42)
test("Counter tracked unmarshal read", backend:get_count() > 0)

io_module.caml_ml_close_channel(chan)

-- Test 19: Round-trip through transform backend
backend = make_counter_output_backend()
chan = io_module.caml_ml_open_custom_out(backend)

local test_list = make_list({10, 20, 30})
marshal.to_channel(chan, test_list, {tag = 0})
io_module.caml_ml_close_channel(chan)

marshalled_data = backend:get_data()
backend = make_counter_input_backend(marshalled_data)
chan = io_module.caml_ml_open_custom_in(backend)

value = marshal.from_channel(chan)
test("Marshal list round-trip",
  value[1] == 10 and value[2][1] == 20 and value[2][2][1] == 30)

io_module.caml_ml_close_channel(chan)

print("")

-- ========================================
-- Backend Lifecycle
-- ========================================

print("Backend Lifecycle")
print("----------------------------------------")

-- Test 21: Backend close callback
local close_called = false
backend = {
  data = "test",
  pos = 1,
  read = function(self, n)
    if self.pos > #self.data then return nil end
    local chunk = string.sub(self.data, self.pos, self.pos)
    self.pos = self.pos + 1
    return chunk
  end,
  close = function(self)
    close_called = true
  end
}

chan = io_module.caml_ml_open_custom_in(backend)
io_module.caml_ml_close_channel(chan)
test("Backend close callback called", close_called)

-- Test 22: Backend flush callback
local flush_called = false
backend = {
  buffer = {},
  write = function(self, str)
    table.insert(self.buffer, str)
    return #str
  end,
  flush = function(self)
    flush_called = true
  end
}

chan = io_module.caml_ml_open_custom_out(backend)
io_module.caml_ml_output(chan, "test", 0, 4)
io_module.caml_ml_flush(chan)
test("Backend flush callback called", flush_called)

io_module.caml_ml_close_channel(chan)

print("")

-- ========================================
-- Edge Cases
-- ========================================

print("Edge Cases")
print("----------------------------------------")

-- Test 24: Empty backend
backend = make_counter_input_backend("")
chan = io_module.caml_ml_open_custom_in(backend)

local ok, err = pcall(io_module.caml_ml_input_char, chan)
test("Empty backend EOF", not ok and string.find(err, "End_of_file"))

io_module.caml_ml_close_channel(chan)

-- Test 25: Large data through backend
local large_str = string.rep("X", 10000)
backend = make_counter_input_backend(large_str)
chan = io_module.caml_ml_open_custom_in(backend)

buf = {}
bytes_read = io_module.caml_ml_input(chan, buf, 0, 10000)
test("Large read through backend", bytes_read == 10000)
test("Large read counter", backend:get_count() == 10000)

io_module.caml_ml_close_channel(chan)

-- Test 27: Partial reads from backend
backend = make_counter_input_backend("ABCDEFGH")
chan = io_module.caml_ml_open_custom_in(backend)

buf = {}
bytes_read = io_module.caml_ml_input(chan, buf, 0, 3)
test("First partial read", bytes_read == 3)

buf = {}
bytes_read = io_module.caml_ml_input(chan, buf, 0, 3)
test("Second partial read", bytes_read == 3)

buf = {}
bytes_read = io_module.caml_ml_input(chan, buf, 0, 3)
test("Third partial read", bytes_read == 2)

io_module.caml_ml_close_channel(chan)

-- Test 30: Backend without optional methods
backend = {
  data = "test",
  pos = 1,
  read = function(self, n)
    if self.pos > #self.data then return nil end
    local chunk = string.sub(self.data, self.pos, self.pos)
    self.pos = self.pos + 1
    return chunk
  end
  -- No close or flush methods
}

chan = io_module.caml_ml_open_custom_in(backend)
c = io_module.caml_ml_input_char(chan)
test("Backend without optional methods", c == string.byte("t"))
io_module.caml_ml_close_channel(chan)

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
