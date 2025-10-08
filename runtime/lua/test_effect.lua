#!/usr/bin/env lua
-- Test suite for effect.lua (OCaml 5 effect handlers using Lua coroutines)

local effect = require("effect")

-- Test framework
local tests_run = 0
local tests_passed = 0

local function test(name, fn)
  tests_run = tests_run + 1
  io.write("Testing " .. name .. " ... ")
  local success, err = pcall(fn)
  if success then
    tests_passed = tests_passed + 1
    print("✓")
  else
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
    error(msg or "Expected true")
  end
end

print("====================================================================")
print("Effect Handler Tests (effect.lua)")
print("====================================================================")
print("")

--
-- Stack Management Tests
--

print("Stack Management:")
print("--------------------------------------------------------------------")

test("get_current_stack returns stack", function()
  local stack = effect.get_current_stack()
  assert_true(stack ~= nil, "Stack should not be nil")
  assert_true(stack.k ~= nil, "Stack should have k field")
  assert_true(stack.x ~= nil, "Stack should have x field")
  assert_true(stack.h ~= nil, "Stack should have h field")
  assert_true(stack.e ~= nil, "Stack should have e field")
end)

test("save_stack and restore_stack work", function()
  local original = effect.get_current_stack()
  local saved = effect.save_stack()

  -- Modify current stack
  local stack = effect.get_current_stack()
  stack.k = 123

  -- Restore saved stack
  effect.restore_stack(saved)

  local restored = effect.get_current_stack()
  assert_eq(restored.k, original.k, "Stack should be restored")
end)

--
-- Exception Handler Tests
--

print("")
print("Exception Handlers:")
print("--------------------------------------------------------------------")

test("caml_push_trap adds handler", function()
  local handler_called = false
  local handler = function(x)
    handler_called = true
    return x
  end

  effect.caml_push_trap(handler)
  local popped = effect.caml_pop_trap()

  assert_eq(popped, handler, "Should return pushed handler")
end)

test("caml_pop_trap on empty stack returns error function", function()
  -- Ensure stack is empty by popping until we get error function
  local result
  for i = 1, 10 do
    result = effect.caml_pop_trap()
    if type(result) == "function" then
      -- Check if it's the error function by calling with safe value
      local success, err = pcall(result, "test")
      if not success then
        -- This is the error function
        break
      end
    end
  end

  assert_true(type(result) == "function", "Should return error function")
end)

test("caml_push_trap and caml_pop_trap maintain stack order", function()
  local handler1 = function() return 1 end
  local handler2 = function() return 2 end
  local handler3 = function() return 3 end

  effect.caml_push_trap(handler1)
  effect.caml_push_trap(handler2)
  effect.caml_push_trap(handler3)

  assert_eq(effect.caml_pop_trap(), handler3, "Should pop handler3 first")
  assert_eq(effect.caml_pop_trap(), handler2, "Should pop handler2 second")
  assert_eq(effect.caml_pop_trap(), handler1, "Should pop handler1 third")
end)

--
-- Fiber Stack Allocation Tests
--

print("")
print("Fiber Stack Allocation:")
print("--------------------------------------------------------------------")

test("caml_alloc_stack creates fiber with handlers", function()
  local hv = function(x) return x end
  local hx = function(e) error(e) end
  local hf = function(eff, cont) return cont end

  local stack = effect.caml_alloc_stack(hv, hx, hf)

  assert_true(stack ~= nil, "Stack should not be nil")
  assert_true(stack.k ~= nil, "Stack should have continuation")
  assert_true(stack.x ~= nil, "Stack should have exception stack")
  assert_true(stack.h ~= nil, "Stack should have handlers")
  assert_true(stack.e ~= nil, "Stack should have enclosing stack")
  assert_true(type(stack.h) == "table", "Handlers should be a table")
  assert_eq(#stack.h, 3, "Handlers should have 3 elements")
end)

test("caml_alloc_stack_disabled returns 0", function()
  local result = effect.caml_alloc_stack_disabled()
  assert_eq(result, 0, "Should return 0")
end)

--
-- Continuation Tests
--

print("")
print("Continuations:")
print("--------------------------------------------------------------------")

test("make_continuation creates continuation with tag 245", function()
  local stack = {k = 1, x = 0, h = 0, e = 0}
  local cont = effect.make_continuation(stack, stack)

  assert_true(cont ~= nil, "Continuation should not be nil")
  assert_eq(cont.tag, 245, "Continuation should have tag 245")
  assert_eq(cont[1], stack, "Continuation should reference stack")
  assert_eq(cont[2], stack, "Continuation should reference last fiber")
end)

test("caml_continuation_use_noexc marks continuation as used", function()
  local stack = {k = 1, x = 0, h = 0, e = 0}
  local cont = effect.make_continuation(stack, stack)

  local used_stack = effect.caml_continuation_use_noexc(cont)
  assert_eq(used_stack, stack, "Should return stack")
  assert_eq(cont[1], 0, "Continuation should be marked as used")

  -- Try to use again
  local used_again = effect.caml_continuation_use_noexc(cont)
  assert_eq(used_again, 0, "Should return 0 for used continuation")
end)

test("caml_continuation_use_and_update_handler_noexc updates handlers", function()
  local hv = function(x) return x end
  local hx = function(e) error(e) end
  local hf = function(eff, cont) return cont end
  local stack = effect.caml_alloc_stack(hv, hx, hf)

  local cont = effect.make_continuation(stack, stack)

  local new_hv = function(x) return x * 2 end
  local new_hx = function(e) return e end
  local new_hf = function(eff, cont) return eff end

  local used_stack = effect.caml_continuation_use_and_update_handler_noexc(
    cont, new_hv, new_hx, new_hf
  )

  assert_true(used_stack ~= 0, "Should return stack")
  assert_eq(stack.h[1], new_hv, "Value handler should be updated")
  assert_eq(stack.h[2], new_hx, "Exception handler should be updated")
  assert_eq(stack.h[3], new_hf, "Effect handler should be updated")
end)

--
-- Effect Operations Tests
--

print("")
print("Effect Operations:")
print("--------------------------------------------------------------------")

test("caml_raise_unhandled raises error", function()
  local success = pcall(function()
    effect.caml_raise_unhandled({type = "Test"})
  end)

  assert_true(not success, "Should raise error for unhandled effect")
end)

test("caml_perform_effect raises error without handler", function()
  local saved = effect.save_stack()

  local success = pcall(function()
    effect.caml_perform_effect({type = "Test"}, function(x) return x end)
  end)

  effect.restore_stack(saved)

  assert_true(not success, "Should raise error without handler")
end)

test("caml_resume_stack raises error for already-used continuation", function()
  local success = pcall(function()
    effect.caml_resume_stack(0, 0, function(x) return x end)
  end)

  assert_true(not success, "Should raise error for 0 stack")
end)

--
-- Coroutine Integration Tests
--

print("")
print("Coroutine Integration:")
print("--------------------------------------------------------------------")

test("with_coroutine creates coroutine", function()
  local f = function(x) return x * 2 end
  local co = effect.with_coroutine(f)

  assert_true(type(co) == "thread", "Should create coroutine")
  assert_eq(coroutine.status(co), "suspended", "Should be suspended")
end)

test("fiber_yield returns value when no parent", function()
  local saved = effect.save_stack()
  local stack = effect.get_current_stack()
  stack.e = 0  -- No parent

  local result = effect.fiber_yield(42)
  assert_eq(result, 42, "Should return value when no parent")

  effect.restore_stack(saved)
end)

test("fiber_resume resumes coroutine", function()
  local co = coroutine.create(function(x)
    return x + 10
  end)

  local result = effect.fiber_resume(co, 32)
  assert_eq(result, 42, "Should resume coroutine and return result")
end)

test("fiber_resume raises error for dead coroutine", function()
  local co = coroutine.create(function(x)
    return x
  end)

  -- Run to completion
  coroutine.resume(co, 1)

  local success = pcall(function()
    effect.fiber_resume(co, 2)
  end)

  assert_true(not success, "Should raise error for dead coroutine")
end)

--
-- Utility Tests
--

print("")
print("Utilities:")
print("--------------------------------------------------------------------")

test("effects_supported returns true", function()
  assert_true(effect.effects_supported(), "Effects should be supported in Lua")
end)

test("caml_get_continuation_callstack returns empty list", function()
  local result = effect.caml_get_continuation_callstack()
  assert_true(type(result) == "table", "Should return table")
  assert_eq(result.tag, 0, "Should be empty list (tag 0)")
end)

--
-- Condition Variable Tests
--

print("")
print("Condition Variables:")
print("--------------------------------------------------------------------")

test("caml_ml_condition_new creates condition", function()
  local cond = effect.caml_ml_condition_new()
  assert_true(cond ~= nil, "Should create condition")
  assert_true(cond.condition ~= nil, "Should have condition field")
end)

test("caml_ml_condition_wait returns 0", function()
  local result = effect.caml_ml_condition_wait()
  assert_eq(result, 0, "Should return 0")
end)

test("caml_ml_condition_broadcast returns 0", function()
  local result = effect.caml_ml_condition_broadcast()
  assert_eq(result, 0, "Should return 0")
end)

test("caml_ml_condition_signal returns 0", function()
  local result = effect.caml_ml_condition_signal()
  assert_eq(result, 0, "Should return 0")
end)

--
-- Error Handling Tests
--

print("")
print("Error Handling:")
print("--------------------------------------------------------------------")

test("jsoo_effect_not_supported raises error", function()
  local success = pcall(function()
    effect.jsoo_effect_not_supported()
  end)

  assert_true(not success, "Should raise error")
end)

--
-- Summary
--

print("")
print("====================================================================")
print("Tests passed: " .. tests_passed .. " / " .. tests_run)
if tests_passed == tests_run then
  print("All tests passed! ✓")
  print("====================================================================")
  os.exit(0)
else
  print("Some tests failed.")
  print("====================================================================")
  os.exit(1)
end
