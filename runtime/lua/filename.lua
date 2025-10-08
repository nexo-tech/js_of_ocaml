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

--- Filename Module
--
-- Provides operations on file names (paths) with platform-specific handling
-- for Unix and Windows paths.

local core = require("core")

local M = {}

-- OS type detection (matches sys.lua)
local os_type
if package.config:sub(1, 1) == '\\' then
  os_type = "Win32"
else
  os_type = "Unix"
end

-- Directory separator
local dir_sep = os_type == "Win32" and "\\" or "/"

-- Check if character is a directory separator
local function is_dir_sep(c)
  if os_type == "Win32" then
    return c == '\\' or c == '/'
  else
    return c == '/'
  end
end

--- Concatenate two paths
-- @param dir string Directory path
-- @param file string File name
-- @return string Combined path
function M.caml_filename_concat(dir, file)
  local dir_str = dir
  local file_str = file

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
    if is_dir_sep(file_str:sub(1, 1)) then
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
  if is_dir_sep(last_char) then
    return dir_str .. file_str
  else
    return dir_str .. dir_sep .. file_str
  end
end

--- Get basename (last component) of a path
-- @param name string Path
-- @return string Basename
function M.caml_filename_basename(name)
  local name_str = name

  if name_str == "" then
    return ""
  end

  -- Remove trailing separators
  while #name_str > 1 and is_dir_sep(name_str:sub(-1)) do
    name_str = name_str:sub(1, -2)
  end

  -- Special case: root directory
  if name_str == "/" or (os_type == "Win32" and name_str:match("^%a:[\\/]?$")) then
    return name_str
  end

  -- Find last separator
  local last_sep = 0
  for i = #name_str, 1, -1 do
    if is_dir_sep(name_str:sub(i, i)) then
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

--- Get dirname (directory part) of a path
-- @param name string Path
-- @return string Directory name
function M.caml_filename_dirname(name)
  local name_str = name

  if name_str == "" then
    return "."
  end

  -- Remove trailing separators
  while #name_str > 1 and is_dir_sep(name_str:sub(-1)) do
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
    if is_dir_sep(name_str:sub(i, i)) then
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

--- Check if filename ends with given suffix
-- @param name string Filename
-- @param suff string Suffix to check
-- @return number 1 (true) or 0 (false)
function M.caml_filename_check_suffix(name, suff)
  local name_str = name
  local suff_str = suff

  if #suff_str > #name_str then
    return core.false_val
  end

  if #suff_str == 0 then
    return core.true_val  -- Empty suffix always matches
  end

  local name_end = name_str:sub(-#suff_str)
  if name_end == suff_str then
    return core.true_val
  else
    return core.false_val
  end
end

--- Remove suffix from filename if present
-- @param name string Filename
-- @param suff string Suffix to remove
-- @return string Filename without suffix
function M.caml_filename_chop_suffix(name, suff)
  local name_str = name
  local suff_str = suff

  if #suff_str > #name_str then
    local fail = require("fail")
    fail.invalid_argument("Filename.chop_suffix")
  end

  if #suff_str == 0 then
    return name_str  -- Empty suffix: return unchanged
  end

  local name_end = name_str:sub(-#suff_str)
  if name_end == suff_str then
    return name_str:sub(1, -#suff_str - 1)
  else
    local fail = require("fail")
    fail.invalid_argument("Filename.chop_suffix")
  end
end

--- Remove extension from filename
-- @param name string Filename
-- @return string Filename without extension
function M.caml_filename_chop_extension(name)
  local name_str = name

  -- Find last dot
  local last_dot = 0
  local last_sep = 0

  for i = #name_str, 1, -1 do
    local c = name_str:sub(i, i)
    if c == '.' and last_dot == 0 then
      last_dot = i
    end
    if is_dir_sep(c) then
      last_sep = i
      break
    end
  end

  -- No dot found, or dot is before last separator, or dot is first character
  if last_dot == 0 or last_dot <= last_sep or last_dot == 1 then
    local fail = require("fail")
    fail.invalid_argument("Filename.chop_extension")
  end

  return name_str:sub(1, last_dot - 1)
end

--- Get file extension
-- @param name string Filename
-- @return string Extension (including the dot, e.g., ".txt")
function M.caml_filename_extension(name)
  local name_str = name

  -- Find last dot
  local last_dot = 0
  local last_sep = 0

  for i = #name_str, 1, -1 do
    local c = name_str:sub(i, i)
    if c == '.' and last_dot == 0 then
      last_dot = i
    end
    if is_dir_sep(c) then
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

--- Remove extension from filename (no error if no extension)
-- @param name string Filename
-- @return string Filename without extension
function M.caml_filename_remove_extension(name)
  local name_str = name

  -- Find last dot
  local last_dot = 0
  local last_sep = 0

  for i = #name_str, 1, -1 do
    local c = name_str:sub(i, i)
    if c == '.' and last_dot == 0 then
      last_dot = i
    end
    if is_dir_sep(c) then
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

--- Check if path is relative (not absolute)
-- @param name string Path
-- @return number 1 (true) or 0 (false)
function M.caml_filename_is_relative(name)
  local name_str = name

  if name_str == "" then
    return core.true_val
  end

  if os_type == "Win32" then
    -- Absolute if starts with separator or drive letter
    if is_dir_sep(name_str:sub(1, 1)) then
      return core.false_val
    end
    if name_str:match("^%a:") then
      return core.false_val
    end
    return core.true_val
  else
    -- Unix: absolute if starts with /
    if name_str:sub(1, 1) == '/' then
      return core.false_val
    else
      return core.true_val
    end
  end
end

--- Check if path is implicit (doesn't start with / or ./ or ../)
-- @param name string Path
-- @return number 1 (true) or 0 (false)
function M.caml_filename_is_implicit(name)
  local name_str = name

  if name_str == "" then
    return core.true_val
  end

  -- Check if starts with separator (explicit)
  if is_dir_sep(name_str:sub(1, 1)) then
    return core.false_val
  end

  -- Check if starts with ./ or ../
  if name_str:sub(1, 2) == "./" or name_str:sub(1, 2) == ".\\" then
    return core.false_val
  end
  if name_str:sub(1, 3) == "../" or name_str:sub(1, 3) == "..\\" then
    return core.false_val
  end

  -- Windows: check for drive letter
  if os_type == "Win32" and name_str:match("^%a:") then
    return core.false_val
  end

  return core.true_val
end

--- Get current directory string (".")
-- @param _unit number Unit value
-- @return string Current directory marker
function M.caml_filename_current_dir_name(_unit)
  return "."
end

--- Get parent directory string ("..")
-- @param _unit number Unit value
-- @return string Parent directory marker
function M.caml_filename_parent_dir_name(_unit)
  return ".."
end

--- Get directory separator string
-- @param _unit number Unit value
-- @return string Directory separator ("/" or "\\")
function M.caml_filename_dir_sep(_unit)
  return dir_sep
end

--- Quote a filename for shell (simple implementation)
-- @param name string Filename
-- @return string Quoted filename
function M.caml_filename_quote(name)
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

--- Quote command for shell (Unix/Windows compatible)
-- @param cmd string Command string
-- @return string Quoted command
function M.caml_filename_quote_command(cmd)
  -- For now, just return the command as-is
  -- Full implementation would need shell-specific quoting
  return cmd
end

--- Get temp directory name (delegates to Sys.temp_dir_name)
-- @param _unit number Unit value
-- @return string Temp directory path
function M.caml_filename_temp_dir_name(_unit)
  -- Lazy load sys module to avoid circular dependency
  local sys = require("sys")
  return sys.caml_sys_temp_dir_name(core.unit)
end

--- Get null device name
-- @param _unit number Unit value
-- @return string Null device ("/dev/null" or "NUL")
function M.caml_filename_null(_unit)
  if os_type == "Win32" then
    return "NUL"
  else
    return "/dev/null"
  end
end

-- Register all primitives
core.register("caml_filename_concat", M.caml_filename_concat)
core.register("caml_filename_basename", M.caml_filename_basename)
core.register("caml_filename_dirname", M.caml_filename_dirname)
core.register("caml_filename_check_suffix", M.caml_filename_check_suffix)
core.register("caml_filename_chop_suffix", M.caml_filename_chop_suffix)
core.register("caml_filename_chop_extension", M.caml_filename_chop_extension)
core.register("caml_filename_extension", M.caml_filename_extension)
core.register("caml_filename_remove_extension", M.caml_filename_remove_extension)
core.register("caml_filename_is_relative", M.caml_filename_is_relative)
core.register("caml_filename_is_implicit", M.caml_filename_is_implicit)
core.register("caml_filename_current_dir_name", M.caml_filename_current_dir_name)
core.register("caml_filename_parent_dir_name", M.caml_filename_parent_dir_name)
core.register("caml_filename_dir_sep", M.caml_filename_dir_sep)
core.register("caml_filename_quote", M.caml_filename_quote)
core.register("caml_filename_quote_command", M.caml_filename_quote_command)
core.register("caml_filename_temp_dir_name", M.caml_filename_temp_dir_name)
core.register("caml_filename_null", M.caml_filename_null)

return M
