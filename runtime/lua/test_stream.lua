#!/usr/bin/env lua
-- Test suite for stream.lua
-- Comprehensive tests for lazy streams

local stream = require("stream")
local core = require("core")

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

-- Helper: create OCaml list from Lua table
local function make_list(tbl)
  local list = {tag = 0}  -- Empty list
  for i = #tbl, 1, -1 do
    list = {tag = 0, [1] = tbl[i], [2] = list}
  end
  return list
end

-- Helper: convert OCaml list to Lua table
local function list_to_table(list)
  local result = {}
  while list.tag == 0 and list[1] do
    table.insert(result, list[1])
    list = list[2] or {tag = 0}
  end
  return result
end

print("=== Stream Module Tests ===\n")

-- Test 1-5: Empty stream
test("empty stream", function()
  local s = stream.caml_stream_empty(core.unit)
  assert_equal(stream.caml_stream_is_empty(s), core.true_val, "should be empty")
end)

test("peek on empty stream", function()
  local s = stream.caml_stream_empty(core.unit)
  assert_equal(stream.caml_stream_peek(s), nil, "peek should return nil")
end)

test("next on empty stream raises Failure", function()
  local s = stream.caml_stream_empty(core.unit)
  assert_error(function()
    stream.caml_stream_next(s)
  end, "should raise Stream.Failure")
end)

test("junk on empty stream raises Failure", function()
  local s = stream.caml_stream_empty(core.unit)
  assert_error(function()
    stream.caml_stream_junk(s)
  end, "should raise Stream.Failure")
end)

test("npeek on empty stream", function()
  local s = stream.caml_stream_empty(core.unit)
  local result = stream.caml_stream_npeek(5, s)
  local tbl = list_to_table(result)
  assert_equal(#tbl, 0, "should return empty list")
end)

-- Test 6-10: Stream from list
test("stream from list", function()
  local list = make_list({1, 2, 3})
  local s = stream.caml_stream_of_list(list)
  assert_equal(stream.caml_stream_is_empty(s), core.false_val, "should not be empty")
end)

test("peek at first element", function()
  local list = make_list({1, 2, 3})
  local s = stream.caml_stream_of_list(list)
  assert_equal(stream.caml_stream_peek(s), 1, "should peek 1")
  assert_equal(stream.caml_stream_peek(s), 1, "should still peek 1")
end)

test("next consumes element", function()
  local list = make_list({1, 2, 3})
  local s = stream.caml_stream_of_list(list)
  assert_equal(stream.caml_stream_next(s), 1, "should get 1")
  assert_equal(stream.caml_stream_next(s), 2, "should get 2")
  assert_equal(stream.caml_stream_next(s), 3, "should get 3")
end)

test("junk removes element", function()
  local list = make_list({1, 2, 3})
  local s = stream.caml_stream_of_list(list)
  stream.caml_stream_junk(s)
  assert_equal(stream.caml_stream_peek(s), 2, "should peek 2 after junk")
end)

test("npeek shows multiple elements", function()
  local list = make_list({1, 2, 3, 4, 5})
  local s = stream.caml_stream_of_list(list)
  local result = stream.caml_stream_npeek(3, s)
  local tbl = list_to_table(result)
  assert_equal(#tbl, 3, "should have 3 elements")
  assert_equal(tbl[1], 1)
  assert_equal(tbl[2], 2)
  assert_equal(tbl[3], 3)
end)

-- Test 11-15: Stream from string
test("stream from string", function()
  local s = stream.caml_stream_of_string("hello")
  assert_equal(stream.caml_stream_is_empty(s), core.false_val, "should not be empty")
end)

test("peek at first character", function()
  local s = stream.caml_stream_of_string("hello")
  assert_equal(stream.caml_stream_peek(s), string.byte("h"), "should peek 'h'")
end)

test("consume all characters from string", function()
  local s = stream.caml_stream_of_string("abc")
  assert_equal(stream.caml_stream_next(s), string.byte("a"))
  assert_equal(stream.caml_stream_next(s), string.byte("b"))
  assert_equal(stream.caml_stream_next(s), string.byte("c"))
  assert_error(function()
    stream.caml_stream_next(s)
  end, "should raise Failure at end")
end)

test("stream from empty string", function()
  local s = stream.caml_stream_of_string("")
  assert_equal(stream.caml_stream_is_empty(s), core.true_val, "should be empty")
end)

test("npeek on string stream", function()
  local s = stream.caml_stream_of_string("hello")
  local result = stream.caml_stream_npeek(3, s)
  local tbl = list_to_table(result)
  assert_equal(#tbl, 3)
  assert_equal(tbl[1], string.byte("h"))
  assert_equal(tbl[2], string.byte("e"))
  assert_equal(tbl[3], string.byte("l"))
end)

-- Test 16-20: Stream from function
test("stream from function", function()
  local i = 0
  local function gen()
    i = i + 1
    if i <= 3 then
      return i
    else
      return nil
    end
  end

  local s = stream.caml_stream_from(gen)
  assert_equal(stream.caml_stream_next(s), 1)
  assert_equal(stream.caml_stream_next(s), 2)
  assert_equal(stream.caml_stream_next(s), 3)
end)

test("stream from function that returns nil", function()
  local function gen()
    return nil
  end

  local s = stream.caml_stream_from(gen)
  assert_equal(stream.caml_stream_is_empty(s), core.true_val)
end)

test("infinite stream from function", function()
  local i = 0
  local function gen()
    i = i + 1
    return i
  end

  local s = stream.caml_stream_from(gen)
  assert_equal(stream.caml_stream_next(s), 1)
  assert_equal(stream.caml_stream_next(s), 2)
  assert_equal(stream.caml_stream_next(s), 3)
  -- Can continue indefinitely
end)

test("lazy evaluation of stream", function()
  local evaluated = false
  local function gen()
    evaluated = true
    return 42
  end

  local s = stream.caml_stream_from(gen)
  assert_equal(evaluated, false, "should not evaluate until needed")
  stream.caml_stream_peek(s)
  assert_equal(evaluated, true, "should evaluate on peek")
end)

test("stream memoization", function()
  local call_count = 0
  local function gen()
    call_count = call_count + 1
    if call_count <= 3 then
      return call_count
    else
      return nil
    end
  end

  local s = stream.caml_stream_from(gen)
  stream.caml_stream_peek(s)
  stream.caml_stream_peek(s)
  -- Peek should not call gen again
  assert_equal(call_count, 1, "should only call gen once for first element")
end)

-- Test 21-25: Cons operation
test("cons prepends element", function()
  local list = make_list({2, 3})
  local s1 = stream.caml_stream_of_list(list)
  local s2 = stream.caml_stream_cons(1, s1)
  assert_equal(stream.caml_stream_next(s2), 1)
  assert_equal(stream.caml_stream_next(s2), 2)
  assert_equal(stream.caml_stream_next(s2), 3)
end)

test("cons to empty stream", function()
  local s1 = stream.caml_stream_empty(core.unit)
  local s2 = stream.caml_stream_cons(42, s1)
  assert_equal(stream.caml_stream_next(s2), 42)
  assert_equal(stream.caml_stream_is_empty(s2), core.true_val)
end)

test("multiple cons operations", function()
  local s = stream.caml_stream_empty(core.unit)
  s = stream.caml_stream_cons(3, s)
  s = stream.caml_stream_cons(2, s)
  s = stream.caml_stream_cons(1, s)
  assert_equal(stream.caml_stream_next(s), 1)
  assert_equal(stream.caml_stream_next(s), 2)
  assert_equal(stream.caml_stream_next(s), 3)
end)

test("cons preserves tail", function()
  local list = make_list({2, 3, 4})
  local s1 = stream.caml_stream_of_list(list)
  local s2 = stream.caml_stream_cons(1, s1)

  stream.caml_stream_next(s2)  -- consume 1 from s2
  -- s1 should still have all its elements
  assert_equal(stream.caml_stream_peek(s1), 2)
end)

test("npeek after cons", function()
  local list = make_list({2, 3})
  local s1 = stream.caml_stream_of_list(list)
  local s2 = stream.caml_stream_cons(1, s1)

  local result = stream.caml_stream_npeek(3, s2)
  local tbl = list_to_table(result)
  assert_equal(#tbl, 3)
  assert_equal(tbl[1], 1)
  assert_equal(tbl[2], 2)
  assert_equal(tbl[3], 3)
end)

-- Test 26-30: Stream iteration and counting
test("iter over stream elements", function()
  local list = make_list({1, 2, 3})
  local s = stream.caml_stream_of_list(list)

  local sum = 0
  stream.caml_stream_iter(function(x)
    sum = sum + x
  end, s)

  assert_equal(sum, 6, "sum should be 6")
  assert_equal(stream.caml_stream_is_empty(s), core.true_val, "stream should be consumed")
end)

test("count stream elements", function()
  local list = make_list({1, 2, 3, 4, 5})
  local s = stream.caml_stream_of_list(list)
  assert_equal(stream.caml_stream_count(s), 5)
end)

test("count empty stream", function()
  local s = stream.caml_stream_empty(core.unit)
  assert_equal(stream.caml_stream_count(s), 0)
end)

test("iter over empty stream", function()
  local s = stream.caml_stream_empty(core.unit)
  local called = false
  stream.caml_stream_iter(function(x)
    called = true
  end, s)
  assert_equal(called, false, "should not call function")
end)

test("stream from array", function()
  local arr = {tag = 0, [0] = 3, [1] = 10, [2] = 20, [3] = 30}
  local s = stream.caml_stream_of_array(arr)
  assert_equal(stream.caml_stream_next(s), 10)
  assert_equal(stream.caml_stream_next(s), 20)
  assert_equal(stream.caml_stream_next(s), 30)
end)

-- Test 31-35: Edge cases
test("npeek more than available", function()
  local list = make_list({1, 2})
  local s = stream.caml_stream_of_list(list)
  local result = stream.caml_stream_npeek(10, s)
  local tbl = list_to_table(result)
  assert_equal(#tbl, 2, "should return only available elements")
end)

test("npeek with 0", function()
  local list = make_list({1, 2, 3})
  local s = stream.caml_stream_of_list(list)
  local result = stream.caml_stream_npeek(0, s)
  local tbl = list_to_table(result)
  assert_equal(#tbl, 0)
end)

test("stream exhaustion", function()
  local list = make_list({1})
  local s = stream.caml_stream_of_list(list)
  stream.caml_stream_next(s)
  assert_equal(stream.caml_stream_is_empty(s), core.true_val)
  assert_error(function()
    stream.caml_stream_next(s)
  end)
end)

test("peek after partial consumption", function()
  local list = make_list({1, 2, 3})
  local s = stream.caml_stream_of_list(list)
  stream.caml_stream_next(s)  -- consume 1
  assert_equal(stream.caml_stream_peek(s), 2)
  assert_equal(stream.caml_stream_peek(s), 2, "peek should be idempotent")
end)

test("mixed peek and next operations", function()
  local list = make_list({1, 2, 3, 4})
  local s = stream.caml_stream_of_list(list)

  assert_equal(stream.caml_stream_peek(s), 1)
  assert_equal(stream.caml_stream_next(s), 1)
  assert_equal(stream.caml_stream_peek(s), 2)
  stream.caml_stream_junk(s)
  assert_equal(stream.caml_stream_next(s), 3)
  assert_equal(stream.caml_stream_peek(s), 4)
end)

-- Test 36-38: Performance tests
test("large stream from list", function()
  local tbl = {}
  for i = 1, 1000 do
    tbl[i] = i
  end
  local list = make_list(tbl)
  local s = stream.caml_stream_of_list(list)

  local count = 0
  while stream.caml_stream_peek(s) ~= nil do
    stream.caml_stream_junk(s)
    count = count + 1
  end
  assert_equal(count, 1000)
end)

test("large string stream", function()
  local str = string.rep("a", 1000)
  local s = stream.caml_stream_of_string(str)
  assert_equal(stream.caml_stream_count(s), 1000)
end)

test("function generator performance", function()
  local i = 0
  local function gen()
    i = i + 1
    if i <= 1000 then
      return i
    else
      return nil
    end
  end

  local s = stream.caml_stream_from(gen)
  local count = stream.caml_stream_count(s)
  assert_equal(count, 1000)
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
