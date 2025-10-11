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

-- Call helpers for curried function application
-- These match js_of_ocaml's caml_call1, caml_call2, etc. in runtime/js/stdlib.js

--Provides: caml_call1
--Requires: caml_call_gen
function caml_call1(f, a0)
  -- DEBUG: Print what we received
  if type(f) == "table" then
    print("DEBUG caml_call1: f is table")
    print("  f.l = " .. tostring(f.l))
    print("  f[1] type = " .. type(f[1]))
    print("  f.tag = " .. tostring(f.tag))
    local mt = getmetatable(f)
    print("  metatable = " .. tostring(mt))
    if mt then
      print("  __call = " .. tostring(mt.__call))
    end
  end

  -- Get arity and actual callable
  local arity, actual_f
  if type(f) == "table" then
    arity = f.l  -- May be nil
    -- Check if it's a wrapped closure {l=arity, [1]=function}
    if type(f[1]) == "function" then
      actual_f = f[1]
    else
      -- Try calling as-is (might have __call metatable)
      actual_f = f
    end
  elseif type(f) == "function" then
    arity = nil
    actual_f = f
  else
    actual_f = f  -- Hope for the best
    arity = nil
  end

  -- If arity is 1 (or unknown), call directly
  if arity == 1 or arity == nil then
    return actual_f(a0)
  else
    -- Wrong arity, use generic call
    return caml_call_gen(f, {a0})
  end
end

--Provides: caml_call2
--Requires: caml_call_gen
function caml_call2(f, a0, a1)
  local arity, actual_f
  if type(f) == "table" then
    arity = f.l
    if type(f[1]) == "function" then
      actual_f = f[1]
    else
      actual_f = f
    end
  else
    arity = nil
    actual_f = f
  end

  if arity == 2 or arity == nil then
    return actual_f(a0, a1)
  else
    return caml_call_gen(f, {a0, a1})
  end
end

--Provides: caml_call3
--Requires: caml_call_gen
function caml_call3(f, a0, a1, a2)
  local arity, actual_f
  if type(f) == "table" then
    arity = f.l
    if type(f[1]) == "function" then
      actual_f = f[1]
    else
      actual_f = f
    end
  else
    arity = nil
    actual_f = f
  end

  if arity == 3 or arity == nil then
    return actual_f(a0, a1, a2)
  else
    return caml_call_gen(f, {a0, a1, a2})
  end
end

--Provides: caml_call4
--Requires: caml_call_gen
function caml_call4(f, a0, a1, a2, a3)
  local arity, actual_f
  if type(f) == "table" then
    arity = f.l
    if type(f[1]) == "function" then
      actual_f = f[1]
    else
      actual_f = f
    end
  else
    arity = nil
    actual_f = f
  end

  if arity == 4 or arity == nil then
    return actual_f(a0, a1, a2, a3)
  else
    return caml_call_gen(f, {a0, a1, a2, a3})
  end
end

--Provides: caml_call5
--Requires: caml_call_gen
function caml_call5(f, a0, a1, a2, a3, a4)
  local arity, actual_f
  if type(f) == "table" then
    arity = f.l
    if type(f[1]) == "function" then
      actual_f = f[1]
    else
      actual_f = f
    end
  else
    arity = nil
    actual_f = f
  end

  if arity == 5 or arity == nil then
    return actual_f(a0, a1, a2, a3, a4)
  else
    return caml_call_gen(f, {a0, a1, a2, a3, a4})
  end
end
