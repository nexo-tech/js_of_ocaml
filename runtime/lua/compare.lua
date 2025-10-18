-- Js_of_ocaml runtime support
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


--Provides: caml_is_ocaml_string
function caml_is_ocaml_string(v)
  if type(v) ~= "table" then
    return false
  end
  -- OCaml strings (bytes) are represented as tables with .length field
  -- Example: {length = 3, [0] = 97, [1] = 98, [2] = 99} for "abc"
  return v.length ~= nil and type(v.length) == "number"
end

--Provides: caml_is_ocaml_block
function caml_is_ocaml_block(v)
  if type(v) ~= "table" then
    return false
  end
  -- Blocks are represented as {tag, field1, field2, ...} where tag is at index [1]
  return v[1] ~= nil and type(v[1]) == "number"
end

--Provides: caml_compare_tag
--Requires: caml_is_ocaml_string, caml_is_ocaml_block
function caml_compare_tag(v)
  local t = type(v)

  if t == "number" then
    return 1000
  elseif t == "string" then
    return 12520
  elseif t == "boolean" then
    return 1002
  elseif t == "nil" then
    return 1003
  elseif t == "function" then
    return 1247
  elseif t == "table" then
    if caml_is_ocaml_string(v) then
      return 252
    elseif caml_is_ocaml_block(v) then
      local tag = v[1]  -- Tag is at index [1]
      if tag == 250 then
        return 250
      end
      return tag == 254 and 0 or tag
    else
      return 1001
    end
  else
    return 1004
  end
end

--Provides: caml_compare_ocaml_strings
function caml_compare_ocaml_strings(a, b)
  local len_a = #a
  local len_b = #b
  local min_len = len_a < len_b and len_a or len_b

  for i = 1, min_len do
    if a[i] < b[i] then
      return -1
    elseif a[i] > b[i] then
      return 1
    end
  end

  if len_a < len_b then
    return -1
  elseif len_a > len_b then
    return 1
  else
    return 0
  end
end

--Provides: caml_compare_numbers
function caml_compare_numbers(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  elseif a == b then
    return 0
  else
    if a ~= a then
      if b ~= b then
        return 0
      else
        return -1
      end
    else
      return 1
    end
  end
end

--Provides: caml_compare_val
--Requires: caml_compare_tag, caml_is_ocaml_block, caml_compare_numbers, caml_compare_ocaml_strings
function caml_compare_val(a, b, total)
  local stack = {}

  while true do
    -- Use repeat-until to enable breaking out and restarting the outer loop
    repeat
      if not (total and a == b) then
        local tag_a = caml_compare_tag(a)

        if tag_a == 250 and caml_is_ocaml_block(a) then
          a = a[1]
          break  -- Restart outer loop
        end

        local tag_b = caml_compare_tag(b)

        if tag_b == 250 and caml_is_ocaml_block(b) then
          b = b[1]
          break  -- Restart outer loop
        end

        if tag_a ~= tag_b then
          if tag_a < tag_b then
            return -1
          else
            return 1
          end
        end

        if tag_a == 1000 then
          local result = caml_compare_numbers(a, b)
          if result ~= 0 then
            return result
          end
        elseif tag_a == 12520 then
          if a < b then
            return -1
          elseif a > b then
            return 1
          end
        elseif tag_a == 252 then
          if a ~= b then
            local result = caml_compare_ocaml_strings(a, b)
            if result ~= 0 then
              return result
            end
          end
        elseif tag_a == 1002 then
          if a ~= b then
            if not a then
              return -1
            else
              return 1
            end
          end
        elseif tag_a == 1003 then
        elseif tag_a == 1247 then
          error("compare: functional value")
        elseif tag_a == 1001 or tag_a == 1004 then
          -- Lua doesn't allow < or > on tables, so wrap in pcall
          local success, cmp_result = pcall(function()
            if a < b then
              return -1
            elseif a > b then
              return 1
            else
              return nil
            end
          end)

          if success and cmp_result ~= nil then
            return cmp_result
          elseif a ~= b then
            -- If comparison failed or values are not equal
            if total then
              return 1
            else
              error("compare: incomparable values")
            end
          end
        elseif tag_a == 248 then
          if caml_is_ocaml_block(a) and caml_is_ocaml_block(b) then
            local id_a = a[2] or 0
            local id_b = b[2] or 0
            if id_a < id_b then
              return -1
            elseif id_a > id_b then
              return 1
            end
          end
        else
          if caml_is_ocaml_block(a) and caml_is_ocaml_block(b) then
            local len_a = #a
            local len_b = #b

            if len_a ~= len_b then
              if len_a < len_b then
                return -1
              else
                return 1
              end
            end

            if len_a > 0 then
              if len_a > 1 then
                table.insert(stack, {a = a, b = b, i = 2})
              end
              a = a[1]
              b = b[1]
              break  -- Restart outer loop
            end
          end
        end
      end

      -- If we reach here, we didn't break, so handle stack
      if #stack == 0 then
        return 0
      end

      local frame = table.remove(stack)
      local parent_a = frame.a
      local parent_b = frame.b
      local i = frame.i

      if i + 1 <= #parent_a then
        table.insert(stack, {a = parent_a, b = parent_b, i = i + 1})
      end

      a = parent_a[i]
      b = parent_b[i]
    until true  -- Single iteration, but allows break to restart outer loop
  end
end

--Provides: caml_compare
--Requires: caml_compare_val
function caml_compare(a, b)
  return caml_compare_val(a, b, true)
end

--Provides: caml_int_compare
function caml_int_compare(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--Provides: caml_int32_compare
function caml_int32_compare(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--Provides: caml_nativeint_compare
function caml_nativeint_compare(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--Provides: caml_float_compare
function caml_float_compare(a, b)
  if a ~= a then
    if b ~= b then
      return 0
    else
      return 1
    end
  end
  if b ~= b then
    return -1
  end

  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

--Provides: caml_equal
--Requires: caml_compare_val
function caml_equal(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) == 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_notequal
--Requires: caml_compare_val
function caml_notequal(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) ~= 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_lessthan
--Requires: caml_compare_val
function caml_lessthan(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) < 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_lessequal
--Requires: caml_compare_val
function caml_lessequal(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) <= 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_greaterthan
--Requires: caml_compare_val
function caml_greaterthan(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) > 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_greaterequal
--Requires: caml_compare_val
function caml_greaterequal(x, y)
  local success, result = pcall(function()
    return caml_compare_val(x, y, false) >= 0
  end)

  if success then
    return result and 1 or 0
  else
    error(result)
  end
end

--Provides: caml_min
--Requires: caml_compare
function caml_min(x, y)
  if caml_compare(x, y) <= 0 then
    return x
  else
    return y
  end
end

--Provides: caml_max
--Requires: caml_compare
function caml_max(x, y)
  if caml_compare(x, y) >= 0 then
    return x
  else
    return y
  end
end
