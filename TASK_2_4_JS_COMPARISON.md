# Task 2.4: JS vs Lua Closure Handling Comparison

## Analysis Date: 2025-10-12

## Executive Summary

**CRITICAL DIFFERENCE FOUND**: js_of_ocaml passes block arguments to entry blocks BEFORE generating the block body, while lua_of_ocaml initializes all variables to nil first. This is the root cause of the Printf bug.

## JavaScript Approach (js_of_ocaml)

### Closure Generation Flow

**Location**: `compiler/lib/generate.ml:2319-2339`

```ocaml
and compile_closure ctx (pc, args) (cloc : Parse_info.t option) =
  let st = build_graph ctx pc cloc in
  let current_blocks = Structure.get_nodes st.structure in
  let scope_stack = [] in
  let start_loc = ... in

  (* KEY: Pass (pc, args) to compile_branch *)
  let _never, res =
    compile_branch st start_loc Q.empty (pc, args) scope_stack ~fall_through:Return
  in
  res
```

**Key Point**: The `(pc, args)` tuple is passed directly to `compile_branch`, which handles argument passing.

### Branch Compilation with Argument Passing

**Location**: `compiler/lib/generate.ml:2245-2317`

```ocaml
and compile_branch st loc queue ((pc, _) as cont) scope_stack ~fall_through : bool * _ =
  let scope = ... in
  let back_edge = ... in

  (* KEY: compile_argument_passing is called FIRST *)
  compile_argument_passing st.ctx loc queue cont back_edge (fun queue ->
      (* Then compile the block *)
      match scope with
      | None -> compile_block st loc queue pc scope_stack ~fall_through
      | Some ... -> (* handle jumps *)
  )
```

**Key Point**: `compile_argument_passing` is called as a WRAPPER around block compilation. The continuation function receives the queue AFTER arguments are passed.

### Argument Passing Implementation

**Location**: `compiler/lib/generate.ml:2238-2243`

```ocaml
and compile_argument_passing ctx loc queue (pc, args) back_edge continuation =
  if List.is_empty args
  then continuation queue
  else
    let block = Addr.Map.find pc ctx.Ctx.blocks in
    parallel_renaming ctx loc back_edge block.params args continuation queue
```

**Key Point**: If args is non-empty, it calls `parallel_renaming` to assign block parameters from args.

### Parallel Renaming

**Location**: `compiler/lib/generate.ml:981-1044`

```ocaml
let parallel_renaming ctx loc back_edge params args continuation queue =
  (* Two paths: ES6 destructuring or temp variables *)
  if back_edge && Config.Flag.es6 () then
    (* ES6: [p1, p2, ...] = [a1, a2, ...] *)
    ...
  else
    (* Classic: Generate assignments in correct order *)
    let l = visit_all params args in  (* Handle dependencies *)
    let queue, before, renaming, _ =
      List.fold_left l ~init:(queue, [], [], Code.Var.Set.empty)
        ~f:(fun (queue, before, renaming, seen) (y, x) ->
          (* y = param, x = arg *)
          (* Generate: var y = x or y = x *)
          ...)
    in
    let renaming =
      if back_edge
      then (* y = x; (assignment) *)
        List.map renaming ~f:(fun (t, e) ->
            J.Expression_statement (J.EBin (J.Eq, J.EVar (J.V t), e)), loc)
      else (* var y = x; (declaration) *)
        List.map renaming ~f:(fun (t, e) ->
            J.variable_declaration [ J.V t, (e, loc) ], loc)
    in
    let never, code = continuation queue in
    (* KEY: Prepend renaming before the block body *)
    never, List.rev_append before (List.rev_append renaming code)
```

**Key Points**:
1. Handles dependency order (uses `visit_all` to handle cases where params reference each other)
2. Generates variable declarations (`var y = x`) for new scopes
3. Generates assignments (`y = x`) for back edges (loops)
4. **CRITICAL**: Prepends these assignments BEFORE the block body code

### Generated JavaScript Pattern

For a closure with entry block parameters:

```javascript
function(counter, v201, v202, v203) {
  // Parallel renaming happens HERE if entry block has parameters
  var v206 = some_arg;  // Block parameter initialization
  var v273 = other_arg; // Another block parameter

  // Then block body
  var result = v273[2];  // Can safely access v273
  ...
}
```

## Lua Approach (lua_of_ocaml)

### Closure Generation Flow

**Location**: `compiler/lib-lua/lua_generate.ml:1246-1298`

```ocaml
and generate_closure ctx params pc block_args =
  let closure_ctx = make_child_context ctx program in
  let param_names = List.map ~f:(var_name closure_ctx) params in

  (* Generate argument passing *)
  let arg_passing = generate_argument_passing closure_ctx pc block_args ~func_params:params () in

  (* Generate body with hoisting *)
  let body_stmts = compile_blocks_with_labels closure_ctx program pc ~params () in

  (* Prepend argument passing *)
  let full_body = arg_passing @ body_stmts in

  let lua_func = L.Function (param_names, false, full_body) in
  L.Call (L.Ident "caml_make_closure", [ arity; lua_func ])
```

**The Problem**: `arg_passing` is generated separately and prepended to `body_stmts`, but `body_stmts` INCLUDES the hoisting logic that initializes variables to nil.

### Body Compilation with Hoisting

**Location**: `compiler/lib-lua/lua_generate.ml:1023-1244`

```ocaml
and compile_blocks_with_labels ctx program start_addr ?(params = []) () =
  (* Collect all variables *)
  let hoisted_vars = collect_block_variables ctx program start_addr in
  let loop_block_params = ... in
  let entry_block_params = ... in
  let all_hoisted_vars = StringSet.union hoisted_vars loop_block_params in

  (* Generate hoisting statements *)
  let hoist_stmts =
    if use_table then
      (* Initialize all vars to nil *)
      let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params in
      ...
      [ L.Local ([ "_V" ], Some [ L.Table [] ])  (* local _V = {} *)
      ] @ init_stmts  (* _V.v273 = nil, etc *)
    else ...
  in

  (* Generate parameter copies *)
  let param_copy_stmts = ... in

  (* Generate dispatch loop *)
  let dispatch_loop = ... in

  (* Return hoisted declarations + parameter copies + dispatch loop *)
  hoist_stmts @ param_copy_stmts @ dispatch_loop
```

**The Problem**: `hoist_stmts` initializes ALL variables (except function parameters) to nil BEFORE the dispatch loop starts. This includes variables that should be initialized by block_args.

### Generated Lua Pattern (WRONG)

For a closure with entry block parameters:

```lua
function(counter, v201, v202, v203)
  -- Hoisting happens FIRST
  _V.v204 = nil
  _V.v205 = nil
  ...
  _V.v273 = nil  -- ❌ v273 initialized to nil
  ...
  _V.counter = counter  -- Copy function params
  _V.v201 = v201
  _V.v202 = v202
  _V.v203 = v203

  -- arg_passing would happen here, but it's TOO LATE
  -- because dispatch loop is already generated

  local _next_block = 484
  while true do
    if _next_block == 484 then
      -- ❌ v273 is still nil here!
      _V.v282 = _V.v273[2]  -- ERROR: attempt to index nil
    end
  end
end
```

## The Core Issue

### What Should Happen

Block 484 should receive its parameters (including the value that should be in v273) BEFORE the block body executes, similar to how JS does it:

```lua
function(counter, v201, v202, v203)
  -- 1. Initialize _V table
  local _V = {}

  -- 2. Copy function parameters
  _V.counter = counter
  _V.v201 = v201
  _V.v202 = v202
  _V.v203 = v203

  -- 3. ✅ Initialize block parameters from block_args
  _V.v204 = some_value_from_block_args
  _V.v206 = another_value_from_block_args
  _V.v273 = the_actual_value  -- ✅ Initialized properly

  -- 4. Initialize other variables to nil
  _V.v205 = nil
  _V.v274 = nil
  ...

  -- 5. Now dispatch loop
  local _next_block = 484
  while true do
    if _next_block == 484 then
      _V.v282 = _V.v273[2]  -- ✅ Works! v273 has value
    end
  end
end
```

### Current Behavior

Currently, `generate_argument_passing` in lua_generate.ml:1312-1358 generates assignments like:

```ocaml
let assignment = L.Assign ([param_target], [arg_expr]) in
```

But these are prepended to `body_stmts` AFTER `body_stmts` has already generated the hoisting + dispatch loop.

So the actual order in the generated Lua is:

```lua
function(...)
  -- arg_passing from generate_argument_passing
  -- (but these are for the entry block parameters, which may not exist!)

  -- body_stmts from compile_blocks_with_labels
  -- - hoisting (initializes v273 = nil)
  -- - param copies
  -- - dispatch loop
end
```

## The Fix

### Option 1: Pass Entry Block Params to Hoisting Logic ✅ RECOMMENDED

Modify `compile_blocks_with_labels` to:
1. Accept `block_args` as a parameter
2. BEFORE hoisting, call `generate_argument_passing` to get entry block param assignments
3. Include these in the function body AFTER _V table creation but BEFORE dispatch loop
4. Exclude entry block params from nil initialization

**Pros**:
- Matches JS behavior exactly
- Clean separation of concerns
- Handles all edge cases

**Cons**:
- Requires threading `block_args` through `compile_blocks_with_labels`

### Option 2: Generate Argument Passing Inside compile_blocks_with_labels

Move the `generate_argument_passing` call from `generate_closure` into `compile_blocks_with_labels`, placing it after hoisting but before dispatch loop.

**Pros**:
- Simpler change

**Cons**:
- Mixes concerns (block compilation now knows about closure arguments)
- Harder to maintain

### Option 3: Two-Phase Hoisting

Split hoisting into:
1. Early phase: Initialize entry block parameters
2. Late phase: Initialize other variables

**Pros**:
- Minimal changes

**Cons**:
- Duplicates logic
- Harder to understand

## Recommended Solution

**Implement Option 1**: Pass entry block arguments to hoisting logic.

### Implementation Plan

1. Modify `generate_closure` to extract entry block parameters:
   ```ocaml
   let entry_block = Addr.Map.find pc program.Code.blocks in
   let entry_has_params = not (List.is_empty entry_block.Code.params) in
   ```

2. Pass `block_args` to `compile_blocks_with_labels`:
   ```ocaml
   let body_stmts = compile_blocks_with_labels closure_ctx program pc
                      ~params ~entry_args:block_args () in
   ```

3. In `compile_blocks_with_labels`, generate argument passing for entry block:
   ```ocaml
   let entry_arg_stmts =
     if not (List.is_empty entry_args) then
       generate_argument_passing ctx start_addr entry_args ~func_params:params ()
     else []
   in
   ```

4. Insert entry_arg_stmts AFTER hoisting, BEFORE dispatch loop:
   ```ocaml
   hoist_stmts @ param_copy_stmts @ entry_arg_stmts @ dispatch_loop
   ```

5. Update `collect_block_variables` to exclude entry block params from hoisting:
   ```ocaml
   let entry_block_param_names =
     match Code.Addr.Map.find_opt start_addr program.Code.blocks with
     | Some block -> List.map ~f:(var_name ctx) block.Code.params
     | None -> []
   in
   let vars_to_hoist = StringSet.diff hoisted_vars entry_block_param_names in
   ```

## Key Takeaways

1. ✅ **JS uses continuation-passing style**: `compile_argument_passing` wraps block compilation
2. ✅ **JS generates parameter assignments BEFORE block body**: Via parallel_renaming
3. ✅ **Lua generates hoisting BEFORE everything**: Including variables that should come from block_args
4. ❌ **Lua's arg_passing is TOO LATE**: It's outside compile_blocks_with_labels
5. ❌ **Entry block parameters are initialized to nil**: They should be initialized from block_args

## Files Analyzed

- `compiler/lib/generate.ml`: Lines 981-1044, 2238-2243, 2245-2339
- `compiler/lib-lua/lua_generate.ml`: Lines 1023-1298
- `/tmp/test_printf_pretty.js`: 6,637 lines, works correctly
- `/tmp/test_printf_out.lua`: 24,441 lines, fails at line 22552

## Next Steps (Task 2.5)

Implement Option 1 fix in lua_generate.ml:
1. Thread `block_args` through `compile_blocks_with_labels`
2. Generate entry block param assignments after hoisting
3. Exclude entry block params from nil initialization
4. Test with Printf and ensure it works

## References

- js_of_ocaml generate.ml: `compile_closure`, `compile_branch`, `parallel_renaming`
- lua_of_ocaml lua_generate.ml: `generate_closure`, `compile_blocks_with_labels`
- TASK_2_3_CLOSURE_ANALYSIS.md: Root cause analysis
