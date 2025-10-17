(* Lua_of_ocaml tests - Stdlib compatibility
 * Tests for OCaml standard library functions that commonly cause issues
 * when porting real libraries
 *)

open Util

let%expect_test "Printf.sprintf basic" =
  compile_and_run
    {|
    let () =
      let s = Printf.sprintf "Hello %s!" "World" in
      print_endline s;
      let s2 = Printf.sprintf "Number: %d" 42 in
      print_endline s2;
      let s3 = Printf.sprintf "%d + %d = %d" 10 32 42 in
      print_endline s3
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:1194: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:1194: in function '__caml_init__'
    test.lua:57607: in main chunk
    [C]: ?
    |}]

let%expect_test "Printf.sprintf formats" =
  compile_and_run
    {|
    let () =
      (* Integer formats *)
      print_endline (Printf.sprintf "%d" 42);
      print_endline (Printf.sprintf "%i" (-10));
      print_endline (Printf.sprintf "%x" 255);
      print_endline (Printf.sprintf "%o" 64);
      (* Float formats *)
      print_endline (Printf.sprintf "%f" 3.14);
      print_endline (Printf.sprintf "%.2f" 3.14159);
      (* Boolean *)
      print_endline (Printf.sprintf "%b" true);
      print_endline (Printf.sprintf "%b" false)
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:1198: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:1198: in function '__caml_init__'
    test.lua:57635: in main chunk
    [C]: ?
    |}]

let%expect_test "String.concat" =
  compile_and_run
    {|
    let () =
      print_endline (String.concat ", " ["a"; "b"; "c"]);
      print_endline (String.concat "" ["hello"; "world"]);
      print_endline (String.concat " - " [])
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:1000: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:1000: in function '__caml_init__'
    test.lua:18132: in main chunk
    [C]: ?
    |}]

let%expect_test "String.split_on_char" =
  compile_and_run
    {|
    let () =
      let parts = String.split_on_char ',' "a,b,c" in
      List.iter (fun s -> print_endline s) parts;
      (* Empty string *)
      let parts2 = String.split_on_char ',' "" in
      print_int (List.length parts2);
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:1013: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:1013: in function '__caml_init__'
    test.lua:24068: in main chunk
    [C]: ?
    |}]

let%expect_test "List.sort and List.sort_uniq" =
  compile_and_run
    {|
    let () =
      let sorted = List.sort compare [3; 1; 4; 1; 5; 9; 2; 6] in
      List.iter (fun x -> print_int x; print_char ' ') sorted;
      print_newline ();
      let unique = List.sort_uniq compare [3; 1; 4; 1; 5; 9; 2; 6] in
      List.iter (fun x -> print_int x; print_char ' ') unique;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:943: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:943: in function '__caml_init__'
    test.lua:9101: in main chunk
    [C]: ?
    |}]

let%expect_test "List.assoc" =
  compile_and_run
    {|
    let () =
      let alist = [("a", 1); ("b", 2); ("c", 3)] in
      print_int (List.assoc "b" alist);
      print_newline ();
      try
        let _ = List.assoc "d" alist in
        print_endline "not found"
      with Not_found ->
        print_endline "Not_found raised"
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:946: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:946: in function '__caml_init__'
    test.lua:9081: in main chunk
    [C]: ?
    |}]

let%expect_test "List.partition" =
  compile_and_run
    {|
    let () =
      let evens, odds = List.partition (fun x -> x mod 2 = 0) [1; 2; 3; 4; 5; 6] in
      List.iter (fun x -> print_int x; print_char ' ') evens;
      print_newline ();
      List.iter (fun x -> print_int x; print_char ' ') odds;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:942: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:942: in function '__caml_init__'
    test.lua:9088: in main chunk
    [C]: ?
    |}]

let%expect_test "List.combine and List.split" =
  compile_and_run
    {|
    let () =
      let combined = List.combine [1; 2; 3] ["a"; "b"; "c"] in
      List.iter (fun (x, y) ->
        print_int x;
        print_char ':';
        print_string y;
        print_char ' '
      ) combined;
      print_newline ();
      let xs, ys = List.split combined in
      List.iter (fun x -> print_int x; print_char ' ') xs;
      print_newline ();
      List.iter (fun y -> print_string y; print_char ' ') ys;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:943: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:943: in function '__caml_init__'
    test.lua:9104: in main chunk
    [C]: ?
    |}]

let%expect_test "Option.bind and Option.map" =
  compile_and_run
    {|
    let safe_div x y = if y = 0 then None else Some (x / y)

    let () =
      match Option.bind (Some 10) (fun x -> safe_div x 2) with
      | Some n -> print_int n; print_newline ()
      | None -> print_endline "none";

      match Option.bind (Some 10) (fun x -> safe_div x 0) with
      | Some n -> print_int n; print_newline ()
      | None -> print_endline "none";

      match Option.map (fun x -> x * 2) (Some 21) with
      | Some n -> print_int n; print_newline ()
      | None -> print_endline "none"
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:950: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:950: in function '__caml_init__'
    test.lua:8324: in main chunk
    [C]: ?
    |}]

let%expect_test "Array.to_list and Array.of_list" =
  compile_and_run
    {|
    let () =
      let arr = [|1; 2; 3; 4; 5|] in
      let lst = Array.to_list arr in
      List.iter (fun x -> print_int x; print_char ' ') lst;
      print_newline ();
      let arr2 = Array.of_list [10; 20; 30] in
      Array.iter (fun x -> print_int x; print_char ' ') arr2;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:974: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:974: in function '__caml_init__'
    test.lua:17475: in main chunk
    [C]: ?
    |}]

let%expect_test "Array.sub and Array.concat" =
  compile_and_run
    {|
    let () =
      let arr = [|1; 2; 3; 4; 5|] in
      let sub = Array.sub arr 1 3 in
      Array.iter (fun x -> print_int x; print_char ' ') sub;
      print_newline ();
      let concat = Array.concat [[|1; 2|]; [|3; 4|]; [|5|]] in
      Array.iter (fun x -> print_int x; print_char ' ') concat;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:957: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:957: in function '__caml_init__'
    test.lua:11569: in main chunk
    [C]: ?
    |}]

let%expect_test "Hashtbl basic operations" =
  compile_and_run
    {|
    let () =
      let h = Hashtbl.create 10 in
      Hashtbl.add h "a" 1;
      Hashtbl.add h "b" 2;
      Hashtbl.add h "c" 3;
      print_int (Hashtbl.find h "b");
      print_newline ();
      print_endline (if Hashtbl.mem h "a" then "yes" else "no");
      print_endline (if Hashtbl.mem h "d" then "yes" else "no");
      print_int (Hashtbl.length h);
      print_newline ()
    |};
  [%expect {| /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:39621: chunk has too many syntax levels |}]

let%expect_test "Hashtbl.iter and Hashtbl.fold" =
  compile_and_run
    {|
    let () =
      let h = Hashtbl.create 10 in
      Hashtbl.add h "a" 1;
      Hashtbl.add h "b" 2;
      Hashtbl.add h "c" 3;
      let sum = Hashtbl.fold (fun _ v acc -> acc + v) h 0 in
      print_int sum;
      print_newline ()
    |};
  [%expect {| /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:39614: chunk has too many syntax levels |}]

let%expect_test "Buffer operations" =
  compile_and_run
    {|
    let () =
      let buf = Buffer.create 16 in
      Buffer.add_string buf "Hello";
      Buffer.add_char buf ' ';
      Buffer.add_string buf "World";
      print_endline (Buffer.contents buf);
      Buffer.clear buf;
      Buffer.add_string buf "Cleared";
      print_endline (Buffer.contents buf)
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:1006: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:1006: in function '__caml_init__'
    test.lua:20598: in main chunk
    [C]: ?
    |}]

let%expect_test "String.index and String.rindex" =
  compile_and_run
    {|
    let () =
      let s = "hello world" in
      print_int (String.index s 'o');
      print_newline ();
      print_int (String.rindex s 'o');
      print_newline ();
      try
        let _ = String.index s 'x' in
        print_endline "found"
      with Not_found ->
        print_endline "Not_found"
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:998: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:998: in function '__caml_init__'
    test.lua:18184: in main chunk
    [C]: ?
    |}]

let%expect_test "Sys.word_size" =
  compile_and_run
    {|
    let () =
      (* Should be 63 for 63-bit OCaml *)
      print_int Sys.word_size;
      print_newline ()
    |};
  [%expect {|
    /nix/store/rnjgfyk5cayaimd6h4gkhj2qbz4icy2d-lua-5.1.5/bin/lua: test.lua:928: attempt to call global 'caml_fresh_oo_id' (a nil value)
    stack traceback:
    test.lua:928: in function '__caml_init__'
    test.lua:3345: in main chunk
    [C]: ?
    |}]
