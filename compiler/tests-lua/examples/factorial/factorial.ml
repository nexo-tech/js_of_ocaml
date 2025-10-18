let rec factorial n =
  if n <= 1 then 1
  else n * factorial (n - 1)

let () =
  for i = 1 to 10 do
    Printf.printf "factorial(%d) = %d\n" i (factorial i)
  done
