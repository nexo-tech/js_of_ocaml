#!/usr/bin/env lua
-- Test suite for Digest module (Task 10.3)
--
-- Tests MD5 hashing with official test vectors from RFC 1321

-- Preload our runtime modules
package.loaded.io = dofile("io.lua")
local io_module = package.loaded.io

local digest = require("digest")

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

print("========================================")
print("Digest Module Test Suite")
print("========================================")
print("")

-- ========================================
-- MD5 Test Vectors from RFC 1321
-- ========================================

print("MD5 RFC 1321 Test Vectors")
print("----------------------------------------")

-- Test 1: Empty string
local md5 = digest.caml_md5_string("", 0, 0)
local hex = digest.digest_to_hex(md5)
test("MD5('')", hex == "d41d8cd98f00b204e9800998ecf8427e",
  string.format("Expected d41d8cd98f00b204e9800998ecf8427e, got %s", hex))

-- Test 2: "a"
md5 = digest.caml_md5_string("a", 0, 1)
hex = digest.digest_to_hex(md5)
test("MD5('a')", hex == "0cc175b9c0f1b6a831c399e269772661",
  string.format("Expected 0cc175b9c0f1b6a831c399e269772661, got %s", hex))

-- Test 3: "abc"
md5 = digest.caml_md5_string("abc", 0, 3)
hex = digest.digest_to_hex(md5)
test("MD5('abc')", hex == "900150983cd24fb0d6963f7d28e17f72",
  string.format("Expected 900150983cd24fb0d6963f7d28e17f72, got %s", hex))

-- Test 4: "message digest"
md5 = digest.caml_md5_string("message digest", 0, 14)
hex = digest.digest_to_hex(md5)
test("MD5('message digest')", hex == "f96b697d7cb7938d525a2f31aaf161d0",
  string.format("Expected f96b697d7cb7938d525a2f31aaf161d0, got %s", hex))

-- Test 5: "abcdefghijklmnopqrstuvwxyz"
md5 = digest.caml_md5_string("abcdefghijklmnopqrstuvwxyz", 0, 26)
hex = digest.digest_to_hex(md5)
test("MD5('abcdefghijklmnopqrstuvwxyz')", hex == "c3fcd3d76192e4007dfb496cca67e13b",
  string.format("Expected c3fcd3d76192e4007dfb496cca67e13b, got %s", hex))

-- Test 6: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
local str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
md5 = digest.caml_md5_string(str, 0, #str)
hex = digest.digest_to_hex(md5)
test("MD5(alphanumeric)", hex == "d174ab98d277d9f5a5611c2c9f419d9f",
  string.format("Expected d174ab98d277d9f5a5611c2c9f419d9f, got %s", hex))

-- Test 7: "12345678901234567890123456789012345678901234567890123456789012345678901234567890"
str = "12345678901234567890123456789012345678901234567890123456789012345678901234567890"
md5 = digest.caml_md5_string(str, 0, #str)
hex = digest.digest_to_hex(md5)
test("MD5(80 digits)", hex == "57edf4a22be3c955ac49da2e2107b67a",
  string.format("Expected 57edf4a22be3c955ac49da2e2107b67a, got %s", hex))

print("")

-- ========================================
-- Substring Hashing
-- ========================================

print("Substring Hashing")
print("----------------------------------------")

-- Test 8: Hash substring
str = "The quick brown fox jumps over the lazy dog"
md5 = digest.caml_md5_string(str, 0, #str)
hex = digest.digest_to_hex(md5)
test("MD5('The quick brown fox...')", hex == "9e107d9d372bb6826bd81d3542a419d6",
  string.format("Expected 9e107d9d372bb6826bd81d3542a419d6, got %s", hex))

-- Test 9: Hash partial substring (first 3 chars of "The quick...")
md5 = digest.caml_md5_string(str, 0, 3)
hex = digest.digest_to_hex(md5)
test("MD5('The' from 'The quick...')", hex == "a4704fd35f0308287f2937ba3eccf5fe",
  string.format("Expected a4704fd35f0308287f2937ba3eccf5fe, got %s", hex))

-- Test 10: Hash middle substring ("quick")
md5 = digest.caml_md5_string(str, 4, 5)
hex = digest.digest_to_hex(md5)
test("MD5('quick' from 'The quick...')", hex == "1df3746a4728276afdc24f828186f73a",
  string.format("Expected 1df3746a4728276afdc24f828186f73a, got %s", hex))

print("")

-- ========================================
-- Channel Hashing
-- ========================================

print("Channel Hashing")
print("----------------------------------------")

-- Test 11: Hash from string channel (entire content)
local test_data = "Hello, World!"
local chan = io_module.caml_ml_open_string_in(test_data)
md5 = digest.caml_md5_chan(chan, -1)
hex = digest.digest_to_hex(md5)
test("MD5 from string channel (-1)", hex == "65a8e27d8879283831b664bd8b7f0ad4",
  string.format("Expected 65a8e27d8879283831b664bd8b7f0ad4, got %s", hex))
io_module.caml_ml_close_channel(chan)

-- Test 12: Hash specific bytes from channel
chan = io_module.caml_ml_open_string_in("Hello, World!")
md5 = digest.caml_md5_chan(chan, 5)
hex = digest.digest_to_hex(md5)
test("MD5 from channel (5 bytes)", hex == "8b1a9953c4611296a827abf8c47804d7",
  string.format("Expected 8b1a9953c4611296a827abf8c47804d7, got %s", hex))
io_module.caml_ml_close_channel(chan)

-- Test 13: Hash from file
local temp_file = "/tmp/md5_test_" .. os.time() .. ".txt"
local f = io.open(temp_file, "w")
f:write("The quick brown fox jumps over the lazy dog")
f:close()

-- Helper: create OCaml list
local function make_list(tbl)
  local list = 0
  for i = #tbl, 1, -1 do
    list = {tag = 0, [1] = tbl[i], [2] = list}
  end
  return list
end

local flags = make_list({0, 6})  -- RDONLY, BINARY
local fd = io_module.caml_sys_open(temp_file, flags, 0)
local file_chan = io_module.caml_ml_open_descriptor_in(fd)

md5 = digest.caml_md5_chan(file_chan, -1)
hex = digest.digest_to_hex(md5)
test("MD5 from file channel", hex == "9e107d9d372bb6826bd81d3542a419d6",
  string.format("Expected 9e107d9d372bb6826bd81d3542a419d6, got %s", hex))

io_module.caml_ml_close_channel(file_chan)
os.remove(temp_file)

print("")

-- ========================================
-- Large Data
-- ========================================

print("Large Data Hashing")
print("----------------------------------------")

-- Test 15: Hash large string (> 64 bytes, multiple MD5 blocks)
local large_str = string.rep("a", 1000)
md5 = digest.caml_md5_string(large_str, 0, #large_str)
hex = digest.digest_to_hex(md5)
test("MD5(1000 'a's)", hex == "cabe45dcc9ae5b66ba86600cca6b8ba8",
  string.format("Expected cabe45dcc9ae5b66ba86600cca6b8ba8, got %s", hex))

-- Test 16: Hash very large string (10KB)
large_str = string.rep("The quick brown fox jumps over the lazy dog. ", 200)
md5 = digest.caml_md5_string(large_str, 0, #large_str)
hex = digest.digest_to_hex(md5)
-- Just verify it completes without error and produces 32 hex chars
test("MD5(10KB data) length", #hex == 32,
  string.format("Expected 32 hex chars, got %d", #hex))

-- Test 17: Hash large data from channel
chan = io_module.caml_ml_open_string_in(string.rep("test", 5000))
md5 = digest.caml_md5_chan(chan, -1)
hex = digest.digest_to_hex(md5)
test("MD5(20KB from channel) length", #hex == 32,
  string.format("Expected 32 hex chars, got %d", #hex))
io_module.caml_ml_close_channel(chan)

print("")

-- ========================================
-- Edge Cases
-- ========================================

print("Edge Cases")
print("----------------------------------------")

-- Test 18: 55 bytes (just before padding boundary)
str = string.rep("a", 55)
md5 = digest.caml_md5_string(str, 0, #str)
hex = digest.digest_to_hex(md5)
test("MD5(55 bytes)", #hex == 32,
  string.format("Expected 32 hex chars, got %d", #hex))

-- Test 19: 56 bytes (at padding boundary)
str = string.rep("b", 56)
md5 = digest.caml_md5_string(str, 0, #str)
hex = digest.digest_to_hex(md5)
test("MD5(56 bytes)", #hex == 32,
  string.format("Expected 32 hex chars, got %d", #hex))

-- Test 20: 64 bytes (exactly one MD5 block)
str = string.rep("c", 64)
md5 = digest.caml_md5_string(str, 0, #str)
hex = digest.digest_to_hex(md5)
test("MD5(64 bytes)", hex == "bcd5708ed79b18f0f0aaa27fd0056d86",
  string.format("Expected bcd5708ed79b18f0f0aaa27fd0056d86, got %s", hex))

-- Test 21: 65 bytes (one byte over MD5 block)
str = string.rep("d", 65)
md5 = digest.caml_md5_string(str, 0, #str)
hex = digest.digest_to_hex(md5)
test("MD5(65 bytes)", #hex == 32,
  string.format("Expected 32 hex chars, got %d", #hex))

-- Test 22: 128 bytes (exactly two MD5 blocks)
str = string.rep("e", 128)
md5 = digest.caml_md5_string(str, 0, #str)
hex = digest.digest_to_hex(md5)
test("MD5(128 bytes)", #hex == 32,
  string.format("Expected 32 hex chars, got %d", #hex))

-- Test 23: Binary data (non-ASCII)
str = string.char(0, 1, 2, 3, 4, 5, 255, 254, 253)
md5 = digest.caml_md5_string(str, 0, #str)
hex = digest.digest_to_hex(md5)
test("MD5(binary data)", #hex == 32,
  string.format("Expected 32 hex chars, got %d", #hex))

-- Test 24: Channel EOF on exact byte count
chan = io_module.caml_ml_open_string_in("12345")
local ok, err = pcall(digest.caml_md5_chan, chan, 10)
test("MD5 chan EOF error", not ok and string.find(err, "End_of_file"),
  "Should raise End_of_file when requesting more bytes than available")
io_module.caml_ml_close_channel(chan)

print("")

-- ========================================
-- Incremental Hashing
-- ========================================

print("Incremental Hashing")
print("----------------------------------------")

-- Test 26: Incremental API
local ctx = digest.md5_init()
digest.md5_update(ctx, "Hello, ")
digest.md5_update(ctx, "World!")
md5 = digest.md5_final(ctx)
hex = digest.digest_to_hex(md5)
test("Incremental MD5('Hello, ' + 'World!')", hex == "65a8e27d8879283831b664bd8b7f0ad4",
  string.format("Expected 65a8e27d8879283831b664bd8b7f0ad4, got %s", hex))

-- Test 27: Incremental with many small updates
ctx = digest.md5_init()
for i = 1, 100 do
  digest.md5_update(ctx, "a")
end
md5 = digest.md5_final(ctx)
hex = digest.digest_to_hex(md5)
test("Incremental MD5(100 updates of 'a')", hex == "36a92cc94a9e0fa21f625f8bfb007adf",
  string.format("Expected 36a92cc94a9e0fa21f625f8bfb007adf, got %s", hex))

-- Test 28: Incremental with varying sizes
ctx = digest.md5_init()
digest.md5_update(ctx, "The ")
digest.md5_update(ctx, "quick brown fox ")
digest.md5_update(ctx, "jumps over the lazy dog")
md5 = digest.md5_final(ctx)
hex = digest.digest_to_hex(md5)
test("Incremental MD5(varying sizes)", hex == "9e107d9d372bb6826bd81d3542a419d6",
  string.format("Expected 9e107d9d372bb6826bd81d3542a419d6, got %s", hex))

print("")

-- ========================================
-- Summary
-- ========================================

print("========================================")
print(string.format("Tests completed: %d/%d passed", pass_count, test_count))
print("========================================")

if pass_count == test_count then
  print("✓ All tests passed!")
  os.exit(0)
else
  print(string.format("✗ %d tests failed", test_count - pass_count))
  os.exit(1)
end
