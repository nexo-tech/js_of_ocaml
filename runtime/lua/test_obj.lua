#!/usr/bin/env lua
-- Test suite for obj.lua object system module

dofile("core.lua")
dofile("obj.lua")

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

-- Test fresh OO ID generation
test("Fresh OO ID generation", function()
  local id1 = caml_fresh_oo_id()
  local id2 = caml_fresh_oo_id()
  local id3 = caml_fresh_oo_id()
  assert(id2 == id1 + 1, "IDs should increment")
  assert(id3 == id2 + 1, "IDs should increment")
end)

-- Test set OO ID
test("Set OO ID on block", function()
  local block = {}
  caml_set_oo_id(block)
  assert(type(block[2]) == "number", "Should set ID at index 2")
  assert(block[2] > 0, "ID should be positive")
end)

-- Test create method table
test("Create method table", function()
  local methods = {
    {10, function() return "method_10" end},
    {20, function() return "method_20" end},
    {30, function() return "method_30" end}
  }
  local method_table = create_method_table(methods)
  assert(method_table[1] == 3, "Should have 3 methods")
  assert(method_table[3] ~= nil, "Should have method at index 3")
  assert(method_table[4] == 10, "Should have tag 10 at index 4")
  assert(method_table[5] ~= nil, "Should have method at index 5")
  assert(method_table[6] == 20, "Should have tag 20 at index 6")
end)

-- Test get public method with single method
test("Get public method - single method", function()
  local methods = {
    {100, function() return "hello" end}
  }
  local method_table = create_method_table(methods)
  local test_obj = {[1] = method_table}

  local method = caml_get_public_method(test_obj, 100)
  assert(method ~= nil, "Should find method")
  assert(method() == "hello", "Should call method correctly")
end)

-- Test get public method with multiple methods
test("Get public method - multiple methods", function()
  local methods = {
    {10, function() return "first" end},
    {20, function() return "second" end},
    {30, function() return "third" end},
    {40, function() return "fourth" end},
    {50, function() return "fifth" end}
  }
  local method_table = create_method_table(methods)
  local test_obj = {[1] = method_table}

  local m1 = caml_get_public_method(test_obj, 10)
  assert(m1() == "first", "Should find first method")

  local m3 = caml_get_public_method(test_obj, 30)
  assert(m3() == "third", "Should find middle method")

  local m5 = caml_get_public_method(test_obj, 50)
  assert(m5() == "fifth", "Should find last method")
end)

-- Test get public method - not found
test("Get public method - not found", function()
  local methods = {
    {10, function() return "a" end},
    {20, function() return "b" end}
  }
  local method_table = create_method_table(methods)
  local test_obj = {[1] = method_table}

  local method = caml_get_public_method(test_obj, 15)
  assert(method == nil, "Should return nil for non-existent method")
end)

-- Test create object
test("Create object", function()
  local methods = {
    {100, function(self) return self[3] end}  -- method that returns first instance var
  }
  local method_table = create_method_table(methods)
  local instance_vars = {42, "hello"}

  local o = create_object(method_table, instance_vars)
  assert(o[1] == method_table, "Should have method table")
  assert(type(o[2]) == "number", "Should have object ID")
  assert(o[3] == 42, "Should have first instance var")
  assert(o[4] == "hello", "Should have second instance var")
end)

-- Test object raw field access
test("Object raw field access", function()
  local methods = create_method_table({})
  local o = create_object(methods, {10, 20, 30})

  assert(caml_obj_raw_field(o, 0) == 10, "Should get field 0")
  assert(caml_obj_raw_field(o, 1) == 20, "Should get field 1")
  assert(caml_obj_raw_field(o, 2) == 30, "Should get field 2")
end)

-- Test object raw field set
test("Object raw field set", function()
  local methods = create_method_table({})
  local o = create_object(methods, {10, 20, 30})

  caml_obj_set_raw_field(o, 0, 100)
  assert(caml_obj_raw_field(o, 0) == 100, "Should set field 0")

  caml_obj_set_raw_field(o, 1, 200)
  assert(caml_obj_raw_field(o, 1) == 200, "Should set field 1")
end)

-- Test call method
test("Call method on object", function()
  local methods = {
    {100, function(self, x) return self[3] + x end}
  }
  local method_table = create_method_table(methods)
  local o = create_object(method_table, {10})

  local result = call_method(o, 100, {5})
  assert(result == 15, "Should call method with self and args")
end)

-- Test method with no args
test("Call method with no args", function()
  local methods = {
    {200, function(self) return self[3] * 2 end}
  }
  local method_table = create_method_table(methods)
  local o = create_object(method_table, {7})

  local result = call_method(o, 200, {})
  assert(result == 14, "Should call method with just self")
end)

-- Test method with multiple args
test("Call method with multiple args", function()
  local methods = {
    {300, function(self, a, b, c) return self[3] + a + b + c end}
  }
  local method_table = create_method_table(methods)
  local o = create_object(method_table, {1})

  local result = call_method(o, 300, {2, 3, 4})
  assert(result == 10, "Should call method with multiple args")
end)

-- Test simple object creation
test("Simple object creation", function()
  local method_map = {
    get_x = function(self) return self[3] end,
    set_x = function(self, val) self[3] = val end,
    double = function(self) return self[3] * 2 end
  }

  local o = simple_object(method_map, {5})
  assert(o[1] ~= nil, "Should have method table")
  assert(o[2] ~= nil, "Should have object ID")
  assert(o[3] == 5, "Should have instance variable")
end)

-- Test object with multiple instance variables
test("Object with multiple instance variables", function()
  local methods = {
    {1, function(self) return self[3] end},
    {2, function(self) return self[4] end},
    {3, function(self) return self[5] end}
  }
  local method_table = create_method_table(methods)
  local o = create_object(method_table, {"a", "b", "c"})

  assert(call_method(o, 1, {}) == "a", "Should access first var")
  assert(call_method(o, 2, {}) == "b", "Should access second var")
  assert(call_method(o, 3, {}) == "c", "Should access third var")
end)

-- Test method table binary search with many methods
test("Binary search with many methods", function()
  local methods = {}
  for i = 1, 20 do
    local tag = i * 10
    table.insert(methods, {tag, function() return tag end})
  end

  local method_table = create_method_table(methods)
  local o = {[1] = method_table}

  -- Test finding first, middle, and last
  local m1 = caml_get_public_method(o, 10)
  assert(m1() == 10, "Should find first method")

  local m10 = caml_get_public_method(o, 100)
  assert(m10() == 100, "Should find middle method")

  local m20 = caml_get_public_method(o, 200)
  assert(m20() == 200, "Should find last method")
end)

-- Test that primitives are defined
test("Primitives are defined", function()
  assert(type(caml_get_public_method) == "function", "caml_get_public_method defined")
  assert(type(caml_fresh_oo_id) == "function", "caml_fresh_oo_id defined")
  assert(type(caml_set_oo_id) == "function", "caml_set_oo_id defined")
  assert(type(caml_obj_raw_field) == "function", "caml_obj_raw_field defined")
  assert(type(caml_obj_set_raw_field) == "function", "caml_obj_set_raw_field defined")
end)

-- Test that helper functions are defined
test("Helper functions are defined", function()
  assert(type(create_method_table) == "function", "create_method_table defined")
  assert(type(create_object) == "function", "create_object defined")
  assert(type(call_method) == "function", "call_method defined")
  assert(type(simple_object) == "function", "simple_object defined")
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
