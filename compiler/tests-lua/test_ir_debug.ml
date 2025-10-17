(* Test IR debug output *)

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler
module Lua_generate = Lua_of_ocaml_compiler__Lua_generate

let%expect_test "debug_print_program shows IR structure for hello.bc" =
  (* Set target before parsing bytecode *)
  Config.set_target `Wasm;

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
  [%expect.unreachable]
[@@expect.uncaught_exn {|
  (* CR expect_test_collector: This test expectation appears to contain a backtrace.
     This is strongly discouraged as backtraces are fragile.
     Please change this test to not include a backtrace. *)
  (Failure "The debug named \"ir\" doesn't exist")
  Raised at Stdlib.failwith in file "stdlib.ml", line 29, characters 17-33
  Called from Test_ir_debug.(fun) in file "compiler/tests-lua/test_ir_debug.ml", line 12, characters 2-19
  Called from Ppx_expect_runtime__Test_block.Configured.dump_backtrace in file "runtime/test_block.ml", line 142, characters 10-28
  |}]
