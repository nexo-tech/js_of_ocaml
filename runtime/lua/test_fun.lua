#!/usr/bin/env lua
-- Test suite for fun.lua function application module

local fun = require("fun")

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

-- Test exact application
test("Exact application with 1 arg", function()
  local f = {l = 1, f = function(x) return x * 2 end}
  local result = fun.caml_call_gen(f, {5})
  assert(result == 10, "Expected 10, got " .. result)
end)

test("Exact application with 2 args", function()
  local f = {l = 2, f = function(x, y) return x + y end}
  local result = fun.caml_call_gen(f, {3, 4})
  assert(result == 7, "Expected 7, got " .. result)
end)

test("Exact application with 3 args", function()
  local f = {l = 3, f = function(x, y, z) return x + y + z end}
  local result = fun.caml_call_gen(f, {1, 2, 3})
  assert(result == 6, "Expected 6, got " .. result)
end)

-- Test partial application (currying)
test("Partial application: missing 1 arg", function()
  local f = {l = 2, f = function(x, y) return x * y end}
  local partial = fun.caml_call_gen(f, {3})
  assert(type(partial) == "table", "Should return a table")
  assert(partial.l == 1, "Partial should have arity 1")
  local result = partial.f(4)
  assert(result == 12, "Expected 12, got " .. result)
end)

test("Partial application: missing 2 args", function()
  local f = {l = 3, f = function(x, y, z) return x + y + z end}
  local partial = fun.caml_call_gen(f, {10})
  assert(type(partial) == "table", "Should return a table")
  assert(partial.l == 2, "Partial should have arity 2")
  local result = partial.f(20, 30)
  assert(result == 60, "Expected 60, got " .. result)
end)

test("Partial application: missing 3 args", function()
  local f = {l = 4, f = function(a, b, c, d) return a + b + c + d end}
  local partial = fun.caml_call_gen(f, {1})
  assert(type(partial) == "table", "Should return a table")
  assert(partial.l == 3, "Partial should have arity 3")
  local result = partial.f(2, 3, 4)
  assert(result == 10, "Expected 10, got " .. result)
end)

test("Multi-stage partial application", function()
  local f = {l = 3, f = function(a, b, c) return a + b + c end}
  local f1 = fun.caml_call_gen(f, {1})
  assert(type(f1) == "table", "First partial should be table")
  local f2 = fun.caml_call_gen(f1, {2})
  assert(type(f2) == "table", "Second partial should be table")
  local result = f2.f(3)
  assert(result == 6, "Expected 6, got " .. result)
end)

-- Test over-application
test("Over-application: 1 extra arg", function()
  local f1 = {l = 1, f = function(x)
    return {l = 1, f = function(y)
      return x + y
    end}
  end}
  local result = fun.caml_call_gen(f1, {10, 20})
  assert(result == 30, "Expected 30, got " .. result)
end)

test("Over-application: 2 extra args", function()
  local f1 = {l = 1, f = function(x)
    return {l = 1, f = function(y)
      return {l = 1, f = function(z)
        return x + y + z
      end}
    end}
  end}
  local result = fun.caml_call_gen(f1, {1, 2, 3})
  assert(result == 6, "Expected 6, got " .. result)
end)

-- Test caml_apply
test("caml_apply with arity", function()
  local f = {l = 2, f = function(x, y) return x - y end}
  local result = fun.caml_apply(f, 10, 3)
  assert(result == 7, "Expected 7, got " .. result)
end)

test("caml_apply with partial", function()
  local f = {l = 2, f = function(x, y) return x * y end}
  local partial = fun.caml_apply(f, 5)
  assert(type(partial) == "table", "Should return table")
  local result = partial.f(6)
  assert(result == 30, "Expected 30, got " .. result)
end)

-- Test caml_curry
test("caml_curry creates curried function", function()
  local impl = function(a, b, c) return a + b * c end
  local f = fun.caml_curry(3, impl)
  assert(f.l == 3, "Should have arity 3")
  local result = f.f(2, 3, 4)
  assert(result == 14, "Expected 14, got " .. result)
end)

test("caml_curry supports partial application", function()
  local impl = function(a, b) return a .. b end
  local f = fun.caml_curry(2, impl)
  local partial = fun.caml_call_gen(f, {"hello"})
  assert(type(partial) == "table", "Should return table")
  local result = partial.f("world")
  assert(result == "helloworld", "Expected helloworld")
end)

-- Test caml_closure
test("caml_closure without environment", function()
  local impl = function(x) return x * x end
  local closure = fun.caml_closure(1, impl)
  assert(closure.l == 1, "Should have arity 1")
  local result = closure.f(7)
  assert(result == 49, "Expected 49, got " .. result)
end)

test("caml_closure with environment", function()
  local env = {base = 100}
  local impl = function(e, x) return e.base + x end
  local closure = fun.caml_closure(1, impl, env)
  assert(closure.l == 1, "Should have arity 1")
  local result = closure.f(42)
  assert(result == 142, "Expected 142, got " .. result)
end)

test("caml_closure with multiple free variables", function()
  local env = {a = 10, b = 20}
  local impl = function(e, x) return e.a + e.b + x end
  local closure = fun.caml_closure(1, impl, env)
  local result = closure.f(5)
  assert(result == 35, "Expected 35, got " .. result)
end)

-- Test complex currying scenarios
test("Curried function returning curried function", function()
  local add = {l = 2, f = function(x, y) return x + y end}
  local make_adder = {l = 1, f = function(x)
    return fun.caml_call_gen(add, {x})
  end}

  local add5 = make_adder.f(5)
  assert(type(add5) == "table", "Should return table")
  local result = add5.f(10)
  assert(result == 15, "Expected 15, got " .. result)
end)

test("Pipeline of partial applications", function()
  local f = {l = 4, f = function(a, b, c, d) return ((a + b) * c) - d end}
  local f1 = fun.caml_call_gen(f, {2})       -- f1 = f(2, _, _, _)
  local f2 = fun.caml_call_gen(f1, {3})      -- f2 = f(2, 3, _, _)
  local f3 = fun.caml_call_gen(f2, {4})      -- f3 = f(2, 3, 4, _)
  local result = fun.caml_call_gen(f3, {1})  -- result = f(2, 3, 4, 1)
  assert(result == 19, "Expected 19, got " .. result)  -- ((2+3)*4) - 1 = 19
end)

-- Test primitives registration
test("Primitives are registered", function()
  local core = require("core")
  assert(core.get_primitive("caml_call_gen") == fun.caml_call_gen, "caml_call_gen registered")
  assert(core.get_primitive("caml_apply") == fun.caml_apply, "caml_apply registered")
  assert(core.get_primitive("caml_curry") == fun.caml_curry, "caml_curry registered")
  assert(core.get_primitive("caml_closure") == fun.caml_closure, "caml_closure registered")
end)

-- Test module registration
test("Module is registered", function()
  local core = require("core")
  local mod = core.get_module("fun")
  assert(mod == fun, "fun module should be registered")
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
