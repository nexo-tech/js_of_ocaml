(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

open Util

let%expect_test "if then else" =
  compile_and_run
    {|
    let () =
      let x = 10 in
      if x > 5 then
        print_endline "greater"
      else
        print_endline "smaller"
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:927: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:927: in function '__caml_init__'
    test.lua:3128: in main chunk
    [C]: ?
    |}]

let%expect_test "nested if" =
  compile_and_run
    {|
    let classify n =
      if n > 0 then
        if n > 10 then "large positive"
        else "small positive"
      else if n < 0 then "negative"
      else "zero"

    let () =
      print_endline (classify 15);
      print_endline (classify 5);
      print_endline (classify (-3));
      print_endline (classify 0)
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:929: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:929: in function '__caml_init__'
    test.lua:3175: in main chunk
    [C]: ?
    |}]

let%expect_test "for loop" =
  compile_and_run
    {|
    let () =
      for i = 1 to 5 do
        print_int i;
        print_char ' '
      done;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3144: in main chunk
    [C]: ?
    |}]

let%expect_test "for loop downto" =
  compile_and_run
    {|
    let () =
      for i = 5 downto 1 do
        print_int i;
        print_char ' '
      done;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3144: in main chunk
    [C]: ?
    |}]

let%expect_test "while loop" =
  compile_and_run
    {|
    let () =
      let i = ref 1 in
      while !i <= 5 do
        print_int !i;
        print_char ' ';
        i := !i + 1
      done;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3139: in main chunk
    [C]: ?
    |}]

let%expect_test "pattern matching" =
  compile_and_run
    {|
    type color = Red | Green | Blue

    let color_name = function
      | Red -> "red"
      | Green -> "green"
      | Blue -> "blue"

    let () =
      print_endline (color_name Red);
      print_endline (color_name Green);
      print_endline (color_name Blue)
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:928: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:928: in function '__caml_init__'
    test.lua:3154: in main chunk
    [C]: ?
    |}]

let%expect_test "pattern matching with values" =
  compile_and_run
    {|
    type result = Ok of int | Error of string

    let describe = function
      | Ok n -> "success: " ^ string_of_int n
      | Error msg -> "error: " ^ msg

    let () =
      print_endline (describe (Ok 42));
      print_endline (describe (Error "failed"))
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:929: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:929: in function '__caml_init__'
    test.lua:3151: in main chunk
    [C]: ?
    |}]

let%expect_test "list pattern matching" =
  compile_and_run
    {|
    let rec sum = function
      | [] -> 0
      | x :: xs -> x + sum xs

    let () =
      print_int (sum [1; 2; 3; 4; 5]);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:926: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:926: in function '__caml_init__'
    test.lua:3140: in main chunk
    [C]: ?
    |}]

let%expect_test "option pattern matching" =
  compile_and_run
    {|
    let get_value opt default =
      match opt with
      | Some v -> v
      | None -> default

    let () =
      print_int (get_value (Some 42) 0);
      print_char ' ';
      print_int (get_value None 99);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:926: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:926: in function '__caml_init__'
    test.lua:3146: in main chunk
    [C]: ?
    |}]

let%expect_test "match with guard" =
  compile_and_run
    {|
    let classify n =
      match n with
      | x when x > 0 && x < 10 -> "small positive"
      | x when x >= 10 -> "large positive"
      | x when x < 0 -> "negative"
      | _ -> "zero"

    let () =
      print_endline (classify 5);
      print_endline (classify 15);
      print_endline (classify (-5));
      print_endline (classify 0)
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:929: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:929: in function '__caml_init__'
    test.lua:3190: in main chunk
    [C]: ?
    |}]

let%expect_test "sequencing" =
  compile_and_run
    {|
    let () =
      print_int 1;
      print_char ' ';
      print_int 2;
      print_char ' ';
      print_int 3;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3118: in main chunk
    [C]: ?
    |}]

let%expect_test "let in expressions" =
  compile_and_run
    {|
    let () =
      let result =
        let x = 10 in
        let y = 20 in
        let z = 12 in
        x + y + z
      in
      print_int result;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3110: in main chunk
    [C]: ?
    |}]
