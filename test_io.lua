-- === OCaml Runtime (Minimal Inline Version) ===
-- Initialize global OCaml namespace (required before loading runtime modules)
_G._OCAML = {}
-- 
-- NOTE: core.lua provides caml_register_global for primitives (name, func).
-- This inline version is for registering OCaml global VALUES (used by generated code).
-- TODO: Rename one of them to avoid confusion.
local _OCAML_GLOBALS = {}
function caml_register_global(n, v, name)
  _OCAML_GLOBALS[n + 1] = v
  if name then
    _OCAML_GLOBALS[name] = v
  end
  return v
end
function caml_register_named_value(name, value)
  _OCAML_GLOBALS[name] = value
  return value
end
-- 
-- Bitwise operations for Lua 5.1 (simplified implementations)
function caml_int_and(a, b)
  -- Simplified bitwise AND for common cases
  -- For full implementation, see runtime/lua/ints.lua
  local result, bit = 0, 1
  a = math.floor(a)
  b = math.floor(b)
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end
function caml_int_or(a, b)
  local result, bit = 0, 1
  a = math.floor(a)
  b = math.floor(b)
  while a > 0 or b > 0 do
    if a % 2 == 1 or b % 2 == 1 then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end
function caml_int_xor(a, b)
  local result, bit = 0, 1
  a = math.floor(a)
  b = math.floor(b)
  while a > 0 or b > 0 do
    local a_bit, b_bit = a % 2, b % 2
    if a_bit ~= b_bit then
      result = result + bit
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit = bit * 2
  end
  return result
end
-- 
-- Int64/Float bit conversion stubs (TODO: proper implementation)
function caml_int64_float_of_bits(i)
  -- Convert int64 bits to float - stub implementation
  -- In Lua, numbers are already IEEE 754 doubles
  return i
end
-- === End Inline Runtime ===
-- 
-- Runtime: weak
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

-- Weak references and Ephemerons
--
-- OCaml weak arrays and ephemerons are implemented using Lua weak tables

-- Ephemeron structure:
-- [0] = tag (251)
-- [1] = "caml_ephe_list_head"
-- [2] = data (ephemeron data)
-- [3..n] = keys (weak references)

local EPHE_KEY_OFFSET = 3
local EPHE_DATA_OFFSET = 2
local EPHE_NONE = {caml_ephe_none = true}

--
-- Weak Array Creation
--

--Provides: caml_weak_create
-- Create a weak array
function caml_weak_create(n)
  local alen = EPHE_KEY_OFFSET + n
  local x = {}
  x[0] = 251
  x[1] = "caml_ephe_list_head"

  for i = 2, alen do
    x[i] = EPHE_NONE
  end

  return x
end

--Provides: caml_ephe_create
--Requires: caml_weak_create
-- Create an ephemeron (same as weak array)
function caml_ephe_create(n)
  return caml_weak_create(n)
end

--
-- Key Management
--

--Provides: caml_ephe_set_key
--Requires: caml_ephe_get_data, caml_ephe_set_data_opt
-- Set a key in ephemeron with weak reference
function caml_ephe_set_key(x, i, v)
  local old = caml_ephe_get_data(x)

  -- Store value with weak reference if it's a table
  if type(v) == "table" then
    -- Create weak table for this key
    local weak_holder = setmetatable({value = v}, {__mode = "v"})
    x[EPHE_KEY_OFFSET + i] = weak_holder
  else
    -- Non-table values are stored directly
    x[EPHE_KEY_OFFSET + i] = v
  end

  caml_ephe_set_data_opt(x, old)
  return 0
end

--Provides: caml_ephe_unset_key
--Requires: caml_ephe_get_data, caml_ephe_set_data_opt
-- Unset a key in ephemeron
function caml_ephe_unset_key(x, i)
  local old = caml_ephe_get_data(x)
  x[EPHE_KEY_OFFSET + i] = EPHE_NONE
  caml_ephe_set_data_opt(x, old)
  return 0
end

--Provides: caml_ephe_get_key
-- Get a key from ephemeron
function caml_ephe_get_key(x, i)
  local weak = x[EPHE_KEY_OFFSET + i]

  if weak == EPHE_NONE then
    return 0  -- None
  end

  -- Check if it's a weak holder
  if type(weak) == "table" and weak.value ~= nil then
    local val = weak.value
    if val == nil then
      -- Value was collected
      x[EPHE_KEY_OFFSET + i] = EPHE_NONE
      x[EPHE_DATA_OFFSET] = EPHE_NONE
      return 0
    end
    return {tag = 0, val}  -- Some(val)
  end

  -- Direct value (not weakly held)
  return {tag = 0, weak}
end

--Provides: caml_ephe_get_key_copy
--Requires: caml_ephe_get_key
-- Get a copy of a key from ephemeron
function caml_ephe_get_key_copy(x, i)
  local y = caml_ephe_get_key(x, i)
  if y == 0 then
    return y
  end

  local z = y[1]
  if type(z) == "table" then
    -- Deep copy the table
    local copy = {}
    for k, v in pairs(z) do
      copy[k] = v
    end
    return {tag = 0, copy}
  end

  return y
end

--Provides: caml_ephe_check_key
-- Check if a key is still alive
function caml_ephe_check_key(x, i)
  local weak = x[EPHE_KEY_OFFSET + i]

  if weak == EPHE_NONE then
    return 0
  end

  -- Check if weak holder still has value
  if type(weak) == "table" and weak.value ~= nil then
    local val = weak.value
    if val == nil then
      -- Value was collected
      x[EPHE_KEY_OFFSET + i] = EPHE_NONE
      x[EPHE_DATA_OFFSET] = EPHE_NONE
      return 0
    end
  end

  return 1
end

--Provides: caml_ephe_blit_key
--Requires: caml_ephe_get_data, caml_ephe_set_data_opt
-- Blit keys from one ephemeron to another
function caml_ephe_blit_key(a1, i1, a2, i2, len)
  local old = caml_ephe_get_data(a1)

  for j = 0, len - 1 do
    a2[EPHE_KEY_OFFSET + i2 + j] = a1[EPHE_KEY_OFFSET + i1 + j]
  end

  caml_ephe_set_data_opt(a2, old)
  return 0
end

--Provides: caml_ephe_blit_data
--Requires: caml_ephe_get_data, caml_ephe_set_data_opt
-- Blit data from one ephemeron to another
function caml_ephe_blit_data(src, dst)
  local old = caml_ephe_get_data(src)
  caml_ephe_set_data_opt(dst, old)
  return 0
end

--
-- Data Management
--

--Provides: caml_ephe_get_data
-- Get data from ephemeron
function caml_ephe_get_data(x)
  local data = x[EPHE_DATA_OFFSET]

  if data == EPHE_NONE then
    return 0
  end

  -- Check if all keys are still alive
  for i = EPHE_KEY_OFFSET, #x do
    local k = x[i]
    if type(k) == "table" and k.value ~= nil then
      local val = k.value
      if val == nil then
        -- A key was collected, clear data
        x[i] = EPHE_NONE
        x[EPHE_DATA_OFFSET] = EPHE_NONE
        return 0
      end
    end
  end

  return {tag = 0, data}
end

--Provides: caml_ephe_get_data_copy
--Requires: caml_ephe_get_data
-- Get a copy of data from ephemeron
function caml_ephe_get_data_copy(x)
  local r = caml_ephe_get_data(x)
  if r == 0 then
    return 0
  end

  local z = r[1]
  if type(z) == "table" then
    local copy = {}
    for k, v in pairs(z) do
      copy[k] = v
    end
    return {tag = 0, copy}
  end

  return r
end

--Provides: caml_ephe_set_data
-- Set data in ephemeron
function caml_ephe_set_data(x, data)
  -- Check if all keys are still alive
  for i = #x, EPHE_KEY_OFFSET, -1 do
    local k = x[i]
    if type(k) == "table" and k.value ~= nil then
      local val = k.value
      if val == nil then
        -- A key was collected
        x[i] = EPHE_NONE
      end
    end
  end

  x[EPHE_DATA_OFFSET] = data
  return 0
end

--Provides: caml_ephe_set_data_opt
--Requires: caml_ephe_unset_data, caml_ephe_set_data
-- Set data optionally
function caml_ephe_set_data_opt(x, data_opt)
  if data_opt == 0 then
    caml_ephe_unset_data(x)
  else
    caml_ephe_set_data(x, data_opt[1])
  end
  return 0
end

--Provides: caml_ephe_unset_data
-- Unset data in ephemeron
function caml_ephe_unset_data(x)
  x[EPHE_DATA_OFFSET] = EPHE_NONE
  return 0
end

--Provides: caml_ephe_check_data
--Requires: caml_ephe_get_data
-- Check if data is set
function caml_ephe_check_data(x)
  local data = caml_ephe_get_data(x)
  if data == 0 then
    return 0
  else
    return 1
  end
end

--
-- Weak Array API (simplified interface)
--

--Provides: caml_weak_set
--Requires: caml_ephe_unset_key, caml_ephe_set_key
-- Set value in weak array
function caml_weak_set(x, i, v)
  if v == 0 then
    caml_ephe_unset_key(x, i)
  else
    caml_ephe_set_key(x, i, v[1])
  end
  return 0
end

--Provides: caml_weak_get
--Requires: caml_ephe_get_key
-- Get value from weak array (alias for caml_ephe_get_key)
caml_weak_get = caml_ephe_get_key

--Provides: caml_weak_get_copy
--Requires: caml_ephe_get_key_copy
-- Get copy from weak array (alias for caml_ephe_get_key_copy)
caml_weak_get_copy = caml_ephe_get_key_copy

--Provides: caml_weak_check
--Requires: caml_ephe_check_key
-- Check weak array value (alias for caml_ephe_check_key)
caml_weak_check = caml_ephe_check_key

--Provides: caml_weak_blit
--Requires: caml_ephe_blit_key
-- Blit weak array (alias for caml_ephe_blit_key)
caml_weak_blit = caml_ephe_blit_key


-- Runtime: stack
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


--Provides: caml_stack_create
function caml_stack_create()
  local stack = {
    elements = {},
    length = 0
  }

  return stack
end

--Provides: caml_stack_push
function caml_stack_push(stack, value)
  stack.length = stack.length + 1
  stack.elements[stack.length] = value
end

--Provides: caml_stack_pop
function caml_stack_pop(stack)
  if stack.length == 0 then
    error("Stack.Empty")
  end

  local value = stack.elements[stack.length]
  stack.elements[stack.length] = nil  -- Allow garbage collection
  stack.length = stack.length - 1

  return value
end

--Provides: caml_stack_top
function caml_stack_top(stack)
  if stack.length == 0 then
    error("Stack.Empty")
  end

  return stack.elements[stack.length]
end

--Provides: caml_stack_is_empty
function caml_stack_is_empty(stack)
  return stack.length == 0
end

--Provides: caml_stack_length
function caml_stack_length(stack)
  return stack.length
end

--Provides: caml_stack_clear
function caml_stack_clear(stack)
  stack.elements = {}
  stack.length = 0
end

--Provides: caml_stack_iter
function caml_stack_iter(stack)
  local index = stack.length
  return function()
    if index > 0 then
      local value = stack.elements[index]
      index = index - 1
      return value
    end
    return nil
  end
end

--Provides: caml_stack_to_array
function caml_stack_to_array(stack)
  local result = {}
  for i = 1, stack.length do
    table.insert(result, stack.elements[i])
  end
  return result
end


-- Runtime: result


--Provides: caml_result_ok
function caml_result_ok(value)
  return {tag = 0, value}
end

--Provides: caml_result_error
function caml_result_error(err)
  return {tag = 1, err}
end


--Provides: caml_result_is_ok
function caml_result_is_ok(result)
  return result.tag == 0
end

--Provides: caml_result_is_error
function caml_result_is_error(result)
  return result.tag == 1
end


--Provides: caml_result_get_ok
function caml_result_get_ok(result)
  if result.tag ~= 0 then
    error("Result.get_ok")
  end
  return result[1]
end

--Provides: caml_result_get_error
function caml_result_get_error(result)
  if result.tag ~= 1 then
    error("Result.get_error")
  end
  return result[1]
end

--Provides: caml_result_value
function caml_result_value(result, default)
  if result.tag == 0 then
    return result[1]
  end
  return default
end


--Provides: caml_result_map
function caml_result_map(f, result)
  if result.tag == 0 then
    return {tag = 0, f(result[1])}
  end
  return result
end

--Provides: caml_result_map_error
function caml_result_map_error(f, result)
  if result.tag == 1 then
    return {tag = 1, f(result[1])}
  end
  return result
end

--Provides: caml_result_bind
function caml_result_bind(result, f)
  if result.tag == 0 then
    return f(result[1])
  end
  return result
end

--Provides: caml_result_join
function caml_result_join(result)
  if result.tag == 0 then
    return result[1]
  end
  return result
end

--Provides: caml_result_fold
function caml_result_fold(ok_f, error_f, result)
  if result.tag == 0 then
    return ok_f(result[1])
  else
    return error_f(result[1])
  end
end

--Provides: caml_result_iter
function caml_result_iter(f, result)
  if result.tag == 0 then
    f(result[1])
  end
end

--Provides: caml_result_iter_error
function caml_result_iter_error(f, result)
  if result.tag == 1 then
    f(result[1])
  end
end


--Provides: caml_result_equal
function caml_result_equal(ok_eq, error_eq, result1, result2)
  if result1.tag ~= result2.tag then
    return false
  end
  if result1.tag == 0 then
    return ok_eq(result1[1], result2[1])
  else
    return error_eq(result1[1], result2[1])
  end
end

--Provides: caml_result_compare
function caml_result_compare(ok_cmp, error_cmp, result1, result2)
  if result1.tag ~= result2.tag then
    if result1.tag == 0 then
      return -1  -- Ok < Error
    else
      return 1   -- Error > Ok
    end
  end
  if result1.tag == 0 then
    return ok_cmp(result1[1], result2[1])
  else
    return error_cmp(result1[1], result2[1])
  end
end


--Provides: caml_result_to_option
function caml_result_to_option(result)
  if result.tag == 0 then
    return {tag = 0, result[1]}  -- Some(value)
  end
  return 0  -- None
end

--Provides: caml_result_to_list
function caml_result_to_list(result)
  if result.tag == 0 then
    return {tag = 0, result[1], 0}  -- Single element list
  end
  return 0  -- Empty list
end

--Provides: caml_result_to_seq
function caml_result_to_seq(result)
  if result.tag == 1 then
    return function() return 0 end  -- Empty sequence
  end
  local yielded = false
  return function()
    if yielded then
      return 0
    end
    yielded = true
    return {tag = 0, result[1], function() return 0 end}
  end
end


-- Runtime: queue
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


--Provides: caml_queue_create
function caml_queue_create()
  local queue = {
    elements = {},
    head = 1,
    tail = 1,
    length = 0
  }

  return queue
end

--Provides: caml_queue_add
function caml_queue_add(queue, value)
  queue.elements[queue.tail] = value
  queue.tail = queue.tail + 1
  queue.length = queue.length + 1
end

--Provides: caml_queue_take
function caml_queue_take(queue)
  if queue.length == 0 then
    error("Queue.Empty")
  end

  local value = queue.elements[queue.head]
  queue.elements[queue.head] = nil  -- Allow garbage collection
  queue.head = queue.head + 1
  queue.length = queue.length - 1

  if queue.length == 0 then
    queue.head = 1
    queue.tail = 1
  end

  return value
end

--Provides: caml_queue_peek
function caml_queue_peek(queue)
  if queue.length == 0 then
    error("Queue.Empty")
  end

  return queue.elements[queue.head]
end

--Provides: caml_queue_is_empty
function caml_queue_is_empty(queue)
  return queue.length == 0
end

--Provides: caml_queue_length
function caml_queue_length(queue)
  return queue.length
end

--Provides: caml_queue_clear
function caml_queue_clear(queue)
  queue.elements = {}
  queue.head = 1
  queue.tail = 1
  queue.length = 0
end

--Provides: caml_queue_iter
function caml_queue_iter(queue)
  local index = queue.head
  return function()
    if index < queue.tail then
      local value = queue.elements[index]
      index = index + 1
      return value
    end
    return nil
  end
end

--Provides: caml_queue_to_array
function caml_queue_to_array(queue)
  local result = {}
  for i = queue.head, queue.tail - 1 do
    table.insert(result, queue.elements[i])
  end
  return result
end


-- Runtime: option


--Provides: caml_option_none
function caml_option_none()
  return 0
end

--Provides: caml_option_some
function caml_option_some(value)
  return {tag = 0, value}
end


--Provides: caml_option_is_none
function caml_option_is_none(opt)
  return opt == 0
end

--Provides: caml_option_is_some
function caml_option_is_some(opt)
  return opt ~= 0
end


--Provides: caml_option_get
function caml_option_get(opt)
  if opt == 0 then
    error("Option.get")
  end
  return opt[1]
end

--Provides: caml_option_value
function caml_option_value(opt, default)
  if opt == 0 then
    return default
  end
  return opt[1]
end


--Provides: caml_option_map
function caml_option_map(f, opt)
  if opt == 0 then
    return 0
  end
  return {tag = 0, f(opt[1])}
end

--Provides: caml_option_bind
function caml_option_bind(opt, f)
  if opt == 0 then
    return 0
  end
  return f(opt[1])
end

--Provides: caml_option_join
function caml_option_join(opt)
  if opt == 0 then
    return 0
  end
  return opt[1]
end

--Provides: caml_option_fold
function caml_option_fold(none_case, some_f, opt)
  if opt == 0 then
    return none_case
  end
  return some_f(opt[1])
end

--Provides: caml_option_iter
function caml_option_iter(f, opt)
  if opt ~= 0 then
    f(opt[1])
  end
end


--Provides: caml_option_equal
function caml_option_equal(eq, opt1, opt2)
  if opt1 == 0 and opt2 == 0 then
    return true
  end
  if opt1 == 0 or opt2 == 0 then
    return false
  end
  return eq(opt1[1], opt2[1])
end

--Provides: caml_option_compare
function caml_option_compare(cmp, opt1, opt2)
  if opt1 == 0 and opt2 == 0 then
    return 0
  end
  if opt1 == 0 then
    return -1
  end
  if opt2 == 0 then
    return 1
  end
  return cmp(opt1[1], opt2[1])
end


--Provides: caml_option_to_result
function caml_option_to_result(none_error, opt)
  if opt == 0 then
    return {tag = 1, none_error}  -- Error(none_error)
  end
  return {tag = 0, opt[1]}  -- Ok(value)
end

--Provides: caml_option_to_list
function caml_option_to_list(opt)
  if opt == 0 then
    return 0  -- Empty list
  end
  return {tag = 0, opt[1], 0}  -- Single element list
end

--Provides: caml_option_to_seq
function caml_option_to_seq(opt)
  if opt == 0 then
    return function() return 0 end  -- Empty sequence
  end
  local yielded = false
  return function()
    if yielded then
      return 0
    end
    yielded = true
    return {tag = 0, opt[1], function() return 0 end}
  end
end


-- Runtime: obj
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

-- Compatibility: unpack is global in Lua 5.1/LuaJIT, table.unpack in Lua 5.2+
local unpack = table.unpack or unpack

--Provides: caml_oo_last_id
caml_oo_last_id = 0

--Provides: caml_fresh_oo_id
--Requires: caml_oo_last_id
function caml_fresh_oo_id()
  caml_oo_last_id = caml_oo_last_id + 1
  return caml_oo_last_id
end

--Provides: caml_set_oo_id
--Requires: caml_fresh_oo_id
--- Set object ID on a block
-- @param block table Object block
-- @return table The same block with ID set
function caml_set_oo_id(block)
  block[2] = caml_fresh_oo_id()
  return block
end

--Provides: caml_get_public_method
--- Get method from object using binary search on method table
-- @param obj table Object with method table at [1]
-- @param tag number Method tag to look up
-- @return function Method function or nil if not found
function caml_get_public_method(obj, tag)
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
-- Helper function for testing and object construction
function create_method_table(methods)
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
-- Helper function for testing and object construction
function create_object(methods, instance_vars)
  local obj = {
    tag = 0,  -- Objects typically have tag 0
    [1] = methods,
    [2] = caml_fresh_oo_id()
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
        return caml_get_public_method(tbl, key)
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
-- Helper function for testing
function call_method(obj, tag, args)
  local method = caml_get_public_method(obj, tag)
  if not method then
    error("Method not found: tag " .. tag)
  end

  -- Methods receive self as first argument
  local all_args = {obj}
  for i, arg in ipairs(args) do
    all_args[i + 1] = arg
  end

  return method(unpack(all_args))
end

--Provides: caml_obj_raw_field
--- Get object field (instance variable)
-- @param obj table Object
-- @param i number Field index (0-based, excluding method table and ID)
-- @return any Field value
function caml_obj_raw_field(obj, i)
  -- Fields start at index 3 (after method table [1] and ID [2])
  return obj[i + 3]
end

--Provides: caml_obj_set_raw_field
--- Set object field (instance variable)
-- @param obj table Object
-- @param i number Field index (0-based)
-- @param v any New value
function caml_obj_set_raw_field(obj, i, v)
  obj[i + 3] = v
end

--- Create a simple object with methods as a table
-- This is a simpler interface for creating objects when you have
-- methods as a Lua table rather than a sorted method table
-- @param method_map table Map of method_name -> function
-- @param instance_vars table Optional instance variables
-- @return table Object
-- Helper function for testing
function simple_object(method_map, instance_vars)
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

  local method_table = create_method_table(methods)
  return create_object(method_table, instance_vars)
end


-- Runtime: mlBytes
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


--Provides: caml_bit_and
function caml_bit_and(a, b)
  local result = 0
  local bit_val = 1
  while a > 0 and b > 0 do
    if a % 2 == 1 and b % 2 == 1 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--Provides: caml_bit_or
function caml_bit_or(a, b)
  local result = 0
  local bit_val = 1
  while a > 0 or b > 0 do
    if a % 2 == 1 or b % 2 == 1 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--Provides: caml_bit_lshift
function caml_bit_lshift(a, n)
  return math.floor(a * (2 ^ n))
end

--Provides: caml_bit_rshift
function caml_bit_rshift(a, n)
  return math.floor(a / (2 ^ n))
end

--Provides: caml_bytes_of_string
function caml_bytes_of_string(s)
  local len = #s
  local bytes = { length = len }
  for i = 1, len do
    bytes[i - 1] = string.byte(s, i)
  end
  return bytes
end

--Provides: caml_string_of_bytes
function caml_string_of_bytes(b)
  local len = b.length
  local chars = {}
  for i = 0, len - 1 do
    chars[i + 1] = string.char(b[i] or 0)
  end
  return table.concat(chars)
end

--Provides: caml_create_bytes
function caml_create_bytes(len, fill)
  fill = fill or 0
  local bytes = { length = len }
  for i = 0, len - 1 do
    bytes[i] = fill
  end
  return bytes
end

--Provides: caml_bytes_unsafe_get
function caml_bytes_unsafe_get(b, i)
  if type(b) == "string" then
    return string.byte(b, i + 1)
  else
    return b[i] or 0
  end
end

--Provides: caml_string_unsafe_get
function caml_string_unsafe_get(b, i)
  return caml_bytes_unsafe_get(b, i)
end

--Provides: caml_bytes_unsafe_set
--Requires: caml_bit_and
function caml_bytes_unsafe_set(b, i, c)
  if type(b) == "table" then
    b[i] = caml_bit_and(c, 0xFF)
  else
    error("Cannot set byte in immutable string")
  end
end

--Provides: caml_bytes_get
--Requires: caml_bytes_unsafe_get, caml_ml_bytes_length
function caml_bytes_get(b, i)
  local len = caml_ml_bytes_length(b)
  if i < 0 or i >= len then
    error("index out of bounds")
  end
  return caml_bytes_unsafe_get(b, i)
end

--Provides: caml_string_get
function caml_string_get(b, i)
  return caml_bytes_get(b, i)
end

--Provides: caml_bytes_set
--Requires: caml_bytes_unsafe_set
function caml_bytes_set(b, i, c)
  if type(b) ~= "table" then
    error("Cannot set byte in immutable string")
  end
  if i < 0 or i >= b.length then
    error("index out of bounds")
  end
  caml_bytes_unsafe_set(b, i, c)
end

--Provides: caml_ml_bytes_length
function caml_ml_bytes_length(s)
  if type(s) == "string" then
    return #s
  else
    return s.length
  end
end

--Provides: caml_ml_string_length
function caml_ml_string_length(s)
  return caml_ml_bytes_length(s)
end

--Provides: caml_blit_bytes
--Requires: caml_bytes_unsafe_get
function caml_blit_bytes(src, src_off, dst, dst_off, len)
  if type(dst) ~= "table" then
    error("Destination must be mutable bytes")
  end

  for i = 0, len - 1 do
    dst[dst_off + i] = caml_bytes_unsafe_get(src, src_off + i)
  end
end

--Provides: caml_blit_string
function caml_blit_string(src, src_off, dst, dst_off, len)
  return caml_blit_bytes(src, src_off, dst, dst_off, len)
end

--Provides: caml_fill_bytes
--Requires: caml_bit_and
function caml_fill_bytes(b, off, len, c)
  if type(b) ~= "table" then
    error("Cannot fill immutable string")
  end
  c = caml_bit_and(c, 0xFF)
  for i = 0, len - 1 do
    b[off + i] = c
  end
end

--Provides: caml_bytes_sub
--Requires: caml_create_bytes, caml_bytes_unsafe_get
function caml_bytes_sub(b, off, len)
  local result = caml_create_bytes(len)
  for i = 0, len - 1 do
    result[i] = caml_bytes_unsafe_get(b, off + i)
  end
  return result
end

--Provides: caml_bytes_compare
--Requires: caml_ml_bytes_length, caml_bytes_unsafe_get
function caml_bytes_compare(s1, s2)
  local len1 = caml_ml_bytes_length(s1)
  local len2 = caml_ml_bytes_length(s2)
  local min_len = math.min(len1, len2)

  for i = 0, min_len - 1 do
    local b1 = caml_bytes_unsafe_get(s1, i)
    local b2 = caml_bytes_unsafe_get(s2, i)
    if b1 < b2 then
      return -1
    elseif b1 > b2 then
      return 1
    end
  end

  if len1 < len2 then
    return -1
  elseif len1 > len2 then
    return 1
  else
    return 0
  end
end

--Provides: caml_string_compare
function caml_string_compare(s1, s2)
  return caml_bytes_compare(s1, s2)
end

--Provides: caml_bytes_equal
--Requires: caml_bytes_compare
function caml_bytes_equal(s1, s2)
  return caml_bytes_compare(s1, s2) == 0
end

--Provides: caml_string_equal
function caml_string_equal(s1, s2)
  return caml_bytes_equal(s1, s2)
end

--Provides: caml_bytes_concat
--Requires: caml_ml_bytes_length, caml_create_bytes, caml_blit_bytes
function caml_bytes_concat(sep, list)
  if #list == 0 then
    return caml_create_bytes(0)
  end

  local sep_len = caml_ml_bytes_length(sep)
  local total_len = 0

  for i, item in ipairs(list) do
    total_len = total_len + caml_ml_bytes_length(item)
    if i < #list then
      total_len = total_len + sep_len
    end
  end

  local result = caml_create_bytes(total_len)
  local pos = 0

  for i, item in ipairs(list) do
    local item_len = caml_ml_bytes_length(item)
    caml_blit_bytes(item, 0, result, pos, item_len)
    pos = pos + item_len

    if i < #list then
      caml_blit_bytes(sep, 0, result, pos, sep_len)
      pos = pos + sep_len
    end
  end

  return result
end

--Provides: caml_bytes_uppercase
--Requires: caml_ml_bytes_length, caml_create_bytes, caml_bytes_unsafe_get
function caml_bytes_uppercase(b)
  local len = caml_ml_bytes_length(b)
  local result = caml_create_bytes(len)

  for i = 0, len - 1 do
    local c = caml_bytes_unsafe_get(b, i)
    if c >= 97 and c <= 122 then
      c = c - 32
    end
    result[i] = c
  end

  return result
end

--Provides: caml_bytes_lowercase
--Requires: caml_ml_bytes_length, caml_create_bytes, caml_bytes_unsafe_get
function caml_bytes_lowercase(b)
  local len = caml_ml_bytes_length(b)
  local result = caml_create_bytes(len)

  for i = 0, len - 1 do
    local c = caml_bytes_unsafe_get(b, i)
    if c >= 65 and c <= 90 then
      c = c + 32
    end
    result[i] = c
  end

  return result
end

--Provides: caml_bytes_index
--Requires: caml_ml_bytes_length, caml_bytes_unsafe_get
function caml_bytes_index(haystack, needle)
  local hay_len = caml_ml_bytes_length(haystack)
  local needle_len = caml_ml_bytes_length(needle)

  if needle_len == 0 then
    return 0
  end
  if needle_len > hay_len then
    return -1
  end

  for i = 0, hay_len - needle_len do
    local match = true
    for j = 0, needle_len - 1 do
      if caml_bytes_unsafe_get(haystack, i + j) ~= caml_bytes_unsafe_get(needle, j) then
        match = false
        break
      end
    end
    if match then
      return i
    end
  end

  return -1
end

--Provides: caml_bytes_get16
--Requires: caml_bytes_unsafe_get, caml_bit_or, caml_bit_lshift
function caml_bytes_get16(b, i)
  local b1 = caml_bytes_unsafe_get(b, i)
  local b2 = caml_bytes_unsafe_get(b, i + 1)
  return caml_bit_or(b1, caml_bit_lshift(b2, 8))
end

--Provides: caml_string_get16
function caml_string_get16(b, i)
  return caml_bytes_get16(b, i)
end

--Provides: caml_bytes_get32
--Requires: caml_bytes_unsafe_get, caml_bit_or, caml_bit_lshift
function caml_bytes_get32(b, i)
  local b1 = caml_bytes_unsafe_get(b, i)
  local b2 = caml_bytes_unsafe_get(b, i + 1)
  local b3 = caml_bytes_unsafe_get(b, i + 2)
  local b4 = caml_bytes_unsafe_get(b, i + 3)
  return caml_bit_or(caml_bit_or(caml_bit_or(b1, caml_bit_lshift(b2, 8)), caml_bit_lshift(b3, 16)), caml_bit_lshift(b4, 24))
end

--Provides: caml_string_get32
function caml_string_get32(b, i)
  return caml_bytes_get32(b, i)
end

--Provides: caml_bytes_set16
--Requires: caml_bytes_unsafe_set, caml_bit_and, caml_bit_rshift
function caml_bytes_set16(b, i, v)
  caml_bytes_unsafe_set(b, i, caml_bit_and(v, 0xFF))
  caml_bytes_unsafe_set(b, i + 1, caml_bit_and(caml_bit_rshift(v, 8), 0xFF))
end

--Provides: caml_bytes_set32
--Requires: caml_bytes_unsafe_set, caml_bit_and, caml_bit_rshift
function caml_bytes_set32(b, i, v)
  caml_bytes_unsafe_set(b, i, caml_bit_and(v, 0xFF))
  caml_bytes_unsafe_set(b, i + 1, caml_bit_and(caml_bit_rshift(v, 8), 0xFF))
  caml_bytes_unsafe_set(b, i + 2, caml_bit_and(caml_bit_rshift(v, 16), 0xFF))
  caml_bytes_unsafe_set(b, i + 3, caml_bit_and(caml_bit_rshift(v, 24), 0xFF))
end


-- Runtime: ints
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


--Provides: caml_int32_xor
--Requires: caml_bit_and
function caml_int32_xor(a, b)
  local result = 0
  local bit_val = 1
  local a_work = a < 0 and (a + 0x100000000) or a
  local b_work = b < 0 and (b + 0x100000000) or b

  while a_work > 0 or b_work > 0 do
    local a_bit = a_work % 2
    local b_bit = b_work % 2
    if a_bit ~= b_bit then
      result = result + bit_val
    end
    a_work = math.floor(a_work / 2)
    b_work = math.floor(b_work / 2)
    bit_val = bit_val * 2
  end

  local n = result % 0x100000000
  if n >= 0x80000000 then
    return n - 0x100000000
  else
    return n
  end
end

--Provides: caml_int32_not
function caml_int32_not(n)
  local unsigned = n < 0 and (n + 0x100000000) or n
  local result = 0
  local bit_val = 1

  for i = 0, 31 do
    if unsigned % 2 == 0 then
      result = result + bit_val
    end
    unsigned = math.floor(unsigned / 2)
    bit_val = bit_val * 2
  end

  if result >= 0x80000000 then
    return result - 0x100000000
  else
    return result
  end
end

--Provides: caml_to_int32
function caml_to_int32(n)
  n = math.floor(n + 0)
  n = n % 0x100000000
  if n < 0 then
    n = n + 0x100000000
  end
  if n >= 0x80000000 then
    return n - 0x100000000
  else
    return n
  end
end

--Provides: caml_int32_add
--Requires: caml_to_int32
function caml_int32_add(a, b)
  return caml_to_int32(a + b)
end

--Provides: caml_int32_sub
--Requires: caml_to_int32
function caml_int32_sub(a, b)
  return caml_to_int32(a - b)
end

--Provides: caml_int32_mul
--Requires: caml_to_int32
function caml_int32_mul(a, b)
  return caml_to_int32(a * b)
end

--Provides: caml_int32_div
--Requires: caml_to_int32
function caml_int32_div(a, b)
  if b == 0 then
    error("Division by zero")
  end
  local result = a / b
  return caml_to_int32(result >= 0 and math.floor(result) or math.ceil(result))
end

--Provides: caml_int32_mod
--Requires: caml_to_int32
function caml_int32_mod(a, b)
  if b == 0 then
    error("Division by zero")
  end
  local r = a % b
  if (a < 0) ~= (b < 0) and r ~= 0 then
    r = r - b
  end
  return caml_to_int32(r)
end

--Provides: caml_int32_neg
--Requires: caml_to_int32
function caml_int32_neg(n)
  return caml_to_int32(-n)
end

--Provides: caml_int32_and
--Requires: caml_to_int32, caml_bit_and
function caml_int32_and(a, b)
  local ua = a < 0 and (a + 0x100000000) or a
  local ub = b < 0 and (b + 0x100000000) or b
  return caml_to_int32(caml_bit_and(ua, ub))
end

--Provides: caml_int32_or
--Requires: caml_to_int32, caml_bit_or
function caml_int32_or(a, b)
  local ua = a < 0 and (a + 0x100000000) or a
  local ub = b < 0 and (b + 0x100000000) or b
  return caml_to_int32(caml_bit_or(ua, ub))
end

--Provides: caml_int32_shift_left
--Requires: caml_to_int32, caml_bit_lshift
function caml_int32_shift_left(n, count)
  count = count % 32
  local unsigned = n < 0 and (n + 0x100000000) or n
  return caml_to_int32(caml_bit_lshift(unsigned, count))
end

--Provides: caml_int32_shift_right_unsigned
--Requires: caml_to_int32, caml_bit_rshift
function caml_int32_shift_right_unsigned(n, count)
  count = count % 32
  local unsigned = n < 0 and (n + 0x100000000) or n
  return caml_to_int32(caml_bit_rshift(unsigned, count))
end

--Provides: caml_int32_shift_right
--Requires: caml_to_int32
function caml_int32_shift_right(n, count)
  count = count % 32
  if count == 0 then
    return n
  end

  local sign = n < 0 and 1 or 0
  local unsigned = n < 0 and (n + 0x100000000) or n

  local result = math.floor(unsigned / (2 ^ count))

  if sign == 1 then
    local sign_extend = 0xFFFFFFFF - math.floor((2 ^ (32 - count)) - 1)
    result = result + sign_extend
  end

  return caml_to_int32(result)
end

--Provides: caml_int32_compare
function caml_int32_compare(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--Provides: caml_int32_unsigned_compare
function caml_int32_unsigned_compare(a, b)
  local ua = a < 0 and (a + 0x100000000) or a
  local ub = b < 0 and (b + 0x100000000) or b

  if ua < ub then
    return -1
  elseif ua > ub then
    return 1
  else
    return 0
  end
end

--Provides: caml_int32_bswap
--Requires: caml_to_int32, caml_bit_and, caml_bit_lshift, caml_bit_rshift, caml_bit_or
function caml_int32_bswap(n)
  n = caml_to_int32(n)
  local unsigned = n < 0 and (n + 0x100000000) or n
  local b0 = caml_bit_lshift(caml_bit_and(unsigned, 0x000000FF), 24)
  local b1 = caml_bit_lshift(caml_bit_and(unsigned, 0x0000FF00), 8)
  local b2 = caml_bit_rshift(caml_bit_and(unsigned, 0x00FF0000), 8)
  local b3 = caml_bit_rshift(caml_bit_and(unsigned, 0xFF000000), 24)
  return caml_to_int32(caml_bit_or(caml_bit_or(caml_bit_or(b0, b1), b2), b3))
end

--Provides: caml_int32_clz
--Requires: caml_bit_and
function caml_int32_clz(n)
  if n == 0 then
    return 32
  end

  local unsigned = n < 0 and (n + 0x100000000) or n

  local count = 0
  local mask = 0x80000000

  for i = 0, 31 do
    if caml_bit_and(unsigned, mask) ~= 0 then
      break
    end
    count = count + 1
    mask = math.floor(mask / 2)
  end

  return count
end

--Provides: caml_int32_ctz
--Requires: caml_bit_and
function caml_int32_ctz(n)
  if n == 0 then
    return 32
  end

  local unsigned = n < 0 and (n + 0x100000000) or n
  local count = 0
  local mask = 1

  for i = 0, 31 do
    if caml_bit_and(unsigned, mask) ~= 0 then
      break
    end
    count = count + 1
    mask = mask * 2
  end

  return count
end

--Provides: caml_int32_popcnt
--Requires: caml_bit_and, caml_bit_rshift
function caml_int32_popcnt(n)
  local unsigned = n < 0 and (n + 0x100000000) or n

  local count = 0
  for i = 0, 31 do
    if caml_bit_and(unsigned, 1) ~= 0 then
      count = count + 1
    end
    unsigned = caml_bit_rshift(unsigned, 1)
  end

  return count
end


-- Runtime: marshal_io
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

-- Marshal: Binary I/O helper functions
-- Provides low-level binary read/write operations for marshal format

--Provides: caml_marshal_buffer_create
function caml_marshal_buffer_create()
  return {
    bytes = {},
    length = 0
  }
end

--Provides: caml_marshal_buffer_write8u
function caml_marshal_buffer_write8u(buf, byte)
  buf.length = buf.length + 1
  buf.bytes[buf.length] = byte
end

--Provides: caml_marshal_buffer_write16u
function caml_marshal_buffer_write16u(buf, value)
  -- Write 16-bit unsigned big-endian
  -- Big-endian: most significant byte first
  local hi = math.floor(value / 256) % 256  -- High byte
  local lo = value % 256                     -- Low byte

  buf.length = buf.length + 1
  buf.bytes[buf.length] = hi
  buf.length = buf.length + 1
  buf.bytes[buf.length] = lo
end

--Provides: caml_marshal_buffer_write32u
function caml_marshal_buffer_write32u(buf, value)
  -- Write 32-bit unsigned big-endian
  -- Big-endian: most significant byte first
  local b3 = math.floor(value / 16777216) % 256  -- Byte 3 (highest)
  local b2 = math.floor(value / 65536) % 256     -- Byte 2
  local b1 = math.floor(value / 256) % 256       -- Byte 1
  local b0 = value % 256                          -- Byte 0 (lowest)

  buf.length = buf.length + 1
  buf.bytes[buf.length] = b3
  buf.length = buf.length + 1
  buf.bytes[buf.length] = b2
  buf.length = buf.length + 1
  buf.bytes[buf.length] = b1
  buf.length = buf.length + 1
  buf.bytes[buf.length] = b0
end

--Provides: caml_marshal_buffer_write_bytes
function caml_marshal_buffer_write_bytes(buf, str)
  for i = 1, #str do
    buf.length = buf.length + 1
    buf.bytes[buf.length] = string.byte(str, i)
  end
end

--Provides: caml_marshal_buffer_to_string
function caml_marshal_buffer_to_string(buf)
  -- Convert byte array to string
  -- Use table.concat for efficiency with large buffers
  local chars = {}
  for i = 1, buf.length do
    chars[i] = string.char(buf.bytes[i])
  end
  return table.concat(chars)
end

--Provides: caml_marshal_read8u
function caml_marshal_read8u(str, offset)
  -- Read 8-bit unsigned from string at offset (0-indexed)
  -- Returns: byte value
  if offset + 1 > #str then
    error(string.format("caml_marshal_read8u: data truncated (need %d bytes, got %d bytes)", offset + 1, #str))
  end
  return string.byte(str, offset + 1)
end

--Provides: caml_marshal_read16u
function caml_marshal_read16u(str, offset)
  -- Read 16-bit unsigned big-endian from string at offset (0-indexed)
  -- Returns: 16-bit value
  if offset + 2 > #str then
    error(string.format("caml_marshal_read16u: data truncated (need %d bytes, got %d bytes)", offset + 2, #str))
  end
  local hi = string.byte(str, offset + 1)      -- High byte
  local lo = string.byte(str, offset + 2)      -- Low byte

  -- Combine bytes: hi * 256 + lo
  return hi * 256 + lo
end

--Provides: caml_marshal_read32u
function caml_marshal_read32u(str, offset)
  -- Read 32-bit unsigned big-endian from string at offset (0-indexed)
  -- Returns: 32-bit value
  if offset + 4 > #str then
    error(string.format("caml_marshal_read32u: data truncated (need %d bytes, got %d bytes)", offset + 4, #str))
  end
  local b3 = string.byte(str, offset + 1)  -- Byte 3 (highest)
  local b2 = string.byte(str, offset + 2)  -- Byte 2
  local b1 = string.byte(str, offset + 3)  -- Byte 1
  local b0 = string.byte(str, offset + 4)  -- Byte 0 (lowest)

  -- Combine bytes: b3 * 2^24 + b2 * 2^16 + b1 * 2^8 + b0
  return b3 * 16777216 + b2 * 65536 + b1 * 256 + b0
end

--Provides: caml_marshal_read16s
function caml_marshal_read16s(str, offset)
  -- Read 16-bit signed big-endian from string at offset (0-indexed)
  -- Returns: signed 16-bit value
  local value = caml_marshal_read16u(str, offset)

  -- Convert unsigned to signed: if >= 2^15, subtract 2^16
  if value >= 32768 then  -- 2^15
    value = value - 65536  -- 2^16
  end

  return value
end

--Provides: caml_marshal_read32s
function caml_marshal_read32s(str, offset)
  -- Read 32-bit signed big-endian from string at offset (0-indexed)
  -- Returns: signed 32-bit value
  local value = caml_marshal_read32u(str, offset)

  -- Convert unsigned to signed: if >= 2^31, subtract 2^32
  if value >= 2147483648 then  -- 2^31
    value = value - 4294967296  -- 2^32
  end

  return value
end

--Provides: caml_marshal_read_bytes
function caml_marshal_read_bytes(str, offset, len)
  -- Read len bytes from string at offset (0-indexed)
  -- Returns: substring
  return string.sub(str, offset + 1, offset + len)
end

--Provides: caml_marshal_write_double_little
function caml_marshal_write_double_little(buf, value)
  -- Write 64-bit IEEE 754 double little-endian (Lua 5.1 compatible)
  -- Manual implementation with fallback

  local bytes_to_write = {}

  -- Handle special cases first
  if value ~= value then
    -- NaN: exponent all 1s, mantissa non-zero
    -- Standard quiet NaN: 0x7FF8000000000000 (little-endian: 00 00 00 00 00 00 F8 7F)
    bytes_to_write = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF8, 0x7F}
  elseif value == math.huge then
    -- +Infinity: sign=0, exponent all 1s, mantissa=0
    -- 0x7FF0000000000000 (little-endian: 00 00 00 00 00 00 F0 7F)
    bytes_to_write = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0x7F}
  elseif value == -math.huge then
    -- -Infinity: sign=1, exponent all 1s, mantissa=0
    -- 0xFFF0000000000000 (little-endian: 00 00 00 00 00 00 F0 FF)
    bytes_to_write = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xF0, 0xFF}
  elseif value == 0 then
    -- +0.0
    bytes_to_write = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00}
  else
    -- Use string.pack if available (Lua 5.3+), otherwise use frexp decomposition
    if string.pack then
      local packed = string.pack("<d", value)
      for i = 1, 8 do
        bytes_to_write[i] = string.byte(packed, i)
      end
    else
      -- Fallback: Use math.frexp to decompose the number
      -- IEEE 754: sign (1 bit) | exponent (11 bits, biased by 1023) | mantissa (52 bits)
      local sign = 0
      if value < 0 then
        sign = 1
        value = -value
      end

      -- math.frexp returns mantissa in [0.5, 1) and exponent
      -- We need mantissa in [1, 2) for IEEE 754
      local mantissa, exp = math.frexp(value)
      mantissa = mantissa * 2  -- Convert [0.5, 1) to [1, 2)
      exp = exp - 1

      -- IEEE 754 exponent is biased by 1023
      local biased_exp = exp + 1023

      -- Mantissa in IEEE 754 is 52 bits, with implicit leading 1
      -- mantissa is in [1, 2), so we store (mantissa - 1) * 2^52
      mantissa = (mantissa - 1) * 4503599627370496  -- 2^52

      -- Extract 52-bit mantissa into bytes (little-endian)
      local m0 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m1 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m2 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m3 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m4 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m5 = mantissa % 256
      mantissa = math.floor(mantissa / 256)
      local m6 = mantissa % 16  -- Only 4 bits

      -- Combine exponent and top mantissa bits
      -- Byte 7 (index 7): low 4 bits of exponent + high 4 bits of mantissa (m6)
      -- Byte 8 (index 8): high 7 bits of exponent + sign bit
      local exp_low = biased_exp % 16  -- Low 4 bits of exponent
      local exp_high = math.floor(biased_exp / 16)  -- High 7 bits of exponent

      bytes_to_write[1] = m0
      bytes_to_write[2] = m1
      bytes_to_write[3] = m2
      bytes_to_write[4] = m3
      bytes_to_write[5] = m4
      bytes_to_write[6] = m5
      bytes_to_write[7] = m6 + exp_low * 16
      bytes_to_write[8] = exp_high + sign * 128
    end
  end

  -- Write all 8 bytes to buffer
  for i = 1, 8 do
    buf.length = buf.length + 1
    buf.bytes[buf.length] = bytes_to_write[i]
  end
end

--Provides: caml_marshal_read_double_little
function caml_marshal_read_double_little(str, offset)
  -- Read 64-bit IEEE 754 double little-endian (Lua 5.1 compatible)

  -- Use string.unpack if available (Lua 5.3+)
  if string.unpack then
    local bytes = string.sub(str, offset + 1, offset + 8)
    return string.unpack("<d", bytes)
  end

  -- Fallback: Manual IEEE 754 decoding for Lua 5.1
  -- Read 8 bytes
  local b1 = string.byte(str, offset + 1)
  local b2 = string.byte(str, offset + 2)
  local b3 = string.byte(str, offset + 3)
  local b4 = string.byte(str, offset + 4)
  local b5 = string.byte(str, offset + 5)
  local b6 = string.byte(str, offset + 6)
  local b7 = string.byte(str, offset + 7)
  local b8 = string.byte(str, offset + 8)

  -- Extract sign, exponent, mantissa from little-endian format
  -- Byte 8 (b8): sign (1 bit) + high 7 bits of exponent
  -- Byte 7 (b7): low 4 bits of exponent + high 4 bits of mantissa
  local sign = math.floor(b8 / 128)  -- Bit 63
  local exp_high = b8 % 128  -- Bits 56-62
  local exp_low = math.floor(b7 / 16)  -- Bits 52-55
  local biased_exp = exp_high * 16 + exp_low

  -- Mantissa: 52 bits across bytes 1-7
  local m6 = b7 % 16  -- Bits 48-51
  local mantissa = m6 * 281474976710656 + b6 * 1099511627776 + b5 * 4294967296 +
                   b4 * 16777216 + b3 * 65536 + b2 * 256 + b1

  -- Check for special cases
  if biased_exp == 0x7FF then
    -- Exponent all 1s: infinity or NaN
    if mantissa == 0 then
      return sign == 1 and -math.huge or math.huge
    else
      return 0/0  -- NaN
    end
  elseif biased_exp == 0 then
    -- Denormalized number or zero
    if mantissa == 0 then
      return 0.0  -- Positive or negative zero (treat as 0.0)
    else
      -- Denormalized: 2^(-1022) * (0 + mantissa/2^52)
      local frac = mantissa / 4503599627370496  -- 2^52
      local value = frac * math.pow(2, -1022)
      return sign == 1 and -value or value
    end
  end

  -- Normal number: (-1)^sign * 2^(exp-1023) * (1 + mantissa/2^52)
  local exp = biased_exp - 1023
  local frac = 1.0 + mantissa / 4503599627370496  -- 2^52
  local value = frac * math.pow(2, exp)

  return sign == 1 and -value or value
end


-- Runtime: marshal_header
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

-- Marshal: Header read/write functions
-- Handles 20-byte OCaml marshal format headers

--Provides: caml_marshal_header_write
--Requires: caml_marshal_buffer_write32u
function caml_marshal_header_write(buf, data_len, num_objects, size_32, size_64)
  -- Write 20-byte marshal header
  -- Format:
  --   Magic number (4 bytes): 0x8495A6BE (MAGIC_SMALL) or 0x8495A6BF (MAGIC_BIG)
  --   Data length (4 bytes): length of marshaled data excluding header
  --   Number of objects (4 bytes): for sharing support
  --   Size 32-bit (4 bytes): size when read on 32-bit platform
  --   Size 64-bit (4 bytes): size when read on 64-bit platform

  -- Magic number: 0x8495A6BE for small (32-bit safe)
  caml_marshal_buffer_write32u(buf, 0x8495A6BE)  -- MAGIC_SMALL

  -- Data length (excluding header)
  caml_marshal_buffer_write32u(buf, data_len)

  -- Number of objects (for sharing)
  caml_marshal_buffer_write32u(buf, num_objects)

  -- Size on 32-bit platform
  caml_marshal_buffer_write32u(buf, size_32)

  -- Size on 64-bit platform
  caml_marshal_buffer_write32u(buf, size_64)
end

--Provides: caml_marshal_header_read
--Requires: caml_marshal_read32u
function caml_marshal_header_read(str, offset)
  -- Read and validate 20-byte marshal header
  -- Returns: {magic, data_len, num_objects, size_32, size_64} or nil on error

  -- Check minimum length
  local available = #str - offset
  if available < 20 then
    error(string.format("caml_marshal_header_read: data too short (need 20 bytes, got %d bytes)", available))
  end

  -- Read magic number (4 bytes)
  local magic = caml_marshal_read32u(str, offset)

  -- Validate magic number
  -- 0x8495A6BE = MAGIC_SMALL (32-bit safe)
  -- 0x8495A6BF = MAGIC_BIG (64-bit values)
  if magic ~= 0x8495A6BE and magic ~= 0x8495A6BF then
    error(string.format("caml_marshal_header_read: invalid header magic 0x%08X", magic))
  end

  -- Read data length (4 bytes)
  local data_len = caml_marshal_read32u(str, offset + 4)

  -- Read number of objects (4 bytes)
  local num_objects = caml_marshal_read32u(str, offset + 8)

  -- Read size on 32-bit platform (4 bytes)
  local size_32 = caml_marshal_read32u(str, offset + 12)

  -- Read size on 64-bit platform (4 bytes)
  local size_64 = caml_marshal_read32u(str, offset + 16)

  return {
    magic = magic,
    data_len = data_len,
    num_objects = num_objects,
    size_32 = size_32,
    size_64 = size_64
  }
end

--Provides: caml_marshal_header_size
function caml_marshal_header_size()
  -- Return the size of the marshal header in bytes
  return 20
end


-- Runtime: marshal
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

-- Marshal: OCaml Marshal format
-- Implements OCaml binary serialization format

-- Integer marshaling functions

--Provides: caml_marshal_write_int
--Requires: caml_marshal_buffer_write8u, caml_marshal_buffer_write16u, caml_marshal_buffer_write32u
function caml_marshal_write_int(buf, value)
  -- Encode integer with optimal format
  -- Small int (0-63): single byte 0x40-0x7F
  -- INT8 (-128 to 127 excluding 0-63): 0x00 + signed byte
  -- INT16 (-32768 to 32767 excluding INT8): 0x01 + signed 16-bit big-endian
  -- INT32 (else): 0x02 + signed 32-bit big-endian

  -- Check for small int (0-63)
  if value >= 0 and value <= 63 then
    -- Small int: 0x40 + value (0x40-0x7F)
    caml_marshal_buffer_write8u(buf, 0x40 + value)
    return
  end

  -- Check for INT8 range (-128 to 127)
  if value >= -128 and value <= 127 then
    -- CODE_INT8 (0x00) + signed byte
    caml_marshal_buffer_write8u(buf, 0x00)
    -- Convert signed to unsigned byte
    local byte_val = value
    if byte_val < 0 then
      byte_val = byte_val + 256
    end
    caml_marshal_buffer_write8u(buf, byte_val)
    return
  end

  -- Check for INT16 range (-32768 to 32767)
  if value >= -32768 and value <= 32767 then
    -- CODE_INT16 (0x01) + signed 16-bit big-endian
    caml_marshal_buffer_write8u(buf, 0x01)
    -- Convert signed to unsigned 16-bit
    local word_val = value
    if word_val < 0 then
      word_val = word_val + 65536
    end
    caml_marshal_buffer_write16u(buf, word_val)
    return
  end

  -- INT32: CODE_INT32 (0x02) + signed 32-bit big-endian
  caml_marshal_buffer_write8u(buf, 0x02)
  -- Convert signed to unsigned 32-bit
  local int_val = value
  if int_val < 0 then
    int_val = int_val + 4294967296
  end
  caml_marshal_buffer_write32u(buf, int_val)
end

--Provides: caml_marshal_read_int
--Requires: caml_marshal_read8u, caml_marshal_read16u, caml_marshal_read32u
function caml_marshal_read_int(str, offset)
  -- Decode integer and return {value, bytes_read}

  -- Read code byte
  local code = caml_marshal_read8u(str, offset)

  -- Small int (0x40-0x7F): value = code - 0x40
  if code >= 0x40 and code <= 0x7F then
    return {
      value = code - 0x40,
      bytes_read = 1
    }
  end

  -- CODE_INT8 (0x00): read signed byte
  if code == 0x00 then
    local byte_val = caml_marshal_read8u(str, offset + 1)
    -- Convert unsigned to signed byte
    local value = byte_val
    if value >= 128 then
      value = value - 256
    end
    return {
      value = value,
      bytes_read = 2
    }
  end

  -- CODE_INT16 (0x01): read signed 16-bit big-endian
  if code == 0x01 then
    local word_val = caml_marshal_read16u(str, offset + 1)
    -- Convert unsigned to signed 16-bit
    local value = word_val
    if value >= 32768 then
      value = value - 65536
    end
    return {
      value = value,
      bytes_read = 3
    }
  end

  -- CODE_INT32 (0x02): read signed 32-bit big-endian
  if code == 0x02 then
    local int_val = caml_marshal_read32u(str, offset + 1)
    -- Convert unsigned to signed 32-bit
    local value = int_val
    if value >= 2147483648 then
      value = value - 4294967296
    end
    return {
      value = value,
      bytes_read = 5
    }
  end

  error(string.format("caml_marshal_read_int: unknown code 0x%02X at offset %d", code, offset))
end

-- String marshaling functions

--Provides: caml_marshal_write_string
--Requires: caml_marshal_buffer_write8u, caml_marshal_buffer_write32u, caml_marshal_buffer_write_bytes
function caml_marshal_write_string(buf, str)
  -- Encode string with optimal format
  -- Small string (0-31 bytes): single byte 0x20-0x3F (0x20 + length) + bytes
  -- STRING8 (32-255 bytes): 0x09 + length byte + bytes
  -- STRING32 (256+ bytes): 0x0A + length (4 bytes big-endian) + bytes

  local len = #str

  -- Check for small string (0-31 bytes)
  if len <= 31 then
    -- Small string: 0x20 + length (0x20-0x3F)
    caml_marshal_buffer_write8u(buf, 0x20 + len)
    caml_marshal_buffer_write_bytes(buf, str)
    return
  end

  -- Check for STRING8 range (32-255 bytes)
  if len <= 255 then
    -- CODE_STRING8 (0x09) + length byte + bytes
    caml_marshal_buffer_write8u(buf, 0x09)
    caml_marshal_buffer_write8u(buf, len)
    caml_marshal_buffer_write_bytes(buf, str)
    return
  end

  -- STRING32: CODE_STRING32 (0x0A) + length (4 bytes big-endian) + bytes
  caml_marshal_buffer_write8u(buf, 0x0A)
  caml_marshal_buffer_write32u(buf, len)
  caml_marshal_buffer_write_bytes(buf, str)
end

--Provides: caml_marshal_read_string
--Requires: caml_marshal_read8u, caml_marshal_read32u, caml_marshal_read_bytes
function caml_marshal_read_string(str, offset)
  -- Decode string and return {value, bytes_read}

  -- Read code byte
  local code = caml_marshal_read8u(str, offset)

  -- Small string (0x20-0x3F): length = code - 0x20
  if code >= 0x20 and code <= 0x3F then
    local len = code - 0x20
    -- Validate sufficient data
    local needed = offset + 1 + len
    if #str < needed then
      error(string.format("caml_marshal_read_string: data truncated (need %d bytes, got %d bytes)", needed, #str))
    end
    local value = caml_marshal_read_bytes(str, offset + 1, len)
    return {
      value = value,
      bytes_read = 1 + len
    }
  end

  -- CODE_STRING8 (0x09): read length byte + bytes
  if code == 0x09 then
    local len = caml_marshal_read8u(str, offset + 1)
    -- Validate sufficient data
    local needed = offset + 2 + len
    if #str < needed then
      error(string.format("caml_marshal_read_string: data truncated (need %d bytes, got %d bytes)", needed, #str))
    end
    local value = caml_marshal_read_bytes(str, offset + 2, len)
    return {
      value = value,
      bytes_read = 2 + len
    }
  end

  -- CODE_STRING32 (0x0A): read 4-byte length + bytes
  if code == 0x0A then
    local len = caml_marshal_read32u(str, offset + 1)
    -- Validate sufficient data
    local needed = offset + 5 + len
    if #str < needed then
      error(string.format("caml_marshal_read_string: data truncated (need %d bytes, got %d bytes)", needed, #str))
    end
    local value = caml_marshal_read_bytes(str, offset + 5, len)
    return {
      value = value,
      bytes_read = 5 + len
    }
  end

  error(string.format("caml_marshal_read_string: unknown code 0x%02X at offset %d", code, offset))
end

-- Block marshaling functions

--Provides: caml_marshal_write_block
--Requires: caml_marshal_buffer_write8u, caml_marshal_buffer_write32u
function caml_marshal_write_block(buf, block, write_value_fn)
  -- Encode block with fields
  -- Small block (tag 0-15, size 0-7): single byte 0x80 + (tag | (size << 4))
  -- BLOCK32 (else): 0x08 + header (4 bytes: (size << 10) | tag big-endian) + fields
  -- Block format: {tag = N, size = M, [1] = field1, [2] = field2, ...}

  local tag = block.tag or 0
  local size = block.size or #block

  -- Check for small block (tag 0-15, size 0-7)
  if tag >= 0 and tag <= 15 and size >= 0 and size <= 7 then
    -- Small block: 0x80 + (tag | (size << 4))
    -- Lua 5.1 compatible: use arithmetic instead of bitwise operators
    local byte = 0x80 + tag + (size * 16)  -- size << 4 = size * 16
    caml_marshal_buffer_write8u(buf, byte)
  else
    -- BLOCK32: 0x08 + header (4 bytes: (size << 10) | tag)
    caml_marshal_buffer_write8u(buf, 0x08)  -- CODE_BLOCK32
    -- Header: (size << 10) | tag
    -- Lua 5.1 compatible: size * 1024 + tag
    local header = size * 1024 + tag  -- size << 10 = size * 1024
    caml_marshal_buffer_write32u(buf, header)
  end

  -- Write fields recursively using provided write_value_fn
  for i = 1, size do
    write_value_fn(buf, block[i])
  end
end

--Provides: caml_marshal_read_block
--Requires: caml_marshal_read8u, caml_marshal_read32u
function caml_marshal_read_block(str, offset, read_value_fn)
  -- Decode block and return {value, bytes_read}
  -- Block format: {tag = N, size = M, [1] = field1, [2] = field2, ...}

  -- Read code byte
  local code = caml_marshal_read8u(str, offset)
  local bytes_consumed = 1
  local tag, size

  -- Small block (0x80-0xFF): extract tag and size from single byte
  if code >= 0x80 and code <= 0xFF then
    -- Small block: code = 0x80 + (tag | (size << 4))
    local val = code - 0x80
    -- Extract tag and size using Lua 5.1 compatible arithmetic
    tag = val % 16  -- val & 0x0F
    size = math.floor(val / 16)  -- (val >> 4)

  -- CODE_BLOCK32 (0x08): read 4-byte header
  elseif code == 0x08 then
    local header = caml_marshal_read32u(str, offset + 1)
    bytes_consumed = bytes_consumed + 4
    -- Extract tag and size: header = (size << 10) | tag
    tag = header % 1024  -- header & 0x3FF
    size = math.floor(header / 1024)  -- header >> 10
  else
    error(string.format("caml_marshal_read_block: unknown code 0x%02X at offset %d", code, offset))
  end

  -- Create block with tag and size
  local block = {
    tag = tag,
    size = size
  }

  -- Read fields recursively using provided read_value_fn
  local field_offset = offset + bytes_consumed
  for i = 1, size do
    local result = read_value_fn(str, field_offset)
    block[i] = result.value
    field_offset = field_offset + result.bytes_read
    bytes_consumed = bytes_consumed + result.bytes_read
  end

  return {
    value = block,
    bytes_read = bytes_consumed
  }
end

-- Double/float marshaling functions

--Provides: caml_marshal_write_double
--Requires: caml_marshal_buffer_write8u, caml_marshal_write_double_little
function caml_marshal_write_double(buf, value)
  -- Encode double with IEEE 754 little-endian format
  -- CODE_DOUBLE_LITTLE (0x0C): 1 byte code + 8 bytes IEEE 754 little-endian
  -- Uses caml_marshal_write_double_little (Lua 5.1 compatible)

  -- CODE_DOUBLE_LITTLE (0x0C)
  caml_marshal_buffer_write8u(buf, 0x0C)

  -- Write double using marshal_io function (handles Lua 5.1 fallback)
  caml_marshal_write_double_little(buf, value)
end

--Provides: caml_marshal_read_double
--Requires: caml_marshal_read8u, caml_marshal_read_double_little
function caml_marshal_read_double(str, offset)
  -- Decode double and return {value, bytes_read}
  -- CODE_DOUBLE_LITTLE (0x0C): 1 byte code + 8 bytes IEEE 754 little-endian
  -- Uses caml_marshal_read_double_little (Lua 5.1 compatible)

  -- Read code byte
  local code = caml_marshal_read8u(str, offset)

  -- CODE_DOUBLE_LITTLE (0x0C)
  if code == 0x0C then
    -- Validate sufficient data (8 bytes for double)
    local needed = offset + 1 + 8
    if #str < needed then
      error(string.format("caml_marshal_read_double: data truncated (need %d bytes, got %d bytes)", needed, #str))
    end

    -- Read double using marshal_io function (handles Lua 5.1 fallback)
    local value = caml_marshal_read_double_little(str, offset + 1)

    return {
      value = value,
      bytes_read = 9  -- 1 code + 8 data
    }
  end

  error(string.format("caml_marshal_read_double: unknown code 0x%02X at offset %d", code, offset))
end

--Provides: caml_marshal_write_float_array
--Requires: caml_marshal_buffer_write8u, caml_marshal_buffer_write32u, caml_marshal_write_double_little
function caml_marshal_write_float_array(buf, arr)
  -- Encode float array (OCaml block with tag 254)
  -- Float array format in OCaml Marshal:
  -- DOUBLE_ARRAY8_LITTLE (0x0E): code + length byte + doubles (if length < 256)
  -- DOUBLE_ARRAY32_LITTLE (0x07): code + length (4 bytes) + doubles (if length >= 256)
  -- Array should be Lua table: {[1] = v1, [2] = v2, ...} with length in arr.size or #arr
  -- Uses caml_marshal_write_double_little (Lua 5.1 compatible)

  -- Get array length
  local len = arr.size or #arr

  -- Check for DOUBLE_ARRAY8_LITTLE range (length < 256)
  if len < 256 then
    -- DOUBLE_ARRAY8_LITTLE (0x0E) + length byte + doubles
    caml_marshal_buffer_write8u(buf, 0x0E)
    caml_marshal_buffer_write8u(buf, len)
  else
    -- DOUBLE_ARRAY32_LITTLE (0x07) + length (4 bytes) + doubles
    caml_marshal_buffer_write8u(buf, 0x07)
    caml_marshal_buffer_write32u(buf, len)
  end

  -- Write each double in little-endian format using marshal_io function
  for i = 1, len do
    local value = arr[i]
    if type(value) ~= "number" then
      error(string.format("caml_marshal_write_float_array: array element %d is not a number", i))
    end
    caml_marshal_write_double_little(buf, value)
  end
end

--Provides: caml_marshal_read_float_array
--Requires: caml_marshal_read8u, caml_marshal_read32u, caml_marshal_read_double_little
function caml_marshal_read_float_array(str, offset)
  -- Decode float array and return {value, bytes_read}
  -- Float array value is Lua table: {size = N, [1] = v1, [2] = v2, ...}
  -- Uses caml_marshal_read_double_little (Lua 5.1 compatible)

  -- Read code byte
  local code = caml_marshal_read8u(str, offset)
  local bytes_consumed = 1
  local len

  -- DOUBLE_ARRAY8_LITTLE (0x0E): read length byte
  if code == 0x0E then
    len = caml_marshal_read8u(str, offset + 1)
    bytes_consumed = bytes_consumed + 1

  -- DOUBLE_ARRAY32_LITTLE (0x07): read 4-byte length
  elseif code == 0x07 then
    len = caml_marshal_read32u(str, offset + 1)
    bytes_consumed = bytes_consumed + 4

  else
    error(string.format("caml_marshal_read_float_array: unknown code 0x%02X at offset %d", code, offset))
  end

  -- Validate sufficient data (8 bytes per double)
  local data_size = len * 8
  local needed = offset + bytes_consumed + data_size
  if #str < needed then
    error(string.format("caml_marshal_read_float_array: data truncated (need %d bytes, got %d bytes)", needed, #str))
  end

  -- Create values array
  local values = {}

  -- Read each double using marshal_io function
  local data_offset = offset + bytes_consumed
  for i = 1, len do
    local value = caml_marshal_read_double_little(str, data_offset)
    values[i] = value
    data_offset = data_offset + 8
    bytes_consumed = bytes_consumed + 8
  end

  -- Return float array with both formats for compatibility:
  -- - size field for test_marshal_double.lua compatibility
  -- - tag=254 and values for test_io_marshal.lua compatibility
  -- - numeric indices [1], [2], ... for direct access
  local arr = {
    tag = 254,
    size = len,
    values = values
  }
  for i = 1, len do
    arr[i] = values[i]
  end

  return {
    value = arr,
    bytes_read = bytes_consumed
  }
end

-- Core value marshaling functions

--Provides: caml_marshal_write_value
--Requires: caml_marshal_write_int, caml_marshal_write_double, caml_marshal_write_string, caml_marshal_write_block, caml_marshal_write_float_array, caml_marshal_buffer_write8u, caml_marshal_buffer_write32u
function caml_marshal_write_value(buf, value, seen, object_table, next_id)
  -- Main marshaling dispatch function with cycle detection and object sharing
  -- Dispatch based on Lua type: number → int/double, string → string, table → block/float_array
  -- Recursive marshaling for block fields
  -- seen: table tracking visited tables to detect cycles (optional, created if nil)
  -- object_table: table mapping table → object_id for sharing (optional, created if nil)
  -- next_id: table with {value = N} for next object ID (optional, created if nil)

  -- Initialize tables on first call
  seen = seen or {}
  object_table = object_table or {}
  next_id = next_id or {value = 1}

  local value_type = type(value)

  if value_type == "number" then
    -- Number: try integer first, fall back to double
    -- Integer if in int32 range and no fractional part
    if value >= -2147483648 and value <= 2147483647 and value == math.floor(value) then
      caml_marshal_write_int(buf, value)
    else
      caml_marshal_write_double(buf, value)
    end

  elseif value_type == "string" then
    -- String
    caml_marshal_write_string(buf, value)

  elseif value_type == "table" then
    -- Object sharing: check if this table already has an ID assigned
    local obj_id = object_table[value]
    if obj_id then
      -- Table already has an ID - write CODE_SHARED reference
      -- This handles both: (1) tables that finished marshaling (sharing)
      --                and (2) tables being marshaled (cycles)
      caml_marshal_buffer_write8u(buf, 0x04)
      caml_marshal_buffer_write32u(buf, obj_id)
      return
    end

    -- Assign object ID immediately (before marshaling fields)
    -- This allows cycles to work via SHARED references
    local current_id = next_id.value
    object_table[value] = current_id
    next_id.value = next_id.value + 1

    -- Mark table as being visited (for cycle detection)
    -- This is now only used to detect the impossible case of encountering
    -- a table that's being visited but has no ID (shouldn't happen)
    seen[value] = true

    -- Table: could be block or float array
    -- Check if it's a float array (tag 254 in OCaml)
    -- Float arrays have numeric indices and all number elements
    -- For simplicity: if table has .tag field, treat as block; else check if float array

    if value.tag == 254 and value.values then
      -- Float array with explicit tag 254 and values field: {tag = 254, values = {...}}
      -- Extract the values array and marshal it as a float array
      caml_marshal_write_float_array(buf, value.values)

    elseif value.tag ~= nil then
      -- Block: has tag field
      -- Use recursive write_value for fields, passing seen, object_table, next_id
      caml_marshal_write_block(buf, value, function(b, v)
        caml_marshal_write_value(b, v, seen, object_table, next_id)
      end)

    else
      -- Plain array without .tag field: treat as block with tag 0
      -- Note: We don't auto-detect float arrays from plain arrays of numbers
      -- Float arrays must be explicitly marked with {tag = 254, values = {...}}
      local len = value.size or #value
      local block = {
        tag = 0,
        size = len
      }
      for i = 1, len do
        block[i] = value[i]
      end
      caml_marshal_write_block(buf, block, function(b, v)
        caml_marshal_write_value(b, v, seen, object_table, next_id)
      end)
    end

    -- Unmark table after marshaling (allows sibling references in DAG)
    seen[value] = nil

  elseif value_type == "boolean" then
    -- Boolean: encode as integer 0 (false) or 1 (true)
    caml_marshal_write_int(buf, value and 1 or 0)

  elseif value_type == "nil" then
    -- Nil: encode as integer 0 (unit value in OCaml)
    caml_marshal_write_int(buf, 0)

  else
    error(string.format("caml_marshal_write_value: unsupported type %s", value_type))
  end
end

--Provides: caml_marshal_read_value
--Requires: caml_marshal_read8u, caml_marshal_read_int, caml_marshal_read_double, caml_marshal_read_string, caml_marshal_read_block, caml_marshal_read_float_array, caml_marshal_read32u
function caml_marshal_read_value(str, offset, objects_by_id, next_id)
  -- Main unmarshaling dispatch function with object sharing
  -- Read code byte and dispatch to appropriate reader
  -- Recursive unmarshaling for block fields
  -- objects_by_id: table mapping object_id → table for sharing (optional, created if nil)
  -- next_id: table with {value = N} for next object ID (optional, created if nil)
  -- Return {value, bytes_read}

  -- Initialize tables on first call
  objects_by_id = objects_by_id or {}
  next_id = next_id or {value = 1}

  -- Read code byte to determine type
  local code = caml_marshal_read8u(str, offset)

  -- CODE_SHARED (0x04): shared object reference
  if code == 0x04 then
    local obj_id = caml_marshal_read32u(str, offset + 1)
    local shared_obj = objects_by_id[obj_id]
    if not shared_obj then
      error(string.format("caml_marshal_read_value: invalid shared object reference %d at offset %d", obj_id, offset))
    end
    return {
      value = shared_obj,
      bytes_read = 5
    }

  -- Small int (0x40-0x7F): 0-63
  elseif code >= 0x40 and code <= 0x7F then
    return caml_marshal_read_int(str, offset)

  -- CODE_INT8 (0x00): signed byte
  elseif code == 0x00 then
    return caml_marshal_read_int(str, offset)

  -- CODE_INT16 (0x01): signed 16-bit
  elseif code == 0x01 then
    return caml_marshal_read_int(str, offset)

  -- CODE_INT32 (0x02): signed 32-bit
  elseif code == 0x02 then
    return caml_marshal_read_int(str, offset)

  -- Small string (0x20-0x3F): 0-31 bytes
  elseif code >= 0x20 and code <= 0x3F then
    return caml_marshal_read_string(str, offset)

  -- CODE_STRING8 (0x09): 32-255 bytes
  elseif code == 0x09 then
    return caml_marshal_read_string(str, offset)

  -- CODE_STRING32 (0x0A): 256+ bytes
  elseif code == 0x0A then
    return caml_marshal_read_string(str, offset)

  -- CODE_DOUBLE_LITTLE (0x0C): IEEE 754 double
  elseif code == 0x0C then
    return caml_marshal_read_double(str, offset)

  -- CODE_DOUBLE_ARRAY8_LITTLE (0x0E): float array with 8-bit length
  elseif code == 0x0E then
    local result = caml_marshal_read_float_array(str, offset)
    local obj_id = next_id.value
    objects_by_id[obj_id] = result.value
    next_id.value = next_id.value + 1
    return result

  -- CODE_DOUBLE_ARRAY32_LITTLE (0x07): float array with 32-bit length
  elseif code == 0x07 then
    local result = caml_marshal_read_float_array(str, offset)
    local obj_id = next_id.value
    objects_by_id[obj_id] = result.value
    next_id.value = next_id.value + 1
    return result

  -- Small block (0x80-0xFF): tag 0-15, size 0-7
  elseif code >= 0x80 and code <= 0xFF then
    -- Allocate object ID first (before reading fields, for cycles)
    local obj_id = next_id.value
    next_id.value = next_id.value + 1

    -- Create placeholder to be filled by read_block
    local placeholder = {}
    objects_by_id[obj_id] = placeholder

    -- Read block with fields
    local result = caml_marshal_read_block(str, offset, function(s, o)
      return caml_marshal_read_value(s, o, objects_by_id, next_id)
    end)

    -- Update placeholder with actual block content
    local block = result.value
    for k, v in pairs(block) do
      placeholder[k] = v
    end

    return {
      value = placeholder,
      bytes_read = result.bytes_read
    }

  -- CODE_BLOCK32 (0x08): large block
  elseif code == 0x08 then
    -- Allocate object ID first (before reading fields, for cycles)
    local obj_id = next_id.value
    next_id.value = next_id.value + 1

    -- Create placeholder to be filled by read_block
    local placeholder = {}
    objects_by_id[obj_id] = placeholder

    -- Read block with fields
    local result = caml_marshal_read_block(str, offset, function(s, o)
      return caml_marshal_read_value(s, o, objects_by_id, next_id)
    end)

    -- Update placeholder with actual block content
    local block = result.value
    for k, v in pairs(block) do
      placeholder[k] = v
    end

    return {
      value = placeholder,
      bytes_read = result.bytes_read
    }

  else
    -- Handle specific unsupported codes with helpful messages
    if code == 0x10 then
      error(string.format("caml_marshal_read_value: code pointer not supported (0x%02X at offset %d)", code, offset))
    elseif code == 0x13 then
      error(string.format("caml_marshal_read_value: 64-bit blocks not supported (0x%02X at offset %d)", code, offset))
    else
      error(string.format("caml_marshal_read_value: unsupported code 0x%02X at offset %d", code, offset))
    end
  end
end

-- Public API

--Provides: caml_marshal_to_string
--Requires: caml_marshal_buffer_create, caml_marshal_write_value, caml_marshal_buffer_to_string, caml_marshal_header_write, caml_marshal_buffer_write8u
function caml_marshal_to_string(value, flags)
  -- Marshal value to string with header
  -- flags parameter is optional (reserved for future use, not implemented)
  -- Returns: marshaled string with 20-byte header + data

  -- Input validation
  if value == nil then
    error("caml_marshal_to_string: cannot marshal nil value")
  end

  if flags ~= nil and type(flags) ~= "table" then
    error("caml_marshal_to_string: flags must be a table or nil, got " .. type(flags))
  end

  -- Check for unsupported flags
  if flags and type(flags) == "table" then
    -- flags[1] = Closures flag (not supported)
    if flags[1] ~= nil and flags[1] ~= 0 then
      error("caml_marshal_to_string: Closures flag not supported")
    end
  end

  -- Create buffer for marshaling the value
  local data_buf = caml_marshal_buffer_create()

  -- Create object tracking tables for sharing
  local seen = {}
  local object_table = {}
  local next_id = {value = 1}

  -- Marshal the value to the data buffer with object sharing
  caml_marshal_write_value(data_buf, value, seen, object_table, next_id)

  -- Get data length and number of objects
  local data_len = data_buf.length
  local num_objects = next_id.value - 1

  -- Create buffer for header + data
  local buf = caml_marshal_buffer_create()

  -- Write 20-byte header
  -- Header format: magic (4) | data_len (4) | num_objects (4) | size_32 (4) | size_64 (4)
  -- num_objects: count of shared objects (tables/arrays)
  -- size_32/size_64: reserved (0)
  caml_marshal_header_write(buf, data_len, num_objects, 0, 0)

  -- Append data bytes
  for i = 1, data_len do
    buf.length = buf.length + 1
    buf.bytes[buf.length] = data_buf.bytes[i]
  end

  -- Convert to string
  return caml_marshal_buffer_to_string(buf)
end

--Provides: caml_marshal_to_bytes
--Requires: caml_marshal_to_string
function caml_marshal_to_bytes(value, flags)
  -- Alias for caml_marshal_to_string
  return caml_marshal_to_string(value, flags)
end

--Provides: caml_marshal_from_bytes
--Requires: caml_marshal_header_read, caml_marshal_header_size, caml_marshal_read_value
function caml_marshal_from_bytes(str, offset)
  -- Unmarshal value from string with header
  -- offset parameter is optional (defaults to 0)
  -- Returns: unmarshaled value

  -- Input validation
  if type(str) ~= "string" then
    error("caml_marshal_from_bytes: expected string, got " .. type(str))
  end

  -- Default offset to 0
  offset = offset or 0

  -- Validate offset
  if type(offset) ~= "number" then
    error("caml_marshal_from_bytes: offset must be non-negative number, got " .. type(offset))
  end

  if offset < 0 then
    error("caml_marshal_from_bytes: offset must be non-negative, got " .. tostring(offset))
  end

  -- Read and validate header (20 bytes)
  local header = caml_marshal_header_read(str, offset)

  -- Header contains: magic, data_len, num_objects, size_32, size_64
  -- num_objects tells us how many shared objects to expect

  -- Calculate data offset (after header)
  local header_size = caml_marshal_header_size()
  local data_offset = offset + header_size

  -- Create object tracking tables for sharing
  local objects_by_id = {}
  local next_id = {value = 1}

  -- Unmarshal value from data section with object sharing
  local result = caml_marshal_read_value(str, data_offset, objects_by_id, next_id)

  -- Return the unmarshaled value (not the bytes_read)
  return result.value
end

--Provides: caml_marshal_from_string
--Requires: caml_marshal_from_bytes
function caml_marshal_from_string(str, offset)
  -- Alias for caml_marshal_from_bytes
  return caml_marshal_from_bytes(str, offset)
end

--Provides: caml_marshal_data_size
--Requires: caml_marshal_header_read
function caml_marshal_data_size(str, offset)
  -- Return data length from header (excludes header size)
  -- offset parameter is optional (defaults to 0)

  -- Default offset to 0
  offset = offset or 0

  -- Read header
  local header = caml_marshal_header_read(str, offset)

  -- Return data length
  return header.data_len
end

--Provides: caml_marshal_total_size
--Requires: caml_marshal_header_size, caml_marshal_data_size
function caml_marshal_total_size(str, offset)
  -- Return total size: header size (20) + data length
  -- offset parameter is optional (defaults to 0)

  -- Default offset to 0
  offset = offset or 0

  -- Get header size (always 20)
  local header_size = caml_marshal_header_size()

  -- Get data size
  local data_size = caml_marshal_data_size(str, offset)

  -- Return total
  return header_size + data_size
end

--Provides: marshal_value_internal
--Requires: caml_marshal_buffer_create, caml_marshal_write_value, caml_marshal_buffer_to_string
function marshal_value_internal(value)
  -- High-level API: Marshal value to string without header
  -- This is a simplified wrapper for test compatibility
  -- Returns: marshaled data (no header)

  local buf = caml_marshal_buffer_create()
  local seen = {}
  local object_table = {}
  local next_id = {value = 1}

  caml_marshal_write_value(buf, value, seen, object_table, next_id)

  return caml_marshal_buffer_to_string(buf)
end

--Provides: unmarshal_value_internal
--Requires: caml_marshal_read_value
function unmarshal_value_internal(str)
  -- High-level API: Unmarshal value from string without header
  -- This is a simplified wrapper for test compatibility
  -- Returns: unmarshaled value

  local objects_by_id = {}
  local next_id = {value = 1}

  local result = caml_marshal_read_value(str, 0, objects_by_id, next_id)

  return result.value
end

--Provides: marshal_header_read_header
--Requires: caml_marshal_header_read
function marshal_header_read_header(str, offset)
  -- High-level API: Alias for caml_marshal_header_read
  -- Provided for test compatibility
  return caml_marshal_header_read(str, offset)
end

--Provides: MARSHAL_MAGIC_SMALL
MARSHAL_MAGIC_SMALL = 0x8495A6BE

--Provides: MARSHAL_MAGIC_BIG
MARSHAL_MAGIC_BIG = 0x8495A6BF


-- Runtime: list


--Provides: caml_list_empty
function caml_list_empty()
  return 0
end

--Provides: caml_list_cons
function caml_list_cons(hd, tl)
  return {tag = 0, hd, tl}
end


--Provides: caml_list_hd
function caml_list_hd(list)
  if list == 0 then
    error("hd")
  end
  return list[1]
end

--Provides: caml_list_tl
function caml_list_tl(list)
  if list == 0 then
    error("tl")
  end
  return list[2]
end

--Provides: caml_list_is_empty
function caml_list_is_empty(list)
  return list == 0
end


--Provides: caml_list_length
function caml_list_length(list)
  local len = 0
  while list ~= 0 do
    len = len + 1
    list = list[2]
  end
  return len
end


--Provides: caml_list_nth
function caml_list_nth(list, n)
  local current = list
  local index = 0
  while current ~= 0 do
    if index == n then
      return current[1]
    end
    index = index + 1
    current = current[2]
  end
  error("nth")
end

--Provides: caml_list_nth_opt
function caml_list_nth_opt(list, n)
  local current = list
  local index = 0
  while current ~= 0 do
    if index == n then
      return {tag = 0, current[1]}  -- Some(value)
    end
    index = index + 1
    current = current[2]
  end
  return 0  -- None
end


--Provides: caml_list_rev
function caml_list_rev(list)
  local result = 0
  while list ~= 0 do
    result = {tag = 0, list[1], result}
    list = list[2]
  end
  return result
end

--Provides: caml_list_rev_append
function caml_list_rev_append(list1, list2)
  local result = list2
  while list1 ~= 0 do
    result = {tag = 0, list1[1], result}
    list1 = list1[2]
  end
  return result
end


--Provides: caml_list_append
function caml_list_append(list1, list2)
  if list1 == 0 then
    return list2
  end
  local rev = 0
  local current = list1
  while current ~= 0 do
    rev = {tag = 0, current[1], rev}
    current = current[2]
  end
  local result = list2
  while rev ~= 0 do
    result = {tag = 0, rev[1], result}
    rev = rev[2]
  end
  return result
end

--Provides: caml_list_concat
--Requires: caml_list_append
function caml_list_concat(lists)
  local result = 0
  local rev_lists = 0
  while lists ~= 0 do
    rev_lists = {tag = 0, lists[1], rev_lists}
    lists = lists[2]
  end
  while rev_lists ~= 0 do
    result = caml_list_append(rev_lists[1], result)
    rev_lists = rev_lists[2]
  end
  return result
end

--Provides: caml_list_flatten
--Requires: caml_list_concat
function caml_list_flatten(lists)
  return caml_list_concat(lists)
end


--Provides: caml_list_iter
function caml_list_iter(f, list)
  while list ~= 0 do
    f(list[1])
    list = list[2]
  end
end

--Provides: caml_list_iteri
function caml_list_iteri(f, list)
  local i = 0
  while list ~= 0 do
    f(i, list[1])
    list = list[2]
    i = i + 1
  end
end


--Provides: caml_list_map
--Requires: caml_list_rev
function caml_list_map(f, list)
  if list == 0 then
    return 0
  end
  local rev = 0
  while list ~= 0 do
    rev = {tag = 0, f(list[1]), rev}
    list = list[2]
  end
  return caml_list_rev(rev)
end

--Provides: caml_list_mapi
--Requires: caml_list_rev
function caml_list_mapi(f, list)
  if list == 0 then
    return 0
  end
  local rev = 0
  local i = 0
  while list ~= 0 do
    rev = {tag = 0, f(i, list[1]), rev}
    list = list[2]
    i = i + 1
  end
  return caml_list_rev(rev)
end

--Provides: caml_list_rev_map
function caml_list_rev_map(f, list)
  local result = 0
  while list ~= 0 do
    result = {tag = 0, f(list[1]), result}
    list = list[2]
  end
  return result
end

--Provides: caml_list_filter_map
--Requires: caml_list_rev
function caml_list_filter_map(f, list)
  local rev = 0
  while list ~= 0 do
    local opt = f(list[1])
    if opt ~= 0 then  -- Some(value)
      rev = {tag = 0, opt[1], rev}
    end
    list = list[2]
  end
  return caml_list_rev(rev)
end

--Provides: caml_list_concat_map
--Requires: caml_list_append
function caml_list_concat_map(f, list)
  local result = 0
  local rev_parts = 0
  while list ~= 0 do
    rev_parts = {tag = 0, f(list[1]), rev_parts}
    list = list[2]
  end
  while rev_parts ~= 0 do
    result = caml_list_append(rev_parts[1], result)
    rev_parts = rev_parts[2]
  end
  return result
end


--Provides: caml_list_fold_left
function caml_list_fold_left(f, acc, list)
  while list ~= 0 do
    acc = f(acc, list[1])
    list = list[2]
  end
  return acc
end

--Provides: caml_list_fold_right
--Requires: caml_list_rev
function caml_list_fold_right(f, list, acc)
  local rev = caml_list_rev(list)
  while rev ~= 0 do
    acc = f(rev[1], acc)
    rev = rev[2]
  end
  return acc
end


--Provides: caml_list_for_all
function caml_list_for_all(pred, list)
  while list ~= 0 do
    if not pred(list[1]) then
      return false
    end
    list = list[2]
  end
  return true
end

--Provides: caml_list_exists
function caml_list_exists(pred, list)
  while list ~= 0 do
    if pred(list[1]) then
      return true
    end
    list = list[2]
  end
  return false
end

--Provides: caml_list_mem
function caml_list_mem(x, list)
  while list ~= 0 do
    if list[1] == x then
      return true
    end
    list = list[2]
  end
  return false
end

--Provides: caml_list_memq
--Requires: caml_list_mem
function caml_list_memq(x, list)
  return caml_list_mem(x, list)
end


--Provides: caml_list_find
function caml_list_find(pred, list)
  while list ~= 0 do
    if pred(list[1]) then
      return list[1]
    end
    list = list[2]
  end
  error("Not_found")
end

--Provides: caml_list_find_opt
function caml_list_find_opt(pred, list)
  while list ~= 0 do
    if pred(list[1]) then
      return {tag = 0, list[1]}  -- Some(value)
    end
    list = list[2]
  end
  return 0  -- None
end

--Provides: caml_list_find_map
function caml_list_find_map(f, list)
  while list ~= 0 do
    local opt = f(list[1])
    if opt ~= 0 then  -- Some(value)
      return opt
    end
    list = list[2]
  end
  return 0  -- None
end

--Provides: caml_list_filter
--Requires: caml_list_rev
function caml_list_filter(pred, list)
  local rev = 0
  while list ~= 0 do
    if pred(list[1]) then
      rev = {tag = 0, list[1], rev}
    end
    list = list[2]
  end
  return caml_list_rev(rev)
end

--Provides: caml_list_partition
--Requires: caml_list_rev
function caml_list_partition(pred, list)
  local true_list = 0
  local false_list = 0
  while list ~= 0 do
    if pred(list[1]) then
      true_list = {tag = 0, list[1], true_list}
    else
      false_list = {tag = 0, list[1], false_list}
    end
    list = list[2]
  end
  return {caml_list_rev(true_list), caml_list_rev(false_list)}
end


--Provides: caml_list_assoc
function caml_list_assoc(key, list)
  while list ~= 0 do
    local pair = list[1]
    if pair[1] == key then
      return pair[2]
    end
    list = list[2]
  end
  error("Not_found")
end

--Provides: caml_list_assoc_opt
function caml_list_assoc_opt(key, list)
  while list ~= 0 do
    local pair = list[1]
    if pair[1] == key then
      return {tag = 0, pair[2]}  -- Some(value)
    end
    list = list[2]
  end
  return 0  -- None
end

--Provides: caml_list_assq
--Requires: caml_list_assoc
function caml_list_assq(key, list)
  return caml_list_assoc(key, list)
end

--Provides: caml_list_assq_opt
--Requires: caml_list_assoc_opt
function caml_list_assq_opt(key, list)
  return caml_list_assoc_opt(key, list)
end

--Provides: caml_list_mem_assoc
function caml_list_mem_assoc(key, list)
  while list ~= 0 do
    local pair = list[1]
    if pair[1] == key then
      return true
    end
    list = list[2]
  end
  return false
end

--Provides: caml_list_mem_assq
--Requires: caml_list_mem_assoc
function caml_list_mem_assq(key, list)
  return caml_list_mem_assoc(key, list)
end

--Provides: caml_list_remove_assoc
--Requires: caml_list_rev
function caml_list_remove_assoc(key, list)
  if list == 0 then
    return 0
  end
  local pair = list[1]
  if pair[1] == key then
    return list[2]  -- Skip this element
  end
  local rev = 0
  local current = list
  local found = false
  while current ~= 0 do
    local p = current[1]
    if not found and p[1] == key then
      found = true
    else
      rev = {tag = 0, p, rev}
    end
    current = current[2]
  end
  return caml_list_rev(rev)
end

--Provides: caml_list_remove_assq
--Requires: caml_list_remove_assoc
function caml_list_remove_assq(key, list)
  return caml_list_remove_assoc(key, list)
end


--Provides: caml_list_split
--Requires: caml_list_rev
function caml_list_split(list)
  local list1 = 0
  local list2 = 0
  while list ~= 0 do
    local pair = list[1]
    list1 = {tag = 0, pair[1], list1}
    list2 = {tag = 0, pair[2], list2}
    list = list[2]
  end
  return {caml_list_rev(list1), caml_list_rev(list2)}
end

--Provides: caml_list_combine
--Requires: caml_list_rev
function caml_list_combine(list1, list2)
  local result = 0
  local rev = 0
  while list1 ~= 0 and list2 ~= 0 do
    rev = {tag = 0, {list1[1], list2[1]}, rev}
    list1 = list1[2]
    list2 = list2[2]
  end
  if list1 ~= 0 or list2 ~= 0 then
    error("Invalid_argument")
  end
  return caml_list_rev(rev)
end


--Provides: caml_list_sort
function caml_list_sort(cmp, list)
  if list == 0 or list[2] == 0 then
    return list
  end
  local arr = {}
  local current = list
  while current ~= 0 do
    table.insert(arr, current[1])
    current = current[2]
  end
  table.sort(arr, function(a, b) return cmp(a, b) < 0 end)
  local result = 0
  for i = #arr, 1, -1 do
    result = {tag = 0, arr[i], result}
  end
  return result
end

--Provides: caml_list_stable_sort
--Requires: caml_list_sort
function caml_list_stable_sort(cmp, list)
  return caml_list_sort(cmp, list)
end

--Provides: caml_list_fast_sort
--Requires: caml_list_sort
function caml_list_fast_sort(cmp, list)
  return caml_list_sort(cmp, list)
end

--Provides: caml_list_sort_uniq
--Requires: caml_list_sort
function caml_list_sort_uniq(cmp, list)
  if list == 0 then
    return 0
  end
  local sorted = caml_list_sort(cmp, list)
  local result = {tag = 0, sorted[1], 0}
  local tail = result
  sorted = sorted[2]
  while sorted ~= 0 do
    if cmp(tail[1], sorted[1]) ~= 0 then
      local new_tail = {tag = 0, sorted[1], 0}
      tail[2] = new_tail
      tail = new_tail
    end
    sorted = sorted[2]
  end
  return result
end

--Provides: caml_list_merge
--Requires: caml_list_rev
function caml_list_merge(cmp, list1, list2)
  if list1 == 0 then
    return list2
  end
  if list2 == 0 then
    return list1
  end
  local rev = 0
  while list1 ~= 0 and list2 ~= 0 do
    if cmp(list1[1], list2[1]) <= 0 then
      rev = {tag = 0, list1[1], rev}
      list1 = list1[2]
    else
      rev = {tag = 0, list2[1], rev}
      list2 = list2[2]
    end
  end
  local remaining = list1 ~= 0 and list1 or list2
  while remaining ~= 0 do
    rev = {tag = 0, remaining[1], rev}
    remaining = remaining[2]
  end
  return caml_list_rev(rev)
end


-- Runtime: lazy
--Provides: caml_lazy_from_fun
function caml_lazy_from_fun(f)
  return {246, f}  -- LAZY_TAG (not yet evaluated)
end

--Provides: caml_lazy_make_forward
function caml_lazy_make_forward(v)
  return {250, v}  -- FORWARD_TAG (already evaluated)
end

--Provides: caml_lazy_from_val
function caml_lazy_from_val(v)
  return {250, v}  -- FORWARD_TAG (already evaluated)
end


--Provides: caml_lazy_update_to_forcing
function caml_lazy_update_to_forcing(lazy_val)
  if lazy_val[1] == 246 then  -- LAZY_TAG
    lazy_val[1] = 244  -- FORCING_TAG (currently being evaluated)
    return 0
  else
    return 1
  end
end

--Provides: caml_lazy_update_to_forward
function caml_lazy_update_to_forward(lazy_val)
  if lazy_val[1] == 244 then  -- FORCING_TAG
    lazy_val[1] = 250  -- FORWARD_TAG
  end
  return 0
end

--Provides: caml_lazy_reset_to_lazy
function caml_lazy_reset_to_lazy(lazy_val)
  if lazy_val[1] == 244 then  -- FORCING_TAG
    lazy_val[1] = 246  -- LAZY_TAG
  end
  return 0
end

--Provides: caml_lazy_read_result
function caml_lazy_read_result(lazy_val)
  if lazy_val[1] == 250 then  -- FORWARD_TAG
    return lazy_val[2]
  else
    return lazy_val
  end
end


--Provides: caml_lazy_force
function caml_lazy_force(lazy_val)
  local tag = lazy_val[1]

  if tag == 250 then  -- FORWARD_TAG
    return lazy_val[2]
  end

  if tag == 244 then  -- FORCING_TAG
    error("Lazy value is undefined (recursive forcing)")
  end

  if tag == 246 then  -- LAZY_TAG
    local update_result = caml_lazy_update_to_forcing(lazy_val)
    if update_result ~= 0 then
      error("Lazy value race condition")
    end

    local thunk = lazy_val[2]

    local success, result = pcall(thunk)

    if success then
      lazy_val[2] = result
      caml_lazy_update_to_forward(lazy_val)
      return result
    else
      caml_lazy_reset_to_lazy(lazy_val)
      error(result)
    end
  end

  error("Invalid lazy value tag: " .. tostring(tag))
end

--Provides: caml_lazy_force_val
--Requires: caml_lazy_force
function caml_lazy_force_val(lazy_val)
  return caml_lazy_force(lazy_val)
end


--Provides: caml_lazy_is_val
function caml_lazy_is_val(lazy_val)
  return lazy_val[1] == 250  -- FORWARD_TAG
end

--Provides: caml_lazy_is_forcing
function caml_lazy_is_forcing(lazy_val)
  return lazy_val[1] == 244  -- FORCING_TAG
end

--Provides: caml_lazy_is_lazy
function caml_lazy_is_lazy(lazy_val)
  return lazy_val[1] == 246  -- LAZY_TAG
end


--Provides: caml_lazy_map
--Requires: caml_lazy_force, caml_lazy_from_fun
function caml_lazy_map(f, lazy_val)
  local thunk = function()
    local value = caml_lazy_force(lazy_val)
    return f(value)
  end
  return caml_lazy_from_fun(thunk)
end

--Provides: caml_lazy_map2
--Requires: caml_lazy_force, caml_lazy_from_fun
function caml_lazy_map2(f, lazy_val1, lazy_val2)
  local thunk = function()
    local value1 = caml_lazy_force(lazy_val1)
    local value2 = caml_lazy_force(lazy_val2)
    return f(value1, value2)
  end
  return caml_lazy_from_fun(thunk)
end


--Provides: caml_lazy_tag
function caml_lazy_tag(lazy_val)
  return lazy_val[1]
end

--Provides: caml_lazy_from_exception
--Requires: caml_lazy_from_fun
function caml_lazy_from_exception(exn)
  local thunk = function()
    error(exn)
  end
  return caml_lazy_from_fun(thunk)
end

--Provides: caml_lazy_force_unit
--Requires: caml_lazy_force
function caml_lazy_force_unit(lazy_val)
  caml_lazy_force(lazy_val)
  return 0  -- unit
end


-- Runtime: gc
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

_OCAML_gc = _OCAML_gc or {finalizers = {}}

--Provides: caml_gc_minor
function caml_gc_minor(_unit)
  collectgarbage("step", 0)
  return 0
end

--Provides: caml_gc_major
function caml_gc_major(_unit)
  collectgarbage("collect")
  return 0
end

--Provides: caml_gc_full_major
function caml_gc_full_major(_unit)
  collectgarbage("collect")
  return 0
end

--Provides: caml_gc_compaction
function caml_gc_compaction(_unit)
  return 0
end

--Provides: caml_gc_counters
function caml_gc_counters(_unit)
  return {254, 0, 0, 0}
end

--Provides: caml_gc_quick_stat
function caml_gc_quick_stat(_unit)
  local mem = collectgarbage("count")
  return {0, mem, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

--Provides: caml_gc_stat
--Requires: caml_gc_quick_stat
function caml_gc_stat(unit)
  return caml_gc_quick_stat(unit)
end

--Provides: caml_gc_set
function caml_gc_set(_control)
  return 0
end

--Provides: caml_gc_get
function caml_gc_get(_unit)
  return {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
end

--Provides: caml_gc_major_slice
function caml_gc_major_slice(_work)
  collectgarbage("step", math.max(_work, 100))
  return 0
end

--Provides: caml_gc_minor_words
function caml_gc_minor_words(_unit)
  return 0
end

--Provides: caml_get_minor_free
function caml_get_minor_free(_unit)
  return 0
end

--Provides: caml_final_register
function caml_final_register(f, x)
  if type(x) == "table" then
    local proxy
    if newproxy then
      proxy = newproxy(true)
      local mt = getmetatable(proxy)
      mt.__gc = function()
        pcall(f, x)
      end
    else
      proxy = {}
      setmetatable(proxy, {__gc = function()
        pcall(f, x)
      end})
    end
    if not _OCAML_gc.finalizers[x] then
      _OCAML_gc.finalizers[x] = {}
    end
    table.insert(_OCAML_gc.finalizers[x], proxy)
  end
  return 0
end

--Provides: caml_final_register_called_without_value
function caml_final_register_called_without_value(cb, a)
  if type(a) == "table" then
    local proxy
    if newproxy then
      proxy = newproxy(true)
      local mt = getmetatable(proxy)
      mt.__gc = function()
        pcall(cb, 0)
      end
    else
      proxy = {}
      setmetatable(proxy, {__gc = function()
        pcall(cb, 0)
      end})
    end
    if not _OCAML_gc.finalizers[a] then
      _OCAML_gc.finalizers[a] = {}
    end
    table.insert(_OCAML_gc.finalizers[a], proxy)
  end
  return 0
end

--Provides: caml_final_release
function caml_final_release(_unit)
  collectgarbage("collect")
  return 0
end

--Provides: caml_memprof_start
function caml_memprof_start(_rate, _stack_size, _tracker)
  return 0
end

--Provides: caml_memprof_stop
function caml_memprof_stop(_unit)
  return 0
end

--Provides: caml_memprof_discard
function caml_memprof_discard(_t)
  return 0
end

--Provides: caml_eventlog_resume
function caml_eventlog_resume(_unit)
  return 0
end

--Provides: caml_eventlog_pause
function caml_eventlog_pause(_unit)
  return 0
end

--Provides: caml_gc_huge_fallback_count
function caml_gc_huge_fallback_count(_unit)
  return 0
end


-- Runtime: fun
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

--Provides: caml_is_ocaml_fun
function caml_is_ocaml_fun(v)
  return type(v) == "table" and type(v.f) == "function" and type(v.l) == "number"
end

--Provides: caml_call_gen
--Requires: caml_is_ocaml_fun
function caml_call_gen(func, args)
  assert(caml_is_ocaml_fun(func), "caml_call_gen expects an OCaml function")

  local n = func.l
  local args_len = #args
  local d = n - args_len

  if d == 0 then
    -- Exact number of arguments: call directly
    return func.f(unpack(args))
  elseif d < 0 then
    -- Over-application: too many arguments
    -- Call func with first n arguments
    local first_args = {}
    for i = 1, n do
      first_args[i] = args[i]
    end
    local result = func.f(unpack(first_args))

    -- If result is an OCaml function, apply remaining arguments
    if caml_is_ocaml_fun(result) then
      local rest_args = {}
      for i = n + 1, args_len do
        rest_args[#rest_args + 1] = args[i]
      end
      return caml_call_gen(result, rest_args)
    else
      -- Result is not a function, return it
      return result
    end
  else
    -- Under-application: not enough arguments
    -- Return a closure that captures the provided arguments

    -- Optimize for common cases (1-2 missing parameters)
    if d == 1 then
      -- Need exactly 1 more argument
      return {
        l = 1,
        f = function(x)
          local new_args = {}
          for i = 1, args_len do
            new_args[i] = args[i]
          end
          new_args[args_len + 1] = x
          return func.f(unpack(new_args))
        end
      }
    elseif d == 2 then
      -- Need exactly 2 more arguments
      return {
        l = 2,
        f = function(x, y)
          local new_args = {}
          for i = 1, args_len do
            new_args[i] = args[i]
          end
          new_args[args_len + 1] = x
          new_args[args_len + 2] = y
          return func.f(unpack(new_args))
        end
      }
    else
      -- Need 3 or more arguments
      -- Create a vararg closure that accumulates arguments
      return {
        l = d,
        f = function(...)
          local extra_args = {...}
          -- Handle case where no args provided (call with unit)
          if #extra_args == 0 then
            extra_args = {0}  -- OCaml unit
          end
          -- Concatenate args with extra_args
          local combined = {}
          for i = 1, args_len do
            combined[i] = args[i]
          end
          for i = 1, #extra_args do
            combined[args_len + i] = extra_args[i]
          end
          return caml_call_gen(func, combined)
        end
      }
    end
  end
end

--Provides: caml_apply
--Requires: caml_call_gen, caml_is_ocaml_fun
function caml_apply(func, ...)
  local args = {...}
  if caml_is_ocaml_fun(func) then
    return caml_call_gen(func, args)
  else
    error("caml_apply expects an OCaml function")
  end
end

--Provides: caml_curry
function caml_curry(arity, lua_fn)
  return {
    l = arity,
    f = lua_fn
  }
end

--Provides: caml_closure
function caml_closure(arity, lua_fn, env)
  if env then
    -- Closure with environment - wrap to inject env as first parameter
    return {
      l = arity,
      f = function(...)
        return lua_fn(env, ...)
      end
    }
  else
    -- No environment needed
    return {
      l = arity,
      f = lua_fn
    }
  end
end


-- Runtime: format
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


--Provides: caml_parse_format
function caml_parse_format(fmt)
  if type(fmt) == "table" then
    local chars = {}
    for i = 1, #fmt do
      table.insert(chars, string.char(fmt[i]))
    end
    fmt = table.concat(chars)
  end

  local len = #fmt
  if len > 31 then
    error("format_int: format too long")
  end

  local f = {
    justify = "+",      -- "+" for right, "-" for left
    signstyle = "-",    -- "-" for no sign on positive, "+" for +, " " for space
    filler = " ",       -- " " or "0"
    alternate = false,  -- # flag for alternate form
    base = 0,           -- 0, 8, 10, or 16
    signedconv = false, -- true for signed conversions
    width = 0,          -- minimum field width
    uppercase = false,  -- true for uppercase output
    sign = 1,           -- 1 for positive, -1 for negative
    prec = -1,          -- precision (-1 means not specified)
    conv = "f"          -- conversion type
  }

  local i = 1
  while i <= len do
    local c = fmt:sub(i, i)

    if c == "-" then
      f.justify = "-"
      i = i + 1
    elseif c == "+" or c == " " then
      f.signstyle = c
      i = i + 1
    elseif c == "0" then
      f.filler = "0"
      i = i + 1
    elseif c == "#" then
      f.alternate = true
      i = i + 1
    elseif c >= "1" and c <= "9" then
      f.width = 0
      while i <= len do
        local digit = fmt:byte(i) - 48
        if digit >= 0 and digit <= 9 then
          f.width = f.width * 10 + digit
          i = i + 1
        else
          break
        end
      end
    elseif c == "." then
      f.prec = 0
      i = i + 1
      while i <= len do
        local digit = fmt:byte(i) - 48
        if digit >= 0 and digit <= 9 then
          f.prec = f.prec * 10 + digit
          i = i + 1
        else
          break
        end
      end
    elseif c == "d" or c == "i" then
      f.signedconv = true
      f.base = 10
      f.conv = c
      i = i + 1
    elseif c == "u" then
      f.base = 10
      f.conv = c
      i = i + 1
    elseif c == "x" then
      f.base = 16
      f.conv = c
      i = i + 1
    elseif c == "X" then
      f.base = 16
      f.uppercase = true
      f.conv = "x"
      i = i + 1
    elseif c == "o" then
      f.base = 8
      f.conv = c
      i = i + 1
    elseif c == "e" or c == "f" or c == "g" then
      f.signedconv = true
      f.conv = c
      i = i + 1
    elseif c == "E" or c == "F" or c == "G" then
      f.signedconv = true
      f.uppercase = true
      f.conv = c:lower()
      i = i + 1
    elseif c == "s" then
      f.conv = "s"
      i = i + 1
    elseif c == "c" then
      f.conv = "c"
      i = i + 1
    else
      i = i + 1
    end
  end

  return f
end

--Provides: caml_finish_formatting
function caml_finish_formatting(f, rawbuffer)
  if f.uppercase then
    rawbuffer = rawbuffer:upper()
  end

  local len = #rawbuffer

  if f.signedconv and (f.sign < 0 or f.signstyle ~= "-") then
    len = len + 1
  end
  if f.alternate then
    if f.base == 8 then
      len = len + 1
    elseif f.base == 16 then
      len = len + 2
    end
  end

  local buffer = ""

  if f.justify == "+" and f.filler == " " then
    for i = len + 1, f.width do
      buffer = buffer .. " "
    end
  end

  if f.signedconv then
    if f.sign < 0 then
      buffer = buffer .. "-"
    elseif f.signstyle ~= "-" then
      buffer = buffer .. f.signstyle
    end
  end

  if f.alternate and f.base == 8 then
    buffer = buffer .. "0"
  end
  if f.alternate and f.base == 16 then
    buffer = buffer .. (f.uppercase and "0X" or "0x")
  end

  if f.justify == "+" and f.filler == "0" then
    for i = len + 1, f.width do
      buffer = buffer .. "0"
    end
  end

  buffer = buffer .. rawbuffer

  if f.justify == "-" then
    for i = len + 1, f.width do
      buffer = buffer .. " "
    end
  end

  local result = {}
  for i = 1, #buffer do
    result[i] = buffer:byte(i)
  end
  return result
end

--Provides: caml_ocaml_string_to_lua
function caml_ocaml_string_to_lua(s)
  if type(s) == "string" then
    return s
  end
  local chars = {}
  for i = 1, #s do
    table.insert(chars, string.char(s[i]))
  end
  return table.concat(chars)
end

--Provides: caml_lua_string_to_ocaml
function caml_lua_string_to_ocaml(s)
  local result = {}
  for i = 1, #s do
    result[i] = s:byte(i)
  end
  return result
end

--Provides: caml_str_repeat
function caml_str_repeat(n, s)
  local result = {}
  for i = 1, n do
    table.insert(result, s)
  end
  return table.concat(result)
end

--Provides: caml_skip_whitespace
function caml_skip_whitespace(s, pos)
  while pos <= #s do
    local c = s:sub(pos, pos)
    if c == " " or c == "\t" or c == "\n" or c == "\r" then
      pos = pos + 1
    else
      break
    end
  end
  return pos
end

--Provides: caml_format_int
--Requires: caml_ocaml_string_to_lua, caml_lua_string_to_ocaml, caml_parse_format, caml_str_repeat, caml_finish_formatting
function caml_format_int(fmt, i)
  local fmt_str = caml_ocaml_string_to_lua(fmt)

  if fmt_str == "%d" then
    return caml_lua_string_to_ocaml(tostring(i))
  end

  local f = caml_parse_format(fmt)

  if i < 0 then
    if f.signedconv then
      f.sign = -1
      i = -i
    else
      i = i + 4294967296  -- 2^32
    end
  end

  local s
  if f.base == 10 then
    s = string.format("%d", math.floor(i))
  elseif f.base == 16 then
    s = string.format("%x", math.floor(i))
  elseif f.base == 8 then
    s = string.format("%o", math.floor(i))
  else
    s = tostring(math.floor(i))
  end

  if f.prec >= 0 then
    f.filler = " "
    local n = f.prec - #s
    if n > 0 then
      s = caml_str_repeat(n, "0") .. s
    end
  end

  return caml_finish_formatting(f, s)
end

--Provides: caml_format_float
--Requires: caml_parse_format, caml_finish_formatting
function caml_format_float(fmt, x)
  local f = caml_parse_format(fmt)
  local prec = f.prec < 0 and 6 or f.prec

  if x < 0 or (x == 0 and 1/x == -math.huge) then
    f.sign = -1
    x = -x
  end

  local s

  if x ~= x then  -- NaN
    s = "nan"
    f.filler = " "
  elseif x == math.huge then  -- Infinity
    s = "inf"
    f.filler = " "
  else
    if f.conv == "e" then
      s = string.format("%." .. prec .. "e", x)
      s = s:gsub("e([+-])(%d)$", "e%10%2")
    elseif f.conv == "f" then
      s = string.format("%." .. prec .. "f", x)
    elseif f.conv == "g" then
      local effective_prec = prec > 0 and prec or 1

      local exp_str = string.format("%." .. (effective_prec - 1) .. "e", x)
      local exp_val = tonumber(exp_str:match("e([+-]%d+)$"))

      if exp_val and (exp_val < -4 or x >= 1e21 or #string.format("%.0f", x) > effective_prec) then
        s = exp_str
        s = s:gsub("(%d)0+e", "%1e")
        s = s:gsub("%.e", "e")
        s = s:gsub("e([+-])(%d)$", "e%10%2")
      else
        local p = effective_prec
        if exp_val and exp_val < 0 then
          p = p - exp_val - 1
          s = string.format("%." .. p .. "f", x)
        else
          repeat
            s = string.format("%." .. p .. "f", x)
            if #s <= effective_prec + 1 then break end
            p = p - 1
          until p < 0
        end

        if p > 0 then
          s = s:gsub("0+$", "")
          s = s:gsub("%.$", "")
        end
      end
    else
      s = string.format("%." .. prec .. "f", x)
    end
  end

  return caml_finish_formatting(f, s)
end

--Provides: caml_format_string
--Requires: caml_parse_format, caml_ocaml_string_to_lua, caml_str_repeat, caml_lua_string_to_ocaml
function caml_format_string(fmt, s)
  local f = caml_parse_format(fmt)
  local str = caml_ocaml_string_to_lua(s)

  if f.prec >= 0 and #str > f.prec then
    str = str:sub(1, f.prec)
  end

  local len = #str
  local buffer = ""

  if f.justify == "+" and len < f.width then
    buffer = caml_str_repeat(f.width - len, " ") .. str
  elseif f.justify == "-" and len < f.width then
    buffer = str .. caml_str_repeat(f.width - len, " ")
  else
    buffer = str
  end

  return caml_lua_string_to_ocaml(buffer)
end

--Provides: caml_format_char
--Requires: caml_parse_format, caml_str_repeat, caml_lua_string_to_ocaml
function caml_format_char(fmt, c)
  local f = caml_parse_format(fmt)

  local char
  if type(c) == "number" then
    char = string.char(c)
  elseif type(c) == "string" then
    char = c:sub(1, 1)
  elseif type(c) == "table" and #c == 1 then
    char = string.char(c[1])
  else
    char = " "
  end

  local buffer = ""
  if f.justify == "+" and 1 < f.width then
    buffer = caml_str_repeat(f.width - 1, " ") .. char
  elseif f.justify == "-" and 1 < f.width then
    buffer = char .. caml_str_repeat(f.width - 1, " ")
  else
    buffer = char
  end

  return caml_lua_string_to_ocaml(buffer)
end

--Provides: caml_scan_int
--Requires: caml_ocaml_string_to_lua, caml_parse_format, caml_skip_whitespace
function caml_scan_int(s, pos, fmt)
  pos = pos or 1
  local str = caml_ocaml_string_to_lua(s)
  local f = caml_parse_format(fmt or "%d")

  pos = caml_skip_whitespace(str, pos)

  if pos > #str then
    return nil, pos
  end

  local sign = 1
  local c = str:sub(pos, pos)
  if c == "-" then
    sign = -1
    pos = pos + 1
  elseif c == "+" then
    pos = pos + 1
  end

  if pos > #str then
    return nil, pos
  end

  local base = f.base
  if base == 0 then
    base = 10
  end

  if str:sub(pos, pos + 1) == "0x" or str:sub(pos, pos + 1) == "0X" then
    if base == 16 or base == 0 then
      base = 16
      pos = pos + 2
    end
  elseif str:sub(pos, pos + 1) == "0o" or str:sub(pos, pos + 1) == "0O" then
    if base == 8 or base == 0 then
      base = 8
      pos = pos + 2
    end
  elseif str:sub(pos, pos + 1) == "0b" or str:sub(pos, pos + 1) == "0B" then
    if base == 2 or base == 0 then
      base = 2
      pos = pos + 2
    end
  elseif str:sub(pos, pos) == "0" and base == 0 then
    base = 8
  end

  local start_pos = pos
  local value = 0
  local found_digit = false

  while pos <= #str do
    local c = str:sub(pos, pos)
    local digit = nil

    if c >= "0" and c <= "9" then
      digit = c:byte() - 48
    elseif c >= "a" and c <= "z" then
      digit = c:byte() - 97 + 10
    elseif c >= "A" and c <= "Z" then
      digit = c:byte() - 65 + 10
    end

    if digit and digit < base then
      value = value * base + digit
      pos = pos + 1
      found_digit = true
    else
      break
    end
  end

  if not found_digit then
    return nil, start_pos
  end

  return sign * value, pos
end

--Provides: caml_scan_float
--Requires: caml_ocaml_string_to_lua, caml_skip_whitespace
function caml_scan_float(s, pos)
  pos = pos or 1
  local str = caml_ocaml_string_to_lua(s)

  pos = caml_skip_whitespace(str, pos)

  if pos > #str then
    return nil, pos
  end

  local start_pos = pos
  local sign_str = ""
  local int_part = ""
  local frac_part = ""
  local exp_part = ""

  local c = str:sub(pos, pos)
  if c == "-" or c == "+" then
    sign_str = c
    pos = pos + 1
  end

  if str:sub(pos, pos + 2) == "nan" or str:sub(pos, pos + 2) == "NaN" then
    return 0/0, pos + 3
  end
  if str:sub(pos, pos + 7) == "infinity" or str:sub(pos, pos + 7) == "Infinity" then
    return (sign_str == "-" and -math.huge or math.huge), pos + 8
  end
  if str:sub(pos, pos + 2) == "inf" or str:sub(pos, pos + 2) == "Inf" then
    return (sign_str == "-" and -math.huge or math.huge), pos + 3
  end

  while pos <= #str do
    c = str:sub(pos, pos)
    if c >= "0" and c <= "9" then
      int_part = int_part .. c
      pos = pos + 1
    else
      break
    end
  end

  if pos <= #str and str:sub(pos, pos) == "." then
    pos = pos + 1
    while pos <= #str do
      c = str:sub(pos, pos)
      if c >= "0" and c <= "9" then
        frac_part = frac_part .. c
        pos = pos + 1
      else
        break
      end
    end
  end

  if int_part == "" and frac_part == "" then
    return nil, start_pos
  end

  if pos <= #str then
    c = str:sub(pos, pos)
    if c == "e" or c == "E" then
      local exp_pos = pos + 1
      local exp_sign = ""

      if exp_pos <= #str then
        c = str:sub(exp_pos, exp_pos)
        if c == "+" or c == "-" then
          exp_sign = c
          exp_pos = exp_pos + 1
        end
      end

      local exp_digits = ""
      while exp_pos <= #str do
        c = str:sub(exp_pos, exp_pos)
        if c >= "0" and c <= "9" then
          exp_digits = exp_digits .. c
          exp_pos = exp_pos + 1
        else
          break
        end
      end

      if exp_digits ~= "" then
        exp_part = "e" .. exp_sign .. exp_digits
        pos = exp_pos
      end
    end
  end

  local num_str = sign_str .. (int_part ~= "" and int_part or "0") ..
                  (frac_part ~= "" and ("." .. frac_part) or "") .. exp_part
  local value = tonumber(num_str)

  if value then
    return value, pos
  else
    return nil, start_pos
  end
end

--Provides: caml_scan_string
--Requires: caml_ocaml_string_to_lua, caml_skip_whitespace
function caml_scan_string(s, pos, width)
  pos = pos or 1
  local str = caml_ocaml_string_to_lua(s)

  pos = caml_skip_whitespace(str, pos)

  if pos > #str then
    return nil, pos
  end

  local start_pos = pos
  local result = ""
  local count = 0

  while pos <= #str do
    local c = str:sub(pos, pos)
    if c == " " or c == "\t" or c == "\n" or c == "\r" then
      break
    end

    result = result .. c
    pos = pos + 1
    count = count + 1

    if width and count >= width then
      break
    end
  end

  if result == "" then
    return nil, start_pos
  end

  return result, pos
end

--Provides: caml_scan_char
--Requires: caml_ocaml_string_to_lua, caml_skip_whitespace
function caml_scan_char(s, pos, skip_ws)
  pos = pos or 1
  local str = caml_ocaml_string_to_lua(s)

  if skip_ws then
    pos = caml_skip_whitespace(str, pos)
  end

  if pos > #str then
    return nil, pos
  end

  local c = str:byte(pos)
  return c, pos + 1
end

--Provides: caml_sscanf
--Requires: caml_ocaml_string_to_lua, caml_scan_int, caml_scan_float, caml_scan_string, caml_scan_char, caml_skip_whitespace
function caml_sscanf(input, fmt)
  local str = caml_ocaml_string_to_lua(input)
  local fmt_str = caml_ocaml_string_to_lua(fmt)

  local results = {}
  local pos = 1
  local fmt_pos = 1

  while fmt_pos <= #fmt_str do
    local c = fmt_str:sub(fmt_pos, fmt_pos)

    if c == "%" then
      fmt_pos = fmt_pos + 1
      if fmt_pos > #fmt_str then
        return nil
      end

      local conv = fmt_str:sub(fmt_pos, fmt_pos)

      if conv == "d" or conv == "i" or conv == "u" or conv == "x" or conv == "o" then
        local value, new_pos = caml_scan_int(str, pos, "%" .. conv)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "f" or conv == "e" or conv == "g" then
        local value, new_pos = caml_scan_float(str, pos)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "s" then
        local value, new_pos = caml_scan_string(str, pos)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "c" then
        local value, new_pos = caml_scan_char(str, pos, false)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "%" then
        pos = caml_skip_whitespace(str, pos)
        if str:sub(pos, pos) ~= "%" then
          return nil
        end
        pos = pos + 1
      else
        return nil
      end

      fmt_pos = fmt_pos + 1
    elseif c == " " or c == "\t" or c == "\n" or c == "\r" then
      pos = caml_skip_whitespace(str, pos)
      fmt_pos = fmt_pos + 1
    else
      pos = caml_skip_whitespace(str, pos)
      if str:sub(pos, pos) ~= c then
        return nil
      end
      pos = pos + 1
      fmt_pos = fmt_pos + 1
    end
  end

  return results
end

--Provides: caml_fprintf
--Requires: caml_ocaml_string_to_lua, caml_lua_string_to_ocaml, caml_format_int, caml_format_float, caml_format_string, caml_format_char
function caml_fprintf(chanid, fmt, ...)
  local io_module = package.loaded.io or require("io")

  local fmt_str = caml_ocaml_string_to_lua(fmt)
  local args = {...}
  local arg_idx = 1
  local result_parts = {}

  local i = 1
  while i <= #fmt_str do
    local c = fmt_str:sub(i, i)

    if c == "%" then
      i = i + 1
      if i > #fmt_str then
        break
      end

      local spec_start = i - 1
      local spec = ""

      while i <= #fmt_str do
        local ch = fmt_str:sub(i, i)
        spec = spec .. ch
        i = i + 1

        if ch:match("[diouxXeEfFgGaAcspn%%]") then
          break
        end
      end

      local conv = spec:sub(-1)

      if conv == "%" then
        table.insert(result_parts, "%")
      elseif conv == "d" or conv == "i" or conv == "u" or conv == "x" or conv == "X" or conv == "o" then
        if arg_idx <= #args then
          local formatted = caml_format_int("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "f" or conv == "F" or conv == "e" or conv == "E" or conv == "g" or conv == "G" then
        if arg_idx <= #args then
          local formatted = caml_format_float("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "s" then
        if arg_idx <= #args then
          local formatted = caml_format_string("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "c" then
        if arg_idx <= #args then
          local formatted = caml_format_char("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      end
    else
      table.insert(result_parts, c)
      i = i + 1
    end
  end

  local output = table.concat(result_parts)
  local output_bytes = caml_lua_string_to_ocaml(output)
  caml_ml_output_bytes(chanid, output_bytes, 0, #output_bytes)
  caml_ml_flush(chanid)

  return 0  -- Unit in OCaml
end

--Provides: caml_printf
--Requires: caml_fprintf
function caml_printf(fmt, ...)
  local io_module = package.loaded.io or require("io")
  local stdout_chanid = caml_ml_open_descriptor_out(1)
  return caml_fprintf(stdout_chanid, fmt, ...)
end

--Provides: caml_eprintf
--Requires: caml_fprintf
function caml_eprintf(fmt, ...)
  local io_module = package.loaded.io or require("io")
  local stderr_chanid = caml_ml_open_descriptor_out(2)
  return caml_fprintf(stderr_chanid, fmt, ...)
end

--Provides: caml_fscanf
--Requires: caml_ocaml_string_to_lua, caml_sscanf
function caml_fscanf(chanid, fmt)
  local io_module = package.loaded.io or require("io")

  local line_len = caml_ml_input_scan_line(chanid)
  if not line_len or line_len <= 0 then
    return nil
  end

  local line_bytes = {}
  local actual_len = caml_ml_input(chanid, line_bytes, 0, math.abs(line_len))

  if actual_len <= 0 then
    return nil
  end

  local line = caml_ocaml_string_to_lua(line_bytes)

  return caml_sscanf(line, fmt)
end

--Provides: caml_scanf
--Requires: caml_fscanf
function caml_scanf(fmt)
  local io_module = package.loaded.io or require("io")
  local stdin_chanid = caml_ml_open_descriptor_in(0)
  return caml_fscanf(stdin_chanid, fmt)
end


-- Runtime: buffer
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


--Provides: caml_ocaml_string_to_lua
function caml_ocaml_string_to_lua(s)
  if type(s) == "string" then
    return s
  end
  local chars = {}
  for i = 1, #s do
    table.insert(chars, string.char(s[i]))
  end
  return table.concat(chars)
end

--Provides: caml_buffer_create
function caml_buffer_create(initial_size)
  initial_size = initial_size or 16

  local buffer = {
    chunks = {},
    length = 0,
    capacity = initial_size
  }

  return buffer
end

--Provides: caml_buffer_add_char
function caml_buffer_add_char(buffer, c)
  local char
  if type(c) == "number" then
    char = string.char(c)
  elseif type(c) == "string" then
    char = c:sub(1, 1)
  elseif type(c) == "table" and #c == 1 then
    char = string.char(c[1])
  else
    error("Invalid character type")
  end

  table.insert(buffer.chunks, char)
  buffer.length = buffer.length + 1
end

--Provides: caml_buffer_add_string
--Requires: caml_ocaml_string_to_lua
function caml_buffer_add_string(buffer, s)
  local str = caml_ocaml_string_to_lua(s)

  if #str > 0 then
    table.insert(buffer.chunks, str)
    buffer.length = buffer.length + #str
  end
end

--Provides: caml_buffer_add_substring
--Requires: caml_ocaml_string_to_lua
function caml_buffer_add_substring(buffer, s, offset, len)
  local str = caml_ocaml_string_to_lua(s)

  local start = offset + 1
  local finish = offset + len

  if start < 1 or finish > #str then
    error("Buffer.add_substring: invalid offset or length")
  end

  local substring = str:sub(start, finish)

  if #substring > 0 then
    table.insert(buffer.chunks, substring)
    buffer.length = buffer.length + #substring
  end
end

--Provides: caml_buffer_contents
function caml_buffer_contents(buffer)
  local result_str = table.concat(buffer.chunks)

  local result = {}
  for i = 1, #result_str do
    result[i] = result_str:byte(i)
  end

  return result
end

--Provides: caml_buffer_length
function caml_buffer_length(buffer)
  return buffer.length
end

--Provides: caml_buffer_reset
function caml_buffer_reset(buffer)
  buffer.chunks = {}
  buffer.length = 0
end

--Provides: caml_buffer_clear
--Requires: caml_buffer_reset
function caml_buffer_clear(buffer)
  caml_buffer_reset(buffer)
end

--Provides: caml_buffer_add_printf
--Requires: caml_ocaml_string_to_lua, caml_buffer_add_string, caml_format_int, caml_format_float, caml_format_string, caml_format_char
function caml_buffer_add_printf(buffer, fmt, ...)
  local fmt_str = caml_ocaml_string_to_lua(fmt)
  local args = {...}
  local arg_idx = 1
  local result_parts = {}

  local i = 1
  while i <= #fmt_str do
    local c = fmt_str:sub(i, i)

    if c == "%" then
      i = i + 1
      if i > #fmt_str then
        break
      end

      local spec = ""

      while i <= #fmt_str do
        local ch = fmt_str:sub(i, i)
        spec = spec .. ch
        i = i + 1

        if ch:match("[diouxXeEfFgGaAcspn%%]") then
          break
        end
      end

      local conv = spec:sub(-1)

      if conv == "%" then
        table.insert(result_parts, "%")
      elseif conv == "d" or conv == "i" or conv == "u" or conv == "x" or conv == "X" or conv == "o" then
        if arg_idx <= #args then
          local formatted = caml_format_int("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "f" or conv == "F" or conv == "e" or conv == "E" or conv == "g" or conv == "G" then
        if arg_idx <= #args then
          local formatted = caml_format_float("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "s" then
        if arg_idx <= #args then
          local formatted = caml_format_string("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "c" then
        if arg_idx <= #args then
          local formatted = caml_format_char("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      end
    else
      table.insert(result_parts, c)
      i = i + 1
    end
  end

  local output = table.concat(result_parts)
  caml_buffer_add_string(buffer, output)
end


-- Runtime: float
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


-- Runtime: fail
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

-- Exception Handling Module
--
-- This module provides OCaml exception handling for Lua.
-- OCaml exceptions are mapped to Lua error() and pcall().
-- Exception values are represented as blocks with tags.

-- Global exception registry
-- Stores predefined exception constructors
_G._OCAML.exceptions = _G._OCAML.exceptions or {}

--Provides: caml_register_exception
function caml_register_exception(name, tag, id)
  local exc = { tag = tag, [1] = name, [2] = id }
  _G._OCAML.exceptions[name] = exc
  return exc
end

--Provides: caml_get_exception
function caml_get_exception(name)
  return _G._OCAML.exceptions[name]
end

-- Predefined OCaml exceptions
-- These are registered lazily when first used

--Provides: caml_get_failure
--Requires: caml_register_exception
function caml_get_failure()
  if not _G._OCAML.exceptions.Failure then
    caml_register_exception("Failure", 248, -3)
  end
  return _G._OCAML.exceptions.Failure
end

--Provides: caml_get_invalid_argument
--Requires: caml_register_exception
function caml_get_invalid_argument()
  if not _G._OCAML.exceptions.Invalid_argument then
    caml_register_exception("Invalid_argument", 248, -4)
  end
  return _G._OCAML.exceptions.Invalid_argument
end

--Provides: caml_get_not_found
--Requires: caml_register_exception
function caml_get_not_found()
  if not _G._OCAML.exceptions.Not_found then
    caml_register_exception("Not_found", 248, -5)
  end
  return _G._OCAML.exceptions.Not_found
end

--Provides: caml_get_end_of_file
--Requires: caml_register_exception
function caml_get_end_of_file()
  if not _G._OCAML.exceptions.End_of_file then
    caml_register_exception("End_of_file", 248, -7)
  end
  return _G._OCAML.exceptions.End_of_file
end

--Provides: caml_get_division_by_zero
--Requires: caml_register_exception
function caml_get_division_by_zero()
  if not _G._OCAML.exceptions.Division_by_zero then
    caml_register_exception("Division_by_zero", 248, -8)
  end
  return _G._OCAML.exceptions.Division_by_zero
end

--Provides: caml_get_match_failure
--Requires: caml_register_exception
function caml_get_match_failure()
  if not _G._OCAML.exceptions.Match_failure then
    caml_register_exception("Match_failure", 248, -9)
  end
  return _G._OCAML.exceptions.Match_failure
end

--Provides: caml_get_sys_error
--Requires: caml_register_exception
function caml_get_sys_error()
  if not _G._OCAML.exceptions.Sys_error then
    caml_register_exception("Sys_error", 248, -11)
  end
  return _G._OCAML.exceptions.Sys_error
end

--Provides: caml_raise_constant
function caml_raise_constant(exc)
  error(exc, 0)
end

--Provides: caml_raise_with_arg
function caml_raise_with_arg(exc, arg)
  local exc_value = { tag = 0, [1] = exc, [2] = arg }
  error(exc_value, 0)
end

--Provides: caml_raise_with_args
function caml_raise_with_args(exc, args)
  local exc_value = { tag = 0, [1] = exc }
  for i, arg in ipairs(args) do
    exc_value[i + 1] = arg
  end
  error(exc_value, 0)
end

--Provides: caml_raise_with_string
--Requires: caml_raise_with_arg
function caml_raise_with_string(exc, msg)
  caml_raise_with_arg(exc, msg)
end

--Provides: caml_failwith
--Requires: caml_get_failure caml_raise_with_arg
function caml_failwith(msg)
  caml_raise_with_arg(caml_get_failure(), msg)
end

--Provides: caml_invalid_argument
--Requires: caml_get_invalid_argument caml_raise_with_arg
function caml_invalid_argument(msg)
  caml_raise_with_arg(caml_get_invalid_argument(), msg)
end

--Provides: caml_raise_not_found
--Requires: caml_get_not_found caml_raise_constant
function caml_raise_not_found()
  caml_raise_constant(caml_get_not_found())
end

--Provides: caml_raise_end_of_file
--Requires: caml_get_end_of_file caml_raise_constant
function caml_raise_end_of_file()
  caml_raise_constant(caml_get_end_of_file())
end

--Provides: caml_raise_zero_divide
--Requires: caml_get_division_by_zero caml_raise_constant
function caml_raise_zero_divide()
  caml_raise_constant(caml_get_division_by_zero())
end

--Provides: caml_raise_match_failure
--Requires: caml_get_match_failure caml_raise_with_arg
function caml_raise_match_failure(location)
  caml_raise_with_arg(caml_get_match_failure(), location)
end

--Provides: caml_raise_sys_error
--Requires: caml_get_sys_error caml_raise_with_arg
function caml_raise_sys_error(msg)
  caml_raise_with_arg(caml_get_sys_error(), msg)
end

--Provides: caml_is_exception
function caml_is_exception(val)
  if type(val) ~= "table" then
    return false
  end
  if val.tag == 248 then
    return true
  end
  if val.tag == 0 and type(val[1]) == "table" and val[1].tag == 248 then
    return true
  end
  return false
end

--Provides: caml_exception_name
function caml_exception_name(exc)
  if type(exc) ~= "table" then
    return "Unknown"
  end
  if exc.tag == 248 and type(exc[1]) == "string" then
    return exc[1]
  end
  if exc.tag == 0 and type(exc[1]) == "table" and exc[1].tag == 248 then
    return exc[1][1] or "Unknown"
  end
  return "Unknown"
end

--Provides: caml_exception_to_string
--Requires: caml_exception_name
function caml_exception_to_string(exc)
  local name = caml_exception_name(exc)
  if type(exc) ~= "table" then
    return name
  end
  if exc.tag == 0 and exc[2] and type(exc[2]) == "string" then
    return name .. "(" .. exc[2] .. ")"
  end
  return name
end

--Provides: caml_try_catch
function caml_try_catch(f, ...)
  local success, result = pcall(f, ...)
  return success, result
end

--Provides: caml_catch
function caml_catch(f, handler, ...)
  local success, result = pcall(f, ...)
  if success then
    return result
  else
    return handler(result)
  end
end

--Provides: caml_try_finally
function caml_try_finally(f, cleanup, ...)
  local success, result = pcall(f, ...)
  cleanup()
  if success then
    return result
  else
    error(result, 0)
  end
end

--Provides: caml_array_bound_error
--Requires: caml_invalid_argument
function caml_array_bound_error()
  caml_invalid_argument("index out of bounds")
end

--Provides: caml_string_bound_error
--Requires: caml_invalid_argument
function caml_string_bound_error()
  caml_invalid_argument("index out of bounds")
end

--Provides: caml_bytes_bound_error
--Requires: caml_invalid_argument
function caml_bytes_bound_error()
  caml_invalid_argument("index out of bounds")
end


-- Runtime: map
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


--Provides: caml_map_height
function caml_map_height(node)
  if not node then
    return 0
  end
  return node.height
end

--Provides: caml_map_create_node
--Requires: caml_map_height
function caml_map_create_node(key, value, left, right)
  return {
    key = key,
    value = value,
    left = left,
    right = right,
    height = 1 + math.max(caml_map_height(left), caml_map_height(right))
  }
end

--Provides: caml_map_balance_factor
--Requires: caml_map_height
function caml_map_balance_factor(node)
  if not node then
    return 0
  end
  return caml_map_height(node.left) - caml_map_height(node.right)
end

--Provides: caml_map_rotate_right
--Requires: caml_map_height
function caml_map_rotate_right(node)
  local left = node.left
  local left_right = left.right

  left.right = node
  node.left = left_right

  node.height = 1 + math.max(caml_map_height(node.left), caml_map_height(node.right))
  left.height = 1 + math.max(caml_map_height(left.left), caml_map_height(left.right))

  return left
end

--Provides: caml_map_rotate_left
--Requires: caml_map_height
function caml_map_rotate_left(node)
  local right = node.right
  local right_left = right.left

  right.left = node
  node.right = right_left

  node.height = 1 + math.max(caml_map_height(node.left), caml_map_height(node.right))
  right.height = 1 + math.max(caml_map_height(right.left), caml_map_height(right.right))

  return right
end

--Provides: caml_map_balance
--Requires: caml_map_balance_factor, caml_map_rotate_left, caml_map_rotate_right
function caml_map_balance(node)
  if not node then
    return nil
  end

  local bf = caml_map_balance_factor(node)

  if bf > 1 then
    if caml_map_balance_factor(node.left) < 0 then
      node.left = caml_map_rotate_left(node.left)
    end
    return caml_map_rotate_right(node)
  end

  if bf < -1 then
    if caml_map_balance_factor(node.right) > 0 then
      node.right = caml_map_rotate_right(node.right)
    end
    return caml_map_rotate_left(node)
  end

  return node
end

--Provides: caml_map_add_internal
--Requires: caml_map_create_node, caml_map_height, caml_map_balance
function caml_map_add_internal(cmp, key, value, node)
  if not node then
    return caml_map_create_node(key, value, nil, nil)
  end

  local c = cmp(key, node.key)

  if c == 0 then
    node.value = value
    return node
  elseif c < 0 then
    node.left = caml_map_add_internal(cmp, key, value, node.left)
  else
    node.right = caml_map_add_internal(cmp, key, value, node.right)
  end

  node.height = 1 + math.max(caml_map_height(node.left), caml_map_height(node.right))

  return caml_map_balance(node)
end

--Provides: caml_map_find_internal
function caml_map_find_internal(cmp, key, node)
  if not node then
    return nil
  end

  local c = cmp(key, node.key)

  if c == 0 then
    return node.value
  elseif c < 0 then
    return caml_map_find_internal(cmp, key, node.left)
  else
    return caml_map_find_internal(cmp, key, node.right)
  end
end

--Provides: caml_map_mem_internal
function caml_map_mem_internal(cmp, key, node)
  if not node then
    return false
  end

  local c = cmp(key, node.key)

  if c == 0 then
    return true
  elseif c < 0 then
    return caml_map_mem_internal(cmp, key, node.left)
  else
    return caml_map_mem_internal(cmp, key, node.right)
  end
end

--Provides: caml_map_min_node
function caml_map_min_node(node)
  if not node.left then
    return node
  end
  return caml_map_min_node(node.left)
end

--Provides: caml_map_remove_internal
--Requires: caml_map_min_node, caml_map_height, caml_map_balance
function caml_map_remove_internal(cmp, key, node)
  if not node then
    return nil
  end

  local c = cmp(key, node.key)

  if c < 0 then
    node.left = caml_map_remove_internal(cmp, key, node.left)
  elseif c > 0 then
    node.right = caml_map_remove_internal(cmp, key, node.right)
  else
    if not node.left then
      return node.right
    elseif not node.right then
      return node.left
    else
      local successor = caml_map_min_node(node.right)
      node.key = successor.key
      node.value = successor.value
      node.right = caml_map_remove_internal(cmp, successor.key, node.right)
    end
  end

  if not node then
    return nil
  end

  node.height = 1 + math.max(caml_map_height(node.left), caml_map_height(node.right))

  return caml_map_balance(node)
end

--Provides: caml_map_iter_internal
function caml_map_iter_internal(f, node)
  if not node then
    return
  end
  caml_map_iter_internal(f, node.left)
  f(node.key, node.value)
  caml_map_iter_internal(f, node.right)
end

--Provides: caml_map_fold_internal
function caml_map_fold_internal(f, node, acc)
  if not node then
    return acc
  end
  acc = caml_map_fold_internal(f, node.left, acc)
  acc = f(node.key, node.value, acc)
  acc = caml_map_fold_internal(f, node.right, acc)
  return acc
end

--Provides: caml_map_for_all_internal
function caml_map_for_all_internal(p, node)
  if not node then
    return true
  end
  return p(node.key, node.value) and caml_map_for_all_internal(p, node.left) and caml_map_for_all_internal(p, node.right)
end

--Provides: caml_map_exists_internal
function caml_map_exists_internal(p, node)
  if not node then
    return false
  end
  return p(node.key, node.value) or caml_map_exists_internal(p, node.left) or caml_map_exists_internal(p, node.right)
end

--Provides: caml_map_cardinal_internal
function caml_map_cardinal_internal(node)
  if not node then
    return 0
  end
  return 1 + caml_map_cardinal_internal(node.left) + caml_map_cardinal_internal(node.right)
end

--Provides: caml_map_map_values_internal
--Requires: caml_map_create_node
function caml_map_map_values_internal(f, node)
  if not node then
    return nil
  end
  return caml_map_create_node(
    node.key,
    f(node.value),
    caml_map_map_values_internal(f, node.left),
    caml_map_map_values_internal(f, node.right)
  )
end

--Provides: caml_map_mapi_internal
--Requires: caml_map_create_node
function caml_map_mapi_internal(f, node)
  if not node then
    return nil
  end
  return caml_map_create_node(
    node.key,
    f(node.key, node.value),
    caml_map_mapi_internal(f, node.left),
    caml_map_mapi_internal(f, node.right)
  )
end

--Provides: caml_map_filter_internal
--Requires: caml_map_create_node, caml_map_balance, caml_map_min_node, caml_map_remove_internal
function caml_map_filter_internal(cmp, p, node)
  if not node then
    return nil
  end

  local left = caml_map_filter_internal(cmp, p, node.left)
  local right = caml_map_filter_internal(cmp, p, node.right)

  if p(node.key, node.value) then
    local result = caml_map_create_node(node.key, node.value, left, right)
    return caml_map_balance(result)
  else
    if not left then
      return right
    elseif not right then
      return left
    else
      local min = caml_map_min_node(right)
      local new_right = caml_map_remove_internal(cmp, min.key, right)
      local result = caml_map_create_node(min.key, min.value, left, new_right)
      return caml_map_balance(result)
    end
  end
end


--Provides: caml_map_empty
function caml_map_empty(_unit)
  return nil
end

--Provides: caml_map_add
--Requires: caml_map_add_internal
function caml_map_add(cmp, key, value, map)
  return caml_map_add_internal(cmp, key, value, map)
end

--Provides: caml_map_find
--Requires: caml_map_find_internal, caml_raise_not_found
function caml_map_find(cmp, key, map)
  local result = caml_map_find_internal(cmp, key, map)
  if result == nil then
    caml_raise_not_found()
  end
  return result
end

--Provides: caml_map_find_opt
--Requires: caml_map_find_internal
function caml_map_find_opt(cmp, key, map)
  local result = caml_map_find_internal(cmp, key, map)
  if result == nil then
    return 0  -- None
  else
    return {tag = 0, [1] = result}  -- Some value
  end
end

--Provides: caml_map_remove
--Requires: caml_map_remove_internal
function caml_map_remove(cmp, key, map)
  return caml_map_remove_internal(cmp, key, map)
end

--Provides: caml_map_mem
--Requires: caml_map_mem_internal
function caml_map_mem(cmp, key, map)
  if caml_map_mem_internal(cmp, key, map) then
    return 1
  else
    return 0
  end
end

--Provides: caml_map_iter
--Requires: caml_map_iter_internal
function caml_map_iter(f, map)
  caml_map_iter_internal(f, map)
  return 0
end

--Provides: caml_map_fold
--Requires: caml_map_fold_internal
function caml_map_fold(f, map, init)
  return caml_map_fold_internal(f, map, init)
end

--Provides: caml_map_for_all
--Requires: caml_map_for_all_internal
function caml_map_for_all(p, map)
  if caml_map_for_all_internal(p, map) then
    return 1
  else
    return 0
  end
end

--Provides: caml_map_exists
--Requires: caml_map_exists_internal
function caml_map_exists(p, map)
  if caml_map_exists_internal(p, map) then
    return 1
  else
    return 0
  end
end

--Provides: caml_map_cardinal
--Requires: caml_map_cardinal_internal
function caml_map_cardinal(map)
  return caml_map_cardinal_internal(map)
end

--Provides: caml_map_is_empty
function caml_map_is_empty(map)
  if map == nil then
    return 1
  else
    return 0
  end
end

--Provides: caml_map_map
--Requires: caml_map_map_values_internal
function caml_map_map(f, map)
  return caml_map_map_values_internal(f, map)
end

--Provides: caml_map_mapi
--Requires: caml_map_mapi_internal
function caml_map_mapi(f, map)
  return caml_map_mapi_internal(f, map)
end

--Provides: caml_map_filter
--Requires: caml_map_filter_internal
function caml_map_filter(cmp, p, map)
  return caml_map_filter_internal(cmp, p, map)
end


-- Runtime: io
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

-- I/O operations for OCaml channels and file descriptors

--Provides: caml_sys_fds
caml_sys_fds = {}
caml_sys_fds[0] = { file = io.stdin, flags = {rdonly = true}, offset = 0 }
caml_sys_fds[1] = { file = io.stdout, flags = {wronly = true}, offset = 0 }
caml_sys_fds[2] = { file = io.stderr, flags = {wronly = true}, offset = 0 }

--Provides: caml_next_chanid
caml_next_chanid = 3

--Provides: caml_ml_channels
caml_ml_channels = {}

--Provides: caml_io_buffer_size
caml_io_buffer_size = 4096

--
-- Channel Backend Interface
--
-- A backend is a table with the following methods:
--   read(n): Read up to n bytes, return string (or nil on EOF)
--   write(str): Write string, return number of bytes written
--   flush(): Flush any pending writes (optional)
--   seek(pos): Seek to position (optional, for seekable backends)
--   close(): Close the backend (optional)
--
-- Built-in backends: file, memory, custom
--

--
-- File descriptor operations
--

--Provides: caml_sys_open
--Requires: caml_sys_fds, caml_next_chanid
function caml_sys_open(name, flags, perms)
  -- Parse OCaml open flags
  -- flags is an OCaml list: 0 = [], [tag, [next]]
  local parsed_flags = {}
  while flags ~= 0 do
    local flag = flags[1]
    -- Flag meanings from OCaml:
    -- 0 = O_RDONLY, 1 = O_WRONLY, 2 = O_APPEND, 3 = O_CREAT,
    -- 4 = O_TRUNC, 5 = O_EXCL, 6 = O_BINARY, 7 = O_TEXT, 8 = O_NONBLOCK
    if flag == 0 then
      parsed_flags.rdonly = true
    elseif flag == 1 then
      parsed_flags.wronly = true
    elseif flag == 2 then
      parsed_flags.append = true
      parsed_flags.wronly = true
    elseif flag == 3 then
      parsed_flags.create = true
    elseif flag == 4 then
      parsed_flags.truncate = true
    elseif flag == 6 then
      parsed_flags.binary = true
    elseif flag == 7 then
      parsed_flags.text = true
    end
    flags = flags[2]
  end

  -- Determine Lua file open mode
  local mode
  if parsed_flags.rdonly and not parsed_flags.wronly then
    mode = parsed_flags.binary and "rb" or "r"
  elseif parsed_flags.wronly and not parsed_flags.rdonly then
    if parsed_flags.append then
      mode = parsed_flags.binary and "ab" or "a"
    else
      mode = parsed_flags.binary and "wb" or "w"
    end
  else
    -- Read/write mode
    mode = parsed_flags.binary and "r+b" or "r+"
    if parsed_flags.create then
      mode = parsed_flags.binary and "w+b" or "w+"
    end
  end

  -- Open the file
  local file, err = io.open(name, mode)
  if not file then
    error("caml_sys_open: " .. (err or "unknown error"))
  end

  -- Find available file descriptor number
  local fd = caml_next_chanid
  caml_next_chanid = caml_next_chanid + 1

  -- Store file descriptor
  caml_sys_fds[fd] = {
    file = file,
    flags = parsed_flags,
    offset = 0
  }

  return fd
end

--Provides: caml_sys_close
--Requires: caml_sys_fds
function caml_sys_close(fd)
  local fd_desc = caml_sys_fds[fd]
  if fd_desc and fd_desc.file then
    -- Don't close stdin/stdout/stderr
    if fd >= 3 then
      fd_desc.file:close()
    end
    caml_sys_fds[fd] = nil
  end
  return 0
end

--
-- Channel operations
--

--Provides: caml_ml_open_descriptor_in
--Requires: caml_sys_fds, caml_ml_channels, caml_next_chanid
function caml_ml_open_descriptor_in(fd)
  local fd_desc = caml_sys_fds[fd]
  if not fd_desc then
    error("caml_ml_open_descriptor_in: invalid file descriptor " .. tostring(fd))
  end

  -- Create channel ID
  local chanid = caml_next_chanid
  caml_next_chanid = caml_next_chanid + 1

  -- Create input channel
  local channel = {
    file = fd_desc.file,
    fd = fd,
    flags = fd_desc.flags,
    opened = true,
    out = false,
    buffer = "",
    buffer_pos = 1,
    offset = fd_desc.offset or 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

--Provides: caml_ml_open_descriptor_out
--Requires: caml_sys_fds, caml_ml_channels, caml_next_chanid
function caml_ml_open_descriptor_out(fd)
  local fd_desc = caml_sys_fds[fd]
  if not fd_desc then
    error("caml_ml_open_descriptor_out: invalid file descriptor " .. tostring(fd))
  end

  -- Create channel ID
  local chanid = caml_next_chanid
  caml_next_chanid = caml_next_chanid + 1

  -- Create output channel
  local channel = {
    file = fd_desc.file,
    fd = fd,
    flags = fd_desc.flags,
    opened = true,
    out = true,
    buffer = {},
    buffered = 1, -- 0 = unbuffered, 1 = buffered, 2 = line buffered
    offset = fd_desc.offset or 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

--Provides: caml_ml_open_descriptor_in_with_flags
--Requires: caml_ml_open_descriptor_in
function caml_ml_open_descriptor_in_with_flags(fd, flags)
  -- OCaml 5.1+: currently ignoring flags
  return caml_ml_open_descriptor_in(fd)
end

--Provides: caml_ml_open_descriptor_out_with_flags
--Requires: caml_ml_open_descriptor_out
function caml_ml_open_descriptor_out_with_flags(fd, flags)
  -- OCaml 5.1+: currently ignoring flags
  return caml_ml_open_descriptor_out(fd)
end

--Provides: caml_ml_close_channel
--Requires: caml_ml_flush, caml_sys_close, caml_ml_channels
function caml_ml_close_channel(chanid)
  local chan = caml_ml_channels[chanid]
  if chan and chan.opened then
    if chan.out then
      caml_ml_flush(chanid)
    end
    chan.opened = false
    -- Close custom backend if it has a close method
    if chan.backend and chan.backend.close then
      chan.backend:close()
    end
    -- Close file descriptor if present (not for memory/custom channels)
    if chan.fd then
      caml_sys_close(chan.fd)
    end
  end
  return 0
end

--Provides: caml_channel_descriptor
--Requires: caml_ml_channels
function caml_channel_descriptor(chanid)
  local chan = caml_ml_channels[chanid]
  if chan then
    return chan.fd
  end
  error("caml_channel_descriptor: invalid channel")
end

--
-- Input operations
--

--Provides: caml_ml_input_char
--Requires: caml_ml_channels
function caml_ml_input_char(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_input_char: channel is closed")
  end

  -- Check buffer first
  if chan.buffer_pos <= #chan.buffer then
    local c = string.byte(chan.buffer, chan.buffer_pos)
    chan.buffer_pos = chan.buffer_pos + 1
    chan.offset = chan.offset + 1
    return c
  end

  -- Memory channel
  if chan.memory then
    if chan.pos > #chan.data then
      error("End_of_file")
    end
    local c = string.byte(chan.data, chan.pos)
    chan.pos = chan.pos + 1
    chan.offset = chan.offset + 1
    return c
  end

  -- Custom backend
  if chan.backend then
    local chunk = chan.backend:read(1)
    if not chunk or #chunk == 0 then
      error("End_of_file")
    end
    chan.offset = chan.offset + 1
    return string.byte(chunk, 1)
  end

  -- Read from file
  local c = chan.file:read(1)
  if not c then
    error("End_of_file")
  end

  chan.offset = chan.offset + 1
  return string.byte(c)
end

--Provides: caml_ml_input
--Requires: caml_ml_channels
function caml_ml_input(chanid, buf, offset, len)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_input: channel is closed")
  end

  local bytes_read = 0

  -- Read from buffer first
  local buf_avail = #chan.buffer - chan.buffer_pos + 1
  if buf_avail > 0 then
    local to_read = math.min(len, buf_avail)
    local chunk = string.sub(chan.buffer, chan.buffer_pos, chan.buffer_pos + to_read - 1)
    -- Store in OCaml bytes buffer (table representation)
    for i = 1, to_read do
      buf[offset + i] = string.byte(chunk, i)
    end
    chan.buffer_pos = chan.buffer_pos + to_read
    bytes_read = to_read
    len = len - to_read
    offset = offset + to_read
  end

  -- Read more from file/memory/backend if needed
  if len > 0 then
    local chunk
    if chan.memory then
      -- Read from memory
      local available = #chan.data - chan.pos + 1
      if available > 0 then
        local to_read = math.min(len, available)
        chunk = string.sub(chan.data, chan.pos, chan.pos + to_read - 1)
        chan.pos = chan.pos + to_read
      end
    elseif chan.backend then
      -- Read from custom backend
      chunk = chan.backend:read(len)
    else
      -- Read from file
      chunk = chan.file:read(len)
    end

    if chunk then
      local chunk_len = #chunk
      for i = 1, chunk_len do
        buf[offset + i] = string.byte(chunk, i)
      end
      bytes_read = bytes_read + chunk_len
      chan.offset = chan.offset + chunk_len
    end
  end

  return bytes_read
end

--Provides: caml_ml_input_int
--Requires: caml_ml_input_char
function caml_ml_input_int(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_input_int: channel is closed")
  end

  -- Read 4 bytes in big-endian order (Lua 5.1 compatible)
  local result = 0
  for i = 1, 4 do
    local b = caml_ml_input_char(chanid)
    result = result * 256 + b
  end

  return result
end

--Provides: caml_ml_input_scan_line
--Requires: caml_ml_channels
function caml_ml_input_scan_line(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_input_scan_line: channel is closed")
  end

  -- Look for newline in buffer
  local newline_pos = string.find(chan.buffer, "\n", chan.buffer_pos, true)
  if newline_pos then
    return newline_pos - chan.buffer_pos + 1
  end

  -- Read more into buffer
  local chunk = chan.file:read("*l")
  if chunk then
    chan.buffer = string.sub(chan.buffer, chan.buffer_pos) .. chunk .. "\n"
    chan.buffer_pos = 1
    return #chan.buffer
  end

  -- No newline found, return remaining buffer size
  return -(#chan.buffer - chan.buffer_pos + 1)
end

--Provides: caml_input_value
--Requires: caml_ml_input, caml_marshal_from_bytes, caml_marshal_total_size, caml_raise_end_of_file, caml_ml_channels
function caml_input_value(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_input_value: channel is closed")
  end

  -- Read the 20-byte marshal header first
  local header_bytes = {}
  local header_size = 20
  local bytes_read = caml_ml_input(chanid, header_bytes, 0, header_size)

  if bytes_read < header_size then
    error("caml_input_value: truncated marshal header (expected 20 bytes, got " .. bytes_read .. ")")
  end

  -- Convert byte array to string for marshal functions
  -- caml_ml_input fills buf[offset+1] to buf[offset+len] with byte values
  local header_chars = {}
  for i = 1, header_size do
    header_chars[i] = string.char(header_bytes[i])
  end
  local header_str = table.concat(header_chars)

  -- Get total size (header + data) from the header
  local total_size = caml_marshal_total_size(header_str, 0)
  local data_size = total_size - header_size

  -- Read the remaining data
  local data_bytes = {}
  if data_size > 0 then
    bytes_read = caml_ml_input(chanid, data_bytes, 0, data_size)
    if bytes_read < data_size then
      error("caml_input_value: truncated marshal data (expected " .. data_size .. " bytes, got " .. bytes_read .. ")")
    end

    -- Convert data bytes to string
    local data_chars = {}
    for i = 1, data_size do
      data_chars[i] = string.char(data_bytes[i])
    end
    local data_str = table.concat(data_chars)

    -- Combine header and data
    local full_bytes = header_str .. data_str

    -- Unmarshal the value
    return caml_marshal_from_bytes(full_bytes, 0)
  else
    -- Only header, no data
    return caml_marshal_from_bytes(header_str, 0)
  end
end

--Provides: caml_input_value_to_outside_heap
--Requires: caml_input_value
-- Alias for compatibility (OCaml 5.0+)
function caml_input_value_to_outside_heap(chanid)
  return caml_input_value(chanid)
end

--
-- Output operations
--

--Provides: caml_ml_flush
--Requires: caml_ml_channels
function caml_ml_flush(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan then
    error("caml_ml_flush: invalid channel")
  end
  if not chan.opened then
    error("caml_ml_flush: channel is closed")
  end
  if not chan.out then
    return 0
  end

  -- For memory channels, buffer is already the destination
  if chan.memory then
    -- Nothing to flush - data is already in chan.buffer
    return 0
  end

  -- Flush buffer to file or custom backend
  if #chan.buffer > 0 then
    local str = table.concat(chan.buffer)
    if chan.backend then
      -- Custom backend
      local written = chan.backend:write(str)
      if chan.backend.flush then
        chan.backend:flush()
      end
      chan.offset = chan.offset + (written or #str)
    else
      -- File backend
      chan.file:write(str)
      chan.file:flush()
      chan.offset = chan.offset + #str
    end
    chan.buffer = {}
  end

  return 0
end

--Provides: caml_ml_output_char
--Requires: caml_ml_flush
function caml_ml_output_char(chanid, c)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_output_char: channel is closed")
  end

  local char = string.char(c)
  table.insert(chan.buffer, char)

  -- Flush if unbuffered
  if chan.buffered == 0 then
    caml_ml_flush(chanid)
  -- Line buffered: flush on newline
  elseif chan.buffered == 2 and c == 10 then
    caml_ml_flush(chanid)
  end

  return 0
end

--Provides: caml_ml_output
--Requires: caml_ml_flush, caml_ml_channels, caml_io_buffer_size
function caml_ml_output(chanid, str, offset, len)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_output: channel is closed")
  end

  -- Extract substring (Lua strings are 1-based, OCaml offset is 0-based)
  local chunk = string.sub(str, offset + 1, offset + len)
  table.insert(chan.buffer, chunk)

  -- Handle buffering
  if chan.buffered == 0 then
    caml_ml_flush(chanid)
  elseif chan.buffered == 2 and string.find(chunk, "\n", 1, true) then
    caml_ml_flush(chanid)
  elseif chan.buffered == 1 and #table.concat(chan.buffer) >= caml_io_buffer_size then
    caml_ml_flush(chanid)
  end

  return 0
end

--Provides: caml_ml_output_bytes
--Requires: caml_ml_output
function caml_ml_output_bytes(chanid, bytes, offset, len)
  -- Convert bytes (table of byte values) to string
  local chars = {}
  for i = 1, len do
    chars[i] = string.char(bytes[offset + i])
  end
  local str = table.concat(chars)

  -- Use regular output
  return caml_ml_output(chanid, str, 0, len)
end

--Provides: caml_ml_output_int
--Requires: caml_ml_flush, caml_ml_channels
function caml_ml_output_int(chanid, i)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_output_int: channel is closed")
  end

  -- Write 4 bytes in big-endian order (Lua 5.1 compatible)
  local function byte_at(val, shift)
    return math.floor(val / (2 ^ shift)) % 256
  end
  local bytes = {
    string.char(byte_at(i, 24)),
    string.char(byte_at(i, 16)),
    string.char(byte_at(i, 8)),
    string.char(i % 256)
  }
  table.insert(chan.buffer, table.concat(bytes))

  if chan.buffered == 0 then
    caml_ml_flush(chanid)
  end

  return 0
end

--Provides: caml_output_value
--Requires: caml_ml_output, caml_marshal_to_string, caml_ml_channels
function caml_output_value(chanid, v, flags)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_output_value: channel is closed")
  end

  if not chan.out then
    error("caml_output_value: channel is not an output channel")
  end

  -- Marshal the value to a string (includes header)
  local marshaled = caml_marshal_to_string(v, flags)

  -- Write the marshaled bytes to the channel
  caml_ml_output(chanid, marshaled, 0, #marshaled)
end

--
-- Channel positioning
--

--Provides: caml_ml_seek_in
--Requires: caml_ml_channels
function caml_ml_seek_in(chanid, pos)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_seek_in: channel is closed")
  end

  chan.file:seek("set", pos)
  chan.offset = pos
  chan.buffer = ""
  chan.buffer_pos = 1
  return 0
end

--Provides: caml_ml_seek_in_64
--Requires: caml_ml_seek_in
function caml_ml_seek_in_64(chanid, pos)
  -- Lua numbers are 64-bit floats, should handle most cases
  return caml_ml_seek_in(chanid, pos)
end

--Provides: caml_ml_seek_out
--Requires: caml_ml_flush
function caml_ml_seek_out(chanid, pos)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened then
    error("caml_ml_seek_out: channel is closed")
  end

  caml_ml_flush(chanid)
  chan.file:seek("set", pos)
  chan.offset = pos
  return 0
end

--Provides: caml_ml_seek_out_64
--Requires: caml_ml_seek_out
function caml_ml_seek_out_64(chanid, pos)
  return caml_ml_seek_out(chanid, pos)
end

--Provides: caml_ml_pos_in
--Requires: caml_ml_channels
function caml_ml_pos_in(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan then
    error("caml_ml_pos_in: invalid channel")
  end

  -- Current position is offset minus unread buffer
  return chan.offset - (#chan.buffer - chan.buffer_pos + 1)
end

--Provides: caml_ml_pos_in_64
--Requires: caml_ml_pos_in
function caml_ml_pos_in_64(chanid)
  return caml_ml_pos_in(chanid)
end

--Provides: caml_ml_pos_out
--Requires: caml_ml_channels
function caml_ml_pos_out(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan then
    error("caml_ml_pos_out: invalid channel")
  end

  -- Current position is offset plus buffered data
  local buffered = 0
  for _, chunk in ipairs(chan.buffer) do
    buffered = buffered + #chunk
  end
  return chan.offset + buffered
end

--Provides: caml_ml_pos_out_64
--Requires: caml_ml_pos_out
function caml_ml_pos_out_64(chanid)
  return caml_ml_pos_out(chanid)
end

--Provides: caml_ml_channel_size
--Requires: caml_ml_channels
function caml_ml_channel_size(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan then
    error("caml_ml_channel_size: invalid channel")
  end

  local current = chan.file:seek()
  local size = chan.file:seek("end")
  chan.file:seek("set", current)
  return size
end

--Provides: caml_ml_channel_size_64
--Requires: caml_ml_channel_size
function caml_ml_channel_size_64(chanid)
  return caml_ml_channel_size(chanid)
end

--
-- Channel configuration
--

--Provides: caml_ml_set_binary_mode
--Requires: caml_ml_channels
function caml_ml_set_binary_mode(chanid, mode)
  local chan = caml_ml_channels[chanid]
  if chan then
    chan.flags.binary = (mode ~= 0)
    chan.flags.text = (mode == 0)
  end
  return 0
end

--Provides: caml_ml_is_binary_mode
--Requires: caml_ml_channels
function caml_ml_is_binary_mode(chanid)
  local chan = caml_ml_channels[chanid]
  if chan and chan.flags.binary then
    return 1
  end
  return 0
end

--Provides: caml_ml_set_channel_name
--Requires: caml_ml_channels
function caml_ml_set_channel_name(chanid, name)
  local chan = caml_ml_channels[chanid]
  if chan then
    chan.name = name
  end
  return 0
end

--Provides: caml_ml_out_channels_list
--Requires: caml_ml_channels
function caml_ml_out_channels_list()
  -- Return OCaml list of all open output channels
  local list = 0 -- empty list
  for chanid, chan in pairs(caml_ml_channels) do
    if chan.opened and chan.out then
      list = {chanid, list}
    end
  end
  return list
end

--Provides: caml_ml_is_buffered
--Requires: caml_ml_channels
function caml_ml_is_buffered(chanid)
  local chan = caml_ml_channels[chanid]
  if chan and chan.buffered and chan.buffered > 0 then
    return 1
  end
  return 0
end

--Provides: caml_ml_set_buffered
--Requires: caml_ml_flush
function caml_ml_set_buffered(chanid, v)
  local chan = caml_ml_channels[chanid]
  if chan then
    chan.buffered = v
    if v == 0 then
      caml_ml_flush(chanid)
    end
  end
  return 0
end

--
-- In-memory channels
--

--Provides: caml_ml_open_string_in
--Requires: caml_ml_channels, caml_next_chanid
function caml_ml_open_string_in(str)
  local chanid = caml_next_chanid
  caml_next_chanid = caml_next_chanid + 1

  local channel = {
    memory = true,
    opened = true,
    out = false,
    data = str,
    pos = 1,
    buffer = "",
    buffer_pos = 1,
    offset = 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

--Provides: caml_ml_open_buffer_out
--Requires: caml_ml_channels, caml_next_chanid
function caml_ml_open_buffer_out()
  local chanid = caml_next_chanid
  caml_next_chanid = caml_next_chanid + 1

  local channel = {
    memory = true,
    opened = true,
    out = true,
    buffer = {},
    buffered = 1,
    offset = 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

--Provides: caml_ml_buffer_contents
--Requires: caml_ml_flush, caml_ml_channels
function caml_ml_buffer_contents(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened or not chan.out or not chan.memory then
    error("caml_ml_buffer_contents: invalid channel")
  end

  -- Flush any pending data
  caml_ml_flush(chanid)

  -- Convert buffer to string
  return table.concat(chan.buffer)
end

--Provides: caml_ml_buffer_reset
--Requires: caml_ml_channels
function caml_ml_buffer_reset(chanid)
  local chan = caml_ml_channels[chanid]
  if not chan or not chan.opened or not chan.out or not chan.memory then
    error("caml_ml_buffer_reset: invalid channel")
  end

  chan.buffer = {}
  chan.offset = 0
end

--
-- Custom Channel Backends
--

--Provides: caml_ml_open_custom_in
--Requires: caml_ml_channels, caml_next_chanid
function caml_ml_open_custom_in(backend)
  local chanid = caml_next_chanid
  caml_next_chanid = caml_next_chanid + 1

  local channel = {
    backend = backend,
    opened = true,
    out = false,
    buffer = "",
    buffer_pos = 1,
    offset = 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end

--Provides: caml_ml_open_custom_out
--Requires: caml_ml_channels, caml_next_chanid
function caml_ml_open_custom_out(backend)
  local chanid = caml_next_chanid
  caml_next_chanid = caml_next_chanid + 1

  local channel = {
    backend = backend,
    opened = true,
    out = true,
    buffer = {},
    buffered = 1,
    offset = 0
  }

  caml_ml_channels[chanid] = channel
  return chanid
end



-- Runtime: stream
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

--Provides: caml_stream_raise_failure
function caml_stream_raise_failure()
  error("Stream.Failure")
end

--Provides: caml_stream_force
function caml_stream_force(stream)
  local data = stream.data
  if data.state == "thunk" then
    local func = data.func
    local result = func()

    if result == nil then
      data.state = "empty"
      data.func = nil
    else
      data.state = "cons"
      data.head = result.head
      data.tail = result.tail
      data.func = nil
    end
  end
  return data.state
end

--Provides: caml_stream_empty
function caml_stream_empty(_unit)
  return {
    data = {
      state = "empty"
    }
  }
end

--Provides: caml_stream_peek
--Requires: caml_stream_force
function caml_stream_peek(stream)
  local state = caml_stream_force(stream)
  if state == "empty" then
    return nil
  else
    return stream.data.head
  end
end

--Provides: caml_stream_next
--Requires: caml_stream_force caml_stream_raise_failure
function caml_stream_next(stream)
  local state = caml_stream_force(stream)
  if state == "empty" then
    caml_stream_raise_failure()
  end

  local head = stream.data.head
  local tail = stream.data.tail

  if tail then
    stream.data = tail.data
  else
    stream.data = { state = "empty" }
  end

  return head
end

--Provides: caml_stream_junk
--Requires: caml_stream_force caml_stream_raise_failure
function caml_stream_junk(stream)
  local state = caml_stream_force(stream)
  if state == "empty" then
    caml_stream_raise_failure()
  end

  local tail = stream.data.tail

  if tail then
    stream.data = tail.data
  else
    stream.data = { state = "empty" }
  end

  return 0
end

--Provides: caml_stream_npeek
--Requires: caml_stream_force
function caml_stream_npeek(n, stream)
  local result = {tag = 0}
  local current = stream
  local count = 0

  while count < n do
    local state = caml_stream_force(current)
    if state == "empty" then
      break
    end

    table.insert(result, current.data.head)
    count = count + 1

    current = current.data.tail
    if not current then
      break
    end
  end

  local ocaml_list = {tag = 0}
  for i = #result, 1, -1 do
    ocaml_list = {tag = 0, [1] = result[i], [2] = ocaml_list}
  end

  return ocaml_list
end

--Provides: caml_stream_is_empty
--Requires: caml_stream_force
function caml_stream_is_empty(stream)
  local state = caml_stream_force(stream)
  if state == "empty" then
    return 1
  else
    return 0
  end
end

--Provides: caml_stream_from
function caml_stream_from(func)
  local function thunk()
    local value = func()
    if value == nil then
      return nil
    else
      return {
        head = value,
        tail = caml_stream_from(func)
      }
    end
  end

  return {
    data = {
      state = "thunk",
      func = thunk
    }
  }
end

--Provides: caml_stream_of_list
--Requires: caml_stream_empty
function caml_stream_of_list(list)
  if list.tag == 0 and not list[1] then
    return caml_stream_empty(0)
  end

  local function thunk()
    if list.tag == 0 and not list[1] then
      return nil
    else
      return {
        head = list[1],
        tail = caml_stream_of_list(list[2] or {tag = 0})
      }
    end
  end

  return {
    data = {
      state = "thunk",
      func = thunk
    }
  }
end

--Provides: caml_stream_of_string
--Requires: caml_stream_from
function caml_stream_of_string(str)
  local pos = 1
  local len = #str

  local function generator()
    if pos > len then
      return nil
    end
    local char = str:byte(pos)
    pos = pos + 1
    return char
  end

  return caml_stream_from(generator)
end

--Provides: caml_stream_of_channel
--Requires: caml_stream_from caml_ml_input_char
function caml_stream_of_channel(chan)
  local function generator()
    local ok, result = pcall(caml_ml_input_char, chan)
    if ok then
      return result
    else
      return nil
    end
  end

  return caml_stream_from(generator)
end

--Provides: caml_stream_cons
function caml_stream_cons(head, tail)
  return {
    data = {
      state = "cons",
      head = head,
      tail = tail
    }
  }
end

--Provides: caml_stream_of_array
--Requires: caml_stream_from
function caml_stream_of_array(arr)
  local len = arr[0]
  local pos = 1

  local function generator()
    if pos > len then
      return nil
    end
    local value = arr[pos]
    pos = pos + 1
    return value
  end

  return caml_stream_from(generator)
end

--Provides: caml_stream_iter
--Requires: caml_stream_force
function caml_stream_iter(f, stream)
  while true do
    local state = caml_stream_force(stream)
    if state == "empty" then
      break
    end

    f(stream.data.head)

    local tail = stream.data.tail
    if tail then
      stream.data = tail.data
    else
      stream.data = { state = "empty" }
    end
  end

  return 0
end

--Provides: caml_stream_count
--Requires: caml_stream_force
function caml_stream_count(stream)
  local count = 0
  while true do
    local state = caml_stream_force(stream)
    if state == "empty" then
      break
    end
    count = count + 1

    local tail = stream.data.tail
    if tail then
      stream.data = tail.data
    else
      stream.data = { state = "empty" }
    end
  end
  return count
end


-- Runtime: lexing
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

--Provides: caml_lex_array
function caml_lex_array(s)
  local len = #s / 2
  local result = {}

  for i = 0, len - 1 do
    local lo = s[2 * i + 1]
    local hi = s[2 * i + 2]
    -- Lua 5.1 compatible: lo | (hi << 8)
    local val = lo + hi * 256
    if val >= 0x8000 then
      val = val - 0x10000
    end
    result[i + 1] = val
  end

  return result
end

--Provides: caml_lex_engine
--Requires: caml_lex_array
function caml_lex_engine(tbl, start_state, lexbuf)
  -- Inline TBL_BASE=1, TBL_BACKTRK=2, TBL_CHECK=5, TBL_TRANS=4, TBL_DEFAULT=3
  if not tbl.lex_default then
    tbl.lex_base = caml_lex_array(tbl[1])     -- TBL_BASE
    tbl.lex_backtrk = caml_lex_array(tbl[2])  -- TBL_BACKTRK
    tbl.lex_check = caml_lex_array(tbl[5])    -- TBL_CHECK
    tbl.lex_trans = caml_lex_array(tbl[4])    -- TBL_TRANS
    tbl.lex_default = caml_lex_array(tbl[3])  -- TBL_DEFAULT
  end

  local state = start_state
  local buffer = lexbuf[2]  -- LEX_BUFFER

  -- Inline LEX_LAST_POS=7, LEX_CURR_POS=6, LEX_START_POS=5, LEX_LAST_ACTION=8
  if state >= 0 then
    lexbuf[7] = lexbuf[6]  -- LEX_LAST_POS = LEX_CURR_POS
    lexbuf[5] = lexbuf[6]  -- LEX_START_POS = LEX_CURR_POS
    lexbuf[8] = -1         -- LEX_LAST_ACTION
  else
    state = -state - 1
  end

  while true do
    local base = tbl.lex_base[state + 1]
    if base < 0 then
      return -base - 1
    end

    local backtrk = tbl.lex_backtrk[state + 1]
    if backtrk >= 0 then
      lexbuf[7] = lexbuf[6]  -- LEX_LAST_POS = LEX_CURR_POS
      lexbuf[8] = backtrk    -- LEX_LAST_ACTION
    end

    -- Inline LEX_CURR_POS=6, LEX_BUFFER_LEN=3, LEX_EOF_REACHED=9
    local c
    if lexbuf[6] >= lexbuf[3] then  -- LEX_CURR_POS >= LEX_BUFFER_LEN
      if lexbuf[9] == 0 then        -- LEX_EOF_REACHED
        return -state - 1
      else
        c = 256  -- EOF pseudo-character
      end
    else
      c = buffer[lexbuf[6] + 1]  -- LEX_CURR_POS
      lexbuf[6] = lexbuf[6] + 1  -- LEX_CURR_POS
    end

    if tbl.lex_check[base + c + 1] == state then
      state = tbl.lex_trans[base + c + 1]
    else
      state = tbl.lex_default[state + 1]
    end

    if state < 0 then
      lexbuf[6] = lexbuf[7]  -- LEX_CURR_POS = LEX_LAST_POS
      if lexbuf[8] == -1 then  -- LEX_LAST_ACTION
        error("lexing: empty token")
      else
        return lexbuf[8]  -- LEX_LAST_ACTION
      end
    else
      if c == 256 then
        lexbuf[9] = 0  -- LEX_EOF_REACHED
      end
    end
  end
end

--Provides: caml_create_lexbuf_from_string
function caml_create_lexbuf_from_string(s)
  local buffer
  if type(s) == "string" then
    buffer = {string.byte(s, 1, -1)}
  else
    buffer = s
  end

  -- Inline: LEX_REFILL_BUF=1, LEX_BUFFER=2, LEX_BUFFER_LEN=3, LEX_ABS_POS=4,
  --         LEX_START_POS=5, LEX_CURR_POS=6, LEX_LAST_POS=7, LEX_LAST_ACTION=8,
  --         LEX_EOF_REACHED=9, LEX_MEM=10, LEX_START_P=11, LEX_CURR_P=12
  local lexbuf = {
    [1] = nil,           -- LEX_REFILL_BUF (not used for string)
    [2] = buffer,        -- LEX_BUFFER (input byte array)
    [3] = #buffer,       -- LEX_BUFFER_LEN
    [4] = 0,             -- LEX_ABS_POS
    [5] = 0,             -- LEX_START_POS
    [6] = 0,             -- LEX_CURR_POS
    [7] = 0,             -- LEX_LAST_POS
    [8] = -1,            -- LEX_LAST_ACTION
    [9] = 0,             -- LEX_EOF_REACHED
    [10] = {},           -- LEX_MEM
    [11] = {             -- LEX_START_P
      pos_fname = "",
      pos_lnum = 1,
      pos_bol = 0,
      pos_cnum = 0,
    },
    [12] = {             -- LEX_CURR_P
      pos_fname = "",
      pos_lnum = 1,
      pos_bol = 0,
      pos_cnum = 0,
    },
  }

  return lexbuf
end

--Provides: caml_lexbuf_refill_from_channel
--Requires: caml_ml_input
function caml_lexbuf_refill_from_channel(channel_id, lexbuf)
  local buf_size = 1024
  local buffer = {}
  local n = caml_ml_input(channel_id, buffer, 0, buf_size)

  if n == 0 then
    lexbuf[9] = 1  -- LEX_EOF_REACHED
    return 0
  end

  lexbuf[2] = buffer  -- LEX_BUFFER
  lexbuf[3] = n       -- LEX_BUFFER_LEN
  lexbuf[6] = 0       -- LEX_CURR_POS

  return n
end

--Provides: caml_create_lexbuf_from_channel
--Requires: caml_lexbuf_refill_from_channel
function caml_create_lexbuf_from_channel(channel_id)
  -- Inline: LEX_REFILL_BUF=1, LEX_BUFFER=2, LEX_BUFFER_LEN=3, LEX_ABS_POS=4,
  --         LEX_START_POS=5, LEX_CURR_POS=6, LEX_LAST_POS=7, LEX_LAST_ACTION=8,
  --         LEX_EOF_REACHED=9, LEX_MEM=10, LEX_START_P=11, LEX_CURR_P=12
  local lexbuf = {
    [1] = channel_id,    -- LEX_REFILL_BUF (store channel_id for refill)
    [2] = {},            -- LEX_BUFFER
    [3] = 0,             -- LEX_BUFFER_LEN
    [4] = 0,             -- LEX_ABS_POS
    [5] = 0,             -- LEX_START_POS
    [6] = 0,             -- LEX_CURR_POS
    [7] = 0,             -- LEX_LAST_POS
    [8] = -1,            -- LEX_LAST_ACTION
    [9] = 0,             -- LEX_EOF_REACHED
    [10] = {},           -- LEX_MEM
    [11] = {             -- LEX_START_P
      pos_fname = "",
      pos_lnum = 1,
      pos_bol = 0,
      pos_cnum = 0,
    },
    [12] = {             -- LEX_CURR_P
      pos_fname = "",
      pos_lnum = 1,
      pos_bol = 0,
      pos_cnum = 0,
    },
  }

  caml_lexbuf_refill_from_channel(channel_id, lexbuf)

  return lexbuf
end

--Provides: caml_lexeme
function caml_lexeme(lexbuf)
  local start_pos = lexbuf[5]  -- LEX_START_POS
  local curr_pos = lexbuf[6]   -- LEX_CURR_POS
  local buffer = lexbuf[2]     -- LEX_BUFFER
  local result = {}

  for i = start_pos + 1, curr_pos do
    result[#result + 1] = buffer[i]
  end

  return result
end

--Provides: caml_lexeme_string
--Requires: caml_lexeme
function caml_lexeme_string(lexbuf)
  local bytes = caml_lexeme(lexbuf)
  local chars = {}
  for i = 1, #bytes do
    chars[i] = string.char(bytes[i])
  end
  return table.concat(chars)
end

--Provides: caml_lexeme_start
function caml_lexeme_start(lexbuf)
  return lexbuf[5] + lexbuf[4]  -- LEX_START_POS + LEX_ABS_POS
end

--Provides: caml_lexeme_end
function caml_lexeme_end(lexbuf)
  return lexbuf[6] + lexbuf[4]  -- LEX_CURR_POS + LEX_ABS_POS
end

--Provides: caml_lexeme_start_p
function caml_lexeme_start_p(lexbuf)
  return lexbuf[11]  -- LEX_START_P
end

--Provides: caml_lexeme_end_p
function caml_lexeme_end_p(lexbuf)
  return lexbuf[12]  -- LEX_CURR_P
end

--Provides: caml_new_line
function caml_new_line(lexbuf)
  local curr_p = lexbuf[12]  -- LEX_CURR_P
  curr_p.pos_lnum = curr_p.pos_lnum + 1
  curr_p.pos_bol = lexbuf[6] + lexbuf[4]  -- LEX_CURR_POS + LEX_ABS_POS
  curr_p.pos_cnum = curr_p.pos_bol
end

--Provides: caml_lexeme_char
function caml_lexeme_char(lexbuf, n)
  local pos = lexbuf[5] + n  -- LEX_START_POS
  if pos < lexbuf[6] then    -- LEX_CURR_POS
    return lexbuf[2][pos + 1]  -- LEX_BUFFER
  else
    error("lexeme_char: index out of bounds")
  end
end

--Provides: caml_flush_lexbuf
function caml_flush_lexbuf(lexbuf)
  lexbuf[4] = lexbuf[4] + lexbuf[6]  -- LEX_ABS_POS = LEX_ABS_POS + LEX_CURR_POS
  lexbuf[6] = 0   -- LEX_CURR_POS
  lexbuf[5] = 0   -- LEX_START_POS
  lexbuf[7] = 0   -- LEX_LAST_POS
  lexbuf[2] = {}  -- LEX_BUFFER
  lexbuf[3] = 0   -- LEX_BUFFER_LEN
end


-- Runtime: parsing
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


-- Global parser trace flag (accessible via caml_set_parser_trace)
caml_parser_trace_flag = false

--Provides: caml_parse_engine
--Requires: caml_lex_array
function caml_parse_engine(tables, env, cmd, arg)
  -- Inline TBL_* constants: DEFRED=6, SINDEX=8, CHECK=13, RINDEX=9, TABLE=12, LEN=5, LHS=4, GINDEX=10, DGOTO=7
  if not tables.dgoto then
    tables.defred = caml_lex_array(tables[6])   -- TBL_DEFRED
    tables.sindex = caml_lex_array(tables[8])   -- TBL_SINDEX
    tables.check = caml_lex_array(tables[13])   -- TBL_CHECK
    tables.rindex = caml_lex_array(tables[9])   -- TBL_RINDEX
    tables.table = caml_lex_array(tables[12])   -- TBL_TABLE
    tables.len = caml_lex_array(tables[5])      -- TBL_LEN
    tables.lhs = caml_lex_array(tables[4])      -- TBL_LHS
    tables.gindex = caml_lex_array(tables[10])  -- TBL_GINDEX
    tables.dgoto = caml_lex_array(tables[7])    -- TBL_DGOTO
  end

  local res = 0
  local n, n1, n2, state1

  -- Inline ENV_* constants: SP=14, STATE=15, ERRFLAG=16
  local sp = env[14]      -- ENV_SP
  local state = env[15]   -- ENV_STATE
  local errflag = env[16] -- ENV_ERRFLAG

  local continue = true
  while continue do
    continue = false  -- Will be set to true to continue loop

    if cmd == 0 then  -- START
      state = 0
      errflag = 0
      cmd = 6  -- LOOP
      continue = true
    elseif cmd == 6 then  -- LOOP
      n = tables.defred[state + 1]
      if n ~= 0 then
        cmd = 10  -- REDUCE
        continue = true
      elseif env[7] >= 0 then  -- ENV_CURR_CHAR
        cmd = 7  -- TESTSHIFT
        continue = true
      else
        res = 0  -- READ_TOKEN
        break
      end
    elseif cmd == 1 then  -- TOKEN_READ
      -- Inline TBL_TRANSL_BLOCK=3, TBL_TRANSL_CONST=2, ENV_CURR_CHAR=7, ENV_LVAL=8
      if type(arg) == "table" and arg.tag ~= nil then
        env[7] = tables[3][arg.tag + 2]  -- ENV_CURR_CHAR = TBL_TRANSL_BLOCK
        env[8] = arg[1]                  -- ENV_LVAL
      else
        env[7] = tables[2][arg + 2]  -- ENV_CURR_CHAR = TBL_TRANSL_CONST
        env[8] = 0                   -- ENV_LVAL
      end
      cmd = 7  -- TESTSHIFT
      continue = true
    elseif cmd == 7 then  -- TESTSHIFT
      n1 = tables.sindex[state + 1]
      n2 = n1 + env[7]  -- ENV_CURR_CHAR
      if n1 ~= 0 and n2 >= 0 and n2 <= tables[11] and  -- TBL_TABLESIZE
         tables.check[n2 + 1] == env[7] then  -- ENV_CURR_CHAR
        cmd = 8  -- SHIFT
        continue = true
      else
        n1 = tables.rindex[state + 1]
        n2 = n1 + env[7]  -- ENV_CURR_CHAR
        if n1 ~= 0 and n2 >= 0 and n2 <= tables[11] and  -- TBL_TABLESIZE
           tables.check[n2 + 1] == env[7] then  -- ENV_CURR_CHAR
          n = tables.table[n2 + 1]
          cmd = 10  -- REDUCE
          continue = true
        elseif errflag <= 0 then
          res = 5  -- CALL_ERROR_FUNCTION
          break
        else
          cmd = 5  -- ERROR_DETECTED
          continue = true
        end
      end
    elseif cmd == 5 then  -- ERROR_DETECTED
      if errflag < 3 then
        errflag = 3
        local error_loop = true
        while error_loop do
          state1 = env[1][sp + 1]  -- ENV_S_STACK
          n1 = tables.sindex[state1 + 1]
          n2 = n1 + 256  -- ERRCODE
          if n1 ~= 0 and n2 >= 0 and n2 <= tables[11] and  -- TBL_TABLESIZE
             tables.check[n2 + 1] == 256 then  -- ERRCODE
            cmd = 9  -- SHIFT_RECOVER
            error_loop = false
            continue = true
          else
            if sp <= env[6] then  -- ENV_STACKBASE
              env[14] = sp      -- ENV_SP
              env[15] = state   -- ENV_STATE
              env[16] = errflag -- ENV_ERRFLAG
              return 1  -- RAISE_PARSE_ERROR
            end
            sp = sp - 1
          end
        end
      else
        if env[7] == 0 then  -- ENV_CURR_CHAR
          env[14] = sp      -- ENV_SP
          env[15] = state   -- ENV_STATE
          env[16] = errflag -- ENV_ERRFLAG
          return 1  -- RAISE_PARSE_ERROR
        end
        env[7] = -1  -- ENV_CURR_CHAR
        cmd = 6  -- LOOP
        continue = true
      end
    elseif cmd == 8 then  -- SHIFT
      env[7] = -1  -- ENV_CURR_CHAR
      if errflag > 0 then
        errflag = errflag - 1
      end
      cmd = 9  -- SHIFT_RECOVER
      continue = true
    elseif cmd == 9 then  -- SHIFT_RECOVER
      state = tables.table[n2 + 1]
      sp = sp + 1
      if sp >= env[5] then  -- ENV_STACKSIZE
        res = 2  -- GROW_STACKS_1
        break
      end
      cmd = 2  -- STACKS_GROWN_1
      continue = true
    elseif cmd == 2 then  -- STACKS_GROWN_1
      -- Inline ENV_S_STACK=1, ENV_V_STACK=2, ENV_SYMB_START_STACK=3, ENV_SYMB_END_STACK=4, ENV_LVAL=8, ENV_SYMB_START=9, ENV_SYMB_END=10
      env[1][sp + 1] = state   -- ENV_S_STACK
      env[2][sp + 1] = env[8]  -- ENV_V_STACK = ENV_LVAL
      env[3][sp + 1] = env[9]  -- ENV_SYMB_START_STACK = ENV_SYMB_START
      env[4][sp + 1] = env[10] -- ENV_SYMB_END_STACK = ENV_SYMB_END
      cmd = 6  -- LOOP
      continue = true
    elseif cmd == 10 then  -- REDUCE
      local m = tables.len[n + 1]
      env[11] = sp  -- ENV_ASP
      env[13] = n   -- ENV_RULE_NUMBER
      env[12] = m   -- ENV_RULE_LEN
      sp = sp - m + 1
      m = tables.lhs[n + 1]
      state1 = env[1][sp + 1]  -- ENV_S_STACK
      n1 = tables.gindex[m + 1]
      n2 = n1 + state1
      if n1 ~= 0 and n2 >= 0 and n2 <= tables[11] and  -- TBL_TABLESIZE
         tables.check[n2 + 1] == state1 then
        state = tables.table[n2 + 1]
      else
        state = tables.dgoto[m + 1]
      end
      if sp >= env[5] then  -- ENV_STACKSIZE
        res = 3  -- GROW_STACKS_2
        break
      end
      cmd = 3  -- STACKS_GROWN_2
      continue = true
    elseif cmd == 3 then  -- STACKS_GROWN_2
      res = 4  -- COMPUTE_SEMANTIC_ACTION
      break
    elseif cmd == 4 then  -- SEMANTIC_ACTION_COMPUTED
      env[1][sp + 1] = state  -- ENV_S_STACK
      env[2][sp + 1] = arg    -- ENV_V_STACK
      local asp = env[11]     -- ENV_ASP
      env[4][sp + 1] = env[4][asp + 1]  -- ENV_SYMB_END_STACK
      if sp > asp then
        env[3][sp + 1] = env[4][asp + 1]  -- ENV_SYMB_START_STACK = ENV_SYMB_END_STACK
      end
      cmd = 6  -- LOOP
      continue = true
    else
      env[14] = sp      -- ENV_SP
      env[15] = state   -- ENV_STATE
      env[16] = errflag -- ENV_ERRFLAG
      return 1  -- RAISE_PARSE_ERROR
    end
  end

  env[14] = sp      -- ENV_SP
  env[15] = state   -- ENV_STATE
  env[16] = errflag -- ENV_ERRFLAG
  return res
end

--Provides: caml_set_parser_trace
function caml_set_parser_trace(bool)
  local oldflag = caml_parser_trace_flag
  caml_parser_trace_flag = bool
  return oldflag
end

--Provides: caml_create_parser_env
function caml_create_parser_env(stacksize)
  local size = stacksize or 100

  -- Inline ENV_* constants: S_STACK=1, V_STACK=2, SYMB_START_STACK=3, SYMB_END_STACK=4, STACKSIZE=5,
  -- STACKBASE=6, CURR_CHAR=7, LVAL=8, SYMB_START=9, SYMB_END=10, ASP=11, RULE_LEN=12, RULE_NUMBER=13,
  -- SP=14, STATE=15, ERRFLAG=16
  local env = {
    [1] = {},   -- ENV_S_STACK
    [2] = {},   -- ENV_V_STACK
    [3] = {},   -- ENV_SYMB_START_STACK
    [4] = {},   -- ENV_SYMB_END_STACK
    [5] = size, -- ENV_STACKSIZE
    [6] = 0,    -- ENV_STACKBASE
    [7] = -1,   -- ENV_CURR_CHAR
    [8] = 0,    -- ENV_LVAL
    [9] = 0,    -- ENV_SYMB_START
    [10] = 0,   -- ENV_SYMB_END
    [11] = 0,   -- ENV_ASP
    [12] = 0,   -- ENV_RULE_LEN
    [13] = 0,   -- ENV_RULE_NUMBER
    [14] = 0,   -- ENV_SP
    [15] = 0,   -- ENV_STATE
    [16] = 0,   -- ENV_ERRFLAG
  }

  return env
end

--Provides: caml_grow_parser_stacks
function caml_grow_parser_stacks(env, new_size)
  env[5] = new_size  -- ENV_STACKSIZE
end

--Provides: caml_parser_rule_info
function caml_parser_rule_info(env)
  return env[13], env[12]  -- ENV_RULE_NUMBER, ENV_RULE_LEN
end

--Provides: caml_parser_stack_value
function caml_parser_stack_value(env, offset)
  local asp = env[11]  -- ENV_ASP
  return env[2][asp + offset + 1]  -- ENV_V_STACK
end

--Provides: caml_parser_symb_start
function caml_parser_symb_start(env, offset)
  local asp = env[11]  -- ENV_ASP
  return env[3][asp + offset + 1]  -- ENV_SYMB_START_STACK
end

--Provides: caml_parser_symb_end
function caml_parser_symb_end(env, offset)
  local asp = env[11]  -- ENV_ASP
  return env[4][asp + offset + 1]  -- ENV_SYMB_END_STACK
end


-- Runtime: effect
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

-- Effect handlers (OCaml 5.x) using Lua coroutines
--
-- Maps OCaml effect handlers to Lua coroutines with fiber stacks.
-- This provides delimited continuations and algebraic effects.
--
-- Design:
-- - Fibers are represented as Lua coroutines
-- - Fiber stack tracks parent-child relationships
-- - Continuations are reified as fiber references
-- - Effect handlers are triples: {retc, exnc, effc}
--
-- Execution model:
-- - Current fiber executes with a low-level continuation
-- - When effect is performed, fiber yields to parent with effect value
-- - Parent's effect handler processes the effect
-- - Continuation can be resumed to return to child fiber

--
-- Fiber Stack Structure
--
-- Each fiber has:
-- - k: low-level continuation (Lua function)
-- - x: exception handler stack
-- - h: handler triple {retc, exnc, effc}
-- - e: parent fiber (enclosing stack)
-- - co: Lua coroutine (optional, for fiber)
--

--Provides: caml_current_stack
caml_current_stack = {
  k = 0,      -- low-level continuation
  x = 0,      -- exception stack
  h = 0,      -- handlers {retc, exnc, effc}
  e = 0       -- enclosing (parent) fiber
}

--
-- Stack Management
--

--Provides: save_stack
--Requires: caml_current_stack
function save_stack()
  return {
    k = caml_current_stack.k,
    x = caml_current_stack.x,
    h = caml_current_stack.h,
    e = caml_current_stack.e
  }
end

--Provides: restore_stack
--Requires: caml_current_stack
function restore_stack(stack)
  caml_current_stack.k = stack.k
  caml_current_stack.x = stack.x
  caml_current_stack.h = stack.h
  caml_current_stack.e = stack.e
end

--Provides: get_current_stack
--Requires: caml_current_stack
function get_current_stack()
  return caml_current_stack
end

--
-- Exception Handlers
--

--Provides: caml_push_trap
--Requires: caml_current_stack
function caml_push_trap(handler)
  caml_current_stack.x = {h = handler, t = caml_current_stack.x}
end

--Provides: caml_pop_trap
--Requires: caml_current_stack
function caml_pop_trap()
  if not caml_current_stack.x or caml_current_stack.x == 0 then
    return function(x)
      error(x)
    end
  end
  local h = caml_current_stack.x.h
  caml_current_stack.x = caml_current_stack.x.t
  return h
end

--
-- Fiber Management
--

--Provides: caml_pop_fiber
--Requires: caml_current_stack
function caml_pop_fiber()
  local parent = caml_current_stack.e
  caml_current_stack.e = 0
  caml_current_stack = parent
  return parent.k
end

--Provides: caml_alloc_stack
--Requires: caml_alloc_stack_call, caml_current_stack
-- Allocate new fiber with handlers
-- hv: value handler (continuation for normal return)
-- hx: exception handler
-- hf: effect handler
function caml_alloc_stack(hv, hx, hf)
  local handlers = {hv, hx, hf}

  -- Handler wrappers that call handlers in parent fiber
  local function hval_wrapper(x)
    -- Call hv in parent fiber
    local f = caml_current_stack.h[1]
    return caml_alloc_stack_call(f, x)
  end

  local function hexn_wrapper(e)
    -- Call hx in parent fiber
    local f = caml_current_stack.h[2]
    return caml_alloc_stack_call(f, e)
  end

  return {
    k = hval_wrapper,
    x = {h = hexn_wrapper, t = 0},
    h = handlers,
    e = 0
  }
end

--Provides: caml_alloc_stack_call
--Requires: caml_pop_fiber
-- Call function in parent fiber context
function caml_alloc_stack_call(f, x)
  local args = {x, caml_pop_fiber()}
  return f(table.unpack(args))
end

--Provides: caml_alloc_stack_disabled
-- Stub for when effects are disabled
function caml_alloc_stack_disabled()
  return 0
end

--
-- Continuation Management
--

--Provides: caml_continuation_tag
caml_continuation_tag = 245

--Provides: make_continuation
--Requires: caml_continuation_tag
function make_continuation(stack, last)
  return {tag = caml_continuation_tag, stack, last}
end

--Provides: caml_continuation_use_noexc
-- Use continuation (one-shot: clears the continuation)
function caml_continuation_use_noexc(cont)
  local stack = cont[1]
  cont[1] = 0  -- Mark as used
  return stack
end

--Provides: caml_continuation_use_and_update_handler_noexc
--Requires: caml_continuation_use_noexc
-- Use continuation and update its handlers
function caml_continuation_use_and_update_handler_noexc(cont, hval, hexn, heff)
  local stack = caml_continuation_use_noexc(cont)
  if stack == 0 then
    return stack
  end
  local last = cont[2]
  last.h[1] = hval
  last.h[2] = hexn
  last.h[3] = heff
  return stack
end

--
-- Effect Operations
--

-- Exception for unhandled effects
local function make_unhandled_effect_exn(eff)
  -- Try to find registered Unhandled exception
  -- Fallback to generic exception
  return {
    tag = 248,
    "Effect.Unhandled",
    eff
  }
end

--Provides: caml_raise_unhandled
-- Raise unhandled effect exception
function caml_raise_unhandled(eff)
  error(make_unhandled_effect_exn(eff))
end

--Provides: caml_perform_effect
--Requires: make_continuation, caml_pop_fiber, caml_current_stack
-- Perform an effect
-- eff: the effect value
-- k0: current continuation
function caml_perform_effect(eff, k0)
  if caml_current_stack.e == 0 then
    -- No effect handler installed
    error(make_unhandled_effect_exn(eff))
  end

  -- Get current effect handler
  local handler = caml_current_stack.h[3]
  local last_fiber = caml_current_stack
  last_fiber.k = k0

  -- Create continuation
  local cont = make_continuation(last_fiber, last_fiber)

  -- Move to parent fiber and execute effect handler
  local k1 = caml_pop_fiber()

  -- Call effect handler with effect, continuation, and parent continuation
  return handler(eff, cont, last_fiber, k1)
end

--Provides: caml_reperform_effect
--Requires: caml_pop_fiber, caml_continuation_use_noexc, caml_resume_stack, caml_current_stack
-- Re-perform an effect (for effect forwarding)
function caml_reperform_effect(eff, cont, last, k0)
  if caml_current_stack.e == 0 then
    -- No effect handler installed
    local stack = caml_continuation_use_noexc(cont)
    caml_resume_stack(stack, last, k0)
    error(make_unhandled_effect_exn(eff))
  end

  -- Get current effect handler
  local handler = caml_current_stack.h[3]
  local last_fiber = caml_current_stack
  last_fiber.k = k0
  last.e = last_fiber
  cont[2] = last_fiber

  -- Move to parent fiber and execute effect handler
  local k1 = caml_pop_fiber()

  return handler(eff, cont, last_fiber, k1)
end

--
-- Continuation Resume
--

--Provides: caml_resume_stack
--Requires: caml_current_stack
function caml_resume_stack(stack, last, k)
  if not stack or stack == 0 then
    error("Effect.Continuation_already_resumed")
  end

  if last == 0 then
    last = stack
    -- Find deepest fiber
    while last.e ~= 0 do
      last = last.e
    end
  end

  caml_current_stack.k = k
  last.e = caml_current_stack
  caml_current_stack = stack
  return stack.k
end

--Provides: caml_resume
--Requires: save_stack, restore_stack, caml_resume_stack, caml_current_stack
-- High-level resume function
function caml_resume(f, arg, stack, last)
  local saved_caml_current_stack = save_stack()

  local success, result = pcall(function()
    caml_current_stack = {k = 0, x = 0, h = 0, e = 0}

    local k = caml_resume_stack(stack, last, function(x)
      return x
    end)

    -- Call function with argument and continuation
    return f(arg, k)
  end)

  restore_stack(saved_caml_current_stack)

  if not success then
    error(result)
  end

  return result
end

--
-- Coroutine Integration
--

-- Wrap function in coroutine for effect handling
-- Helper function for testing
function with_coroutine(f)
  return coroutine.create(function(...)
    return f(...)
  end)
end

-- Yield current fiber (for cooperative multitasking)
-- Helper function for testing
function fiber_yield(value)
  if caml_current_stack.e == 0 then
    -- No parent fiber, can't yield
    return value
  end

  -- Save state and yield to parent
  return coroutine.yield(value)
end

-- Resume a fiber coroutine
-- Helper function for testing
function fiber_resume(co, value)
  if coroutine.status(co) == "dead" then
    error("Cannot resume dead fiber")
  end

  local success, result = coroutine.resume(co, value)
  if not success then
    error(result)
  end

  return result
end

--
-- Effect Handler Utilities
--

-- Check if effects are supported
-- Helper function for testing
function effects_supported()
  return true  -- Lua coroutines provide necessary support
end

--Provides: caml_get_continuation_callstack
-- Get continuation callstack (for debugging)
function caml_get_continuation_callstack()
  -- Lua doesn't provide detailed callstack for continuations
  -- Return empty list
  return {tag = 0}  -- Empty OCaml list
end

--
-- Condition Variables (for Stdlib.Condition)
--

--Provides: caml_ml_condition_new
function caml_ml_condition_new()
  return {condition = 1}
end

--Provides: caml_ml_condition_wait
function caml_ml_condition_wait()
  return 0
end

--Provides: caml_ml_condition_broadcast
function caml_ml_condition_broadcast()
  return 0
end

--Provides: caml_ml_condition_signal
function caml_ml_condition_signal()
  return 0
end

--
-- Error Handling
--

--Provides: jsoo_effect_not_supported
-- Raise "not supported" error
function jsoo_effect_not_supported()
  error("Effect handlers are not supported")
end


-- Runtime: domain
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

-- OCaml 5.0+ Domain and Atomic Operations
--
-- Lua is single-threaded, so atomic operations don't need actual atomic semantics.
-- These are simple implementations that provide the correct interface.

--Provides: caml_domain_dls
caml_domain_dls = {0}

--Provides: caml_domain_dls_set
--Requires: caml_domain_dls
function caml_domain_dls_set(a)
  caml_domain_dls = a
end

--Provides: caml_domain_dls_compare_and_set
--Requires: caml_domain_dls
function caml_domain_dls_compare_and_set(old, n)
  if caml_domain_dls ~= old then
    return 0
  end
  caml_domain_dls = n
  return 1
end

--Provides: caml_domain_dls_get
--Requires: caml_domain_dls
function caml_domain_dls_get(_unit)
  return caml_domain_dls
end

--Provides: caml_atomic_load
function caml_atomic_load(ref)
  return ref[1]
end

--Provides: caml_atomic_load_field
function caml_atomic_load_field(b, i)
  return b[i + 1]
end

--Provides: caml_atomic_cas
function caml_atomic_cas(ref, o, n)
  if ref[1] == o then
    ref[1] = n
    return 1
  end
  return 0
end

--Provides: caml_atomic_cas_field
function caml_atomic_cas_field(b, i, o, n)
  if b[i + 1] == o then
    b[i + 1] = n
    return 1
  end
  return 0
end

--Provides: caml_atomic_fetch_add
function caml_atomic_fetch_add(ref, i)
  local old = ref[1]
  ref[1] = ref[1] + i
  return old
end

--Provides: caml_atomic_fetch_add_field
function caml_atomic_fetch_add_field(b, i, n)
  local old = b[i + 1]
  b[i + 1] = b[i + 1] + n
  return old
end

--Provides: caml_atomic_exchange
function caml_atomic_exchange(ref, v)
  local r = ref[1]
  ref[1] = v
  return r
end

--Provides: caml_atomic_exchange_field
function caml_atomic_exchange_field(b, i, v)
  local r = b[i + 1]
  b[i + 1] = v
  return r
end

--Provides: caml_atomic_make_contended
function caml_atomic_make_contended(a)
  return {0, a}
end

--Provides: caml_ml_domain_unique_token
caml_ml_domain_unique_token = {0}

--Provides: caml_ml_domain_id
function caml_ml_domain_id(_unit)
  return 0
end

--Provides: caml_ml_domain_spawn
function caml_ml_domain_spawn(_f, _term)
  error("Domains not supported in Lua (single-threaded)")
end

--Provides: caml_ml_domain_join
function caml_ml_domain_join(_domain)
  error("Domains not supported in Lua (single-threaded)")
end

--Provides: caml_ml_domain_cpu_relax
function caml_ml_domain_cpu_relax()
  -- No-op in single-threaded environment
end

--Provides: caml_ml_domain_set_name
function caml_ml_domain_set_name(_name)
  -- No-op in single-threaded environment
end

--Provides: caml_ml_domain_recommended_domain_count
function caml_ml_domain_recommended_domain_count(_unit)
  return 1
end


-- Runtime: digest
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

-- Digest: MD5 cryptographic hashing primitives

-- Bitwise operations (Lua 5.1 compatible)

--Provides: caml_digest_bit_and
function caml_digest_bit_and(a, b)
  -- 32-bit AND using arithmetic (Lua 5.1 compatible)
  local result = 0
  local bit_val = 1
  for i = 1, 32 do
    if (a % 2 == 1) and (b % 2 == 1) then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--Provides: caml_digest_bit_or
function caml_digest_bit_or(a, b)
  -- 32-bit OR using arithmetic (Lua 5.1 compatible)
  local result = 0
  local bit_val = 1
  for i = 1, 32 do
    if (a % 2 == 1) or (b % 2 == 1) then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--Provides: caml_digest_bit_xor
function caml_digest_bit_xor(a, b)
  -- 32-bit XOR using arithmetic (Lua 5.1 compatible)
  local result = 0
  local bit_val = 1
  for i = 1, 32 do
    local a_bit = a % 2
    local b_bit = b % 2
    if a_bit ~= b_bit then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result
end

--Provides: caml_digest_bit_not
function caml_digest_bit_not(a)
  -- 32-bit NOT using arithmetic (Lua 5.1 compatible)
  -- NOT is: 0xFFFFFFFF - a
  local max_u32 = 4294967295
  return max_u32 - a
end

--Provides: caml_digest_bit_lshift
function caml_digest_bit_lshift(a, n)
  -- 32-bit left shift with masking (Lua 5.1 compatible)
  local result = a
  for i = 1, n do
    result = result * 2
  end
  -- Mask to 32 bits
  return result % 4294967296
end

--Provides: caml_digest_bit_rshift
function caml_digest_bit_rshift(a, n)
  -- 32-bit right shift (Lua 5.1 compatible)
  local result = a
  for i = 1, n do
    result = math.floor(result / 2)
  end
  return result
end

--Provides: caml_digest_add32
function caml_digest_add32(a, b)
  -- 32-bit addition with overflow (Lua 5.1 compatible)
  local result = a + b
  return result % 4294967296
end

--Provides: caml_digest_rotl32
--Requires: caml_digest_bit_or, caml_digest_bit_lshift, caml_digest_bit_rshift
function caml_digest_rotl32(x, n)
  -- 32-bit left rotate (Lua 5.1 compatible)
  local left = caml_digest_bit_lshift(x, n)
  local right = caml_digest_bit_rshift(x, 32 - n)
  return caml_digest_bit_or(left, right)
end

-- MD5 auxiliary functions

--Provides: caml_digest_md5_F
--Requires: caml_digest_bit_and, caml_digest_bit_or, caml_digest_bit_not
function caml_digest_md5_F(x, y, z)
  -- F(x, y, z) = (x & y) | (~x & z)
  return caml_digest_bit_or(
    caml_digest_bit_and(x, y),
    caml_digest_bit_and(caml_digest_bit_not(x), z)
  )
end

--Provides: caml_digest_md5_G
--Requires: caml_digest_bit_and, caml_digest_bit_or, caml_digest_bit_not
function caml_digest_md5_G(x, y, z)
  -- G(x, y, z) = (x & z) | (y & ~z)
  return caml_digest_bit_or(
    caml_digest_bit_and(x, z),
    caml_digest_bit_and(y, caml_digest_bit_not(z))
  )
end

--Provides: caml_digest_md5_H
--Requires: caml_digest_bit_xor
function caml_digest_md5_H(x, y, z)
  -- H(x, y, z) = x ^ y ^ z
  return caml_digest_bit_xor(x, caml_digest_bit_xor(y, z))
end

--Provides: caml_digest_md5_I
--Requires: caml_digest_bit_xor, caml_digest_bit_or, caml_digest_bit_not
function caml_digest_md5_I(x, y, z)
  -- I(x, y, z) = y ^ (x | ~z)
  return caml_digest_bit_xor(y, caml_digest_bit_or(x, caml_digest_bit_not(z)))
end

--Provides: caml_digest_md5_step
--Requires: caml_digest_add32, caml_digest_rotl32
function caml_digest_md5_step(func, a, b, c, d, x, s, ac)
  -- MD5 step: a = b + rotl32(a + func(b, c, d) + x + ac, s)
  a = caml_digest_add32(a, caml_digest_add32(caml_digest_add32(func(b, c, d), x), ac))
  a = caml_digest_add32(caml_digest_rotl32(a, s), b)
  return a
end

--Provides: caml_digest_md5_transform
--Requires: caml_digest_md5_step, caml_digest_md5_F, caml_digest_md5_G, caml_digest_md5_H, caml_digest_md5_I, caml_digest_bit_or, caml_digest_bit_lshift, caml_digest_add32
function caml_digest_md5_transform(state, block)
  -- Transform MD5 state with one 64-byte block
  local a = state[1]
  local b = state[2]
  local c = state[3]
  local d = state[4]

  -- Decode block into 16 32-bit words (little-endian)
  local x = {}
  for i = 0, 15 do
    local offset = i * 4 + 1
    x[i + 1] = caml_digest_bit_or(
      caml_digest_bit_or(block[offset], caml_digest_bit_lshift(block[offset + 1], 8)),
      caml_digest_bit_or(caml_digest_bit_lshift(block[offset + 2], 16), caml_digest_bit_lshift(block[offset + 3], 24))
    )
  end

  -- Round 1 (constants: S11=7, S12=12, S13=17, S14=22)
  a = caml_digest_md5_step(caml_digest_md5_F, a, b, c, d, x[1], 7, 0xD76AA478)
  d = caml_digest_md5_step(caml_digest_md5_F, d, a, b, c, x[2], 12, 0xE8C7B756)
  c = caml_digest_md5_step(caml_digest_md5_F, c, d, a, b, x[3], 17, 0x242070DB)
  b = caml_digest_md5_step(caml_digest_md5_F, b, c, d, a, x[4], 22, 0xC1BDCEEE)
  a = caml_digest_md5_step(caml_digest_md5_F, a, b, c, d, x[5], 7, 0xF57C0FAF)
  d = caml_digest_md5_step(caml_digest_md5_F, d, a, b, c, x[6], 12, 0x4787C62A)
  c = caml_digest_md5_step(caml_digest_md5_F, c, d, a, b, x[7], 17, 0xA8304613)
  b = caml_digest_md5_step(caml_digest_md5_F, b, c, d, a, x[8], 22, 0xFD469501)
  a = caml_digest_md5_step(caml_digest_md5_F, a, b, c, d, x[9], 7, 0x698098D8)
  d = caml_digest_md5_step(caml_digest_md5_F, d, a, b, c, x[10], 12, 0x8B44F7AF)
  c = caml_digest_md5_step(caml_digest_md5_F, c, d, a, b, x[11], 17, 0xFFFF5BB1)
  b = caml_digest_md5_step(caml_digest_md5_F, b, c, d, a, x[12], 22, 0x895CD7BE)
  a = caml_digest_md5_step(caml_digest_md5_F, a, b, c, d, x[13], 7, 0x6B901122)
  d = caml_digest_md5_step(caml_digest_md5_F, d, a, b, c, x[14], 12, 0xFD987193)
  c = caml_digest_md5_step(caml_digest_md5_F, c, d, a, b, x[15], 17, 0xA679438E)
  b = caml_digest_md5_step(caml_digest_md5_F, b, c, d, a, x[16], 22, 0x49B40821)

  -- Round 2 (constants: S21=5, S22=9, S23=14, S24=20)
  a = caml_digest_md5_step(caml_digest_md5_G, a, b, c, d, x[2], 5, 0xF61E2562)
  d = caml_digest_md5_step(caml_digest_md5_G, d, a, b, c, x[7], 9, 0xC040B340)
  c = caml_digest_md5_step(caml_digest_md5_G, c, d, a, b, x[12], 14, 0x265E5A51)
  b = caml_digest_md5_step(caml_digest_md5_G, b, c, d, a, x[1], 20, 0xE9B6C7AA)
  a = caml_digest_md5_step(caml_digest_md5_G, a, b, c, d, x[6], 5, 0xD62F105D)
  d = caml_digest_md5_step(caml_digest_md5_G, d, a, b, c, x[11], 9, 0x02441453)
  c = caml_digest_md5_step(caml_digest_md5_G, c, d, a, b, x[16], 14, 0xD8A1E681)
  b = caml_digest_md5_step(caml_digest_md5_G, b, c, d, a, x[5], 20, 0xE7D3FBC8)
  a = caml_digest_md5_step(caml_digest_md5_G, a, b, c, d, x[10], 5, 0x21E1CDE6)
  d = caml_digest_md5_step(caml_digest_md5_G, d, a, b, c, x[15], 9, 0xC33707D6)
  c = caml_digest_md5_step(caml_digest_md5_G, c, d, a, b, x[4], 14, 0xF4D50D87)
  b = caml_digest_md5_step(caml_digest_md5_G, b, c, d, a, x[9], 20, 0x455A14ED)
  a = caml_digest_md5_step(caml_digest_md5_G, a, b, c, d, x[14], 5, 0xA9E3E905)
  d = caml_digest_md5_step(caml_digest_md5_G, d, a, b, c, x[3], 9, 0xFCEFA3F8)
  c = caml_digest_md5_step(caml_digest_md5_G, c, d, a, b, x[8], 14, 0x676F02D9)
  b = caml_digest_md5_step(caml_digest_md5_G, b, c, d, a, x[13], 20, 0x8D2A4C8A)

  -- Round 3 (constants: S31=4, S32=11, S33=16, S34=23)
  a = caml_digest_md5_step(caml_digest_md5_H, a, b, c, d, x[6], 4, 0xFFFA3942)
  d = caml_digest_md5_step(caml_digest_md5_H, d, a, b, c, x[9], 11, 0x8771F681)
  c = caml_digest_md5_step(caml_digest_md5_H, c, d, a, b, x[12], 16, 0x6D9D6122)
  b = caml_digest_md5_step(caml_digest_md5_H, b, c, d, a, x[15], 23, 0xFDE5380C)
  a = caml_digest_md5_step(caml_digest_md5_H, a, b, c, d, x[2], 4, 0xA4BEEA44)
  d = caml_digest_md5_step(caml_digest_md5_H, d, a, b, c, x[5], 11, 0x4BDECFA9)
  c = caml_digest_md5_step(caml_digest_md5_H, c, d, a, b, x[8], 16, 0xF6BB4B60)
  b = caml_digest_md5_step(caml_digest_md5_H, b, c, d, a, x[11], 23, 0xBEBFBC70)
  a = caml_digest_md5_step(caml_digest_md5_H, a, b, c, d, x[14], 4, 0x289B7EC6)
  d = caml_digest_md5_step(caml_digest_md5_H, d, a, b, c, x[1], 11, 0xEAA127FA)
  c = caml_digest_md5_step(caml_digest_md5_H, c, d, a, b, x[4], 16, 0xD4EF3085)
  b = caml_digest_md5_step(caml_digest_md5_H, b, c, d, a, x[7], 23, 0x04881D05)
  a = caml_digest_md5_step(caml_digest_md5_H, a, b, c, d, x[10], 4, 0xD9D4D039)
  d = caml_digest_md5_step(caml_digest_md5_H, d, a, b, c, x[13], 11, 0xE6DB99E5)
  c = caml_digest_md5_step(caml_digest_md5_H, c, d, a, b, x[16], 16, 0x1FA27CF8)
  b = caml_digest_md5_step(caml_digest_md5_H, b, c, d, a, x[3], 23, 0xC4AC5665)

  -- Round 4 (constants: S41=6, S42=10, S43=15, S44=21)
  a = caml_digest_md5_step(caml_digest_md5_I, a, b, c, d, x[1], 6, 0xF4292244)
  d = caml_digest_md5_step(caml_digest_md5_I, d, a, b, c, x[8], 10, 0x432AFF97)
  c = caml_digest_md5_step(caml_digest_md5_I, c, d, a, b, x[15], 15, 0xAB9423A7)
  b = caml_digest_md5_step(caml_digest_md5_I, b, c, d, a, x[6], 21, 0xFC93A039)
  a = caml_digest_md5_step(caml_digest_md5_I, a, b, c, d, x[13], 6, 0x655B59C3)
  d = caml_digest_md5_step(caml_digest_md5_I, d, a, b, c, x[4], 10, 0x8F0CCC92)
  c = caml_digest_md5_step(caml_digest_md5_I, c, d, a, b, x[11], 15, 0xFFEFF47D)
  b = caml_digest_md5_step(caml_digest_md5_I, b, c, d, a, x[2], 21, 0x85845DD1)
  a = caml_digest_md5_step(caml_digest_md5_I, a, b, c, d, x[9], 6, 0x6FA87E4F)
  d = caml_digest_md5_step(caml_digest_md5_I, d, a, b, c, x[16], 10, 0xFE2CE6E0)
  c = caml_digest_md5_step(caml_digest_md5_I, c, d, a, b, x[7], 15, 0xA3014314)
  b = caml_digest_md5_step(caml_digest_md5_I, b, c, d, a, x[14], 21, 0x4E0811A1)
  a = caml_digest_md5_step(caml_digest_md5_I, a, b, c, d, x[5], 6, 0xF7537E82)
  d = caml_digest_md5_step(caml_digest_md5_I, d, a, b, c, x[12], 10, 0xBD3AF235)
  c = caml_digest_md5_step(caml_digest_md5_I, c, d, a, b, x[3], 15, 0x2AD7D2BB)
  b = caml_digest_md5_step(caml_digest_md5_I, b, c, d, a, x[10], 21, 0xEB86D391)

  -- Add to state
  state[1] = caml_digest_add32(state[1], a)
  state[2] = caml_digest_add32(state[2], b)
  state[3] = caml_digest_add32(state[3], c)
  state[4] = caml_digest_add32(state[4], d)
end

--Provides: caml_md5_init
function caml_md5_init()
  -- Initialize MD5 context
  -- MD5 initial state (constants: INIT_A, INIT_B, INIT_C, INIT_D)
  return {
    state = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476},
    count = 0,
    buffer = {}
  }
end

--Provides: caml_md5_update
--Requires: caml_digest_md5_transform
function caml_md5_update(ctx, data)
  -- Update MD5 context with data
  local data_len = string.len(data)
  ctx.count = ctx.count + data_len

  -- Convert string to byte array
  local bytes = {}
  for i = 1, data_len do
    bytes[i] = string.byte(data, i)
  end

  local pos = 1
  local buf_len = #ctx.buffer

  -- Fill buffer if partially filled
  if buf_len > 0 then
    local needed = 64 - buf_len
    if data_len < needed then
      -- Not enough to complete a block
      for i = 1, data_len do
        table.insert(ctx.buffer, bytes[i])
      end
      return
    end
    -- Complete the block
    for i = 1, needed do
      table.insert(ctx.buffer, bytes[i])
    end
    caml_digest_md5_transform(ctx.state, ctx.buffer)
    ctx.buffer = {}
    pos = needed + 1
  end

  -- Process complete 64-byte blocks
  while pos + 63 <= data_len do
    local block = {}
    for i = 0, 63 do
      block[i + 1] = bytes[pos + i]
    end
    caml_digest_md5_transform(ctx.state, block)
    pos = pos + 64
  end

  -- Store remaining bytes in buffer
  while pos <= data_len do
    table.insert(ctx.buffer, bytes[pos])
    pos = pos + 1
  end
end

--Provides: caml_md5_final
--Requires: caml_digest_md5_transform, caml_digest_bit_rshift
function caml_md5_final(ctx)
  -- Finalize MD5 and produce digest
  table.insert(ctx.buffer, 0x80)

  -- Pad to 56 bytes (leaving 8 for length)
  if #ctx.buffer > 56 then
    -- Need to add another block
    while #ctx.buffer < 64 do
      table.insert(ctx.buffer, 0)
    end
    caml_digest_md5_transform(ctx.state, ctx.buffer)
    ctx.buffer = {}
  end

  -- Pad to 56 bytes
  while #ctx.buffer < 56 do
    table.insert(ctx.buffer, 0)
  end

  -- Append length in bits (little-endian 64-bit)
  local bit_len = ctx.count * 8
  for i = 0, 7 do
    local byte_val = math.floor(caml_digest_bit_rshift(bit_len, i * 8)) % 256
    table.insert(ctx.buffer, byte_val)
  end

  -- Final transform
  caml_digest_md5_transform(ctx.state, ctx.buffer)

  -- Produce digest (little-endian)
  local digest = {}
  for i = 1, 4 do
    local word = ctx.state[i]
    for j = 0, 3 do
      local byte_val = math.floor(caml_digest_bit_rshift(word, j * 8)) % 256
      table.insert(digest, string.char(byte_val))
    end
  end

  return table.concat(digest)
end

--Provides: caml_digest_to_hex
function caml_digest_to_hex(digest)
  -- Convert digest to hex string
  local hex = {}
  for i = 1, string.len(digest) do
    table.insert(hex, string.format("%02x", string.byte(digest, i)))
  end
  return table.concat(hex)
end

--Provides: caml_md5_string
--Requires: caml_md5_init, caml_md5_update, caml_md5_final
function caml_md5_string(str, offset, len)
  -- Hash a substring of a string
  local ctx = caml_md5_init()
  local substring = string.sub(str, offset + 1, offset + len)
  caml_md5_update(ctx, substring)
  return caml_md5_final(ctx)
end

--Provides: caml_md5_chan
--Requires: caml_md5_init, caml_md5_update, caml_md5_final
function caml_md5_chan(chanid, toread)
  -- Hash data from a channel
  -- toread: -1 for entire channel, or specific number of bytes
  local ctx = caml_md5_init()
  local buffer_size = 4096

  if toread < 0 then
    -- Read entire channel
    while true do
      local buf = {}
      local bytes_read = caml_ml_input(chanid, buf, 0, buffer_size)
      if bytes_read == 0 then
        break
      end
      -- Convert byte array to string
      local chars = {}
      for i = 1, bytes_read do
        table.insert(chars, string.char(buf[i]))
      end
      caml_md5_update(ctx, table.concat(chars))
    end
  else
    -- Read specific number of bytes
    local remaining = toread
    while remaining > 0 do
      local to_read = math.min(remaining, buffer_size)
      local buf = {}
      local bytes_read = caml_ml_input(chanid, buf, 0, to_read)
      if bytes_read == 0 then
        error("End_of_file")
      end
      -- Convert byte array to string
      local chars = {}
      for i = 1, bytes_read do
        table.insert(chars, string.char(buf[i]))
      end
      caml_md5_update(ctx, table.concat(chars))
      remaining = remaining - bytes_read
    end
  end

  return caml_md5_final(ctx)
end


-- Runtime: sys
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

--- Sys Module
--
-- Provides system operations including:
-- - Program arguments
-- - Environment variables
-- - Time measurement
-- - File system operations
-- - System configuration

-- Global state for sys module (linker-compatible)
_OCAML_sys = _OCAML_sys or {
  static_env = {},
  argv = nil,
  initial_time = os.time(),
  runtime_warnings = 0
}

--- Detect OS type (inline function for reuse)
--Provides: caml_sys_detect_os_type
function caml_sys_detect_os_type()
  if package.config:sub(1, 1) == '\\' then
    return "Win32"
  else
    return "Unix"
  end
end

--- Initialize argv from command line arguments
--Provides: caml_sys_init_argv
function caml_sys_init_argv()
  if _OCAML_sys.argv then return _OCAML_sys.argv end

  local main = arg and arg[0] or "a.out"
  local args = arg or {}

  -- Build OCaml array: [0, program_name, arg1, arg2, ...]
  -- First element is tag 0, then program name, then arguments
  _OCAML_sys.argv = {tag = 0}
  _OCAML_sys.argv[1] = main

  -- Add command-line arguments (starting from arg[1])
  for i = 1, #args do
    _OCAML_sys.argv[i + 1] = args[i]
  end

  return _OCAML_sys.argv
end

--- Set static environment variable
-- @param key string Environment variable name
-- @param value string Environment variable value
-- @return number 0 (unit)
--Provides: caml_set_static_env
--Requires: caml_unit
function caml_set_static_env(key, value)
  local key_str = key
  local val_str = value
  _OCAML_sys.static_env[key_str] = val_str
  return caml_unit
end

--- Get environment variable (internal helper)
-- @param name string Environment variable name (Lua string)
-- @return string|nil Environment variable value or nil
--Provides: caml_sys_jsoo_getenv
function caml_sys_jsoo_getenv(name)
  -- Check static environment first
  if _OCAML_sys.static_env[name] then
    return _OCAML_sys.static_env[name]
  end

  -- Check os.getenv
  local value = os.getenv(name)
  if value then
    return value
  end

  return nil
end

--- Get environment variable
-- Raises Not_found exception if variable doesn't exist
-- @param name string|table OCaml string (environment variable name)
-- @return string|table OCaml string (environment variable value)
--Provides: caml_sys_getenv
--Requires: caml_raise_not_found, caml_sys_jsoo_getenv
function caml_sys_getenv(name)
  local name_str = name
  local value = caml_sys_jsoo_getenv(name_str)

  if value == nil then
    caml_raise_not_found()
  end

  return value
end

--- Get environment variable (optional version for OCaml 5.4+)
-- @param name string|table OCaml string (environment variable name)
-- @return number|table 0 (None) or [0, value] (Some value)
--Provides: caml_sys_getenv_opt
--Requires: caml_sys_jsoo_getenv
function caml_sys_getenv_opt(name)
  local name_str = name
  local value = caml_sys_jsoo_getenv(name_str)

  if value == nil then
    return 0 -- None (represented as 0)
  else
    -- Some value: {tag = 0, [1] = value}
    return {tag = 0, [1] = value}
  end
end

--- Unsafe get environment variable (same as caml_sys_getenv)
-- @param name string|table OCaml string
-- @return string|table OCaml string
--Provides: caml_sys_unsafe_getenv
--Requires: caml_sys_getenv
function caml_sys_unsafe_getenv(name)
  return caml_sys_getenv(name)
end

--- Get program arguments
-- @param _unit number Unit value (ignored)
-- @return table OCaml array of strings
--Provides: caml_sys_argv
--Requires: caml_sys_init_argv
function caml_sys_argv(_unit)
  local argv = caml_sys_init_argv()
  return argv
end

--- Get program arguments (alternative format)
-- Returns [0, program_name, argv_array]
-- @param _unit number Unit value (ignored)
-- @return table Tuple of [0, name, array]
--Provides: caml_sys_get_argv
--Requires: caml_sys_init_argv
function caml_sys_get_argv(_unit)
  local argv = caml_sys_init_argv()
  return {tag = 0, [1] = argv[1], [2] = argv}
end

--- Modify program arguments
-- @param arg table New argv array
-- @return number 0 (unit)
--Provides: caml_sys_modify_argv
--Requires: caml_unit
function caml_sys_modify_argv(arg)
  _OCAML_sys.argv = arg
  return caml_unit
end

--- Get executable name
-- @param _unit number Unit value (ignored)
-- @return string|table OCaml string
--Provides: caml_sys_executable_name
--Requires: caml_sys_init_argv
function caml_sys_executable_name(_unit)
  local argv = caml_sys_init_argv()
  return argv[1]
end

--- Get system configuration
-- Returns [0, os_type, word_size, big_endian]
-- @param _unit number Unit value (ignored)
-- @return table Configuration tuple
--Provides: caml_sys_get_config
--Requires: caml_sys_detect_os_type
function caml_sys_get_config(_unit)
  return {
    tag = 0,
    [1] = caml_sys_detect_os_type(),
    [2] = 32,  -- word_size (always 32 for js_of_ocaml compatibility)
    [3] = 0    -- big_endian (0 = little endian)
  }
end

--- Get elapsed time since program start (in seconds)
-- @param _unit number Unit value (ignored)
-- @return number Elapsed time in seconds
--Provides: caml_sys_time
function caml_sys_time(_unit)
  local now = os.time()
  return now - _OCAML_sys.initial_time
end

--- Get elapsed time including children processes
-- Note: In Lua, there's no notion of child processes, so this is the same as caml_sys_time
-- @param _b number Ignored
-- @return number Elapsed time in seconds
--Provides: caml_sys_time_include_children
--Requires: caml_sys_time
function caml_sys_time_include_children(_b)
  return caml_sys_time(0)
end

--- Check if file exists
-- @param name string|table OCaml string (file path)
-- @return number 0 (false) or 1 (true)
--Provides: caml_sys_file_exists
--Requires: caml_true_val, caml_false_val
function caml_sys_file_exists(name)
  local path = name
  local file = io.open(path, "r")
  if file then
    file:close()
    return caml_true_val
  else
    return caml_false_val
  end
end

--- Check if path is a directory
-- @param name string|table OCaml string (directory path)
-- @return number 0 (false) or 1 (true)
--Provides: caml_sys_is_directory
--Requires: caml_true_val, caml_false_val
function caml_sys_is_directory(name)
  local path = name

  -- Try to open as directory using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    local attr = lfs.attributes(path)
    if attr and attr.mode == "directory" then
      return caml_true_val
    else
      return caml_false_val
    end
  end

  -- Fallback: try to list directory (Unix-specific)
  local ok, _, code = os.execute('test -d "' .. path:gsub('"', '\\"') .. '"')
  if ok == true or code == 0 then
    return caml_true_val
  else
    return caml_false_val
  end
end

--- Check if path is a regular file (OCaml 5.1+)
-- @param name string|table OCaml string (file path)
-- @return number 0 (false) or 1 (true)
--Provides: caml_sys_is_regular_file
--Requires: caml_sys_is_directory, caml_true_val, caml_false_val
function caml_sys_is_regular_file(name)
  local path = name

  -- Try using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    local attr = lfs.attributes(path)
    if attr and attr.mode == "file" then
      return caml_true_val
    else
      return caml_false_val
    end
  end

  -- Fallback: check if we can open for reading
  local file = io.open(path, "r")
  if file then
    file:close()
    -- Additional check: not a directory
    if caml_sys_is_directory(name) == caml_true_val then
      return caml_false_val
    end
    return caml_true_val
  else
    return caml_false_val
  end
end

--- Remove (delete) a file
-- @param name string|table OCaml string (file path)
-- @return number 0 (unit)
--Provides: caml_sys_remove
--Requires: caml_raise_sys_error, caml_unit
function caml_sys_remove(name)
  local path = name
  local ok, err = os.remove(path)
  if not ok then
    caml_raise_sys_error("remove: " .. (err or "unknown error"))
  end
  return caml_unit
end

--- Rename a file
-- @param oldname string|table OCaml string (old path)
-- @param newname string|table OCaml string (new path)
-- @return number 0 (unit)
--Provides: caml_sys_rename
--Requires: caml_raise_sys_error, caml_unit
function caml_sys_rename(oldname, newname)
  local old_path = oldname
  local new_path = newname
  local ok, err = os.rename(old_path, new_path)
  if not ok then
    caml_raise_sys_error("rename: " .. (err or "unknown error"))
  end
  return caml_unit
end

--- Change current directory
-- @param dirname string|table OCaml string (directory path)
-- @return number 0 (unit)
--Provides: caml_sys_chdir
--Requires: caml_raise_sys_error, caml_unit
function caml_sys_chdir(dirname)
  local path = dirname

  -- Try using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    local ok, err = lfs.chdir(path)
    if not ok then
      caml_raise_sys_error("chdir: " .. (err or "unknown error"))
    end
    return caml_unit
  end

  -- Fallback: not supported without lfs
  caml_raise_sys_error("chdir: not supported (install LuaFileSystem)")
end

--- Get current working directory
-- @param _unit number Unit value (ignored)
-- @return string|table OCaml string (current directory)
--Provides: caml_sys_getcwd
--Requires: caml_raise_sys_error
function caml_sys_getcwd(_unit)
  -- Try using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    local cwd = lfs.currentdir()
    return cwd
  end

  -- Fallback: use shell command (Unix-specific)
  local handle = io.popen("pwd")
  if handle then
    local cwd = handle:read("*l")
    handle:close()
    if cwd then
      return cwd
    end
  end

  -- Last resort: raise error
  caml_raise_sys_error("getcwd: not supported (install LuaFileSystem)")
end

--- Read directory contents
-- @param dirname string|table OCaml string (directory path)
-- @return table OCaml array of strings (filenames)
--Provides: caml_sys_readdir
--Requires: caml_raise_sys_error
function caml_sys_readdir(dirname)
  local path = dirname

  -- Try using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    local entries = {tag = 0}  -- OCaml array
    local i = 0
    for entry in lfs.dir(path) do
      if entry ~= "." and entry ~= ".." then
        entries[i] = entry
        i = i + 1
      end
    end
    return entries
  end

  -- Fallback: not supported without lfs
  caml_raise_sys_error("readdir: not supported (install LuaFileSystem)")
end

--- Execute system command
-- @param cmd string|table OCaml string (command to execute)
-- @return number Exit code
--Provides: caml_sys_system_command
function caml_sys_system_command(cmd)
  local cmd_str = cmd
  local ok, exit_type, code = os.execute(cmd_str)

  -- Lua 5.2+ returns (true/nil, "exit"/"signal", code)
  -- Lua 5.1 returns just the exit code
  if type(ok) == "number" then
    return ok  -- Lua 5.1
  elseif ok == true then
    return 0  -- Success
  else
    return code or 1  -- Failure
  end
end

--- Exit program
-- @param code number Exit code
--Provides: caml_sys_exit
function caml_sys_exit(code)
  os.exit(code)
end

--- Open file (stub - not yet implemented)
-- @param path string|table File path
-- @param flags number Open flags
-- @return number File descriptor (stub)
--Provides: sys_open
function sys_open(path, flags)
  error("caml_sys_open: not yet implemented in lua_of_ocaml")
end

--- Close file (stub - not yet implemented)
-- @param fd number File descriptor
-- @return number 0 (unit)
--Provides: sys_close
function sys_close(fd)
  error("caml_sys_close: not yet implemented in lua_of_ocaml")
end

--- Get random seed
-- Returns array of random integers for seeding Random module
-- @param _unit number Unit value (ignored)
-- @return table OCaml array [0, x1, x2, x3, x4]
--Provides: caml_sys_random_seed
function caml_sys_random_seed(_unit)
  -- Try to get good random seed
  math.randomseed(os.time() + os.clock() * 1000000)

  -- Generate 4 random integers
  local r1 = math.random(-2147483648, 2147483647)
  local r2 = math.random(-2147483648, 2147483647)
  local r3 = math.random(-2147483648, 2147483647)
  local r4 = math.random(-2147483648, 2147483647)

  return {tag = 0, [1] = r1, [2] = r2, [3] = r3, [4] = r4}
end

--- System constants

--Provides: caml_sys_const_big_endian
function caml_sys_const_big_endian(_unit)
  return 0  -- Little endian
end

--Provides: caml_sys_const_word_size
function caml_sys_const_word_size(_unit)
  return 32  -- 32-bit word size (js_of_ocaml compatibility)
end

--Provides: caml_sys_const_int_size
function caml_sys_const_int_size(_unit)
  return 32  -- 32-bit int size
end

--Provides: caml_sys_const_max_wosize
function caml_sys_const_max_wosize(_unit)
  return math.floor(0x7fffffff / 4)  -- max_int / 4
end

--Provides: caml_sys_const_ostype_unix
--Requires: caml_true_val, caml_false_val, caml_sys_detect_os_type
function caml_sys_const_ostype_unix(_unit)
  return caml_sys_detect_os_type() == "Unix" and caml_true_val or caml_false_val
end

--Provides: caml_sys_const_ostype_win32
--Requires: caml_true_val, caml_false_val, caml_sys_detect_os_type
function caml_sys_const_ostype_win32(_unit)
  return caml_sys_detect_os_type() == "Win32" and caml_true_val or caml_false_val
end

--Provides: caml_sys_const_ostype_cygwin
--Requires: caml_false_val
function caml_sys_const_ostype_cygwin(_unit)
  return caml_false_val  -- We don't detect Cygwin specifically
end

--Provides: caml_sys_const_backend_type
function caml_sys_const_backend_type(_unit)
  return {tag = 0, [1] = "lua_of_ocaml"}
end

--Provides: caml_sys_const_naked_pointers_checked
function caml_sys_const_naked_pointers_checked(_unit)
  return 0
end

--- Check if channel is a TTY
-- @param _chan number Channel id
-- @return number 0 (false, channels are not TTYs in Lua)
--Provides: caml_sys_isatty
--Requires: caml_false_val
function caml_sys_isatty(_chan)
  return caml_false_val
end

--- Get runtime variant
-- @param _unit number Unit value (ignored)
-- @return string|table OCaml string (empty)
--Provides: caml_runtime_variant
function caml_runtime_variant(_unit)
  return ""
end

--- Get runtime parameters
-- @param _unit number Unit value (ignored)
-- @return string|table OCaml string (empty)
--Provides: caml_runtime_parameters
function caml_runtime_parameters(_unit)
  return ""
end

--- Install signal handler (no-op in Lua)
-- @return number 0
--Provides: caml_install_signal_handler
--Requires: caml_unit
function caml_install_signal_handler(_sig, _action)
  return caml_unit
end

--- Enable/disable runtime warnings
-- @param bool number 0 (false) or 1 (true)
-- @return number 0 (unit)
--Provides: caml_ml_enable_runtime_warnings
--Requires: caml_unit
function caml_ml_enable_runtime_warnings(bool)
  _OCAML_sys.runtime_warnings = bool
  return caml_unit
end

--- Check if runtime warnings are enabled
-- @param _unit number Unit value (ignored)
-- @return number 0 (false) or 1 (true)
--Provides: caml_ml_runtime_warnings_enabled
function caml_ml_runtime_warnings_enabled(_unit)
  return _OCAML_sys.runtime_warnings
end

--- Get I/O buffer size (OCaml 5.4+)
-- @param _unit number Unit value (ignored)
-- @return number Buffer size (65536)
--Provides: caml_sys_io_buffer_size
function caml_sys_io_buffer_size(_unit)
  return 65536
end

--- Get temp directory name (OCaml 5.4+)
-- @param _unit number Unit value (ignored)
-- @return string|table OCaml string (temp directory or empty)
--Provides: caml_sys_temp_dir_name
--Requires: caml_sys_detect_os_type
function caml_sys_temp_dir_name(_unit)
  if caml_sys_detect_os_type() == "Win32" then
    local tmp = os.getenv("TEMP") or os.getenv("TMP") or ""
    return tmp
  else
    local tmp = os.getenv("TMPDIR") or "/tmp"
    return tmp
  end
end

--- XDG defaults (OCaml 5.2+)
-- @param _unit number Unit value (ignored)
-- @return number 0 (empty list)
--Provides: caml_xdg_defaults
function caml_xdg_defaults(_unit)
  return 0  -- Empty list
end

--- Convert signal number (OCaml 5.4+)
-- @param signo number Signal number
-- @return number Same signal number
--Provides: caml_sys_convert_signal_number
function caml_sys_convert_signal_number(signo)
  return signo
end

--- Reverse convert signal number (OCaml 5.4+)
-- @param signo number Signal number
-- @return number Same signal number
--Provides: caml_sys_rev_convert_signal_number
function caml_sys_rev_convert_signal_number(signo)
  return signo
end



-- Runtime: filename
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

--Provides: caml_filename_os_type
function caml_filename_os_type()
  if package.config:sub(1, 1) == '\\' then
    return "Win32"
  else
    return "Unix"
  end
end

--Provides: caml_filename_dir_sep
--Requires: caml_filename_os_type
function caml_filename_dir_sep(_unit)
  return caml_filename_os_type() == "Win32" and "\\" or "/"
end

--Provides: caml_filename_is_dir_sep
--Requires: caml_filename_os_type
function caml_filename_is_dir_sep(c)
  if caml_filename_os_type() == "Win32" then
    return c == '\\' or c == '/'
  else
    return c == '/'
  end
end

--Provides: caml_filename_concat
--Requires: caml_filename_os_type caml_filename_is_dir_sep caml_filename_dir_sep
function caml_filename_concat(dir, file)
  local dir_str = dir
  local file_str = file
  local os_type = caml_filename_os_type()
  local dir_sep = caml_filename_dir_sep(0)

  -- Handle empty cases
  if dir_str == "" then
    return file_str
  end
  if file_str == "" then
    return dir_str
  end

  -- Check if file is absolute (should return file unchanged)
  -- Unix: starts with /
  -- Windows: starts with \ or / or drive letter (C:\)
  if os_type == "Win32" then
    if caml_filename_is_dir_sep(file_str:sub(1, 1)) then
      return file_str
    end
    -- Check for drive letter (C:)
    if file_str:match("^%a:") then
      return file_str
    end
  else
    if file_str:sub(1, 1) == '/' then
      return file_str
    end
  end

  -- Add separator if dir doesn't end with one
  local last_char = dir_str:sub(-1)
  if caml_filename_is_dir_sep(last_char) then
    return dir_str .. file_str
  else
    return dir_str .. dir_sep .. file_str
  end
end

--Provides: caml_filename_basename
--Requires: caml_filename_is_dir_sep caml_filename_os_type
function caml_filename_basename(name)
  local name_str = name
  local os_type = caml_filename_os_type()

  if name_str == "" then
    return ""
  end

  -- Remove trailing separators
  while #name_str > 1 and caml_filename_is_dir_sep(name_str:sub(-1)) do
    name_str = name_str:sub(1, -2)
  end

  -- Special case: root directory
  if name_str == "/" or (os_type == "Win32" and name_str:match("^%a:[\\/]?$")) then
    return name_str
  end

  -- Find last separator
  local last_sep = 0
  for i = #name_str, 1, -1 do
    if caml_filename_is_dir_sep(name_str:sub(i, i)) then
      last_sep = i
      break
    end
  end

  if last_sep == 0 then
    return name_str
  else
    return name_str:sub(last_sep + 1)
  end
end

--Provides: caml_filename_dirname
--Requires: caml_filename_is_dir_sep caml_filename_os_type caml_filename_dir_sep
function caml_filename_dirname(name)
  local name_str = name
  local os_type = caml_filename_os_type()
  local dir_sep = caml_filename_dir_sep(0)

  if name_str == "" then
    return "."
  end

  -- Remove trailing separators
  while #name_str > 1 and caml_filename_is_dir_sep(name_str:sub(-1)) do
    name_str = name_str:sub(1, -2)
  end

  -- Special case: root directory
  if name_str == "/" then
    return "/"
  end
  if os_type == "Win32" and name_str:match("^%a:[\\/]?$") then
    return name_str
  end

  -- Find last separator
  local last_sep = 0
  for i = #name_str, 1, -1 do
    if caml_filename_is_dir_sep(name_str:sub(i, i)) then
      last_sep = i
      break
    end
  end

  if last_sep == 0 then
    return "."
  elseif last_sep == 1 then
    return "/"
  else
    -- Remove trailing separator from dirname
    local result = name_str:sub(1, last_sep - 1)
    if result == "" then
      return "/"
    end
    -- Windows drive letter case
    if os_type == "Win32" and result:match("^%a:$") then
      return result .. dir_sep
    end
    return result
  end
end

--Provides: caml_filename_check_suffix
function caml_filename_check_suffix(name, suff)
  local name_str = name
  local suff_str = suff

  if #suff_str > #name_str then
    return 0
  end

  if #suff_str == 0 then
    return 1
  end

  local name_end = name_str:sub(-#suff_str)
  if name_end == suff_str then
    return 1
  else
    return 0
  end
end

--Provides: caml_filename_chop_suffix
--Requires: caml_invalid_argument
function caml_filename_chop_suffix(name, suff)
  local name_str = name
  local suff_str = suff

  if #suff_str > #name_str then
    caml_invalid_argument("Filename.chop_suffix")
  end

  if #suff_str == 0 then
    return name_str
  end

  local name_end = name_str:sub(-#suff_str)
  if name_end == suff_str then
    return name_str:sub(1, -#suff_str - 1)
  else
    caml_invalid_argument("Filename.chop_suffix")
  end
end

--Provides: caml_filename_chop_extension
--Requires: caml_filename_is_dir_sep caml_invalid_argument
function caml_filename_chop_extension(name)
  local name_str = name

  -- Find last dot
  local last_dot = 0
  local last_sep = 0

  for i = #name_str, 1, -1 do
    local c = name_str:sub(i, i)
    if c == '.' and last_dot == 0 then
      last_dot = i
    end
    if caml_filename_is_dir_sep(c) then
      last_sep = i
      break
    end
  end

  -- No dot found, or dot is before last separator, or dot is first character
  if last_dot == 0 or last_dot <= last_sep or last_dot == 1 then
    caml_invalid_argument("Filename.chop_extension")
  end

  return name_str:sub(1, last_dot - 1)
end

--Provides: caml_filename_extension
--Requires: caml_filename_is_dir_sep
function caml_filename_extension(name)
  local name_str = name

  -- Find last dot
  local last_dot = 0
  local last_sep = 0

  for i = #name_str, 1, -1 do
    local c = name_str:sub(i, i)
    if c == '.' and last_dot == 0 then
      last_dot = i
    end
    if caml_filename_is_dir_sep(c) then
      last_sep = i
      break
    end
  end

  -- No dot found, or dot is before last separator, or dot is first character
  if last_dot == 0 or last_dot <= last_sep or last_dot == 1 then
    return ""
  end

  return name_str:sub(last_dot)
end

--Provides: caml_filename_remove_extension
--Requires: caml_filename_is_dir_sep
function caml_filename_remove_extension(name)
  local name_str = name

  -- Find last dot
  local last_dot = 0
  local last_sep = 0

  for i = #name_str, 1, -1 do
    local c = name_str:sub(i, i)
    if c == '.' and last_dot == 0 then
      last_dot = i
    end
    if caml_filename_is_dir_sep(c) then
      last_sep = i
      break
    end
  end

  -- No dot found, or dot is before last separator, or dot is first character
  if last_dot == 0 or last_dot <= last_sep or last_dot == 1 then
    return name_str
  end

  return name_str:sub(1, last_dot - 1)
end

--Provides: caml_filename_is_relative
--Requires: caml_filename_os_type caml_filename_is_dir_sep
function caml_filename_is_relative(name)
  local name_str = name
  local os_type = caml_filename_os_type()

  if name_str == "" then
    return 1
  end

  if os_type == "Win32" then
    -- Absolute if starts with separator or drive letter
    if caml_filename_is_dir_sep(name_str:sub(1, 1)) then
      return 0
    end
    if name_str:match("^%a:") then
      return 0
    end
    return 1
  else
    -- Unix: absolute if starts with /
    if name_str:sub(1, 1) == '/' then
      return 0
    else
      return 1
    end
  end
end

--Provides: caml_filename_is_implicit
--Requires: caml_filename_is_dir_sep caml_filename_os_type
function caml_filename_is_implicit(name)
  local name_str = name
  local os_type = caml_filename_os_type()

  if name_str == "" then
    return 1
  end

  -- Check if starts with separator (explicit)
  if caml_filename_is_dir_sep(name_str:sub(1, 1)) then
    return 0
  end

  -- Check if starts with ./ or ../
  if name_str:sub(1, 2) == "./" or name_str:sub(1, 2) == ".\\" then
    return 0
  end
  if name_str:sub(1, 3) == "../" or name_str:sub(1, 3) == "..\\" then
    return 0
  end

  -- Windows: check for drive letter
  if os_type == "Win32" and name_str:match("^%a:") then
    return 0
  end

  return 1
end

--Provides: caml_filename_current_dir_name
function caml_filename_current_dir_name(_unit)
  return "."
end

--Provides: caml_filename_parent_dir_name
function caml_filename_parent_dir_name(_unit)
  return ".."
end

--Provides: caml_filename_quote
function caml_filename_quote(name)
  local name_str = name

  -- Simple quoting: wrap in quotes if contains spaces or special chars
  if name_str:match("[ \t\n'\"\\$`!*?]") then
    -- Escape quotes and backslashes
    local escaped = name_str:gsub("\\", "\\\\"):gsub('"', '\\"')
    return '"' .. escaped .. '"'
  else
    return name_str
  end
end

--Provides: caml_filename_quote_command
function caml_filename_quote_command(cmd)
  return cmd
end

--Provides: caml_filename_temp_dir_name
--Requires: caml_sys_temp_dir_name
function caml_filename_temp_dir_name(_unit)
  return caml_sys_temp_dir_name(0)
end

--Provides: caml_filename_null
--Requires: caml_filename_os_type
function caml_filename_null(_unit)
  local os_type = caml_filename_os_type()
  if os_type == "Win32" then
    return "NUL"
  else
    return "/dev/null"
  end
end


-- Runtime: set
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


--Provides: caml_set_height
function caml_set_height(node)
  if not node then
    return 0
  end
  return node.height
end

--Provides: caml_set_create_node
--Requires: caml_set_height
function caml_set_create_node(elt, left, right)
  return {
    elt = elt,
    left = left,
    right = right,
    height = 1 + math.max(caml_set_height(left), caml_set_height(right))
  }
end

--Provides: caml_set_balance_factor
--Requires: caml_set_height
function caml_set_balance_factor(node)
  if not node then
    return 0
  end
  return caml_set_height(node.left) - caml_set_height(node.right)
end

--Provides: caml_set_rotate_right
--Requires: caml_set_height
function caml_set_rotate_right(node)
  local left = node.left
  local left_right = left.right

  left.right = node
  node.left = left_right

  node.height = 1 + math.max(caml_set_height(node.left), caml_set_height(node.right))
  left.height = 1 + math.max(caml_set_height(left.left), caml_set_height(left.right))

  return left
end

--Provides: caml_set_rotate_left
--Requires: caml_set_height
function caml_set_rotate_left(node)
  local right = node.right
  local right_left = right.left

  right.left = node
  node.right = right_left

  node.height = 1 + math.max(caml_set_height(node.left), caml_set_height(node.right))
  right.height = 1 + math.max(caml_set_height(right.left), caml_set_height(right.right))

  return right
end

--Provides: caml_set_balance
--Requires: caml_set_balance_factor, caml_set_rotate_left, caml_set_rotate_right
function caml_set_balance(node)
  if not node then
    return nil
  end

  local bf = caml_set_balance_factor(node)

  if bf > 1 then
    if caml_set_balance_factor(node.left) < 0 then
      node.left = caml_set_rotate_left(node.left)
    end
    return caml_set_rotate_right(node)
  end

  if bf < -1 then
    if caml_set_balance_factor(node.right) > 0 then
      node.right = caml_set_rotate_right(node.right)
    end
    return caml_set_rotate_left(node)
  end

  return node
end

--Provides: caml_set_add_internal
--Requires: caml_set_create_node, caml_set_height, caml_set_balance
function caml_set_add_internal(cmp, elt, node)
  if not node then
    return caml_set_create_node(elt, nil, nil)
  end

  local c = cmp(elt, node.elt)

  if c == 0 then
    return node  -- Element already exists
  elseif c < 0 then
    node.left = caml_set_add_internal(cmp, elt, node.left)
  else
    node.right = caml_set_add_internal(cmp, elt, node.right)
  end

  node.height = 1 + math.max(caml_set_height(node.left), caml_set_height(node.right))
  return caml_set_balance(node)
end

--Provides: caml_set_mem_internal
function caml_set_mem_internal(cmp, elt, node)
  if not node then
    return false
  end

  local c = cmp(elt, node.elt)

  if c == 0 then
    return true
  elseif c < 0 then
    return caml_set_mem_internal(cmp, elt, node.left)
  else
    return caml_set_mem_internal(cmp, elt, node.right)
  end
end

--Provides: caml_set_min_node
function caml_set_min_node(node)
  if not node.left then
    return node
  end
  return caml_set_min_node(node.left)
end

--Provides: caml_set_remove_internal
--Requires: caml_set_min_node, caml_set_height, caml_set_balance
function caml_set_remove_internal(cmp, elt, node)
  if not node then
    return nil
  end

  local c = cmp(elt, node.elt)

  if c < 0 then
    node.left = caml_set_remove_internal(cmp, elt, node.left)
  elseif c > 0 then
    node.right = caml_set_remove_internal(cmp, elt, node.right)
  else
    if not node.left then
      return node.right
    elseif not node.right then
      return node.left
    else
      local successor = caml_set_min_node(node.right)
      node.elt = successor.elt
      node.right = caml_set_remove_internal(cmp, successor.elt, node.right)
    end
  end

  if not node then
    return nil
  end

  node.height = 1 + math.max(caml_set_height(node.left), caml_set_height(node.right))
  return caml_set_balance(node)
end

--Provides: caml_set_union_internal
--Requires: caml_set_add_internal
function caml_set_union_internal(cmp, s1, s2)
  if not s1 then
    return s2
  end
  if not s2 then
    return s1
  end

  local result = s1
  local function add_all(node)
    if node then
      add_all(node.left)
      result = caml_set_add_internal(cmp, node.elt, result)
      add_all(node.right)
    end
  end
  add_all(s2)
  return result
end

--Provides: caml_set_inter_internal
--Requires: caml_set_mem_internal, caml_set_add_internal
function caml_set_inter_internal(cmp, s1, s2)
  if not s1 or not s2 then
    return nil
  end

  local result = nil
  local function check_all(node)
    if node then
      check_all(node.left)
      if caml_set_mem_internal(cmp, node.elt, s2) then
        result = caml_set_add_internal(cmp, node.elt, result)
      end
      check_all(node.right)
    end
  end
  check_all(s1)
  return result
end

--Provides: caml_set_diff_internal
--Requires: caml_set_mem_internal, caml_set_add_internal
function caml_set_diff_internal(cmp, s1, s2)
  if not s1 then
    return nil
  end
  if not s2 then
    return s1
  end

  local result = nil
  local function check_all(node)
    if node then
      check_all(node.left)
      if not caml_set_mem_internal(cmp, node.elt, s2) then
        result = caml_set_add_internal(cmp, node.elt, result)
      end
      check_all(node.right)
    end
  end
  check_all(s1)
  return result
end

--Provides: caml_set_iter_internal
function caml_set_iter_internal(f, node)
  if not node then
    return
  end
  caml_set_iter_internal(f, node.left)
  f(node.elt)
  caml_set_iter_internal(f, node.right)
end

--Provides: caml_set_fold_internal
function caml_set_fold_internal(f, node, acc)
  if not node then
    return acc
  end
  acc = caml_set_fold_internal(f, node.left, acc)
  acc = f(node.elt, acc)
  acc = caml_set_fold_internal(f, node.right, acc)
  return acc
end

--Provides: caml_set_for_all_internal
function caml_set_for_all_internal(p, node)
  if not node then
    return true
  end
  return p(node.elt) and caml_set_for_all_internal(p, node.left) and caml_set_for_all_internal(p, node.right)
end

--Provides: caml_set_exists_internal
function caml_set_exists_internal(p, node)
  if not node then
    return false
  end
  return p(node.elt) or caml_set_exists_internal(p, node.left) or caml_set_exists_internal(p, node.right)
end

--Provides: caml_set_cardinal_internal
function caml_set_cardinal_internal(node)
  if not node then
    return 0
  end
  return 1 + caml_set_cardinal_internal(node.left) + caml_set_cardinal_internal(node.right)
end

--Provides: caml_set_filter_internal
--Requires: caml_set_create_node, caml_set_balance, caml_set_min_node, caml_set_remove_internal
function caml_set_filter_internal(cmp, p, node)
  if not node then
    return nil
  end

  local left = caml_set_filter_internal(cmp, p, node.left)
  local right = caml_set_filter_internal(cmp, p, node.right)

  if p(node.elt) then
    local result = caml_set_create_node(node.elt, left, right)
    return caml_set_balance(result)
  else
    if not left then
      return right
    elseif not right then
      return left
    else
      local min = caml_set_min_node(right)
      local new_right = caml_set_remove_internal(cmp, min.elt, right)
      local result = caml_set_create_node(min.elt, left, new_right)
      return caml_set_balance(result)
    end
  end
end

--Provides: caml_set_partition_internal
--Requires: caml_set_create_node, caml_set_balance, caml_set_union_internal
function caml_set_partition_internal(cmp, p, node)
  if not node then
    return nil, nil
  end

  local left_t, left_f = caml_set_partition_internal(cmp, p, node.left)
  local right_t, right_f = caml_set_partition_internal(cmp, p, node.right)

  if p(node.elt) then
    local t = caml_set_create_node(node.elt, left_t, right_t)
    return caml_set_balance(t), caml_set_union_internal(cmp, left_f, right_f)
  else
    local f = caml_set_create_node(node.elt, left_f, right_f)
    return caml_set_union_internal(cmp, left_t, right_t), caml_set_balance(f)
  end
end

--Provides: caml_set_subset_internal
--Requires: caml_set_for_all_internal, caml_set_mem_internal
function caml_set_subset_internal(cmp, s1, s2)
  if not s1 then
    return true
  end
  if not s2 then
    return false
  end
  return caml_set_for_all_internal(function(elt) return caml_set_mem_internal(cmp, elt, s2) end, s1)
end

--Provides: caml_set_min_elt_internal
function caml_set_min_elt_internal(node)
  if not node then
    return nil
  end
  if not node.left then
    return node.elt
  end
  return caml_set_min_elt_internal(node.left)
end

--Provides: caml_set_max_elt_internal
function caml_set_max_elt_internal(node)
  if not node then
    return nil
  end
  if not node.right then
    return node.elt
  end
  return caml_set_max_elt_internal(node.right)
end


--Provides: caml_set_empty
function caml_set_empty(_unit)
  return nil
end

--Provides: caml_set_add
--Requires: caml_set_add_internal
function caml_set_add(cmp, elt, set)
  return caml_set_add_internal(cmp, elt, set)
end

--Provides: caml_set_remove
--Requires: caml_set_remove_internal
function caml_set_remove(cmp, elt, set)
  return caml_set_remove_internal(cmp, elt, set)
end

--Provides: caml_set_mem
--Requires: caml_set_mem_internal, caml_true_val, caml_false_val
function caml_set_mem(cmp, elt, set)
  if caml_set_mem_internal(cmp, elt, set) then
    return caml_true_val
  else
    return caml_false_val
  end
end

--Provides: caml_set_union
--Requires: caml_set_union_internal
function caml_set_union(cmp, s1, s2)
  return caml_set_union_internal(cmp, s1, s2)
end

--Provides: caml_set_inter
--Requires: caml_set_inter_internal
function caml_set_inter(cmp, s1, s2)
  return caml_set_inter_internal(cmp, s1, s2)
end

--Provides: caml_set_diff
--Requires: caml_set_diff_internal
function caml_set_diff(cmp, s1, s2)
  return caml_set_diff_internal(cmp, s1, s2)
end

--Provides: caml_set_iter
--Requires: caml_set_iter_internal, caml_unit
function caml_set_iter(f, set)
  caml_set_iter_internal(f, set)
  return caml_unit
end

--Provides: caml_set_fold
--Requires: caml_set_fold_internal
function caml_set_fold(f, set, init)
  return caml_set_fold_internal(f, set, init)
end

--Provides: caml_set_for_all
--Requires: caml_set_for_all_internal, caml_true_val, caml_false_val
function caml_set_for_all(p, set)
  if caml_set_for_all_internal(p, set) then
    return caml_true_val
  else
    return caml_false_val
  end
end

--Provides: caml_set_exists
--Requires: caml_set_exists_internal, caml_true_val, caml_false_val
function caml_set_exists(p, set)
  if caml_set_exists_internal(p, set) then
    return caml_true_val
  else
    return caml_false_val
  end
end

--Provides: caml_set_cardinal
--Requires: caml_set_cardinal_internal
function caml_set_cardinal(set)
  return caml_set_cardinal_internal(set)
end

--Provides: caml_set_is_empty
--Requires: caml_true_val, caml_false_val
function caml_set_is_empty(set)
  if set == nil then
    return caml_true_val
  else
    return caml_false_val
  end
end

--Provides: caml_set_filter
--Requires: caml_set_filter_internal
function caml_set_filter(cmp, p, set)
  return caml_set_filter_internal(cmp, p, set)
end

--Provides: caml_set_partition
--Requires: caml_set_partition_internal
function caml_set_partition(cmp, p, set)
  local t, f = caml_set_partition_internal(cmp, p, set)
  return {tag = 0, [1] = t, [2] = f}
end

--Provides: caml_set_subset
--Requires: caml_set_subset_internal, caml_true_val, caml_false_val
function caml_set_subset(cmp, s1, s2)
  if caml_set_subset_internal(cmp, s1, s2) then
    return caml_true_val
  else
    return caml_false_val
  end
end

--Provides: caml_set_min_elt
--Requires: caml_set_min_elt_internal, caml_raise_not_found
function caml_set_min_elt(set)
  local min = caml_set_min_elt_internal(set)
  if min == nil then
    caml_raise_not_found()
  end
  return min
end

--Provides: caml_set_max_elt
--Requires: caml_set_max_elt_internal, caml_raise_not_found
function caml_set_max_elt(set)
  local max = caml_set_max_elt_internal(set)
  if max == nil then
    caml_raise_not_found()
  end
  return max
end

--Provides: caml_set_equal
--Requires: caml_set_cardinal_internal, caml_set_subset_internal, caml_true_val, caml_false_val
function caml_set_equal(cmp, s1, s2)
  if caml_set_cardinal_internal(s1) ~= caml_set_cardinal_internal(s2) then
    return caml_false_val
  end
  if caml_set_subset_internal(cmp, s1, s2) then
    return caml_true_val
  else
    return caml_false_val
  end
end


-- Runtime: compare
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


--Provides: caml_is_ocaml_string
function caml_is_ocaml_string(v)
  if type(v) ~= "table" then
    return false
  end
  if v.tag ~= nil then
    return false
  end
  for k, val in pairs(v) do
    if type(k) ~= "number" or type(val) ~= "number" then
      return false
    end
  end
  return true
end

--Provides: caml_is_ocaml_block
function caml_is_ocaml_block(v)
  if type(v) ~= "table" then
    return false
  end
  return v.tag ~= nil and type(v.tag) == "number"
end

--Provides: caml_compare_tag
--Requires: caml_is_ocaml_string, caml_is_ocaml_block
function caml_compare_tag(v)
  local t = type(v)

  if t == "number" then
    return 1000
  elseif t == "string" then
    return 12520
  elseif t == "boolean" then
    return 1002
  elseif t == "nil" then
    return 1003
  elseif t == "function" then
    return 1247
  elseif t == "table" then
    if caml_is_ocaml_string(v) then
      return 252
    elseif caml_is_ocaml_block(v) then
      local tag = v.tag
      if tag == 250 then
        return 250
      end
      return tag == 254 and 0 or tag
    else
      return 1001
    end
  else
    return 1004
  end
end

--Provides: caml_compare_ocaml_strings
function caml_compare_ocaml_strings(a, b)
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

  if len_a < len_b then
    return -1
  elseif len_a > len_b then
    return 1
  else
    return 0
  end
end

--Provides: caml_compare_numbers
function caml_compare_numbers(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  elseif a == b then
    return 0
  else
    if a ~= a then
      if b ~= b then
        return 0
      else
        return -1
      end
    else
      return 1
    end
  end
end

--Provides: caml_compare_val
--Requires: caml_compare_tag, caml_is_ocaml_block, caml_compare_numbers, caml_compare_ocaml_strings
function caml_compare_val(a, b, total)
  local stack = {}

  while true do
    -- Use repeat-until to enable breaking out and restarting the outer loop
    repeat
      if not (total and a == b) then
        local tag_a = caml_compare_tag(a)

        if tag_a == 250 and caml_is_ocaml_block(a) then
          a = a[1]
          break  -- Restart outer loop
        end

        local tag_b = caml_compare_tag(b)

        if tag_b == 250 and caml_is_ocaml_block(b) then
          b = b[1]
          break  -- Restart outer loop
        end

        if tag_a ~= tag_b then
          if tag_a < tag_b then
            return -1
          else
            return 1
          end
        end

        if tag_a == 1000 then
          local result = caml_compare_numbers(a, b)
          if result ~= 0 then
            return result
          end
        elseif tag_a == 12520 then
          if a < b then
            return -1
          elseif a > b then
            return 1
          end
        elseif tag_a == 252 then
          if a ~= b then
            local result = caml_compare_ocaml_strings(a, b)
            if result ~= 0 then
              return result
            end
          end
        elseif tag_a == 1002 then
          if a ~= b then
            if not a then
              return -1
            else
              return 1
            end
          end
        elseif tag_a == 1003 then
        elseif tag_a == 1247 then
          error("compare: functional value")
        elseif tag_a == 1001 or tag_a == 1004 then
          if a < b then
            return -1
          elseif a > b then
            return 1
          elseif a ~= b then
            if total then
              return 1
            else
              error("compare: incomparable values")
            end
          end
        elseif tag_a == 248 then
          if caml_is_ocaml_block(a) and caml_is_ocaml_block(b) then
            local id_a = a[2] or 0
            local id_b = b[2] or 0
            if id_a < id_b then
              return -1
            elseif id_a > id_b then
              return 1
            end
          end
        else
          if caml_is_ocaml_block(a) and caml_is_ocaml_block(b) then
            local len_a = #a
            local len_b = #b

            if len_a ~= len_b then
              if len_a < len_b then
                return -1
              else
                return 1
              end
            end

            if len_a > 0 then
              if len_a > 1 then
                table.insert(stack, {a = a, b = b, i = 2})
              end
              a = a[1]
              b = b[1]
              break  -- Restart outer loop
            end
          end
        end
      end

      -- If we reach here, we didn't break, so handle stack
      if #stack == 0 then
        return 0
      end

      local frame = table.remove(stack)
      local parent_a = frame.a
      local parent_b = frame.b
      local i = frame.i

      if i + 1 <= #parent_a then
        table.insert(stack, {a = parent_a, b = parent_b, i = i + 1})
      end

      a = parent_a[i]
      b = parent_b[i]
    until true  -- Single iteration, but allows break to restart outer loop
  end
end

--Provides: caml_compare
--Requires: caml_compare_val
function caml_compare(a, b)
  return caml_compare_val(a, b, true)
end

--Provides: caml_int_compare
function caml_int_compare(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--Provides: caml_int32_compare
function caml_int32_compare(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--Provides: caml_nativeint_compare
function caml_nativeint_compare(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--Provides: caml_float_compare
function caml_float_compare(a, b)
  if a ~= a then
    if b ~= b then
      return 0
    else
      return 1
    end
  end
  if b ~= b then
    return -1
  end

  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--Provides: caml_equal
--Requires: caml_compare_val
function caml_equal(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) == 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_notequal
--Requires: caml_compare_val
function caml_notequal(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) ~= 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_lessthan
--Requires: caml_compare_val
function caml_lessthan(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) < 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_lessequal
--Requires: caml_compare_val
function caml_lessequal(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) <= 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_greaterthan
--Requires: caml_compare_val
function caml_greaterthan(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) > 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_greaterequal
--Requires: caml_compare_val
function caml_greaterequal(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) >= 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_min
--Requires: caml_compare
function caml_min(x, y)
  if caml_compare(x, y) <= 0 then
    return x
  else
    return y
  end
end

--Provides: caml_max
--Requires: caml_compare
function caml_max(x, y)
  if caml_compare(x, y) >= 0 then
    return x
  else
    return y
  end
end


-- Runtime: hash
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


--Provides: caml_hash_bit_xor
function caml_hash_bit_xor(a, b)
  a = a % 0x100000000
  b = b % 0x100000000
  local result = 0
  local bit_val = 1
  for i = 0, 31 do
    local a_bit = a % 2
    local b_bit = b % 2
    if a_bit ~= b_bit then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result % 0x100000000
end

--Provides: caml_hash_bit_lshift
function caml_hash_bit_lshift(a, n)
  a = a % 0x100000000
  n = n % 32
  local result = a * (2 ^ n)
  return math.floor(result % 0x100000000)
end

--Provides: caml_hash_bit_rshift
function caml_hash_bit_rshift(a, n)
  a = a % 0x100000000
  n = n % 32
  local result = a / (2 ^ n)
  return math.floor(result % 0x100000000)
end

--Provides: caml_hash_bit_and
function caml_hash_bit_and(a, b)
  a = a % 0x100000000
  b = b % 0x100000000
  local result = 0
  local bit_val = 1
  for i = 0, 31 do
    if a % 2 == 1 and b % 2 == 1 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result % 0x100000000
end

--Provides: caml_hash_bit_or
function caml_hash_bit_or(a, b)
  a = a % 0x100000000
  b = b % 0x100000000
  local result = 0
  local bit_val = 1
  for i = 0, 31 do
    if a % 2 == 1 or b % 2 == 1 then
      result = result + bit_val
    end
    a = math.floor(a / 2)
    b = math.floor(b / 2)
    bit_val = bit_val * 2
  end
  return result % 0x100000000
end

--Provides: caml_hash_mul32
function caml_hash_mul32(a, b)
  a = a % 0x100000000
  b = b % 0x100000000
  local result = a * b
  return math.floor(result % 0x100000000)
end

--Provides: caml_hash_to_int32
function caml_hash_to_int32(n)
  n = math.floor(n % 0x100000000)
  if n >= 0x80000000 then
    return n - 0x100000000
  end
  return n
end

--Provides: caml_hash_mix_int
--Requires: caml_hash_mul32, caml_hash_bit_or, caml_hash_bit_lshift, caml_hash_bit_rshift, caml_hash_bit_xor, caml_hash_to_int32
function caml_hash_mix_int(h, d)
  d = caml_hash_mul32(d, 0xcc9e2d51)
  d = caml_hash_bit_or(caml_hash_bit_lshift(d, 15), caml_hash_bit_rshift(d, 17))  -- ROTL32(d, 15)
  d = caml_hash_mul32(d, 0x1b873593)
  h = caml_hash_bit_xor(h, d)
  h = caml_hash_bit_or(caml_hash_bit_lshift(h, 13), caml_hash_bit_rshift(h, 19))  -- ROTL32(h, 13)
  h = caml_hash_to_int32(caml_hash_to_int32(h + caml_hash_bit_lshift(h, 2)) + 0xe6546b64)
  return h
end

--Provides: caml_hash_mix_final
--Requires: caml_hash_bit_xor, caml_hash_bit_rshift, caml_hash_mul32
function caml_hash_mix_final(h)
  h = caml_hash_bit_xor(h, caml_hash_bit_rshift(h, 16))
  h = caml_hash_mul32(h, 0x85ebca6b)
  h = caml_hash_bit_xor(h, caml_hash_bit_rshift(h, 13))
  h = caml_hash_mul32(h, 0xc2b2ae35)
  h = caml_hash_bit_xor(h, caml_hash_bit_rshift(h, 16))
  return h
end

--Provides: caml_hash_mix_float
--Requires: caml_hash_bit_and, caml_hash_bit_rshift, caml_hash_bit_lshift, caml_hash_bit_or, caml_hash_mix_int, caml_hash_to_int32
function caml_hash_mix_float(hash, v)
  local lo, hi

  if v == 0 then
    if 1/v == -math.huge then
      lo, hi = 0, 0x80000000
    else
      lo, hi = 0, 0
    end
  elseif v ~= v then
    lo, hi = 0x00000001, 0x7ff00000
  elseif v == math.huge then
    lo, hi = 0, 0x7ff00000
  elseif v == -math.huge then
    lo, hi = 0, 0xfff00000
  else
    local sign = v < 0 and 1 or 0
    v = math.abs(v)

    local exp = math.floor(math.log(v) / math.log(2))
    local frac = v / (2 ^ exp) - 1

    exp = exp + 1023
    if exp <= 0 then
      exp = 0
      frac = v / (2 ^ -1022)
    elseif exp >= 0x7ff then
      exp = 0x7ff
      frac = 0
    end

    local frac_hi = math.floor(frac * (2 ^ 20))
    local frac_lo = math.floor((frac * (2 ^ 52)) % (2 ^ 32))

    hi = caml_hash_bit_or(caml_hash_bit_lshift(sign, 31), caml_hash_bit_or(caml_hash_bit_lshift(exp, 20), frac_hi))
    lo = frac_lo
  end

  local exp = caml_hash_bit_and(caml_hash_bit_rshift(hi, 20), 0x7ff)
  if exp == 0x7ff then
    local frac_hi = caml_hash_bit_and(hi, 0xfffff)
    if frac_hi ~= 0 or lo ~= 0 then
      hi = 0x7ff00000
      lo = 0x00000001
    end
  elseif hi == 0x80000000 and lo == 0 then
    hi = 0
  end

  hash = caml_hash_mix_int(hash, caml_hash_to_int32(lo))
  hash = caml_hash_mix_int(hash, caml_hash_to_int32(hi))
  return hash
end

--Provides: caml_hash_mix_string
--Requires: caml_hash_bit_or, caml_hash_bit_lshift, caml_hash_mix_int, caml_hash_to_int32, caml_hash_bit_xor
function caml_hash_mix_string(h, s)
  local len = #s
  local i = 1
  local w

  while i + 3 <= len do
    w = caml_hash_bit_or(
      caml_hash_bit_or(s[i], caml_hash_bit_lshift(s[i + 1], 8)),
      caml_hash_bit_or(caml_hash_bit_lshift(s[i + 2], 16), caml_hash_bit_lshift(s[i + 3], 24))
    )
    h = caml_hash_mix_int(h, caml_hash_to_int32(w))
    i = i + 4
  end

  w = 0
  local remaining = len - i + 1
  if remaining == 3 then
    w = caml_hash_bit_lshift(s[i + 2], 16)
    w = caml_hash_bit_or(w, caml_hash_bit_lshift(s[i + 1], 8))
    w = caml_hash_bit_or(w, s[i])
    h = caml_hash_mix_int(h, caml_hash_to_int32(w))
  elseif remaining == 2 then
    w = caml_hash_bit_or(caml_hash_bit_lshift(s[i + 1], 8), s[i])
    h = caml_hash_mix_int(h, caml_hash_to_int32(w))
  elseif remaining == 1 then
    w = s[i]
    h = caml_hash_mix_int(h, caml_hash_to_int32(w))
  end

  h = caml_hash_bit_xor(h, len)
  return h
end

--Provides: caml_hash
--Requires: caml_hash_mix_int, caml_hash_mix_float, caml_hash_mix_string, caml_hash_mix_final, caml_is_ocaml_string, caml_is_ocaml_block, caml_hash_bit_or, caml_hash_bit_lshift, caml_hash_to_int32, caml_hash_bit_and
function caml_hash(count, limit, seed, obj)
  local sz = limit
  if sz < 0 or sz > 256 then
    sz = 256
  end

  local num = count
  local h = seed
  local queue = {obj}
  local rd = 1
  local wr = 2

  while rd < wr and num > 0 do
    local v = queue[rd]
    rd = rd + 1

    if type(v) == "number" then
      -- Lua 5.1: no math.type(), all numbers are doubles
      -- Check if integer-valued and in 31-bit signed range
      if v == math.floor(v) and v >= -0x40000000 and v < 0x40000000 then
        h = caml_hash_mix_int(h, caml_hash_to_int32(v + v + 1))
        num = num - 1
      else
        h = caml_hash_mix_float(h, v)
        num = num - 1
      end
    elseif type(v) == "string" then
      local bytes = {string.byte(v, 1, -1)}
      h = caml_hash_mix_string(h, bytes)
      num = num - 1
    elseif caml_is_ocaml_string(v) then
      h = caml_hash_mix_string(h, v)
      num = num - 1
    elseif caml_is_ocaml_block(v) then
      local tag_value = caml_hash_bit_or(caml_hash_bit_lshift(#v, 10), v.tag)
      h = caml_hash_mix_int(h, caml_hash_to_int32(tag_value))

      for i = 1, #v do
        if wr >= sz then
          break
        end
        queue[wr] = v[i]
        wr = wr + 1
      end
    elseif type(v) == "table" then
      h = caml_hash_mix_int(h, caml_hash_to_int32(#v))

      for i = 1, #v do
        if wr >= sz then
          break
        end
        queue[wr] = v[i]
        wr = wr + 1
      end
    end
  end

  h = caml_hash_mix_final(h)
  return caml_hash_bit_and(h, 0x3fffffff)
end

--Provides: caml_hash_default
--Requires: caml_hash
function caml_hash_default(obj)
  return caml_hash(10, 100, 0, obj)
end


-- Runtime: hashtbl
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


--Provides: caml_hashtbl_equal
function caml_hashtbl_equal(a, b)
  if a == b then
    return true
  end

  local ta = type(a)
  local tb = type(b)

  if ta ~= tb then
    return false
  end

  if ta ~= "table" then
    return false
  end

  local len_a = #a
  local len_b = #b

  if len_a ~= len_b then
    return false
  end

  for i = 1, len_a do
    if not caml_hashtbl_equal(a[i], b[i]) then
      return false
    end
  end

  if a.tag ~= b.tag then
    return false
  end

  return true
end

--Provides: caml_hashtbl_get_bucket_index
--Requires: caml_hash_default
function caml_hashtbl_get_bucket_index(tbl, key)
  local hash = caml_hash_default(key)
  return (hash % tbl.capacity) + 1
end

--Provides: caml_hashtbl_resize
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hashtbl_resize(tbl)
  local new_capacity = tbl.capacity * 2
  local old_buckets = tbl.buckets

  tbl.buckets = {}
  for i = 1, new_capacity do
    tbl.buckets[i] = {}
  end

  tbl.capacity = new_capacity
  local old_size = tbl.size
  tbl.size = 0

  for _, bucket in ipairs(old_buckets) do
    for _, entry in ipairs(bucket) do
      local idx = caml_hashtbl_get_bucket_index(tbl, entry.key)
      local new_bucket = tbl.buckets[idx]
      table.insert(new_bucket, 1, {key = entry.key, value = entry.value})
      tbl.size = tbl.size + 1
    end
  end
end

--Provides: caml_hash_create
function caml_hash_create(initial_size)
  local size = initial_size or 16
  if size < 1 then
    size = 16
  end

  local tbl = {
    buckets = {},
    size = 0,
    capacity = size,
  }

  for i = 1, size do
    tbl.buckets[i] = {}
  end

  return tbl
end

--Provides: caml_hash_add
--Requires: caml_hashtbl_resize, caml_hashtbl_get_bucket_index
function caml_hash_add(tbl, key, value)
  if tbl.size >= tbl.capacity * 0.75 then
    caml_hashtbl_resize(tbl)
  end

  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  table.insert(bucket, 1, {key = key, value = value})
  tbl.size = tbl.size + 1
end

--Provides: caml_hash_find
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hash_find(tbl, key)
  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  for _, entry in ipairs(bucket) do
    if caml_hashtbl_equal(entry.key, key) then
      return entry.value
    end
  end

  error("Not_found")
end

--Provides: caml_hash_find_opt
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hash_find_opt(tbl, key)
  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  for _, entry in ipairs(bucket) do
    if caml_hashtbl_equal(entry.key, key) then
      return entry.value
    end
  end

  return nil
end

--Provides: caml_hash_remove
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hash_remove(tbl, key)
  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  for i, entry in ipairs(bucket) do
    if caml_hashtbl_equal(entry.key, key) then
      table.remove(bucket, i)
      tbl.size = tbl.size - 1
      return
    end
  end
end

--Provides: caml_hash_replace
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hash_replace(tbl, key, value)
  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  local removed_count = 0
  for i = #bucket, 1, -1 do
    if caml_hashtbl_equal(bucket[i].key, key) then
      table.remove(bucket, i)
      removed_count = removed_count + 1
    end
  end

  table.insert(bucket, 1, {key = key, value = value})

  tbl.size = tbl.size - removed_count + 1
end

--Provides: caml_hash_mem
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hash_mem(tbl, key)
  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  for _, entry in ipairs(bucket) do
    if caml_hashtbl_equal(entry.key, key) then
      return true
    end
  end

  return false
end

--Provides: caml_hash_length
function caml_hash_length(tbl)
  return tbl.size
end

--Provides: caml_hash_clear
function caml_hash_clear(tbl)
  for i = 1, tbl.capacity do
    tbl.buckets[i] = {}
  end
  tbl.size = 0
end

--Provides: caml_hash_iter
function caml_hash_iter(tbl, f)
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      f(entry.key, entry.value)
    end
  end
end

--Provides: caml_hash_fold
function caml_hash_fold(tbl, f, init)
  local acc = init
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      acc = f(entry.key, entry.value, acc)
    end
  end
  return acc
end

--Provides: caml_hash_entries
function caml_hash_entries(tbl)
  local bucket_idx = 1
  local entry_idx = 0

  return function()
    while bucket_idx <= tbl.capacity do
      entry_idx = entry_idx + 1
      local bucket = tbl.buckets[bucket_idx]

      if entry_idx <= #bucket then
        local entry = bucket[entry_idx]
        return entry.key, entry.value
      end

      bucket_idx = bucket_idx + 1
      entry_idx = 0
    end

    return nil
  end
end

--Provides: caml_hash_keys
function caml_hash_keys(tbl)
  local keys = {}
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      table.insert(keys, entry.key)
    end
  end
  return keys
end

--Provides: caml_hash_values
function caml_hash_values(tbl)
  local values = {}
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      table.insert(values, entry.value)
    end
  end
  return values
end

--Provides: caml_hash_to_array
function caml_hash_to_array(tbl)
  local result = {}
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      table.insert(result, {entry.key, entry.value})
    end
  end
  return result
end

--Provides: caml_hash_stats
function caml_hash_stats(tbl)
  local max_bucket_size = 0
  local empty_buckets = 0
  local total_buckets = tbl.capacity

  for _, bucket in ipairs(tbl.buckets) do
    local bucket_size = #bucket
    if bucket_size == 0 then
      empty_buckets = empty_buckets + 1
    end
    if bucket_size > max_bucket_size then
      max_bucket_size = bucket_size
    end
  end

  return {
    size = tbl.size,
    capacity = tbl.capacity,
    load_factor = tbl.size / tbl.capacity,
    max_bucket_size = max_bucket_size,
    empty_buckets = empty_buckets,
    avg_bucket_size = tbl.size / (tbl.capacity - empty_buckets),
  }
end


-- Runtime: bigarray
-- Lua_of_ocaml runtime support
-- Bigarray support (OCaml Bigarray module)
--
-- Provides multi-dimensional arrays with various numeric types.
-- Supports both C layout (row-major) and Fortran layout (column-major).
--
-- Note: Lua doesn't have typed arrays like JavaScript. We use regular tables
-- with metadata to track element kind and provide bounds checking.

--Provides: caml_ba_get_size_per_element
function caml_ba_get_size_per_element(kind)
  -- Element size per kind (in number of storage elements)
  -- kind values: FLOAT32=0, FLOAT64=1, INT8_SIGNED=2, INT8_UNSIGNED=3,
  --   INT16_SIGNED=4, INT16_UNSIGNED=5, INT32=6, INT64=7, NATIVEINT=8,
  --   CAML_INT=9, COMPLEX32=10, COMPLEX64=11, CHAR=12, FLOAT16=13
  if kind == 7 or kind == 10 or kind == 11 then
    -- INT64 or COMPLEX32 or COMPLEX64
    return 2  -- Stored as 2 numbers
  else
    return 1
  end
end

--Provides: caml_ba_clamp_value
function caml_ba_clamp_value(kind, value)
  -- Range clamping for different kinds
  if kind == 2 then
    -- INT8_SIGNED
    value = math.floor(value)
    if value < -128 then return -128 end
    if value > 127 then return 127 end
    return value
  elseif kind == 3 or kind == 12 then
    -- INT8_UNSIGNED or CHAR
    value = math.floor(value)
    if value < 0 then return 0 end
    if value > 255 then return 255 end
    return value
  elseif kind == 4 then
    -- INT16_SIGNED
    value = math.floor(value)
    if value < -32768 then return -32768 end
    if value > 32767 then return 32767 end
    return value
  elseif kind == 5 then
    -- INT16_UNSIGNED
    value = math.floor(value)
    if value < 0 then return 0 end
    if value > 65535 then return 65535 end
    return value
  elseif kind == 6 or kind == 8 or kind == 9 then
    -- INT32 or NATIVEINT or CAML_INT
    return math.floor(value)
  else
    -- Float types: no clamping, just return as-is
    return value
  end
end

--Provides: caml_ba_create_buffer
--Requires: caml_ba_get_size_per_element
function caml_ba_create_buffer(kind, size)
  -- Create buffer for bigarray data
  local elem_size = caml_ba_get_size_per_element(kind)
  local total_size = size * elem_size
  local buffer = {}

  -- Initialize all elements to 0
  for i = 1, total_size do
    buffer[i] = 0
  end

  return buffer
end

--Provides: caml_ba_get_size
function caml_ba_get_size(dims)
  -- Get total size from dimensions
  local size = 1
  for i = 1, #dims do
    if dims[i] < 0 then
      error("Bigarray.create: negative dimension")
    end
    size = size * dims[i]
  end
  return size
end

--Provides: caml_ba_create_unsafe
function caml_ba_create_unsafe(kind, layout, dims, data)
  -- Create bigarray (unsafe, no validation)
  -- BA_CUSTOM_NAME = "_bigarr02"
  return {
    kind = kind,
    layout = layout,
    dims = dims,
    data = data,
    caml_custom = "_bigarr02"
  }
end

--Provides: caml_ba_create
--Requires: caml_ba_get_size, caml_ba_create_buffer, caml_ba_create_unsafe
function caml_ba_create(kind, layout, dims_ml)
  -- Create bigarray with validation
  -- dims_ml can be either a Lua table or OCaml array representation
  local dims
  if type(dims_ml) == "table" then
    if dims_ml[0] ~= nil then
      -- OCaml array (0-indexed)
      dims = {}
      for i = 0, #dims_ml do
        if dims_ml[i] ~= nil then
          table.insert(dims, dims_ml[i])
        end
      end
    else
      -- Plain Lua table (1-indexed)
      dims = dims_ml
    end
  else
    error("Bigarray.create: invalid dims")
  end

  local size = caml_ba_get_size(dims)
  local data = caml_ba_create_buffer(kind, size)
  return caml_ba_create_unsafe(kind, layout, dims, data)
end

--Provides: caml_ba_init
function caml_ba_init()
  -- Initialize bigarray module
  return 0
end

--Provides: caml_ba_kind
function caml_ba_kind(ba)
  -- Get bigarray kind
  return ba.kind
end

--Provides: caml_ba_layout
function caml_ba_layout(ba)
  -- Get bigarray layout
  return ba.layout
end

--Provides: caml_ba_num_dims
function caml_ba_num_dims(ba)
  -- Get number of dimensions
  return #ba.dims
end

--Provides: caml_ba_dim
function caml_ba_dim(ba, i)
  -- Get dimension size
  if i < 0 or i >= #ba.dims then
    error("Bigarray.dim")
  end
  return ba.dims[i + 1]  -- Lua is 1-indexed
end

--Provides: caml_ba_dim_1
--Requires: caml_ba_dim
function caml_ba_dim_1(ba)
  -- Get first dimension
  return caml_ba_dim(ba, 0)
end

--Provides: caml_ba_dim_2
--Requires: caml_ba_dim
function caml_ba_dim_2(ba)
  -- Get second dimension
  return caml_ba_dim(ba, 1)
end

--Provides: caml_ba_dim_3
--Requires: caml_ba_dim
function caml_ba_dim_3(ba)
  -- Get third dimension
  return caml_ba_dim(ba, 2)
end

--Provides: caml_ba_change_layout
--Requires: caml_ba_create_unsafe
function caml_ba_change_layout(ba, layout)
  -- Change bigarray layout
  if ba.layout == layout then
    return ba
  end

  -- Reverse dimensions for layout change
  local new_dims = {}
  for i = #ba.dims, 1, -1 do
    table.insert(new_dims, ba.dims[i])
  end

  return caml_ba_create_unsafe(ba.kind, layout, new_dims, ba.data)
end

--Provides: caml_ba_calculate_offset
function caml_ba_calculate_offset(ba, indices)
  -- Calculate linear offset from multi-dimensional index
  local ofs = 0
  -- LAYOUT: C_LAYOUT=0, FORTRAN_LAYOUT=1

  if ba.layout == 0 then
    -- C layout: row-major, 0-indexed
    for i = 1, #ba.dims do
      local idx = indices[i]
      if idx < 0 or idx >= ba.dims[i] then
        error("array bound error")
      end
      ofs = ofs * ba.dims[i] + idx
    end
  else
    -- Fortran layout: column-major, 1-indexed
    for i = #ba.dims, 1, -1 do
      local idx = indices[i]
      if idx < 1 or idx > ba.dims[i] then
        error("array bound error")
      end
      ofs = ofs * ba.dims[i] + (idx - 1)
    end
  end

  return ofs
end

--Provides: caml_ba_get_generic
--Requires: caml_ba_calculate_offset, caml_ba_get_size_per_element
function caml_ba_get_generic(ba, indices)
  -- Get element at indices
  local ofs = caml_ba_calculate_offset(ba, indices)
  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64: stored as two Int32s
    local lo = ba.data[ofs * elem_size + 1]
    local hi = ba.data[ofs * elem_size + 2]
    return {lo, hi}  -- OCaml int64 representation
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64: stored as (real, imag)
    local re = ba.data[ofs * elem_size + 1]
    local im = ba.data[ofs * elem_size + 2]
    return {tag = 0, re, im}  -- OCaml complex representation
  else
    -- Simple scalar types
    return ba.data[ofs + 1]
  end
end

--Provides: caml_ba_set_generic
--Requires: caml_ba_calculate_offset, caml_ba_get_size_per_element, caml_ba_clamp_value
function caml_ba_set_generic(ba, indices, value)
  -- Set element at indices
  local ofs = caml_ba_calculate_offset(ba, indices)
  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64: store as two Int32s
    ba.data[ofs * elem_size + 1] = value[1]  -- lo
    ba.data[ofs * elem_size + 2] = value[2]  -- hi
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64: store as (real, imag)
    ba.data[ofs * elem_size + 1] = value[1]  -- real
    ba.data[ofs * elem_size + 2] = value[2]  -- imag
  else
    -- Simple scalar types
    ba.data[ofs + 1] = caml_ba_clamp_value(ba.kind, value)
  end

  return 0  -- unit
end

--Provides: caml_ba_get_1
--Requires: caml_ba_get_generic
function caml_ba_get_1(ba, i0)
  -- Get element from 1D array
  return caml_ba_get_generic(ba, {i0})
end

--Provides: caml_ba_set_1
--Requires: caml_ba_set_generic
function caml_ba_set_1(ba, i0, value)
  -- Set element in 1D array
  return caml_ba_set_generic(ba, {i0}, value)
end

--Provides: caml_ba_unsafe_get_1
--Requires: caml_ba_get_size_per_element
function caml_ba_unsafe_get_1(ba, i0)
  -- Unsafe get (no bounds check)
  local ofs = ba.layout == 0 and i0 or (i0 - 1)
  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64
    return {ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64
    return {tag = 0, ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  else
    return ba.data[ofs + 1]
  end
end

--Provides: caml_ba_unsafe_set_1
--Requires: caml_ba_get_size_per_element, caml_ba_clamp_value
function caml_ba_unsafe_set_1(ba, i0, value)
  -- Unsafe set (no bounds check)
  local ofs = ba.layout == 0 and i0 or (i0 - 1)
  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  else
    ba.data[ofs + 1] = caml_ba_clamp_value(ba.kind, value)
  end

  return 0
end

--Provides: caml_ba_get_2
--Requires: caml_ba_get_generic
function caml_ba_get_2(ba, i0, i1)
  return caml_ba_get_generic(ba, {i0, i1})
end

--Provides: caml_ba_set_2
--Requires: caml_ba_set_generic
function caml_ba_set_2(ba, i0, i1, value)
  return caml_ba_set_generic(ba, {i0, i1}, value)
end

--Provides: caml_ba_unsafe_get_2
--Requires: caml_ba_get_size_per_element
function caml_ba_unsafe_get_2(ba, i0, i1)
  -- For unsafe, skip bounds check
  local ofs = 0

  if ba.layout == 0 then
    -- C layout: row-major, 0-indexed
    ofs = i0 * ba.dims[2] + i1
  else
    -- Fortran layout: column-major, 1-indexed
    ofs = (i1 - 1) * ba.dims[1] + (i0 - 1)
  end

  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64
    return {ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64
    return {tag = 0, ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  else
    return ba.data[ofs + 1]
  end
end

--Provides: caml_ba_unsafe_set_2
--Requires: caml_ba_get_size_per_element, caml_ba_clamp_value
function caml_ba_unsafe_set_2(ba, i0, i1, value)
  local ofs = 0

  if ba.layout == 0 then
    -- C layout: row-major, 0-indexed
    ofs = i0 * ba.dims[2] + i1
  else
    -- Fortran layout: column-major, 1-indexed
    ofs = (i1 - 1) * ba.dims[1] + (i0 - 1)
  end

  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  else
    ba.data[ofs + 1] = caml_ba_clamp_value(ba.kind, value)
  end

  return 0
end

--Provides: caml_ba_get_3
--Requires: caml_ba_get_generic
function caml_ba_get_3(ba, i0, i1, i2)
  return caml_ba_get_generic(ba, {i0, i1, i2})
end

--Provides: caml_ba_set_3
--Requires: caml_ba_set_generic
function caml_ba_set_3(ba, i0, i1, i2, value)
  return caml_ba_set_generic(ba, {i0, i1, i2}, value)
end

--Provides: caml_ba_sub
--Requires: caml_ba_get_size_per_element, caml_ba_create_unsafe
function caml_ba_sub(ba, ofs, len)
  -- Create sub-array (shares data with parent)
  if #ba.dims ~= 1 then
    error("Bigarray.sub: only for 1D arrays")
  end

  local elem_size = caml_ba_get_size_per_element(ba.kind)

  -- Create shallow copy of data starting at offset
  local new_data = {}
  local start_ofs = ofs * elem_size + 1
  for i = 0, len * elem_size - 1 do
    new_data[i + 1] = ba.data[start_ofs + i]
  end

  return caml_ba_create_unsafe(ba.kind, ba.layout, {len}, new_data)
end

--Provides: caml_ba_slice_left
function caml_ba_slice_left(ba, indices)
  -- Slice array along first dimension
  error("Bigarray.slice_left: not yet implemented")
end

--Provides: caml_ba_slice_right
function caml_ba_slice_right(ba, indices)
  -- Slice array along last dimension
  error("Bigarray.slice_right: not yet implemented")
end

--Provides: caml_ba_fill
--Requires: caml_ba_get_size_per_element, caml_ba_get_size, caml_ba_clamp_value
function caml_ba_fill(ba, value)
  -- Fill bigarray with value
  local elem_size = caml_ba_get_size_per_element(ba.kind)
  local total_elems = caml_ba_get_size(ba.dims)

  if ba.kind == 7 then
    -- INT64
    for i = 0, total_elems - 1 do
      ba.data[i * elem_size + 1] = value[1]
      ba.data[i * elem_size + 2] = value[2]
    end
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64
    for i = 0, total_elems - 1 do
      ba.data[i * elem_size + 1] = value[1]
      ba.data[i * elem_size + 2] = value[2]
    end
  else
    local clamped = caml_ba_clamp_value(ba.kind, value)
    for i = 1, total_elems do
      ba.data[i] = clamped
    end
  end

  return 0
end

--Provides: caml_ba_blit
function caml_ba_blit(src, dst)
  -- Blit (copy) from src to dst
  if src.kind ~= dst.kind then
    error("Bigarray.blit: kind mismatch")
  end

  if #src.dims ~= #dst.dims then
    error("Bigarray.blit: dimension mismatch")
  end

  for i = 1, #src.dims do
    if src.dims[i] ~= dst.dims[i] then
      error("Bigarray.blit: dimension mismatch")
    end
  end

  -- Copy data
  for i = 1, #src.data do
    dst.data[i] = src.data[i]
  end

  return 0
end

--Provides: caml_ba_reshape
--Requires: caml_ba_get_size, caml_ba_create_unsafe
function caml_ba_reshape(ba, new_dims_ml)
  -- Reshape bigarray to new dimensions
  -- Handle both OCaml arrays and Lua tables
  local new_dims
  if type(new_dims_ml) == "table" then
    if new_dims_ml[0] ~= nil then
      -- OCaml array (0-indexed)
      new_dims = {}
      for i = 0, #new_dims_ml do
        if new_dims_ml[i] ~= nil then
          table.insert(new_dims, new_dims_ml[i])
        end
      end
    else
      -- Plain Lua table (1-indexed)
      new_dims = new_dims_ml
    end
  else
    error("Bigarray.reshape: invalid dims")
  end

  local old_size = caml_ba_get_size(ba.dims)
  local new_size = caml_ba_get_size(new_dims)

  if old_size ~= new_size then
    error("Bigarray.reshape: size mismatch")
  end

  return caml_ba_create_unsafe(ba.kind, ba.layout, new_dims, ba.data)
end


-- Runtime: array
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


-- 
function __caml_init__()
  -- Module initialization code
  -- Hoisted variables (187 total, using table due to Lua's 200 local limit)
  local _V = {}
  local _next_block = 0
  while true do
    if _next_block == 0 then
      _V.Out_of_memory = {tag = 248, "Out_of_memory", -1}
      _V.Sys_error = {tag = 248, "Sys_error", -2}
      _V.Failure = {tag = 248, "Failure", -3}
      _V.Invalid_argument = {tag = 248, "Invalid_argument", -4}
      _V.End_of_file = {tag = 248, "End_of_file", -5}
      _V.Division_by_zero = {tag = 248, "Division_by_zero", -6}
      _V.Not_found = {tag = 248, "Not_found", -7}
      _V.Match_failure = {tag = 248, "Match_failure", -8}
      _V.Stack_overflow = {tag = 248, "Stack_overflow", -9}
      _V.Sys_blocked_io = {tag = 248, "Sys_blocked_io", -10}
      _V.Assert_failure = {tag = 248, "Assert_failure", -11}
      _V.Undefined_recursive_module = {tag = 248, "Undefined_recursive_module", -12}
      _V.v0 = "%,"
      _V.v1 = "really_input"
      _V.v2 = "input"
      _V.v3 = {tag = 0, 0, {tag = 0, 6, 0}}
      _V.v4 = {tag = 0, 0, {tag = 0, 7, 0}}
      _V.v5 = "output_substring"
      _V.v6 = "output"
      _V.v7 = {tag = 0, 1, {tag = 0, 3, {tag = 0, 4, {tag = 0, 6, 0}}}}
      _V.v8 = {tag = 0, 1, {tag = 0, 3, {tag = 0, 4, {tag = 0, 7, 0}}}}
      _V.v9 = "%.12g"
      _V.v10 = "."
      _V.v11 = "%d"
      _V.v12 = "false"
      _V.v13 = "true"
      _V.v14 = {tag = 0, 1}
      _V.v15 = {tag = 0, 0}
      _V.v16 = "false"
      _V.v17 = "true"
      _V.v18 = "bool_of_string"
      _V.v19 = "true"
      _V.v20 = "false"
      _V.v21 = "char_of_int"
      _V.v22 = "index out of bounds"
      _V.v23 = "Pervasives.array_bound_error"
      _V.v24 = "Stdlib.Exit"
      _V.v25 = 9218868437227405312
      _V.v26 = -4503599627370496
      _V.v27 = 9221120237041090561
      _V.v28 = 9218868437227405311
      _V.v29 = 4503599627370496
      _V.v30 = 4372995238176751616
      _V.v31 = "Pervasives.do_at_exit"
      _V.v32 = "Hello from Lua!"
      _V.v33 = caml_register_global(11, _V.Undefined_recursive_module, "Undefined_recursive_module")
      _V.v34 = caml_register_global(10, _V.Assert_failure, "Assert_failure")
      _V.v35 = caml_register_global(9, _V.Sys_blocked_io, "Sys_blocked_io")
      _V.v36 = caml_register_global(8, _V.Stack_overflow, "Stack_overflow")
      _V.v37 = caml_register_global(7, _V.Match_failure, "Match_failure")
      _V.v38 = caml_register_global(6, _V.Not_found, "Not_found")
      _V.v39 = caml_register_global(5, _V.Division_by_zero, "Division_by_zero")
      _V.v40 = caml_register_global(4, _V.End_of_file, "End_of_file")
      _V.v41 = caml_register_global(3, _V.Invalid_argument, "Invalid_argument")
      _V.v42 = caml_register_global(2, _V.Failure, "Failure")
      _V.v43 = caml_register_global(1, _V.Sys_error, "Sys_error")
      _V.v44 = caml_register_global(0, _V.Out_of_memory, "Out_of_memory")
      _next_block = 68
    else
      if _next_block == 68 then
        _V.v45 = function(v175)
          -- Hoisted variables (50 total, using inherited _V table)
          _V.v175 = v175
          local _next_block = 1
          while true do
            if _next_block == 1 then
              _V.v176 = type(_V.v175) == "number" and _V.v175 % 1 == 0
              if _V.v176 then
                _next_block = 2
              else
                _next_block = 3
              end
            else
              if _next_block == 2 then
                if _V.v175 == 0 then
                  _next_block = 4
                else
                  _next_block = 4
                end
              else
                if _next_block == 3 then
                  _V.v177 = _V.v175.tag or 0
                  if _V.v177 == 0 then
                    _next_block = 5
                  else
                    if _V.v177 == 1 then
                      _next_block = 6
                    else
                      if _V.v177 == 2 then
                        _next_block = 7
                      else
                        if _V.v177 == 3 then
                          _next_block = 8
                        else
                          if _V.v177 == 4 then
                            _next_block = 9
                          else
                            if _V.v177 == 5 then
                              _next_block = 10
                            else
                              if _V.v177 == 6 then
                                _next_block = 11
                              else
                                if _V.v177 == 7 then
                                  _next_block = 12
                                else
                                  if _V.v177 == 8 then
                                    _next_block = 13
                                  else
                                    if _V.v177 == 9 then
                                      _next_block = 14
                                    else
                                      if _V.v177 == 10 then
                                        _next_block = 15
                                      else
                                        if _V.v177 == 11 then
                                          _next_block = 16
                                        else
                                          if _V.v177 == 12 then
                                            _next_block = 17
                                          else
                                            if _V.v177 == 13 then
                                              _next_block = 18
                                            else
                                              if _V.v177 == 14 then
                                                _next_block = 19
                                              else
                                                _next_block = 5
                                              end
                                            end
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                else
                  if _next_block == 4 then
                    _V.v178 = 0
                    return _V.v178
                  else
                    if _next_block == 5 then
                      _V.v179 = _V.v175[1]
                      _V.v180 = _V.v45(_V.v179)
                      _V.v181 = {tag = 0, _V.v180}
                      return _V.v181
                    else
                      if _next_block == 6 then
                        _V.v182 = _V.v175[1]
                        _V.v183 = _V.v45(_V.v182)
                        _V.v184 = {tag = 1, _V.v183}
                        return _V.v184
                      else
                        if _next_block == 7 then
                          _V.v185 = _V.v175[1]
                          _V.v186 = _V.v45(_V.v185)
                          _V.v187 = {tag = 2, _V.v186}
                          return _V.v187
                        else
                          if _next_block == 8 then
                            _V.v188 = _V.v175[1]
                            _V.v189 = _V.v45(_V.v188)
                            _V.v190 = {tag = 3, _V.v189}
                            return _V.v190
                          else
                            if _next_block == 9 then
                              _V.v191 = _V.v175[1]
                              _V.v192 = _V.v45(_V.v191)
                              _V.v193 = {tag = 4, _V.v192}
                              return _V.v193
                            else
                              if _next_block == 10 then
                                _V.v194 = _V.v175[1]
                                _V.v195 = _V.v45(_V.v194)
                                _V.v196 = {tag = 5, _V.v195}
                                return _V.v196
                              else
                                if _next_block == 11 then
                                  _V.v197 = _V.v175[1]
                                  _V.v198 = _V.v45(_V.v197)
                                  _V.v199 = {tag = 6, _V.v198}
                                  return _V.v199
                                else
                                  if _next_block == 12 then
                                    _V.v200 = _V.v175[1]
                                    _V.v201 = _V.v45(_V.v200)
                                    _V.v202 = {tag = 7, _V.v201}
                                    return _V.v202
                                  else
                                    if _next_block == 13 then
                                      _V.v203 = _V.v175[2]
                                      _V.v204 = _V.v175[1]
                                      _V.v205 = _V.v45(_V.v203)
                                      _V.v206 = {tag = 8, _V.v204, _V.v205}
                                      return _V.v206
                                    else
                                      if _next_block == 14 then
                                        _V.v207 = _V.v175[3]
                                        _V.v208 = _V.v175[1]
                                        _V.v209 = _V.v45(_V.v207)
                                        _V.v210 = {tag = 9, _V.v208, _V.v208, _V.v209}
                                        return _V.v210
                                      else
                                        if _next_block == 15 then
                                          _V.v211 = _V.v175[1]
                                          _V.v212 = _V.v45(_V.v211)
                                          _V.v213 = {tag = 10, _V.v212}
                                          return _V.v213
                                        else
                                          if _next_block == 16 then
                                            _V.v214 = _V.v175[1]
                                            _V.v215 = _V.v45(_V.v214)
                                            _V.v216 = {tag = 11, _V.v215}
                                            return _V.v216
                                          else
                                            if _next_block == 17 then
                                              _V.v217 = _V.v175[1]
                                              _V.v218 = _V.v45(_V.v217)
                                              _V.v219 = {tag = 12, _V.v218}
                                              return _V.v219
                                            else
                                              if _next_block == 18 then
                                                _V.v220 = _V.v175[1]
                                                _V.v221 = _V.v45(_V.v220)
                                                _V.v222 = {tag = 13, _V.v221}
                                                return _V.v222
                                              else
                                                if _next_block == 19 then
                                                  _V.v223 = _V.v175[1]
                                                  _V.v224 = _V.v45(_V.v223)
                                                  _V.v225 = {tag = 14, _V.v224}
                                                  return _V.v225
                                                else
                                                  break
                                                end
                                              end
                                            end
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
        _V.v46 = function(v175, v176)
          -- Hoisted variables (50 total, using inherited _V table)
          _V.v175 = v175
          _V.v176 = v176
          local _next_block = 20
          while true do
            if _next_block == 20 then
              _V.v177 = type(_V.v175) == "number" and _V.v175 % 1 == 0
              if _V.v177 then
                _next_block = 21
              else
                _next_block = 22
              end
            else
              if _next_block == 21 then
                if _V.v175 == 0 then
                  _next_block = 23
                else
                  _next_block = 23
                end
              else
                if _next_block == 22 then
                  _V.v178 = _V.v175.tag or 0
                  if _V.v178 == 0 then
                    _next_block = 24
                  else
                    if _V.v178 == 1 then
                      _next_block = 25
                    else
                      if _V.v178 == 2 then
                        _next_block = 26
                      else
                        if _V.v178 == 3 then
                          _next_block = 27
                        else
                          if _V.v178 == 4 then
                            _next_block = 28
                          else
                            if _V.v178 == 5 then
                              _next_block = 29
                            else
                              if _V.v178 == 6 then
                                _next_block = 30
                              else
                                if _V.v178 == 7 then
                                  _next_block = 31
                                else
                                  if _V.v178 == 8 then
                                    _next_block = 32
                                  else
                                    if _V.v178 == 9 then
                                      _next_block = 33
                                    else
                                      if _V.v178 == 10 then
                                        _next_block = 34
                                      else
                                        if _V.v178 == 11 then
                                          _next_block = 35
                                        else
                                          if _V.v178 == 12 then
                                            _next_block = 36
                                          else
                                            if _V.v178 == 13 then
                                              _next_block = 37
                                            else
                                              if _V.v178 == 14 then
                                                _next_block = 38
                                              else
                                                _next_block = 24
                                              end
                                            end
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                else
                  if _next_block == 23 then
                    return _V.v176
                  else
                    if _next_block == 24 then
                      _V.v179 = _V.v175[1]
                      _V.v180 = _V.v46(_V.v179, _V.v176)
                      _V.v181 = {tag = 0, _V.v180}
                      return _V.v181
                    else
                      if _next_block == 25 then
                        _V.v182 = _V.v175[1]
                        _V.v183 = _V.v46(_V.v182, _V.v176)
                        _V.v184 = {tag = 1, _V.v183}
                        return _V.v184
                      else
                        if _next_block == 26 then
                          _V.v185 = _V.v175[1]
                          _V.v186 = _V.v46(_V.v185, _V.v176)
                          _V.v187 = {tag = 2, _V.v186}
                          return _V.v187
                        else
                          if _next_block == 27 then
                            _V.v188 = _V.v175[1]
                            _V.v189 = _V.v46(_V.v188, _V.v176)
                            _V.v190 = {tag = 3, _V.v189}
                            return _V.v190
                          else
                            if _next_block == 28 then
                              _V.v191 = _V.v175[1]
                              _V.v192 = _V.v46(_V.v191, _V.v176)
                              _V.v193 = {tag = 4, _V.v192}
                              return _V.v193
                            else
                              if _next_block == 29 then
                                _V.v194 = _V.v175[1]
                                _V.v195 = _V.v46(_V.v194, _V.v176)
                                _V.v196 = {tag = 5, _V.v195}
                                return _V.v196
                              else
                                if _next_block == 30 then
                                  _V.v197 = _V.v175[1]
                                  _V.v198 = _V.v46(_V.v197, _V.v176)
                                  _V.v199 = {tag = 6, _V.v198}
                                  return _V.v199
                                else
                                  if _next_block == 31 then
                                    _V.v200 = _V.v175[1]
                                    _V.v201 = _V.v46(_V.v200, _V.v176)
                                    _V.v202 = {tag = 7, _V.v201}
                                    return _V.v202
                                  else
                                    if _next_block == 32 then
                                      _V.v203 = _V.v175[2]
                                      _V.v204 = _V.v175[1]
                                      _V.v205 = _V.v46(_V.v203, _V.v176)
                                      _V.v206 = {tag = 8, _V.v204, _V.v205}
                                      return _V.v206
                                    else
                                      if _next_block == 33 then
                                        _V.v207 = _V.v175[3]
                                        _V.v208 = _V.v175[2]
                                        _V.v209 = _V.v175[1]
                                        _V.v210 = _V.v46(_V.v207, _V.v176)
                                        _V.v211 = {tag = 9, _V.v209, _V.v208, _V.v210}
                                        return _V.v211
                                      else
                                        if _next_block == 34 then
                                          _V.v212 = _V.v175[1]
                                          _V.v213 = _V.v46(_V.v212, _V.v176)
                                          _V.v214 = {tag = 10, _V.v213}
                                          return _V.v214
                                        else
                                          if _next_block == 35 then
                                            _V.v215 = _V.v175[1]
                                            _V.v216 = _V.v46(_V.v215, _V.v176)
                                            _V.v217 = {tag = 11, _V.v216}
                                            return _V.v217
                                          else
                                            if _next_block == 36 then
                                              _V.v218 = _V.v175[1]
                                              _V.v219 = _V.v46(_V.v218, _V.v176)
                                              _V.v220 = {tag = 12, _V.v219}
                                              return _V.v220
                                            else
                                              if _next_block == 37 then
                                                _V.v221 = _V.v175[1]
                                                _V.v222 = _V.v46(_V.v221, _V.v176)
                                                _V.v223 = {tag = 13, _V.v222}
                                                return _V.v223
                                              else
                                                if _next_block == 38 then
                                                  _V.v224 = _V.v175[1]
                                                  _V.v225 = _V.v46(_V.v224, _V.v176)
                                                  _V.v226 = {tag = 14, _V.v225}
                                                  return _V.v226
                                                else
                                                  break
                                                end
                                              end
                                            end
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
        _V.v47 = function(v175, v176)
          -- Hoisted variables (109 total, using inherited _V table)
          _V.v175 = v175
          _V.v176 = v176
          local _next_block = 39
          while true do
            if _next_block == 39 then
              _V.v177 = type(_V.v175) == "number" and _V.v175 % 1 == 0
              if _V.v177 then
                _next_block = 40
              else
                _next_block = 41
              end
            else
              if _next_block == 40 then
                if _V.v175 == 0 then
                  _next_block = 42
                else
                  _next_block = 42
                end
              else
                if _next_block == 41 then
                  _V.v178 = _V.v175.tag or 0
                  if _V.v178 == 0 then
                    _next_block = 43
                  else
                    if _V.v178 == 1 then
                      _next_block = 44
                    else
                      if _V.v178 == 2 then
                        _next_block = 45
                      else
                        if _V.v178 == 3 then
                          _next_block = 46
                        else
                          if _V.v178 == 4 then
                            _next_block = 47
                          else
                            if _V.v178 == 5 then
                              _next_block = 48
                            else
                              if _V.v178 == 6 then
                                _next_block = 49
                              else
                                if _V.v178 == 7 then
                                  _next_block = 50
                                else
                                  if _V.v178 == 8 then
                                    _next_block = 51
                                  else
                                    if _V.v178 == 9 then
                                      _next_block = 52
                                    else
                                      if _V.v178 == 10 then
                                        _next_block = 53
                                      else
                                        if _V.v178 == 11 then
                                          _next_block = 54
                                        else
                                          if _V.v178 == 12 then
                                            _next_block = 55
                                          else
                                            if _V.v178 == 13 then
                                              _next_block = 56
                                            else
                                              if _V.v178 == 14 then
                                                _next_block = 57
                                              else
                                                if _V.v178 == 15 then
                                                  _next_block = 58
                                                else
                                                  if _V.v178 == 16 then
                                                    _next_block = 59
                                                  else
                                                    if _V.v178 == 17 then
                                                      _next_block = 60
                                                    else
                                                      if _V.v178 == 18 then
                                                        _next_block = 61
                                                      else
                                                        if _V.v178 == 19 then
                                                          _next_block = 62
                                                        else
                                                          if _V.v178 == 20 then
                                                            _next_block = 63
                                                          else
                                                            if _V.v178 == 21 then
                                                              _next_block = 64
                                                            else
                                                              if _V.v178 == 22 then
                                                                _next_block = 65
                                                              else
                                                                if _V.v178 == 23 then
                                                                  _next_block = 66
                                                                else
                                                                  if _V.v178 == 24 then
                                                                    _next_block = 67
                                                                  else
                                                                    _next_block = 43
                                                                  end
                                                                end
                                                              end
                                                            end
                                                          end
                                                        end
                                                      end
                                                    end
                                                  end
                                                end
                                              end
                                            end
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                else
                  if _next_block == 42 then
                    return _V.v176
                  else
                    if _next_block == 43 then
                      _V.v179 = _V.v175[1]
                      _V.v180 = _V.v47(_V.v179, _V.v176)
                      _V.v181 = {tag = 0, _V.v180}
                      return _V.v181
                    else
                      if _next_block == 44 then
                        _V.v182 = _V.v175[1]
                        _V.v183 = _V.v47(_V.v182, _V.v176)
                        _V.v184 = {tag = 1, _V.v183}
                        return _V.v184
                      else
                        if _next_block == 45 then
                          _V.v185 = _V.v175[2]
                          _V.v186 = _V.v175[1]
                          _V.v187 = _V.v47(_V.v185, _V.v176)
                          _V.v188 = {tag = 2, _V.v186, _V.v187}
                          return _V.v188
                        else
                          if _next_block == 46 then
                            _V.v189 = _V.v175[2]
                            _V.v190 = _V.v175[1]
                            _V.v191 = _V.v47(_V.v189, _V.v176)
                            _V.v192 = {tag = 3, _V.v190, _V.v191}
                            return _V.v192
                          else
                            if _next_block == 47 then
                              _V.v193 = _V.v175[4]
                              _V.v194 = _V.v175[3]
                              _V.v195 = _V.v175[2]
                              _V.v196 = _V.v175[1]
                              _V.v197 = _V.v47(_V.v193, _V.v176)
                              _V.v198 = {tag = 4, _V.v196, _V.v195, _V.v194, _V.v197}
                              return _V.v198
                            else
                              if _next_block == 48 then
                                _V.v199 = _V.v175[4]
                                _V.v200 = _V.v175[3]
                                _V.v201 = _V.v175[2]
                                _V.v202 = _V.v175[1]
                                _V.v203 = _V.v47(_V.v199, _V.v176)
                                _V.v204 = {tag = 5, _V.v202, _V.v201, _V.v200, _V.v203}
                                return _V.v204
                              else
                                if _next_block == 49 then
                                  _V.v205 = _V.v175[4]
                                  _V.v206 = _V.v175[3]
                                  _V.v207 = _V.v175[2]
                                  _V.v208 = _V.v175[1]
                                  _V.v209 = _V.v47(_V.v205, _V.v176)
                                  _V.v210 = {tag = 6, _V.v208, _V.v207, _V.v206, _V.v209}
                                  return _V.v210
                                else
                                  if _next_block == 50 then
                                    _V.v211 = _V.v175[4]
                                    _V.v212 = _V.v175[3]
                                    _V.v213 = _V.v175[2]
                                    _V.v214 = _V.v175[1]
                                    _V.v215 = _V.v47(_V.v211, _V.v176)
                                    _V.v216 = {tag = 7, _V.v214, _V.v213, _V.v212, _V.v215}
                                    return _V.v216
                                  else
                                    if _next_block == 51 then
                                      _V.v217 = _V.v175[4]
                                      _V.v218 = _V.v175[3]
                                      _V.v219 = _V.v175[2]
                                      _V.v220 = _V.v175[1]
                                      _V.v221 = _V.v47(_V.v217, _V.v176)
                                      _V.v222 = {tag = 8, _V.v220, _V.v219, _V.v218, _V.v221}
                                      return _V.v222
                                    else
                                      if _next_block == 52 then
                                        _V.v223 = _V.v175[2]
                                        _V.v224 = _V.v175[1]
                                        _V.v225 = _V.v47(_V.v223, _V.v176)
                                        _V.v226 = {tag = 9, _V.v224, _V.v225}
                                        return _V.v226
                                      else
                                        if _next_block == 53 then
                                          _V.v227 = _V.v175[1]
                                          _V.v228 = _V.v47(_V.v227, _V.v176)
                                          _V.v229 = {tag = 10, _V.v228}
                                          return _V.v229
                                        else
                                          if _next_block == 54 then
                                            _V.v230 = _V.v175[2]
                                            _V.v231 = _V.v175[1]
                                            _V.v232 = _V.v47(_V.v230, _V.v176)
                                            _V.v233 = {tag = 11, _V.v231, _V.v232}
                                            return _V.v233
                                          else
                                            if _next_block == 55 then
                                              _V.v234 = _V.v175[2]
                                              _V.v235 = _V.v175[1]
                                              _V.v236 = _V.v47(_V.v234, _V.v176)
                                              _V.v237 = {tag = 12, _V.v235, _V.v236}
                                              return _V.v237
                                            else
                                              if _next_block == 56 then
                                                _V.v238 = _V.v175[3]
                                                _V.v239 = _V.v175[2]
                                                _V.v240 = _V.v175[1]
                                                _V.v241 = _V.v47(_V.v238, _V.v176)
                                                _V.v242 = {tag = 13, _V.v240, _V.v239, _V.v241}
                                                return _V.v242
                                              else
                                                if _next_block == 57 then
                                                  _V.v243 = _V.v175[3]
                                                  _V.v244 = _V.v175[2]
                                                  _V.v245 = _V.v175[1]
                                                  _V.v246 = _V.v47(_V.v243, _V.v176)
                                                  _V.v247 = {tag = 14, _V.v245, _V.v244, _V.v246}
                                                  return _V.v247
                                                else
                                                  if _next_block == 58 then
                                                    _V.v248 = _V.v175[1]
                                                    _V.v249 = _V.v47(_V.v248, _V.v176)
                                                    _V.v250 = {tag = 15, _V.v249}
                                                    return _V.v250
                                                  else
                                                    if _next_block == 59 then
                                                      _V.v251 = _V.v175[1]
                                                      _V.v252 = _V.v47(_V.v251, _V.v176)
                                                      _V.v253 = {tag = 16, _V.v252}
                                                      return _V.v253
                                                    else
                                                      if _next_block == 60 then
                                                        _V.v254 = _V.v175[2]
                                                        _V.v255 = _V.v175[1]
                                                        _V.v256 = _V.v47(_V.v254, _V.v176)
                                                        _V.v257 = {tag = 17, _V.v255, _V.v256}
                                                        return _V.v257
                                                      else
                                                        if _next_block == 61 then
                                                          _V.v258 = _V.v175[2]
                                                          _V.v259 = _V.v175[1]
                                                          _V.v260 = _V.v47(_V.v258, _V.v176)
                                                          _V.v261 = {tag = 18, _V.v259, _V.v260}
                                                          return _V.v261
                                                        else
                                                          if _next_block == 62 then
                                                            _V.v262 = _V.v175[1]
                                                            _V.v263 = _V.v47(_V.v262, _V.v176)
                                                            _V.v264 = {tag = 19, _V.v263}
                                                            return _V.v264
                                                          else
                                                            if _next_block == 63 then
                                                              _V.v265 = _V.v175[3]
                                                              _V.v266 = _V.v175[2]
                                                              _V.v267 = _V.v175[1]
                                                              _V.v268 = _V.v47(_V.v265, _V.v176)
                                                              _V.v269 = {tag = 20, _V.v267, _V.v266, _V.v268}
                                                              return _V.v269
                                                            else
                                                              if _next_block == 64 then
                                                                _V.v270 = _V.v175[2]
                                                                _V.v271 = _V.v175[1]
                                                                _V.v272 = _V.v47(_V.v270, _V.v176)
                                                                _V.v273 = {tag = 21, _V.v271, _V.v272}
                                                                return _V.v273
                                                              else
                                                                if _next_block == 65 then
                                                                  _V.v274 = _V.v175[1]
                                                                  _V.v275 = _V.v47(_V.v274, _V.v176)
                                                                  _V.v276 = {tag = 22, _V.v275}
                                                                  return _V.v276
                                                                else
                                                                  if _next_block == 66 then
                                                                    _V.v277 = _V.v175[2]
                                                                    _V.v278 = _V.v175[1]
                                                                    _V.v279 = _V.v47(_V.v277, _V.v176)
                                                                    _V.v280 = {tag = 23, _V.v278, _V.v279}
                                                                    return _V.v280
                                                                  else
                                                                    if _next_block == 67 then
                                                                      _V.v281 = _V.v175[3]
                                                                      _V.v282 = _V.v175[2]
                                                                      _V.v283 = _V.v175[1]
                                                                      _V.v284 = _V.v47(_V.v281, _V.v176)
                                                                      _V.v285 = {tag = 24, _V.v283, _V.v282, _V.v284}
                                                                      return _V.v285
                                                                    else
                                                                      break
                                                                    end
                                                                  end
                                                                end
                                                              end
                                                            end
                                                          end
                                                        end
                                                      end
                                                    end
                                                  end
                                                end
                                              end
                                            end
                                          end
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
        _V.v48 = {tag = 0, _V.v46, _V.v45, _V.v47}
        _V.v49 = 0
        _next_block = 268
      else
        if _next_block == 268 then
          _V.v50 = 199
          _V.v51 = {tag = 0, _V.Invalid_argument, _V.v22}
          _V.v52 = caml_register_named_value(_V.v23, _V.v51)
          _V.v53 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 267
            while true do
              if _next_block == 267 then
                _V.v176 = {tag = 0, _V.Failure, _V.v175}
                error(_V.v176)
              else
                break
              end
            end
          end
          _V.v54 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 266
            while true do
              if _next_block == 266 then
                _V.v176 = {tag = 0, _V.Invalid_argument, _V.v175}
                error(_V.v176)
              else
                break
              end
            end
          end
          _V.v55 = 0
          _V.v56 = caml_fresh_oo_id(_V.v55)
          _V.v57 = {tag = 248, _V.v24, _V.v56}
          _V.v58 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 263
            while true do
              if _next_block == 263 then
                _V.v177 = caml_lessequal(_V.v175, _V.v176)
                if _V.v177 then
                  _next_block = 264
                else
                  _next_block = 265
                end
              else
                if _next_block == 264 then
                  return _V.v175
                else
                  if _next_block == 265 then
                    return _V.v176
                  else
                    break
                  end
                end
              end
            end
          end
          _V.v59 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 260
            while true do
              if _next_block == 260 then
                _V.v177 = caml_greaterequal(_V.v175, _V.v176)
                if _V.v177 then
                  _next_block = 261
                else
                  _next_block = 262
                end
              else
                if _next_block == 261 then
                  return _V.v175
                else
                  if _next_block == 262 then
                    return _V.v176
                  else
                    break
                  end
                end
              end
            end
          end
          _V.v60 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 257
            while true do
              if _next_block == 257 then
                _V.v176 = 0 <= _V.v175
                if _V.v176 then
                  _next_block = 258
                else
                  _next_block = 259
                end
              else
                if _next_block == 258 then
                  return _V.v175
                else
                  if _next_block == 259 then
                    _V.v177 = -_V.v175
                    return _V.v177
                  else
                    break
                  end
                end
              end
            end
          end
          _V.v61 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 256
            while true do
              if _next_block == 256 then
                _V.v176 = -1
                _V.v177 = caml_int_xor(_V.v175, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v62 = 1
          _V.v63 = -1
          _V.v64 = math.floor(_V.v63 / 2 ^ _V.v62)
          _V.v65 = 1
          _V.v66 = _V.v64 + _V.v65
          _V.v67 = caml_int64_float_of_bits(_V.v25)
          _V.v68 = caml_int64_float_of_bits(_V.v26)
          _V.v69 = caml_int64_float_of_bits(_V.v27)
          _V.v70 = caml_int64_float_of_bits(_V.v28)
          _V.v71 = caml_int64_float_of_bits(_V.v29)
          _V.v72 = caml_int64_float_of_bits(_V.v30)
          _V.v73 = function(v175, v176)
            -- Hoisted variables (10 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 255
            while true do
              if _next_block == 255 then
                _V.v177 = caml_ml_string_length(_V.v175)
                _V.v178 = caml_ml_string_length(_V.v176)
                _V.v179 = _V.v177 + _V.v178
                _V.v180 = caml_create_bytes(_V.v179)
                _V.v181 = 0
                _V.v182 = 0
                _V.v183 = caml_blit_string(_V.v175, _V.v182, _V.v180, _V.v181, _V.v177)
                _V.v184 = 0
                _V.v185 = caml_blit_string(_V.v176, _V.v184, _V.v180, _V.v177, _V.v178)
                _V.v186 = caml_string_of_bytes(_V.v180)
                return _V.v186
              else
                break
              end
            end
          end
          _V.v74 = function(v175)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 251
            while true do
              if _next_block == 251 then
                _V.v176 = 0 <= _V.v175
                if _V.v176 then
                  _next_block = 252
                else
                  _V.v179 = _V.v175
                  _V.v180 = _V.v175
                  _next_block = 253
                end
              else
                if _next_block == 252 then
                  _V.v177 = 255 < _V.v175
                  if _V.v177 then
                    _V.v179 = _V.v175
                    _V.v180 = _V.v175
                    _next_block = 253
                  else
                    _next_block = 254
                  end
                else
                  if _next_block == 253 then
                    _V.v178 = _V.v54(_V.v21)
                    return _V.v178
                  else
                    if _next_block == 254 then
                      return _V.v175
                    else
                      break
                    end
                  end
                end
              end
            end
          end
          _V.v75 = function(v175)
            _V.v175 = v175
            local _next_block = 248
            while true do
              if _next_block == 248 then
                if _V.v175 then
                  _next_block = 249
                else
                  _next_block = 250
                end
              else
                if _next_block == 249 then
                  return _V.v19
                else
                  if _next_block == 250 then
                    return _V.v20
                  else
                    break
                  end
                end
              end
            end
          end
          _V.v76 = function(v175)
            -- Hoisted variables (5 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 243
            while true do
              if _next_block == 243 then
                _V.v176 = caml_string_notequal(_V.v175, _V.v16)
                if _V.v176 then
                  _next_block = 244
                else
                  _next_block = 246
                end
              else
                if _next_block == 244 then
                  _V.v177 = caml_string_notequal(_V.v175, _V.v17)
                  if _V.v177 then
                    _next_block = 247
                  else
                    _next_block = 245
                  end
                else
                  if _next_block == 245 then
                    _V.v178 = 1
                    return _V.v178
                  else
                    if _next_block == 246 then
                      _V.v179 = 0
                      return _V.v179
                    else
                      if _next_block == 247 then
                        _V.v180 = _V.v54(_V.v18)
                        return _V.v180
                      else
                        break
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v77 = function(v175)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 238
            while true do
              if _next_block == 238 then
                _V.v176 = caml_string_notequal(_V.v175, _V.v12)
                if _V.v176 then
                  _next_block = 239
                else
                  _next_block = 241
                end
              else
                if _next_block == 239 then
                  _V.v177 = caml_string_notequal(_V.v175, _V.v13)
                  if _V.v177 then
                    _next_block = 242
                  else
                    _next_block = 240
                  end
                else
                  if _next_block == 240 then
                    return _V.v14
                  else
                    if _next_block == 241 then
                      return _V.v15
                    else
                      if _next_block == 242 then
                        _V.v178 = 0
                        return _V.v178
                      else
                        break
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v78 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 237
            while true do
              if _next_block == 237 then
                _V.v176 = caml_format_int(_V.v11, _V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v79 = function(v175)
            -- Hoisted variables (5 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 230
            while true do
              if _next_block == 230 then
                _V.v181 = _V.v175
                _next_block = 231
              else
                if _next_block == 231 then
                  _next_block = 232
                else
                  if _next_block == 232 then
                    _V.v176 = caml_int_of_string(_V.v175)
                    _V.v177 = {tag = 0, _V.v176}
                    _next_block = 233
                  else
                    if _next_block == 233 then
                      return _V.v177
                    else
                      if _next_block == 234 then
                        _V.v178 = _V.v182[1]
                        _V.v179 = _V.v178 == _V.Failure
                        if _V.v179 then
                          _next_block = 235
                        else
                          _next_block = 236
                        end
                      else
                        if _next_block == 235 then
                          _V.v180 = 0
                          return _V.v180
                        else
                          if _next_block == 236 then
                            error(_V.v182)
                          else
                            break
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v80 = function(v175)
            -- Hoisted variables (4 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 229
            while true do
              if _next_block == 229 then
                _V.v176 = caml_ml_string_length(_V.v175)
                _V.v177 = function(v180)
                  -- Hoisted variables (9 total, using inherited _V table)
                  _V.v180 = v180
                  local _next_block = 220
                  while true do
                    if _next_block == 220 then
                      _V.v181 = _V.v176 <= _V.v180
                      if _V.v181 then
                        _next_block = 221
                      else
                        _next_block = 222
                      end
                    else
                      if _next_block == 221 then
                        _V.v182 = _V.v73(_V.v175, _V.v10)
                        return _V.v182
                      else
                        if _next_block == 222 then
                          _V.v183 = caml_string_get(_V.v175, _V.v180)
                          _V.v184 = 48 <= _V.v183
                          if _V.v184 then
                            _next_block = 223
                          else
                            _next_block = 225
                          end
                        else
                          if _next_block == 223 then
                            _V.v185 = 58 <= _V.v183
                            if _V.v185 then
                              _V.v190 = _V.v180
                              _V.v191 = _V.v183
                              _V.v192 = _V.v183
                              _next_block = 227
                            else
                              _next_block = 224
                            end
                          else
                            if _next_block == 224 then
                              _V.v193 = _V.v180
                              _V.v194 = _V.v183
                              _V.v195 = _V.v183
                              _next_block = 228
                            else
                              if _next_block == 225 then
                                _V.v186 = 45 == _V.v183
                                if _V.v186 then
                                  _next_block = 226
                                else
                                  _V.v190 = _V.v180
                                  _V.v191 = _V.v183
                                  _V.v192 = _V.v183
                                  _next_block = 227
                                end
                              else
                                if _next_block == 226 then
                                  _V.v193 = _V.v180
                                  _V.v194 = _V.v183
                                  _V.v195 = _V.v183
                                  _next_block = 228
                                else
                                  if _next_block == 227 then
                                    return _V.v175
                                  else
                                    if _next_block == 228 then
                                      _V.v187 = 1
                                      _V.v188 = _V.v193 + _V.v187
                                      _V.v189 = _V.v177(_V.v188)
                                      return _V.v189
                                    else
                                      break
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
                _V.v178 = 0
                _V.v179 = _V.v177(_V.v178)
                return _V.v179
              else
                break
              end
            end
          end
          _V.v81 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 219
            while true do
              if _next_block == 219 then
                _V.v176 = caml_format_float(_V.v9, _V.v175)
                _V.v177 = _V.v80(_V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v82 = function(v175)
            -- Hoisted variables (5 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 212
            while true do
              if _next_block == 212 then
                _V.v181 = _V.v175
                _next_block = 213
              else
                if _next_block == 213 then
                  _next_block = 214
                else
                  if _next_block == 214 then
                    _V.v176 = caml_float_of_string(_V.v175)
                    _V.v177 = {tag = 0, _V.v176}
                    _next_block = 215
                  else
                    if _next_block == 215 then
                      return _V.v177
                    else
                      if _next_block == 216 then
                        _V.v178 = _V.v182[1]
                        _V.v179 = _V.v178 == _V.Failure
                        if _V.v179 then
                          _next_block = 217
                        else
                          _next_block = 218
                        end
                      else
                        if _next_block == 217 then
                          _V.v180 = 0
                          return _V.v180
                        else
                          if _next_block == 218 then
                            error(_V.v182)
                          else
                            break
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v83 = function(v175, v176)
            -- Hoisted variables (15 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 69
            while true do
              if _next_block == 69 then
                if _V.v175 then
                  _next_block = 70
                else
                  _next_block = 75
                end
              else
                if _next_block == 70 then
                  _V.v177 = _V.v175[2]
                  _V.v178 = _V.v175[1]
                  if _V.v177 then
                    _next_block = 71
                  else
                    _next_block = 74
                  end
                else
                  if _next_block == 71 then
                    _V.v179 = _V.v177[2]
                    _V.v180 = _V.v177[1]
                    if _V.v179 then
                      _next_block = 72
                    else
                      _next_block = 73
                    end
                  else
                    if _next_block == 72 then
                      _V.v181 = _V.v179[2]
                      _V.v182 = _V.v179[1]
                      _V.v183 = 24029
                      _V.v184 = {tag = 0, _V.v182, _V.v183}
                      _V.v185 = 1
                      _V.v186 = _V.v84(_V.v184, _V.v185, _V.v181, _V.v176)
                      _V.v187 = {tag = 0, _V.v180, _V.v184}
                      _V.v188 = {tag = 0, _V.v178, _V.v187}
                      return _V.v188
                    else
                      if _next_block == 73 then
                        _V.v189 = {tag = 0, _V.v180, _V.v176}
                        _V.v190 = {tag = 0, _V.v178, _V.v189}
                        return _V.v190
                      else
                        if _next_block == 74 then
                          _V.v191 = {tag = 0, _V.v178, _V.v176}
                          return _V.v191
                        else
                          if _next_block == 75 then
                            return _V.v176
                          else
                            break
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v84 = function(v175, v176, v177, v178)
            -- Hoisted variables (19 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            _V.v177 = v177
            _V.v178 = v178
            local _next_block = 76
            while true do
              if _next_block == 76 then
                if _V.v177 then
                  _next_block = 77
                else
                  _next_block = 82
                end
              else
                if _next_block == 77 then
                  _V.v179 = _V.v177[2]
                  _V.v180 = _V.v177[1]
                  if _V.v179 then
                    _next_block = 78
                  else
                    _next_block = 81
                  end
                else
                  if _next_block == 78 then
                    _V.v181 = _V.v179[2]
                    _V.v182 = _V.v179[1]
                    if _V.v181 then
                      _next_block = 79
                    else
                      _next_block = 80
                    end
                  else
                    if _next_block == 79 then
                      _V.v183 = _V.v181[2]
                      _V.v184 = _V.v181[1]
                      _V.v185 = 24029
                      _V.v186 = {tag = 0, _V.v184, _V.v185}
                      _V.v187 = {tag = 0, _V.v182, _V.v186}
                      _V.v188 = {tag = 0, _V.v180, _V.v187}
                      _V.v175[_V.v176 + 1] = _V.v188
                      _V.v189 = 0
                      _V.v190 = 1
                      _V.v191 = _V.v84(_V.v186, _V.v190, _V.v183, _V.v178)
                      return _V.v191
                    else
                      if _next_block == 80 then
                        _V.v192 = {tag = 0, _V.v182, _V.v178}
                        _V.v193 = {tag = 0, _V.v180, _V.v192}
                        _V.v175[_V.v176 + 1] = _V.v193
                        _V.v194 = 0
                        return _V.v194
                      else
                        if _next_block == 81 then
                          _V.v195 = {tag = 0, _V.v180, _V.v178}
                          _V.v175[_V.v176 + 1] = _V.v195
                          _V.v196 = 0
                          return _V.v196
                        else
                          if _next_block == 82 then
                            _V.v175[_V.v176 + 1] = _V.v178
                            _V.v197 = 0
                            return _V.v197
                          else
                            break
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v85 = 0
          _V.v86 = caml_ml_open_descriptor_in(_V.v85)
          _V.v87 = 1
          _V.v88 = caml_ml_open_descriptor_out(_V.v87)
          _V.v89 = 2
          _V.v90 = caml_ml_open_descriptor_out(_V.v89)
          _V.v91 = function(v175, v176, v177)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            _V.v177 = v177
            local _next_block = 211
            while true do
              if _next_block == 211 then
                _V.v178 = caml_sys_open(_V.v177, _V.v175, _V.v176)
                _V.v179 = caml_ml_open_descriptor_out(_V.v178)
                _V.v180 = caml_ml_set_channel_name(_V.v179, _V.v177)
                return _V.v179
              else
                break
              end
            end
          end
          _V.v92 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 210
            while true do
              if _next_block == 210 then
                _V.v176 = 438
                _V.v177 = _V.v91(_V.v8, _V.v176, _V.v175)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v93 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 209
            while true do
              if _next_block == 209 then
                _V.v176 = 438
                _V.v177 = _V.v91(_V.v7, _V.v176, _V.v175)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v94 = function(v175)
            -- Hoisted variables (4 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 208
            while true do
              if _next_block == 208 then
                _V.v176 = function(v180)
                  -- Hoisted variables (8 total, using inherited _V table)
                  _V.v180 = v180
                  local _next_block = 197
                  while true do
                    if _next_block == 197 then
                      if _V.v180 then
                        _next_block = 198
                      else
                        _next_block = 207
                      end
                    else
                      if _next_block == 198 then
                        _V.v181 = _V.v180[2]
                        _V.v182 = _V.v180[1]
                        _V.v189 = _V.v180
                        _V.v190 = _V.v181
                        _V.v191 = _V.v182
                        _V.v192 = _V.v182
                        _next_block = 199
                      else
                        if _next_block == 199 then
                          _next_block = 200
                        else
                          if _next_block == 200 then
                            _V.v183 = caml_ml_flush(_V.v182)
                            _next_block = 201
                          else
                            if _next_block == 201 then
                              _V.v193 = _V.v180
                              _V.v194 = _V.v181
                              _V.v195 = _V.v182
                              _V.v196 = _V.v183
                              _next_block = 206
                            else
                              if _next_block == 202 then
                                _V.v184 = _V.v197[1]
                                _V.v185 = _V.v184 == _V.Sys_error
                                if _V.v185 then
                                  _next_block = 203
                                else
                                  _next_block = 204
                                end
                              else
                                if _next_block == 203 then
                                  _V.v186 = 0
                                  _next_block = 205
                                else
                                  if _next_block == 204 then
                                    error(_V.v197)
                                  else
                                    if _next_block == 205 then
                                      _V.v193 = _V.v189
                                      _V.v194 = _V.v190
                                      _V.v195 = _V.v191
                                      _V.v196 = _V.v186
                                      _next_block = 206
                                    else
                                      if _next_block == 206 then
                                        _V.v187 = _V.v176(_V.v194)
                                        return _V.v187
                                      else
                                        if _next_block == 207 then
                                          _V.v188 = 0
                                          return _V.v188
                                        else
                                          break
                                        end
                                      end
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
                _V.v177 = 0
                _V.v178 = caml_ml_out_channels_list(_V.v177)
                _V.v179 = _V.v176(_V.v178)
                return _V.v179
              else
                break
              end
            end
          end
          _V.v95 = function(v175, v176)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 196
            while true do
              if _next_block == 196 then
                _V.v177 = caml_ml_bytes_length(_V.v176)
                _V.v178 = 0
                _V.v179 = caml_ml_output_bytes(_V.v175, _V.v176, _V.v178, _V.v177)
                return _V.v179
              else
                break
              end
            end
          end
          _V.v96 = function(v175, v176)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 195
            while true do
              if _next_block == 195 then
                _V.v177 = caml_ml_string_length(_V.v176)
                _V.v178 = 0
                _V.v179 = caml_ml_output(_V.v175, _V.v176, _V.v178, _V.v177)
                return _V.v179
              else
                break
              end
            end
          end
          _V.v97 = function(v175, v176, v177, v178)
            -- Hoisted variables (7 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            _V.v177 = v177
            _V.v178 = v178
            local _next_block = 190
            while true do
              if _next_block == 190 then
                _V.v179 = 0 <= _V.v177
                if _V.v179 then
                  _next_block = 191
                else
                  _V.v186 = _V.v178
                  _V.v187 = _V.v177
                  _V.v188 = _V.v176
                  _V.v189 = _V.v175
                  _V.v190 = _V.v177
                  _next_block = 193
                end
              else
                if _next_block == 191 then
                  _V.v180 = 0 <= _V.v178
                  if _V.v180 then
                    _next_block = 192
                  else
                    _V.v186 = _V.v178
                    _V.v187 = _V.v177
                    _V.v188 = _V.v176
                    _V.v189 = _V.v175
                    _V.v190 = _V.v178
                    _next_block = 193
                  end
                else
                  if _next_block == 192 then
                    _V.v181 = caml_ml_bytes_length(_V.v176)
                    _V.v182 = _V.v181 - _V.v178
                    _V.v183 = _V.v182 < _V.v177
                    if _V.v183 then
                      _V.v186 = _V.v178
                      _V.v187 = _V.v177
                      _V.v188 = _V.v176
                      _V.v189 = _V.v175
                      _V.v190 = _V.v183
                      _next_block = 193
                    else
                      _next_block = 194
                    end
                  else
                    if _next_block == 193 then
                      _V.v184 = _V.v54(_V.v6)
                      return _V.v184
                    else
                      if _next_block == 194 then
                        _V.v185 = caml_ml_output_bytes(_V.v175, _V.v176, _V.v177, _V.v178)
                        return _V.v185
                      else
                        break
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v98 = function(v175, v176, v177, v178)
            -- Hoisted variables (7 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            _V.v177 = v177
            _V.v178 = v178
            local _next_block = 185
            while true do
              if _next_block == 185 then
                _V.v179 = 0 <= _V.v177
                if _V.v179 then
                  _next_block = 186
                else
                  _V.v186 = _V.v178
                  _V.v187 = _V.v177
                  _V.v188 = _V.v176
                  _V.v189 = _V.v175
                  _V.v190 = _V.v177
                  _next_block = 188
                end
              else
                if _next_block == 186 then
                  _V.v180 = 0 <= _V.v178
                  if _V.v180 then
                    _next_block = 187
                  else
                    _V.v186 = _V.v178
                    _V.v187 = _V.v177
                    _V.v188 = _V.v176
                    _V.v189 = _V.v175
                    _V.v190 = _V.v178
                    _next_block = 188
                  end
                else
                  if _next_block == 187 then
                    _V.v181 = caml_ml_string_length(_V.v176)
                    _V.v182 = _V.v181 - _V.v178
                    _V.v183 = _V.v182 < _V.v177
                    if _V.v183 then
                      _V.v186 = _V.v178
                      _V.v187 = _V.v177
                      _V.v188 = _V.v176
                      _V.v189 = _V.v175
                      _V.v190 = _V.v183
                      _next_block = 188
                    else
                      _next_block = 189
                    end
                  else
                    if _next_block == 188 then
                      _V.v184 = _V.v54(_V.v5)
                      return _V.v184
                    else
                      if _next_block == 189 then
                        _V.v185 = caml_ml_output(_V.v175, _V.v176, _V.v177, _V.v178)
                        return _V.v185
                      else
                        break
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v99 = function(v175, v176)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 184
            while true do
              if _next_block == 184 then
                _V.v177 = 0
                _V.v178 = caml_output_value(_V.v175, _V.v176, _V.v177)
                return _V.v178
              else
                break
              end
            end
          end
          _V.v100 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 183
            while true do
              if _next_block == 183 then
                _V.v176 = caml_ml_flush(_V.v175)
                _V.v177 = caml_ml_close_channel(_V.v175)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v101 = function(v175)
            -- Hoisted variables (4 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 173
            while true do
              if _next_block == 173 then
                _V.v180 = _V.v175
                _next_block = 174
              else
                if _next_block == 174 then
                  _next_block = 175
                else
                  if _next_block == 175 then
                    _V.v176 = caml_ml_flush(_V.v175)
                    _next_block = 176
                  else
                    if _next_block == 176 then
                      _V.v181 = _V.v175
                      _V.v182 = _V.v176
                      _next_block = 178
                    else
                      if _next_block == 177 then
                        _V.v177 = 0
                        _V.v181 = _V.v180
                        _V.v182 = _V.v177
                        _next_block = 178
                      else
                        if _next_block == 178 then
                          _V.v183 = _V.v181
                          _V.v184 = _V.v182
                          _next_block = 179
                        else
                          if _next_block == 179 then
                            _next_block = 180
                          else
                            if _next_block == 180 then
                              _V.v178 = caml_ml_close_channel(_V.v181)
                              _next_block = 181
                            else
                              if _next_block == 181 then
                                return _V.v178
                              else
                                if _next_block == 182 then
                                  _V.v179 = 0
                                  return _V.v179
                                else
                                  break
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v102 = function(v175, v176, v177)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            _V.v177 = v177
            local _next_block = 172
            while true do
              if _next_block == 172 then
                _V.v178 = caml_sys_open(_V.v177, _V.v175, _V.v176)
                _V.v179 = caml_ml_open_descriptor_in(_V.v178)
                _V.v180 = caml_ml_set_channel_name(_V.v179, _V.v177)
                return _V.v179
              else
                break
              end
            end
          end
          _V.v103 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 171
            while true do
              if _next_block == 171 then
                _V.v176 = 0
                _V.v177 = _V.v102(_V.v4, _V.v176, _V.v175)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v104 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 170
            while true do
              if _next_block == 170 then
                _V.v176 = 0
                _V.v177 = _V.v102(_V.v3, _V.v176, _V.v175)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v105 = function(v175, v176, v177, v178)
            -- Hoisted variables (7 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            _V.v177 = v177
            _V.v178 = v178
            local _next_block = 165
            while true do
              if _next_block == 165 then
                _V.v179 = 0 <= _V.v177
                if _V.v179 then
                  _next_block = 166
                else
                  _V.v186 = _V.v178
                  _V.v187 = _V.v177
                  _V.v188 = _V.v176
                  _V.v189 = _V.v175
                  _V.v190 = _V.v177
                  _next_block = 168
                end
              else
                if _next_block == 166 then
                  _V.v180 = 0 <= _V.v178
                  if _V.v180 then
                    _next_block = 167
                  else
                    _V.v186 = _V.v178
                    _V.v187 = _V.v177
                    _V.v188 = _V.v176
                    _V.v189 = _V.v175
                    _V.v190 = _V.v178
                    _next_block = 168
                  end
                else
                  if _next_block == 167 then
                    _V.v181 = caml_ml_bytes_length(_V.v176)
                    _V.v182 = _V.v181 - _V.v178
                    _V.v183 = _V.v182 < _V.v177
                    if _V.v183 then
                      _V.v186 = _V.v178
                      _V.v187 = _V.v177
                      _V.v188 = _V.v176
                      _V.v189 = _V.v175
                      _V.v190 = _V.v183
                      _next_block = 168
                    else
                      _next_block = 169
                    end
                  else
                    if _next_block == 168 then
                      _V.v184 = _V.v54(_V.v2)
                      return _V.v184
                    else
                      if _next_block == 169 then
                        _V.v185 = caml_ml_input(_V.v175, _V.v176, _V.v177, _V.v178)
                        return _V.v185
                      else
                        break
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v106 = function(v175, v176, v177, v178)
            -- Hoisted variables (7 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            _V.v177 = v177
            _V.v178 = v178
            local _next_block = 83
            while true do
              if _next_block == 83 then
                _V.v179 = 0 < _V.v178
                if _V.v179 then
                  _next_block = 85
                else
                  _next_block = 84
                end
              else
                if _next_block == 84 then
                  _V.v180 = 0
                  return _V.v180
                else
                  if _next_block == 85 then
                    _V.v181 = caml_ml_input(_V.v175, _V.v176, _V.v177, _V.v178)
                    _V.v182 = 0 == _V.v181
                    if _V.v182 then
                      _next_block = 86
                    else
                      _next_block = 87
                    end
                  else
                    if _next_block == 86 then
                      error(_V.End_of_file)
                    else
                      if _next_block == 87 then
                        _V.v183 = _V.v178 - _V.v181
                        _V.v184 = _V.v177 + _V.v181
                        _V.v185 = _V.v106(_V.v175, _V.v176, _V.v184, _V.v183)
                        return _V.v185
                      else
                        break
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v107 = function(v175, v176, v177, v178)
            -- Hoisted variables (7 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            _V.v177 = v177
            _V.v178 = v178
            local _next_block = 160
            while true do
              if _next_block == 160 then
                _V.v179 = 0 <= _V.v177
                if _V.v179 then
                  _next_block = 161
                else
                  _V.v186 = _V.v178
                  _V.v187 = _V.v177
                  _V.v188 = _V.v176
                  _V.v189 = _V.v175
                  _V.v190 = _V.v177
                  _next_block = 163
                end
              else
                if _next_block == 161 then
                  _V.v180 = 0 <= _V.v178
                  if _V.v180 then
                    _next_block = 162
                  else
                    _V.v186 = _V.v178
                    _V.v187 = _V.v177
                    _V.v188 = _V.v176
                    _V.v189 = _V.v175
                    _V.v190 = _V.v178
                    _next_block = 163
                  end
                else
                  if _next_block == 162 then
                    _V.v181 = caml_ml_bytes_length(_V.v176)
                    _V.v182 = _V.v181 - _V.v178
                    _V.v183 = _V.v182 < _V.v177
                    if _V.v183 then
                      _V.v186 = _V.v178
                      _V.v187 = _V.v177
                      _V.v188 = _V.v176
                      _V.v189 = _V.v175
                      _V.v190 = _V.v183
                      _next_block = 163
                    else
                      _next_block = 164
                    end
                  else
                    if _next_block == 163 then
                      _V.v184 = _V.v54(_V.v1)
                      return _V.v184
                    else
                      if _next_block == 164 then
                        _V.v185 = _V.v106(_V.v175, _V.v176, _V.v177, _V.v178)
                        return _V.v185
                      else
                        break
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v108 = function(v175, v176)
            -- Hoisted variables (4 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 159
            while true do
              if _next_block == 159 then
                _V.v177 = caml_create_bytes(_V.v176)
                _V.v178 = 0
                _V.v179 = _V.v107(_V.v175, _V.v177, _V.v178, _V.v176)
                _V.v180 = caml_string_of_bytes(_V.v177)
                return _V.v180
              else
                break
              end
            end
          end
          _V.v109 = function(v175)
            -- Hoisted variables (6 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 158
            while true do
              if _next_block == 158 then
                _V.v176 = function(v182, v183, v184)
                  -- Hoisted variables (8 total, using inherited _V table)
                  _V.v182 = v182
                  _V.v183 = v183
                  _V.v184 = v184
                  local _next_block = 146
                  while true do
                    if _next_block == 146 then
                      if _V.v184 then
                        _next_block = 147
                      else
                        _next_block = 148
                      end
                    else
                      if _next_block == 147 then
                        _V.v185 = _V.v184[2]
                        _V.v186 = _V.v184[1]
                        _V.v187 = caml_ml_bytes_length(_V.v186)
                        _V.v188 = _V.v183 - _V.v187
                        _V.v189 = 0
                        _V.v190 = caml_blit_bytes(_V.v186, _V.v189, _V.v182, _V.v188, _V.v187)
                        _V.v191 = _V.v183 - _V.v187
                        _V.v192 = _V.v176(_V.v182, _V.v191, _V.v185)
                        return _V.v192
                      else
                        if _next_block == 148 then
                          return _V.v182
                        else
                          break
                        end
                      end
                    end
                  end
                end
                _V.v177 = function(v182, v183)
                  -- Hoisted variables (30 total, using inherited _V table)
                  _V.v182 = v182
                  _V.v183 = v183
                  local _next_block = 149
                  while true do
                    if _next_block == 149 then
                      _V.v184 = caml_ml_input_scan_line(_V.v175)
                      _V.v185 = 0 == _V.v184
                      if _V.v185 then
                        _next_block = 150
                      else
                        _next_block = 153
                      end
                    else
                      if _next_block == 150 then
                        if _V.v182 then
                          _next_block = 151
                        else
                          _next_block = 152
                        end
                      else
                        if _next_block == 151 then
                          _V.v186 = caml_create_bytes(_V.v183)
                          _V.v187 = _V.v176(_V.v186, _V.v183, _V.v182)
                          return _V.v187
                        else
                          if _next_block == 152 then
                            error(_V.End_of_file)
                          else
                            if _next_block == 153 then
                              _V.v188 = 0 < _V.v184
                              if _V.v188 then
                                _next_block = 154
                              else
                                _next_block = 157
                              end
                            else
                              if _next_block == 154 then
                                _V.v189 = -1
                                _V.v190 = _V.v184 + _V.v189
                                _V.v191 = caml_create_bytes(_V.v190)
                                _V.v192 = -1
                                _V.v193 = _V.v184 + _V.v192
                                _V.v194 = 0
                                _V.v195 = caml_ml_input(_V.v175, _V.v191, _V.v194, _V.v193)
                                _V.v196 = 0
                                _V.v197 = caml_ml_input_char(_V.v175)
                                _V.v198 = 0
                                if _V.v182 then
                                  _next_block = 155
                                else
                                  _next_block = 156
                                end
                              else
                                if _next_block == 155 then
                                  _V.v199 = _V.v183 + _V.v184
                                  _V.v200 = -1
                                  _V.v201 = _V.v199 + _V.v200
                                  _V.v202 = {tag = 0, _V.v191, _V.v182}
                                  _V.v203 = caml_create_bytes(_V.v201)
                                  _V.v204 = _V.v176(_V.v203, _V.v201, _V.v202)
                                  return _V.v204
                                else
                                  if _next_block == 156 then
                                    return _V.v191
                                  else
                                    if _next_block == 157 then
                                      _V.v205 = -_V.v184
                                      _V.v206 = caml_create_bytes(_V.v205)
                                      _V.v207 = -_V.v184
                                      _V.v208 = 0
                                      _V.v209 = caml_ml_input(_V.v175, _V.v206, _V.v208, _V.v207)
                                      _V.v210 = 0
                                      _V.v211 = _V.v183 - _V.v184
                                      _V.v212 = {tag = 0, _V.v206, _V.v182}
                                      _V.v213 = _V.v177(_V.v212, _V.v211)
                                      return _V.v213
                                    else
                                      break
                                    end
                                  end
                                end
                              end
                            end
                          end
                        end
                      end
                    end
                  end
                end
                _V.v178 = 0
                _V.v179 = 0
                _V.v180 = _V.v177(_V.v179, _V.v178)
                _V.v181 = caml_string_of_bytes(_V.v180)
                return _V.v181
              else
                break
              end
            end
          end
          _V.v110 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 141
            while true do
              if _next_block == 141 then
                _V.v178 = _V.v175
                _next_block = 142
              else
                if _next_block == 142 then
                  _next_block = 143
                else
                  if _next_block == 143 then
                    _V.v176 = caml_ml_close_channel(_V.v175)
                    _next_block = 144
                  else
                    if _next_block == 144 then
                      return _V.v176
                    else
                      if _next_block == 145 then
                        _V.v177 = 0
                        return _V.v177
                      else
                        break
                      end
                    end
                  end
                end
              end
            end
          end
          _V.v111 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 140
            while true do
              if _next_block == 140 then
                _V.v176 = caml_ml_output_char(_V.v88, _V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v112 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 139
            while true do
              if _next_block == 139 then
                _V.v176 = _V.v96(_V.v88, _V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v113 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 138
            while true do
              if _next_block == 138 then
                _V.v176 = _V.v95(_V.v88, _V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v114 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 137
            while true do
              if _next_block == 137 then
                _V.v176 = _V.v78(_V.v175)
                _V.v177 = _V.v96(_V.v88, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v115 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 136
            while true do
              if _next_block == 136 then
                _V.v176 = _V.v81(_V.v175)
                _V.v177 = _V.v96(_V.v88, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v116 = function(v175)
            -- Hoisted variables (4 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 135
            while true do
              if _next_block == 135 then
                _V.v176 = _V.v96(_V.v88, _V.v175)
                _V.v177 = 10
                _V.v178 = caml_ml_output_char(_V.v88, _V.v177)
                _V.v179 = caml_ml_flush(_V.v88)
                return _V.v179
              else
                break
              end
            end
          end
          _V.v117 = function(v175)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 134
            while true do
              if _next_block == 134 then
                _V.v176 = 10
                _V.v177 = caml_ml_output_char(_V.v88, _V.v176)
                _V.v178 = caml_ml_flush(_V.v88)
                return _V.v178
              else
                break
              end
            end
          end
          _V.v118 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 133
            while true do
              if _next_block == 133 then
                _V.v176 = caml_ml_output_char(_V.v90, _V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v119 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 132
            while true do
              if _next_block == 132 then
                _V.v176 = _V.v96(_V.v90, _V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v120 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 131
            while true do
              if _next_block == 131 then
                _V.v176 = _V.v95(_V.v90, _V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v121 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 130
            while true do
              if _next_block == 130 then
                _V.v176 = _V.v78(_V.v175)
                _V.v177 = _V.v96(_V.v90, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v122 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 129
            while true do
              if _next_block == 129 then
                _V.v176 = _V.v81(_V.v175)
                _V.v177 = _V.v96(_V.v90, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v123 = function(v175)
            -- Hoisted variables (4 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 128
            while true do
              if _next_block == 128 then
                _V.v176 = _V.v96(_V.v90, _V.v175)
                _V.v177 = 10
                _V.v178 = caml_ml_output_char(_V.v90, _V.v177)
                _V.v179 = caml_ml_flush(_V.v90)
                return _V.v179
              else
                break
              end
            end
          end
          _V.v124 = function(v175)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 127
            while true do
              if _next_block == 127 then
                _V.v176 = 10
                _V.v177 = caml_ml_output_char(_V.v90, _V.v176)
                _V.v178 = caml_ml_flush(_V.v90)
                return _V.v178
              else
                break
              end
            end
          end
          _V.v125 = function(v175)
            -- Hoisted variables (2 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 126
            while true do
              if _next_block == 126 then
                _V.v176 = caml_ml_flush(_V.v88)
                _V.v177 = _V.v109(_V.v86)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v126 = function(v175)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 125
            while true do
              if _next_block == 125 then
                _V.v176 = 0
                _V.v177 = _V.v125(_V.v176)
                _V.v178 = caml_int_of_string(_V.v177)
                return _V.v178
              else
                break
              end
            end
          end
          _V.v127 = function(v175)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 124
            while true do
              if _next_block == 124 then
                _V.v176 = 0
                _V.v177 = _V.v125(_V.v176)
                _V.v178 = _V.v79(_V.v177)
                return _V.v178
              else
                break
              end
            end
          end
          _V.v128 = function(v175)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 123
            while true do
              if _next_block == 123 then
                _V.v176 = 0
                _V.v177 = _V.v125(_V.v176)
                _V.v178 = caml_float_of_string(_V.v177)
                return _V.v178
              else
                break
              end
            end
          end
          _V.v129 = function(v175)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 122
            while true do
              if _next_block == 122 then
                _V.v176 = 0
                _V.v177 = _V.v125(_V.v176)
                _V.v178 = _V.v82(_V.v177)
                return _V.v178
              else
                break
              end
            end
          end
          _V.v130 = {tag = 0}
          _V.v131 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 121
            while true do
              if _next_block == 121 then
                _V.v176 = _V.v175[2]
                return _V.v176
              else
                break
              end
            end
          end
          _V.v132 = function(v175, v176)
            -- Hoisted variables (9 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 120
            while true do
              if _next_block == 120 then
                _V.v177 = _V.v176[2]
                _V.v178 = _V.v176[1]
                _V.v179 = _V.v175[2]
                _V.v180 = _V.v175[1]
                _V.v181 = _V.v73(_V.v0, _V.v177)
                _V.v182 = _V.v73(_V.v179, _V.v181)
                _V.v183 = _V.v48[3]
                _V.v184 = _V.v183(_V.v180, _V.v178)
                _V.v185 = {tag = 0, _V.v184, _V.v182}
                return _V.v185
              else
                break
              end
            end
          end
          _V.v133 = {tag = 0, _V.v94}
          _V.v134 = function(v175)
            -- Hoisted variables (7 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 91
            while true do
              if _next_block == 91 then
                _V.v176 = 1
                _V.v177 = {tag = 0, _V.v176}
                _V.v178 = caml_atomic_load(_V.v133)
                _V.v179 = function(v183)
                  -- Hoisted variables (7 total, using inherited _V table)
                  _V.v183 = v183
                  local _next_block = 88
                  while true do
                    if _next_block == 88 then
                      _V.v184 = 0
                      _V.v185 = 1
                      _V.v186 = caml_atomic_cas(_V.v177, _V.v185, _V.v184)
                      if _V.v186 then
                        _next_block = 89
                      else
                        _V.v191 = _V.v183
                        _V.v192 = _V.v186
                        _next_block = 90
                      end
                    else
                      if _next_block == 89 then
                        _V.v187 = 0
                        _V.v188 = _V.v175(_V.v187)
                        _V.v191 = _V.v183
                        _V.v192 = _V.v188
                        _next_block = 90
                      else
                        if _next_block == 90 then
                          _V.v189 = 0
                          _V.v190 = _V.v178(_V.v189)
                          return _V.v190
                        else
                          break
                        end
                      end
                    end
                  end
                end
                _V.v180 = caml_atomic_cas(_V.v133, _V.v178, _V.v179)
                _V.v181 = not _V.v180
                if _V.v181 then
                  _next_block = 92
                else
                  _next_block = 93
                end
              else
                if _next_block == 92 then
                  _V.v182 = _V.v134(_V.v175)
                  return _V.v182
                else
                  if _next_block == 93 then
                    return _V.v181
                  else
                    break
                  end
                end
              end
            end
          end
          _V.v135 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 119
            while true do
              if _next_block == 119 then
                _V.v176 = 0
                return _V.v176
              else
                break
              end
            end
          end
          _V.v136 = {tag = 0, _V.v135}
          _V.v137 = function(v175)
            -- Hoisted variables (6 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 118
            while true do
              if _next_block == 118 then
                _V.v176 = 0
                _V.v177 = _V.v136[1]
                _V.v178 = _V.v177(_V.v176)
                _V.v179 = 0
                _V.v180 = caml_atomic_load(_V.v133)
                _V.v181 = _V.v180(_V.v179)
                return _V.v181
              else
                break
              end
            end
          end
          _V.v138 = function(v175)
            -- Hoisted variables (3 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 117
            while true do
              if _next_block == 117 then
                _V.v176 = 0
                _V.v177 = _V.v137(_V.v176)
                _V.v178 = caml_sys_exit(_V.v175)
                return _V.v178
              else
                break
              end
            end
          end
          _V.v139 = caml_register_named_value(_V.v31, _V.v137)
          _V.v140 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 116
            while true do
              if _next_block == 116 then
                _V.v176 = caml_ml_channel_size_64(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v141 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 115
            while true do
              if _next_block == 115 then
                _V.v176 = caml_ml_pos_in_64(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v142 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 114
            while true do
              if _next_block == 114 then
                _V.v177 = caml_ml_seek_in_64(_V.v175, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v143 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 113
            while true do
              if _next_block == 113 then
                _V.v176 = caml_ml_channel_size_64(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v144 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 112
            while true do
              if _next_block == 112 then
                _V.v176 = caml_ml_pos_out_64(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v145 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 111
            while true do
              if _next_block == 111 then
                _V.v177 = caml_ml_seek_out_64(_V.v175, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v146 = {tag = 0, _V.v145, _V.v144, _V.v143, _V.v142, _V.v141, _V.v140}
          _V.v147 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 110
            while true do
              if _next_block == 110 then
                _V.v177 = caml_ml_set_binary_mode(_V.v175, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v148 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 109
            while true do
              if _next_block == 109 then
                _V.v176 = caml_ml_close_channel(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v149 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 108
            while true do
              if _next_block == 108 then
                _V.v176 = caml_ml_channel_size(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v150 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 107
            while true do
              if _next_block == 107 then
                _V.v176 = caml_ml_pos_in(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v151 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 106
            while true do
              if _next_block == 106 then
                _V.v177 = caml_ml_seek_in(_V.v175, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v152 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 105
            while true do
              if _next_block == 105 then
                _V.v176 = caml_input_value(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v153 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 104
            while true do
              if _next_block == 104 then
                _V.v176 = caml_ml_input_int(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v154 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 103
            while true do
              if _next_block == 103 then
                _V.v176 = caml_ml_input_char(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v155 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 102
            while true do
              if _next_block == 102 then
                _V.v176 = caml_ml_input_char(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v156 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 101
            while true do
              if _next_block == 101 then
                _V.v177 = caml_ml_set_binary_mode(_V.v175, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v157 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 100
            while true do
              if _next_block == 100 then
                _V.v176 = caml_ml_channel_size(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v158 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 99
            while true do
              if _next_block == 99 then
                _V.v176 = caml_ml_pos_out(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v159 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 98
            while true do
              if _next_block == 98 then
                _V.v177 = caml_ml_seek_out(_V.v175, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v160 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 97
            while true do
              if _next_block == 97 then
                _V.v177 = caml_ml_output_int(_V.v175, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v161 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 96
            while true do
              if _next_block == 96 then
                _V.v177 = caml_ml_output_char(_V.v175, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v162 = function(v175, v176)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            _V.v176 = v176
            local _next_block = 95
            while true do
              if _next_block == 95 then
                _V.v177 = caml_ml_output_char(_V.v175, _V.v176)
                return _V.v177
              else
                break
              end
            end
          end
          _V.v163 = function(v175)
            -- Hoisted variables (1 total, using inherited _V table)
            _V.v175 = v175
            local _next_block = 94
            while true do
              if _next_block == 94 then
                _V.v176 = caml_ml_flush(_V.v175)
                return _V.v176
              else
                break
              end
            end
          end
          _V.v164 = {tag = 0, _V.v54, _V.v53, _V.v57, _V.Match_failure, _V.Assert_failure, _V.Invalid_argument, _V.Failure, _V.Not_found, _V.Out_of_memory, _V.Stack_overflow, _V.Sys_error, _V.End_of_file, _V.Division_by_zero, _V.Sys_blocked_io, _V.Undefined_recursive_module, _V.v58, _V.v59, _V.v60, _V.v64, _V.v66, _V.v61, _V.v67, _V.v68, _V.v69, _V.v70, _V.v71, _V.v72, _V.v73, _V.v74, _V.v75, _V.v77, _V.v76, _V.v78, _V.v79, _V.v81, _V.v82, _V.v83, _V.v86, _V.v88, _V.v90, _V.v111, _V.v112, _V.v113, _V.v114, _V.v115, _V.v116, _V.v117, _V.v118, _V.v119, _V.v120, _V.v121, _V.v122, _V.v123, _V.v124, _V.v125, _V.v127, _V.v126, _V.v129, _V.v128, _V.v92, _V.v93, _V.v91, _V.v163, _V.v94, _V.v162, _V.v96, _V.v95, _V.v97, _V.v98, _V.v161, _V.v160, _V.v99, _V.v159, _V.v158, _V.v157, _V.v100, _V.v101, _V.v156, _V.v103, _V.v104, _V.v102, _V.v155, _V.v109, _V.v105, _V.v107, _V.v108, _V.v154, _V.v153, _V.v152, _V.v151, _V.v150, _V.v149, _V.v148, _V.v110, _V.v147, _V.v146, _V.v131, _V.v132, _V.v138, _V.v134, _V.v80, _V.v106, _V.v137, _V.v136}
          _V.v165 = 0
          _V.v166 = _V.v164[46]
          _V.v167 = _V.v166(_V.v32)
          _V.v168 = {tag = 0}
          _V.v169 = 0
          _V.v170 = 0
          _V.v171 = _V.v164[103]
          _V.v172 = _V.v171(_V.v170)
          _V.v173 = {tag = 0}
          _V.v174 = 0
          return nil
        else
          break
        end
      end
    end
  end
end
__caml_init__()
