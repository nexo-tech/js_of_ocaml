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

--- Set Module
--
-- Provides balanced binary search tree (AVL tree) implementation
-- for ordered sets with polymorphic comparison.

local core = require("core")

local M = {}

-- AVL tree node structure:
-- {
--   elt = <element value>,
--   left = <left subtree or nil>,
--   right = <right subtree or nil>,
--   height = <tree height>
-- }

--- Get height of a tree node
-- @param node table|nil Tree node
-- @return number Height (0 for nil)
local function height(node)
  if not node then
    return 0
  end
  return node.height
end

--- Create a new node
-- @param elt any Element
-- @param left table|nil Left subtree
-- @param right table|nil Right subtree
-- @return table New node
local function create_node(elt, left, right)
  return {
    elt = elt,
    left = left,
    right = right,
    height = 1 + math.max(height(left), height(right))
  }
end

--- Get balance factor of a node
-- @param node table Tree node
-- @return number Balance factor (left height - right height)
local function balance_factor(node)
  if not node then
    return 0
  end
  return height(node.left) - height(node.right)
end

--- Right rotation
-- @param node table Tree node
-- @return table Rotated tree
local function rotate_right(node)
  local left = node.left
  local left_right = left.right

  left.right = node
  node.left = left_right

  node.height = 1 + math.max(height(node.left), height(node.right))
  left.height = 1 + math.max(height(left.left), height(left.right))

  return left
end

--- Left rotation
-- @param node table Tree node
-- @return table Rotated tree
local function rotate_left(node)
  local right = node.right
  local right_left = right.left

  right.left = node
  node.right = right_left

  node.height = 1 + math.max(height(node.left), height(node.right))
  right.height = 1 + math.max(height(right.left), height(right.right))

  return right
end

--- Balance a tree node
-- @param node table Tree node
-- @return table Balanced tree
local function balance(node)
  if not node then
    return nil
  end

  local bf = balance_factor(node)

  -- Left-heavy
  if bf > 1 then
    if balance_factor(node.left) < 0 then
      node.left = rotate_left(node.left)
    end
    return rotate_right(node)
  end

  -- Right-heavy
  if bf < -1 then
    if balance_factor(node.right) > 0 then
      node.right = rotate_right(node.right)
    end
    return rotate_left(node)
  end

  return node
end

--- Add element to set
-- @param cmp function Comparison function
-- @param elt any Element
-- @param node table|nil Tree node
-- @return table Updated tree
local function add(cmp, elt, node)
  if not node then
    return create_node(elt, nil, nil)
  end

  local c = cmp(elt, node.elt)

  if c == 0 then
    return node  -- Element already exists
  elseif c < 0 then
    node.left = add(cmp, elt, node.left)
  else
    node.right = add(cmp, elt, node.right)
  end

  node.height = 1 + math.max(height(node.left), height(node.right))
  return balance(node)
end

--- Check if element exists in set
-- @param cmp function Comparison function
-- @param elt any Element
-- @param node table|nil Tree node
-- @return boolean True if element exists
local function mem(cmp, elt, node)
  if not node then
    return false
  end

  local c = cmp(elt, node.elt)

  if c == 0 then
    return true
  elseif c < 0 then
    return mem(cmp, elt, node.left)
  else
    return mem(cmp, elt, node.right)
  end
end

--- Find minimum node in tree
-- @param node table Tree node
-- @return table Minimum node
local function min_node(node)
  if not node.left then
    return node
  end
  return min_node(node.left)
end

--- Remove element from set
-- @param cmp function Comparison function
-- @param elt any Element
-- @param node table|nil Tree node
-- @return table|nil Updated tree
local function remove(cmp, elt, node)
  if not node then
    return nil
  end

  local c = cmp(elt, node.elt)

  if c < 0 then
    node.left = remove(cmp, elt, node.left)
  elseif c > 0 then
    node.right = remove(cmp, elt, node.right)
  else
    -- Found the node to remove
    if not node.left then
      return node.right
    elseif not node.right then
      return node.left
    else
      local successor = min_node(node.right)
      node.elt = successor.elt
      node.right = remove(cmp, successor.elt, node.right)
    end
  end

  if not node then
    return nil
  end

  node.height = 1 + math.max(height(node.left), height(node.right))
  return balance(node)
end

--- Union of two sets
-- @param cmp function Comparison function
-- @param s1 table|nil First set
-- @param s2 table|nil Second set
-- @return table|nil Union set
local function union(cmp, s1, s2)
  if not s1 then
    return s2
  end
  if not s2 then
    return s1
  end

  -- Add all elements from s2 to s1
  local result = s1
  local function add_all(node)
    if node then
      add_all(node.left)
      result = add(cmp, node.elt, result)
      add_all(node.right)
    end
  end
  add_all(s2)
  return result
end

--- Intersection of two sets
-- @param cmp function Comparison function
-- @param s1 table|nil First set
-- @param s2 table|nil Second set
-- @return table|nil Intersection set
local function inter(cmp, s1, s2)
  if not s1 or not s2 then
    return nil
  end

  local result = nil
  local function check_all(node)
    if node then
      check_all(node.left)
      if mem(cmp, node.elt, s2) then
        result = add(cmp, node.elt, result)
      end
      check_all(node.right)
    end
  end
  check_all(s1)
  return result
end

--- Difference of two sets (s1 - s2)
-- @param cmp function Comparison function
-- @param s1 table|nil First set
-- @param s2 table|nil Second set
-- @return table|nil Difference set
local function diff(cmp, s1, s2)
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
      if not mem(cmp, node.elt, s2) then
        result = add(cmp, node.elt, result)
      end
      check_all(node.right)
    end
  end
  check_all(s1)
  return result
end

--- Iterate over set in ascending order
-- @param f function Function to call for each element
-- @param node table|nil Tree node
local function iter(f, node)
  if not node then
    return
  end
  iter(f, node.left)
  f(node.elt)
  iter(f, node.right)
end

--- Fold over set in ascending order
-- @param f function Fold function (elt, acc) -> acc
-- @param node table|nil Tree node
-- @param acc any Accumulator
-- @return any Final accumulator value
local function fold(f, node, acc)
  if not node then
    return acc
  end
  acc = fold(f, node.left, acc)
  acc = f(node.elt, acc)
  acc = fold(f, node.right, acc)
  return acc
end

--- Check if predicate holds for all elements
-- @param p function Predicate (elt) -> bool
-- @param node table|nil Tree node
-- @return boolean True if predicate holds for all
local function for_all(p, node)
  if not node then
    return true
  end
  return p(node.elt) and for_all(p, node.left) and for_all(p, node.right)
end

--- Check if predicate holds for at least one element
-- @param p function Predicate (elt) -> bool
-- @param node table|nil Tree node
-- @return boolean True if predicate holds for at least one
local function exists(p, node)
  if not node then
    return false
  end
  return p(node.elt) or exists(p, node.left) or exists(p, node.right)
end

--- Count number of elements in set
-- @param node table|nil Tree node
-- @return number Number of elements
local function cardinal(node)
  if not node then
    return 0
  end
  return 1 + cardinal(node.left) + cardinal(node.right)
end

--- Filter set by predicate
-- @param cmp function Comparison function
-- @param p function Predicate (elt) -> bool
-- @param node table|nil Tree node
-- @return table|nil Filtered set
local function filter(cmp, p, node)
  if not node then
    return nil
  end

  local left = filter(cmp, p, node.left)
  local right = filter(cmp, p, node.right)

  if p(node.elt) then
    local result = create_node(node.elt, left, right)
    return balance(result)
  else
    if not left then
      return right
    elseif not right then
      return left
    else
      local min = min_node(right)
      local new_right = remove(cmp, min.elt, right)
      local result = create_node(min.elt, left, new_right)
      return balance(result)
    end
  end
end

--- Partition set by predicate
-- @param cmp function Comparison function
-- @param p function Predicate (elt) -> bool
-- @param node table|nil Tree node
-- @return table|nil, table|nil True set, False set
local function partition(cmp, p, node)
  if not node then
    return nil, nil
  end

  local left_t, left_f = partition(cmp, p, node.left)
  local right_t, right_f = partition(cmp, p, node.right)

  if p(node.elt) then
    local t = create_node(node.elt, left_t, right_t)
    return balance(t), union(cmp, left_f, right_f)
  else
    local f = create_node(node.elt, left_f, right_f)
    return union(cmp, left_t, right_t), balance(f)
  end
end

--- Check if s1 is subset of s2
-- @param cmp function Comparison function
-- @param s1 table|nil First set
-- @param s2 table|nil Second set
-- @return boolean True if s1 ⊆ s2
local function subset(cmp, s1, s2)
  if not s1 then
    return true
  end
  if not s2 then
    return false
  end
  return for_all(function(elt) return mem(cmp, elt, s2) end, s1)
end

--- Get minimum element
-- @param node table|nil Tree node
-- @return any Minimum element
local function min_elt(node)
  if not node then
    return nil
  end
  if not node.left then
    return node.elt
  end
  return min_elt(node.left)
end

--- Get maximum element
-- @param node table|nil Tree node
-- @return any Maximum element
local function max_elt(node)
  if not node then
    return nil
  end
  if not node.right then
    return node.elt
  end
  return max_elt(node.right)
end

-- OCaml Set primitives

--- Create empty set
-- @param _unit number Unit value
-- @return nil Empty set
function M.caml_set_empty(_unit)
  return nil
end

--- Add element to set
-- @param cmp function Comparison function
-- @param elt any Element
-- @param set table|nil Set
-- @return table Updated set
function M.caml_set_add(cmp, elt, set)
  return add(cmp, elt, set)
end

--- Remove element from set
-- @param cmp function Comparison function
-- @param elt any Element
-- @param set table|nil Set
-- @return table|nil Updated set
function M.caml_set_remove(cmp, elt, set)
  return remove(cmp, elt, set)
end

--- Check if element is in set
-- @param cmp function Comparison function
-- @param elt any Element
-- @param set table|nil Set
-- @return number 1 (true) or 0 (false)
function M.caml_set_mem(cmp, elt, set)
  if mem(cmp, elt, set) then
    return core.true_val
  else
    return core.false_val
  end
end

--- Union of two sets
-- @param cmp function Comparison function
-- @param s1 table|nil First set
-- @param s2 table|nil Second set
-- @return table|nil Union set
function M.caml_set_union(cmp, s1, s2)
  return union(cmp, s1, s2)
end

--- Intersection of two sets
-- @param cmp function Comparison function
-- @param s1 table|nil First set
-- @param s2 table|nil Second set
-- @return table|nil Intersection set
function M.caml_set_inter(cmp, s1, s2)
  return inter(cmp, s1, s2)
end

--- Difference of two sets
-- @param cmp function Comparison function
-- @param s1 table|nil First set
-- @param s2 table|nil Second set
-- @return table|nil Difference set
function M.caml_set_diff(cmp, s1, s2)
  return diff(cmp, s1, s2)
end

--- Iterate function over set elements
-- @param f function Function (elt) -> unit
-- @param set table|nil Set
-- @return number Unit value
function M.caml_set_iter(f, set)
  iter(f, set)
  return core.unit
end

--- Fold function over set elements
-- @param f function Fold function (elt, acc) -> acc
-- @param set table|nil Set
-- @param init any Initial accumulator
-- @return any Final accumulator
function M.caml_set_fold(f, set, init)
  return fold(f, set, init)
end

--- Check if predicate holds for all elements
-- @param p function Predicate (elt) -> bool
-- @param set table|nil Set
-- @return number 1 (true) or 0 (false)
function M.caml_set_for_all(p, set)
  if for_all(p, set) then
    return core.true_val
  else
    return core.false_val
  end
end

--- Check if predicate holds for at least one element
-- @param p function Predicate (elt) -> bool
-- @param set table|nil Set
-- @return number 1 (true) or 0 (false)
function M.caml_set_exists(p, set)
  if exists(p, set) then
    return core.true_val
  else
    return core.false_val
  end
end

--- Get number of elements in set
-- @param set table|nil Set
-- @return number Number of elements
function M.caml_set_cardinal(set)
  return cardinal(set)
end

--- Check if set is empty
-- @param set table|nil Set
-- @return number 1 (true) or 0 (false)
function M.caml_set_is_empty(set)
  if set == nil then
    return core.true_val
  else
    return core.false_val
  end
end

--- Filter set by predicate
-- @param cmp function Comparison function
-- @param p function Predicate (elt) -> bool
-- @param set table|nil Set
-- @return table|nil Filtered set
function M.caml_set_filter(cmp, p, set)
  return filter(cmp, p, set)
end

--- Partition set by predicate
-- @param cmp function Comparison function
-- @param p function Predicate (elt) -> bool
-- @param set table|nil Set
-- @return table Tuple [0, true_set, false_set]
function M.caml_set_partition(cmp, p, set)
  local t, f = partition(cmp, p, set)
  return {tag = 0, [1] = t, [2] = f}
end

--- Check if s1 is subset of s2
-- @param cmp function Comparison function
-- @param s1 table|nil First set
-- @param s2 table|nil Second set
-- @return number 1 (true) or 0 (false)
function M.caml_set_subset(cmp, s1, s2)
  if subset(cmp, s1, s2) then
    return core.true_val
  else
    return core.false_val
  end
end

--- Get minimum element
-- @param set table|nil Set
-- @return any Minimum element (raises Not_found if empty)
function M.caml_set_min_elt(set)
  local min = min_elt(set)
  if min == nil then
    local fail = require("fail")
    fail.caml_raise_not_found()
  end
  return min
end

--- Get maximum element
-- @param set table|nil Set
-- @return any Maximum element (raises Not_found if empty)
function M.caml_set_max_elt(set)
  local max = max_elt(set)
  if max == nil then
    local fail = require("fail")
    fail.caml_raise_not_found()
  end
  return max
end

--- Check if two sets are equal
-- @param cmp function Comparison function
-- @param s1 table|nil First set
-- @param s2 table|nil Second set
-- @return number 1 (true) or 0 (false)
function M.caml_set_equal(cmp, s1, s2)
  if cardinal(s1) ~= cardinal(s2) then
    return core.false_val
  end
  if subset(cmp, s1, s2) then
    return core.true_val
  else
    return core.false_val
  end
end

-- Register primitives
core.register("caml_set_empty", M.caml_set_empty)
core.register("caml_set_add", M.caml_set_add)
core.register("caml_set_remove", M.caml_set_remove)
core.register("caml_set_mem", M.caml_set_mem)
core.register("caml_set_union", M.caml_set_union)
core.register("caml_set_inter", M.caml_set_inter)
core.register("caml_set_diff", M.caml_set_diff)
core.register("caml_set_iter", M.caml_set_iter)
core.register("caml_set_fold", M.caml_set_fold)
core.register("caml_set_for_all", M.caml_set_for_all)
core.register("caml_set_exists", M.caml_set_exists)
core.register("caml_set_cardinal", M.caml_set_cardinal)
core.register("caml_set_is_empty", M.caml_set_is_empty)
core.register("caml_set_filter", M.caml_set_filter)
core.register("caml_set_partition", M.caml_set_partition)
core.register("caml_set_subset", M.caml_set_subset)
core.register("caml_set_min_elt", M.caml_set_min_elt)
core.register("caml_set_max_elt", M.caml_set_max_elt)
core.register("caml_set_equal", M.caml_set_equal)

return M
