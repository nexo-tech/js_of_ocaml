#!/usr/bin/env lua
-- Test suite for fail.lua exception handling module

local fail = require("fail")

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

-- Test exception registration
test("Register exception", function()
  local exc = fail.register_exception("TestException", 248, -100)
  assert(exc.tag == 248, "Exception should have tag 248")
  assert(exc[1] == "TestException", "Exception should have name")
  assert(exc[2] == -100, "Exception should have id")
end)

test("Get registered exception", function()
  fail.register_exception("MyException", 248, -101)
  local exc = fail.get_exception("MyException")
  assert(exc ~= nil, "Should retrieve registered exception")
  assert(exc[1] == "MyException", "Should have correct name")
end)

test("Get unregistered exception", function()
  local exc = fail.get_exception("NonexistentException")
  assert(exc == nil, "Should return nil for unregistered exception")
end)

-- Test raising constant exceptions
test("Raise constant exception", function()
  local exc = fail.register_exception("ConstExc", 248, -102)
  local caught = false
  local success, result = pcall(function()
    fail.raise_constant(exc)
  end)
  assert(not success, "Should raise exception")
  assert(result == exc, "Should catch the exception")
end)

-- Test raising exceptions with arguments
test("Raise exception with single argument", function()
  local exc = fail.register_exception("ArgExc", 248, -103)
  local success, result = pcall(function()
    fail.raise_with_arg(exc, "error message")
  end)
  assert(not success, "Should raise exception")
  assert(result.tag == 0, "Exception value should have tag 0")
  assert(result[1] == exc, "Should have exception constructor")
  assert(result[2] == "error message", "Should have argument")
end)

test("Raise exception with multiple arguments", function()
  local exc = fail.register_exception("MultiArgExc", 248, -104)
  local success, result = pcall(function()
    fail.raise_with_args(exc, {1, 2, 3})
  end)
  assert(not success, "Should raise exception")
  assert(result[1] == exc, "Should have exception constructor")
  assert(result[2] == 1, "Should have first arg")
  assert(result[3] == 2, "Should have second arg")
  assert(result[4] == 3, "Should have third arg")
end)

-- Test predefined exceptions
test("Failwith exception", function()
  local success, result = pcall(function()
    fail.failwith("test failure")
  end)
  assert(not success, "Should raise Failure")
  assert(result[2] == "test failure", "Should have message")
end)

test("Invalid_argument exception", function()
  local success, result = pcall(function()
    fail.invalid_argument("bad argument")
  end)
  assert(not success, "Should raise Invalid_argument")
  assert(result[2] == "bad argument", "Should have message")
end)

test("Not_found exception", function()
  local success, result = pcall(function()
    fail.raise_not_found()
  end)
  assert(not success, "Should raise Not_found")
end)

test("End_of_file exception", function()
  local success, result = pcall(function()
    fail.raise_end_of_file()
  end)
  assert(not success, "Should raise End_of_file")
end)

test("Division_by_zero exception", function()
  local success, result = pcall(function()
    fail.raise_zero_divide()
  end)
  assert(not success, "Should raise Division_by_zero")
end)

test("Sys_error exception", function()
  local success, result = pcall(function()
    fail.raise_sys_error("system error")
  end)
  assert(not success, "Should raise Sys_error")
  assert(result[2] == "system error", "Should have message")
end)

-- Test exception checking
test("Is exception - constant", function()
  local exc = fail.register_exception("TestExc1", 248, -105)
  assert(fail.is_exception(exc), "Exception constructor should be recognized")
end)

test("Is exception - with argument", function()
  local exc = fail.register_exception("TestExc2", 248, -106)
  local success, exc_value = pcall(function()
    fail.raise_with_arg(exc, "msg")
  end)
  assert(fail.is_exception(exc_value), "Exception value should be recognized")
end)

test("Is exception - not an exception", function()
  assert(not fail.is_exception(42), "Number should not be exception")
  assert(not fail.is_exception("string"), "String should not be exception")
  assert(not fail.is_exception({tag = 1}), "Regular block should not be exception")
end)

-- Test exception name
test("Exception name - constant", function()
  local exc = fail.register_exception("NamedExc", 248, -107)
  assert(fail.exception_name(exc) == "NamedExc", "Should get exception name")
end)

test("Exception name - with argument", function()
  local success, exc_value = pcall(function()
    fail.failwith("test")
  end)
  assert(fail.exception_name(exc_value) == "Failure", "Should get Failure name")
end)

test("Exception name - unknown", function()
  assert(fail.exception_name(42) == "Unknown", "Non-exception should return Unknown")
  assert(fail.exception_name({}) == "Unknown", "Non-exception table should return Unknown")
end)

-- Test exception to string
test("Exception to string - constant", function()
  local exc = fail.register_exception("MyExc", 248, -108)
  assert(fail.exception_to_string(exc) == "MyExc", "Should convert to string")
end)

test("Exception to string - with message", function()
  local success, exc_value = pcall(function()
    fail.failwith("error message")
  end)
  local str = fail.exception_to_string(exc_value)
  assert(str == "Failure(error message)", "Should include message")
end)

-- Test try_catch
test("Try catch - success", function()
  local success, result = fail.try_catch(function()
    return 42
  end)
  assert(success, "Should succeed")
  assert(result == 42, "Should return result")
end)

test("Try catch - exception", function()
  local success, result = fail.try_catch(function()
    fail.failwith("error")
  end)
  assert(not success, "Should fail")
  assert(fail.is_exception(result), "Should catch exception")
end)

-- Test catch with handler
test("Catch with handler - success", function()
  local result = fail.catch(
    function() return 100 end,
    function(exc) return -1 end
  )
  assert(result == 100, "Should return success result")
end)

test("Catch with handler - exception", function()
  local result = fail.catch(
    function() fail.failwith("error") end,
    function(exc) return 999 end
  )
  assert(result == 999, "Should return handler result")
end)

-- Test try_finally
test("Try finally - success", function()
  local cleanup_called = false
  local result = fail.try_finally(
    function() return 42 end,
    function() cleanup_called = true end
  )
  assert(result == 42, "Should return result")
  assert(cleanup_called, "Should call cleanup")
end)

test("Try finally - exception", function()
  local cleanup_called = false
  local success, result = pcall(function()
    fail.try_finally(
      function() fail.failwith("error") end,
      function() cleanup_called = true end
    )
  end)
  assert(not success, "Should propagate exception")
  assert(cleanup_called, "Should call cleanup even on exception")
end)

-- Test multiple exception types
test("Different exception types", function()
  -- Raise different exceptions and verify they're distinct
  local failures = {}

  local s1, r1 = pcall(function() fail.failwith("msg1") end)
  local s2, r2 = pcall(function() fail.invalid_argument("msg2") end)
  local s3, r3 = pcall(function() fail.raise_not_found() end)

  assert(fail.exception_name(r1) == "Failure", "First should be Failure")
  assert(fail.exception_name(r2) == "Invalid_argument", "Second should be Invalid_argument")
  assert(fail.exception_name(r3) == "Not_found", "Third should be Not_found")
end)

-- Test nested exception handling
test("Nested exception handling", function()
  local result = fail.catch(
    function()
      return fail.catch(
        function() fail.failwith("inner") end,
        function(exc) return "caught inner" end
      )
    end,
    function(exc) return "caught outer" end
  )
  assert(result == "caught inner", "Should catch inner exception")
end)

-- Test exception propagation
test("Exception propagation", function()
  local function level3()
    fail.failwith("deep error")
  end

  local function level2()
    level3()
  end

  local function level1()
    level2()
  end

  local success, exc = pcall(level1)
  assert(not success, "Should propagate through call stack")
  assert(fail.exception_name(exc) == "Failure", "Should preserve exception type")
end)

-- Test primitives registration
test("Primitives are registered", function()
  local core = require("core")
  assert(core.get_primitive("caml_failwith") == fail.failwith, "failwith registered")
  assert(core.get_primitive("caml_invalid_argument") == fail.invalid_argument, "invalid_argument registered")
  assert(core.get_primitive("caml_raise_not_found") == fail.raise_not_found, "raise_not_found registered")
end)

-- Test module registration
test("Module is registered", function()
  local core = require("core")
  local mod = core.get_module("fail")
  assert(mod == fail, "fail module should be registered")
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
