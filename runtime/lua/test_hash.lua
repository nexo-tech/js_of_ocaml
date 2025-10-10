#!/usr/bin/env lua
-- Test Hash primitives

-- Load dependencies in correct order
dofile("mlBytes.lua")  -- Provides caml_bit_and, caml_bit_or, caml_bit_lshift, caml_bit_rshift
dofile("ints.lua")     -- Provides caml_to_int32
dofile("compare.lua")  -- Provides caml_is_ocaml_string, caml_is_ocaml_block
dofile("hash.lua")     -- Provides caml_hash_* functions
dofile("hashtbl.lua")  -- Provides caml_hashtbl_* functions

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
  io.write("Test: " .. name .. " ... ")
  local success, err = pcall(fn)
  if success then
    tests_passed = tests_passed + 1
    print("✓")
  else
    tests_failed = tests_failed + 1
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
    error(msg or "Expected true, got false")
  end
end

local function assert_false(value, msg)
  if value then
    error(msg or "Expected false, got true")
  end
end

local function assert_in_range(value, min, max, msg)
  if value < min or value > max then
    error(msg or ("Expected value in range [" .. min .. ", " .. max .. "], got " .. value))
  end
end

print("====================================================================")
print("Hash Module Tests")
print("====================================================================")
print()

print("Hash Mix Int Tests:")
print("--------------------------------------------------------------------")

test("hash_mix_int: deterministic", function()
  local h1 = caml_hash_mix_int(0, 42)
  local h2 = caml_hash_mix_int(0, 42)
  assert_eq(h1, h2)
end)

test("hash_mix_int: different inputs different hashes", function()
  local h1 = caml_hash_mix_int(0, 42)
  local h2 = caml_hash_mix_int(0, 43)
  assert_true(h1 ~= h2)
end)

test("hash_mix_int: zero input", function()
  local h = caml_hash_mix_int(0, 0)
  assert_true(h ~= 0)  -- Should produce non-zero hash
end)

test("hash_mix_int: negative input", function()
  local h = caml_hash_mix_int(0, -42)
  assert_true(h ~= 0)
end)

test("hash_mix_int: large input", function()
  local h = caml_hash_mix_int(0, 0x7FFFFFFF)
  assert_true(h ~= 0)
end)

print()
print("Hash Mix Final Tests:")
print("--------------------------------------------------------------------")

test("hash_mix_final: deterministic", function()
  local h1 = caml_hash_mix_final(12345)
  local h2 = caml_hash_mix_final(12345)
  assert_eq(h1, h2)
end)

test("hash_mix_final: avalanche effect", function()
  local h1 = caml_hash_mix_final(12345)
  local h2 = caml_hash_mix_final(12346)
  -- Small input change should produce large output change
  assert_true(h1 ~= h2)
end)

print()
print("Hash Mix Float Tests:")
print("--------------------------------------------------------------------")

test("hash_mix_float: deterministic", function()
  local h1 = caml_hash_mix_float(0, 3.14)
  local h2 = caml_hash_mix_float(0, 3.14)
  assert_eq(h1, h2)
end)

test("hash_mix_float: different floats", function()
  local h1 = caml_hash_mix_float(0, 3.14)
  local h2 = caml_hash_mix_float(0, 2.71)
  assert_true(h1 ~= h2)
end)

test("hash_mix_float: zero", function()
  local h = caml_hash_mix_float(0, 0.0)
  assert_true(h ~= 0)
end)

test("hash_mix_float: negative zero normalized", function()
  local h1 = caml_hash_mix_float(0, 0.0)
  local h2 = caml_hash_mix_float(0, -0.0)
  assert_eq(h1, h2)  -- -0.0 should hash same as 0.0
end)

test("hash_mix_float: infinity", function()
  local h = caml_hash_mix_float(0, math.huge)
  assert_true(h ~= 0)
end)

test("hash_mix_float: negative infinity", function()
  local h1 = caml_hash_mix_float(0, math.huge)
  local h2 = caml_hash_mix_float(0, -math.huge)
  assert_true(h1 ~= h2)
end)

test("hash_mix_float: NaN normalized", function()
  local nan1 = 0/0
  local nan2 = math.sqrt(-1)
  local h1 = caml_hash_mix_float(0, nan1)
  local h2 = caml_hash_mix_float(0, nan2)
  assert_eq(h1, h2)  -- All NaNs should hash to same value
end)

print()
print("Hash Mix String Tests:")
print("--------------------------------------------------------------------")

test("hash_mix_string: empty string", function()
  local h = caml_hash_mix_string(0, {})
  -- Empty string with seed 0 will hash to 0 (just XOR with length 0)
  -- This is fine because final mixing will still distribute it
  assert_eq(h, 0)
end)

test("hash_mix_string: single byte", function()
  local h = caml_hash_mix_string(0, {65})  -- "A"
  assert_true(h ~= 0)
end)

test("hash_mix_string: deterministic", function()
  local s = {72, 101, 108, 108, 111}  -- "Hello"
  local h1 = caml_hash_mix_string(0, s)
  local h2 = caml_hash_mix_string(0, s)
  assert_eq(h1, h2)
end)

test("hash_mix_string: different strings", function()
  local s1 = {72, 101, 108, 108, 111}  -- "Hello"
  local s2 = {87, 111, 114, 108, 100}  -- "World"
  local h1 = caml_hash_mix_string(0, s1)
  local h2 = caml_hash_mix_string(0, s2)
  assert_true(h1 ~= h2)
end)

test("hash_mix_string: length matters", function()
  local s1 = {72, 101, 108, 108, 111}     -- "Hello"
  local s2 = {72, 101, 108, 108, 111, 33} -- "Hello!"
  local h1 = caml_hash_mix_string(0, s1)
  local h2 = caml_hash_mix_string(0, s2)
  assert_true(h1 ~= h2)
end)

test("hash_mix_string: order matters", function()
  local s1 = {65, 66, 67}  -- "ABC"
  local s2 = {67, 66, 65}  -- "CBA"
  local h1 = caml_hash_mix_string(0, s1)
  local h2 = caml_hash_mix_string(0, s2)
  assert_true(h1 ~= h2)
end)

test("hash_mix_string: long string", function()
  local s = {}
  for i = 1, 100 do
    s[i] = 65 + (i % 26)
  end
  local h = caml_hash_mix_string(0, s)
  assert_true(h ~= 0)
end)

print()
print("Polymorphic Hash Tests:")
print("--------------------------------------------------------------------")

test("hash: integer", function()
  local h = caml_hash(10, 100, 0, 42)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("hash: integer deterministic", function()
  local h1 = caml_hash(10, 100, 0, 42)
  local h2 = caml_hash(10, 100, 0, 42)
  assert_eq(h1, h2)
end)

test("hash: different integers", function()
  local h1 = caml_hash(10, 100, 0, 42)
  local h2 = caml_hash(10, 100, 0, 43)
  assert_true(h1 ~= h2)
end)

test("hash: zero", function()
  local h = caml_hash(10, 100, 0, 0)
  assert_true(h ~= 0)
end)

test("hash: negative integer", function()
  local h = caml_hash(10, 100, 0, -42)
  assert_true(h ~= 0)
end)

test("hash: float", function()
  local h = caml_hash(10, 100, 0, 3.14)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("hash: different floats", function()
  local h1 = caml_hash(10, 100, 0, 3.14)
  local h2 = caml_hash(10, 100, 0, 2.71)
  assert_true(h1 ~= h2)
end)

test("hash: lua string", function()
  local h = caml_hash(10, 100, 0, "hello")
  assert_in_range(h, 0, 0x3fffffff)
end)

test("hash: different lua strings", function()
  local h1 = caml_hash(10, 100, 0, "hello")
  local h2 = caml_hash(10, 100, 0, "world")
  assert_true(h1 ~= h2)
end)

test("hash: ocaml byte array", function()
  local s = {72, 101, 108, 108, 111}  -- "Hello"
  local h = caml_hash(10, 100, 0, s)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("hash: different ocaml strings", function()
  local s1 = {72, 101, 108, 108, 111}  -- "Hello"
  local s2 = {87, 111, 114, 108, 100}  -- "World"
  local h1 = caml_hash(10, 100, 0, s1)
  local h2 = caml_hash(10, 100, 0, s2)
  assert_true(h1 ~= h2)
end)

test("hash: ocaml block with tag", function()
  local b = {tag = 0, 1, 2, 3}
  local h = caml_hash(10, 100, 0, b)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("hash: different blocks", function()
  local b1 = {tag = 0, 1, 2, 3}
  local b2 = {tag = 0, 1, 2, 4}
  local h1 = caml_hash(10, 100, 0, b1)
  local h2 = caml_hash(10, 100, 0, b2)
  assert_true(h1 ~= h2)
end)

test("hash: nested blocks", function()
  local b = {tag = 0, {tag = 0, 1, 2}, 3}
  local h = caml_hash(10, 100, 0, b)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("hash: different nested blocks", function()
  local b1 = {tag = 0, {tag = 0, 1, 2}, 3}
  local b2 = {tag = 0, {tag = 0, 1, 5}, 3}
  local h1 = caml_hash(10, 100, 0, b1)
  local h2 = caml_hash(10, 100, 0, b2)
  assert_true(h1 ~= h2)
end)

test("hash: generic table", function()
  local t = {1, 2, 3}
  local h = caml_hash(10, 100, 0, t)
  assert_in_range(h, 0, 0x3fffffff)
end)

print()
print("Hash Default Tests:")
print("--------------------------------------------------------------------")

test("hash_default: integer", function()
  local h = caml_hash_default(42)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("hash_default: deterministic", function()
  local h1 = caml_hash_default(42)
  local h2 = caml_hash_default(42)
  assert_eq(h1, h2)
end)

test("hash_default: string", function()
  local h = caml_hash_default("hello")
  assert_in_range(h, 0, 0x3fffffff)
end)

test("hash_default: block", function()
  local b = {tag = 0, 1, 2, 3}
  local h = caml_hash_default(b)
  assert_in_range(h, 0, 0x3fffffff)
end)

print()
print("Hash Distribution Tests:")
print("--------------------------------------------------------------------")

test("distribution: sequential integers", function()
  local hashes = {}
  local collisions = 0

  -- Hash 100 sequential integers
  for i = 1, 100 do
    local h = caml_hash_default(i)
    if hashes[h] then
      collisions = collisions + 1
    end
    hashes[h] = true
  end

  -- Should have reasonable collision rate (< 15%)
  assert_true(collisions < 15, "Too many collisions: " .. collisions)
end)

test("distribution: strings with common prefix", function()
  local hashes = {}
  local collisions = 0

  -- Hash strings with common prefix
  for i = 1, 100 do
    local s = "prefix" .. i
    local h = caml_hash_default(s)
    if hashes[h] then
      collisions = collisions + 1
    end
    hashes[h] = true
  end

  -- Should have reasonable collision rate (< 15%)
  assert_true(collisions < 15, "Too many collisions: " .. collisions)
end)

test("distribution: blocks with similar structure", function()
  local hashes = {}
  local collisions = 0

  -- Hash blocks with similar structure
  for i = 1, 50 do
    local b = {tag = 0, i, i * 2, i * 3}
    local h = caml_hash_default(b)
    if hashes[h] then
      collisions = collisions + 1
    end
    hashes[h] = true
  end

  assert_true(collisions < 3, "Too many collisions: " .. collisions)
end)

test("distribution: bucket distribution", function()
  local buckets = {}
  local num_buckets = 16

  -- Initialize buckets
  for i = 0, num_buckets - 1 do
    buckets[i] = 0
  end

  -- Hash 1000 values and count bucket distribution
  for i = 1, 1000 do
    local h = caml_hash_default(i)
    local bucket = h % num_buckets
    buckets[bucket] = buckets[bucket] + 1
  end

  -- Check distribution is reasonably uniform
  local expected = 1000 / num_buckets
  for i = 0, num_buckets - 1 do
    -- Each bucket should have roughly expected number of elements
    -- Allow 50% deviation
    assert_in_range(buckets[i], expected * 0.5, expected * 1.5,
      "Bucket " .. i .. " has poor distribution: " .. buckets[i])
  end
end)

print()
print("Seed Parameter Tests:")
print("--------------------------------------------------------------------")

test("seed: same seed produces same hash", function()
  local h1 = caml_hash(10, 100, 12345, 42)
  local h2 = caml_hash(10, 100, 12345, 42)
  assert_eq(h1, h2)
end)

test("seed: is used in computation", function()
  -- Verify seed is actually used (not ignored)
  -- For most values, different seeds will produce different intermediate states
  local obj = "test string for hashing"
  local h1 = caml_hash(10, 100, 0, obj)
  local h2 = caml_hash(10, 100, 1, obj)
  local h3 = caml_hash(10, 100, 2, obj)
  -- At least some should be different (not all collapsed)
  assert_true(h1 ~= h2 or h2 ~= h3 or h1 ~= h3,
    "All hashes with different seeds are identical - seed may not be used")
end)

print()
print("Count and Limit Parameters:")
print("--------------------------------------------------------------------")

test("count: limits number of atoms processed", function()
  -- Create structure with multiple atoms at different levels
  -- Note: count limits atoms (strings, numbers), not blocks
  local wide = {tag = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10}

  -- With count=1, should only hash first atom
  local h1 = caml_hash(1, 100, 0, wide)

  -- With count=20, should hash all atoms
  local h2 = caml_hash(20, 100, 0, wide)

  -- Hashes should be different
  assert_true(h1 ~= h2, "count parameter should limit atoms processed")
end)

test("limit: bounds queue size", function()
  -- Create wide structure
  local wide = {tag = 0}
  for i = 1, 300 do
    wide[i] = i
  end

  -- With limit=10, should only process first elements
  local h1 = caml_hash(100, 10, 0, wide)

  -- With limit=256, should process more
  local h2 = caml_hash(100, 256, 0, wide)

  -- Hashes should be different
  assert_true(h1 ~= h2)
end)

test("limit: auto-clamped to 256", function()
  -- Limit > 256 should be clamped
  local h1 = caml_hash(100, 256, 0, 42)
  local h2 = caml_hash(100, 1000, 0, 42)
  assert_eq(h1, h2)  -- Should produce same hash
end)

print()
print("Complex Structure Tests:")
print("--------------------------------------------------------------------")

test("complex: list-like structure", function()
  -- OCaml list: 1 :: 2 :: 3 :: []
  local nil_val = {tag = 0}
  local list = {tag = 0, 1, {tag = 0, 2, {tag = 0, 3, nil_val}}}
  local h = caml_hash_default(list)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("complex: different lists", function()
  local nil_val = {tag = 0}
  local list1 = {tag = 0, 1, {tag = 0, 2, nil_val}}
  local list2 = {tag = 0, 1, {tag = 0, 3, nil_val}}
  local h1 = caml_hash_default(list1)
  local h2 = caml_hash_default(list2)
  assert_true(h1 ~= h2)
end)

test("complex: tuple-like structure", function()
  local tuple = {tag = 0, 42, "hello", 3.14}
  local h = caml_hash_default(tuple)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("complex: record-like structure", function()
  local record = {tag = 0, {65, 108, 105, 99, 101}, 30}  -- {name:"Alice", age:30}
  local h = caml_hash_default(record)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("complex: tree-like structure", function()
  local leaf = {tag = 1, 42}
  local node = {tag = 0, leaf, leaf}
  local tree = {tag = 0, node, node}
  local h = caml_hash_default(tree)
  assert_in_range(h, 0, 0x3fffffff)
end)

print()
print("Hashtbl Integration Tests:")
print("--------------------------------------------------------------------")

test("hashtbl: can use as hash function", function()
  -- Create hash table
  local tbl = caml_hash_create(16)

  -- Add some values
  caml_hash_add(tbl, 42, "value1")
  caml_hash_add(tbl, "key", "value2")
  caml_hash_add(tbl, {tag = 0, 1, 2}, "value3")

  -- Should be able to find them
  assert_eq(caml_hash_find(tbl, 42), "value1")
  assert_eq(caml_hash_find(tbl, "key"), "value2")
  assert_eq(caml_hash_find(tbl, {tag = 0, 1, 2}), "value3")
end)

test("hashtbl: structural equality for keys", function()
  local tbl = caml_hash_create(16)

  local key1 = {tag = 0, 1, 2, 3}
  local key2 = {tag = 0, 1, 2, 3}  -- Different table, same structure

  caml_hash_add(tbl, key1, "value")

  -- Should find with structurally equal key
  assert_eq(caml_hash_find(tbl, key2), "value")
end)

print()
print("Edge Cases:")
print("--------------------------------------------------------------------")

test("edge: empty block", function()
  local b = {tag = 0}
  local h = caml_hash_default(b)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("edge: large integer", function()
  local h = caml_hash_default(0x7FFFFFFF)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("edge: very long string", function()
  local s = {}
  for i = 1, 1000 do
    s[i] = 65
  end
  local h = caml_hash_default(s)
  assert_in_range(h, 0, 0x3fffffff)
end)

test("edge: deeply nested structure", function()
  local deep = {tag = 0, 1}
  for i = 1, 50 do
    deep = {tag = 0, deep}
  end
  local h = caml_hash_default(deep)
  assert_in_range(h, 0, 0x3fffffff)
end)

print()
print("Performance Tests:")
print("--------------------------------------------------------------------")

test("performance: hash many integers", function()
  for i = 1, 1000 do
    caml_hash_default(i)
  end
end)

test("performance: hash many strings", function()
  for i = 1, 100 do
    caml_hash_default("string" .. i)
  end
end)

test("performance: hash complex structures", function()
  for i = 1, 100 do
    local b = {tag = 0, i, i * 2, {tag = 0, i * 3, i * 4}}
    caml_hash_default(b)
  end
end)

print()
print(string.rep("=", 60))
print("Tests passed: " .. tests_passed)
print("Tests failed: " .. tests_failed)
if tests_failed == 0 then
  print("All tests passed! ✓")
  print(string.rep("=", 60))
  os.exit(0)
else
  print("Some tests failed.")
  print(string.rep("=", 60))
  os.exit(1)
end
