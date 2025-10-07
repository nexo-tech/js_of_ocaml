-- Tests for List module

local list = require("list")

-- Test helpers
local function assert_eq(a, b, msg)
  if a ~= b then
    error(msg or ("Assertion failed: " .. tostring(a) .. " ~= " .. tostring(b)))
  end
end

local function assert_true(v, msg)
  if not v then
    error(msg or "Assertion failed: expected true")
  end
end

local function assert_false(v, msg)
  if v then
    error(msg or "Assertion failed: expected false")
  end
end

print("Testing List module...")

-- Test empty list
local empty = list.caml_list_empty()
assert_eq(empty, 0, "Empty list should be 0")
assert_true(list.caml_list_is_empty(empty), "Empty list should be empty")
assert_eq(list.caml_list_length(empty), 0, "Empty list length should be 0")

-- Test cons
local l1 = list.caml_list_cons(1, empty)
assert_false(list.caml_list_is_empty(l1), "Non-empty list")
assert_eq(list.caml_list_length(l1), 1, "Length 1")
assert_eq(list.caml_list_hd(l1), 1, "Head should be 1")
assert_eq(list.caml_list_tl(l1), 0, "Tail should be empty")

-- Test building a list [3, 2, 1]
local l3 = list.caml_list_cons(3, list.caml_list_cons(2, list.caml_list_cons(1, 0)))
assert_eq(list.caml_list_length(l3), 3, "Length 3")
assert_eq(list.caml_list_hd(l3), 3, "Head should be 3")
assert_eq(list.caml_list_nth(l3, 0), 3, "0th element")
assert_eq(list.caml_list_nth(l3, 1), 2, "1st element")
assert_eq(list.caml_list_nth(l3, 2), 1, "2nd element")

-- Test rev
local rev_l3 = list.caml_list_rev(l3)
assert_eq(list.caml_list_hd(rev_l3), 1, "Rev head")
assert_eq(list.caml_list_nth(rev_l3, 0), 1, "Rev 0th")
assert_eq(list.caml_list_nth(rev_l3, 1), 2, "Rev 1st")
assert_eq(list.caml_list_nth(rev_l3, 2), 3, "Rev 2nd")

-- Test append
local l2 = list.caml_list_cons(2, list.caml_list_cons(1, 0))
local l4 = list.caml_list_cons(4, list.caml_list_cons(3, 0))
local appended = list.caml_list_append(l4, l2)
assert_eq(list.caml_list_length(appended), 4, "Appended length")
assert_eq(list.caml_list_nth(appended, 0), 4, "Appended 0th")
assert_eq(list.caml_list_nth(appended, 3), 1, "Appended 3rd")

-- Test map
local doubled = list.caml_list_map(function(x) return x * 2 end, l2)
assert_eq(list.caml_list_nth(doubled, 0), 4, "Doubled 0th")
assert_eq(list.caml_list_nth(doubled, 1), 2, "Doubled 1st")

-- Test filter
local evens = list.caml_list_filter(function(x) return x % 2 == 0 end, appended)
assert_eq(list.caml_list_length(evens), 2, "Evens length")
assert_eq(list.caml_list_nth(evens, 0), 4, "Even 0th")
assert_eq(list.caml_list_nth(evens, 1), 2, "Even 1st")

-- Test fold_left
local sum = list.caml_list_fold_left(function(acc, x) return acc + x end, 0, l2)
assert_eq(sum, 3, "Sum should be 3")

-- Test for_all
local all_positive = list.caml_list_for_all(function(x) return x > 0 end, l2)
assert_true(all_positive, "All positive")

local all_even = list.caml_list_for_all(function(x) return x % 2 == 0 end, l2)
assert_false(all_even, "Not all even")

-- Test exists
local has_even = list.caml_list_exists(function(x) return x % 2 == 0 end, l2)
assert_true(has_even, "Has even")

-- Test mem
assert_true(list.caml_list_mem(2, l2), "Mem 2")
assert_false(list.caml_list_mem(5, l2), "Not mem 5")

-- Test sort
local unsorted = list.caml_list_cons(3, list.caml_list_cons(1, list.caml_list_cons(2, 0)))
local sorted = list.caml_list_sort(function(a, b) return a - b end, unsorted)
assert_eq(list.caml_list_nth(sorted, 0), 1, "Sorted 0th")
assert_eq(list.caml_list_nth(sorted, 1), 2, "Sorted 1st")
assert_eq(list.caml_list_nth(sorted, 2), 3, "Sorted 2nd")

print("All List tests passed!")
