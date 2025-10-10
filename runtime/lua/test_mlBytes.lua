#!/usr/bin/env lua
-- Test suite for mlBytes.lua string and bytes operations primitives

-- Load mlBytes.lua directly (it defines global caml_* functions)
dofile("mlBytes.lua")

local tests_passed = 0
local tests_failed = 0

-- Test helper
local function test(name, func)
  local success, err = pcall(func)
  if success then
    tests_passed = tests_passed + 1
    print("✓ " .. name)
  else
    tests_failed = tests_failed + 1
    print("✗ " .. name)
    print("  Error: " .. tostring(err))
  end
end

-- Test bytes creation and conversion
test("Create empty bytes", function()
  local b = caml_create_bytes(0)
  assert(b.length == 0, "Empty bytes should have length 0")
end)

test("Create bytes with fill", function()
  local b = caml_create_bytes(5, 42)
  assert(b.length == 5, "Bytes should have length 5")
  for i = 0, 4 do
    assert(b[i] == 42, "All bytes should be 42")
  end
end)

test("Bytes of string", function()
  local b = caml_bytes_of_string("hello")
  assert(b.length == 5, "Should have length 5")
  assert(b[0] == string.byte('h'), "First byte should be 'h'")
  assert(b[4] == string.byte('o'), "Last byte should be 'o'")
end)

test("String of bytes", function()
  local b = caml_create_bytes(5)
  b[0] = string.byte('h')
  b[1] = string.byte('e')
  b[2] = string.byte('l')
  b[3] = string.byte('l')
  b[4] = string.byte('o')
  local s = caml_string_of_bytes(b)
  assert(s == "hello", "Should convert to 'hello'")
end)

test("Round-trip conversion", function()
  local orig = "test string 123"
  local b = caml_bytes_of_string(orig)
  local result = caml_string_of_bytes(b)
  assert(orig == result, "Round-trip should preserve string")
end)

-- Test get/set operations
test("Unsafe get from bytes", function()
  local b = caml_bytes_of_string("abc")
  assert(caml_bytes_unsafe_get(b, 0) == string.byte('a'), "Get first byte")
  assert(caml_bytes_unsafe_get(b, 1) == string.byte('b'), "Get second byte")
  assert(caml_bytes_unsafe_get(b, 2) == string.byte('c'), "Get third byte")
end)

test("Unsafe get from string", function()
  local s = "xyz"
  assert(caml_bytes_unsafe_get(s, 0) == string.byte('x'), "Get from string")
  assert(caml_bytes_unsafe_get(s, 1) == string.byte('y'), "Get from string")
end)

test("Unsafe set", function()
  local b = caml_create_bytes(3)
  caml_bytes_unsafe_set(b, 0, string.byte('A'))
  caml_bytes_unsafe_set(b, 1, string.byte('B'))
  caml_bytes_unsafe_set(b, 2, string.byte('C'))
  assert(caml_string_of_bytes(b) == "ABC", "Set should work")
end)

test("Safe get with bounds check", function()
  local b = caml_bytes_of_string("test")
  assert(caml_bytes_get(b, 0) == string.byte('t'), "Get within bounds")
  local success = pcall(function() caml_bytes_get(b, 10) end)
  assert(not success, "Should fail for out of bounds")
end)

test("Safe set with bounds check", function()
  local b = caml_create_bytes(3)
  caml_bytes_set(b, 0, 65)
  assert(b[0] == 65, "Set should work")
  local success = pcall(function() caml_bytes_set(b, 10, 65) end)
  assert(not success, "Should fail for out of bounds")
end)

test("Set with byte masking", function()
  local b = caml_create_bytes(1)
  caml_bytes_unsafe_set(b, 0, 0x1FF)  -- 511, should be masked to 255
  assert(b[0] == 0xFF, "Should mask to 8 bits")
end)

-- Test length
test("Length of bytes", function()
  local b = caml_create_bytes(10)
  assert(caml_ml_bytes_length(b) == 10, "Bytes length")
end)

test("Length of string", function()
  assert(caml_ml_bytes_length("hello") == 5, "String length")
  assert(caml_ml_bytes_length("") == 0, "Empty string length")
end)

-- Test blit (copy)
test("Blit bytes to bytes", function()
  local src = caml_bytes_of_string("hello")
  local dst = caml_create_bytes(10, 0)
  caml_blit_bytes(src, 0, dst, 0, 5)
  assert(caml_string_of_bytes(dst):sub(1, 5) == "hello", "Should copy hello")
end)

test("Blit with offset", function()
  local src = caml_bytes_of_string("world")
  local dst = caml_create_bytes(10, string.byte('_'))
  caml_blit_bytes(src, 1, dst, 2, 3)  -- Copy "orl" to position 2
  local result = caml_string_of_bytes(dst)
  assert(result:sub(3, 5) == "orl", "Should copy with offsets")
end)

test("Blit from string", function()
  local dst = caml_create_bytes(5)
  caml_blit_bytes("test", 0, dst, 1, 3)
  assert(dst[1] == string.byte('t'), "Should blit from string")
  assert(dst[2] == string.byte('e'), "Should blit from string")
  assert(dst[3] == string.byte('s'), "Should blit from string")
end)

-- Test fill
test("Fill bytes", function()
  local b = caml_create_bytes(10)
  caml_fill_bytes(b, 0, 10, 65)
  for i = 0, 9 do
    assert(b[i] == 65, "All bytes should be 65 (A)")
  end
end)

test("Fill partial", function()
  local b = caml_create_bytes(10, 0)
  caml_fill_bytes(b, 2, 5, 88)  -- Fill positions 2-6 with 'X'
  assert(b[1] == 0, "Before range should be 0")
  assert(b[2] == 88, "In range should be 88")
  assert(b[6] == 88, "In range should be 88")
  assert(b[7] == 0, "After range should be 0")
end)

-- Test sub
test("Sub bytes", function()
  local b = caml_bytes_of_string("hello world")
  local sub = caml_bytes_sub(b, 6, 5)  -- Extract "world"
  assert(caml_string_of_bytes(sub) == "world", "Sub should extract substring")
end)

-- Test compare
test("Compare equal bytes", function()
  local b1 = caml_bytes_of_string("test")
  local b2 = caml_bytes_of_string("test")
  assert(caml_bytes_compare(b1, b2) == 0, "Equal bytes")
end)

test("Compare less than", function()
  local b1 = caml_bytes_of_string("apple")
  local b2 = caml_bytes_of_string("banana")
  assert(caml_bytes_compare(b1, b2) == -1, "apple < banana")
end)

test("Compare greater than", function()
  local b1 = caml_bytes_of_string("zebra")
  local b2 = caml_bytes_of_string("apple")
  assert(caml_bytes_compare(b1, b2) == 1, "zebra > apple")
end)

test("Compare different lengths", function()
  local b1 = caml_bytes_of_string("test")
  local b2 = caml_bytes_of_string("testing")
  assert(caml_bytes_compare(b1, b2) == -1, "Shorter < longer")
end)

-- Test equal
test("Equal bytes", function()
  assert(caml_bytes_equal("test", "test"), "Strings equal")
  assert(not caml_bytes_equal("test", "best"), "Strings not equal")
end)

-- Test concat
test("Concat empty list", function()
  local result = caml_bytes_concat("", {})
  assert(result.length == 0, "Empty concat")
end)

test("Concat with separator", function()
  local parts = {
    caml_bytes_of_string("a"),
    caml_bytes_of_string("b"),
    caml_bytes_of_string("c")
  }
  local result = caml_bytes_concat(caml_bytes_of_string(","), parts)
  assert(caml_string_of_bytes(result) == "a,b,c", "Concat with separator")
end)

test("Concat without separator", function()
  local parts = {
    caml_bytes_of_string("hello"),
    caml_bytes_of_string("world")
  }
  local result = caml_bytes_concat("", parts)
  assert(caml_string_of_bytes(result) == "helloworld", "Concat without separator")
end)

-- Test case conversion
test("Uppercase", function()
  local b = caml_bytes_of_string("Hello World!")
  local upper = caml_bytes_uppercase(b)
  assert(caml_string_of_bytes(upper) == "HELLO WORLD!", "Uppercase conversion")
end)

test("Lowercase", function()
  local b = caml_bytes_of_string("Hello World!")
  local lower = caml_bytes_lowercase(b)
  assert(caml_string_of_bytes(lower) == "hello world!", "Lowercase conversion")
end)

-- Test index (search)
test("Index found", function()
  local haystack = caml_bytes_of_string("hello world")
  local needle = caml_bytes_of_string("world")
  local idx = caml_bytes_index(haystack, needle)
  assert(idx == 6, "Should find 'world' at index 6")
end)

test("Index not found", function()
  local haystack = caml_bytes_of_string("hello world")
  local needle = caml_bytes_of_string("xyz")
  local idx = caml_bytes_index(haystack, needle)
  assert(idx == -1, "Should return -1 when not found")
end)

test("Index empty needle", function()
  local haystack = caml_bytes_of_string("test")
  local needle = caml_bytes_of_string("")
  local idx = caml_bytes_index(haystack, needle)
  assert(idx == 0, "Empty needle should return 0")
end)

-- Test multi-byte get/set
test("Get/set 16-bit", function()
  local b = caml_create_bytes(10)
  caml_bytes_set16(b, 0, 0x1234)
  local val = caml_bytes_get16(b, 0)
  assert(val == 0x1234, "16-bit round-trip")
end)

test("Get/set 32-bit", function()
  local b = caml_create_bytes(10)
  caml_bytes_set32(b, 0, 0x12345678)
  local val = caml_bytes_get32(b, 0)
  assert(val == 0x12345678, "32-bit round-trip")
end)

test("16-bit little-endian", function()
  local b = caml_create_bytes(2)
  b[0] = 0x12
  b[1] = 0x34
  assert(caml_bytes_get16(b, 0) == 0x3412, "Little-endian 16-bit")
end)

test("32-bit little-endian", function()
  local b = caml_create_bytes(4)
  b[0] = 0x12
  b[1] = 0x34
  b[2] = 0x56
  b[3] = 0x78
  assert(caml_bytes_get32(b, 0) == 0x78563412, "Little-endian 32-bit")
end)

-- Print summary
print("\n" .. string.rep("=", 50))
print("Tests passed: " .. tests_passed)
print("Tests failed: " .. tests_failed)
print(string.rep("=", 50))

if tests_failed > 0 then
  os.exit(1)
else
  print("\nAll tests passed!")
  os.exit(0)
end
