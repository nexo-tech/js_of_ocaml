(* OCaml program to generate marshal test data for Lua compatibility tests *)

type color = Red | Green | Blue | RGB of int * int * int

type person = { name : string; age : int; email : string }

type tree = Leaf | Node of int * tree * tree

let write_test name value =
  let filename = "test_data_" ^ name ^ ".bin" in
  let oc = open_out_bin filename in
  Marshal.to_channel oc value [];
  close_out oc;
  Printf.printf "Generated: %s\n" filename

let write_test_noshare name value =
  let filename = "test_data_" ^ name ^ "_noshare.bin" in
  let oc = open_out_bin filename in
  Marshal.to_channel oc value [Marshal.No_sharing];
  close_out oc;
  Printf.printf "Generated: %s\n" filename

let () =
  (* Integers *)
  write_test "int_0" 0;
  write_test "int_42" 42;
  write_test "int_neg" (-128);
  write_test "int_large" 1234567;

  (* Strings *)
  write_test "str_empty" "";
  write_test "str_hello" "Hello, World!";
  write_test "str_unicode" "Hello, 世界! 🌍";
  write_test "str_long" (String.make 1000 'x');

  (* Floats *)
  write_test "float_pi" 3.14159265359;
  write_test "float_zero" 0.0;
  write_test "float_neg" (-42.5);
  write_test "float_inf" infinity;
  write_test "float_neginf" neg_infinity;
  write_test "float_nan" nan;

  (* Lists *)
  write_test "list_empty" [];
  write_test "list_ints" [1; 2; 3; 4; 5];
  write_test "list_strings" ["a"; "b"; "c"];

  (* Options *)
  write_test "option_none" None;
  write_test "option_some" (Some 42);
  write_test "option_some_str" (Some "hello");

  (* Results *)
  write_test "result_ok" (Ok 100);
  write_test "result_error" (Error "failure");

  (* Tuples (represented as blocks) *)
  write_test "tuple_2" (1, "two");
  write_test "tuple_3" (1, 2.5, "three");

  (* Variants *)
  write_test "variant_red" Red;
  write_test "variant_rgb" (RGB (255, 128, 0));

  (* Nested structures *)
  write_test "nested_list" [[1; 2]; [3; 4]; [5; 6]];
  write_test "nested_option" (Some (Some (Some 42)));

  (* Sharing *)
  let shared = [1; 2; 3] in
  write_test "sharing" (shared, shared);
  write_test_noshare "sharing" (shared, shared);

  (* Cycles *)
  let rec cycle = 1 :: 2 :: 3 :: cycle in
  write_test "cycle_list" cycle;

  (* Custom types - Int64 *)
  write_test "int64_small" 42L;
  write_test "int64_large" 9876543210L;

  (* Custom types - Int32 *)
  write_test "int32_small" 100l;
  write_test "int32_large" 2147483647l;

  (* Arrays *)
  write_test "array_empty" [||];
  write_test "array_ints" [|1; 2; 3; 4; 5|];
  write_test "array_strings" [|"a"; "b"; "c"|];

  (* Records *)
  let alice = { name = "Alice"; age = 30; email = "alice@example.com" } in
  write_test "record_person" alice;

  (* Complex nested structure *)
  let tree = Node (5,
                   Node (3, Leaf, Leaf),
                   Node (7, Leaf, Leaf)) in
  write_test "tree" tree;

  Printf.printf "\nAll test data generated successfully!\n"
