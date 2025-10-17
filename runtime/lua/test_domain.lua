#!/usr/bin/env lua
-- Test suite for domain.lua
-- Tests for OCaml 5.0+ domain and atomic operations

dofile("domain.lua")

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
  local status, err = pcall(fn)
  if status then
    tests_passed = tests_passed + 1
    print("✓ " .. name)
  else
    tests_failed = tests_failed + 1
    print("✗ " .. name)
    print("  Error: " .. tostring(err))
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error((msg or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

-- Atomic load/store operations
test("caml_atomic_load returns reference value", function()
  local ref = {tag = 0, 42}  -- OCaml blocks have named 'tag' field
  assert_eq(caml_atomic_load(ref), 42)
end)

test("caml_atomic_load_field returns block field", function()
  local block = {tag = 0, 10, 20, 30}  -- Fields at indices 1, 2, 3
  assert_eq(caml_atomic_load_field(block, 0), 10)
  assert_eq(caml_atomic_load_field(block, 1), 20)
  assert_eq(caml_atomic_load_field(block, 2), 30)
end)

-- Compare-and-swap operations
test("caml_atomic_cas succeeds when value matches", function()
  local ref = {tag = 0, 42}
  local result = caml_atomic_cas(ref, 42, 100)
  assert_eq(result, 1, "CAS should succeed")
  assert_eq(ref[1], 100, "Value should be updated")
end)

test("caml_atomic_cas fails when value doesn't match", function()
  local ref = {tag = 0, 42}
  local result = caml_atomic_cas(ref, 99, 100)
  assert_eq(result, 0, "CAS should fail")
  assert_eq(ref[1], 42, "Value should not be updated")
end)

test("caml_atomic_cas_field succeeds when field matches", function()
  local block = {tag = 0, 10, 20, 30}
  local result = caml_atomic_cas_field(block, 1, 20, 200)
  assert_eq(result, 1, "CAS should succeed")
  assert_eq(block[2], 200, "Field should be updated")
end)

test("caml_atomic_cas_field fails when field doesn't match", function()
  local block = {tag = 0, 10, 20, 30}
  local result = caml_atomic_cas_field(block, 1, 99, 200)
  assert_eq(result, 0, "CAS should fail")
  assert_eq(block[2], 20, "Field should not be updated")
end)

-- Fetch-add operations
test("caml_atomic_fetch_add returns old value and increments", function()
  local ref = {tag = 0, 10}
  local old = caml_atomic_fetch_add(ref, 5)
  assert_eq(old, 10, "Should return old value")
  assert_eq(ref[1], 15, "Should increment")
end)

test("caml_atomic_fetch_add_field returns old value and increments field", function()
  local block = {tag = 0, 100, 200, 300}
  local old = caml_atomic_fetch_add_field(block, 1, 50)
  assert_eq(old, 200, "Should return old value")
  assert_eq(block[2], 250, "Should increment field")
end)

-- Exchange operations
test("caml_atomic_exchange returns old value and sets new", function()
  local ref = {tag = 0, 42}
  local old = caml_atomic_exchange(ref, 99)
  assert_eq(old, 42, "Should return old value")
  assert_eq(ref[1], 99, "Should set new value")
end)

test("caml_atomic_exchange_field returns old value and sets new field", function()
  local block = {tag = 0, 10, 20, 30}
  local old = caml_atomic_exchange_field(block, 1, 999)
  assert_eq(old, 20, "Should return old value")
  assert_eq(block[2], 999, "Should set new value")
end)

-- Domain operations
test("caml_atomic_make_contended creates atomic reference", function()
  local ref = caml_atomic_make_contended(42)
  assert_eq(ref.tag, 0, "Tag should be 0")
  assert_eq(ref[1], 42, "Value should be at index 1")
end)

test("caml_ml_domain_id returns 0 for single-threaded", function()
  assert_eq(caml_ml_domain_id(0), 0)
end)

test("caml_ml_domain_recommended_domain_count returns 1", function()
  assert_eq(caml_ml_domain_recommended_domain_count(0), 1)
end)

test("caml_ml_domain_cpu_relax is no-op", function()
  caml_ml_domain_cpu_relax() -- Should not error
end)

test("caml_ml_domain_set_name is no-op", function()
  caml_ml_domain_set_name("test") -- Should not error
end)

-- DLS operations
test("caml_domain_dls_get returns current DLS", function()
  local dls = caml_domain_dls_get(0)
  assert_eq(type(dls), "table", "DLS should be a table")
end)

test("caml_domain_dls_set updates DLS", function()
  local old_dls = caml_domain_dls
  local new_dls = {0, "test"}
  caml_domain_dls_set(new_dls)
  assert_eq(caml_domain_dls, new_dls, "DLS should be updated")
  caml_domain_dls = old_dls -- Restore
end)

test("caml_domain_dls_compare_and_set succeeds on match", function()
  local old = caml_domain_dls
  local new_dls = {0, "new"}
  local result = caml_domain_dls_compare_and_set(old, new_dls)
  assert_eq(result, 1, "Should succeed")
  assert_eq(caml_domain_dls, new_dls, "DLS should be updated")
end)

test("caml_domain_dls_compare_and_set fails on mismatch", function()
  local wrong = {0, "wrong"}
  local new_dls = {0, "new2"}
  local result = caml_domain_dls_compare_and_set(wrong, new_dls)
  assert_eq(result, 0, "Should fail")
end)

-- Print summary
print("\n" .. string.rep("=", 50))
print("Tests passed: " .. tests_passed)
print("Tests failed: " .. tests_failed)
print(string.rep("=", 50))

if tests_failed > 0 then
  os.exit(1)
end
