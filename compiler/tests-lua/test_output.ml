(* Unit tests for Lua pretty printer *)

module Lua_ast = struct
  include Lua_of_ocaml_compiler__Lua_ast
end

module Lua_output = struct
  include Lua_of_ocaml_compiler__Lua_output
end

(** Helper to convert AST to string *)
let to_string program = Lua_output.program_to_string program

(** Test basic literals *)
let test_literals () =
  let open Lua_ast in
  (* nil *)
  assert (to_string [ return [ nil ] ] = "return nil\n");
  (* booleans *)
  assert (to_string [ return [ bool true ] ] = "return true\n");
  assert (to_string [ return [ bool false ] ] = "return false\n");
  (* numbers *)
  assert (to_string [ return [ number "42" ] ] = "return 42\n");
  assert (to_string [ return [ number "3.14" ] ] = "return 3.14\n");
  (* strings *)
  assert (to_string [ return [ string "hello" ] ] = "return \"hello\"\n");
  ()

(** Test operators *)
let test_operators () =
  let open Lua_ast in
  (* Arithmetic *)
  assert (to_string [ return [ binop Add (number "1") (number "2") ] ] = "return 1 + 2\n");
  assert (to_string [ return [ binop Sub (ident "x") (ident "y") ] ] = "return x - y\n");
  (* Precedence *)
  let expr = binop Add (binop Mul (number "2") (number "3")) (number "4") in
  assert (to_string [ return [ expr ] ] = "return 2 * 3 + 4\n");
  (* Parentheses needed *)
  let expr = binop Mul (binop Add (number "2") (number "3")) (number "4") in
  assert (to_string [ return [ expr ] ] = "return (2 + 3) * 4\n");
  ()

(** Test table constructors *)
let test_tables () =
  let open Lua_ast in
  (* Empty table *)
  assert (to_string [ return [ empty_table ] ] = "return {}\n");
  (* Array-style *)
  let t = table [ array_field (number "1"); array_field (number "2") ] in
  assert (to_string [ return [ t ] ] = "return {1, 2}\n");
  (* Record-style *)
  let t = table [ rec_field "x" (number "10"); rec_field "y" (number "20") ] in
  assert (to_string [ return [ t ] ] = "return {x = 10, y = 20}\n");
  ()

(** Test function expressions *)
let test_functions () =
  let open Lua_ast in
  (* Simple function *)
  let f = function_simple [ "x" ] [ return [ ident "x" ] ] in
  let expected = "return function(x)\n  return x\nend\n" in
  assert (to_string [ return [ f ] ] = expected);
  (* Function with vararg *)
  let f = function_ [] true [ return [ vararg ] ] in
  let expected = "return function(...)\n  return ...\nend\n" in
  assert (to_string [ return [ f ] ] = expected);
  ()

(** Test function declarations *)
let test_function_decls () =
  let open Lua_ast in
  (* Function declaration *)
  let decl =
    function_decl_simple "add" [ "a"; "b" ] [ return [ binop Add (ident "a") (ident "b") ] ]
  in
  let expected = "function add(a, b)\n  return a + b\nend\n" in
  assert (to_string [ decl ] = expected);
  ()

(** Test control flow *)
let test_control_flow () =
  let open Lua_ast in
  (* If statement *)
  let stmt = if_ (ident "x") [ return [ number "1" ] ] None in
  let expected = "if x then\n  return 1\nend\n" in
  assert (to_string [ stmt ] = expected);
  (* If-else *)
  let stmt = if_ (ident "x") [ return [ number "1" ] ] (Some [ return [ number "0" ] ]) in
  let expected = "if x then\n  return 1\nelse\n  return 0\nend\n" in
  assert (to_string [ stmt ] = expected);
  (* While loop *)
  let stmt = while_ (ident "x") [ assign [ ident "x" ] [ binop Sub (ident "x") (number "1") ] ] in
  let expected = "while x do\n  x = x - 1\nend\n" in
  assert (to_string [ stmt ] = expected);
  ()

(** Test for loops *)
let test_for_loops () =
  let open Lua_ast in
  (* Numeric for *)
  let stmt = for_num "i" (number "1") (number "10") [ call_stat (call (ident "print") [ ident "i" ]) ] in
  let expected = "for i = 1, 10 do\n  print(i)\nend\n" in
  assert (to_string [ stmt ] = expected);
  (* Generic for *)
  let stmt = for_in [ "k"; "v" ] [ call (ident "pairs") [ ident "t" ] ] [ call_stat (call (ident "print") [ ident "k" ]) ] in
  let expected = "for k, v in pairs(t) do\n  print(k)\nend\n" in
  assert (to_string [ stmt ] = expected);
  ()

(** Test complete program *)
let test_complete_program () =
  let open Lua_ast in
  let program =
    [ local [ "x" ] (Some [ number "10" ])
    ; function_decl_simple "double" [ "n" ] [ return [ binop Mul (ident "n") (number "2") ] ]
    ; local [ "result" ] (Some [ call (ident "double") [ ident "x" ] ])
    ; return [ ident "result" ]
    ]
  in
  let expected =
    "local x = 10\n\
     function double(n)\n\
    \  return n * 2\n\
     end\n\
     local result = double(x)\n\
     return result\n"
  in
  let output = to_string program in
  assert (output = expected);
  ()

(** Test table access *)
let test_table_access () =
  let open Lua_ast in
  (* Dot notation *)
  assert (to_string [ return [ dot (ident "obj") "field" ] ] = "return obj.field\n");
  (* Index notation *)
  assert (to_string [ return [ index (ident "t") (string "key") ] ] = "return t[\"key\"]\n");
  (* Method call *)
  assert (to_string [ return [ method_call (ident "obj") "method" [ ident "arg" ] ] ] = "return obj:method(arg)\n");
  ()

let () =
  test_literals ();
  test_operators ();
  test_tables ();
  test_functions ();
  test_function_decls ();
  test_control_flow ();
  test_for_loops ();
  test_complete_program ();
  test_table_access ();
  print_endline "All Lua output tests passed!"
