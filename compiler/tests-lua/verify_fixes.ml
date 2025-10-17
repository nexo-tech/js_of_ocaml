(* Verify the critical fixes are working *)

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler

let () =
  (* Initialize Targetint for 32-bit *)
  Targetint.set_num_bits 32;
  print_endline "Testing Lua code generation fixes...";
  print_newline ()

(* Test 1: Variable hoisting only collects locally defined variables *)
let test_variable_hoisting () =
  let module L = Lua_of_ocaml_compiler__Lua_generate in
  let ctx = L.make_context ~debug:false in

  let var_local = Code.Var.fresh_n "local_var" in
  let var_captured = Code.Var.fresh_n "captured_var" in
  let var_closure = Code.Var.fresh_n "closure" in

  let block = {
    Code.params = [];
    Code.body = [
      Code.Let (var_local, Code.Constant (Code.Int (Targetint.of_int_exn 1)));
      Code.Assign (var_local, var_captured);  (* Assign captures var_captured *)
      Code.Let (var_closure,
                Code.Closure ([var_captured], (1, []), None));  (* Closure captures var_captured *)
    ];
    Code.branch = Code.Return var_local;
  } in

  let blocks = Code.Addr.Map.singleton 0 block in
  let program = {
    Code.start = 0;
    Code.blocks = blocks;
    Code.free_pc = 2;
  } in

  let (defined_vars, free_vars) = L.collect_block_variables ctx program 0 in
  let collected = StringSet.union defined_vars free_vars in
  let collected_list = StringSet.elements collected in

  (* Should only have local_var and closure, NOT captured_var *)
  let has_local = List.mem "local_var" collected_list ~eq:String.equal in
  let has_closure = List.mem "closure" collected_list ~eq:String.equal in
  let has_captured = List.mem "captured_var" collected_list ~eq:String.equal in

  if has_local && has_closure && not has_captured then
    print_endline "✓ Variable hoisting: Only locally defined variables collected"
  else begin
    print_endline "✗ Variable hoisting FAILED:";
    Printf.printf "  Collected: [%s]\n" (String.concat ~sep:"; " collected_list);
    Printf.printf "  has_local=%b, has_closure=%b, has_captured=%b (should be true,true,false)\n"
      has_local has_closure has_captured
  end

(* Test 2: Block generation creates array format *)
let test_block_generation () =
  let module L = Lua_of_ocaml_compiler__Lua_generate in
  let module LA = Lua_of_ocaml_compiler__Lua_ast in
  let ctx = L.make_context ~debug:false in

  let var = Code.Var.fresh_n "field_value" in
  let block_expr = Code.Block (0, [|var|], Code.NotArray, Code.Immutable) in

  let result = L.generate_expr ctx block_expr in

  (match result with
  | LA.Table entries ->
      if List.length entries = 2 then  (* tag + 1 field *)
        print_endline "✓ Block generation: Creates array format {tag, field}"
      else
        Printf.printf "✗ Block generation FAILED: Expected 2 entries, got %d\n"
          (List.length entries)
  | _ ->
      print_endline "✗ Block generation FAILED: Did not generate Table")

(* Test 3: Field access generates correct indices *)
let test_field_access () =
  let module L = Lua_of_ocaml_compiler__Lua_generate in
  let module LA = Lua_of_ocaml_compiler__Lua_ast in
  let ctx = L.make_context ~debug:false in

  let var = Code.Var.fresh_n "block" in

  (* Test field 0 -> index 2 *)
  let field0 = Code.Field (var, 0, Code.Non_float) in
  let result0 = L.generate_expr ctx field0 in

  (match result0 with
  | LA.Index (_, LA.Number idx) when String.equal idx "2" ->
      print_endline "✓ Field access: field[0] generates index 2"
  | LA.Index (_, LA.Number idx) ->
      Printf.printf "✗ Field access FAILED: field[0] generated index %s, expected 2\n" idx
  | _ ->
      print_endline "✗ Field access FAILED: Did not generate Index");

  (* Test field 1 -> index 3 *)
  let field1 = Code.Field (var, 1, Code.Non_float) in
  let result1 = L.generate_expr ctx field1 in

  (match result1 with
  | LA.Index (_, LA.Number idx) when String.equal idx "3" ->
      print_endline "✓ Field access: field[1] generates index 3"
  | LA.Index (_, LA.Number idx) ->
      Printf.printf "✗ Field access FAILED: field[1] generated index %s, expected 3\n" idx
  | _ ->
      print_endline "✗ Field access FAILED: Did not generate Index")

(* Run all tests *)
let () =
  test_variable_hoisting ();
  test_block_generation ();
  test_field_access ();
  print_newline ();
  print_endline "Tests completed."