#!/usr/bin/env lua
-- Test suite for filename.lua
-- Comprehensive tests for path manipulation

dofile("sys.lua")
dofile("filename.lua")

local test_count = 0
local pass_count = 0
local fail_count = 0

-- Detect OS type for platform-specific tests
local os_type
if package.config:sub(1, 1) == '\\' then
  os_type = "Win32"
else
  os_type = "Unix"
end

local function test(name, fn)
  test_count = test_count + 1
  io.write(string.format("Test %d: %s ... ", test_count, name))
  io.flush()

  local ok, err = pcall(fn)
  if ok then
    pass_count = pass_count + 1
    print("PASS")
  else
    fail_count = fail_count + 1
    print("FAIL")
    print("  Error: " .. tostring(err))
  end
end

local function assert_equal(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %q, got %q",
      msg or "assertion failed",
      tostring(expected),
      tostring(actual)))
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "expected true")
  end
end

local function assert_error(fn, msg)
  local ok = pcall(fn)
  if ok then
    error(msg or "expected error but function succeeded")
  end
end

print("=== Filename Module Tests ===")
print("OS Type: " .. os_type .. "\n")

-- Test 1-5: concat
test("concat with simple paths", function()
  local result = caml_filename_concat("dir", "file.txt")
  if os_type == "Win32" then
    assert_equal(result, "dir\\file.txt", "should use backslash on Windows")
  else
    assert_equal(result, "dir/file.txt", "should use forward slash on Unix")
  end
end)

test("concat with empty directory", function()
  local result = caml_filename_concat("", "file.txt")
  assert_equal(result, "file.txt", "should return file when dir is empty")
end)

test("concat with empty file", function()
  local result = caml_filename_concat("dir", "")
  assert_equal(result, "dir", "should return dir when file is empty")
end)

test("concat with absolute path (Unix)", function()
  if os_type == "Unix" then
    local result = caml_filename_concat("dir", "/absolute/path")
    assert_equal(result, "/absolute/path", "should return absolute path unchanged")
  end
end)

test("concat with trailing separator", function()
  if os_type == "Win32" then
    local result = caml_filename_concat("dir\\", "file.txt")
    assert_equal(result, "dir\\file.txt", "should not duplicate separator")
  else
    local result = caml_filename_concat("dir/", "file.txt")
    assert_equal(result, "dir/file.txt", "should not duplicate separator")
  end
end)

-- Test 6-10: basename
test("basename of simple path", function()
  if os_type == "Win32" then
    assert_equal(caml_filename_basename("dir\\file.txt"), "file.txt")
  else
    assert_equal(caml_filename_basename("dir/file.txt"), "file.txt")
  end
end)

test("basename of nested path", function()
  if os_type == "Win32" then
    assert_equal(caml_filename_basename("a\\b\\c\\file.txt"), "file.txt")
  else
    assert_equal(caml_filename_basename("a/b/c/file.txt"), "file.txt")
  end
end)

test("basename of file without directory", function()
  assert_equal(caml_filename_basename("file.txt"), "file.txt")
end)

test("basename with trailing separator", function()
  if os_type == "Win32" then
    assert_equal(caml_filename_basename("dir\\subdir\\"), "subdir")
  else
    assert_equal(caml_filename_basename("dir/subdir/"), "subdir")
  end
end)

test("basename of root", function()
  if os_type == "Unix" then
    assert_equal(caml_filename_basename("/"), "/")
  end
end)

-- Test 11-15: dirname
test("dirname of simple path", function()
  if os_type == "Win32" then
    assert_equal(caml_filename_dirname("dir\\file.txt"), "dir")
  else
    assert_equal(caml_filename_dirname("dir/file.txt"), "dir")
  end
end)

test("dirname of nested path", function()
  if os_type == "Win32" then
    assert_equal(caml_filename_dirname("a\\b\\c\\file.txt"), "a\\b\\c")
  else
    assert_equal(caml_filename_dirname("a/b/c/file.txt"), "a/b/c")
  end
end)

test("dirname of file without directory", function()
  assert_equal(caml_filename_dirname("file.txt"), ".")
end)

test("dirname of root file", function()
  if os_type == "Unix" then
    assert_equal(caml_filename_dirname("/file.txt"), "/")
  end
end)

test("dirname of root", function()
  if os_type == "Unix" then
    assert_equal(caml_filename_dirname("/"), "/")
  end
end)

-- Test 16-20: check_suffix
test("check_suffix with matching suffix", function()
  assert_equal(caml_filename_check_suffix("file.txt", ".txt"), 1)
end)

test("check_suffix with non-matching suffix", function()
  assert_equal(caml_filename_check_suffix("file.txt", ".doc"), 0)
end)

test("check_suffix with longer suffix than name", function()
  assert_equal(caml_filename_check_suffix("a.txt", ".very_long_suffix"), 0)
end)

test("check_suffix with empty suffix", function()
  assert_equal(caml_filename_check_suffix("file.txt", ""), 1)
end)

test("check_suffix case sensitive", function()
  assert_equal(caml_filename_check_suffix("file.TXT", ".txt"), 0)
end)

-- Test 21-25: chop_suffix
test("chop_suffix with matching suffix", function()
  assert_equal(caml_filename_chop_suffix("file.txt", ".txt"), "file")
end)

test("chop_suffix with non-matching suffix raises error", function()
  assert_error(function()
    caml_filename_chop_suffix("file.txt", ".doc")
  end, "should raise Invalid_argument")
end)

test("chop_suffix with longer suffix raises error", function()
  assert_error(function()
    caml_filename_chop_suffix("a.txt", ".very_long_suffix")
  end, "should raise Invalid_argument")
end)

test("chop_suffix with empty suffix", function()
  assert_equal(caml_filename_chop_suffix("file.txt", ""), "file.txt")
end)

test("chop_suffix with full name as suffix", function()
  assert_equal(caml_filename_chop_suffix("file.txt", "file.txt"), "")
end)

-- Test 26-30: chop_extension
test("chop_extension with simple extension", function()
  assert_equal(caml_filename_chop_extension("file.txt"), "file")
end)

test("chop_extension with multiple dots", function()
  assert_equal(caml_filename_chop_extension("archive.tar.gz"), "archive.tar")
end)

test("chop_extension without extension raises error", function()
  assert_error(function()
    caml_filename_chop_extension("file")
  end, "should raise Invalid_argument")
end)

test("chop_extension with dot at start raises error", function()
  assert_error(function()
    caml_filename_chop_extension(".hidden")
  end, "should raise Invalid_argument")
end)

test("chop_extension with path containing dots", function()
  if os_type == "Unix" then
    assert_equal(caml_filename_chop_extension("dir.name/file.txt"), "dir.name/file")
  end
end)

-- Test 31-35: extension
test("extension with simple extension", function()
  assert_equal(caml_filename_extension("file.txt"), ".txt")
end)

test("extension with multiple dots", function()
  assert_equal(caml_filename_extension("archive.tar.gz"), ".gz")
end)

test("extension without extension", function()
  assert_equal(caml_filename_extension("file"), "")
end)

test("extension with dot at start", function()
  assert_equal(caml_filename_extension(".hidden"), "")
end)

test("extension with path containing dots", function()
  if os_type == "Unix" then
    assert_equal(caml_filename_extension("dir.name/file.txt"), ".txt")
  end
end)

-- Test 36-38: remove_extension
test("remove_extension with extension", function()
  assert_equal(caml_filename_remove_extension("file.txt"), "file")
end)

test("remove_extension without extension", function()
  assert_equal(caml_filename_remove_extension("file"), "file")
end)

test("remove_extension with dot at start", function()
  assert_equal(caml_filename_remove_extension(".hidden"), ".hidden")
end)

-- Test 39-43: is_relative
test("is_relative with relative path", function()
  assert_equal(caml_filename_is_relative("dir/file.txt"), 1)
end)

test("is_relative with absolute Unix path", function()
  if os_type == "Unix" then
    assert_equal(caml_filename_is_relative("/absolute/path"), 0)
  end
end)

test("is_relative with absolute Windows path", function()
  if os_type == "Win32" then
    assert_equal(caml_filename_is_relative("C:\\absolute\\path"), 0)
  end
end)

test("is_relative with empty path", function()
  assert_equal(caml_filename_is_relative(""), 1)
end)

test("is_relative with current directory", function()
  assert_equal(caml_filename_is_relative("."), 1)
end)

-- Test 44-48: is_implicit
test("is_implicit with implicit path", function()
  assert_equal(caml_filename_is_implicit("dir/file.txt"), 1)
end)

test("is_implicit with explicit relative path ./", function()
  assert_equal(caml_filename_is_implicit("./file.txt"), 0)
end)

test("is_implicit with explicit relative path ../", function()
  assert_equal(caml_filename_is_implicit("../file.txt"), 0)
end)

test("is_implicit with absolute path", function()
  if os_type == "Unix" then
    assert_equal(caml_filename_is_implicit("/absolute/path"), 0)
  end
end)

test("is_implicit with empty path", function()
  assert_equal(caml_filename_is_implicit(""), 1)
end)

-- Test 49-51: directory markers
test("current_dir_name", function()
  assert_equal(caml_filename_current_dir_name(0), ".")
end)

test("parent_dir_name", function()
  assert_equal(caml_filename_parent_dir_name(0), "..")
end)

test("dir_sep", function()
  local sep = caml_filename_dir_sep(0)
  if os_type == "Win32" then
    assert_equal(sep, "\\")
  else
    assert_equal(sep, "/")
  end
end)

-- Test 52-54: quote
test("quote simple filename", function()
  assert_equal(caml_filename_quote("file.txt"), "file.txt")
end)

test("quote filename with spaces", function()
  local result = caml_filename_quote("my file.txt")
  assert_true(result:match('"'), "should be quoted")
end)

test("quote filename with special chars", function()
  local result = caml_filename_quote("file$name.txt")
  assert_true(result:match('"'), "should be quoted")
end)

-- Test 55-56: null device
test("null device name", function()
  local null = caml_filename_null(0)
  if os_type == "Win32" then
    assert_equal(null, "NUL")
  else
    assert_equal(null, "/dev/null")
  end
end)

test("temp_dir_name returns string", function()
  local temp = caml_filename_temp_dir_name(0)
  assert_true(type(temp) == "string", "should return a string")
end)

-- Test 57-62: Edge cases and complex paths
test("concat with multiple components", function()
  local r1 = caml_filename_concat("a", "b")
  local r2 = caml_filename_concat(r1, "c")
  local r3 = caml_filename_concat(r2, "file.txt")
  if os_type == "Win32" then
    assert_equal(r3, "a\\b\\c\\file.txt")
  else
    assert_equal(r3, "a/b/c/file.txt")
  end
end)

test("basename and dirname are inverse", function()
  local path
  if os_type == "Win32" then
    path = "dir\\subdir\\file.txt"
  else
    path = "dir/subdir/file.txt"
  end
  local dir = caml_filename_dirname(path)
  local base = caml_filename_basename(path)
  local reconstructed = caml_filename_concat(dir, base)
  assert_equal(reconstructed, path)
end)

test("chop and check suffix consistency", function()
  local name = "file.txt"
  local suffix = ".txt"
  if caml_filename_check_suffix(name, suffix) == 1 then
    local chopped = caml_filename_chop_suffix(name, suffix)
    assert_equal(chopped, "file")
  end
end)

test("extension and remove_extension consistency", function()
  local name = "file.txt"
  local ext = caml_filename_extension(name)
  local removed = caml_filename_remove_extension(name)
  if ext ~= "" then
    assert_equal(removed .. ext, name)
  end
end)

test("empty string handling", function()
  assert_equal(caml_filename_basename(""), "")
  assert_equal(caml_filename_dirname(""), ".")
  assert_equal(caml_filename_is_relative(""), 1)
  assert_equal(caml_filename_is_implicit(""), 1)
end)

test("paths with only separators", function()
  if os_type == "Unix" then
    assert_equal(caml_filename_dirname("///"), "/")
    assert_equal(caml_filename_basename("///"), "/")
  end
end)

-- Test 63-67: Windows-specific tests
if os_type == "Win32" then
  test("Windows: drive letter handling in concat", function()
    assert_equal(caml_filename_concat("C:\\dir", "file.txt"), "C:\\dir\\file.txt")
  end)

  test("Windows: absolute path with drive letter", function()
    assert_equal(caml_filename_is_relative("C:\\path"), 0)
  end)

  test("Windows: basename with drive letter", function()
    assert_equal(caml_filename_basename("C:\\dir\\file.txt"), "file.txt")
  end)

  test("Windows: dirname with drive letter", function()
    assert_equal(caml_filename_dirname("C:\\dir\\file.txt"), "C:\\dir")
  end)

  test("Windows: mixed separators", function()
    assert_equal(caml_filename_basename("C:\\dir/file.txt"), "file.txt")
  end)
end

-- Test 68-72: Unix-specific tests
if os_type == "Unix" then
  test("Unix: absolute path detection", function()
    assert_equal(caml_filename_is_relative("/usr/bin/ls"), 0)
  end)

  test("Unix: hidden files", function()
    assert_equal(caml_filename_basename("/home/user/.bashrc"), ".bashrc")
  end)

  test("Unix: extension of hidden file", function()
    assert_equal(caml_filename_extension(".bashrc"), "")
  end)

  test("Unix: current and parent dirs", function()
    assert_equal(caml_filename_dirname("./file"), ".")
    assert_equal(caml_filename_dirname("../file"), "..")
  end)

  test("Unix: root directory operations", function()
    assert_equal(caml_filename_dirname("/"), "/")
    assert_equal(caml_filename_basename("/"), "/")
  end)
end

-- Test 73-75: Performance tests
test("concat performance", function()
  local iterations = 1000
  local start = os.clock()
  for i = 1, iterations do
    caml_filename_concat("dir", "file.txt")
  end
  local elapsed = os.clock() - start
  assert_true(elapsed < 1.0, "should be fast (< 1ms per call)")
end)

test("basename performance", function()
  local path
  if os_type == "Win32" then
    path = "a\\b\\c\\d\\e\\f\\file.txt"
  else
    path = "a/b/c/d/e/f/file.txt"
  end
  local iterations = 1000
  local start = os.clock()
  for i = 1, iterations do
    caml_filename_basename(path)
  end
  local elapsed = os.clock() - start
  assert_true(elapsed < 1.0, "should be fast (< 1ms per call)")
end)

test("chop_extension performance", function()
  local iterations = 1000
  local start = os.clock()
  for i = 1, iterations do
    caml_filename_chop_extension("file.txt")
  end
  local elapsed = os.clock() - start
  assert_true(elapsed < 1.0, "should be fast (< 1ms per call)")
end)

-- Summary
print("\n=== Test Summary ===")
print(string.format("Total: %d", test_count))
print(string.format("Passed: %d", pass_count))
print(string.format("Failed: %d", fail_count))

if fail_count == 0 then
  print("\n✓ All tests passed!")
  os.exit(0)
else
  print(string.format("\n✗ %d test(s) failed", fail_count))
  os.exit(1)
end
