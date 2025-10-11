(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

(** Tests for pattern matching field extraction and continuation arguments

    This tests the fix for v1165 nil error - missing argument passing in
    Switch, Branch, Cond, Pushtrap, and Poptrap statements.

    The fix adds generate_argument_passing() which assigns continuation
    arguments to target block parameters before jumping.
*)

open Util

let%expect_test "simple variant pattern match" =
  compile_and_run
    {|
    type t = A | B | C

    let test x =
      match x with
      | A -> 1
      | B -> 2
      | C -> 3

    let () =
      print_int (test A);
      print_char ' ';
      print_int (test B);
      print_char ' ';
      print_int (test C);
      print_newline ()
    |};
  [%expect {|
    1 2 3
    |}]

let%expect_test "variant with single field" =
  compile_and_run
    {|
    type t = Empty | Value of int

    let get_value x =
      match x with
      | Empty -> 0
      | Value n -> n

    let () =
      print_int (get_value Empty);
      print_char ' ';
      print_int (get_value (Value 42));
      print_newline ()
    |};
  [%expect {|
    0 42
    |}]

let%expect_test "variant with multiple fields" =
  compile_and_run
    {|
    type point = Point of int * int

    let add_coords p =
      match p with
      | Point (x, y) -> x + y

    let () =
      let p = Point (10, 20) in
      print_int (add_coords p);
      print_newline ()
    |};
  [%expect {|
    30
    |}]

let%expect_test "nested variant pattern match" =
  compile_and_run
    {|
    type inner = IEmpty | IValue of int
    type outer = OEmpty | OInner of inner

    let get_value x =
      match x with
      | OEmpty -> 0
      | OInner IEmpty -> 1
      | OInner (IValue n) -> n

    let () =
      print_int (get_value OEmpty);
      print_char ' ';
      print_int (get_value (OInner IEmpty));
      print_char ' ';
      print_int (get_value (OInner (IValue 99)));
      print_newline ()
    |};
  [%expect {|
    0 1 99
    |}]

let%expect_test "option type pattern matching" =
  compile_and_run
    {|
    let get_or_default opt default =
      match opt with
      | None -> default
      | Some x -> x

    let () =
      print_int (get_or_default None 10);
      print_char ' ';
      print_int (get_or_default (Some 42) 10);
      print_newline ()
    |};
  [%expect {|
    10 42
    |}]

let%expect_test "result type pattern matching" =
  compile_and_run
    {|
    type ('a, 'b) result = Ok of 'a | Error of 'b

    let get_value r =
      match r with
      | Ok x -> x
      | Error _ -> 0

    let () =
      print_int (get_value (Ok 123));
      print_char ' ';
      print_int (get_value (Error "fail"));
      print_newline ()
    |};
  [%expect {|
    123 0
    |}]

let%expect_test "variant with three fields" =
  compile_and_run
    {|
    type rgb = RGB of int * int * int

    let sum_rgb c =
      match c with
      | RGB (r, g, b) -> r + g + b

    let () =
      let color = RGB (100, 150, 200) in
      print_int (sum_rgb color);
      print_newline ()
    |};
  [%expect {|
    450
    |}]

let%expect_test "match with when guards" =
  compile_and_run
    {|
    type value = Value of int

    let categorize v =
      match v with
      | Value n when n < 0 -> "negative"
      | Value n when n = 0 -> "zero"
      | Value n when n > 0 -> "positive"
      | _ -> "unknown"

    let () =
      print_endline (categorize (Value (-5)));
      print_endline (categorize (Value 0));
      print_endline (categorize (Value 10))
    |};
  [%expect {|
    negative
    zero
    positive
    |}]

let%expect_test "polymorphic variant pattern match" =
  compile_and_run
    {|
    type t = Int of int | String of string | Float of float

    let to_int x =
      match x with
      | Int n -> n
      | String s -> int_of_string s
      | Float f -> int_of_float f

    let () =
      print_int (to_int (Int 42));
      print_char ' ';
      print_int (to_int (String "99"));
      print_char ' ';
      print_int (to_int (Float 3.14));
      print_newline ()
    |};
  [%expect {|
    42 99 3
    |}]

let%expect_test "exhaustive pattern matching" =
  compile_and_run
    {|
    type direction = North | South | East | West

    let opposite d =
      match d with
      | North -> South
      | South -> North
      | East -> West
      | West -> East

    let dir_to_int d =
      match d with
      | North -> 0
      | South -> 1
      | East -> 2
      | West -> 3

    let () =
      print_int (dir_to_int (opposite North));
      print_char ' ';
      print_int (dir_to_int (opposite East));
      print_newline ()
    |};
  [%expect {|
    1 3
    |}]
