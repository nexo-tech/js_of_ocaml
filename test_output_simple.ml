let () =
  print_endline "Test 1: print_endline works";

  (* Direct channel output *)
  let oc = stdout in
  output_string oc "Test 2: output_string works\n";
  flush oc;

  (* Printf with simple format *)
  Printf.printf "Test 3: Printf without arguments\n";

  (* Printf with one argument *)
  Printf.printf "Test 4: Printf with int %d\n" 42
