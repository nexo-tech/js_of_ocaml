#!/usr/bin/env lua
-- Test suite for fun.lua function application module

dofile("fun.lua")

local tests_passed = 0
local tests_failed = 0

-- Test helper
local function test(name, func)
  local success, err = pcall(func)
  if success then
    tests_passed = tests_passed + 1
    print("✓ " .. name)
  else
    tests_failed = tests_failed + 1
    print("✗ " .. name)
    print("  Error: " .. tostring(err))
  end
end

-- Helper to create function with arity
-- In Lua 5.1, we can't set properties on functions, so wrap in table
local function make_func(arity, fn)
  return {l = arity, fn}
end

-- Test exact application
test("Exact application with 1 arg", function()
  local f = make_func(1, function(x) return x * 2 end)
  local result = caml_call_gen(f, {5})
  assert(result == 10, "Expected 10, got " .. result)
end)

test("Exact application with 2 args", function()
  local f = make_func(2, function(x, y) return x + y end)
  local result = caml_call_gen(f, {3, 4})
  assert(result == 7, "Expected 7, got " .. result)
end)

test("Exact application with 3 args", function()
  local f = make_func(3, function(x, y, z) return x + y + z end)
  local result = caml_call_gen(f, {1, 2, 3})
  assert(result == 6, "Expected 6, got " .. result)
end)

-- Test partial application (currying)
test("Partial application: missing 1 arg", function()
  local f = make_func(2, function(x, y) return x * y end)
  local partial = caml_call_gen(f, {3})
  assert(type(partial) == "table", "Should return a table")
  assert(partial.l == 1, "Partial should have arity 1")
  local result = partial[1](4)
  assert(result == 12, "Expected 12, got " .. result)
end)

test("Partial application: missing 2 args", function()
  local f = make_func(3, function(x, y, z) return x + y + z end)
  local partial = caml_call_gen(f, {10})
  assert(type(partial) == "table", "Should return a table")
  assert(partial.l == 2, "Partial should have arity 2")
  local result = partial[1](20, 30)
  assert(result == 60, "Expected 60, got " .. result)
end)

test("Partial application: missing 3 args", function()
  local f = make_func(4, function(a, b, c, d) return a + b + c + d end)
  local partial = caml_call_gen(f, {1})
  assert(type(partial) == "table", "Should return a table")
  assert(partial.l == 3, "Partial should have arity 3")
  local result = partial[1](2, 3, 4)
  assert(result == 10, "Expected 10, got " .. result)
end)

test("Multi-stage partial application", function()
  local f = make_func(3, function(a, b, c) return a + b + c end)
  local f1 = caml_call_gen(f, {1})
  assert(type(f1) == "table", "First partial should be table")
  local f2 = caml_call_gen(f1, {2})
  assert(type(f2) == "table", "Second partial should be table")
  local result = f2[1](3)
  assert(result == 6, "Expected 6, got " .. result)
end)

-- Test over-application
test("Over-application: 1 extra arg", function()
  local f1 = make_func(1, function(x)
    return make_func(1, function(y)
      return x + y
    end)
  end)
  local result = caml_call_gen(f1, {10, 20})
  assert(result == 30, "Expected 30, got " .. result)
end)

test("Over-application: 2 extra args", function()
  local f1 = make_func(1, function(x)
    return make_func(1, function(y)
      return make_func(1, function(z)
        return x + y + z
      end)
    end)
  end)
  local result = caml_call_gen(f1, {1, 2, 3})
  assert(result == 6, "Expected 6, got " .. result)
end)

-- Test caml_apply
test("caml_apply with exact arity", function()
  local f = make_func(2, function(x, y) return x - y end)
  local result = caml_apply(f, 10, 3)
  assert(result == 7, "Expected 7, got " .. result)
end)

test("caml_apply with partial", function()
  local f = make_func(2, function(x, y) return x * y end)
  local partial = caml_apply(f, 5)
  assert(type(partial) == "table", "Should return table")
  local result = partial[1](6)
  assert(result == 30, "Expected 30, got " .. result)
end)

-- Test complex currying scenarios
test("Curried function returning curried function", function()
  local add = make_func(2, function(x, y) return x + y end)
  local make_adder = make_func(1, function(x)
    return caml_call_gen(add, {x})
  end)

  local add5 = caml_call_gen(make_adder, {5})
  assert(type(add5) == "table", "Should return table")
  local result = add5[1](10)
  assert(result == 15, "Expected 15, got " .. result)
end)

test("Pipeline of partial applications", function()
  local f = make_func(4, function(a, b, c, d) return ((a + b) * c) - d end)
  local f1 = caml_call_gen(f, {2})       -- f1 = f(2, _, _, _)
  local f2 = caml_call_gen(f1, {3})      -- f2 = f(2, 3, _, _)
  local f3 = caml_call_gen(f2, {4})      -- f3 = f(2, 3, 4, _)
  local result = caml_call_gen(f3, {1})  -- result = f(2, 3, 4, 1)
  assert(result == 19, "Expected 19, got " .. result)  -- ((2+3)*4) - 1 = 19
end)

-- Test that primitives are defined
test("Primitives are defined", function()
  assert(type(caml_call_gen) == "function", "caml_call_gen is defined")
  assert(type(caml_apply) == "function", "caml_apply is defined")
end)

-- Test edge cases
test("Zero-arg function call", function()
  local f = make_func(0, function() return 42 end)
  local result = caml_call_gen(f, {})
  assert(result == 42, "Expected 42, got " .. result)
end)

test("Function with numeric arguments", function()
  local f = make_func(2, function(x, y)
    return x * 10 + y
  end)
  local result = caml_call_gen(f, {5, 3})
  assert(result == 53, "Expected 53, got " .. tostring(result))
end)

-- Print summary
print("\n" .. string.rep("=", 50))
print("Tests passed: " .. tests_passed)
print("Tests failed: " .. tests_failed)
print(string.rep("=", 50))

if tests_failed > 0 then
  os.exit(1)
else
  print("\nAll tests passed!")
  os.exit(0)
end
