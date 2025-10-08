-- Lua_of_ocaml runtime support
-- Bigarray support (OCaml Bigarray module)
--
-- Provides multi-dimensional arrays with various numeric types.
-- Supports both C layout (row-major) and Fortran layout (column-major).
--
-- Note: Lua doesn't have typed arrays like JavaScript. We use regular tables
-- with metadata to track element kind and provide bounds checking.

local M = {}

-- Bigarray custom name for marshalling
local BA_CUSTOM_NAME = "_bigarr02"

-- Bigarray kinds (matching OCaml)
local KIND = {
  FLOAT32 = 0,
  FLOAT64 = 1,
  INT8_SIGNED = 2,
  INT8_UNSIGNED = 3,
  INT16_SIGNED = 4,
  INT16_UNSIGNED = 5,
  INT32 = 6,
  INT64 = 7,
  NATIVEINT = 8,
  CAML_INT = 9,
  COMPLEX32 = 10,
  COMPLEX64 = 11,
  CHAR = 12,
  FLOAT16 = 13,
}

-- Layout types
local LAYOUT = {
  C_LAYOUT = 0,      -- Row-major (C style)
  FORTRAN_LAYOUT = 1 -- Column-major (Fortran style)
}

-- Element size per kind (in number of storage elements)
local function get_size_per_element(kind)
  if kind == KIND.INT64 or kind == KIND.COMPLEX32 or kind == KIND.COMPLEX64 then
    return 2  -- Stored as 2 numbers
  else
    return 1
  end
end

-- Range clamping for different kinds
local function clamp_value(kind, value)
  if kind == KIND.INT8_SIGNED then
    value = math.floor(value)
    if value < -128 then return -128 end
    if value > 127 then return 127 end
    return value
  elseif kind == KIND.INT8_UNSIGNED or kind == KIND.CHAR then
    value = math.floor(value)
    if value < 0 then return 0 end
    if value > 255 then return 255 end
    return value
  elseif kind == KIND.INT16_SIGNED then
    value = math.floor(value)
    if value < -32768 then return -32768 end
    if value > 32767 then return 32767 end
    return value
  elseif kind == KIND.INT16_UNSIGNED then
    value = math.floor(value)
    if value < 0 then return 0 end
    if value > 65535 then return 65535 end
    return value
  elseif kind == KIND.INT32 or kind == KIND.NATIVEINT or kind == KIND.CAML_INT then
    return math.floor(value)
  else
    -- Float types: no clamping, just return as-is
    return value
  end
end

--
-- Bigarray Creation
--

-- Get total size from dimensions
function M.caml_ba_get_size(dims)
  local size = 1
  for i = 1, #dims do
    if dims[i] < 0 then
      error("Bigarray.create: negative dimension")
    end
    size = size * dims[i]
  end
  return size
end

-- Create buffer for bigarray data
local function create_buffer(kind, size)
  local elem_size = get_size_per_element(kind)
  local total_size = size * elem_size
  local buffer = {}

  -- Initialize all elements to 0
  for i = 1, total_size do
    buffer[i] = 0
  end

  return buffer
end

-- Create bigarray (unsafe, no validation)
function M.caml_ba_create_unsafe(kind, layout, dims, data)
  return {
    kind = kind,
    layout = layout,
    dims = dims,
    data = data,
    caml_custom = BA_CUSTOM_NAME
  }
end

-- Create bigarray with validation
function M.caml_ba_create(kind, layout, dims_ml)
  -- dims_ml can be either a Lua table or OCaml array representation
  local dims
  if type(dims_ml) == "table" then
    if dims_ml[0] ~= nil then
      -- OCaml array (0-indexed)
      dims = {}
      for i = 0, #dims_ml do
        if dims_ml[i] ~= nil then
          table.insert(dims, dims_ml[i])
        end
      end
    else
      -- Plain Lua table (1-indexed)
      dims = dims_ml
    end
  else
    error("Bigarray.create: invalid dims")
  end

  local size = M.caml_ba_get_size(dims)
  local data = create_buffer(kind, size)
  return M.caml_ba_create_unsafe(kind, layout, dims, data)
end

-- Initialize bigarray module
function M.caml_ba_init()
  return 0
end

--
-- Bigarray Properties
--

-- Get bigarray kind
function M.caml_ba_kind(ba)
  return ba.kind
end

-- Get bigarray layout
function M.caml_ba_layout(ba)
  return ba.layout
end

-- Get number of dimensions
function M.caml_ba_num_dims(ba)
  return #ba.dims
end

-- Get dimension size
function M.caml_ba_dim(ba, i)
  if i < 0 or i >= #ba.dims then
    error("Bigarray.dim")
  end
  return ba.dims[i + 1]  -- Lua is 1-indexed
end

-- Get first dimension
function M.caml_ba_dim_1(ba)
  return M.caml_ba_dim(ba, 0)
end

-- Get second dimension
function M.caml_ba_dim_2(ba)
  return M.caml_ba_dim(ba, 1)
end

-- Get third dimension
function M.caml_ba_dim_3(ba)
  return M.caml_ba_dim(ba, 2)
end

--
-- Layout Operations
--

-- Change bigarray layout
function M.caml_ba_change_layout(ba, layout)
  if ba.layout == layout then
    return ba
  end

  -- Reverse dimensions for layout change
  local new_dims = {}
  for i = #ba.dims, 1, -1 do
    table.insert(new_dims, ba.dims[i])
  end

  return M.caml_ba_create_unsafe(ba.kind, layout, new_dims, ba.data)
end

--
-- Index Calculation
--

-- Calculate linear offset from multi-dimensional index
local function calculate_offset(ba, indices)
  local ofs = 0

  if ba.layout == LAYOUT.C_LAYOUT then
    -- C layout: row-major
    for i = 1, #ba.dims do
      local idx = indices[i]
      if idx < 0 or idx >= ba.dims[i] then
        error("array bound error")
      end
      ofs = ofs * ba.dims[i] + idx
    end
  else
    -- Fortran layout: column-major (1-indexed)
    for i = #ba.dims, 1, -1 do
      local idx = indices[i]
      if idx < 1 or idx > ba.dims[i] then
        error("array bound error")
      end
      ofs = ofs * ba.dims[i] + (idx - 1)
    end
  end

  return ofs
end

--
-- Element Access
--

-- Get element at indices
function M.caml_ba_get_generic(ba, indices)
  local ofs = calculate_offset(ba, indices)
  local elem_size = get_size_per_element(ba.kind)

  if ba.kind == KIND.INT64 then
    -- Int64: stored as two Int32s
    local lo = ba.data[ofs * elem_size + 1]
    local hi = ba.data[ofs * elem_size + 2]
    return {lo, hi}  -- OCaml int64 representation
  elseif ba.kind == KIND.COMPLEX32 or ba.kind == KIND.COMPLEX64 then
    -- Complex: stored as (real, imag)
    local re = ba.data[ofs * elem_size + 1]
    local im = ba.data[ofs * elem_size + 2]
    return {tag = 0, re, im}  -- OCaml complex representation
  else
    -- Simple scalar types
    return ba.data[ofs + 1]
  end
end

-- Set element at indices
function M.caml_ba_set_generic(ba, indices, value)
  local ofs = calculate_offset(ba, indices)
  local elem_size = get_size_per_element(ba.kind)

  if ba.kind == KIND.INT64 then
    -- Int64: store as two Int32s
    ba.data[ofs * elem_size + 1] = value[1]  -- lo
    ba.data[ofs * elem_size + 2] = value[2]  -- hi
  elseif ba.kind == KIND.COMPLEX32 or ba.kind == KIND.COMPLEX64 then
    -- Complex: store as (real, imag)
    ba.data[ofs * elem_size + 1] = value[1]  -- real
    ba.data[ofs * elem_size + 2] = value[2]  -- imag
  else
    -- Simple scalar types
    ba.data[ofs + 1] = clamp_value(ba.kind, value)
  end

  return 0  -- unit
end

--
-- 1D Array Fast Paths
--

-- Get element from 1D array
function M.caml_ba_get_1(ba, i0)
  return M.caml_ba_get_generic(ba, {i0})
end

-- Set element in 1D array
function M.caml_ba_set_1(ba, i0, value)
  return M.caml_ba_set_generic(ba, {i0}, value)
end

-- Unsafe get (no bounds check)
function M.caml_ba_unsafe_get_1(ba, i0)
  local ofs = ba.layout == LAYOUT.C_LAYOUT and i0 or (i0 - 1)
  local elem_size = get_size_per_element(ba.kind)

  if ba.kind == KIND.INT64 then
    return {ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  elseif ba.kind == KIND.COMPLEX32 or ba.kind == KIND.COMPLEX64 then
    return {tag = 0, ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  else
    return ba.data[ofs + 1]
  end
end

-- Unsafe set (no bounds check)
function M.caml_ba_unsafe_set_1(ba, i0, value)
  local ofs = ba.layout == LAYOUT.C_LAYOUT and i0 or (i0 - 1)
  local elem_size = get_size_per_element(ba.kind)

  if ba.kind == KIND.INT64 then
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  elseif ba.kind == KIND.COMPLEX32 or ba.kind == KIND.COMPLEX64 then
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  else
    ba.data[ofs + 1] = clamp_value(ba.kind, value)
  end

  return 0
end

--
-- 2D Array Operations
--

function M.caml_ba_get_2(ba, i0, i1)
  return M.caml_ba_get_generic(ba, {i0, i1})
end

function M.caml_ba_set_2(ba, i0, i1, value)
  return M.caml_ba_set_generic(ba, {i0, i1}, value)
end

function M.caml_ba_unsafe_get_2(ba, i0, i1)
  -- For unsafe, skip bounds check
  local ofs = 0

  if ba.layout == LAYOUT.C_LAYOUT then
    -- C layout: row-major, 0-indexed
    ofs = i0 * ba.dims[2] + i1
  else
    -- Fortran layout: column-major, 1-indexed
    ofs = (i1 - 1) * ba.dims[1] + (i0 - 1)
  end

  local elem_size = get_size_per_element(ba.kind)

  if ba.kind == KIND.INT64 then
    return {ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  elseif ba.kind == KIND.COMPLEX32 or ba.kind == KIND.COMPLEX64 then
    return {tag = 0, ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  else
    return ba.data[ofs + 1]
  end
end

function M.caml_ba_unsafe_set_2(ba, i0, i1, value)
  local ofs = 0

  if ba.layout == LAYOUT.C_LAYOUT then
    -- C layout: row-major, 0-indexed
    ofs = i0 * ba.dims[2] + i1
  else
    -- Fortran layout: column-major, 1-indexed
    ofs = (i1 - 1) * ba.dims[1] + (i0 - 1)
  end

  local elem_size = get_size_per_element(ba.kind)

  if ba.kind == KIND.INT64 then
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  elseif ba.kind == KIND.COMPLEX32 or ba.kind == KIND.COMPLEX64 then
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  else
    ba.data[ofs + 1] = clamp_value(ba.kind, value)
  end

  return 0
end

--
-- 3D Array Operations
--

function M.caml_ba_get_3(ba, i0, i1, i2)
  return M.caml_ba_get_generic(ba, {i0, i1, i2})
end

function M.caml_ba_set_3(ba, i0, i1, i2, value)
  return M.caml_ba_set_generic(ba, {i0, i1, i2}, value)
end

--
-- Sub-array and Slicing
--

-- Create sub-array (shares data with parent)
function M.caml_ba_sub(ba, ofs, len)
  -- For 1D arrays, create view with offset
  if #ba.dims ~= 1 then
    error("Bigarray.sub: only for 1D arrays")
  end

  local elem_size = get_size_per_element(ba.kind)

  -- Create shallow copy of data starting at offset
  local new_data = {}
  local start_ofs = ofs * elem_size + 1
  for i = 0, len * elem_size - 1 do
    new_data[i + 1] = ba.data[start_ofs + i]
  end

  return M.caml_ba_create_unsafe(ba.kind, ba.layout, {len}, new_data)
end

-- Slice array along first dimension
function M.caml_ba_slice_left(ba, indices)
  error("Bigarray.slice_left: not yet implemented")
end

-- Slice array along last dimension
function M.caml_ba_slice_right(ba, indices)
  error("Bigarray.slice_right: not yet implemented")
end

--
-- Fill and Blit
--

-- Fill bigarray with value
function M.caml_ba_fill(ba, value)
  local elem_size = get_size_per_element(ba.kind)
  local total_elems = M.caml_ba_get_size(ba.dims)

  if ba.kind == KIND.INT64 then
    for i = 0, total_elems - 1 do
      ba.data[i * elem_size + 1] = value[1]
      ba.data[i * elem_size + 2] = value[2]
    end
  elseif ba.kind == KIND.COMPLEX32 or ba.kind == KIND.COMPLEX64 then
    for i = 0, total_elems - 1 do
      ba.data[i * elem_size + 1] = value[1]
      ba.data[i * elem_size + 2] = value[2]
    end
  else
    local clamped = clamp_value(ba.kind, value)
    for i = 1, total_elems do
      ba.data[i] = clamped
    end
  end

  return 0
end

-- Blit (copy) from src to dst
function M.caml_ba_blit(src, dst)
  if src.kind ~= dst.kind then
    error("Bigarray.blit: kind mismatch")
  end

  if #src.dims ~= #dst.dims then
    error("Bigarray.blit: dimension mismatch")
  end

  for i = 1, #src.dims do
    if src.dims[i] ~= dst.dims[i] then
      error("Bigarray.blit: dimension mismatch")
    end
  end

  -- Copy data
  for i = 1, #src.data do
    dst.data[i] = src.data[i]
  end

  return 0
end

--
-- Reshape
--

-- Reshape bigarray to new dimensions
function M.caml_ba_reshape(ba, new_dims_ml)
  -- Handle both OCaml arrays and Lua tables
  local new_dims
  if type(new_dims_ml) == "table" then
    if new_dims_ml[0] ~= nil then
      -- OCaml array (0-indexed)
      new_dims = {}
      for i = 0, #new_dims_ml do
        if new_dims_ml[i] ~= nil then
          table.insert(new_dims, new_dims_ml[i])
        end
      end
    else
      -- Plain Lua table (1-indexed)
      new_dims = new_dims_ml
    end
  else
    error("Bigarray.reshape: invalid dims")
  end

  local old_size = M.caml_ba_get_size(ba.dims)
  local new_size = M.caml_ba_get_size(new_dims)

  if old_size ~= new_size then
    error("Bigarray.reshape: size mismatch")
  end

  return M.caml_ba_create_unsafe(ba.kind, ba.layout, new_dims, ba.data)
end

--
-- Module Exports
--

return {
  -- Constants
  KIND = KIND,
  LAYOUT = LAYOUT,

  -- Creation
  caml_ba_init = M.caml_ba_init,
  caml_ba_create = M.caml_ba_create,
  caml_ba_create_unsafe = M.caml_ba_create_unsafe,
  caml_ba_get_size = M.caml_ba_get_size,

  -- Properties
  caml_ba_kind = M.caml_ba_kind,
  caml_ba_layout = M.caml_ba_layout,
  caml_ba_num_dims = M.caml_ba_num_dims,
  caml_ba_dim = M.caml_ba_dim,
  caml_ba_dim_1 = M.caml_ba_dim_1,
  caml_ba_dim_2 = M.caml_ba_dim_2,
  caml_ba_dim_3 = M.caml_ba_dim_3,

  -- Layout
  caml_ba_change_layout = M.caml_ba_change_layout,

  -- Element access (generic)
  caml_ba_get_generic = M.caml_ba_get_generic,
  caml_ba_set_generic = M.caml_ba_set_generic,

  -- 1D array operations
  caml_ba_get_1 = M.caml_ba_get_1,
  caml_ba_set_1 = M.caml_ba_set_1,
  caml_ba_unsafe_get_1 = M.caml_ba_unsafe_get_1,
  caml_ba_unsafe_set_1 = M.caml_ba_unsafe_set_1,

  -- 2D array operations
  caml_ba_get_2 = M.caml_ba_get_2,
  caml_ba_set_2 = M.caml_ba_set_2,
  caml_ba_unsafe_get_2 = M.caml_ba_unsafe_get_2,
  caml_ba_unsafe_set_2 = M.caml_ba_unsafe_set_2,

  -- 3D array operations
  caml_ba_get_3 = M.caml_ba_get_3,
  caml_ba_set_3 = M.caml_ba_set_3,

  -- Sub-array and slicing
  caml_ba_sub = M.caml_ba_sub,
  caml_ba_slice_left = M.caml_ba_slice_left,
  caml_ba_slice_right = M.caml_ba_slice_right,

  -- Fill and blit
  caml_ba_fill = M.caml_ba_fill,
  caml_ba_blit = M.caml_ba_blit,

  -- Reshape
  caml_ba_reshape = M.caml_ba_reshape,
}
