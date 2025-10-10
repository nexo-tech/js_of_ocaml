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
