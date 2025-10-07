(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

open Util

let%expect_test "simple record" =
  compile_and_run
    {|
    type point = { x : int; y : int }

    let () =
      let p = { x = 10; y = 20 } in
      print_int p.x;
      print_char ' ';
      print_int p.y;
      print_newline ()
    |};
  [%expect {| 10 20 |}]

let%expect_test "record update" =
  compile_and_run
    {|
    type point = { x : int; y : int }

    let () =
      let p1 = { x = 10; y = 20 } in
      let p2 = { p1 with x = 30 } in
      print_int p1.x;
      print_char ' ';
      print_int p1.y;
      print_char ' ';
      print_int p2.x;
      print_char ' ';
      print_int p2.y;
      print_newline ()
    |};
  [%expect {| 10 20 30 20 |}]

let%expect_test "nested records" =
  compile_and_run
    {|
    type point = { x : int; y : int }
    type rect = { top_left : point; bottom_right : point }

    let () =
      let r = {
        top_left = { x = 0; y = 0 };
        bottom_right = { x = 100; y = 100 }
      } in
      print_int r.top_left.x;
      print_char ' ';
      print_int r.bottom_right.x;
      print_newline ()
    |};
  [%expect {| 0 100 |}]

let%expect_test "record pattern matching" =
  compile_and_run
    {|
    type point = { x : int; y : int }

    let is_origin p =
      match p with
      | { x = 0; y = 0 } -> true
      | _ -> false

    let () =
      print_endline (if is_origin { x = 0; y = 0 } then "yes" else "no");
      print_endline (if is_origin { x = 1; y = 0 } then "yes" else "no")
    |};
  [%expect {|
    yes
    no
    |}]

let%expect_test "record with function" =
  compile_and_run
    {|
    type point = { x : int; y : int }

    let distance_from_origin p =
      (* Simple Manhattan distance *)
      abs p.x + abs p.y

    let () =
      print_int (distance_from_origin { x = 3; y = 4 });
      print_newline ();
      print_int (distance_from_origin { x = (-5); y = 12 });
      print_newline ()
    |};
  [%expect {|
    7
    17
    |}]

let%expect_test "mutable record fields" =
  compile_and_run
    {|
    type counter = { mutable count : int }

    let () =
      let c = { count = 0 } in
      c.count <- 10;
      print_int c.count;
      print_newline ();
      c.count <- c.count + 5;
      print_int c.count;
      print_newline ()
    |};
  [%expect {|
    10
    15
    |}]

let%expect_test "record with different types" =
  compile_and_run
    {|
    type person = {
      name : string;
      age : int;
      active : bool
    }

    let () =
      let p = { name = "Alice"; age = 30; active = true } in
      print_endline p.name;
      print_int p.age;
      print_newline ();
      print_endline (if p.active then "active" else "inactive")
    |};
  [%expect {|
    Alice
    30
    active
    |}]

let%expect_test "polymorphic record" =
  compile_and_run
    {|
    type 'a container = { value : 'a }

    let () =
      let int_cont = { value = 42 } in
      let str_cont = { value = "hello" } in
      print_int int_cont.value;
      print_newline ();
      print_endline str_cont.value
    |};
  [%expect {|
    42
    hello
    |}]
