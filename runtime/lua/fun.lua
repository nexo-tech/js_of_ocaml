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

--- Function and Closure Support Module
--
-- This module provides OCaml function application and currying for Lua.
--
-- OCaml functions are represented as tables (not raw Lua functions) with:
-- - `f` field: the actual Lua function
-- - `l` field: arity (number of expected parameters)
--
-- This design allows us to attach metadata to functions in all Lua versions.
--
-- Partial application: When a function is called with fewer arguments
-- than expected, a new closure is returned that captures the provided
-- arguments and waits for the remaining ones.
--
-- Over-application: When a function is called with more arguments than
-- expected, the function is called with the first n arguments, and if
-- the result is a function, it's called with the remaining arguments.

local core = require("core")
local M = {}

--- Check if a value is an OCaml function (table with f and l fields)
local function is_ocaml_fun(v)
  return type(v) == "table" and type(v.f) == "function" and type(v.l) == "number"
end

--- Generic function application with currying and partial application.
-- This is the core function that handles OCaml's currying semantics.
--
-- @param func table OCaml function {f = lua_function, l = arity}
-- @param args table Array of arguments
-- @return any Result of function application (may be a partial closure)
function M.caml_call_gen(func, args)
  assert(is_ocaml_fun(func), "caml_call_gen expects an OCaml function")

  local n = func.l
  local args_len = #args
  local d = n - args_len

  if d == 0 then
    -- Exact number of arguments: call directly
    return func.f(table.unpack(args))
  elseif d < 0 then
    -- Over-application: too many arguments
    -- Call func with first n arguments
    local first_args = {}
    for i = 1, n do
      first_args[i] = args[i]
    end
    local result = func.f(table.unpack(first_args))

    -- If result is an OCaml function, apply remaining arguments
    if is_ocaml_fun(result) then
      local rest_args = {}
      for i = n + 1, args_len do
        rest_args[#rest_args + 1] = args[i]
      end
      return M.caml_call_gen(result, rest_args)
    else
      -- Result is not a function, return it
      return result
    end
  else
    -- Under-application: not enough arguments
    -- Return a closure that captures the provided arguments

    -- Optimize for common cases (1-2 missing parameters)
    if d == 1 then
      -- Need exactly 1 more argument
      return {
        l = 1,
        f = function(x)
          local new_args = {}
          for i = 1, args_len do
            new_args[i] = args[i]
          end
          new_args[args_len + 1] = x
          return func.f(table.unpack(new_args))
        end
      }
    elseif d == 2 then
      -- Need exactly 2 more arguments
      return {
        l = 2,
        f = function(x, y)
          local new_args = {}
          for i = 1, args_len do
            new_args[i] = args[i]
          end
          new_args[args_len + 1] = x
          new_args[args_len + 2] = y
          return func.f(table.unpack(new_args))
        end
      }
    else
      -- Need 3 or more arguments
      -- Create a vararg closure that accumulates arguments
      return {
        l = d,
        f = function(...)
          local extra_args = {...}
          -- Handle case where no args provided (call with unit)
          if #extra_args == 0 then
            extra_args = {0}  -- OCaml unit
          end
          -- Concatenate args with extra_args
          local combined = {}
          for i = 1, args_len do
            combined[i] = args[i]
          end
          for i = 1, #extra_args do
            combined[args_len + i] = extra_args[i]
          end
          return M.caml_call_gen(func, combined)
        end
      }
    end
  end
end

--- Apply a function to arguments (runtime helper).
-- This is a simpler version for when arity is known at compile time.
--
-- @param func table OCaml function
-- @param ... any Arguments to pass
-- @return any Result of function application
function M.caml_apply(func, ...)
  local args = {...}
  if is_ocaml_fun(func) then
    -- Function has known arity, use general application
    return M.caml_call_gen(func, args)
  else
    -- Shouldn't happen in well-typed code
    error("caml_apply expects an OCaml function")
  end
end

--- Create a curried function with known arity.
-- This wraps a Lua function to give it OCaml currying semantics.
--
-- @param arity number Number of parameters the function expects
-- @param lua_fn function The actual Lua function implementation
-- @return table OCaml function {f, l}
function M.caml_curry(arity, lua_fn)
  return {
    l = arity,
    f = lua_fn
  }
end

--- Create a closure with captured free variables.
-- Generated code will use this to create closures that close over
-- variables from enclosing scopes.
--
-- @param arity number Number of parameters
-- @param lua_fn function Function implementation
-- @param env table Optional environment table with free variables
-- @return table OCaml function {f, l}
function M.caml_closure(arity, lua_fn, env)
  if env then
    -- Closure with environment - wrap to inject env as first parameter
    return {
      l = arity,
      f = function(...)
        return lua_fn(env, ...)
      end
    }
  else
    -- No environment needed
    return {
      l = arity,
      f = lua_fn
    }
  end
end

--- Export the is_ocaml_fun helper for use by other modules
M.is_fun = is_ocaml_fun

-- Register primitives
core.register("caml_call_gen", M.caml_call_gen)
core.register("caml_apply", M.caml_apply)
core.register("caml_curry", M.caml_curry)
core.register("caml_closure", M.caml_closure)

-- Register module
core.register_module("fun", M)

return M
