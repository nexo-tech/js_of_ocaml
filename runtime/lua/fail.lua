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

--- Exception Handling Module
--
-- This module provides OCaml exception handling for Lua.
-- OCaml exceptions are mapped to Lua error() and pcall().
-- Exception values are represented as blocks with tags.

local core = require("core")
local M = {}

-- Global exception registry
-- Stores predefined exception constructors
_G._OCAML.exceptions = _G._OCAML.exceptions or {}

--- Register a global exception constructor
-- @param name string Exception name
-- @param tag number Exception tag (248 for extensible exceptions)
-- @param id number Exception id
-- @return table Exception constructor
function M.register_exception(name, tag, id)
  local exc = { tag = tag, [1] = name, [2] = id }
  _G._OCAML.exceptions[name] = exc
  return exc
end

--- Get a registered exception
-- @param name string Exception name
-- @return table Exception constructor or nil
function M.get_exception(name)
  return _G._OCAML.exceptions[name]
end

-- Predefined OCaml exceptions
-- These are registered lazily when first used

--- Get or create the Failure exception
-- @return table Failure exception constructor
local function get_failure()
  if not _G._OCAML.exceptions.Failure then
    M.register_exception("Failure", 248, -3)
  end
  return _G._OCAML.exceptions.Failure
end

--- Get or create the Invalid_argument exception
-- @return table Invalid_argument exception constructor
local function get_invalid_argument()
  if not _G._OCAML.exceptions.Invalid_argument then
    M.register_exception("Invalid_argument", 248, -4)
  end
  return _G._OCAML.exceptions.Invalid_argument
end

--- Get or create the Not_found exception
-- @return table Not_found exception constructor
local function get_not_found()
  if not _G._OCAML.exceptions.Not_found then
    M.register_exception("Not_found", 248, -5)
  end
  return _G._OCAML.exceptions.Not_found
end

--- Get or create the End_of_file exception
-- @return table End_of_file exception constructor
local function get_end_of_file()
  if not _G._OCAML.exceptions.End_of_file then
    M.register_exception("End_of_file", 248, -7)
  end
  return _G._OCAML.exceptions.End_of_file
end

--- Get or create the Division_by_zero exception
-- @return table Division_by_zero exception constructor
local function get_division_by_zero()
  if not _G._OCAML.exceptions.Division_by_zero then
    M.register_exception("Division_by_zero", 248, -8)
  end
  return _G._OCAML.exceptions.Division_by_zero
end

--- Get or create the Match_failure exception
-- @return table Match_failure exception constructor
local function get_match_failure()
  if not _G._OCAML.exceptions.Match_failure then
    M.register_exception("Match_failure", 248, -9)
  end
  return _G._OCAML.exceptions.Match_failure
end

--- Get or create the Sys_error exception
-- @return table Sys_error exception constructor
local function get_sys_error()
  if not _G._OCAML.exceptions.Sys_error then
    M.register_exception("Sys_error", 248, -11)
  end
  return _G._OCAML.exceptions.Sys_error
end

--- Raise an exception (constant, no arguments)
-- @param exc table Exception constructor
function M.raise_constant(exc)
  error(exc, 0)
end

--- Raise an exception with a single argument
-- @param exc table Exception constructor
-- @param arg any Exception argument
function M.raise_with_arg(exc, arg)
  local exc_value = { tag = 0, [1] = exc, [2] = arg }
  error(exc_value, 0)
end

--- Raise an exception with multiple arguments
-- @param exc table Exception constructor
-- @param args table Array of arguments
function M.raise_with_args(exc, args)
  local exc_value = { tag = 0, [1] = exc }
  for i, arg in ipairs(args) do
    exc_value[i + 1] = arg
  end
  error(exc_value, 0)
end

--- Raise Failure exception
-- @param msg string Failure message
function M.failwith(msg)
  M.raise_with_arg(get_failure(), msg)
end

--- Raise Invalid_argument exception
-- @param msg string Error message
function M.invalid_argument(msg)
  M.raise_with_arg(get_invalid_argument(), msg)
end

--- Raise Not_found exception
function M.raise_not_found()
  M.raise_constant(get_not_found())
end

--- Raise End_of_file exception
function M.raise_end_of_file()
  M.raise_constant(get_end_of_file())
end

--- Raise Division_by_zero exception
function M.raise_zero_divide()
  M.raise_constant(get_division_by_zero())
end

--- Raise Match_failure exception
-- @param location table Location info (file, line, column)
function M.raise_match_failure(location)
  M.raise_with_arg(get_match_failure(), location)
end

--- Raise Sys_error exception
-- @param msg string Error message
function M.raise_sys_error(msg)
  M.raise_with_arg(get_sys_error(), msg)
end

--- Check if a value is an OCaml exception
-- @param val any Value to check
-- @return boolean True if it's an exception
function M.is_exception(val)
  if type(val) ~= "table" then
    return false
  end
  -- Check if it has exception structure
  if val.tag == 248 then
    return true  -- Exception constructor
  end
  if val.tag == 0 and type(val[1]) == "table" and val[1].tag == 248 then
    return true  -- Exception value with arguments
  end
  return false
end

--- Get exception name from exception value
-- @param exc any Exception value
-- @return string Exception name or "Unknown"
function M.exception_name(exc)
  if type(exc) ~= "table" then
    return "Unknown"
  end

  -- Exception constructor
  if exc.tag == 248 and type(exc[1]) == "string" then
    return exc[1]
  end

  -- Exception value with arguments
  if exc.tag == 0 and type(exc[1]) == "table" and exc[1].tag == 248 then
    return exc[1][1] or "Unknown"
  end

  return "Unknown"
end

--- Convert exception to string
-- @param exc any Exception value
-- @return string String representation
function M.exception_to_string(exc)
  local name = M.exception_name(exc)

  if type(exc) ~= "table" then
    return name
  end

  -- Exception with single string argument
  if exc.tag == 0 and exc[2] and type(exc[2]) == "string" then
    return name .. "(" .. exc[2] .. ")"
  end

  -- Just the name for constant exceptions
  return name
end

--- Wrap a function call with exception handling
-- @param f function Function to call
-- @param ... any Arguments to pass
-- @return boolean, any Success flag and result or exception
function M.try_catch(f, ...)
  local success, result = pcall(f, ...)
  return success, result
end

--- Catch exceptions and call handler
-- @param f function Function to try
-- @param handler function Exception handler (exc) -> result
-- @param ... any Arguments for f
-- @return any Result from f or handler
function M.catch(f, handler, ...)
  local success, result = pcall(f, ...)
  if success then
    return result
  else
    return handler(result)
  end
end

--- Finally: ensure cleanup code runs
-- @param f function Main function
-- @param cleanup function Cleanup function
-- @param ... any Arguments for f
-- @return any Result from f
function M.try_finally(f, cleanup, ...)
  local success, result = pcall(f, ...)
  cleanup()
  if success then
    return result
  else
    error(result, 0)
  end
end

-- Register primitives
core.register("caml_raise_constant", M.raise_constant)
core.register("caml_raise_with_arg", M.raise_with_arg)
core.register("caml_raise_with_args", M.raise_with_args)
core.register("caml_raise_with_string", M.raise_with_arg)  -- Same as raise_with_arg for strings
core.register("caml_failwith", M.failwith)
core.register("caml_invalid_argument", M.invalid_argument)
core.register("caml_raise_not_found", M.raise_not_found)
core.register("caml_raise_end_of_file", M.raise_end_of_file)
core.register("caml_raise_zero_divide", M.raise_zero_divide)
core.register("caml_raise_sys_error", M.raise_sys_error)

-- Array bound error uses invalid_argument
core.register("caml_array_bound_error", function()
  M.invalid_argument("index out of bounds")
end)

-- String bound error uses invalid_argument
core.register("caml_string_bound_error", function()
  M.invalid_argument("index out of bounds")
end)

-- Bytes bound error uses invalid_argument
core.register("caml_bytes_bound_error", function()
  M.invalid_argument("index out of bounds")
end)

-- Register module
core.register_module("fail", M)

return M
