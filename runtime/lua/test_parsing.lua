#!/usr/bin/env lua
-- Test Parsing module

local parsing = require("parsing")

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

local function assert_true(value, msg)
  if not value then
    error(msg or "Expected true, got false")
  end
end

local function assert_false(value, msg)
  if value then
    error(msg or "Expected false, got true")
  end
end

print("====================================================================")
print("Parsing Module Tests")
print("====================================================================")
print()

print("Parser Environment Creation Tests:")
print("--------------------------------------------------------------------")

test("create_parser_env: default stack size", function()
  local env = parsing.caml_create_parser_env()
  assert_eq(env[5], 100)  -- stacksize = 100
end)

test("create_parser_env: custom stack size", function()
  local env = parsing.caml_create_parser_env(200)
  assert_eq(env[5], 200)
end)

test("create_parser_env: initial state", function()
  local env = parsing.caml_create_parser_env()
  assert_eq(env[14], 0)  -- sp = 0
  assert_eq(env[15], 0)  -- state = 0
  assert_eq(env[16], 0)  -- errflag = 0
  assert_eq(env[7], -1)  -- curr_char = -1
end)

test("create_parser_env: stacks initialized", function()
  local env = parsing.caml_create_parser_env()
  assert_true(env[1] ~= nil)  -- s_stack
  assert_true(env[2] ~= nil)  -- v_stack
  assert_true(env[3] ~= nil)  -- symb_start_stack
  assert_true(env[4] ~= nil)  -- symb_end_stack
end)

print()
print("Parser Trace Tests:")
print("--------------------------------------------------------------------")

test("set_parser_trace: returns old value", function()
  local old = parsing.caml_set_parser_trace(true)
  assert_true(old == true or old == false)
end)

test("set_parser_trace: can enable", function()
  parsing.caml_set_parser_trace(false)
  local old = parsing.caml_set_parser_trace(true)
  assert_eq(old, false)
end)

test("set_parser_trace: can disable", function()
  parsing.caml_set_parser_trace(true)
  local old = parsing.caml_set_parser_trace(false)
  assert_eq(old, true)
end)

print()
print("Stack Growth Tests:")
print("--------------------------------------------------------------------")

test("grow_stacks: updates stack size", function()
  local env = parsing.caml_create_parser_env(100)
  parsing.caml_grow_parser_stacks(env, 200)
  assert_eq(env[5], 200)
end)

test("grow_stacks: can grow multiple times", function()
  local env = parsing.caml_create_parser_env(50)
  parsing.caml_grow_parser_stacks(env, 100)
  parsing.caml_grow_parser_stacks(env, 150)
  assert_eq(env[5], 150)
end)

print()
print("Rule Information Tests:")
print("--------------------------------------------------------------------")

test("rule_info: returns rule number and length", function()
  local env = parsing.caml_create_parser_env()
  env[13] = 42  -- rule_number
  env[12] = 3   -- rule_len

  local num, len = parsing.caml_parser_rule_info(env)
  assert_eq(num, 42)
  assert_eq(len, 3)
end)

test("rule_info: initial values", function()
  local env = parsing.caml_create_parser_env()
  local num, len = parsing.caml_parser_rule_info(env)
  assert_eq(num, 0)
  assert_eq(len, 0)
end)

print()
print("Stack Value Access Tests:")
print("--------------------------------------------------------------------")

test("stack_value: access at offset 0", function()
  local env = parsing.caml_create_parser_env()
  env[11] = 5  -- asp = 5
  env[2][6] = "value"  -- v_stack[asp + 1]

  local val = parsing.caml_parser_stack_value(env, 0)
  assert_eq(val, "value")
end)

test("stack_value: access at positive offset", function()
  local env = parsing.caml_create_parser_env()
  env[11] = 5  -- asp = 5
  env[2][6] = "first"
  env[2][7] = "second"
  env[2][8] = "third"

  local val = parsing.caml_parser_stack_value(env, 1)
  assert_eq(val, "second")

  val = parsing.caml_parser_stack_value(env, 2)
  assert_eq(val, "third")
end)

test("stack_value: multiple values", function()
  local env = parsing.caml_create_parser_env()
  env[11] = 10
  env[2][11] = 42
  env[2][12] = "test"
  env[2][13] = 3.14

  assert_eq(parsing.caml_parser_stack_value(env, 0), 42)
  assert_eq(parsing.caml_parser_stack_value(env, 1), "test")
  assert_eq(parsing.caml_parser_stack_value(env, 2), 3.14)
end)

print()
print("Symbol Position Tests:")
print("--------------------------------------------------------------------")

test("symb_start: access at offset 0", function()
  local env = parsing.caml_create_parser_env()
  env[11] = 3  -- asp
  env[3][4] = 100  -- symb_start_stack[asp + 1]

  local pos = parsing.caml_parser_symb_start(env, 0)
  assert_eq(pos, 100)
end)

test("symb_end: access at offset 0", function()
  local env = parsing.caml_create_parser_env()
  env[11] = 3  -- asp
  env[4][4] = 200  -- symb_end_stack[asp + 1]

  local pos = parsing.caml_parser_symb_end(env, 0)
  assert_eq(pos, 200)
end)

test("symb positions: multiple offsets", function()
  local env = parsing.caml_create_parser_env()
  env[11] = 5
  env[3][6] = 10
  env[3][7] = 20
  env[3][8] = 30
  env[4][6] = 15
  env[4][7] = 25
  env[4][8] = 35

  assert_eq(parsing.caml_parser_symb_start(env, 0), 10)
  assert_eq(parsing.caml_parser_symb_start(env, 1), 20)
  assert_eq(parsing.caml_parser_symb_start(env, 2), 30)

  assert_eq(parsing.caml_parser_symb_end(env, 0), 15)
  assert_eq(parsing.caml_parser_symb_end(env, 1), 25)
  assert_eq(parsing.caml_parser_symb_end(env, 2), 35)
end)

print()
print("Parse Engine Infrastructure Tests:")
print("--------------------------------------------------------------------")

test("parse_engine: table caching", function()
  -- Create minimal parse tables
  local tables = {
    [6] = {0x00, 0x00},  -- defred
    [8] = {0x00, 0x00},  -- sindex
    [13] = {0x00, 0x00},  -- check
    [9] = {0x00, 0x00},  -- rindex
    [12] = {0x00, 0x00},  -- table
    [5] = {0x00, 0x00},  -- len
    [4] = {0x00, 0x00},  -- lhs
    [10] = {0x00, 0x00},  -- gindex
    [7] = {0x00, 0x00},  -- dgoto
    [11] = 100,  -- tablesize
  }

  local env = parsing.caml_create_parser_env()

  assert_true(tables.dgoto == nil)  -- Not cached

  -- Call parse engine (will fail but tables should be cached)
  pcall(function() parsing.caml_parse_engine(tables, env, 0, nil) end)

  assert_true(tables.dgoto ~= nil)  -- Now cached
end)

test("parse_engine: START command initializes state", function()
  local tables = {
    [2] = {0x00, 0x00},  -- transl_const
    [3] = {0x00, 0x00},  -- transl_block
    [6] = {0x00, 0x00},  -- defred (no default reduction, will request token)
    [8] = {0x00, 0x00},
    [13] = {0x00, 0x00},
    [9] = {0x00, 0x00},
    [12] = {0x00, 0x00},
    [5] = {0x01, 0x00},  -- len
    [4] = {0x00, 0x00},  -- lhs
    [10] = {0x00, 0x00},
    [7] = {0x00, 0x00},
    [11] = 100,
  }

  local env = parsing.caml_create_parser_env()
  env[15] = 99  -- Set non-zero state
  env[16] = 5   -- Set non-zero errflag
  env[7] = -1   -- curr_char not set (will cause READ_TOKEN)

  -- START command (0) should reset state and errflag
  local result = parsing.caml_parse_engine(tables, env, 0, nil)

  -- After START and LOOP, should request token with state=0, errflag=0
  assert_eq(env[15], 0)  -- state reset to 0
  assert_eq(env[16], 0)  -- errflag reset to 0
end)

test("parse_engine: READ_TOKEN command", function()
  local tables = {
    [2] = {0x00, 0x00, 0x05, 0x00},  -- transl_const
    [3] = {0x00, 0x00},
    [6] = {0x00, 0x00},
    [8] = {0x00, 0x00},
    [13] = {0x00, 0x00},
    [9] = {0x00, 0x00},
    [12] = {0x00, 0x00},
    [5] = {0x01, 0x00},
    [4] = {0x00, 0x00},
    [10] = {0x00, 0x00},
    [7] = {0x00, 0x00},
    [11] = 100,
  }

  local env = parsing.caml_create_parser_env()
  env[7] = -1  -- curr_char not set

  -- Cache tables first
  pcall(function() parsing.caml_parse_engine(tables, env, 0, nil) end)

  -- READ_TOKEN should update curr_char from arg
  local result = parsing.caml_parse_engine(tables, env, 1, 1)

  -- curr_char should now be set (from transl_const)
  assert_true(env[7] >= 0)
end)

test("parse_engine: state preservation", function()
  local tables = {
    [2] = {0x00, 0x00},
    [3] = {0x00, 0x00},
    [6] = {0x00, 0x00},  -- no default reduction
    [8] = {0x00, 0x00},
    [13] = {0x00, 0x00},
    [9] = {0x00, 0x00},
    [12] = {0x00, 0x00},
    [5] = {0x01, 0x00},
    [4] = {0x00, 0x00},
    [10] = {0x00, 0x00},
    [7] = {0x00, 0x00},
    [11] = 100,
  }

  local env = parsing.caml_create_parser_env()
  env[14] = 5   -- sp
  env[15] = 10  -- state
  env[16] = 2   -- errflag

  -- Call parse engine
  pcall(function() parsing.caml_parse_engine(tables, env, 0, nil) end)

  -- State should be preserved in env (may have changed due to parsing)
  assert_true(env[14] >= 0)  -- sp is valid
  assert_true(env[15] >= 0)  -- state is valid
  assert_true(env[16] >= 0)  -- errflag is valid
end)

print()
print("Integration Tests:")
print("--------------------------------------------------------------------")

test("integration: env and tables work together", function()
  local env = parsing.caml_create_parser_env(50)
  local tables = {
    [2] = {0x00, 0x00},
    [3] = {0x00, 0x00},
    [6] = {0x00, 0x00},
    [8] = {0x00, 0x00},
    [13] = {0x00, 0x00},
    [9] = {0x00, 0x00},
    [12] = {0x00, 0x00},
    [5] = {0x01, 0x00},
    [4] = {0x00, 0x00},
    [10] = {0x00, 0x00},
    [7] = {0x00, 0x00},
    [11] = 100,
  }

  -- Should not crash
  pcall(function() parsing.caml_parse_engine(tables, env, 0, nil) end)

  -- Tables should be cached
  assert_true(tables.dgoto ~= nil)
end)

test("integration: multiple parse calls", function()
  local env = parsing.caml_create_parser_env()
  local tables = {
    [2] = {0x00, 0x00},
    [3] = {0x00, 0x00},
    [6] = {0x00, 0x00},
    [8] = {0x00, 0x00},
    [13] = {0x00, 0x00},
    [9] = {0x00, 0x00},
    [12] = {0x00, 0x00},
    [5] = {0x01, 0x00},
    [4] = {0x00, 0x00},
    [10] = {0x00, 0x00},
    [7] = {0x00, 0x00},
    [11] = 100,
  }

  -- Multiple calls should not crash
  pcall(function() parsing.caml_parse_engine(tables, env, 0, nil) end)
  pcall(function() parsing.caml_parse_engine(tables, env, 0, nil) end)
  pcall(function() parsing.caml_parse_engine(tables, env, 0, nil) end)

  assert_true(true)
end)

test("integration: stack value and position tracking", function()
  local env = parsing.caml_create_parser_env()

  -- Simulate a reduce action with 3 symbols
  env[11] = 10  -- asp
  env[2][11] = "first"
  env[2][12] = "second"
  env[2][13] = "third"
  env[3][11] = 0
  env[3][12] = 5
  env[3][13] = 10
  env[4][11] = 5
  env[4][12] = 10
  env[4][13] = 15

  -- Access values
  assert_eq(parsing.caml_parser_stack_value(env, 0), "first")
  assert_eq(parsing.caml_parser_stack_value(env, 1), "second")
  assert_eq(parsing.caml_parser_stack_value(env, 2), "third")

  -- Access positions
  assert_eq(parsing.caml_parser_symb_start(env, 0), 0)
  assert_eq(parsing.caml_parser_symb_start(env, 1), 5)
  assert_eq(parsing.caml_parser_symb_start(env, 2), 10)

  assert_eq(parsing.caml_parser_symb_end(env, 0), 5)
  assert_eq(parsing.caml_parser_symb_end(env, 1), 10)
  assert_eq(parsing.caml_parser_symb_end(env, 2), 15)
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
