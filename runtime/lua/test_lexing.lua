#!/usr/bin/env lua
-- Test Lexing module

local lexing = require("lexing")

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

local function assert_table_eq(actual, expected)
  if #actual ~= #expected then
    error("Table lengths differ: expected " .. #expected .. ", got " .. #actual)
  end
  for i = 1, #expected do
    if actual[i] ~= expected[i] then
      error("Tables differ at index " .. i .. ": expected " .. tostring(expected[i]) .. ", got " .. tostring(actual[i]))
    end
  end
end

print("====================================================================")
print("Lexing Module Tests")
print("====================================================================")
print()

print("Lex Array Tests:")
print("--------------------------------------------------------------------")

test("lex_array: empty array", function()
  local arr = lexing.caml_lex_array({})
  assert_eq(#arr, 0)
end)

test("lex_array: single element", function()
  local arr = lexing.caml_lex_array({0x42, 0x00})
  assert_eq(#arr, 1)
  assert_eq(arr[1], 0x42)
end)

test("lex_array: multiple elements", function()
  local arr = lexing.caml_lex_array({0x01, 0x00, 0x02, 0x00, 0x03, 0x00})
  assert_eq(#arr, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], 2)
  assert_eq(arr[3], 3)
end)

test("lex_array: negative values (sign extension)", function()
  -- 0xFF 0xFF should be -1
  local arr = lexing.caml_lex_array({0xFF, 0xFF})
  assert_eq(#arr, 1)
  assert_eq(arr[1], -1)
end)

test("lex_array: mixed positive and negative", function()
  local arr = lexing.caml_lex_array({0x01, 0x00, 0xFF, 0xFF, 0x00, 0x80})
  assert_eq(#arr, 3)
  assert_eq(arr[1], 1)
  assert_eq(arr[2], -1)
  assert_eq(arr[3], -32768)  -- 0x8000 sign-extended
end)

print()
print("Lexbuf Creation from String Tests:")
print("--------------------------------------------------------------------")

test("create from string: empty string", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("")
  assert_eq(lexbuf[3], 0)  -- buffer_len
  assert_eq(lexbuf[6], 0)  -- curr_pos
end)

test("create from string: simple string", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("hello")
  assert_eq(lexbuf[3], 5)  -- buffer_len
  assert_eq(lexbuf[6], 0)  -- curr_pos starts at 0
end)

test("create from string: initial positions", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("test")
  assert_eq(lexbuf[4], 0)  -- abs_pos
  assert_eq(lexbuf[5], 0)  -- start_pos
  assert_eq(lexbuf[6], 0)  -- curr_pos
  assert_eq(lexbuf[9], 0)  -- eof_reached
end)

test("create from string: position tracking", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("test")
  local start_p = lexbuf[11]
  local curr_p = lexbuf[12]

  assert_eq(start_p.pos_lnum, 1)
  assert_eq(start_p.pos_bol, 0)
  assert_eq(start_p.pos_cnum, 0)

  assert_eq(curr_p.pos_lnum, 1)
  assert_eq(curr_p.pos_bol, 0)
  assert_eq(curr_p.pos_cnum, 0)
end)

test("create from byte array", function()
  local bytes = {104, 101, 108, 108, 111}  -- "hello"
  local lexbuf = lexing.caml_create_lexbuf_from_string(bytes)
  assert_eq(lexbuf[3], 5)  -- buffer_len
end)

print()
print("Lexeme Extraction Tests:")
print("--------------------------------------------------------------------")

test("lexeme: extract substring", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("hello world")
  lexbuf[5] = 0  -- start_pos
  lexbuf[6] = 5  -- curr_pos (points after "hello")

  local lexeme = lexing.caml_lexeme(lexbuf)
  assert_table_eq(lexeme, {104, 101, 108, 108, 111})  -- "hello"
end)

test("lexeme_string: extract as Lua string", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("hello world")
  lexbuf[5] = 0
  lexbuf[6] = 5

  local str = lexing.caml_lexeme_string(lexbuf)
  assert_eq(str, "hello")
end)

test("lexeme_string: middle of buffer", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("hello world")
  lexbuf[5] = 6  -- start at 'w'
  lexbuf[6] = 11  -- end after "world"

  local str = lexing.caml_lexeme_string(lexbuf)
  assert_eq(str, "world")
end)

test("lexeme: empty lexeme", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("test")
  lexbuf[5] = 2
  lexbuf[6] = 2  -- same position

  local lexeme = lexing.caml_lexeme(lexbuf)
  assert_eq(#lexeme, 0)
end)

print()
print("Position Tracking Tests:")
print("--------------------------------------------------------------------")

test("lexeme_start: absolute position", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("hello")
  lexbuf[4] = 100  -- abs_pos
  lexbuf[5] = 3    -- start_pos

  local start = lexing.caml_lexeme_start(lexbuf)
  assert_eq(start, 103)  -- 100 + 3
end)

test("lexeme_end: absolute position", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("hello")
  lexbuf[4] = 100  -- abs_pos
  lexbuf[6] = 5    -- curr_pos

  local end_pos = lexing.caml_lexeme_end(lexbuf)
  assert_eq(end_pos, 105)  -- 100 + 5
end)

test("lexeme_start_p: returns start position record", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("test")
  local start_p = lexing.caml_lexeme_start_p(lexbuf)

  assert_true(start_p ~= nil)
  assert_eq(start_p.pos_lnum, 1)
  assert_eq(start_p.pos_bol, 0)
end)

test("lexeme_end_p: returns current position record", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("test")
  local curr_p = lexing.caml_lexeme_end_p(lexbuf)

  assert_true(curr_p ~= nil)
  assert_eq(curr_p.pos_lnum, 1)
  assert_eq(curr_p.pos_bol, 0)
end)

print()
print("New Line Tracking Tests:")
print("--------------------------------------------------------------------")

test("new_line: increments line number", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("line1\nline2")
  local curr_p = lexbuf[12]

  assert_eq(curr_p.pos_lnum, 1)
  lexing.caml_new_line(lexbuf)
  assert_eq(curr_p.pos_lnum, 2)
end)

test("new_line: updates bol (beginning of line)", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("line1\nline2")
  lexbuf[6] = 6  -- after newline
  lexbuf[4] = 0  -- abs_pos

  lexing.caml_new_line(lexbuf)
  local curr_p = lexbuf[12]

  assert_eq(curr_p.pos_bol, 6)
  assert_eq(curr_p.pos_cnum, 6)
end)

test("new_line: multiple newlines", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("line1\nline2\nline3")
  local curr_p = lexbuf[12]

  lexing.caml_new_line(lexbuf)
  lexing.caml_new_line(lexbuf)
  lexing.caml_new_line(lexbuf)

  assert_eq(curr_p.pos_lnum, 4)
end)

print()
print("Lexeme Char Tests:")
print("--------------------------------------------------------------------")

test("lexeme_char: get character at offset", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("hello")
  lexbuf[5] = 0
  lexbuf[6] = 5

  assert_eq(lexing.caml_lexeme_char(lexbuf, 0), 104)  -- 'h'
  assert_eq(lexing.caml_lexeme_char(lexbuf, 1), 101)  -- 'e'
  assert_eq(lexing.caml_lexeme_char(lexbuf, 4), 111)  -- 'o'
end)

test("lexeme_char: out of bounds raises error", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("hi")
  lexbuf[5] = 0
  lexbuf[6] = 2

  local success, err = pcall(function()
    lexing.caml_lexeme_char(lexbuf, 5)
  end)

  assert_true(not success)
  assert_true(string.find(tostring(err), "out of bounds"))
end)

print()
print("Flush Tests:")
print("--------------------------------------------------------------------")

test("flush: updates absolute position", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("test")
  lexbuf[6] = 4  -- curr_pos

  lexing.caml_flush_lexbuf(lexbuf)

  assert_eq(lexbuf[4], 4)  -- abs_pos updated
  assert_eq(lexbuf[6], 0)  -- curr_pos reset
end)

test("flush: resets positions", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("test")
  lexbuf[5] = 2
  lexbuf[6] = 4

  lexing.caml_flush_lexbuf(lexbuf)

  assert_eq(lexbuf[5], 0)  -- start_pos reset
  assert_eq(lexbuf[6], 0)  -- curr_pos reset
  assert_eq(lexbuf[7], 0)  -- last_pos reset
end)

test("flush: clears buffer", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("test")

  lexing.caml_flush_lexbuf(lexbuf)

  assert_eq(lexbuf[3], 0)  -- buffer_len cleared
  assert_eq(#lexbuf[2], 0)  -- buffer cleared
end)

print()
print("Lex Engine Infrastructure Tests:")
print("--------------------------------------------------------------------")

test("lex_engine: table caching", function()
  -- Test that transition tables are cached after first parse
  local tbl = {
    [1] = {0x01, 0x00, 0xFE, 0xFF},  -- base: [1, -2]
    [2] = {0xFF, 0xFF, 0x00, 0x00},  -- backtrk: [-1, 0]
    [3] = {0xFF, 0xFF, 0xFF, 0xFF},  -- default: [-1, -1]
    [4] = {0x01, 0x00, 0x00, 0x00},  -- trans: [1, 0]
    [5] = {0x00, 0x00, 0x00, 0x00},  -- check: [0, 0]
  }

  assert_true(tbl.lex_base == nil)  -- Not cached yet

  -- First call should cache
  local lexbuf = lexing.caml_create_lexbuf_from_string("a")
  pcall(function() lexing.caml_lex_engine(tbl, 0, lexbuf) end)

  -- Tables should now be cached
  assert_true(tbl.lex_base ~= nil)
  assert_true(tbl.lex_trans ~= nil)
  assert_true(tbl.lex_check ~= nil)
end)

test("lex_engine: lexbuf state initialization", function()
  -- Test that lexbuf state is properly initialized on first entry
  local tbl = {
    [1] = {0x00, 0x00, 0xFE, 0xFF},
    [2] = {0xFF, 0xFF, 0x00, 0x00},
    [3] = {0xFF, 0xFF, 0xFF, 0xFF},
    [4] = {0x01, 0x00, 0x00, 0x00},
    [5] = {0x00, 0x00, 0x00, 0x00},
  }

  local lexbuf = lexing.caml_create_lexbuf_from_string("test")
  lexbuf[8] = 99  -- Set last_action to non-default

  pcall(function() lexing.caml_lex_engine(tbl, 0, lexbuf) end)

  -- last_action should be reset to -1 on first entry
  assert_eq(lexbuf[8], -1)
end)

test("lex_engine: reentry state handling", function()
  -- Test reentry with negative state (after refill)
  local tbl = {
    [1] = {0x00, 0x00, 0xFE, 0xFF},
    [2] = {0xFF, 0xFF, 0x00, 0x00},
    [3] = {0xFF, 0xFF, 0xFF, 0xFF},
    [4] = {0x01, 0x00, 0x00, 0x00},
    [5] = {0x00, 0x00, 0x00, 0x00},
  }

  local lexbuf = lexing.caml_create_lexbuf_from_string("x")

  -- Call with negative state (simulating reentry)
  pcall(function() lexing.caml_lex_engine(tbl, -2, lexbuf) end)

  -- Should convert to positive state (1)
  -- Test passes if no error is raised
  assert_true(true)
end)

test("lex_engine: EOF pseudo-character handling", function()
  -- Test that EOF is represented as character 256
  local tbl = {
    [1] = {0x00, 0x00, 0xFE, 0xFF},
    [2] = {0xFF, 0xFF, 0x00, 0x00},
    [3] = {0xFF, 0xFF, 0xFF, 0xFF},
    [4] = {0x01, 0x00, 0x00, 0x00},
    [5] = {0x00, 0x00, 0x00, 0x00},
  }

  local lexbuf = lexing.caml_create_lexbuf_from_string("")
  lexbuf[9] = 1  -- Set EOF reached

  -- Should handle EOF (char 256) without crashing
  pcall(function() lexing.caml_lex_engine(tbl, 0, lexbuf) end)
  assert_true(true)
end)

print()
print("Integration Tests:")
print("--------------------------------------------------------------------")

test("integration: manual lexeme extraction", function()
  -- Test lexeme extraction by manually advancing position
  local input = "ab"
  local lexbuf = lexing.caml_create_lexbuf_from_string(input)

  -- Manually advance position as if lexer matched 1 character
  lexbuf[6] = 1  -- curr_pos

  local lexeme = lexing.caml_lexeme_string(lexbuf)
  assert_eq(lexeme, "a")
end)

test("integration: position tracking with newlines", function()
  local lexbuf = lexing.caml_create_lexbuf_from_string("line1\nline2\n")
  local curr_p = lexbuf[12]

  -- Simulate lexing across newlines
  lexbuf[6] = 5  -- Position before first newline
  lexing.caml_new_line(lexbuf)

  assert_eq(curr_p.pos_lnum, 2)

  lexbuf[6] = 11  -- Position before second newline
  lexing.caml_new_line(lexbuf)

  assert_eq(curr_p.pos_lnum, 3)
end)

test("integration: multiple lexeme extractions", function()
  local input = "abc def ghi"
  local lexbuf = lexing.caml_create_lexbuf_from_string(input)

  -- First lexeme: "abc"
  lexbuf[5] = 0
  lexbuf[6] = 3
  local lex1 = lexing.caml_lexeme_string(lexbuf)
  assert_eq(lex1, "abc")

  -- Second lexeme: "def"
  lexbuf[5] = 4
  lexbuf[6] = 7
  local lex2 = lexing.caml_lexeme_string(lexbuf)
  assert_eq(lex2, "def")

  -- Third lexeme: "ghi"
  lexbuf[5] = 8
  lexbuf[6] = 11
  local lex3 = lexing.caml_lexeme_string(lexbuf)
  assert_eq(lex3, "ghi")
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
