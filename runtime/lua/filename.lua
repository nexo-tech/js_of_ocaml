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

--Provides: caml_filename_os_type
function caml_filename_os_type()
  if package.config:sub(1, 1) == '\\' then
    return "Win32"
  else
    return "Unix"
  end
end

--Provides: caml_filename_dir_sep
--Requires: caml_filename_os_type
function caml_filename_dir_sep(_unit)
  return caml_filename_os_type() == "Win32" and "\\" or "/"
end

--Provides: caml_filename_is_dir_sep
--Requires: caml_filename_os_type
function caml_filename_is_dir_sep(c)
  if caml_filename_os_type() == "Win32" then
    return c == '\\' or c == '/'
  else
    return c == '/'
  end
end

--Provides: caml_filename_concat
--Requires: caml_filename_os_type caml_filename_is_dir_sep caml_filename_dir_sep
function caml_filename_concat(dir, file)
  local dir_str = dir
  local file_str = file
  local os_type = caml_filename_os_type()
  local dir_sep = caml_filename_dir_sep(0)

  -- Handle empty cases
  if dir_str == "" then
    return file_str
  end
  if file_str == "" then
    return dir_str
  end

  -- Check if file is absolute (should return file unchanged)
  -- Unix: starts with /
  -- Windows: starts with \ or / or drive letter (C:\)
  if os_type == "Win32" then
    if caml_filename_is_dir_sep(file_str:sub(1, 1)) then
      return file_str
    end
    -- Check for drive letter (C:)
    if file_str:match("^%a:") then
      return file_str
    end
  else
    if file_str:sub(1, 1) == '/' then
      return file_str
    end
  end

  -- Add separator if dir doesn't end with one
  local last_char = dir_str:sub(-1)
  if caml_filename_is_dir_sep(last_char) then
    return dir_str .. file_str
  else
    return dir_str .. dir_sep .. file_str
  end
end

--Provides: caml_filename_basename
--Requires: caml_filename_is_dir_sep caml_filename_os_type
function caml_filename_basename(name)
  local name_str = name
  local os_type = caml_filename_os_type()

  if name_str == "" then
    return ""
  end

  -- Remove trailing separators
  while #name_str > 1 and caml_filename_is_dir_sep(name_str:sub(-1)) do
    name_str = name_str:sub(1, -2)
  end

  -- Special case: root directory
  if name_str == "/" or (os_type == "Win32" and name_str:match("^%a:[\\/]?$")) then
    return name_str
  end

  -- Find last separator
  local last_sep = 0
  for i = #name_str, 1, -1 do
    if caml_filename_is_dir_sep(name_str:sub(i, i)) then
      last_sep = i
      break
    end
  end

  if last_sep == 0 then
    return name_str
  else
    return name_str:sub(last_sep + 1)
  end
end

--Provides: caml_filename_dirname
--Requires: caml_filename_is_dir_sep caml_filename_os_type caml_filename_dir_sep
function caml_filename_dirname(name)
  local name_str = name
  local os_type = caml_filename_os_type()
  local dir_sep = caml_filename_dir_sep(0)

  if name_str == "" then
    return "."
  end

  -- Remove trailing separators
  while #name_str > 1 and caml_filename_is_dir_sep(name_str:sub(-1)) do
    name_str = name_str:sub(1, -2)
  end

  -- Special case: root directory
  if name_str == "/" then
    return "/"
  end
  if os_type == "Win32" and name_str:match("^%a:[\\/]?$") then
    return name_str
  end

  -- Find last separator
  local last_sep = 0
  for i = #name_str, 1, -1 do
    if caml_filename_is_dir_sep(name_str:sub(i, i)) then
      last_sep = i
      break
    end
  end

  if last_sep == 0 then
    return "."
  elseif last_sep == 1 then
    return "/"
  else
    -- Remove trailing separator from dirname
    local result = name_str:sub(1, last_sep - 1)
    if result == "" then
      return "/"
    end
    -- Windows drive letter case
    if os_type == "Win32" and result:match("^%a:$") then
      return result .. dir_sep
    end
    return result
  end
end

--Provides: caml_filename_check_suffix
function caml_filename_check_suffix(name, suff)
  local name_str = name
  local suff_str = suff

  if #suff_str > #name_str then
    return 0
  end

  if #suff_str == 0 then
    return 1
  end

  local name_end = name_str:sub(-#suff_str)
  if name_end == suff_str then
    return 1
  else
    return 0
  end
end

--Provides: caml_filename_chop_suffix
--Requires: caml_invalid_argument
function caml_filename_chop_suffix(name, suff)
  local name_str = name
  local suff_str = suff

  if #suff_str > #name_str then
    caml_invalid_argument("Filename.chop_suffix")
  end

  if #suff_str == 0 then
    return name_str
  end

  local name_end = name_str:sub(-#suff_str)
  if name_end == suff_str then
    return name_str:sub(1, -#suff_str - 1)
  else
    caml_invalid_argument("Filename.chop_suffix")
  end
end

--Provides: caml_filename_chop_extension
--Requires: caml_filename_is_dir_sep caml_invalid_argument
function caml_filename_chop_extension(name)
  local name_str = name

  -- Find last dot
  local last_dot = 0
  local last_sep = 0

  for i = #name_str, 1, -1 do
    local c = name_str:sub(i, i)
    if c == '.' and last_dot == 0 then
      last_dot = i
    end
    if caml_filename_is_dir_sep(c) then
      last_sep = i
      break
    end
  end

  -- No dot found, or dot is before last separator, or dot is first character
  if last_dot == 0 or last_dot <= last_sep or last_dot == 1 then
    caml_invalid_argument("Filename.chop_extension")
  end

  return name_str:sub(1, last_dot - 1)
end

--Provides: caml_filename_extension
--Requires: caml_filename_is_dir_sep
function caml_filename_extension(name)
  local name_str = name

  -- Find last dot
  local last_dot = 0
  local last_sep = 0

  for i = #name_str, 1, -1 do
    local c = name_str:sub(i, i)
    if c == '.' and last_dot == 0 then
      last_dot = i
    end
    if caml_filename_is_dir_sep(c) then
      last_sep = i
      break
    end
  end

  -- No dot found, or dot is before last separator, or dot is first character
  if last_dot == 0 or last_dot <= last_sep or last_dot == 1 then
    return ""
  end

  return name_str:sub(last_dot)
end

--Provides: caml_filename_remove_extension
--Requires: caml_filename_is_dir_sep
function caml_filename_remove_extension(name)
  local name_str = name

  -- Find last dot
  local last_dot = 0
  local last_sep = 0

  for i = #name_str, 1, -1 do
    local c = name_str:sub(i, i)
    if c == '.' and last_dot == 0 then
      last_dot = i
    end
    if caml_filename_is_dir_sep(c) then
      last_sep = i
      break
    end
  end

  -- No dot found, or dot is before last separator, or dot is first character
  if last_dot == 0 or last_dot <= last_sep or last_dot == 1 then
    return name_str
  end

  return name_str:sub(1, last_dot - 1)
end

--Provides: caml_filename_is_relative
--Requires: caml_filename_os_type caml_filename_is_dir_sep
function caml_filename_is_relative(name)
  local name_str = name
  local os_type = caml_filename_os_type()

  if name_str == "" then
    return 1
  end

  if os_type == "Win32" then
    -- Absolute if starts with separator or drive letter
    if caml_filename_is_dir_sep(name_str:sub(1, 1)) then
      return 0
    end
    if name_str:match("^%a:") then
      return 0
    end
    return 1
  else
    -- Unix: absolute if starts with /
    if name_str:sub(1, 1) == '/' then
      return 0
    else
      return 1
    end
  end
end

--Provides: caml_filename_is_implicit
--Requires: caml_filename_is_dir_sep caml_filename_os_type
function caml_filename_is_implicit(name)
  local name_str = name
  local os_type = caml_filename_os_type()

  if name_str == "" then
    return 1
  end

  -- Check if starts with separator (explicit)
  if caml_filename_is_dir_sep(name_str:sub(1, 1)) then
    return 0
  end

  -- Check if starts with ./ or ../
  if name_str:sub(1, 2) == "./" or name_str:sub(1, 2) == ".\\" then
    return 0
  end
  if name_str:sub(1, 3) == "../" or name_str:sub(1, 3) == "..\\" then
    return 0
  end

  -- Windows: check for drive letter
  if os_type == "Win32" and name_str:match("^%a:") then
    return 0
  end

  return 1
end

--Provides: caml_filename_current_dir_name
function caml_filename_current_dir_name(_unit)
  return "."
end

--Provides: caml_filename_parent_dir_name
function caml_filename_parent_dir_name(_unit)
  return ".."
end

--Provides: caml_filename_quote
function caml_filename_quote(name)
  local name_str = name

  -- Simple quoting: wrap in quotes if contains spaces or special chars
  if name_str:match("[ \t\n'\"\\$`!*?]") then
    -- Escape quotes and backslashes
    local escaped = name_str:gsub("\\", "\\\\"):gsub('"', '\\"')
    return '"' .. escaped .. '"'
  else
    return name_str
  end
end

--Provides: caml_filename_quote_command
function caml_filename_quote_command(cmd)
  return cmd
end

--Provides: caml_filename_temp_dir_name
--Requires: caml_sys_temp_dir_name
function caml_filename_temp_dir_name(_unit)
  return caml_sys_temp_dir_name(0)
end

--Provides: caml_filename_null
--Requires: caml_filename_os_type
function caml_filename_null(_unit)
  local os_type = caml_filename_os_type()
  if os_type == "Win32" then
    return "NUL"
  else
    return "/dev/null"
  end
end
