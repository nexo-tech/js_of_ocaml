-- Tests for Lazy module

local lazy = require("lazy")

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

print("Testing Lazy module...")

-- Test lazy value construction
local counter = 0
local lazy_val = lazy.caml_lazy_from_fun(function()
  counter = counter + 1
  return 42
end)

assert_true(lazy.caml_lazy_is_lazy(lazy_val), "is_lazy before force")
assert_false(lazy.caml_lazy_is_val(lazy_val), "not is_val before force")
assert_eq(counter, 0, "thunk not called yet")

-- Test forcing
local result = lazy.caml_lazy_force(lazy_val)
assert_eq(result, 42, "force returns correct value")
assert_eq(counter, 1, "thunk called once")
assert_true(lazy.caml_lazy_is_val(lazy_val), "is_val after force")
assert_false(lazy.caml_lazy_is_lazy(lazy_val), "not is_lazy after force")

-- Test caching: forcing again should not re-evaluate
local result2 = lazy.caml_lazy_force(lazy_val)
assert_eq(result2, 42, "force returns same value")
assert_eq(counter, 1, "thunk still called only once (cached)")

-- Test already-evaluated lazy value
local forward_val = lazy.caml_lazy_make_forward(100)
assert_true(lazy.caml_lazy_is_val(forward_val), "forward is_val")
assert_false(lazy.caml_lazy_is_lazy(forward_val), "forward not is_lazy")
assert_eq(lazy.caml_lazy_force(forward_val), 100, "force forward value")

-- Test lazy_from_val
local from_val = lazy.caml_lazy_from_val(200)
assert_true(lazy.caml_lazy_is_val(from_val), "from_val is_val")
assert_eq(lazy.caml_lazy_force(from_val), 200, "force from_val")

-- Test recursive forcing detection
local recursive_lazy = nil
recursive_lazy = lazy.caml_lazy_from_fun(function()
  return lazy.caml_lazy_force(recursive_lazy)
end)

local success, err = pcall(function()
  lazy.caml_lazy_force(recursive_lazy)
end)
assert_false(success, "recursive forcing should fail")
assert_true(string.find(err, "recursive") or string.find(err, "undefined"), "error mentions recursion")

-- Test exception handling
local exception_lazy = lazy.caml_lazy_from_fun(function()
  error("test exception")
end)

local success2, err2 = pcall(function()
  lazy.caml_lazy_force(exception_lazy)
end)
assert_false(success2, "forcing exception should fail")

-- After exception, lazy value should be reset to lazy state
assert_true(lazy.caml_lazy_is_lazy(exception_lazy), "lazy reset after exception")

-- Can force again after exception
local success3, err3 = pcall(function()
  lazy.caml_lazy_force(exception_lazy)
end)
assert_false(success3, "forcing again should fail again")

-- Test lazy_map
local base_lazy = lazy.caml_lazy_from_fun(function()
  return 10
end)

local mapped_lazy = lazy.caml_lazy_map(function(x) return x * 2 end, base_lazy)
assert_true(lazy.caml_lazy_is_lazy(mapped_lazy), "mapped lazy is lazy")
assert_eq(lazy.caml_lazy_force(mapped_lazy), 20, "map applies function")
assert_true(lazy.caml_lazy_is_val(base_lazy), "base lazy was forced")
assert_true(lazy.caml_lazy_is_val(mapped_lazy), "mapped lazy is now val")

-- Test lazy_map2
local lazy1 = lazy.caml_lazy_from_fun(function() return 3 end)
local lazy2 = lazy.caml_lazy_from_fun(function() return 4 end)
local lazy_sum = lazy.caml_lazy_map2(function(a, b) return a + b end, lazy1, lazy2)

assert_true(lazy.caml_lazy_is_lazy(lazy_sum), "map2 result is lazy")
assert_eq(lazy.caml_lazy_force(lazy_sum), 7, "map2 applies function")
assert_true(lazy.caml_lazy_is_val(lazy1), "lazy1 was forced")
assert_true(lazy.caml_lazy_is_val(lazy2), "lazy2 was forced")

-- Test lazy_from_exception
local exn_lazy = lazy.caml_lazy_from_exception("custom error")
local success4, err4 = pcall(function()
  lazy.caml_lazy_force(exn_lazy)
end)
assert_false(success4, "from_exception should raise")

-- Test lazy_read_result
local forward_for_read = lazy.caml_lazy_make_forward(123)
assert_eq(lazy.caml_lazy_read_result(forward_for_read), 123, "read_result on forward")

local lazy_for_read = lazy.caml_lazy_from_fun(function() return 456 end)
-- Before forcing, read_result returns the lazy value itself
local read_before = lazy.caml_lazy_read_result(lazy_for_read)
assert_eq(read_before, lazy_for_read, "read_result on lazy returns lazy")

-- After forcing, read_result returns the value
lazy.caml_lazy_force(lazy_for_read)
assert_eq(lazy.caml_lazy_read_result(lazy_for_read), 456, "read_result after force")

-- Test lazy_force_val (alias)
local lazy_for_alias = lazy.caml_lazy_from_fun(function() return 789 end)
assert_eq(lazy.caml_lazy_force_val(lazy_for_alias), 789, "force_val works")

-- Test lazy_force_unit
local side_effect_counter = 0
local lazy_unit = lazy.caml_lazy_from_fun(function()
  side_effect_counter = side_effect_counter + 1
  return 999
end)
local unit_result = lazy.caml_lazy_force_unit(lazy_unit)
assert_eq(unit_result, 0, "force_unit returns unit (0)")
assert_eq(side_effect_counter, 1, "side effect executed")

-- Test lazy_tag
local lazy_tagged = lazy.caml_lazy_from_fun(function() return 1 end)
assert_eq(lazy.caml_lazy_tag(lazy_tagged), 246, "lazy tag is 246")
lazy.caml_lazy_force(lazy_tagged)
assert_eq(lazy.caml_lazy_tag(lazy_tagged), 250, "forward tag is 250")

-- Test state transitions manually
local manual_lazy = lazy.caml_lazy_from_fun(function() return 555 end)
assert_eq(lazy.caml_lazy_update_to_forcing(manual_lazy), 0, "update to forcing succeeds")
assert_true(lazy.caml_lazy_is_forcing(manual_lazy), "is_forcing")
assert_eq(lazy.caml_lazy_update_to_forcing(manual_lazy), 1, "update to forcing fails when already forcing")

manual_lazy[2] = 555  -- Set the result
lazy.caml_lazy_update_to_forward(manual_lazy)
assert_true(lazy.caml_lazy_is_val(manual_lazy), "is_val after update_to_forward")
assert_eq(lazy.caml_lazy_force(manual_lazy), 555, "can read value")

-- Test reset_to_lazy
local reset_lazy = lazy.caml_lazy_from_fun(function() return 888 end)
lazy.caml_lazy_update_to_forcing(reset_lazy)
lazy.caml_lazy_reset_to_lazy(reset_lazy)
assert_true(lazy.caml_lazy_is_lazy(reset_lazy), "reset back to lazy")

print("All Lazy tests passed!")
