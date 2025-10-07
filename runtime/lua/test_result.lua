-- Tests for Result module

local result = require("result")

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

print("Testing Result module...")

-- Test Ok
local ok_5 = result.caml_result_ok(5)
assert_true(result.caml_result_is_ok(ok_5), "is_ok")
assert_false(result.caml_result_is_error(ok_5), "is_error for Ok")
assert_eq(result.caml_result_get_ok(ok_5), 5, "get_ok")

-- Test Error
local err_msg = result.caml_result_error("error message")
assert_false(result.caml_result_is_ok(err_msg), "is_ok for Error")
assert_true(result.caml_result_is_error(err_msg), "is_error")
assert_eq(result.caml_result_get_error(err_msg), "error message", "get_error")

-- Test value with default
assert_eq(result.caml_result_value(ok_5, 10), 5, "value for Ok")
assert_eq(result.caml_result_value(err_msg, 10), 10, "value for Error")

-- Test map
local ok_mapped = result.caml_result_map(function(x) return x * 2 end, ok_5)
assert_eq(result.caml_result_get_ok(ok_mapped), 10, "map on Ok")

local err_mapped = result.caml_result_map(function(x) return x * 2 end, err_msg)
assert_eq(result.caml_result_get_error(err_mapped), "error message", "map on Error")

-- Test map_error
local ok_mapped_err = result.caml_result_map_error(function(e) return "mapped: " .. e end, ok_5)
assert_eq(result.caml_result_get_ok(ok_mapped_err), 5, "map_error on Ok")

local err_mapped_err = result.caml_result_map_error(function(e) return "mapped: " .. e end, err_msg)
assert_eq(result.caml_result_get_error(err_mapped_err), "mapped: error message", "map_error on Error")

-- Test bind
local ok_bound = result.caml_result_bind(ok_5, function(x) return result.caml_result_ok(x + 1) end)
assert_eq(result.caml_result_get_ok(ok_bound), 6, "bind on Ok")

local err_bound = result.caml_result_bind(err_msg, function(x) return result.caml_result_ok(x + 1) end)
assert_eq(result.caml_result_get_error(err_bound), "error message", "bind on Error")

-- Test fold
local ok_folded = result.caml_result_fold(
  function(x) return x * 2 end,
  function(e) return 100 end,
  ok_5
)
assert_eq(ok_folded, 10, "fold on Ok")

local err_folded = result.caml_result_fold(
  function(x) return x * 2 end,
  function(e) return 100 end,
  err_msg
)
assert_eq(err_folded, 100, "fold on Error")

-- Test equal
local ok_5_2 = result.caml_result_ok(5)
local ok_6 = result.caml_result_ok(6)
local err_msg_2 = result.caml_result_error("error message")
local err_other = result.caml_result_error("other error")

local eq_fn = function(a, b) return a == b end

assert_true(result.caml_result_equal(eq_fn, eq_fn, ok_5, ok_5_2), "Ok(5) == Ok(5)")
assert_false(result.caml_result_equal(eq_fn, eq_fn, ok_5, ok_6), "Ok(5) != Ok(6)")
assert_true(result.caml_result_equal(eq_fn, eq_fn, err_msg, err_msg_2), "Error == Error")
assert_false(result.caml_result_equal(eq_fn, eq_fn, err_msg, err_other), "Error != Error2")
assert_false(result.caml_result_equal(eq_fn, eq_fn, ok_5, err_msg), "Ok != Error")

-- Test compare
local cmp_fn = function(a, b) return a < b and -1 or (a > b and 1 or 0) end

assert_eq(result.caml_result_compare(cmp_fn, cmp_fn, ok_5, ok_5_2), 0, "Ok(5) cmp Ok(5)")
assert_true(result.caml_result_compare(cmp_fn, cmp_fn, ok_5, ok_6) < 0, "Ok(5) < Ok(6)")
assert_true(result.caml_result_compare(cmp_fn, cmp_fn, ok_6, ok_5) > 0, "Ok(6) > Ok(5)")
assert_true(result.caml_result_compare(cmp_fn, cmp_fn, ok_5, err_msg) < 0, "Ok < Error")
assert_true(result.caml_result_compare(cmp_fn, cmp_fn, err_msg, ok_5) > 0, "Error > Ok")

print("All Result tests passed!")
