#!/usr/bin/env lua
-- Test Stack module

local stack = require("stack")

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
print("Stack Module Tests")
print("====================================================================")
print()

print("Stack Creation Tests:")
print("--------------------------------------------------------------------")

test("create: empty stack", function()
  local s = stack.caml_stack_create()
  assert_eq(stack.caml_stack_length(s), 0)
  assert_true(stack.caml_stack_is_empty(s))
end)

print()
print("Push Tests:")
print("--------------------------------------------------------------------")

test("push: single element", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 42)
  assert_eq(stack.caml_stack_length(s), 1)
  assert_false(stack.caml_stack_is_empty(s))
end)

test("push: multiple elements", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_push(s, 2)
  stack.caml_stack_push(s, 3)
  assert_eq(stack.caml_stack_length(s), 3)
end)

test("push: different types", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 42)
  stack.caml_stack_push(s, "hello")
  stack.caml_stack_push(s, 3.14)
  stack.caml_stack_push(s, {a = 1})
  assert_eq(stack.caml_stack_length(s), 4)
end)

print()
print("Pop Tests:")
print("--------------------------------------------------------------------")

test("pop: single element", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 42)
  local value = stack.caml_stack_pop(s)
  assert_eq(value, 42)
  assert_eq(stack.caml_stack_length(s), 0)
  assert_true(stack.caml_stack_is_empty(s))
end)

test("pop: LIFO order", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_push(s, 2)
  stack.caml_stack_push(s, 3)

  assert_eq(stack.caml_stack_pop(s), 3)
  assert_eq(stack.caml_stack_pop(s), 2)
  assert_eq(stack.caml_stack_pop(s), 1)
  assert_true(stack.caml_stack_is_empty(s))
end)

test("pop: from empty stack raises error", function()
  local s = stack.caml_stack_create()
  assert_error(function()
    stack.caml_stack_pop(s)
  end, "Stack.Empty")
end)

test("pop: after clear raises error", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_clear(s)
  assert_error(function()
    stack.caml_stack_pop(s)
  end, "Stack.Empty")
end)

print()
print("Top Tests:")
print("--------------------------------------------------------------------")

test("top: view top element", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 42)
  assert_eq(stack.caml_stack_top(s), 42)
  assert_eq(stack.caml_stack_length(s), 1)  -- Length unchanged
end)

test("top: doesn't remove element", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_push(s, 2)

  assert_eq(stack.caml_stack_top(s), 2)
  assert_eq(stack.caml_stack_top(s), 2)  -- Still 2
  assert_eq(stack.caml_stack_length(s), 2)
end)

test("top: returns most recent push", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  assert_eq(stack.caml_stack_top(s), 1)

  stack.caml_stack_push(s, 2)
  assert_eq(stack.caml_stack_top(s), 2)

  stack.caml_stack_push(s, 3)
  assert_eq(stack.caml_stack_top(s), 3)
end)

test("top: from empty stack raises error", function()
  local s = stack.caml_stack_create()
  assert_error(function()
    stack.caml_stack_top(s)
  end, "Stack.Empty")
end)

print()
print("Is Empty Tests:")
print("--------------------------------------------------------------------")

test("is_empty: true for new stack", function()
  local s = stack.caml_stack_create()
  assert_true(stack.caml_stack_is_empty(s))
end)

test("is_empty: false after push", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  assert_false(stack.caml_stack_is_empty(s))
end)

test("is_empty: true after all elements removed", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_push(s, 2)
  stack.caml_stack_pop(s)
  stack.caml_stack_pop(s)
  assert_true(stack.caml_stack_is_empty(s))
end)

print()
print("Length Tests:")
print("--------------------------------------------------------------------")

test("length: tracks correctly", function()
  local s = stack.caml_stack_create()
  assert_eq(stack.caml_stack_length(s), 0)

  stack.caml_stack_push(s, 1)
  assert_eq(stack.caml_stack_length(s), 1)

  stack.caml_stack_push(s, 2)
  assert_eq(stack.caml_stack_length(s), 2)

  stack.caml_stack_pop(s)
  assert_eq(stack.caml_stack_length(s), 1)

  stack.caml_stack_pop(s)
  assert_eq(stack.caml_stack_length(s), 0)
end)

test("length: after many operations", function()
  local s = stack.caml_stack_create()
  for i = 1, 10 do
    stack.caml_stack_push(s, i)
  end
  assert_eq(stack.caml_stack_length(s), 10)

  for i = 1, 5 do
    stack.caml_stack_pop(s)
  end
  assert_eq(stack.caml_stack_length(s), 5)
end)

print()
print("Clear Tests:")
print("--------------------------------------------------------------------")

test("clear: empties stack", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_push(s, 2)
  stack.caml_stack_push(s, 3)

  stack.caml_stack_clear(s)
  assert_eq(stack.caml_stack_length(s), 0)
  assert_true(stack.caml_stack_is_empty(s))
end)

test("clear: can reuse stack", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_clear(s)
  stack.caml_stack_push(s, 2)

  assert_eq(stack.caml_stack_length(s), 1)
  assert_eq(stack.caml_stack_pop(s), 2)
end)

test("clear: on empty stack", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_clear(s)
  assert_true(stack.caml_stack_is_empty(s))
end)

print()
print("Iterator Tests:")
print("--------------------------------------------------------------------")

test("iter: empty stack", function()
  local s = stack.caml_stack_create()
  local count = 0
  for v in stack.caml_stack_iter(s) do
    count = count + 1
  end
  assert_eq(count, 0)
end)

test("iter: single element", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 42)

  local values = {}
  for v in stack.caml_stack_iter(s) do
    table.insert(values, v)
  end

  assert_eq(#values, 1)
  assert_eq(values[1], 42)
end)

test("iter: multiple elements (top to bottom)", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_push(s, 2)
  stack.caml_stack_push(s, 3)

  local values = {}
  for v in stack.caml_stack_iter(s) do
    table.insert(values, v)
  end

  assert_eq(#values, 3)
  assert_eq(values[1], 3)  -- Top first
  assert_eq(values[2], 2)
  assert_eq(values[3], 1)  -- Bottom last
end)

test("iter: doesn't modify stack", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_push(s, 2)

  for v in stack.caml_stack_iter(s) do
    -- Just iterate
  end

  assert_eq(stack.caml_stack_length(s), 2)
end)

print()
print("To Array Tests:")
print("--------------------------------------------------------------------")

test("to_array: empty stack", function()
  local s = stack.caml_stack_create()
  local arr = stack.caml_stack_to_array(s)
  assert_eq(#arr, 0)
end)

test("to_array: with elements (bottom to top)", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_push(s, 2)
  stack.caml_stack_push(s, 3)

  local arr = stack.caml_stack_to_array(s)
  assert_eq(#arr, 3)
  assert_eq(arr[1], 1)  -- Bottom first
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)  -- Top last
end)

print()
print("Mixed Operations Tests:")
print("--------------------------------------------------------------------")

test("mixed: interleaved push and pop", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_push(s, 2)
  assert_eq(stack.caml_stack_pop(s), 2)
  stack.caml_stack_push(s, 3)
  assert_eq(stack.caml_stack_pop(s), 3)
  assert_eq(stack.caml_stack_pop(s), 1)
  assert_true(stack.caml_stack_is_empty(s))
end)

test("mixed: top and pop", function()
  local s = stack.caml_stack_create()
  stack.caml_stack_push(s, 1)
  stack.caml_stack_push(s, 2)

  assert_eq(stack.caml_stack_top(s), 2)
  assert_eq(stack.caml_stack_pop(s), 2)
  assert_eq(stack.caml_stack_top(s), 1)
  assert_eq(stack.caml_stack_pop(s), 1)
end)

test("mixed: reverse order with stack", function()
  local s = stack.caml_stack_create()
  local input = {1, 2, 3, 4, 5}

  -- Push all
  for i = 1, #input do
    stack.caml_stack_push(s, input[i])
  end

  -- Pop all (reversed)
  local output = {}
  while not stack.caml_stack_is_empty(s) do
    table.insert(output, stack.caml_stack_pop(s))
  end

  -- Verify reversed
  assert_eq(#output, 5)
  for i = 1, #input do
    assert_eq(output[i], input[#input - i + 1])
  end
end)

print()
print("Performance Tests:")
print("--------------------------------------------------------------------")

test("performance: many pushes", function()
  local s = stack.caml_stack_create()
  for i = 1, 1000 do
    stack.caml_stack_push(s, i)
  end
  assert_eq(stack.caml_stack_length(s), 1000)
end)

test("performance: many pops", function()
  local s = stack.caml_stack_create()
  for i = 1, 1000 do
    stack.caml_stack_push(s, i)
  end
  for i = 1, 1000 do
    stack.caml_stack_pop(s)
  end
  assert_true(stack.caml_stack_is_empty(s))
end)

test("performance: repeated push/pop cycles", function()
  local s = stack.caml_stack_create()
  for cycle = 1, 100 do
    for i = 1, 10 do
      stack.caml_stack_push(s, i)
    end
    for i = 1, 10 do
      stack.caml_stack_pop(s)
    end
  end
  assert_true(stack.caml_stack_is_empty(s))
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
