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

-- Initialize global _OCAML namespace
_G._OCAML = {
  primitives = {},
  modules = {},
  version = "1.0.0",
  initialized = false
}

--Provides: caml_register_global
function caml_register_global(name, func)
  if type(name) ~= "string" then
    error("Primitive name must be a string, got " .. type(name))
  end
  if type(func) ~= "function" then
    error("Primitive must be a function, got " .. type(func))
  end
  _G._OCAML.primitives[name] = func
end

--Provides: caml_get_primitive
function caml_get_primitive(name)
  local prim = _G._OCAML.primitives[name]
  if not prim then
    error("Undefined primitive: " .. tostring(name))
  end
  return prim
end

--Provides: caml_register_module
function caml_register_module(name, mod)
  if type(name) ~= "string" then
    error("Module name must be a string, got " .. type(name))
  end
  if type(mod) ~= "table" then
    error("Module must be a table, got " .. type(mod))
  end
  _G._OCAML.modules[name] = mod
end

--Provides: caml_get_module
function caml_get_module(name)
  return _G._OCAML.modules[name]
end

--Provides: caml_ml_bool
function caml_ml_bool(lua_bool)
  return lua_bool and 1 or 0
end

--Provides: caml_lua_bool
function caml_lua_bool(ml_bool)
  return ml_bool ~= 0
end

--Provides: caml_some
function caml_some(x)
  return { tag = 0, [1] = x }
end

--Provides: caml_is_none
function caml_is_none(x)
  return type(x) == "number" and x == 0
end

--Provides: caml_make_block
function caml_make_block(tag, ...)
  local args = { ... }
  local block = { tag = tag }
  for i, v in ipairs(args) do
    block[i] = v
  end
  return block
end

--Provides: caml_tag
function caml_tag(block)
  if type(block) == "table" then
    return block.tag
  end
  return nil
end

--Provides: caml_size
function caml_size(block)
  if type(block) ~= "table" then
    return 0
  end
  local count = 0
  for i = 1, math.huge do
    if block[i] == nil then
      break
    end
    count = count + 1
  end
  return count
end

--Provides: caml_ref_set
function caml_ref_set(ref, value)
  ref[1] = value
end

--Provides: caml_unit
caml_unit = 0

--Provides: caml_false_val
caml_false_val = 0

--Provides: caml_true_val
caml_true_val = 1

--Provides: caml_none
caml_none = 0

--Provides: caml_lua_version
caml_lua_version = tonumber(_VERSION:match("%d+%.%d+"))

--Provides: caml_has_bitops
caml_has_bitops = caml_lua_version >= 5.3

--Provides: caml_has_utf8
caml_has_utf8 = caml_lua_version >= 5.3

--Provides: caml_has_integers
caml_has_integers = caml_lua_version >= 5.3

--Provides: caml_initialize
--Requires: caml_register_module caml_unit caml_false_val caml_true_val caml_none caml_lua_version caml_has_bitops caml_has_utf8 caml_has_integers
function caml_initialize()
  if _G._OCAML.initialized then
    return
  end
  if caml_lua_version < 5.1 then
    error("Lua_of_ocaml requires Lua 5.1 or later")
  end
  caml_register_module("core", {
    unit = caml_unit,
    false_val = caml_false_val,
    true_val = caml_true_val,
    none = caml_none,
    lua_version = caml_lua_version,
    has_bitops = caml_has_bitops,
    has_utf8 = caml_has_utf8,
    has_integers = caml_has_integers
  })
  _G._OCAML.initialized = true
end

--Provides: caml_version_info
--Requires: caml_lua_version
function caml_version_info()
  local version = _G._OCAML.version
  local major, minor, patch = version:match("(%d+)%.(%d+)%.(%d+)")
  return {
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
    string = version,
    lua_version = caml_lua_version
  }
end

-- Auto-initialize runtime
caml_initialize()
