#!/usr/bin/env lua
-- Test format channel I/O integration

-- Unload builtin io if loaded
package.loaded.io = nil

-- Load custom io module
local io_module = dofile("./io.lua")
package.loaded.io = io_module

-- Load format.lua directly (it defines global caml_* functions)
dofile("format.lua")

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
    error(msg or ("Expected '" .. tostring(expected) .. "', got '" .. tostring(actual) .. "'"))
  end
end

local function assert_true(value, msg)
  if not value then
    error(msg or "Expected true, got false")
  end
end

-- Helper to create temporary file
local temp_file_counter = 0
local function make_temp_file()
  temp_file_counter = temp_file_counter + 1
  return "/tmp/test_format_channel_" .. temp_file_counter .. ".txt"
end

-- Helper to cleanup temp file
local function cleanup_temp_file(path)
  os.remove(path)
end

-- Helper to convert OCaml string (byte array) to Lua string
local function ocaml_string_to_lua(bytes)
  if type(bytes) == "string" then
    return bytes
  end
  local chars = {}
  for i = 1, #bytes do
    table.insert(chars, string.char(bytes[i]))
  end
  return table.concat(chars)
end

-- Helper: Make OCaml list
local function make_ocaml_list(arr)
  local result = 0
  for i = #arr, 1, -1 do
    result = {arr[i], result}
  end
  return result
end

print("====================================================================")
print("Format Channel I/O Integration Tests")
print("====================================================================")
print()

print("Printf Channel Output Tests:")
print("--------------------------------------------------------------------")

-- Test fprintf to file
test("fprintf: write integer to file", function()
  local temp_file = make_temp_file()

  -- Open file for writing
  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({1, 6}), 438)  -- O_WRONLY|O_CREAT, 0666
  local chanid = io_module.caml_ml_open_descriptor_out(fd)

  -- Write using fprintf
  caml_fprintf(chanid, "Number: %d\n", 42)

  -- Close
  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  -- Read back and verify
  local content = io.open(temp_file, "r"):read("*all")
  assert_eq(content, "Number: 42\n")

  cleanup_temp_file(temp_file)
end)

test("fprintf: write multiple values", function()
  local temp_file = make_temp_file()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({1, 6}), 438)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)

  caml_fprintf(chanid, "x=%d, y=%d\n", 10, 20)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  local content = io.open(temp_file, "r"):read("*all")
  assert_eq(content, "x=10, y=20\n")

  cleanup_temp_file(temp_file)
end)

test("fprintf: write float", function()
  local temp_file = make_temp_file()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({1, 6}), 438)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)

  caml_fprintf(chanid, "PI=%.2f\n", 3.14159)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  local content = io.open(temp_file, "r"):read("*all")
  assert_eq(content, "PI=3.14\n")

  cleanup_temp_file(temp_file)
end)

test("fprintf: write string", function()
  local temp_file = make_temp_file()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({1, 6}), 438)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)

  caml_fprintf(chanid, "Hello, %s!\n", "world")

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  local content = io.open(temp_file, "r"):read("*all")
  assert_eq(content, "Hello, world!\n")

  cleanup_temp_file(temp_file)
end)

test("fprintf: mixed types", function()
  local temp_file = make_temp_file()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({1, 6}), 438)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)

  caml_fprintf(chanid, "%s: %d items at $%.2f each\n", "Order", 5, 12.99)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  local content = io.open(temp_file, "r"):read("*all")
  assert_eq(content, "Order: 5 items at $12.99 each\n")

  cleanup_temp_file(temp_file)
end)

test("fprintf: hexadecimal", function()
  local temp_file = make_temp_file()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({1, 6}), 438)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)

  caml_fprintf(chanid, "0x%x\n", 255)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  local content = io.open(temp_file, "r"):read("*all")
  assert_eq(content, "0xff\n")

  cleanup_temp_file(temp_file)
end)

test("fprintf: formatted output", function()
  local temp_file = make_temp_file()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({1, 6}), 438)
  local chanid = io_module.caml_ml_open_descriptor_out(fd)

  caml_fprintf(chanid, "%+08d\n", 42)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  local content = io.open(temp_file, "r"):read("*all")
  assert_eq(content, "+0000042\n")

  cleanup_temp_file(temp_file)
end)

print()
print("Scanf Channel Input Tests:")
print("--------------------------------------------------------------------")

-- Test fscanf from file
test("fscanf: read integer from file", function()
  local temp_file = make_temp_file()

  -- Write test data
  local f = io.open(temp_file, "w")
  f:write("42\n")
  f:close()

  -- Open for reading
  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({0}), 438)  -- O_RDONLY
  local chanid = io_module.caml_ml_open_descriptor_in(fd)

  -- Read using fscanf
  local result = caml_fscanf(chanid, "%d")
  assert_eq(#result, 1)
  assert_eq(result[1], 42)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  cleanup_temp_file(temp_file)
end)

test("fscanf: read multiple integers", function()
  local temp_file = make_temp_file()

  local f = io.open(temp_file, "w")
  f:write("10 20 30\n")
  f:close()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({0}), 438)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)

  local result = caml_fscanf(chanid, "%d %d %d")
  assert_eq(#result, 3)
  assert_eq(result[1], 10)
  assert_eq(result[2], 20)
  assert_eq(result[3], 30)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  cleanup_temp_file(temp_file)
end)

test("fscanf: read float", function()
  local temp_file = make_temp_file()

  local f = io.open(temp_file, "w")
  f:write("3.14159\n")
  f:close()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({0}), 438)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)

  local result = caml_fscanf(chanid, "%f")
  assert_eq(#result, 1)
  assert_eq(result[1], 3.14159)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  cleanup_temp_file(temp_file)
end)

test("fscanf: read string", function()
  local temp_file = make_temp_file()

  local f = io.open(temp_file, "w")
  f:write("hello\n")
  f:close()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({0}), 438)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)

  local result = caml_fscanf(chanid, "%s")
  assert_eq(#result, 1)
  assert_eq(result[1], "hello")

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  cleanup_temp_file(temp_file)
end)

test("fscanf: mixed types", function()
  local temp_file = make_temp_file()

  local f = io.open(temp_file, "w")
  f:write("42 hello 3.14\n")
  f:close()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({0}), 438)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)

  local result = caml_fscanf(chanid, "%d %s %f")
  assert_eq(#result, 3)
  assert_eq(result[1], 42)
  assert_eq(result[2], "hello")
  assert_eq(result[3], 3.14)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  cleanup_temp_file(temp_file)
end)

test("fscanf: with format literals", function()
  local temp_file = make_temp_file()

  local f = io.open(temp_file, "w")
  f:write("x=10, y=20\n")
  f:close()

  local fd = io_module.caml_sys_open(temp_file, make_ocaml_list({0}), 438)
  local chanid = io_module.caml_ml_open_descriptor_in(fd)

  local result = caml_fscanf(chanid, "x=%d, y=%d")
  assert_eq(#result, 2)
  assert_eq(result[1], 10)
  assert_eq(result[2], 20)

  io_module.caml_ml_close_channel(chanid)
  io_module.caml_sys_close(fd)

  cleanup_temp_file(temp_file)
end)

print()
print("Round-trip Tests (Printf + Scanf):")
print("--------------------------------------------------------------------")

test("Round-trip: integer", function()
  local temp_file = make_temp_file()

  -- Write
  local fd_w = io_module.caml_sys_open(temp_file, make_ocaml_list({1, 6}), 438)
  local chan_w = io_module.caml_ml_open_descriptor_out(fd_w)
  caml_fprintf(chan_w, "%d\n", 12345)
  io_module.caml_ml_close_channel(chan_w)
  io_module.caml_sys_close(fd_w)

  -- Read
  local fd_r = io_module.caml_sys_open(temp_file, make_ocaml_list({0}), 438)
  local chan_r = io_module.caml_ml_open_descriptor_in(fd_r)
  local result = caml_fscanf(chan_r, "%d")
  assert_eq(result[1], 12345)
  io_module.caml_ml_close_channel(chan_r)
  io_module.caml_sys_close(fd_r)

  cleanup_temp_file(temp_file)
end)

test("Round-trip: multiple values", function()
  local temp_file = make_temp_file()

  -- Write
  local fd_w = io_module.caml_sys_open(temp_file, make_ocaml_list({1, 6}), 438)
  local chan_w = io_module.caml_ml_open_descriptor_out(fd_w)
  caml_fprintf(chan_w, "%d %s %.2f\n", 100, "test", 2.5)
  io_module.caml_ml_close_channel(chan_w)
  io_module.caml_sys_close(fd_w)

  -- Read
  local fd_r = io_module.caml_sys_open(temp_file, make_ocaml_list({0}), 438)
  local chan_r = io_module.caml_ml_open_descriptor_in(fd_r)
  local result = caml_fscanf(chan_r, "%d %s %f")
  assert_eq(result[1], 100)
  assert_eq(result[2], "test")
  assert_eq(result[3], 2.5)
  io_module.caml_ml_close_channel(chan_r)
  io_module.caml_sys_close(fd_r)

  cleanup_temp_file(temp_file)
end)

test("Round-trip: formatted data", function()
  local temp_file = make_temp_file()

  -- Write
  local fd_w = io_module.caml_sys_open(temp_file, make_ocaml_list({1, 6}), 438)
  local chan_w = io_module.caml_ml_open_descriptor_out(fd_w)
  caml_fprintf(chan_w, "data: %d,%d,%d\n", 1, 2, 3)
  io_module.caml_ml_close_channel(chan_w)
  io_module.caml_sys_close(fd_w)

  -- Read
  local fd_r = io_module.caml_sys_open(temp_file, make_ocaml_list({0}), 438)
  local chan_r = io_module.caml_ml_open_descriptor_in(fd_r)
  local result = caml_fscanf(chan_r, "data: %d,%d,%d")
  assert_eq(result[1], 1)
  assert_eq(result[2], 2)
  assert_eq(result[3], 3)
  io_module.caml_ml_close_channel(chan_r)
  io_module.caml_sys_close(fd_r)

  cleanup_temp_file(temp_file)
end)

print()
print(string.rep("=", 60))
print("Tests passed: " .. tests_passed)
print("Tests failed: " .. tests_failed)
if tests_failed == 0 then
  print("All tests passed! ✓")
  print(string.rep("=", 60))
  os.exit(0)
else
  print("Some tests failed.")
  print(string.rep("=", 60))
  os.exit(1)
end
