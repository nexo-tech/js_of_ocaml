#!/usr/bin/env lua
-- Test suite for Digest (MD5) module (Task 6.4)
-- Works on Lua 5.1+

dofile("digest.lua")

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
  io.write("Test: " .. name .. " ... ")
  local success, err = pcall(fn)
  if success then
    tests_passed = tests_passed + 1
    print("✓")
  else
    tests_failed = tests_failed + 1
    print("✗")
    print("  Error: " .. tostring(err))
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(msg or ("Expected " .. tostring(expected) .. ", got " .. tostring(actual)))
  end
end

print("====================================================================")
print("Digest (MD5) Tests (Task 6.4)")
print("====================================================================")
print()

print("MD5 Known Test Vectors:")
print("--------------------------------------------------------------------")

test("MD5: empty string", function()
  local digest = caml_md5_string("", 0, 0)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "d41d8cd98f00b204e9800998ecf8427e", "MD5 of empty string")
end)

test("MD5: 'a'", function()
  local digest = caml_md5_string("a", 0, 1)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "0cc175b9c0f1b6a831c399e269772661", "MD5 of 'a'")
end)

test("MD5: 'abc'", function()
  local digest = caml_md5_string("abc", 0, 3)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "900150983cd24fb0d6963f7d28e17f72", "MD5 of 'abc'")
end)

test("MD5: 'message digest'", function()
  local str = "message digest"
  local digest = caml_md5_string(str, 0, string.len(str))
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "f96b697d7cb7938d525a2f31aaf161d0", "MD5 of 'message digest'")
end)

test("MD5: 'abcdefghijklmnopqrstuvwxyz'", function()
  local str = "abcdefghijklmnopqrstuvwxyz"
  local digest = caml_md5_string(str, 0, string.len(str))
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "c3fcd3d76192e4007dfb496cca67e13b", "MD5 of alphabet")
end)

test("MD5: alphanumeric", function()
  local str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  local digest = caml_md5_string(str, 0, string.len(str))
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "d174ab98d277d9f5a5611c2c9f419d9f", "MD5 of alphanumeric")
end)

test("MD5: 80 repeated digits", function()
  local str = "12345678901234567890123456789012345678901234567890123456789012345678901234567890"
  local digest = caml_md5_string(str, 0, string.len(str))
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "57edf4a22be3c955ac49da2e2107b67a", "MD5 of repeated digits")
end)

print()
print("MD5 Substring Tests:")
print("--------------------------------------------------------------------")

test("substring: first 3 of 'abcdef'", function()
  local digest = caml_md5_string("abcdef", 0, 3)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "900150983cd24fb0d6963f7d28e17f72", "Should hash 'abc'")
end)

test("substring: last 3 of 'abcdef'", function()
  local digest = caml_md5_string("abcdef", 3, 3)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "4ed9407630eb1000c0f6b63842defa7d", "Should hash 'def'")
end)

test("substring: middle 1 of 'abc'", function()
  local digest = caml_md5_string("abc", 1, 1)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "92eb5ffee6ae2fec3ad71c777531578f", "Should hash 'b'")
end)

print()
print("MD5 Multi-Block Tests:")
print("--------------------------------------------------------------------")

test("64 bytes (one block)", function()
  local str = string.rep("a", 64)
  local digest = caml_md5_string(str, 0, 64)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "014842d480b571495a4a0363793f7367", "MD5 of 64 'a's")
end)

test("128 bytes (two blocks)", function()
  local str = string.rep("a", 128)
  local digest = caml_md5_string(str, 0, 128)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "e510683b3f5ffe4093d021808bc6ff70", "MD5 of 128 'a's")
end)

test("100 bytes (partial second block)", function()
  local str = string.rep("b", 100)
  local digest = caml_md5_string(str, 0, 100)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "d84a935724eac27d7c9676679b6cdbaf", "MD5 of 100 'b's")
end)

test("1000 bytes", function()
  local str = string.rep("x", 1000)
  local digest = caml_md5_string(str, 0, 1000)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "398533d48111e9f664b1f64cb10c4b63", "MD5 of 1000 'x's")
end)

print()
print("MD5 Context Tests:")
print("--------------------------------------------------------------------")

test("context: single update", function()
  local ctx = caml_md5_init()
  caml_md5_update(ctx, "abc")
  local digest = caml_md5_final(ctx)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "900150983cd24fb0d6963f7d28e17f72", "MD5 of 'abc' via context")
end)

test("context: multiple updates", function()
  local ctx = caml_md5_init()
  caml_md5_update(ctx, "a")
  caml_md5_update(ctx, "b")
  caml_md5_update(ctx, "c")
  local digest = caml_md5_final(ctx)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "900150983cd24fb0d6963f7d28e17f72", "MD5 via multiple updates")
end)

test("context: updates spanning blocks", function()
  local ctx = caml_md5_init()
  caml_md5_update(ctx, string.rep("a", 50))
  caml_md5_update(ctx, string.rep("a", 50))
  caml_md5_update(ctx, string.rep("a", 28))
  local digest = caml_md5_final(ctx)
  local hex = caml_digest_to_hex(digest)
  -- Should equal MD5 of 128 'a's
  assert_eq(hex, "e510683b3f5ffe4093d021808bc6ff70", "MD5 with block-spanning updates")
end)

test("context: empty updates", function()
  local ctx = caml_md5_init()
  caml_md5_update(ctx, "")
  caml_md5_update(ctx, "abc")
  caml_md5_update(ctx, "")
  local digest = caml_md5_final(ctx)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "900150983cd24fb0d6963f7d28e17f72", "MD5 with empty updates")
end)

print()
print("Bitwise Operations Tests:")
print("--------------------------------------------------------------------")

test("bit_and: 0xFF & 0x0F", function()
  local result = caml_digest_bit_and(0xFF, 0x0F)
  assert_eq(result, 0x0F)
end)

test("bit_or: 0xF0 | 0x0F", function()
  local result = caml_digest_bit_or(0xF0, 0x0F)
  assert_eq(result, 0xFF)
end)

test("bit_xor: 0xFF ^ 0xAA", function()
  local result = caml_digest_bit_xor(0xFF, 0xAA)
  assert_eq(result, 0x55)
end)

test("bit_not: ~0xFFFFFFFF", function()
  local result = caml_digest_bit_not(0xFFFFFFFF)
  assert_eq(result, 0)
end)

test("bit_not: ~0", function()
  local result = caml_digest_bit_not(0)
  assert_eq(result, 0xFFFFFFFF)
end)

test("bit_lshift: 1 << 8", function()
  local result = caml_digest_bit_lshift(1, 8)
  assert_eq(result, 256)
end)

test("bit_rshift: 256 >> 4", function()
  local result = caml_digest_bit_rshift(256, 4)
  assert_eq(result, 16)
end)

test("add32: overflow", function()
  local result = caml_digest_add32(0xFFFFFFFF, 1)
  assert_eq(result, 0)
end)

test("rotl32: rotate left", function()
  local result = caml_digest_rotl32(0x12345678, 4)
  assert_eq(result, 0x23456781)
end)

print()
print("Hex Conversion Tests:")
print("--------------------------------------------------------------------")

test("hex: all zeros", function()
  local digest = string.char(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "00000000000000000000000000000000")
end)

test("hex: all 0xFF", function()
  local digest = string.rep(string.char(0xFF), 16)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "ffffffffffffffffffffffffffffffff")
end)

test("hex: mixed bytes", function()
  local digest = string.char(0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF,
                              0xFE, 0xDC, 0xBA, 0x98, 0x76, 0x54, 0x32, 0x10)
  local hex = caml_digest_to_hex(digest)
  assert_eq(hex, "0123456789abcdeffedcba9876543210")
end)

print()
print("====================================================================")
print("Tests passed: " .. tests_passed .. " / " .. (tests_passed + tests_failed))
if tests_failed == 0 then
  print("All tests passed! ✓")
  print("====================================================================")
  os.exit(0)
else
  print("Some tests failed.")
  print("====================================================================")
  os.exit(1)
end
