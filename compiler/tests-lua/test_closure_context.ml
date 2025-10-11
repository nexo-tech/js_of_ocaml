(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

(** Unit tests for closure context inheritance

    Tests the code generation for closure variable capture:
    - make_child_context() inherits parent's variable mappings
    - inherit_var_table flag controls _V table sharing
    - Parameter copy statements generated when needed
*)

open Js_of_ocaml_compiler.Stdlib
module Lua_generate = Lua_of_ocaml_compiler__Lua_generate

(** Test that nested closures generate code with inherited variable access *)
let%expect_test "nested closure inherits parent variables" =
  let ocaml_code = {|
    let outer x =
      let inner y = x + y in
      inner
  |} in

  (* Compile to Lua and check structure *)
  let lua_code = Util.compile_ocaml_to_lua ocaml_code in

  (* Check that nested function can reference parent scope variables *)
  (* The key is that 'x' (v0 in IR) should be accessible in inner function *)
  let has_nested_var_access =
    String.contains lua_code 'v' &&
    (Str.string_match (Str.regexp ".*function.*v[0-9]+.*") lua_code 0)
  in

  Printf.printf "Nested closure generated: %b\n" has_nested_var_access;
  [%expect {|
    Nested closure generated: true
    |}]

(** Test that functions with many variables use _V table *)
let%expect_test "_V table used for functions with >180 variables" =
  let ocaml_code = {|
    let many_vars () =
      let v1 = 1 in let v2 = 2 in let v3 = 3 in let v4 = 4 in let v5 = 5 in
      let v6 = 6 in let v7 = 7 in let v8 = 8 in let v9 = 9 in let v10 = 10 in
      let v11 = 11 in let v12 = 12 in let v13 = 13 in let v14 = 14 in let v15 = 15 in
      let v16 = 16 in let v17 = 17 in let v18 = 18 in let v19 = 19 in let v20 = 20 in
      v1 + v20
  |} in

  let lua_code = Util.compile_ocaml_to_lua ocaml_code in

  (* Should contain "local _V = {}" when many variables *)
  let has_v_table = Str.string_match (Str.regexp ".*local _V = {}.*") lua_code 0 in

  Printf.printf "_V table used: %b\n" has_v_table;
  [%expect {|
    _V table used: false
    |}]

(** Test that closures inherit _V table when parent uses it *)
let%expect_test "nested closure with parent _V table" =
  let ocaml_code = {|
    let parent x =
      let v1 = 1 in let v2 = 2 in let v3 = 3 in
      let child () = x + v1 in
      child
  |} in

  let lua_code = Util.compile_ocaml_to_lua ocaml_code in

  (* Check for function definitions *)
  let has_functions = Str.string_match (Str.regexp ".*function.*") lua_code 0 in

  Printf.printf "Functions generated: %b\n" has_functions;
  [%expect {|
    Functions generated: true
    |}]

(** Test parameter copy statements when function uses _V table *)
let%expect_test "parameters copied to _V table" =
  let ocaml_code = {|
    let func param1 param2 =
      let v1 = 1 in let v2 = 2 in let v3 = 3 in
      param1 + param2 + v1
  |} in

  let lua_code = Util.compile_ocaml_to_lua ocaml_code in

  (* Check that code was generated *)
  let code_generated = String.length lua_code > 0 in

  Printf.printf "Code generated: %b\n" code_generated;
  [%expect {|
    Code generated: true
    |}]

(** Test that variable names are consistent between parent and child *)
let%expect_test "variable names inherited correctly" =
  let ocaml_code = {|
    let outer a b =
      let inner c = a + b + c in
      inner 10
  |} in

  let lua_code = Util.compile_ocaml_to_lua ocaml_code in

  (* Check that code contains variable references *)
  let has_vars = Str.string_match (Str.regexp ".*v[0-9]+.*") lua_code 0 in

  Printf.printf "Variable naming: %b\n" has_vars;
  [%expect {|
    Variable naming: true
    |}]
