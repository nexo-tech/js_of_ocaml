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
    lua: test.lua:811: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:811: in function '__caml_init__'
    test.lua:2463: in main chunk
    [C]: in ?
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
    lua: test.lua:810: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:810: in function '__caml_init__'
    test.lua:2203: in main chunk
    [C]: in ?
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
    lua: test.lua:811: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:811: in function '__caml_init__'
    test.lua:2460: in main chunk
    [C]: in ?
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
    lua: test.lua:809: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:809: in function '__caml_init__'
    test.lua:2173: in main chunk
    [C]: in ?
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
    lua: test.lua:804: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:804: in function '__caml_init__'
    test.lua:2173: in main chunk
    [C]: in ?
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
    lua: test.lua:805: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:805: in function '__caml_init__'
    test.lua:2172: in main chunk
    [C]: in ?
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
    lua: test.lua:811: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:811: in function '__caml_init__'
    test.lua:2460: in main chunk
    [C]: in ?
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
    lua: test.lua:805: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:805: in function '__caml_init__'
    test.lua:2190: in main chunk
    [C]: in ?
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
    lua: test.lua:807: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:807: in function '__caml_init__'
    test.lua:2177: in main chunk
    [C]: in ?
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
    lua: test.lua:866: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:866: in function '__caml_init__'
    test.lua:10534: in main chunk
    [C]: in ?
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
    lua: test.lua:865: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:865: in function '__caml_init__'
    test.lua:10533: in main chunk
    [C]: in ?
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
    lua: test.lua:864: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:864: in function '__caml_init__'
    test.lua:10542: in main chunk
    [C]: in ?
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
    lua: test.lua:867: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:867: in function '__caml_init__'
    test.lua:10547: in main chunk
    [C]: in ?
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
    lua: test.lua:864: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:864: in function '__caml_init__'
    test.lua:10566: in main chunk
    [C]: in ?
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
    lua: test.lua:869: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:869: in function '__caml_init__'
    test.lua:10552: in main chunk
    [C]: in ?
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
    lua: test.lua:812: attempt to call a nil value (global 'caml_register_named_value')
    stack traceback:
    test.lua:812: in function '__caml_init__'
    test.lua:2190: in main chunk
    [C]: in ?
    |}]
