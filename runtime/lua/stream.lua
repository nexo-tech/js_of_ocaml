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

--- Stream Module
--
-- Provides lazy stream operations for on-demand sequence processing.
-- Streams are lazy sequences where elements are computed only when needed.

local core = require("core")

local M = {}

-- Stream structure:
-- {
--   data = {
--     state = "empty" | "cons" | "thunk",
--     -- For "cons": head = <value>, tail = <stream>
--     -- For "thunk": func = <function>, args = <table>
--   }
-- }

--- Raise Stream.Failure exception
local function raise_failure()
  local fail = require("fail")
  -- Stream.Failure is a standard OCaml exception
  error("Stream.Failure")
end

--- Force evaluation of a stream thunk
-- @param stream table Stream
-- @return string New state ("empty" or "cons")
local function force(stream)
  local data = stream.data
  if data.state == "thunk" then
    -- Evaluate the thunk
    local func = data.func
    local result = func()

    -- Update stream with result
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

--- Create empty stream
-- @param _unit number Unit value
-- @return table Empty stream
function M.caml_stream_empty(_unit)
  return {
    data = {
      state = "empty"
    }
  }
end

--- Peek at first element without consuming
-- @param stream table Stream
-- @return any|nil First element or nil if empty
function M.caml_stream_peek(stream)
  local state = force(stream)
  if state == "empty" then
    return nil
  else
    return stream.data.head
  end
end

--- Get and remove first element
-- @param stream table Stream
-- @return any First element (raises Failure if empty)
function M.caml_stream_next(stream)
  local state = force(stream)
  if state == "empty" then
    raise_failure()
  end

  local head = stream.data.head
  local tail = stream.data.tail

  -- Update stream to point to tail
  if tail then
    stream.data = tail.data
  else
    stream.data = { state = "empty" }
  end

  return head
end

--- Remove first element without returning it
-- @param stream table Stream
-- @return number Unit value
function M.caml_stream_junk(stream)
  local state = force(stream)
  if state == "empty" then
    raise_failure()
  end

  local tail = stream.data.tail

  -- Update stream to point to tail
  if tail then
    stream.data = tail.data
  else
    stream.data = { state = "empty" }
  end

  return core.unit
end

--- Peek at N elements without consuming
-- @param n number Number of elements to peek
-- @param stream table Stream
-- @return table OCaml list of peeked elements
function M.caml_stream_npeek(n, stream)
  local result = {tag = 0}  -- Empty list initially
  local current = stream
  local count = 0

  while count < n do
    local state = force(current)
    if state == "empty" then
      break
    end

    -- Build list (in reverse order, then reverse at end)
    table.insert(result, current.data.head)
    count = count + 1

    current = current.data.tail
    if not current then
      break
    end
  end

  -- Convert to OCaml list (reverse order)
  local ocaml_list = {tag = 0}  -- Empty list: []
  for i = #result, 1, -1 do
    ocaml_list = {tag = 0, [1] = result[i], [2] = ocaml_list}
  end

  return ocaml_list
end

--- Check if stream is empty
-- @param stream table Stream
-- @return number 1 (true) or 0 (false)
function M.caml_stream_is_empty(stream)
  local state = force(stream)
  if state == "empty" then
    return core.true_val
  else
    return core.false_val
  end
end

--- Create stream from function
-- @param func function Generator function (returns value or nil)
-- @return table Stream
function M.caml_stream_from(func)
  local function thunk()
    local value = func()
    if value == nil then
      return nil
    else
      return {
        head = value,
        tail = M.caml_stream_from(func)
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

--- Create stream from list
-- @param list table OCaml list
-- @return table Stream
function M.caml_stream_of_list(list)
  if list.tag == 0 and not list[1] then
    -- Empty list
    return M.caml_stream_empty(core.unit)
  end

  local function thunk()
    if list.tag == 0 and not list[1] then
      return nil
    else
      return {
        head = list[1],
        tail = M.caml_stream_of_list(list[2] or {tag = 0})
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

--- Create stream from string
-- @param str string String to stream
-- @return table Stream of characters
function M.caml_stream_of_string(str)
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

  return M.caml_stream_from(generator)
end

--- Create stream from channel
-- @param chan number Channel ID
-- @return table Stream of characters
function M.caml_stream_of_channel(chan)
  local function generator()
    -- Lazy load io module to avoid circular dependency
    local io = require("io")

    -- Try to read one character
    local ok, result = pcall(io.caml_ml_input_char, chan)
    if ok then
      return result
    else
      return nil  -- EOF or error
    end
  end

  return M.caml_stream_from(generator)
end

--- Cons: prepend element to stream
-- @param head any Element to prepend
-- @param tail table Stream tail
-- @return table New stream
function M.caml_stream_cons(head, tail)
  return {
    data = {
      state = "cons",
      head = head,
      tail = tail
    }
  }
end

--- Create stream from array
-- @param arr table OCaml array
-- @return table Stream
function M.caml_stream_of_array(arr)
  local len = arr[0]  -- Length is stored at index 0
  local pos = 1  -- Start at Lua index 1 (OCaml index 0)

  local function generator()
    if pos > len then
      return nil
    end
    local value = arr[pos]
    pos = pos + 1
    return value
  end

  return M.caml_stream_from(generator)
end

--- Iterate over stream elements
-- @param f function Function to call for each element
-- @param stream table Stream
-- @return number Unit value
function M.caml_stream_iter(f, stream)
  while true do
    local state = force(stream)
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

  return core.unit
end

--- Count elements in stream (consumes stream)
-- @param stream table Stream
-- @return number Number of elements
function M.caml_stream_count(stream)
  local count = 0
  while true do
    local state = force(stream)
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

-- Register primitives
core.register("caml_stream_empty", M.caml_stream_empty)
core.register("caml_stream_peek", M.caml_stream_peek)
core.register("caml_stream_next", M.caml_stream_next)
core.register("caml_stream_junk", M.caml_stream_junk)
core.register("caml_stream_npeek", M.caml_stream_npeek)
core.register("caml_stream_is_empty", M.caml_stream_is_empty)
core.register("caml_stream_from", M.caml_stream_from)
core.register("caml_stream_of_list", M.caml_stream_of_list)
core.register("caml_stream_of_string", M.caml_stream_of_string)
core.register("caml_stream_of_channel", M.caml_stream_of_channel)
core.register("caml_stream_cons", M.caml_stream_cons)
core.register("caml_stream_of_array", M.caml_stream_of_array)
core.register("caml_stream_iter", M.caml_stream_iter)
core.register("caml_stream_count", M.caml_stream_count)

return M
