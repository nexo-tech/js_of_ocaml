#!/usr/bin/env lua
-- Comprehensive unit tests for Marshal module (Task 7.1)
--
-- Tests all value types, immediate values, structured values, sharing, cycles, custom blocks, and edge cases

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
  local marshalled = marshal.to_string(value, flags)
  return marshal.from_bytes(marshalled, 0)
end

-- Helper: compare tables
local function table_eq(t1, t2)
  if type(t1) ~= "table" or type(t2) ~= "table" then
    return t1 == t2
  end

  -- Check tag
  if t1.tag ~= t2.tag then return false end

  -- Check size
  if t1.size ~= t2.size then return false end

  -- Check fields
  for k, v in pairs(t1) do
    if k ~= "tag" and k ~= "size" then
      if not table_eq(v, t2[k]) then
        return false
      end
    end
  end

  return true
end

print("========================================")
print("Marshal Unit Tests (Comprehensive)")
print("========================================")
print("")

-- ========================================
-- Immediate Values: Integers
-- ========================================

print("Immediate Values: Integers")
print("----------------------------------------")

-- Test 1-5: Small integers (0-63)
test("Small int: 0", roundtrip(0) == 0)
test("Small int: 1", roundtrip(1) == 1)
test("Small int: 42", roundtrip(42) == 42)
test("Small int: 63", roundtrip(63) == 63)

-- Test 6-8: INT8 range
test("INT8: -128", roundtrip(-128) == -128)
test("INT8: 127", roundtrip(127) == 127)
test("INT8: 64", roundtrip(64) == 64)

-- Test 9-10: INT16 range
test("INT16: -32768", roundtrip(-32768) == -32768)
test("INT16: 32767", roundtrip(32767) == 32767)

-- Test 11-12: INT32 range
test("INT32: -2147483648", roundtrip(-2147483648) == -2147483648)
test("INT32: 2147483647", roundtrip(2147483647) == 2147483647)

print("")

-- ========================================
-- Immediate Values: Strings
-- ========================================

print("Immediate Values: Strings")
print("----------------------------------------")

-- Test 13-16: Small strings (0-31 bytes)
test("Small string: empty", roundtrip("") == "")
test("Small string: 1 char", roundtrip("a") == "a")
test("Small string: 10 chars", roundtrip("0123456789") == "0123456789")
test("Small string: 31 chars", roundtrip(string.rep("x", 31)) == string.rep("x", 31))

-- Test 17-19: STRING8 (32-255 bytes)
test("STRING8: 32 chars", roundtrip(string.rep("a", 32)) == string.rep("a", 32))
test("STRING8: 100 chars", roundtrip(string.rep("b", 100)) == string.rep("b", 100))
test("STRING8: 255 chars", roundtrip(string.rep("c", 255)) == string.rep("c", 255))

-- Test 20: STRING32 (>255 bytes)
test("STRING32: 1000 chars", roundtrip(string.rep("d", 1000)) == string.rep("d", 1000))

-- Test 21: Unicode/special chars
test("String: unicode/special", roundtrip("Hello, 世界! \n\t\r") == "Hello, 世界! \n\t\r")

print("")

-- ========================================
-- Immediate Values: Doubles
-- ========================================

print("Immediate Values: Doubles")
print("----------------------------------------")

-- Test 22-26: Basic doubles
test("Double: 0.0", roundtrip(0.0) == 0.0)
test("Double: 1.5", roundtrip(1.5) == 1.5)
test("Double: -3.14159", roundtrip(-3.14159) == -3.14159)
test("Double: 1e10", roundtrip(1e10) == 1e10)
test("Double: 1e-10", roundtrip(1e-10) == 1e-10)

-- Test 27-28: Special values
local inf_result = roundtrip(math.huge)
test("Double: infinity", inf_result == math.huge)

local ninf_result = roundtrip(-math.huge)
test("Double: -infinity", ninf_result == -math.huge)

-- NaN is tricky - NaN ~= NaN, so check it's NaN
local nan_result = roundtrip(0/0)
test("Double: NaN", nan_result ~= nan_result)  -- NaN property

print("")

-- ========================================
-- Structured Values: Small Blocks
-- ========================================

print("Structured Values: Small Blocks")
print("----------------------------------------")

-- Test 30: Empty block (tag=0 is the standard empty block)
test("Small block: tag=0 size=0", table_eq(roundtrip({tag = 0}), {tag = 0, size = 0}))

-- Test 31-33: Blocks with fields (size 1-7)
test("Small block: tag=0 size=1", table_eq(
  roundtrip({tag = 0, [1] = 42}),
  {tag = 0, size = 1, [1] = 42}
))

test("Small block: tag=1 size=2", table_eq(
  roundtrip({tag = 1, [1] = "a", [2] = "b"}),
  {tag = 1, size = 2, [1] = "a", [2] = "b"}
))

test("Small block: tag=3 size=7", table_eq(
  roundtrip({tag = 3, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [7] = 7}),
  {tag = 3, size = 7, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [7] = 7}
))

print("")

-- ========================================
-- Structured Values: BLOCK32
-- ========================================

print("Structured Values: BLOCK32")
print("----------------------------------------")

-- Test 34-36: Larger blocks (size > 7)
test("BLOCK32: size=8", table_eq(
  roundtrip({tag = 0, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [7] = 7, [8] = 8}),
  {tag = 0, size = 8, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [7] = 7, [8] = 8}
))

test("BLOCK32: size=100", (function()
  local block = {tag = 3}
  for i = 1, 100 do
    block[i] = i
  end
  local result = roundtrip(block)
  if result.tag ~= 3 or result.size ~= 100 then return false end
  for i = 1, 100 do
    if result[i] ~= i then return false end
  end
  return true
end)())

-- Test 41: High tag value
test("BLOCK32: tag=255", table_eq(
  roundtrip({tag = 255, [1] = "high tag"}),
  {tag = 255, size = 1, [1] = "high tag"}
))

print("")

-- ========================================
-- Structured Values: Nested Blocks
-- ========================================

print("Structured Values: Nested Blocks")
print("----------------------------------------")

-- Test 42: Two-level nesting
test("Nested: 2 levels", table_eq(
  roundtrip({tag = 0, [1] = {tag = 1, [1] = 42}}),
  {tag = 0, size = 1, [1] = {tag = 1, size = 1, [1] = 42}}
))

-- Test 43: Three-level nesting
test("Nested: 3 levels", table_eq(
  roundtrip({tag = 0, [1] = {tag = 1, [1] = {tag = 2, [1] = "deep"}}}),
  {tag = 0, size = 1, [1] = {tag = 1, size = 1, [1] = {tag = 2, size = 1, [1] = "deep"}}}
))

-- Test 44: Mixed types nested
test("Nested: mixed types", table_eq(
  roundtrip({tag = 0, [1] = 10, [2] = "str", [3] = {tag = 1, [1] = 3.14}}),
  {tag = 0, size = 3, [1] = 10, [2] = "str", [3] = {tag = 1, size = 1, [1] = 3.14}}
))

print("")

-- ========================================
-- Sharing (no_sharing = false)
-- ========================================

print("Value Sharing")
print("----------------------------------------")

-- Test 45: Shared string
local shared_str = {tag = 0, [1] = "shared", [2] = "shared"}
local result = roundtrip(shared_str)
test("Shared string: both fields present", result[1] == "shared" and result[2] == "shared")

-- Test 46: Shared block
local inner = {tag = 1, [1] = 99}
local shared_block = {tag = 0, [1] = inner, [2] = inner}
result = roundtrip(shared_block)
test("Shared block: structure preserved",
  result[1].tag == 1 and result[1][1] == 99 and
  result[2].tag == 1 and result[2][1] == 99)

print("")

-- ========================================
-- Cycles (with sharing)
-- ========================================

print("Cycles and Self-Reference")
print("----------------------------------------")

-- Test 47: Simple cycle
local cycle = {tag = 0, [1] = 10}
cycle[2] = cycle  -- Self-reference
result = roundtrip(cycle)
test("Simple cycle: self-reference",
  result.tag == 0 and result[1] == 10 and result[2] == result)

-- Test 48: Mutual reference
local node1 = {tag = 0, [1] = "A"}
local node2 = {tag = 0, [1] = "B"}
node1[2] = node2
node2[2] = node1
result = roundtrip(node1)
test("Mutual reference: A->B->A",
  result[1] == "A" and result[2][1] == "B" and result[2][2] == result)

print("")

-- ========================================
-- Custom Blocks
-- ========================================

print("Custom Blocks")
print("----------------------------------------")

-- Test 49: Int64 custom block
local int64 = {
  caml_custom = "_j",
  bytes = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2A}  -- 42 in big-endian
}
result = roundtrip(int64)
test("Custom: Int64",
  result.caml_custom == "_j" and
  result.bytes[8] == 0x2A)

-- Test 50: Int32 custom block
local int32 = {
  caml_custom = "_i",
  bytes = {0x00, 0x00, 0x00, 0x64}  -- 100 in big-endian
}
result = roundtrip(int32)
test("Custom: Int32",
  result.caml_custom == "_i" and
  result.bytes[4] == 0x64)

print("")

-- ========================================
-- Edge Cases
-- ========================================

print("Edge Cases")
print("----------------------------------------")

-- Test 51: Boundary: 63 vs 64 (small int vs INT8)
test("Boundary: 63 (small)", roundtrip(63) == 63)
test("Boundary: 64 (INT8)", roundtrip(64) == 64)

-- Test 53: Boundary: 31 vs 32 bytes (small string vs STRING8)
test("Boundary: 31 bytes (small)", roundtrip(string.rep("x", 31)) == string.rep("x", 31))
test("Boundary: 32 bytes (STRING8)", roundtrip(string.rep("x", 32)) == string.rep("x", 32))

-- Test 55: Boundary: 7 vs 8 fields (small block vs BLOCK32)
local block7 = {tag = 0, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [7] = 7}
local result7 = roundtrip(block7)
test("Boundary: 7 fields (small block)", result7.size == 7 and result7[7] == 7)

local block8 = {tag = 0, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6, [7] = 7, [8] = 8}
local result8 = roundtrip(block8)
test("Boundary: 8 fields (BLOCK32)", result8.size == 8 and result8[8] == 8)

-- Test 57: Empty string
test("Edge: empty string", roundtrip("") == "")

-- Test 58: Very long string
local long_str = string.rep("Long", 10000)
test("Edge: 40KB string", roundtrip(long_str) == long_str)

-- Test 59: Deeply nested structure
local deep = {tag = 0}
local current = deep
for i = 1, 50 do
  current[1] = {tag = 0}
  current = current[1]
end
current[1] = "bottom"
result = roundtrip(deep)
current = result
for i = 1, 50 do
  current = current[1]
end
test("Edge: 50-level nesting", current[1] == "bottom")

print("")

-- ========================================
-- Flags: No Sharing
-- ========================================

print("Flags: No Sharing")
print("----------------------------------------")

-- Test 60: No sharing flag with duplicates
local dup_str = {tag = 0, [1] = "dup", [2] = "dup"}
result = roundtrip(dup_str, {tag = 0, [1] = 0})  -- No_sharing flag
test("No sharing: strings duplicated", result[1] == "dup" and result[2] == "dup")

-- Test 61: No sharing with blocks
local dup_block = {tag = 0, [1] = {tag = 1, [1] = 5}, [2] = {tag = 1, [1] = 5}}
result = roundtrip(dup_block, {tag = 0, [1] = 0})
test("No sharing: blocks duplicated",
  result[1].tag == 1 and result[1][1] == 5 and
  result[2].tag == 1 and result[2][1] == 5)

print("")

-- ========================================
-- All Value Type Coverage
-- ========================================

print("Complete Type Coverage")
print("----------------------------------------")

-- Test 62: Mix of all types in one structure
local all_types = {
  tag = 0,
  [1] = 0,                    -- Small int
  [2] = 100,                  -- INT8
  [3] = 50000,                -- INT16
  [4] = "small",              -- Small string
  [5] = string.rep("a", 100), -- STRING8
  [6] = 3.14,                 -- Double
  [7] = {tag = 1, [1] = "nested"},  -- Block
  [8] = {caml_custom = "_i", bytes = {0, 0, 0, 1}}  -- Custom
}

result = roundtrip(all_types)
test("All types: comprehensive",
  result[1] == 0 and
  result[2] == 100 and
  result[3] == 50000 and
  result[4] == "small" and
  result[5] == string.rep("a", 100) and
  result[6] == 3.14 and
  result[7].tag == 1 and
  result[8].caml_custom == "_i")

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
