(* Lua_of_ocaml compiler main entry point *)

let run () =
  let open Cmdliner in
  let version = "%%VERSION%%" in
  let info = Cmd.info "lua_of_ocaml" ~version in
  let default = Term.(ret (const (`Help (`Pager, None)))) in
  let cmd = Cmd.group info ~default [] in
  exit (Cmd.eval cmd)

let () = run ()
