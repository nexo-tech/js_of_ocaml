#!/usr/bin/env lua
-- Test suite for compare.lua comparison primitives

-- Load compare.lua directly (it defines global caml_* functions)
dofile("compare.lua")

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

local function assert_error(fn, expected_msg)
  local success, err = pcall(fn)
  if success then
    error("Expected error but function succeeded")
  end
  if expected_msg and not string.find(tostring(err), expected_msg, 1, true) then
    error("Expected error containing '" .. expected_msg .. "', got: " .. tostring(err))
  end
end

print("====================================================================")
print("Compare Module Tests")
print("====================================================================")
print()

print("Integer Comparison Tests:")
print("--------------------------------------------------------------------")

test("int_compare: equal integers", function()
  assert_eq(caml_int_compare(5, 5), 0)
end)

test("int_compare: less than", function()
  assert_eq(caml_int_compare(3, 7), -1)
end)

test("int_compare: greater than", function()
  assert_eq(caml_int_compare(10, 5), 1)
end)

test("int_compare: negative numbers", function()
  assert_eq(caml_int_compare(-5, -3), -1)
  assert_eq(caml_int_compare(-3, -5), 1)
end)

print()
print("Number Comparison Tests:")
print("--------------------------------------------------------------------")

test("compare: equal numbers", function()
  assert_eq(caml_compare(42, 42), 0)
end)

test("compare: less than numbers", function()
  assert_eq(caml_compare(10, 20), -1)
end)

test("compare: greater than numbers", function()
  assert_eq(caml_compare(30, 15), 1)
end)

test("compare: float numbers", function()
  assert_eq(caml_compare(3.14, 3.14), 0)
  assert_eq(caml_compare(1.5, 2.5), -1)
  assert_eq(caml_compare(5.5, 4.5), 1)
end)

test("compare: zero and negative zero", function()
  assert_eq(caml_compare(0, -0), 0)
end)

test("compare: infinity", function()
  local inf = math.huge
  assert_eq(caml_compare(inf, inf), 0)
  assert_eq(caml_compare(1, inf), -1)
  assert_eq(caml_compare(inf, 1), 1)
end)

test("compare: negative infinity", function()
  local ninf = -math.huge
  assert_eq(caml_compare(ninf, ninf), 0)
  assert_eq(caml_compare(ninf, 0), -1)
  assert_eq(caml_compare(0, ninf), 1)
end)

test("compare: NaN", function()
  local nan = 0/0
  -- NaN compares equal to itself in total order
  assert_eq(caml_compare(nan, nan), 0)
end)

print()
print("String Comparison Tests:")
print("--------------------------------------------------------------------")

test("compare: equal strings", function()
  assert_eq(caml_compare("hello", "hello"), 0)
end)

test("compare: lexicographic order", function()
  assert_eq(caml_compare("abc", "xyz"), -1)
  assert_eq(caml_compare("xyz", "abc"), 1)
end)

test("compare: string prefix", function()
  assert_eq(caml_compare("hello", "hello world"), -1)
  assert_eq(caml_compare("hello world", "hello"), 1)
end)

test("compare: empty strings", function()
  assert_eq(caml_compare("", ""), 0)
  assert_eq(caml_compare("", "a"), -1)
  assert_eq(caml_compare("a", ""), 1)
end)

print()
print("OCaml String (Byte Array) Tests:")
print("--------------------------------------------------------------------")

test("compare: equal byte arrays", function()
  local s1 = {72, 101, 108, 108, 111}  -- "Hello"
  local s2 = {72, 101, 108, 108, 111}
  assert_eq(caml_compare(s1, s2), 0)
end)

test("compare: different byte arrays", function()
  local s1 = {65, 66, 67}  -- "ABC"
  local s2 = {88, 89, 90}  -- "XYZ"
  assert_eq(caml_compare(s1, s2), -1)
  assert_eq(caml_compare(s2, s1), 1)
end)

test("compare: byte array prefix", function()
  local s1 = {72, 105}        -- "Hi"
  local s2 = {72, 105, 33}    -- "Hi!"
  assert_eq(caml_compare(s1, s2), -1)
  assert_eq(caml_compare(s2, s1), 1)
end)

test("compare: empty byte array", function()
  local s1 = {}
  local s2 = {65}
  assert_eq(caml_compare(s1, s2), -1)
  assert_eq(caml_compare(s2, s1), 1)
end)

print()
print("Boolean Comparison Tests:")
print("--------------------------------------------------------------------")

test("compare: equal booleans", function()
  assert_eq(caml_compare(true, true), 0)
  assert_eq(caml_compare(false, false), 0)
end)

test("compare: false < true", function()
  assert_eq(caml_compare(false, true), -1)
  assert_eq(caml_compare(true, false), 1)
end)

print()
print("Mixed Type Comparison Tests:")
print("--------------------------------------------------------------------")

test("compare: different types by tag order", function()
  -- Numbers (tag 1000) vs strings (tag 12520)
  local result = caml_compare(42, "hello")
  assert_eq(result, -1)  -- Number tag < string tag
end)

test("compare: string vs byte array", function()
  local str = "hello"
  local bytes = {104, 101, 108, 108, 111}
  -- String tag (12520) > byte array tag (252)
  local result = caml_compare(str, bytes)
  assert_eq(result, 1)
end)

print()
print("OCaml Block Comparison Tests:")
print("--------------------------------------------------------------------")

test("compare: equal blocks with same tag", function()
  local b1 = {tag = 0, 1, 2, 3}
  local b2 = {tag = 0, 1, 2, 3}
  assert_eq(caml_compare(b1, b2), 0)
end)

test("compare: blocks different sizes", function()
  local b1 = {tag = 0, 1, 2}
  local b2 = {tag = 0, 1, 2, 3}
  assert_eq(caml_compare(b1, b2), -1)
  assert_eq(caml_compare(b2, b1), 1)
end)

test("compare: blocks different fields", function()
  local b1 = {tag = 0, 1, 2, 3}
  local b2 = {tag = 0, 1, 5, 3}
  assert_eq(caml_compare(b1, b2), -1)
  assert_eq(caml_compare(b2, b1), 1)
end)

test("compare: nested blocks", function()
  local b1 = {tag = 0, {tag = 0, 1, 2}, 3}
  local b2 = {tag = 0, {tag = 0, 1, 2}, 3}
  assert_eq(caml_compare(b1, b2), 0)
end)

test("compare: nested blocks different", function()
  local b1 = {tag = 0, {tag = 0, 1, 2}, 3}
  local b2 = {tag = 0, {tag = 0, 1, 5}, 3}
  assert_eq(caml_compare(b1, b2), -1)
end)

test("compare: deeply nested blocks", function()
  local b1 = {tag = 0, {tag = 0, {tag = 0, 1}}}
  local b2 = {tag = 0, {tag = 0, {tag = 0, 1}}}
  assert_eq(caml_compare(b1, b2), 0)
end)

print()
print("Equality Tests:")
print("--------------------------------------------------------------------")

test("equal: equal integers", function()
  assert_eq(caml_equal(42, 42), 1)
end)

test("equal: different integers", function()
  assert_eq(caml_equal(42, 43), 0)
end)

test("equal: equal strings", function()
  assert_eq(caml_equal("hello", "hello"), 1)
end)

test("equal: different strings", function()
  assert_eq(caml_equal("hello", "world"), 0)
end)

test("equal: equal blocks", function()
  local b1 = {tag = 0, 1, 2, 3}
  local b2 = {tag = 0, 1, 2, 3}
  assert_eq(caml_equal(b1, b2), 1)
end)

test("equal: different blocks", function()
  local b1 = {tag = 0, 1, 2, 3}
  local b2 = {tag = 0, 1, 2, 4}
  assert_eq(caml_equal(b1, b2), 0)
end)

print()
print("Not Equal Tests:")
print("--------------------------------------------------------------------")

test("notequal: equal values", function()
  assert_eq(caml_notequal(42, 42), 0)
end)

test("notequal: different values", function()
  assert_eq(caml_notequal(42, 43), 1)
end)

test("notequal: equal strings", function()
  assert_eq(caml_notequal("hello", "hello"), 0)
end)

test("notequal: different strings", function()
  assert_eq(caml_notequal("hello", "world"), 1)
end)

print()
print("Less Than Tests:")
print("--------------------------------------------------------------------")

test("lessthan: less", function()
  assert_eq(caml_lessthan(5, 10), 1)
end)

test("lessthan: greater", function()
  assert_eq(caml_lessthan(10, 5), 0)
end)

test("lessthan: equal", function()
  assert_eq(caml_lessthan(7, 7), 0)
end)

test("lessthan: strings", function()
  assert_eq(caml_lessthan("abc", "xyz"), 1)
  assert_eq(caml_lessthan("xyz", "abc"), 0)
end)

print()
print("Less Than or Equal Tests:")
print("--------------------------------------------------------------------")

test("lessequal: less", function()
  assert_eq(caml_lessequal(5, 10), 1)
end)

test("lessequal: equal", function()
  assert_eq(caml_lessequal(7, 7), 1)
end)

test("lessequal: greater", function()
  assert_eq(caml_lessequal(10, 5), 0)
end)

print()
print("Greater Than Tests:")
print("--------------------------------------------------------------------")

test("greaterthan: greater", function()
  assert_eq(caml_greaterthan(10, 5), 1)
end)

test("greaterthan: less", function()
  assert_eq(caml_greaterthan(5, 10), 0)
end)

test("greaterthan: equal", function()
  assert_eq(caml_greaterthan(7, 7), 0)
end)

print()
print("Greater Than or Equal Tests:")
print("--------------------------------------------------------------------")

test("greaterequal: greater", function()
  assert_eq(caml_greaterequal(10, 5), 1)
end)

test("greaterequal: equal", function()
  assert_eq(caml_greaterequal(7, 7), 1)
end)

test("greaterequal: less", function()
  assert_eq(caml_greaterequal(5, 10), 0)
end)

print()
print("Min/Max Tests:")
print("--------------------------------------------------------------------")

test("min: returns smaller", function()
  assert_eq(caml_min(5, 10), 5)
  assert_eq(caml_min(10, 5), 5)
end)

test("min: equal values", function()
  assert_eq(caml_min(7, 7), 7)
end)

test("min: strings", function()
  assert_eq(caml_min("abc", "xyz"), "abc")
end)

test("max: returns larger", function()
  assert_eq(caml_max(5, 10), 10)
  assert_eq(caml_max(10, 5), 10)
end)

test("max: equal values", function()
  assert_eq(caml_max(7, 7), 7)
end)

test("max: strings", function()
  assert_eq(caml_max("abc", "xyz"), "xyz")
end)

print()
print("Error Handling Tests:")
print("--------------------------------------------------------------------")

test("compare: functions raise error", function()
  local f1 = function() end
  local f2 = function() end
  assert_error(function()
    caml_compare(f1, f2)
  end, "functional value")
end)

test("equal: functions raise error", function()
  local f = function() end
  assert_error(function()
    caml_equal(f, f)
  end, "functional value")
end)

print()
print("Complex Structure Tests:")
print("--------------------------------------------------------------------")

test("compare: list-like structure", function()
  -- Representing OCaml list: 1 :: 2 :: 3 :: []
  local nil_val = {tag = 0}  -- []
  local list1 = {tag = 0, 3, nil_val}  -- 3 :: []
  local list2 = {tag = 0, 2, list1}    -- 2 :: 3 :: []
  local list3 = {tag = 0, 1, list2}    -- 1 :: 2 :: 3 :: []

  local list3_copy = {tag = 0, 1, {tag = 0, 2, {tag = 0, 3, {tag = 0}}}}

  assert_eq(caml_compare(list3, list3_copy), 0)
end)

test("compare: option-like structure", function()
  -- None: tag 0, no fields
  -- Some(x): tag 0, one field x
  local none = {tag = 0}
  local some_5 = {tag = 0, 5}
  local some_10 = {tag = 0, 10}

  assert_eq(caml_compare(none, {tag = 0}), 0)
  assert_eq(caml_compare(some_5, {tag = 0, 5}), 0)
  assert_eq(caml_compare(some_5, some_10), -1)
  assert_eq(caml_compare(none, some_5), -1)  -- Different sizes
end)

test("compare: tuple-like structure", function()
  local t1 = {tag = 0, 1, "hello", 3.14}
  local t2 = {tag = 0, 1, "hello", 3.14}
  local t3 = {tag = 0, 1, "world", 3.14}

  assert_eq(caml_compare(t1, t2), 0)
  assert_eq(caml_compare(t1, t3), -1)
end)

test("compare: record-like structure", function()
  -- {name: "Alice", age: 30}
  local r1 = {tag = 0, {65, 108, 105, 99, 101}, 30}  -- "Alice"
  local r2 = {tag = 0, {65, 108, 105, 99, 101}, 30}
  local r3 = {tag = 0, {66, 111, 98}, 25}            -- "Bob", 25

  assert_eq(caml_compare(r1, r2), 0)
  assert_eq(caml_compare(r1, r3), -1)  -- "Alice" < "Bob"
end)

print()
print("Edge Cases Tests:")
print("--------------------------------------------------------------------")

test("compare: empty blocks", function()
  local b1 = {tag = 0}
  local b2 = {tag = 0}
  assert_eq(caml_compare(b1, b2), 0)
end)

test("compare: nil values", function()
  assert_eq(caml_compare(nil, nil), 0)
end)

test("compare: mixed nil and values", function()
  -- Different tags: nil vs number
  local result = caml_compare(nil, 5)
  assert_true(result ~= 0)
end)

test("compare: large blocks", function()
  local b1 = {tag = 0}
  local b2 = {tag = 0}
  for i = 1, 100 do
    b1[i] = i
    b2[i] = i
  end
  assert_eq(caml_compare(b1, b2), 0)
end)

test("compare: large blocks different at end", function()
  local b1 = {tag = 0}
  local b2 = {tag = 0}
  for i = 1, 100 do
    b1[i] = i
    b2[i] = i
  end
  b2[100] = 999
  assert_eq(caml_compare(b1, b2), -1)
end)

print()
print("Performance Tests:")
print("--------------------------------------------------------------------")

test("performance: many integer comparisons", function()
  for i = 1, 1000 do
    caml_compare(i, i + 1)
  end
end)

test("performance: many string comparisons", function()
  for i = 1, 100 do
    caml_compare("string" .. i, "string" .. (i + 1))
  end
end)

test("performance: deep nested structures", function()
  local function make_nested(depth)
    if depth == 0 then
      return {tag = 0, 42}
    else
      return {tag = 0, make_nested(depth - 1)}
    end
  end

  local deep1 = make_nested(10)
  local deep2 = make_nested(10)
  assert_eq(caml_compare(deep1, deep2), 0)
end)

print()
print(string.rep("=", 60))
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
