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

--- Map Module
--
-- Provides balanced binary search tree (AVL tree) implementation
-- for ordered maps with polymorphic comparison.

-- AVL tree node structure:
-- {
--   key = <key value>,
--   value = <data value>,
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
-- @param key any Key
-- @param value any Value
-- @param left table|nil Left subtree
-- @param right table|nil Right subtree
-- @return table New node
local function create_node(key, value, left, right)
  return {
    key = key,
    value = value,
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

  -- Perform rotation
  left.right = node
  node.left = left_right

  -- Update heights
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

  -- Perform rotation
  right.left = node
  node.right = right_left

  -- Update heights
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
      -- Left-Right case
      node.left = rotate_left(node.left)
    end
    -- Left-Left case
    return rotate_right(node)
  end

  -- Right-heavy
  if bf < -1 then
    if balance_factor(node.right) > 0 then
      -- Right-Left case
      node.right = rotate_right(node.right)
    end
    -- Right-Right case
    return rotate_left(node)
  end

  return node
end

--- Add key-value pair to tree
-- @param cmp function Comparison function
-- @param key any Key
-- @param value any Value
-- @param node table|nil Tree node
-- @return table Updated tree
local function add(cmp, key, value, node)
  if not node then
    return create_node(key, value, nil, nil)
  end

  local c = cmp(key, node.key)

  if c == 0 then
    -- Key exists, replace value
    node.value = value
    return node
  elseif c < 0 then
    -- Add to left subtree
    node.left = add(cmp, key, value, node.left)
  else
    -- Add to right subtree
    node.right = add(cmp, key, value, node.right)
  end

  -- Update height
  node.height = 1 + math.max(height(node.left), height(node.right))

  -- Balance the tree
  return balance(node)
end

--- Find value by key in tree
-- @param cmp function Comparison function
-- @param key any Key
-- @param node table|nil Tree node
-- @return any|nil Value if found, nil otherwise
local function find(cmp, key, node)
  if not node then
    return nil
  end

  local c = cmp(key, node.key)

  if c == 0 then
    return node.value
  elseif c < 0 then
    return find(cmp, key, node.left)
  else
    return find(cmp, key, node.right)
  end
end

--- Check if key exists in tree
-- @param cmp function Comparison function
-- @param key any Key
-- @param node table|nil Tree node
-- @return boolean True if key exists
local function mem(cmp, key, node)
  if not node then
    return false
  end

  local c = cmp(key, node.key)

  if c == 0 then
    return true
  elseif c < 0 then
    return mem(cmp, key, node.left)
  else
    return mem(cmp, key, node.right)
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

--- Remove key from tree
-- @param cmp function Comparison function
-- @param key any Key
-- @param node table|nil Tree node
-- @return table|nil Updated tree
local function remove(cmp, key, node)
  if not node then
    return nil
  end

  local c = cmp(key, node.key)

  if c < 0 then
    -- Remove from left subtree
    node.left = remove(cmp, key, node.left)
  elseif c > 0 then
    -- Remove from right subtree
    node.right = remove(cmp, key, node.right)
  else
    -- Found the node to remove
    if not node.left then
      return node.right
    elseif not node.right then
      return node.left
    else
      -- Node has two children: find in-order successor
      local successor = min_node(node.right)
      node.key = successor.key
      node.value = successor.value
      node.right = remove(cmp, successor.key, node.right)
    end
  end

  if not node then
    return nil
  end

  -- Update height
  node.height = 1 + math.max(height(node.left), height(node.right))

  -- Balance the tree
  return balance(node)
end

--- Iterate over tree in ascending key order
-- @param f function Function to call for each (key, value) pair
-- @param node table|nil Tree node
local function iter(f, node)
  if not node then
    return
  end
  iter(f, node.left)
  f(node.key, node.value)
  iter(f, node.right)
end

--- Fold over tree in ascending key order
-- @param f function Fold function (key, value, acc) -> acc
-- @param node table|nil Tree node
-- @param acc any Accumulator
-- @return any Final accumulator value
local function fold(f, node, acc)
  if not node then
    return acc
  end
  acc = fold(f, node.left, acc)
  acc = f(node.key, node.value, acc)
  acc = fold(f, node.right, acc)
  return acc
end

--- Check if predicate holds for all elements
-- @param p function Predicate (key, value) -> bool
-- @param node table|nil Tree node
-- @return boolean True if predicate holds for all elements
local function for_all(p, node)
  if not node then
    return true
  end
  return p(node.key, node.value) and for_all(p, node.left) and for_all(p, node.right)
end

--- Check if predicate holds for at least one element
-- @param p function Predicate (key, value) -> bool
-- @param node table|nil Tree node
-- @return boolean True if predicate holds for at least one element
local function exists(p, node)
  if not node then
    return false
  end
  return p(node.key, node.value) or exists(p, node.left) or exists(p, node.right)
end

--- Count number of elements in tree
-- @param node table|nil Tree node
-- @return number Number of elements
local function cardinal(node)
  if not node then
    return 0
  end
  return 1 + cardinal(node.left) + cardinal(node.right)
end

--- Map function over tree values
-- @param f function Mapping function (value) -> new_value
-- @param node table|nil Tree node
-- @return table|nil Mapped tree
local function map_values(f, node)
  if not node then
    return nil
  end
  return create_node(
    node.key,
    f(node.value),
    map_values(f, node.left),
    map_values(f, node.right)
  )
end

--- Map function over tree key-value pairs
-- @param f function Mapping function (key, value) -> new_value
-- @param node table|nil Tree node
-- @return table|nil Mapped tree
local function mapi(f, node)
  if not node then
    return nil
  end
  return create_node(
    node.key,
    f(node.key, node.value),
    mapi(f, node.left),
    mapi(f, node.right)
  )
end

--- Filter tree by predicate
-- @param cmp function Comparison function
-- @param p function Predicate (key, value) -> bool
-- @param node table|nil Tree node
-- @return table|nil Filtered tree
local function filter(cmp, p, node)
  if not node then
    return nil
  end

  local left = filter(cmp, p, node.left)
  local right = filter(cmp, p, node.right)

  if p(node.key, node.value) then
    local result = create_node(node.key, node.value, left, right)
    return balance(result)
  else
    -- Merge left and right subtrees
    if not left then
      return right
    elseif not right then
      return left
    else
      local min = min_node(right)
      local new_right = remove(cmp, min.key, right)
      local result = create_node(min.key, min.value, left, new_right)
      return balance(result)
    end
  end
end

-- OCaml Map primitives
-- In OCaml, maps are immutable and use structural sharing

--- Create empty map
-- @param _unit number Unit value
-- @return nil Empty map (represented as nil)
--Provides: caml_map_empty
function caml_map_empty(_unit)
  return nil
end

--- Add key-value binding to map
-- @param cmp function Comparison function
-- @param key any Key
-- @param value any Value
-- @param map table|nil Map
-- @return table Updated map
--Provides: caml_map_add
function caml_map_add(cmp, key, value, map)
  return add(cmp, key, value, map)
end

--- Find value by key
-- @param cmp function Comparison function
-- @param key any Key
-- @param map table|nil Map
-- @return any Value (raises Not_found if not present)
--Provides: caml_map_find
--Requires: caml_raise_not_found
function caml_map_find(cmp, key, map)
  local result = find(cmp, key, map)
  if result == nil then
    caml_raise_not_found()
  end
  return result
end

--- Find value by key (optional version)
-- @param cmp function Comparison function
-- @param key any Key
-- @param map table|nil Map
-- @return number|table None (0) or Some value
--Provides: caml_map_find_opt
function caml_map_find_opt(cmp, key, map)
  local result = find(cmp, key, map)
  if result == nil then
    return 0  -- None
  else
    return {tag = 0, [1] = result}  -- Some value
  end
end

--- Remove key from map
-- @param cmp function Comparison function
-- @param key any Key
-- @param map table|nil Map
-- @return table|nil Updated map
--Provides: caml_map_remove
function caml_map_remove(cmp, key, map)
  return remove(cmp, key, map)
end

--- Check if key is in map
-- @param cmp function Comparison function
-- @param key any Key
-- @param map table|nil Map
-- @return number 1 (true) or 0 (false)
--Provides: caml_map_mem
function caml_map_mem(cmp, key, map)
  if mem(cmp, key, map) then
    return 1
  else
    return 0
  end
end

--- Iterate function over map bindings
-- @param f function Function (key, value) -> unit
-- @param map table|nil Map
-- @return number Unit value
--Provides: caml_map_iter
function caml_map_iter(f, map)
  iter(f, map)
  return 0
end

--- Fold function over map bindings
-- @param f function Fold function (key, value, acc) -> acc
-- @param map table|nil Map
-- @param init any Initial accumulator
-- @return any Final accumulator
--Provides: caml_map_fold
function caml_map_fold(f, map, init)
  return fold(f, map, init)
end

--- Check if predicate holds for all bindings
-- @param p function Predicate (key, value) -> bool
-- @param map table|nil Map
-- @return number 1 (true) or 0 (false)
--Provides: caml_map_for_all
function caml_map_for_all(p, map)
  if for_all(p, map) then
    return 1
  else
    return 0
  end
end

--- Check if predicate holds for at least one binding
-- @param p function Predicate (key, value) -> bool
-- @param map table|nil Map
-- @return number 1 (true) or 0 (false)
--Provides: caml_map_exists
function caml_map_exists(p, map)
  if exists(p, map) then
    return 1
  else
    return 0
  end
end

--- Get number of bindings in map
-- @param map table|nil Map
-- @return number Number of bindings
--Provides: caml_map_cardinal
function caml_map_cardinal(map)
  return cardinal(map)
end

--- Check if map is empty
-- @param map table|nil Map
-- @return number 1 (true) or 0 (false)
--Provides: caml_map_is_empty
function caml_map_is_empty(map)
  if map == nil then
    return 1
  else
    return 0
  end
end

--- Map function over values
-- @param f function Mapping function (value) -> new_value
-- @param map table|nil Map
-- @return table|nil Mapped map
--Provides: caml_map_map
function caml_map_map(f, map)
  return map_values(f, map)
end

--- Map function over key-value pairs
-- @param f function Mapping function (key, value) -> new_value
-- @param map table|nil Map
-- @return table|nil Mapped map
--Provides: caml_map_mapi
function caml_map_mapi(f, map)
  return mapi(f, map)
end

--- Filter map by predicate
-- @param cmp function Comparison function
-- @param p function Predicate (key, value) -> bool
-- @param map table|nil Map
-- @return table|nil Filtered map
--Provides: caml_map_filter
function caml_map_filter(cmp, p, map)
  return filter(cmp, p, map)
end
