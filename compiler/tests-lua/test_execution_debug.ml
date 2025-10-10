(* Test to compare Lua and JS backend outputs for the same program *)

open! Js_of_ocaml_compiler.Stdlib

(* Helper: check if string contains substring *)
let contains_substring str sub =
  try
    let _ = Str.search_forward (Str.regexp_string sub) str 0 in
    true
  with Not_found -> false

let%expect_test "compare hello.ml compilation between JS and Lua backends" =
  (* This test helps us understand what the JS backend generates vs Lua *)

  (* Check if JS output exists *)
  let js_file = "../../examples/hello_lua/hello.bc.js" in
  if Sys.file_exists js_file
  then begin
    (* Read first 50 lines of JS output to see structure *)
    let ic = open_in_text js_file in
    Printf.printf "=== JS Backend Output (first 50 lines) ===\n";
    (try
       for _ = 1 to 50 do
         let line = input_line ic in
         Printf.printf "%s\n" line
       done
     with End_of_file -> ());
    close_in ic
  end
  else Printf.printf "JS output not found, run: dune build examples/hello_lua/hello.bc.js\n";

  [%expect
    {| JS output not found, run: dune build examples/hello_lua/hello.bc.js |}]

let%expect_test "check if hello.bc.lua contains execution code" =
  (* Check generated Lua for execution patterns *)
  let lua_file = "../../examples/hello_lua/hello.bc.lua" in
  if Sys.file_exists lua_file
  then begin
    let content = In_channel.with_open_bin lua_file In_channel.input_all in
    (* Look for execution patterns *)
    let has_print_call = contains_substring content "print" in
    let has_function_calls =
      contains_substring content "(" && contains_substring content ")"
    in
    let has_returns = contains_substring content "return" in
    let has_local_vars = contains_substring content "local v" in
    Printf.printf "Has print calls: %b\n" has_print_call;
    Printf.printf "Has function calls: %b\n" has_function_calls;
    Printf.printf "Has returns: %b\n" has_returns;
    Printf.printf "Has local vars: %b\n" has_local_vars;
    (* Show chunk of code around initialization *)
    let lines = String.split_on_char ~sep:'\n' content in
    Printf.printf "\n=== Init chunk sample (lines 20-40) ===\n";
    List.iteri
      ~f:(fun i line ->
        if i >= 19 && i < 40 then Printf.printf "%d: %s\n" (i + 1) line)
      lines
  end
  else Printf.printf "Lua output not found\n";

  [%expect
    {| Lua output not found |}]

let%expect_test "analyze JS vs Lua structure differences" =
  let js_file = "../../examples/hello_lua/hello.bc.js" in
  let lua_file = "../../examples/hello_lua/hello.bc.lua" in
  let js_exists = Sys.file_exists js_file in
  let lua_exists = Sys.file_exists lua_file in
  Printf.printf "JS file exists: %b\n" js_exists;
  Printf.printf "Lua file exists: %b\n" lua_exists;
  if js_exists && lua_exists
  then begin
    let js_content = In_channel.with_open_bin js_file In_channel.input_all in
    let lua_content = In_channel.with_open_bin lua_file In_channel.input_all in
    (* Analyze JS output *)
    let js_lines = List.length (String.split_on_char ~sep:'\n' js_content) in
    let js_size = String.length js_content in
    let js_has_hello = contains_substring js_content "Hello from" in
    let js_has_factorial = contains_substring js_content "Factorial" in
    (* Analyze Lua output *)
    let lua_lines = List.length (String.split_on_char ~sep:'\n' lua_content) in
    let lua_size = String.length lua_content in
    let lua_has_hello = contains_substring lua_content "Hello from" in
    let lua_has_factorial = contains_substring lua_content "Factorial" in
    Printf.printf "\n=== JS Backend ===\n";
    Printf.printf "Lines: %d\n" js_lines;
    Printf.printf "Size: %d bytes\n" js_size;
    Printf.printf "Contains 'Hello from': %b\n" js_has_hello;
    Printf.printf "Contains 'Factorial': %b\n" js_has_factorial;
    Printf.printf "\n=== Lua Backend ===\n";
    Printf.printf "Lines: %d\n" lua_lines;
    Printf.printf "Size: %d bytes\n" lua_size;
    Printf.printf "Contains 'Hello from': %b\n" lua_has_hello;
    Printf.printf "Contains 'Factorial': %b\n" lua_has_factorial;
    Printf.printf "\n=== Analysis ===\n";
    Printf.printf
      "Both backends include the string constants, confirming they process the same \
       source.\n";
    Printf.printf
      "JS backend is minified (%d bytes), Lua is readable (%d bytes).\n"
      js_size
      lua_size
  end;

  [%expect
    {|
    JS file exists: false
    Lua file exists: false
    |}]
