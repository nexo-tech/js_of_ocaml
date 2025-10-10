#!/usr/bin/env lua
-- Test Queue module

dofile("queue.lua")

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
print("Queue Module Tests")
print("====================================================================")
print()

print("Queue Creation Tests:")
print("--------------------------------------------------------------------")

test("create: empty queue", function()
  local q = caml_queue_create()
  assert_eq(caml_queue_length(q), 0)
  assert_true(caml_queue_is_empty(q))
end)

print()
print("Add (Enqueue) Tests:")
print("--------------------------------------------------------------------")

test("add: single element", function()
  local q = caml_queue_create()
  caml_queue_add(q, 42)
  assert_eq(caml_queue_length(q), 1)
  assert_false(caml_queue_is_empty(q))
end)

test("add: multiple elements", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_add(q, 2)
  caml_queue_add(q, 3)
  assert_eq(caml_queue_length(q), 3)
end)

test("add: different types", function()
  local q = caml_queue_create()
  caml_queue_add(q, 42)
  caml_queue_add(q, "hello")
  caml_queue_add(q, 3.14)
  caml_queue_add(q, {a = 1})
  assert_eq(caml_queue_length(q), 4)
end)

print()
print("Take (Dequeue) Tests:")
print("--------------------------------------------------------------------")

test("take: single element", function()
  local q = caml_queue_create()
  caml_queue_add(q, 42)
  local value = caml_queue_take(q)
  assert_eq(value, 42)
  assert_eq(caml_queue_length(q), 0)
  assert_true(caml_queue_is_empty(q))
end)

test("take: FIFO order", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_add(q, 2)
  caml_queue_add(q, 3)

  assert_eq(caml_queue_take(q), 1)
  assert_eq(caml_queue_take(q), 2)
  assert_eq(caml_queue_take(q), 3)
  assert_true(caml_queue_is_empty(q))
end)

test("take: from empty queue raises error", function()
  local q = caml_queue_create()
  assert_error(function()
    caml_queue_take(q)
  end, "Queue.Empty")
end)

test("take: after clear raises error", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_clear(q)
  assert_error(function()
    caml_queue_take(q)
  end, "Queue.Empty")
end)

print()
print("Peek Tests:")
print("--------------------------------------------------------------------")

test("peek: view first element", function()
  local q = caml_queue_create()
  caml_queue_add(q, 42)
  assert_eq(caml_queue_peek(q), 42)
  assert_eq(caml_queue_length(q), 1)  -- Length unchanged
end)

test("peek: doesn't remove element", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_add(q, 2)

  assert_eq(caml_queue_peek(q), 1)
  assert_eq(caml_queue_peek(q), 1)  -- Still 1
  assert_eq(caml_queue_length(q), 2)
end)

test("peek: from empty queue raises error", function()
  local q = caml_queue_create()
  assert_error(function()
    caml_queue_peek(q)
  end, "Queue.Empty")
end)

print()
print("Is Empty Tests:")
print("--------------------------------------------------------------------")

test("is_empty: true for new queue", function()
  local q = caml_queue_create()
  assert_true(caml_queue_is_empty(q))
end)

test("is_empty: false after add", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  assert_false(caml_queue_is_empty(q))
end)

test("is_empty: true after all elements removed", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_add(q, 2)
  caml_queue_take(q)
  caml_queue_take(q)
  assert_true(caml_queue_is_empty(q))
end)

print()
print("Length Tests:")
print("--------------------------------------------------------------------")

test("length: tracks correctly", function()
  local q = caml_queue_create()
  assert_eq(caml_queue_length(q), 0)

  caml_queue_add(q, 1)
  assert_eq(caml_queue_length(q), 1)

  caml_queue_add(q, 2)
  assert_eq(caml_queue_length(q), 2)

  caml_queue_take(q)
  assert_eq(caml_queue_length(q), 1)

  caml_queue_take(q)
  assert_eq(caml_queue_length(q), 0)
end)

test("length: after many operations", function()
  local q = caml_queue_create()
  for i = 1, 10 do
    caml_queue_add(q, i)
  end
  assert_eq(caml_queue_length(q), 10)

  for i = 1, 5 do
    caml_queue_take(q)
  end
  assert_eq(caml_queue_length(q), 5)
end)

print()
print("Clear Tests:")
print("--------------------------------------------------------------------")

test("clear: empties queue", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_add(q, 2)
  caml_queue_add(q, 3)

  caml_queue_clear(q)
  assert_eq(caml_queue_length(q), 0)
  assert_true(caml_queue_is_empty(q))
end)

test("clear: can reuse queue", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_clear(q)
  caml_queue_add(q, 2)

  assert_eq(caml_queue_length(q), 1)
  assert_eq(caml_queue_take(q), 2)
end)

test("clear: on empty queue", function()
  local q = caml_queue_create()
  caml_queue_clear(q)
  assert_true(caml_queue_is_empty(q))
end)

print()
print("Iterator Tests:")
print("--------------------------------------------------------------------")

test("iter: empty queue", function()
  local q = caml_queue_create()
  local count = 0
  for v in caml_queue_iter(q) do
    count = count + 1
  end
  assert_eq(count, 0)
end)

test("iter: single element", function()
  local q = caml_queue_create()
  caml_queue_add(q, 42)

  local values = {}
  for v in caml_queue_iter(q) do
    table.insert(values, v)
  end

  assert_eq(#values, 1)
  assert_eq(values[1], 42)
end)

test("iter: multiple elements in order", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_add(q, 2)
  caml_queue_add(q, 3)

  local values = {}
  for v in caml_queue_iter(q) do
    table.insert(values, v)
  end

  assert_eq(#values, 3)
  assert_eq(values[1], 1)
  assert_eq(values[2], 2)
  assert_eq(values[3], 3)
end)

test("iter: doesn't modify queue", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_add(q, 2)

  for v in caml_queue_iter(q) do
    -- Just iterate
  end

  assert_eq(caml_queue_length(q), 2)
end)

print()
print("To Array Tests:")
print("--------------------------------------------------------------------")

test("to_array: empty queue", function()
  local q = caml_queue_create()
  local arr = caml_queue_to_array(q)
  assert_eq(#arr, 0)
end)

test("to_array: with elements", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_add(q, 2)
  caml_queue_add(q, 3)

  local arr = caml_queue_to_array(q)
  assert_eq(#arr, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
end)

print()
print("Mixed Operations Tests:")
print("--------------------------------------------------------------------")

test("mixed: interleaved add and take", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_add(q, 2)
  assert_eq(caml_queue_take(q), 1)
  caml_queue_add(q, 3)
  assert_eq(caml_queue_take(q), 2)
  assert_eq(caml_queue_take(q), 3)
  assert_true(caml_queue_is_empty(q))
end)

test("mixed: peek and take", function()
  local q = caml_queue_create()
  caml_queue_add(q, 1)
  caml_queue_add(q, 2)

  assert_eq(caml_queue_peek(q), 1)
  assert_eq(caml_queue_take(q), 1)
  assert_eq(caml_queue_peek(q), 2)
  assert_eq(caml_queue_take(q), 2)
end)

print()
print("Performance Tests:")
print("--------------------------------------------------------------------")

test("performance: many enqueues", function()
  local q = caml_queue_create()
  for i = 1, 1000 do
    caml_queue_add(q, i)
  end
  assert_eq(caml_queue_length(q), 1000)
end)

test("performance: many dequeues", function()
  local q = caml_queue_create()
  for i = 1, 1000 do
    caml_queue_add(q, i)
  end
  for i = 1, 1000 do
    caml_queue_take(q)
  end
  assert_true(caml_queue_is_empty(q))
end)

test("performance: repeated add/take cycles", function()
  local q = caml_queue_create()
  for cycle = 1, 100 do
    for i = 1, 10 do
      caml_queue_add(q, i)
    end
    for i = 1, 10 do
      caml_queue_take(q)
    end
  end
  assert_true(caml_queue_is_empty(q))
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
