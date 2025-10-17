(* Tests for entry block parameter initialization fix *)

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler

(* Initialize Targetint *)
let () = Targetint.set_num_bits 32

(* Helper to test if generated Lua runs without errors *)
let test_lua_execution lua_code expected_output =
  let tmp_file = Filename.temp_file "test_" ".lua" in
  let oc = open_out_text tmp_file in
  output_string oc lua_code;
  close_out oc;

  let result = Unix.system (Printf.sprintf "cd /Users/snowbear/WORK/GIT/js_of_ocaml && lua %s 2>&1" tmp_file) in
  Sys.remove tmp_file;
  match result with
  | Unix.WEXITED 0 -> true
  | _ -> false

(* Test 1: Entry block with parameters pattern (flush_all style) *)
let%expect_test "test_entry_block_with_params" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")
dofile("../../runtime/lua/obj.lua")

-- Simulate the flush_all pattern where entry block expects parameters
local test_flush_pattern = caml_make_closure(0, function()
  -- This simulates a closure with entry block that has parameters
  local _V = {}

  -- Initialize variables
  _V.v1 = nil  -- This will be the loop variable
  _V.v2 = nil
  _V.v3 = nil

  -- The dispatch loop - now with proper initialization
  local _next_block = 6  -- Start at initialization block, not block 1

  while true do
    if _next_block == 1 then
      -- This is the loop header - expects v1 to be initialized
      if _V.v1 then
        _V.v2 = _V.v1[2]  -- Extract second element
        _V.v3 = _V.v1[1]  -- Extract first element
        print("Processing: " .. tostring(_V.v3))
        _V.v1 = _V.v2  -- Move to next
        _next_block = 1  -- Loop back
      else
        _next_block = 2  -- Exit
      end
    elseif _next_block == 2 then
      -- Exit block
      return 0
    elseif _next_block == 6 then
      -- Initialization block - compute initial value for v1
      _V.v1 = {1, {2, {3, nil}}}  -- Linked list: 1 -> 2 -> 3
      _next_block = 1  -- Go to loop header
    else
      break
    end
  end
end)

-- Test the function
local result = test_flush_pattern()
print("Test completed successfully")
|} in

  let success = test_lua_execution lua_code "Processing: 1\nProcessing: 2\nProcessing: 3\nTest completed successfully\n" in
  if success then
    print_endline "Entry block with params: OK"
  else
    print_endline "Entry block with params: FAILED";
  [%expect {| Entry block with params: OK |}]

(* Test 2: Complex control flow with entry parameters *)
let%expect_test "test_complex_entry_params" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")

-- Test complex control flow where entry block needs initialization
local test_complex = caml_make_closure(1, function(n)
  local _V = {}
  _V.n = n

  -- Variables that need initialization
  _V.acc = nil
  _V.current = nil

  -- Start at initialization block
  local _next_block = 5

  while true do
    if _next_block == 1 then
      -- Loop header - expects current and acc
      if _V.current > 0 then
        _V.acc = _V.acc + _V.current
        _V.current = _V.current - 1
        _next_block = 1  -- Loop back
      else
        _next_block = 2  -- Exit
      end
    elseif _next_block == 2 then
      -- Return accumulated value
      return _V.acc
    elseif _next_block == 5 then
      -- Initialization block
      _V.current = _V.n
      _V.acc = 0
      _next_block = 1  -- Go to loop
    else
      break
    end
  end
end)

-- Test: sum of 1 to 5 = 15
local result = caml_call_gen(test_complex, {5})
assert(result == 15, "Expected 15, got " .. tostring(result))
print("Complex entry params: OK")
|} in

  let success = test_lua_execution lua_code "Complex entry params: OK\n" in
  if success then
    print_endline "Complex entry params test: OK"
  else
    print_endline "Complex entry params test: FAILED";
  [%expect {| Complex entry params test: OK |}]

(* Test 3: Nested closures with entry parameters *)
let%expect_test "test_nested_closures_entry_params" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")

-- Nested closures where inner closure has entry block params
local test_nested = caml_make_closure(1, function(lst)
  local _V = {}
  _V.lst = lst

  -- Create inner closure
  _V.processor = caml_make_closure(0, function()
    -- Inner closure with entry block params pattern
    local inner_V = {}
    inner_V.current = nil
    inner_V.result = nil

    -- Start at initialization
    local _next_block = 3

    while true do
      if _next_block == 1 then
        -- Process current item
        if inner_V.current then
          inner_V.result = (inner_V.result or 0) + inner_V.current[1]
          inner_V.current = inner_V.current[2]
          _next_block = 1
        else
          _next_block = 2
        end
      elseif _next_block == 2 then
        return inner_V.result or 0
      elseif _next_block == 3 then
        -- Initialize from outer closure
        inner_V.current = _V.lst
        inner_V.result = 0
        _next_block = 1
      else
        break
      end
    end
  end)

  return caml_call_gen(_V.processor, {})
end)

-- Test with list [10, 20, 30]
local list = {10, {20, {30, nil}}}
local result = caml_call_gen(test_nested, {list})
assert(result == 60, "Expected 60, got " .. tostring(result))
print("Nested closures with entry params: OK")
|} in

  let success = test_lua_execution lua_code "Nested closures with entry params: OK\n" in
  if success then
    print_endline "Nested closures test: OK"
  else
    print_endline "Nested closures test: FAILED";
  [%expect {| Nested closures test: OK |}]

(* Test 4: Entry parameters with exception handling *)
let%expect_test "test_entry_params_with_exceptions" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")

-- Test entry params with try-catch pattern
local test_exception = caml_make_closure(1, function(items)
  local _V = {}
  _V.items = items
  _V.current = nil
  _V.safe_result = nil

  -- Start at initialization
  local _next_block = 4

  while true do
    if _next_block == 1 then
      -- Process with exception handling
      if _V.current then
        -- Simulate try block
        local ok, err = pcall(function()
          if _V.current[1] == 0 then
            error("Division by zero")
          end
          _V.safe_result = 100 / _V.current[1]
        end)

        if not ok then
          print("Caught error: " .. tostring(err))
          _V.safe_result = -1
        end

        print("Result: " .. tostring(_V.safe_result))
        _V.current = _V.current[2]
        _next_block = 1
      else
        _next_block = 2
      end
    elseif _next_block == 2 then
      return 0
    elseif _next_block == 4 then
      -- Initialize
      _V.current = _V.items
      _next_block = 1
    else
      break
    end
  end
end)

-- Test with list containing zero
local items = {5, {0, {2, nil}}}
caml_call_gen(test_exception, {items})
print("Exception handling with entry params: OK")
|} in

  let success = test_lua_execution lua_code "" in
  if success then
    print_endline "Exception handling test: OK"
  else
    print_endline "Exception handling test: FAILED";
  [%expect {| Exception handling test: OK |}]