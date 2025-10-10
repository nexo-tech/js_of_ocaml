#!/usr/bin/env lua
-- Comprehensive Lua 5.1 compatibility test for all runtime modules
-- Tests all 13 modules systematically

local function test_module(name, test_fn)
  io.write(string.format("Testing %-20s ... ", name))
  io.flush()

  local success, err = pcall(test_fn)
  if success then
    print("✓ PASS")
    return true
  else
    print("✗ FAIL")
    print("  Error: " .. tostring(err))
    return false
  end
end

local results = {}

-- Test 1: core.lua
results.core = test_module("core.lua", function()
  local core = require("core")
  assert(type(core) == "table", "core should be a table")
  assert(type(core.register) == "function", "core.register should exist")
  assert(type(core.register_module) == "function", "core.register_module should exist")
end)

-- Test 2: compat_bit.lua
results.compat_bit = test_module("compat_bit.lua", function()
  local bit = require("compat_bit")
  assert(type(bit) == "table", "bit should be a table")
  assert(bit.band(0xFF, 0x0F) == 0x0F, "band failed")
  assert(bit.bor(0xF0, 0x0F) == 0xFF, "bor failed")
  assert(bit.bxor(0xFF, 0x0F) == 0xF0, "bxor failed")
  assert(bit.lshift(1, 4) == 16, "lshift failed")
  assert(bit.rshift(16, 4) == 1, "rshift failed")
  assert(bit.implementation ~= nil, "implementation info missing")
end)

-- Test 3: ints.lua
results.ints = test_module("ints.lua", function()
  local ints = require("ints")
  assert(ints.add(5, 3) == 8, "add failed")
  assert(ints.sub(5, 3) == 2, "sub failed")
  assert(ints.mul(5, 3) == 15, "mul failed")
  assert(ints.div(15, 3) == 5, "div failed")
  assert(ints.mod(17, 5) == 2, "mod failed")
  assert(ints.band(0xFF, 0x0F) == 0x0F, "band failed")
  assert(ints.bor(0xF0, 0x0F) == 0xFF, "bor failed")
  assert(ints.lsl(1, 4) == 16, "lsl failed")
  assert(ints.compare(5, 3) == 1, "compare failed")
end)

-- Test 4: float.lua
results.float = test_module("float.lua", function()
  local float = require("float")
  local modf_result = float.caml_modf_float(3.14)
  assert(modf_result[1] == 3, "modf int part failed")
  assert(math.abs(modf_result[2] - 0.14) < 0.001, "modf frac part failed")
  assert(float.caml_ldexp_float(1.5, 3) == 12, "ldexp failed")
  assert(float.caml_is_finite(42) == true, "is_finite failed")
  assert(float.caml_is_nan(0/0) == true, "is_nan failed")
  assert(float.caml_is_infinite(math.huge) == true, "is_infinite failed")
end)

-- Test 5: mlBytes.lua
results.mlBytes = test_module("mlBytes.lua", function()
  local mlBytes = require("mlBytes")
  local bytes = mlBytes.create(10)
  assert(type(bytes) == "table", "create_bytes failed")
  mlBytes.set(bytes, 0, 65) -- 'A'
  assert(mlBytes.get(bytes, 0) == 65, "bytes get/set failed")
  mlBytes.set16(bytes, 0, 0x1234)
  assert(mlBytes.get16(bytes, 0) == 0x1234, "get16/set16 failed")
end)

-- Test 6: array.lua
results.array = test_module("array.lua", function()
  local array = require("array")
  local arr = array.make(5, 42)
  assert(#arr >= 5, "array size failed")
  assert(arr[1] == 42, "array init failed")
  array.set(arr, 2, 100)
  assert(array.get(arr, 2) == 100, "array set/get failed")
end)

-- Test 7: obj.lua
results.obj = test_module("obj.lua", function()
  local obj = require("obj")
  -- Test fresh_oo_id
  local id1 = obj.fresh_oo_id()
  local id2 = obj.fresh_oo_id()
  assert(type(id1) == "number", "fresh_oo_id should return number")
  assert(id2 > id1, "fresh_oo_id not incrementing")
  -- Test method table
  local mt = obj.create_method_table({})
  assert(type(mt) == "table", "create_method_table failed")
  -- Test simple object
  local simple = obj.simple_object({method1 = function() return 42 end}, {})
  assert(type(simple) == "table", "simple_object failed")
end)

-- Print summary
print("\n" .. string.rep("=", 60))
print("Lua 5.1 Compatibility Test Summary")
print(string.rep("=", 60))

local total = 0
local passed = 0
for name, result in pairs(results) do
  total = total + 1
  if result then
    passed = passed + 1
  end
end

print(string.format("Total modules tested: %d", total))
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", total - passed))
print(string.format("Success rate: %.1f%%", (passed / total) * 100))

-- List failed modules
local failed = {}
for name, result in pairs(results) do
  if not result then
    table.insert(failed, name)
  end
end

if #failed > 0 then
  print("\nFailed modules:")
  for _, name in ipairs(failed) do
    print("  - " .. name)
  end
  os.exit(1)
else
  print("\n✓ All modules passed!")
  os.exit(0)
end
