(* Test IR debug output *)

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler
module Lua_generate = Lua_of_ocaml_compiler__Lua_generate

let%expect_test "debug_print_program shows IR structure for hello.bc" =
  (* Enable IR debug flag *)
  Debug.enable "ir";

  (* Load hello.bc *)
  let bytecode_file = "../../examples/hello_lua/hello.bc" in
  let ic = open_in_bin bytecode_file in
  let parsed =
    Parse_bytecode.from_exe
      ~includes:[]
      ~linkall:false
      ~link_info:false
      ~include_cmis:false
      ~debug:false
      ic
  in
  close_in ic;

  let program = parsed.code in

  (* Call debug_print_program - output goes to stderr *)
  Lua_generate.debug_print_program program;

  (* Print a marker to stdout so we know the test ran *)
  Printf.printf "Debug output printed to stderr\n";
  Printf.printf "Entry block: %s\n" (Code.Addr.to_string program.Code.start);
  Printf.printf "Total blocks: %d\n" (Code.Addr.Map.cardinal program.Code.blocks);

  (* Note: stderr output won't show in expect test output *)
  [%expect {|
    Debug output printed to stderr
    Entry block: 0
    Total blocks: 356
  |}]
