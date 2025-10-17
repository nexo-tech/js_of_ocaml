-- Lua_of_ocaml runtime support
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


--Provides: caml_map_height
function caml_map_height(node)
  if not node then
    return 0
  end
  return node.height
end

--Provides: caml_map_create_node
--Requires: caml_map_height
function caml_map_create_node(key, value, left, right)
  return {
    key = key,
    value = value,
    left = left,
    right = right,
    height = 1 + math.max(caml_map_height(left), caml_map_height(right))
  }
end

--Provides: caml_map_balance_factor
--Requires: caml_map_height
function caml_map_balance_factor(node)
  if not node then
    return 0
  end
  return caml_map_height(node.left) - caml_map_height(node.right)
end

--Provides: caml_map_rotate_right
--Requires: caml_map_height
function caml_map_rotate_right(node)
  local left = node.left
  local left_right = left.right

  left.right = node
  node.left = left_right

  node.height = 1 + math.max(caml_map_height(node.left), caml_map_height(node.right))
  left.height = 1 + math.max(caml_map_height(left.left), caml_map_height(left.right))

  return left
end

--Provides: caml_map_rotate_left
--Requires: caml_map_height
function caml_map_rotate_left(node)
  local right = node.right
  local right_left = right.left

  right.left = node
  node.right = right_left

  node.height = 1 + math.max(caml_map_height(node.left), caml_map_height(node.right))
  right.height = 1 + math.max(caml_map_height(right.left), caml_map_height(right.right))

  return right
end

--Provides: caml_map_balance
--Requires: caml_map_balance_factor, caml_map_rotate_left, caml_map_rotate_right
function caml_map_balance(node)
  if not node then
    return nil
  end

  local bf = caml_map_balance_factor(node)

  if bf > 1 then
    if caml_map_balance_factor(node.left) < 0 then
      node.left = caml_map_rotate_left(node.left)
    end
    return caml_map_rotate_right(node)
  end

  if bf < -1 then
    if caml_map_balance_factor(node.right) > 0 then
      node.right = caml_map_rotate_right(node.right)
    end
    return caml_map_rotate_left(node)
  end

  return node
end

--Provides: caml_map_add_internal
--Requires: caml_map_create_node, caml_map_height, caml_map_balance
function caml_map_add_internal(cmp, key, value, node)
  if not node then
    return caml_map_create_node(key, value, nil, nil)
  end

  local c = cmp(key, node.key)

  if c == 0 then
    node.value = value
    return node
  elseif c < 0 then
    node.left = caml_map_add_internal(cmp, key, value, node.left)
  else
    node.right = caml_map_add_internal(cmp, key, value, node.right)
  end

  node.height = 1 + math.max(caml_map_height(node.left), caml_map_height(node.right))

  return caml_map_balance(node)
end

--Provides: caml_map_find_internal
function caml_map_find_internal(cmp, key, node)
  if not node then
    return nil
  end

  local c = cmp(key, node.key)

  if c == 0 then
    return node.value
  elseif c < 0 then
    return caml_map_find_internal(cmp, key, node.left)
  else
    return caml_map_find_internal(cmp, key, node.right)
  end
end

--Provides: caml_map_mem_internal
function caml_map_mem_internal(cmp, key, node)
  if not node then
    return false
  end

  local c = cmp(key, node.key)

  if c == 0 then
    return true
  elseif c < 0 then
    return caml_map_mem_internal(cmp, key, node.left)
  else
    return caml_map_mem_internal(cmp, key, node.right)
  end
end

--Provides: caml_map_min_node
function caml_map_min_node(node)
  if not node.left then
    return node
  end
  return caml_map_min_node(node.left)
end

--Provides: caml_map_remove_internal
--Requires: caml_map_min_node, caml_map_height, caml_map_balance
function caml_map_remove_internal(cmp, key, node)
  if not node then
    return nil
  end

  local c = cmp(key, node.key)

  if c < 0 then
    node.left = caml_map_remove_internal(cmp, key, node.left)
  elseif c > 0 then
    node.right = caml_map_remove_internal(cmp, key, node.right)
  else
    if not node.left then
      return node.right
    elseif not node.right then
      return node.left
    else
      local successor = caml_map_min_node(node.right)
      node.key = successor.key
      node.value = successor.value
      node.right = caml_map_remove_internal(cmp, successor.key, node.right)
    end
  end

  if not node then
    return nil
  end

  node.height = 1 + math.max(caml_map_height(node.left), caml_map_height(node.right))

  return caml_map_balance(node)
end

--Provides: caml_map_iter_internal
function caml_map_iter_internal(f, node)
  if not node then
    return
  end
  caml_map_iter_internal(f, node.left)
  f(node.key, node.value)
  caml_map_iter_internal(f, node.right)
end

--Provides: caml_map_fold_internal
function caml_map_fold_internal(f, node, acc)
  if not node then
    return acc
  end
  acc = caml_map_fold_internal(f, node.left, acc)
  acc = f(node.key, node.value, acc)
  acc = caml_map_fold_internal(f, node.right, acc)
  return acc
end

--Provides: caml_map_for_all_internal
function caml_map_for_all_internal(p, node)
  if not node then
    return true
  end
  return p(node.key, node.value) and caml_map_for_all_internal(p, node.left) and caml_map_for_all_internal(p, node.right)
end

--Provides: caml_map_exists_internal
function caml_map_exists_internal(p, node)
  if not node then
    return false
  end
  return p(node.key, node.value) or caml_map_exists_internal(p, node.left) or caml_map_exists_internal(p, node.right)
end

--Provides: caml_map_cardinal_internal
function caml_map_cardinal_internal(node)
  if not node then
    return 0
  end
  return 1 + caml_map_cardinal_internal(node.left) + caml_map_cardinal_internal(node.right)
end

--Provides: caml_map_map_values_internal
--Requires: caml_map_create_node
function caml_map_map_values_internal(f, node)
  if not node then
    return nil
  end
  return caml_map_create_node(
    node.key,
    f(node.value),
    caml_map_map_values_internal(f, node.left),
    caml_map_map_values_internal(f, node.right)
  )
end

--Provides: caml_map_mapi_internal
--Requires: caml_map_create_node
function caml_map_mapi_internal(f, node)
  if not node then
    return nil
  end
  return caml_map_create_node(
    node.key,
    f(node.key, node.value),
    caml_map_mapi_internal(f, node.left),
    caml_map_mapi_internal(f, node.right)
  )
end

--Provides: caml_map_filter_internal
--Requires: caml_map_create_node, caml_map_balance, caml_map_min_node, caml_map_remove_internal
function caml_map_filter_internal(cmp, p, node)
  if not node then
    return nil
  end

  local left = caml_map_filter_internal(cmp, p, node.left)
  local right = caml_map_filter_internal(cmp, p, node.right)

  if p(node.key, node.value) then
    local result = caml_map_create_node(node.key, node.value, left, right)
    return caml_map_balance(result)
  else
    if not left then
      return right
    elseif not right then
      return left
    else
      local min = caml_map_min_node(right)
      local new_right = caml_map_remove_internal(cmp, min.key, right)
      local result = caml_map_create_node(min.key, min.value, left, new_right)
      return caml_map_balance(result)
    end
  end
end


--Provides: caml_map_empty
function caml_map_empty(_unit)
  return nil
end

--Provides: caml_map_add
--Requires: caml_map_add_internal
function caml_map_add(cmp, key, value, map)
  return caml_map_add_internal(cmp, key, value, map)
end

--Provides: caml_map_find
--Requires: caml_map_find_internal, caml_raise_not_found
function caml_map_find(cmp, key, map)
  local result = caml_map_find_internal(cmp, key, map)
  if result == nil then
    caml_raise_not_found()
  end
  return result
end

--Provides: caml_map_find_opt
--Requires: caml_map_find_internal
function caml_map_find_opt(cmp, key, map)
  local result = caml_map_find_internal(cmp, key, map)
  if result == nil then
    return 0  -- None
  else
    return {tag = 0, [1] = result}  -- Some value
  end
end

--Provides: caml_map_remove
--Requires: caml_map_remove_internal
function caml_map_remove(cmp, key, map)
  return caml_map_remove_internal(cmp, key, map)
end

--Provides: caml_map_mem
--Requires: caml_map_mem_internal
function caml_map_mem(cmp, key, map)
  if caml_map_mem_internal(cmp, key, map) then
    return 1
  else
    return 0
  end
end

--Provides: caml_map_iter
--Requires: caml_map_iter_internal
function caml_map_iter(f, map)
  caml_map_iter_internal(f, map)
  return 0
end

--Provides: caml_map_fold
--Requires: caml_map_fold_internal
function caml_map_fold(f, map, init)
  return caml_map_fold_internal(f, map, init)
end

--Provides: caml_map_for_all
--Requires: caml_map_for_all_internal
function caml_map_for_all(p, map)
  if caml_map_for_all_internal(p, map) then
    return 1
  else
    return 0
  end
end

--Provides: caml_map_exists
--Requires: caml_map_exists_internal
function caml_map_exists(p, map)
  if caml_map_exists_internal(p, map) then
    return 1
  else
    return 0
  end
end

--Provides: caml_map_cardinal
--Requires: caml_map_cardinal_internal
function caml_map_cardinal(map)
  return caml_map_cardinal_internal(map)
end

--Provides: caml_map_is_empty
function caml_map_is_empty(map)
  if map == nil then
    return 1
  else
    return 0
  end
end

--Provides: caml_map_map
--Requires: caml_map_map_values_internal
function caml_map_map(f, map)
  return caml_map_map_values_internal(f, map)
end

--Provides: caml_map_mapi
--Requires: caml_map_mapi_internal
function caml_map_mapi(f, map)
  return caml_map_mapi_internal(f, map)
end

--Provides: caml_map_filter
--Requires: caml_map_filter_internal
function caml_map_filter(cmp, p, map)
  return caml_map_filter_internal(cmp, p, map)
end