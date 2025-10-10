#!/usr/bin/env lua
-- Roundtrip tests for Marshal module (Task 7.2)
--
-- Tests marshal → unmarshal roundtrips for realistic OCaml data structures:
-- - Lists
-- - Trees
-- - Graphs with cycles
-- - Records
-- - Variants
-- - Custom types
-- - Large data

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

-- Helper: roundtrip marshal/unmarshal
local function roundtrip(value, flags)
  flags = flags or {tag = 0}
  local marshalled = caml_marshal_to_string(value, flags)
  return caml_marshal_from_bytes(marshalled, 0)
end

-- Helper: deep equality for complex structures
local function deep_eq(v1, v2, seen)
  seen = seen or {}

  -- Handle same reference
  if v1 == v2 then return true end

  -- Handle different types
  if type(v1) ~= type(v2) then return false end

  -- Handle non-tables
  if type(v1) ~= "table" then
    -- Special case for NaN
    if type(v1) == "number" and v1 ~= v1 and v2 ~= v2 then
      return true  -- Both are NaN
    end
    return v1 == v2
  end

  -- Handle cycles - mark as seen
  if seen[v1] then
    return seen[v1] == v2
  end
  seen[v1] = v2

  -- Check tag
  if v1.tag ~= v2.tag then return false end

  -- Check size
  if v1.size ~= v2.size then return false end

  -- Check caml_custom
  if v1.caml_custom ~= v2.caml_custom then return false end

  -- Check bytes array for custom blocks
  if v1.bytes and v2.bytes then
    if #v1.bytes ~= #v2.bytes then return false end
    for i = 1, #v1.bytes do
      if v1.bytes[i] ~= v2.bytes[i] then return false end
    end
  end

  -- Check all fields
  for k, val1 in pairs(v1) do
    if k ~= "tag" and k ~= "size" then
      local val2 = v2[k]
      if not deep_eq(val1, val2, seen) then
        return false
      end
    end
  end

  -- Check v2 doesn't have extra fields
  for k in pairs(v2) do
    if k ~= "tag" and k ~= "size" and v1[k] == nil then
      return false
    end
  end

  return true
end

print("========================================")
print("Marshal Roundtrip Tests")
print("========================================")
print("")

-- ========================================
-- Lists
-- ========================================

print("Lists")
print("----------------------------------------")

-- Test 1: Empty list
local empty_list = 0  -- []
test("Empty list", deep_eq(roundtrip(empty_list), 0))

-- Test 2: Single element list
local single_list = {tag = 0, [1] = 42, [2] = 0}  -- [42]
local result = roundtrip(single_list)
test("Single element list",
  result.tag == 0 and result[1] == 42 and result[2] == 0)

-- Test 3: Multiple element list
local multi_list = {tag = 0, [1] = 1, [2] = {tag = 0, [1] = 2, [2] = {tag = 0, [1] = 3, [2] = 0}}}  -- [1; 2; 3]
result = roundtrip(multi_list)
test("Three element list",
  result.tag == 0 and result[1] == 1 and
  result[2].tag == 0 and result[2][1] == 2 and
  result[2][2].tag == 0 and result[2][2][1] == 3 and
  result[2][2][2] == 0)

-- Test 4: List of strings
local str_list = {tag = 0, [1] = "hello", [2] = {tag = 0, [1] = "world", [2] = 0}}  -- ["hello"; "world"]
result = roundtrip(str_list)
test("List of strings",
  result[1] == "hello" and result[2][1] == "world" and result[2][2] == 0)

-- Test 5: Long list
local long_list = 0
for i = 100, 1, -1 do
  long_list = {tag = 0, [1] = i, [2] = long_list}
end
result = roundtrip(long_list)
test("100 element list", (function()
  local count = 0
  local curr = result
  while curr ~= 0 do
    count = count + 1
    if curr[1] ~= count then return false end
    curr = curr[2]
  end
  return count == 100
end)())

print("")

-- ========================================
-- Trees
-- ========================================

print("Trees")
print("----------------------------------------")

-- Test 6: Leaf node (variant with tag)
local leaf = {tag = 0}  -- Leaf
test("Tree: Leaf node", deep_eq(roundtrip(leaf), {tag = 0, size = 0}))

-- Test 7: Single node tree
local node = {tag = 1, [1] = 42, [2] = {tag = 0}, [3] = {tag = 0}}  -- Node(42, Leaf, Leaf)
result = roundtrip(node)
test("Tree: Single node",
  result.tag == 1 and result[1] == 42 and
  result[2].tag == 0 and result[3].tag == 0)

-- Test 8: Balanced binary tree
local tree = {
  tag = 1,
  [1] = 5,
  [2] = {tag = 1, [1] = 3, [2] = {tag = 0}, [3] = {tag = 0}},
  [3] = {tag = 1, [1] = 7, [2] = {tag = 0}, [3] = {tag = 0}}
}
result = roundtrip(tree)
test("Tree: Balanced binary tree",
  result.tag == 1 and result[1] == 5 and
  result[2].tag == 1 and result[2][1] == 3 and
  result[3].tag == 1 and result[3][1] == 7)

-- Test 9: Deep tree (left-skewed)
local deep_tree = {tag = 0}
for i = 10, 1, -1 do
  deep_tree = {tag = 1, [1] = i, [2] = deep_tree, [3] = {tag = 0}}
end
result = roundtrip(deep_tree)
test("Tree: 10-level deep", (function()
  local curr = result
  for i = 1, 10 do
    if curr.tag ~= 1 or curr[1] ~= i then return false end
    curr = curr[2]
  end
  return curr.tag == 0
end)())

print("")

-- ========================================
-- Graphs with Cycles
-- ========================================

print("Graphs with Cycles")
print("----------------------------------------")

-- Test 10: Self-referencing node
local self_ref = {tag = 0, [1] = "self"}
self_ref[2] = self_ref
result = roundtrip(self_ref)
test("Graph: Self-reference",
  result[1] == "self" and result[2] == result)

-- Test 11: Two-node cycle
local node_a = {tag = 0, [1] = "A"}
local node_b = {tag = 0, [1] = "B"}
node_a[2] = node_b
node_b[2] = node_a
result = roundtrip(node_a)
test("Graph: Two-node cycle",
  result[1] == "A" and result[2][1] == "B" and result[2][2] == result)

-- Test 12: Three-node cycle
local n1 = {tag = 0, [1] = 1}
local n2 = {tag = 0, [1] = 2}
local n3 = {tag = 0, [1] = 3}
n1[2] = n2
n2[2] = n3
n3[2] = n1
result = roundtrip(n1)
test("Graph: Three-node cycle",
  result[1] == 1 and
  result[2][1] == 2 and
  result[2][2][1] == 3 and
  result[2][2][2] == result)

-- Test 13: DAG with shared nodes
local shared = {tag = 1, [1] = "shared"}
local dag = {
  tag = 0,
  [1] = {tag = 2, [1] = "left", [2] = shared},
  [2] = {tag = 2, [1] = "right", [2] = shared}
}
result = roundtrip(dag)
test("Graph: DAG with sharing",
  result[1][2][1] == "shared" and
  result[2][2][1] == "shared" and
  result[1][2] == result[2][2])  -- Same object reference

print("")

-- ========================================
-- Records
-- ========================================

print("Records")
print("----------------------------------------")

-- Test 14: Simple record (person)
local person = {tag = 0, [1] = "Alice", [2] = 30, [3] = "alice@example.com"}
result = roundtrip(person)
test("Record: Person {name; age; email}",
  result[1] == "Alice" and result[2] == 30 and result[3] == "alice@example.com")

-- Test 15: Nested record
local address = {tag = 0, [1] = "123 Main St", [2] = "Springfield", [3] = "12345"}
local person_with_addr = {tag = 0, [1] = "Bob", [2] = 25, [3] = address}
result = roundtrip(person_with_addr)
test("Record: Nested records",
  result[1] == "Bob" and result[3][1] == "123 Main St" and result[3][2] == "Springfield")

-- Test 16: Record with optional fields
local user = {
  tag = 0,
  [1] = "charlie",
  [2] = {tag = 0, [1] = "charlie@example.com"},  -- Some(email)
  [3] = 0  -- None (no phone)
}
result = roundtrip(user)
test("Record: With optional fields",
  result[1] == "charlie" and
  result[2].tag == 0 and result[2][1] == "charlie@example.com" and
  result[3] == 0)

-- Test 17: Large record (many fields)
local large_record = {tag = 0}
for i = 1, 50 do
  large_record[i] = i * 10
end
result = roundtrip(large_record)
test("Record: 50 fields", (function()
  if result.tag ~= 0 or result.size ~= 50 then return false end
  for i = 1, 50 do
    if result[i] ~= i * 10 then return false end
  end
  return true
end)())

print("")

-- ========================================
-- Variants
-- ========================================

print("Variants")
print("----------------------------------------")

-- Test 18: Simple variant - None
local none = 0
test("Variant: None", roundtrip(none) == 0)

-- Test 19: Simple variant - Some
local some = {tag = 0, [1] = 42}
result = roundtrip(some)
test("Variant: Some(42)", result.tag == 0 and result[1] == 42)

-- Test 20: Result - Ok
local ok = {tag = 0, [1] = "success"}
result = roundtrip(ok)
test("Variant: Ok(\"success\")", result.tag == 0 and result[1] == "success")

-- Test 21: Result - Error
local err = {tag = 1, [1] = "failure"}
result = roundtrip(err)
test("Variant: Error(\"failure\")", result.tag == 1 and result[1] == "failure")

-- Test 22: Complex variant with multiple constructors
-- type shape = Circle of float | Rectangle of float * float | Triangle of float * float * float
local circle = {tag = 0, [1] = 5.5}
local rectangle = {tag = 1, [1] = 10.0, [2] = 20.0}
local triangle = {tag = 2, [1] = 3.0, [2] = 4.0, [3] = 5.0}

local circle_r = roundtrip(circle)
local rectangle_r = roundtrip(rectangle)
local triangle_r = roundtrip(triangle)

test("Variant: Circle(5.5)",
  circle_r.tag == 0 and circle_r[1] == 5.5)
test("Variant: Rectangle(10.0, 20.0)",
  rectangle_r.tag == 1 and rectangle_r[1] == 10.0 and rectangle_r[2] == 20.0)
test("Variant: Triangle(3.0, 4.0, 5.0)",
  triangle_r.tag == 2 and triangle_r[1] == 3.0 and triangle_r[2] == 4.0 and triangle_r[3] == 5.0)

-- Test 25: Variant with nested data
local nested_variant = {tag = 1, [1] = {tag = 0, [1] = "nested", [2] = 0}}  -- Some(list)
result = roundtrip(nested_variant)
test("Variant: Nested variant with list",
  result.tag == 1 and result[1].tag == 0 and result[1][1] == "nested")

print("")

-- ========================================
-- Custom Types
-- ========================================

print("Custom Types")
print("----------------------------------------")

-- Test 26: Int64 custom block
local int64 = {
  caml_custom = "_j",
  bytes = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0xE8}  -- 1000
}
result = roundtrip(int64)
test("Custom: Int64(1000)",
  result.caml_custom == "_j" and deep_eq(result.bytes, int64.bytes))

-- Test 27: Int32 custom block
local int32 = {
  caml_custom = "_i",
  bytes = {0x00, 0x00, 0x27, 0x10}  -- 10000
}
result = roundtrip(int32)
test("Custom: Int32(10000)",
  result.caml_custom == "_i" and deep_eq(result.bytes, int32.bytes))

-- Test 28: Record containing custom types
local record_with_custom = {
  tag = 0,
  [1] = "data",
  [2] = {caml_custom = "_j", bytes = {0, 0, 0, 0, 0, 0, 0, 42}},
  [3] = {caml_custom = "_i", bytes = {0, 0, 0, 100}}
}
result = roundtrip(record_with_custom)
test("Custom: Record with Int64 and Int32",
  result[1] == "data" and
  result[2].caml_custom == "_j" and result[2].bytes[8] == 42 and
  result[3].caml_custom == "_i" and result[3].bytes[4] == 100)

-- Test 29: List of custom types
local custom_list = {
  tag = 0,
  [1] = {caml_custom = "_j", bytes = {0, 0, 0, 0, 0, 0, 0, 1}},
  [2] = {
    tag = 0,
    [1] = {caml_custom = "_j", bytes = {0, 0, 0, 0, 0, 0, 0, 2}},
    [2] = 0
  }
}
result = roundtrip(custom_list)
test("Custom: List of Int64",
  result[1].caml_custom == "_j" and result[1].bytes[8] == 1 and
  result[2][1].caml_custom == "_j" and result[2][1].bytes[8] == 2)

print("")

-- ========================================
-- Large Data
-- ========================================

print("Large Data")
print("----------------------------------------")

-- Test 30: Large string (1MB)
local large_string = string.rep("Lorem ipsum dolor sit amet, ", 37000)  -- ~1MB
result = roundtrip(large_string)
test("Large: 1MB string", result == large_string and #result > 1000000)

-- Test 31: Large array
local large_array = {tag = 0}
for i = 1, 1000 do
  large_array[i] = i
end
result = roundtrip(large_array)
test("Large: 1000 element array", (function()
  if result.size ~= 1000 then return false end
  for i = 1, 1000 do
    if result[i] ~= i then return false end
  end
  return true
end)())

-- Test 32: Large list
local large_list = 0
for i = 1000, 1, -1 do
  large_list = {tag = 0, [1] = i, [2] = large_list}
end
result = roundtrip(large_list)
test("Large: 1000 element list", (function()
  local count = 0
  local curr = result
  while curr ~= 0 do
    count = count + 1
    if curr[1] ~= count then return false end
    curr = curr[2]
  end
  return count == 1000
end)())

-- Test 33: Deep nesting
local deep = {tag = 0, [1] = "value"}
for i = 1, 100 do
  deep = {tag = 0, [1] = deep}
end
result = roundtrip(deep)
test("Large: 100-level nesting", (function()
  local curr = result
  for i = 1, 100 do
    if curr.tag ~= 0 then return false end
    curr = curr[1]
  end
  return curr[1] == "value"
end)())

-- Test 34: Complex nested structure
local complex = {
  tag = 0,
  [1] = {tag = 0, [1] = "users", [2] = 0},  -- List of users (empty here)
  [2] = {tag = 0, [1] = 1000, [2] = 2000, [3] = 3000},  -- Stats record
  [3] = {tag = 1, [1] = "active"},  -- Status variant
  [4] = {caml_custom = "_j", bytes = {0, 0, 0, 0, 0, 0, 0xFF, 0xFF}},  -- Timestamp
  [5] = string.rep("data", 1000)  -- Large metadata
}
result = roundtrip(complex)
test("Large: Complex nested structure",
  result[1].tag == 0 and result[1][2] == 0 and
  result[2][1] == 1000 and result[2][2] == 2000 and
  result[3].tag == 1 and result[3][1] == "active" and
  result[4].caml_custom == "_j" and
  #result[5] == 4000)

-- Test 35: Wide graph with sharing
local shared_node = {tag = 0, [1] = "shared_data"}
local wide_graph = {tag = 0}
for i = 1, 50 do
  wide_graph[i] = shared_node
end
result = roundtrip(wide_graph)
test("Large: Wide graph with 50 references to same node", (function()
  if result.size ~= 50 then return false end
  -- All should reference the same object
  for i = 2, 50 do
    if result[i] ~= result[1] then return false end
  end
  return result[1][1] == "shared_data"
end)())

print("")

-- ========================================
-- Summary
-- ========================================

print("========================================")
print(string.format("Tests completed: %d/%d passed", pass_count, test_count))
print("========================================")

if pass_count == test_count then
  print("✓ All roundtrip tests passed!")
  os.exit(0)
else
  print(string.format("✗ %d tests failed", test_count - pass_count))
  os.exit(1)
end
