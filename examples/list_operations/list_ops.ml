(* Demonstrates List module usage *)

let () =
  print_endline "=== List Operations Example ===";
  print_endline "";
  
  (* Basic list operations *)
  let lst = [1; 2; 3; 4; 5] in
  Printf.printf "Original: ";
  List.iter (Printf.printf "%d ") lst;
  Printf.printf "\n";
  
  (* Map - transform each element *)
  let doubled = List.map (fun x -> x * 2) lst in
  Printf.printf "Doubled: ";
  List.iter (Printf.printf "%d ") doubled;
  Printf.printf "\n";
  
  (* Filter - keep only elements matching predicate *)
  let evens = List.filter (fun x -> x mod 2 = 0) lst in
  Printf.printf "Evens only: ";
  List.iter (Printf.printf "%d ") evens;
  Printf.printf "\n";
  
  (* Fold - reduce list to single value *)
  let sum = List.fold_left (+) 0 lst in
  Printf.printf "Sum: %d\n" sum;
  
  let product = List.fold_left ( * ) 1 lst in
  Printf.printf "Product: %d\n" product;
  
  (* Append - combine lists *)
  let lst2 = [6; 7; 8; 9; 10] in
  let combined = lst @ lst2 in
  Printf.printf "Combined [1..5] @ [6..10]: ";
  List.iter (Printf.printf "%d ") combined;
  Printf.printf "\n";
  
  (* Reverse *)
  let reversed = List.rev lst in
  Printf.printf "Reversed: ";
  List.iter (Printf.printf "%d ") reversed;
  Printf.printf "\n";
  
  (* Sort *)
  let unsorted = [3; 1; 4; 1; 5; 9; 2; 6] in
  let sorted = List.sort compare unsorted in
  Printf.printf "Sorted [3;1;4;1;5;9;2;6]: ";
  List.iter (Printf.printf "%d ") sorted;
  Printf.printf "\n";
  
  (* Advanced: chaining operations *)
  print_endline "";
  print_endline "Advanced: Chaining operations";
  let result = [1; 2; 3; 4; 5; 6; 7; 8; 9; 10]
    |> List.filter (fun x -> x mod 2 = 0)  (* Keep evens: [2;4;6;8;10] *)
    |> List.map (fun x -> x * x)           (* Square: [4;16;36;64;100] *)
    |> List.fold_left (+) 0                (* Sum: 220 *)
  in
  Printf.printf "Sum of squares of evens from [1..10]: %d\n" result;
  
  print_endline "";
  print_endline "All list operations work perfectly!"
