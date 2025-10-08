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

-- Helper: Convert OCaml string to Lua string
local function ocaml_string_to_lua(s)
  if type(s) == "string" then
    return s
  end
  -- OCaml string is a byte array
  local chars = {}
  for i = 1, #s do
    table.insert(chars, string.char(s[i]))
  end
  return table.concat(chars)
end

-- Helper: Convert Lua string to OCaml string (byte array)
local function lua_string_to_ocaml(s)
  local result = {}
  for i = 1, #s do
    result[i] = s:byte(i)
  end
  return result
end

-- Helper: Repeat a string n times
local function str_repeat(n, s)
  local result = {}
  for i = 1, n do
    table.insert(result, s)
  end
  return table.concat(result)
end

-- Format an integer according to format specification
-- fmt: OCaml string (byte array) or Lua string
-- i: integer value
-- Returns: OCaml string (byte array)
function M.caml_format_int(fmt, i)
  local fmt_str = ocaml_string_to_lua(fmt)

  -- Fast path for simple %d
  if fmt_str == "%d" then
    return lua_string_to_ocaml(tostring(i))
  end

  local f = M.caml_parse_format(fmt)

  -- Handle negative numbers
  if i < 0 then
    if f.signedconv then
      f.sign = -1
      i = -i
    else
      -- Unsigned conversion of negative number
      -- In Lua, we need to handle this carefully
      -- For 32-bit integers: add 2^32
      i = i + 4294967296  -- 2^32
    end
  end

  -- Convert to string in the appropriate base
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

  -- Apply precision (minimum number of digits)
  if f.prec >= 0 then
    f.filler = " "
    local n = f.prec - #s
    if n > 0 then
      s = str_repeat(n, "0") .. s
    end
  end

  return M.caml_finish_formatting(f, s)
end

-- Format a float according to format specification
-- fmt: OCaml string (byte array) or Lua string
-- x: float value
-- Returns: OCaml string (byte array)
function M.caml_format_float(fmt, x)
  local f = M.caml_parse_format(fmt)
  local prec = f.prec < 0 and 6 or f.prec

  -- Handle sign
  if x < 0 or (x == 0 and 1/x == -math.huge) then
    f.sign = -1
    x = -x
  end

  local s

  -- Handle special values
  if x ~= x then  -- NaN
    s = "nan"
    f.filler = " "
  elseif x == math.huge then  -- Infinity
    s = "inf"
    f.filler = " "
  else
    -- Format according to conversion type
    if f.conv == "e" then
      -- Exponential notation
      s = string.format("%." .. prec .. "e", x)
      -- Ensure exponent has at least two digits
      s = s:gsub("e([+-])(%d)$", "e%10%2")
    elseif f.conv == "f" then
      -- Fixed-point notation
      s = string.format("%." .. prec .. "f", x)
    elseif f.conv == "g" then
      -- General format (use exponential or fixed, whichever is shorter)
      local effective_prec = prec > 0 and prec or 1

      -- Try exponential first to get the exponent
      local exp_str = string.format("%." .. (effective_prec - 1) .. "e", x)
      local exp_val = tonumber(exp_str:match("e([+-]%d+)$"))

      if exp_val and (exp_val < -4 or x >= 1e21 or #string.format("%.0f", x) > effective_prec) then
        -- Use exponential notation
        s = exp_str
        -- Remove trailing zeros
        s = s:gsub("(%d)0+e", "%1e")
        s = s:gsub("%.e", "e")
        -- Ensure exponent has at least two digits
        s = s:gsub("e([+-])(%d)$", "e%10%2")
      else
        -- Use fixed-point notation
        local p = effective_prec
        if exp_val and exp_val < 0 then
          p = p - exp_val - 1
          s = string.format("%." .. p .. "f", x)
        else
          -- Find appropriate precision
          repeat
            s = string.format("%." .. p .. "f", x)
            if #s <= effective_prec + 1 then break end
            p = p - 1
          until p < 0
        end

        if p > 0 then
          -- Remove trailing zeros
          s = s:gsub("0+$", "")
          s = s:gsub("%.$", "")
        end
      end
    else
      -- Default to fixed-point
      s = string.format("%." .. prec .. "f", x)
    end
  end

  return M.caml_finish_formatting(f, s)
end

-- Format a string according to format specification
-- fmt: OCaml string (byte array) or Lua string
-- s: OCaml string (byte array) or Lua string
-- Returns: OCaml string (byte array)
function M.caml_format_string(fmt, s)
  local f = M.caml_parse_format(fmt)
  local str = ocaml_string_to_lua(s)

  -- Apply precision (maximum length)
  if f.prec >= 0 and #str > f.prec then
    str = str:sub(1, f.prec)
  end

  -- Apply width
  local len = #str
  local buffer = ""

  if f.justify == "+" and len < f.width then
    -- Right justify
    buffer = str_repeat(f.width - len, " ") .. str
  elseif f.justify == "-" and len < f.width then
    -- Left justify
    buffer = str .. str_repeat(f.width - len, " ")
  else
    buffer = str
  end

  return lua_string_to_ocaml(buffer)
end

-- Format a character according to format specification
-- fmt: OCaml string (byte array) or Lua string
-- c: integer (character code) or single-char string
-- Returns: OCaml string (byte array)
function M.caml_format_char(fmt, c)
  local f = M.caml_parse_format(fmt)

  -- Convert to character
  local char
  if type(c) == "number" then
    char = string.char(c)
  elseif type(c) == "string" then
    char = c:sub(1, 1)
  elseif type(c) == "table" and #c == 1 then
    -- OCaml string with single char
    char = string.char(c[1])
  else
    char = " "
  end

  -- Apply width
  local buffer = ""
  if f.justify == "+" and 1 < f.width then
    -- Right justify
    buffer = str_repeat(f.width - 1, " ") .. char
  elseif f.justify == "-" and 1 < f.width then
    -- Left justify
    buffer = char .. str_repeat(f.width - 1, " ")
  else
    buffer = char
  end

  return lua_string_to_ocaml(buffer)
end

return M
