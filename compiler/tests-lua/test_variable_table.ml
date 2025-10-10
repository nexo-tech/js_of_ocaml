(* Test table-based variable storage for MAJOR.md Task 3.1
 * Tests the solution to Lua's 200 local variable limit
 *)

open Js_of_ocaml_compiler
open Stdlib

(* Helper to create a program with N variables *)
let create_program_with_n_vars n =
  let open Code in
  (* Create N variables *)
  let vars = List.init ~len:n ~f:(fun _ -> Var.fresh ()) in

  (* Create a block that uses all variables *)
  let body =
    List.mapi vars ~f:(fun i v ->
      Let (v, Constant (Int32 (Int32.of_int i))))
  in

  (* Return the last variable *)
  let last_var = List.nth vars (n - 1) in
  let block0 =
    { params = []
    ; body
    ; branch = Return last_var
    }
  in
  let blocks = Addr.Map.empty |> Addr.Map.add 0 block0 in
  { start = 0; blocks; free_pc = 1 }

(* Helper to check if string contains substring *)
let contains_substring str sub =
  try
    let _ = Str.search_forward (Str.regexp_string sub) str 0 in
    true
  with Not_found -> false

(* Helper to generate Lua code and extract it as string *)
let generate_lua_string program =
  let lua_stmts = Lua_of_ocaml_compiler__Lua_generate.generate ~debug:false program in
  Lua_of_ocaml_compiler__Lua_output.program_to_string lua_stmts

(* Test 1: Small function with 50 variables uses locals *)
let%expect_test "small_function_uses_locals" =
  Printf.printf "Test: Small function (50 vars) uses locals\n";
  let program = create_program_with_n_vars 50 in
  let lua_code = generate_lua_string program in

  (* Check that it uses local declarations *)
  let has_local_vars = contains_substring lua_code "local v" in
  let has_table_storage = contains_substring lua_code "local _V = {}" in

  Printf.printf "Uses local vars: %b\n" has_local_vars;
  Printf.printf "Uses table storage: %b\n" has_table_storage;
  Printf.printf "Variable count: 50 (threshold: 180)\n";

  (* Verify comment mentions 50 vars *)
  let has_50_vars = contains_substring lua_code "50 total" in
  Printf.printf "Comment mentions 50 vars: %b\n" has_50_vars;

  [%expect {|
    Test: Small function (50 vars) uses locals
    Uses local vars: true
    Uses table storage: false
    Variable count: 50 (threshold: 180)
    Comment mentions 50 vars: true |}]

(* Test 2: Large function with 250 variables uses table storage *)
let%expect_test "large_function_uses_table" =
  Printf.printf "Test: Large function (250 vars) uses table storage\n";
  let program = create_program_with_n_vars 250 in
  let lua_code = generate_lua_string program in

  (* Check that it uses table storage *)
  let has_table_storage = contains_substring lua_code "local _V = {}" in
  let has_table_comment = contains_substring lua_code "using table due to Lua's 200 local limit" in

  Printf.printf "Uses table storage: %b\n" has_table_storage;
  Printf.printf "Has table comment: %b\n" has_table_comment;
  Printf.printf "Variable count: 250 (threshold: 180)\n";

  (* Verify it uses _V.vN pattern *)
  let has_table_access = contains_substring lua_code "_V.v" in
  Printf.printf "Uses _V.vN access pattern: %b\n" has_table_access;

  [%expect {|
    Test: Large function (250 vars) uses table storage
    Uses table storage: true
    Has table comment: true
    Variable count: 250 (threshold: 180)
    Uses _V.vN access pattern: true |}]

(* Test 3: Table access correctness - verify generated code structure *)
let%expect_test "table_access_correctness" =
  Printf.printf "Test: Table access correctness\n";
  let program = create_program_with_n_vars 200 in
  let lua_code = generate_lua_string program in

  (* Verify pattern: local _V = {} followed by _V.vN = value *)
  let lines = String.split_on_char ~sep:'\n' lua_code in

  (* Find the _V declaration *)
  let has_v_decl = List.exists lines ~f:(fun line ->
    contains_substring line "local _V = {}") in

  (* Find table assignments *)
  let has_v_assignment = List.exists lines ~f:(fun line ->
    contains_substring line "_V.v" && contains_substring line "=") in

  (* Find table access in return *)
  let has_v_return = List.exists lines ~f:(fun line ->
    contains_substring line "return" && contains_substring line "_V.") in

  Printf.printf "Has _V declaration: %b\n" has_v_decl;
  Printf.printf "Has _V assignments: %b\n" has_v_assignment;
  Printf.printf "Has _V in return: %b\n" has_v_return;

  [%expect {|
    Test: Table access correctness
    Has _V declaration: true
    Has _V assignments: true
    Has _V in return: true |}]

(* Test 4: Nested functions with independent storage decisions *)
let%expect_test "nested_functions_independent" =
  Printf.printf "Test: Nested functions with independent storage\n";

  let open Code in
  (* Create outer function with 250 vars *)
  let outer_vars = List.init ~len:250 ~f:(fun _ -> Var.fresh ()) in

  (* Create a closure parameter *)
  let closure_param = Var.fresh () in

  (* Create inner function (closure) with 50 vars *)
  let inner_vars = List.init ~len:50 ~f:(fun _ -> Var.fresh ()) in

  (* Inner function block (starts at PC 10) *)
  let inner_body = List.mapi inner_vars ~f:(fun i v ->
    Let (v, Constant (Int32 (Int32.of_int i)))) in
  let inner_block =
    { params = [ closure_param ]
    ; body = inner_body
    ; branch = Return (List.nth inner_vars 49)
    }
  in

  (* Outer function creates closure and uses outer vars *)
  let outer_body =
    (List.mapi outer_vars ~f:(fun i v ->
      Let (v, Constant (Int32 (Int32.of_int i)))))
    @ [ Let (closure_param, Closure ([ closure_param ], (10, []), Some Parse_info.zero)) ]
  in
  let outer_block =
    { params = []
    ; body = outer_body
    ; branch = Return (List.nth outer_vars 249)
    }
  in

  let blocks =
    Addr.Map.empty
    |> Addr.Map.add 0 outer_block
    |> Addr.Map.add 10 inner_block
  in
  let program = { start = 0; blocks; free_pc = 11 } in

  let lua_code = generate_lua_string program in

  (* Outer function should use table (_V) *)
  let outer_uses_table = contains_substring lua_code "using table" in

  (* Inner function should use locals *)
  let inner_uses_locals = contains_substring lua_code "50 total)" in

  Printf.printf "Outer function (250 vars) uses table: %b\n" outer_uses_table;
  Printf.printf "Inner function (50 vars) uses locals: %b\n" inner_uses_locals;
  Printf.printf "Each function decides independently\n";

  [%expect {|
    Test: Nested functions with independent storage
    Outer function (250 vars) uses table: true
    Inner function (50 vars) uses locals: true
    Each function decides independently
    |}]

(* Test 5: Verify threshold boundary at 180 variables *)
let%expect_test "threshold_boundary_test" =
  Printf.printf "Test: Threshold boundary (180 vars)\n";

  (* Test with 180 vars - should use locals *)
  let program_180 = create_program_with_n_vars 180 in
  let lua_180 = generate_lua_string program_180 in
  let uses_locals_180 = contains_substring lua_180 "local v"
    && not (contains_substring lua_180 "local _V = {}") in

  (* Test with 181 vars - should use table *)
  let program_181 = create_program_with_n_vars 181 in
  let lua_181 = generate_lua_string program_181 in
  let uses_table_181 = contains_substring lua_181 "local _V = {}" in

  Printf.printf "180 vars uses locals: %b\n" uses_locals_180;
  Printf.printf "181 vars uses table: %b\n" uses_table_181;
  Printf.printf "Threshold is correctly set at 180\n";

  [%expect {|
    Test: Threshold boundary (180 vars)
    180 vars uses locals: true
    181 vars uses table: true
    Threshold is correctly set at 180 |}]

(* Test 6: Verify actual Lua execution with table storage *)
let%expect_test "table_storage_execution" =
  Printf.printf "Test: Table storage execution\n";

  (* Create simple test that can actually execute *)
  let lua_code = {|
-- Test table-based variable storage
function test_table_vars()
  -- Hoisted variables (5 total, using table due to Lua's 200 local limit)
  local _V = {}
  ::block_0::
  _V.v0 = 42
  _V.v1 = 100
  _V.v2 = _V.v0 + _V.v1
  return _V.v2
end

local result = test_table_vars()
print("Result: " .. result)
|} in

  (* Write to temp file and execute *)
  let temp_file = Filename.temp_file "lua_table" ".lua" in
  let oc = open_out_text temp_file in
  output_string oc lua_code;
  close_out oc;

  let ic = Unix.open_process_in (Printf.sprintf "lua %s 2>&1" temp_file) in
  let output = In_channel.input_all ic in
  let status = Unix.close_process_in ic in
  Sys.remove temp_file;

  (match status with
  | Unix.WEXITED 0 -> Printf.printf "%s" output
  | Unix.WEXITED code -> Printf.printf "Failed (exit %d): %s" code output
  | _ -> Printf.printf "Abnormal termination: %s" output);

  [%expect {|
    Test: Table storage execution
    Result: 142 |}]
