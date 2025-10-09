(* Lua_of_ocaml tests - General edge cases
 * Miscellaneous tricky cases that commonly break when compiling real code
 *)

open Util

let%expect_test "empty list patterns" =
  compile_and_run
    {|
    let () =
      match [] with
      | [] -> print_endline "empty"
      | _ :: _ -> print_endline "non-empty"
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "deeply nested pattern matching" =
  compile_and_run
    {|
    type tree = Leaf | Node of tree * int * tree

    let rec count = function
      | Leaf -> 0
      | Node (Leaf, n, Leaf) -> n
      | Node (Leaf, n, right) -> n + count right
      | Node (left, n, Leaf) -> count left + n
      | Node (left, n, right) -> count left + n + count right

    let () =
      let t = Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf)) in
      print_int (count t);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "mutual recursion across let rec" =
  compile_and_run
    {|
    let rec is_even n =
      n = 0 || is_odd (n - 1)
    and is_odd n =
      n <> 0 && is_even (n - 1)

    let () =
      print_endline (if is_even 100 then "even" else "odd");
      print_endline (if is_odd 99 then "odd" else "even")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "nested let rec" =
  compile_and_run
    {|
    let () =
      let rec outer n =
        if n <= 0 then 0
        else
          let rec inner m =
            if m <= 0 then 0
            else m + inner (m - 1)
          in
          inner n + outer (n - 1)
      in
      print_int (outer 3);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "lazy evaluation simulation" =
  compile_and_run
    {|
    type 'a lazy_t = Lazy of (unit -> 'a) | Forced of 'a

    let make_lazy f = Lazy f

    let force = function
      | Forced v -> v
      | Lazy f -> f ()

    let () =
      let expensive = make_lazy (fun () ->
        print_endline "computing...";
        42
      ) in
      print_int (force expensive);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "option chaining" =
  compile_and_run
    {|
    let ( >>= ) opt f =
      match opt with
      | None -> None
      | Some x -> f x

    let safe_div x y = if y = 0 then None else Some (x / y)

    let () =
      match Some 100 >>= fun x -> safe_div x 2 >>= fun y -> safe_div y 5 with
      | Some n -> print_int n; print_newline ()
      | None -> print_endline "none"
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "result type error handling" =
  compile_and_run
    {|
    type ('a, 'e) result = Ok of 'a | Error of 'e

    let safe_div x y =
      if y = 0 then Error "division by zero"
      else Ok (x / y)

    let () =
      match safe_div 42 2 with
      | Ok n -> print_int n; print_newline ()
      | Error msg -> print_endline msg;

      match safe_div 42 0 with
      | Ok n -> print_int n; print_newline ()
      | Error msg -> print_endline msg
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "accumulator pattern" =
  compile_and_run
    {|
    let rec sum_acc acc = function
      | [] -> acc
      | x :: xs -> sum_acc (acc + x) xs

    let rec rev_acc acc = function
      | [] -> acc
      | x :: xs -> rev_acc (x :: acc) xs

    let () =
      print_int (sum_acc 0 [1; 2; 3; 4; 5]);
      print_newline ();
      let rev = rev_acc [] [1; 2; 3; 4; 5] in
      List.iter (fun x -> print_int x; print_char ' ') rev;
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "continuation passing style simulation" =
  compile_and_run
    {|
    let rec factorial_cps n k =
      if n <= 1 then k 1
      else factorial_cps (n - 1) (fun result -> k (n * result))

    let () =
      print_int (factorial_cps 5 (fun x -> x));
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "state monad simulation" =
  compile_and_run
    {|
    let return x = fun s -> (x, s)

    let bind m f = fun s ->
      let (a, s') = m s in
      f a s'

    let get = fun s -> (s, s)

    let put s' = fun _ -> ((), s')

    let run_state m s = fst (m s)

    let counter =
      bind get (fun count ->
        bind (put (count + 1)) (fun () ->
          return count))

    let () =
      print_int (run_state counter 0);
      print_newline ();
      print_int (run_state counter 10);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "complex list comprehension pattern" =
  compile_and_run
    {|
    let rec range a b =
      if a > b then []
      else a :: range (a + 1) b

    let cartesian_product xs ys =
      List.concat (List.map (fun x ->
        List.map (fun y -> (x, y)) ys
      ) xs)

    let () =
      let pairs = cartesian_product [1; 2] [3; 4] in
      List.iter (fun (x, y) ->
        print_int x;
        print_char ',';
        print_int y;
        print_char ' '
      ) pairs;
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "memoization pattern" =
  compile_and_run
    {|
    let memo_fib () =
      let cache = Hashtbl.create 100 in
      let rec fib n =
        if Hashtbl.mem cache n then
          Hashtbl.find cache n
        else
          let result =
            if n <= 1 then n
            else fib (n - 1) + fib (n - 2)
          in
          Hashtbl.add cache n result;
          result
      in
      fib

    let () =
      let fib = memo_fib () in
      print_int (fib 10);
      print_newline ();
      print_int (fib 20);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "zipper pattern for lists" =
  compile_and_run
    {|
    type 'a zipper = { left : 'a list; focus : 'a; right : 'a list }

    let move_right z =
      match z.right with
      | [] -> None
      | r :: rs -> Some { left = z.focus :: z.left; focus = r; right = rs }

    let move_left z =
      match z.left with
      | [] -> None
      | l :: ls -> Some { left = ls; focus = l; right = z.focus :: z.right }

    let () =
      let z = { left = []; focus = 1; right = [2; 3; 4] } in
      match move_right z with
      | Some z2 ->
          print_int z2.focus;
          print_newline ()
      | None ->
          print_endline "none"
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "type witness pattern" =
  compile_and_run
    {|
    type int_witness = Int_witness
    type string_witness = String_witness

    type 'a value =
      | Int_value : int_witness value
      | String_value : string_witness value

    let show_int (type a) (w : a value) (x : int) : string =
      match w with
      | Int_value -> string_of_int x

    let () =
      print_endline (show_int Int_value 42)
    |};
  [%expect {| OCaml compilation failed: |}]

let%expect_test "varargs simulation with lists" =
  compile_and_run
    {|
    let sum_all nums = List.fold_left (+) 0 nums

    let () =
      print_int (sum_all [1; 2; 3]);
      print_newline ();
      print_int (sum_all [10; 20; 30; 40; 50]);
      print_newline ();
      print_int (sum_all []);
      print_newline ()
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]

let%expect_test "builder pattern" =
  compile_and_run
    {|
    type config = {
      name : string;
      port : int;
      debug : bool;
    }

    let default_config = {
      name = "app";
      port = 8080;
      debug = false;
    }

    let with_name name cfg = { cfg with name }
    let with_port port cfg = { cfg with port }
    let with_debug debug cfg = { cfg with debug }

    let () =
      let cfg =
        default_config
        |> with_name "myapp"
        |> with_port 3000
        |> with_debug true
      in
      print_endline cfg.name;
      print_int cfg.port;
      print_newline ();
      print_endline (if cfg.debug then "debug" else "no debug")
    |};
  [%expect {|
    Lua compilation failed:
    /bin/sh: 1: /home/snowbear/projects/js_of_ocaml/_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe: not found
    |}]
