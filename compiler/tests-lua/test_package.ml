(* Test that lua_of_ocaml_compiler package can be loaded *)

let () =
  print_endline "lua_of_ocaml_compiler package loaded successfully";
  print_endline ("Version: " ^ Lua_of_ocaml_compiler.version);
  exit 0
