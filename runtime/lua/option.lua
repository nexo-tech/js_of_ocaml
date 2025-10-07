-- Lua_of_ocaml runtime support
-- Standard Library: Option module
--
-- OCaml option values are represented as:
-- None = 0
-- Some(v) = {tag=0, v}

--
-- Option construction
--

function caml_option_none()
  return 0
end

function caml_option_some(value)
  return {tag = 0, value}
end

--
-- Option queries
--

function caml_option_is_none(opt)
  return opt == 0
end

function caml_option_is_some(opt)
  return opt ~= 0
end

--
-- Option extraction
--

function caml_option_get(opt)
  if opt == 0 then
    error("Option.get")
  end
  return opt[1]
end

function caml_option_value(opt, default)
  if opt == 0 then
    return default
  end
  return opt[1]
end

--
-- Option mapping
--

function caml_option_map(f, opt)
  if opt == 0 then
    return 0
  end
  return {tag = 0, f(opt[1])}
end

function caml_option_bind(opt, f)
  if opt == 0 then
    return 0
  end
  return f(opt[1])
end

function caml_option_join(opt)
  if opt == 0 then
    return 0
  end
  return opt[1]
end

function caml_option_fold(none_case, some_f, opt)
  if opt == 0 then
    return none_case
  end
  return some_f(opt[1])
end

function caml_option_iter(f, opt)
  if opt ~= 0 then
    f(opt[1])
  end
end

--
-- Option comparison
--

function caml_option_equal(eq, opt1, opt2)
  if opt1 == 0 and opt2 == 0 then
    return true
  end
  if opt1 == 0 or opt2 == 0 then
    return false
  end
  return eq(opt1[1], opt2[1])
end

function caml_option_compare(cmp, opt1, opt2)
  if opt1 == 0 and opt2 == 0 then
    return 0
  end
  if opt1 == 0 then
    return -1
  end
  if opt2 == 0 then
    return 1
  end
  return cmp(opt1[1], opt2[1])
end

--
-- Option conversion
--

function caml_option_to_result(none_error, opt)
  if opt == 0 then
    return {tag = 1, none_error}  -- Error(none_error)
  end
  return {tag = 0, opt[1]}  -- Ok(value)
end

function caml_option_to_list(opt)
  if opt == 0 then
    return 0  -- Empty list
  end
  return {tag = 0, opt[1], 0}  -- Single element list
end

function caml_option_to_seq(opt)
  -- Sequences are represented as functions
  if opt == 0 then
    return function() return 0 end  -- Empty sequence
  end
  local yielded = false
  return function()
    if yielded then
      return 0
    end
    yielded = true
    return {tag = 0, opt[1], function() return 0 end}
  end
end

-- Export all functions as a module
return {
  caml_option_none = caml_option_none,
  caml_option_some = caml_option_some,
  caml_option_is_none = caml_option_is_none,
  caml_option_is_some = caml_option_is_some,
  caml_option_get = caml_option_get,
  caml_option_value = caml_option_value,
  caml_option_map = caml_option_map,
  caml_option_bind = caml_option_bind,
  caml_option_join = caml_option_join,
  caml_option_fold = caml_option_fold,
  caml_option_iter = caml_option_iter,
  caml_option_equal = caml_option_equal,
  caml_option_compare = caml_option_compare,
  caml_option_to_result = caml_option_to_result,
  caml_option_to_list = caml_option_to_list,
  caml_option_to_seq = caml_option_to_seq,
}
