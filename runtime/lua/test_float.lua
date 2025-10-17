#!/usr/bin/env lua
-- Tests for Float primitives

-- Load float.lua directly (it defines global caml_* functions)
dofile("float.lua")

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

local function assert_nan(v, msg)
  if v == v then
    error(msg or "Assertion failed: expected NaN")
  end
end

local function assert_close(a, b, epsilon, msg)
  epsilon = epsilon or 1e-10
  if math.abs(a - b) > epsilon then
    error(msg or ("Assertion failed: " .. tostring(a) .. " not close to " .. tostring(b)))
  end
end

print("Testing Float module...")

--
-- Test Float Classification
--

local nan = 0/0
local inf = math.huge
local neg_inf = -math.huge

assert_eq(caml_classify_float(nan), 4, "NaN classification")
assert_eq(caml_classify_float(inf), 3, "Infinity classification")
assert_eq(caml_classify_float(neg_inf), 3, "Negative infinity classification")
assert_eq(caml_classify_float(0.0), 2, "Zero classification")
assert_eq(caml_classify_float(-0.0), 2, "Negative zero classification")
assert_eq(caml_classify_float(1.0), 0, "Normal float classification")
assert_eq(caml_classify_float(-42.5), 0, "Negative normal float classification")

-- Test subnormal (very small number)
local subnormal = 1e-320
assert_eq(caml_classify_float(subnormal), 1, "Subnormal classification")

print("Float classification tests passed!")

--
-- Test Special Value Checks
--

assert_true(caml_is_nan(nan), "is_nan for NaN")
assert_false(caml_is_nan(0.0), "is_nan for zero")
assert_false(caml_is_nan(inf), "is_nan for infinity")

assert_true(caml_is_infinite(inf), "is_infinite for inf")
assert_true(caml_is_infinite(neg_inf), "is_infinite for -inf")
assert_false(caml_is_infinite(0.0), "is_infinite for zero")
assert_false(caml_is_infinite(nan), "is_infinite for NaN")

assert_true(caml_is_finite(0.0), "is_finite for zero")
assert_true(caml_is_finite(42.5), "is_finite for normal")
assert_false(caml_is_finite(inf), "is_finite for inf")
assert_false(caml_is_finite(nan), "is_finite for NaN")

print("Special value check tests passed!")

--
-- Test Basic Float Operations
--

-- modf
local modf_result = caml_modf_float(3.14)
assert_eq(modf_result[1], 3, "modf integer part")
assert_close(modf_result[2], 0.14, 0.001, "modf fractional part")

local modf_result2 = caml_modf_float(-2.7)
assert_eq(modf_result2[1], -3, "modf negative integer part")
assert_close(modf_result2[2], 0.3, 0.001, "modf negative fractional part")

-- ldexp: x * 2^exp
assert_eq(caml_ldexp_float(1.0, 0), 1.0, "ldexp 1 * 2^0")
assert_eq(caml_ldexp_float(1.0, 3), 8.0, "ldexp 1 * 2^3")
assert_eq(caml_ldexp_float(3.0, 2), 12.0, "ldexp 3 * 2^2")
assert_eq(caml_ldexp_float(1.0, -2), 0.25, "ldexp 1 * 2^-2")

-- frexp: extract mantissa and exponent
local frexp_result = caml_frexp_float(8.0)
assert_eq(frexp_result[1], 0.5, "frexp mantissa of 8")
assert_eq(frexp_result[2], 4, "frexp exponent of 8")

local frexp_result2 = caml_frexp_float(0.0)
assert_eq(frexp_result2[1], 0.0, "frexp mantissa of 0")
assert_eq(frexp_result2[2], 0, "frexp exponent of 0")

-- copysign
assert_eq(caml_copysign_float(3.0, 5.0), 3.0, "copysign positive")
assert_eq(caml_copysign_float(3.0, -5.0), -3.0, "copysign negative")
assert_eq(caml_copysign_float(-3.0, 5.0), 3.0, "copysign change sign")

-- signbit
assert_eq(caml_signbit_float(5.0), 0, "signbit positive")
assert_eq(caml_signbit_float(-5.0), 1, "signbit negative")
assert_eq(caml_signbit_float(0.0), 0, "signbit zero")

print("Basic float operation tests passed!")

--
-- Test Rounding Operations
--

assert_eq(caml_trunc_float(3.7), 3, "trunc positive")
assert_eq(caml_trunc_float(-3.7), -3, "trunc negative")
assert_eq(caml_trunc_float(0.0), 0, "trunc zero")

assert_eq(caml_round_float(3.4), 3, "round 3.4")
assert_eq(caml_round_float(3.5), 4, "round 3.5")
assert_eq(caml_round_float(3.6), 4, "round 3.6")
assert_eq(caml_round_float(-2.5), -3, "round -2.5")

print("Rounding operation tests passed!")

--
-- Test Float Comparison
--

assert_eq(caml_float_compare(1.0, 2.0), -1, "compare 1 < 2")
assert_eq(caml_float_compare(2.0, 1.0), 1, "compare 2 > 1")
assert_eq(caml_float_compare(1.0, 1.0), 0, "compare 1 = 1")
assert_eq(caml_float_compare(nan, nan), 0, "compare NaN = NaN")
assert_eq(caml_float_compare(nan, 1.0), -1, "compare NaN < 1")
assert_eq(caml_float_compare(1.0, nan), 1, "compare 1 > NaN")

assert_eq(caml_float_min(1.0, 2.0), 1.0, "min 1 and 2")
assert_eq(caml_float_min(-1.0, 2.0), -1.0, "min -1 and 2")
assert_nan(caml_float_min(nan, 2.0), "min with NaN")

assert_eq(caml_float_max(1.0, 2.0), 2.0, "max 1 and 2")
assert_eq(caml_float_max(-1.0, 2.0), 2.0, "max -1 and 2")
assert_nan(caml_float_max(nan, 2.0), "max with NaN")

print("Float comparison tests passed!")

--
-- Test Float Arrays
--

local farr = caml_floatarray_create(5)
assert_eq(farr[0], 254, "float array tag")
assert_eq(caml_floatarray_length(farr), 5, "float array length")

-- set and get
caml_floatarray_set(farr, 0, 1.5)
caml_floatarray_set(farr, 1, 2.5)
caml_floatarray_set(farr, 2, 3.5)

assert_eq(caml_floatarray_get(farr, 0), 1.5, "get element 0")
assert_eq(caml_floatarray_get(farr, 1), 2.5, "get element 1")
assert_eq(caml_floatarray_get(farr, 2), 3.5, "get element 2")

-- unsafe operations
caml_floatarray_unsafe_set(farr, 3, 4.5)
assert_eq(caml_floatarray_unsafe_get(farr, 3), 4.5, "unsafe get/set")

-- fill
local farr2 = caml_floatarray_create(3)
caml_floatarray_fill(farr2, 0, 3, 9.9)
assert_eq(caml_floatarray_get(farr2, 0), 9.9, "fill element 0")
assert_eq(caml_floatarray_get(farr2, 1), 9.9, "fill element 1")
assert_eq(caml_floatarray_get(farr2, 2), 9.9, "fill element 2")

-- blit
local farr3 = caml_floatarray_create(5)
caml_floatarray_blit(farr, 0, farr3, 0, 3)
assert_eq(caml_floatarray_get(farr3, 0), 1.5, "blit element 0")
assert_eq(caml_floatarray_get(farr3, 1), 2.5, "blit element 1")
assert_eq(caml_floatarray_get(farr3, 2), 3.5, "blit element 2")

-- sub
local farr4 = caml_floatarray_sub(farr, 1, 2)
assert_eq(caml_floatarray_length(farr4), 2, "sub length")
assert_eq(caml_floatarray_get(farr4, 0), 2.5, "sub element 0")
assert_eq(caml_floatarray_get(farr4, 1), 3.5, "sub element 1")

-- append
local farr5 = caml_floatarray_create(2)
caml_floatarray_set(farr5, 0, 10.0)
caml_floatarray_set(farr5, 1, 20.0)

local farr6 = caml_floatarray_append(farr4, farr5)
assert_eq(caml_floatarray_length(farr6), 4, "append length")
assert_eq(caml_floatarray_get(farr6, 0), 2.5, "append element 0")
assert_eq(caml_floatarray_get(farr6, 1), 3.5, "append element 1")
assert_eq(caml_floatarray_get(farr6, 2), 10.0, "append element 2")
assert_eq(caml_floatarray_get(farr6, 3), 20.0, "append element 3")

-- of_array / to_array
local regular_arr = {1.1, 2.2, 3.3}
local farr7 = caml_floatarray_of_array(regular_arr)
assert_eq(caml_floatarray_get(farr7, 0), 1.1, "of_array element 0")
assert_eq(caml_floatarray_get(farr7, 1), 2.2, "of_array element 1")
assert_eq(caml_floatarray_get(farr7, 2), 3.3, "of_array element 2")

local regular_arr2 = caml_floatarray_to_array(farr7)
assert_eq(regular_arr2[0], 0, "to_array tag")
assert_eq(regular_arr2[1], 1.1, "to_array element 1")
assert_eq(regular_arr2[2], 2.2, "to_array element 2")
assert_eq(regular_arr2[3], 3.3, "to_array element 3")

print("Float array tests passed!")

--
-- Test Float Formatting and Parsing
--

assert_eq(caml_format_float("%.2f", 3.14159), "3.14", "format float")
assert_eq(caml_format_float("%e", 1000.0), "1.000000e+03", "format scientific")
assert_eq(caml_format_float("%g", nan), "nan", "format NaN")
assert_eq(caml_format_float("%g", inf), "inf", "format inf")
assert_eq(caml_format_float("%g", neg_inf), "-inf", "format -inf")

-- hexstring
local hex = caml_hexstring_of_float(1.0)
assert_true(string.find(hex, "0x") ~= nil, "hexstring contains 0x")

assert_eq(caml_hexstring_of_float(nan), "nan", "hexstring NaN")
assert_eq(caml_hexstring_of_float(inf), "infinity", "hexstring inf")
assert_eq(caml_hexstring_of_float(neg_inf), "-infinity", "hexstring -inf")

-- parsing
assert_eq(caml_float_of_string("3.14"), 3.14, "parse float")
assert_eq(caml_float_of_string("-2.5"), -2.5, "parse negative")
assert_nan(caml_float_of_string("nan"), "parse NaN")
assert_eq(caml_float_of_string("inf"), inf, "parse inf")
assert_eq(caml_float_of_string("-inf"), neg_inf, "parse -inf")

-- Error handling for invalid string
local ok, err = pcall(function() caml_float_of_string("invalid") end)
assert_false(ok, "parse invalid string should error")

print("Float formatting and parsing tests passed!")

--
-- Test Edge Cases
--

-- nextafter
local next = caml_nextafter_float(1.0, 2.0)
assert_true(next > 1.0, "nextafter increases")
assert_true(next < 1.1, "nextafter small increment")

local prev = caml_nextafter_float(1.0, 0.0)
assert_true(prev < 1.0, "nextafter decreases")
assert_true(prev > 0.9, "nextafter small decrement")

assert_eq(caml_nextafter_float(1.0, 1.0), 1.0, "nextafter same value")
assert_nan(caml_nextafter_float(nan, 1.0), "nextafter with NaN")

-- Zero sign handling
assert_eq(caml_copysign_float(1.0, 0.0), 1.0, "copysign +0")
-- Lua 5.1: -0.0 literal doesn't preserve sign, use -1.0 / math.huge instead
local neg_zero = -1.0 / math.huge
assert_eq(caml_copysign_float(1.0, neg_zero), -1.0, "copysign -0")

-- Large values
local large = 1e308
assert_eq(caml_classify_float(large), 0, "large value classification")

print("Edge case tests passed!")

print("All Float tests passed!")
