#!/usr/bin/env lua
-- Test suite for bigarray.lua (OCaml Bigarray module)

dofile("bigarray.lua")

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
print("Bigarray Tests (Task 6.5)")
print("====================================================================")
print("")

-- KIND constants (inlined from original)
local KIND = {
  FLOAT32 = 0,
  FLOAT64 = 1,
  INT8_SIGNED = 2,
  INT8_UNSIGNED = 3,
  INT16_SIGNED = 4,
  INT16_UNSIGNED = 5,
  INT32 = 6,
  INT64 = 7,
  NATIVEINT = 8,
  CAML_INT = 9,
  COMPLEX32 = 10,
  COMPLEX64 = 11,
  CHAR = 12,
}

-- LAYOUT constants (inlined from original)
local LAYOUT = {
  C_LAYOUT = 0,      -- Row-major (C style)
  FORTRAN_LAYOUT = 1 -- Column-major (Fortran style)
}

--
-- Initialization Tests
--

print("Initialization:")
print("--------------------------------------------------------------------")

test("caml_ba_init returns 0", function()
  local result = caml_ba_init()
  assert_eq(result, 0, "Should return 0")
end)

--
-- Size Calculation Tests
--

print("")
print("Size Calculation:")
print("--------------------------------------------------------------------")

test("caml_ba_get_size calculates correct size", function()
  assert_eq(caml_ba_get_size({10}), 10, "1D size")
  assert_eq(caml_ba_get_size({3, 4}), 12, "2D size")
  assert_eq(caml_ba_get_size({2, 3, 4}), 24, "3D size")
end)

test("caml_ba_get_size handles zero dimension", function()
  assert_eq(caml_ba_get_size({0}), 0, "Zero size")
  assert_eq(caml_ba_get_size({5, 0}), 0, "Zero in middle")
end)

test("caml_ba_get_size raises error for negative dimension", function()
  local success = pcall(function()
    caml_ba_get_size({-1})
  end)
  assert_true(not success, "Should raise error for negative dimension")
end)

--
-- Creation Tests
--

print("")
print("Creation:")
print("--------------------------------------------------------------------")

test("caml_ba_create_unsafe creates bigarray", function()
  local ba = caml_ba_create_unsafe(KIND.FLOAT64, LAYOUT.C_LAYOUT, {10}, {})
  assert_true(ba ~= nil, "Should create bigarray")
  assert_eq(ba.kind, KIND.FLOAT64, "Should have correct kind")
  assert_eq(ba.layout, LAYOUT.C_LAYOUT, "Should have correct layout")
  assert_eq(#ba.dims, 1, "Should have correct dimensions")
  assert_eq(ba.dims[1], 10, "Should have correct dimension size")
end)

test("caml_ba_create creates initialized bigarray", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {5, 4})
  assert_true(ba ~= nil, "Should create bigarray")
  assert_eq(#ba.data, 20, "Should have correct data size")
  -- Check initialization to 0
  for i = 1, 20 do
    assert_eq(ba.data[i], 0, "Should initialize to 0")
  end
end)

--
-- Property Tests
--

print("")
print("Properties:")
print("--------------------------------------------------------------------")

test("caml_ba_kind returns kind", function()
  local ba = caml_ba_create(KIND.INT8_SIGNED, LAYOUT.C_LAYOUT, {10})
  assert_eq(caml_ba_kind(ba), KIND.INT8_SIGNED, "Should return kind")
end)

test("caml_ba_layout returns layout", function()
  local ba = caml_ba_create(KIND.FLOAT32, LAYOUT.FORTRAN_LAYOUT, {10})
  assert_eq(caml_ba_layout(ba), LAYOUT.FORTRAN_LAYOUT, "Should return layout")
end)

test("caml_ba_num_dims returns number of dimensions", function()
  local ba1 = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {10})
  assert_eq(caml_ba_num_dims(ba1), 1, "Should return 1 for 1D")

  local ba2 = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {3, 4, 5})
  assert_eq(caml_ba_num_dims(ba2), 3, "Should return 3 for 3D")
end)

test("caml_ba_dim returns dimension size", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {3, 4, 5})
  assert_eq(caml_ba_dim(ba, 0), 3, "First dimension")
  assert_eq(caml_ba_dim(ba, 1), 4, "Second dimension")
  assert_eq(caml_ba_dim(ba, 2), 5, "Third dimension")
end)

test("caml_ba_dim raises error for invalid index", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {10})

  local success = pcall(function()
    caml_ba_dim(ba, -1)
  end)
  assert_true(not success, "Should raise error for negative index")

  success = pcall(function()
    caml_ba_dim(ba, 1)
  end)
  assert_true(not success, "Should raise error for out of bounds")
end)

test("caml_ba_dim_1/2/3 return dimensions", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {3, 4, 5})
  assert_eq(caml_ba_dim_1(ba), 3, "First dimension")
  assert_eq(caml_ba_dim_2(ba), 4, "Second dimension")
  assert_eq(caml_ba_dim_3(ba), 5, "Third dimension")
end)

--
-- Layout Tests
--

print("")
print("Layout:")
print("--------------------------------------------------------------------")

test("caml_ba_change_layout changes layout", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {3, 4})
  local ba2 = caml_ba_change_layout(ba, LAYOUT.FORTRAN_LAYOUT)

  assert_eq(caml_ba_layout(ba2), LAYOUT.FORTRAN_LAYOUT, "Should change layout")
  -- Dimensions should be reversed
  assert_eq(ba2.dims[1], 4, "First dimension should be reversed")
  assert_eq(ba2.dims[2], 3, "Second dimension should be reversed")
end)

test("caml_ba_change_layout returns same if layout unchanged", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {10})
  local ba2 = caml_ba_change_layout(ba, LAYOUT.C_LAYOUT)
  assert_eq(ba, ba2, "Should return same bigarray")
end)

--
-- 1D Array Access Tests
--

print("")
print("1D Array Access:")
print("--------------------------------------------------------------------")

test("caml_ba_set_1 and caml_ba_get_1 work", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {10})

  caml_ba_set_1(ba, 0, 42)
  caml_ba_set_1(ba, 5, 100)
  caml_ba_set_1(ba, 9, 255)

  assert_eq(caml_ba_get_1(ba, 0), 42, "Should get correct value at 0")
  assert_eq(caml_ba_get_1(ba, 5), 100, "Should get correct value at 5")
  assert_eq(caml_ba_get_1(ba, 9), 255, "Should get correct value at 9")
end)

test("caml_ba_unsafe_get_1 and caml_ba_unsafe_set_1 work", function()
  local ba = caml_ba_create(KIND.FLOAT64, LAYOUT.C_LAYOUT, {5})

  caml_ba_unsafe_set_1(ba, 0, 3.14)
  caml_ba_unsafe_set_1(ba, 4, 2.71)

  assert_eq(caml_ba_unsafe_get_1(ba, 0), 3.14, "Should get 3.14")
  assert_eq(caml_ba_unsafe_get_1(ba, 4), 2.71, "Should get 2.71")
end)

test("1D array bounds checking", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {10})

  local success = pcall(function()
    caml_ba_get_1(ba, -1)
  end)
  assert_true(not success, "Should raise error for negative index")

  success = pcall(function()
    caml_ba_get_1(ba, 10)
  end)
  assert_true(not success, "Should raise error for out of bounds")
end)

test("INT8_SIGNED clamping", function()
  local ba = caml_ba_create(KIND.INT8_SIGNED, LAYOUT.C_LAYOUT, {3})

  caml_ba_set_1(ba, 0, 200)  -- Over max
  caml_ba_set_1(ba, 1, -200) -- Under min
  caml_ba_set_1(ba, 2, 50)   -- In range

  assert_eq(caml_ba_get_1(ba, 0), 127, "Should clamp to max")
  assert_eq(caml_ba_get_1(ba, 1), -128, "Should clamp to min")
  assert_eq(caml_ba_get_1(ba, 2), 50, "Should preserve in-range value")
end)

test("INT8_UNSIGNED clamping", function()
  local ba = caml_ba_create(KIND.INT8_UNSIGNED, LAYOUT.C_LAYOUT, {3})

  caml_ba_set_1(ba, 0, 300)  -- Over max
  caml_ba_set_1(ba, 1, -50)  -- Under min
  caml_ba_set_1(ba, 2, 128)  -- In range

  assert_eq(caml_ba_get_1(ba, 0), 255, "Should clamp to max")
  assert_eq(caml_ba_get_1(ba, 1), 0, "Should clamp to min")
  assert_eq(caml_ba_get_1(ba, 2), 128, "Should preserve in-range value")
end)

--
-- 2D Array Access Tests
--

print("")
print("2D Array Access:")
print("--------------------------------------------------------------------")

test("caml_ba_set_2 and caml_ba_get_2 work with C layout", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {3, 4})

  caml_ba_set_2(ba, 0, 0, 11)
  caml_ba_set_2(ba, 1, 2, 42)
  caml_ba_set_2(ba, 2, 3, 99)

  assert_eq(caml_ba_get_2(ba, 0, 0), 11, "Should get (0,0)")
  assert_eq(caml_ba_get_2(ba, 1, 2), 42, "Should get (1,2)")
  assert_eq(caml_ba_get_2(ba, 2, 3), 99, "Should get (2,3)")
end)

test("caml_ba_unsafe_get_2 and caml_ba_unsafe_set_2 work", function()
  local ba = caml_ba_create(KIND.FLOAT64, LAYOUT.C_LAYOUT, {2, 3})

  caml_ba_unsafe_set_2(ba, 0, 1, 1.5)
  caml_ba_unsafe_set_2(ba, 1, 2, 2.5)

  assert_eq(caml_ba_unsafe_get_2(ba, 0, 1), 1.5, "Should get (0,1)")
  assert_eq(caml_ba_unsafe_get_2(ba, 1, 2), 2.5, "Should get (1,2)")
end)

test("2D array bounds checking", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {3, 4})

  local success = pcall(function()
    caml_ba_get_2(ba, 3, 0)  -- First dimension out of bounds
  end)
  assert_true(not success, "Should raise error for first dimension OOB")

  success = pcall(function()
    caml_ba_get_2(ba, 0, 4)  -- Second dimension out of bounds
  end)
  assert_true(not success, "Should raise error for second dimension OOB")
end)

--
-- 3D Array Access Tests
--

print("")
print("3D Array Access:")
print("--------------------------------------------------------------------")

test("caml_ba_set_3 and caml_ba_get_3 work", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {2, 3, 4})

  caml_ba_set_3(ba, 0, 0, 0, 111)
  caml_ba_set_3(ba, 1, 2, 3, 999)

  assert_eq(caml_ba_get_3(ba, 0, 0, 0), 111, "Should get (0,0,0)")
  assert_eq(caml_ba_get_3(ba, 1, 2, 3), 999, "Should get (1,2,3)")
end)

--
-- Fill Tests
--

print("")
print("Fill:")
print("--------------------------------------------------------------------")

test("caml_ba_fill fills array with value", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {10})

  caml_ba_fill(ba, 42)

  for i = 0, 9 do
    assert_eq(caml_ba_get_1(ba, i), 42, "Should fill with 42")
  end
end)

test("caml_ba_fill works with 2D array", function()
  local ba = caml_ba_create(KIND.FLOAT64, LAYOUT.C_LAYOUT, {3, 4})

  caml_ba_fill(ba, 3.14)

  for i = 0, 2 do
    for j = 0, 3 do
      assert_eq(caml_ba_get_2(ba, i, j), 3.14, "Should fill with 3.14")
    end
  end
end)

--
-- Blit Tests
--

print("")
print("Blit:")
print("--------------------------------------------------------------------")

test("caml_ba_blit copies data", function()
  local src = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {5})
  local dst = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {5})

  -- Fill src with values
  for i = 0, 4 do
    caml_ba_set_1(src, i, i * 10)
  end

  caml_ba_blit(src, dst)

  -- Check dst has same values
  for i = 0, 4 do
    assert_eq(caml_ba_get_1(dst, i), i * 10, "Should copy values")
  end
end)

test("caml_ba_blit raises error for kind mismatch", function()
  local src = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {5})
  local dst = caml_ba_create(KIND.FLOAT64, LAYOUT.C_LAYOUT, {5})

  local success = pcall(function()
    caml_ba_blit(src, dst)
  end)
  assert_true(not success, "Should raise error for kind mismatch")
end)

test("caml_ba_blit raises error for dimension mismatch", function()
  local src = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {5})
  local dst = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {10})

  local success = pcall(function()
    caml_ba_blit(src, dst)
  end)
  assert_true(not success, "Should raise error for dimension mismatch")
end)

--
-- Sub-array Tests
--

print("")
print("Sub-array:")
print("--------------------------------------------------------------------")

test("caml_ba_sub creates sub-array", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {10})

  -- Fill with values
  for i = 0, 9 do
    caml_ba_set_1(ba, i, i)
  end

  -- Create sub-array starting at index 3, length 4
  local sub = caml_ba_sub(ba, 3, 4)

  assert_eq(caml_ba_dim_1(sub), 4, "Sub-array should have length 4")
  assert_eq(caml_ba_get_1(sub, 0), 3, "Sub-array should start at 3")
  assert_eq(caml_ba_get_1(sub, 3), 6, "Sub-array should end at 6")
end)

--
-- Reshape Tests
--

print("")
print("Reshape:")
print("--------------------------------------------------------------------")

test("caml_ba_reshape changes dimensions", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {12})

  -- Fill with values
  for i = 0, 11 do
    caml_ba_set_1(ba, i, i)
  end

  -- Reshape to 3x4
  local reshaped = caml_ba_reshape(ba, {3, 4})

  assert_eq(caml_ba_num_dims(reshaped), 2, "Should have 2 dimensions")
  assert_eq(caml_ba_dim_1(reshaped), 3, "First dimension should be 3")
  assert_eq(caml_ba_dim_2(reshaped), 4, "Second dimension should be 4")

  -- Data should be same
  assert_eq(caml_ba_get_2(reshaped, 0, 0), 0, "Should preserve data")
  assert_eq(caml_ba_get_2(reshaped, 2, 3), 11, "Should preserve data at end")
end)

test("caml_ba_reshape raises error for size mismatch", function()
  local ba = caml_ba_create(KIND.INT32, LAYOUT.C_LAYOUT, {10})

  local success = pcall(function()
    caml_ba_reshape(ba, {3, 4})  -- 12 != 10
  end)
  assert_true(not success, "Should raise error for size mismatch")
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
