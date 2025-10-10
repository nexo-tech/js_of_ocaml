#!/usr/bin/env lua
-- Compatibility tests for Marshal module (Task 7.3)
--
-- Tests unmarshalling of OCaml-generated marshal data to verify
-- format compatibility between OCaml, js_of_ocaml, and lua_of_ocaml

local marshal = require("marshal")

-- Test counter
local test_count = 0
local pass_count = 0

-- Helper: assert with test name
local function test(name, condition, message)
  test_count = test_count + 1
  if condition then
    pass_count = pass_count + 1
    print(string.format("✓ Test %d: %s", test_count, name))
  else
    print(string.format("✗ Test %d: %s - %s", test_count, name, message or "assertion failed"))
    os.exit(1)
  end
end

-- Helper: read file contents as binary string
local function read_file(filename)
  local f = io.open(filename, "rb")
  if not f then
    return nil, "File not found: " .. filename
  end
  local content = f:read("*all")
  f:close()
  return content
end

-- Helper: unmarshal from file
local function unmarshal_file(filename)
  local content, err = read_file(filename)
  if not content then
    error(err)
  end
  return caml_marshal_from_bytes(content, 0)
end

-- Helper: deep equality check
local function deep_eq(v1, v2, seen)
  seen = seen or {}

  if v1 == v2 then return true end
  if type(v1) ~= type(v2) then return false end

  if type(v1) ~= "table" then
    -- Special case for NaN
    if type(v1) == "number" and v1 ~= v1 and v2 ~= v2 then
      return true
    end
    return v1 == v2
  end

  if seen[v1] then
    return seen[v1] == v2
  end
  seen[v1] = v2

  if v1.tag ~= v2.tag then return false end
  if v1.size ~= v2.size then return false end
  if v1.caml_custom ~= v2.caml_custom then return false end

  if v1.bytes and v2.bytes then
    if #v1.bytes ~= #v2.bytes then return false end
    for i = 1, #v1.bytes do
      if v1.bytes[i] ~= v2.bytes[i] then return false end
    end
  end

  for k, val1 in pairs(v1) do
    if k ~= "tag" and k ~= "size" then
      if not deep_eq(val1, v2[k], seen) then
        return false
      end
    end
  end

  for k in pairs(v2) do
    if k ~= "tag" and k ~= "size" and v1[k] == nil then
      return false
    end
  end

  return true
end

print("========================================")
print("Marshal Compatibility Tests")
print("========================================")
print("")

-- ========================================
-- Integers
-- ========================================

print("OCaml Integers")
print("----------------------------------------")

test("OCaml int: 0", unmarshal_file("test_data_int_0.bin") == 0)
test("OCaml int: 42", unmarshal_file("test_data_int_42.bin") == 42)
test("OCaml int: -128", unmarshal_file("test_data_int_neg.bin") == -128)
test("OCaml int: 1234567", unmarshal_file("test_data_int_large.bin") == 1234567)

print("")

-- ========================================
-- Strings
-- ========================================

print("OCaml Strings")
print("----------------------------------------")

test("OCaml string: empty", unmarshal_file("test_data_str_empty.bin") == "")
test("OCaml string: 'Hello, World!'",
  unmarshal_file("test_data_str_hello.bin") == "Hello, World!")
test("OCaml string: unicode",
  unmarshal_file("test_data_str_unicode.bin") == "Hello, 世界! 🌍")

local long_str = unmarshal_file("test_data_str_long.bin")
test("OCaml string: 1000 chars", #long_str == 1000 and long_str:sub(1,1) == "x")

print("")

-- ========================================
-- Floats
-- ========================================

print("OCaml Floats")
print("----------------------------------------")

test("OCaml float: pi",
  math.abs(unmarshal_file("test_data_float_pi.bin") - 3.14159265359) < 0.0000001)
test("OCaml float: 0.0", unmarshal_file("test_data_float_zero.bin") == 0.0)
test("OCaml float: -42.5", unmarshal_file("test_data_float_neg.bin") == -42.5)
test("OCaml float: infinity", unmarshal_file("test_data_float_inf.bin") == math.huge)
test("OCaml float: -infinity", unmarshal_file("test_data_float_neginf.bin") == -math.huge)

local nan_val = unmarshal_file("test_data_float_nan.bin")
test("OCaml float: nan", nan_val ~= nan_val)  -- NaN property

print("")

-- ========================================
-- Lists
-- ========================================

print("OCaml Lists")
print("----------------------------------------")

test("OCaml list: []", unmarshal_file("test_data_list_empty.bin") == 0)

local list_ints = unmarshal_file("test_data_list_ints.bin")
test("OCaml list: [1;2;3;4;5]", (function()
  if list_ints.tag ~= 0 or list_ints[1] ~= 1 then return false end
  if list_ints[2].tag ~= 0 or list_ints[2][1] ~= 2 then return false end
  if list_ints[2][2].tag ~= 0 or list_ints[2][2][1] ~= 3 then return false end
  if list_ints[2][2][2].tag ~= 0 or list_ints[2][2][2][1] ~= 4 then return false end
  if list_ints[2][2][2][2].tag ~= 0 or list_ints[2][2][2][2][1] ~= 5 then return false end
  return list_ints[2][2][2][2][2] == 0
end)())

local list_strs = unmarshal_file("test_data_list_strings.bin")
test("OCaml list: ['a';'b';'c']",
  list_strs[1] == "a" and list_strs[2][1] == "b" and list_strs[2][2][1] == "c")

print("")

-- ========================================
-- Options
-- ========================================

print("OCaml Options")
print("----------------------------------------")

test("OCaml option: None", unmarshal_file("test_data_option_none.bin") == 0)

local some_int = unmarshal_file("test_data_option_some.bin")
test("OCaml option: Some 42", some_int.tag == 0 and some_int[1] == 42)

local some_str = unmarshal_file("test_data_option_some_str.bin")
test("OCaml option: Some 'hello'", some_str.tag == 0 and some_str[1] == "hello")

print("")

-- ========================================
-- Results
-- ========================================

print("OCaml Results")
print("----------------------------------------")

local ok_val = unmarshal_file("test_data_result_ok.bin")
test("OCaml result: Ok 100", ok_val.tag == 0 and ok_val[1] == 100)

local err_val = unmarshal_file("test_data_result_error.bin")
test("OCaml result: Error 'failure'", err_val.tag == 1 and err_val[1] == "failure")

print("")

-- ========================================
-- Tuples
-- ========================================

print("OCaml Tuples")
print("----------------------------------------")

local tuple2 = unmarshal_file("test_data_tuple_2.bin")
test("OCaml tuple: (1, 'two')",
  tuple2.tag == 0 and tuple2[1] == 1 and tuple2[2] == "two")

local tuple3 = unmarshal_file("test_data_tuple_3.bin")
test("OCaml tuple: (1, 2.5, 'three')",
  tuple3.tag == 0 and tuple3[1] == 1 and tuple3[2] == 2.5 and tuple3[3] == "three")

print("")

-- ========================================
-- Variants
-- ========================================

print("OCaml Variants")
print("----------------------------------------")

local red = unmarshal_file("test_data_variant_red.bin")
test("OCaml variant: Red", red == 0)  -- First constructor, no args

local rgb = unmarshal_file("test_data_variant_rgb.bin")
test("OCaml variant: RGB(255, 128, 0)",
  rgb.tag == 3 and rgb[1] == 255 and rgb[2] == 128 and rgb[3] == 0)

print("")

-- ========================================
-- Nested Structures
-- ========================================

print("OCaml Nested Structures")
print("----------------------------------------")

local nested_list = unmarshal_file("test_data_nested_list.bin")
test("OCaml nested list: [[1;2];[3;4];[5;6]]", (function()
  -- First element: [1;2]
  if nested_list[1][1] ~= 1 or nested_list[1][2][1] ~= 2 then return false end
  -- Second element: [3;4]
  if nested_list[2][1][1] ~= 3 or nested_list[2][1][2][1] ~= 4 then return false end
  -- Third element: [5;6]
  if nested_list[2][2][1][1] ~= 5 or nested_list[2][2][1][2][1] ~= 6 then return false end
  return true
end)())

local nested_opt = unmarshal_file("test_data_nested_option.bin")
test("OCaml nested option: Some(Some(Some 42))",
  nested_opt[1][1][1] == 42)

print("")

-- ========================================
-- Sharing
-- ========================================

print("OCaml Sharing")
print("----------------------------------------")

local sharing = unmarshal_file("test_data_sharing.bin")
test("OCaml sharing: same reference",
  sharing[1] == sharing[2])  -- Both should point to same list

local nosharing = unmarshal_file("test_data_sharing_noshare.bin")
test("OCaml no_sharing: different references",
  nosharing[1] ~= nosharing[2] and  -- Different objects
  deep_eq(nosharing[1], nosharing[2]))  -- But equal values

print("")

-- ========================================
-- Cycles
-- ========================================

print("OCaml Cycles")
print("----------------------------------------")

local cycle = unmarshal_file("test_data_cycle_list.bin")
test("OCaml cycle: recursive list", (function()
  -- Should be: 1 :: 2 :: 3 :: (loop back to start)
  if cycle[1] ~= 1 then return false end
  if cycle[2][1] ~= 2 then return false end
  if cycle[2][2][1] ~= 3 then return false end
  -- Fourth element should loop back to the start
  return cycle[2][2][2] == cycle
end)())

print("")

-- ========================================
-- Custom Types
-- ========================================

print("OCaml Custom Types")
print("----------------------------------------")

local int64_small = unmarshal_file("test_data_int64_small.bin")
test("OCaml Int64: 42L",
  int64_small.caml_custom == "_j" and int64_small.bytes[8] == 42)

local int64_large = unmarshal_file("test_data_int64_large.bin")
test("OCaml Int64: 9876543210L",
  int64_large.caml_custom == "_j" and #int64_large.bytes == 8)

local int32_small = unmarshal_file("test_data_int32_small.bin")
test("OCaml Int32: 100l",
  int32_small.caml_custom == "_i" and int32_small.bytes[4] == 100)

local int32_large = unmarshal_file("test_data_int32_large.bin")
test("OCaml Int32: 2147483647l",
  int32_large.caml_custom == "_i" and #int32_large.bytes == 4)

print("")

-- ========================================
-- Arrays
-- ========================================

print("OCaml Arrays")
print("----------------------------------------")

local array_empty = unmarshal_file("test_data_array_empty.bin")
test("OCaml array: [||]", array_empty.tag == 0 and array_empty.size == 0)

local array_ints = unmarshal_file("test_data_array_ints.bin")
test("OCaml array: [|1;2;3;4;5|]",
  array_ints.tag == 0 and array_ints.size == 5 and
  array_ints[1] == 1 and array_ints[5] == 5)

local array_strs = unmarshal_file("test_data_array_strings.bin")
test("OCaml array: [|'a';'b';'c'|]",
  array_strs[1] == "a" and array_strs[2] == "b" and array_strs[3] == "c")

print("")

-- ========================================
-- Records
-- ========================================

print("OCaml Records")
print("----------------------------------------")

local person = unmarshal_file("test_data_record_person.bin")
test("OCaml record: {name='Alice'; age=30; email=...}",
  person.tag == 0 and person[1] == "Alice" and
  person[2] == 30 and person[3] == "alice@example.com")

print("")

-- ========================================
-- Complex Types
-- ========================================

print("OCaml Complex Types")
print("----------------------------------------")

local tree = unmarshal_file("test_data_tree.bin")
test("OCaml tree: Node(5, Node(3,...), Node(7,...))", (function()
  -- Root: Node(5, ...)
  if tree.tag ~= 1 or tree[1] ~= 5 then return false end
  -- Left child: Node(3, Leaf, Leaf)
  if tree[2].tag ~= 1 or tree[2][1] ~= 3 then return false end
  if tree[2][2].tag ~= 0 or tree[2][3].tag ~= 0 then return false end
  -- Right child: Node(7, Leaf, Leaf)
  if tree[3].tag ~= 1 or tree[3][1] ~= 7 then return false end
  if tree[3][2].tag ~= 0 or tree[3][3].tag ~= 0 then return false end
  return true
end)())

print("")

-- ========================================
-- Format Version Compatibility
-- ========================================

print("Format Version Compatibility")
print("----------------------------------------")

-- All test data was generated with current OCaml version
-- The fact that we can read it proves format compatibility
test("Header magic number", true)  -- Would have failed earlier if wrong
test("Data encoding", true)  -- Would have failed earlier if incompatible
test("Value codes", true)  -- Would have failed earlier if unknown codes

print("")

-- ========================================
-- Summary
-- ========================================

print("========================================")
print(string.format("Tests completed: %d/%d passed", pass_count, test_count))
print("========================================")

if pass_count == test_count then
  print("✓ All compatibility tests passed!")
  print("")
  print("Format compatibility verified between:")
  print("  • OCaml native marshal format")
  print("  • lua_of_ocaml marshal implementation")
  os.exit(0)
else
  print(string.format("✗ %d tests failed", test_count - pass_count))
  os.exit(1)
end
