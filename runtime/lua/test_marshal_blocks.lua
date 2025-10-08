#!/usr/bin/env lua
-- Test complex block marshalling

local marshal = require("marshal")

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

local function assert_close(actual, expected, epsilon, msg)
  epsilon = epsilon or 1e-10
  if math.abs(actual - expected) > epsilon then
    error(msg or ("Expected " .. tostring(expected) .. ", got " .. tostring(actual)))
  end
end

-- Test 1: Simple array-style table
test("Simple array roundtrip", function()
  local t1 = {42, "hello", 3.14}
  local m1 = marshal.to_string(t1)
  local r1 = marshal.from_bytes(m1, 0)
  assert_eq(r1[1], 42)
  assert_eq(r1[2], "hello")
  assert_close(r1[3], 3.14)
end)

-- Test 2: Nested tables
test("Nested tables roundtrip", function()
  local t2 = {{1, 2}, {3, 4}}
  local m2 = marshal.to_string(t2)
  local r2 = marshal.from_bytes(m2, 0)
  assert_eq(r2[1][1], 1)
  assert_eq(r2[1][2], 2)
  assert_eq(r2[2][1], 3)
  assert_eq(r2[2][2], 4)
end)

-- Test 3: Mixed types
test("Mixed types in table", function()
  local t3 = {100, "test", {5, 6}}
  local m3 = marshal.to_string(t3)
  local r3 = marshal.from_bytes(m3, 0)
  assert_eq(r3[1], 100)
  assert_eq(r3[2], "test")
  assert_eq(r3[3][1], 5)
  assert_eq(r3[3][2], 6)
end)

-- Test 4: Deeply nested structure
test("Deeply nested structure", function()
  local t4 = {1, {2, {3, {4, 5}}}}
  local m4 = marshal.to_string(t4)
  local r4 = marshal.from_bytes(m4, 0)
  assert_eq(r4[1], 1)
  assert_eq(r4[2][1], 2)
  assert_eq(r4[2][2][1], 3)
  assert_eq(r4[2][2][2][1], 4)
  assert_eq(r4[2][2][2][2], 5)
end)

-- Test 5: Empty table
test("Empty table", function()
  local t5 = {}
  local m5 = marshal.to_string(t5)
  local r5 = marshal.from_bytes(m5, 0)
  assert_eq(r5.tag, 0)
  assert_eq(r5.size, 0)
end)

-- Test 6: Table with strings
test("Table with multiple strings", function()
  local t6 = {"alpha", "beta", "gamma"}
  local m6 = marshal.to_string(t6)
  local r6 = marshal.from_bytes(m6, 0)
  assert_eq(r6[1], "alpha")
  assert_eq(r6[2], "beta")
  assert_eq(r6[3], "gamma")
end)

-- Test 7: Block with explicit tag/size
test("Block with explicit tag and size", function()
  local t7 = {tag = 0, size = 2, [1] = 10, [2] = 20}
  local m7 = marshal.to_string(t7)
  local r7 = marshal.from_bytes(m7, 0)
  assert_eq(r7.tag, 0)
  assert_eq(r7.size, 2)
  assert_eq(r7[1], 10)
  assert_eq(r7[2], 20)
end)

-- Test 8: Complex mixed structure
test("Complex mixed structure", function()
  local t8 = {
    {1, 2, 3},
    "middle",
    {
      {4, 5},
      {6, 7, 8}
    }
  }
  local m8 = marshal.to_string(t8)
  local r8 = marshal.from_bytes(m8, 0)
  assert_eq(r8[1][1], 1)
  assert_eq(r8[1][2], 2)
  assert_eq(r8[1][3], 3)
  assert_eq(r8[2], "middle")
  assert_eq(r8[3][1][1], 4)
  assert_eq(r8[3][1][2], 5)
  assert_eq(r8[3][2][1], 6)
  assert_eq(r8[3][2][2], 7)
  assert_eq(r8[3][2][3], 8)
end)

-- Test 9: Large array
test("Large array (100 elements)", function()
  local t9 = {}
  for i = 1, 100 do
    t9[i] = i * 2
  end
  local m9 = marshal.to_string(t9)
  local r9 = marshal.from_bytes(m9, 0)
  for i = 1, 100 do
    assert_eq(r9[i], i * 2, "Element " .. i)
  end
end)

-- Test 10: Array with numbers and nested arrays
test("Array with numbers and nested arrays", function()
  local t10 = {1, {2, 3}, 4, {5, {6, 7}}, 8}
  local m10 = marshal.to_string(t10)
  local r10 = marshal.from_bytes(m10, 0)
  assert_eq(r10[1], 1)
  assert_eq(r10[2][1], 2)
  assert_eq(r10[2][2], 3)
  assert_eq(r10[3], 4)
  assert_eq(r10[4][1], 5)
  assert_eq(r10[4][2][1], 6)
  assert_eq(r10[4][2][2], 7)
  assert_eq(r10[5], 8)
end)

print("\n" .. string.rep("=", 60))
print("Tests passed: " .. tests_passed)
print("Tests failed: " .. tests_failed)
if tests_failed == 0 then
  print("All tests passed! ✓")
  print(string.rep("=", 60))
  os.exit(0)
else
  print("Some tests failed.")
  print(string.rep("=", 60))
  os.exit(1)
end
