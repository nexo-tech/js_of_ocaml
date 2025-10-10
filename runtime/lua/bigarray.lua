-- Lua_of_ocaml runtime support
-- Bigarray support (OCaml Bigarray module)
--
-- Provides multi-dimensional arrays with various numeric types.
-- Supports both C layout (row-major) and Fortran layout (column-major).
--
-- Note: Lua doesn't have typed arrays like JavaScript. We use regular tables
-- with metadata to track element kind and provide bounds checking.

--Provides: caml_ba_get_size_per_element
function caml_ba_get_size_per_element(kind)
  -- Element size per kind (in number of storage elements)
  -- kind values: FLOAT32=0, FLOAT64=1, INT8_SIGNED=2, INT8_UNSIGNED=3,
  --   INT16_SIGNED=4, INT16_UNSIGNED=5, INT32=6, INT64=7, NATIVEINT=8,
  --   CAML_INT=9, COMPLEX32=10, COMPLEX64=11, CHAR=12, FLOAT16=13
  if kind == 7 or kind == 10 or kind == 11 then
    -- INT64 or COMPLEX32 or COMPLEX64
    return 2  -- Stored as 2 numbers
  else
    return 1
  end
end

--Provides: caml_ba_clamp_value
function caml_ba_clamp_value(kind, value)
  -- Range clamping for different kinds
  if kind == 2 then
    -- INT8_SIGNED
    value = math.floor(value)
    if value < -128 then return -128 end
    if value > 127 then return 127 end
    return value
  elseif kind == 3 or kind == 12 then
    -- INT8_UNSIGNED or CHAR
    value = math.floor(value)
    if value < 0 then return 0 end
    if value > 255 then return 255 end
    return value
  elseif kind == 4 then
    -- INT16_SIGNED
    value = math.floor(value)
    if value < -32768 then return -32768 end
    if value > 32767 then return 32767 end
    return value
  elseif kind == 5 then
    -- INT16_UNSIGNED
    value = math.floor(value)
    if value < 0 then return 0 end
    if value > 65535 then return 65535 end
    return value
  elseif kind == 6 or kind == 8 or kind == 9 then
    -- INT32 or NATIVEINT or CAML_INT
    return math.floor(value)
  else
    -- Float types: no clamping, just return as-is
    return value
  end
end

--Provides: caml_ba_create_buffer
--Requires: caml_ba_get_size_per_element
function caml_ba_create_buffer(kind, size)
  -- Create buffer for bigarray data
  local elem_size = caml_ba_get_size_per_element(kind)
  local total_size = size * elem_size
  local buffer = {}

  -- Initialize all elements to 0
  for i = 1, total_size do
    buffer[i] = 0
  end

  return buffer
end

--Provides: caml_ba_get_size
function caml_ba_get_size(dims)
  -- Get total size from dimensions
  local size = 1
  for i = 1, #dims do
    if dims[i] < 0 then
      error("Bigarray.create: negative dimension")
    end
    size = size * dims[i]
  end
  return size
end

--Provides: caml_ba_create_unsafe
function caml_ba_create_unsafe(kind, layout, dims, data)
  -- Create bigarray (unsafe, no validation)
  -- BA_CUSTOM_NAME = "_bigarr02"
  return {
    kind = kind,
    layout = layout,
    dims = dims,
    data = data,
    caml_custom = "_bigarr02"
  }
end

--Provides: caml_ba_create
--Requires: caml_ba_get_size, caml_ba_create_buffer, caml_ba_create_unsafe
function caml_ba_create(kind, layout, dims_ml)
  -- Create bigarray with validation
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

  local size = caml_ba_get_size(dims)
  local data = caml_ba_create_buffer(kind, size)
  return caml_ba_create_unsafe(kind, layout, dims, data)
end

--Provides: caml_ba_init
function caml_ba_init()
  -- Initialize bigarray module
  return 0
end

--Provides: caml_ba_kind
function caml_ba_kind(ba)
  -- Get bigarray kind
  return ba.kind
end

--Provides: caml_ba_layout
function caml_ba_layout(ba)
  -- Get bigarray layout
  return ba.layout
end

--Provides: caml_ba_num_dims
function caml_ba_num_dims(ba)
  -- Get number of dimensions
  return #ba.dims
end

--Provides: caml_ba_dim
function caml_ba_dim(ba, i)
  -- Get dimension size
  if i < 0 or i >= #ba.dims then
    error("Bigarray.dim")
  end
  return ba.dims[i + 1]  -- Lua is 1-indexed
end

--Provides: caml_ba_dim_1
--Requires: caml_ba_dim
function caml_ba_dim_1(ba)
  -- Get first dimension
  return caml_ba_dim(ba, 0)
end

--Provides: caml_ba_dim_2
--Requires: caml_ba_dim
function caml_ba_dim_2(ba)
  -- Get second dimension
  return caml_ba_dim(ba, 1)
end

--Provides: caml_ba_dim_3
--Requires: caml_ba_dim
function caml_ba_dim_3(ba)
  -- Get third dimension
  return caml_ba_dim(ba, 2)
end

--Provides: caml_ba_change_layout
--Requires: caml_ba_create_unsafe
function caml_ba_change_layout(ba, layout)
  -- Change bigarray layout
  if ba.layout == layout then
    return ba
  end

  -- Reverse dimensions for layout change
  local new_dims = {}
  for i = #ba.dims, 1, -1 do
    table.insert(new_dims, ba.dims[i])
  end

  return caml_ba_create_unsafe(ba.kind, layout, new_dims, ba.data)
end

--Provides: caml_ba_calculate_offset
function caml_ba_calculate_offset(ba, indices)
  -- Calculate linear offset from multi-dimensional index
  local ofs = 0
  -- LAYOUT: C_LAYOUT=0, FORTRAN_LAYOUT=1

  if ba.layout == 0 then
    -- C layout: row-major, 0-indexed
    for i = 1, #ba.dims do
      local idx = indices[i]
      if idx < 0 or idx >= ba.dims[i] then
        error("array bound error")
      end
      ofs = ofs * ba.dims[i] + idx
    end
  else
    -- Fortran layout: column-major, 1-indexed
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

--Provides: caml_ba_get_generic
--Requires: caml_ba_calculate_offset, caml_ba_get_size_per_element
function caml_ba_get_generic(ba, indices)
  -- Get element at indices
  local ofs = caml_ba_calculate_offset(ba, indices)
  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64: stored as two Int32s
    local lo = ba.data[ofs * elem_size + 1]
    local hi = ba.data[ofs * elem_size + 2]
    return {lo, hi}  -- OCaml int64 representation
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64: stored as (real, imag)
    local re = ba.data[ofs * elem_size + 1]
    local im = ba.data[ofs * elem_size + 2]
    return {tag = 0, re, im}  -- OCaml complex representation
  else
    -- Simple scalar types
    return ba.data[ofs + 1]
  end
end

--Provides: caml_ba_set_generic
--Requires: caml_ba_calculate_offset, caml_ba_get_size_per_element, caml_ba_clamp_value
function caml_ba_set_generic(ba, indices, value)
  -- Set element at indices
  local ofs = caml_ba_calculate_offset(ba, indices)
  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64: store as two Int32s
    ba.data[ofs * elem_size + 1] = value[1]  -- lo
    ba.data[ofs * elem_size + 2] = value[2]  -- hi
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64: store as (real, imag)
    ba.data[ofs * elem_size + 1] = value[1]  -- real
    ba.data[ofs * elem_size + 2] = value[2]  -- imag
  else
    -- Simple scalar types
    ba.data[ofs + 1] = caml_ba_clamp_value(ba.kind, value)
  end

  return 0  -- unit
end

--Provides: caml_ba_get_1
--Requires: caml_ba_get_generic
function caml_ba_get_1(ba, i0)
  -- Get element from 1D array
  return caml_ba_get_generic(ba, {i0})
end

--Provides: caml_ba_set_1
--Requires: caml_ba_set_generic
function caml_ba_set_1(ba, i0, value)
  -- Set element in 1D array
  return caml_ba_set_generic(ba, {i0}, value)
end

--Provides: caml_ba_unsafe_get_1
--Requires: caml_ba_get_size_per_element
function caml_ba_unsafe_get_1(ba, i0)
  -- Unsafe get (no bounds check)
  local ofs = ba.layout == 0 and i0 or (i0 - 1)
  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64
    return {ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64
    return {tag = 0, ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  else
    return ba.data[ofs + 1]
  end
end

--Provides: caml_ba_unsafe_set_1
--Requires: caml_ba_get_size_per_element, caml_ba_clamp_value
function caml_ba_unsafe_set_1(ba, i0, value)
  -- Unsafe set (no bounds check)
  local ofs = ba.layout == 0 and i0 or (i0 - 1)
  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  else
    ba.data[ofs + 1] = caml_ba_clamp_value(ba.kind, value)
  end

  return 0
end

--Provides: caml_ba_get_2
--Requires: caml_ba_get_generic
function caml_ba_get_2(ba, i0, i1)
  return caml_ba_get_generic(ba, {i0, i1})
end

--Provides: caml_ba_set_2
--Requires: caml_ba_set_generic
function caml_ba_set_2(ba, i0, i1, value)
  return caml_ba_set_generic(ba, {i0, i1}, value)
end

--Provides: caml_ba_unsafe_get_2
--Requires: caml_ba_get_size_per_element
function caml_ba_unsafe_get_2(ba, i0, i1)
  -- For unsafe, skip bounds check
  local ofs = 0

  if ba.layout == 0 then
    -- C layout: row-major, 0-indexed
    ofs = i0 * ba.dims[2] + i1
  else
    -- Fortran layout: column-major, 1-indexed
    ofs = (i1 - 1) * ba.dims[1] + (i0 - 1)
  end

  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64
    return {ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64
    return {tag = 0, ba.data[ofs * elem_size + 1], ba.data[ofs * elem_size + 2]}
  else
    return ba.data[ofs + 1]
  end
end

--Provides: caml_ba_unsafe_set_2
--Requires: caml_ba_get_size_per_element, caml_ba_clamp_value
function caml_ba_unsafe_set_2(ba, i0, i1, value)
  local ofs = 0

  if ba.layout == 0 then
    -- C layout: row-major, 0-indexed
    ofs = i0 * ba.dims[2] + i1
  else
    -- Fortran layout: column-major, 1-indexed
    ofs = (i1 - 1) * ba.dims[1] + (i0 - 1)
  end

  local elem_size = caml_ba_get_size_per_element(ba.kind)

  if ba.kind == 7 then
    -- INT64
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64
    ba.data[ofs * elem_size + 1] = value[1]
    ba.data[ofs * elem_size + 2] = value[2]
  else
    ba.data[ofs + 1] = caml_ba_clamp_value(ba.kind, value)
  end

  return 0
end

--Provides: caml_ba_get_3
--Requires: caml_ba_get_generic
function caml_ba_get_3(ba, i0, i1, i2)
  return caml_ba_get_generic(ba, {i0, i1, i2})
end

--Provides: caml_ba_set_3
--Requires: caml_ba_set_generic
function caml_ba_set_3(ba, i0, i1, i2, value)
  return caml_ba_set_generic(ba, {i0, i1, i2}, value)
end

--Provides: caml_ba_sub
--Requires: caml_ba_get_size_per_element, caml_ba_create_unsafe
function caml_ba_sub(ba, ofs, len)
  -- Create sub-array (shares data with parent)
  if #ba.dims ~= 1 then
    error("Bigarray.sub: only for 1D arrays")
  end

  local elem_size = caml_ba_get_size_per_element(ba.kind)

  -- Create shallow copy of data starting at offset
  local new_data = {}
  local start_ofs = ofs * elem_size + 1
  for i = 0, len * elem_size - 1 do
    new_data[i + 1] = ba.data[start_ofs + i]
  end

  return caml_ba_create_unsafe(ba.kind, ba.layout, {len}, new_data)
end

--Provides: caml_ba_slice_left
function caml_ba_slice_left(ba, indices)
  -- Slice array along first dimension
  error("Bigarray.slice_left: not yet implemented")
end

--Provides: caml_ba_slice_right
function caml_ba_slice_right(ba, indices)
  -- Slice array along last dimension
  error("Bigarray.slice_right: not yet implemented")
end

--Provides: caml_ba_fill
--Requires: caml_ba_get_size_per_element, caml_ba_get_size, caml_ba_clamp_value
function caml_ba_fill(ba, value)
  -- Fill bigarray with value
  local elem_size = caml_ba_get_size_per_element(ba.kind)
  local total_elems = caml_ba_get_size(ba.dims)

  if ba.kind == 7 then
    -- INT64
    for i = 0, total_elems - 1 do
      ba.data[i * elem_size + 1] = value[1]
      ba.data[i * elem_size + 2] = value[2]
    end
  elseif ba.kind == 10 or ba.kind == 11 then
    -- COMPLEX32 or COMPLEX64
    for i = 0, total_elems - 1 do
      ba.data[i * elem_size + 1] = value[1]
      ba.data[i * elem_size + 2] = value[2]
    end
  else
    local clamped = caml_ba_clamp_value(ba.kind, value)
    for i = 1, total_elems do
      ba.data[i] = clamped
    end
  end

  return 0
end

--Provides: caml_ba_blit
function caml_ba_blit(src, dst)
  -- Blit (copy) from src to dst
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

--Provides: caml_ba_reshape
--Requires: caml_ba_get_size, caml_ba_create_unsafe
function caml_ba_reshape(ba, new_dims_ml)
  -- Reshape bigarray to new dimensions
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

  local old_size = caml_ba_get_size(ba.dims)
  local new_size = caml_ba_get_size(new_dims)

  if old_size ~= new_size then
    error("Bigarray.reshape: size mismatch")
  end

  return caml_ba_create_unsafe(ba.kind, ba.layout, new_dims, ba.data)
end
