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


--Provides: caml_parse_format
function caml_parse_format(fmt)
  if type(fmt) == "table" then
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
      i = i + 1
    end
  end

  return f
end

--Provides: caml_finish_formatting
function caml_finish_formatting(f, rawbuffer)
  if f.uppercase then
    rawbuffer = rawbuffer:upper()
  end

  local len = #rawbuffer

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

  local buffer = ""

  if f.justify == "+" and f.filler == " " then
    for i = len + 1, f.width do
      buffer = buffer .. " "
    end
  end

  if f.signedconv then
    if f.sign < 0 then
      buffer = buffer .. "-"
    elseif f.signstyle ~= "-" then
      buffer = buffer .. f.signstyle
    end
  end

  if f.alternate and f.base == 8 then
    buffer = buffer .. "0"
  end
  if f.alternate and f.base == 16 then
    buffer = buffer .. (f.uppercase and "0X" or "0x")
  end

  if f.justify == "+" and f.filler == "0" then
    for i = len + 1, f.width do
      buffer = buffer .. "0"
    end
  end

  buffer = buffer .. rawbuffer

  if f.justify == "-" then
    for i = len + 1, f.width do
      buffer = buffer .. " "
    end
  end

  local result = {}
  for i = 1, #buffer do
    result[i] = buffer:byte(i)
  end
  return result
end

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

--Provides: caml_lua_string_to_ocaml
function caml_lua_string_to_ocaml(s)
  local result = {}
  for i = 1, #s do
    result[i] = s:byte(i)
  end
  result.length = #s
  return result
end

--Provides: caml_str_repeat
function caml_str_repeat(n, s)
  local result = {}
  for i = 1, n do
    table.insert(result, s)
  end
  return table.concat(result)
end

--Provides: caml_skip_whitespace
function caml_skip_whitespace(s, pos)
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

--Provides: caml_format_int
--Requires: caml_ocaml_string_to_lua, caml_lua_string_to_ocaml, caml_parse_format, caml_str_repeat, caml_finish_formatting
function caml_format_int(fmt, i)
  local fmt_str = caml_ocaml_string_to_lua(fmt)

  if fmt_str == "%d" then
    return caml_lua_string_to_ocaml(tostring(i))
  end

  local f = caml_parse_format(fmt)

  if i < 0 then
    if f.signedconv then
      f.sign = -1
      i = -i
    else
      i = i + 4294967296  -- 2^32
    end
  end

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

  if f.prec >= 0 then
    f.filler = " "
    local n = f.prec - #s
    if n > 0 then
      s = caml_str_repeat(n, "0") .. s
    end
  end

  return caml_finish_formatting(f, s)
end

--Provides: caml_format_int_special
--Requires: caml_lua_string_to_ocaml
function caml_format_int_special(i)
  -- Special fast path for integer to string conversion
  -- Used by print_int and similar functions
  return caml_lua_string_to_ocaml(tostring(i))
end

--Provides: caml_format_float
--Requires: caml_parse_format, caml_finish_formatting
function caml_format_float(fmt, x)
  local f = caml_parse_format(fmt)
  local prec = f.prec < 0 and 6 or f.prec

  if x < 0 or (x == 0 and 1/x == -math.huge) then
    f.sign = -1
    x = -x
  end

  local s

  if x ~= x then  -- NaN
    s = "nan"
    f.filler = " "
  elseif x == math.huge then  -- Infinity
    s = "inf"
    f.filler = " "
  else
    if f.conv == "e" then
      s = string.format("%." .. prec .. "e", x)
      s = s:gsub("e([+-])(%d)$", "e%10%2")
    elseif f.conv == "f" then
      s = string.format("%." .. prec .. "f", x)
    elseif f.conv == "g" then
      local effective_prec = prec > 0 and prec or 1

      local exp_str = string.format("%." .. (effective_prec - 1) .. "e", x)
      local exp_val = tonumber(exp_str:match("e([+-]%d+)$"))

      if exp_val and (exp_val < -4 or x >= 1e21 or #string.format("%.0f", x) > effective_prec) then
        s = exp_str
        s = s:gsub("(%d)0+e", "%1e")
        s = s:gsub("%.e", "e")
        s = s:gsub("e([+-])(%d)$", "e%10%2")
      else
        local p = effective_prec
        if exp_val and exp_val < 0 then
          p = p - exp_val - 1
          s = string.format("%." .. p .. "f", x)
        else
          repeat
            s = string.format("%." .. p .. "f", x)
            if #s <= effective_prec + 1 then break end
            p = p - 1
          until p < 0
        end

        if p > 0 then
          s = s:gsub("0+$", "")
          s = s:gsub("%.$", "")
        end
      end
    else
      s = string.format("%." .. prec .. "f", x)
    end
  end

  return caml_finish_formatting(f, s)
end

--Provides: caml_format_string
--Requires: caml_parse_format, caml_ocaml_string_to_lua, caml_str_repeat, caml_lua_string_to_ocaml
function caml_format_string(fmt, s)
  local f = caml_parse_format(fmt)
  local str = caml_ocaml_string_to_lua(s)

  if f.prec >= 0 and #str > f.prec then
    str = str:sub(1, f.prec)
  end

  local len = #str
  local buffer = ""

  if f.justify == "+" and len < f.width then
    buffer = caml_str_repeat(f.width - len, " ") .. str
  elseif f.justify == "-" and len < f.width then
    buffer = str .. caml_str_repeat(f.width - len, " ")
  else
    buffer = str
  end

  return caml_lua_string_to_ocaml(buffer)
end

--Provides: caml_format_char
--Requires: caml_parse_format, caml_str_repeat, caml_lua_string_to_ocaml
function caml_format_char(fmt, c)
  local f = caml_parse_format(fmt)

  local char
  if type(c) == "number" then
    char = string.char(c)
  elseif type(c) == "string" then
    char = c:sub(1, 1)
  elseif type(c) == "table" and #c == 1 then
    char = string.char(c[1])
  else
    char = " "
  end

  local buffer = ""
  if f.justify == "+" and 1 < f.width then
    buffer = caml_str_repeat(f.width - 1, " ") .. char
  elseif f.justify == "-" and 1 < f.width then
    buffer = char .. caml_str_repeat(f.width - 1, " ")
  else
    buffer = char
  end

  return caml_lua_string_to_ocaml(buffer)
end

--Provides: caml_scan_int
--Requires: caml_ocaml_string_to_lua, caml_parse_format, caml_skip_whitespace
function caml_scan_int(s, pos, fmt)
  pos = pos or 1
  local str = caml_ocaml_string_to_lua(s)
  local f = caml_parse_format(fmt or "%d")

  pos = caml_skip_whitespace(str, pos)

  if pos > #str then
    return nil, pos
  end

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

  local base = f.base
  if base == 0 then
    base = 10
  end

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

--Provides: caml_scan_float
--Requires: caml_ocaml_string_to_lua, caml_skip_whitespace
function caml_scan_float(s, pos)
  pos = pos or 1
  local str = caml_ocaml_string_to_lua(s)

  pos = caml_skip_whitespace(str, pos)

  if pos > #str then
    return nil, pos
  end

  local start_pos = pos
  local sign_str = ""
  local int_part = ""
  local frac_part = ""
  local exp_part = ""

  local c = str:sub(pos, pos)
  if c == "-" or c == "+" then
    sign_str = c
    pos = pos + 1
  end

  if str:sub(pos, pos + 2) == "nan" or str:sub(pos, pos + 2) == "NaN" then
    return 0/0, pos + 3
  end
  if str:sub(pos, pos + 7) == "infinity" or str:sub(pos, pos + 7) == "Infinity" then
    return (sign_str == "-" and -math.huge or math.huge), pos + 8
  end
  if str:sub(pos, pos + 2) == "inf" or str:sub(pos, pos + 2) == "Inf" then
    return (sign_str == "-" and -math.huge or math.huge), pos + 3
  end

  while pos <= #str do
    c = str:sub(pos, pos)
    if c >= "0" and c <= "9" then
      int_part = int_part .. c
      pos = pos + 1
    else
      break
    end
  end

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

  if int_part == "" and frac_part == "" then
    return nil, start_pos
  end

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

  local num_str = sign_str .. (int_part ~= "" and int_part or "0") ..
                  (frac_part ~= "" and ("." .. frac_part) or "") .. exp_part
  local value = tonumber(num_str)

  if value then
    return value, pos
  else
    return nil, start_pos
  end
end

--Provides: caml_scan_string
--Requires: caml_ocaml_string_to_lua, caml_skip_whitespace
function caml_scan_string(s, pos, width)
  pos = pos or 1
  local str = caml_ocaml_string_to_lua(s)

  pos = caml_skip_whitespace(str, pos)

  if pos > #str then
    return nil, pos
  end

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

--Provides: caml_scan_char
--Requires: caml_ocaml_string_to_lua, caml_skip_whitespace
function caml_scan_char(s, pos, skip_ws)
  pos = pos or 1
  local str = caml_ocaml_string_to_lua(s)

  if skip_ws then
    pos = caml_skip_whitespace(str, pos)
  end

  if pos > #str then
    return nil, pos
  end

  local c = str:byte(pos)
  return c, pos + 1
end

--Provides: caml_sscanf
--Requires: caml_ocaml_string_to_lua, caml_scan_int, caml_scan_float, caml_scan_string, caml_scan_char, caml_skip_whitespace
function caml_sscanf(input, fmt)
  local str = caml_ocaml_string_to_lua(input)
  local fmt_str = caml_ocaml_string_to_lua(fmt)

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
        local value, new_pos = caml_scan_int(str, pos, "%" .. conv)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "f" or conv == "e" or conv == "g" then
        local value, new_pos = caml_scan_float(str, pos)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "s" then
        local value, new_pos = caml_scan_string(str, pos)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "c" then
        local value, new_pos = caml_scan_char(str, pos, false)
        if not value then
          return nil
        end
        table.insert(results, value)
        pos = new_pos
      elseif conv == "%" then
        pos = caml_skip_whitespace(str, pos)
        if str:sub(pos, pos) ~= "%" then
          return nil
        end
        pos = pos + 1
      else
        return nil
      end

      fmt_pos = fmt_pos + 1
    elseif c == " " or c == "\t" or c == "\n" or c == "\r" then
      pos = caml_skip_whitespace(str, pos)
      fmt_pos = fmt_pos + 1
    else
      pos = caml_skip_whitespace(str, pos)
      if str:sub(pos, pos) ~= c then
        return nil
      end
      pos = pos + 1
      fmt_pos = fmt_pos + 1
    end
  end

  return results
end

-- NOTE: caml_printf, caml_fprintf, caml_eprintf are NOT provided here.
-- The OCaml compiler generates its own Printf code from the stdlib that uses
-- low-level primitives like caml_ml_output directly. Providing these here would
-- conflict with the compiled OCaml version.

--Provides: caml_fscanf
--Requires: caml_ocaml_string_to_lua, caml_sscanf
function caml_fscanf(chanid, fmt)
  local io_module = package.loaded.io or require("io")

  local line_len = caml_ml_input_scan_line(chanid)
  if not line_len or line_len <= 0 then
    return nil
  end

  local line_bytes = {}
  local actual_len = caml_ml_input(chanid, line_bytes, 0, math.abs(line_len))

  if actual_len <= 0 then
    return nil
  end

  local line = caml_ocaml_string_to_lua(line_bytes)

  return caml_sscanf(line, fmt)
end

--Provides: caml_scanf
--Requires: caml_fscanf
function caml_scanf(fmt)
  local io_module = package.loaded.io or require("io")
  local stdin_chanid = caml_ml_open_descriptor_in(0)
  return caml_fscanf(stdin_chanid, fmt)
end
