#!/usr/bin/env lua
-- Comprehensive Lua 5.1 compatibility test for runtime modules
-- Tests global functions (not modules) per runtime implementation guidelines

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
  dofile("core.lua")
  assert(type(_G._OCAML) == "table", "_OCAML namespace should exist")
  assert(type(caml_register_global) == "function", "caml_register_global should exist")
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
  dofile("mlBytes.lua")  -- Load dependencies first (provides caml_bit_*)
  dofile("ints.lua")
  assert(type(caml_int32_xor) == "function", "caml_int32_xor should exist")
  assert(type(caml_int32_and) == "function", "caml_int32_and should exist")
  assert(type(caml_int32_or) == "function", "caml_int32_or should exist")
  -- Test bitwise operations
  assert(caml_int32_and(0xFF, 0x0F) == 0x0F, "int32_and failed")
  assert(caml_int32_or(0xF0, 0x0F) == 0xFF, "int32_or failed")
end)

-- Test 4: float.lua
results.float = test_module("float.lua", function()
  dofile("float.lua")
  assert(type(caml_modf_float) == "function", "caml_modf_float should exist")
  assert(type(caml_ldexp_float) == "function", "caml_ldexp_float should exist")
  assert(type(caml_is_finite) == "function", "caml_is_finite should exist")
  -- Test modf (returns a table, not multiple values)
  local modf_result = caml_modf_float(3.14)
  assert(modf_result[1] == 3, "modf int part failed")
  assert(math.abs(modf_result[2] - 0.14) < 0.001, "modf frac part failed")
  -- Test ldexp
  assert(caml_ldexp_float(1.5, 3) == 12, "ldexp failed")
  -- Test predicates (return booleans, not 0/1)
  assert(caml_is_finite(42) == true, "is_finite failed")
  assert(caml_is_infinite(math.huge) == true, "is_infinite failed")
end)

-- Test 5: mlBytes.lua
results.mlBytes = test_module("mlBytes.lua", function()
  dofile("mlBytes.lua")
  assert(type(caml_create_bytes) == "function", "caml_create_bytes should exist")
  assert(type(caml_ml_bytes_length) == "function", "caml_ml_bytes_length should exist")
  -- Test bytes creation and access
  local bytes = caml_create_bytes(10)
  assert(type(bytes) == "table", "create_bytes failed")
  assert(caml_ml_bytes_length(bytes) == 10, "bytes length failed")
end)

-- Test 6: array.lua
results.array = test_module("array.lua", function()
  dofile("array.lua")
  assert(type(caml_make_vect) == "function", "caml_make_vect should exist")
  assert(type(caml_array_get) == "function", "caml_array_get should exist")
  assert(type(caml_array_set) == "function", "caml_array_set should exist")
  -- Test array creation
  local arr = caml_make_vect(5, 42)
  assert(type(arr) == "table", "array creation failed")
  assert(arr[1] == 42, "array init failed")
  -- Test get/set
  caml_array_set(arr, 2, 100)
  assert(caml_array_get(arr, 2) == 100, "array set/get failed")
end)

-- Test 7: obj.lua
results.obj = test_module("obj.lua", function()
  dofile("obj.lua")
  assert(type(caml_fresh_oo_id) == "function", "caml_fresh_oo_id should exist")
  -- Test OO ID generation
  local id1 = caml_fresh_oo_id(0)
  local id2 = caml_fresh_oo_id(0)
  assert(type(id1) == "number", "fresh_oo_id should return number")
  assert(id2 > id1, "fresh_oo_id not incrementing")
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
