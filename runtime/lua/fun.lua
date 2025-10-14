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
--Requires: caml_make_closure
function caml_call_gen(f, args)
  -- Normalize f to ensure consistent handling
  -- f can be:
  --   1. A wrapped closure from caml_make_closure: {l=arity, [1]=fn} with __closure metatable
  --   2. A plain function (shouldn't happen in normal operation)
  --   3. Another table with .l property (from partial application)

  local n, actual_f

  -- Check if f is a table with .l property (matches JavaScript f.l)
  if type(f) == "table" and f.l then
    n = f.l

    -- Check if it's one of our wrapped closures or has function at [1]
    if type(f[1]) == "function" then
      -- It has a function at [1], use it
      actual_f = f[1]
    else
      -- f itself might be callable via metatable
      local mt = getmetatable(f)
      if mt and mt.__call then
        actual_f = f
      else
        error("caml_call_gen: table has .l but no callable function")
      end
    end
  elseif type(f) == "function" then
    -- Plain function - shouldn't happen in normal OCaml code
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

    -- If result is not a function or callable table, return it
    if type(g) ~= "function" and type(g) ~= "table" then
      return g
    end

    -- Result is a function/callable, apply remaining arguments recursively
    local rest_args = {}
    for i = n + 1, argsLen do
      rest_args[#rest_args + 1] = args[i]
    end
    return caml_call_gen(g, rest_args)
  else
    -- Under-application: not enough arguments
    -- Build a closure that captures provided args and waits for more
    -- This matches JavaScript's partial application behavior

    -- Task 3.6.5.7 Option B: For d==1, try calling with nil first (dead param workaround)
    -- This handles Printf format closures where the second param is never used
    if d == 1 and argsLen == 1 then
      -- Build arg list with nil for missing arg
      local nargs = {}
      for i = 1, argsLen do
        nargs[i] = args[i]
      end
      nargs[argsLen + 1] = nil  -- Missing argument as nil

      -- Try calling with the nil argument
      local ok, result = pcall(actual_f, unpack(nargs, 1, n))
      if ok then
        -- Success! Return the result directly
        return result
      end
      -- Failed, fall through to partial application
    end

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
      -- Need 3 or more arguments - general case
      -- IMPORTANT FIX: We must create a new partial application closure
      -- that will be called with the remaining arguments
      g_fn = function(...)
        local extra_args = {...}
        -- If no args provided, JavaScript passes undefined (nil in Lua)
        if #extra_args == 0 then
          extra_args = {nil}
        end
        -- Combine captured args with new args and call caml_call_gen again
        -- BUT we need to use the ORIGINAL f with ALL accumulated args
        local combined_args = {}
        for i = 1, argsLen do
          combined_args[i] = args[i]
        end
        for i = 1, #extra_args do
          combined_args[argsLen + i] = extra_args[i]
        end
        -- CRITICAL: Pass the original f (with its full arity), not the partial
        return caml_call_gen(f, combined_args)
      end
    end

    -- Return wrapped closure with correct arity, matching JavaScript behavior
    -- In JavaScript: g.l = d; return g
    return caml_make_closure(d, g_fn)
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
