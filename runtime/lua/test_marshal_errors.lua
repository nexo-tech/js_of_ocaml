#!/usr/bin/env lua
-- Test suite for Marshal error handling (Task 6.3)
--
-- Tests input validation, truncated data, corrupted data, and error messages

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

print("========================================")
print("Marshal Error Handling Test Suite")
print("========================================")
print("")

-- ========================================
-- Input Validation
-- ========================================

print("Input Validation")
print("----------------------------------------")

-- Test 1: to_string with nil value
local ok, err = pcall(caml_marshal_to_string, nil, {tag = 0})
test("to_string rejects nil value", not ok and string.find(err, "cannot marshal nil"),
  "Should reject nil value")

-- Test 2: to_string with invalid flags type
ok, err = pcall(caml_marshal_to_string, 42, "invalid")
test("to_string rejects invalid flags", not ok and string.find(err, "flags must be"),
  "Should reject invalid flags type")

-- Test 3: from_bytes with non-string input
ok, err = pcall(caml_marshal_from_bytes, 12345, 0)
test("from_bytes rejects non-string", not ok and string.find(err, "expected string"),
  "Should reject non-string input")

-- Test 4: from_bytes with invalid offset
ok, err = pcall(caml_marshal_from_bytes, "test", -1)
test("from_bytes rejects negative offset", not ok and string.find(err, "non%-negative"),
  "Should reject negative offset")

-- Test 5: from_bytes with non-number offset
ok, err = pcall(caml_marshal_from_bytes, "test", "invalid")
test("from_bytes rejects non-number offset", not ok and string.find(err, "non%-negative"),
  "Should reject non-number offset")

print("")

-- ========================================
-- Truncated Data
-- ========================================

print("Truncated Data Handling")
print("----------------------------------------")

-- Test 6: Empty string
ok, err = pcall(caml_marshal_from_bytes, "", 0)
test("from_bytes rejects empty string", not ok and string.find(err, "too short"),
  "Should detect truncated header")

-- Test 7: Partial header (10 bytes)
ok, err = pcall(caml_marshal_from_bytes, string.rep("\0", 10), 0)
test("from_bytes rejects partial header", not ok and string.find(err, "too short"),
  "Should detect incomplete header")

-- Test 8: Valid header but truncated data
-- Use a larger value to ensure truncation
local valid_string = caml_marshal_to_string("Hello, World!", {tag = 0})
local truncated = string.sub(valid_string, 1, 25)  -- Cut off some of the string data
ok, err = pcall(caml_marshal_from_bytes, truncated, 0)
test("from_bytes detects truncated data", not ok and string.find(err, "truncated"),
  "Should detect data truncation")

-- Test 9: Header claims more data than available
local header_plus_one = string.sub(valid_string, 1, 24)  -- One byte less than needed
ok, err = pcall(caml_marshal_from_bytes, header_plus_one, 0)
test("from_bytes detects insufficient data", not ok and (string.find(err, "truncated") or string.find(err, "corrupted")),
  "Should detect insufficient data")

print("")

-- ========================================
-- Corrupted Data
-- ========================================

print("Corrupted Data Handling")
print("----------------------------------------")

-- Test 10: Invalid magic number
local corrupted_magic = string.char(0xFF, 0xFF, 0xFF, 0xFF) .. string.rep("\0", 20)
ok, err = pcall(caml_marshal_from_bytes, corrupted_magic, 0)
test("from_bytes rejects invalid magic", not ok and string.find(err, "invalid header"),
  "Should reject invalid magic number")

-- Test 11: Unknown value code
-- Create valid header manually, then add unknown code
local header = string.char(
  0x84, 0x95, 0xA6, 0xBE,  -- magic
  0x00, 0x00, 0x00, 0x01,  -- data_len = 1
  0x00, 0x00, 0x00, 0x00,  -- num_objects = 0
  0x00, 0x00, 0x00, 0x00,  -- size_32 = 0
  0x00, 0x00, 0x00, 0x00   -- size_64 = 0
)
local invalid_code = header .. string.char(0x1A)  -- 0x1A is not a valid code
ok, err = pcall(caml_marshal_from_bytes, invalid_code, 0)
test("from_bytes rejects unknown code", not ok and string.find(err, "unsupported code"),
  "Should reject unknown value code")

-- Test 12: Invalid shared reference (out of bounds)
local marshalled = caml_marshal_to_string(42, {tag = 0})
-- Manually craft a SHARED8 reference to invalid offset
header = string.char(
  0x84, 0x95, 0xA6, 0xBE,  -- magic
  0x00, 0x00, 0x00, 0x02,  -- data_len = 2
  0x00, 0x00, 0x00, 0x05,  -- num_objects = 5 (but we'll only have 0)
  0x00, 0x00, 0x00, 0x00,  -- size_32 = 0
  0x00, 0x00, 0x00, 0x00   -- size_64 = 0
)
local bad_shared = header .. string.char(0x04, 0x0A)  -- SHARED8 with offset 10 (> 5)
ok, err = pcall(caml_marshal_from_bytes, bad_shared, 0)
test("from_bytes detects invalid shared ref", not ok,
  "Should detect out-of-bounds shared reference")

print("")

-- ========================================
-- Unsupported Features
-- ========================================

print("Unsupported Features")
print("----------------------------------------")

-- Test 13: Closures flag
ok, err = pcall(caml_marshal_to_string, 42, {tag = 0, [1] = 1})  -- Closures flag
test("to_string rejects Closures flag", not ok and string.find(err, "Closures.*not supported"),
  "Should reject Closures flag")

-- Test 14: Code pointer (should be rejected by unmarshal)
header = string.char(
  0x84, 0x95, 0xA6, 0xBE,  -- magic
  0x00, 0x00, 0x00, 0x01,  -- data_len = 1
  0x00, 0x00, 0x00, 0x00,  -- num_objects = 0
  0x00, 0x00, 0x00, 0x00,  -- size_32 = 0
  0x00, 0x00, 0x00, 0x00   -- size_64 = 0
)
local code_pointer = header .. string.char(0x10)  -- CODE_CODEPOINTER
ok, err = pcall(caml_marshal_from_bytes, code_pointer, 0)
test("from_bytes rejects code pointer", not ok and string.find(err, "code pointer"),
  "Should reject code pointer")

-- Test 15: 64-bit block (should be rejected)
local block64 = header .. string.char(0x13)  -- CODE_BLOCK64
ok, err = pcall(caml_marshal_from_bytes, block64, 0)
test("from_bytes rejects 64-bit blocks", not ok and string.find(err, "64%-bit"),
  "Should reject 64-bit blocks")

print("")

-- ========================================
-- Edge Cases
-- ========================================

print("Edge Cases")
print("----------------------------------------")

-- Test 16: Very large offset
local marshalled_42 = caml_marshal_to_string(42, {tag = 0})
ok, err = pcall(caml_marshal_from_bytes, marshalled_42, 1000000)
test("from_bytes handles large offset", not ok and string.find(err, "too short"),
  "Should handle offset beyond string length")

-- Test 17: Offset at end of string
ok, err = pcall(caml_marshal_from_bytes, marshalled_42, #marshalled_42)
test("from_bytes handles offset at end", not ok and string.find(err, "too short"),
  "Should handle offset at string end")

-- Test 18: Multiple errors (truncated + corrupted)
local multi_error = string.char(0xFF, 0xFF, 0xFF)  -- Only 3 bytes, corrupted magic
ok, err = pcall(caml_marshal_from_bytes, multi_error, 0)
test("from_bytes reports first error", not ok,
  "Should report truncation before checking magic")

print("")

-- ========================================
-- Error Message Quality
-- ========================================

print("Error Message Quality")
print("----------------------------------------")

-- Test 19: Truncation error has byte counts
ok, err = pcall(caml_marshal_from_bytes, truncated, 0)
test("Truncation error includes byte count", not ok and string.find(err, "%d+ bytes"),
  "Error message should include byte counts")

-- Test 20: Unknown code error shows hex value
ok, err = pcall(caml_marshal_from_bytes, invalid_code, 0)
test("Unknown code error shows hex", not ok and string.find(err, "0x"),
  "Error message should show hex code")

-- Test 21: Type error shows actual type
ok, err = pcall(caml_marshal_to_string, 42, "string")
test("Type error shows actual type", not ok and string.find(err, "string"),
  "Error message should show actual type received")

print("")

-- ========================================
-- Recovery and Partial Data
-- ========================================

print("Recovery and Partial Data")
print("----------------------------------------")

-- Test 22: Valid data after error position
-- If we have: [valid_marshal_1][valid_marshal_2]
-- And we try to read at offset of marshal_2, it should work
local m1 = caml_marshal_to_string(10, {tag = 0})
local m2 = caml_marshal_to_string(20, {tag = 0})
local combined = m1 .. m2

local val1 = caml_marshal_from_bytes(combined, 0)
test("Can read first value from combined", val1 == 10)

local val2 = caml_marshal_from_bytes(combined, #m1)
test("Can read second value at offset", val2 == 20)

-- Test 24: Graceful degradation - simple values still work after error
ok, err = pcall(caml_marshal_from_bytes, invalid_code, 0)
test("Error doesn't corrupt state", not ok)

-- This should still work fine
local simple = caml_marshal_to_string(999, {tag = 0})
local result = caml_marshal_from_bytes(simple, 0)
test("Simple marshal works after error", result == 999)

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
