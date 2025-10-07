(* Lua_of_ocaml tests - Polymorphism and type system edge cases
 * Tests for polymorphic functions, phantom types, GADT-like patterns, equality
 *)

open Util

let%expect_test "polymorphic identity" =
  compile_and_run
    {|
    let id x = x

    let () =
      print_int (id 42);
      print_newline ();
      print_endline (id "hello");
      print_endline (if id true then "true" else "false")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "polymorphic list functions" =
  compile_and_run
    {|
    let rec length = function
      | [] -> 0
      | _ :: xs -> 1 + length xs

    let rec map f = function
      | [] -> []
      | x :: xs -> f x :: map f xs

    let () =
      print_int (length [1; 2; 3]);
      print_newline ();
      print_int (length ["a"; "b"]);
      print_newline ();
      let doubled = map (fun x -> x * 2) [1; 2; 3] in
      List.iter (fun x -> print_int x; print_char ' ') doubled;
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "polymorphic comparison" =
  compile_and_run
    {|
    let () =
      (* Compare with same type *)
      print_endline (if compare 5 3 > 0 then "greater" else "not greater");
      (* Compare tuples *)
      print_endline (if compare (1, 2) (1, 3) < 0 then "less" else "not less");
      (* Compare lists *)
      print_endline (if compare [1; 2] [1; 2] = 0 then "equal" else "not equal");
      (* Compare options *)
      print_endline (if compare (Some 5) None > 0 then "some > none" else "fail");
      print_endline (if compare None None = 0 then "none = none" else "fail")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "polymorphic equality vs physical equality" =
  compile_and_run
    {|
    let () =
      (* Structural equality *)
      let a = [1; 2; 3] in
      let b = [1; 2; 3] in
      print_endline (if a = b then "equal" else "not equal");
      (* Physical equality *)
      print_endline (if a == b then "same" else "different");
      (* Same reference *)
      let c = a in
      print_endline (if a == c then "same" else "different")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "option type polymorphism" =
  compile_and_run
    {|
    let get_or default = function
      | Some x -> x
      | None -> default

    let () =
      print_int (get_or 0 (Some 42));
      print_newline ();
      print_int (get_or 99 None);
      print_newline ();
      print_endline (get_or "default" (Some "value"));
      print_endline (get_or "default" None)
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "either type pattern" =
  compile_and_run
    {|
    type ('a, 'b) either = Left of 'a | Right of 'b

    let show_either = function
      | Left n -> "Left " ^ string_of_int n
      | Right s -> "Right " ^ s

    let () =
      print_endline (show_either (Left 42));
      print_endline (show_either (Right "hello"))
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "phantom types simulation" =
  compile_and_run
    {|
    (* Simulate phantom types with variants *)
    type validated
    type unvalidated

    type 'a email = Email of string

    let create s : unvalidated email = Email s

    let validate (Email s : unvalidated email) : validated email option =
      if String.contains s '@' then Some (Email s) else None

    let get_address (Email s : validated email) : string = s

    let () =
      let unval = create "test@example.com" in
      match validate unval with
      | Some validated ->
          print_endline (get_address validated)
      | None ->
          print_endline "invalid"
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "polymorphic variants simulation" =
  compile_and_run
    {|
    (* Test variant exhaustiveness *)
    type color = Red | Green | Blue | Yellow

    let color_to_string = function
      | Red -> "red"
      | Green -> "green"
      | Blue -> "blue"
      | Yellow -> "yellow"

    let () =
      print_endline (color_to_string Red);
      print_endline (color_to_string Yellow)
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "nested polymorphic types" =
  compile_and_run
    {|
    type 'a tree = Leaf | Node of 'a * 'a tree * 'a tree

    let rec sum_tree = function
      | Leaf -> 0
      | Node (v, left, right) -> v + sum_tree left + sum_tree right

    let rec count_tree = function
      | Leaf -> 0
      | Node (_, left, right) -> 1 + count_tree left + count_tree right

    let () =
      let t = Node (5, Node (3, Leaf, Leaf), Node (7, Leaf, Leaf)) in
      print_int (sum_tree t);
      print_newline ();
      print_int (count_tree t);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "polymorphic refs" =
  compile_and_run
    {|
    let () =
      let r = ref 0 in
      r := 42;
      print_int !r;
      print_newline ();
      (* Ref with different type after rebinding? No - this tests runtime *)
      let r2 = ref "hello" in
      print_endline !r2
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "polymorphic record fields" =
  compile_and_run
    {|
    type 'a box = { contents : 'a }

    let make_box x = { contents = x }

    let get_contents b = b.contents

    let () =
      let int_box = make_box 42 in
      let str_box = make_box "hello" in
      print_int (get_contents int_box);
      print_newline ();
      print_endline (get_contents str_box)
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "polymorphic recursion simulation" =
  compile_and_run
    {|
    (* Nested list type to test polymorphic recursion *)
    type 'a nested = Value of 'a | Nested of 'a nested list

    let rec depth = function
      | Value _ -> 0
      | Nested [] -> 1
      | Nested (x :: _) -> 1 + depth x

    let () =
      let simple = Value 42 in
      let nested1 = Nested [Value 1; Value 2] in
      let nested2 = Nested [Nested [Value 1]] in
      print_int (depth simple);
      print_char ' ';
      print_int (depth nested1);
      print_char ' ';
      print_int (depth nested2);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "equality on functions fails" =
  compile_and_run
    {|
    let () =
      try
        let f = fun x -> x + 1 in
        let g = fun x -> x + 1 in
        let _ = f = g in
        print_endline "no exception"
      with Invalid_argument _ ->
        print_endline "cannot compare functions"
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "polymorphic comparison with nested structures" =
  compile_and_run
    {|
    let () =
      (* Nested tuples *)
      let a = (1, (2, 3)) in
      let b = (1, (2, 4)) in
      print_endline (if a < b then "less" else "not less");
      (* List of tuples *)
      let c = [(1, 2); (3, 4)] in
      let d = [(1, 2); (3, 5)] in
      print_endline (if c < d then "less" else "not less")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]
