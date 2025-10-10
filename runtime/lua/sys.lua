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

--- Sys Module
--
-- Provides system operations including:
-- - Program arguments
-- - Environment variables
-- - Time measurement
-- - File system operations
-- - System configuration

dofile("core.lua")

-- OS type detection
local os_type
if package.config:sub(1, 1) == '\\' then
  os_type = "Win32"
else
  os_type = "Unix"
end

-- Static environment variables (set by caml_set_static_env)
local static_env = {}

-- Initial time for caml_sys_time
local initial_time = os.time()

-- Program arguments (initialized lazily)
local caml_argv = nil

--- Initialize argv from command line arguments
local function init_argv()
  if caml_argv then return end

  local main = arg and arg[0] or "a.out"
  local args = arg or {}

  -- Build OCaml array: [0, program_name, arg1, arg2, ...]
  -- First element is tag 0, then program name, then arguments
  caml_argv = {tag = 0}
  caml_argv[1] = main

  -- Add command-line arguments (starting from arg[1])
  for i = 1, #args do
    caml_argv[i + 1] = args[i]
  end

  return caml_argv
end

--- Set static environment variable
-- @param key string Environment variable name
-- @param value string Environment variable value
-- @return number 0 (unit)
--Provides: caml_set_static_env
--Requires: caml_unit
function caml_set_static_env(key, value)
  local key_str = key
  local val_str = value
  static_env[key_str] = val_str
  return caml_unit
end

--- Get environment variable (internal helper)
-- @param name string Environment variable name (Lua string)
-- @return string|nil Environment variable value or nil
local function jsoo_sys_getenv(name)
  -- Check static environment first
  if static_env[name] then
    return static_env[name]
  end

  -- Check os.getenv
  local value = os.getenv(name)
  if value then
    return value
  end

  return nil
end

--- Get environment variable
-- Raises Not_found exception if variable doesn't exist
-- @param name string|table OCaml string (environment variable name)
-- @return string|table OCaml string (environment variable value)
--Provides: caml_sys_getenv
--Requires: caml_raise_not_found
function caml_sys_getenv(name)
  local name_str = name
  local value = jsoo_sys_getenv(name_str)

  if value == nil then
    caml_raise_not_found()
  end

  return value
end

--- Get environment variable (optional version for OCaml 5.4+)
-- @param name string|table OCaml string (environment variable name)
-- @return number|table 0 (None) or [0, value] (Some value)
--Provides: caml_sys_getenv_opt
function caml_sys_getenv_opt(name)
  local name_str = name
  local value = jsoo_sys_getenv(name_str)

  if value == nil then
    return 0 -- None (represented as 0)
  else
    -- Some value: {tag = 0, [1] = value}
    return {tag = 0, [1] = value}
  end
end

--- Unsafe get environment variable (same as caml_sys_getenv)
-- @param name string|table OCaml string
-- @return string|table OCaml string
--Provides: caml_sys_unsafe_getenv
--Requires: caml_sys_getenv
function caml_sys_unsafe_getenv(name)
  return caml_sys_getenv(name)
end

--- Get program arguments
-- @param _unit number Unit value (ignored)
-- @return table OCaml array of strings
--Provides: caml_sys_argv
function caml_sys_argv(_unit)
  init_argv()
  return caml_argv
end

--- Get program arguments (alternative format)
-- Returns [0, program_name, argv_array]
-- @param _unit number Unit value (ignored)
-- @return table Tuple of [0, name, array]
--Provides: caml_sys_get_argv
function caml_sys_get_argv(_unit)
  init_argv()
  return {tag = 0, [1] = caml_argv[1], [2] = caml_argv}
end

--- Modify program arguments
-- @param arg table New argv array
-- @return number 0 (unit)
--Provides: caml_sys_modify_argv
--Requires: caml_unit
function caml_sys_modify_argv(arg)
  caml_argv = arg
  return caml_unit
end

--- Get executable name
-- @param _unit number Unit value (ignored)
-- @return string|table OCaml string
--Provides: caml_sys_executable_name
function caml_sys_executable_name(_unit)
  init_argv()
  return caml_argv[1]
end

--- Get system configuration
-- Returns [0, os_type, word_size, big_endian]
-- @param _unit number Unit value (ignored)
-- @return table Configuration tuple
--Provides: caml_sys_get_config
function caml_sys_get_config(_unit)
  return {
    tag = 0,
    [1] = os_type,
    [2] = 32,  -- word_size (always 32 for js_of_ocaml compatibility)
    [3] = 0    -- big_endian (0 = little endian)
  }
end

--- Get elapsed time since program start (in seconds)
-- @param _unit number Unit value (ignored)
-- @return number Elapsed time in seconds
--Provides: caml_sys_time
function caml_sys_time(_unit)
  local now = os.time()
  return now - initial_time
end

--- Get elapsed time including children processes
-- Note: In Lua, there's no notion of child processes, so this is the same as caml_sys_time
-- @param _b number Ignored
-- @return number Elapsed time in seconds
--Provides: caml_sys_time_include_children
--Requires: caml_sys_time
function caml_sys_time_include_children(_b)
  return caml_sys_time(0)
end

--- Check if file exists
-- @param name string|table OCaml string (file path)
-- @return number 0 (false) or 1 (true)
--Provides: caml_sys_file_exists
--Requires: caml_true_val, caml_false_val
function caml_sys_file_exists(name)
  local path = name
  local file = io.open(path, "r")
  if file then
    file:close()
    return caml_true_val
  else
    return caml_false_val
  end
end

--- Check if path is a directory
-- @param name string|table OCaml string (directory path)
-- @return number 0 (false) or 1 (true)
--Provides: caml_sys_is_directory
--Requires: caml_true_val, caml_false_val
function caml_sys_is_directory(name)
  local path = name

  -- Try to open as directory using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    local attr = lfs.attributes(path)
    if attr and attr.mode == "directory" then
      return caml_true_val
    else
      return caml_false_val
    end
  end

  -- Fallback: try to list directory (Unix-specific)
  local ok, _, code = os.execute('test -d "' .. path:gsub('"', '\\"') .. '"')
  if ok == true or code == 0 then
    return caml_true_val
  else
    return caml_false_val
  end
end

--- Check if path is a regular file (OCaml 5.1+)
-- @param name string|table OCaml string (file path)
-- @return number 0 (false) or 1 (true)
--Provides: caml_sys_is_regular_file
--Requires: caml_sys_is_directory, caml_true_val, caml_false_val
function caml_sys_is_regular_file(name)
  local path = name

  -- Try using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    local attr = lfs.attributes(path)
    if attr and attr.mode == "file" then
      return caml_true_val
    else
      return caml_false_val
    end
  end

  -- Fallback: check if we can open for reading
  local file = io.open(path, "r")
  if file then
    file:close()
    -- Additional check: not a directory
    if caml_sys_is_directory(name) == caml_true_val then
      return caml_false_val
    end
    return caml_true_val
  else
    return caml_false_val
  end
end

--- Remove (delete) a file
-- @param name string|table OCaml string (file path)
-- @return number 0 (unit)
--Provides: caml_sys_remove
--Requires: caml_raise_sys_error, caml_unit
function caml_sys_remove(name)
  local path = name
  local ok, err = os.remove(path)
  if not ok then
    caml_raise_sys_error("remove: " .. (err or "unknown error"))
  end
  return caml_unit
end

--- Rename a file
-- @param oldname string|table OCaml string (old path)
-- @param newname string|table OCaml string (new path)
-- @return number 0 (unit)
--Provides: caml_sys_rename
--Requires: caml_raise_sys_error, caml_unit
function caml_sys_rename(oldname, newname)
  local old_path = oldname
  local new_path = newname
  local ok, err = os.rename(old_path, new_path)
  if not ok then
    caml_raise_sys_error("rename: " .. (err or "unknown error"))
  end
  return caml_unit
end

--- Change current directory
-- @param dirname string|table OCaml string (directory path)
-- @return number 0 (unit)
--Provides: caml_sys_chdir
--Requires: caml_raise_sys_error, caml_unit
function caml_sys_chdir(dirname)
  local path = dirname

  -- Try using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    local ok, err = lfs.chdir(path)
    if not ok then
      caml_raise_sys_error("chdir: " .. (err or "unknown error"))
    end
    return caml_unit
  end

  -- Fallback: not supported without lfs
  caml_raise_sys_error("chdir: not supported (install LuaFileSystem)")
end

--- Get current working directory
-- @param _unit number Unit value (ignored)
-- @return string|table OCaml string (current directory)
--Provides: caml_sys_getcwd
--Requires: caml_raise_sys_error
function caml_sys_getcwd(_unit)
  -- Try using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    local cwd = lfs.currentdir()
    return cwd
  end

  -- Fallback: use shell command (Unix-specific)
  local handle = io.popen("pwd")
  if handle then
    local cwd = handle:read("*l")
    handle:close()
    if cwd then
      return cwd
    end
  end

  -- Last resort: raise error
  caml_raise_sys_error("getcwd: not supported (install LuaFileSystem)")
end

--- Read directory contents
-- @param dirname string|table OCaml string (directory path)
-- @return table OCaml array of strings (filenames)
--Provides: caml_sys_readdir
--Requires: caml_raise_sys_error
function caml_sys_readdir(dirname)
  local path = dirname

  -- Try using lfs if available
  local has_lfs, lfs = pcall(require, "lfs")
  if has_lfs then
    local entries = {tag = 0}  -- OCaml array
    local i = 0
    for entry in lfs.dir(path) do
      if entry ~= "." and entry ~= ".." then
        entries[i] = entry
        i = i + 1
      end
    end
    return entries
  end

  -- Fallback: not supported without lfs
  caml_raise_sys_error("readdir: not supported (install LuaFileSystem)")
end

--- Execute system command
-- @param cmd string|table OCaml string (command to execute)
-- @return number Exit code
--Provides: caml_sys_system_command
function caml_sys_system_command(cmd)
  local cmd_str = cmd
  local ok, exit_type, code = os.execute(cmd_str)

  -- Lua 5.2+ returns (true/nil, "exit"/"signal", code)
  -- Lua 5.1 returns just the exit code
  if type(ok) == "number" then
    return ok  -- Lua 5.1
  elseif ok == true then
    return 0  -- Success
  else
    return code or 1  -- Failure
  end
end

--- Exit program
-- @param code number Exit code
--Provides: caml_sys_exit
function caml_sys_exit(code)
  os.exit(code)
end

--- Open file (stub - not yet implemented)
-- @param path string|table File path
-- @param flags number Open flags
-- @return number File descriptor (stub)
--Provides: sys_open
function sys_open(path, flags)
  error("caml_sys_open: not yet implemented in lua_of_ocaml")
end

--- Close file (stub - not yet implemented)
-- @param fd number File descriptor
-- @return number 0 (unit)
--Provides: sys_close
function sys_close(fd)
  error("caml_sys_close: not yet implemented in lua_of_ocaml")
end

--- Get random seed
-- Returns array of random integers for seeding Random module
-- @param _unit number Unit value (ignored)
-- @return table OCaml array [0, x1, x2, x3, x4]
--Provides: caml_sys_random_seed
function caml_sys_random_seed(_unit)
  -- Try to get good random seed
  math.randomseed(os.time() + os.clock() * 1000000)

  -- Generate 4 random integers
  local r1 = math.random(-2147483648, 2147483647)
  local r2 = math.random(-2147483648, 2147483647)
  local r3 = math.random(-2147483648, 2147483647)
  local r4 = math.random(-2147483648, 2147483647)

  return {tag = 0, [1] = r1, [2] = r2, [3] = r3, [4] = r4}
end

--- System constants

--Provides: caml_sys_const_big_endian
function caml_sys_const_big_endian(_unit)
  return 0  -- Little endian
end

--Provides: caml_sys_const_word_size
function caml_sys_const_word_size(_unit)
  return 32  -- 32-bit word size (js_of_ocaml compatibility)
end

--Provides: caml_sys_const_int_size
function caml_sys_const_int_size(_unit)
  return 32  -- 32-bit int size
end

--Provides: caml_sys_const_max_wosize
function caml_sys_const_max_wosize(_unit)
  return math.floor(0x7fffffff / 4)  -- max_int / 4
end

--Provides: caml_sys_const_ostype_unix
--Requires: caml_true_val, caml_false_val
function caml_sys_const_ostype_unix(_unit)
  return os_type == "Unix" and caml_true_val or caml_false_val
end

--Provides: caml_sys_const_ostype_win32
--Requires: caml_true_val, caml_false_val
function caml_sys_const_ostype_win32(_unit)
  return os_type == "Win32" and caml_true_val or caml_false_val
end

--Provides: caml_sys_const_ostype_cygwin
--Requires: caml_false_val
function caml_sys_const_ostype_cygwin(_unit)
  return caml_false_val  -- We don't detect Cygwin specifically
end

--Provides: caml_sys_const_backend_type
function caml_sys_const_backend_type(_unit)
  return {tag = 0, [1] = "lua_of_ocaml"}
end

--Provides: caml_sys_const_naked_pointers_checked
function caml_sys_const_naked_pointers_checked(_unit)
  return 0
end

--- Check if channel is a TTY
-- @param _chan number Channel id
-- @return number 0 (false, channels are not TTYs in Lua)
--Provides: caml_sys_isatty
--Requires: caml_false_val
function caml_sys_isatty(_chan)
  return caml_false_val
end

--- Get runtime variant
-- @param _unit number Unit value (ignored)
-- @return string|table OCaml string (empty)
--Provides: caml_runtime_variant
function caml_runtime_variant(_unit)
  return ""
end

--- Get runtime parameters
-- @param _unit number Unit value (ignored)
-- @return string|table OCaml string (empty)
--Provides: caml_runtime_parameters
function caml_runtime_parameters(_unit)
  return ""
end

--- Install signal handler (no-op in Lua)
-- @return number 0
--Provides: caml_install_signal_handler
--Requires: caml_unit
function caml_install_signal_handler(_sig, _action)
  return caml_unit
end

--- Runtime warnings flag
local runtime_warnings = 0

--- Enable/disable runtime warnings
-- @param bool number 0 (false) or 1 (true)
-- @return number 0 (unit)
--Provides: caml_ml_enable_runtime_warnings
--Requires: caml_unit
function caml_ml_enable_runtime_warnings(bool)
  runtime_warnings = bool
  return caml_unit
end

--- Check if runtime warnings are enabled
-- @param _unit number Unit value (ignored)
-- @return number 0 (false) or 1 (true)
--Provides: caml_ml_runtime_warnings_enabled
function caml_ml_runtime_warnings_enabled(_unit)
  return runtime_warnings
end

--- Get I/O buffer size (OCaml 5.4+)
-- @param _unit number Unit value (ignored)
-- @return number Buffer size (65536)
--Provides: caml_sys_io_buffer_size
function caml_sys_io_buffer_size(_unit)
  return 65536
end

--- Get temp directory name (OCaml 5.4+)
-- @param _unit number Unit value (ignored)
-- @return string|table OCaml string (temp directory or empty)
--Provides: caml_sys_temp_dir_name
function caml_sys_temp_dir_name(_unit)
  if os_type == "Win32" then
    local tmp = os.getenv("TEMP") or os.getenv("TMP") or ""
    return tmp
  else
    local tmp = os.getenv("TMPDIR") or "/tmp"
    return tmp
  end
end

--- XDG defaults (OCaml 5.2+)
-- @param _unit number Unit value (ignored)
-- @return number 0 (empty list)
--Provides: caml_xdg_defaults
function caml_xdg_defaults(_unit)
  return 0  -- Empty list
end

--- Convert signal number (OCaml 5.4+)
-- @param signo number Signal number
-- @return number Same signal number
--Provides: caml_sys_convert_signal_number
function caml_sys_convert_signal_number(signo)
  return signo
end

--- Reverse convert signal number (OCaml 5.4+)
-- @param signo number Signal number
-- @return number Same signal number
--Provides: caml_sys_rev_convert_signal_number
function caml_sys_rev_convert_signal_number(signo)
  return signo
end

