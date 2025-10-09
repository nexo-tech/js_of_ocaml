-- Lua_of_ocaml runtime support
-- Weak references and Ephemerons
--
-- OCaml weak arrays and ephemerons are implemented using Lua weak tables

-- Ephemeron structure:
-- [0] = tag (251)
-- [1] = "caml_ephe_list_head"
-- [2] = data (ephemeron data)
-- [3..n] = keys (weak references)

local EPHE_KEY_OFFSET = 3
local EPHE_DATA_OFFSET = 2
local EPHE_NONE = {caml_ephe_none = true}

--
-- Weak Array Creation
--

-- Create a weak array
function caml_weak_create(n)
  local alen = EPHE_KEY_OFFSET + n
  local x = {}
  x[0] = 251
  x[1] = "caml_ephe_list_head"

  for i = 2, alen do
    x[i] = EPHE_NONE
  end

  return x
end

-- Create an ephemeron (same as weak array)
function caml_ephe_create(n)
  return caml_weak_create(n)
end

--
-- Key Management
--

-- Set a key in ephemeron with weak reference
function caml_ephe_set_key(x, i, v)
  local old = caml_ephe_get_data(x)

  -- Store value with weak reference if it's a table
  if type(v) == "table" then
    -- Create weak table for this key
    local weak_holder = setmetatable({value = v}, {__mode = "v"})
    x[EPHE_KEY_OFFSET + i] = weak_holder
  else
    -- Non-table values are stored directly
    x[EPHE_KEY_OFFSET + i] = v
  end

  caml_ephe_set_data_opt(x, old)
  return 0
end

-- Unset a key in ephemeron
function caml_ephe_unset_key(x, i)
  local old = caml_ephe_get_data(x)
  x[EPHE_KEY_OFFSET + i] = EPHE_NONE
  caml_ephe_set_data_opt(x, old)
  return 0
end

-- Get a key from ephemeron
function caml_ephe_get_key(x, i)
  local weak = x[EPHE_KEY_OFFSET + i]

  if weak == EPHE_NONE then
    return 0  -- None
  end

  -- Check if it's a weak holder
  if type(weak) == "table" and weak.value ~= nil then
    local val = weak.value
    if val == nil then
      -- Value was collected
      x[EPHE_KEY_OFFSET + i] = EPHE_NONE
      x[EPHE_DATA_OFFSET] = EPHE_NONE
      return 0
    end
    return {tag = 0, val}  -- Some(val)
  end

  -- Direct value (not weakly held)
  return {tag = 0, weak}
end

-- Get a copy of a key from ephemeron
function caml_ephe_get_key_copy(x, i)
  local y = caml_ephe_get_key(x, i)
  if y == 0 then
    return y
  end

  local z = y[1]
  if type(z) == "table" then
    -- Deep copy the table
    local copy = {}
    for k, v in pairs(z) do
      copy[k] = v
    end
    return {tag = 0, copy}
  end

  return y
end

-- Check if a key is still alive
function caml_ephe_check_key(x, i)
  local weak = x[EPHE_KEY_OFFSET + i]

  if weak == EPHE_NONE then
    return 0
  end

  -- Check if weak holder still has value
  if type(weak) == "table" and weak.value ~= nil then
    local val = weak.value
    if val == nil then
      -- Value was collected
      x[EPHE_KEY_OFFSET + i] = EPHE_NONE
      x[EPHE_DATA_OFFSET] = EPHE_NONE
      return 0
    end
  end

  return 1
end

-- Blit keys from one ephemeron to another
function caml_ephe_blit_key(a1, i1, a2, i2, len)
  local old = caml_ephe_get_data(a1)

  for j = 0, len - 1 do
    a2[EPHE_KEY_OFFSET + i2 + j] = a1[EPHE_KEY_OFFSET + i1 + j]
  end

  caml_ephe_set_data_opt(a2, old)
  return 0
end

-- Blit data from one ephemeron to another
function caml_ephe_blit_data(src, dst)
  local old = caml_ephe_get_data(src)
  caml_ephe_set_data_opt(dst, old)
  return 0
end

--
-- Data Management
--

-- Get data from ephemeron
function caml_ephe_get_data(x)
  local data = x[EPHE_DATA_OFFSET]

  if data == EPHE_NONE then
    return 0
  end

  -- Check if all keys are still alive
  for i = EPHE_KEY_OFFSET, #x do
    local k = x[i]
    if type(k) == "table" and k.value ~= nil then
      local val = k.value
      if val == nil then
        -- A key was collected, clear data
        x[i] = EPHE_NONE
        x[EPHE_DATA_OFFSET] = EPHE_NONE
        return 0
      end
    end
  end

  return {tag = 0, data}
end

-- Get a copy of data from ephemeron
function caml_ephe_get_data_copy(x)
  local r = caml_ephe_get_data(x)
  if r == 0 then
    return 0
  end

  local z = r[1]
  if type(z) == "table" then
    local copy = {}
    for k, v in pairs(z) do
      copy[k] = v
    end
    return {tag = 0, copy}
  end

  return r
end

-- Set data in ephemeron
function caml_ephe_set_data(x, data)
  -- Check if all keys are still alive
  for i = #x, EPHE_KEY_OFFSET, -1 do
    local k = x[i]
    if type(k) == "table" and k.value ~= nil then
      local val = k.value
      if val == nil then
        -- A key was collected
        x[i] = EPHE_NONE
      end
    end
  end

  x[EPHE_DATA_OFFSET] = data
  return 0
end

-- Set data optionally
function caml_ephe_set_data_opt(x, data_opt)
  if data_opt == 0 then
    caml_ephe_unset_data(x)
  else
    caml_ephe_set_data(x, data_opt[1])
  end
  return 0
end

-- Unset data in ephemeron
function caml_ephe_unset_data(x)
  x[EPHE_DATA_OFFSET] = EPHE_NONE
  return 0
end

-- Check if data is set
function caml_ephe_check_data(x)
  local data = caml_ephe_get_data(x)
  if data == 0 then
    return 0
  else
    return 1
  end
end

--
-- Weak Array API (simplified interface)
--

-- Set value in weak array
function caml_weak_set(x, i, v)
  if v == 0 then
    caml_ephe_unset_key(x, i)
  else
    caml_ephe_set_key(x, i, v[1])
  end
  return 0
end

-- Get value from weak array (alias for caml_ephe_get_key)
caml_weak_get = caml_ephe_get_key

-- Get copy from weak array (alias for caml_ephe_get_key_copy)
caml_weak_get_copy = caml_ephe_get_key_copy

-- Check weak array value (alias for caml_ephe_check_key)
caml_weak_check = caml_ephe_check_key

-- Blit weak array (alias for caml_ephe_blit_key)
caml_weak_blit = caml_ephe_blit_key

-- Export all functions as a module
local M = {
  caml_weak_create = caml_weak_create,
  caml_weak_set = caml_weak_set,
  caml_weak_get = caml_weak_get,
  caml_weak_get_copy = caml_weak_get_copy,
  caml_weak_check = caml_weak_check,
  caml_weak_blit = caml_weak_blit,
  caml_ephe_create = caml_ephe_create,
  caml_ephe_set_key = caml_ephe_set_key,
  caml_ephe_unset_key = caml_ephe_unset_key,
  caml_ephe_get_key = caml_ephe_get_key,
  caml_ephe_get_key_copy = caml_ephe_get_key_copy,
  caml_ephe_check_key = caml_ephe_check_key,
  caml_ephe_blit_key = caml_ephe_blit_key,
  caml_ephe_blit_data = caml_ephe_blit_data,
  caml_ephe_get_data = caml_ephe_get_data,
  caml_ephe_get_data_copy = caml_ephe_get_data_copy,
  caml_ephe_set_data = caml_ephe_set_data,
  caml_ephe_set_data_opt = caml_ephe_set_data_opt,
  caml_ephe_unset_data = caml_ephe_unset_data,
  caml_ephe_check_data = caml_ephe_check_data,
}

-- Add M.* aliases for naming convention
M.create = caml_weak_create
M.set = caml_weak_set
M.get = caml_weak_get

return M
