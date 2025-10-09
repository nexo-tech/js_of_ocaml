(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

open Util

let%expect_test "list creation" =
  compile_and_run
    {|
    let () =
      let l = [1; 2; 3; 4; 5] in
      let rec print_list = function
        | [] -> print_newline ()
        | x :: xs ->
            print_int x;
            print_char ' ';
            print_list xs
      in
      print_list l
    |};
  [%expect {| lua: test.lua:173: <goto block_4> at line 105 jumps into the scope of local 'v177' |}]

let%expect_test "list cons" =
  compile_and_run
    {|
    let () =
      let l = 1 :: 2 :: 3 :: [] in
      let rec print_list = function
        | [] -> print_newline ()
        | x :: xs ->
            print_int x;
            print_char ' ';
            print_list xs
      in
      print_list l
    |};
  [%expect {| lua: test.lua:173: <goto block_4> at line 105 jumps into the scope of local 'v177' |}]

let%expect_test "list length" =
  compile_and_run
    {|
    let () =
      print_int (List.length [1; 2; 3; 4; 5]);
      print_newline ();
      print_int (List.length []);
      print_newline ()
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list hd tl" =
  compile_and_run
    {|
    let () =
      let l = [1; 2; 3] in
      print_int (List.hd l);
      print_newline ();
      let tl = List.tl l in
      print_int (List.hd tl);
      print_newline ()
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list append" =
  compile_and_run
    {|
    let rec print_list = function
      | [] -> print_newline ()
      | x :: xs ->
          print_int x;
          print_char ' ';
          print_list xs

    let () =
      let l1 = [1; 2; 3] in
      let l2 = [4; 5; 6] in
      print_list (l1 @ l2)
    |};
  [%expect {| lua: test.lua:174: <goto block_4> at line 106 jumps into the scope of local 'v180' |}]

let%expect_test "list rev" =
  compile_and_run
    {|
    let rec print_list = function
      | [] -> print_newline ()
      | x :: xs ->
          print_int x;
          print_char ' ';
          print_list xs

    let () =
      print_list (List.rev [1; 2; 3; 4; 5])
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list map" =
  compile_and_run
    {|
    let rec print_list = function
      | [] -> print_newline ()
      | x :: xs ->
          print_int x;
          print_char ' ';
          print_list xs

    let () =
      let l = [1; 2; 3; 4; 5] in
      print_list (List.map (fun x -> x * 2) l)
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list filter" =
  compile_and_run
    {|
    let rec print_list = function
      | [] -> print_newline ()
      | x :: xs ->
          print_int x;
          print_char ' ';
          print_list xs

    let () =
      let l = [1; 2; 3; 4; 5; 6; 7; 8; 9; 10] in
      print_list (List.filter (fun x -> x mod 2 = 0) l)
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list fold_left" =
  compile_and_run
    {|
    let () =
      let l = [1; 2; 3; 4; 5] in
      let sum = List.fold_left (+) 0 l in
      print_int sum;
      print_newline ()
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list fold_right" =
  compile_and_run
    {|
    let () =
      let l = [1; 2; 3; 4; 5] in
      let sum = List.fold_right (+) l 0 in
      print_int sum;
      print_newline ()
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list iter" =
  compile_and_run
    {|
    let () =
      let l = [1; 2; 3; 4; 5] in
      List.iter (fun x -> print_int x; print_char ' ') l;
      print_newline ()
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list find" =
  compile_and_run
    {|
    let () =
      let l = [1; 2; 3; 4; 5] in
      let result = List.find (fun x -> x > 3) l in
      print_int result;
      print_newline ()
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list exists" =
  compile_and_run
    {|
    let () =
      let l = [1; 2; 3; 4; 5] in
      print_endline (if List.exists (fun x -> x = 3) l then "yes" else "no");
      print_endline (if List.exists (fun x -> x = 10) l then "yes" else "no")
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list for_all" =
  compile_and_run
    {|
    let () =
      let l = [2; 4; 6; 8] in
      print_endline (if List.for_all (fun x -> x mod 2 = 0) l then "yes" else "no");
      let l2 = [2; 3; 4] in
      print_endline (if List.for_all (fun x -> x mod 2 = 0) l2 then "yes" else "no")
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]

let%expect_test "list flatten" =
  compile_and_run
    {|
    let rec print_list = function
      | [] -> print_newline ()
      | x :: xs ->
          print_int x;
          print_char ' ';
          print_list xs

    let () =
      let ll = [[1; 2]; [3; 4]; [5; 6]] in
      print_list (List.flatten ll)
    |};
  [%expect {| lua: test.lua:29: too many local variables (limit is 200) in function at line 26 near ',' |}]
