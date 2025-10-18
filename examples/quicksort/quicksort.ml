(* Quicksort implementation demonstrating array manipulation *)

(* Swap two elements in an array *)
let swap arr i j =
  let temp = arr.(i) in
  arr.(i) <- arr.(j);
  arr.(j) <- temp

(* Partition array around pivot, return partition index *)
let partition arr low high =
  let pivot = arr.(high) in
  let i = ref (low - 1) in
  for j = low to high - 1 do
    if arr.(j) <= pivot then begin
      i := !i + 1;
      swap arr !i j
    end
  done;
  swap arr (!i + 1) high;
  !i + 1

(* Quicksort implementation using iterative partition *)
let rec quicksort arr low high =
  if low < high then begin
    let pi = partition arr low high in
    quicksort arr low (pi - 1);
    quicksort arr (pi + 1) high
  end

let print_array arr =
  Printf.printf "[";
  for i = 0 to Array.length arr - 1 do
    if i > 0 then Printf.printf ", ";
    Printf.printf "%d" arr.(i)
  done;
  Printf.printf "]\n"

let () =
  (* Test 1: Random unsorted array *)
  let arr1 = [| 64; 34; 25; 12; 22; 11; 90; 88 |] in
  Printf.printf "Original array: ";
  print_array arr1;
  quicksort arr1 0 (Array.length arr1 - 1);
  Printf.printf "Sorted array:   ";
  print_array arr1;
  Printf.printf "\n";

  (* Test 2: Already sorted array *)
  let arr2 = [| 1; 2; 3; 4; 5; 6; 7; 8 |] in
  Printf.printf "Already sorted: ";
  print_array arr2;
  quicksort arr2 0 (Array.length arr2 - 1);
  Printf.printf "After sorting:  ";
  print_array arr2;
  Printf.printf "\n";

  (* Test 3: Reverse sorted array *)
  let arr3 = [| 9; 7; 5; 3; 1 |] in
  Printf.printf "Reverse sorted: ";
  print_array arr3;
  quicksort arr3 0 (Array.length arr3 - 1);
  Printf.printf "After sorting:  ";
  print_array arr3;
  Printf.printf "\n";

  (* Test 4: Array with duplicates *)
  let arr4 = [| 5; 2; 8; 2; 9; 1; 5; 5 |] in
  Printf.printf "With duplicates: ";
  print_array arr4;
  quicksort arr4 0 (Array.length arr4 - 1);
  Printf.printf "After sorting:   ";
  print_array arr4;
  Printf.printf "\n";

  (* Test 5: Single element *)
  let arr5 = [| 42 |] in
  Printf.printf "Single element: ";
  print_array arr5;
  quicksort arr5 0 (Array.length arr5 - 1);
  Printf.printf "After sorting:  ";
  print_array arr5;
  Printf.printf "\n";

  (* Test 6: Two elements *)
  let arr6 = [| 2; 1 |] in
  Printf.printf "Two elements: ";
  print_array arr6;
  quicksort arr6 0 (Array.length arr6 - 1);
  Printf.printf "After sorting: ";
  print_array arr6
