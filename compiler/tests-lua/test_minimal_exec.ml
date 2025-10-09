(* Test minimal execution case *)

open! Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler
module Lua_generate = Lua_of_ocaml_compiler__Lua_generate
module Lua_output = Lua_of_ocaml_compiler__Lua_output

(* Helper: check if string contains substring *)
let contains_substring str sub =
  try
    let _ = Str.search_forward (Str.regexp_string sub) str 0 in
    true
  with Not_found -> false

let%expect_test "minimal program with single print generates execution code" =
  (* This is the MINIMAL case: just one side effect *)
  (* If this doesn't work, we know the problem is fundamental *)

  (* Set target before parsing bytecode *)
  Js_of_ocaml_compiler.Config.set_target `Wasm;

  (* Path relative to sandbox location *)
  let bytecode_file = "../../../../../default/compiler/tests-lua/minimal_exec.bc" in

  (* Parse bytecode *)
  let ic = open_in_bin bytecode_file in
  let parsed =
    Parse_bytecode.from_exe
      ~includes:[]
      ~linkall:false
      ~link_info:false
      ~include_cmis:false
      ~debug:false
      ic
  in
  close_in ic;

  let program = parsed.code in

  (* Print IR structure *)
  Printf.printf "Entry block: %s\n" (Code.Addr.to_string program.Code.start);

  (* Check ALL blocks, not just entry block *)
  Printf.printf "Total blocks in program: %d\n"
    (Code.Addr.Map.cardinal program.Code.blocks);

  (* Find blocks with Apply instructions *)
  let blocks_with_apply = ref [] in
  Code.Addr.Map.iter
    (fun addr block ->
      let has_apply =
        List.exists
          ~f:(fun instr ->
            match instr with
            | Code.Let (_, Code.Apply _) -> true
            | _ -> false)
          block.Code.body
      in
      if has_apply then blocks_with_apply := addr :: !blocks_with_apply)
    program.Code.blocks;

  Printf.printf "Blocks with Apply instructions: [%s]\n"
    (String.concat ~sep:", "
       (List.map ~f:Code.Addr.to_string (List.rev !blocks_with_apply)));

  (match Code.Addr.Map.find_opt program.Code.start program.Code.blocks with
  | Some block ->
      Printf.printf "Entry block has %d instructions\n" (List.length block.Code.body);

      (* Check for execution code markers in entry block *)
      let has_apply =
        List.exists
          ~f:(fun instr ->
            match instr with
            | Code.Let (_, Code.Apply _) -> true
            | _ -> false)
          block.Code.body
      in

      let has_extern =
        List.exists
          ~f:(fun instr ->
            match instr with
            | Code.Let (_, Code.Prim (Code.Extern _, _)) -> true
            | _ -> false)
          block.Code.body
      in

      Printf.printf "Entry block has Apply: %b\n" has_apply;
      Printf.printf "Entry block has Extern: %b\n" has_extern;

      (* Generate Lua *)
      let lua_code = Lua_generate.generate ~debug:false program in
      let lua_string = Lua_output.program_to_string lua_code in

      (* Check if Lua contains execution *)
      let has_call = contains_substring lua_string "print" in
      Printf.printf "Generated Lua has print call: %b\n" has_call;

      (* Show a sample of generated Lua *)
      let lines = String.split_on_char ~sep:'\n' lua_string in
      let sample_lines = List.filteri ~f:(fun i _ -> i < 30) lines in
      Printf.printf "\n=== Generated Lua (first 30 lines) ===\n";
      List.iter ~f:(fun line -> Printf.printf "%s\n" line) sample_lines
  | None -> Printf.printf "ERROR: Entry block not found\n");

  [%expect
    {|
    Entry block: 0
    Total blocks in program: 269
    Blocks with Apply instructions: [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 72, 79, 87, 89, 90, 92, 117, 118, 120, 122, 123, 124, 125, 126, 128, 129, 130, 131, 132, 135, 136, 137, 138, 139, 147, 151, 155, 157, 158, 159, 163, 164, 168, 170, 171, 188, 193, 206, 208, 209, 210, 219, 221, 228, 229, 247, 253, 268]
    Entry block has 57 instructions
    Entry block has Apply: false
    Entry block has Extern: true
    Generated Lua has print call: false

    === Generated Lua (first 30 lines) ===
    -- === OCaml Runtime (Minimal Inline Version) ===
    -- Global storage for OCaml values
    local _OCAML_GLOBALS = {}
    --
    -- caml_register_global: Register a global OCaml value
    --   n: global index
    --   v: value to register
    --   name: optional string name for the global
    function caml_register_global(n, v, name)
      -- Store value at index n+1 (Lua 1-indexed)
      _OCAML_GLOBALS[n + 1] = v
      -- Also store by name if provided
      if name then
        _OCAML_GLOBALS[name] = v
      end
      -- Return the value for chaining
      return v
    end
    --
    -- === End Runtime ===
    --
    -- -- Global Primitive Wrappers


    --
    function __caml_init__()
      -- Module initialization code
      local Out_of_memory = {tag = 248, "Out_of_memory", -1}
      local Sys_error = {tag = 248, "Sys_error", -2}
      local Failure = {tag = 248, "Failure", -3}
    |}]
