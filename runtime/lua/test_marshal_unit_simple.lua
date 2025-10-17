#!/usr/bin/env lua
-- Unit value marshaling optimization tests (Task 9.5)
--
-- Tests that unit type () - represented as 0 in OCaml - is marshaled efficiently

dofile("marshal_io.lua")
dofile("marshal_header.lua")
dofile("marshal.lua")

local test_count = 0
local pass_count = 0

-- Helper: test function
local function test(name, fn)
  test_count = test_count + 1
  local success, err = pcall(fn)
  if success then
    pass_count = pass_count + 1
    print(string.format("✓ Test %d: %s", test_count, name))
  else
    print(string.format("✗ Test %d: %s", test_count, name))
    print(string.format("  Error: %s", tostring(err)))
  end
end

print("========================================")
print("Unit Value Marshaling Optimization Tests")
print("========================================")
print("")

-- ========================================
-- Unit Value Size Optimization
-- ========================================

print("Unit Value Size Optimization")
print("----------------------------------------")

test("Unit (0) marshals to single byte", function()
  -- Unit value in OCaml is represented as integer 0
  local marshaled = marshal_value_internal(0)
  -- Should be single byte: 0x40 (small int code for 0)
  assert(#marshaled == 1, "Unit should be 1 byte, got " .. #marshaled)
  assert(string.byte(marshaled, 1) == 0x40, "Unit should be 0x40")
end)

test("Unit roundtrip preserves value", function()
  local marshaled = marshal_value_internal(0)
  local unmarshaled = unmarshal_value_internal(marshaled)
  assert(unmarshaled == 0, "Unit roundtrip should preserve 0")
end)

test("Unit with header is minimal", function()
  local marshaled = caml_marshal_to_string(0, {tag = 0})
  -- Header: 20 bytes + data: 1 byte = 21 bytes total
  assert(#marshaled == 21, "Unit with header should be 21 bytes, got " .. #marshaled)
end)

print("")

-- ========================================
-- Fast Path Verification
-- ========================================

print("Fast Path Verification")
print("----------------------------------------")

test("Unit uses small int code", function()
  local marshaled = marshal_value_internal(0)
  local code = string.byte(marshaled, 1)
  -- Small int range is 0x40-0x7F (values 0-63)
  assert(code >= 0x40 and code <= 0x7F, "Should use small int code")
  assert(code == 0x40, "Unit specifically should be 0x40")
end)

test("Unit does not use CODE_INT8", function()
  local marshaled = marshal_value_internal(0)
  local code = string.byte(marshaled, 1)
  -- CODE_INT8 is 0x00
  assert(code ~= 0x00, "Unit should not use CODE_INT8")
end)

test("Unit does not use CODE_INT16", function()
  local marshaled = marshal_value_internal(0)
  local code = string.byte(marshaled, 1)
  -- CODE_INT16 is 0x01
  assert(code ~= 0x01, "Unit should not use CODE_INT16")
end)

test("Unit does not use CODE_INT32", function()
  local marshaled = marshal_value_internal(0)
  local code = string.byte(marshaled, 1)
  -- CODE_INT32 is 0x02
  assert(code ~= 0x02, "Unit should not use CODE_INT32")
end)

print("")

-- ========================================
-- Performance Comparison
-- ========================================

print("Performance Comparison")
print("----------------------------------------")

test("Unit is smallest integer representation", function()
  -- Compare sizes of different integers
  local unit_size = #marshal_value_internal(0)
  local int1_size = #marshal_value_internal(1)
  local int63_size = #marshal_value_internal(63)
  local int64_size = #marshal_value_internal(64)  -- Uses INT8
  local int128_size = #marshal_value_internal(128)  -- Uses INT8 or INT16

  -- Unit should be same as other small ints (0-63)
  assert(unit_size == 1, "Unit should be 1 byte")
  assert(int1_size == 1, "Small int 1 should be 1 byte")
  assert(int63_size == 1, "Small int 63 should be 1 byte")

  -- Larger ints should be bigger
  assert(int64_size > 1, "INT8 should be > 1 byte")
  assert(int128_size > 1, "Larger int should be > 1 byte")
end)

test("Unit marshaling is optimal", function()
  -- Unit (0) should be the smallest possible representation
  local marshaled = marshal_value_internal(0)
  assert(#marshaled == 1, "Cannot be more optimal than 1 byte")
end)

print("")

-- ========================================
-- Edge Cases
-- ========================================

print("Edge Cases")
print("----------------------------------------")

test("Multiple units marshal independently", function()
  local container = {tag = 0, size = 3, [1] = 0, [2] = 0, [3] = 0}
  local marshaled = caml_marshal_to_string(container, {tag = 0})
  local unmarshaled = caml_marshal_from_bytes(marshaled, 0)
  assert(unmarshaled[1] == 0, "First unit preserved")
  assert(unmarshaled[2] == 0, "Second unit preserved")
  assert(unmarshaled[3] == 0, "Third unit preserved")
end)

test("Unit in nested structure", function()
  local nested = {tag = 0, size = 1, [1] = {tag = 0, size = 1, [1] = 0}}
  local marshaled = caml_marshal_to_string(nested, {tag = 0})
  local unmarshaled = caml_marshal_from_bytes(marshaled, 0)
  assert(unmarshaled[1][1] == 0, "Nested unit preserved")
end)

test("Unit vs None (0 constant)", function()
  -- In OCaml: () = 0, None = 0
  -- Both should marshal the same way
  local unit_marshaled = marshal_value_internal(0)
  local none_marshaled = marshal_value_internal(0)
  assert(unit_marshaled == none_marshaled, "Unit and None marshal identically")
end)

print("")

-- ========================================
-- Summary
-- ========================================

print("========================================")
print(string.format("Tests completed: %d/%d passed", pass_count, test_count))
print("========================================")

if pass_count == test_count then
  print("✓ All unit value optimization tests passed!")
  print("")
  print("Unit value optimization verified:")
  print("  • Unit (0) marshals to single byte (0x40)")
  print("  • Minimal representation achieved")
  print("  • Fast path uses small int code")
  print("  • No larger encoding used")
  print("  • Optimal for common OCaml pattern")
  os.exit(0)
else
  print(string.format("✗ %d tests failed", test_count - pass_count))
  os.exit(1)
end
