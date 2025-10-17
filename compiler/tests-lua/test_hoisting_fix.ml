(* Test to verify variable hoisting fix in Lua code generator *)

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler

(* Test that collect_block_variables only collects locally defined variables *)
let%expect_test "test_collect_block_variables_only_local" =
  let module L = Lua_of_ocaml_compiler__Lua_generate in
  let ctx = L.make_context ~debug:false in

  (* Create test variables *)
  let var_defined = Code.Var.fresh_n "defined" in
  let var_captured = Code.Var.fresh_n "captured" in
  let var_assigned = Code.Var.fresh_n "assigned" in

  (* Create a block with various types of variables *)
  let block = {
    Code.params = [];
    Code.body = [
      (* Variable defined via Let - should be collected *)
      Code.Let (var_defined, Code.Constant (Code.Int (Targetint.of_int_exn 1)));
      (* Variable assigned - should be collected *)
      Code.Assign (var_assigned, var_captured);
      (* Closure capturing var_captured - var_captured should NOT be collected *)
      Code.Let (Code.Var.fresh_n "closure",
                Code.Closure ([var_captured], (1, []), None));
    ];
    Code.branch = Code.Return var_defined;
  } in

  let blocks = Code.Addr.Map.singleton 0 block in
  let program = {
    Code.start = 0;
    Code.blocks = blocks;
    Code.free_pc = 2;
  } in

  (* Collect variables for this block *)
  let (defined_vars, free_vars) = L.collect_block_variables ctx program 0 in
  let collected = StringSet.union defined_vars free_vars in
  let collected_list = StringSet.elements collected |> List.sort ~cmp:String.compare in

  (* Print collected variables *)
  Format.printf "Collected variables: [%s]\n"
    (String.concat ~sep:"; " collected_list);

  (* We expect: assigned, closure, defined
     We do NOT expect: captured (it's from parent scope) *)
  [%expect {| Collected variables: [assigned; closure; defined] |}]

(* Test that generate_expr correctly creates blocks with array format *)
let%expect_test "test_block_generation_array_format" =
  let module L = Lua_of_ocaml_compiler__Lua_generate in
  let module LA = Lua_of_ocaml_compiler__Lua_ast in
  let ctx = L.make_context ~debug:false in

  (* Create a block expression in the IR *)
  let var = Code.Var.fresh_n "hello" in
  let block_expr = Code.Block (0, [|var|], Code.NotArray, Code.Immutable) in

  (* Generate Lua AST for the block *)
  let result = L.generate_expr ctx block_expr in

  (* Check that it's generated as an array {0, var} *)
  (match result with
  | LA.Table entries ->
      assert (List.length entries = 2);  (* tag + 1 field *)
      print_endline "Block generation creates array format: OK"
  | _ -> assert false);
  [%expect {| Block generation creates array format: OK |}]

(* Test that field access generates correct indices *)
let%expect_test "test_field_expr_correct_indexing" =
  let module L = Lua_of_ocaml_compiler__Lua_generate in
  let module LA = Lua_of_ocaml_compiler__Lua_ast in
  let ctx = L.make_context ~debug:false in

  (* Create a field access expression *)
  let var = Code.Var.fresh_n "block" in
  let field_expr = Code.Field (var, 0, Code.Non_float) in

  (* Generate Lua AST for field access *)
  let result = L.generate_expr ctx field_expr in

  (* Should generate block[2] for field 0 (tag at index 1) *)
  (match result with
  | LA.Index (_, LA.Number idx) ->
      assert (String.equal idx "2");  (* Field 0 -> index 2 *)
      print_endline "Field access generates index 2 for field 0: OK"
  | _ -> assert false);
  [%expect {| Field access generates index 2 for field 0: OK |}]