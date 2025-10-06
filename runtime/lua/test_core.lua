#!/usr/bin/env lua
-- Test suite for core.lua runtime module

local core = require("core")

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
  core.register("test_add1", test_prim)
  local retrieved = core.get_primitive("test_add1")
  assert(retrieved == test_prim, "Retrieved primitive should match registered")
  assert(retrieved(5) == 6, "Primitive should work correctly")
end)

test("Get undefined primitive throws error", function()
  local success = pcall(function()
    core.get_primitive("nonexistent_primitive")
  end)
  assert(not success, "Should throw error for undefined primitive")
end)

-- Test module registration
test("Register module", function()
  local test_mod = { foo = "bar" }
  core.register_module("TestModule", test_mod)
  local retrieved = core.get_module("TestModule")
  assert(retrieved == test_mod, "Retrieved module should match registered")
  assert(retrieved.foo == "bar", "Module fields should be accessible")
end)

test("Get undefined module returns nil", function()
  local result = core.get_module("NonexistentModule")
  assert(result == nil, "Should return nil for undefined module")
end)

-- Test OCaml values
test("Unit value", function()
  assert(core.unit == 0, "Unit should be 0")
end)

test("Boolean values", function()
  assert(core.false_val == 0, "false should be 0")
  assert(core.true_val == 1, "true should be 1")
end)

test("Boolean conversions", function()
  assert(core.ml_bool(true) == 1, "Lua true -> OCaml 1")
  assert(core.ml_bool(false) == 0, "Lua false -> OCaml 0")
  assert(core.lua_bool(1) == true, "OCaml 1 -> Lua true")
  assert(core.lua_bool(0) == false, "OCaml 0 -> Lua false")
  assert(core.lua_bool(42) == true, "OCaml non-zero -> Lua true")
end)

test("None value", function()
  assert(core.none == 0, "None should be 0")
  assert(core.is_none(core.none), "is_none should recognize None")
  assert(core.is_none(0), "is_none should recognize 0 as None")
  assert(not core.is_none(1), "is_none should reject non-zero")
  assert(not core.is_none({}), "is_none should reject tables")
end)

test("Some value", function()
  local some_val = core.some(42)
  assert(type(some_val) == "table", "Some should be a table")
  assert(some_val.tag == 0, "Some tag should be 0")
  assert(some_val[1] == 42, "Some should contain the value")
  assert(not core.is_none(some_val), "Some should not be None")
end)

-- Test block operations
test("Make block", function()
  local block = core.make_block(5, "a", "b", "c")
  assert(type(block) == "table", "Block should be a table")
  assert(block.tag == 5, "Block tag should be 5")
  assert(block[1] == "a", "Field 1 should be 'a'")
  assert(block[2] == "b", "Field 2 should be 'b'")
  assert(block[3] == "c", "Field 3 should be 'c'")
end)

test("Block tag", function()
  local block = core.make_block(7, 1, 2)
  assert(core.tag(block) == 7, "Should get correct tag")
  assert(core.tag(42) == nil, "Non-block should return nil tag")
  assert(core.tag("foo") == nil, "String should return nil tag")
end)

test("Block size", function()
  local block0 = core.make_block(0)
  local block3 = core.make_block(0, "a", "b", "c")
  assert(core.size(block0) == 0, "Empty block should have size 0")
  assert(core.size(block3) == 3, "Block with 3 fields should have size 3")
  assert(core.size(42) == 0, "Non-block should have size 0")
end)

-- Test version detection
test("Lua version detection", function()
  assert(type(core.lua_version) == "number", "lua_version should be a number")
  assert(core.lua_version >= 5.1, "Should support Lua 5.1+")
  assert(type(core.has_bitops) == "boolean", "has_bitops should be boolean")
  assert(type(core.has_utf8) == "boolean", "has_utf8 should be boolean")
  assert(type(core.has_integers) == "boolean", "has_integers should be boolean")
end)

test("Version info", function()
  local info = core.version_info()
  assert(type(info) == "table", "version_info should return table")
  assert(type(info.major) == "number", "Should have major version")
  assert(type(info.minor) == "number", "Should have minor version")
  assert(type(info.patch) == "number", "Should have patch version")
  assert(type(info.string) == "string", "Should have version string")
  assert(info.string == _OCAML.version, "Version string should match")
  assert(info.lua_version == core.lua_version, "Should include Lua version")
end)

-- Test core module is registered
test("Core module is self-registered", function()
  local core_mod = core.get_module("core")
  assert(core_mod == core, "Core should be registered as a module")
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
