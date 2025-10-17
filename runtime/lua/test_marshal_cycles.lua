#!/usr/bin/env lua
-- Test suite for cycle detection (Task 6.1.7)
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

local function assert_error_contains(fn, expected_substring, msg)
  local success, err = pcall(fn)
  if success then
    error(msg or "Expected error but function succeeded")
  end
  if not string.find(tostring(err), expected_substring, 1, true) then
    error(msg or ("Expected error containing '" .. expected_substring .. "', got: " .. tostring(err)))
  end
end

print("====================================================================")
print("Cycle Detection Tests (Task 6.1.7)")
print("====================================================================")
print()

print("No Cycles (Should Work):")
print("--------------------------------------------------------------------")

test("no cycle: simple value", function()
  local value = 42
  local marshaled = caml_marshal_to_string(value)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result, 42)
end)

test("no cycle: simple block", function()
  local block = {tag = 1, size = 2, [1] = 10, [2] = 20}
  local marshaled = caml_marshal_to_string(block)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 1)
  assert_eq(result[1], 10)
  assert_eq(result[2], 20)
end)

test("no cycle: nested blocks", function()
  local inner = {tag = 2, size = 1, [1] = 99}
  local outer = {tag = 1, size = 2, [1] = 42, [2] = inner}
  local marshaled = caml_marshal_to_string(outer)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 1)
  assert_eq(result[1], 42)
  assert_eq(result[2].tag, 2)
  assert_eq(result[2][1], 99)
end)

test("no cycle: deeply nested (10 levels)", function()
  local value = {tag = 10, size = 1, [1] = "deep"}
  for i = 9, 1, -1 do
    value = {tag = i, size = 1, [1] = value}
  end
  local marshaled = caml_marshal_to_string(value)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 1)
end)

print()
print("Direct Cycles (Should Work with Object Sharing):")
print("--------------------------------------------------------------------")

test("direct cycle: self-reference", function()
  local x = {tag = 0, size = 1}
  x[1] = x  -- Direct self-reference
  local marshaled = caml_marshal_to_string(x)
  local result = caml_marshal_from_bytes(marshaled)
  assert_true(result[1] == result, "Self-reference preserved")
end)

test("direct cycle: self in second field", function()
  local x = {tag = 1, size = 2}
  x[1] = 42
  x[2] = x  -- Self-reference in field 2
  local marshaled = caml_marshal_to_string(x)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result[1], 42, "First field preserved")
  assert_true(result[2] == result, "Self-reference preserved")
end)

test("direct cycle: array self-reference", function()
  local arr = {size = 2}
  arr[1] = 10
  arr[2] = arr  -- Self-reference in array (no tag field)
  local marshaled = caml_marshal_to_string(arr)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result[1], 10, "First element preserved")
  assert_true(result[2] == result, "Self-reference preserved")
end)

print()
print("Indirect Cycles (Should Work with Object Sharing):")
print("--------------------------------------------------------------------")

test("indirect cycle: 2-node cycle", function()
  local a = {tag = 0, size = 1}
  local b = {tag = 1, size = 1}
  a[1] = b
  b[1] = a  -- Creates cycle: a → b → a
  local marshaled = caml_marshal_to_string(a)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 0, "Tag preserved")
  assert_eq(result[1].tag, 1, "Inner tag preserved")
  assert_true(result[1][1] == result, "Cycle preserved")
end)

test("indirect cycle: 3-node cycle", function()
  local a = {tag = 0, size = 1}
  local b = {tag = 1, size = 1}
  local c = {tag = 2, size = 1}
  a[1] = b
  b[1] = c
  c[1] = a  -- Creates cycle: a → b → c → a
  local marshaled = caml_marshal_to_string(a)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 0, "First tag preserved")
  assert_eq(result[1].tag, 1, "Second tag preserved")
  assert_eq(result[1][1].tag, 2, "Third tag preserved")
  assert_true(result[1][1][1] == result, "Cycle preserved")
end)

test("indirect cycle: mixed with acyclic", function()
  local a = {tag = 0, size = 2}
  local b = {tag = 1, size = 2}
  local c = {tag = 2, size = 1, [1] = 999}  -- Acyclic leaf
  a[1] = b
  a[2] = c  -- Acyclic branch
  b[1] = c  -- Also points to acyclic leaf
  b[2] = a  -- Creates cycle: a → b → a
  local marshaled = caml_marshal_to_string(a)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 0, "Root tag preserved")
  assert_eq(result[1].tag, 1, "Child tag preserved")
  assert_eq(result[2][1], 999, "Acyclic leaf preserved")
  assert_true(result[1][2] == result, "Cycle preserved")
end)

print()
print("Deep Cycles (Should Work with Object Sharing):")
print("--------------------------------------------------------------------")

test("deep cycle: 10 levels then back", function()
  local nodes = {}
  for i = 1, 10 do
    nodes[i] = {tag = i, size = 1}
  end
  -- Chain them: nodes[1] → nodes[2] → ... → nodes[10]
  for i = 1, 9 do
    nodes[i][1] = nodes[i + 1]
  end
  -- Close the cycle: nodes[10] → nodes[1]
  nodes[10][1] = nodes[1]

  local marshaled = caml_marshal_to_string(nodes[1])
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 1, "First tag preserved")
  -- Follow the chain
  local current = result
  for i = 2, 10 do
    current = current[1]
    assert_eq(current.tag, i, "Tag " .. i .. " preserved")
  end
  -- Check cycle back to start
  assert_true(current[1] == result, "Cycle back to start preserved")
end)

test("deep cycle: 5 levels then back to middle", function()
  local n1 = {tag = 1, size = 1}
  local n2 = {tag = 2, size = 1}
  local n3 = {tag = 3, size = 1}
  local n4 = {tag = 4, size = 1}
  local n5 = {tag = 5, size = 1}
  n1[1] = n2
  n2[1] = n3
  n3[1] = n4
  n4[1] = n5
  n5[1] = n3  -- Cycle back to n3: n3 → n4 → n5 → n3

  local marshaled = caml_marshal_to_string(n1)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 1, "n1 tag preserved")
  assert_eq(result[1].tag, 2, "n2 tag preserved")
  assert_eq(result[1][1].tag, 3, "n3 tag preserved")
  assert_eq(result[1][1][1].tag, 4, "n4 tag preserved")
  assert_eq(result[1][1][1][1].tag, 5, "n5 tag preserved")
  assert_true(result[1][1][1][1][1] == result[1][1], "Cycle back to n3 preserved")
end)

print()
print("DAG Without Cycles (Should Work With Current Implementation):")
print("--------------------------------------------------------------------")

test("DAG: diamond pattern", function()
  -- Diamond: top → left, top → right, left → bottom, right → bottom
  -- This is a DAG (directed acyclic graph) but has shared reference to bottom
  local bottom = {tag = 3, size = 1, [1] = 99}
  local left = {tag = 1, size = 1, [1] = bottom}
  local right = {tag = 2, size = 1, [1] = bottom}
  local top = {tag = 0, size = 2, [1] = left, [2] = right}

  -- Current implementation: unmarking after processing allows this
  -- Note: bottom will be marshaled twice (no sharing yet)
  local marshaled = caml_marshal_to_string(top)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 0)
  assert_eq(result[1].tag, 1)
  assert_eq(result[2].tag, 2)
  assert_eq(result[1][1].tag, 3)
  assert_eq(result[2][1].tag, 3)
  -- Note: result[1][1] ~= result[2][1] (different tables, no sharing yet)
end)

test("DAG: multiple paths to same node", function()
  local shared = {tag = 5, size = 1, [1] = "shared"}
  local a = {tag = 1, size = 1, [1] = shared}
  local b = {tag = 2, size = 1, [1] = shared}
  local c = {tag = 3, size = 1, [1] = shared}
  local top = {tag = 0, size = 3, [1] = a, [2] = b, [3] = c}

  -- All three paths reach the same shared node, but no cycle
  local marshaled = caml_marshal_to_string(top)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 0)
  assert_eq(result[1][1][1], "shared")
  assert_eq(result[2][1][1], "shared")
  assert_eq(result[3][1][1], "shared")
end)

print()
print("Complex Cycle Patterns (Should Work with Object Sharing):")
print("--------------------------------------------------------------------")

test("complex: cycle in subtree", function()
  -- Main tree has a subtree with a cycle
  local good_leaf = {tag = 10, size = 1, [1] = 42}
  local cycle_a = {tag = 20, size = 1}
  local cycle_b = {tag = 21, size = 1}
  cycle_a[1] = cycle_b
  cycle_b[1] = cycle_a  -- Cycle in subtree

  local root = {tag = 0, size = 2, [1] = good_leaf, [2] = cycle_a}

  local marshaled = caml_marshal_to_string(root)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 0, "Root tag preserved")
  assert_eq(result[1][1], 42, "Acyclic leaf preserved")
  assert_eq(result[2].tag, 20, "Cycle root tag preserved")
  assert_true(result[2][1][1] == result[2], "Cycle in subtree preserved")
end)

test("complex: multiple cycles", function()
  -- Two separate cycles in one structure
  local a1 = {tag = 1, size = 1}
  local a2 = {tag = 2, size = 1}
  a1[1] = a2
  a2[1] = a1  -- First cycle

  local b1 = {tag = 10, size = 1}
  local b2 = {tag = 11, size = 1}
  b1[1] = b2
  b2[1] = b1  -- Second cycle

  local root = {tag = 0, size = 2, [1] = a1, [2] = b1}

  local marshaled = caml_marshal_to_string(root)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 0, "Root tag preserved")
  assert_true(result[1][1][1] == result[1], "First cycle preserved")
  assert_true(result[2][1][1] == result[2], "Second cycle preserved")
end)

print()
print("Edge Cases:")
print("--------------------------------------------------------------------")

test("edge: empty table self-reference", function()
  local x = {size = 1}
  x[1] = x
  local marshaled = caml_marshal_to_string(x)
  local result = caml_marshal_from_bytes(marshaled)
  assert_true(result[1] == result, "Empty table self-reference preserved")
end)

test("edge: cycle through array (no tag)", function()
  local arr1 = {size = 4, [1] = 1, [2] = 2, [3] = 3}
  local arr2 = {size = 3, [1] = 4, [2] = 5}
  arr2[3] = arr1
  arr1[4] = arr2  -- arr1 → arr2 → arr1
  local marshaled = caml_marshal_to_string(arr1)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result[1], 1, "First element preserved")
  assert_true(result[4][3] == result, "Cycle through arrays preserved")
end)

test("edge: cycle through float array", function()
  -- Float arrays are all numbers, but we can create structure around them
  local float_arr = {size = 3, [1] = 1.0, [2] = 2.0, [3] = 3.0}
  local wrapper = {tag = 0, size = 1, [1] = float_arr}
  -- Can't create cycle through float array itself (all elements must be numbers)
  -- This test ensures we handle it correctly
  local marshaled = caml_marshal_to_string(wrapper)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 0)
  assert_eq(result[1].size, 3)
end)

test("edge: very large acyclic structure", function()
  -- Large tree without cycles should work (not stack overflow)
  local value = {tag = 100, size = 1, [1] = 42}
  for i = 99, 1, -1 do
    value = {tag = i, size = 1, [1] = value}
  end
  -- 100 levels deep, no cycle
  local marshaled = caml_marshal_to_string(value)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 1)
end)

print()
print("Cycle Support Verification:")
print("--------------------------------------------------------------------")

test("verify: cycles work via object sharing", function()
  local x = {tag = 0, size = 1}
  x[1] = x
  local marshaled = caml_marshal_to_string(x)
  local result = caml_marshal_from_bytes(marshaled)
  assert_true(result[1] == result, "Self-reference preserved via object sharing")
end)

test("verify: no false positives on similar values", function()
  -- Two separate tables with same contents (not same reference)
  local a = {tag = 1, size = 1, [1] = 42}
  local b = {tag = 1, size = 1, [1] = 42}
  local container = {tag = 0, size = 2, [1] = a, [2] = b}
  -- Should work fine (different tables, even if same structure)
  local marshaled = caml_marshal_to_string(container)
  local result = caml_marshal_from_bytes(marshaled)
  assert_eq(result.tag, 0)
  assert_eq(result[1][1], 42)
  assert_eq(result[2][1], 42)
  -- Note: a and b are different tables in input, so result[1] and result[2] are also different
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
