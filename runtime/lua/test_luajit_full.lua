#!/usr/bin/env luajit
-- Comprehensive LuaJIT Compatibility Test Suite
-- Tests all runtime modules on LuaJIT

local results = {}
local total_tests = 0
local total_passed = 0
local total_failed = 0

local function run_test_file(name, file)
  io.write(string.format("Testing %-20s ... ", name))
  io.flush()

  -- Load and execute the test file in the same interpreter
  local chunk, err = loadfile(file)
  if not chunk then
    print("✗ FAIL (load error)")
    results[name] = {passed = false, tests = 0, output = "Load error: " .. tostring(err)}
    return false
  end

  -- Capture output by redirecting print and os.exit
  local output_lines = {}
  local old_print = print
  local old_exit = os.exit
  local test_passed = 0
  local test_failed = 0
  local exit_code = nil

  _G.print = function(...)
    local args = {...}
    local line = table.concat(args, "\t")
    table.insert(output_lines, line)

    -- Parse test results
    local passed = line:match("Tests passed: (%d+)")
    local failed = line:match("Tests failed: (%d+)")
    if passed then test_passed = tonumber(passed) end
    if failed then test_failed = tonumber(failed) end
  end

  -- Override os.exit to capture exit codes
  os.exit = function(code)
    exit_code = code
    error("__TEST_EXIT__")  -- Use error to break out
  end

  -- Run the test
  local success, err = pcall(chunk)

  -- Restore functions
  _G.print = old_print
  os.exit = old_exit

  -- Handle test exit
  if not success and err == "__TEST_EXIT__" then
    success = (exit_code == 0)
  end

  local output = table.concat(output_lines, "\n")

  if success and test_failed == 0 and test_passed > 0 then
    old_print(string.format("✓ PASS (%d tests)", test_passed))
    results[name] = {passed = true, tests = test_passed, output = output}
    total_tests = total_tests + test_passed
    total_passed = total_passed + test_passed
    return true
  else
    if not success then
      old_print(string.format("✗ FAIL (error: %s)", tostring(err)))
      results[name] = {passed = false, tests = 0, output = output .. "\nError: " .. tostring(err)}
    else
      old_print(string.format("✗ FAIL (%d passed, %d failed)", test_passed, test_failed))
      results[name] = {passed = false, tests = test_passed, output = output}
      total_tests = total_tests + test_passed + test_failed
      total_passed = total_passed + test_passed
      total_failed = total_failed + test_failed
    end
    return false
  end
end

print("LuaJIT Full Compatibility Test Suite")
print(string.rep("=", 70))

-- Verify we're running on LuaJIT
if not jit then
  error("This test must be run with LuaJIT")
end

print("LuaJIT Version: " .. jit.version)
print("JIT Status: " .. (jit.status() and "enabled" or "disabled"))
print("")

-- Test all modules
local modules_tested = 0
local modules_passed = 0

print("Core Runtime Modules:")
print(string.rep("-", 70))

if run_test_file("core.lua", "test_core.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("compat_bit.lua", "test_compat_bit.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("ints.lua", "test_ints.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("float.lua", "test_float.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("mlBytes.lua", "test_mlBytes.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("array.lua", "test_array.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("obj.lua", "test_obj.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

print("")
print("Standard Library Modules:")
print(string.rep("-", 70))

if run_test_file("list.lua", "test_list.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("option.lua", "test_option.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("result.lua", "test_result.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("lazy.lua", "test_lazy.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("fun.lua", "test_fun.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("fail.lua", "test_fail.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

if run_test_file("gc.lua", "test_gc.lua") then modules_passed = modules_passed + 1 end
modules_tested = modules_tested + 1

print("")
print(string.rep("=", 70))
print("LuaJIT Compatibility Summary")
print(string.rep("=", 70))
print(string.format("Modules tested: %d", modules_tested))
print(string.format("Modules passed: %d", modules_passed))
print(string.format("Modules failed: %d", modules_tested - modules_passed))
print(string.format("Module success rate: %.1f%%", (modules_passed / modules_tested) * 100))
print("")
print(string.format("Total individual tests: %d", total_tests))
print(string.format("Tests passed: %d", total_passed))
print(string.format("Tests failed: %d", total_failed))
if total_tests > 0 then
  print(string.format("Test success rate: %.1f%%", (total_passed / total_tests) * 100))
end

-- List failed modules
local failed = {}
for name, result in pairs(results) do
  if not result.passed then
    table.insert(failed, name)
  end
end

if #failed > 0 then
  print("")
  print("Failed modules:")
  for _, name in ipairs(failed) do
    print("  - " .. name)
  end
  print("")
  print("Run individual tests for details:")
  for _, name in ipairs(failed) do
    local test_name = "test_" .. name:gsub("%.lua$", ".lua")
    print(string.format("  luajit %s", test_name))
  end
  os.exit(1)
else
  print("")
  print("✓ All modules passed on LuaJIT!")
  print("✓ Full compatibility verified")
  os.exit(0)
end
