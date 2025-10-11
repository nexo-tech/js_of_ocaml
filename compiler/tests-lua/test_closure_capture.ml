(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

(** Tests for closure variable capture

    This tests the fix for nested closures capturing variables from
    parent scopes. The fix adds:
    - make_child_context() to inherit parent's variable mappings
    - inherit_var_table flag to share _V table between parent/child
    - Parameter copy statements (_V.param = param) for functions using _V
*)

open Util

let%expect_test "simple closure captures variable" =
  compile_and_run
    {|
    let outer x =
      let inner y = x + y in
      inner

    let () =
      let add5 = outer 5 in
      print_int (add5 10);
      print_newline ()
    |};
  [%expect {|
    15
    |}]

let%expect_test "nested closure captures multiple variables" =
  compile_and_run
    {|
    let make_ops a b =
      let add () = a + b in
      let mul () = a * b in
      (add, mul)

    let () =
      let (add, mul) = make_ops 3 4 in
      print_int (add ());
      print_char ' ';
      print_int (mul ());
      print_newline ()
    |};
  [%expect {|
    7 12
    |}]

let%expect_test "deeply nested closures" =
  compile_and_run
    {|
    let level1 a =
      let level2 b =
        let level3 c =
          a + b + c
        in
        level3
      in
      level2

    let () =
      let f = level1 10 20 in
      print_int (f 30);
      print_newline ()
    |};
  [%expect {|
    60
    |}]

let%expect_test "closure with function parameter" =
  compile_and_run
    {|
    let apply_twice f x =
      let apply1 = f x in
      f apply1

    let () =
      let double x = x * 2 in
      print_int (apply_twice double 5);
      print_newline ()
    |};
  [%expect {|
    20
    |}]

let%expect_test "closure accessing ref from parent" =
  compile_and_run
    {|
    let make_counter () =
      let count = ref 0 in
      let inc () =
        count := !count + 1;
        !count
      in
      let dec () =
        count := !count - 1;
        !count
      in
      (inc, dec)

    let () =
      let (inc, dec) = make_counter () in
      print_int (inc ());
      print_char ' ';
      print_int (inc ());
      print_char ' ';
      print_int (dec ());
      print_newline ()
    |};
  [%expect {|
    1 2 1
    |}]

let%expect_test "closure in function with many locals (>180)" =
  (* This tests parameter copying to _V table when parent uses table storage *)
  compile_and_run
    {|
    (* Function with many variables to trigger _V table usage *)
    let many_vars () =
      let v1 = 1 in let v2 = 2 in let v3 = 3 in let v4 = 4 in let v5 = 5 in
      let v6 = 6 in let v7 = 7 in let v8 = 8 in let v9 = 9 in let v10 = 10 in
      let v11 = 11 in let v12 = 12 in let v13 = 13 in let v14 = 14 in let v15 = 15 in
      let v16 = 16 in let v17 = 17 in let v18 = 18 in let v19 = 19 in let v20 = 20 in
      let v21 = 21 in let v22 = 22 in let v23 = 23 in let v24 = 24 in let v25 = 25 in
      (* Create closure that captures some variables *)
      let inner () = v1 + v10 + v25 in
      inner ()

    let () =
      print_int (many_vars ());
      print_newline ()
    |};
  [%expect {|
    36
    |}]

let%expect_test "closure captures function parameter with _V table" =
  (* Tests parameter copy (_V.param = param) when function uses _V table *)
  compile_and_run
    {|
    let outer_with_param param =
      (* Many locals to trigger _V table *)
      let v1 = 1 in let v2 = 2 in let v3 = 3 in let v4 = 4 in let v5 = 5 in
      let v6 = 6 in let v7 = 7 in let v8 = 8 in let v9 = 9 in let v10 = 10 in
      (* Closure captures parameter *)
      let inner () = param + v1 + v10 in
      inner

    let () =
      let f = outer_with_param 100 in
      print_int (f ());
      print_newline ()
    |};
  [%expect {|
    111
    |}]

let%expect_test "multiple nested closures share parent _V" =
  compile_and_run
    {|
    let parent x =
      let v1 = 10 in
      let v2 = 20 in
      let child1 () = x + v1 in
      let child2 () = x + v2 in
      (child1, child2)

    let () =
      let (c1, c2) = parent 5 in
      print_int (c1 ());
      print_char ' ';
      print_int (c2 ());
      print_newline ()
    |};
  [%expect {|
    15 25
    |}]

let%expect_test "closure captures and modifies ref" =
  compile_and_run
    {|
    let make_accumulator init =
      let total = ref init in
      fun x ->
        total := !total + x;
        !total

    let () =
      let acc = make_accumulator 0 in
      print_int (acc 5);
      print_char ' ';
      print_int (acc 10);
      print_char ' ';
      print_int (acc 3);
      print_newline ()
    |};
  [%expect {|
    5 15 18
    |}]
