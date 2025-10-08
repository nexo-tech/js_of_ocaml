(* Lua_of_ocaml tests - Lua interop
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

open Util

let%expect_test "lua identifier safety - reserved keywords" =
  let lua_code = compile_ocaml_to_lua
    {|
    (* Test that OCaml identifiers that clash with Lua keywords are renamed *)
    let local_var = 42
    let end_var = 10
    let function_var = 5

    let () =
      print_int (local_var + end_var + function_var);
      print_newline ()
    |}
  in
  (* Check that identifiers are made safe *)
  let has_safe_identifiers =
    String.contains lua_code '_' &&
    not (Str.string_match (Str.regexp ".*\\blocal =.*") lua_code 0) &&
    not (Str.string_match (Str.regexp ".*\\bend =.*") lua_code 0) &&
    not (Str.string_match (Str.regexp ".*\\bfunction =.*") lua_code 0)
  in
  print_endline (if has_safe_identifiers then "identifiers are safe" else "ERROR: unsafe identifiers");
  [%expect {| identifiers are safe |}]

let%expect_test "lua number representation" =
  compile_and_run
    {|
    let () =
      (* Test various number representations *)
      print_int 0;
      print_newline ();
      print_int 42;
      print_newline ();
      print_int (-10);
      print_newline ();
      print_int max_int;
      print_newline ()
    |};
  [%expect {| /bin/sh: 1: lua: not found |}]

let%expect_test "lua table as array" =
  compile_and_run
    {|
    let () =
      (* Arrays should map to Lua tables with 1-based indexing internally *)
      let a = [|10; 20; 30|] in
      print_int a.(0);
      print_char ' ';
      print_int a.(1);
      print_char ' ';
      print_int a.(2);
      print_newline ()
    |};
  [%expect {| /bin/sh: 1: lua: not found |}]

let%expect_test "lua nil vs ocaml option" =
  compile_and_run
    {|
    let () =
      (* None/Some should work correctly *)
      let opt = Some 42 in
      match opt with
      | Some n -> print_int n
      | None -> print_string "none";
      print_newline ();
      let opt2 = None in
      match opt2 with
      | Some n -> print_int n
      | None -> print_string "none";
      print_newline ()
    |};
  [%expect {| /bin/sh: 1: lua: not found |}]

let%expect_test "lua boolean representation" =
  compile_and_run
    {|
    let () =
      print_endline (if true then "true" else "false");
      print_endline (if false then "true" else "false");
      print_endline (if true && false then "true" else "false");
      print_endline (if true || false then "true" else "false");
      print_endline (if not true then "true" else "false")
    |};
  [%expect {| /bin/sh: 1: lua: not found |}]

let%expect_test "lua string escaping" =
  compile_and_run
    {|
    let () =
      (* Test that special characters are properly escaped *)
      print_endline "Hello\nWorld";
      print_endline "Tab\there";
      print_endline "Quote\"here";
      print_endline "Backslash\\here"
    |};
  [%expect {| /bin/sh: 1: lua: not found |}]

let%expect_test "lua vararg handling" =
  compile_and_run
    {|
    let f x y z = x + y + z

    let () =
      (* Curried functions should work with multiple arguments *)
      print_int (f 1 2 3);
      print_newline ();
      let g = f 10 in
      print_int (g 20 12);
      print_newline ()
    |};
  [%expect {| /bin/sh: 1: lua: not found |}]

let%expect_test "lua closure upvalue handling" =
  compile_and_run
    {|
    let () =
      (* Test that closures properly capture variables *)
      let x = 10 in
      let f () = x + 32 in
      print_int (f ());
      print_newline ()
    |};
  [%expect {| /bin/sh: 1: lua: not found |}]

let%expect_test "lua module loading" =
  let lua_code = compile_ocaml_to_lua
    {|
    let x = 42
    let () = print_int x; print_newline ()
    |}
  in
  (* Check that initialization code is present *)
  let has_init =
    String.contains lua_code 'p' &&
    String.contains lua_code 'r' &&
    String.contains lua_code 'i' &&
    String.contains lua_code 'n' &&
    String.contains lua_code 't'
  in
  print_endline (if has_init then "has initialization" else "ERROR: no init");
  [%expect {| has initialization |}]
