-- Lua_of_ocaml runtime support
-- Standard Library: Result module
--
-- OCaml result values are represented as:
-- Ok(v) = {tag=0, v}
-- Error(e) = {tag=1, e}

--
-- Result construction
--

function caml_result_ok(value)
  return {tag = 0, value}
end

function caml_result_error(err)
  return {tag = 1, err}
end

--
-- Result queries
--

function caml_result_is_ok(result)
  return result.tag == 0
end

function caml_result_is_error(result)
  return result.tag == 1
end

--
-- Result extraction
--

function caml_result_get_ok(result)
  if result.tag ~= 0 then
    error("Result.get_ok")
  end
  return result[1]
end

function caml_result_get_error(result)
  if result.tag ~= 1 then
    error("Result.get_error")
  end
  return result[1]
end

function caml_result_value(result, default)
  if result.tag == 0 then
    return result[1]
  end
  return default
end

--
-- Result mapping
--

function caml_result_map(f, result)
  if result.tag == 0 then
    return {tag = 0, f(result[1])}
  end
  return result
end

function caml_result_map_error(f, result)
  if result.tag == 1 then
    return {tag = 1, f(result[1])}
  end
  return result
end

function caml_result_bind(result, f)
  if result.tag == 0 then
    return f(result[1])
  end
  return result
end

function caml_result_join(result)
  if result.tag == 0 then
    return result[1]
  end
  return result
end

function caml_result_fold(ok_f, error_f, result)
  if result.tag == 0 then
    return ok_f(result[1])
  else
    return error_f(result[1])
  end
end

function caml_result_iter(f, result)
  if result.tag == 0 then
    f(result[1])
  end
end

function caml_result_iter_error(f, result)
  if result.tag == 1 then
    f(result[1])
  end
end

--
-- Result comparison
--

function caml_result_equal(ok_eq, error_eq, result1, result2)
  if result1.tag ~= result2.tag then
    return false
  end
  if result1.tag == 0 then
    return ok_eq(result1[1], result2[1])
  else
    return error_eq(result1[1], result2[1])
  end
end

function caml_result_compare(ok_cmp, error_cmp, result1, result2)
  if result1.tag ~= result2.tag then
    if result1.tag == 0 then
      return -1  -- Ok < Error
    else
      return 1   -- Error > Ok
    end
  end
  if result1.tag == 0 then
    return ok_cmp(result1[1], result2[1])
  else
    return error_cmp(result1[1], result2[1])
  end
end

--
-- Result conversion
--

function caml_result_to_option(result)
  if result.tag == 0 then
    return {tag = 0, result[1]}  -- Some(value)
  end
  return 0  -- None
end

function caml_result_to_list(result)
  if result.tag == 0 then
    return {tag = 0, result[1], 0}  -- Single element list
  end
  return 0  -- Empty list
end

function caml_result_to_seq(result)
  -- Sequences are represented as functions
  if result.tag == 1 then
    return function() return 0 end  -- Empty sequence
  end
  local yielded = false
  return function()
    if yielded then
      return 0
    end
    yielded = true
    return {tag = 0, result[1], function() return 0 end}
  end
end

-- Export all functions as a module
return {
  caml_result_ok = caml_result_ok,
  caml_result_error = caml_result_error,
  caml_result_is_ok = caml_result_is_ok,
  caml_result_is_error = caml_result_is_error,
  caml_result_get_ok = caml_result_get_ok,
  caml_result_get_error = caml_result_get_error,
  caml_result_value = caml_result_value,
  caml_result_map = caml_result_map,
  caml_result_map_error = caml_result_map_error,
  caml_result_bind = caml_result_bind,
  caml_result_join = caml_result_join,
  caml_result_fold = caml_result_fold,
  caml_result_iter = caml_result_iter,
  caml_result_iter_error = caml_result_iter_error,
  caml_result_equal = caml_result_equal,
  caml_result_compare = caml_result_compare,
  caml_result_to_option = caml_result_to_option,
  caml_result_to_list = caml_result_to_list,
  caml_result_to_seq = caml_result_to_seq,
}
