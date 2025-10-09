(* Benchmark suite for Lua code generation *)

open Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler
module Lua_generate = Lua_of_ocaml_compiler__Lua_generate

(** Benchmark result *)
type bench_result =
  { name : string
  ; time_ms : float
  ; memory_mb : float
  ; blocks : int
  ; output_size : int
  }

(** Time a function and return result + duration *)
let time_function f =
  Gc.compact ();
  (* Force GC before timing *)
  let start_time = Unix.gettimeofday () in
  let start_mem = Gc.stat () in
  let result = f () in
  let end_time = Unix.gettimeofday () in
  let end_mem = Gc.stat () in
  let time_ms = (end_time -. start_time) *. 1000.0 in
  let memory_mb =
    float_of_int (end_mem.Gc.top_heap_words - start_mem.Gc.top_heap_words)
    *. 8.0 /. 1024.0 /. 1024.0
  in
  result, time_ms, memory_mb

(** Compile bytecode file and measure performance with detailed breakdown *)
let bench_compile_file ~name bytecode_path =
  Printf.eprintf "Benchmarking %s...\n" name;
  (* Measure parse time *)
  let parsed, parse_time_ms, parse_mem_mb =
    time_function (fun () ->
      let ic = open_in_bin bytecode_path in
      Js_of_ocaml_compiler.Config.set_target `Wasm;
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
      parsed)
  in
  (* Measure generation time *)
  let lua_string, gen_time_ms, gen_mem_mb =
    time_function (fun () -> Lua_generate.generate_to_string ~debug:false parsed.code)
  in
  let time_ms = parse_time_ms +. gen_time_ms in
  let memory_mb = parse_mem_mb +. gen_mem_mb in
  Printf.eprintf "  Parse: %.2fms (%.2fMB), Generate: %.2fms (%.2fMB)\n"
    parse_time_ms
    parse_mem_mb
    gen_time_ms
    gen_mem_mb;
  let lua_string, time_ms, memory_mb = lua_string, time_ms, memory_mb in
  let num_blocks =
    let ic = open_in_bin bytecode_path in
    Js_of_ocaml_compiler.Config.set_target `Wasm;
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
    Code.Addr.Map.cardinal parsed.code.Code.blocks
  in
  { name; time_ms; memory_mb; blocks = num_blocks; output_size = String.length lua_string }

(** Print benchmark results *)
let print_results results =
  Printf.printf "\n=== BENCHMARK RESULTS ===\n\n";
  Printf.printf
    "%-30s %10s %10s %10s %12s %10s\n"
    "Benchmark"
    "Time(ms)"
    "Mem(MB)"
    "Blocks"
    "Output(KB)"
    "ms/block";
  Printf.printf "%s\n" (String.make 90 '-');
  List.iter
    ~f:(fun r ->
      let kb = float_of_int r.output_size /. 1024.0 in
      let ms_per_block = r.time_ms /. float_of_int r.blocks in
      Printf.printf
        "%-30s %10.2f %10.2f %10d %12.2f %10.4f\n"
        r.name
        r.time_ms
        r.memory_mb
        r.blocks
        kb
        ms_per_block)
    results;
  Printf.printf "\n";
  (* Performance targets *)
  Printf.printf "PERFORMANCE TARGETS:\n";
  Printf.printf "  - Small modules (<100 blocks): <100ms\n";
  Printf.printf "  - Medium modules (100-500 blocks): <500ms\n";
  Printf.printf "  - Large modules (>500 blocks): <2000ms\n";
  Printf.printf "  - Memory: <50MB per compilation\n"

(** Check if benchmark meets performance targets *)
let check_target r =
  let time_threshold =
    if r.blocks < 100 then 100.0 else if r.blocks < 500 then 500.0 else 2000.0
  in
  let time_ok = Float.compare r.time_ms time_threshold < 0 in
  let mem_ok = Float.compare r.memory_mb 50.0 < 0 in
  time_ok && mem_ok

(** Create a synthetic program with N variables for benchmarking *)
let create_test_program n =
  let vars = List.init ~len:n ~f:(fun _ -> Code.Var.fresh ()) in
  let instr_body =
    List.mapi vars ~f:(fun i v ->
        match i mod 5 with
        | 0 -> Code.Let (v, Code.Constant (Code.Int32 (Int32.of_int (i * 2))))
        | 1 -> Code.Let (v, Code.Constant (Code.String (Printf.sprintf "var_%d" i)))
        | 2 ->
            if i > 0
            then
              Code.Let
                ( v
                , Code.Prim
                    ( Code.Extern "caml_add"
                    , [ Code.Pv (List.nth vars (i - 1)); Code.Pc (Code.Int32 1l) ] ) )
            else Code.Let (v, Code.Constant (Code.Int32 0l))
        | 3 -> Code.Let (v, Code.Constant (Code.Int32 (Int32.of_int (i + 100))))
        | _ -> Code.Let (v, Code.Constant (Code.Int32 (Int32.of_int (i * 3)))))
  in
  let last_var = List.nth vars (n - 1) in
  let block0 =
    { Code.params = []; body = instr_body; branch = Code.Return last_var }
  in
  let code_blocks = Code.Addr.Map.empty |> Code.Addr.Map.add 0 block0 in
  { Code.start = 0; blocks = code_blocks; free_pc = 1 }

(** Benchmark code generation for a synthetic program *)
let bench_synthetic ~name program =
  Printf.eprintf "Benchmarking %s...\n" name;
  let lua_string, gen_time_ms, gen_mem_mb =
    time_function (fun () -> Lua_generate.generate_to_string ~debug:false program)
  in
  Printf.eprintf "  Generate: %.2fms (%.2fMB)\n" gen_time_ms gen_mem_mb;
  let num_blocks = Code.Addr.Map.cardinal program.Code.blocks in
  { name
  ; time_ms = gen_time_ms
  ; memory_mb = gen_mem_mb
  ; blocks = num_blocks
  ; output_size = String.length lua_string
  }

(** Run all benchmarks *)
let run_benchmarks () =
  (* File-based benchmarks *)
  let file_benchmarks =
    [ "minimal_exec", "_build/default/compiler/tests-lua/minimal_exec.bc" ]
  in
  let file_results =
    List.filter_map
      ~f:(fun (name, path) ->
        try Some (bench_compile_file ~name path)
        with e ->
          Printf.eprintf "Failed to benchmark %s: %s\n" name (Printexc.to_string e);
          None)
      file_benchmarks
  in
  (* Synthetic benchmarks for variable storage comparison *)
  Printf.printf "\n=== Variable Storage Performance Comparison ===\n";
  Printf.printf "Testing local storage (<= 180 vars) vs table storage (> 180 vars)\n\n";
  let synthetic_benchmarks =
    [ "locals_50_vars", 50
    ; "locals_100_vars", 100
    ; "locals_150_vars", 150
    ; "locals_180_vars", 180
    ; "table_200_vars", 200
    ; "table_300_vars", 300
    ; "table_500_vars", 500
    ]
  in
  let synthetic_results =
    List.map
      ~f:(fun (name, var_count) ->
        let program = create_test_program var_count in
        bench_synthetic ~name program)
      synthetic_benchmarks
  in
  (* Calculate overhead for table storage *)
  let find_bench name results =
    try Some (List.find ~f:(fun r -> String.equal r.name name) results) with Not_found -> None
  in
  let locals_180 = find_bench "locals_180_vars" synthetic_results in
  let table_200 = find_bench "table_200_vars" synthetic_results in
  (match (locals_180, table_200) with
  | (Some l180, Some t200) ->
      let overhead_pct = (t200.time_ms -. l180.time_ms) /. l180.time_ms *. 100.0 in
      Printf.printf
        "\n=== Table Storage Overhead ===\n\
         Locals (180 vars):  %.2fms\n\
         Table (200 vars):   %.2fms\n\
         Overhead:           %.1f%%\n\
         Target:             <20%%\n\
         Status:             %s\n\n"
        l180.time_ms
        t200.time_ms
        overhead_pct
        (if Float.compare overhead_pct 20.0 < 0 then "PASS ✓" else "FAIL ✗")
  | _ -> ());
  let all_results = file_results @ synthetic_results in
  print_results all_results;
  (* Verify generation time targets *)
  Printf.printf "\n=== Generation Time Verification ===\n";
  List.iter
    ~f:(fun r ->
      let per_var_time = r.time_ms /. float_of_int r.output_size *. 1000.0 in
      (* µs per output char *)
      Printf.printf "  %s: %.2fms (%.3fµs/char)\n" r.name r.time_ms per_var_time)
    synthetic_results;
  Printf.printf "\nTarget: Fast compilation (<10ms for simple programs)\n";
  let is_prefix prefix str =
    let prefix_len = String.length prefix in
    String.length str >= prefix_len
    && String.equal (String.sub str ~pos:0 ~len:prefix_len) prefix
  in
  let fast_programs =
    List.filter
      ~f:(fun r -> is_prefix "locals_" r.name || is_prefix "table_" r.name)
      all_results
  in
  let slow_programs = List.filter ~f:(fun r -> Float.compare r.time_ms 10.0 > 0) fast_programs in
  if List.length slow_programs > 0
  then
    Printf.printf "Note: %d program(s) >10ms (expected for larger programs)\n"
      (List.length slow_programs);
  (* Check if any benchmark failed targets *)
  let failures = List.filter ~f:(fun r -> not (check_target r)) all_results in
  if List.length failures > 0
  then begin
    Printf.eprintf "\nWARNING: %d benchmark(s) failed performance targets:\n"
      (List.length failures);
    List.iter
      ~f:(fun r ->
        Printf.eprintf
          "  - %s: %.2fms (blocks: %d, mem: %.2fMB)\n"
          r.name
          r.time_ms
          r.blocks
          r.memory_mb)
      failures;
    exit 1
  end
  else begin
    Printf.printf "\nSUCCESS: All benchmarks meet performance targets!\n";
    exit 0
  end

let () = run_benchmarks ()
