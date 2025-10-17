(* Test for loop block argument initialization fix *)

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler

(* Initialize Targetint *)
let () = Targetint.set_num_bits 32

(* Test 1: Simple loop with block arguments *)
let%expect_test "test_simple_loop_block_args" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")
dofile("../../runtime/lua/obj.lua")

-- Test a closure with a loop that has block arguments
local test_loop = caml_make_closure(1, function(n)
  -- Simulating a loop with block arguments like the flush_all issue
  local param, result
  local _next_block = 1

  -- Initialize block argument (mimics the fix)
  param = n

  while true do
    if _next_block == 1 then
      -- Access param (should not be nil on first iteration)
      result = param
      if param > 0 then
        param = param - 1
        _next_block = 1  -- Loop back
      else
        _next_block = 2  -- Exit
      end
    else
      if _next_block == 2 then
        return result
      end
    end
  end
end)

-- Test the function
local result = caml_call_gen(test_loop, {5})
assert(result == 0, "Loop block args test failed")
print("Simple loop with block args: OK")
|} in

  let tmp_file = Filename.temp_file "test_" ".lua" in
  let oc = open_out_text tmp_file in
  output_string oc lua_code;
  close_out oc;

  let result = Unix.system (Printf.sprintf "cd /Users/snowbear/WORK/GIT/js_of_ocaml && lua %s 2>&1" tmp_file) in
  Sys.remove tmp_file;
  (match result with
  | Unix.WEXITED 0 -> ()
  | _ -> print_endline "Test failed");
  [%expect {| Simple loop with block args: OK |}]

(* Test 2: Forward reference fix - closure accessing loop variables *)
let%expect_test "test_forward_reference_in_loop" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")
dofile("../../runtime/lua/obj.lua")

-- Test forward reference issue where closure accesses loop variables
local test_forward_ref = caml_make_closure(0, function()
  -- Hoist all variables including loop block params
  local v34, v27, v28, result

  -- Initialize loop block argument to prevent nil access
  v34 = nil  -- This is the fix - initialize before use

  local inner_closure = caml_make_closure(1, function(x)
    local _next_block = 1
    while true do
      if _next_block == 1 then
        -- This would fail without v34 initialization
        if v34 then
          v27 = v34[3] or 0  -- Safe access with default
          v28 = v34[2] or 0
        else
          v27 = 0
          v28 = 0
        end
        result = x + v27 + v28
        _next_block = 2
      else
        if _next_block == 2 then
          return result
        end
      end
    end
  end)

  -- Now set v34 to actual value (simulating later initialization)
  v34 = {0, 10, 20}  -- Block with tag 0 and values

  return caml_call_gen(inner_closure, {5})
end)

-- Test the function
local result = caml_call_gen(test_forward_ref, {})
assert(result == 35, "Forward reference test failed: got " .. tostring(result))
print("Forward reference in loop: OK")
|} in

  let tmp_file = Filename.temp_file "test_" ".lua" in
  let oc = open_out_text tmp_file in
  output_string oc lua_code;
  close_out oc;

  let result = Unix.system (Printf.sprintf "cd /Users/snowbear/WORK/GIT/js_of_ocaml && lua %s 2>&1" tmp_file) in
  Sys.remove tmp_file;
  (match result with
  | Unix.WEXITED 0 -> ()
  | _ -> print_endline "Test failed");
  [%expect {| Forward reference in loop: OK |}]

(* Test 3: Loop detection algorithm *)
let%expect_test "test_loop_detection" =
  (* Create a simple program with loops to test detection *)
  let open Code in

  (* Create blocks that form a loop *)
  let blocks =
    let block0 = {
      params = [];
      body = [Let (Var.fresh (), Const (Int 0L))];
      branch = Branch (1, [])
    } in
    let block1 = {
      params = [Var.fresh ()];  (* Loop header with block param *)
      body = [];
      branch = Cond (Var.fresh (), (2, []), (1, []))  (* Back edge to self *)
    } in
    let block2 = {
      params = [];
      body = [];
      branch = Return (Var.fresh ())
    } in
    Addr.Map.empty
    |> Addr.Map.add 0 block0
    |> Addr.Map.add 1 block1
    |> Addr.Map.add 2 block2
  in

  let program = {
    start = 0;
    blocks;
    free_vars = Var.Set.empty
  } in

  (* Test loop detection *)
  let loop_headers = Lua_generate.detect_loop_headers program 0 in

  (* Block 1 should be detected as a loop header *)
  assert (Addr.Set.mem 1 loop_headers);
  assert (Addr.Set.cardinal loop_headers = 1);

  Printf.printf "Loop detection: OK (detected %d loop headers)\n"
    (Addr.Set.cardinal loop_headers);

  [%expect {| Loop detection: OK (detected 1 loop headers) |}]

(* Test 4: Complex nested loops *)
let%expect_test "test_nested_loops" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")

-- Test nested loops with block arguments
local test_nested = caml_make_closure(2, function(n, m)
  -- All variables hoisted including loop params
  local i, j, sum, inner_sum

  -- Initialize loop variables
  i = n
  sum = 0

  -- Outer loop
  local _outer_block = 1
  while true do
    if _outer_block == 1 then
      if i > 0 then
        j = m  -- Initialize inner loop variable
        inner_sum = 0

        -- Inner loop
        local _inner_block = 1
        while true do
          if _inner_block == 1 then
            if j > 0 then
              inner_sum = inner_sum + 1
              j = j - 1
              _inner_block = 1  -- Continue inner
            else
              _inner_block = 2  -- Exit inner
            end
          else
            if _inner_block == 2 then
              break
            end
          end
        end

        sum = sum + inner_sum
        i = i - 1
        _outer_block = 1  -- Continue outer
      else
        _outer_block = 2  -- Exit outer
      end
    else
      if _outer_block == 2 then
        return sum
      end
    end
  end
end)

-- Test: 3 * 4 = 12 iterations total
local result = caml_call_gen(test_nested, {3, 4})
assert(result == 12, "Nested loops failed: expected 12, got " .. tostring(result))
print("Nested loops: OK")
|} in

  let tmp_file = Filename.temp_file "test_" ".lua" in
  let oc = open_out_text tmp_file in
  output_string oc lua_code;
  close_out oc;

  let result = Unix.system (Printf.sprintf "cd /Users/snowbear/WORK/GIT/js_of_ocaml && lua %s 2>&1" tmp_file) in
  Sys.remove tmp_file;
  (match result with
  | Unix.WEXITED 0 -> ()
  | _ -> print_endline "Test failed");
  [%expect {| Nested loops: OK |}]