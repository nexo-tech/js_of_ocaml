(* Generator for embedding Lua runtime files into OCaml module *)

let read_file f =
  let ic = open_in f in
  let rec loop acc =
    try
      let line = input_line ic in
      loop (line :: acc)
    with End_of_file ->
      close_in ic;
      List.rev acc
  in
  String.concat "\n" (loop [])

let files = ref []

let () =
  for i = 1 to Array.length Sys.argv - 1 do
    let name = Sys.argv.(i) in
    if Filename.check_suffix name ".lua" then
      let content = read_file name in
      let basename = Filename.basename name in
      files := (basename, content) :: !files
  done;
  files := List.rev !files;

  (* Generate OCaml module with embedded runtime files *)
  print_endline "(* Generated file - do not edit *)";
  print_endline "";
  print_endline "let runtime = [";
  List.iter (fun (name, content) ->
    Printf.printf "  (%S, %S);\n" name content
  ) !files;
  print_endline "]";
  print_endline "";
  print_endline "let find name =";
  print_endline "  try Some (List.assoc name runtime) with Not_found -> None"