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

--Provides: caml_is_ocaml_fun
function caml_is_ocaml_fun(v)
  return type(v) == "table" and type(v.f) == "function" and type(v.l) == "number"
end

--Provides: caml_call_gen
--Requires: caml_is_ocaml_fun
function caml_call_gen(func, args)
  assert(caml_is_ocaml_fun(func), "caml_call_gen expects an OCaml function")

  local n = func.l
  local args_len = #args
  local d = n - args_len

  if d == 0 then
    -- Exact number of arguments: call directly
    return func.f(unpack(args))
  elseif d < 0 then
    -- Over-application: too many arguments
    -- Call func with first n arguments
    local first_args = {}
    for i = 1, n do
      first_args[i] = args[i]
    end
    local result = func.f(unpack(first_args))

    -- If result is an OCaml function, apply remaining arguments
    if caml_is_ocaml_fun(result) then
      local rest_args = {}
      for i = n + 1, args_len do
        rest_args[#rest_args + 1] = args[i]
      end
      return caml_call_gen(result, rest_args)
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
          return func.f(unpack(new_args))
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
          return func.f(unpack(new_args))
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
          return caml_call_gen(func, combined)
        end
      }
    end
  end
end

--Provides: caml_apply
--Requires: caml_call_gen, caml_is_ocaml_fun
function caml_apply(func, ...)
  local args = {...}
  if caml_is_ocaml_fun(func) then
    return caml_call_gen(func, args)
  else
    error("caml_apply expects an OCaml function")
  end
end

--Provides: caml_curry
function caml_curry(arity, lua_fn)
  return {
    l = arity,
    f = lua_fn
  }
end

--Provides: caml_closure
function caml_closure(arity, lua_fn, env)
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
