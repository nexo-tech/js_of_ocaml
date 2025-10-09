(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

open Util

let%expect_test "basic exception" =
  compile_and_run
    {|
    exception MyError

    let () =
      try
        raise MyError
      with MyError ->
        print_endline "caught MyError"
    |};
  [%expect {|
    lua: test.lua:806: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:806: in function '__caml_init__'
    test.lua:2185: in main chunk
    [C]: in ?
    |}]

let%expect_test "exception with argument" =
  compile_and_run
    {|
    exception Error of string

    let () =
      try
        raise (Error "test message")
      with Error msg ->
        print_endline ("caught: " ^ msg)
    |};
  [%expect {|
    lua: test.lua:807: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:807: in function '__caml_init__'
    test.lua:2191: in main chunk
    [C]: in ?
    |}]

let%expect_test "nested exceptions" =
  compile_and_run
    {|
    exception A
    exception B

    let () =
      try
        try
          raise A
        with B ->
          print_endline "caught B (not reached)"
      with A ->
        print_endline "caught A"
    |};
  [%expect {|
    lua: test.lua:808: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:808: in function '__caml_init__'
    test.lua:2213: in main chunk
    [C]: in ?
    |}]

let%expect_test "exception propagation" =
  compile_and_run
    {|
    exception MyError of int

    let f x =
      if x > 0 then raise (MyError x)
      else x

    let () =
      try
        let _ = f 1 in
        let _ = f 2 in
        print_endline "no exception"
      with MyError n ->
        print_string "caught MyError ";
        print_int n;
        print_newline ()
    |};
  [%expect {|
    lua: test.lua:807: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:807: in function '__caml_init__'
    test.lua:2220: in main chunk
    [C]: in ?
    |}]

let%expect_test "multiple exception types" =
  compile_and_run
    {|
    exception A of int
    exception B of string

    let test n =
      if n = 0 then raise (A 42)
      else if n = 1 then raise (B "hello")
      else n

    let () =
      begin try
        let _ = test 0 in ()
      with A n ->
        print_string "A: ";
        print_int n;
        print_newline ()
      end;
      begin try
        let _ = test 1 in ()
      with B s ->
        print_string "B: ";
        print_string s;
        print_newline ()
      end
    |};
  [%expect {|
    lua: test.lua:809: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:809: in function '__caml_init__'
    test.lua:2268: in main chunk
    [C]: in ?
    |}]

let%expect_test "finally simulation" =
  compile_and_run
    {|
    exception E

    let with_finally f cleanup =
      try
        let result = f () in
        cleanup ();
        result
      with e ->
        cleanup ();
        raise e

    let () =
      try
        with_finally
          (fun () ->
            print_endline "in function";
            raise E)
          (fun () ->
            print_endline "cleanup")
      with E ->
        print_endline "caught E"
    |};
  [%expect {|
    lua: test.lua:808: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:808: in function '__caml_init__'
    test.lua:2228: in main chunk
    [C]: in ?
    |}]

let%expect_test "builtin exceptions" =
  compile_and_run
    {|
    let () =
      (* Test Invalid_argument *)
      begin try
        failwith "test error"
      with Failure msg ->
        print_endline ("Failure: " ^ msg)
      end;
      (* Test Not_found *)
      begin try
        raise Not_found
      with Not_found ->
        print_endline "Not_found caught"
      end
    |};
  [%expect {|
    lua: test.lua:807: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:807: in function '__caml_init__'
    test.lua:2215: in main chunk
    [C]: in ?
    |}]
