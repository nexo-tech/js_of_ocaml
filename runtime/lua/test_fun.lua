#!/usr/bin/env lua
-- Test suite for fun.lua function application module

dofile("closure.lua")
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
-- Uses caml_make_closure to wrap with __call metatable
local function make_func(arity, fn)
  return caml_make_closure(arity, fn)
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
  local result = partial(4)
  assert(result == 12, "Expected 12, got " .. result)
end)

test("Partial application: missing 2 args", function()
  local f = make_func(3, function(x, y, z) return x + y + z end)
  local partial = caml_call_gen(f, {10})
  assert(type(partial) == "table", "Should return a table")
  assert(partial.l == 2, "Partial should have arity 2")
  local result = partial(20, 30)
  assert(result == 60, "Expected 60, got " .. result)
end)

test("Partial application: missing 3 args", function()
  local f = make_func(4, function(a, b, c, d) return a + b + c + d end)
  local partial = caml_call_gen(f, {1})
  assert(type(partial) == "table", "Should return a table")
  assert(partial.l == 3, "Partial should have arity 3")
  local result = partial(2, 3, 4)
  assert(result == 10, "Expected 10, got " .. result)
end)

test("Multi-stage partial application", function()
  local f = make_func(3, function(a, b, c) return a + b + c end)
  local f1 = caml_call_gen(f, {1})
  assert(type(f1) == "table", "First partial should be table")
  local f2 = caml_call_gen(f1, {2})
  assert(type(f2) == "table", "Second partial should be table")
  local result = f2(3)
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
  local result = partial(6)
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
  local result = add5(10)
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

-- Task 2.4: Partial Application Patterns

test("OCaml pattern: let add x y = x + y; let add5 = add 5", function()
  -- Define add function with arity 2
  local add = make_func(2, function(x, y) return x + y end)

  -- Partially apply with 5
  local add5 = caml_call_gen(add, {5})
  assert(type(add5) == "table", "add5 should be a table")
  assert(add5.l == 1, "add5 should have arity 1")

  -- Apply to 10
  local result = add5(10)
  assert(result == 15, "Expected 15, got " .. tostring(result))

  -- Apply to different values
  assert(add5(7) == 12, "add5 7 should be 12")
  assert(add5(100) == 105, "add5 100 should be 105")
end)

test("Multi-level partial: let f a b c = a+b+c; let g = f 1; let h = g 2", function()
  local f = make_func(3, function(a, b, c) return a + b + c end)

  -- First partial: f 1
  local g = caml_call_gen(f, {1})
  assert(type(g) == "table", "g should be table")
  assert(g.l == 2, "g should have arity 2")

  -- Second partial: g 2
  local h = caml_call_gen(g, {2})
  assert(type(h) == "table", "h should be table")
  assert(h.l == 1, "h should have arity 1")

  -- Final application: h 3
  local result = h(3)
  assert(result == 6, "Expected 6, got " .. tostring(result))
end)

test("Closure arity preservation through multiple stages", function()
  local f = make_func(4, function(a, b, c, d) return a * b + c * d end)

  -- Stage 1: provide 1 arg, expect arity 3
  local f1 = caml_call_gen(f, {2})
  assert(f1.l == 3, "f1 arity should be 3")

  -- Stage 2: provide 1 more arg, expect arity 2
  local f2 = caml_call_gen(f1, {3})
  assert(f2.l == 2, "f2 arity should be 2")

  -- Stage 3: provide 1 more arg, expect arity 1
  local f3 = caml_call_gen(f2, {4})
  assert(f3.l == 1, "f3 arity should be 1")

  -- Final: provide last arg, get result
  local result = f3(5)
  assert(result == 26, "Expected 26 (2*3 + 4*5), got " .. tostring(result))
end)

test("Over-application chain: f 1 2 where f returns function", function()
  -- f returns a function that returns a function
  local f = make_func(1, function(x)
    return make_func(1, function(y)
      return make_func(1, function(z)
        return x * 100 + y * 10 + z
      end)
    end)
  end)

  -- Over-apply with 3 args at once
  local result = caml_call_gen(f, {1, 2, 3})
  assert(result == 123, "Expected 123, got " .. tostring(result))
end)

test("Mixed partial and over-application", function()
  -- Two-arg function returning two-arg function
  local f = make_func(2, function(a, b)
    return make_func(2, function(c, d)
      return a + b + c + d
    end)
  end)

  -- Partial apply with 1 arg
  local g = caml_call_gen(f, {10})
  assert(g.l == 1, "g arity should be 1")

  -- Over-apply g with 3 args (1 needed + 2 extra)
  local result = caml_call_gen(g, {20, 30, 40})
  assert(result == 100, "Expected 100 (10+20+30+40), got " .. tostring(result))
end)

test("Partial application with string concat", function()
  local concat3 = make_func(3, function(a, b, c)
    return a .. b .. c
  end)

  local hello = caml_call_gen(concat3, {"Hello"})
  assert(hello.l == 2, "hello arity should be 2")

  local hello_space = caml_call_gen(hello, {" "})
  assert(hello_space.l == 1, "hello_space arity should be 1")

  local result = hello_space("World")
  assert(result == "Hello World", "Expected 'Hello World', got " .. tostring(result))
end)

test("Partial with arithmetic operations", function()
  local multiply = make_func(2, function(x, y) return x * y end)
  local add = make_func(2, function(x, y) return x + y end)

  -- Create multiply by 10
  local times10 = caml_call_gen(multiply, {10})
  assert(times10.l == 1, "times10 arity should be 1")

  -- Create add 5
  local plus5 = caml_call_gen(add, {5})
  assert(plus5.l == 1, "plus5 arity should be 1")

  -- Compose: (3 * 10) + 5 = 35
  local x = times10(3)
  local result = plus5(x)
  assert(result == 35, "Expected 35, got " .. tostring(result))
end)

test("Higher-order: map-like function with partial application", function()
  -- Simple map function
  local map = make_func(2, function(fn, list)
    local result = {}
    for i, v in ipairs(list) do
      result[i] = caml_call_gen(fn, {v})
    end
    return result
  end)

  -- Create increment function
  local inc = make_func(1, function(x) return x + 1 end)

  -- Partial apply map with inc
  local map_inc = caml_call_gen(map, {inc})
  assert(map_inc.l == 1, "map_inc arity should be 1")

  -- Apply to list
  local result = map_inc({1, 2, 3})
  assert(result[1] == 2 and result[2] == 3 and result[3] == 4, "map_inc failed")
end)

test("Partial application preserves closure captures", function()
  -- Outer value captured
  local base = 100
  local add_with_base = make_func(2, function(x, y)
    return base + x + y
  end)

  -- Partial application should still capture base
  local partial = caml_call_gen(add_with_base, {10})
  assert(partial.l == 1, "partial arity should be 1")

  local result = partial(5)
  assert(result == 115, "Expected 115 (100+10+5), got " .. tostring(result))
end)

test("Complex pipeline: f |> g |> h with partial application", function()
  -- Define functions
  local f = make_func(2, function(x, y) return x + y end)
  local g = make_func(1, function(x) return x * 2 end)
  local h = make_func(1, function(x) return x - 3 end)

  -- Simulate pipeline: 5 |> (f 10) |> g |> h
  local step1 = caml_call_gen(f, {10, 5})    -- 15
  local step2 = caml_call_gen(g, {step1})    -- 30
  local step3 = caml_call_gen(h, {step2})    -- 27

  assert(step3 == 27, "Expected 27, got " .. tostring(step3))

  -- Now with partial application
  local f_10 = caml_call_gen(f, {10})
  local step1_partial = f_10(5)          -- 15
  local step2_partial = caml_call_gen(g, {step1_partial})  -- 30
  local step3_partial = caml_call_gen(h, {step2_partial})  -- 27

  assert(step3_partial == 27, "Expected 27, got " .. tostring(step3_partial))
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
