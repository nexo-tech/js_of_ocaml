(* Comprehensive tests for closure handling in Lua backend *)

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler

(* Initialize Targetint *)
let () = Targetint.set_num_bits 32

(* Test 1: Basic closure creation and calling *)
let%expect_test "test_basic_closure" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")

-- Test basic closure creation
local add5 = caml_make_closure(1, function(x)
  return x + 5
end)

-- Test calling with exact arity
local result = caml_call_gen(add5, {10})
assert(result == 15, "Basic closure call failed")
print("Basic closure: OK")
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
  [%expect {| Basic closure: OK |}]

(* Test 2: Partial application *)
let%expect_test "test_partial_application" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")

-- Test partial application
local add = caml_make_closure(2, function(x, y)
  return x + y
end)

-- Apply with 1 argument (partial application)
local add5 = caml_call_gen(add, {5})

-- Check that add5 has arity 1
assert(add5.l == 1, "Partial application should have arity 1")

-- Apply the partial with second argument
local result = caml_call_gen(add5, {10})
assert(result == 15, "Partial application failed")
print("Partial application: OK")
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
  [%expect {| Partial application: OK |}]

(* Test 3: Over-application *)
let%expect_test "test_over_application" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")

-- Test over-application
local make_adder = caml_make_closure(1, function(x)
  return caml_make_closure(1, function(y)
    return x + y
  end)
end)

-- Call with 2 arguments (over-application)
local result = caml_call_gen(make_adder, {5, 10})
assert(result == 15, "Over-application failed")
print("Over-application: OK")
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
  [%expect {| Over-application: OK |}]

(* Test 4: Closures stored in blocks *)
let%expect_test "test_closure_in_block" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")

-- Test closures stored in blocks (like OCaml variants)
local add5 = caml_make_closure(1, function(x)
  return x + 5
end)

-- Store closure in a block (variant with tag 1 and closure as field)
local block = {1, add5}

-- Extract closure from block
local extracted = block[2]

-- Call the extracted closure
local result = caml_call_gen(extracted, {10})
assert(result == 15, "Closure from block failed")
print("Closure in block: OK")
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
  [%expect {| Closure in block: OK |}]

(* Test 5: Complex nested partial applications *)
let%expect_test "test_nested_partial" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")

-- Test complex nested partial applications
local add3 = caml_make_closure(3, function(x, y, z)
  return x + y + z
end)

-- Apply one at a time
local f1 = caml_call_gen(add3, {10})
assert(f1.l == 2, "First partial should have arity 2")

local f2 = caml_call_gen(f1, {20})
assert(f2.l == 1, "Second partial should have arity 1")

local result = caml_call_gen(f2, {30})
assert(result == 60, "Nested partial application failed")
print("Nested partial: OK")
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
  [%expect {| Nested partial: OK |}]

(* Test 6: Verify closure metatable *)
let%expect_test "test_closure_metatable" =
  let lua_code = {|
-- Load runtime
dofile("../../runtime/lua/closure.lua")
dofile("../../runtime/lua/fun.lua")

-- Test closure metatable
local add = caml_make_closure(2, function(x, y)
  return x + y
end)

-- Check metatable exists and has __closure marker
local mt = getmetatable(add)
assert(mt ~= nil, "Closure should have metatable")
assert(mt.__closure == true, "Metatable should have __closure marker")

-- Test that closure is callable via metatable
local result = add(5, 10)
assert(result == 15, "Direct call via metatable failed")
print("Closure metatable: OK")
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
  [%expect {| Closure metatable: OK |}]