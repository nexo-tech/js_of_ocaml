-- Tests for GC module

dofile("gc.lua")
local weak = require("weak")

-- Test helpers
local function assert_eq(a, b, msg)
  if a ~= b then
    error(msg or ("Assertion failed: " .. tostring(a) .. " ~= " .. tostring(b)))
  end
end

local function assert_true(v, msg)
  if not v then
    error(msg or "Assertion failed: expected true")
  end
end

local function assert_false(v, msg)
  if v then
    error(msg or "Assertion failed: expected false")
  end
end

local function assert_type(v, t, msg)
  if type(v) ~= t then
    error(msg or ("Assertion failed: expected type " .. t .. ", got " .. type(v)))
  end
end

print("Testing GC module...")

-- Test GC control functions
local result = caml_gc_minor(0)
assert_eq(result, 0, "gc_minor returns 0")

result = caml_gc_major(0)
assert_eq(result, 0, "gc_major returns 0")

result = caml_gc_full_major(0)
assert_eq(result, 0, "gc_full_major returns 0")

result = caml_gc_compaction(0)
assert_eq(result, 0, "gc_compaction returns 0")

-- Test GC counters
local counters = caml_gc_counters(0)
assert_type(counters, "table", "counters is a table")
assert_eq(counters[1], 254, "counters tag is 254")

-- Test GC stats
local stats = caml_gc_quick_stat(0)
assert_type(stats, "table", "stats is a table")
assert_eq(#stats, 18, "stats has 18 elements")

local stats2 = caml_gc_stat(0)
assert_type(stats2, "table", "gc_stat returns table")

-- Test GC control
result = caml_gc_set({0, 0, 0})
assert_eq(result, 0, "gc_set returns 0")

local control = caml_gc_get(0)
assert_type(control, "table", "gc_get returns table")

-- Test GC slice
result = caml_gc_major_slice(100)
assert_eq(result, 0, "gc_major_slice returns 0")

-- Test GC memory functions
local minor_words = caml_gc_minor_words(0)
assert_eq(minor_words, 0, "gc_minor_words returns 0")

local minor_free = caml_get_minor_free(0)
assert_eq(minor_free, 0, "get_minor_free returns 0")

-- Test finalizer registration
local finalizer_called = false
local function my_finalizer(x)
  finalizer_called = true
end

local obj = {value = 42}
result = caml_final_register(my_finalizer, obj)
assert_eq(result, 0, "final_register returns 0")

-- Test finalizer without value
local finalizer_no_val_called = false
local function my_finalizer_no_val()
  finalizer_no_val_called = true
end

local obj2 = {value = 99}
result = caml_final_register_called_without_value(my_finalizer_no_val, obj2)
assert_eq(result, 0, "final_register_called_without_value returns 0")

-- Test final release
result = caml_final_release(0)
assert_eq(result, 0, "final_release returns 0")

-- Test memory profiling (no-ops)
result = caml_memprof_start(100, 10, nil)
assert_eq(result, 0, "memprof_start returns 0")

result = caml_memprof_stop(0)
assert_eq(result, 0, "memprof_stop returns 0")

result = caml_memprof_discard(nil)
assert_eq(result, 0, "memprof_discard returns 0")

-- Test event logging (no-ops)
result = caml_eventlog_resume(0)
assert_eq(result, 0, "eventlog_resume returns 0")

result = caml_eventlog_pause(0)
assert_eq(result, 0, "eventlog_pause returns 0")

result = caml_gc_huge_fallback_count(0)
assert_eq(result, 0, "gc_huge_fallback_count returns 0")

print("All GC tests passed!")

print("Testing Weak tables...")

-- Test weak array creation
local weak_arr = weak.caml_weak_create(5)
assert_type(weak_arr, "table", "weak array is table")
assert_eq(weak_arr[0], 251, "weak array tag is 251")

-- Test ephemeron creation
local ephe = weak.caml_ephe_create(3)
assert_type(ephe, "table", "ephemeron is table")
assert_eq(ephe[0], 251, "ephemeron tag is 251")

-- Test setting and getting weak values
local value1 = {data = "test1"}
result = weak.caml_weak_set(weak_arr, 0, {tag = 0, value1})
assert_eq(result, 0, "weak_set returns 0")

local retrieved = weak.caml_weak_get(weak_arr, 0)
assert_type(retrieved, "table", "weak_get returns table")
assert_true(retrieved.tag == 0, "retrieved value has correct tag")

-- Test weak_check
local check_result = weak.caml_weak_check(weak_arr, 0)
assert_eq(check_result, 1, "weak_check returns 1 for set value")

local check_empty = weak.caml_weak_check(weak_arr, 1)
assert_eq(check_empty, 0, "weak_check returns 0 for empty slot")

-- Test ephemeron key operations
local key1 = {key_data = "key1"}
result = weak.caml_ephe_set_key(ephe, 0, key1)
assert_eq(result, 0, "ephe_set_key returns 0")

local key_retrieved = weak.caml_ephe_get_key(ephe, 0)
assert_type(key_retrieved, "table", "ephe_get_key returns table")

-- Test ephemeron data operations
local data = {ephe_data = "data1"}
result = weak.caml_ephe_set_data(ephe, data)
assert_eq(result, 0, "ephe_set_data returns 0")

local data_retrieved = weak.caml_ephe_get_data(ephe)
assert_type(data_retrieved, "table", "ephe_get_data returns table")
assert_true(data_retrieved.tag == 0, "retrieved data has correct tag")

-- Test ephemeron check_data
local data_check = weak.caml_ephe_check_data(ephe)
assert_eq(data_check, 1, "ephe_check_data returns 1 when data is set")

-- Test ephemeron unset_data
result = weak.caml_ephe_unset_data(ephe)
assert_eq(result, 0, "ephe_unset_data returns 0")

data_check = weak.caml_ephe_check_data(ephe)
assert_eq(data_check, 0, "ephe_check_data returns 0 after unset")

-- Test ephemeron key copy
local key2 = {key_data = "key2"}
result = weak.caml_ephe_set_key(ephe, 1, key2)
local key_copy = weak.caml_ephe_get_key_copy(ephe, 1)
assert_type(key_copy, "table", "ephe_get_key_copy returns table")

-- Test ephemeron data copy
result = weak.caml_ephe_set_data(ephe, {copy_data = "data"})
local data_copy = weak.caml_ephe_get_data_copy(ephe)
assert_type(data_copy, "table", "ephe_get_data_copy returns table")

-- Test weak blit
local weak_arr2 = weak.caml_weak_create(5)
result = weak.caml_weak_blit(weak_arr, 0, weak_arr2, 0, 1)
assert_eq(result, 0, "weak_blit returns 0")

-- Test ephemeron blit
local ephe2 = weak.caml_ephe_create(3)
result = weak.caml_ephe_blit_key(ephe, 0, ephe2, 0, 2)
assert_eq(result, 0, "ephe_blit_key returns 0")

result = weak.caml_ephe_blit_data(ephe, ephe2)
assert_eq(result, 0, "ephe_blit_data returns 0")

-- Test cyclic references with weak tables
local cycle1 = {name = "cycle1"}
local cycle2 = {name = "cycle2"}
cycle1.ref = cycle2
cycle2.ref = cycle1

-- Store in weak array
result = weak.caml_weak_set(weak_arr, 2, {tag = 0, cycle1})
assert_eq(result, 0, "can store cyclic structure")

-- Retrieve it
local cycle_retrieved = weak.caml_weak_get(weak_arr, 2)
assert_type(cycle_retrieved, "table", "can retrieve cyclic structure")

print("All Weak table tests passed!")
print("All GC integration tests passed!")
