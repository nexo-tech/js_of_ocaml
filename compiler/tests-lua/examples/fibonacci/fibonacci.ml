(* Fibonacci: Recursive and Iterative implementations *)

(* Simple recursive fibonacci - exponential time complexity *)
let rec fib_recursive n =
  if n <= 1 then n
  else fib_recursive (n - 1) + fib_recursive (n - 2)

(* Iterative fibonacci - linear time complexity *)
let fib_iterative n =
  if n <= 1 then n
  else
    let rec loop a b count =
      if count = 0 then a
      else loop b (a + b) (count - 1)
    in
    loop 0 1 n

(* Memoized fibonacci using array - linear time, space tradeoff *)
let fib_memoized n =
  if n <= 1 then n
  else
    let memo = Array.make (n + 1) 0 in
    memo.(0) <- 0;
    memo.(1) <- 1;
    for i = 2 to n do
      memo.(i) <- memo.(i - 1) + memo.(i - 2)
    done;
    memo.(n)

let () =
  print_endline "=== Fibonacci Number Calculator ===";
  print_endline "";
  
  print_endline "First 20 Fibonacci numbers (iterative):";
  for i = 0 to 19 do
    Printf.printf "fib(%d) = %d\n" i (fib_iterative i)
  done;
  
  print_endline "";
  print_endline "Comparison - fib(15) with different methods:";
  Printf.printf "Recursive: fib(15) = %d\n" (fib_recursive 15);
  Printf.printf "Iterative: fib(15) = %d\n" (fib_iterative 15);
  Printf.printf "Memoized:  fib(15) = %d\n" (fib_memoized 15);
  
  print_endline "";
  print_endline "Large Fibonacci numbers (iterative):";
  Printf.printf "fib(25) = %d\n" (fib_iterative 25);
  Printf.printf "fib(30) = %d\n" (fib_iterative 30);
  Printf.printf "fib(35) = %d\n" (fib_iterative 35);
  Printf.printf "fib(40) = %d\n" (fib_iterative 40)
