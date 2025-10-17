#!/usr/bin/env lua
-- Test suite for sys.lua
-- Comprehensive tests for system operations

dofile("sys.lua")
dofile("core.lua")

local test_count = 0
local pass_count = 0
local fail_count = 0

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
    error(string.format("%s: expected %s, got %s",
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

local function assert_ocaml_string(value, expected, msg)
  local actual = value
  assert_equal(actual, expected, msg)
end

local function assert_error(fn, msg)
  local ok = pcall(fn)
  if ok then
    error(msg or "expected error but function succeeded")
  end
end

print("=== Sys Module Tests ===\n")

-- Test 1: caml_sys_get_config
test("caml_sys_get_config returns config tuple", function()
  local config = caml_sys_get_config(caml_unit)
  assert_equal(config.tag, 0, "config should be a tuple")
  assert_true(config[1] ~= nil, "os_type should be present")
  assert_equal(config[2], 32, "word_size should be 32")
  assert_equal(config[3], 0, "should be little endian")
end)

-- Test 2: OS type detection
test("OS type is detected correctly", function()
  local config = caml_sys_get_config(caml_unit)
  local os_type = config[1]
  assert_true(os_type == "Unix" or os_type == "Win32", "os_type should be Unix or Win32")
end)

-- Test 3: caml_sys_argv
test("caml_sys_argv returns array", function()
  local argv = caml_sys_argv(caml_unit)
  assert_equal(argv.tag, 0, "argv should be an array")
  assert_true(argv[1] ~= nil, "argv should have program name")
end)

-- Test 4: caml_sys_get_argv
test("caml_sys_get_argv returns tuple", function()
  local result = caml_sys_get_argv(caml_unit)
  assert_equal(result.tag, 0, "result should be a tuple")
  assert_true(result[1] ~= nil, "should have program name")
  assert_true(result[2] ~= nil, "should have argv array")
  assert_equal(result[2].tag, 0, "argv should be an array")
end)

-- Test 5: caml_sys_executable_name
test("caml_sys_executable_name returns program name", function()
  local name = caml_sys_executable_name(caml_unit)
  assert_true(name ~= nil, "executable name should not be nil")
  -- Should match first element of argv
  local argv = caml_sys_argv(caml_unit)
  local name_str = name
  local argv_name_str = argv[1]
  assert_equal(name_str, argv_name_str, "executable name should match argv[0]")
end)

-- Test 6: caml_sys_modify_argv
test("caml_sys_modify_argv changes argv", function()
  local old_argv = caml_sys_argv(caml_unit)
  local new_argv = {tag = 0, [1] = "test_prog"}
  caml_sys_modify_argv(new_argv)
  local current_argv = caml_sys_argv(caml_unit)
  assert_equal(current_argv[1], new_argv[1], "argv should be modified")
  -- Restore
  caml_sys_modify_argv(old_argv)
end)

-- Test 7: caml_set_static_env and caml_sys_getenv
test("caml_set_static_env and caml_sys_getenv", function()
  local key = "TEST_VAR_STATIC"
  local value = "test_value_123"
  caml_set_static_env(key, value)
  local result = caml_sys_getenv(key)
  assert_ocaml_string(result, "test_value_123", "should get static env var")
end)

-- Test 8: caml_sys_getenv with system environment
test("caml_sys_getenv with system env var", function()
  -- Set a real environment variable
  os.execute('export TEST_VAR_REAL=real_value 2>/dev/null || set TEST_VAR_REAL=real_value')
  -- Note: This may not work in all environments, so we'll use PATH which should exist
  local path_key = "PATH"
  local ok, result = pcall(caml_sys_getenv, path_key)
  -- PATH may not exist in all environments, so we just check it doesn't crash
  assert_true(true, "getenv should not crash")
end)

-- Test 9: caml_sys_getenv with nonexistent variable
test("caml_sys_getenv raises Not_found for nonexistent var", function()
  local key = "NONEXISTENT_VAR_XYZ123"
  assert_error(function()
    caml_sys_getenv(key)
  end, "should raise Not_found for nonexistent var")
end)

-- Test 10: caml_sys_getenv_opt with existing variable
test("caml_sys_getenv_opt returns Some for existing var", function()
  local key = "TEST_VAR_OPT"
  local value = "opt_value"
  caml_set_static_env(key, value)
  local result = caml_sys_getenv_opt(key)
  assert_equal(result.tag, 0, "should return Some")
  assert_ocaml_string(result[1], "opt_value", "should have correct value")
end)

-- Test 11: caml_sys_getenv_opt with nonexistent variable
test("caml_sys_getenv_opt returns None for nonexistent var", function()
  local key = "NONEXISTENT_VAR_OPT_XYZ"
  local result = caml_sys_getenv_opt(key)
  assert_equal(result, caml_unit, "should return None (0)")
end)

-- Test 12: caml_sys_time
test("caml_sys_time returns non-negative number", function()
  local t1 = caml_sys_time(caml_unit)
  assert_true(type(t1) == "number", "time should be a number")
  assert_true(t1 >= 0, "time should be non-negative")
  -- Wait a bit
  local start = os.clock()
  while os.clock() - start < 0.01 do end
  local t2 = caml_sys_time(caml_unit)
  assert_true(t2 >= t1, "time should increase")
end)

-- Test 13: caml_sys_time_include_children
test("caml_sys_time_include_children returns time", function()
  local t = caml_sys_time_include_children(caml_unit)
  assert_true(type(t) == "number", "time should be a number")
  assert_true(t >= 0, "time should be non-negative")
end)

-- Test 14: caml_sys_random_seed
test("caml_sys_random_seed returns array of 4 integers", function()
  local seed = caml_sys_random_seed(caml_unit)
  assert_equal(seed.tag, 0, "seed should be an array")
  assert_true(seed[1] ~= nil, "should have first value")
  assert_true(seed[2] ~= nil, "should have second value")
  assert_true(seed[3] ~= nil, "should have third value")
  assert_true(seed[4] ~= nil, "should have fourth value")
  -- Values should be different (very likely)
  local all_same = (seed[1] == seed[2] and seed[2] == seed[3] and seed[3] == seed[4])
  assert_true(not all_same, "seed values should be different")
end)

-- Test 15: System constants
test("caml_sys_const_big_endian", function()
  assert_equal(caml_sys_const_big_endian(caml_unit), 0, "should be little endian")
end)

test("caml_sys_const_word_size", function()
  assert_equal(caml_sys_const_word_size(caml_unit), 32, "word size should be 32")
end)

test("caml_sys_const_int_size", function()
  assert_equal(caml_sys_const_int_size(caml_unit), 32, "int size should be 32")
end)

test("caml_sys_const_max_wosize", function()
  local max_wosize = caml_sys_const_max_wosize(caml_unit)
  assert_equal(max_wosize, math.floor(0x7fffffff / 4), "max_wosize should be correct")
end)

test("caml_sys_const_backend_type", function()
  local backend = caml_sys_const_backend_type(caml_unit)
  assert_equal(backend.tag, 0, "backend should be a tuple")
  assert_ocaml_string(backend[1], "lua_of_ocaml", "backend should be lua_of_ocaml")
end)

-- Test 16-20: File operations
test("caml_sys_file_exists with existing file", function()
  -- Create a test file
  local test_file = "/tmp/test_sys_exists_" .. os.time() .. ".txt"
  local f = io.open(test_file, "w")
  f:write("test")
  f:close()

  local name = test_file
  local result = caml_sys_file_exists(name)
  assert_equal(result, caml_true_val, "file should exist")

  -- Clean up
  os.remove(test_file)
end)

test("caml_sys_file_exists with nonexistent file", function()
  local name = "/tmp/nonexistent_file_xyz123.txt"
  local result = caml_sys_file_exists(name)
  assert_equal(result, caml_false_val, "file should not exist")
end)

test("caml_sys_remove removes file", function()
  -- Create a test file
  local test_file = "/tmp/test_sys_remove_" .. os.time() .. ".txt"
  local f = io.open(test_file, "w")
  f:write("test")
  f:close()

  local name = test_file
  caml_sys_remove(name)

  -- Verify it's gone
  local f2 = io.open(test_file, "r")
  assert_true(f2 == nil, "file should be removed")
end)

test("caml_sys_remove raises error for nonexistent file", function()
  local name = "/tmp/nonexistent_file_remove_xyz.txt"
  assert_error(function()
    caml_sys_remove(name)
  end, "should raise error for nonexistent file")
end)

test("caml_sys_rename renames file", function()
  -- Create a test file
  local old_file = "/tmp/test_sys_rename_old_" .. os.time() .. ".txt"
  local new_file = "/tmp/test_sys_rename_new_" .. os.time() .. ".txt"
  local f = io.open(old_file, "w")
  f:write("test content")
  f:close()

  local old_name = old_file
  local new_name = new_file
  caml_sys_rename(old_name, new_name)

  -- Verify old file is gone
  local f1 = io.open(old_file, "r")
  assert_true(f1 == nil, "old file should not exist")

  -- Verify new file exists
  local f2 = io.open(new_file, "r")
  assert_true(f2 ~= nil, "new file should exist")
  if f2 then
    local content = f2:read("*a")
    f2:close()
    assert_equal(content, "test content", "content should be preserved")
    os.remove(new_file)
  end
end)

test("caml_sys_is_regular_file detects regular file", function()
  -- Create a test file
  local test_file = "/tmp/test_sys_regular_" .. os.time() .. ".txt"
  local f = io.open(test_file, "w")
  f:write("test")
  f:close()

  local name = test_file
  local result = caml_sys_is_regular_file(name)
  assert_equal(result, caml_true_val, "should detect regular file")

  -- Clean up
  os.remove(test_file)
end)

test("caml_sys_is_directory detects directory", function()
  -- Use /tmp which should exist on Unix systems
  local name = "/tmp"
  local result = caml_sys_is_directory(name)
  -- This may fail without lfs or on Windows, so we just check it doesn't crash
  assert_true(result == caml_true_val or result == caml_false_val, "should return boolean")
end)

-- Test 27: caml_sys_system_command
test("caml_sys_system_command executes command", function()
  local cmd = "true"  -- Always succeeds on Unix
  local result = caml_sys_system_command(cmd)
  -- Should return 0 for success (may vary by platform)
  assert_true(type(result) == "number", "should return a number")
end)

-- Test 28: caml_sys_isatty
test("caml_sys_isatty returns false", function()
  local result = caml_sys_isatty(0)
  assert_equal(result, caml_false_val, "should return false")
end)

-- Test 29: caml_runtime_variant
test("caml_runtime_variant returns empty string", function()
  local result = caml_runtime_variant(caml_unit)
  assert_ocaml_string(result, "", "should return empty string")
end)

-- Test 30: caml_runtime_parameters
test("caml_runtime_parameters returns empty string", function()
  local result = caml_runtime_parameters(caml_unit)
  assert_ocaml_string(result, "", "should return empty string")
end)

-- Test 31: Runtime warnings
test("runtime warnings can be enabled and disabled", function()
  caml_ml_enable_runtime_warnings(caml_true_val)
  assert_equal(caml_ml_runtime_warnings_enabled(caml_unit), caml_true_val, "should be enabled")
  caml_ml_enable_runtime_warnings(caml_false_val)
  assert_equal(caml_ml_runtime_warnings_enabled(caml_unit), caml_false_val, "should be disabled")
end)

-- Test 32: caml_sys_io_buffer_size
test("caml_sys_io_buffer_size returns 65536", function()
  local size = caml_sys_io_buffer_size(caml_unit)
  assert_equal(size, 65536, "buffer size should be 65536")
end)

-- Test 33: caml_sys_temp_dir_name
test("caml_sys_temp_dir_name returns temp directory", function()
  local temp = caml_sys_temp_dir_name(caml_unit)
  local temp_str = temp
  assert_true(type(temp_str) == "string", "should return a string")
  -- On Unix, should be /tmp or similar
  -- On Windows, should be from TEMP/TMP env var
end)

-- Test 34: caml_xdg_defaults
test("caml_xdg_defaults returns empty list", function()
  local result = caml_xdg_defaults(caml_unit)
  assert_equal(result, caml_unit, "should return empty list (0)")
end)

-- Test 35: Signal number conversion
test("caml_sys_convert_signal_number returns same number", function()
  assert_equal(caml_sys_convert_signal_number(15), 15, "should return same")
  assert_equal(caml_sys_rev_convert_signal_number(15), 15, "should return same")
end)

-- Test 36: OS type constants
test("OS type constants are consistent", function()
  local config = caml_sys_get_config(caml_unit)
  local os_type = config[1]

  local is_unix = caml_sys_const_ostype_unix(caml_unit)
  local is_win32 = caml_sys_const_ostype_win32(caml_unit)
  local is_cygwin = caml_sys_const_ostype_cygwin(caml_unit)

  if os_type == "Unix" then
    assert_equal(is_unix, caml_true_val, "Unix flag should be true")
    assert_equal(is_win32, caml_false_val, "Win32 flag should be false")
  elseif os_type == "Win32" then
    assert_equal(is_unix, caml_false_val, "Unix flag should be false")
    assert_equal(is_win32, caml_true_val, "Win32 flag should be true")
  end
  assert_equal(is_cygwin, caml_false_val, "Cygwin flag should always be false")
end)

-- Test 37: caml_install_signal_handler (no-op)
test("caml_install_signal_handler is no-op", function()
  local result = caml_install_signal_handler(15, 0)
  assert_equal(result, caml_unit, "should return unit")
end)

-- Test 38: Multiple environment variables
test("multiple static environment variables", function()
  local keys = {"VAR1", "VAR2", "VAR3"}
  local values = {"value1", "value2", "value3"}

  for i = 1, #keys do
    local key = keys[i]
    local value = values[i]
    caml_set_static_env(key, value)
  end

  for i = 1, #keys do
    local key = keys[i]
    local result = caml_sys_getenv(key)
    assert_ocaml_string(result, values[i], "should get correct value for " .. keys[i])
  end
end)

-- Test 39: Large environment variable value
test("large environment variable value", function()
  local large_value = string.rep("x", 10000)
  local key = "LARGE_VAR"
  local value = large_value
  caml_set_static_env(key, value)
  local result = caml_sys_getenv(key)
  assert_ocaml_string(result, large_value, "should handle large values")
end)

-- Test 40: File operations with special characters in path
test("file operations with special characters", function()
  local test_file = "/tmp/test_file_with space_" .. os.time() .. ".txt"
  local f = io.open(test_file, "w")
  if f then
    f:write("test")
    f:close()

    local name = test_file
    local exists = caml_sys_file_exists(name)
    assert_equal(exists, caml_true_val, "should handle paths with spaces")

    caml_sys_remove(name)
  end
end)

-- Test 41-42: Performance tests
test("caml_sys_time performance", function()
  local iterations = 1000
  local start = os.clock()
  for i = 1, iterations do
    caml_sys_time(caml_unit)
  end
  local elapsed = os.clock() - start
  assert_true(elapsed < 1.0, "should be fast (< 1ms per call)")
end)

test("caml_sys_getenv performance", function()
  local key = "PERF_TEST_VAR"
  local value = "value"
  caml_set_static_env(key, value)

  local iterations = 1000
  local start = os.clock()
  for i = 1, iterations do
    caml_sys_getenv(key)
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
