(* Comprehensive Array module test for lua_of_ocaml *)

let () =
  print_endline "=== Comprehensive Array Module Test Suite ===";
  print_endline ""

(* ==== Array Creation ==== *)
let () =
  print_endline "--- Array Creation ---";
  let arr = Array.make 5 0 in
  Printf.printf "Array.make 5 0: length %d\n" (Array.length arr);
  
  let arr2 = Array.init 5 (fun i -> i * 2) in
  Printf.printf "Array.init 5 (i*2): [";
  Array.iter (Printf.printf "%d; ") arr2;
  Printf.printf "]\n";
  
  let arr3 = [|1; 2; 3; 4; 5|] in
  Printf.printf "Array literal [|1;2;3;4;5|]: length %d\n" (Array.length arr3);
  print_endline ""

(* ==== Array Access ==== *)
let () =
  print_endline "--- Array Access ---";
  let arr = [|10; 20; 30; 40; 50|] in
  Printf.printf "arr.(0): %d\n" (Array.get arr 0);
  Printf.printf "arr.(2): %d\n" (Array.get arr 2);
  Printf.printf "arr.(4): %d\n" (Array.get arr 4);
  print_endline ""

(* ==== Array Modification ==== *)
let () =
  print_endline "--- Array Modification ---";
  let arr = Array.make 3 0 in
  Array.set arr 0 10;
  Array.set arr 1 20;
  Array.set arr 2 30;
  Printf.printf "After set: [";
  Array.iter (Printf.printf "%d; ") arr;
  Printf.printf "]\n";
  print_endline ""

(* ==== Array.map ==== *)
let () =
  print_endline "--- Array.map ---";
  let arr = [|1; 2; 3; 4; 5|] in
  let doubled = Array.map (fun x -> x * 2) arr in
  Printf.printf "Array.map (*2) [|1;2;3;4;5|]: [";
  Array.iter (Printf.printf "%d; ") doubled;
  Printf.printf "]\n";
  
  let squared = Array.map (fun x -> x * x) [|2; 3; 4|] in
  Printf.printf "Array.map (square) [|2;3;4|]: [";
  Array.iter (Printf.printf "%d; ") squared;
  Printf.printf "]\n";
  print_endline ""

(* ==== Array.mapi ==== *)
let () =
  print_endline "--- Array.mapi ---";
  let arr = [|10; 20; 30|] in
  let indexed = Array.mapi (fun i x -> i + x) arr in
  Printf.printf "Array.mapi (i+x) [|10;20;30|]: [";
  Array.iter (Printf.printf "%d; ") indexed;
  Printf.printf "]\n";
  print_endline ""

(* ==== Array.iter ==== *)
let () =
  print_endline "--- Array.iter ---";
  print_string "Array.iter print_int [|1;2;3;4;5|]: ";
  Array.iter (fun x -> Printf.printf "%d " x) [|1; 2; 3; 4; 5|];
  print_newline ();
  print_endline ""

(* ==== Array.iteri ==== *)
let () =
  print_endline "--- Array.iteri ---";
  print_string "Array.iteri (print index:value): ";
  Array.iteri (fun i x -> Printf.printf "(%d:%d) " i x) [|10; 20; 30|];
  print_newline ();
  print_endline ""

(* ==== Array.fold_left ==== *)
let () =
  print_endline "--- Array.fold_left ---";
  let arr = [|1; 2; 3; 4; 5|] in
  let sum = Array.fold_left (+) 0 arr in
  Printf.printf "Array.fold_left (+) 0 [|1;2;3;4;5|]: %d\n" sum;
  
  let product = Array.fold_left ( * ) 1 [|1; 2; 3; 4|] in
  Printf.printf "Array.fold_left (*) 1 [|1;2;3;4|]: %d\n" product;
  print_endline ""

(* ==== Array.fold_right ==== *)
let () =
  print_endline "--- Array.fold_right ---";
  let arr = [|1; 2; 3; 4; 5|] in
  let sum = Array.fold_right (+) arr 0 in
  Printf.printf "Array.fold_right (+) [|1;2;3;4;5|] 0: %d\n" sum;
  print_endline ""

(* ==== Array.append ==== *)
let () =
  print_endline "--- Array.append ---";
  let arr1 = [|1; 2; 3|] in
  let arr2 = [|4; 5; 6|] in
  let appended = Array.append arr1 arr2 in
  Printf.printf "Array.append [|1;2;3|] [|4;5;6|]: length %d\n" (Array.length appended);
  Printf.printf "Elements: [";
  Array.iter (Printf.printf "%d; ") appended;
  Printf.printf "]\n";
  print_endline ""

(* ==== Array.concat ==== *)
let () =
  print_endline "--- Array.concat ---";
  let arrays = [[|1; 2|]; [|3; 4|]; [|5; 6|]] in
  let concatenated = Array.concat arrays in
  Printf.printf "Array.concat: length %d\n" (Array.length concatenated);
  Printf.printf "Elements: [";
  Array.iter (Printf.printf "%d; ") concatenated;
  Printf.printf "]\n";
  print_endline ""

(* ==== Array.sub ==== *)
let () =
  print_endline "--- Array.sub ---";
  let arr = [|10; 20; 30; 40; 50|] in
  let sub1 = Array.sub arr 0 3 in
  Printf.printf "Array.sub [|10;20;30;40;50|] 0 3: [";
  Array.iter (Printf.printf "%d; ") sub1;
  Printf.printf "]\n";
  
  let sub2 = Array.sub arr 2 3 in
  Printf.printf "Array.sub [|10;20;30;40;50|] 2 3: [";
  Array.iter (Printf.printf "%d; ") sub2;
  Printf.printf "]\n";
  print_endline ""

(* ==== Array.for_all ==== *)
let () =
  print_endline "--- Array.for_all ---";
  let all_positive = Array.for_all (fun x -> x > 0) [|1; 2; 3; 4; 5|] in
  Printf.printf "Array.for_all (>0) [|1;2;3;4;5|]: %b\n" all_positive;
  
  let all_even = Array.for_all (fun x -> x mod 2 = 0) [|2; 4; 6; 8|] in
  Printf.printf "Array.for_all (even) [|2;4;6;8|]: %b\n" all_even;
  print_endline ""

(* ==== Array.exists ==== *)
let () =
  print_endline "--- Array.exists ---";
  let has_even = Array.exists (fun x -> x mod 2 = 0) [|1; 3; 5; 6; 7|] in
  Printf.printf "Array.exists (even) [|1;3;5;6;7|]: %b\n" has_even;
  print_endline ""

(* ==== Edge Cases ==== *)
let () =
  print_endline "--- Edge Cases ---";
  let empty = Array.make 0 0 in
  Printf.printf "Array.make 0 0: length %d\n" (Array.length empty);
  
  let init_empty = Array.init 0 (fun _ -> 42) in
  Printf.printf "Array.init 0: length %d\n" (Array.length init_empty);
  
  let concat_empty = Array.concat [] in
  Printf.printf "Array.concat []: length %d\n" (Array.length concat_empty);
  print_endline ""

(* ==== Combined Operations ==== *)
let () =
  print_endline "--- Combined Operations ---";
  let result = [|1; 2; 3; 4; 5; 6; 7; 8; 9; 10|]
    |> Array.map (fun x -> x * x)
    |> Array.to_list
    |> List.filter (fun x -> x mod 2 = 0)
    |> Array.of_list
  in
  Printf.printf "Square -> to_list -> filter even -> of_list: length %d\n" (Array.length result);
  print_endline ""

(* ==== Summary ==== *)
let () =
  print_endline "=== All Array Module Tests Complete ===";
  print_endline "✓ Array creation (make, init, literals)";
  print_endline "✓ Array access (get, length)";
  print_endline "✓ Array modification (set)";
  print_endline "✓ Higher-order functions (map, mapi)";
  print_endline "✓ Iteration (iter, iteri)";
  print_endline "✓ Folding (fold_left, fold_right)";
  print_endline "✓ Array operations (append, concat, sub)";
  print_endline "✓ Predicates (for_all, exists)";
  print_endline "✓ List conversion (to_list, of_list)";
  print_endline "✓ Edge cases and combined operations";
  print_endline "All tested Array module functions work successfully!"
