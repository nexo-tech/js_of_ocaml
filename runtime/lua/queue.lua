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