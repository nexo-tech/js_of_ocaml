-- Lua_of_ocaml runtime support
-- Standard Library: Result module
--
-- OCaml result values are represented as:
-- Ok(v) = {tag=0, v}
-- Error(e) = {tag=1, e}

--
-- Result construction
--

--Provides: caml_result_ok
function caml_result_ok(value)
  return {tag = 0, value}
end

--Provides: caml_result_error
function caml_result_error(err)
  return {tag = 1, err}
end

--
-- Result queries
--

--Provides: caml_result_is_ok
function caml_result_is_ok(result)
  return result.tag == 0
end

--Provides: caml_result_is_error
function caml_result_is_error(result)
  return result.tag == 1
end

--
-- Result extraction
--

--Provides: caml_result_get_ok
function caml_result_get_ok(result)
  if result.tag ~= 0 then
    error("Result.get_ok")
  end
  return result[1]
end

--Provides: caml_result_get_error
function caml_result_get_error(result)
  if result.tag ~= 1 then
    error("Result.get_error")
  end
  return result[1]
end

--Provides: caml_result_value
function caml_result_value(result, default)
  if result.tag == 0 then
    return result[1]
  end
  return default
end

--
-- Result mapping
--

--Provides: caml_result_map
function caml_result_map(f, result)
  if result.tag == 0 then
    return {tag = 0, f(result[1])}
  end
  return result
end

--Provides: caml_result_map_error
function caml_result_map_error(f, result)
  if result.tag == 1 then
    return {tag = 1, f(result[1])}
  end
  return result
end

--Provides: caml_result_bind
function caml_result_bind(result, f)
  if result.tag == 0 then
    return f(result[1])
  end
  return result
end

--Provides: caml_result_join
function caml_result_join(result)
  if result.tag == 0 then
    return result[1]
  end
  return result
end

--Provides: caml_result_fold
function caml_result_fold(ok_f, error_f, result)
  if result.tag == 0 then
    return ok_f(result[1])
  else
    return error_f(result[1])
  end
end

--Provides: caml_result_iter
function caml_result_iter(f, result)
  if result.tag == 0 then
    f(result[1])
  end
end

--Provides: caml_result_iter_error
function caml_result_iter_error(f, result)
  if result.tag == 1 then
    f(result[1])
  end
end

--
-- Result comparison
--

--Provides: caml_result_equal
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

--Provides: caml_result_compare
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

--Provides: caml_result_to_option
function caml_result_to_option(result)
  if result.tag == 0 then
    return {tag = 0, result[1]}  -- Some(value)
  end
  return 0  -- None
end

--Provides: caml_result_to_list
function caml_result_to_list(result)
  if result.tag == 0 then
    return {tag = 0, result[1], 0}  -- Single element list
  end
  return 0  -- Empty list
end

--Provides: caml_result_to_seq
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
