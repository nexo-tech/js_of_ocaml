(* Test Printf functionality after loop block args fix *)

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler
open Unix

(* Initialize Targetint *)
let () = Targetint.set_num_bits 32

(* Helper to compile OCaml to Lua and run it *)
let compile_and_run_ocaml code expected_output =
  (* Write OCaml code to temp file *)
  let ml_file = Filename.temp_file "test_" ".ml" in
  let bc_file = Filename.temp_file "test_" ".bc" in
  let lua_file = Filename.temp_file "test_" ".lua" in

  let oc = open_out_text ml_file in
  output_string oc code;
  close_out oc;

  try
    (* Compile to bytecode *)
    let compile_result = Unix.system (Printf.sprintf "ocamlc -g %s -o %s 2>&1" ml_file bc_file) in
    if compile_result <> Unix.WEXITED 0 then
      failwith "OCaml compilation failed";

    (* Parse bytecode *)
    let ch = open_in_bin bc_file in
    let _magic = Bytecode.Bytes.read ch in
    let _index = Bytecode.Toc.read ch in
    let prim_orig = Bytecode.Toc.Primitive.read ch in
    let crcs = Bytecode.Toc.Crcs.read ch in
    let data = Bytecode.Toc.Data.read ch in
    let code = Bytecode.Toc.Code.read ch in
    close_in ch;

    (* Process the bytecode *)
    let code = Bytecode.Code.parse code in
    let data = Bytecode.Data.parse ~crcs ~includes:[] ~create_empty_units:true data in

    let module Driver = Js_of_ocaml_compiler.Driver in
    let module Config = Js_of_ocaml_compiler.Config in

    (* Build primitive table *)
    let symtable = Bytecode.Symtable.read code in
    let primitive_table = Array.of_list prim_orig in

    (* Generate IR *)
    let start = Driver.generate
      ~warn_on_unhandled_effect:(fun _ -> ())
      code
    in

    let start, closures = Driver.link ~standalone:true ~linkall:false start [] in

    (* Create the program *)
    let program = {
      Code.start = start.Code.start;
      Code.blocks = closures;
      Code.free_vars = Var.Set.empty
    } in

    (* Generate Lua code *)
    let lua_ctx = Lua_generate.make_context_with_program ~debug:false program in
    let lua_stmts = Lua_generate.f program in

    (* Generate runtime linking *)
    let runtime_files = Lua_link.get_required_runtime lua_stmts in

    (* Write Lua output *)
    let oc = open_out_text lua_file in

    (* Include necessary runtime files *)
    List.iter runtime_files ~f:(fun file ->
      Printf.fprintf oc "-- Runtime: %s\n" file;
      Printf.fprintf oc "dofile(\"../../runtime/lua/%s\")\n" file
    );
    Printf.fprintf oc "\n-- Generated code:\n";

    (* Output the generated Lua code *)
    let lua_ast = L.Block lua_stmts in
    Lua_output.program (Format.formatter_of_out_channel oc) lua_ast;
    close_out oc;

    (* Run the Lua code *)
    let run_result = Unix.system (Printf.sprintf "cd /Users/snowbear/WORK/GIT/js_of_ocaml && lua %s 2>&1" lua_file) in

    (* Clean up *)
    Sys.remove ml_file;
    Sys.remove bc_file;
    Sys.remove lua_file;

    run_result = Unix.WEXITED 0

  with e ->
    (* Clean up on error *)
    (try Sys.remove ml_file with _ -> ());
    (try Sys.remove bc_file with _ -> ());
    (try Sys.remove lua_file with _ -> ());
    Printf.eprintf "Error: %s\n" (Printexc.to_string e);
    false

(* Test 1: Simple print_int with loop (flush_all pattern) *)
let%expect_test "test_print_int_works" =
  let ocaml_code = {|
let () =
  print_int 42;
  print_newline ()
|} in

  let success = compile_and_run_ocaml ocaml_code "42\n" in
  if success then
    print_endline "print_int with flush: OK"
  else
    print_endline "print_int with flush: FAILED";

  [%expect {| print_int with flush: OK |}]

(* Test 2: Printf with formatting (the actual issue) *)
let%expect_test "test_printf_works" =
  let ocaml_code = {|
let () = Printf.printf "Hello %d\n" 42
|} in

  let success = compile_and_run_ocaml ocaml_code "Hello 42\n" in
  if success then
    print_endline "Printf with format: OK"
  else
    print_endline "Printf with format: FAILED";

  [%expect {| Printf with format: OK |}]

(* Test 3: Recursive function (generates loops) *)
let%expect_test "test_recursive_function" =
  let ocaml_code = {|
let rec sum n acc =
  if n <= 0 then acc
  else sum (n - 1) (acc + n)

let () =
  let result = sum 5 0 in
  Printf.printf "Sum 1-5 = %d\n" result
|} in

  let success = compile_and_run_ocaml ocaml_code "Sum 1-5 = 15\n" in
  if success then
    print_endline "Recursive function: OK"
  else
    print_endline "Recursive function: FAILED";

  [%expect {| Recursive function: OK |}]

(* Test 4: Multiple printfs (stress test for flush_all) *)
let%expect_test "test_multiple_printf" =
  let ocaml_code = {|
let () =
  Printf.printf "Line 1: %d\n" 1;
  Printf.printf "Line 2: %s\n" "test";
  Printf.printf "Line 3: %d + %d = %d\n" 2 3 5
|} in

  let success = compile_and_run_ocaml ocaml_code "Line 1: 1\nLine 2: test\nLine 3: 2 + 3 = 5\n" in
  if success then
    print_endline "Multiple printf: OK"
  else
    print_endline "Multiple printf: FAILED";

  [%expect {| Multiple printf: OK |}]