#!/usr/bin/env lua
-- Test suite for core value marshaling (Task 6.1.5)
-- Works on Lua 5.1+

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

local function assert_near(actual, expected, tolerance, msg)
  local diff = math.abs(actual - expected)
  if diff > tolerance then
    error(msg or string.format("Expected %g (±%g), got %g (diff: %g)", expected, tolerance, actual, diff))
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "Expected true, got false")
  end
end

print("====================================================================")
print("Core Value Marshaling Tests (Task 6.1.5)")
print("====================================================================")
print()

print("Integer Marshaling:")
print("--------------------------------------------------------------------")

test("write/read value: integer 0", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, 0)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, 0)
end)

test("write/read value: integer 42", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, 42)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, 42)
end)

test("write/read value: integer -100", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, -100)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, -100)
end)

test("write/read value: large integer", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, 1000000)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, 1000000)
end)

print()
print("Double Marshaling:")
print("--------------------------------------------------------------------")

test("write/read value: double 3.14", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, 3.14)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_near(result.value, 3.14, 1e-15)
end)

test("write/read value: double 0.5", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, 0.5)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_near(result.value, 0.5, 1e-15)
end)

test("write/read value: large double", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, 1.23e50)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_near(result.value, 1.23e50, 1e35)
end)

test("write/read value: infinity", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, math.huge)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, math.huge)
end)

print()
print("String Marshaling:")
print("--------------------------------------------------------------------")

test("write/read value: empty string", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, "")
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, "")
end)

test("write/read value: string 'hello'", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, "hello")
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, "hello")
end)

test("write/read value: long string", function()
  local s = string.rep("abcdef", 50)  -- 300 chars
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, s)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, s)
end)

print()
print("Boolean Marshaling:")
print("--------------------------------------------------------------------")

test("write/read value: true", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, true)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, 1)  -- Encoded as integer 1
end)

test("write/read value: false", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, false)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, 0)  -- Encoded as integer 0
end)

print()
print("Nil Marshaling:")
print("--------------------------------------------------------------------")

test("write/read value: nil", function()
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, nil)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value, 0)  -- Encoded as integer 0
end)

print()
print("Block Marshaling:")
print("--------------------------------------------------------------------")

test("write/read value: empty block", function()
  local block = {tag = 0, size = 0}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, block)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value.tag, 0)
  assert_eq(result.value.size, 0)
end)

test("write/read value: block with integers", function()
  local block = {tag = 1, size = 3, [1] = 10, [2] = 20, [3] = 30}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, block)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value.tag, 1)
  assert_eq(result.value.size, 3)
  assert_eq(result.value[1], 10)
  assert_eq(result.value[2], 20)
  assert_eq(result.value[3], 30)
end)

test("write/read value: block with strings", function()
  local block = {tag = 2, size = 2, [1] = "foo", [2] = "bar"}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, block)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value.tag, 2)
  assert_eq(result.value.size, 2)
  assert_eq(result.value[1], "foo")
  assert_eq(result.value[2], "bar")
end)

test("write/read value: block with mixed types", function()
  local block = {tag = 5, size = 3, [1] = 42, [2] = "hello", [3] = 3.14}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, block)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value.tag, 5)
  assert_eq(result.value.size, 3)
  assert_eq(result.value[1], 42)
  assert_eq(result.value[2], "hello")
  assert_near(result.value[3], 3.14, 1e-15)
end)

print()
print("Nested Block Marshaling:")
print("--------------------------------------------------------------------")

test("write/read value: nested blocks", function()
  local inner = {tag = 1, size = 2, [1] = 10, [2] = 20}
  local outer = {tag = 0, size = 2, [1] = 5, [2] = inner}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, outer)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value.tag, 0)
  assert_eq(result.value.size, 2)
  assert_eq(result.value[1], 5)
  assert_eq(result.value[2].tag, 1)
  assert_eq(result.value[2].size, 2)
  assert_eq(result.value[2][1], 10)
  assert_eq(result.value[2][2], 20)
end)

test("write/read value: deeply nested blocks", function()
  local level3 = {tag = 3, size = 1, [1] = 99}
  local level2 = {tag = 2, size = 1, [1] = level3}
  local level1 = {tag = 1, size = 1, [1] = level2}
  local level0 = {tag = 0, size = 1, [1] = level1}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, level0)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value.tag, 0)
  assert_eq(result.value[1].tag, 1)
  assert_eq(result.value[1][1].tag, 2)
  assert_eq(result.value[1][1][1].tag, 3)
  assert_eq(result.value[1][1][1][1], 99)
end)

print()
print("Float Array Marshaling:")
print("--------------------------------------------------------------------")

test("write/read value: float array (explicit)", function()
  local arr = {size = 5, [1] = 1.0, [2] = 2.0, [3] = 3.0, [4] = 4.0, [5] = 5.0}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value.size, 5)
  for i = 1, 5 do
    assert_near(result.value[i], i * 1.0, 1e-15)
  end
end)

test("write/read value: float array (inferred)", function()
  local arr = {1.5, 2.5, 3.5}  -- No tag field, all numbers
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value.size, 3)
  assert_near(result.value[1], 1.5, 1e-15)
  assert_near(result.value[2], 2.5, 1e-15)
  assert_near(result.value[3], 3.5, 1e-15)
end)

print()
print("Array Without Tag (Treated as Block):")
print("--------------------------------------------------------------------")

test("write/read value: array without tag (mixed types)", function()
  local arr = {10, "hello", 3.14}  -- No tag field, mixed types
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  -- Should be encoded as block with tag 0
  assert_eq(result.value.tag, 0)
  assert_eq(result.value.size, 3)
  assert_eq(result.value[1], 10)
  assert_eq(result.value[2], "hello")
  assert_near(result.value[3], 3.14, 1e-15)
end)

test("write/read value: empty array without tag", function()
  local arr = {}  -- No tag field, empty
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, arr)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  -- Should be encoded as block with tag 0, size 0
  assert_eq(result.value.tag, 0)
  assert_eq(result.value.size, 0)
end)

print()
print("Complex Nested Structures:")
print("--------------------------------------------------------------------")

test("write/read value: block containing float array", function()
  local float_arr = {size = 3, [1] = 1.0, [2] = 2.0, [3] = 3.0}
  local block = {tag = 10, size = 2, [1] = 42, [2] = float_arr}
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, block)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value.tag, 10)
  assert_eq(result.value.size, 2)
  assert_eq(result.value[1], 42)
  assert_eq(result.value[2].size, 3)
  assert_near(result.value[2][1], 1.0, 1e-15)
  assert_near(result.value[2][2], 2.0, 1e-15)
  assert_near(result.value[2][3], 3.0, 1e-15)
end)

test("write/read value: block with all types", function()
  local inner_block = {tag = 1, size = 1, [1] = "nested"}
  local float_arr = {size = 2, [1] = 1.5, [2] = 2.5}
  local block = {tag = 100, size = 5,
                [1] = 42,          -- int
                [2] = 3.14,        -- double
                [3] = "hello",     -- string
                [4] = inner_block, -- block
                [5] = float_arr}   -- float array
  local buf = caml_marshal_buffer_create()
  caml_marshal_write_value(buf, block)
  local str = caml_marshal_buffer_to_string(buf)
  local result = caml_marshal_read_value(str, 0)
  assert_eq(result.value.tag, 100)
  assert_eq(result.value.size, 5)
  assert_eq(result.value[1], 42)
  assert_near(result.value[2], 3.14, 1e-15)
  assert_eq(result.value[3], "hello")
  assert_eq(result.value[4].tag, 1)
  assert_eq(result.value[4][1], "nested")
  assert_eq(result.value[5].size, 2)
  assert_near(result.value[5][1], 1.5, 1e-15)
end)

print()
print("Roundtrip Tests (Various Types):")
print("--------------------------------------------------------------------")

test("roundtrip: integers range", function()
  local values = {0, 1, 63, 64, 127, 128, 1000, 32767, 32768, 100000, -1, -50, -128, -129, -1000, -32768, -32769}
  for _, v in ipairs(values) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_value(buf, v)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_value(str, 0)
    assert_eq(result.value, v, "Roundtrip int " .. v)
  end
end)

test("roundtrip: doubles range", function()
  local values = {0.5, 1.5, 3.14159, 2.71828, 1e-10, 1e10, 1e100, -0.5, -1.5, -3.14}
  for _, v in ipairs(values) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_value(buf, v)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_value(str, 0)
    assert_near(result.value, v, math.abs(v) * 1e-15 + 1e-15, "Roundtrip double " .. v)
  end
end)

test("roundtrip: strings range", function()
  local values = {"", "a", "hello", string.rep("x", 31), string.rep("y", 32), string.rep("z", 255), string.rep("w", 256)}
  for _, v in ipairs(values) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_value(buf, v)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_value(str, 0)
    assert_eq(#result.value, #v, "Roundtrip string length " .. #v)
  end
end)

test("roundtrip: blocks range", function()
  local blocks = {
    {tag = 0, size = 0},
    {tag = 1, size = 1, [1] = 42},
    {tag = 15, size = 7, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [7] = 7},
    {tag = 16, size = 0},
    {tag = 100, size = 10}
  }
  for _, size_val in ipairs({1, 2, 3, 4, 5, 6, 7, 8, 9, 10}) do
    blocks[5][size_val] = size_val
  end
  for _, block in ipairs(blocks) do
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_value(buf, block)
    local str = caml_marshal_buffer_to_string(buf)
    local result = caml_marshal_read_value(str, 0)
    assert_eq(result.value.tag, block.tag, "Roundtrip block tag")
    assert_eq(result.value.size, block.size, "Roundtrip block size")
  end
end)

print()
print("Error Handling:")
print("--------------------------------------------------------------------")

test("write value: unsupported type (function)", function()
  local success = pcall(function()
    local buf = caml_marshal_buffer_create()
    caml_marshal_write_value(buf, function() end)
  end)
  assert_true(not success, "Should error on unsupported type")
end)

test("read value: invalid code", function()
  local str = string.char(0xFF, 0xFF, 0xFF)  -- Invalid code sequence
  local success = pcall(function()
    caml_marshal_read_value(str, 2)
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
