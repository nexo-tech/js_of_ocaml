(* Lua_of_ocaml tests
 * http://www.ocsigen.org/js_of_ocaml/
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *)

open Util

let%expect_test "string concatenation" =
  compile_and_run
    {|
    let () =
      let s = "Hello" ^ " " ^ "World" in
      print_endline s
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:928: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:928: in function '__caml_init__'
    test.lua:3109: in main chunk
    [C]: ?
    |}]

let%expect_test "string length" =
  compile_and_run
    {|
    let () =
      print_int (String.length "hello");
      print_newline ();
      print_int (String.length "");
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:927: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:927: in function '__caml_init__'
    test.lua:3114: in main chunk
    [C]: ?
    |}]

let%expect_test "string access" =
  compile_and_run
    {|
    let () =
      let s = "hello" in
      print_char s.[0];
      print_char s.[1];
      print_char s.[4];
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:926: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:926: in function '__caml_init__'
    test.lua:3116: in main chunk
    [C]: ?
    |}]

let%expect_test "string_of_int" =
  compile_and_run
    {|
    let () =
      print_endline (string_of_int 42);
      print_endline (string_of_int (-10));
      print_endline (string_of_int 0)
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3115: in main chunk
    [C]: ?
    |}]

let%expect_test "int_of_string" =
  compile_and_run
    {|
    let () =
      print_int (int_of_string "42");
      print_newline ();
      print_int (int_of_string "-10");
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:927: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:927: in function '__caml_init__'
    test.lua:3114: in main chunk
    [C]: ?
    |}]

let%expect_test "string compare" =
  compile_and_run
    {|
    let () =
      print_endline (if "abc" = "abc" then "equal" else "not equal");
      print_endline (if "abc" = "def" then "equal" else "not equal");
      print_endline (if "abc" < "def" then "less" else "greater")
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:937: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:937: in function '__caml_init__'
    test.lua:3175: in main chunk
    [C]: ?
    |}]

let%expect_test "string sub" =
  compile_and_run
    {|
    let () =
      let s = "hello world" in
      print_endline (String.sub s 0 5);
      print_endline (String.sub s 6 5)
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:996: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:996: in function '__caml_init__'
    test.lua:18127: in main chunk
    [C]: ?
    |}]

let%expect_test "string contains" =
  compile_and_run
    {|
    let () =
      let s = "hello" in
      print_endline (if String.contains s 'e' then "yes" else "no");
      print_endline (if String.contains s 'x' then "yes" else "no")
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:1000: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:1000: in function '__caml_init__'
    test.lua:18169: in main chunk
    [C]: ?
    |}]

let%expect_test "string make" =
  compile_and_run
    {|
    let () =
      print_endline (String.make 5 'a');
      print_endline (String.make 3 'x')
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:995: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:995: in function '__caml_init__'
    test.lua:18126: in main chunk
    [C]: ?
    |}]

let%expect_test "string escape sequences" =
  compile_and_run
    {|
    let () =
      print_endline "line1\nline2";
      print_endline "tab\there";
      print_endline "quote:\"hello\""
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:928: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:928: in function '__caml_init__'
    test.lua:3109: in main chunk
    [C]: ?
    |}]

let%expect_test "empty string" =
  compile_and_run
    {|
    let () =
      let s = "" in
      print_int (String.length s);
      print_newline ();
      print_endline (if s = "" then "empty" else "not empty")
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:929: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:929: in function '__caml_init__'
    test.lua:3133: in main chunk
    [C]: ?
    |}]

let%expect_test "string uppercase lowercase" =
  compile_and_run
    {|
    let () =
      print_endline (String.uppercase_ascii "hello");
      print_endline (String.lowercase_ascii "WORLD")
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:997: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:997: in function '__caml_init__'
    test.lua:18124: in main chunk
    [C]: ?
    |}]

let%expect_test "string trim" =
  compile_and_run
    {|
    let () =
      print_endline (String.trim "  hello  ");
      print_endline (String.trim "\n\tworld\t\n")
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:997: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:997: in function '__caml_init__'
    test.lua:18124: in main chunk
    [C]: ?
    |}]
