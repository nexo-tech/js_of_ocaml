(* List module stdlib coverage audit *)
(* This test comprehensively audits OCaml's List module functions *)

let test_count = ref 0
let pass_count = ref 0
let fail_count = ref 0

let test name f =
  test_count := !test_count + 1;
  try
    f ();
    pass_count := !pass_count + 1;
    Printf.printf "✓ %s\n" name
  with e ->
    fail_count := !fail_count + 1;
    Printf.printf "✗ %s: %s\n" name (Printexc.to_string e)

let assert_int_eq name expected actual =
  if expected = actual then ()
  else failwith (Printf.sprintf "%s: expected %d, got %d" name expected actual)

let assert_bool name expected actual =
  (* Normalize booleans to avoid OCaml int vs Lua boolean issues *)
  let norm b = if b then 1 else 0 in
  if norm expected = norm actual then ()
  else
    let exp_str = if expected then "true" else "false" in
    let act_str = if actual then "true" else "false" in
    failwith (Printf.sprintf "%s: expected %s, got %s" name exp_str act_str)

let assert_list_eq name expected actual =
  if expected = actual then ()
  else failwith (Printf.sprintf "%s: lists not equal" name)

let assert_option_eq name expected actual =
  if expected = actual then ()
  else failwith (Printf.sprintf "%s: options not equal" name)

let () =
  Printf.printf "=== List Module Coverage Audit ===\n\n";

  (* Basic operations *)
  Printf.printf "--- Basic Operations ---\n";

  test "List.length empty" (fun () ->
    assert_int_eq "length" 0 (List.length []));

  test "List.length non-empty" (fun () ->
    assert_int_eq "length" 5 (List.length [1; 2; 3; 4; 5]));

  test "List.hd first element" (fun () ->
    assert_int_eq "hd" 1 (List.hd [1; 2; 3]));

  test "List.tl rest of list" (fun () ->
    assert_list_eq "tl" [2; 3] (List.tl [1; 2; 3]));

  test "List.nth access element" (fun () ->
    assert_int_eq "nth" 3 (List.nth [1; 2; 3; 4; 5] 2));

  test "List.nth first element" (fun () ->
    assert_int_eq "nth" 1 (List.nth [1; 2; 3] 0));

  test "List.nth last element" (fun () ->
    assert_int_eq "nth" 5 (List.nth [1; 2; 3; 4; 5] 4));

  (* List construction and deconstruction *)
  Printf.printf "\n--- List Construction ---\n";

  test "List.cons" (fun () ->
    assert_list_eq "cons" [0; 1; 2] (0 :: [1; 2]));

  test "List.append (@ operator)" (fun () ->
    assert_list_eq "append" [1; 2; 3; 4] ([1; 2] @ [3; 4]));

  test "List.append empty left" (fun () ->
    assert_list_eq "append" [1; 2] ([] @ [1; 2]));

  test "List.append empty right" (fun () ->
    assert_list_eq "append" [1; 2] ([1; 2] @ []));

  test "List.rev reverse" (fun () ->
    assert_list_eq "rev" [5; 4; 3; 2; 1] (List.rev [1; 2; 3; 4; 5]));

  test "List.rev empty" (fun () ->
    assert_list_eq "rev" [] (List.rev []));

  test "List.concat flatten" (fun () ->
    assert_list_eq "concat" [1; 2; 3; 4; 5; 6]
      (List.concat [[1; 2]; [3; 4]; [5; 6]]));

  test "List.concat empty" (fun () ->
    assert_list_eq "concat" [] (List.concat []));

  test "List.flatten (same as concat)" (fun () ->
    assert_list_eq "flatten" [1; 2; 3; 4]
      (List.flatten [[1; 2]; [3; 4]]));

  (* Iteration *)
  Printf.printf "\n--- Iteration ---\n";

  test "List.iter count" (fun () ->
    let count = ref 0 in
    List.iter (fun _ -> count := !count + 1) [1; 2; 3; 4; 5];
    assert_int_eq "iter" 5 !count);

  test "List.iter sum" (fun () ->
    let sum = ref 0 in
    List.iter (fun x -> sum := !sum + x) [1; 2; 3; 4; 5];
    assert_int_eq "iter" 15 !sum);

  test "List.iteri with index" (fun () ->
    let sum = ref 0 in
    List.iteri (fun i x -> sum := !sum + i + x) [10; 20; 30];
    assert_int_eq "iteri" 63 !sum);

  (* Mapping *)
  Printf.printf "\n--- Mapping ---\n";

  test "List.map double" (fun () ->
    assert_list_eq "map" [2; 4; 6] (List.map (fun x -> x * 2) [1; 2; 3]));

  test "List.map empty" (fun () ->
    assert_list_eq "map" [] (List.map (fun x -> x * 2) []));

  test "List.mapi with index" (fun () ->
    assert_list_eq "mapi" [0; 11; 22]
      (List.mapi (fun i x -> i + x) [0; 10; 20]));

  test "List.rev_map reverse and map" (fun () ->
    assert_list_eq "rev_map" [6; 4; 2]
      (List.rev_map (fun x -> x * 2) [1; 2; 3]));

  (* Filtering *)
  Printf.printf "\n--- Filtering ---\n";

  test "List.filter evens" (fun () ->
    assert_list_eq "filter" [2; 4; 6]
      (List.filter (fun x -> x mod 2 = 0) [1; 2; 3; 4; 5; 6]));

  test "List.filter empty result" (fun () ->
    assert_list_eq "filter" []
      (List.filter (fun x -> x > 10) [1; 2; 3]));

  test "List.filter all pass" (fun () ->
    assert_list_eq "filter" [1; 2; 3]
      (List.filter (fun _ -> true) [1; 2; 3]));

  test "List.find_all (same as filter)" (fun () ->
    assert_list_eq "find_all" [2; 4]
      (List.find_all (fun x -> x mod 2 = 0) [1; 2; 3; 4]));

  test "List.partition split" (fun () ->
    let evens, odds = List.partition (fun x -> x mod 2 = 0) [1; 2; 3; 4; 5] in
    assert_list_eq "partition evens" [2; 4] evens;
    assert_list_eq "partition odds" [1; 3; 5] odds);

  (* Folding *)
  Printf.printf "\n--- Folding ---\n";

  test "List.fold_left sum" (fun () ->
    let result = List.fold_left (+) 0 [1; 2; 3; 4; 5] in
    assert_int_eq "fold_left" 15 result);

  test "List.fold_left reverse" (fun () ->
    let result = List.fold_left (fun acc x -> x :: acc) [] [1; 2; 3] in
    assert_list_eq "fold_left" [3; 2; 1] result);

  test "List.fold_right sum" (fun () ->
    let result = List.fold_right (+) [1; 2; 3; 4; 5] 0 in
    assert_int_eq "fold_right" 15 result);

  test "List.fold_right cons" (fun () ->
    let result = List.fold_right (fun x acc -> x :: acc) [1; 2; 3] [] in
    assert_list_eq "fold_right" [1; 2; 3] result);

  (* Searching *)
  Printf.printf "\n--- Searching ---\n";

  test "List.find found" (fun () ->
    let result = List.find (fun x -> x > 3) [1; 2; 3; 4; 5] in
    assert_int_eq "find" 4 result);

  test "List.find_opt found" (fun () ->
    let result = List.find_opt (fun x -> x > 3) [1; 2; 3; 4; 5] in
    assert_option_eq "find_opt" (Some 4) result);

  test "List.find_opt not found" (fun () ->
    let result = List.find_opt (fun x -> x > 10) [1; 2; 3] in
    assert_option_eq "find_opt" None result);

  test "List.exists true" (fun () ->
    assert_bool "exists" true (List.exists (fun x -> x > 3) [1; 2; 3; 4; 5]));

  test "List.exists false" (fun () ->
    assert_bool "exists" false (List.exists (fun x -> x > 10) [1; 2; 3]));

  test "List.for_all true" (fun () ->
    assert_bool "for_all" true (List.for_all (fun x -> x > 0) [1; 2; 3]));

  test "List.for_all false" (fun () ->
    assert_bool "for_all" false (List.for_all (fun x -> x > 2) [1; 2; 3]));

  test "List.mem true" (fun () ->
    assert_bool "mem" true (List.mem 3 [1; 2; 3; 4; 5]));

  test "List.mem false" (fun () ->
    assert_bool "mem" false (List.mem 10 [1; 2; 3]));

  test "List.memq (physical equality)" (fun () ->
    let x = [1; 2] in
    assert_bool "memq" true (List.memq x [x; [3; 4]]));

  (* Association lists *)
  Printf.printf "\n--- Association Lists ---\n";

  test "List.assoc find value" (fun () ->
    let result = List.assoc "b" [("a", 1); ("b", 2); ("c", 3)] in
    assert_int_eq "assoc" 2 result);

  test "List.assoc_opt found" (fun () ->
    let result = List.assoc_opt "b" [("a", 1); ("b", 2); ("c", 3)] in
    assert_option_eq "assoc_opt" (Some 2) result);

  test "List.assoc_opt not found" (fun () ->
    let result = List.assoc_opt "x" [("a", 1); ("b", 2)] in
    assert_option_eq "assoc_opt" None result);

  test "List.mem_assoc true" (fun () ->
    assert_bool "mem_assoc" true
      (List.mem_assoc "b" [("a", 1); ("b", 2); ("c", 3)]));

  test "List.mem_assoc false" (fun () ->
    assert_bool "mem_assoc" false
      (List.mem_assoc "x" [("a", 1); ("b", 2)]));

  test "List.remove_assoc" (fun () ->
    let result = List.remove_assoc "b" [("a", 1); ("b", 2); ("c", 3)] in
    assert_list_eq "remove_assoc" [("a", 1); ("c", 3)] result);

  test "List.split pairs" (fun () ->
    let keys, values = List.split [("a", 1); ("b", 2); ("c", 3)] in
    assert_list_eq "split keys" ["a"; "b"; "c"] keys;
    assert_list_eq "split values" [1; 2; 3] values);

  test "List.combine pairs" (fun () ->
    let result = List.combine ["a"; "b"; "c"] [1; 2; 3] in
    assert_list_eq "combine" [("a", 1); ("b", 2); ("c", 3)] result);

  (* Sorting *)
  Printf.printf "\n--- Sorting ---\n";

  test "List.sort ascending" (fun () ->
    assert_list_eq "sort" [1; 2; 3; 4; 5]
      (List.sort compare [3; 1; 4; 1; 5; 9; 2; 6; 5]));

  test "List.sort descending" (fun () ->
    assert_list_eq "sort" [5; 4; 3; 2; 1]
      (List.sort (fun a b -> compare b a) [3; 1; 4; 2; 5]));

  test "List.stable_sort" (fun () ->
    assert_list_eq "stable_sort" [1; 2; 3; 4; 5]
      (List.stable_sort compare [3; 1; 4; 2; 5]));

  test "List.fast_sort (same as stable_sort)" (fun () ->
    assert_list_eq "fast_sort" [1; 2; 3; 4; 5]
      (List.fast_sort compare [3; 1; 4; 2; 5]));

  test "List.sort_uniq remove duplicates" (fun () ->
    assert_list_eq "sort_uniq" [1; 2; 3; 4; 5]
      (List.sort_uniq compare [3; 1; 4; 1; 5; 9; 2; 6; 5; 3; 5]));

  (* Comparison *)
  Printf.printf "\n--- Comparison ---\n";

  test "List.compare_lengths equal" (fun () ->
    assert_int_eq "compare_lengths" 0
      (List.compare_lengths [1; 2; 3] [4; 5; 6]));

  test "List.compare_lengths less" (fun () ->
    let result = List.compare_lengths [1; 2] [3; 4; 5] in
    if result < 0 then () else failwith "should be less");

  test "List.compare_lengths greater" (fun () ->
    let result = List.compare_lengths [1; 2; 3] [4; 5] in
    if result > 0 then () else failwith "should be greater");

  test "List.compare_length_with equal" (fun () ->
    assert_int_eq "compare_length_with" 0
      (List.compare_length_with [1; 2; 3] 3));

  test "List.compare_length_with less" (fun () ->
    let result = List.compare_length_with [1; 2] 5 in
    if result < 0 then () else failwith "should be less");

  test "List.compare_length_with greater" (fun () ->
    let result = List.compare_length_with [1; 2; 3] 2 in
    if result > 0 then () else failwith "should be greater");

  (* List manipulation *)
  Printf.printf "\n--- List Manipulation ---\n";

  test "List.init create list" (fun () ->
    assert_list_eq "init" [0; 1; 2; 3; 4]
      (List.init 5 (fun i -> i)));

  test "List.init with function" (fun () ->
    assert_list_eq "init" [0; 2; 4; 6; 8]
      (List.init 5 (fun i -> i * 2)));

  test "List.take first n" (fun () ->
    assert_list_eq "take" [1; 2; 3]
      (List.to_seq [1; 2; 3; 4; 5] |> Seq.take 3 |> List.of_seq));

  test "List.drop first n" (fun () ->
    assert_list_eq "drop" [4; 5]
      (List.to_seq [1; 2; 3; 4; 5] |> Seq.drop 3 |> List.of_seq));

  (* Conversion *)
  Printf.printf "\n--- Conversion ---\n";

  test "List.to_seq and of_seq" (fun () ->
    let result = [1; 2; 3; 4; 5] |> List.to_seq |> List.of_seq in
    assert_list_eq "to_seq/of_seq" [1; 2; 3; 4; 5] result);

  (* Edge cases and combinations *)
  Printf.printf "\n--- Edge Cases & Combinations ---\n";

  test "Complex pipeline: filter -> map -> fold" (fun () ->
    let result = [1; 2; 3; 4; 5; 6; 7; 8; 9; 10]
      |> List.filter (fun x -> x mod 2 = 0)
      |> List.map (fun x -> x * x)
      |> List.fold_left (+) 0 in
    assert_int_eq "pipeline" 220 result);

  test "Empty list operations" (fun () ->
    assert_list_eq "empty map" [] (List.map (fun x -> x * 2) []);
    assert_list_eq "empty filter" [] (List.filter (fun _ -> true) []);
    assert_int_eq "empty fold_left" 0 (List.fold_left (+) 0 []);
    assert_int_eq "empty fold_right" 0 (List.fold_right (+) [] 0));

  test "Single element list" (fun () ->
    assert_int_eq "single length" 1 (List.length [42]);
    assert_int_eq "single hd" 42 (List.hd [42]);
    assert_list_eq "single tl" [] (List.tl [42]);
    assert_list_eq "single map" [84] (List.map (fun x -> x * 2) [42]));

  test "Multiple rev operations" (fun () ->
    let result = [1; 2; 3] |> List.rev |> List.rev |> List.rev in
    assert_list_eq "triple rev" [3; 2; 1] result);

  test "Nested maps" (fun () ->
    let result = [1; 2; 3]
      |> List.map (fun x -> x * 2)
      |> List.map (fun x -> x + 1)
      |> List.map (fun x -> x * 3) in
    assert_list_eq "nested maps" [9; 15; 21] result);

  (* Summary *)
  Printf.printf "\n=== Summary ===\n";
  Printf.printf "Total tests: %d\n" !test_count;
  Printf.printf "Passed: %d\n" !pass_count;
  Printf.printf "Failed: %d\n" !fail_count;
  Printf.printf "Coverage: %d/%d\n" !pass_count !test_count;

  if !fail_count = 0 then
    Printf.printf "\n✅ All List tests PASSED!\n"
  else
    Printf.printf "\n⚠ %d tests failed\n" !fail_count
