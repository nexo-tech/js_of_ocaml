(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

open Util

let%expect_test "array creation and access" =
  compile_and_run
    {|
    let () =
      let a = [|1; 2; 3; 4; 5|] in
      print_int a.(0);
      print_newline ();
      print_int a.(2);
      print_newline ();
      print_int a.(4);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:926: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:926: in function '__caml_init__'
    test.lua:3123: in main chunk
    [C]: ?
    |}]

let%expect_test "array set" =
  compile_and_run
    {|
    let () =
      let a = [|1; 2; 3|] in
      a.(1) <- 42;
      print_int a.(0);
      print_char ' ';
      print_int a.(1);
      print_char ' ';
      print_int a.(2);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3128: in main chunk
    [C]: ?
    |}]

let%expect_test "array length" =
  compile_and_run
    {|
    let () =
      let a = [|1; 2; 3; 4; 5|] in
      print_int (Array.length a);
      print_newline ();
      let b = [||] in
      print_int (Array.length b);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:926: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:926: in function '__caml_init__'
    test.lua:3115: in main chunk
    [C]: ?
    |}]

let%expect_test "array make" =
  compile_and_run
    {|
    let () =
      let a = Array.make 3 42 in
      print_int a.(0);
      print_char ' ';
      print_int a.(1);
      print_char ' ';
      print_int a.(2);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:956: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:956: in function '__caml_init__'
    test.lua:11525: in main chunk
    [C]: ?
    |}]

let%expect_test "array init" =
  compile_and_run
    {|
    let () =
      let a = Array.init 5 (fun i -> i * 2) in
      for i = 0 to 4 do
        print_int a.(i);
        if i < 4 then print_char ' '
      done;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:956: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:956: in function '__caml_init__'
    test.lua:11593: in main chunk
    [C]: ?
    |}]

let%expect_test "array iter" =
  compile_and_run
    {|
    let () =
      let a = [|1; 2; 3; 4; 5|] in
      Array.iter (fun x -> print_int x; print_char ' ') a;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:957: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:957: in function '__caml_init__'
    test.lua:11529: in main chunk
    [C]: ?
    |}]

let%expect_test "array map" =
  compile_and_run
    {|
    let () =
      let a = [|1; 2; 3; 4; 5|] in
      let b = Array.map (fun x -> x * 2) a in
      Array.iter (fun x -> print_int x; print_char ' ') b;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:957: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:957: in function '__caml_init__'
    test.lua:11545: in main chunk
    [C]: ?
    |}]

let%expect_test "array fold_left" =
  compile_and_run
    {|
    let () =
      let a = [|1; 2; 3; 4; 5|] in
      let sum = Array.fold_left (+) 0 a in
      print_int sum;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:957: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:957: in function '__caml_init__'
    test.lua:11529: in main chunk
    [C]: ?
    |}]

let%expect_test "array bounds check" =
  compile_and_run
    {|
    let () =
      let a = [|1; 2; 3|] in
      try
        let _ = a.(10) in
        print_endline "no exception"
      with Invalid_argument msg ->
        print_endline "caught: Invalid_argument"
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:927: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:927: in function '__caml_init__'
    test.lua:3157: in main chunk
    [C]: ?
    |}]
