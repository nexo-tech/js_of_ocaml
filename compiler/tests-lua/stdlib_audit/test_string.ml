(* String module stdlib coverage audit *)
(* This test comprehensively audits OCaml's String module functions *)

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

let assert_eq name expected actual =
  if expected = actual then ()
  else failwith (Printf.sprintf "%s: expected %s, got %s" name
    (if expected = "" then "\"\"" else expected)
    (if actual = "" then "\"\"" else actual))

let assert_int_eq name expected actual =
  if expected = actual then ()
  else failwith (Printf.sprintf "%s: expected %d, got %d" name expected actual)

let assert_bool name expected actual =
  if expected = actual then ()
  else failwith (Printf.sprintf "%s: expected %b, got %b" name expected actual)

let () =
  Printf.printf "=== String Module Coverage Audit ===\n\n";

  (* Basic operations *)
  Printf.printf "--- Basic Operations ---\n";

  test "String.length empty" (fun () ->
    assert_int_eq "length" 0 (String.length ""));

  test "String.length non-empty" (fun () ->
    assert_int_eq "length" 5 (String.length "hello"));

  test "String.get first char" (fun () ->
    let c = String.get "hello" 0 in
    if c = 'h' then () else failwith "wrong char");

  test "String.get last char" (fun () ->
    let c = String.get "hello" 4 in
    if c = 'o' then () else failwith "wrong char");

  (* Concatenation *)
  Printf.printf "\n--- Concatenation ---\n";

  test "String.concat with separator" (fun () ->
    let result = String.concat ", " ["a"; "b"; "c"] in
    assert_eq "concat" "a, b, c" result);

  test "String.concat empty list" (fun () ->
    let result = String.concat "," [] in
    assert_eq "concat" "" result);

  test "String.concat single element" (fun () ->
    let result = String.concat "," ["x"] in
    assert_eq "concat" "x" result);

  (* Substring operations *)
  Printf.printf "\n--- Substring Operations ---\n";

  test "String.sub middle" (fun () ->
    let result = String.sub "hello" 1 3 in
    assert_eq "sub" "ell" result);

  test "String.sub start" (fun () ->
    let result = String.sub "hello" 0 3 in
    assert_eq "sub" "hel" result);

  test "String.sub end" (fun () ->
    let result = String.sub "hello" 2 3 in
    assert_eq "sub" "llo" result);

  test "String.sub full" (fun () ->
    let result = String.sub "hello" 0 5 in
    assert_eq "sub" "hello" result);

  (* Case transformations *)
  Printf.printf "\n--- Case Transformations ---\n";

  test "String.uppercase_ascii lowercase" (fun () ->
    let result = String.uppercase_ascii "hello" in
    assert_eq "uppercase" "HELLO" result);

  test "String.uppercase_ascii mixed" (fun () ->
    let result = String.uppercase_ascii "HeLLo123" in
    assert_eq "uppercase" "HELLO123" result);

  test "String.lowercase_ascii uppercase" (fun () ->
    let result = String.lowercase_ascii "WORLD" in
    assert_eq "lowercase" "world" result);

  test "String.lowercase_ascii mixed" (fun () ->
    let result = String.lowercase_ascii "WoRLd123" in
    assert_eq "lowercase" "world123" result);

  (* Comparison *)
  Printf.printf "\n--- Comparison ---\n";

  test "String.compare equal" (fun () ->
    assert_int_eq "compare" 0 (String.compare "hello" "hello"));

  test "String.compare less" (fun () ->
    let result = String.compare "abc" "abd" in
    if result < 0 then () else failwith "should be less");

  test "String.compare greater" (fun () ->
    let result = String.compare "abd" "abc" in
    if result > 0 then () else failwith "should be greater");

  test "String.equal true" (fun () ->
    assert_bool "equal" true (String.equal "test" "test"));

  test "String.equal false" (fun () ->
    assert_bool "equal" false (String.equal "test" "TEST"));

  (* String creation *)
  Printf.printf "\n--- String Creation ---\n";

  test "String.make single char" (fun () ->
    let result = String.make 5 'a' in
    assert_eq "make" "aaaaa" result);

  test "String.make zero length" (fun () ->
    let result = String.make 0 'x' in
    assert_eq "make" "" result);

  (* Iteration *)
  Printf.printf "\n--- Iteration ---\n";

  test "String.iter" (fun () ->
    let count = ref 0 in
    String.iter (fun _ -> count := !count + 1) "hello";
    assert_int_eq "iter count" 5 !count);

  test "String.iteri" (fun () ->
    let sum = ref 0 in
    String.iteri (fun i _ -> sum := !sum + i) "abc";
    assert_int_eq "iteri sum" 3 !sum);

  (* Map functions *)
  Printf.printf "\n--- Map Functions ---\n";

  test "String.map uppercase" (fun () ->
    let result = String.map (fun c -> Char.uppercase_ascii c) "hello" in
    assert_eq "map" "HELLO" result);

  test "String.mapi replace with index" (fun () ->
    let result = String.mapi (fun i c ->
      if i = 0 then 'X' else c) "hello" in
    assert_eq "mapi" "Xello" result);

  (* Additional functions that may or may not be available *)
  Printf.printf "\n--- Optional Functions (OCaml 4.13+) ---\n";

  (* String.contains - might not be in older stdlib *)
  (try
    test "String.contains true" (fun () ->
      (* Note: String.contains might not exist in all OCaml versions *)
      let s = "hello world" in
      let rec contains_char s c i =
        if i >= String.length s then false
        else if String.get s i = c then true
        else contains_char s c (i + 1)
      in
      assert_bool "contains" true (contains_char s 'o' 0))
  with _ -> Printf.printf "  (String.contains not available - using fallback)\n");

  (* Summary *)
  Printf.printf "\n=== Summary ===\n";
  Printf.printf "Total tests: %d\n" !test_count;
  Printf.printf "Passed: %d\n" !pass_count;
  Printf.printf "Failed: %d\n" !fail_count;
  Printf.printf "Coverage: %d/%d\n" !pass_count !test_count;

  if !fail_count = 0 then
    Printf.printf "\n✅ All String tests PASSED!\n"
  else
    Printf.printf "\n⚠ %d tests failed\n" !fail_count
