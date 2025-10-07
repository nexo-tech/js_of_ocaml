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

--- OCaml Object System Support
--
-- This module provides basic support for OCaml objects using Lua metatables.
--
-- OCaml objects are represented as:
-- - [1] = method table (sorted array of {tag, method_function} pairs)
-- - [2] = object ID (unique per object)
-- - [3+] = instance variables
--
-- The method table is sorted by tag for binary search lookup.
-- Metatables are used for method dispatch via __index metamethod.

local core = require("core")
local M = {}

-- Global object ID counter
local oo_last_id = 0

--- Generate a fresh object ID
-- @return number New unique object ID
function M.fresh_oo_id()
  oo_last_id = oo_last_id + 1
  return oo_last_id
end

--- Set object ID on a block
-- @param block table Object block
-- @return table The same block with ID set
function M.set_oo_id(block)
  block[2] = M.fresh_oo_id()
  return block
end

--- Get method from object using binary search on method table
-- @param obj table Object with method table at [1]
-- @param tag number Method tag to look up
-- @return function Method function or nil if not found
function M.get_public_method(obj, tag)
  local meths = obj[1]
  if not meths then
    return nil
  end

  -- Method table structure:
  -- meths[1] = number of methods
  -- meths[2] = unused
  -- meths[3] = method_1
  -- meths[4] = tag_1
  -- meths[5] = method_2
  -- meths[6] = tag_2
  -- ...

  local num_methods = meths[1]
  if not num_methods or num_methods == 0 then
    return nil
  end

  -- Binary search
  -- Methods are at odd indices: 3, 5, 7, ...
  -- Tags are at even indices: 4, 6, 8, ...
  local li = 3
  local hi = num_methods * 2 + 1

  while li <= hi do
    -- Find middle, ensuring it's an odd index
    local mid = math.floor((li + hi) / 2)
    if mid % 2 == 0 then
      mid = mid - 1
    end

    local mid_tag = meths[mid + 1]

    if mid_tag == tag then
      -- Found it!
      return meths[mid]
    elseif tag < mid_tag then
      -- Search left half
      hi = mid - 2
    else
      -- Search right half
      li = mid + 2
    end
  end

  -- Not found
  return nil
end

--- Create a method table from a list of (tag, method) pairs
-- The list should already be sorted by tag
-- @param methods table Array of {tag, method} pairs, sorted by tag
-- @return table Method table in OCaml format
function M.create_method_table(methods)
  local num_methods = #methods
  local meths = {num_methods, 0}  -- [1] = count, [2] = unused

  for i, pair in ipairs(methods) do
    local tag = pair[1]
    local method = pair[2]
    meths[i * 2 + 1] = method  -- method at odd indices
    meths[i * 2 + 2] = tag      -- tag at even indices
  end

  return meths
end

--- Create an OCaml object
-- @param methods table Method table (from create_method_table)
-- @param instance_vars table Optional array of instance variables
-- @return table Object block
function M.create_object(methods, instance_vars)
  local obj = {
    tag = 0,  -- Objects typically have tag 0
    [1] = methods,
    [2] = M.fresh_oo_id()
  }

  -- Add instance variables if provided
  if instance_vars then
    for i, v in ipairs(instance_vars) do
      obj[i + 2] = v
    end
  end

  -- Create metatable for method dispatch
  local mt = {
    __index = function(tbl, key)
      -- If key is a number (method tag), look up method
      if type(key) == "number" then
        return M.get_public_method(tbl, key)
      end
      return nil
    end
  }

  setmetatable(obj, mt)
  return obj
end

--- Call a method on an object
-- @param obj table Object
-- @param tag number Method tag
-- @param args table Array of arguments
-- @return any Result of method call
function M.call_method(obj, tag, args)
  local method = M.get_public_method(obj, tag)
  if not method then
    error("Method not found: tag " .. tag)
  end

  -- Methods receive self as first argument
  local all_args = {obj}
  for i, arg in ipairs(args) do
    all_args[i + 1] = arg
  end

  return method(table.unpack(all_args))
end

--- Get object field (instance variable)
-- @param obj table Object
-- @param i number Field index (0-based, excluding method table and ID)
-- @return any Field value
function M.obj_raw_field(obj, i)
  -- Fields start at index 3 (after method table [1] and ID [2])
  return obj[i + 3]
end

--- Set object field (instance variable)
-- @param obj table Object
-- @param i number Field index (0-based)
-- @param v any New value
function M.obj_set_raw_field(obj, i, v)
  obj[i + 3] = v
end

--- Create a simple object with methods as a table
-- This is a simpler interface for creating objects when you have
-- methods as a Lua table rather than a sorted method table
-- @param method_map table Map of method_name -> function
-- @param instance_vars table Optional instance variables
-- @return table Object
function M.simple_object(method_map, instance_vars)
  -- Convert method map to sorted method table
  -- For simplicity, we'll use string hashing for method tags
  local methods = {}
  for name, func in pairs(method_map) do
    -- Simple hash: sum of byte values
    local tag = 0
    for i = 1, #name do
      tag = tag + string.byte(name, i)
    end
    table.insert(methods, {tag, func})
  end

  -- Sort by tag
  table.sort(methods, function(a, b) return a[1] < b[1] end)

  local method_table = M.create_method_table(methods)
  return M.create_object(method_table, instance_vars)
end

-- Register primitives
core.register("caml_get_public_method", M.get_public_method)
core.register("caml_fresh_oo_id", M.fresh_oo_id)
core.register("caml_set_oo_id", M.set_oo_id)
core.register("caml_obj_raw_field", M.obj_raw_field)
core.register("caml_obj_set_raw_field", M.obj_set_raw_field)

-- Register module
core.register_module("obj", M)

return M
