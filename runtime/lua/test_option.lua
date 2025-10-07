-- Tests for Option module

local option = require("option")

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

print("Testing Option module...")

-- Test None
local none = option.caml_option_none()
assert_eq(none, 0, "None should be 0")
assert_true(option.caml_option_is_none(none), "is_none")
assert_false(option.caml_option_is_some(none), "is_some for None")

-- Test Some
local some_5 = option.caml_option_some(5)
assert_false(option.caml_option_is_none(some_5), "is_none for Some")
assert_true(option.caml_option_is_some(some_5), "is_some")
assert_eq(option.caml_option_get(some_5), 5, "get Some")

-- Test value with default
assert_eq(option.caml_option_value(none, 10), 10, "value with default for None")
assert_eq(option.caml_option_value(some_5, 10), 5, "value with default for Some")

-- Test map
local none_mapped = option.caml_option_map(function(x) return x * 2 end, none)
assert_eq(none_mapped, 0, "map on None")

local some_mapped = option.caml_option_map(function(x) return x * 2 end, some_5)
assert_eq(option.caml_option_get(some_mapped), 10, "map on Some")

-- Test bind
local none_bound = option.caml_option_bind(none, function(x) return option.caml_option_some(x + 1) end)
assert_eq(none_bound, 0, "bind on None")

local some_bound = option.caml_option_bind(some_5, function(x) return option.caml_option_some(x + 1) end)
assert_eq(option.caml_option_get(some_bound), 6, "bind on Some")

-- Test fold
local none_folded = option.caml_option_fold(100, function(x) return x * 2 end, none)
assert_eq(none_folded, 100, "fold on None")

local some_folded = option.caml_option_fold(100, function(x) return x * 2 end, some_5)
assert_eq(some_folded, 10, "fold on Some")

-- Test equal
local some_5_2 = option.caml_option_some(5)
local some_6 = option.caml_option_some(6)

assert_true(option.caml_option_equal(function(a, b) return a == b end, none, none), "None == None")
assert_true(option.caml_option_equal(function(a, b) return a == b end, some_5, some_5_2), "Some(5) == Some(5)")
assert_false(option.caml_option_equal(function(a, b) return a == b end, some_5, some_6), "Some(5) != Some(6)")
assert_false(option.caml_option_equal(function(a, b) return a == b end, none, some_5), "None != Some")

-- Test compare
assert_eq(option.caml_option_compare(function(a, b) return a - b end, none, none), 0, "None cmp None")
assert_eq(option.caml_option_compare(function(a, b) return a - b end, none, some_5), -1, "None < Some")
assert_eq(option.caml_option_compare(function(a, b) return a - b end, some_5, none), 1, "Some > None")
assert_eq(option.caml_option_compare(function(a, b) return a - b end, some_5, some_5_2), 0, "Some(5) cmp Some(5)")
assert_true(option.caml_option_compare(function(a, b) return a - b end, some_5, some_6) < 0, "Some(5) < Some(6)")

print("All Option tests passed!")
