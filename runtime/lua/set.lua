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


--Provides: caml_set_height
function caml_set_height(node)
  if not node then
    return 0
  end
  return node.height
end

--Provides: caml_set_create_node
--Requires: caml_set_height
function caml_set_create_node(elt, left, right)
  return {
    elt = elt,
    left = left,
    right = right,
    height = 1 + math.max(caml_set_height(left), caml_set_height(right))
  }
end

--Provides: caml_set_balance_factor
--Requires: caml_set_height
function caml_set_balance_factor(node)
  if not node then
    return 0
  end
  return caml_set_height(node.left) - caml_set_height(node.right)
end

--Provides: caml_set_rotate_right
--Requires: caml_set_height
function caml_set_rotate_right(node)
  local left = node.left
  local left_right = left.right

  left.right = node
  node.left = left_right

  node.height = 1 + math.max(caml_set_height(node.left), caml_set_height(node.right))
  left.height = 1 + math.max(caml_set_height(left.left), caml_set_height(left.right))

  return left
end

--Provides: caml_set_rotate_left
--Requires: caml_set_height
function caml_set_rotate_left(node)
  local right = node.right
  local right_left = right.left

  right.left = node
  node.right = right_left

  node.height = 1 + math.max(caml_set_height(node.left), caml_set_height(node.right))
  right.height = 1 + math.max(caml_set_height(right.left), caml_set_height(right.right))

  return right
end

--Provides: caml_set_balance
--Requires: caml_set_balance_factor, caml_set_rotate_left, caml_set_rotate_right
function caml_set_balance(node)
  if not node then
    return nil
  end

  local bf = caml_set_balance_factor(node)

  if bf > 1 then
    if caml_set_balance_factor(node.left) < 0 then
      node.left = caml_set_rotate_left(node.left)
    end
    return caml_set_rotate_right(node)
  end

  if bf < -1 then
    if caml_set_balance_factor(node.right) > 0 then
      node.right = caml_set_rotate_right(node.right)
    end
    return caml_set_rotate_left(node)
  end

  return node
end

--Provides: caml_set_add_internal
--Requires: caml_set_create_node, caml_set_height, caml_set_balance
function caml_set_add_internal(cmp, elt, node)
  if not node then
    return caml_set_create_node(elt, nil, nil)
  end

  local c = cmp(elt, node.elt)

  if c == 0 then
    return node  -- Element already exists
  elseif c < 0 then
    node.left = caml_set_add_internal(cmp, elt, node.left)
  else
    node.right = caml_set_add_internal(cmp, elt, node.right)
  end

  node.height = 1 + math.max(caml_set_height(node.left), caml_set_height(node.right))
  return caml_set_balance(node)
end

--Provides: caml_set_mem_internal
function caml_set_mem_internal(cmp, elt, node)
  if not node then
    return false
  end

  local c = cmp(elt, node.elt)

  if c == 0 then
    return true
  elseif c < 0 then
    return caml_set_mem_internal(cmp, elt, node.left)
  else
    return caml_set_mem_internal(cmp, elt, node.right)
  end
end

--Provides: caml_set_min_node
function caml_set_min_node(node)
  if not node.left then
    return node
  end
  return caml_set_min_node(node.left)
end

--Provides: caml_set_remove_internal
--Requires: caml_set_min_node, caml_set_height, caml_set_balance
function caml_set_remove_internal(cmp, elt, node)
  if not node then
    return nil
  end

  local c = cmp(elt, node.elt)

  if c < 0 then
    node.left = caml_set_remove_internal(cmp, elt, node.left)
  elseif c > 0 then
    node.right = caml_set_remove_internal(cmp, elt, node.right)
  else
    if not node.left then
      return node.right
    elseif not node.right then
      return node.left
    else
      local successor = caml_set_min_node(node.right)
      node.elt = successor.elt
      node.right = caml_set_remove_internal(cmp, successor.elt, node.right)
    end
  end

  if not node then
    return nil
  end

  node.height = 1 + math.max(caml_set_height(node.left), caml_set_height(node.right))
  return caml_set_balance(node)
end

--Provides: caml_set_union_internal
--Requires: caml_set_add_internal
function caml_set_union_internal(cmp, s1, s2)
  if not s1 then
    return s2
  end
  if not s2 then
    return s1
  end

  local result = s1
  local function add_all(node)
    if node then
      add_all(node.left)
      result = caml_set_add_internal(cmp, node.elt, result)
      add_all(node.right)
    end
  end
  add_all(s2)
  return result
end

--Provides: caml_set_inter_internal
--Requires: caml_set_mem_internal, caml_set_add_internal
function caml_set_inter_internal(cmp, s1, s2)
  if not s1 or not s2 then
    return nil
  end

  local result = nil
  local function check_all(node)
    if node then
      check_all(node.left)
      if caml_set_mem_internal(cmp, node.elt, s2) then
        result = caml_set_add_internal(cmp, node.elt, result)
      end
      check_all(node.right)
    end
  end
  check_all(s1)
  return result
end

--Provides: caml_set_diff_internal
--Requires: caml_set_mem_internal, caml_set_add_internal
function caml_set_diff_internal(cmp, s1, s2)
  if not s1 then
    return nil
  end
  if not s2 then
    return s1
  end

  local result = nil
  local function check_all(node)
    if node then
      check_all(node.left)
      if not caml_set_mem_internal(cmp, node.elt, s2) then
        result = caml_set_add_internal(cmp, node.elt, result)
      end
      check_all(node.right)
    end
  end
  check_all(s1)
  return result
end

--Provides: caml_set_iter_internal
function caml_set_iter_internal(f, node)
  if not node then
    return
  end
  caml_set_iter_internal(f, node.left)
  f(node.elt)
  caml_set_iter_internal(f, node.right)
end

--Provides: caml_set_fold_internal
function caml_set_fold_internal(f, node, acc)
  if not node then
    return acc
  end
  acc = caml_set_fold_internal(f, node.left, acc)
  acc = f(node.elt, acc)
  acc = caml_set_fold_internal(f, node.right, acc)
  return acc
end

--Provides: caml_set_for_all_internal
function caml_set_for_all_internal(p, node)
  if not node then
    return true
  end
  return p(node.elt) and caml_set_for_all_internal(p, node.left) and caml_set_for_all_internal(p, node.right)
end

--Provides: caml_set_exists_internal
function caml_set_exists_internal(p, node)
  if not node then
    return false
  end
  return p(node.elt) or caml_set_exists_internal(p, node.left) or caml_set_exists_internal(p, node.right)
end

--Provides: caml_set_cardinal_internal
function caml_set_cardinal_internal(node)
  if not node then
    return 0
  end
  return 1 + caml_set_cardinal_internal(node.left) + caml_set_cardinal_internal(node.right)
end

--Provides: caml_set_filter_internal
--Requires: caml_set_create_node, caml_set_balance, caml_set_min_node, caml_set_remove_internal
function caml_set_filter_internal(cmp, p, node)
  if not node then
    return nil
  end

  local left = caml_set_filter_internal(cmp, p, node.left)
  local right = caml_set_filter_internal(cmp, p, node.right)

  if p(node.elt) then
    local result = caml_set_create_node(node.elt, left, right)
    return caml_set_balance(result)
  else
    if not left then
      return right
    elseif not right then
      return left
    else
      local min = caml_set_min_node(right)
      local new_right = caml_set_remove_internal(cmp, min.elt, right)
      local result = caml_set_create_node(min.elt, left, new_right)
      return caml_set_balance(result)
    end
  end
end

--Provides: caml_set_partition_internal
--Requires: caml_set_create_node, caml_set_balance, caml_set_union_internal
function caml_set_partition_internal(cmp, p, node)
  if not node then
    return nil, nil
  end

  local left_t, left_f = caml_set_partition_internal(cmp, p, node.left)
  local right_t, right_f = caml_set_partition_internal(cmp, p, node.right)

  if p(node.elt) then
    local t = caml_set_create_node(node.elt, left_t, right_t)
    return caml_set_balance(t), caml_set_union_internal(cmp, left_f, right_f)
  else
    local f = caml_set_create_node(node.elt, left_f, right_f)
    return caml_set_union_internal(cmp, left_t, right_t), caml_set_balance(f)
  end
end

--Provides: caml_set_subset_internal
--Requires: caml_set_for_all_internal, caml_set_mem_internal
function caml_set_subset_internal(cmp, s1, s2)
  if not s1 then
    return true
  end
  if not s2 then
    return false
  end
  return caml_set_for_all_internal(function(elt) return caml_set_mem_internal(cmp, elt, s2) end, s1)
end

--Provides: caml_set_min_elt_internal
function caml_set_min_elt_internal(node)
  if not node then
    return nil
  end
  if not node.left then
    return node.elt
  end
  return caml_set_min_elt_internal(node.left)
end

--Provides: caml_set_max_elt_internal
function caml_set_max_elt_internal(node)
  if not node then
    return nil
  end
  if not node.right then
    return node.elt
  end
  return caml_set_max_elt_internal(node.right)
end


--Provides: caml_set_empty
function caml_set_empty(_unit)
  return nil
end

--Provides: caml_set_add
--Requires: caml_set_add_internal
function caml_set_add(cmp, elt, set)
  return caml_set_add_internal(cmp, elt, set)
end

--Provides: caml_set_remove
--Requires: caml_set_remove_internal
function caml_set_remove(cmp, elt, set)
  return caml_set_remove_internal(cmp, elt, set)
end

--Provides: caml_set_mem
--Requires: caml_set_mem_internal, caml_true_val, caml_false_val
function caml_set_mem(cmp, elt, set)
  if caml_set_mem_internal(cmp, elt, set) then
    return caml_true_val
  else
    return caml_false_val
  end
end

--Provides: caml_set_union
--Requires: caml_set_union_internal
function caml_set_union(cmp, s1, s2)
  return caml_set_union_internal(cmp, s1, s2)
end

--Provides: caml_set_inter
--Requires: caml_set_inter_internal
function caml_set_inter(cmp, s1, s2)
  return caml_set_inter_internal(cmp, s1, s2)
end

--Provides: caml_set_diff
--Requires: caml_set_diff_internal
function caml_set_diff(cmp, s1, s2)
  return caml_set_diff_internal(cmp, s1, s2)
end

--Provides: caml_set_iter
--Requires: caml_set_iter_internal, caml_unit
function caml_set_iter(f, set)
  caml_set_iter_internal(f, set)
  return caml_unit
end

--Provides: caml_set_fold
--Requires: caml_set_fold_internal
function caml_set_fold(f, set, init)
  return caml_set_fold_internal(f, set, init)
end

--Provides: caml_set_for_all
--Requires: caml_set_for_all_internal, caml_true_val, caml_false_val
function caml_set_for_all(p, set)
  if caml_set_for_all_internal(p, set) then
    return caml_true_val
  else
    return caml_false_val
  end
end

--Provides: caml_set_exists
--Requires: caml_set_exists_internal, caml_true_val, caml_false_val
function caml_set_exists(p, set)
  if caml_set_exists_internal(p, set) then
    return caml_true_val
  else
    return caml_false_val
  end
end

--Provides: caml_set_cardinal
--Requires: caml_set_cardinal_internal
function caml_set_cardinal(set)
  return caml_set_cardinal_internal(set)
end

--Provides: caml_set_is_empty
--Requires: caml_true_val, caml_false_val
function caml_set_is_empty(set)
  if set == nil then
    return caml_true_val
  else
    return caml_false_val
  end
end

--Provides: caml_set_filter
--Requires: caml_set_filter_internal
function caml_set_filter(cmp, p, set)
  return caml_set_filter_internal(cmp, p, set)
end

--Provides: caml_set_partition
--Requires: caml_set_partition_internal
function caml_set_partition(cmp, p, set)
  local t, f = caml_set_partition_internal(cmp, p, set)
  return {tag = 0, [1] = t, [2] = f}
end

--Provides: caml_set_subset
--Requires: caml_set_subset_internal, caml_true_val, caml_false_val
function caml_set_subset(cmp, s1, s2)
  if caml_set_subset_internal(cmp, s1, s2) then
    return caml_true_val
  else
    return caml_false_val
  end
end

--Provides: caml_set_min_elt
--Requires: caml_set_min_elt_internal, caml_raise_not_found
function caml_set_min_elt(set)
  local min = caml_set_min_elt_internal(set)
  if min == nil then
    caml_raise_not_found()
  end
  return min
end

--Provides: caml_set_max_elt
--Requires: caml_set_max_elt_internal, caml_raise_not_found
function caml_set_max_elt(set)
  local max = caml_set_max_elt_internal(set)
  if max == nil then
    caml_raise_not_found()
  end
  return max
end

--Provides: caml_set_equal
--Requires: caml_set_cardinal_internal, caml_set_subset_internal, caml_true_val, caml_false_val
function caml_set_equal(cmp, s1, s2)
  if caml_set_cardinal_internal(s1) ~= caml_set_cardinal_internal(s2) then
    return caml_false_val
  end
  if caml_set_subset_internal(cmp, s1, s2) then
    return caml_true_val
  else
    return caml_false_val
  end
end