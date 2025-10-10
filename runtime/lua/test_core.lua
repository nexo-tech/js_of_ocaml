#!/usr/bin/env lua
-- Test suite for core.lua runtime primitives

-- Load core.lua directly (it defines global caml_* functions)
dofile("core.lua")

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

-- Test global namespace
test("Global _OCAML namespace exists", function()
  assert(_OCAML ~= nil, "_OCAML should be initialized")
  assert(type(_OCAML) == "table", "_OCAML should be a table")
  assert(_OCAML.primitives ~= nil, "_OCAML.primitives should exist")
  assert(_OCAML.modules ~= nil, "_OCAML.modules should exist")
  assert(_OCAML.version ~= nil, "_OCAML.version should exist")
end)

-- Test initialization
test("Runtime is initialized", function()
  assert(_OCAML.initialized == true, "Runtime should be initialized")
end)

-- Test primitive registration
test("Register primitive function", function()
  local test_prim = function(x) return x + 1 end
  caml_register_global("test_add1", test_prim)
  local retrieved = caml_get_primitive("test_add1")
  assert(retrieved == test_prim, "Retrieved primitive should match registered")
  assert(retrieved(5) == 6, "Primitive should work correctly")
end)

test("Get undefined primitive throws error", function()
  local success = pcall(function()
    caml_get_primitive("nonexistent_primitive")
  end)
  assert(not success, "Should throw error for undefined primitive")
end)

-- Test module registration
test("Register module", function()
  local test_mod = { foo = "bar" }
  caml_register_module("TestModule", test_mod)
  local retrieved = caml_get_module("TestModule")
  assert(retrieved == test_mod, "Retrieved module should match registered")
  assert(retrieved.foo == "bar", "Module fields should be accessible")
end)

test("Get undefined module returns nil", function()
  local result = caml_get_module("NonexistentModule")
  assert(result == nil, "Should return nil for undefined module")
end)

-- Test OCaml values
test("Unit value", function()
  assert(caml_unit == 0, "Unit should be 0")
end)

test("Boolean values", function()
  assert(caml_false_val == 0, "false should be 0")
  assert(caml_true_val == 1, "true should be 1")
end)

test("Boolean conversions", function()
  assert(caml_ml_bool(true) == 1, "Lua true -> OCaml 1")
  assert(caml_ml_bool(false) == 0, "Lua false -> OCaml 0")
  assert(caml_lua_bool(1) == true, "OCaml 1 -> Lua true")
  assert(caml_lua_bool(0) == false, "OCaml 0 -> Lua false")
  assert(caml_lua_bool(42) == true, "OCaml non-zero -> Lua true")
end)

test("None value", function()
  assert(caml_none == 0, "None should be 0")
  assert(caml_is_none(caml_none), "is_none should recognize None")
  assert(caml_is_none(0), "is_none should recognize 0 as None")
  assert(not caml_is_none(1), "is_none should reject non-zero")
  assert(not caml_is_none({}), "is_none should reject tables")
end)

test("Some value", function()
  local some_val = caml_some(42)
  assert(type(some_val) == "table", "Some should be a table")
  assert(some_val.tag == 0, "Some tag should be 0")
  assert(some_val[1] == 42, "Some should contain the value")
  assert(not caml_is_none(some_val), "Some should not be None")
end)

-- Test block operations
test("Make block", function()
  local block = caml_make_block(5, "a", "b", "c")
  assert(type(block) == "table", "Block should be a table")
  assert(block.tag == 5, "Block tag should be 5")
  assert(block[1] == "a", "Field 1 should be 'a'")
  assert(block[2] == "b", "Field 2 should be 'b'")
  assert(block[3] == "c", "Field 3 should be 'c'")
end)

test("Block tag", function()
  local block = caml_make_block(7, 1, 2)
  assert(caml_tag(block) == 7, "Should get correct tag")
  assert(caml_tag(42) == nil, "Non-block should return nil tag")
  assert(caml_tag("foo") == nil, "String should return nil tag")
end)

test("Block size", function()
  local block0 = caml_make_block(0)
  local block3 = caml_make_block(0, "a", "b", "c")
  assert(caml_size(block0) == 0, "Empty block should have size 0")
  assert(caml_size(block3) == 3, "Block with 3 fields should have size 3")
  assert(caml_size(42) == 0, "Non-block should have size 0")
end)

test("Ref set", function()
  local ref = caml_make_block(0, 42)
  assert(ref[1] == 42, "Initial ref value should be 42")
  caml_ref_set(ref, 100)
  assert(ref[1] == 100, "Ref value should be updated to 100")
end)

-- Test version detection
test("Lua version detection", function()
  assert(type(caml_lua_version) == "number", "lua_version should be a number")
  assert(caml_lua_version >= 5.1, "Should support Lua 5.1+")
  assert(type(caml_has_bitops) == "boolean", "has_bitops should be boolean")
  assert(type(caml_has_utf8) == "boolean", "has_utf8 should be boolean")
  assert(type(caml_has_integers) == "boolean", "has_integers should be boolean")
end)

test("Version info", function()
  local info = caml_version_info()
  assert(type(info) == "table", "version_info should return table")
  assert(type(info.major) == "number", "Should have major version")
  assert(type(info.minor) == "number", "Should have minor version")
  assert(type(info.patch) == "number", "Should have patch version")
  assert(type(info.string) == "string", "Should have version string")
  assert(info.string == _OCAML.version, "Version string should match")
  assert(info.lua_version == caml_lua_version, "Should include Lua version")
end)

-- Test core module is registered for compatibility
test("Core module is registered for compatibility", function()
  local core_mod = caml_get_module("core")
  assert(core_mod ~= nil, "Core should be registered as a module")
  assert(core_mod.unit == caml_unit, "Core module should have unit")
  assert(core_mod.false_val == caml_false_val, "Core module should have false_val")
  assert(core_mod.true_val == caml_true_val, "Core module should have true_val")
  assert(core_mod.none == caml_none, "Core module should have none")
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
