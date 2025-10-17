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

-- Exception Handling Module
--
-- This module provides OCaml exception handling for Lua.
-- OCaml exceptions are mapped to Lua error() and pcall().
-- Exception values are represented as blocks with tags.

-- Global exception registry
-- Stores predefined exception constructors
_G._OCAML.exceptions = _G._OCAML.exceptions or {}

--Provides: caml_register_exception
function caml_register_exception(name, tag, id)
  local exc = { tag = tag, [1] = name, [2] = id }
  _G._OCAML.exceptions[name] = exc
  return exc
end

--Provides: caml_get_exception
function caml_get_exception(name)
  return _G._OCAML.exceptions[name]
end

-- Predefined OCaml exceptions
-- These are registered lazily when first used

--Provides: caml_get_failure
--Requires: caml_register_exception
function caml_get_failure()
  if not _G._OCAML.exceptions.Failure then
    caml_register_exception("Failure", 248, -3)
  end
  return _G._OCAML.exceptions.Failure
end

--Provides: caml_get_invalid_argument
--Requires: caml_register_exception
function caml_get_invalid_argument()
  if not _G._OCAML.exceptions.Invalid_argument then
    caml_register_exception("Invalid_argument", 248, -4)
  end
  return _G._OCAML.exceptions.Invalid_argument
end

--Provides: caml_get_not_found
--Requires: caml_register_exception
function caml_get_not_found()
  if not _G._OCAML.exceptions.Not_found then
    caml_register_exception("Not_found", 248, -5)
  end
  return _G._OCAML.exceptions.Not_found
end

--Provides: caml_get_end_of_file
--Requires: caml_register_exception
function caml_get_end_of_file()
  if not _G._OCAML.exceptions.End_of_file then
    caml_register_exception("End_of_file", 248, -7)
  end
  return _G._OCAML.exceptions.End_of_file
end

--Provides: caml_get_division_by_zero
--Requires: caml_register_exception
function caml_get_division_by_zero()
  if not _G._OCAML.exceptions.Division_by_zero then
    caml_register_exception("Division_by_zero", 248, -8)
  end
  return _G._OCAML.exceptions.Division_by_zero
end

--Provides: caml_get_match_failure
--Requires: caml_register_exception
function caml_get_match_failure()
  if not _G._OCAML.exceptions.Match_failure then
    caml_register_exception("Match_failure", 248, -9)
  end
  return _G._OCAML.exceptions.Match_failure
end

--Provides: caml_get_sys_error
--Requires: caml_register_exception
function caml_get_sys_error()
  if not _G._OCAML.exceptions.Sys_error then
    caml_register_exception("Sys_error", 248, -11)
  end
  return _G._OCAML.exceptions.Sys_error
end

--Provides: caml_raise_constant
function caml_raise_constant(exc)
  error(exc, 0)
end

--Provides: caml_raise_with_arg
function caml_raise_with_arg(exc, arg)
  local exc_value = { tag = 0, [1] = exc, [2] = arg }
  error(exc_value, 0)
end

--Provides: caml_raise_with_args
function caml_raise_with_args(exc, args)
  local exc_value = { tag = 0, [1] = exc }
  for i, arg in ipairs(args) do
    exc_value[i + 1] = arg
  end
  error(exc_value, 0)
end

--Provides: caml_raise_with_string
--Requires: caml_raise_with_arg
function caml_raise_with_string(exc, msg)
  caml_raise_with_arg(exc, msg)
end

--Provides: caml_failwith
--Requires: caml_get_failure caml_raise_with_arg
function caml_failwith(msg)
  caml_raise_with_arg(caml_get_failure(), msg)
end

--Provides: caml_invalid_argument
--Requires: caml_get_invalid_argument caml_raise_with_arg
function caml_invalid_argument(msg)
  caml_raise_with_arg(caml_get_invalid_argument(), msg)
end

--Provides: caml_raise_not_found
--Requires: caml_get_not_found caml_raise_constant
function caml_raise_not_found()
  caml_raise_constant(caml_get_not_found())
end

--Provides: caml_raise_end_of_file
--Requires: caml_get_end_of_file caml_raise_constant
function caml_raise_end_of_file()
  caml_raise_constant(caml_get_end_of_file())
end

--Provides: caml_raise_zero_divide
--Requires: caml_get_division_by_zero caml_raise_constant
function caml_raise_zero_divide()
  caml_raise_constant(caml_get_division_by_zero())
end

--Provides: caml_raise_match_failure
--Requires: caml_get_match_failure caml_raise_with_arg
function caml_raise_match_failure(location)
  caml_raise_with_arg(caml_get_match_failure(), location)
end

--Provides: caml_raise_sys_error
--Requires: caml_get_sys_error caml_raise_with_arg
function caml_raise_sys_error(msg)
  caml_raise_with_arg(caml_get_sys_error(), msg)
end

--Provides: caml_is_exception
function caml_is_exception(val)
  if type(val) ~= "table" then
    return false
  end
  if val.tag == 248 then
    return true
  end
  if val.tag == 0 and type(val[1]) == "table" and val[1].tag == 248 then
    return true
  end
  return false
end

--Provides: caml_exception_name
function caml_exception_name(exc)
  if type(exc) ~= "table" then
    return "Unknown"
  end
  if exc.tag == 248 and type(exc[1]) == "string" then
    return exc[1]
  end
  if exc.tag == 0 and type(exc[1]) == "table" and exc[1].tag == 248 then
    return exc[1][1] or "Unknown"
  end
  return "Unknown"
end

--Provides: caml_exception_to_string
--Requires: caml_exception_name
function caml_exception_to_string(exc)
  local name = caml_exception_name(exc)
  if type(exc) ~= "table" then
    return name
  end
  if exc.tag == 0 and exc[2] and type(exc[2]) == "string" then
    return name .. "(" .. exc[2] .. ")"
  end
  return name
end

--Provides: caml_try_catch
function caml_try_catch(f, ...)
  local success, result = pcall(f, ...)
  return success, result
end

--Provides: caml_catch
function caml_catch(f, handler, ...)
  local success, result = pcall(f, ...)
  if success then
    return result
  else
    return handler(result)
  end
end

--Provides: caml_try_finally
function caml_try_finally(f, cleanup, ...)
  local success, result = pcall(f, ...)
  cleanup()
  if success then
    return result
  else
    error(result, 0)
  end
end

--Provides: caml_array_bound_error
--Requires: caml_invalid_argument
function caml_array_bound_error()
  caml_invalid_argument("index out of bounds")
end

--Provides: caml_string_bound_error
--Requires: caml_invalid_argument
function caml_string_bound_error()
  caml_invalid_argument("index out of bounds")
end

--Provides: caml_bytes_bound_error
--Requires: caml_invalid_argument
function caml_bytes_bound_error()
  caml_invalid_argument("index out of bounds")
end
