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

--- Core OCaml Runtime Primitives
--
-- This module provides the foundational runtime support for OCaml code
-- compiled to Lua, including:
-- - Global runtime namespace management
-- - Primitive function registration
-- - OCaml value representation basics

-- Global OCaml runtime namespace
-- All OCaml-specific state is stored in _G._OCAML to avoid polluting
-- the global namespace and allow easy inspection
_OCAML = _OCAML or {
  primitives = {},     -- Registered primitive functions
  modules = {},        -- Loaded OCaml modules
  version = "1.0.0",   -- Runtime version
  initialized = false  -- Initialization flag
}

--Provides: caml_register_global
function caml_register_global(name, func)
  if type(name) ~= "string" then
    error("Primitive name must be a string, got " .. type(name))
  end
  if type(func) ~= "function" then
    error("Primitive must be a function, got " .. type(func))
  end
  _OCAML.primitives[name] = func
end

--Provides: caml_get_primitive
function caml_get_primitive(name)
  local prim = _OCAML.primitives[name]
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
  _OCAML.modules[name] = mod
end

--Provides: caml_get_module
function caml_get_module(name)
  return _OCAML.modules[name]
end

-- OCaml unit value
-- The unit type has a single value, represented as 0
caml_unit = 0

-- OCaml boolean values
-- OCaml bools are represented as integers: false=0, true=1
caml_false_val = 0
caml_true_val = 1

--Provides: caml_ml_bool
function caml_ml_bool(lua_bool)
  return lua_bool and 1 or 0
end

--Provides: caml_lua_bool
function caml_lua_bool(ml_bool)
  return ml_bool ~= 0
end

-- OCaml None value
-- The None constructor of the option type is represented as 0
caml_none = 0

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

-- Check Lua version and feature availability
caml_lua_version = tonumber(_VERSION:match("%d+%.%d+"))
caml_has_bitops = caml_lua_version >= 5.3  -- Native bitwise operators
caml_has_utf8 = caml_lua_version >= 5.3    -- UTF-8 library
caml_has_integers = caml_lua_version >= 5.3 -- Integer type (vs float-only)

--Provides: caml_initialize
--Requires: caml_register_module
function caml_initialize()
  if _OCAML.initialized then
    return
  end

  -- Check minimum Lua version
  if caml_lua_version < 5.1 then
    error("Lua_of_ocaml requires Lua 5.1 or later")
  end

  -- Register core as a module for compatibility
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

  _OCAML.initialized = true
end

--Provides: caml_version_info
function caml_version_info()
  local version = _OCAML.version
  local major, minor, patch = version:match("(%d+)%.(%d+)%.(%d+)")
  return {
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
    string = version,
    lua_version = caml_lua_version
  }
end

-- Auto-initialize on module load
caml_initialize()
