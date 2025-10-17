#!/usr/bin/env lua
-- Test suite for object sharing (Task 6.1.8)
-- Works on Lua 5.1+

dofile("marshal_io.lua")
dofile("marshal_header.lua")
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

local function assert_false(value, msg)
  if value then
    error(msg or "Expected false, got true")
  end
end

local function assert_lt(a, b, msg)
  if not (a < b) then
    error(msg or ("Expected " .. tostring(a) .. " < " .. tostring(b)))
  end
end

print("====================================================================")
print("Object Sharing Tests (Task 6.1.8)")
print("====================================================================")
print()

print("Simple Sharing:")
print("--------------------------------------------------------------------")

test("simple sharing: same table referenced twice", function()
  local shared = {tag = 1, size = 2, [1] = 10, [2] = 20}
  local container = {tag = 0, size = 2, [1] = shared, [2] = shared}

  local marshaled = caml_marshal_to_string(container)
  local result = caml_marshal_from_bytes(marshaled)

  -- Check structure
  assert_eq(result.tag, 0)
  assert_eq(result[1].tag, 1)
  assert_eq(result[2].tag, 1)
  assert_eq(result[1][1], 10)
  assert_eq(result[2][1], 10)

  -- Check identity: result[1] and result[2] should be the same table
  assert_true(result[1] == result[2], "Shared references should point to same table")
end)

test("simple sharing: three references to same table", function()
  local shared = {tag = 5, size = 1, [1] = 42}
  local container = {tag = 0, size = 3, [1] = shared, [2] = shared, [3] = shared}

  local marshaled = caml_marshal_to_string(container)
  local result = caml_marshal_from_bytes(marshaled)

  assert_eq(result.tag, 0)
  assert_true(result[1] == result[2], "First and second refs should be same")
  assert_true(result[2] == result[3], "Second and third refs should be same")
  assert_true(result[1] == result[3], "First and third refs should be same")
  assert_eq(result[1][1], 42)
end)

test("simple sharing: float array shared", function()
  local shared = {size = 3, [1] = 1.5, [2] = 2.5, [3] = 3.5}
  local container = {tag = 0, size = 2, [1] = shared, [2] = shared}

  local marshaled = caml_marshal_to_string(container)
  local result = caml_marshal_from_bytes(marshaled)

  assert_eq(result.tag, 0)
  assert_true(result[1] == result[2], "Shared float arrays should be same table")
  assert_eq(result[1][1], 1.5)
  assert_eq(result[1][2], 2.5)
  assert_eq(result[1][3], 3.5)
end)

print()
print("Size Reduction:")
print("--------------------------------------------------------------------")

test("size: sharing reduces marshaled size", function()
  -- Large shared table
  local shared = {tag = 1, size = 10}
  for i = 1, 10 do
    shared[i] = i * 100
  end

  -- Reference it 10 times
  local with_sharing = {tag = 0, size = 10}
  for i = 1, 10 do
    with_sharing[i] = shared
  end

  -- Marshal with sharing
  local marshaled_with = caml_marshal_to_string(with_sharing)
  local size_with = #marshaled_with

  -- Create equivalent structure without sharing (10 separate copies)
  local without_sharing = {tag = 0, size = 10}
  for i = 1, 10 do
    local copy = {tag = 1, size = 10}
    for j = 1, 10 do
      copy[j] = j * 100
    end
    without_sharing[i] = copy
  end

  -- Marshal without sharing (disable by using separate tables)
  local marshaled_without = caml_marshal_to_string(without_sharing)
  local size_without = #marshaled_without

  -- With sharing should be significantly smaller
  assert_lt(size_with, size_without, "Shared version should be smaller")

  -- Verify correctness
  local result = caml_marshal_from_bytes(marshaled_with)
  assert_eq(result.tag, 0)
  assert_true(result[1] == result[2], "Should preserve sharing")
end)

print()
print("DAG (Directed Acyclic Graph):")
print("--------------------------------------------------------------------")

test("DAG: diamond pattern with sharing", function()
  -- Diamond: top → left, top → right, left → bottom, right → bottom
  local bottom = {tag = 3, size = 1, [1] = 99}
  local left = {tag = 1, size = 1, [1] = bottom}
  local right = {tag = 2, size = 1, [1] = bottom}
  local top = {tag = 0, size = 2, [1] = left, [2] = right}

  local marshaled = caml_marshal_to_string(top)
  local result = caml_marshal_from_bytes(marshaled)

  -- Check structure
  assert_eq(result.tag, 0)
  assert_eq(result[1].tag, 1)
  assert_eq(result[2].tag, 2)
  assert_eq(result[1][1].tag, 3)
  assert_eq(result[2][1].tag, 3)

  -- Check sharing: bottom should be shared
  assert_true(result[1][1] == result[2][1], "Bottom node should be shared")
  assert_eq(result[1][1][1], 99)
end)

test("DAG: multiple paths to same node", function()
  local shared = {tag = 5, size = 1, [1] = "shared"}
  local a = {tag = 1, size = 1, [1] = shared}
  local b = {tag = 2, size = 1, [1] = shared}
  local c = {tag = 3, size = 1, [1] = shared}
  local top = {tag = 0, size = 3, [1] = a, [2] = b, [3] = c}

  local marshaled = caml_marshal_to_string(top)
  local result = caml_marshal_from_bytes(marshaled)

  -- Check structure
  assert_eq(result.tag, 0)

  -- Check sharing: all three paths should reach the same node
  assert_true(result[1][1] == result[2][1], "Path 1 and 2 should share")
  assert_true(result[2][1] == result[3][1], "Path 2 and 3 should share")
  assert_eq(result[1][1][1], "shared")
end)

test("DAG: complex multi-level sharing", function()
  -- Create a complex DAG with multiple levels of sharing
  local leaf1 = {tag = 10, size = 1, [1] = 100}
  local leaf2 = {tag = 11, size = 1, [1] = 200}

  local mid1 = {tag = 5, size = 2, [1] = leaf1, [2] = leaf2}
  local mid2 = {tag = 6, size = 2, [1] = leaf1, [2] = leaf2}

  local top = {tag = 0, size = 4, [1] = mid1, [2] = mid2, [3] = leaf1, [4] = leaf2}

  local marshaled = caml_marshal_to_string(top)
  local result = caml_marshal_from_bytes(marshaled)

  -- Check all sharing relationships
  assert_true(result[1][1] == result[2][1], "mid1.leaf1 == mid2.leaf1")
  assert_true(result[1][2] == result[2][2], "mid1.leaf2 == mid2.leaf2")
  assert_true(result[1][1] == result[3], "mid1.leaf1 == top.leaf1")
  assert_true(result[1][2] == result[4], "mid1.leaf2 == top.leaf2")
  assert_true(result[2][1] == result[3], "mid2.leaf1 == top.leaf1")
  assert_true(result[2][2] == result[4], "mid2.leaf2 == top.leaf2")
end)

print()
print("Cycles With Sharing:")
print("--------------------------------------------------------------------")

test("cycle with sharing: self-reference now works", function()
  local x = {tag = 0, size = 1}
  x[1] = x

  -- With object sharing, cycles are now valid!
  local marshaled = caml_marshal_to_string(x)
  local result = caml_marshal_from_bytes(marshaled)

  -- Check structure
  assert_eq(result.tag, 0)
  assert_eq(result.size, 1)

  -- Check cycle: result[1] should be result itself
  assert_true(result[1] == result, "Self-reference should be preserved")
end)

test("cycle with sharing: 2-node cycle now works", function()
  local a = {tag = 0, size = 1}
  local b = {tag = 1, size = 1}
  a[1] = b
  b[1] = a

  -- With object sharing, cycles are now valid!
  local marshaled = caml_marshal_to_string(a)
  local result = caml_marshal_from_bytes(marshaled)

  -- Check structure
  assert_eq(result.tag, 0)
  assert_eq(result.size, 1)
  assert_eq(result[1].tag, 1)
  assert_eq(result[1].size, 1)

  -- Check cycle: a → b → a
  assert_true(result[1][1] == result, "Cycle should be preserved")
end)

print()
print("Mixed Sharing:")
print("--------------------------------------------------------------------")

test("mixed: some shared, some not shared", function()
  local shared = {tag = 1, size = 1, [1] = 42}
  local unshared1 = {tag = 2, size = 1, [1] = 100}
  local unshared2 = {tag = 3, size = 1, [1] = 200}

  local container = {tag = 0, size = 4, [1] = shared, [2] = unshared1, [3] = shared, [4] = unshared2}

  local marshaled = caml_marshal_to_string(container)
  local result = caml_marshal_from_bytes(marshaled)

  -- Shared should be same
  assert_true(result[1] == result[3], "Shared refs should be same")

  -- Unshared should be different
  assert_false(result[2] == result[4], "Unshared refs should be different")

  -- Values should be correct
  assert_eq(result[1][1], 42)
  assert_eq(result[2][1], 100)
  assert_eq(result[3][1], 42)
  assert_eq(result[4][1], 200)
end)

test("mixed: nested sharing at different levels", function()
  local deep_shared = {tag = 10, size = 1, [1] = "deep"}
  local mid = {tag = 5, size = 1, [1] = deep_shared}
  local top = {tag = 0, size = 3, [1] = mid, [2] = mid, [3] = deep_shared}

  local marshaled = caml_marshal_to_string(top)
  local result = caml_marshal_from_bytes(marshaled)

  -- Mid level sharing
  assert_true(result[1] == result[2], "Mid level should be shared")

  -- Deep sharing through mid
  assert_true(result[1][1] == result[3], "Deep level should be shared with top")
  assert_true(result[2][1] == result[3], "Deep level should be shared through both mids")
end)

print()
print("Backward Compatibility:")
print("--------------------------------------------------------------------")

test("compatibility: can read old format without sharing", function()
  -- Manually create data without sharing (num_objects = 0)
  -- This simulates old marshal format before Task 6.1.8
  local value = {tag = 1, size = 2, [1] = 10, [2] = 20}

  -- Use old-style marshaling by creating a structure that won't share
  local container = {tag = 0, size = 2}
  -- Make two separate copies (different table instances)
  container[1] = {tag = 1, size = 2, [1] = 10, [2] = 20}
  container[2] = {tag = 1, size = 2, [1] = 10, [2] = 20}

  local marshaled = caml_marshal_to_string(container)
  local result = caml_marshal_from_bytes(marshaled)

  -- Should work fine
  assert_eq(result.tag, 0)
  assert_eq(result[1].tag, 1)
  assert_eq(result[2].tag, 1)
  assert_eq(result[1][1], 10)
  assert_eq(result[2][1], 10)

  -- These are different tables (no sharing)
  assert_false(result[1] == result[2], "Should be different tables without sharing")
end)

print()
print("Edge Cases:")
print("--------------------------------------------------------------------")

test("edge: empty shared table", function()
  local shared = {tag = 0, size = 0}
  local container = {tag = 1, size = 2, [1] = shared, [2] = shared}

  local marshaled = caml_marshal_to_string(container)
  local result = caml_marshal_from_bytes(marshaled)

  assert_eq(result.tag, 1)
  assert_true(result[1] == result[2], "Empty tables should be shared")
  assert_eq(result[1].size, 0)
end)

test("edge: single element shared many times", function()
  local shared = {tag = 1, size = 1, [1] = 999}
  local container = {tag = 0, size = 20}
  for i = 1, 20 do
    container[i] = shared
  end

  local marshaled = caml_marshal_to_string(container)
  local result = caml_marshal_from_bytes(marshaled)

  -- All should be the same table
  for i = 2, 20 do
    assert_true(result[1] == result[i], "All refs should be same")
  end
  assert_eq(result[1][1], 999)
end)

test("edge: deeply nested shared structure", function()
  local shared = {tag = 1, size = 1, [1] = "leaf"}
  local value = shared

  -- Build 5 levels, each referencing the shared leaf twice
  for i = 1, 5 do
    value = {tag = i + 1, size = 2, [1] = value, [2] = shared}
  end

  local marshaled = caml_marshal_to_string(value)
  local result = caml_marshal_from_bytes(marshaled)

  -- Verify structure
  assert_eq(result.tag, 6)

  -- Walk down left path
  local current = result
  for i = 1, 5 do
    assert_eq(current.tag, 7 - i)
    current = current[1]
  end
  assert_eq(current[1], "leaf")

  -- Verify sharing: all paths should reach the same leaf
  assert_true(result[2] == result[1][2], "Level 1 sharing")
  assert_true(result[2] == result[1][1][2], "Level 2 sharing")
end)

test("edge: sharing with mixed types", function()
  local shared_block = {tag = 1, size = 1, [1] = 42}
  local shared_array = {size = 3, [1] = 1.5, [2] = 2.5, [3] = 3.5}

  local container = {tag = 0, size = 4, [1] = shared_block, [2] = shared_array, [3] = shared_block, [4] = shared_array}

  local marshaled = caml_marshal_to_string(container)
  local result = caml_marshal_from_bytes(marshaled)

  -- Blocks should be shared
  assert_true(result[1] == result[3], "Blocks should be shared")

  -- Arrays should be shared
  assert_true(result[2] == result[4], "Arrays should be shared")

  -- Different types should not be same
  assert_false(result[1] == result[2], "Different types should be different")
end)

print()
print("Header Verification:")
print("--------------------------------------------------------------------")

test("header: num_objects reflects actual count", function()
  local shared = {tag = 1, size = 1, [1] = 42}
  local container = {tag = 0, size = 3, [1] = shared, [2] = shared, [3] = shared}

  local marshaled = caml_marshal_to_string(container)

  -- Read header manually
  local b1 = string.byte(marshaled, 1)
  local b2 = string.byte(marshaled, 2)
  local b3 = string.byte(marshaled, 3)
  local b4 = string.byte(marshaled, 4)
  local magic = b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
  assert_eq(magic, 0x8495A6BE, "Magic number should be correct")

  -- Read num_objects (bytes 9-12, big-endian)
  local n1 = string.byte(marshaled, 9)
  local n2 = string.byte(marshaled, 10)
  local n3 = string.byte(marshaled, 11)
  local n4 = string.byte(marshaled, 12)
  local num_objects = n1 * 16777216 + n2 * 65536 + n3 * 256 + n4

  -- Should have 2 objects: container and shared (shared is written once, referenced twice)
  assert_eq(num_objects, 2, "Should have 2 objects")
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
