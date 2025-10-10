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

-- FIFO Queue implementation
-- Efficient first-in-first-out queue operations

-- Queue object
local Queue = {}
Queue.__index = Queue

-- Create a new empty queue
-- Returns: queue object
--Provides: caml_queue_create
function caml_queue_create()
  local queue = {
    -- Array of elements
    elements = {},
    -- Head index (next element to dequeue)
    head = 1,
    -- Tail index (next position to enqueue)
    tail = 1,
    -- Current length
    length = 0
  }

  setmetatable(queue, Queue)
  return queue
end

-- Add an element to the end of the queue (enqueue)
-- queue: queue object
-- value: element to add
--Provides: caml_queue_add
function caml_queue_add(queue, value)
  queue.elements[queue.tail] = value
  queue.tail = queue.tail + 1
  queue.length = queue.length + 1
end

-- Remove and return the first element from the queue (dequeue)
-- queue: queue object
-- Returns: first element
-- Raises: error if queue is empty
--Provides: caml_queue_take
function caml_queue_take(queue)
  if queue.length == 0 then
    error("Queue.Empty")
  end

  local value = queue.elements[queue.head]
  queue.elements[queue.head] = nil  -- Allow garbage collection
  queue.head = queue.head + 1
  queue.length = queue.length - 1

  -- Optimize: reset indices when queue becomes empty
  if queue.length == 0 then
    queue.head = 1
    queue.tail = 1
  end

  return value
end

-- Return the first element without removing it (peek)
-- queue: queue object
-- Returns: first element
-- Raises: error if queue is empty
--Provides: caml_queue_peek
function caml_queue_peek(queue)
  if queue.length == 0 then
    error("Queue.Empty")
  end

  return queue.elements[queue.head]
end

-- Check if queue is empty
-- queue: queue object
-- Returns: true if empty, false otherwise
--Provides: caml_queue_is_empty
function caml_queue_is_empty(queue)
  return queue.length == 0
end

-- Get the number of elements in the queue
-- queue: queue object
-- Returns: number of elements
--Provides: caml_queue_length
function caml_queue_length(queue)
  return queue.length
end

-- Remove all elements from the queue
-- queue: queue object
--Provides: caml_queue_clear
function caml_queue_clear(queue)
  queue.elements = {}
  queue.head = 1
  queue.tail = 1
  queue.length = 0
end

-- Iterator for queue elements (from front to back)
-- queue: queue object
-- Returns: iterator function
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

-- Convert queue to array (for debugging/testing)
-- queue: queue object
-- Returns: array of elements in order
--Provides: caml_queue_to_array
function caml_queue_to_array(queue)
  local result = {}
  for i = queue.head, queue.tail - 1 do
    table.insert(result, queue.elements[i])
  end
  return result
end
