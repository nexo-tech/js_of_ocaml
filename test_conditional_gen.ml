(* Simple test to verify conditional generation for non-exact calls *)

(* Function that takes unknown arity function *)
let apply_func f x y = f x y

(* This should generate a conditional since we don't know f's arity *)
let result = apply_func (fun a b -> a + b) 5 3

let () =
  print_int result;
  print_newline ()
