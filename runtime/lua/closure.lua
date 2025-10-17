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

-- Metatable for callable wrapped closures
-- This makes tables with {l=arity, [1]=fn} callable like functions
local closure_mt = {
  __call = function(t, ...)
    return t[1](...)
  end,
  -- Add __closure marker to distinguish our closures from other tables
  __closure = true
}

--Provides: caml_make_closure
function caml_make_closure(arity, fn)
  -- Create a callable table that acts like a JavaScript function with .l property
  -- The table has:
  --   .l = arity (matches JavaScript's f.l)
  --   [1] = actual function
  --   metatable.__closure = true (marker to identify our closures)
  return setmetatable({l = arity, [1] = fn}, closure_mt)
end
