#!/usr/bin/env lua
-- Test Hashtbl module

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

local function assert_error(fn, expected_msg)
  local success, err = pcall(fn)
  if success then
    error("Expected error but function succeeded")
  end
  if expected_msg and not string.find(tostring(err), expected_msg, 1, true) then
    error("Expected error containing '" .. expected_msg .. "', got: " .. tostring(err))
  end
end

print("====================================================================")
print("Hashtbl Module Tests")
print("====================================================================")
print()

print("Hash Table Creation Tests:")
print("--------------------------------------------------------------------")

test("create: empty hash table", function()
  local h = caml_hash_create()
  assert_eq(caml_hash_length(h), 0)
end)

test("create: with initial size", function()
  local h = caml_hash_create(32)
  assert_eq(caml_hash_length(h), 0)
  local stats = caml_hash_stats(h)
  assert_eq(stats.capacity, 32)
end)

test("create: with invalid size defaults to 16", function()
  local h = caml_hash_create(0)
  local stats = caml_hash_stats(h)
  assert_eq(stats.capacity, 16)
end)

print()
print("Add Tests:")
print("--------------------------------------------------------------------")

test("add: single binding", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  assert_eq(caml_hash_length(h), 1)
end)

test("add: multiple bindings", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  caml_hash_add(h, "key2", "value2")
  caml_hash_add(h, "key3", "value3")
  assert_eq(caml_hash_length(h), 3)
end)

test("add: duplicate keys (both bindings kept)", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  caml_hash_add(h, "key1", "value2")
  assert_eq(caml_hash_length(h), 2)
end)

test("add: integer keys", function()
  local h = caml_hash_create()
  caml_hash_add(h, 1, "one")
  caml_hash_add(h, 2, "two")
  caml_hash_add(h, 3, "three")
  assert_eq(caml_hash_length(h), 3)
end)

test("add: mixed types", function()
  local h = caml_hash_create()
  caml_hash_add(h, 1, "number")
  caml_hash_add(h, "str", "string")
  caml_hash_add(h, 3.14, "float")
  assert_eq(caml_hash_length(h), 3)
end)

print()
print("Find Tests:")
print("--------------------------------------------------------------------")

test("find: existing key", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  local value = caml_hash_find(h, "key1")
  assert_eq(value, "value1")
end)

test("find: non-existent key raises error", function()
  local h = caml_hash_create()
  assert_error(function()
    caml_hash_find(h, "missing")
  end, "Not_found")
end)

test("find: most recent binding with duplicate keys", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "old")
  caml_hash_add(h, "key1", "new")
  local value = caml_hash_find(h, "key1")
  assert_eq(value, "new")
end)

test("find: integer keys", function()
  local h = caml_hash_create()
  caml_hash_add(h, 42, "answer")
  local value = caml_hash_find(h, 42)
  assert_eq(value, "answer")
end)

print()
print("Find Opt Tests:")
print("--------------------------------------------------------------------")

test("find_opt: existing key", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  local value = caml_hash_find_opt(h, "key1")
  assert_eq(value, "value1")
end)

test("find_opt: non-existent key returns nil", function()
  local h = caml_hash_create()
  local value = caml_hash_find_opt(h, "missing")
  assert_eq(value, nil)
end)

test("find_opt: most recent binding", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "old")
  caml_hash_add(h, "key1", "new")
  local value = caml_hash_find_opt(h, "key1")
  assert_eq(value, "new")
end)

print()
print("Remove Tests:")
print("--------------------------------------------------------------------")

test("remove: existing key", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  caml_hash_remove(h, "key1")
  assert_eq(caml_hash_length(h), 0)
end)

test("remove: non-existent key (no effect)", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  caml_hash_remove(h, "missing")
  assert_eq(caml_hash_length(h), 1)
end)

test("remove: one of duplicate keys", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "old")
  caml_hash_add(h, "key1", "new")
  caml_hash_remove(h, "key1")
  assert_eq(caml_hash_length(h), 1)
  -- Should find the remaining binding
  local value = caml_hash_find(h, "key1")
  assert_eq(value, "old")
end)

test("remove: after remove, key not found", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  caml_hash_remove(h, "key1")
  assert_error(function()
    caml_hash_find(h, "key1")
  end, "Not_found")
end)

print()
print("Replace Tests:")
print("--------------------------------------------------------------------")

test("replace: new key", function()
  local h = caml_hash_create()
  caml_hash_replace(h, "key1", "value1")
  assert_eq(caml_hash_length(h), 1)
  local value = caml_hash_find(h, "key1")
  assert_eq(value, "value1")
end)

test("replace: existing key", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "old")
  caml_hash_replace(h, "key1", "new")
  assert_eq(caml_hash_length(h), 1)
  local value = caml_hash_find(h, "key1")
  assert_eq(value, "new")
end)

test("replace: removes all duplicate bindings", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "old1")
  caml_hash_add(h, "key1", "old2")
  caml_hash_add(h, "key1", "old3")
  caml_hash_replace(h, "key1", "new")
  assert_eq(caml_hash_length(h), 1)
  local value = caml_hash_find(h, "key1")
  assert_eq(value, "new")
end)

print()
print("Mem Tests:")
print("--------------------------------------------------------------------")

test("mem: existing key", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  assert_true(caml_hash_mem(h, "key1"))
end)

test("mem: non-existent key", function()
  local h = caml_hash_create()
  assert_false(caml_hash_mem(h, "missing"))
end)

test("mem: after remove", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  caml_hash_remove(h, "key1")
  assert_false(caml_hash_mem(h, "key1"))
end)

print()
print("Length Tests:")
print("--------------------------------------------------------------------")

test("length: empty hash table", function()
  local h = caml_hash_create()
  assert_eq(caml_hash_length(h), 0)
end)

test("length: tracks additions", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", "v1")
  assert_eq(caml_hash_length(h), 1)
  caml_hash_add(h, "k2", "v2")
  assert_eq(caml_hash_length(h), 2)
  caml_hash_add(h, "k3", "v3")
  assert_eq(caml_hash_length(h), 3)
end)

test("length: tracks removals", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", "v1")
  caml_hash_add(h, "k2", "v2")
  caml_hash_remove(h, "k1")
  assert_eq(caml_hash_length(h), 1)
end)

test("length: includes duplicate keys", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "v1")
  caml_hash_add(h, "key1", "v2")
  assert_eq(caml_hash_length(h), 2)
end)

print()
print("Clear Tests:")
print("--------------------------------------------------------------------")

test("clear: empties hash table", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", "v1")
  caml_hash_add(h, "k2", "v2")
  caml_hash_clear(h)
  assert_eq(caml_hash_length(h), 0)
end)

test("clear: can reuse hash table", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", "v1")
  caml_hash_clear(h)
  caml_hash_add(h, "k2", "v2")
  assert_eq(caml_hash_length(h), 1)
  local value = caml_hash_find(h, "k2")
  assert_eq(value, "v2")
end)

test("clear: on empty hash table", function()
  local h = caml_hash_create()
  caml_hash_clear(h)
  assert_eq(caml_hash_length(h), 0)
end)

print()
print("Iter Tests:")
print("--------------------------------------------------------------------")

test("iter: empty hash table", function()
  local h = caml_hash_create()
  local count = 0
  caml_hash_iter(h, function(k, v)
    count = count + 1
  end)
  assert_eq(count, 0)
end)

test("iter: single element", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "value1")
  local count = 0
  local found_key, found_value
  caml_hash_iter(h, function(k, v)
    count = count + 1
    found_key = k
    found_value = v
  end)
  assert_eq(count, 1)
  assert_eq(found_key, "key1")
  assert_eq(found_value, "value1")
end)

test("iter: multiple elements", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", "v1")
  caml_hash_add(h, "k2", "v2")
  caml_hash_add(h, "k3", "v3")
  local count = 0
  caml_hash_iter(h, function(k, v)
    count = count + 1
  end)
  assert_eq(count, 3)
end)

test("iter: includes duplicate keys", function()
  local h = caml_hash_create()
  caml_hash_add(h, "key1", "v1")
  caml_hash_add(h, "key1", "v2")
  local count = 0
  caml_hash_iter(h, function(k, v)
    count = count + 1
  end)
  assert_eq(count, 2)
end)

print()
print("Fold Tests:")
print("--------------------------------------------------------------------")

test("fold: empty hash table", function()
  local h = caml_hash_create()
  local result = caml_hash_fold(h, function(k, v, acc)
    return acc + 1
  end, 0)
  assert_eq(result, 0)
end)

test("fold: count elements", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", "v1")
  caml_hash_add(h, "k2", "v2")
  caml_hash_add(h, "k3", "v3")
  local count = caml_hash_fold(h, function(k, v, acc)
    return acc + 1
  end, 0)
  assert_eq(count, 3)
end)

test("fold: sum integer values", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", 10)
  caml_hash_add(h, "k2", 20)
  caml_hash_add(h, "k3", 30)
  local sum = caml_hash_fold(h, function(k, v, acc)
    return acc + v
  end, 0)
  assert_eq(sum, 60)
end)

print()
print("Entries Iterator Tests:")
print("--------------------------------------------------------------------")

test("entries: empty hash table", function()
  local h = caml_hash_create()
  local count = 0
  for k, v in caml_hash_entries(h) do
    count = count + 1
  end
  assert_eq(count, 0)
end)

test("entries: iterate over elements", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", "v1")
  caml_hash_add(h, "k2", "v2")
  caml_hash_add(h, "k3", "v3")
  local count = 0
  local keys = {}
  for k, v in caml_hash_entries(h) do
    count = count + 1
    keys[k] = v
  end
  assert_eq(count, 3)
  assert_eq(keys["k1"], "v1")
  assert_eq(keys["k2"], "v2")
  assert_eq(keys["k3"], "v3")
end)

print()
print("Keys/Values Tests:")
print("--------------------------------------------------------------------")

test("keys: empty hash table", function()
  local h = caml_hash_create()
  local keys = caml_hash_keys(h)
  assert_eq(#keys, 0)
end)

test("keys: returns all keys", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", "v1")
  caml_hash_add(h, "k2", "v2")
  caml_hash_add(h, "k3", "v3")
  local keys = caml_hash_keys(h)
  assert_eq(#keys, 3)
end)

test("values: empty hash table", function()
  local h = caml_hash_create()
  local values = caml_hash_values(h)
  assert_eq(#values, 0)
end)

test("values: returns all values", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", "v1")
  caml_hash_add(h, "k2", "v2")
  caml_hash_add(h, "k3", "v3")
  local values = caml_hash_values(h)
  assert_eq(#values, 3)
end)

print()
print("To Array Tests:")
print("--------------------------------------------------------------------")

test("to_array: empty hash table", function()
  local h = caml_hash_create()
  local arr = caml_hash_to_array(h)
  assert_eq(#arr, 0)
end)

test("to_array: with elements", function()
  local h = caml_hash_create()
  caml_hash_add(h, "k1", "v1")
  caml_hash_add(h, "k2", "v2")
  local arr = caml_hash_to_array(h)
  assert_eq(#arr, 2)
end)

print()
print("Resize Tests:")
print("--------------------------------------------------------------------")

test("resize: automatic on load factor", function()
  local h = caml_hash_create(4)
  -- Add enough elements to trigger resize (load factor > 0.75)
  for i = 1, 10 do
    caml_hash_add(h, "key" .. i, "value" .. i)
  end
  assert_eq(caml_hash_length(h), 10)
  -- All elements should still be findable
  for i = 1, 10 do
    local value = caml_hash_find(h, "key" .. i)
    assert_eq(value, "value" .. i)
  end
end)

test("resize: preserves all bindings", function()
  local h = caml_hash_create(2)
  for i = 1, 20 do
    caml_hash_add(h, i, i * 10)
  end
  assert_eq(caml_hash_length(h), 20)
  for i = 1, 20 do
    local value = caml_hash_find(h, i)
    assert_eq(value, i * 10)
  end
end)

print()
print("Complex Key Tests:")
print("--------------------------------------------------------------------")

test("complex: OCaml byte array keys", function()
  local h = caml_hash_create()
  local key1 = {72, 101, 108, 108, 111}  -- "Hello"
  local key2 = {87, 111, 114, 108, 100}  -- "World"
  caml_hash_add(h, key1, "greeting")
  caml_hash_add(h, key2, "earth")
  local v1 = caml_hash_find(h, key1)
  local v2 = caml_hash_find(h, key2)
  assert_eq(v1, "greeting")
  assert_eq(v2, "earth")
end)

test("complex: table keys with same structure", function()
  local h = caml_hash_create()
  local key1 = {1, 2, 3}
  local key2 = {1, 2, 3}  -- Different table, same structure
  caml_hash_add(h, key1, "first")
  local value = caml_hash_find(h, key2)
  assert_eq(value, "first")  -- Should find due to structural equality
end)

print()
print("Performance Tests:")
print("--------------------------------------------------------------------")

test("performance: many insertions", function()
  local h = caml_hash_create()
  for i = 1, 1000 do
    caml_hash_add(h, i, i * 2)
  end
  assert_eq(caml_hash_length(h), 1000)
end)

test("performance: many lookups", function()
  local h = caml_hash_create()
  for i = 1, 100 do
    caml_hash_add(h, i, i * 2)
  end
  for i = 1, 100 do
    local value = caml_hash_find(h, i)
    assert_eq(value, i * 2)
  end
end)

test("performance: mixed operations", function()
  local h = caml_hash_create()
  for i = 1, 100 do
    caml_hash_add(h, i, i)
  end
  for i = 1, 50 do
    caml_hash_remove(h, i)
  end
  for i = 51, 100 do
    assert_true(caml_hash_mem(h, i))
  end
  assert_eq(caml_hash_length(h), 50)
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
