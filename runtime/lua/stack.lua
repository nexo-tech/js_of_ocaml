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