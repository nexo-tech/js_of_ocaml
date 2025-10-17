#!/usr/bin/env lua
-- Test suite for set.lua
-- Comprehensive tests for AVL tree-based sets

dofile("set.lua")
dofile("core.lua")
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

print("=== Set Module Tests ===\n")

-- Test 1-5: Basic operations
test("empty set", function()
  local s = caml_set_empty(caml_unit)
  assert_equal(s, nil, "empty set should be nil")
  assert_equal(caml_set_is_empty(s), caml_true_val, "should be empty")
  assert_equal(caml_set_cardinal(s), 0, "should have 0 elements")
end)

test("add single element", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 5, s)
  assert_equal(caml_set_is_empty(s), caml_false_val, "should not be empty")
  assert_equal(caml_set_cardinal(s), 1, "should have 1 element")
  assert_equal(caml_set_mem(int_cmp, 5, s), caml_true_val, "should contain 5")
end)

test("add duplicate element", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 5, s)
  s = caml_set_add(int_cmp, 5, s)
  assert_equal(caml_set_cardinal(s), 1, "should still have 1 element")
end)

test("mem checks membership", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 5, s)
  s = caml_set_add(int_cmp, 3, s)
  assert_equal(caml_set_mem(int_cmp, 5, s), caml_true_val)
  assert_equal(caml_set_mem(int_cmp, 3, s), caml_true_val)
  assert_equal(caml_set_mem(int_cmp, 10, s), caml_false_val)
end)

test("remove element", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 5, s)
  s = caml_set_add(int_cmp, 3, s)
  s = caml_set_remove(int_cmp, 5, s)
  assert_equal(caml_set_cardinal(s), 1, "should have 1 element")
  assert_equal(caml_set_mem(int_cmp, 5, s), caml_false_val, "5 should be removed")
  assert_equal(caml_set_mem(int_cmp, 3, s), caml_true_val, "3 should remain")
end)

-- Test 6-10: Set operations
test("union of two sets", function()
  local s1 = caml_set_empty(caml_unit)
  s1 = caml_set_add(int_cmp, 1, s1)
  s1 = caml_set_add(int_cmp, 2, s1)

  local s2 = caml_set_empty(caml_unit)
  s2 = caml_set_add(int_cmp, 2, s2)
  s2 = caml_set_add(int_cmp, 3, s2)

  local s3 = caml_set_union(int_cmp, s1, s2)
  assert_equal(caml_set_cardinal(s3), 3, "union should have 3 elements")
  assert_equal(caml_set_mem(int_cmp, 1, s3), caml_true_val)
  assert_equal(caml_set_mem(int_cmp, 2, s3), caml_true_val)
  assert_equal(caml_set_mem(int_cmp, 3, s3), caml_true_val)
end)

test("intersection of two sets", function()
  local s1 = caml_set_empty(caml_unit)
  s1 = caml_set_add(int_cmp, 1, s1)
  s1 = caml_set_add(int_cmp, 2, s1)
  s1 = caml_set_add(int_cmp, 3, s1)

  local s2 = caml_set_empty(caml_unit)
  s2 = caml_set_add(int_cmp, 2, s2)
  s2 = caml_set_add(int_cmp, 3, s2)
  s2 = caml_set_add(int_cmp, 4, s2)

  local s3 = caml_set_inter(int_cmp, s1, s2)
  assert_equal(caml_set_cardinal(s3), 2, "intersection should have 2 elements")
  assert_equal(caml_set_mem(int_cmp, 2, s3), caml_true_val)
  assert_equal(caml_set_mem(int_cmp, 3, s3), caml_true_val)
  assert_equal(caml_set_mem(int_cmp, 1, s3), caml_false_val)
end)

test("difference of two sets", function()
  local s1 = caml_set_empty(caml_unit)
  s1 = caml_set_add(int_cmp, 1, s1)
  s1 = caml_set_add(int_cmp, 2, s1)
  s1 = caml_set_add(int_cmp, 3, s1)

  local s2 = caml_set_empty(caml_unit)
  s2 = caml_set_add(int_cmp, 2, s2)
  s2 = caml_set_add(int_cmp, 4, s2)

  local s3 = caml_set_diff(int_cmp, s1, s2)
  assert_equal(caml_set_cardinal(s3), 2, "difference should have 2 elements")
  assert_equal(caml_set_mem(int_cmp, 1, s3), caml_true_val)
  assert_equal(caml_set_mem(int_cmp, 3, s3), caml_true_val)
  assert_equal(caml_set_mem(int_cmp, 2, s3), caml_false_val)
end)

test("union with empty set", function()
  local s1 = caml_set_empty(caml_unit)
  s1 = caml_set_add(int_cmp, 1, s1)

  local s2 = caml_set_empty(caml_unit)
  local s3 = caml_set_union(int_cmp, s1, s2)

  assert_equal(caml_set_cardinal(s3), 1)
  assert_equal(caml_set_mem(int_cmp, 1, s3), caml_true_val)
end)

test("intersection with empty set", function()
  local s1 = caml_set_empty(caml_unit)
  s1 = caml_set_add(int_cmp, 1, s1)

  local s2 = caml_set_empty(caml_unit)
  local s3 = caml_set_inter(int_cmp, s1, s2)

  assert_equal(s3, nil, "intersection should be empty")
end)

-- Test 11-15: Iteration and folding
test("iter over empty set", function()
  local s = caml_set_empty(caml_unit)
  local count = 0
  caml_set_iter(function(elt)
    count = count + 1
  end, s)
  assert_equal(count, 0, "should not iterate")
end)

test("iter over set elements in order", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 5, s)
  s = caml_set_add(int_cmp, 3, s)
  s = caml_set_add(int_cmp, 7, s)
  s = caml_set_add(int_cmp, 1, s)

  local elts = {}
  caml_set_iter(function(elt)
    table.insert(elts, elt)
  end, s)

  assert_equal(#elts, 4, "should iterate over all elements")
  assert_equal(elts[1], 1, "elements should be in order")
  assert_equal(elts[2], 3)
  assert_equal(elts[3], 5)
  assert_equal(elts[4], 7)
end)

test("fold to sum elements", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 5, s)
  s = caml_set_add(int_cmp, 3, s)
  s = caml_set_add(int_cmp, 7, s)

  local sum = caml_set_fold(function(elt, acc)
    return acc + elt
  end, s, 0)

  assert_equal(sum, 15, "sum should be 15")
end)

test("for_all with true predicate", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 2, s)
  s = caml_set_add(int_cmp, 4, s)
  s = caml_set_add(int_cmp, 6, s)

  local result = caml_set_for_all(function(elt)
    return elt % 2 == 0
  end, s)

  assert_equal(result, caml_true_val, "all elements should be even")
end)

test("for_all with false predicate", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 2, s)
  s = caml_set_add(int_cmp, 3, s)
  s = caml_set_add(int_cmp, 4, s)

  local result = caml_set_for_all(function(elt)
    return elt % 2 == 0
  end, s)

  assert_equal(result, caml_false_val, "not all elements are even")
end)

-- Test 16-20: Advanced operations
test("exists with matching element", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 2, s)
  s = caml_set_add(int_cmp, 3, s)
  s = caml_set_add(int_cmp, 4, s)

  local result = caml_set_exists(function(elt)
    return elt == 3
  end, s)

  assert_equal(result, caml_true_val, "should find 3")
end)

test("filter set", function()
  local s = caml_set_empty(caml_unit)
  for i = 1, 10 do
    s = caml_set_add(int_cmp, i, s)
  end

  local s2 = caml_set_filter(int_cmp, function(elt)
    return elt % 2 == 0
  end, s)

  assert_equal(caml_set_cardinal(s2), 5, "should have 5 even elements")
  assert_equal(caml_set_mem(int_cmp, 2, s2), caml_true_val)
  assert_equal(caml_set_mem(int_cmp, 1, s2), caml_false_val)
end)

test("partition set", function()
  local s = caml_set_empty(caml_unit)
  for i = 1, 10 do
    s = caml_set_add(int_cmp, i, s)
  end

  local result = caml_set_partition(int_cmp, function(elt)
    return elt % 2 == 0
  end, s)

  local evens = result[1]
  local odds = result[2]

  assert_equal(caml_set_cardinal(evens), 5, "should have 5 even elements")
  assert_equal(caml_set_cardinal(odds), 5, "should have 5 odd elements")
end)

test("subset checking", function()
  local s1 = caml_set_empty(caml_unit)
  s1 = caml_set_add(int_cmp, 2, s1)
  s1 = caml_set_add(int_cmp, 3, s1)

  local s2 = caml_set_empty(caml_unit)
  s2 = caml_set_add(int_cmp, 1, s2)
  s2 = caml_set_add(int_cmp, 2, s2)
  s2 = caml_set_add(int_cmp, 3, s2)
  s2 = caml_set_add(int_cmp, 4, s2)

  assert_equal(caml_set_subset(int_cmp, s1, s2), caml_true_val, "s1 should be subset of s2")
  assert_equal(caml_set_subset(int_cmp, s2, s1), caml_false_val, "s2 should not be subset of s1")
end)

test("min and max elements", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 5, s)
  s = caml_set_add(int_cmp, 3, s)
  s = caml_set_add(int_cmp, 7, s)
  s = caml_set_add(int_cmp, 1, s)

  assert_equal(caml_set_min_elt(s), 1, "min should be 1")
  assert_equal(caml_set_max_elt(s), 7, "max should be 7")
end)

-- Test 21-25: Large datasets and balancing
test("add many elements in ascending order", function()
  local s = caml_set_empty(caml_unit)
  for i = 1, 100 do
    s = caml_set_add(int_cmp, i, s)
  end
  assert_equal(caml_set_cardinal(s), 100, "should have 100 elements")

  for i = 1, 100 do
    assert_equal(caml_set_mem(int_cmp, i, s), caml_true_val)
  end
end)

test("add many elements in descending order", function()
  local s = caml_set_empty(caml_unit)
  for i = 100, 1, -1 do
    s = caml_set_add(int_cmp, i, s)
  end
  assert_equal(caml_set_cardinal(s), 100, "should have 100 elements")

  -- Verify order in iteration
  local prev = 0
  caml_set_iter(function(elt)
    assert_true(elt > prev, "elements should be in ascending order")
    prev = elt
  end, s)
end)

test("add many elements in random order", function()
  local s = caml_set_empty(caml_unit)
  local elts = {}
  for i = 1, 50 do
    elts[i] = i
  end

  -- Shuffle
  for i = #elts, 2, -1 do
    local j = math.random(1, i)
    elts[i], elts[j] = elts[j], elts[i]
  end

  for _, elt in ipairs(elts) do
    s = caml_set_add(int_cmp, elt, s)
  end

  assert_equal(caml_set_cardinal(s), 50, "should have 50 elements")

  -- Verify order
  local prev = 0
  caml_set_iter(function(elt)
    assert_true(elt > prev, "elements should be in ascending order")
    prev = elt
  end, s)
end)

test("remove many elements", function()
  local s = caml_set_empty(caml_unit)
  for i = 1, 50 do
    s = caml_set_add(int_cmp, i, s)
  end

  for i = 2, 50, 2 do
    s = caml_set_remove(int_cmp, i, s)
  end

  assert_equal(caml_set_cardinal(s), 25, "should have 25 elements")

  for i = 1, 50 do
    if i % 2 == 1 then
      assert_equal(caml_set_mem(int_cmp, i, s), caml_true_val)
    else
      assert_equal(caml_set_mem(int_cmp, i, s), caml_false_val)
    end
  end
end)

test("large union operation", function()
  local s1 = caml_set_empty(caml_unit)
  for i = 1, 50 do
    s1 = caml_set_add(int_cmp, i, s1)
  end

  local s2 = caml_set_empty(caml_unit)
  for i = 26, 75 do
    s2 = caml_set_add(int_cmp, i, s2)
  end

  local s3 = caml_set_union(int_cmp, s1, s2)
  assert_equal(caml_set_cardinal(s3), 75, "union should have 75 elements")
end)

-- Test 26-30: Edge cases
test("remove from single-element set", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 5, s)
  s = caml_set_remove(int_cmp, 5, s)
  assert_equal(s, nil, "set should be empty")
  assert_equal(caml_set_is_empty(s), caml_true_val)
end)

test("min_elt on empty set raises Not_found", function()
  local s = caml_set_empty(caml_unit)
  assert_error(function()
    caml_set_min_elt(s)
  end, "should raise Not_found")
end)

test("max_elt on empty set raises Not_found", function()
  local s = caml_set_empty(caml_unit)
  assert_error(function()
    caml_set_max_elt(s)
  end, "should raise Not_found")
end)

test("equal sets", function()
  local s1 = caml_set_empty(caml_unit)
  s1 = caml_set_add(int_cmp, 1, s1)
  s1 = caml_set_add(int_cmp, 2, s1)
  s1 = caml_set_add(int_cmp, 3, s1)

  local s2 = caml_set_empty(caml_unit)
  s2 = caml_set_add(int_cmp, 3, s2)
  s2 = caml_set_add(int_cmp, 1, s2)
  s2 = caml_set_add(int_cmp, 2, s2)

  assert_equal(caml_set_equal(int_cmp, s1, s2), caml_true_val, "sets should be equal")
end)

test("unequal sets", function()
  local s1 = caml_set_empty(caml_unit)
  s1 = caml_set_add(int_cmp, 1, s1)
  s1 = caml_set_add(int_cmp, 2, s1)

  local s2 = caml_set_empty(caml_unit)
  s2 = caml_set_add(int_cmp, 1, s2)
  s2 = caml_set_add(int_cmp, 3, s2)

  assert_equal(caml_set_equal(int_cmp, s1, s2), caml_false_val, "sets should not be equal")
end)

-- Test 31-35: Complex operations
test("complex comparison with polymorphic compare", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(caml_compare, "apple", s)
  s = caml_set_add(caml_compare, "banana", s)
  s = caml_set_add(caml_compare, "cherry", s)

  assert_equal(caml_set_cardinal(s), 3)

  local elts = {}
  caml_set_iter(function(elt)
    table.insert(elts, elt)
  end, s)
  assert_equal(elts[1], "apple")
  assert_equal(elts[2], "banana")
  assert_equal(elts[3], "cherry")
end)

test("union contains all elements from both sets", function()
  local s1 = caml_set_empty(caml_unit)
  s1 = caml_set_add(int_cmp, 1, s1)
  s1 = caml_set_add(int_cmp, 2, s1)

  local s2 = caml_set_empty(caml_unit)
  s2 = caml_set_add(int_cmp, 3, s2)
  s2 = caml_set_add(int_cmp, 4, s2)

  local s3 = caml_set_union(int_cmp, s1, s2)
  assert_equal(caml_set_cardinal(s3), 4, "union of disjoint sets")

  -- Verify all elements
  for i = 1, 4 do
    assert_equal(caml_set_mem(int_cmp, i, s3), caml_true_val)
  end
end)

test("empty operations on empty set", function()
  local s = caml_set_empty(caml_unit)
  assert_equal(caml_set_for_all(function() return false end, s), caml_true_val)
  assert_equal(caml_set_exists(function() return true end, s), caml_false_val)
  local s2 = caml_set_filter(int_cmp, function() return true end, s)
  assert_equal(s2, nil, "filtered empty set should be empty")
end)

test("subset reflexivity", function()
  local s = caml_set_empty(caml_unit)
  s = caml_set_add(int_cmp, 1, s)
  s = caml_set_add(int_cmp, 2, s)

  assert_equal(caml_set_subset(int_cmp, s, s), caml_true_val, "set should be subset of itself")
end)

test("empty set is subset of any set", function()
  local s1 = caml_set_empty(caml_unit)
  local s2 = caml_set_empty(caml_unit)
  s2 = caml_set_add(int_cmp, 1, s2)

  assert_equal(caml_set_subset(int_cmp, s1, s2), caml_true_val)
end)

-- Test 36-38: Performance tests
test("add performance", function()
  local s = caml_set_empty(caml_unit)
  local start = os.clock()
  for i = 1, 1000 do
    s = caml_set_add(int_cmp, i, s)
  end
  local elapsed = os.clock() - start
  assert_true(elapsed < 1.0, "should be fast (< 1s for 1000 insertions)")
end)

test("mem performance", function()
  local s = caml_set_empty(caml_unit)
  for i = 1, 1000 do
    s = caml_set_add(int_cmp, i, s)
  end

  local start = os.clock()
  for i = 1, 1000 do
    caml_set_mem(int_cmp, i, s)
  end
  local elapsed = os.clock() - start
  assert_true(elapsed < 0.5, "should be fast (< 0.5s for 1000 lookups)")
end)

test("union performance", function()
  local s1 = caml_set_empty(caml_unit)
  for i = 1, 500 do
    s1 = caml_set_add(int_cmp, i, s1)
  end

  local s2 = caml_set_empty(caml_unit)
  for i = 250, 750 do
    s2 = caml_set_add(int_cmp, i, s2)
  end

  local start = os.clock()
  local s3 = caml_set_union(int_cmp, s1, s2)
  local elapsed = os.clock() - start
  assert_equal(caml_set_cardinal(s3), 750)
  assert_true(elapsed < 1.0, "should be fast (< 1s for union)")
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
