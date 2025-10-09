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

(** Run all benchmarks *)
let run_benchmarks () =
  let benchmarks =
    [ "minimal_exec", "_build/default/compiler/tests-lua/minimal_exec.bc" ]
  in
  let results =
    List.filter_map
      ~f:(fun (name, path) ->
        try Some (bench_compile_file ~name path)
        with e ->
          Printf.eprintf "Failed to benchmark %s: %s\n" name (Printexc.to_string e);
          None)
      benchmarks
  in
  print_results results;
  (* Check if any benchmark failed targets *)
  let failures = List.filter ~f:(fun r -> not (check_target r)) results in
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
