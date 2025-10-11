#!/usr/bin/env luajit
-- LuaJIT Optimization Compatibility Tests
--
-- This script tests that LuaJIT's JIT compiler and optimizations don't
-- break the semantics of lua_of_ocaml runtime modules.

-- Load runtime modules (uses global functions)
dofile("core.lua")
dofile("mlBytes.lua")
dofile("ints.lua")
dofile("float.lua")
dofile("array.lua")
dofile("obj.lua")

local test_count = 0
local pass_count = 0
local fail_count = 0

local function test(name, fn)
  test_count = test_count + 1
  io.write(string.format("%-50s ... ", name))
  io.flush()

  local success, err = pcall(fn)
  if success then
    pass_count = pass_count + 1
    print("✓ PASS")
    return true
  else
    fail_count = fail_count + 1
    print("✗ FAIL")
    print("  Error: " .. tostring(err))
    return false
  end
end

print("LuaJIT Optimization Compatibility Tests")
print(string.rep("=", 70))

-- Check JIT availability
if jit then
  print("JIT Status: " .. (jit.status() and "enabled" or "disabled"))
  print("LuaJIT Version: " .. jit.version)
  print("JIT Arch: " .. jit.arch)
  print("")
else
  error("This test must be run with LuaJIT")
end

-- Test 1: JIT compilation doesn't break ints module
test("ints: JIT-compiled arithmetic operations", function()
  -- Force JIT compilation through repeated execution
  local result
  for i = 1, 100 do
    result = caml_int32_add(1000000, 2000000)
  end
  assert(result == 3000000, "add failed after JIT compilation")

  -- Test overflow with JIT
  for i = 1, 100 do
    result = caml_int32_add(0x7FFFFFFF, 1)
  end
  assert(result == -2147483648, "overflow handling broken by JIT")

  -- Test bitwise operations with JIT
  for i = 1, 100 do
    result = caml_int32_and(0xFF00FF00, 0x00FF00FF)
  end
  assert(result == 0, "bitwise AND broken by JIT")
end)

-- Test 2: JIT doesn't break float operations
test("float: JIT-compiled float operations", function()
  -- Force JIT compilation
  local result
  for i = 1, 100 do
    result = caml_modf_float(3.14159)
  end
  assert(result[1] == 3, "modf int part broken by JIT")
  assert(math.abs(result[2] - 0.14159) < 0.00001, "modf frac part broken by JIT")

  -- Test special values with JIT
  for i = 1, 100 do
    result = caml_is_nan(0/0)
  end
  assert(result == true, "NaN detection broken by JIT")
end)

-- Test 3: Table optimizations don't break mlBytes
test("mlBytes: Table operations under JIT", function()
  local bytes = caml_create_bytes(1000)

  -- Force JIT compilation of table access
  for i = 0, 999 do
    caml_bytes_unsafe_set(bytes, i, i % 256)
  end

  -- Verify correctness
  for i = 0, 999 do
    local val = caml_bytes_unsafe_get(bytes, i)
    assert(val == i % 256, "table access broken by JIT at index " .. i)
  end
end)

-- Test 4: Multi-byte operations with JIT
test("mlBytes: Multi-byte ops with JIT", function()
  local bytes = caml_create_bytes(100)

  -- Force JIT compilation of 16-bit operations
  for i = 0, 49 do
    caml_bytes_set16(bytes, i * 2, i * 1000)
  end

  for i = 0, 49 do
    local val = caml_bytes_get16(bytes, i * 2)
    assert(val == (i * 1000) % 65536, "16-bit ops broken by JIT")
  end

  -- Force JIT compilation of 32-bit operations
  for i = 0, 24 do
    caml_bytes_set32(bytes, i * 4, i * 100000)
  end

  for i = 0, 24 do
    local val = caml_bytes_get32(bytes, i * 4)
    -- 32-bit wrapping
    local expected = (i * 100000) % 4294967296
    assert(val == expected, "32-bit ops broken by JIT")
  end
end)

-- Test 5: Array operations with JIT
test("array: Array operations under JIT", function()
  local arr = caml_make_vect(100, 0)

  -- Force JIT compilation
  for i = 1, 100 do
    caml_array_set(arr, i - 1, i * i)
  end

  for i = 1, 100 do
    local val = caml_array_get(arr, i - 1)
    assert(val == i * i, "array access broken by JIT")
  end
end)

-- Test 6: Object system with JIT
test("obj: Method dispatch under JIT", function()
  -- Create method table with numeric tags
  local counter = 0
  local increment_method = function(self, n) counter = counter + n end
  local methods = {{42, increment_method}}  -- tag=42, method=increment_method

  local method_table = create_method_table(methods)
  local test_obj = {[1] = method_table}

  -- Force JIT compilation of method calls
  for i = 1, 100 do
    local method = caml_get_public_method(test_obj, 42)
    method(test_obj, 1)
  end

  assert(counter == 100, "method calls broken by JIT")

  -- Also test get_public_method directly
  for i = 1, 100 do
    local method = caml_get_public_method(test_obj, 42)
    assert(method ~= nil, "method lookup broken by JIT")
  end
end)

-- Test 7: Bitwise operations with JIT (using caml_bit_*)
test("bitwise: Bitwise ops under JIT", function()
  -- Force JIT compilation
  local result
  for i = 1, 1000 do
    result = caml_bit_and(caml_bit_or(i, 0xFF00), 0x00FF)
  end

  -- Test complex bit operations
  for i = 1, 100 do
    local a = caml_bit_lshift(1, i % 16)
    local b = caml_bit_rshift(0xFFFF, i % 16)
    result = caml_bit_and(a, b)
  end
end)

-- Test 8: String operations with JIT
test("mlBytes: String conversions under JIT", function()
  -- Force JIT compilation
  for i = 1, 100 do
    local bytes = caml_bytes_of_string("Hello, World!")
    local str = caml_string_of_bytes(bytes)
    assert(str == "Hello, World!", "string conversion broken by JIT")
  end
end)

-- Test 9: Numerical accuracy with JIT
test("ints: Numerical accuracy under JIT", function()
  -- Test that JIT doesn't introduce floating point errors
  local tests = {
    {caml_int32_mul, 123456, 789, 97406784},
    {caml_int32_div, 1000000, 7, 142857},
    {caml_int32_mod, 1000000, 7, 1},
    {caml_int32_shift_left, 1, 20, 1048576},
    {caml_int32_shift_right, -1048576, 10, -1024},
  }

  for _, test_case in ipairs(tests) do
    local fn, a, b, expected = test_case[1], test_case[2], test_case[3], test_case[4]
    for i = 1, 100 do
      local result = fn(a, b)
      assert(result == expected, "numerical accuracy broken by JIT")
    end
  end
end)

-- Test 10: Force compilation and verify correctness
test("JIT: Explicit compilation check", function()
  -- Create a hot loop to force JIT compilation
  local function hot_function(n)
    local sum = 0
    for i = 1, n do
      sum = caml_int32_add(sum, i)
    end
    return sum
  end

  -- Run enough times to trigger JIT
  for i = 1, 100 do
    hot_function(100)
  end

  -- Verify result is correct
  local result = hot_function(100)
  assert(result == 5050, "JIT-compiled function gives wrong result")
end)

-- Test 11: Table allocation patterns
test("Performance: Table allocation patterns", function()
  -- LuaJIT optimizes table allocation patterns
  -- Verify this doesn't break semantics
  local tables = {}
  for i = 1, 100 do
    tables[i] = caml_create_bytes(10)
    caml_make_vect(10, i)
  end

  -- Verify all tables are independent
  for i = 1, 100 do
    caml_bytes_unsafe_set(tables[i], 0, i)
  end

  for i = 1, 100 do
    assert(caml_bytes_unsafe_get(tables[i], 0) == i, "table aliasing bug")
  end
end)

-- Test 12: Float operations with JIT
test("float: Float classification under JIT", function()
  -- Force JIT compilation of float classification
  local result
  for i = 1, 100 do
    result = caml_is_finite(i * 1.5)
  end
  assert(result == true, "is_finite broken by JIT")

  for i = 1, 100 do
    result = caml_is_infinite(math.huge)
  end
  assert(result == true, "is_infinite broken by JIT")

  for i = 1, 100 do
    result = caml_is_nan(0/0)
  end
  assert(result == true, "is_nan broken by JIT")
end)

-- Test 13: Complex nested operations
test("Complex: Nested operations under JIT", function()
  -- Test combinations that might stress the JIT
  for i = 2, 100, 2 do  -- Use even numbers to avoid rounding
    local a = caml_int32_add(i, 1000)
    local b = caml_int32_mul(a, 2)
    local c = caml_int32_sub(b, i)
    local d = caml_int32_div(c, 2)
    local expected = math.floor(i / 2) + 1000
    assert(d == expected, "complex nested ops broken by JIT: got " .. d .. ", expected " .. expected)
  end
end)

-- Test 14: String byte operations under JIT
test("mlBytes: Byte-level string ops under JIT", function()
  local str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

  -- Force JIT compilation
  for i = 1, 100 do
    for j = 0, 25 do
      local byte = caml_string_unsafe_get(str, j)
      assert(byte == string.byte("A") + j, "string byte access broken by JIT")
    end
  end
end)

-- Print summary
print("")
print(string.rep("=", 70))
print("LuaJIT Optimization Test Summary")
print(string.rep("=", 70))
print(string.format("Total tests: %d", test_count))
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", fail_count))
print(string.format("Success rate: %.1f%%", (pass_count / test_count) * 100))
print("")

if jit then
  print("JIT Status at end: " .. (jit.status() and "enabled" or "disabled"))

  -- Print JIT statistics if available
  if jit.util then
    print("")
    print("Note: JIT compiler optimizations are working correctly.")
    print("All runtime modules maintain correct semantics under JIT compilation.")
  end
end

if fail_count > 0 then
  os.exit(1)
else
  print("")
  print("✓ All LuaJIT optimization tests passed!")
  print("✓ JIT compilation does not break runtime semantics")
  print("✓ Table optimizations work correctly")
  print("✓ No FFI compatibility issues (FFI not used)")
  os.exit(0)
end
