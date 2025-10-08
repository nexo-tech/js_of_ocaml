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

-- Format string parsing and formatting for Printf/Scanf support

local M = {}

-- Parse a format string into a format specification
-- Returns a table with fields: justify, signstyle, filler, alternate, base,
-- signedconv, width, uppercase, sign, prec, conv
function M.caml_parse_format(fmt)
  if type(fmt) == "table" then
    -- OCaml string (bytes array)
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
      -- Parse width
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
      -- Parse precision
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
      -- Unknown character, skip it
      i = i + 1
    end
  end

  return f
end

-- Finish formatting by applying width, padding, and sign
-- Returns an OCaml string (bytes array)
function M.caml_finish_formatting(f, rawbuffer)
  if f.uppercase then
    rawbuffer = rawbuffer:upper()
  end

  local len = #rawbuffer

  -- Adjust len to reflect additional chars (sign, etc)
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

  -- Build the formatted string
  local buffer = ""

  -- Right justify with space padding
  if f.justify == "+" and f.filler == " " then
    for i = len + 1, f.width do
      buffer = buffer .. " "
    end
  end

  -- Add sign
  if f.signedconv then
    if f.sign < 0 then
      buffer = buffer .. "-"
    elseif f.signstyle ~= "-" then
      buffer = buffer .. f.signstyle
    end
  end

  -- Add alternate prefix
  if f.alternate and f.base == 8 then
    buffer = buffer .. "0"
  end
  if f.alternate and f.base == 16 then
    buffer = buffer .. (f.uppercase and "0X" or "0x")
  end

  -- Right justify with zero padding
  if f.justify == "+" and f.filler == "0" then
    for i = len + 1, f.width do
      buffer = buffer .. "0"
    end
  end

  -- Add the actual content
  buffer = buffer .. rawbuffer

  -- Left justify
  if f.justify == "-" then
    for i = len + 1, f.width do
      buffer = buffer .. " "
    end
  end

  -- Convert to OCaml string (bytes array)
  local result = {}
  for i = 1, #buffer do
    result[i] = buffer:byte(i)
  end
  return result
end

return M
