(* Comprehensive Hashtbl module test for lua_of_ocaml *)

let () =
  print_endline "=== Comprehensive Hashtbl Module Test Suite ===";
  print_endline ""

(* ==== Hashtbl Creation ==== *)
let () =
  print_endline "--- Hashtbl Creation ---";
  let h = Hashtbl.create 10 in
  Printf.printf "Hashtbl.create 10: length %d\n" (Hashtbl.length h);

  let h2 = Hashtbl.create 0 in
  Printf.printf "Hashtbl.create 0: length %d (should default to valid size)\n" (Hashtbl.length h2);
  print_endline ""

(* ==== Add and Find ==== *)
let () =
  print_endline "--- Add and Find ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "key1" "value1";
  Hashtbl.add h "key2" "value2";
  Hashtbl.add h "key3" "value3";
  Printf.printf "After adding 3 keys: length %d\n" (Hashtbl.length h);

  Printf.printf "find \"key1\": %s\n" (Hashtbl.find h "key1");
  Printf.printf "find \"key2\": %s\n" (Hashtbl.find h "key2");
  Printf.printf "find \"key3\": %s\n" (Hashtbl.find h "key3");
  print_endline ""

(* ==== Integer Keys ==== *)
let () =
  print_endline "--- Integer Keys ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h 1 "one";
  Hashtbl.add h 2 "two";
  Hashtbl.add h 3 "three";
  Printf.printf "find 1: %s\n" (Hashtbl.find h 1);
  Printf.printf "find 2: %s\n" (Hashtbl.find h 2);
  Printf.printf "find 3: %s\n" (Hashtbl.find h 3);
  print_endline ""

(* ==== Find_opt ==== *)
let () =
  print_endline "--- Find_opt ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "exists" "value";
  (match Hashtbl.find_opt h "exists" with
   | Some v -> Printf.printf "find_opt \"exists\": Some %s\n" v
   | None -> print_endline "find_opt \"exists\": None");
  (match Hashtbl.find_opt h "missing" with
   | Some v -> Printf.printf "find_opt \"missing\": Some %s\n" v
   | None -> print_endline "find_opt \"missing\": None");
  print_endline ""

(* ==== Mem ==== *)
let () =
  print_endline "--- Mem ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "key1" "value1";
  Printf.printf "mem \"key1\": %b\n" (Hashtbl.mem h "key1");
  Printf.printf "mem \"missing\": %b\n" (Hashtbl.mem h "missing");
  print_endline ""

(* ==== Remove ==== *)
let () =
  print_endline "--- Remove ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "key1" "value1";
  Hashtbl.add h "key2" "value2";
  Printf.printf "Before remove: length %d\n" (Hashtbl.length h);
  Hashtbl.remove h "key1";
  Printf.printf "After removing key1: length %d\n" (Hashtbl.length h);
  Printf.printf "mem \"key1\" after remove: %b\n" (Hashtbl.mem h "key1");
  Printf.printf "mem \"key2\" still there: %b\n" (Hashtbl.mem h "key2");
  print_endline ""

(* ==== Replace ==== *)
let () =
  print_endline "--- Replace ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "key1" "old_value";
  Printf.printf "Before replace: %s\n" (Hashtbl.find h "key1");
  Hashtbl.replace h "key1" "new_value";
  Printf.printf "After replace: %s\n" (Hashtbl.find h "key1");
  Printf.printf "Length after replace: %d\n" (Hashtbl.length h);

  (* Replace on new key should add it *)
  Hashtbl.replace h "key2" "value2";
  Printf.printf "After replacing new key: length %d\n" (Hashtbl.length h);
  print_endline ""

(* ==== Duplicate Keys ==== *)
let () =
  print_endline "--- Duplicate Keys (add multiple times) ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "dup" "first";
  Hashtbl.add h "dup" "second";
  Hashtbl.add h "dup" "third";
  Printf.printf "After adding 3 times: length %d\n" (Hashtbl.length h);
  Printf.printf "find returns most recent: %s\n" (Hashtbl.find h "dup");
  print_endline ""

(* ==== Find_all ==== *)
let () =
  print_endline "--- Find_all ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "multi" "first";
  Hashtbl.add h "multi" "second";
  Hashtbl.add h "multi" "third";
  let values = Hashtbl.find_all h "multi" in
  Printf.printf "find_all \"multi\" returns %d values: " (List.length values);
  List.iter (fun v -> Printf.printf "%s; " v) values;
  print_endline "";
  print_endline ""

(* ==== Clear ==== *)
let () =
  print_endline "--- Clear ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "k1" "v1";
  Hashtbl.add h "k2" "v2";
  Hashtbl.add h "k3" "v3";
  Printf.printf "Before clear: length %d\n" (Hashtbl.length h);
  Hashtbl.clear h;
  Printf.printf "After clear: length %d\n" (Hashtbl.length h);
  Printf.printf "mem \"k1\" after clear: %b\n" (Hashtbl.mem h "k1");
  print_endline ""

(* ==== Iter ==== *)
let () =
  print_endline "--- Iter ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "a" 1;
  Hashtbl.add h "b" 2;
  Hashtbl.add h "c" 3;
  print_endline "Iterating over entries:";
  Hashtbl.iter (fun k v -> Printf.printf "  %s -> %d\n" k v) h;
  print_endline ""

(* ==== Fold ==== *)
let () =
  print_endline "--- Fold ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "a" 10;
  Hashtbl.add h "b" 20;
  Hashtbl.add h "c" 30;
  let sum = Hashtbl.fold (fun _k v acc -> acc + v) h 0 in
  Printf.printf "Sum of values via fold: %d\n" sum;

  let count = Hashtbl.fold (fun _k _v acc -> acc + 1) h 0 in
  Printf.printf "Count via fold: %d\n" count;
  print_endline ""

(* ==== Copy ==== *)
let () =
  print_endline "--- Copy ---";
  let h1 = Hashtbl.create 10 in
  Hashtbl.add h1 "key1" "value1";
  Hashtbl.add h1 "key2" "value2";
  let h2 = Hashtbl.copy h1 in
  Printf.printf "Original length: %d\n" (Hashtbl.length h1);
  Printf.printf "Copy length: %d\n" (Hashtbl.length h2);

  (* Modify copy, should not affect original *)
  Hashtbl.add h2 "key3" "value3";
  Printf.printf "After adding to copy: original %d, copy %d\n"
    (Hashtbl.length h1) (Hashtbl.length h2);
  print_endline ""

(* ==== Length ==== *)
let () =
  print_endline "--- Length ---";
  let h = Hashtbl.create 10 in
  Printf.printf "Empty: length %d\n" (Hashtbl.length h);
  Hashtbl.add h "k1" "v1";
  Printf.printf "After 1 add: length %d\n" (Hashtbl.length h);
  Hashtbl.add h "k2" "v2";
  Hashtbl.add h "k3" "v3";
  Printf.printf "After 3 adds: length %d\n" (Hashtbl.length h);
  Hashtbl.remove h "k2";
  Printf.printf "After 1 remove: length %d\n" (Hashtbl.length h);
  print_endline ""

(* ==== Large Hashtbl (resize test) ==== *)
let () =
  print_endline "--- Large Hashtbl (automatic resize) ---";
  let h = Hashtbl.create 4 in
  for i = 1 to 100 do
    Hashtbl.add h i (i * 10)
  done;
  Printf.printf "After adding 100 entries: length %d\n" (Hashtbl.length h);

  (* Verify all entries are findable *)
  let all_found = ref true in
  for i = 1 to 100 do
    if Hashtbl.find h i <> i * 10 then all_found := false
  done;
  Printf.printf "All 100 entries findable: %b\n" !all_found;
  print_endline ""

(* ==== Mixed Types ==== *)
let () =
  print_endline "--- Mixed Types (polymorphic) ---";
  let h_int = Hashtbl.create 10 in
  Hashtbl.add h_int 42 "answer";
  Hashtbl.add h_int 7 "lucky";
  Printf.printf "Integer key 42: %s\n" (Hashtbl.find h_int 42);

  let h_float = Hashtbl.create 10 in
  Hashtbl.add h_float 3.14 "pi";
  Hashtbl.add h_float 2.71 "e";
  Printf.printf "Float key 3.14: %s\n" (Hashtbl.find h_float 3.14);
  print_endline ""

(* ==== Complex Values ==== *)
let () =
  print_endline "--- Complex Values ---";
  let h1 = Hashtbl.create 10 in
  Hashtbl.add h1 "list" [1; 2; 3; 4; 5];
  let list_val = Hashtbl.find h1 "list" in
  Printf.printf "List value length: %d\n" (List.length list_val);

  let h2 = Hashtbl.create 10 in
  Hashtbl.add h2 "tuple" [(1, "one"); (2, "two")];
  let tuple_val = Hashtbl.find h2 "tuple" in
  Printf.printf "Tuple list length: %d\n" (List.length tuple_val);
  print_endline ""

(* ==== Not_found Exception ==== *)
let () =
  print_endline "--- Not_found Exception ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "exists" "value";
  (try
    let _ = Hashtbl.find h "missing" in
    print_endline "ERROR: Should have raised Not_found"
  with Not_found ->
    print_endline "Correctly raised Not_found for missing key");
  print_endline ""

(* ==== Reset ==== *)
let () =
  print_endline "--- Reset ---";
  let h = Hashtbl.create 4 in
  (* Add many elements to cause resize *)
  for i = 1 to 20 do
    Hashtbl.add h i (i * 10)
  done;
  Printf.printf "After 20 adds: length %d\n" (Hashtbl.length h);
  Hashtbl.reset h;
  Printf.printf "After reset: length %d\n" (Hashtbl.length h);
  (* Can still use after reset *)
  Hashtbl.add h 100 999;
  Printf.printf "After adding to reset table: length %d\n" (Hashtbl.length h);
  print_endline ""

(* ==== Filter_map_inplace ==== *)
let () =
  print_endline "--- Filter_map_inplace ---";
  let h = Hashtbl.create 10 in
  Hashtbl.add h "a" 1;
  Hashtbl.add h "b" 2;
  Hashtbl.add h "c" 3;
  Hashtbl.add h "d" 4;
  Printf.printf "Before filter_map_inplace: length %d\n" (Hashtbl.length h);
  (* Keep even values, double them *)
  Hashtbl.filter_map_inplace (fun _k v ->
    if v mod 2 = 0 then Some (v * 2) else None
  ) h;
  Printf.printf "After filter_map_inplace: length %d\n" (Hashtbl.length h);
  print_endline "Remaining entries:";
  Hashtbl.iter (fun k v -> Printf.printf "  %s -> %d\n" k v) h;
  print_endline ""

(* ==== Stats ==== *)
let () =
  print_endline "--- Stats ---";
  let h = Hashtbl.create 10 in
  for i = 1 to 50 do
    Hashtbl.add h i (i * 2)
  done;
  let stats = Hashtbl.stats h in
  Printf.printf "Stats for 50-entry hashtbl:\n";
  Printf.printf "  num_bindings: %d\n" stats.num_bindings;
  Printf.printf "  num_buckets: %d\n" stats.num_buckets;
  Printf.printf "  max_bucket_length: %d\n" stats.max_bucket_length;
  Printf.printf "  bucket_histogram length: %d\n" (Array.length stats.bucket_histogram);
  print_endline ""

(* ==== Edge Cases ==== *)
let () =
  print_endline "--- Edge Cases ---";

  (* Empty string key *)
  let h = Hashtbl.create 10 in
  Hashtbl.add h "" "empty_key";
  Printf.printf "Empty string key: %s\n" (Hashtbl.find h "");

  (* Zero as key *)
  let h2 = Hashtbl.create 10 in
  Hashtbl.add h2 0 "zero";
  Printf.printf "Zero key: %s\n" (Hashtbl.find h2 0);

  (* Remove non-existent (should not error) *)
  Hashtbl.remove h "non_existent";
  Printf.printf "Remove non-existent: no error\n";

  print_endline ""

(* ==== Stress Test ==== *)
let () =
  print_endline "--- Stress Test ---";
  let h = Hashtbl.create 10 in

  (* Add 1000 entries *)
  for i = 1 to 1000 do
    Hashtbl.add h i (i * 3)
  done;

  (* Verify all can be found *)
  let errors = ref 0 in
  for i = 1 to 1000 do
    try
      let v = Hashtbl.find h i in
      if v <> i * 3 then incr errors
    with Not_found -> incr errors
  done;
  Printf.printf "Added 1000 entries, lookup errors: %d\n" !errors;

  (* Remove every other entry *)
  for i = 1 to 1000 do
    if i mod 2 = 0 then Hashtbl.remove h i
  done;
  Printf.printf "After removing evens: length %d\n" (Hashtbl.length h);

  (* Verify removed entries are gone *)
  let found_removed = ref 0 in
  for i = 2 to 1000 do
    if i mod 2 = 0 && Hashtbl.mem h i then incr found_removed
  done;
  Printf.printf "Should have removed evens, but found: %d\n" !found_removed;

  print_endline ""

(* ==== Final Summary ==== *)
let () =
  print_endline "=== Test Suite Complete ===";
  print_endline "All Hashtbl operations tested successfully!"
