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

-- Scanf-style parsing functions

-- Skip whitespace in input string starting at position pos
-- Returns new position after whitespace
local function skip_whitespace(s, pos)
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

-- Parse an integer from string starting at position pos
-- Returns: value, new_position or nil, error_position
function M.caml_scan_int(s, pos, fmt)
  pos = pos or 1
  local str = ocaml_string_to_lua(s)
  local f = M.caml_parse_format(fmt or "%d")

  -- Skip leading whitespace
  pos = skip_whitespace(str, pos)

  if pos > #str then
    return nil, pos
  end

  -- Parse sign
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

  -- Determine base
  local base = f.base
  if base == 0 then
    base = 10
  end

  -- Check for base prefix (0x, 0o, 0b)
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

  -- Parse digits
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

-- Parse a float from string starting at position pos
-- Returns: value, new_position or nil, error_position
function M.caml_scan_float(s, pos)
  pos = pos or 1
  local str = ocaml_string_to_lua(s)

  -- Skip leading whitespace
  pos = skip_whitespace(str, pos)

  if pos > #str then
    return nil, pos
  end

  -- Try to match a float pattern
  -- Pattern: [+-]?(\d+\.?\d*|\d*\.\d+)([eE][+-]?\d+)?
  local start_pos = pos
  local sign_str = ""
  local int_part = ""
  local frac_part = ""
  local exp_part = ""

  -- Parse sign
  local c = str:sub(pos, pos)
  if c == "-" or c == "+" then
    sign_str = c
    pos = pos + 1
  end

  -- Check for special values
  if str:sub(pos, pos + 2) == "nan" or str:sub(pos, pos + 2) == "NaN" then
    return 0/0, pos + 3
  end
  -- Check for infinity (longer first)
  if str:sub(pos, pos + 7) == "infinity" or str:sub(pos, pos + 7) == "Infinity" then
    return (sign_str == "-" and -math.huge or math.huge), pos + 8
  end
  if str:sub(pos, pos + 2) == "inf" or str:sub(pos, pos + 2) == "Inf" then
    return (sign_str == "-" and -math.huge or math.huge), pos + 3
  end

  -- Parse integer part
  while pos <= #str do
    c = str:sub(pos, pos)
    if c >= "0" and c <= "9" then
      int_part = int_part .. c
      pos = pos + 1
    else
      break
    end
  end

  -- Parse decimal point and fractional part
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

  -- Must have at least integer or fractional part
  if int_part == "" and frac_part == "" then
    return nil, start_pos
  end

  -- Parse exponent
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

  -- Build the number string and convert
  local num_str = sign_str .. (int_part ~= "" and int_part or "0") ..
                  (frac_part ~= "" and ("." .. frac_part) or "") .. exp_part
  local value = tonumber(num_str)

  if value then
    return value, pos
  else
    return nil, start_pos
  end
end

-- Parse a string from input starting at position pos
-- For Scanf %s: reads non-whitespace characters
-- width: maximum number of characters to read (from format precision)
-- Returns: string, new_position or nil, error_position
function M.caml_scan_string(s, pos, width)
  pos = pos or 1
  local str = ocaml_string_to_lua(s)

  -- Skip leading whitespace
  pos = skip_whitespace(str, pos)

  if pos > #str then
    return nil, pos
  end

  -- Read non-whitespace characters
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

-- Parse a character from input starting at position pos
-- Returns: character (as byte value), new_position or nil, error_position
function M.caml_scan_char(s, pos, skip_ws)
  pos = pos or 1
  local str = ocaml_string_to_lua(s)

  -- Optionally skip leading whitespace (for %c with space before)
  if skip_ws then
    pos = skip_whitespace(str, pos)
  end

  if pos > #str then
    return nil, pos
  end

  local c = str:byte(pos)
  return c, pos + 1
end

-- Simple sscanf-like function
-- Scans a string according to a format
-- Returns: table of parsed values or nil on error
function M.caml_sscanf(input, fmt)
  local str = ocaml_string_to_lua(input)
  local fmt_str = ocaml_string_to_lua(fmt)

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
        local value, new_pos = M.caml_scan_int(str, pos, "%" .. conv)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "f" or conv == "e" or conv == "g" then
        local value, new_pos = M.caml_scan_float(str, pos)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "s" then
        local value, new_pos = M.caml_scan_string(str, pos)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "c" then
        local value, new_pos = M.caml_scan_char(str, pos, false)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "%" then
        -- Literal %
        pos = skip_whitespace(str, pos)
        if str:sub(pos, pos) ~= "%" then
          return nil
        end
        pos = pos + 1
      else
        -- Unsupported format
        return nil
      end

      fmt_pos = fmt_pos + 1
    elseif c == " " or c == "\t" or c == "\n" or c == "\r" then
      -- Whitespace in format matches any whitespace in input
      pos = skip_whitespace(str, pos)
      fmt_pos = fmt_pos + 1
    else
      -- Literal character must match
      pos = skip_whitespace(str, pos)
      if str:sub(pos, pos) ~= c then
        return nil
      end
      pos = pos + 1
      fmt_pos = fmt_pos + 1
    end
  end

  return results
end

-- Channel I/O integration
-- These functions require lazy loading of the io module to avoid circular dependencies

-- Printf-style channel output functions

-- Format and output to a channel
-- chanid: channel ID from io.lua
-- fmt: format string (OCaml string or Lua string)
-- ...: values to format
function M.caml_fprintf(chanid, fmt, ...)
  -- Lazy load io module
  local io_module = package.loaded.io or require("io")

  local fmt_str = ocaml_string_to_lua(fmt)
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

      -- Parse format specifier
      local spec_start = i - 1
      local spec = ""

      -- Collect flags, width, precision, and conversion
      while i <= #fmt_str do
        local ch = fmt_str:sub(i, i)
        spec = spec .. ch
        i = i + 1

        -- Check if we hit a conversion character
        if ch:match("[diouxXeEfFgGaAcspn%%]") then
          break
        end
      end

      local conv = spec:sub(-1)

      if conv == "%" then
        table.insert(result_parts, "%")
      elseif conv == "d" or conv == "i" or conv == "u" or conv == "x" or conv == "X" or conv == "o" then
        if arg_idx <= #args then
          local formatted = M.caml_format_int("%" .. spec, args[arg_idx])
          table.insert(result_parts, ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "f" or conv == "F" or conv == "e" or conv == "E" or conv == "g" or conv == "G" then
        if arg_idx <= #args then
          local formatted = M.caml_format_float("%" .. spec, args[arg_idx])
          table.insert(result_parts, ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "s" then
        if arg_idx <= #args then
          local formatted = M.caml_format_string("%" .. spec, args[arg_idx])
          table.insert(result_parts, ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      elseif conv == "c" then
        if arg_idx <= #args then
          local formatted = M.caml_format_char("%" .. spec, args[arg_idx])
          table.insert(result_parts, ocaml_string_to_lua(formatted))
          arg_idx = arg_idx + 1
        end
      end
    else
      table.insert(result_parts, c)
      i = i + 1
    end
  end

  -- Write result to channel
  local output = table.concat(result_parts)
  local output_bytes = lua_string_to_ocaml(output)
  io_module.caml_ml_output_bytes(chanid, output_bytes, 0, #output_bytes)
  io_module.caml_ml_flush(chanid)

  return 0  -- Unit in OCaml
end

-- Format and output to stdout
function M.caml_printf(fmt, ...)
  -- Lazy load io module
  local io_module = package.loaded.io or require("io")
  -- stdout channel is typically 1
  local stdout_chanid = io_module.caml_ml_open_descriptor_out(1)
  return M.caml_fprintf(stdout_chanid, fmt, ...)
end

-- Format and output to stderr
function M.caml_eprintf(fmt, ...)
  -- Lazy load io module
  local io_module = package.loaded.io or require("io")
  -- stderr channel is typically 2
  local stderr_chanid = io_module.caml_ml_open_descriptor_out(2)
  return M.caml_fprintf(stderr_chanid, fmt, ...)
end

-- Scanf-style channel input functions

-- Read a line from channel and scan according to format
-- chanid: channel ID from io.lua
-- fmt: format string (OCaml string or Lua string)
-- Returns: table of parsed values or nil on error
function M.caml_fscanf(chanid, fmt)
  -- Lazy load io module
  local io_module = package.loaded.io or require("io")

  -- Scan line to get the length
  local line_len = io_module.caml_ml_input_scan_line(chanid)
  if not line_len or line_len <= 0 then
    return nil
  end

  -- Read the actual line data
  local line_bytes = {}
  local actual_len = io_module.caml_ml_input(chanid, line_bytes, 0, math.abs(line_len))

  if actual_len <= 0 then
    return nil
  end

  -- Convert to Lua string
  local line = ocaml_string_to_lua(line_bytes)

  -- Parse using sscanf
  return M.caml_sscanf(line, fmt)
end

-- Read a line from stdin and scan according to format
function M.caml_scanf(fmt)
  -- Lazy load io module
  local io_module = package.loaded.io or require("io")
  -- stdin channel is typically 0
  local stdin_chanid = io_module.caml_ml_open_descriptor_in(0)
  return M.caml_fscanf(stdin_chanid, fmt)
end

return M
