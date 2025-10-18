

--Provides: caml_list_empty
function caml_list_empty()
  return 0
end

--Provides: caml_list_cons
function caml_list_cons(hd, tl)
  return {0, hd, tl}
end


--Provides: caml_list_hd
function caml_list_hd(list)
  if list == 0 then
    error("hd")
  end
  return list[2]
end

--Provides: caml_list_tl
function caml_list_tl(list)
  if list == 0 then
    error("tl")
  end
  return list[3]
end

--Provides: caml_list_is_empty
function caml_list_is_empty(list)
  return list == 0
end


--Provides: caml_list_length
function caml_list_length(list)
  local len = 0
  while list ~= 0 do
    len = len + 1
    list = list[3]
  end
  return len
end


--Provides: caml_list_nth
function caml_list_nth(list, n)
  local current = list
  local index = 0
  while current ~= 0 do
    if index == n then
      return current[2]
    end
    index = index + 1
    current = current[3]
  end
  error("nth")
end

--Provides: caml_list_nth_opt
function caml_list_nth_opt(list, n)
  local current = list
  local index = 0
  while current ~= 0 do
    if index == n then
      return {0, current[2]}  -- Some(value)
    end
    index = index + 1
    current = current[3]
  end
  return 0  -- None
end


--Provides: caml_list_rev
function caml_list_rev(list)
  local result = 0
  while list ~= 0 do
    result = {0, list[2], result}
    list = list[3]
  end
  return result
end

--Provides: caml_list_rev_append
function caml_list_rev_append(list1, list2)
  local result = list2
  while list1 ~= 0 do
    result = {0, list1[2], result}
    list1 = list1[3]
  end
  return result
end


--Provides: caml_list_append
function caml_list_append(list1, list2)
  if list1 == 0 then
    return list2
  end
  local rev = 0
  local current = list1
  while current ~= 0 do
    rev = {0, current[2], rev}
    current = current[3]
  end
  local result = list2
  while rev ~= 0 do
    result = {0, rev[2], result}
    rev = rev[3]
  end
  return result
end

--Provides: caml_list_concat
--Requires: caml_list_append
function caml_list_concat(lists)
  local result = 0
  local rev_lists = 0
  while lists ~= 0 do
    rev_lists = {0, lists[2], rev_lists}
    lists = lists[3]
  end
  while rev_lists ~= 0 do
    result = caml_list_append(rev_lists[2], result)
    rev_lists = rev_lists[3]
  end
  return result
end

--Provides: caml_list_flatten
--Requires: caml_list_concat
function caml_list_flatten(lists)
  return caml_list_concat(lists)
end


--Provides: caml_list_iter
function caml_list_iter(f, list)
  while list ~= 0 do
    f(list[2])
    list = list[3]
  end
end

--Provides: caml_list_iteri
function caml_list_iteri(f, list)
  local i = 0
  while list ~= 0 do
    f(i, list[2])
    list = list[3]
    i = i + 1
  end
end


--Provides: caml_list_map
--Requires: caml_list_rev
function caml_list_map(f, list)
  if list == 0 then
    return 0
  end
  local rev = 0
  while list ~= 0 do
    rev = {0, f(list[2]), rev}
    list = list[3]
  end
  return caml_list_rev(rev)
end

--Provides: caml_list_mapi
--Requires: caml_list_rev
function caml_list_mapi(f, list)
  if list == 0 then
    return 0
  end
  local rev = 0
  local i = 0
  while list ~= 0 do
    rev = {0, f(i, list[2]), rev}
    list = list[3]
    i = i + 1
  end
  return caml_list_rev(rev)
end

--Provides: caml_list_rev_map
function caml_list_rev_map(f, list)
  local result = 0
  while list ~= 0 do
    result = {0, f(list[2]), result}
    list = list[3]
  end
  return result
end

--Provides: caml_list_filter_map
--Requires: caml_list_rev
function caml_list_filter_map(f, list)
  local rev = 0
  while list ~= 0 do
    local opt = f(list[2])
    if opt ~= 0 then  -- Some(value)
      rev = {0, opt[2], rev}
    end
    list = list[3]
  end
  return caml_list_rev(rev)
end

--Provides: caml_list_concat_map
--Requires: caml_list_append
function caml_list_concat_map(f, list)
  local result = 0
  local rev_parts = 0
  while list ~= 0 do
    rev_parts = {0, f(list[2]), rev_parts}
    list = list[3]
  end
  while rev_parts ~= 0 do
    result = caml_list_append(rev_parts[2], result)
    rev_parts = rev_parts[3]
  end
  return result
end


--Provides: caml_list_fold_left
function caml_list_fold_left(f, acc, list)
  while list ~= 0 do
    acc = f(acc, list[2])
    list = list[3]
  end
  return acc
end

--Provides: caml_list_fold_right
--Requires: caml_list_rev
function caml_list_fold_right(f, list, acc)
  local rev = caml_list_rev(list)
  while rev ~= 0 do
    acc = f(rev[2], acc)
    rev = rev[3]
  end
  return acc
end


--Provides: caml_list_for_all
function caml_list_for_all(pred, list)
  while list ~= 0 do
    if pred(list[2]) == 0 then
      return 0  -- OCaml false
    end
    list = list[3]
  end
  return 1  -- OCaml true
end

--Provides: caml_list_exists
function caml_list_exists(pred, list)
  while list ~= 0 do
    if pred(list[2]) ~= 0 then
      return 1  -- OCaml true
    end
    list = list[3]
  end
  return 0  -- OCaml false
end

--Provides: caml_list_mem
function caml_list_mem(x, list)
  while list ~= 0 do
    if list[2] == x then
      return 1  -- OCaml true
    end
    list = list[3]
  end
  return 0  -- OCaml false
end

--Provides: caml_list_memq
--Requires: caml_list_mem
function caml_list_memq(x, list)
  return caml_list_mem(x, list)
end


--Provides: caml_list_find
function caml_list_find(pred, list)
  while list ~= 0 do
    if pred(list[2]) then
      return list[2]
    end
    list = list[3]
  end
  error("Not_found")
end

--Provides: caml_list_find_opt
function caml_list_find_opt(pred, list)
  while list ~= 0 do
    if pred(list[2]) then
      return {0, list[2]}  -- Some(value)
    end
    list = list[3]
  end
  return 0  -- None
end

--Provides: caml_list_find_map
function caml_list_find_map(f, list)
  while list ~= 0 do
    local opt = f(list[2])
    if opt ~= 0 then  -- Some(value)
      return opt
    end
    list = list[3]
  end
  return 0  -- None
end

--Provides: caml_list_filter
--Requires: caml_list_rev
function caml_list_filter(pred, list)
  local rev = 0
  while list ~= 0 do
    if pred(list[2]) then
      rev = {0, list[2], rev}
    end
    list = list[3]
  end
  return caml_list_rev(rev)
end

--Provides: caml_list_partition
--Requires: caml_list_rev
function caml_list_partition(pred, list)
  local true_list = 0
  local false_list = 0
  while list ~= 0 do
    if pred(list[2]) then
      true_list = {0, list[2], true_list}
    else
      false_list = {0, list[2], false_list}
    end
    list = list[3]
  end
  return {caml_list_rev(true_list), caml_list_rev(false_list)}
end


--Provides: caml_list_assoc
function caml_list_assoc(key, list)
  while list ~= 0 do
    local pair = list[2]
    if pair[2] == key then
      return pair[3]
    end
    list = list[3]
  end
  error("Not_found")
end

--Provides: caml_list_assoc_opt
function caml_list_assoc_opt(key, list)
  while list ~= 0 do
    local pair = list[2]
    if pair[2] == key then
      return {0, pair[3]}  -- Some(value)
    end
    list = list[3]
  end
  return 0  -- None
end

--Provides: caml_list_assq
--Requires: caml_list_assoc
function caml_list_assq(key, list)
  return caml_list_assoc(key, list)
end

--Provides: caml_list_assq_opt
--Requires: caml_list_assoc_opt
function caml_list_assq_opt(key, list)
  return caml_list_assoc_opt(key, list)
end

--Provides: caml_list_mem_assoc
function caml_list_mem_assoc(key, list)
  while list ~= 0 do
    local pair = list[2]
    if pair[2] == key then
      return 1  -- OCaml true
    end
    list = list[3]
  end
  return 0  -- OCaml false
end

--Provides: caml_list_mem_assq
--Requires: caml_list_mem_assoc
function caml_list_mem_assq(key, list)
  return caml_list_mem_assoc(key, list)
end

--Provides: caml_list_remove_assoc
--Requires: caml_list_rev
function caml_list_remove_assoc(key, list)
  if list == 0 then
    return 0
  end
  local pair = list[2]
  if pair[2] == key then
    return list[3]  -- Skip this element
  end
  local rev = 0
  local current = list
  local found = false
  while current ~= 0 do
    local p = current[2]
    if not found and p[2] == key then
      found = true
    else
      rev = {0, p, rev}
    end
    current = current[3]
  end
  return caml_list_rev(rev)
end

--Provides: caml_list_remove_assq
--Requires: caml_list_remove_assoc
function caml_list_remove_assq(key, list)
  return caml_list_remove_assoc(key, list)
end


--Provides: caml_list_split
--Requires: caml_list_rev
function caml_list_split(list)
  local list1 = 0
  local list2 = 0
  while list ~= 0 do
    local pair = list[2]
    list1 = {0, pair[2], list1}
    list2 = {0, pair[3], list2}
    list = list[3]
  end
  return {caml_list_rev(list1), caml_list_rev(list2)}
end

--Provides: caml_list_combine
--Requires: caml_list_rev
function caml_list_combine(list1, list2)
  local result = 0
  local rev = 0
  while list1 ~= 0 and list2 ~= 0 do
    rev = {0, {list1[2], list2[2]}, rev}
    list1 = list1[3]
    list2 = list2[3]
  end
  if list1 ~= 0 or list2 ~= 0 then
    error("Invalid_argument")
  end
  return caml_list_rev(rev)
end


--Provides: caml_list_sort
function caml_list_sort(cmp, list)
  if list == 0 or list[3] == 0 then
    return list
  end
  local arr = {}
  local current = list
  while current ~= 0 do
    table.insert(arr, current[2])
    current = current[3]
  end
  table.sort(arr, function(a, b) return cmp(a, b) < 0 end)
  local result = 0
  for i = #arr, 1, -1 do
    result = {0, arr[i], result}
  end
  return result
end

--Provides: caml_list_stable_sort
--Requires: caml_list_sort
function caml_list_stable_sort(cmp, list)
  return caml_list_sort(cmp, list)
end

--Provides: caml_list_fast_sort
--Requires: caml_list_sort
function caml_list_fast_sort(cmp, list)
  return caml_list_sort(cmp, list)
end

--Provides: caml_list_sort_uniq
--Requires: caml_list_sort
function caml_list_sort_uniq(cmp, list)
  if list == 0 then
    return 0
  end
  local sorted = caml_list_sort(cmp, list)
  local result = {0, sorted[2], 0}
  local tail = result
  sorted = sorted[3]
  while sorted ~= 0 do
    if cmp(tail[2], sorted[2]) ~= 0 then
      local new_tail = {0, sorted[2], 0}
      tail[3] = new_tail
      tail = new_tail
    end
    sorted = sorted[3]
  end
  return result
end

--Provides: caml_list_merge
--Requires: caml_list_rev
function caml_list_merge(cmp, list1, list2)
  if list1 == 0 then
    return list2
  end
  if list2 == 0 then
    return list1
  end
  local rev = 0
  while list1 ~= 0 and list2 ~= 0 do
    if cmp(list1[2], list2[2]) <= 0 then
      rev = {0, list1[2], rev}
      list1 = list1[3]
    else
      rev = {0, list2[2], rev}
      list2 = list2[3]
    end
  end
  local remaining = list1 ~= 0 and list1 or list2
  while remaining ~= 0 do
    rev = {0, remaining[2], rev}
    remaining = remaining[3]
  end
  return caml_list_rev(rev)
end