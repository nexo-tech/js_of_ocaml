let () = print_endline "Hello from Lua_of_ocaml!"

let factorial n =
  let rec loop acc i =
    if i <= 1 then acc
    else loop (acc * i) (i - 1)
  in
  loop 1 n

let () =
  Printf.printf "Factorial of 5 is: %d\n" (factorial 5);
  Printf.printf "Testing string operations...\n";
  let s = "lua_of_ocaml" in
  Printf.printf "Length of '%s': %d\n" s (String.length s);
  Printf.printf "Uppercase: %s\n" (String.uppercase_ascii s)
