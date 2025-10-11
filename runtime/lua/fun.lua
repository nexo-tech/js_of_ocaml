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

--Provides: caml_call_gen
function caml_call_gen(f, args)
  -- Get arity and actual function
  -- f can be either a plain function (no arity info) or a table {l=arity, [...]}
  local n, actual_f
  if type(f) == "table" and f.l then
    n = f.l
    -- Find the actual function: check if table is callable or has explicit function
    if type(f[1]) == "function" then
      actual_f = f[1]
    else
      -- Table might be callable via metatable
      local mt = getmetatable(f)
      if mt and mt.__call then
        actual_f = f
      else
        error("caml_call_gen: table has .l but no callable function")
      end
    end
  elseif type(f) == "function" then
    error("caml_call_gen: plain function has no arity information")
  else
    error("caml_call_gen: not a function or callable table")
  end

  local argsLen = #args
  local d = n - argsLen

  if d == 0 then
    -- Exact match: call function directly with all arguments
    return actual_f(unpack(args))
  elseif d < 0 then
    -- Over-application: more args than needed
    -- Call f with first n arguments, then apply rest to result
    local first_args = {}
    for i = 1, n do
      first_args[i] = args[i]
    end
    local g = actual_f(unpack(first_args))

    -- If result is not a function or callable, return it
    if type(g) ~= "function" and type(g) ~= "table" then
      return g
    end

    -- Result is a function, apply remaining arguments recursively
    local rest_args = {}
    for i = n + 1, argsLen do
      rest_args[#rest_args + 1] = args[i]
    end
    return caml_call_gen(g, rest_args)
  else
    -- Under-application: not enough arguments
    -- Build a closure that captures provided args and waits for more

    -- Optimize common cases: d == 1 or d == 2
    local g_fn
    if d == 1 then
      -- Need exactly 1 more argument
      g_fn = function(x)
        local nargs = {}
        for i = 1, argsLen do
          nargs[i] = args[i]
        end
        nargs[argsLen + 1] = x
        return actual_f(unpack(nargs))
      end
    elseif d == 2 then
      -- Need exactly 2 more arguments
      g_fn = function(x, y)
        local nargs = {}
        for i = 1, argsLen do
          nargs[i] = args[i]
        end
        nargs[argsLen + 1] = x
        nargs[argsLen + 2] = y
        return actual_f(unpack(nargs))
      end
    else
      -- Need 3 or more arguments
      -- Create vararg closure that recursively calls caml_call_gen
      g_fn = function(...)
        local extra_args = {...}
        if #extra_args == 0 then
          extra_args = {nil}  -- Handle zero-arg call
        end
        local combined = {}
        for i = 1, argsLen do
          combined[i] = args[i]
        end
        for i = 1, #extra_args do
          combined[argsLen + i] = extra_args[i]
        end
        return caml_call_gen(f, combined)
      end
    end

    -- Return table with arity and function
    return {l = d, g_fn}
  end
end

--Provides: caml_apply
--Requires: caml_call_gen
function caml_apply(func, ...)
  local args = {...}
  if type(func) == "table" or type(func) == "function" then
    return caml_call_gen(func, args)
  else
    error("caml_apply expects a function or callable table")
  end
end
