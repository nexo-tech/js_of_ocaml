(* Lua_of_ocaml tests - Calling conventions
 * Tests for partial application, currying, argument passing edge cases
 * Critical for libraries that use higher-order functions heavily
 *)

open Util

let%expect_test "partial application single arg" =
  compile_and_run
    {|
    let add x y = x + y

    let () =
      let add5 = add 5 in
      print_int (add5 10);
      print_newline ();
      print_int (add5 37);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2183: in main chunk
    [C]: in ?
    |}]

let%expect_test "partial application multiple stages" =
  compile_and_run
    {|
    let f a b c d = a + b + c + d

    let () =
      let f1 = f 1 in
      let f2 = f1 2 in
      let f3 = f2 3 in
      print_int (f3 4);
      print_newline ();
      (* Or all at once *)
      print_int (f 10 20 30 40);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2192: in main chunk
    [C]: in ?
    |}]

let%expect_test "partial application with different types" =
  compile_and_run
    {|
    let concat_with_sep sep a b = a ^ sep ^ b

    let () =
      let comma_sep = concat_with_sep ", " in
      print_endline (comma_sep "hello" "world");
      let dash_sep = concat_with_sep " - " in
      print_endline (dash_sep "foo" "bar")
    |};
  [%expect {|
    lua: test.lua:810: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:810: in function '__caml_init__'
    test.lua:2184: in main chunk
    [C]: in ?
    |}]

let%expect_test "currying vs tupled arguments" =
  compile_and_run
    {|
    (* Curried *)
    let add_curried x y = x + y

    (* Tupled *)
    let add_tupled (x, y) = x + y

    let () =
      (* Curried can be partially applied *)
      let add5 = add_curried 5 in
      print_int (add5 10);
      print_newline ();
      (* Tupled needs full tuple *)
      print_int (add_tupled (5, 10));
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:805: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:805: in function '__caml_init__'
    test.lua:2192: in main chunk
    [C]: in ?
    |}]

let%expect_test "function composition" =
  compile_and_run
    {|
    let compose f g x = f (g x)

    let double x = x * 2
    let add_three x = x + 3

    let () =
      let f = compose double add_three in
      print_int (f 10);
      print_newline ();
      let g = compose add_three double in
      print_int (g 10);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2200: in main chunk
    [C]: in ?
    |}]

let%expect_test "higher order function with multiple args" =
  compile_and_run
    {|
    let apply_twice f x = f (f x)

    let () =
      print_int (apply_twice (fun x -> x * 2) 5);
      print_newline ();
      print_int (apply_twice (fun x -> x + 1) 5);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2198: in main chunk
    [C]: in ?
    |}]

let%expect_test "function returning function" =
  compile_and_run
    {|
    let make_multiplier n =
      fun x -> x * n

    let () =
      let times_two = make_multiplier 2 in
      let times_ten = make_multiplier 10 in
      print_int (times_two 21);
      print_newline ();
      print_int (times_ten 4);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2191: in main chunk
    [C]: in ?
    |}]

let%expect_test "curried application with side effects" =
  compile_and_run
    {|
    let f x y =
      print_string "f called: ";
      print_int x;
      print_char ' ';
      print_int y;
      print_newline ();
      x + y

    let () =
      let partial = f 10 in
      print_endline "after partial";
      let result = partial 32 in
      print_int result;
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:806: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:806: in function '__caml_init__'
    test.lua:2192: in main chunk
    [C]: in ?
    |}]

let%expect_test "eta expansion" =
  compile_and_run
    {|
    let add x y = x + y

    let () =
      (* Eta expanded *)
      let add' x y = add x y in
      print_int (add' 10 32);
      print_newline ();
      (* Point-free *)
      let add'' = add in
      print_int (add'' 20 22);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2190: in main chunk
    [C]: in ?
    |}]

let%expect_test "passing functions as arguments" =
  compile_and_run
    {|
    let apply_binary_op op x y = op x y

    let () =
      print_int (apply_binary_op (+) 10 32);
      print_newline ();
      print_int (apply_binary_op ( * ) 6 7);
      print_newline ();
      print_int (apply_binary_op (-) 50 8);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2212: in main chunk
    [C]: in ?
    |}]

let%expect_test "recursive function as argument" =
  compile_and_run
    {|
    let rec factorial n =
      if n <= 1 then 1 else n * factorial (n - 1)

    let apply_to_five f = f 5

    let () =
      print_int (apply_to_five factorial);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2196: in main chunk
    [C]: in ?
    |}]

let%expect_test "closure capturing multiple variables" =
  compile_and_run
    {|
    let make_range_checker min max =
      fun x -> x >= min && x <= max

    let () =
      let is_in_range = make_range_checker 10 20 in
      print_endline (if is_in_range 15 then "yes" else "no");
      print_endline (if is_in_range 25 then "yes" else "no");
      print_endline (if is_in_range 5 then "yes" else "no")
    |};
  [%expect {|
    lua: test.lua:810: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:810: in function '__caml_init__'
    test.lua:2229: in main chunk
    [C]: in ?
    |}]

let%expect_test "nested partial applications" =
  compile_and_run
    {|
    let f a b c = a + b + c

    let () =
      let g = f 1 in
      let h = g 2 in
      print_int (h 3);
      print_newline ();
      (* Create another branch from g *)
      let h2 = g 10 in
      print_int (h2 20);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2188: in main chunk
    [C]: in ?
    |}]

let%expect_test "partial application with polymorphic function" =
  compile_and_run
    {|
    let pair x y = (x, y)

    let () =
      let pair_with_42 = pair 42 in
      let p1 = pair_with_42 10 in
      let p2 = pair_with_42 20 in
      print_int (fst p1);
      print_char ',';
      print_int (snd p1);
      print_newline ();
      print_int (fst p2);
      print_char ',';
      print_int (snd p2);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2197: in main chunk
    [C]: in ?
    |}]

let%expect_test "many arguments" =
  compile_and_run
    {|
    let sum_many a b c d e f g h = a + b + c + d + e + f + g + h

    let () =
      print_int (sum_many 1 2 3 4 5 6 7 8);
      print_newline ();
      (* Partial application with many args *)
      let partial = sum_many 1 2 3 4 in
      print_int (partial 5 6 7 8);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2202: in main chunk
    [C]: in ?
    |}]

let%expect_test "unit argument" =
  compile_and_run
    {|
    let make_counter () =
      let count = ref 0 in
      fun () ->
        incr count;
        !count

    let () =
      let c1 = make_counter () in
      let c2 = make_counter () in
      print_int (c1 ());
      print_char ' ';
      print_int (c1 ());
      print_char ' ';
      print_int (c2 ());
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2202: in main chunk
    [C]: in ?
    |}]

let%expect_test "ignoring arguments" =
  compile_and_run
    {|
    let const x _ = x

    let () =
      print_int (const 42 "ignored");
      print_newline ();
      print_int (const 100 999);
      print_newline ()
    |};
  [%expect {|
    lua: test.lua:805: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:805: in function '__caml_init__'
    test.lua:2180: in main chunk
    [C]: in ?
    |}]
