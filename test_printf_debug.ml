(* Simple test to debug Printf channel issue *)

let () =
  Printf.printf "Hello, %s!\n" "world";
  print_endline "Test complete"
