--Provides: caml_lazy_from_fun
function caml_lazy_from_fun(f)
  return {246, f}  -- LAZY_TAG (not yet evaluated)
end

--Provides: caml_lazy_make_forward
function caml_lazy_make_forward(v)
  return {250, v}  -- FORWARD_TAG (already evaluated)
end

--Provides: caml_lazy_from_val
function caml_lazy_from_val(v)
  return {250, v}  -- FORWARD_TAG (already evaluated)
end


--Provides: caml_lazy_update_to_forcing
function caml_lazy_update_to_forcing(lazy_val)
  if lazy_val[1] == 246 then  -- LAZY_TAG
    lazy_val[1] = 244  -- FORCING_TAG (currently being evaluated)
    return 0
  else
    return 1
  end
end

--Provides: caml_lazy_update_to_forward
function caml_lazy_update_to_forward(lazy_val)
  if lazy_val[1] == 244 then  -- FORCING_TAG
    lazy_val[1] = 250  -- FORWARD_TAG
  end
  return 0
end

--Provides: caml_lazy_reset_to_lazy
function caml_lazy_reset_to_lazy(lazy_val)
  if lazy_val[1] == 244 then  -- FORCING_TAG
    lazy_val[1] = 246  -- LAZY_TAG
  end
  return 0
end

--Provides: caml_lazy_read_result
function caml_lazy_read_result(lazy_val)
  if lazy_val[1] == 250 then  -- FORWARD_TAG
    return lazy_val[2]
  else
    return lazy_val
  end
end


--Provides: caml_lazy_force
function caml_lazy_force(lazy_val)
  local tag = lazy_val[1]

  if tag == 250 then  -- FORWARD_TAG
    return lazy_val[2]
  end

  if tag == 244 then  -- FORCING_TAG
    error("Lazy value is undefined (recursive forcing)")
  end

  if tag == 246 then  -- LAZY_TAG
    local update_result = caml_lazy_update_to_forcing(lazy_val)
    if update_result ~= 0 then
      error("Lazy value race condition")
    end

    local thunk = lazy_val[2]

    local success, result = pcall(thunk)

    if success then
      lazy_val[2] = result
      caml_lazy_update_to_forward(lazy_val)
      return result
    else
      caml_lazy_reset_to_lazy(lazy_val)
      error(result)
    end
  end

  error("Invalid lazy value tag: " .. tostring(tag))
end

--Provides: caml_lazy_force_val
--Requires: caml_lazy_force
function caml_lazy_force_val(lazy_val)
  return caml_lazy_force(lazy_val)
end


--Provides: caml_lazy_is_val
function caml_lazy_is_val(lazy_val)
  return lazy_val[1] == 250  -- FORWARD_TAG
end

--Provides: caml_lazy_is_forcing
function caml_lazy_is_forcing(lazy_val)
  return lazy_val[1] == 244  -- FORCING_TAG
end

--Provides: caml_lazy_is_lazy
function caml_lazy_is_lazy(lazy_val)
  return lazy_val[1] == 246  -- LAZY_TAG
end


--Provides: caml_lazy_map
--Requires: caml_lazy_force, caml_lazy_from_fun
function caml_lazy_map(f, lazy_val)
  local thunk = function()
    local value = caml_lazy_force(lazy_val)
    return f(value)
  end
  return caml_lazy_from_fun(thunk)
end

--Provides: caml_lazy_map2
--Requires: caml_lazy_force, caml_lazy_from_fun
function caml_lazy_map2(f, lazy_val1, lazy_val2)
  local thunk = function()
    local value1 = caml_lazy_force(lazy_val1)
    local value2 = caml_lazy_force(lazy_val2)
    return f(value1, value2)
  end
  return caml_lazy_from_fun(thunk)
end


--Provides: caml_lazy_tag
function caml_lazy_tag(lazy_val)
  return lazy_val[1]
end

--Provides: caml_lazy_from_exception
--Requires: caml_lazy_from_fun
function caml_lazy_from_exception(exn)
  local thunk = function()
    error(exn)
  end
  return caml_lazy_from_fun(thunk)
end

--Provides: caml_lazy_force_unit
--Requires: caml_lazy_force
function caml_lazy_force_unit(lazy_val)
  caml_lazy_force(lazy_val)
  return 0  -- unit
end