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

-- LIFO Stack implementation
-- Efficient last-in-first-out stack operations

-- Stack object
local Stack = {}
Stack.__index = Stack

-- Create a new empty stack
-- Returns: stack object
--Provides: caml_stack_create
function caml_stack_create()
  local stack = {
    -- Array of elements (top is at the end)
    elements = {},
    -- Current length
    length = 0
  }

  setmetatable(stack, Stack)
  return stack
end

-- Push an element onto the stack
-- stack: stack object
-- value: element to push
--Provides: caml_stack_push
function caml_stack_push(stack, value)
  stack.length = stack.length + 1
  stack.elements[stack.length] = value
end

-- Pop and return the top element from the stack
-- stack: stack object
-- Returns: top element
-- Raises: error if stack is empty
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

-- Return the top element without removing it
-- stack: stack object
-- Returns: top element
-- Raises: error if stack is empty
--Provides: caml_stack_top
function caml_stack_top(stack)
  if stack.length == 0 then
    error("Stack.Empty")
  end

  return stack.elements[stack.length]
end

-- Check if stack is empty
-- stack: stack object
-- Returns: true if empty, false otherwise
--Provides: caml_stack_is_empty
function caml_stack_is_empty(stack)
  return stack.length == 0
end

-- Get the number of elements in the stack
-- stack: stack object
-- Returns: number of elements
--Provides: caml_stack_length
function caml_stack_length(stack)
  return stack.length
end

-- Remove all elements from the stack
-- stack: stack object
--Provides: caml_stack_clear
function caml_stack_clear(stack)
  stack.elements = {}
  stack.length = 0
end

-- Iterator for stack elements (from top to bottom)
-- stack: stack object
-- Returns: iterator function
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

-- Convert stack to array (for debugging/testing)
-- stack: stack object
-- Returns: array of elements from bottom to top
--Provides: caml_stack_to_array
function caml_stack_to_array(stack)
  local result = {}
  for i = 1, stack.length do
    table.insert(result, stack.elements[i])
  end
  return result
end
