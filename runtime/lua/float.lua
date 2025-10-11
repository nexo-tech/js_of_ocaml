-- Lua_of_ocaml runtime support
-- Float operations and IEEE 754 support
--
-- Provides OCaml float operations with proper NaN/infinity handling

--Provides: caml_classify_float
function caml_classify_float(x)
  -- FP_nan = 4, FP_infinite = 3, FP_zero = 2, FP_subnormal = 1, FP_normal = 0
  if x ~= x then
    return 4  -- FP_nan
  end
  if x == math.huge or x == -math.huge then
    return 3  -- FP_infinite
  end
  if x == 0 then
    return 2  -- FP_zero
  end
  -- Lua doesn't distinguish subnormal from normal
  -- We approximate: very small numbers are subnormal
  local abs_x = math.abs(x)
  if abs_x < 2.2250738585072014e-308 then
    return 1  -- FP_subnormal
  end
  return 0  -- FP_normal
end


--Provides: caml_modf_float
function caml_modf_float(x)
  local int_part = math.floor(x)
  local frac_part = x - int_part
  return {int_part, frac_part}
end

--Provides: caml_ldexp_float
function caml_ldexp_float(x, exp)
  -- x * 2^exp
  return x * (2 ^ exp)
end

--Provides: caml_frexp_float
function caml_frexp_float(x)
  -- Extract mantissa and exponent: x = m * 2^e where 0.5 <= |m| < 1
  if x == 0 then
    return {0, 0}
  end
  if x ~= x then
    return {0/0, 0}  -- NAN
  end
  if x == math.huge or x == -math.huge then
    return {x, 0}
  end

  local exp = 0
  local mantissa = math.abs(x)

  -- Normalize to [0.5, 1)
  while mantissa >= 1 do
    mantissa = mantissa / 2
    exp = exp + 1
  end
  while mantissa < 0.5 and mantissa > 0 do
    mantissa = mantissa * 2
    exp = exp - 1
  end

  if x < 0 then
    mantissa = -mantissa
  end

  return {mantissa, exp}
end

--Provides: caml_copysign_float
function caml_copysign_float(x, y)
  local abs_x = math.abs(x)
  if y < 0 or (y == 0 and 1/y < 0) then
    return -abs_x
  else
    return abs_x
  end
end

--Provides: caml_signbit_float
function caml_signbit_float(x)
  -- Returns 1 if sign bit is set (negative), 0 otherwise
  if x < 0 or (x == 0 and 1/x < 0) then
    return 1
  else
    return 0
  end
end

--Provides: caml_nextafter_float
function caml_nextafter_float(x, y)
  -- Next representable float after x in direction of y
  if x == y then
    return x
  end
  if x ~= x or y ~= y then
    return 0/0  -- NAN
  end

  -- Simple approximation using epsilon
  local eps = 2.220446049250313e-16
  if x < y then
    if x >= 0 then
      return x + eps * math.abs(x)
    else
      return x + eps * math.abs(x)
    end
  else
    if x >= 0 then
      return x - eps * math.abs(x)
    else
      return x - eps * math.abs(x)
    end
  end
end


--Provides: caml_trunc_float
function caml_trunc_float(x)
  if x >= 0 then
    return math.floor(x)
  else
    return math.ceil(x)
  end
end

--Provides: caml_round_float
function caml_round_float(x)
  -- Round to nearest integer, halfway cases away from zero
  if x >= 0 then
    return math.floor(x + 0.5)
  else
    return math.ceil(x - 0.5)
  end
end


--Provides: caml_is_nan
function caml_is_nan(x)
  return x ~= x
end

--Provides: caml_is_infinite
function caml_is_infinite(x)
  return x == math.huge or x == -math.huge
end

--Provides: caml_is_finite
function caml_is_finite(x)
  return x == x and x ~= math.huge and x ~= -math.huge
end


--Provides: caml_float_compare
function caml_float_compare(x, y)
  -- OCaml-style comparison: NaN = NaN, NaN < other values
  if x ~= x and y ~= y then
    return 0  -- NaN = NaN
  end
  if x ~= x then
    return -1  -- NaN < y
  end
  if y ~= y then
    return 1  -- x > NaN
  end
  if x < y then
    return -1
  end
  if x > y then
    return 1
  end
  return 0
end

--Provides: caml_float_min
function caml_float_min(x, y)
  if x ~= x then return x end
  if y ~= y then return y end
  if x < y then return x else return y end
end

--Provides: caml_float_max
function caml_float_max(x, y)
  if x ~= x then return x end
  if y ~= y then return y end
  if x > y then return x else return y end
end


-- [0] = 254 (double_array_tag)
-- [1..n] = float values

--Provides: caml_floatarray_create
function caml_floatarray_create(size)
  local arr = {}
  arr[0] = 254  -- double_array_tag
  for i = 1, size do
    arr[i] = 0.0
  end
  return arr
end

--Provides: caml_floatarray_get
function caml_floatarray_get(arr, idx)
  return arr[idx + 1]
end

--Provides: caml_floatarray_set
function caml_floatarray_set(arr, idx, val)
  arr[idx + 1] = val
  return 0
end

--Provides: caml_floatarray_unsafe_get
function caml_floatarray_unsafe_get(arr, idx)
  return arr[idx + 1]
end

--Provides: caml_floatarray_unsafe_set
function caml_floatarray_unsafe_set(arr, idx, val)
  arr[idx + 1] = val
  return 0
end

--Provides: caml_floatarray_length
function caml_floatarray_length(arr)
  return #arr
end

--Provides: caml_floatarray_blit
function caml_floatarray_blit(src, src_pos, dst, dst_pos, len)
  for i = 0, len - 1 do
    dst[dst_pos + i + 1] = src[src_pos + i + 1]
  end
  return 0
end

--Provides: caml_floatarray_fill
function caml_floatarray_fill(arr, ofs, len, val)
  for i = 0, len - 1 do
    arr[ofs + i + 1] = val
  end
  return 0
end

--Provides: caml_floatarray_of_array
function caml_floatarray_of_array(arr)
  local farr = caml_floatarray_create(#arr)
  for i = 1, #arr do
    farr[i] = arr[i]
  end
  return farr
end

--Provides: caml_floatarray_to_array
function caml_floatarray_to_array(farr)
  local arr = {}
  arr[0] = 0  -- normal array tag
  for i = 1, #farr do
    arr[i] = farr[i]
  end
  return arr
end

--Provides: caml_floatarray_concat
function caml_floatarray_concat(arrays)
  local total_len = 0
  for i = 1, #arrays do
    total_len = total_len + #arrays[i]
  end

  local result = caml_floatarray_create(total_len)
  local pos = 1
  for i = 1, #arrays do
    local arr = arrays[i]
    for j = 1, #arr do
      result[pos] = arr[j]
      pos = pos + 1
    end
  end

  return result
end

--Provides: caml_floatarray_sub
function caml_floatarray_sub(arr, ofs, len)
  local result = caml_floatarray_create(len)
  for i = 0, len - 1 do
    result[i + 1] = arr[ofs + i + 1]
  end
  return result
end

--Provides: caml_floatarray_append
function caml_floatarray_append(arr1, arr2)
  local len1 = #arr1
  local len2 = #arr2
  local result = caml_floatarray_create(len1 + len2)

  for i = 1, len1 do
    result[i] = arr1[i]
  end
  for i = 1, len2 do
    result[len1 + i] = arr2[i]
  end

  return result
end


--Provides: caml_format_float
function caml_format_float(fmt, x)
  -- Simple float formatting
  if x ~= x then
    return "nan"
  end
  if x == math.huge then
    return "inf"
  end
  if x == -math.huge then
    return "-inf"
  end
  return string.format(fmt, x)
end

--Provides: caml_hexstring_of_float
function caml_hexstring_of_float(x)
  -- Hexadecimal float representation
  if x ~= x then
    return "nan"
  end
  if x == math.huge then
    return "infinity"
  end
  if x == -math.huge then
    return "-infinity"
  end
  if x == 0 then
    if 1/x < 0 then
      return "-0x0p+0"
    else
      return "0x0p+0"
    end
  end

  -- Extract sign, mantissa, exponent
  local sign = ""
  if x < 0 then
    sign = "-"
    x = -x
  end

  local exp = 0
  while x >= 2 do
    x = x / 2
    exp = exp + 1
  end
  while x < 1 do
    x = x * 2
    exp = exp - 1
  end

  -- Convert mantissa to hex
  local mantissa = math.floor(x * 0x10000000000000)
  local mantissa_hex = string.format("%x", mantissa)

  return string.format("%s0x%s.%sp%+d", sign,
    string.sub(mantissa_hex, 1, 1),
    string.sub(mantissa_hex, 2),
    exp)
end

--Provides: caml_float_of_string
function caml_float_of_string(s)
  -- Parse float from string
  if s == "nan" or s == "NaN" then
    return 0/0  -- NAN
  end
  if s == "inf" or s == "infinity" or s == "+inf" or s == "+infinity" then
    return math.huge  -- INFINITY
  end
  if s == "-inf" or s == "-infinity" then
    return -math.huge  -- NEG_INFINITY
  end

  local num = tonumber(s)
  if num == nil then
    error("invalid float string: " .. s)
  end
  return num
end
