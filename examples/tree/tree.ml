(* Binary Search Tree implementation demonstrating recursive data structures *)

type 'a tree =
  | Empty
  | Node of 'a * 'a tree * 'a tree

(* Insert a value into the tree *)
let rec insert x tree =
  match tree with
  | Empty -> Node (x, Empty, Empty)
  | Node (v, left, right) ->
      if x < v then
        Node (v, insert x left, right)
      else if x > v then
        Node (v, left, insert x right)
      else
        tree (* Value already exists *)

(* Search for a value in the tree *)
let rec search x tree =
  match tree with
  | Empty -> false
  | Node (v, left, right) ->
      if x < v then
        search x left
      else if x > v then
        search x right
      else
        true

(* In-order traversal (left, root, right) *)
let rec in_order tree acc =
  match tree with
  | Empty -> acc
  | Node (v, left, right) ->
      let acc' = in_order left acc in
      let acc'' = v :: acc' in
      in_order right acc''

(* Pre-order traversal (root, left, right) *)
let rec pre_order tree acc =
  match tree with
  | Empty -> acc
  | Node (v, left, right) ->
      let acc' = v :: acc in
      let acc'' = pre_order left acc' in
      pre_order right acc''

(* Post-order traversal (left, right, root) *)
let rec post_order tree acc =
  match tree with
  | Empty -> acc
  | Node (v, left, right) ->
      let acc' = post_order left acc in
      let acc'' = post_order right acc' in
      v :: acc''

(* Count nodes in the tree *)
let rec size tree =
  match tree with
  | Empty -> 0
  | Node (_, left, right) ->
      1 + size left + size right

(* Calculate height of the tree *)
let rec height tree =
  match tree with
  | Empty -> 0
  | Node (_, left, right) ->
      1 + max (height left) (height right)

(* Find minimum value *)
let rec find_min tree =
  match tree with
  | Empty -> None
  | Node (v, Empty, _) -> Some v
  | Node (_, left, _) -> find_min left

(* Find maximum value *)
let rec find_max tree =
  match tree with
  | Empty -> None
  | Node (v, _, Empty) -> Some v
  | Node (_, _, right) -> find_max right

(* Pretty print a list *)
let print_list lst =
  Printf.printf "[";
  let rec print_items = function
    | [] -> ()
    | [x] -> Printf.printf "%d" x
    | x :: xs ->
        Printf.printf "%d, " x;
        print_items xs
  in
  print_items lst;
  Printf.printf "]"

(* Print option value *)
let print_option = function
  | None -> Printf.printf "None"
  | Some x -> Printf.printf "Some %d" x

let () =
  Printf.printf "=== Binary Search Tree Demo ===\n\n";

  (* Create a tree by inserting values *)
  Printf.printf "Building tree with values: 5, 3, 7, 2, 4, 6, 8\n";
  let tree = Empty in
  let tree = insert 5 tree in
  let tree = insert 3 tree in
  let tree = insert 7 tree in
  let tree = insert 2 tree in
  let tree = insert 4 tree in
  let tree = insert 6 tree in
  let tree = insert 8 tree in
  Printf.printf "\n";

  (* Test search *)
  Printf.printf "Search tests:\n";
  Printf.printf "  Search 4: %b\n" (search 4 tree);
  Printf.printf "  Search 6: %b\n" (search 6 tree);
  Printf.printf "  Search 9: %b\n" (search 9 tree);
  Printf.printf "  Search 1: %b\n" (search 1 tree);
  Printf.printf "\n";

  (* Tree statistics *)
  Printf.printf "Tree statistics:\n";
  Printf.printf "  Size: %d nodes\n" (size tree);
  Printf.printf "  Height: %d\n" (height tree);
  Printf.printf "  Min value: ";
  print_option (find_min tree);
  Printf.printf "\n";
  Printf.printf "  Max value: ";
  print_option (find_max tree);
  Printf.printf "\n\n";

  (* Traversals *)
  Printf.printf "Tree traversals:\n";
  Printf.printf "  In-order:   ";
  let in_order_list = List.rev (in_order tree []) in
  print_list in_order_list;
  Printf.printf "\n";

  Printf.printf "  Pre-order:  ";
  let pre_order_list = List.rev (pre_order tree []) in
  print_list pre_order_list;
  Printf.printf "\n";

  Printf.printf "  Post-order: ";
  let post_order_list = List.rev (post_order tree []) in
  print_list post_order_list;
  Printf.printf "\n\n";

  (* Test with different tree *)
  Printf.printf "=== Testing with another tree ===\n";
  Printf.printf "Building tree with values: 10, 5, 15, 3, 7, 12, 20, 1\n";
  let tree2 = Empty in
  let tree2 = insert 10 tree2 in
  let tree2 = insert 5 tree2 in
  let tree2 = insert 15 tree2 in
  let tree2 = insert 3 tree2 in
  let tree2 = insert 7 tree2 in
  let tree2 = insert 12 tree2 in
  let tree2 = insert 20 tree2 in
  let tree2 = insert 1 tree2 in
  Printf.printf "\n";

  Printf.printf "Tree statistics:\n";
  Printf.printf "  Size: %d nodes\n" (size tree2);
  Printf.printf "  Height: %d\n" (height tree2);
  Printf.printf "  In-order traversal: ";
  let in_order_list2 = List.rev (in_order tree2 []) in
  print_list in_order_list2;
  Printf.printf "\n";

  (* Test duplicate insertion *)
  Printf.printf "\n=== Testing duplicate insertion ===\n";
  let tree3 = insert 5 (insert 5 (insert 5 Empty)) in
  Printf.printf "Inserted 5 three times, size: %d (should be 1)\n" (size tree3);
  Printf.printf "In-order traversal: ";
  let in_order_list3 = List.rev (in_order tree3 []) in
  print_list in_order_list3;
  Printf.printf "\n"
