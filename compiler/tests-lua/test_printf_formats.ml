(* Test Printf format functionality after Task 5.3k fixes
   Tests dispatch infrastructure, control flow, and Set_field indexing *)

(* Test basic integer formats *)
let%expect_test "printf_int_basic" =
  Printf.printf "%d\n" 42;
  [%expect {| 42 |}]

let%expect_test "printf_int_negative" =
  Printf.printf "%d\n" (-42);
  [%expect {| -42 |}]

let%expect_test "printf_int_formats" =
  Printf.printf "%d %i %u %x %o\n" 42 42 42 42 42;
  [%expect {| 42 42 42 2a 52 |}]

(* Test string formats *)
let%expect_test "printf_string" =
  Printf.printf "%s\n" "Hello, World!";
  [%expect {| Hello, World! |}]

let%expect_test "printf_char" =
  Printf.printf "%c\n" 'A';
  [%expect {| A |}]

(* Test float formats - Task 5.3k.3 fix *)
let%expect_test "printf_float_basic" =
  Printf.printf "%f\n" 3.14;
  [%expect {| 3.140000 |}]

let%expect_test "printf_float_negative" =
  Printf.printf "%f\n" (-3.14);
  [%expect {| -3.140000 |}]

let%expect_test "printf_float_zero" =
  Printf.printf "%f\n" 0.0;
  [%expect {| 0.000000 |}]

let%expect_test "printf_float_precision" =
  Printf.printf "%.2f\n" 3.14159;
  [%expect {| 3.14 |}]

let%expect_test "printf_float_exponential" =
  Printf.printf "%e\n" 1.23e10;
  [%expect {| 1.230000e+10 |}]

let%expect_test "printf_float_general" =
  Printf.printf "%g\n" 0.00123;
  [%expect {| 0.00123 |}]

(* Test combined formats *)
let%expect_test "printf_mixed_formats" =
  Printf.printf "%d %s %f\n" 42 "test" 3.14;
  [%expect {| 42 test 3.140000 |}]

(* Test multiple Printf calls - Task 5.3k.1 fix (dispatch infrastructure) *)
let%expect_test "printf_multiple_calls" =
  Printf.printf "First: %d\n" 1;
  Printf.printf "Second: %s\n" "two";
  Printf.printf "Third: %f\n" 3.0;
  [%expect {|
    First: 1
    Second: two
    Third: 3.000000 |}]

(* Test format with width - verifies buffer operations work correctly *)
let%expect_test "printf_width" =
  Printf.printf "%5d\n" 42;
  [%expect {|    42 |}]

let%expect_test "printf_width_zero_pad" =
  Printf.printf "%05d\n" 42;
  [%expect {| 00042 |}]

(* Test sign forcing *)
let%expect_test "printf_force_sign" =
  Printf.printf "%+d\n" 42;
  [%expect {| +42 |}]

(* Test precision with floats *)
let%expect_test "printf_float_prec_0" =
  Printf.printf "%.0f\n" 3.7;
  [%expect {| 4 |}]

let%expect_test "printf_float_prec_10" =
  Printf.printf "%.10f\n" 3.14;
  [%expect {| 3.1400000000 |}]

(* Test edge cases *)
let%expect_test "printf_float_large" =
  Printf.printf "%f\n" 123456789.0;
  [%expect {| 123456789.000000 |}]

let%expect_test "printf_float_small" =
  Printf.printf "%f\n" 0.000001;
  [%expect {| 0.000001 |}]

(* Verify Task 5.3k.2 fix - control flow with continuation blocks *)
let%expect_test "printf_float_continuation" =
  (* This specifically tests that continuation blocks 572-587 execute correctly *)
  Printf.printf "%f %f %f\n" 1.1 2.2 3.3;
  [%expect {| 1.100000 2.200000 3.300000 |}]

(* Test that Set_field fix (Task 5.3k.3) doesn't break other code *)
let%expect_test "array_mutation" =
  let arr = [| 1; 2; 3 |] in
  arr.(0) <- 10;
  arr.(1) <- 20;
  arr.(2) <- 30;
  Printf.printf "%d %d %d\n" arr.(0) arr.(1) arr.(2);
  [%expect {| 10 20 30 |}]

let%expect_test "record_mutation" =
  let r = { contents = 0 } in
  r.contents <- 42;
  Printf.printf "%d\n" r.contents;
  [%expect {| 42 |}]
