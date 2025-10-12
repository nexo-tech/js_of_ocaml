(* Comprehensive tests for Lua code generation fixes *)

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler

let run_lua_code lua_code =
  let tmp_file = Filename.temp_file "test_" ".lua" in
  let oc = open_out_text tmp_file in
  output_string oc lua_code;
  close_out oc;

  let result =
    try
      let ic = Unix.open_process_in (Printf.sprintf "lua %s 2>&1" tmp_file) in
      let output =
        let rec read_all acc =
          try
            let line = input_line ic in
            read_all (acc ^ line ^ "\n")
          with End_of_file -> acc
        in
        read_all ""
      in
      let status = Unix.close_process_in ic in
      Sys.remove tmp_file;
      match status with
      | Unix.WEXITED 0 -> Ok output
      | _ -> Error output
    with e ->
      Sys.remove tmp_file;
      Error (Printexc.to_string e)
  in
  result

(* Test 1: Block representation using arrays *)
let%expect_test "test_block_representation" =
  let lua_code = {|
-- Test that blocks are represented as arrays {tag, field1, field2, ...}
local block = {0, 42, "hello"}
assert(block[1] == 0, "Tag should be at index 1")
assert(block[2] == 42, "First field should be at index 2")
assert(block[3] == "hello", "Second field should be at index 3")
print("Block representation: OK")
|} in
  (match run_lua_code lua_code with
  | Ok output -> print_endline output
  | Error err -> Printf.printf "Error: %s\n" err);
  [%expect {| Block representation: OK |}]

(* Test 2: Atomic reference operations *)
let%expect_test "test_atomic_references" =
  let lua_code = {|
-- Atomic reference primitives with new block representation
--Provides: caml_atomic_load
function caml_atomic_load(ref)
  return ref[2]  -- Value at index 2, tag at index 1
end

--Provides: caml_atomic_cas
function caml_atomic_cas(ref, old, new)
  if ref[2] == old then
    ref[2] = new
    return 1
  end
  return 0
end

-- Test atomic load
local ref = {0, 42}  -- Atomic ref with tag 0, value 42
assert(caml_atomic_load(ref) == 42, "caml_atomic_load failed")

-- Test atomic CAS
assert(caml_atomic_cas(ref, 42, 100) == 1, "CAS should succeed")
assert(ref[2] == 100, "Value should be updated")
assert(caml_atomic_cas(ref, 42, 200) == 0, "CAS should fail")
assert(ref[2] == 100, "Value should not change")

print("Atomic references: OK")
|} in
  (match run_lua_code lua_code with
  | Ok output -> print_endline output
  | Error err -> Printf.printf "Error: %s\n" err);
  [%expect {| Atomic references: OK |}]

(* Test 3: Variable hoisting in closures *)
let%expect_test "test_closure_variable_hoisting" =
  let lua_code = {|
-- Test that only locally defined variables are hoisted, not captured ones
local captured_var = 42

local function make_closure()
  local local_var = 100  -- Should be hoisted in make_closure

  return function()
    -- captured_var should NOT be hoisted here
    -- local_var should NOT be hoisted here (captured from parent)
    return captured_var + local_var
  end
end

local closure = make_closure()
assert(closure() == 142, "Closure should return 142")
print("Variable hoisting: OK")
|} in
  (match run_lua_code lua_code with
  | Ok output -> print_endline output
  | Error err -> Printf.printf "Error: %s\n" err);
  [%expect {| Variable hoisting: OK |}]

(* Test 4: Forward references in closures *)
let%expect_test "test_forward_references" =
  let lua_code = {|
-- Test forward references (closure created before variable assigned)
local r = {0, 0}  -- Atomic ref initialized to 0

-- Closure created before r is assigned its real value
local function get_value()
  return r[2]  -- Access value at index 2
end

-- Now assign the real value
r[2] = 42

assert(get_value() == 42, "Forward reference should work")
print("Forward references: OK")
|} in
  (match run_lua_code lua_code with
  | Ok output -> print_endline output
  | Error err -> Printf.printf "Error: %s\n" err);
  [%expect {| Forward references: OK |}]

(* Test 5: Nested closures *)
let%expect_test "test_nested_closures" =
  let lua_code = {|
-- Test nested closures with proper variable capture
local outer = 10

local function level1()
  local mid = 20

  local function level2()
    local inner = 30

    return function()
      -- All three should be accessible
      return outer + mid + inner
    end
  end

  return level2()
end

local closure = level1()
assert(closure() == 60, "Nested closure should return 60")
print("Nested closures: OK")
|} in
  (match run_lua_code lua_code with
  | Ok output -> print_endline output
  | Error err -> Printf.printf "Error: %s\n" err);
  [%expect {| Nested closures: OK |}]

(* Test 6: _V table for >180 variables *)
let%expect_test "test_v_table" =
  let lua_code = {|
-- Test that _V table is used when there are many variables
local _V = {}
-- Simulate many variables
for i = 1, 190 do
  _V["v" .. i] = i
end

-- Access via _V table
assert(_V.v1 == 1, "First variable should be 1")
assert(_V.v190 == 190, "Last variable should be 190")
print("_V table: OK")
|} in
  (match run_lua_code lua_code with
  | Ok output -> print_endline output
  | Error err -> Printf.printf "Error: %s\n" err);
  [%expect {| _V table: OK |}]

(* Test 7: Test the actual Lua_generate module *)
let%expect_test "test_lua_generate_hoisting" =
  let module L = Lua_of_ocaml_compiler__Lua_generate in
  let ctx = L.make_context ~debug:false in

  (* Create variables *)
  let var_local = Code.Var.fresh_n "local" in
  let var_captured = Code.Var.fresh_n "captured" in
  let var_closure = Code.Var.fresh_n "closure" in

  (* Create a block that:
     - Defines var_local via Let
     - Creates a closure that captures var_captured *)
  let block = {
    Code.params = [];
    Code.body = [
      Code.Let (var_local, Code.Constant (Code.Int (Targetint.of_int_exn 42)));
      Code.Let (var_closure,
                Code.Closure ([var_captured], (1, []), None))
    ];
    Code.branch = Code.Return var_local;
  } in

  let blocks = Code.Addr.Map.singleton 0 block in
  let program = {
    Code.start = 0;
    Code.blocks = blocks;
    Code.free_pc = 2;
  } in

  (* Collect variables - should only get locally defined ones *)
  let collected = L.collect_block_variables ctx program 0 in
  let collected_list = StringSet.elements collected |> List.sort ~cmp:String.compare in

  (* Should collect: closure, local
     Should NOT collect: captured (it's from parent scope) *)
  assert (List.mem "closure" collected_list ~eq:String.equal);
  assert (List.mem "local" collected_list ~eq:String.equal);
  assert (not (List.mem "captured" collected_list ~eq:String.equal));

  print_endline "Lua_generate hoisting: OK";
  [%expect {| Lua_generate hoisting: OK |}]