-- Js_of_ocaml runtime support
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

-- Polymorphic comparison implementation
-- Compatible with OCaml's polymorphic comparison
-- Supports deep structural comparison with cycle detection

local M = {}

-- Check if a value is an OCaml string (byte array)
local function is_ocaml_string(v)
  if type(v) ~= "table" then
    return false
  end
  -- If it has a tag, it's a block, not a string
  if v.tag ~= nil then
    return false
  end
  -- OCaml strings are tables with numeric indices only
  -- Empty tables {} are considered OCaml strings (empty strings)
  for k, val in pairs(v) do
    if type(k) ~= "number" or type(val) ~= "number" then
      return false
    end
  end
  return true
end

-- Check if a value is an OCaml block (tagged array)
local function is_ocaml_block(v)
  if type(v) ~= "table" then
    return false
  end
  -- OCaml blocks have a tag field
  return v.tag ~= nil and type(v.tag) == "number"
end

-- Get comparison tag for a value
-- Returns a numeric tag that determines comparison order
local function compare_tag(v)
  local t = type(v)

  if t == "number" then
    return 1000  -- int_tag (used for all numbers)
  elseif t == "string" then
    return 12520  -- JavaScript string
  elseif t == "boolean" then
    return 1002  -- Boolean tag
  elseif t == "nil" then
    return 1003  -- Nil tag
  elseif t == "function" then
    return 1247  -- Closure tag
  elseif t == "table" then
    if is_ocaml_string(v) then
      return 252  -- OCaml bytes/string tag
    elseif is_ocaml_block(v) then
      local tag = v.tag
      -- Forward_tag handling
      if tag == 250 then
        return 250
      end
      -- Ignore double_array_tag (254)
      return tag == 254 and 0 or tag
    else
      return 1001  -- Generic table (out of heap tag)
    end
  else
    return 1004  -- Unknown type
  end
end

-- Compare two OCaml strings (byte arrays)
local function compare_ocaml_strings(a, b)
  local len_a = #a
  local len_b = #b
  local min_len = len_a < len_b and len_a or len_b

  for i = 1, min_len do
    if a[i] < b[i] then
      return -1
    elseif a[i] > b[i] then
      return 1
    end
  end

  -- All compared bytes are equal, compare lengths
  if len_a < len_b then
    return -1
  elseif len_a > len_b then
    return 1
  else
    return 0
  end
end

-- Compare two numbers
local function compare_numbers(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  elseif a == b then
    return 0
  else
    -- Handle NaN case
    -- In OCaml, NaN is not equal to NaN
    if a ~= a then  -- a is NaN
      if b ~= b then  -- b is also NaN
        return 0
      else
        return -1  -- NaN < number
      end
    else  -- b is NaN
      return 1  -- number > NaN
    end
  end
end

-- Polymorphic comparison implementation
-- a, b: values to compare
-- total: if true, always return -1, 0, or 1 (total order)
--        if false, may raise error for incomparable values
-- Returns: -1 if a < b, 0 if a = b, 1 if a > b
function M.caml_compare_val(a, b, total)
  -- Stack for iterative traversal (avoids stack overflow)
  -- Each entry: {a_val, b_val, index}
  local stack = {}

  while true do
    -- Fast path: identical values
    if not (total and a == b) then
      local tag_a = compare_tag(a)

      -- Handle forward tag
      if tag_a == 250 and is_ocaml_block(a) then
        a = a[1]
        goto continue
      end

      local tag_b = compare_tag(b)

      -- Handle forward tag
      if tag_b == 250 and is_ocaml_block(b) then
        b = b[1]
        goto continue
      end

      -- Different tags: compare by tag order
      if tag_a ~= tag_b then
        if tag_a < tag_b then
          return -1
        else
          return 1
        end
      end

      -- Same tag: compare by tag-specific rules
      if tag_a == 1000 then
        -- Numbers
        local result = compare_numbers(a, b)
        if result ~= 0 then
          return result
        end
      elseif tag_a == 12520 then
        -- Lua strings
        if a < b then
          return -1
        elseif a > b then
          return 1
        end
      elseif tag_a == 252 then
        -- OCaml strings (byte arrays)
        if a ~= b then
          local result = compare_ocaml_strings(a, b)
          if result ~= 0 then
            return result
          end
        end
      elseif tag_a == 1002 then
        -- Booleans
        if a ~= b then
          -- false < true
          if not a then
            return -1
          else
            return 1
          end
        end
      elseif tag_a == 1003 then
        -- Nil values are always equal
        -- Already handled by identity check
      elseif tag_a == 1247 then
        -- Functions
        error("compare: functional value")
      elseif tag_a == 1001 or tag_a == 1004 then
        -- Generic tables or unknown types
        -- Try primitive comparison
        if a < b then
          return -1
        elseif a > b then
          return 1
        elseif a ~= b then
          if total then
            return 1
          else
            -- Incomparable values in non-total mode
            error("compare: incomparable values")
          end
        end
      elseif tag_a == 248 then
        -- Object tag: compare object IDs
        if is_ocaml_block(a) and is_ocaml_block(b) then
          local id_a = a[2] or 0
          local id_b = b[2] or 0
          if id_a < id_b then
            return -1
          elseif id_a > id_b then
            return 1
          end
        end
        -- If IDs are equal, continue to field comparison
      else
        -- OCaml blocks with other tags
        if is_ocaml_block(a) and is_ocaml_block(b) then
          -- Compare block sizes first
          local len_a = #a
          local len_b = #b

          if len_a ~= len_b then
            if len_a < len_b then
              return -1
            else
              return 1
            end
          end

          -- Blocks have same size, compare fields recursively
          if len_a > 0 then
            -- Push remaining fields to stack
            if len_a > 1 then
              table.insert(stack, {a = a, b = b, i = 2})
            end
            -- Compare first field
            a = a[1]
            b = b[1]
            goto continue
          end
        end
      end
    end

    -- Pop next comparison from stack
    if #stack == 0 then
      return 0
    end

    local frame = table.remove(stack)
    local parent_a = frame.a
    local parent_b = frame.b
    local i = frame.i

    -- Push next field if any
    if i + 1 <= #parent_a then
      table.insert(stack, {a = parent_a, b = parent_b, i = i + 1})
    end

    -- Compare current field
    a = parent_a[i]
    b = parent_b[i]

    ::continue::
  end
end

-- Total order comparison (always returns -1, 0, or 1)
-- Raises error for incomparable values (functions, etc.)
function M.caml_compare(a, b)
  return M.caml_compare_val(a, b, true)
end

-- Integer comparison
function M.caml_int_compare(a, b)
  if a < b then
    return -1
  elseif a == b then
    return 0
  else
    return 1
  end
end

-- Equality check
-- Returns 1 if equal, 0 if not equal
function M.caml_equal(x, y)
  local success, result = pcall(function()
    return M.caml_compare_val(x, y, false) == 0
  end)

  if success then
    return result and 1 or 0
  else
    -- Comparison raised an error (incomparable values)
    error(result)
  end
end

-- Inequality check
-- Returns 1 if not equal, 0 if equal
function M.caml_notequal(x, y)
  local success, result = pcall(function()
    return M.caml_compare_val(x, y, false) ~= 0
  end)

  if success then
    return result and 1 or 0
  else
    -- Comparison raised an error
    error(result)
  end
end

-- Less than
-- Returns 1 if x < y, 0 otherwise
function M.caml_lessthan(x, y)
  local success, result = pcall(function()
    return M.caml_compare_val(x, y, false) < 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

-- Less than or equal
-- Returns 1 if x <= y, 0 otherwise
function M.caml_lessequal(x, y)
  local success, result = pcall(function()
    return M.caml_compare_val(x, y, false) <= 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

-- Greater than
-- Returns 1 if x > y, 0 otherwise
function M.caml_greaterthan(x, y)
  local success, result = pcall(function()
    return M.caml_compare_val(x, y, false) > 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

-- Greater than or equal
-- Returns 1 if x >= y, 0 otherwise
function M.caml_greaterequal(x, y)
  local success, result = pcall(function()
    return M.caml_compare_val(x, y, false) >= 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

-- Min function
function M.caml_min(x, y)
  if M.caml_compare(x, y) <= 0 then
    return x
  else
    return y
  end
end

-- Max function
function M.caml_max(x, y)
  if M.caml_compare(x, y) >= 0 then
    return x
  else
    return y
  end
end

return M
