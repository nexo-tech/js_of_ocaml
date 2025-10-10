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
--Requires: caml_ocaml_string_to_lua, caml_buffer_add_string
function caml_buffer_add_printf(buffer, fmt, ...)
  local format = package.loaded.format or require("format")

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
          local formatted = format.caml_format_int("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "f" or conv == "F" or conv == "e" or conv == "E" or conv == "g" or conv == "G" then
        if arg_idx <= #args then
          local formatted = format.caml_format_float("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "s" then
        if arg_idx <= #args then
          local formatted = format.caml_format_string("%" .. spec, args[arg_idx])
          table.insert(result_parts, caml_ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "c" then
        if arg_idx <= #args then
          local formatted = format.caml_format_char("%" .. spec, args[arg_idx])
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
