(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

open Util

let%expect_test "simple function" =
  compile_and_run
    {|
    let double x = x * 2

    let () =
      print_int (double 21);
      print_newline ()
    |};
  [%expect {| 42 |}]

let%expect_test "multiple arguments" =
  compile_and_run
    {|
    let add x y = x + y

    let () =
      print_int (add 10 32);
      print_newline ()
    |};
  [%expect {| 42 |}]

let%expect_test "curried function" =
  compile_and_run
    {|
    let add x y = x + y
    let add5 = add 5

    let () =
      print_int (add5 37);
      print_newline ()
    |};
  [%expect {| 42 |}]

let%expect_test "higher order function" =
  compile_and_run
    {|
    let apply f x = f x

    let () =
      print_int (apply (fun x -> x * 2) 21);
      print_newline ()
    |};
  [%expect {| 42 |}]

let%expect_test "recursive function" =
  compile_and_run
    {|
    let rec factorial n =
      if n <= 1 then 1
      else n * factorial (n - 1)

    let () =
      print_int (factorial 5);
      print_newline ()
    |};
  [%expect {| 120 |}]

let%expect_test "mutually recursive functions" =
  compile_and_run
    {|
    let rec is_even n =
      if n = 0 then true
      else is_odd (n - 1)
    and is_odd n =
      if n = 0 then false
      else is_even (n - 1)

    let () =
      print_endline (if is_even 4 then "true" else "false");
      print_endline (if is_odd 4 then "true" else "false");
      print_endline (if is_even 7 then "true" else "false");
      print_endline (if is_odd 7 then "true" else "false")
    |};
  [%expect {|
    true
    false
    false
    true
    |}]

let%expect_test "closure" =
  compile_and_run
    {|
    let make_adder n =
      fun x -> x + n

    let () =
      let add10 = make_adder 10 in
      print_int (add10 32);
      print_newline ()
    |};
  [%expect {| 42 |}]

let%expect_test "nested closures" =
  compile_and_run
    {|
    let make_counter start =
      let count = ref start in
      fun () ->
        let result = !count in
        count := !count + 1;
        result

    let () =
      let c = make_counter 10 in
      print_int (c ());
      print_char ' ';
      print_int (c ());
      print_char ' ';
      print_int (c ());
      print_newline ()
    |};
  [%expect {| 10 11 12 |}]

let%expect_test "function composition" =
  compile_and_run
    {|
    let compose f g x = f (g x)

    let double x = x * 2
    let add3 x = x + 3

    let () =
      let f = compose double add3 in
      print_int (f 10);
      print_newline ()
    |};
  [%expect {| 26 |}]

let%expect_test "tail recursion" =
  compile_and_run
    {|
    let rec sum_tail n acc =
      if n = 0 then acc
      else sum_tail (n - 1) (acc + n)

    let () =
      print_int (sum_tail 100 0);
      print_newline ()
    |};
  [%expect {| 5050 |}]

let%expect_test "anonymous function" =
  compile_and_run
    {|
    let () =
      let result = (fun x y -> x * y) 6 7 in
      print_int result;
      print_newline ()
    |};
  [%expect {| 42 |}]

let%expect_test "optional arguments simulation" =
  compile_and_run
    {|
    let greet name =
      match name with
      | Some n -> "Hello, " ^ n
      | None -> "Hello, World"

    let () =
      print_endline (greet (Some "Alice"));
      print_endline (greet None)
    |};
  [%expect {|
    Hello, Alice
    Hello, World
    |}]
