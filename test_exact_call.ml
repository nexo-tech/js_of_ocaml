(* Test exact function calls for Task 3.1 *)

(* Two-argument function *)
let add x y = x + y

(* Test exact application *)
let result1 = add 5 3

(* Test partial application *)
let add5 = add 5
let result2 = add5 3

let () =
  print_int result1;
  print_newline ();
  print_int result2;
  print_newline ()
