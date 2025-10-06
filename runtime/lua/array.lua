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

--- Array Operations Module
--
-- This module provides OCaml array operations for Lua.
-- OCaml arrays are mutable, fixed-size sequences indexed from 0.
-- In Lua, we represent them as tables with:
-- - tag = 0 (array tag for OCaml blocks)
-- - [1..n] = array elements (1-indexed in Lua, but exposed as 0-indexed to OCaml)
-- - length stored at index 0

local core = require("core")
local M = {}

--- Create a new array of given length with initial value
-- @param len number Array length
-- @param init any Initial value for all elements
-- @return table Array
function M.make(len, init)
  local arr = { tag = 0, [0] = len }
  for i = 1, len do
    arr[i] = init
  end
  return arr
end

--- Create array from list
-- @param list table OCaml list (tag-based structure)
-- @return table Array
function M.of_list(list)
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

--- Convert array to list
-- @param arr table Array
-- @return table OCaml list
function M.to_list(arr)
  local len = arr[0]
  local result = 0  -- nil/empty list

  -- Build list in reverse
  for i = len, 1, -1 do
    result = { tag = 0, [1] = arr[i], [2] = result }
  end

  return result
end

--- Get array length
-- @param arr table Array
-- @return number Length
function M.length(arr)
  return arr[0]
end

--- Get element at index (with bounds checking)
-- @param arr table Array
-- @param idx number Index (0-based)
-- @return any Element value
function M.get(arr, idx)
  local len = arr[0]
  if idx < 0 or idx >= len then
    error("index out of bounds")
  end
  return arr[idx + 1]  -- Convert to 1-indexed
end

--- Set element at index (with bounds checking)
-- @param arr table Array
-- @param idx number Index (0-based)
-- @param val any New value
function M.set(arr, idx, val)
  local len = arr[0]
  if idx < 0 or idx >= len then
    error("index out of bounds")
  end
  arr[idx + 1] = val
end

--- Get element at index (unsafe, no bounds checking)
-- @param arr table Array
-- @param idx number Index (0-based)
-- @return any Element value
function M.unsafe_get(arr, idx)
  return arr[idx + 1]
end

--- Set element at index (unsafe, no bounds checking)
-- @param arr table Array
-- @param idx number Index (0-based)
-- @param val any New value
function M.unsafe_set(arr, idx, val)
  arr[idx + 1] = val
end

--- Copy a sub-array
-- @param arr table Source array
-- @param start number Start index (0-based)
-- @param len number Length to copy
-- @return table New array with copied elements
function M.sub(arr, start, len)
  local result = { tag = 0, [0] = len }
  for i = 0, len - 1 do
    result[i + 1] = arr[start + i + 1]
  end
  return result
end

--- Append two arrays
-- @param arr1 table First array
-- @param arr2 table Second array
-- @return table New array with concatenated elements
function M.append(arr1, arr2)
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

--- Concatenate a list of arrays
-- @param list table OCaml list of arrays
-- @return table New array with all elements
function M.concat(list)
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

--- Blit (copy) elements from one array to another
-- @param src table Source array
-- @param src_pos number Source start position (0-based)
-- @param dst table Destination array
-- @param dst_pos number Destination start position (0-based)
-- @param len number Number of elements to copy
function M.blit(src, src_pos, dst, dst_pos, len)
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

--- Fill array range with value
-- @param arr table Array
-- @param start number Start position (0-based)
-- @param len number Number of elements to fill
-- @param val any Fill value
function M.fill(arr, start, len, val)
  for i = 0, len - 1 do
    arr[start + i + 1] = val
  end
end

--- Create array by mapping function over range
-- @param len number Array length
-- @param f function Function taking index (0-based) and returning value
-- @return table New array
function M.init(len, f)
  local arr = { tag = 0, [0] = len }
  for i = 0, len - 1 do
    arr[i + 1] = f(i)
  end
  return arr
end

--- Apply function to each element
-- @param f function Function to apply
-- @param arr table Array
function M.iter(f, arr)
  local len = arr[0]
  for i = 0, len - 1 do
    f(arr[i + 1])
  end
end

--- Apply function to each element with index
-- @param f function Function taking index and value
-- @param arr table Array
function M.iteri(f, arr)
  local len = arr[0]
  for i = 0, len - 1 do
    f(i, arr[i + 1])
  end
end

--- Map function over array
-- @param f function Mapping function
-- @param arr table Source array
-- @return table New array with mapped values
function M.map(f, arr)
  local len = arr[0]
  local result = { tag = 0, [0] = len }
  for i = 0, len - 1 do
    result[i + 1] = f(arr[i + 1])
  end
  return result
end

--- Map function over array with index
-- @param f function Mapping function taking index and value
-- @param arr table Source array
-- @return table New array with mapped values
function M.mapi(f, arr)
  local len = arr[0]
  local result = { tag = 0, [0] = len }
  for i = 0, len - 1 do
    result[i + 1] = f(i, arr[i + 1])
  end
  return result
end

--- Fold left over array
-- @param f function Folding function (acc, elem) -> acc
-- @param init any Initial accumulator
-- @param arr table Array
-- @return any Final accumulator
function M.fold_left(f, init, arr)
  local acc = init
  local len = arr[0]
  for i = 0, len - 1 do
    acc = f(acc, arr[i + 1])
  end
  return acc
end

--- Fold right over array
-- @param f function Folding function (elem, acc) -> acc
-- @param arr table Array
-- @param init any Initial accumulator
-- @return any Final accumulator
function M.fold_right(f, arr, init)
  local acc = init
  local len = arr[0]
  for i = len - 1, 0, -1 do
    acc = f(arr[i + 1], acc)
  end
  return acc
end

-- Register primitives
core.register("caml_make_vect", M.make)
core.register("caml_array_of_list", M.of_list)
core.register("caml_array_to_list", M.to_list)
core.register("caml_array_length", M.length)
core.register("caml_array_get", M.get)
core.register("caml_array_set", M.set)
core.register("caml_array_unsafe_get", M.unsafe_get)
core.register("caml_array_unsafe_set", M.unsafe_set)
core.register("caml_array_sub", M.sub)
core.register("caml_array_append", M.append)
core.register("caml_array_concat", M.concat)
core.register("caml_array_blit", M.blit)
core.register("caml_array_fill", M.fill)

-- Float array aliases (same implementation in Lua)
core.register("caml_floatarray_get", M.get)
core.register("caml_floatarray_set", M.set)
core.register("caml_floatarray_sub", M.sub)
core.register("caml_floatarray_append", M.append)
core.register("caml_floatarray_concat", M.concat)
core.register("caml_floatarray_blit", M.blit)

-- Uniform array aliases (OCaml 5.3+)
core.register("caml_uniform_array_sub", M.sub)
core.register("caml_uniform_array_append", M.append)
core.register("caml_uniform_array_concat", M.concat)
core.register("caml_uniform_array_blit", M.blit)

-- Register module
core.register_module("array", M)

return M
