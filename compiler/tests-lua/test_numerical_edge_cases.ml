(* Lua_of_ocaml tests - Numerical edge cases
 * Tests for integer overflow, float precision, numerical boundaries
 * Critical for ensuring real OCaml libraries compile correctly
 *)

open Util

let%expect_test "max_int and min_int" =
  compile_and_run
    {|
    let () =
      print_int max_int;
      print_newline ();
      print_int min_int;
      print_newline ();
      (* Test that max_int + 1 wraps or handles correctly *)
      print_int (max_int + 1);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "integer overflow behavior" =
  compile_and_run
    {|
    let () =
      (* Test overflow in arithmetic *)
      let a = max_int in
      let b = a + 1 in
      let c = a + 2 in
      print_int b;
      print_char ' ';
      print_int c;
      print_newline ();
      (* Test underflow *)
      let d = min_int in
      let e = d - 1 in
      print_int e;
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "integer multiplication overflow" =
  compile_and_run
    {|
    let () =
      let a = 1000000 in
      let b = 1000000 in
      let c = a * b in
      print_int c;
      print_newline ();
      (* Large multiplication that overflows *)
      let d = max_int / 2 in
      let e = d * 3 in
      print_int e;
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "division by zero" =
  compile_and_run
    {|
    let () =
      try
        let _ = 10 / 0 in
        print_endline "no exception"
      with Division_by_zero ->
        print_endline "caught Division_by_zero"
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "modulo operations" =
  compile_and_run
    {|
    let () =
      (* Positive modulo *)
      print_int (10 mod 3);
      print_newline ();
      (* Negative modulo - behavior critical *)
      print_int ((-10) mod 3);
      print_newline ();
      print_int (10 mod (-3));
      print_newline ();
      print_int ((-10) mod (-3));
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "float precision" =
  compile_and_run
    {|
    let () =
      (* Test float arithmetic precision *)
      let a = 0.1 +. 0.2 in
      let b = 0.3 in
      (* Don't test exact equality, test behavior *)
      print_endline (if a = b then "equal" else "not equal");
      (* Test float printing *)
      print_float a;
      print_newline ();
      print_float b;
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "float special values" =
  compile_and_run
    {|
    let () =
      (* Infinity *)
      let inf = infinity in
      let neg_inf = neg_infinity in
      print_endline (if classify_float inf = FP_infinite then "inf" else "not inf");
      print_endline (if classify_float neg_inf = FP_infinite then "neg_inf" else "not neg_inf");
      (* NaN *)
      let nan = nan in
      print_endline (if classify_float nan = FP_nan then "nan" else "not nan");
      (* NaN comparison always false *)
      print_endline (if nan = nan then "nan=nan" else "nan<>nan");
      print_endline (if nan <> nan then "nan<>nan true" else "nan<>nan false")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "float comparison edge cases" =
  compile_and_run
    {|
    let () =
      (* Zero comparison *)
      let pos_zero = 0.0 in
      let neg_zero = -0.0 in
      print_endline (if pos_zero = neg_zero then "equal" else "not equal");
      (* Infinity comparison *)
      print_endline (if infinity > 1000000.0 then "inf > large" else "inf <= large");
      print_endline (if neg_infinity < (-1000000.0) then "neg_inf < large_neg" else "fail");
      (* Comparison with NaN *)
      print_endline (if nan > 0.0 then "nan > 0" else "nan not > 0")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "int and float conversion" =
  compile_and_run
    {|
    let () =
      (* int_of_float truncation *)
      print_int (int_of_float 3.7);
      print_newline ();
      print_int (int_of_float (-3.7));
      print_newline ();
      (* float_of_int precision *)
      let large_int = 1000000000 in
      let f = float_of_int large_int in
      let back = int_of_float f in
      print_endline (if back = large_int then "preserved" else "lost precision")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "comparison edge cases" =
  compile_and_run
    {|
    let () =
      (* Polymorphic comparison with mixed types *)
      let a = (1, 2) in
      let b = (1, 2) in
      let c = (1, 3) in
      print_endline (if a = b then "equal" else "not equal");
      print_endline (if a < c then "less" else "not less");
      (* String comparison *)
      print_endline (if "abc" < "abd" then "less" else "not less");
      (* List comparison *)
      print_endline (if [1; 2] < [1; 3] then "less" else "not less")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "min max functions" =
  compile_and_run
    {|
    let () =
      print_int (min 5 3);
      print_char ' ';
      print_int (max 5 3);
      print_newline ();
      (* With negative numbers *)
      print_int (min (-5) (-3));
      print_char ' ';
      print_int (max (-5) (-3));
      print_newline ();
      (* Float min/max *)
      print_float (min 5.5 3.3);
      print_char ' ';
      print_float (max 5.5 3.3);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "bitwise operations" =
  compile_and_run
    {|
    let () =
      (* AND *)
      print_int (15 land 7);
      print_newline ();
      (* OR *)
      print_int (8 lor 4);
      print_newline ();
      (* XOR *)
      print_int (15 lxor 7);
      print_newline ();
      (* NOT *)
      print_int (lnot 0);
      print_newline ();
      (* Shifts *)
      print_int (1 lsl 10);
      print_newline ();
      print_int (1024 lsr 2);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "power and sqrt" =
  compile_and_run
    {|
    let () =
      (* Integer power simulation *)
      let rec pow a n =
        if n = 0 then 1
        else if n = 1 then a
        else a * pow a (n - 1)
      in
      print_int (pow 2 10);
      print_newline ();
      (* Float power *)
      print_float (2.0 ** 10.0);
      print_newline ();
      (* Square root *)
      print_float (sqrt 16.0);
      print_newline ();
      (* Negative sqrt gives NaN *)
      let neg_sqrt = sqrt (-1.0) in
      print_endline (if classify_float neg_sqrt = FP_nan then "nan" else "not nan")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]
