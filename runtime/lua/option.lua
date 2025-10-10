-- Lua_of_ocaml runtime support
-- Standard Library: Option module
--
-- OCaml option values are represented as:
-- None = 0
-- Some(v) = {tag=0, v}

--
-- Option construction
--

--Provides: caml_option_none
function caml_option_none()
  return 0
end

--Provides: caml_option_some
function caml_option_some(value)
  return {tag = 0, value}
end

--
-- Option queries
--

--Provides: caml_option_is_none
function caml_option_is_none(opt)
  return opt == 0
end

--Provides: caml_option_is_some
function caml_option_is_some(opt)
  return opt ~= 0
end

--
-- Option extraction
--

--Provides: caml_option_get
function caml_option_get(opt)
  if opt == 0 then
    error("Option.get")
  end
  return opt[1]
end

--Provides: caml_option_value
function caml_option_value(opt, default)
  if opt == 0 then
    return default
  end
  return opt[1]
end

--
-- Option mapping
--

--Provides: caml_option_map
function caml_option_map(f, opt)
  if opt == 0 then
    return 0
  end
  return {tag = 0, f(opt[1])}
end

--Provides: caml_option_bind
function caml_option_bind(opt, f)
  if opt == 0 then
    return 0
  end
  return f(opt[1])
end

--Provides: caml_option_join
function caml_option_join(opt)
  if opt == 0 then
    return 0
  end
  return opt[1]
end

--Provides: caml_option_fold
function caml_option_fold(none_case, some_f, opt)
  if opt == 0 then
    return none_case
  end
  return some_f(opt[1])
end

--Provides: caml_option_iter
function caml_option_iter(f, opt)
  if opt ~= 0 then
    f(opt[1])
  end
end

--
-- Option comparison
--

--Provides: caml_option_equal
function caml_option_equal(eq, opt1, opt2)
  if opt1 == 0 and opt2 == 0 then
    return true
  end
  if opt1 == 0 or opt2 == 0 then
    return false
  end
  return eq(opt1[1], opt2[1])
end

--Provides: caml_option_compare
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

--Provides: caml_option_to_result
function caml_option_to_result(none_error, opt)
  if opt == 0 then
    return {tag = 1, none_error}  -- Error(none_error)
  end
  return {tag = 0, opt[1]}  -- Ok(value)
end

--Provides: caml_option_to_list
function caml_option_to_list(opt)
  if opt == 0 then
    return 0  -- Empty list
  end
  return {tag = 0, opt[1], 0}  -- Single element list
end

--Provides: caml_option_to_seq
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

