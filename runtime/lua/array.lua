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
--
-- This module provides OCaml array operations for Lua.
-- OCaml arrays are mutable, fixed-size sequences indexed from 0.
-- In Lua, we represent them as tables with:
-- - tag = 0 (array tag for OCaml blocks)
-- - [1..n] = array elements (1-indexed in Lua, but exposed as 0-indexed to OCaml)
-- - length stored at index 0

--Provides: caml_make_vect
function caml_make_vect(len, init)
  local arr = { tag = 0, [0] = len }
  for i = 1, len do
    arr[i] = init
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
    l = l[2]  -- tail
  end

  -- Build array
  local arr = { tag = 0, [0] = len }
  l = list
  local i = 1
  while l ~= 0 do
    arr[i] = l[1]  -- head
    l = l[2]       -- tail
    i = i + 1
  end

  return arr
end

--Provides: caml_array_to_list
function caml_array_to_list(arr)
  local len = arr[0]
  local result = 0  -- nil/empty list

  -- Build list in reverse
  for i = len, 1, -1 do
    result = { tag = 0, [1] = arr[i], [2] = result }
  end

  return result
end

--Provides: caml_array_length
function caml_array_length(arr)
  return arr[0]
end

--Provides: caml_array_get
function caml_array_get(arr, idx)
  local len = arr[0]
  if idx < 0 or idx >= len then
    error("index out of bounds")
  end
  return arr[idx + 1]  -- Convert to 1-indexed
end

--Provides: caml_array_set
function caml_array_set(arr, idx, val)
  local len = arr[0]
  if idx < 0 or idx >= len then
    error("index out of bounds")
  end
  arr[idx + 1] = val
end

--Provides: caml_array_unsafe_get
function caml_array_unsafe_get(arr, idx)
  return arr[idx + 1]
end

--Provides: caml_array_unsafe_set
function caml_array_unsafe_set(arr, idx, val)
  arr[idx + 1] = val
end

--Provides: caml_array_sub
function caml_array_sub(arr, start, len)
  local result = { tag = 0, [0] = len }
  for i = 0, len - 1 do
    result[i + 1] = arr[start + i + 1]
  end
  return result
end

--Provides: caml_array_append
function caml_array_append(arr1, arr2)
  local len1 = arr1[0]
  local len2 = arr2[0]
  local len = len1 + len2

  local result = { tag = 0, [0] = len }

  -- Copy first array
  for i = 1, len1 do
    result[i] = arr1[i]
  end

  -- Copy second array
  for i = 1, len2 do
    result[len1 + i] = arr2[i]
  end

  return result
end

--Provides: caml_array_concat
function caml_array_concat(list)
  -- Calculate total length
  local total_len = 0
  local l = list
  while l ~= 0 do
    local arr = l[1]  -- head
    total_len = total_len + arr[0]
    l = l[2]  -- tail
  end

  -- Build result
  local result = { tag = 0, [0] = total_len }
  local pos = 1

  l = list
  while l ~= 0 do
    local arr = l[1]
    local arr_len = arr[0]
    for i = 1, arr_len do
      result[pos] = arr[i]
      pos = pos + 1
    end
    l = l[2]
  end

  return result
end

--Provides: caml_array_blit
function caml_array_blit(src, src_pos, dst, dst_pos, len)
  -- Handle overlapping ranges by copying in appropriate direction
  if dst == src and dst_pos > src_pos then
    -- Copy backwards to handle overlap
    for i = len - 1, 0, -1 do
      dst[dst_pos + i + 1] = src[src_pos + i + 1]
    end
  else
    -- Copy forwards
    for i = 0, len - 1 do
      dst[dst_pos + i + 1] = src[src_pos + i + 1]
    end
  end
end

--Provides: caml_array_fill
function caml_array_fill(arr, start, len, val)
  for i = 0, len - 1 do
    arr[start + i + 1] = val
  end
end

--Provides: caml_array_init
function caml_array_init(len, f)
  local arr = { tag = 0, [0] = len }
  for i = 0, len - 1 do
    arr[i + 1] = f(i)
  end
  return arr
end

--Provides: caml_array_iter
function caml_array_iter(f, arr)
  local len = arr[0]
  for i = 0, len - 1 do
    f(arr[i + 1])
  end
end

--Provides: caml_array_iteri
function caml_array_iteri(f, arr)
  local len = arr[0]
  for i = 0, len - 1 do
    f(i, arr[i + 1])
  end
end

--Provides: caml_array_map
function caml_array_map(f, arr)
  local len = arr[0]
  local result = { tag = 0, [0] = len }
  for i = 0, len - 1 do
    result[i + 1] = f(arr[i + 1])
  end
  return result
end

--Provides: caml_array_mapi
function caml_array_mapi(f, arr)
  local len = arr[0]
  local result = { tag = 0, [0] = len }
  for i = 0, len - 1 do
    result[i + 1] = f(i, arr[i + 1])
  end
  return result
end

--Provides: caml_array_fold_left
function caml_array_fold_left(f, init, arr)
  local acc = init
  local len = arr[0]
  for i = 0, len - 1 do
    acc = f(acc, arr[i + 1])
  end
  return acc
end

--Provides: caml_array_fold_right
function caml_array_fold_right(f, arr, init)
  local acc = init
  local len = arr[0]
  for i = len - 1, 0, -1 do
    acc = f(arr[i + 1], acc)
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
