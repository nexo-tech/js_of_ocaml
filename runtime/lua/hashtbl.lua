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

-- Mutable hash table implementation
-- Compatible with OCaml's Hashtbl module
-- Uses polymorphic hashing and structural equality

local M = {}

-- Lazy load hash module to avoid circular dependencies
local hash_module = nil
local function get_hash_module()
  if not hash_module then
    hash_module = package.loaded.hash or require("hash")
  end
  return hash_module
end

-- Hashtbl object
local Hashtbl = {}
Hashtbl.__index = Hashtbl

-- Default initial size
local DEFAULT_INITIAL_SIZE = 16

-- Load factor threshold for resize (0.75)
local LOAD_FACTOR = 0.75

-- Structural equality check
-- Compares OCaml values recursively
local function equal(a, b)
  if a == b then
    return true
  end

  local ta = type(a)
  local tb = type(b)

  if ta ~= tb then
    return false
  end

  if ta ~= "table" then
    return false
  end

  -- Compare tables recursively
  -- Simple structural comparison (no cycle detection for hashtbl keys)
  local len_a = #a
  local len_b = #b

  if len_a ~= len_b then
    return false
  end

  -- Compare array elements
  for i = 1, len_a do
    if not equal(a[i], b[i]) then
      return false
    end
  end

  -- Compare tag if present
  if a.tag ~= b.tag then
    return false
  end

  return true
end

-- Create a new hash table
-- initial_size: initial capacity (optional, default 16)
-- Returns: hash table object
function M.caml_hash_create(initial_size)
  local size = initial_size or DEFAULT_INITIAL_SIZE
  if size < 1 then
    size = DEFAULT_INITIAL_SIZE
  end

  local tbl = {
    -- Array of buckets (each bucket is a list of {key, value} pairs)
    buckets = {},
    -- Current number of key-value pairs
    size = 0,
    -- Current capacity (number of buckets)
    capacity = size,
  }

  -- Initialize empty buckets
  for i = 1, size do
    tbl.buckets[i] = {}
  end

  setmetatable(tbl, Hashtbl)
  return tbl
end

-- Get bucket index for a key
local function get_bucket_index(tbl, key)
  local hash = get_hash_module().caml_hash_default(key)
  -- Map hash to bucket index (1-based)
  return (hash % tbl.capacity) + 1
end

-- Resize the hash table when load factor exceeds threshold
local function resize(tbl)
  local new_capacity = tbl.capacity * 2
  local old_buckets = tbl.buckets

  -- Create new buckets
  tbl.buckets = {}
  for i = 1, new_capacity do
    tbl.buckets[i] = {}
  end

  tbl.capacity = new_capacity
  tbl.size = 0

  -- Rehash all existing entries
  for _, bucket in ipairs(old_buckets) do
    for _, entry in ipairs(bucket) do
      M.caml_hash_add(tbl, entry.key, entry.value)
    end
  end
end

-- Add a binding to the hash table
-- Multiple bindings for the same key are allowed
-- tbl: hash table
-- key: key to add
-- value: value to associate with key
function M.caml_hash_add(tbl, key, value)
  -- Check load factor and resize if needed
  if tbl.size >= tbl.capacity * LOAD_FACTOR then
    resize(tbl)
  end

  local idx = get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  -- Add new entry to bucket (prepend for O(1) insertion)
  table.insert(bucket, 1, {key = key, value = value})
  tbl.size = tbl.size + 1
end

-- Find the value associated with a key
-- Returns the most recently added binding
-- tbl: hash table
-- key: key to find
-- Returns: value if found
-- Raises: error if not found
function M.caml_hash_find(tbl, key)
  local idx = get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  -- Search bucket for matching key
  for _, entry in ipairs(bucket) do
    if equal(entry.key, key) then
      return entry.value
    end
  end

  error("Not_found")
end

-- Find the value associated with a key (option variant)
-- tbl: hash table
-- key: key to find
-- Returns: value if found, nil otherwise
function M.caml_hash_find_opt(tbl, key)
  local idx = get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  for _, entry in ipairs(bucket) do
    if equal(entry.key, key) then
      return entry.value
    end
  end

  return nil
end

-- Remove one binding for a key
-- Removes the most recently added binding
-- tbl: hash table
-- key: key to remove
function M.caml_hash_remove(tbl, key)
  local idx = get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  -- Find and remove first matching entry
  for i, entry in ipairs(bucket) do
    if equal(entry.key, key) then
      table.remove(bucket, i)
      tbl.size = tbl.size - 1
      return
    end
  end
end

-- Remove all bindings for a key, then add a single binding
-- tbl: hash table
-- key: key to replace
-- value: new value
function M.caml_hash_replace(tbl, key, value)
  local idx = get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  -- Remove all existing bindings for this key
  local removed_count = 0
  for i = #bucket, 1, -1 do
    if equal(bucket[i].key, key) then
      table.remove(bucket, i)
      removed_count = removed_count + 1
    end
  end

  -- Add new binding
  table.insert(bucket, 1, {key = key, value = value})

  -- Update size (removed N, added 1)
  tbl.size = tbl.size - removed_count + 1
end

-- Check if a key exists in the hash table
-- tbl: hash table
-- key: key to check
-- Returns: true if key exists, false otherwise
function M.caml_hash_mem(tbl, key)
  local idx = get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  for _, entry in ipairs(bucket) do
    if equal(entry.key, key) then
      return true
    end
  end

  return false
end

-- Get the number of bindings in the hash table
-- tbl: hash table
-- Returns: number of bindings
function M.caml_hash_length(tbl)
  return tbl.size
end

-- Remove all bindings from the hash table
-- tbl: hash table
function M.caml_hash_clear(tbl)
  for i = 1, tbl.capacity do
    tbl.buckets[i] = {}
  end
  tbl.size = 0
end

-- Iterate over all bindings in the hash table
-- tbl: hash table
-- f: function(key, value) to call for each binding
function M.caml_hash_iter(tbl, f)
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      f(entry.key, entry.value)
    end
  end
end

-- Fold over all bindings in the hash table
-- tbl: hash table
-- f: function(key, value, acc) to call for each binding
-- init: initial accumulator value
-- Returns: final accumulator value
function M.caml_hash_fold(tbl, f, init)
  local acc = init
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      acc = f(entry.key, entry.value, acc)
    end
  end
  return acc
end

-- Iterator for use in for loops
-- Returns iterator that yields key, value pairs
function M.caml_hash_entries(tbl)
  local bucket_idx = 1
  local entry_idx = 0

  return function()
    while bucket_idx <= tbl.capacity do
      entry_idx = entry_idx + 1
      local bucket = tbl.buckets[bucket_idx]

      if entry_idx <= #bucket then
        local entry = bucket[entry_idx]
        return entry.key, entry.value
      end

      -- Move to next bucket
      bucket_idx = bucket_idx + 1
      entry_idx = 0
    end

    return nil
  end
end

-- Get all keys in the hash table
-- tbl: hash table
-- Returns: array of keys
function M.caml_hash_keys(tbl)
  local keys = {}
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      table.insert(keys, entry.key)
    end
  end
  return keys
end

-- Get all values in the hash table
-- tbl: hash table
-- Returns: array of values
function M.caml_hash_values(tbl)
  local values = {}
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      table.insert(values, entry.value)
    end
  end
  return values
end

-- Convert hash table to array of {key, value} pairs
-- tbl: hash table
-- Returns: array of pairs
function M.caml_hash_to_array(tbl)
  local result = {}
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      table.insert(result, {entry.key, entry.value})
    end
  end
  return result
end

-- Get statistics about the hash table (for debugging/testing)
-- tbl: hash table
-- Returns: table with statistics
function M.caml_hash_stats(tbl)
  local max_bucket_size = 0
  local empty_buckets = 0
  local total_buckets = tbl.capacity

  for _, bucket in ipairs(tbl.buckets) do
    local bucket_size = #bucket
    if bucket_size == 0 then
      empty_buckets = empty_buckets + 1
    end
    if bucket_size > max_bucket_size then
      max_bucket_size = bucket_size
    end
  end

  return {
    size = tbl.size,
    capacity = tbl.capacity,
    load_factor = tbl.size / tbl.capacity,
    max_bucket_size = max_bucket_size,
    empty_buckets = empty_buckets,
    avg_bucket_size = tbl.size / (tbl.capacity - empty_buckets),
  }
end

return M
