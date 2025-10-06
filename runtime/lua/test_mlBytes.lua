#!/usr/bin/env lua
-- Test suite for mlBytes.lua string and bytes operations module

local mlBytes = require("mlBytes")

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
  local b = mlBytes.create(0)
  assert(b.length == 0, "Empty bytes should have length 0")
end)

test("Create bytes with fill", function()
  local b = mlBytes.create(5, 42)
  assert(b.length == 5, "Bytes should have length 5")
  for i = 0, 4 do
    assert(b[i] == 42, "All bytes should be 42")
  end
end)

test("Bytes of string", function()
  local b = mlBytes.bytes_of_string("hello")
  assert(b.length == 5, "Should have length 5")
  assert(b[0] == string.byte('h'), "First byte should be 'h'")
  assert(b[4] == string.byte('o'), "Last byte should be 'o'")
end)

test("String of bytes", function()
  local b = mlBytes.create(5)
  b[0] = string.byte('h')
  b[1] = string.byte('e')
  b[2] = string.byte('l')
  b[3] = string.byte('l')
  b[4] = string.byte('o')
  local s = mlBytes.string_of_bytes(b)
  assert(s == "hello", "Should convert to 'hello'")
end)

test("Round-trip conversion", function()
  local orig = "test string 123"
  local b = mlBytes.bytes_of_string(orig)
  local result = mlBytes.string_of_bytes(b)
  assert(orig == result, "Round-trip should preserve string")
end)

-- Test get/set operations
test("Unsafe get from bytes", function()
  local b = mlBytes.bytes_of_string("abc")
  assert(mlBytes.unsafe_get(b, 0) == string.byte('a'), "Get first byte")
  assert(mlBytes.unsafe_get(b, 1) == string.byte('b'), "Get second byte")
  assert(mlBytes.unsafe_get(b, 2) == string.byte('c'), "Get third byte")
end)

test("Unsafe get from string", function()
  local s = "xyz"
  assert(mlBytes.unsafe_get(s, 0) == string.byte('x'), "Get from string")
  assert(mlBytes.unsafe_get(s, 1) == string.byte('y'), "Get from string")
end)

test("Unsafe set", function()
  local b = mlBytes.create(3)
  mlBytes.unsafe_set(b, 0, string.byte('A'))
  mlBytes.unsafe_set(b, 1, string.byte('B'))
  mlBytes.unsafe_set(b, 2, string.byte('C'))
  assert(mlBytes.string_of_bytes(b) == "ABC", "Set should work")
end)

test("Safe get with bounds check", function()
  local b = mlBytes.bytes_of_string("test")
  assert(mlBytes.get(b, 0) == string.byte('t'), "Get within bounds")
  local success = pcall(function() mlBytes.get(b, 10) end)
  assert(not success, "Should fail for out of bounds")
end)

test("Safe set with bounds check", function()
  local b = mlBytes.create(3)
  mlBytes.set(b, 0, 65)
  assert(b[0] == 65, "Set should work")
  local success = pcall(function() mlBytes.set(b, 10, 65) end)
  assert(not success, "Should fail for out of bounds")
end)

test("Set with byte masking", function()
  local b = mlBytes.create(1)
  mlBytes.unsafe_set(b, 0, 0x1FF)  -- 511, should be masked to 255
  assert(b[0] == 0xFF, "Should mask to 8 bits")
end)

-- Test length
test("Length of bytes", function()
  local b = mlBytes.create(10)
  assert(mlBytes.length(b) == 10, "Bytes length")
end)

test("Length of string", function()
  assert(mlBytes.length("hello") == 5, "String length")
  assert(mlBytes.length("") == 0, "Empty string length")
end)

-- Test blit (copy)
test("Blit bytes to bytes", function()
  local src = mlBytes.bytes_of_string("hello")
  local dst = mlBytes.create(10, 0)
  mlBytes.blit(src, 0, dst, 0, 5)
  assert(mlBytes.string_of_bytes(dst):sub(1, 5) == "hello", "Should copy hello")
end)

test("Blit with offset", function()
  local src = mlBytes.bytes_of_string("world")
  local dst = mlBytes.create(10, string.byte('_'))
  mlBytes.blit(src, 1, dst, 2, 3)  -- Copy "orl" to position 2
  local result = mlBytes.string_of_bytes(dst)
  assert(result:sub(3, 5) == "orl", "Should copy with offsets")
end)

test("Blit from string", function()
  local dst = mlBytes.create(5)
  mlBytes.blit("test", 0, dst, 1, 3)
  assert(dst[1] == string.byte('t'), "Should blit from string")
  assert(dst[2] == string.byte('e'), "Should blit from string")
  assert(dst[3] == string.byte('s'), "Should blit from string")
end)

-- Test fill
test("Fill bytes", function()
  local b = mlBytes.create(10)
  mlBytes.fill(b, 0, 10, 65)
  for i = 0, 9 do
    assert(b[i] == 65, "All bytes should be 65 (A)")
  end
end)

test("Fill partial", function()
  local b = mlBytes.create(10, 0)
  mlBytes.fill(b, 2, 5, 88)  -- Fill positions 2-6 with 'X'
  assert(b[1] == 0, "Before range should be 0")
  assert(b[2] == 88, "In range should be 88")
  assert(b[6] == 88, "In range should be 88")
  assert(b[7] == 0, "After range should be 0")
end)

-- Test sub
test("Sub bytes", function()
  local b = mlBytes.bytes_of_string("hello world")
  local sub = mlBytes.sub(b, 6, 5)  -- Extract "world"
  assert(mlBytes.string_of_bytes(sub) == "world", "Sub should extract substring")
end)

-- Test compare
test("Compare equal bytes", function()
  local b1 = mlBytes.bytes_of_string("test")
  local b2 = mlBytes.bytes_of_string("test")
  assert(mlBytes.compare(b1, b2) == 0, "Equal bytes")
end)

test("Compare less than", function()
  local b1 = mlBytes.bytes_of_string("apple")
  local b2 = mlBytes.bytes_of_string("banana")
  assert(mlBytes.compare(b1, b2) == -1, "apple < banana")
end)

test("Compare greater than", function()
  local b1 = mlBytes.bytes_of_string("zebra")
  local b2 = mlBytes.bytes_of_string("apple")
  assert(mlBytes.compare(b1, b2) == 1, "zebra > apple")
end)

test("Compare different lengths", function()
  local b1 = mlBytes.bytes_of_string("test")
  local b2 = mlBytes.bytes_of_string("testing")
  assert(mlBytes.compare(b1, b2) == -1, "Shorter < longer")
end)

-- Test equal
test("Equal bytes", function()
  assert(mlBytes.equal("test", "test"), "Strings equal")
  assert(not mlBytes.equal("test", "best"), "Strings not equal")
end)

-- Test concat
test("Concat empty list", function()
  local result = mlBytes.concat("", {})
  assert(result.length == 0, "Empty concat")
end)

test("Concat with separator", function()
  local parts = {
    mlBytes.bytes_of_string("a"),
    mlBytes.bytes_of_string("b"),
    mlBytes.bytes_of_string("c")
  }
  local result = mlBytes.concat(mlBytes.bytes_of_string(","), parts)
  assert(mlBytes.string_of_bytes(result) == "a,b,c", "Concat with separator")
end)

test("Concat without separator", function()
  local parts = {
    mlBytes.bytes_of_string("hello"),
    mlBytes.bytes_of_string("world")
  }
  local result = mlBytes.concat("", parts)
  assert(mlBytes.string_of_bytes(result) == "helloworld", "Concat without separator")
end)

-- Test case conversion
test("Uppercase", function()
  local b = mlBytes.bytes_of_string("Hello World!")
  local upper = mlBytes.uppercase(b)
  assert(mlBytes.string_of_bytes(upper) == "HELLO WORLD!", "Uppercase conversion")
end)

test("Lowercase", function()
  local b = mlBytes.bytes_of_string("Hello World!")
  local lower = mlBytes.lowercase(b)
  assert(mlBytes.string_of_bytes(lower) == "hello world!", "Lowercase conversion")
end)

-- Test index (search)
test("Index found", function()
  local haystack = mlBytes.bytes_of_string("hello world")
  local needle = mlBytes.bytes_of_string("world")
  local idx = mlBytes.index(haystack, needle)
  assert(idx == 6, "Should find 'world' at index 6")
end)

test("Index not found", function()
  local haystack = mlBytes.bytes_of_string("hello world")
  local needle = mlBytes.bytes_of_string("xyz")
  local idx = mlBytes.index(haystack, needle)
  assert(idx == -1, "Should return -1 when not found")
end)

test("Index empty needle", function()
  local haystack = mlBytes.bytes_of_string("test")
  local needle = mlBytes.bytes_of_string("")
  local idx = mlBytes.index(haystack, needle)
  assert(idx == 0, "Empty needle should return 0")
end)

-- Test multi-byte get/set
test("Get/set 16-bit", function()
  local b = mlBytes.create(10)
  mlBytes.set16(b, 0, 0x1234)
  local val = mlBytes.get16(b, 0)
  assert(val == 0x1234, "16-bit round-trip")
end)

test("Get/set 32-bit", function()
  local b = mlBytes.create(10)
  mlBytes.set32(b, 0, 0x12345678)
  local val = mlBytes.get32(b, 0)
  assert(val == 0x12345678, "32-bit round-trip")
end)

test("16-bit little-endian", function()
  local b = mlBytes.create(2)
  b[0] = 0x12
  b[1] = 0x34
  assert(mlBytes.get16(b, 0) == 0x3412, "Little-endian 16-bit")
end)

test("32-bit little-endian", function()
  local b = mlBytes.create(4)
  b[0] = 0x12
  b[1] = 0x34
  b[2] = 0x56
  b[3] = 0x78
  assert(mlBytes.get32(b, 0) == 0x78563412, "Little-endian 32-bit")
end)

-- Test primitive registration
test("Primitives are registered", function()
  local core = require("core")
  assert(core.get_primitive("caml_create_bytes") == mlBytes.create, "create registered")
  assert(core.get_primitive("caml_bytes_of_string") == mlBytes.bytes_of_string, "bytes_of_string registered")
  assert(core.get_primitive("caml_string_of_bytes") == mlBytes.string_of_bytes, "string_of_bytes registered")
end)

-- Test module registration
test("Module is registered", function()
  local core = require("core")
  local mod = core.get_module("mlBytes")
  assert(mod == mlBytes, "mlBytes module should be registered")
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
