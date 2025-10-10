#!/usr/bin/env lua
-- Test suite for block marshaling (Task 6.1.3)

dofile("marshal_io.lua")
dofile("marshal.lua")

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
  io.write("Test: " .. name .. " ... ")
  local success, err = pcall(fn)
  if success then
    tests_passed = tests_passed + 1
    print("✓")
  else
    tests_failed = tests_failed + 1
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
    error(msg or "Expected true, got false")
  end
end

-- Helper: simple write_value_fn for testing (writes integers only)
local function simple_write_value(buf, value)
  caml_marshal_write_int(buf, value)
end

-- Helper: simple read_value_fn for testing (reads integers only)
local function simple_read_value(str, offset)
  return caml_marshal_read_int(str, offset)
end

print("====================================================================")
print("Block Marshaling Tests (Task 6.1.3)")
print("====================================================================")
print()

print("Small Block Write Tests (tag 0-15, size 0-7):")
print("--------------------------------------------------------------------")

test("write_block: tag=0 size=0", function()
  local block = {tag = 0, size = 0}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  assert_eq(buf.length, 1)
  assert_eq(buf.bytes[1], 0x80)  -- 0x80 + 0 + 0*16
end)

test("write_block: tag=1 size=0", function()
  local block = {tag = 1, size = 0}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  assert_eq(buf.length, 1)
  assert_eq(buf.bytes[1], 0x81)  -- 0x80 + 1 + 0*16
end)

test("write_block: tag=0 size=1", function()
  local block = {tag = 0, size = 1, [1] = 42}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  assert_eq(buf.bytes[1], 0x90)  -- 0x80 + 0 + 1*16
  -- Field should be marshaled after header
  assert_eq(buf.bytes[2], 0x40 + 42)  -- Small int 42
end)

test("write_block: tag=5 size=3", function()
  local block = {tag = 5, size = 3, [1] = 1, [2] = 2, [3] = 3}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  assert_eq(buf.bytes[1], 0x85 + 3 * 16)  -- 0x80 + 5 + 3*16 = 0xB5
end)

test("write_block: tag=15 size=7 (max small)", function()
  local block = {tag = 15, size = 7}
  for i = 1, 7 do
    block[i] = i
  end
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  assert_eq(buf.bytes[1], 0xFF)  -- 0x80 + 15 + 7*16
end)

print()
print("BLOCK32 Write Tests:")
print("--------------------------------------------------------------------")

test("write_block: tag=16 size=0 (BLOCK32)", function()
  local block = {tag = 16, size = 0}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  assert_eq(buf.length, 5)
  assert_eq(buf.bytes[1], 0x08)  -- CODE_BLOCK32
  local str = caml_marshal_buffer_to_string(buf)
  local header = caml_marshal_read32u(str, 1)
  assert_eq(header, 16)  -- 0 * 1024 + 16
end)

test("write_block: tag=0 size=8 (BLOCK32)", function()
  local block = {tag = 0, size = 8}
  for i = 1, 8 do
    block[i] = i
  end
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  assert_eq(buf.bytes[1], 0x08)  -- CODE_BLOCK32
  local str = caml_marshal_buffer_to_string(buf)
  local header = caml_marshal_read32u(str, 1)
  assert_eq(header, 8 * 1024)  -- 8 << 10
end)

test("write_block: tag=100 size=50 (BLOCK32)", function()
  local block = {tag = 100, size = 50}
  for i = 1, 50 do
    block[i] = i
  end
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  assert_eq(buf.bytes[1], 0x08)  -- CODE_BLOCK32
  local str = caml_marshal_buffer_to_string(buf)
  local header = caml_marshal_read32u(str, 1)
  assert_eq(header, 50 * 1024 + 100)  -- (50 << 10) | 100
end)

test("write_block: tag=255 size=1000 (BLOCK32 large)", function()
  local block = {tag = 255, size = 1000}
  for i = 1, 1000 do
    block[i] = 0
  end
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  assert_eq(buf.bytes[1], 0x08)  -- CODE_BLOCK32
end)

print()
print("Read Block Tests:")
print("--------------------------------------------------------------------")

test("read_block: tag=0 size=0", function()
  local str = string.char(0x80)
  local result = caml_marshal_read_block(str, 0, simple_read_value)
  assert_eq(result.value.tag, 0)
  assert_eq(result.value.size, 0)
  assert_eq(result.bytes_read, 1)
end)

test("read_block: tag=5 size=0", function()
  local str = string.char(0x85)  -- 0x80 + 5 + 0*16
  local result = caml_marshal_read_block(str, 0, simple_read_value)
  assert_eq(result.value.tag, 5)
  assert_eq(result.value.size, 0)
  assert_eq(result.bytes_read, 1)  -- No fields
end)

test("read_block: tag=0 size=1 with field", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x90)  -- tag=0 size=1
  caml_marshal_write_int(buf, 42)
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_block(str, 0, simple_read_value)
  assert_eq(result.value.tag, 0)
  assert_eq(result.value.size, 1)
  assert_eq(result.value[1], 42)
end)

test("read_block: tag=2 size=3 with fields", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x82 + 3 * 16)  -- tag=2 size=3
  caml_marshal_write_int(buf, 10)
  caml_marshal_write_int(buf, 20)
  caml_marshal_write_int(buf, 30)
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_block(str, 0, simple_read_value)
  assert_eq(result.value.tag, 2)
  assert_eq(result.value.size, 3)
  assert_eq(result.value[1], 10)
  assert_eq(result.value[2], 20)
  assert_eq(result.value[3], 30)
end)

test("read_block: BLOCK32 tag=16 size=0", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x08)  -- CODE_BLOCK32
  caml_marshal_buffer_write32u(buf, 16)  -- 0 * 1024 + 16
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_block(str, 0, simple_read_value)
  assert_eq(result.value.tag, 16)
  assert_eq(result.value.size, 0)
  assert_eq(result.bytes_read, 5)
end)

test("read_block: BLOCK32 tag=0 size=8", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x08)  -- CODE_BLOCK32
  caml_marshal_buffer_write32u(buf, 8 * 1024)  -- 8 << 10
  -- Add 8 fields
  for i = 1, 8 do
    caml_marshal_write_int(buf, i)
  end
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_block(str, 0, simple_read_value)
  assert_eq(result.value.tag, 0)
  assert_eq(result.value.size, 8)
  for i = 1, 8 do
    assert_eq(result.value[i], i)
  end
end)

test("read_block: BLOCK32 tag=100 size=5", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0x08)  -- CODE_BLOCK32
  caml_marshal_buffer_write32u(buf, 5 * 1024 + 100)
  -- Add 5 fields
  for i = 1, 5 do
    caml_marshal_write_int(buf, i * 10)
  end
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_block(str, 0, simple_read_value)
  assert_eq(result.value.tag, 100)
  assert_eq(result.value.size, 5)
  for i = 1, 5 do
    assert_eq(result.value[i], i * 10)
  end
end)

test("read_block: at offset", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_buffer_write8u(buf, 0xFF)  -- Padding
  caml_marshal_buffer_write8u(buf, 0xFF)  -- Padding
  caml_marshal_buffer_write8u(buf, 0x80)  -- tag=0 size=0
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_block(str, 2, simple_read_value)
  assert_eq(result.value.tag, 0)
  assert_eq(result.value.size, 0)
end)

print()
print("Roundtrip Tests:")
print("--------------------------------------------------------------------")

test("roundtrip: all small blocks (tag 0-15, size 0-7)", function()
  for tag = 0, 15 do
    for size = 0, 7 do
      local block = {tag = tag, size = size}
      for i = 1, size do
        block[i] = i
      end

      local buf = caml_marshal_buffer_create()
      caml_marshal_write_block(buf, block, simple_write_value)
      local str = caml_marshal_buffer_to_string(buf)

      local result = caml_marshal_read_block(str, 0, simple_read_value)
      assert_eq(result.value.tag, tag, "Tag mismatch")
      assert_eq(result.value.size, size, "Size mismatch")
      for i = 1, size do
        assert_eq(result.value[i], i, "Field mismatch")
      end
    end
  end
end)

test("roundtrip: BLOCK32 boundary cases", function()
  local cases = {
    {tag = 16, size = 0},
    {tag = 0, size = 8},
    {tag = 100, size = 10},
    {tag = 255, size = 100},
    {tag = 1023, size = 1000}
  }

  for _, tc in ipairs(cases) do
    local block = {tag = tc.tag, size = tc.size}
    for i = 1, tc.size do
      block[i] = i % 64  -- Use small ints for testing
    end

    local buf = caml_marshal_buffer_create()
    caml_marshal_write_block(buf, block, simple_write_value)
    local str = caml_marshal_buffer_to_string(buf)

    local result = caml_marshal_read_block(str, 0, simple_read_value)
    assert_eq(result.value.tag, tc.tag, "Tag mismatch for " .. tc.tag)
    assert_eq(result.value.size, tc.size, "Size mismatch for " .. tc.size)
  end
end)

test("roundtrip: empty block", function()
  local block = {tag = 0, size = 0}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_block(str, 0, simple_read_value)
  assert_eq(result.value.tag, 0)
  assert_eq(result.value.size, 0)
end)

test("roundtrip: block with various field values", function()
  local block = {tag = 3, size = 5, [1] = 0, [2] = 63, [3] = 100, [4] = -50, [5] = 1000}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, block, simple_write_value)
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_block(str, 0, simple_read_value)
  assert_eq(result.value.tag, 3)
  assert_eq(result.value.size, 5)
  assert_eq(result.value[1], 0)
  assert_eq(result.value[2], 63)
  assert_eq(result.value[3], 100)
  assert_eq(result.value[4], -50)
  assert_eq(result.value[5], 1000)
end)

print()
print("Nested Block Tests:")
print("--------------------------------------------------------------------")

-- Helper: write_value_fn that can handle both ints and blocks
local function nested_write_value(buf, value)
  if type(value) == "table" and value.tag ~= nil then
    caml_marshal_write_block(buf, value, nested_write_value)
  else
    caml_marshal_write_int(buf, value)
  end
end

-- Helper: read_value_fn that can handle both ints and blocks
local function nested_read_value(str, offset)
  local code = caml_marshal_read8u(str, offset)
  if code >= 0x80 or code == 0x08 then
    return caml_marshal_read_block(str, offset, nested_read_value)
  else
    return caml_marshal_read_int(str, offset)
  end
end

test("nested: block containing block", function()
  local inner = {tag = 1, size = 2, [1] = 10, [2] = 20}
  local outer = {tag = 0, size = 1, [1] = inner}

  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, outer, nested_write_value)
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_block(str, 0, nested_read_value)
  assert_eq(result.value.tag, 0)
  assert_eq(result.value.size, 1)
  -- result.value[1] is the nested block (extracted from result.value by marshal.lua:298)
  local inner_block = result.value[1]
  assert_eq(inner_block.tag, 1)
  assert_eq(inner_block.size, 2)
  assert_eq(inner_block[1], 10)
  assert_eq(inner_block[2], 20)
end)

test("nested: block with mixed fields", function()
  local inner = {tag = 2, size = 1, [1] = 42}
  local outer = {tag = 5, size = 3, [1] = 100, [2] = inner, [3] = 200}

  local buf = caml_marshal_buffer_create()
  caml_marshal_write_block(buf, outer, nested_write_value)
  local str = caml_marshal_buffer_to_string(buf)

  local result = caml_marshal_read_block(str, 0, nested_read_value)
  assert_eq(result.value.tag, 5)
  assert_eq(result.value.size, 3)
  assert_eq(result.value[1], 100)
  -- result.value[2] is the nested block (extracted from result.value by marshal.lua:298)
  local inner_block = result.value[2]
  assert_eq(inner_block.tag, 2)
  assert_eq(inner_block[1], 42)
  assert_eq(result.value[3], 200)
end)

print()
print("Format Selection Tests:")
print("--------------------------------------------------------------------")

test("format: tag 0-15, size 0-7 uses small block", function()
  for tag = 0, 15 do
    for size = 0, 7 do
      local block = {tag = tag, size = size}
      -- Add field data for blocks with size > 0
      for i = 1, size do
        block[i] = 0
      end
      local buf = caml_marshal_buffer_create()
      caml_marshal_write_block(buf, block, simple_write_value)
      assert_eq(buf.bytes[1], 0x80 + tag + size * 16, "Small block encoding")
      assert_true(buf.length >= 1, "At least header byte")
    end
  end
end)

test("format: tag >= 16 uses BLOCK32", function()
  local tags = {16, 100, 255, 1023}
  for _, tag in ipairs(tags) do
    local block = {tag = tag, size = 0}
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_block(buf, block, simple_write_value)
    assert_eq(buf.bytes[1], 0x08, "Tag " .. tag .. " should use BLOCK32")
  end
end)

test("format: size >= 8 uses BLOCK32", function()
  local sizes = {8, 10, 100, 1000}
  for _, size in ipairs(sizes) do
    local block = {tag = 0, size = size}
    for i = 1, size do
      block[i] = 0
    end
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_block(buf, block, simple_write_value)
    assert_eq(buf.bytes[1], 0x08, "Size " .. size .. " should use BLOCK32")
  end
end)

print()
print("Error Handling Tests:")
print("--------------------------------------------------------------------")

test("read_block: invalid code", function()
  local str = string.char(0x05)  -- Invalid code for block
  local success = pcall(function()
    caml_marshal_read_block(str, 0, simple_read_value)
  end)
  assert_true(not success, "Should error on invalid code")
end)

print()
print("====================================================================")
print("Tests passed: " .. tests_passed .. " / " .. (tests_passed + tests_failed))
if tests_failed == 0 then
  print("All tests passed! ✓")
  print("====================================================================")
  os.exit(0)
else
  print("Some tests failed.")
  print("====================================================================")
  os.exit(1)
end
