(* Tests for Lua code generation *)

open Js_of_ocaml_compiler

module Lua_generate = struct
  include Lua_of_ocaml_compiler__Lua_generate
end

module Lua_ast = struct
  include Lua_of_ocaml_compiler__Lua_ast
end

(* Test helper: create a dummy Code.program *)
let dummy_program : Code.program =
  { start = Code.Addr.zero
  ; blocks = Code.Addr.Map.empty
  ; free_pc = Code.Addr.zero
  }

(* Test helper: extract statement types for easier assertion *)
let rec stat_types = function
  | [] -> []
  | s :: rest ->
      let ty =
        match s with
        | Lua_ast.Local _ -> "local"
        | Lua_ast.Assign _ -> "assign"
        | Lua_ast.Function_decl _ -> "function_decl"
        | Lua_ast.Local_function _ -> "local_function"
        | Lua_ast.If _ -> "if"
        | Lua_ast.While _ -> "while"
        | Lua_ast.Repeat _ -> "repeat"
        | Lua_ast.For_num _ -> "for_num"
        | Lua_ast.For_in _ -> "for_in"
        | Lua_ast.Break -> "break"
        | Lua_ast.Return _ -> "return"
        | Lua_ast.Goto _ -> "goto"
        | Lua_ast.Label _ -> "label"
        | Lua_ast.Call_stat _ -> "call_stat"
        | Lua_ast.Block _ -> "block"
      in
      ty :: stat_types rest

let%expect_test "generate produces statements" =
  let result = Lua_generate.generate ~debug:false dummy_program in
  Printf.printf "Generated %d statements\n" (List.length result);
  [%expect {| Generated 2 statements |}]

let%expect_test "generate produces main function" =
  let result = Lua_generate.generate ~debug:false dummy_program in
  let types = stat_types result in
  List.iter (Printf.printf "Statement type: %s\n") types;
  [%expect {|
    Statement type: function_decl
    Statement type: call_stat |}]

let%expect_test "generate with debug produces same structure" =
  let result = Lua_generate.generate ~debug:true dummy_program in
  Printf.printf "Generated %d statements (debug mode)\n" (List.length result);
  let types = stat_types result in
  List.iter (Printf.printf "Statement type: %s\n") types;
  [%expect {|
    Generated 2 statements (debug mode)
    Statement type: function_decl
    Statement type: call_stat |}]

let%expect_test "generate_to_string produces valid Lua" =
  let result = Lua_generate.generate_to_string ~debug:false dummy_program in
  (* Check that it contains basic structure *)
  let contains s = String.length result > 0 &&
    try ignore (String.index result (String.get s 0));
        let rec search pos =
          let idx = String.index_from result pos (String.get s 0) in
          if String.length result >= idx + String.length s &&
             String.sub result idx (String.length s) = s
          then true
          else search (idx + 1)
        in search 0
    with Not_found -> false
  in
  Printf.printf "Output contains 'function': %b\n" (contains "function");
  Printf.printf "Output contains 'main': %b\n" (contains "main");
  Printf.printf "Output contains 'return': %b\n" (contains "return");
  [%expect {|
    Output contains 'function': true
    Output contains 'main': true
    Output contains 'return': true |}]

let%expect_test "generate_to_string full output" =
  let result = Lua_generate.generate_to_string ~debug:false dummy_program in
  print_endline result;
  [%expect {|
    function main()
      return 0
    end
    main() |}]

let%expect_test "generate_to_string with debug" =
  let result = Lua_generate.generate_to_string ~debug:true dummy_program in
  print_endline result;
  [%expect {|
    function main()
      return 0
    end
    main() |}]

(* Test variable name generation by testing internal structure *)
(* We can't directly test var_name since it's not exported, but we can test *)
(* that the generated code would work with our variable mapping logic *)

let%expect_test "basic code generation produces valid output" =
  (* This test verifies that the basic code generation infrastructure works *)
  let prog = Lua_generate.generate ~debug:false dummy_program in
  (* Verify we have the right number of top-level statements *)
  Printf.printf "Statement count: %d\n" (List.length prog);
  (* Verify statement structure *)
  (match prog with
  | [ Lua_ast.Function_decl (name, params, vararg, body)
    ; Lua_ast.Call_stat (Lua_ast.Call (Lua_ast.Ident call_name, []))
    ] ->
      Printf.printf "Function name: %s\n" name;
      Printf.printf "Parameters: %d\n" (List.length params);
      Printf.printf "Vararg: %b\n" vararg;
      Printf.printf "Body length: %d\n" (List.length body);
      Printf.printf "Called function: %s\n" call_name;
      Printf.printf "Structure is correct\n"
  | _ ->
      Printf.printf "Unexpected structure\n");
  [%expect {|
    Statement count: 2
    Function name: main
    Parameters: 0
    Vararg: false
    Body length: 1
    Called function: main
    Structure is correct |}]

let%expect_test "code generation produces compilable Lua" =
  (* Verify the output is syntactically valid Lua by checking key elements *)
  let lua_code = Lua_generate.generate_to_string ~debug:false dummy_program in
  let contains s =
    try
      let _ = Str.search_forward (Str.regexp_string s) lua_code 0 in true
    with Not_found -> false
  in
  Printf.printf "Has 'function' keyword: %b\n" (contains "function");
  Printf.printf "Has 'end' keyword: %b\n" (contains "end");
  Printf.printf "Has 'return' keyword: %b\n" (contains "return");
  [%expect {|
    Has 'function' keyword: true
    Has 'end' keyword: true
    Has 'return' keyword: true |}]

let%expect_test "empty program generation" =
  (* Test with completely empty program *)
  let empty_prog : Code.program =
    { start = Code.Addr.zero
    ; blocks = Code.Addr.Map.empty
    ; free_pc = Code.Addr.zero
    }
  in
  let result = Lua_generate.generate ~debug:false empty_prog in
  Printf.printf "Empty program generates %d statements\n" (List.length result);
  let lua_str = Lua_generate.generate_to_string ~debug:false empty_prog in
  Printf.printf "Generated Lua length: %d\n" (String.length lua_str);
  let contains_main =
    try
      let _ = Str.search_forward (Str.regexp_string "main") lua_str 0 in true
    with Not_found -> false
  in
  Printf.printf "Contains main function: %b\n" contains_main;
  [%expect {|
    Empty program generates 2 statements
    Generated Lua length: 38
    Contains main function: true
    |}]
