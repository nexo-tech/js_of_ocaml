(* Lua_of_ocaml tests - Name collisions and shadowing
 * Critical tests for ensuring OCaml identifiers don't clash with Lua keywords
 * and that shadowing works correctly
 *)

open Util

let%expect_test "lua keyword as ocaml identifier" =
  compile_and_run
    {|
    (* These are Lua keywords that are valid OCaml identifiers *)
    let local_value = 10 in
    let end_value = 20 in
    let function_value = 30 in
    let then_value = 40 in
    let else_value = 50 in
    let while_value = 60 in
    let do_value = 70 in
    let repeat_value = 80 in
    let until_value = 90 in
    let () =
      print_int (local_value + end_value + function_value);
      print_newline ();
      print_int (then_value + else_value + while_value);
      print_newline ();
      print_int (do_value + repeat_value + until_value);
      print_newline ()
    |};
  [%expect {| OCaml compilation failed: |}]

let%expect_test "shadowing local variables" =
  compile_and_run
    {|
    let () =
      let x = 10 in
      print_int x;
      print_newline ();
      let x = 20 in
      print_int x;
      print_newline ();
      let x = x + 5 in
      print_int x;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3119: in main chunk
    [C]: ?
    |}]

let%expect_test "shadowing in nested scopes" =
  compile_and_run
    {|
    let x = 1 in
    let () =
      print_int x;
      print_newline ();
      let f () =
        let x = 2 in
        print_int x;
        print_newline ();
        let g () =
          let x = 3 in
          print_int x;
          print_newline ()
        in
        g ();
        print_int x;
        print_newline ()
      in
      f ();
      print_int x;
      print_newline ()
    |};
  [%expect {| OCaml compilation failed: |}]

let%expect_test "function parameter shadowing" =
  compile_and_run
    {|
    let x = 100 in
    let f x =
      print_int x;
      print_newline ()
    in
    let () =
      f 42;
      print_int x;
      print_newline ()
    |};
  [%expect {| OCaml compilation failed: |}]

let%expect_test "pattern matching shadowing" =
  compile_and_run
    {|
    let x = 10 in
    let () =
      match Some 20 with
      | Some x ->
          print_int x;
          print_newline ()
      | None ->
          print_int x;
          print_newline ()
    in
    let () =
      print_int x;
      print_newline ()
    |};
  [%expect {| OCaml compilation failed: |}]

let%expect_test "loop variable shadowing" =
  compile_and_run
    {|
    let i = 100 in
    let () =
      for i = 1 to 3 do
        print_int i;
        print_char ' '
      done;
      print_newline ();
      print_int i;
      print_newline ()
    |};
  [%expect {| OCaml compilation failed: |}]

let%expect_test "lua builtin name as identifier" =
  compile_and_run
    {|
    (* Lua has builtins like print, type, pairs, ipairs, etc. *)
    let print = 42 in
    let type_val = 10 in
    let pairs = 20 in
    let ipairs = 30 in
    let next = 40 in
    let () =
      (* OCaml print_int should still work *)
      print_int (print + type_val + pairs + ipairs + next);
      print_newline ()
    |};
  [%expect {| OCaml compilation failed: |}]

let%expect_test "underscore identifiers" =
  compile_and_run
    {|
    let () =
      let _x = 10 in
      let _y_ = 20 in
      let __ = 30 in
      let x_y_z = 40 in
      print_int (_x + _y_ + __ + x_y_z);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3112: in main chunk
    [C]: ?
    |}]

let%expect_test "numeric suffixes in identifiers" =
  compile_and_run
    {|
    let () =
      let x1 = 10 in
      let x2 = 20 in
      let x10 = 30 in
      let x100 = 40 in
      print_int (x1 + x2 + x10 + x100);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3112: in main chunk
    [C]: ?
    |}]

let%expect_test "case sensitivity" =
  compile_and_run
    {|
    let () =
      let foo = 10 in
      let Foo = 20 in
      let FOO = 30 in
      let fOo = 40 in
      print_int (foo + Foo + FOO + fOo);
      print_newline ()
    |};
  [%expect {| OCaml compilation failed: |}]

let%expect_test "very long identifier names" =
  compile_and_run
    {|
    let () =
      let this_is_a_very_long_identifier_name_that_should_still_work = 42 in
      print_int this_is_a_very_long_identifier_name_that_should_still_work;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3106: in main chunk
    [C]: ?
    |}]

let%expect_test "apostrophe in identifiers" =
  compile_and_run
    {|
    let () =
      let x' = 10 in
      let x'' = 20 in
      let x'y' = 30 in
      print_int (x' + x'' + x'y');
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3110: in main chunk
    [C]: ?
    |}]

let%expect_test "module-like naming" =
  compile_and_run
    {|
    (* OCaml allows __ in identifiers from module flattening *)
    let () =
      let module__function = 10 in
      let Module__Type__value = 20 in
      print_int (module__function + Module__Type__value);
      print_newline ()
    |};
  [%expect {| OCaml compilation failed: |}]

let%expect_test "shadowing with same name in let rec" =
  compile_and_run
    {|
    let rec f n =
      if n <= 0 then 0
      else
        let f = n * 2 in
        f + f (n - 1)
    in
    let () =
      print_int (f 3);
      print_newline ()
    |};
  [%expect {| OCaml compilation failed: |}]

let%expect_test "multiple bindings same name" =
  compile_and_run
    {|
    let () =
      let x = 1 and y = 2 in
      print_int (x + y);
      print_newline ();
      (* This shadows both *)
      let x = 10 and y = 20 in
      print_int (x + y);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:925: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:925: in function '__caml_init__'
    test.lua:3116: in main chunk
    [C]: ?
    |}]

let%expect_test "exception names as identifiers" =
  compile_and_run
    {|
    exception My_error of int

    let () =
      try
        raise (My_error 42)
      with My_error n ->
        print_int n;
        print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:926: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:926: in function '__caml_init__'
    test.lua:3144: in main chunk
    [C]: ?
    |}]

let%expect_test "constructor names vs value names" =
  compile_and_run
    {|
    type result = Ok of int | Error of string

    let () =
      let Ok = 100 in
      let Error = 200 in
      (* Lowercase bindings shadow differently than constructors *)
      print_int Ok;
      print_char ' ';
      print_int Error;
      print_newline ();
      (* Constructors still work in pattern matching *)
      match result.Ok 42 with
      | result.Ok n -> print_int n; print_newline ()
      | result.Error _ -> print_endline "error"
    |};
  [%expect {| OCaml compilation failed: |}]
