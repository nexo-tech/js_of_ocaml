#!/usr/bin/env lua
-- Test suite for array.lua array operations primitives

-- Load array.lua directly (it defines global caml_* functions)
dofile("array.lua")

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

-- Test array creation
test("Make array with initial value", function()
  local arr = caml_make_vect(5, 42)
  assert(arr.tag == 0, "Array should have tag 0")
  assert(arr[0] == 5, "Length should be stored at index 0")
  for i = 1, 5 do
    assert(arr[i] == 42, "All elements should be 42")
  end
end)

test("Make empty array", function()
  local arr = caml_make_vect(0, nil)
  assert(caml_array_length(arr) == 0, "Empty array should have length 0")
end)

-- Test length
test("Array length", function()
  local arr = caml_make_vect(10, 0)
  assert(caml_array_length(arr) == 10, "Length should be 10")
end)

-- Test get/set with bounds checking
test("Get element", function()
  local arr = caml_make_vect(3, 0)
  arr[1] = 10
  arr[2] = 20
  arr[3] = 30
  assert(caml_array_get(arr, 0) == 10, "Get index 0")
  assert(caml_array_get(arr, 1) == 20, "Get index 1")
  assert(caml_array_get(arr, 2) == 30, "Get index 2")
end)

test("Get out of bounds", function()
  local arr = caml_make_vect(3, 0)
  local success = pcall(function() caml_array_get(arr, 5) end)
  assert(not success, "Should fail for index >= length")
  success = pcall(function() caml_array_get(arr, -1) end)
  assert(not success, "Should fail for negative index")
end)

test("Set element", function()
  local arr = caml_make_vect(3, 0)
  caml_array_set(arr, 0, 100)
  caml_array_set(arr, 1, 200)
  caml_array_set(arr, 2, 300)
  assert(arr[1] == 100, "Set index 0")
  assert(arr[2] == 200, "Set index 1")
  assert(arr[3] == 300, "Set index 2")
end)

test("Set out of bounds", function()
  local arr = caml_make_vect(3, 0)
  local success = pcall(function() caml_array_set(arr, 5, 999) end)
  assert(not success, "Should fail for index >= length")
  success = pcall(function() caml_array_set(arr, -1, 999) end)
  assert(not success, "Should fail for negative index")
end)

-- Test unsafe get/set
test("Unsafe get", function()
  local arr = caml_make_vect(3, 0)
  arr[2] = 42
  assert(caml_array_unsafe_get(arr, 1) == 42, "Unsafe get should work")
end)

test("Unsafe set", function()
  local arr = caml_make_vect(3, 0)
  caml_array_unsafe_set(arr, 1, 99)
  assert(arr[2] == 99, "Unsafe set should work")
end)

-- Test list conversion
test("Array of list", function()
  -- Build OCaml list: 1 :: 2 :: 3 :: []
  local list = { tag = 0, [1] = 1, [2] = { tag = 0, [1] = 2, [2] = { tag = 0, [1] = 3, [2] = 0 } } }
  local arr = caml_array_of_list(list)
  assert(caml_array_length(arr) == 3, "Array should have length 3")
  assert(arr[1] == 1, "First element")
  assert(arr[2] == 2, "Second element")
  assert(arr[3] == 3, "Third element")
end)

test("Array of empty list", function()
  local arr = caml_array_of_list(0)  -- Empty list
  assert(caml_array_length(arr) == 0, "Should be empty")
end)

test("Array to list", function()
  local arr = caml_make_vect(3, 0)
  arr[1] = 10
  arr[2] = 20
  arr[3] = 30
  local list = caml_array_to_list(arr)
  assert(list[1] == 10, "First element")
  assert(list[2][1] == 20, "Second element")
  assert(list[2][2][1] == 30, "Third element")
  assert(list[2][2][2] == 0, "End of list")
end)

test("Empty array to list", function()
  local arr = caml_make_vect(0, nil)
  local list = caml_array_to_list(arr)
  assert(list == 0, "Empty array should convert to empty list")
end)

-- Test sub
test("Sub array", function()
  local arr = caml_make_vect(5, 0)
  for i = 0, 4 do
    arr[i + 1] = i * 10
  end
  local sub = caml_array_sub(arr, 1, 3)  -- Extract [10, 20, 30]
  assert(caml_array_length(sub) == 3, "Sub should have length 3")
  assert(sub[1] == 10, "First element")
  assert(sub[2] == 20, "Second element")
  assert(sub[3] == 30, "Third element")
end)

-- Test append
test("Append arrays", function()
  local arr1 = caml_make_vect(2, 0)
  arr1[1] = 1
  arr1[2] = 2
  local arr2 = caml_make_vect(3, 0)
  arr2[1] = 3
  arr2[2] = 4
  arr2[3] = 5
  local result = caml_array_append(arr1, arr2)
  assert(caml_array_length(result) == 5, "Result should have length 5")
  assert(result[1] == 1, "Element 0")
  assert(result[2] == 2, "Element 1")
  assert(result[3] == 3, "Element 2")
  assert(result[4] == 4, "Element 3")
  assert(result[5] == 5, "Element 4")
end)

test("Append with empty", function()
  local arr = caml_make_vect(2, 1)
  local empty = caml_make_vect(0, nil)
  local result = caml_array_append(arr, empty)
  assert(caml_array_length(result) == 2, "Should keep original length")
  result = caml_array_append(empty, arr)
  assert(caml_array_length(result) == 2, "Should keep original length")
end)

-- Test concat
test("Concat arrays", function()
  local a1 = caml_make_vect(2, 0)
  a1[1] = 1
  a1[2] = 2
  local a2 = caml_make_vect(1, 0)
  a2[1] = 3
  local a3 = caml_make_vect(2, 0)
  a3[1] = 4
  a3[2] = 5

  -- Build list of arrays: a1 :: a2 :: a3 :: []
  local list = { tag = 0, [1] = a1, [2] = { tag = 0, [1] = a2, [2] = { tag = 0, [1] = a3, [2] = 0 } } }

  local result = caml_array_concat(list)
  assert(caml_array_length(result) == 5, "Concat should have length 5")
  assert(result[1] == 1, "Element 0")
  assert(result[5] == 5, "Element 4")
end)

test("Concat empty list", function()
  local result = caml_array_concat(0)  -- Empty list
  assert(caml_array_length(result) == 0, "Should be empty")
end)

-- Test blit
test("Blit arrays", function()
  local src = caml_make_vect(5, 0)
  for i = 0, 4 do
    src[i + 1] = i + 1
  end
  local dst = caml_make_vect(5, 99)
  caml_array_blit(src, 1, dst, 0, 3)  -- Copy [2,3,4] to start of dst
  assert(dst[1] == 2, "Blit element 0")
  assert(dst[2] == 3, "Blit element 1")
  assert(dst[3] == 4, "Blit element 2")
  assert(dst[4] == 99, "Unchanged element")
end)

test("Blit overlapping forward", function()
  local arr = caml_make_vect(5, 0)
  for i = 0, 4 do
    arr[i + 1] = i
  end
  caml_array_blit(arr, 0, arr, 2, 3)  -- Copy [0,1,2] to positions 2,3,4
  assert(arr[3] == 0, "Forward blit")
  assert(arr[4] == 1, "Forward blit")
  assert(arr[5] == 2, "Forward blit")
end)

test("Blit overlapping backward", function()
  local arr = caml_make_vect(5, 0)
  for i = 0, 4 do
    arr[i + 1] = i
  end
  caml_array_blit(arr, 2, arr, 0, 3)  -- Copy [2,3,4] to positions 0,1,2
  assert(arr[1] == 2, "Backward blit")
  assert(arr[2] == 3, "Backward blit")
  assert(arr[3] == 4, "Backward blit")
end)

-- Test fill
test("Fill array", function()
  local arr = caml_make_vect(5, 0)
  caml_array_fill(arr, 1, 3, 42)  -- Fill positions 1,2,3 with 42
  assert(arr[1] == 0, "Before fill range")
  assert(arr[2] == 42, "Filled")
  assert(arr[3] == 42, "Filled")
  assert(arr[4] == 42, "Filled")
  assert(arr[5] == 0, "After fill range")
end)

-- Test init
test("Init array with function", function()
  local arr = caml_array_init(5, function(i) return i * i end)
  assert(caml_array_length(arr) == 5, "Length should be 5")
  assert(arr[1] == 0, "0^2")
  assert(arr[2] == 1, "1^2")
  assert(arr[3] == 4, "2^2")
  assert(arr[4] == 9, "3^2")
  assert(arr[5] == 16, "4^2")
end)

-- Test iter
test("Iter over array", function()
  local arr = caml_make_vect(3, 0)
  arr[1] = 1
  arr[2] = 2
  arr[3] = 3
  local sum = 0
  caml_array_iter(function(x) sum = sum + x end, arr)
  assert(sum == 6, "Sum should be 6")
end)

test("Iteri with index", function()
  local arr = caml_make_vect(3, 10)
  local indices = {}
  caml_array_iteri(function(i, x) table.insert(indices, i) end, arr)
  assert(indices[1] == 0, "First index")
  assert(indices[2] == 1, "Second index")
  assert(indices[3] == 2, "Third index")
end)

-- Test map
test("Map over array", function()
  local arr = caml_make_vect(3, 0)
  arr[1] = 1
  arr[2] = 2
  arr[3] = 3
  local result = caml_array_map(function(x) return x * 2 end, arr)
  assert(caml_array_length(result) == 3, "Same length")
  assert(result[1] == 2, "Mapped element 0")
  assert(result[2] == 4, "Mapped element 1")
  assert(result[3] == 6, "Mapped element 2")
end)

test("Mapi with index", function()
  local arr = caml_make_vect(3, 10)
  local result = caml_array_mapi(function(i, x) return i + x end, arr)
  assert(result[1] == 10, "0 + 10")
  assert(result[2] == 11, "1 + 10")
  assert(result[3] == 12, "2 + 10")
end)

-- Test fold
test("Fold left", function()
  local arr = caml_make_vect(4, 0)
  arr[1] = 1
  arr[2] = 2
  arr[3] = 3
  arr[4] = 4
  local result = caml_array_fold_left(function(acc, x) return acc + x end, 0, arr)
  assert(result == 10, "Sum should be 10")
end)

test("Fold right", function()
  local arr = caml_make_vect(3, 0)
  arr[1] = 1
  arr[2] = 2
  arr[3] = 3
  -- Build list: (1 :: (2 :: (3 :: [])))
  local result = caml_array_fold_right(
    function(x, acc) return { tag = 0, [1] = x, [2] = acc } end,
    arr,
    0
  )
  assert(result[1] == 1, "First element")
  assert(result[2][1] == 2, "Second element")
  assert(result[2][2][1] == 3, "Third element")
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
