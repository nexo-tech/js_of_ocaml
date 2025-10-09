(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

open Util

let%expect_test "basic ref" =
  compile_and_run
    {|
    let () =
      let x = ref 42 in
      print_int !x;
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2166: in main chunk
    [C]: in ?
    |}]

let%expect_test "ref assignment" =
  compile_and_run
    {|
    let () =
      let x = ref 10 in
      print_int !x;
      print_newline ();
      x := 20;
      print_int !x;
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2175: in main chunk
    [C]: in ?
    |}]

let%expect_test "ref increment" =
  compile_and_run
    {|
    let () =
      let counter = ref 0 in
      for i = 1 to 5 do
        counter := !counter + i
      done;
      print_int !counter;
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2190: in main chunk
    [C]: in ?
    |}]

let%expect_test "multiple refs" =
  compile_and_run
    {|
    let () =
      let x = ref 10 in
      let y = ref 20 in
      print_int (!x + !y);
      print_newline ();
      x := 15;
      y := 25;
      print_int (!x + !y);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2184: in main chunk
    [C]: in ?
    |}]

let%expect_test "ref aliasing" =
  compile_and_run
    {|
    let () =
      let x = ref 10 in
      let y = x in
      y := 20;
      print_int !x;
      print_newline ();
      print_int !y;
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2175: in main chunk
    [C]: in ?
    |}]

let%expect_test "ref in closure" =
  compile_and_run
    {|
    let make_counter () =
      let count = ref 0 in
      fun () ->
        count := !count + 1;
        !count

    let () =
      let c = make_counter () in
      print_int (c ());
      print_char ' ';
      print_int (c ());
      print_char ' ';
      print_int (c ());
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2203: in main chunk
    [C]: in ?
    |}]

let%expect_test "ref swap" =
  compile_and_run
    {|
    let swap x y =
      let temp = !x in
      x := !y;
      y := temp

    let () =
      let a = ref 10 in
      let b = ref 20 in
      print_int !a;
      print_char ' ';
      print_int !b;
      print_newline ();
      swap a b;
      print_int !a;
      print_char ' ';
      print_int !b;
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2201: in main chunk
    [C]: in ?
    |}]

let%expect_test "ref incr decr" =
  compile_and_run
    {|
    let () =
      let x = ref 5 in
      incr x;
      print_int !x;
      print_newline ();
      decr x;
      decr x;
      print_int !x;
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2178: in main chunk
    [C]: in ?
    |}]

let%expect_test "ref in record" =
  compile_and_run
    {|
    type state = { mutable value : int }

    let () =
      let s = { value = 10 } in
      print_int s.value;
      print_newline ();
      s.value <- 20;
      print_int s.value;
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2175: in main chunk
    [C]: in ?
    |}]
