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

--- Core OCaml Runtime Module
--
-- This module provides the foundational runtime support for OCaml code
-- compiled to Lua, including:
-- - Global runtime namespace management
-- - Primitive function registration
-- - Module loading mechanism
-- - OCaml value representation basics

local M = {}

-- Global OCaml runtime namespace
-- All OCaml-specific state is stored in _G._OCAML to avoid polluting
-- the global namespace and allow easy inspection
_G._OCAML = _G._OCAML or {
  primitives = {},     -- Registered primitive functions
  modules = {},        -- Loaded OCaml modules
  version = "1.0.0",   -- Runtime version
  initialized = false  -- Initialization flag
}

--- Register a primitive function
-- Primitives are low-level functions that implement OCaml runtime operations
-- @param name string The primitive name (e.g., "caml_int32_add")
-- @param func function The implementation function
function M.register(name, func)
  if type(name) ~= "string" then
    error("Primitive name must be a string, got " .. type(name))
  end
  if type(func) ~= "function" then
    error("Primitive must be a function, got " .. type(func))
  end
  _OCAML.primitives[name] = func
end

--- Get a primitive function
-- Used by generated code to look up primitive implementations
-- @param name string The primitive name
-- @return function The primitive implementation
function M.get_primitive(name)
  local prim = _OCAML.primitives[name]
  if not prim then
    error("Undefined primitive: " .. tostring(name))
  end
  return prim
end

--- Register an OCaml module
-- @param name string The module name
-- @param mod table The module table
function M.register_module(name, mod)
  if type(name) ~= "string" then
    error("Module name must be a string, got " .. type(name))
  end
  if type(mod) ~= "table" then
    error("Module must be a table, got " .. type(mod))
  end
  _OCAML.modules[name] = mod
end

--- Get a loaded module
-- @param name string The module name
-- @return table The module table, or nil if not loaded
function M.get_module(name)
  return _OCAML.modules[name]
end

--- OCaml unit value
-- The unit type has a single value, represented as 0
M.unit = 0

--- OCaml boolean values
-- OCaml bools are represented as integers: false=0, true=1
M.false_val = 0
M.true_val = 1

--- Convert Lua boolean to OCaml boolean
-- @param lua_bool boolean Lua boolean value
-- @return number OCaml boolean (0 or 1)
function M.ml_bool(lua_bool)
  return lua_bool and 1 or 0
end

--- Convert OCaml boolean to Lua boolean
-- @param ml_bool number OCaml boolean (0 or 1)
-- @return boolean Lua boolean
function M.lua_bool(ml_bool)
  return ml_bool ~= 0
end

--- OCaml None value
-- The None constructor of the option type is represented as 0
M.none = 0

--- Create OCaml Some value
-- @param x any The wrapped value
-- @return table Block with tag 0 and the value
function M.some(x)
  return { tag = 0, [1] = x }
end

--- Check if a value is None
-- @param x any The value to check
-- @return boolean True if the value is None
function M.is_none(x)
  return type(x) == "number" and x == 0
end

--- Create an OCaml block (structured value)
-- Blocks are the fundamental structured data type in OCaml runtime.
-- They have a tag (indicating constructor/type) and 0+ fields.
-- @param tag number The block tag (0-245 for variants, 246-255 reserved)
-- @param ... any Field values
-- @return table The block with tag and numbered fields
function M.make_block(tag, ...)
  local args = { ... }
  local block = { tag = tag }
  for i, v in ipairs(args) do
    block[i] = v
  end
  return block
end

--- Get the tag of a block
-- @param block table The block
-- @return number The tag, or nil if not a block
function M.tag(block)
  if type(block) == "table" then
    return block.tag
  end
  return nil
end

--- Get the size (number of fields) of a block
-- @param block table The block
-- @return number The number of fields
function M.size(block)
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

--- Set the value of a reference
-- References are represented as blocks with tag 0 and a single field
-- @param ref table The reference block
-- @param value any The new value
function M.ref_set(ref, value)
  ref[1] = value
end

--- Check Lua version and feature availability
M.lua_version = tonumber(_VERSION:match("%d+%.%d+"))
M.has_bitops = M.lua_version >= 5.3  -- Native bitwise operators
M.has_utf8 = M.lua_version >= 5.3    -- UTF-8 library
M.has_integers = M.lua_version >= 5.3 -- Integer type (vs float-only)

--- Initialize the runtime
-- This should be called once before executing OCaml code
function M.initialize()
  if _OCAML.initialized then
    return M
  end

  -- Check minimum Lua version
  if M.lua_version < 5.1 then
    error("Lua_of_ocaml requires Lua 5.1 or later")
  end

  -- Register this module
  M.register_module("core", M)

  _OCAML.initialized = true
  return M
end

--- Get runtime version information
-- @return table Version info with major, minor, patch fields
function M.version_info()
  local version = _OCAML.version
  local major, minor, patch = version:match("(%d+)%.(%d+)%.(%d+)")
  return {
    major = tonumber(major),
    minor = tonumber(minor),
    patch = tonumber(patch),
    string = version,
    lua_version = M.lua_version
  }
end

-- Auto-initialize on module load
M.initialize()

return M
