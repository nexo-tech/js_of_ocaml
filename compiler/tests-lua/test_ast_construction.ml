(* Unit tests for Lua AST construction *)

(* The library wraps modules with __ prefix *)
module Lua_ast = struct
  include Lua_of_ocaml_compiler__Lua_ast
end

(* Test that AST module exports work correctly *)
let test_literals () =
  let open Lua_ast in
  (* Test literal constructors *)
  let _ : expr = nil in
  let _ : expr = bool true in
  let _ : expr = bool false in
  let _ : expr = number "42" in
  let _ : expr = number_of_int 10 in
  let _ : expr = number_of_float 3.14 in
  let _ : expr = string "hello" in
  ()

let test_tables () =
  let open Lua_ast in
  (* Empty table *)
  let _ : expr = empty_table in
  (* Array-style table: {1, 2, 3} *)
  let _ : expr =
    table
      [ array_field (number_of_int 1)
      ; array_field (number_of_int 2)
      ; array_field (number_of_int 3)
      ]
  in
  (* Record-style table: {x = 10, y = 20} *)
  let _ : expr =
    table [ rec_field "x" (number_of_int 10); rec_field "y" (number_of_int 20) ]
  in
  (* Mixed table *)
  let _ : expr =
    table
      [ rec_field "name" (string "value")
      ; general_field (string "key") (number_of_int 42)
      ; array_field (bool true)
      ]
  in
  ()

let test_functions () =
  let open Lua_ast in
  (* Function expression: function(x, y) return x + y end *)
  let _ : expr =
    function_simple [ "x"; "y" ] [ return [ binop Add (ident "x") (ident "y") ] ]
  in
  (* Function with vararg: function(...) return ... end *)
  let _ : expr = function_ [] true [ return [ vararg ] ] in
  (* Function declaration: function add(x, y) return x + y end *)
  let _ : stat =
    function_decl_simple
      "add"
      [ "x"; "y" ]
      [ return [ binop Add (ident "x") (ident "y") ] ]
  in
  (* Local function *)
  let _ : stat = local_function_simple "helper" [ "a" ] [ return [ ident "a" ] ] in
  ()

let test_control_flow () =
  let open Lua_ast in
  (* if x > 0 then return x else return 0 end *)
  let _ : stat =
    if_
      (binop Gt (ident "x") (number_of_int 0))
      [ return [ ident "x" ] ]
      (Some [ return [ number_of_int 0 ] ])
  in
  (* while i < 10 do i = i + 1 end *)
  let _ : stat =
    while_
      (binop Lt (ident "i") (number_of_int 10))
      [ assign [ ident "i" ] [ binop Add (ident "i") (number_of_int 1) ] ]
  in
  (* for i = 1, 10 do print(i) end *)
  let _ : stat =
    for_num
      "i"
      (number_of_int 1)
      (number_of_int 10)
      [ call_stat (call (ident "print") [ ident "i" ]) ]
  in
  (* for i = 1, 10, 2 do end *)
  let _ : stat =
    for_num_step "i" (number_of_int 1) (number_of_int 10) (number_of_int 2) []
  in
  (* for k, v in pairs(t) do end *)
  let _ : stat = for_in [ "k"; "v" ] [ call (ident "pairs") [ ident "t" ] ] [] in
  ()

let test_operators () =
  let open Lua_ast in
  (* Arithmetic operators *)
  let _ : expr = binop Add (number_of_int 1) (number_of_int 2) in
  let _ : expr = binop Sub (ident "x") (ident "y") in
  let _ : expr = binop Mul (number_of_int 3) (number_of_int 4) in
  let _ : expr = binop Div (ident "a") (ident "b") in
  let _ : expr = binop Mod (ident "n") (number_of_int 2) in
  let _ : expr = binop Pow (number_of_int 2) (number_of_int 8) in
  (* String concatenation *)
  let _ : expr = binop Concat (string "hello ") (string "world") in
  (* Relational operators *)
  let _ : expr = binop Eq (ident "x") (ident "y") in
  let _ : expr = binop Neq (ident "a") (ident "b") in
  let _ : expr = binop Lt (ident "x") (number_of_int 10) in
  let _ : expr = binop Le (ident "x") (number_of_int 10) in
  let _ : expr = binop Gt (ident "x") (number_of_int 0) in
  let _ : expr = binop Ge (ident "x") (number_of_int 0) in
  (* Logical operators *)
  let _ : expr = binop And (ident "x") (ident "y") in
  let _ : expr = binop Or (ident "a") (ident "b") in
  (* Bitwise operators (Lua 5.3+) *)
  let _ : expr = binop BAnd (ident "x") (number_of_int 0xFF) in
  let _ : expr = binop BOr (ident "a") (ident "b") in
  let _ : expr = binop BXor (ident "x") (ident "y") in
  let _ : expr = binop Shl (number_of_int 1) (number_of_int 8) in
  let _ : expr = binop Shr (ident "n") (number_of_int 2) in
  (* Unary operators *)
  let _ : expr = unop Not (ident "flag") in
  let _ : expr = unop Neg (ident "x") in
  let _ : expr = unop BNot (ident "mask") in
  let _ : expr = unop Len (ident "array") in
  ()

let test_table_access () =
  let open Lua_ast in
  (* obj.field *)
  let _ : expr = dot (ident "obj") "field" in
  (* obj[key] *)
  let _ : expr = index (ident "obj") (ident "key") in
  (* obj:method(args) *)
  let _ : expr = method_call (ident "obj") "method" [ ident "arg1"; ident "arg2" ] in
  (* Nested access: obj.nested.field *)
  let _ : expr = dot (dot (ident "obj") "nested") "field" in
  (* Complex: obj[key].field[index] *)
  let _ : expr = index (dot (index (ident "obj") (ident "key")) "field") (ident "index") in
  ()

let test_complete_program () =
  let open Lua_ast in
  (* Build a complete Lua program *)
  let _program : program =
    [ (* local x = 42 *)
      local [ "x" ] (Some [ number_of_int 42 ])
    ; (* function double(n) return n * 2 end *)
      function_decl_simple
        "double"
        [ "n" ]
        [ return [ binop Mul (ident "n") (number_of_int 2) ] ]
    ; (* local function add(a, b) return a + b end *)
      local_function_simple
        "add"
        [ "a"; "b" ]
        [ return [ binop Add (ident "a") (ident "b") ] ]
    ; (* local result = double(x) + add(x, 10) *)
      local
        [ "result" ]
        (Some
           [ binop
               Add
               (call (ident "double") [ ident "x" ])
               (call (ident "add") [ ident "x"; number_of_int 10 ])
           ])
    ; (* local tbl = {x = 1, y = 2, double(x)} *)
      local
        [ "tbl" ]
        (Some
           [ table
               [ rec_field "x" (number_of_int 1)
               ; rec_field "y" (number_of_int 2)
               ; array_field (call (ident "double") [ ident "x" ])
               ]
           ])
    ; (* return result *)
      return [ ident "result" ]
    ]
  in
  ()

let () =
  test_literals ();
  test_tables ();
  test_functions ();
  test_control_flow ();
  test_operators ();
  test_table_access ();
  test_complete_program ();
  print_endline "All AST construction tests passed!"
