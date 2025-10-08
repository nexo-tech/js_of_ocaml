#!/usr/bin/env lua
-- Test suite for marshal_header.lua (Task 1.2)

local marshal_header = require("marshal_header")
local marshal_io = require("marshal_io")
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

print("====================================================================")
print("Marshal Header Tests (marshal_header.lua - Task 1.2)")
print("====================================================================")
print("")

--
-- VLQ Tests
--

print("VLQ Encoding Tests:")
print("--------------------------------------------------------------------")

test("VLQ encode small values", function()
  local writer = Writer:new()
  marshal_header.write_vlq(writer, 0)
  marshal_header.write_vlq(writer, 1)
  marshal_header.write_vlq(writer, 127)

  local str = writer:to_string()
  assert_eq(#str, 3, "Should write 3 bytes")
  assert_eq(string.byte(str, 1), 0, "VLQ(0) = 0")
  assert_eq(string.byte(str, 2), 1, "VLQ(1) = 1")
  assert_eq(string.byte(str, 3), 127, "VLQ(127) = 127")
end)

test("VLQ encode medium values", function()
  local writer = Writer:new()
  marshal_header.write_vlq(writer, 128)    -- 0x81 0x00
  marshal_header.write_vlq(writer, 255)    -- 0x81 0x7F
  marshal_header.write_vlq(writer, 16383)  -- 0xFF 0x7F

  local str = writer:to_string()
  assert_eq(string.byte(str, 1), 0x81, "VLQ(128) byte 1")
  assert_eq(string.byte(str, 2), 0x00, "VLQ(128) byte 2")
  assert_eq(string.byte(str, 3), 0x81, "VLQ(255) byte 1")
  assert_eq(string.byte(str, 4), 0x7F, "VLQ(255) byte 2")
end)

test("VLQ encode large values", function()
  local writer = Writer:new()
  marshal_header.write_vlq(writer, 16384)    -- 0x81 0x80 0x00
  marshal_header.write_vlq(writer, 2097151)  -- 0xFF 0xFF 0x7F

  local str = writer:to_string()
  assert_eq(string.byte(str, 1), 0x81, "VLQ(16384) byte 1")
  assert_eq(string.byte(str, 2), 0x80, "VLQ(16384) byte 2")
  assert_eq(string.byte(str, 3), 0x00, "VLQ(16384) byte 3")
end)

test("VLQ roundtrip small values", function()
  local values = {0, 1, 42, 63, 64, 127}
  for _, v in ipairs(values) do
    local writer = Writer:new()
    marshal_header.write_vlq(writer, v)

    local reader = marshal_io.Reader:new(writer:to_string())
    local decoded, overflow = marshal_header.read_vlq(reader)

    assert_eq(decoded, v, "VLQ roundtrip " .. v)
    assert_true(not overflow, "No overflow for " .. v)
  end
end)

test("VLQ roundtrip medium values", function()
  local values = {128, 255, 256, 1000, 16383, 16384, 100000}
  for _, v in ipairs(values) do
    local writer = Writer:new()
    marshal_header.write_vlq(writer, v)

    local reader = marshal_io.Reader:new(writer:to_string())
    local decoded, overflow = marshal_header.read_vlq(reader)

    assert_eq(decoded, v, "VLQ roundtrip " .. v)
    assert_true(not overflow, "No overflow for " .. v)
  end
end)

test("VLQ roundtrip large values", function()
  local values = {1000000, 16777215, 2097151, 268435455}
  for _, v in ipairs(values) do
    local writer = Writer:new()
    marshal_header.write_vlq(writer, v)

    local reader = marshal_io.Reader:new(writer:to_string())
    local decoded, overflow = marshal_header.read_vlq(reader)

    assert_eq(decoded, v, "VLQ roundtrip " .. v)
    assert_true(not overflow, "No overflow for " .. v)
  end
end)

--
-- Standard Header Tests
--

print("")
print("Standard Header Tests:")
print("--------------------------------------------------------------------")

test("Write standard header", function()
  local header_str = marshal_header.write_header(100, 5, 0, 0)

  assert_eq(#header_str, 20, "Header should be 20 bytes")

  -- Check magic number
  local b1, b2, b3, b4 = string.byte(header_str, 1, 4)
  local magic = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
  assert_eq(magic, 0x8495A6BE, "Magic number should be MAGIC_SMALL")
end)

test("Read standard header", function()
  local header_str = marshal_header.write_header(200, 10, 0, 0)
  local header = marshal_header.read_header(header_str)

  assert_eq(header.magic, 0x8495A6BE, "Magic number")
  assert_eq(header.header_len, 20, "Header length")
  assert_eq(header.data_len, 200, "Data length")
  assert_eq(header.uncompressed_data_len, 200, "Uncompressed data length")
  assert_eq(header.num_objects, 10, "Number of objects")
  assert_eq(header.size_32, 0, "Size 32")
  assert_eq(header.size_64, 0, "Size 64")
  assert_true(not header.compressed, "Not compressed")
end)

test("Roundtrip standard header - zero objects", function()
  local header_str = marshal_header.write_header(0, 0, 0, 0)
  local header = marshal_header.read_header(header_str)

  assert_eq(header.data_len, 0, "Data length")
  assert_eq(header.num_objects, 0, "Number of objects")
end)

test("Roundtrip standard header - large values", function()
  local header_str = marshal_header.write_header(1000000, 5000, 123, 456)
  local header = marshal_header.read_header(header_str)

  assert_eq(header.data_len, 1000000, "Data length")
  assert_eq(header.num_objects, 5000, "Number of objects")
  assert_eq(header.size_32, 123, "Size 32")
  assert_eq(header.size_64, 456, "Size 64")
end)

--
-- Compressed Header Tests
--

print("")
print("Compressed Header Tests:")
print("--------------------------------------------------------------------")

test("Write compressed header", function()
  local header_str = marshal_header.write_compressed_header(100, 150, 5, 0, 0)

  -- Header should be at least 4 bytes (magic) + 1 byte (len) + VLQs
  assert_true(#header_str >= 5, "Header should be at least 5 bytes")

  -- Check magic number
  local b1, b2, b3, b4 = string.byte(header_str, 1, 4)
  local magic = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
  assert_eq(magic, 0x8495A6BD, "Magic number should be MAGIC_COMPRESSED")
end)

test("Read compressed header", function()
  local header_str = marshal_header.write_compressed_header(200, 300, 10, 0, 0)
  local header = marshal_header.read_header(header_str)

  assert_eq(header.magic, 0x8495A6BD, "Magic number")
  assert_eq(header.data_len, 200, "Data length")
  assert_eq(header.uncompressed_data_len, 300, "Uncompressed data length")
  assert_eq(header.num_objects, 10, "Number of objects")
  assert_eq(header.size_32, 0, "Size 32")
  assert_eq(header.size_64, 0, "Size 64")
  assert_true(header.compressed, "Is compressed")
end)

test("Roundtrip compressed header - small values", function()
  local header_str = marshal_header.write_compressed_header(10, 20, 1, 0, 0)
  local header = marshal_header.read_header(header_str)

  assert_eq(header.data_len, 10, "Data length")
  assert_eq(header.uncompressed_data_len, 20, "Uncompressed data length")
  assert_eq(header.num_objects, 1, "Number of objects")
end)

test("Roundtrip compressed header - large values", function()
  local header_str = marshal_header.write_compressed_header(1000000, 2000000, 50000, 100, 200)
  local header = marshal_header.read_header(header_str)

  assert_eq(header.data_len, 1000000, "Data length")
  assert_eq(header.uncompressed_data_len, 2000000, "Uncompressed data length")
  assert_eq(header.num_objects, 50000, "Number of objects")
  assert_eq(header.size_32, 100, "Size 32")
  assert_eq(header.size_64, 200, "Size 64")
end)

test("Compressed header is smaller than standard", function()
  local standard = marshal_header.write_header(100, 5, 0, 0)
  local compressed = marshal_header.write_compressed_header(100, 100, 5, 0, 0)

  assert_true(#compressed < #standard, "Compressed should be smaller for small values")
end)

--
-- Size Functions Tests
--

print("")
print("Size Functions Tests:")
print("--------------------------------------------------------------------")

test("total_size standard header", function()
  local header_str = marshal_header.write_header(100, 5, 0, 0)
  local total = marshal_header.total_size(header_str)

  assert_eq(total, 120, "Total size should be header (20) + data (100)")
end)

test("data_size standard header", function()
  local header_str = marshal_header.write_header(250, 10, 0, 0)
  local data = marshal_header.data_size(header_str)

  assert_eq(data, 250, "Data size should be 250")
end)

test("total_size compressed header", function()
  local header_str = marshal_header.write_compressed_header(80, 120, 3, 0, 0)
  local total = marshal_header.total_size(header_str)
  local header_len = #header_str

  assert_eq(total, header_len + 80, "Total size should be header + data")
end)

test("data_size compressed header", function()
  local header_str = marshal_header.write_compressed_header(150, 200, 5, 0, 0)
  local data = marshal_header.data_size(header_str)

  assert_eq(data, 150, "Data size should be 150")
end)

--
-- Error Handling Tests
--

print("")
print("Error Handling:")
print("--------------------------------------------------------------------")

test("Invalid magic number", function()
  local writer = Writer:new()
  writer:write32u(0x12345678)  -- Invalid magic
  writer:write32u(0)
  writer:write32u(0)
  writer:write32u(0)
  writer:write32u(0)

  local success = pcall(function()
    marshal_header.read_header(writer:to_string())
  end)
  assert_true(not success, "Should error on invalid magic")
end)

test("MAGIC_BIG error", function()
  local writer = Writer:new()
  writer:write32u(0x8495A6BF)  -- MAGIC_BIG

  local success = pcall(function()
    marshal_header.read_header(writer:to_string())
  end)
  assert_true(not success, "Should error on MAGIC_BIG")
end)

test("Truncated standard header", function()
  local header_str = marshal_header.write_header(100, 5, 0, 0)
  local truncated = string.sub(header_str, 1, 15)  -- Only 15 bytes

  local success = pcall(function()
    marshal_header.read_header(truncated)
  end)
  assert_true(not success, "Should error on truncated header")
end)

test("VLQ negative value error", function()
  local writer = Writer:new()

  local success = pcall(function()
    marshal_header.write_vlq(writer, -1)
  end)
  assert_true(not success, "Should error on negative VLQ")
end)

--
-- Edge Cases
--

print("")
print("Edge Cases:")
print("--------------------------------------------------------------------")

test("Header with offset", function()
  local prefix = "XXXX"
  local header_str = marshal_header.write_header(50, 2, 0, 0)
  local full_str = prefix .. header_str

  local header = marshal_header.read_header(full_str, 4)

  assert_eq(header.data_len, 50, "Should read header at offset")
  assert_eq(header.num_objects, 2, "Should read correct values")
end)

test("Zero data length", function()
  local header_str = marshal_header.write_header(0, 0, 0, 0)
  local header = marshal_header.read_header(header_str)

  assert_eq(header.data_len, 0, "Zero data length")
  assert_eq(header.num_objects, 0, "Zero objects")
end)

test("Maximum standard header values", function()
  -- Use large but valid 32-bit values
  local max_val = 2147483647  -- Max positive 32-bit signed int
  local header_str = marshal_header.write_header(max_val, 1000, 100, 200)
  local header = marshal_header.read_header(header_str)

  assert_eq(header.data_len, max_val, "Large data length")
  assert_eq(header.num_objects, 1000, "Objects")
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
