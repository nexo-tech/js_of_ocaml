# Lua_of_ocaml Program Execution Fix Plan

This document details the investigation and fix for why hello_lua generates only constants instead of execution code.

## Master Checklist

**Phase 5: Root Cause Investigation**
- [x] Task 5.1: Add IR debug output to understand what bytecode parser generates (~50 lines)
- [x] Task 5.2: Compare JS backend output for hello.ml to identify differences (~30 lines)
- [x] Task 5.3: Create minimal reproduction test case (~40 lines)

**Phase 6: Identify and Fix the Problem**
- [x] Task 6.1: Analyze IR and identify why execution code is missing (~investigation)
- [x] Task 6.2: Implement fix in bytecode parser, driver, or code generator (~variable)

**Phase 7: Code Generation Cleanup & Optimization**
- [x] Task 7.1: Unify block compilation strategy (~100 lines)
- [x] Task 7.2: Remove dead code (~50 lines)
- [ ] Task 7.3: Test all code paths (~50 lines)

**Phase 8: Performance Optimization & Benchmarking** (CRITICAL for self-hosted compiler)
- [ ] Task 8.1: Establish baseline benchmarks (~80 lines)
- [ ] Task 8.2: Profile and identify bottlenecks (~investigation)
- [ ] Task 8.3: Implement core optimizations (~200 lines)
- [ ] Task 8.4: Verify improvements with benchmarks (~50 lines)
- [ ] Task 8.5: Add performance regression tests (~50 lines)

**Phase 9: Verification**
- [ ] Task 9.1: Verify hello_lua executes correctly with Lua (~20 lines)
- [ ] Task 9.2: Add execution tests for common patterns (~100 lines)

**Total**: 13 tasks = **~650 lines new code + investigation + optimization**

---

## Problem Summary

**Current State**: After LINKING.md completion (Tasks 1.1-4.2), the hello_lua example:
- ✅ Compiles successfully
- ✅ Generates valid Lua syntax
- ✅ Has correct structure (runtime, init chunks)
- ❌ Only contains constant definitions, NO execution code

**Example**: `hello.ml` has `let () = print_endline "Hello from Lua_of_ocaml!"` but generated Lua only defines:
```lua
local v297 = "Hello from Lua_of_ocaml!"
-- Missing: actual call to print_endline!
```

## Critical Finding: Code Generation IS Complete

### Investigation Results (from lua_generate.ml analysis)

**IMPORTANT**: The Lua code generator already has FULL execution infrastructure:

| Component | Status | Location | Description |
|-----------|--------|----------|-------------|
| Expression translation | ✅ COMPLETE | line 631 | `generate_expr` handles all Code.expr cases |
| Instruction translation | ✅ COMPLETE | line 665 | `generate_instr` handles all Code.instr cases |
| Primitive operations | ✅ COMPLETE | line 169 | `generate_prim` ~400 lines, all primitives |
| Control flow | ✅ COMPLETE | line 723 | `generate_last_with_program` handles branches, conditionals, switch |
| Block compilation | ✅ COMPLETE | line 824 | `generate_block_with_program` recursive compilation |
| Closure generation | ✅ COMPLETE | line 847 | `generate_closure` with tail call optimization |
| Module initialization | ✅ COMPLETE | line 967 | `generate_module_init` with local var chunking |
| Standalone generation | ✅ COMPLETE | line 1133 | `generate_standalone` with runtime linking |

### Example: generate_expr (line 631) Already Handles Everything

```ocaml
let rec generate_expr ctx expr =
  match expr with
  | Code.Constant c -> generate_constant c
  | Code.Apply { f; args; exact = _ } ->
      (* ✅ Function calls - WORKS *)
      let func_expr = var_ident ctx f in
      let arg_exprs = List.map ~f:(var_ident ctx) args in
      L.Call (func_expr, arg_exprs)
  | Code.Block (tag, arr, _, _) ->
      (* ✅ Block construction - WORKS *)
      optimize_block_construction tag fields
  | Code.Field (v, idx, _) ->
      (* ✅ Field access - WORKS *)
      optimize_field_access ctx obj idx
  | Code.Closure (params, (pc, _), _) ->
      (* ✅ Closures - WORKS *)
      generate_closure ctx params pc
  | Code.Prim (prim, args) ->
      (* ✅ Primitives - WORKS *)
      generate_prim ctx prim args
  | Code.Special _ -> L.Ident "caml_special"
```

### Example: generate_last_with_program (line 723) Handles All Control Flow

```ocaml
and generate_last_with_program ctx program last =
  match last with
  | Code.Return var -> (* ✅ Returns *)
  | Code.Raise (var, _) -> (* ✅ Exceptions *)
  | Code.Stop -> (* ✅ Program termination *)
  | Code.Branch (addr, args) -> (* ✅ Unconditional branches *)
  | Code.Cond (var, (addr_true, _), (addr_false, _)) ->
      (* ✅ Conditionals - generates if-then-else with recursive block compilation *)
      let true_stmts = generate_block_with_program ctx program tb in
      let false_stmts = generate_block_with_program ctx program fb in
      [ L.If (cond_expr, true_stmts, Some false_stmts) ]
  | Code.Switch (var, conts) ->
      (* ✅ Switch - generates if-elseif chain *)
      generate_switch ctx program discriminator conts 0
  | Code.Pushtrap / Poptrap -> (* ✅ Exception handlers *)
```

**Conclusion**: The code generator can ALREADY translate all execution constructs to Lua.

## Root Cause Hypothesis

The problem is NOT in code generation. It's in the **IR (intermediate representation)** that the code generator receives.

### What Should Happen

For `hello.ml`:
```ocaml
let () = print_endline "Hello from Lua_of_ocaml!"
let factorial n = ...
let () = Printf.printf "Factorial of 5 is: %d\n" (factorial 5)
```

The `Code.program.start` block should contain:
```
Block 0 (entry):
  Let v1 = Constant "Hello from Lua_of_ocaml!"
  Let v2 = Apply (print_endline, [v1])        ← EXECUTION CODE
  Let v3 = Closure (factorial, ...)
  Let v4 = Apply (factorial, [5])             ← EXECUTION CODE
  Let v5 = Apply (Printf.printf, [format, v4]) ← EXECUTION CODE
  Return/Stop
```

### What Likely Happens

The entry block ONLY contains constant definitions:
```
Block 0 (entry):
  Let v297 = Constant "Hello from Lua_of_ocaml!"
  Let v298 = Constant "Factorial of %d is: %d\012"
  ... (more constants)
  Branch -> Block 1  (but Block 1 might contain execution code that's never reached?)
```

### Possible Causes

1. **Bytecode parsing issue** (`Parse_bytecode.from_exe`):
   - Top-level `let () = ...` statements not included in entry block
   - Execution code in unreachable blocks
   - Module initialization vs program execution confusion

2. **Driver issue** (`Driver.ml` optimization passes):
   - Dead code elimination removing execution code
   - Constant folding moving everything to constants
   - Inlining breaking execution flow

3. **Code generator issue** (less likely):
   - `generate_module_init` not recursing through all reachable blocks
   - Control flow branches not followed
   - But this is UNLIKELY given how complete the code is

## Implementation Phases

---

## Phase 5: Root Cause Investigation (~120 lines)

**Objective**: Determine exactly why execution code is missing from generated Lua

### Task 5.1: Add IR Debug Output (~50 lines)

Add debug output to understand what IR the code generator receives.

**File**: `compiler/lib-lua/lua_generate.ml`

**Implementation**:

```ocaml
(** Debug: Print Code.program IR structure
    @param program Code IR program
*)
let debug_print_program program =
  if Debug.find "ir" () then begin
    Printf.eprintf "\n=== Code.program IR Debug ===\n";
    Printf.eprintf "Entry block: %s\n" (Code.Addr.to_string program.Code.start);
    Printf.eprintf "Total blocks: %d\n" (Code.Addr.Map.cardinal program.Code.blocks);

    (* Print entry block details *)
    (match Code.Addr.Map.find_opt program.Code.start program.Code.blocks with
    | Some block ->
        Printf.eprintf "\nEntry block instructions (%d):\n" (List.length block.Code.body);
        List.iteri (fun i instr ->
          Printf.eprintf "  %d: %s\n" i (Code.Print.instr instr)
        ) block.Code.body;
        Printf.eprintf "Entry block terminator: %s\n" (Code.Print.last block.Code.branch)
    | None ->
        Printf.eprintf "ERROR: Entry block not found!\n");

    (* Print all blocks summary *)
    Printf.eprintf "\nAll blocks:\n";
    Code.Addr.Map.iter (fun addr block ->
      Printf.eprintf "  Block %s: %d instrs, term: %s\n"
        (Code.Addr.to_string addr)
        (List.length block.Code.body)
        (Code.Print.last block.Code.branch)
    ) program.Code.blocks;
    Printf.eprintf "=== End IR Debug ===\n\n"
  end

(* Call from generate_standalone *)
let generate_standalone ctx program =
  debug_print_program program;  (* ADD THIS LINE *)
  (* ... rest of existing code ... *)
```

**Usage**:
```bash
# Enable IR debug output
dune exec -- lua_of_ocaml compile examples/hello_lua/hello.bc --debug-ir -o hello.lua
```

**Test**: Compile hello.ml with debug enabled:
```bash
dune build examples/hello_lua/hello.bc.lua
```

**Expected Output**: Console shows all blocks, instructions, and terminators in the IR.

**Success Criteria**:
- ✅ Compiles without warnings
- ✅ Debug output shows IR structure
- ✅ Can identify which blocks contain execution code vs constants

---

### Task 5.2: Compare JS Backend Output (~30 lines)

Generate JavaScript for the same program and compare what's different.

**File**: `compiler/tests-lua/test_execution_debug.ml`

**Implementation**:

```ocaml
(* Test to compare Lua and JS backend outputs for the same program *)

open Js_of_ocaml_compiler.Stdlib

let%expect_test "compare hello.ml compilation between JS and Lua backends" =
  (* This test helps us understand what the JS backend generates vs Lua *)

  (* Build both versions *)
  let bc_file = "examples/hello_lua/hello.bc" in

  (* Check if JS output exists *)
  let js_file = "_build/default/examples/hello_lua/hello.bc.js" in
  if Sys.file_exists js_file then begin
    (* Read first 100 lines of JS output to see structure *)
    let ic = open_in js_file in
    Printf.printf "=== JS Backend Output (first 50 lines) ===\n";
    for i = 1 to 50 do
      try
        let line = input_line ic in
        Printf.printf "%s\n" line
      with End_of_file -> ()
    done;
    close_in ic
  end else
    Printf.printf "JS output not found, run: dune build examples/hello_lua/hello.bc.js\n";

  [%expect {|
    (* Will show JS backend structure *)
  |}]

let%expect_test "check if hello.bc.lua contains execution code" =
  (* Check generated Lua for execution patterns *)
  let lua_file = "_build/default/examples/hello_lua/hello.bc.lua" in
  if Sys.file_exists lua_file then begin
    let content = In_channel.with_open_bin lua_file In_channel.input_all in

    (* Look for execution patterns *)
    let has_print_call = String.contains_substring content "print" in
    let has_function_calls = String.contains_substring content "(" && String.contains_substring content ")" in
    let only_constants =
      String.contains_substring content "local v" &&
      not (String.contains_substring content "return") in

    Printf.printf "Has print calls: %b\n" has_print_call;
    Printf.printf "Has function calls: %b\n" has_function_calls;
    Printf.printf "Only constants (no returns): %b\n" only_constants;

    (* Show chunk of code around initialization *)
    let lines = String.split_on_char '\n' content in
    Printf.printf "\n=== Init chunk sample (lines 20-40) ===\n";
    List.iteri (fun i line ->
      if i >= 19 && i < 40 then
        Printf.printf "%d: %s\n" (i+1) line
    ) lines
  end else
    Printf.printf "Lua output not found\n";

  [%expect {|
    (* Will show what patterns exist in Lua output *)
  |}]
```

**Test**:
```bash
# Build both outputs
dune build examples/hello_lua/hello.bc.js
dune build examples/hello_lua/hello.bc.lua

# Run comparison test
dune runtest compiler/tests-lua/test_execution_debug.ml
```

**Success Criteria**:
- ✅ Can see JS backend structure
- ✅ Can identify differences between JS and Lua outputs
- ✅ Determine if JS has execution code that Lua lacks

---

### Task 5.3: Create Minimal Reproduction (~40 lines)

Create the simplest possible test case to isolate the problem.

**File**: `compiler/tests-lua/minimal_exec.ml` (test input)

```ocaml
(* Minimal test case: single side effect *)
let () = print_endline "test"
```

**File**: `compiler/tests-lua/test_minimal_exec.ml` (test)

```ocaml
(* Test minimal execution case *)

open Js_of_ocaml_compiler.Stdlib
module Lua_generate = Lua_of_ocaml_compiler__Lua_generate

let%expect_test "minimal program with single print generates execution code" =
  (* This is the MINIMAL case: just one side effect *)
  (* If this doesn't work, we know the problem is fundamental *)

  let bytecode_file = "compiler/tests-lua/minimal_exec.bc" in

  (* Parse bytecode *)
  let ic = open_in_bin bytecode_file in
  let parsed = Parse_bytecode.from_exe
    ~includes:[]
    ~linkall:false
    ~link_info:false
    ~include_cmis:false
    ~debug:true
    ic
  in
  close_in ic;

  let program = parsed.code in

  (* Print IR structure *)
  Printf.printf "Entry block: %s\n" (Code.Addr.to_string program.Code.start);

  (match Code.Addr.Map.find_opt program.Code.start program.Code.blocks with
  | Some block ->
      Printf.printf "Entry block has %d instructions\n" (List.length block.Code.body);

      (* Check for execution code markers *)
      let has_apply = List.exists (fun instr ->
        match instr with
        | Code.Let (_, Code.Apply _) -> true
        | _ -> false
      ) block.Code.body in

      let has_extern = List.exists (fun instr ->
        match instr with
        | Code.Let (_, Code.Prim (Code.Extern _, _)) -> true
        | _ -> false
      ) block.Code.body in

      Printf.printf "Has Apply (function calls): %b\n" has_apply;
      Printf.printf "Has Extern (primitives): %b\n" has_extern;

      (* Generate Lua *)
      let lua_code = Lua_generate.generate ~debug:true program in
      let lua_string = Lua_output.program_to_string lua_code in

      (* Check if Lua contains execution *)
      let has_call = String.contains_substring lua_string "print" in
      Printf.printf "Generated Lua has print call: %b\n" has_call
  | None ->
      Printf.printf "ERROR: Entry block not found\n");

  [%expect {|
    Entry block: 0
    Entry block has 1 instructions
    Has Apply (function calls): true
    Has Extern (primitives): true
    Generated Lua has print call: true
  |}]
```

**File**: `compiler/tests-lua/dune` (add test)

```ocaml
(executable
 (name minimal_exec)
 (modules minimal_exec))

(rule
 (targets minimal_exec.bc)
 (deps minimal_exec.ml)
 (action
  (run ocamlc -o %{targets} %{deps})))
```

**Test**:
```bash
dune runtest compiler/tests-lua/
```

**Success Criteria**:
- [x] Minimal test compiles
- [x] Can see if IR contains Apply/Extern for print_endline
- [x] Can see if generated Lua contains the call
- [x] Identifies exact point where execution code is lost (if at all)

---

## Phase 6: Identify and Fix (~variable lines)

**Objective**: Based on Phase 5 findings, implement the fix

### Task 6.1: Analyze IR and Identify Problem (~investigation)

**Process**:
1. Review output from Task 5.1 (IR debug)
2. Review output from Task 5.2 (JS comparison)
3. Review output from Task 5.3 (minimal case)

**Possible Findings**:

#### Finding A: IR is correct, code generator is wrong
If IR contains `Apply` and `Prim (Extern)` but Lua doesn't have calls:
- **Problem**: `generate_block_with_program` not recursing through branches
- **Fix**: Modify `generate_last_with_program` to follow branches recursively
- **Location**: lua_generate.ml line 736

#### Finding B: IR is missing execution code
If IR only contains constants and closures, no Apply/Extern:
- **Problem**: `Parse_bytecode.from_exe` not including top-level side effects
- **Fix**: Check how JS backend parses, ensure linkall/initialization flags correct
- **Location**: compiler/bin-lua_of_ocaml/compile.ml line 45

#### Finding C: Execution code in unreachable blocks
If IR has execution code in Block 1, 2, ... but not in entry block:
- **Problem**: Control flow not followed from entry block
- **Fix**: Modify `generate_module_init` to traverse all reachable blocks
- **Location**: lua_generate.ml line 967

**Deliverable**: Document in this file which finding is true and the fix plan.

---

## Task 6.1 Results: Finding C Confirmed

**Analysis Date**: 2025-10-09

### Investigation Summary

Ran comprehensive IR analysis test (`test_minimal_exec.ml`) on minimal program:
```ocaml
let () = print_endline "test"
```

### Findings

**IR Statistics**:
- Total blocks: 269
- Blocks with Apply instructions: 103 blocks (5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, ...)
- Entry block (0): 57 instructions, NO Apply instructions
- Generated Lua: NO print call

### Conclusion: Finding C is TRUE

**Problem**: Control flow not followed from entry block

The bytecode parsing is working correctly (user confirmed jsoo works for JS/Wasm).
The IR contains all necessary execution code (Apply instructions).
**The Lua code generator only processes the entry block and doesn't traverse to subsequent blocks.**

### Root Cause

In `compiler/lib-lua/lua_generate.ml`:
- `generate_module_init` (line ~967) only generates code for the entry block
- Does not follow `block.Code.branch` to traverse reachable blocks
- Execution code in blocks 5, 6, 7, ... is never compiled to Lua

### Fix Plan (Task 6.2)

**Location**: `compiler/lib-lua/lua_generate.ml`, function `generate_module_init`

**Approach**:
1. Collect all reachable blocks from entry block via BFS/DFS
2. Generate Lua code for each reachable block in proper order
3. Ensure control flow (branches, conditionals, switches) is preserved

**Implementation Strategy**:
- Follow example in EXECUTION.md Finding C
- Use `Code.Addr.Set` to track visited blocks
- Recursively traverse `block.Code.branch` patterns:
  - `Branch (addr, _)` → single successor
  - `Cond (_, (t_addr, _), (f_addr, _))` → two successors
  - `Switch (_, conts)` → multiple successors
  - Other patterns → handle appropriately

**Expected Impact**:
- Generated Lua will include all function calls and execution code
- `hello.bc.lua` will contain `print_endline` calls
- All execution tests should pass

---

### Task 6.2: Implement Fix (~variable lines)

**Process**: Based on Task 6.1 findings, implement the appropriate fix.

**Example Fix for Finding B** (if bytecode parsing is the issue):

**File**: `compiler/bin-lua_of_ocaml/compile.ml`

```ocaml
(* Line 45: Ensure initialization code is included *)
let one =
  let ic = open_in_bin bytecode in
  let result =
    Parse_bytecode.from_exe
      ~includes:include_dirs
      ~linkall:true  (* CHANGE: was 'linkall' parameter, ensure it's true *)
      ~link_info:true  (* CHANGE: was false, may need linking info *)
      ~include_cmis:false
      ~debug:need_debug
      ic
  in
  close_in ic;
  result
```

**Example Fix for Finding C** (if control flow not followed):

**File**: `compiler/lib-lua/lua_generate.ml`

```ocaml
(* Modify generate_module_init to follow all branches *)
let generate_module_init ctx program =
  (* Instead of just compiling entry block, compile ALL reachable blocks *)

  (* Collect all reachable blocks via BFS/DFS *)
  let rec collect_reachable visited addr =
    if Code.Addr.Set.mem addr visited then visited
    else
      match Code.Addr.Map.find_opt addr program.Code.blocks with
      | None -> visited
      | Some block ->
          let visited = Code.Addr.Set.add addr visited in
          (* Find next blocks from terminator *)
          let next_addrs = match block.Code.branch with
            | Code.Branch (addr, _) -> [addr]
            | Code.Cond (_, (t_addr, _), (f_addr, _)) -> [t_addr; f_addr]
            | Code.Switch (_, conts) -> Array.to_list conts |> List.map fst
            | _ -> []
          in
          List.fold_left collect_reachable visited next_addrs
  in

  let reachable = collect_reachable Code.Addr.Set.empty program.Code.start in

  (* Generate code for all reachable blocks in order *)
  (* ... rest of implementation ... *)
```

**Test**: After fix, run:
```bash
dune build examples/hello_lua/hello.bc.lua
cat _build/default/examples/hello_lua/hello.bc.lua | grep -A5 "print"
```

**Success Criteria**:
- ✅ Compiles without warnings
- ✅ Generated Lua contains execution code (function calls, primitives)
- ✅ No regression in existing tests: `dune runtest`

---

## Phase 7: Code Generation Cleanup & Optimization (~300 lines)

**Objective**: Make code generation rock solid, remove duplication, optimize performance

### Task 7.1: Unify Block Compilation Strategy (~100 lines)

**Problem**: Currently have two approaches mixed together:
1. OLD: `generate_block_with_program` - recursive inlining (causes exponential blowup)
2. NEW: `generate_module_init` - collect reachable blocks + labels/gotos (correct but incomplete)

**Fix**: Unify on label/goto approach for ALL code paths:
- Module initialization (✅ done in Task 6.2)
- Closures (⚠️  still uses recursive inlining - needs fix)
- Separate compilation (`generate_module` - still uses old approach)

**File**: `compiler/lib-lua/lua_generate.ml`

**Changes**:
1. Create `compile_blocks_with_labels` helper:
```ocaml
(** Compile blocks with labels and gotos (no recursive inlining)
    @param ctx Code generation context
    @param program Full IR program
    @param start_addr Starting block address
    @return List of Lua statements with labels and gotos
*)
let compile_blocks_with_labels ctx program start_addr =
  (* Collect all reachable blocks from start *)
  let rec collect_reachable visited addr =
    if Code.Addr.Set.mem addr visited then visited
    else match Code.Addr.Map.find_opt addr program.Code.blocks with
    | None -> visited
    | Some block ->
        let visited = Code.Addr.Set.add addr visited in
        let successors = match block.Code.branch with
        | Code.Branch (next, _) -> [next]
        | Code.Cond (_, (t, _), (f, _)) -> [t; f]
        | Code.Switch (_, conts) -> Array.to_list conts |> List.map ~f:fst
        | Code.Pushtrap ((c, _), _, (h, _)) -> [c; h]
        | Code.Poptrap (a, _) -> [a]
        | Code.Return _ | Code.Raise _ | Code.Stop -> []
        in
        List.fold_left ~f:collect_reachable ~init:visited successors
  in

  let reachable = collect_reachable Code.Addr.Set.empty start_addr in

  (* Generate code for each block with label *)
  reachable
  |> Code.Addr.Set.elements
  |> List.sort ~cmp:compare
  |> List.concat_map ~f:(fun addr ->
      match Code.Addr.Map.find_opt addr program.Code.blocks with
      | None -> []
      | Some block ->
          let label = L.Label ("block_" ^ Code.Addr.to_string addr) in
          let body = generate_instrs ctx block.Code.body in
          let terminator = generate_last ctx block.Code.branch in
          [label] @ body @ terminator)
```

2. Update `generate_closure` to use `compile_blocks_with_labels`:
```ocaml
and generate_closure ctx params pc =
  match ctx.program with
  | None -> L.Ident "caml_closure"
  | Some program ->
      let param_names = List.map ~f:(var_name ctx) params in
      let body_stmts = compile_blocks_with_labels ctx program pc in
      L.Function (param_names, false, body_stmts)
```

3. Update `generate_module` to use same approach as `generate_module_init`

**Success Criteria**:
- [x] Single unified approach for all code generation
- [x] No more recursive inlining anywhere
- [x] All tests compile without warnings
- [x] Performance: hello.bc.lua builds in <5 seconds

---

### Task 7.2: Remove Dead Code (~50 lines)

**Process**: Remove unused functions that are now redundant

**File**: `compiler/lib-lua/lua_generate.ml`

**Remove**:
1. `generate_last_with_program` - no longer used
2. `generate_block_with_program` - replaced by `compile_blocks_with_labels`
3. `generate_switch` helper - replaced by goto version in `generate_last`
4. Old visited parameter infrastructure if no longer needed

**File**: `compiler/lib-lua/lua_generate.mli`

**Remove**:
1. Export of `generate_last_with_program`
2. Export of `generate_block_with_program`

**Success Criteria**:
- [x] No unused functions remain
- [x] No compilation warnings about unused code
- [x] Code is cleaner and easier to understand

---

### Task 7.3: Test All Code Paths (~50 lines)

**Process**: Ensure all execution patterns work

**Tests to verify**:
1. Simple linear code (minimal_exec.ml) ✅
2. Conditional branches (if/else)
3. Switch statements (pattern matching)
4. Closures with multiple blocks
5. Tail recursion
6. Exception handling (basic)
7. Large programs (>1000 blocks)

**File**: Add tests to `compiler/tests-lua/test_code_generation.ml`

**Success Criteria**:
- [ ] All test patterns pass
- [ ] Generated Lua is valid and executable
- [ ] No regressions in existing tests

---

## Phase 8: Performance Optimization & Benchmarking (~380 lines)

**Context**: Lua_of_ocaml will be used in **self-hosted compiler** for **on-demand compilation**.
This means:
- Compilation must be **FAST** (<1s for typical modules, <5s for large ones)
- Will run in production during development (like js_of_ocaml)
- Performance regressions are **critical failures**

**Current Problem**: Tests timeout after 2 minutes (completely unacceptable)

**Objective**: Make code generation 100x faster through systematic optimization

---

### Task 8.1: Establish Baseline Benchmarks (~80 lines)

**Critical**: You can't optimize what you don't measure!

Create comprehensive benchmark suite to measure:
1. **End-to-end compilation time** (bytecode → Lua string)
2. **Block traversal time** (BFS to collect reachable blocks)
3. **Code generation time** (blocks → Lua AST)
4. **String serialization time** (AST → string)
5. **Memory allocation** (GC pressure)

**File**: `compiler/tests-lua/bench_lua_generate.ml`

```ocaml
(* Benchmark suite for Lua code generation *)

open Js_of_ocaml_compiler.Stdlib
open Js_of_ocaml_compiler
module Lua_generate = Lua_of_ocaml_compiler__Lua_generate
module Lua_output = Lua_of_ocaml_compiler__Lua_output

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
  Gc.compact ();  (* Force GC before timing *)
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
  (result, time_ms, memory_mb)

(** Compile bytecode file and measure performance *)
let bench_compile_file ~name bytecode_path =
  Printf.eprintf "Benchmarking %s...\n" name;

  let (lua_string, time_ms, memory_mb) = time_function (fun () ->
    (* Parse bytecode *)
    let ic = open_in_bin bytecode_path in
    Js_of_ocaml_compiler.Config.set_target `Wasm;
    let parsed = Parse_bytecode.from_exe
      ~includes:[]
      ~linkall:false
      ~link_info:false
      ~include_cmis:false
      ~debug:false
      ic
    in
    close_in ic;

    (* Generate Lua *)
    Lua_generate.generate_to_string ~debug:false parsed.code
  ) in

  let num_blocks =
    let ic = open_in_bin bytecode_path in
    Js_of_ocaml_compiler.Config.set_target `Wasm;
    let parsed = Parse_bytecode.from_exe
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

  { name
  ; time_ms
  ; memory_mb
  ; blocks = num_blocks
  ; output_size = String.length lua_string
  }

(** Print benchmark results *)
let print_results results =
  Printf.printf "\n=== BENCHMARK RESULTS ===\n\n";
  Printf.printf "%-30s %10s %10s %10s %12s %10s\n"
    "Benchmark" "Time(ms)" "Mem(MB)" "Blocks" "Output(KB)" "ms/block";
  Printf.printf "%s\n" (String.make 90 '-');

  List.iter (fun r ->
    let kb = float_of_int r.output_size /. 1024.0 in
    let ms_per_block = r.time_ms /. float_of_int r.blocks in
    Printf.printf "%-30s %10.2f %10.2f %10d %12.2f %10.4f\n"
      r.name r.time_ms r.memory_mb r.blocks kb ms_per_block
  ) results;

  Printf.printf "\n";

  (* Performance targets *)
  Printf.printf "PERFORMANCE TARGETS:\n";
  Printf.printf "  - Small modules (<100 blocks): <100ms\n";
  Printf.printf "  - Medium modules (100-500 blocks): <500ms\n";
  Printf.printf "  - Large modules (>500 blocks): <2000ms\n";
  Printf.printf "  - Memory: <50MB per compilation\n"

(** Run all benchmarks *)
let run_benchmarks () =
  let benchmarks = [
    ("minimal_exec", "../../../../../default/compiler/tests-lua/minimal_exec.bc");
    (* Add more benchmark files as needed *)
  ] in

  let results = List.map (fun (name, path) ->
    bench_compile_file ~name path
  ) benchmarks in

  print_results results;

  (* Check if any benchmark failed targets *)
  let has_failures = List.exists (fun r ->
    r.time_ms > 2000.0 || r.memory_mb > 50.0
  ) results in

  if has_failures then begin
    Printf.eprintf "\nWARNING: Some benchmarks failed performance targets!\n";
    exit 1
  end

let () = run_benchmarks ()
```

**Usage**:
```bash
# Add to dune:
(executable
 (name bench_lua_generate)
 (libraries lua_of_ocaml_compiler unix)
 (modules bench_lua_generate))

# Run benchmarks:
dune exec compiler/tests-lua/bench_lua_generate.exe
```

**Success Criteria**:
- [ ] Benchmarks run successfully
- [ ] Establish baseline metrics (document current performance)
- [ ] Identify slowest operations

---

### Task 8.2: Profile and Identify Bottlenecks (~investigation)

Use OCaml profiling tools to find hotspots:

```bash
# Build with profiling
dune clean
dune build --instrument-with landmarks compiler/tests-lua/bench_lua_generate.exe

# Run with profiling
OCAML_LANDMARKS=on dune exec compiler/tests-lua/bench_lua_generate.exe

# Or use perf (Linux)
dune build compiler/tests-lua/bench_lua_generate.exe
perf record -g ./bench_lua_generate.exe
perf report
```

**Expected Bottlenecks** (hypothesis to verify):

1. **Block traversal duplication**
   - Hypothesis: `compile_blocks_with_labels` called multiple times
   - Expected: 30-40% of time
   - Fix: Cache reachable blocks at program level

2. **String concatenation**
   - Hypothesis: Repeated "block_" ^ Code.Addr.to_string
   - Expected: 15-20% of time
   - Fix: Pre-generate label map

3. **List operations**
   - Hypothesis: Multiple concat_map, excessive allocations
   - Expected: 20-25% of time
   - Fix: Use Buffer, single-pass generation

4. **Variable name lookups**
   - Hypothesis: Map lookups in hot path
   - Expected: 10-15% of time
   - Fix: Better memoization strategy

**Document findings**:
Create `PERF_ANALYSIS.md` with:
- Profiling screenshots/data
- Hotspot functions with % time
- Hypothesis for each bottleneck
- Proposed optimization strategy

**Success Criteria**:
- [ ] Profiling data collected
- [ ] Top 5 bottlenecks identified with % time
- [ ] Root cause analysis for each bottleneck
- [ ] Optimization strategy documented

---

### Task 8.3: Implement Core Optimizations (~200 lines)

Based on profiling, implement targeted optimizations:

#### Optimization 1: Cache Reachable Blocks at Program Level

**Problem**: `compile_blocks_with_labels` recomputes reachable blocks every time it's called

**Fix**: Compute once, reuse everywhere

```ocaml
(** Enhanced context with cached block info *)
type compilation_cache =
  { reachable_from : Code.Addr.Set.t Code.Addr.Map.t
        (** Map: block addr → set of reachable blocks *)
  ; block_labels : string Code.Addr.Map.t
        (** Pre-generated labels for O(1) lookup *)
  }

let make_compilation_cache program =
  (* Collect all blocks in program *)
  let all_blocks =
    Code.Addr.Map.fold
      (fun addr _ acc -> Code.Addr.Set.add addr acc)
      program.Code.blocks
      Code.Addr.Set.empty
  in

  (* Pre-generate all labels *)
  let block_labels =
    Code.Addr.Set.fold
      (fun addr map ->
        Code.Addr.Map.add addr ("block_" ^ Code.Addr.to_string addr) map)
      all_blocks
      Code.Addr.Map.empty
  in

  (* Compute reachable blocks from each starting point *)
  (* For now, we primarily care about entry point + closures *)
  { reachable_from = Code.Addr.Map.empty
  ; block_labels
  }

(* Update context type *)
type context =
  { vars : var_context
  ; _debug : bool
  ; program : Code.program option
  ; optimize_field_access : bool
  ; cache : compilation_cache option  (* NEW *)
  }

(* Update compile_blocks_with_labels to use cache *)
let compile_blocks_with_labels ctx program start_addr =
  match ctx.cache with
  | Some cache ->
      (* Fast path: use pre-generated labels *)
      let get_label addr =
        Code.Addr.Map.find addr cache.block_labels
      in
      (* ... rest of function using get_label ... *)
  | None ->
      (* Slow path: generate on demand *)
      (* ... existing implementation ... *)
```

#### Optimization 2: Single-Pass Code Generation with Buffer

**Problem**: Multiple list allocations and concatenations

**Fix**: Use Buffer for direct string building

```ocaml
(** Generate code directly to Buffer (zero-copy) *)
let compile_blocks_to_buffer ctx program start_addr buf =
  let reachable = collect_reachable Code.Addr.Set.empty start_addr in
  let sorted_blocks =
    reachable
    |> Code.Addr.Set.elements
    |> List.sort compare
  in

  (* Generate directly to buffer *)
  List.iter (fun addr ->
    match Code.Addr.Map.find_opt addr program.Code.blocks with
    | None -> ()
    | Some block ->
        (* Add label *)
        Buffer.add_string buf "::block_";
        Buffer.add_string buf (Code.Addr.to_string addr);
        Buffer.add_string buf "::\n";

        (* Generate body *)
        List.iter (fun instr ->
          let lua_stmt = generate_instr ctx instr in
          Lua_output.emit_stat_to_buffer buf lua_stmt;
          Buffer.add_char buf '\n'
        ) block.Code.body;

        (* Generate terminator *)
        let last_stmts = generate_last ctx block.Code.branch in
        List.iter (fun stmt ->
          Lua_output.emit_stat_to_buffer buf stmt;
          Buffer.add_char buf '\n'
        ) last_stmts
  ) sorted_blocks
```

#### Optimization 3: Lazy Block Generation

**Problem**: Generate all blocks even if unreachable from closures

**Fix**: Only generate what's needed

```ocaml
(** Generate only entry blocks + actually-used closures *)
let compile_program_lazy ctx program =
  (* Track which blocks are actually referenced *)
  let referenced_blocks = ref Code.Addr.Set.empty in

  (* Mark closure entry points during traversal *)
  let rec mark_expr = function
    | Code.Closure (_, (pc, _), _) ->
        referenced_blocks := Code.Addr.Set.add pc !referenced_blocks
    | Code.Block (_, arr, _, _) ->
        Array.iter (fun v -> mark_var v) arr
    | _ -> ()
  and mark_var v = (* traverse variable definition *) ()
  in

  (* Only generate referenced blocks *)
  Code.Addr.Set.iter (fun addr ->
    compile_block_if_needed ctx program addr
  ) !referenced_blocks
```

#### Optimization 4: Parallel Block Generation

**Problem**: Large programs could benefit from parallelism

**Fix**: Use Domainslib for parallel compilation

```ocaml
(** Compile blocks in parallel using Domainslib *)
let compile_blocks_parallel ctx program blocks =
  let pool = Domainslib.Task.setup_pool ~num_domains:4 () in

  let compile_one addr =
    match Code.Addr.Map.find_opt addr program.Code.blocks with
    | None -> []
    | Some block -> compile_block ctx block
  in

  let results =
    Domainslib.Task.run pool (fun () ->
      blocks
      |> List.map (fun addr ->
          Domainslib.Task.async pool (fun () -> compile_one addr))
      |> List.map (Domainslib.Task.await pool)
    )
  in

  Domainslib.Task.teardown_pool pool;
  results
```

#### Optimization 5: Avoid Redundant Traversals

**Problem**: generate_instrs maps over list, could combine with other passes

**Fix**: Fuse traversals

```ocaml
(** Generate block with fused passes *)
let generate_block_optimized ctx block =
  (* Single pass: generate + count locals + optimize *)
  let buf = Buffer.create 256 in
  let local_count = ref 0 in

  List.iter (fun instr ->
    match instr with
    | Code.Let (var, expr) ->
        incr local_count;
        let lua_stmt = generate_instr ctx instr in
        Lua_output.emit_stat_to_buffer buf lua_stmt
    | _ ->
        let lua_stmt = generate_instr ctx instr in
        Lua_output.emit_stat_to_buffer buf lua_stmt
  ) block.Code.body;

  (Buffer.contents buf, !local_count)
```

**Implementation Priority**:
1. ✅ Optimization 1 (cache) - Highest impact, ~50% speedup expected
2. ✅ Optimization 2 (buffer) - High impact, ~30% speedup expected
3. ✅ Optimization 5 (fused passes) - Medium impact, ~15% speedup expected
4. ⚠️  Optimization 3 (lazy) - Test if needed after 1+2
5. ⚠️  Optimization 4 (parallel) - Only if targets still not met

**Success Criteria**:
- [ ] Optimizations 1, 2, 5 implemented
- [ ] Code compiles without warnings
- [ ] All existing tests pass
- [ ] Benchmark shows >10x speedup

---

### Task 8.4: Verify Improvements with Benchmarks (~50 lines)

Re-run benchmarks and compare to baseline:

```ocaml
(** Compare benchmark results *)
let compare_benchmarks baseline_file optimized_file =
  (* Load results from both runs *)
  let baseline = load_results baseline_file in
  let optimized = load_results optimized_file in

  Printf.printf "\n=== OPTIMIZATION IMPACT ===\n\n";
  Printf.printf "%-30s %10s %10s %10s\n"
    "Benchmark" "Before(ms)" "After(ms)" "Speedup";
  Printf.printf "%s\n" (String.make 70 '-');

  List.iter2 (fun b o ->
    let speedup = b.time_ms /. o.time_ms in
    let symbol = if speedup > 2.0 then "✓✓" else if speedup > 1.2 then "✓" else "✗" in
    Printf.printf "%-30s %10.2f %10.2f %9.1fx %s\n"
      b.name b.time_ms o.time_ms speedup symbol
  ) baseline optimized
```

**Performance Targets** (revised based on profiling):
- **Minimal programs** (<100 blocks): <50ms ⚡
- **Small programs** (100-200 blocks): <150ms
- **Medium programs** (200-500 blocks): <500ms
- **Large programs** (500-1000 blocks): <1500ms
- **Very large** (>1000 blocks): <3000ms
- **Memory**: <50MB per compilation

**Success Criteria**:
- [ ] All benchmarks meet performance targets
- [ ] Speedup >10x from baseline
- [ ] Memory usage within limits
- [ ] No performance regressions

---

### Task 8.5: Add Performance Regression Tests (~50 lines)

Prevent future performance degradation:

```ocaml
(** Performance regression test *)
let%expect_test "compilation performance regression" =
  (* This test FAILS if compilation is too slow *)
  let start = Unix.gettimeofday () in

  let bytecode_file = "../../../../../default/compiler/tests-lua/minimal_exec.bc" in
  let ic = open_in_bin bytecode_file in
  Js_of_ocaml_compiler.Config.set_target `Wasm;
  let parsed = Parse_bytecode.from_exe
    ~includes:[]
    ~linkall:false
    ~link_info:false
    ~include_cmis:false
    ~debug:false
    ic
  in
  close_in ic;

  let _lua_code = Lua_generate.generate_to_string ~debug:false parsed.code in

  let elapsed = (Unix.gettimeofday () -. start) *. 1000.0 in
  let num_blocks = Code.Addr.Map.cardinal parsed.code.Code.blocks in

  Printf.printf "Blocks: %d, Time: %.2fms\n" num_blocks elapsed;

  (* FAIL test if too slow *)
  if elapsed > 100.0 then
    failwith (Printf.sprintf "REGRESSION: Compilation took %.2fms (>100ms limit)" elapsed);

  [%expect {|
    Blocks: 269, Time: <100ms
  |}]
```

**Success Criteria**:
- [ ] Regression tests in place
- [ ] Clear failure messages when performance degrades

---

## Phase 9: Verification (~120 lines)

**Objective**: Verify the fix works correctly

### Task 9.1: Verify hello_lua Executes (~20 lines)

Install Lua and run the generated code.

**Process**:

```bash
# Install Lua 5.4 (update CLAUDE.md with working command if needed)
# Try different approaches:
apt-get install lua5.4  # Ubuntu/Debian
brew install lua  # macOS
# Or use local build

# Verify Lua installed
lua -v

# Run hello_lua
dune build examples/hello_lua/hello.bc.lua
lua _build/default/examples/hello_lua/hello.bc.lua
```

**Expected Output**:
```
Hello from Lua_of_ocaml!
Factorial of 5 is: 120
Testing string operations...
Length of 'lua_of_ocaml': 13
Uppercase: LUA_OF_OCAML
```

**File**: `examples/hello_lua/README.md` (update)

```markdown
# hello_lua Example

Demonstrates Lua_of_ocaml compilation.

## Build

dune build hello.bc.lua

## Run

lua _build/default/hello.bc.lua

## Expected Output

Hello from Lua_of_ocaml!
Factorial of 5 is: 120
Testing string operations...
Length of 'lua_of_ocaml': 13
Uppercase: LUA_OF_OCAML
```

**Success Criteria**:
- ✅ Lua executes without errors
- ✅ Output matches expected output
- ✅ All functionality works (factorial, string ops)

---

### Task 9.2: Add Execution Tests (~100 lines)

Add tests for common execution patterns.

**File**: `compiler/tests-lua/test_execution.ml`

```ocaml
(* Tests for program execution patterns *)

open Js_of_ocaml_compiler.Stdlib
module Lua_generate = Lua_of_ocaml_compiler__Lua_generate
module Lua_output = Lua_of_ocaml_compiler__Lua_output

(* Helper: compile OCaml source to Lua string *)
let compile_to_lua source_code =
  (* Write source to temp file *)
  let tmp_ml = Filename.temp_file "test" ".ml" in
  let tmp_bc = Filename.temp_file "test" ".bc" in
  Out_channel.with_open_bin tmp_ml (fun oc ->
    Out_channel.output_string oc source_code);

  (* Compile to bytecode *)
  let cmd = Printf.sprintf "ocamlc -o %s %s" tmp_bc tmp_ml in
  let _ = Sys.command cmd in

  (* Parse and generate Lua *)
  let ic = open_in_bin tmp_bc in
  let parsed = Parse_bytecode.from_exe
    ~includes:[] ~linkall:true ~link_info:false
    ~include_cmis:false ~debug:false ic in
  close_in ic;

  let lua_code = Lua_generate.generate ~debug:false parsed.code in
  Lua_output.program_to_string lua_code

let%expect_test "simple print statement generates call" =
  let lua = compile_to_lua {|
    let () = print_endline "test"
  |} in

  (* Check for print-related code *)
  let has_print = String.contains_substring lua "print" in
  Printf.printf "Contains print: %b\n" has_print;
  [%expect {| Contains print: true |}]

let%expect_test "function call generates apply" =
  let lua = compile_to_lua {|
    let double x = x * 2
    let () = print_int (double 5)
  |} in

  (* Check for function definition and call *)
  let has_function = String.contains_substring lua "function" in
  let has_call = String.contains_substring lua "(" in
  Printf.printf "Contains function: %b\n" has_function;
  Printf.printf "Contains call: %b\n" has_call;
  [%expect {|
    Contains function: true
    Contains call: true
  |}]

let%expect_test "if statement generates conditional" =
  let lua = compile_to_lua {|
    let () = if true then print_endline "yes" else print_endline "no"
  |} in

  (* Check for if statement *)
  let has_if = String.contains_substring lua "if" in
  Printf.printf "Contains if: %b\n" has_if;
  [%expect {| Contains if: true |}]

let%expect_test "match statement generates switch" =
  let lua = compile_to_lua {|
    type t = A | B | C
    let () = match A with
      | A -> print_endline "A"
      | B -> print_endline "B"
      | C -> print_endline "C"
  |} in

  (* Check for conditional logic *)
  let has_conditional =
    String.contains_substring lua "if" ||
    String.contains_substring lua "elseif" in
  Printf.printf "Contains conditional: %b\n" has_conditional;
  [%expect {| Contains conditional: true |}]
```

**Test**:
```bash
dune runtest compiler/tests-lua/
```

**Success Criteria**:
- ✅ All tests pass
- ✅ Common execution patterns generate correct Lua
- ✅ No warnings during compilation

---

## Summary

This plan focuses on **investigation first, then targeted fix**, rather than reimplementing already-working code.

**Key Insight**: 90% of execution infrastructure already exists in lua_generate.ml. The problem is either:
1. The IR being fed to the code generator is incomplete, OR
2. The code generator isn't following all control flow paths

**Phases**:
- **Phase 5**: Investigate and identify the exact root cause
- **Phase 6**: Implement minimal targeted fix
- **Phase 7**: Verify fix works end-to-end

**Next Steps After Completion**:
- Update LINKING.md Task 4.2 to mark as fully complete
- Consider adding more runtime primitives (I/O, strings) as separate tasks
- Move on to Task 4.3: Verify all existing tests pass
