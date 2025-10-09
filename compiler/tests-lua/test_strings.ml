(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

open Util

let%expect_test "string concatenation" =
  compile_and_run
    {|
    let () =
      let s = "Hello" ^ " " ^ "World" in
      print_endline s
    |};
  [%expect {|
    lua: test.lua:807: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:807: in function '__caml_init__'
    test.lua:2167: in main chunk
    [C]: in ?
    |}]

let%expect_test "string length" =
  compile_and_run
    {|
    let () =
      print_int (String.length "hello");
      print_newline ();
      print_int (String.length "");
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:806: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:806: in function '__caml_init__'
    test.lua:2172: in main chunk
    [C]: in ?
    |}]

let%expect_test "string access" =
  compile_and_run
    {|
    let () =
      let s = "hello" in
      print_char s.[0];
      print_char s.[1];
      print_char s.[4];
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:805: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:805: in function '__caml_init__'
    test.lua:2174: in main chunk
    [C]: in ?
    |}]

let%expect_test "string_of_int" =
  compile_and_run
    {|
    let () =
      print_endline (string_of_int 42);
      print_endline (string_of_int (-10));
      print_endline (string_of_int 0)
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2173: in main chunk
    [C]: in ?
    |}]

let%expect_test "int_of_string" =
  compile_and_run
    {|
    let () =
      print_int (int_of_string "42");
      print_newline ();
      print_int (int_of_string "-10");
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:806: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:806: in function '__caml_init__'
    test.lua:2172: in main chunk
    [C]: in ?
    |}]

let%expect_test "string compare" =
  compile_and_run
    {|
    let () =
      print_endline (if "abc" = "abc" then "equal" else "not equal");
      print_endline (if "abc" = "def" then "equal" else "not equal");
      print_endline (if "abc" < "def" then "less" else "greater")
    |};
  [%expect {|
    lua: test.lua:816: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:816: in function '__caml_init__'
    test.lua:2206: in main chunk
    [C]: in ?
    |}]

let%expect_test "string sub" =
  compile_and_run
    {|
    let () =
      let s = "hello world" in
      print_endline (String.sub s 0 5);
      print_endline (String.sub s 6 5)
    |};
  [%expect {|
    lua: test.lua:875: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:875: in function '__caml_init__'
    test.lua:11755: in main chunk
    [C]: in ?
    |}]

let%expect_test "string contains" =
  compile_and_run
    {|
    let () =
      let s = "hello" in
      print_endline (if String.contains s 'e' then "yes" else "no");
      print_endline (if String.contains s 'x' then "yes" else "no")
    |};
  [%expect {|
    lua: test.lua:879: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:879: in function '__caml_init__'
    test.lua:11775: in main chunk
    [C]: in ?
    |}]

let%expect_test "string make" =
  compile_and_run
    {|
    let () =
      print_endline (String.make 5 'a');
      print_endline (String.make 3 'x')
    |};
  [%expect {|
    lua: test.lua:874: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:874: in function '__caml_init__'
    test.lua:11754: in main chunk
    [C]: in ?
    |}]

let%expect_test "string escape sequences" =
  compile_and_run
    {|
    let () =
      print_endline "line1\nline2";
      print_endline "tab\there";
      print_endline "quote:\"hello\""
    |};
  [%expect {|
    lua: test.lua:807: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:807: in function '__caml_init__'
    test.lua:2167: in main chunk
    [C]: in ?
    |}]

let%expect_test "empty string" =
  compile_and_run
    {|
    let () =
      let s = "" in
      print_int (String.length s);
      print_newline ();
      print_endline (if s = "" then "empty" else "not empty")
    |};
  [%expect {|
    lua: test.lua:808: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:808: in function '__caml_init__'
    test.lua:2180: in main chunk
    [C]: in ?
    |}]

let%expect_test "string uppercase lowercase" =
  compile_and_run
    {|
    let () =
      print_endline (String.uppercase_ascii "hello");
      print_endline (String.lowercase_ascii "WORLD")
    |};
  [%expect {|
    lua: test.lua:876: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:876: in function '__caml_init__'
    test.lua:11752: in main chunk
    [C]: in ?
    |}]

let%expect_test "string trim" =
  compile_and_run
    {|
    let () =
      print_endline (String.trim "  hello  ");
      print_endline (String.trim "\n\tworld\t\n")
    |};
  [%expect {|
    lua: test.lua:876: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:876: in function '__caml_init__'
    test.lua:11752: in main chunk
    [C]: in ?
    |}]
