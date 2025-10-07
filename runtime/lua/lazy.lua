-- Lua_of_ocaml runtime support
-- Standard Library: Lazy module
--
-- OCaml lazy values are represented as:
-- [tag, value] where:
--   tag = 246: Lazy (not yet evaluated, value is thunk function)
--   tag = 244: Forcing (currently being evaluated)
--   tag = 250: Forward (evaluated, value is the result)

-- Lazy value tags
local LAZY_TAG = 246      -- Not yet evaluated
local FORCING_TAG = 244   -- Currently being evaluated
local FORWARD_TAG = 250   -- Already evaluated

--
-- Lazy construction
--

-- Create a lazy value from a thunk function
function caml_lazy_from_fun(f)
  return {LAZY_TAG, f}
end

-- Create an already-evaluated lazy value
function caml_lazy_make_forward(v)
  return {FORWARD_TAG, v}
end

-- Create a lazy value from a normal value (wraps it as evaluated)
function caml_lazy_from_val(v)
  return {FORWARD_TAG, v}
end

--
-- Lazy state management
--

-- Try to update lazy value to forcing state (returns 0 on success, 1 on failure)
function caml_lazy_update_to_forcing(lazy_val)
  if lazy_val[1] == LAZY_TAG then
    lazy_val[1] = FORCING_TAG
    return 0
  else
    return 1
  end
end

-- Update forcing value to forward state with result
function caml_lazy_update_to_forward(lazy_val)
  if lazy_val[1] == FORCING_TAG then
    lazy_val[1] = FORWARD_TAG
  end
  return 0
end

-- Reset forcing value back to lazy (used on exception)
function caml_lazy_reset_to_lazy(lazy_val)
  if lazy_val[1] == FORCING_TAG then
    lazy_val[1] = LAZY_TAG
  end
  return 0
end

-- Read the result from a lazy value (only call after forcing)
function caml_lazy_read_result(lazy_val)
  if lazy_val[1] == FORWARD_TAG then
    return lazy_val[2]
  else
    return lazy_val
  end
end

--
-- Lazy forcing
--

-- Force evaluation of a lazy value
function caml_lazy_force(lazy_val)
  local tag = lazy_val[1]

  -- Already evaluated
  if tag == FORWARD_TAG then
    return lazy_val[2]
  end

  -- Currently being evaluated (infinite loop detected)
  if tag == FORCING_TAG then
    error("Lazy value is undefined (recursive forcing)")
  end

  -- Not yet evaluated
  if tag == LAZY_TAG then
    -- Mark as forcing to detect recursion
    local update_result = caml_lazy_update_to_forcing(lazy_val)
    if update_result ~= 0 then
      -- Another thread is forcing, should not happen in single-threaded Lua
      error("Lazy value race condition")
    end

    -- Get the thunk function
    local thunk = lazy_val[2]

    -- Evaluate the thunk with exception handling
    local success, result = pcall(thunk)

    if success then
      -- Store the result
      lazy_val[2] = result
      -- Mark as evaluated
      caml_lazy_update_to_forward(lazy_val)
      return result
    else
      -- Exception occurred, reset to lazy state
      caml_lazy_reset_to_lazy(lazy_val)
      -- Re-throw the exception
      error(result)
    end
  end

  -- Unknown tag
  error("Invalid lazy value tag: " .. tostring(tag))
end

-- Force and return the value (alias for caml_lazy_force)
function caml_lazy_force_val(lazy_val)
  return caml_lazy_force(lazy_val)
end

--
-- Lazy queries
--

-- Check if lazy value has been forced
function caml_lazy_is_val(lazy_val)
  return lazy_val[1] == FORWARD_TAG
end

-- Check if lazy value is currently being forced
function caml_lazy_is_forcing(lazy_val)
  return lazy_val[1] == FORCING_TAG
end

-- Check if lazy value is lazy (not yet evaluated)
function caml_lazy_is_lazy(lazy_val)
  return lazy_val[1] == LAZY_TAG
end

--
-- Lazy mapping
--

-- Map over a lazy value (returns a new lazy value)
function caml_lazy_map(f, lazy_val)
  -- Create a new lazy thunk that forces the original and applies f
  local thunk = function()
    local value = caml_lazy_force(lazy_val)
    return f(value)
  end
  return caml_lazy_from_fun(thunk)
end

-- Map over two lazy values
function caml_lazy_map2(f, lazy_val1, lazy_val2)
  local thunk = function()
    local value1 = caml_lazy_force(lazy_val1)
    local value2 = caml_lazy_force(lazy_val2)
    return f(value1, value2)
  end
  return caml_lazy_from_fun(thunk)
end

--
-- Utility functions
--

-- Get the tag of a lazy value
function caml_lazy_tag(lazy_val)
  return lazy_val[1]
end

-- Create a lazy value that raises an exception when forced
function caml_lazy_from_exception(exn)
  local thunk = function()
    error(exn)
  end
  return caml_lazy_from_fun(thunk)
end

-- Force a lazy value and ignore the result (for side effects)
function caml_lazy_force_unit(lazy_val)
  caml_lazy_force(lazy_val)
  return 0  -- unit
end

-- Export all functions as a module
return {
  caml_lazy_from_fun = caml_lazy_from_fun,
  caml_lazy_make_forward = caml_lazy_make_forward,
  caml_lazy_from_val = caml_lazy_from_val,
  caml_lazy_update_to_forcing = caml_lazy_update_to_forcing,
  caml_lazy_update_to_forward = caml_lazy_update_to_forward,
  caml_lazy_reset_to_lazy = caml_lazy_reset_to_lazy,
  caml_lazy_read_result = caml_lazy_read_result,
  caml_lazy_force = caml_lazy_force,
  caml_lazy_force_val = caml_lazy_force_val,
  caml_lazy_is_val = caml_lazy_is_val,
  caml_lazy_is_forcing = caml_lazy_is_forcing,
  caml_lazy_is_lazy = caml_lazy_is_lazy,
  caml_lazy_map = caml_lazy_map,
  caml_lazy_map2 = caml_lazy_map2,
  caml_lazy_tag = caml_lazy_tag,
  caml_lazy_from_exception = caml_lazy_from_exception,
  caml_lazy_force_unit = caml_lazy_force_unit,
}
