-- Lua_of_ocaml runtime support
-- http://www.ocsigen.org/js_of_ocaml/
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, with linking exception;
-- either version 2.1 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

--- Array Operations Primitives

--Provides: caml_make_vect
function caml_make_vect(len, init)
  -- Arrays follow JS representation: {tag, elem0, elem1, ...}
  -- where [1] = tag (0), [2] = elem0, [3] = elem1, etc.
  -- This matches compiler's Block representation
  local arr = {0}  -- tag at [1]
  for i = 1, len do
    arr[i + 1] = init  -- elements at [2], [3], ...
  end
  return arr
end

--Provides: caml_array_of_list
function caml_array_of_list(list)
  -- Count list length
  local len = 0
  local l = list
  while l ~= 0 do
    len = len + 1
    l = l[3]  -- tail (new representation)
  end

  -- Build array: {tag, elem0, elem1, ...}
  local arr = {0}  -- tag at [1]
  l = list
  local i = 2  -- elements start at [2]
  while l ~= 0 do
    arr[i] = l[2]  -- head (new representation)
    l = l[3]       -- tail (new representation)
    i = i + 1
  end

  return arr
end

--Provides: caml_array_to_list
function caml_array_to_list(arr)
  -- Array: {tag, elem0, elem1, ...} where [1]=tag, length = #arr - 1
  local len = #arr - 1
  local result = 0  -- empty list

  -- Build list in reverse
  for i = len, 1, -1 do
    result = {0, arr[i + 1], result}  -- new list representation
  end

  return result
end

--Provides: caml_array_length
function caml_array_length(arr)
  -- Length is #arr - 1 (subtract tag)
  return #arr - 1
end

--Provides: caml_array_get
function caml_array_get(arr, idx)
  local len = #arr - 1
  if idx < 0 or idx >= len then
    error("index out of bounds")
  end
  return arr[idx + 2]  -- elem 0 at index 2
end

--Provides: caml_array_set
function caml_array_set(arr, idx, val)
  local len = #arr - 1
  if idx < 0 or idx >= len then
    error("index out of bounds")
  end
  arr[idx + 2] = val  -- elem 0 at index 2
end

--Provides: caml_array_unsafe_get
function caml_array_unsafe_get(arr, idx)
  return arr[idx + 2]  -- elem 0 at index 2
end

--Provides: caml_array_unsafe_set
function caml_array_unsafe_set(arr, idx, val)
  arr[idx + 2] = val  -- elem 0 at index 2
end

--Provides: caml_array_sub
function caml_array_sub(arr, start, len)
  -- Create result array: {tag, elem0, elem1, ...}
  local result = {0}  -- tag at [1]
  for i = 0, len - 1 do
    result[i + 2] = arr[start + i + 2]  -- elements at [2], [3], ...
  end
  return result
end

--Provides: caml_array_append
function caml_array_append(arr1, arr2)
  local len1 = #arr1 - 1
  local len2 = #arr2 - 1

  local result = {0}  -- tag at [1]

  -- Copy first array
  for i = 1, len1 do
    result[i + 1] = arr1[i + 1]  -- Copy from [2], [3], ... to [2], [3], ...
  end

  -- Copy second array
  for i = 1, len2 do
    result[len1 + i + 1] = arr2[i + 1]
  end

  return result
end

--Provides: caml_array_concat
function caml_array_concat(list)
  -- Calculate total length
  local total_len = 0
  local l = list
  while l ~= 0 do
    local arr = l[2]  -- head (new list representation)
    total_len = total_len + (#arr - 1)
    l = l[3]  -- tail (new list representation)
  end

  -- Build result
  local result = {0}  -- tag at [1]
  local pos = 2  -- elements start at [2]

  l = list
  while l ~= 0 do
    local arr = l[2]  -- head (new list representation)
    local arr_len = #arr - 1
    for i = 1, arr_len do
      result[pos] = arr[i + 1]  -- Copy from arr[2], arr[3], ...
      pos = pos + 1
    end
    l = l[3]  -- tail (new list representation)
  end

  return result
end

--Provides: caml_array_blit
function caml_array_blit(src, src_pos, dst, dst_pos, len)
  -- Handle overlapping ranges by copying in appropriate direction
  -- Elements at [2], [3], ... (index = element_index + 2)
  if dst == src and dst_pos > src_pos then
    -- Copy backwards to handle overlap
    for i = len - 1, 0, -1 do
      dst[dst_pos + i + 2] = src[src_pos + i + 2]
    end
  else
    -- Copy forwards
    for i = 0, len - 1 do
      dst[dst_pos + i + 2] = src[src_pos + i + 2]
    end
  end
end

--Provides: caml_array_fill
function caml_array_fill(arr, start, len, val)
  for i = 0, len - 1 do
    arr[start + i + 2] = val  -- elements at [2], [3], ...
  end
end

--Provides: caml_array_init
function caml_array_init(len, f)
  local arr = {0}  -- tag at [1]
  for i = 0, len - 1 do
    arr[i + 2] = f(i)  -- elements at [2], [3], ...
  end
  return arr
end

--Provides: caml_array_iter
function caml_array_iter(f, arr)
  local len = #arr - 1
  for i = 0, len - 1 do
    f(arr[i + 2])  -- elements at [2], [3], ...
  end
end

--Provides: caml_array_iteri
function caml_array_iteri(f, arr)
  local len = #arr - 1
  for i = 0, len - 1 do
    f(i, arr[i + 2])  -- elements at [2], [3], ...
  end
end

--Provides: caml_array_map
function caml_array_map(f, arr)
  local len = #arr - 1
  local result = {0}  -- tag at [1]
  for i = 0, len - 1 do
    result[i + 2] = f(arr[i + 2])  -- elements at [2], [3], ...
  end
  return result
end

--Provides: caml_array_mapi
function caml_array_mapi(f, arr)
  local len = #arr - 1
  local result = {0}  -- tag at [1]
  for i = 0, len - 1 do
    result[i + 2] = f(i, arr[i + 2])  -- elements at [2], [3], ...
  end
  return result
end

--Provides: caml_array_fold_left
function caml_array_fold_left(f, init, arr)
  local acc = init
  local len = #arr - 1
  for i = 0, len - 1 do
    acc = f(acc, arr[i + 2])  -- elements at [2], [3], ...
  end
  return acc
end

--Provides: caml_array_fold_right
function caml_array_fold_right(f, arr, init)
  local acc = init
  local len = #arr - 1
  for i = len - 1, 0, -1 do
    acc = f(arr[i + 2], acc)  -- elements at [2], [3], ...
  end
  return acc
end

--Provides: caml_floatarray_get
function caml_floatarray_get(arr, idx)
  return caml_array_get(arr, idx)
end

--Provides: caml_floatarray_set
function caml_floatarray_set(arr, idx, val)
  return caml_array_set(arr, idx, val)
end

--Provides: caml_floatarray_sub
function caml_floatarray_sub(arr, start, len)
  return caml_array_sub(arr, start, len)
end

--Provides: caml_floatarray_append
function caml_floatarray_append(arr1, arr2)
  return caml_array_append(arr1, arr2)
end

--Provides: caml_floatarray_concat
function caml_floatarray_concat(list)
  return caml_array_concat(list)
end

--Provides: caml_floatarray_blit
function caml_floatarray_blit(src, src_pos, dst, dst_pos, len)
  return caml_array_blit(src, src_pos, dst, dst_pos, len)
end

--Provides: caml_uniform_array_sub
function caml_uniform_array_sub(arr, start, len)
  return caml_array_sub(arr, start, len)
end

--Provides: caml_uniform_array_append
function caml_uniform_array_append(arr1, arr2)
  return caml_array_append(arr1, arr2)
end

--Provides: caml_uniform_array_concat
function caml_uniform_array_concat(list)
  return caml_array_concat(list)
end

--Provides: caml_uniform_array_blit
function caml_uniform_array_blit(src, src_pos, dst, dst_pos, len)
  return caml_array_blit(src, src_pos, dst, dst_pos, len)
end

--Provides: caml_check_bound
--Requires: caml_array_bound_error
function caml_check_bound(array, index)
  -- JS: if (index >>> 0 >= array.length - 1) caml_array_bound_error();
  -- In Lua: length is #array - 1 (subtract tag)
  local len = #array - 1
  if index < 0 or index >= len then
    caml_array_bound_error()
  end
  return array
end

--Provides: caml_check_bound_gen
--Requires: caml_check_bound
function caml_check_bound_gen(array, index)
  return caml_check_bound(array, index)
end

--Provides: caml_check_bound_float
--Requires: caml_check_bound
function caml_check_bound_float(array, index)
  return caml_check_bound(array, index)
end
