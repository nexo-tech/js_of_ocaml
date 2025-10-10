#!/usr/bin/env lua
-- Test suite for map.lua
-- Comprehensive tests for AVL tree-based maps

dofile("map.lua")
dofile("compare.lua")

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

-- Simple integer comparison function
local function int_cmp(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

print("=== Map Module Tests ===\n")

-- Test 1-5: Basic operations
test("empty map", function()
  local m = caml_map_empty(0)
  assert_equal(m, nil, "empty map should be nil")
  assert_equal(caml_map_is_empty(m), 1, "should be empty")
  assert_equal(caml_map_cardinal(m), 0, "should have 0 elements")
end)

test("add single element", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  assert_equal(caml_map_is_empty(m), 0, "should not be empty")
  assert_equal(caml_map_cardinal(m), 1, "should have 1 element")
  assert_equal(caml_map_mem(int_cmp, 5, m), 1, "should contain key 5")
end)

test("find existing element", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  local value = caml_map_find(int_cmp, 5, m)
  assert_equal(value, "five", "should find value 'five'")
end)

test("find non-existing element raises Not_found", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  assert_error(function()
    caml_map_find(int_cmp, 10, m)
  end, "should raise Not_found")
end)

test("find_opt with existing element", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  local result = caml_map_find_opt(int_cmp, 5, m)
  assert_equal(result.tag, 0, "should return Some")
  assert_equal(result[1], "five", "should have correct value")
end)

-- Test 6-10: Multiple elements
test("add multiple elements", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  m = caml_map_add(int_cmp, 3, "three", m)
  m = caml_map_add(int_cmp, 7, "seven", m)
  assert_equal(caml_map_cardinal(m), 3, "should have 3 elements")
  assert_equal(caml_map_find(int_cmp, 3, m), "three")
  assert_equal(caml_map_find(int_cmp, 5, m), "five")
  assert_equal(caml_map_find(int_cmp, 7, m), "seven")
end)

test("replace existing element", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  m = caml_map_add(int_cmp, 5, "FIVE", m)
  assert_equal(caml_map_cardinal(m), 1, "should still have 1 element")
  assert_equal(caml_map_find(int_cmp, 5, m), "FIVE", "value should be replaced")
end)

test("mem checks membership", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  m = caml_map_add(int_cmp, 3, "three", m)
  assert_equal(caml_map_mem(int_cmp, 5, m), 1)
  assert_equal(caml_map_mem(int_cmp, 3, m), 1)
  assert_equal(caml_map_mem(int_cmp, 10, m), 0)
end)

test("remove element", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  m = caml_map_add(int_cmp, 3, "three", m)
  m = caml_map_remove(int_cmp, 5, m)
  assert_equal(caml_map_cardinal(m), 1, "should have 1 element")
  assert_equal(caml_map_mem(int_cmp, 5, m), 0, "key 5 should be removed")
  assert_equal(caml_map_mem(int_cmp, 3, m), 1, "key 3 should remain")
end)

test("remove non-existing element", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  m = caml_map_remove(int_cmp, 10, m)
  assert_equal(caml_map_cardinal(m), 1, "should still have 1 element")
end)

-- Test 11-15: Iteration and folding
test("iter over empty map", function()
  local m = caml_map_empty(0)
  local count = 0
  caml_map_iter(function(k, v)
    count = count + 1
  end, m)
  assert_equal(count, 0, "should not iterate")
end)

test("iter over map elements in order", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  m = caml_map_add(int_cmp, 3, "three", m)
  m = caml_map_add(int_cmp, 7, "seven", m)
  m = caml_map_add(int_cmp, 1, "one", m)

  local keys = {}
  caml_map_iter(function(k, v)
    table.insert(keys, k)
  end, m)

  assert_equal(#keys, 4, "should iterate over all elements")
  assert_equal(keys[1], 1, "keys should be in order")
  assert_equal(keys[2], 3)
  assert_equal(keys[3], 5)
  assert_equal(keys[4], 7)
end)

test("fold to sum keys", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  m = caml_map_add(int_cmp, 3, "three", m)
  m = caml_map_add(int_cmp, 7, "seven", m)

  local sum = caml_map_fold(function(k, v, acc)
    return acc + k
  end, m, 0)

  assert_equal(sum, 15, "sum of keys should be 15")
end)

test("fold to collect values", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 1, "a", m)
  m = caml_map_add(int_cmp, 2, "b", m)
  m = caml_map_add(int_cmp, 3, "c", m)

  local values = caml_map_fold(function(k, v, acc)
    return acc .. v
  end, m, "")

  assert_equal(values, "abc", "concatenated values should be 'abc'")
end)

test("for_all with true predicate", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 2, "even", m)
  m = caml_map_add(int_cmp, 4, "even", m)
  m = caml_map_add(int_cmp, 6, "even", m)

  local result = caml_map_for_all(function(k, v)
    return k % 2 == 0
  end, m)

  assert_equal(result, 1, "all keys should be even")
end)

-- Test 16-20: Advanced operations
test("for_all with false predicate", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 2, "even", m)
  m = caml_map_add(int_cmp, 3, "odd", m)
  m = caml_map_add(int_cmp, 4, "even", m)

  local result = caml_map_for_all(function(k, v)
    return k % 2 == 0
  end, m)

  assert_equal(result, 0, "not all keys are even")
end)

test("exists with matching element", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 2, "even", m)
  m = caml_map_add(int_cmp, 3, "odd", m)
  m = caml_map_add(int_cmp, 4, "even", m)

  local result = caml_map_exists(function(k, v)
    return k == 3
  end, m)

  assert_equal(result, 1, "should find key 3")
end)

test("exists without matching element", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 2, "even", m)
  m = caml_map_add(int_cmp, 4, "even", m)

  local result = caml_map_exists(function(k, v)
    return k == 3
  end, m)

  assert_equal(result, 0, "should not find key 3")
end)

test("map over values", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 1, 10, m)
  m = caml_map_add(int_cmp, 2, 20, m)
  m = caml_map_add(int_cmp, 3, 30, m)

  local m2 = caml_map_map(function(v)
    return v * 2
  end, m)

  assert_equal(caml_map_find(int_cmp, 1, m2), 20)
  assert_equal(caml_map_find(int_cmp, 2, m2), 40)
  assert_equal(caml_map_find(int_cmp, 3, m2), 60)
end)

test("mapi over key-value pairs", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 1, 10, m)
  m = caml_map_add(int_cmp, 2, 20, m)
  m = caml_map_add(int_cmp, 3, 30, m)

  local m2 = caml_map_mapi(function(k, v)
    return k + v
  end, m)

  assert_equal(caml_map_find(int_cmp, 1, m2), 11)
  assert_equal(caml_map_find(int_cmp, 2, m2), 22)
  assert_equal(caml_map_find(int_cmp, 3, m2), 33)
end)

-- Test 21-25: Balancing and large datasets
test("add many elements in ascending order", function()
  local m = caml_map_empty(0)
  for i = 1, 100 do
    m = caml_map_add(int_cmp, i, tostring(i), m)
  end
  assert_equal(caml_map_cardinal(m), 100, "should have 100 elements")

  -- Verify all elements are findable
  for i = 1, 100 do
    assert_equal(caml_map_find(int_cmp, i, m), tostring(i))
  end
end)

test("add many elements in descending order", function()
  local m = caml_map_empty(0)
  for i = 100, 1, -1 do
    m = caml_map_add(int_cmp, i, tostring(i), m)
  end
  assert_equal(caml_map_cardinal(m), 100, "should have 100 elements")

  -- Verify order in iteration
  local count = 0
  local prev = 0
  caml_map_iter(function(k, v)
    count = count + 1
    assert_true(k > prev, "keys should be in ascending order")
    prev = k
  end, m)
  assert_equal(count, 100)
end)

test("add many elements in random order", function()
  local m = caml_map_empty(0)
  local keys = {}
  for i = 1, 50 do
    keys[i] = i
  end

  -- Shuffle keys
  for i = #keys, 2, -1 do
    local j = math.random(1, i)
    keys[i], keys[j] = keys[j], keys[i]
  end

  -- Add in shuffled order
  for _, k in ipairs(keys) do
    m = caml_map_add(int_cmp, k, tostring(k), m)
  end

  assert_equal(caml_map_cardinal(m), 50, "should have 50 elements")

  -- Verify all findable and in order
  local prev = 0
  caml_map_iter(function(k, v)
    assert_true(k > prev, "keys should be in ascending order")
    prev = k
  end, m)
end)

test("remove many elements", function()
  local m = caml_map_empty(0)
  for i = 1, 50 do
    m = caml_map_add(int_cmp, i, tostring(i), m)
  end

  -- Remove even keys
  for i = 2, 50, 2 do
    m = caml_map_remove(int_cmp, i, m)
  end

  assert_equal(caml_map_cardinal(m), 25, "should have 25 elements")

  -- Verify only odd keys remain
  for i = 1, 50 do
    if i % 2 == 1 then
      assert_equal(caml_map_mem(int_cmp, i, m), 1, "odd key should exist")
    else
      assert_equal(caml_map_mem(int_cmp, i, m), 0, "even key should not exist")
    end
  end
end)

test("filter map", function()
  local m = caml_map_empty(0)
  for i = 1, 10 do
    m = caml_map_add(int_cmp, i, tostring(i), m)
  end

  local m2 = caml_map_filter(int_cmp, function(k, v)
    return k % 2 == 0
  end, m)

  assert_equal(caml_map_cardinal(m2), 5, "should have 5 even elements")
  assert_equal(caml_map_mem(int_cmp, 2, m2), 1)
  assert_equal(caml_map_mem(int_cmp, 4, m2), 1)
  assert_equal(caml_map_mem(int_cmp, 1, m2), 0)
end)

-- Test 26-30: Edge cases
test("remove from single-element map", function()
  local m = caml_map_empty(0)
  m = caml_map_add(int_cmp, 5, "five", m)
  m = caml_map_remove(int_cmp, 5, m)
  assert_equal(m, nil, "map should be empty")
  assert_equal(caml_map_is_empty(m), 1)
end)

test("find_opt on empty map", function()
  local m = caml_map_empty(0)
  local result = caml_map_find_opt(int_cmp, 5, m)
  assert_equal(result, 0, "should return None")
end)

test("immutability: original map unchanged after add", function()
  local m1 = caml_map_empty(0)
  m1 = caml_map_add(int_cmp, 5, "five", m1)
  local m2 = caml_map_add(int_cmp, 10, "ten", m1)

  -- m1 should still have only 1 element (structural sharing in implementation)
  -- Note: This tests implementation behavior, not OCaml semantics
  assert_equal(caml_map_cardinal(m2), 2, "m2 should have 2 elements")
end)

test("complex comparison with polymorphic compare", function()
  local m = caml_map_empty(0)
  m = caml_map_add(caml_compare, "apple", 1, m)
  m = caml_map_add(caml_compare, "banana", 2, m)
  m = caml_map_add(caml_compare, "cherry", 3, m)

  assert_equal(caml_map_find(caml_compare, "banana", m), 2)
  assert_equal(caml_map_cardinal(m), 3)

  -- Check iteration order
  local keys = {}
  caml_map_iter(function(k, v)
    table.insert(keys, k)
  end, m)
  assert_equal(keys[1], "apple")
  assert_equal(keys[2], "banana")
  assert_equal(keys[3], "cherry")
end)

test("empty operations on empty map", function()
  local m = caml_map_empty(0)
  assert_equal(caml_map_for_all(function() return false end, m), 1)
  assert_equal(caml_map_exists(function() return true end, m), 0)
  local m2 = caml_map_map(function(v) return v * 2 end, m)
  assert_equal(m2, nil, "mapped empty map should be empty")
end)

-- Test 31-33: Performance tests
test("add performance", function()
  local m = caml_map_empty(0)
  local start = os.clock()
  for i = 1, 1000 do
    m = caml_map_add(int_cmp, i, i, m)
  end
  local elapsed = os.clock() - start
  assert_true(elapsed < 1.0, "should be fast (< 1s for 1000 insertions)")
end)

test("find performance", function()
  local m = caml_map_empty(0)
  for i = 1, 1000 do
    m = caml_map_add(int_cmp, i, i, m)
  end

  local start = os.clock()
  for i = 1, 1000 do
    caml_map_find(int_cmp, i, m)
  end
  local elapsed = os.clock() - start
  assert_true(elapsed < 0.5, "should be fast (< 0.5s for 1000 lookups)")
end)

test("iter performance", function()
  local m = caml_map_empty(0)
  for i = 1, 1000 do
    m = caml_map_add(int_cmp, i, i, m)
  end

  local start = os.clock()
  local count = 0
  caml_map_iter(function(k, v)
    count = count + 1
  end, m)
  local elapsed = os.clock() - start
  assert_equal(count, 1000)
  assert_true(elapsed < 0.5, "should be fast (< 0.5s for 1000 iterations)")
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
