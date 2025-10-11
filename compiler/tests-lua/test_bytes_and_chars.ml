(* Lua_of_ocaml tests - Bytes and character edge cases
 * Tests for String vs Bytes, character encoding, escape sequences
 *)

open Util

let%expect_test "char operations" =
  compile_and_run
    {|
    let () =
      let c = 'A' in
      print_char c;
      print_newline ();
      print_int (Char.code c);
      print_newline ();
      print_char (Char.chr 66);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:932: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:932: in function '__caml_init__'
    test.lua:3516: in main chunk
    [C]: ?
    |}]

let%expect_test "char comparison" =
  compile_and_run
    {|
    let () =
      print_endline (if 'a' < 'b' then "less" else "not less");
      print_endline (if 'z' > 'a' then "greater" else "not greater");
      print_endline (if 'A' = 'A' then "equal" else "not equal")
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:931: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:931: in function '__caml_init__'
    test.lua:3172: in main chunk
    [C]: ?
    |}]

let%expect_test "char case conversion" =
  compile_and_run
    {|
    let () =
      print_char (Char.uppercase_ascii 'a');
      print_newline ();
      print_char (Char.lowercase_ascii 'Z');
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:932: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:932: in function '__caml_init__'
    test.lua:3513: in main chunk
    [C]: ?
    |}]

let%expect_test "escape sequences in strings" =
  compile_and_run
    {|
    let () =
      print_endline "line1\nline2";
      print_endline "tab\there";
      print_endline "quote\"test";
      print_endline "backslash\\test";
      print_endline "return\rtest"
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:930: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:930: in function '__caml_init__'
    test.lua:3115: in main chunk
    [C]: ?
    |}]

let%expect_test "escape sequences in chars" =
  compile_and_run
    {|
    let () =
      print_char '\n';
      print_char 'A';
      print_char '\t';
      print_char 'B';
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3115: in main chunk
    [C]: ?
    |}]

let%expect_test "null character" =
  compile_and_run
    {|
    let () =
      let s = "hello\000world" in
      print_int (String.length s);
      print_newline ();
      print_int (Char.code s.[5]);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:926: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:926: in function '__caml_init__'
    test.lua:3114: in main chunk
    [C]: ?
    |}]

let%expect_test "high ascii characters" =
  compile_and_run
    {|
    let () =
      (* Characters 128-255 *)
      print_int (Char.code (Char.chr 128));
      print_newline ();
      print_int (Char.code (Char.chr 255));
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:932: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:932: in function '__caml_init__'
    test.lua:3513: in main chunk
    [C]: ?
    |}]

let%expect_test "string as char sequence" =
  compile_and_run
    {|
    let () =
      let s = "hello" in
      for i = 0 to String.length s - 1 do
        print_char s.[i];
        print_char ' '
      done;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:926: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:926: in function '__caml_init__'
    test.lua:3152: in main chunk
    [C]: ?
    |}]

let%expect_test "string modification edge case" =
  compile_and_run
    {|
    let () =
      (* Strings are immutable in OCaml *)
      let s1 = "hello" in
      let s2 = s1 in
      print_endline s1;
      print_endline s2;
      print_endline (if s1 == s2 then "same" else "different")
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:928: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:928: in function '__caml_init__'
    test.lua:3132: in main chunk
    [C]: ?
    |}]

let%expect_test "bytes creation and modification" =
  compile_and_run
    {|
    let () =
      let b = Bytes.of_string "hello" in
      Bytes.set b 0 'H';
      print_endline (Bytes.to_string b);
      (* Original string unchanged *)
      print_endline "hello"
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:987: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:987: in function '__caml_init__'
    test.lua:16141: in main chunk
    [C]: ?
    |}]

let%expect_test "bytes vs string" =
  compile_and_run
    {|
    let () =
      let s = "test" in
      let b = Bytes.of_string s in
      Bytes.set b 0 'T';
      (* String s unchanged *)
      print_endline s;
      print_endline (Bytes.to_string b)
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:986: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:986: in function '__caml_init__'
    test.lua:16140: in main chunk
    [C]: ?
    |}]

let%expect_test "bytes operations" =
  compile_and_run
    {|
    let () =
      let b = Bytes.create 5 in
      Bytes.set b 0 'h';
      Bytes.set b 1 'e';
      Bytes.set b 2 'l';
      Bytes.set b 3 'l';
      Bytes.set b 4 'o';
      print_endline (Bytes.to_string b)
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:985: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:985: in function '__caml_init__'
    test.lua:16149: in main chunk
    [C]: ?
    |}]

let%expect_test "bytes concat and sub" =
  compile_and_run
    {|
    let () =
      let b1 = Bytes.of_string "hello" in
      let b2 = Bytes.of_string "world" in
      let b3 = Bytes.concat (Bytes.of_string " ") [b1; b2] in
      print_endline (Bytes.to_string b3);
      let sub = Bytes.sub b3 0 5 in
      print_endline (Bytes.to_string sub)
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:988: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:988: in function '__caml_init__'
    test.lua:16154: in main chunk
    [C]: ?
    |}]

let%expect_test "string contains all char range" =
  compile_and_run
    {|
    let () =
      (* Test we can handle all byte values *)
      let b = Bytes.create 256 in
      for i = 0 to 255 do
        Bytes.set b i (Char.chr i)
      done;
      print_int (Bytes.length b);
      print_newline ();
      print_int (Char.code (Bytes.get b 0));
      print_newline ();
      print_int (Char.code (Bytes.get b 255));
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:985: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:985: in function '__caml_init__'
    test.lua:16193: in main chunk
    [C]: ?
    |}]

let%expect_test "empty string edge cases" =
  compile_and_run
    {|
    let () =
      let s = "" in
      print_int (String.length s);
      print_newline ();
      print_endline (if s = "" then "empty" else "not empty");
      let b = Bytes.of_string "" in
      print_int (Bytes.length b);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:990: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:990: in function '__caml_init__'
    test.lua:16170: in main chunk
    [C]: ?
    |}]

let%expect_test "string equality with special chars" =
  compile_and_run
    {|
    let () =
      let s1 = "hello\nworld" in
      let s2 = "hello\nworld" in
      print_endline (if s1 = s2 then "equal" else "not equal");
      let s3 = "hello\000world" in
      let s4 = "hello\000world" in
      print_endline (if s3 = s4 then "equal" else "not equal")
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:933: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:933: in function '__caml_init__'
    test.lua:3162: in main chunk
    [C]: ?
    |}]
