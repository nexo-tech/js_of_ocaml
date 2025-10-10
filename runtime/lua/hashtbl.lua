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


--Provides: caml_hashtbl_equal
function caml_hashtbl_equal(a, b)
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

  local len_a = #a
  local len_b = #b

  if len_a ~= len_b then
    return false
  end

  for i = 1, len_a do
    if not caml_hashtbl_equal(a[i], b[i]) then
      return false
    end
  end

  if a.tag ~= b.tag then
    return false
  end

  return true
end

--Provides: caml_hashtbl_get_bucket_index
--Requires: caml_hash_default
function caml_hashtbl_get_bucket_index(tbl, key)
  local hash = caml_hash_default(key)
  return (hash % tbl.capacity) + 1
end

--Provides: caml_hashtbl_resize
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hashtbl_resize(tbl)
  local new_capacity = tbl.capacity * 2
  local old_buckets = tbl.buckets

  tbl.buckets = {}
  for i = 1, new_capacity do
    tbl.buckets[i] = {}
  end

  tbl.capacity = new_capacity
  local old_size = tbl.size
  tbl.size = 0

  for _, bucket in ipairs(old_buckets) do
    for _, entry in ipairs(bucket) do
      local idx = caml_hashtbl_get_bucket_index(tbl, entry.key)
      local new_bucket = tbl.buckets[idx]
      table.insert(new_bucket, 1, {key = entry.key, value = entry.value})
      tbl.size = tbl.size + 1
    end
  end
end

--Provides: caml_hash_create
function caml_hash_create(initial_size)
  local size = initial_size or 16
  if size < 1 then
    size = 16
  end

  local tbl = {
    buckets = {},
    size = 0,
    capacity = size,
  }

  for i = 1, size do
    tbl.buckets[i] = {}
  end

  return tbl
end

--Provides: caml_hash_add
--Requires: caml_hashtbl_resize, caml_hashtbl_get_bucket_index
function caml_hash_add(tbl, key, value)
  if tbl.size >= tbl.capacity * 0.75 then
    caml_hashtbl_resize(tbl)
  end

  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  table.insert(bucket, 1, {key = key, value = value})
  tbl.size = tbl.size + 1
end

--Provides: caml_hash_find
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hash_find(tbl, key)
  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  for _, entry in ipairs(bucket) do
    if caml_hashtbl_equal(entry.key, key) then
      return entry.value
    end
  end

  error("Not_found")
end

--Provides: caml_hash_find_opt
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hash_find_opt(tbl, key)
  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  for _, entry in ipairs(bucket) do
    if caml_hashtbl_equal(entry.key, key) then
      return entry.value
    end
  end

  return nil
end

--Provides: caml_hash_remove
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hash_remove(tbl, key)
  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  for i, entry in ipairs(bucket) do
    if caml_hashtbl_equal(entry.key, key) then
      table.remove(bucket, i)
      tbl.size = tbl.size - 1
      return
    end
  end
end

--Provides: caml_hash_replace
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hash_replace(tbl, key, value)
  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  local removed_count = 0
  for i = #bucket, 1, -1 do
    if caml_hashtbl_equal(bucket[i].key, key) then
      table.remove(bucket, i)
      removed_count = removed_count + 1
    end
  end

  table.insert(bucket, 1, {key = key, value = value})

  tbl.size = tbl.size - removed_count + 1
end

--Provides: caml_hash_mem
--Requires: caml_hashtbl_get_bucket_index, caml_hashtbl_equal
function caml_hash_mem(tbl, key)
  local idx = caml_hashtbl_get_bucket_index(tbl, key)
  local bucket = tbl.buckets[idx]

  for _, entry in ipairs(bucket) do
    if caml_hashtbl_equal(entry.key, key) then
      return true
    end
  end

  return false
end

--Provides: caml_hash_length
function caml_hash_length(tbl)
  return tbl.size
end

--Provides: caml_hash_clear
function caml_hash_clear(tbl)
  for i = 1, tbl.capacity do
    tbl.buckets[i] = {}
  end
  tbl.size = 0
end

--Provides: caml_hash_iter
function caml_hash_iter(tbl, f)
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      f(entry.key, entry.value)
    end
  end
end

--Provides: caml_hash_fold
function caml_hash_fold(tbl, f, init)
  local acc = init
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      acc = f(entry.key, entry.value, acc)
    end
  end
  return acc
end

--Provides: caml_hash_entries
function caml_hash_entries(tbl)
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

      bucket_idx = bucket_idx + 1
      entry_idx = 0
    end

    return nil
  end
end

--Provides: caml_hash_keys
function caml_hash_keys(tbl)
  local keys = {}
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      table.insert(keys, entry.key)
    end
  end
  return keys
end

--Provides: caml_hash_values
function caml_hash_values(tbl)
  local values = {}
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      table.insert(values, entry.value)
    end
  end
  return values
end

--Provides: caml_hash_to_array
function caml_hash_to_array(tbl)
  local result = {}
  for _, bucket in ipairs(tbl.buckets) do
    for _, entry in ipairs(bucket) do
      table.insert(result, {entry.key, entry.value})
    end
  end
  return result
end

--Provides: caml_hash_stats
function caml_hash_stats(tbl)
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
