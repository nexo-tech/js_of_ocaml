# OPTIMAL_LINKING.md - Runtime Linking Optimization Plan

**Created**: 2025-10-17
**Goal**: Implement minimal runtime linking - only include functions actually used
**Priority**: HIGH - 16x code bloat currently (26K lines vs 1.6K in JS)

---

## Current Situation

### The Problem 🔴

**Lua output is 16x larger than JS for the same program!**

| Metric | hello_lua (Lua) | hello_lua (JS) | Ratio |
|--------|-----------------|----------------|-------|
| **Lines of code** | 26,919 | 1,671 | **16.1x** |
| **Provides count** | 765 | 0 (stripped) | N/A |
| **Unique functions** | 755 | ~50 (estimated) | **15x** |

**Minimal `print_int 42` program:**
| Metric | Lua | JS | Ratio |
|--------|-----|-----|-------|
| **Lines** | 12,756 | 2,762 | **4.6x** |
| **Provides** | 765 | 0 | N/A |
| **Bytecode primitives** | 439 | 439 | 1x |

### Root Cause

**File**: `compiler/lib-lua/lua_generate.ml:3630-3642`

```ocaml
(* FORCE linkall behavior until we track primitives added during codegen *)
let needed_symbols =
  (* Include all symbols from all fragments (linkall) *)
  List.fold_left
    ~f:(fun acc frag ->
      if String.equal frag.Lua_link.name "core" then acc
      else
        List.fold_left
          ~f:(fun acc2 sym -> StringSet.add sym acc2)
          ~init:acc
          frag.Lua_link.provides)
    ~init:StringSet.empty
    fragments
in
```

**This includes ALL 755 functions from ALL 25+ runtime modules:**
- weak.lua (17 functions)
- trampoline.lua (2 functions)
- stack.lua (8 functions)
- result.lua (14 functions)
- queue.lua (18 functions)
- option.lua (22 functions)
- obj.lua (35 functions)
- mlBytes.lua (60+ functions)
- ints.lua (50+ functions)
- marshal_io.lua (30+ functions)
- marshal_header.lua (10+ functions)
- marshal.lua (50+ functions)
- list.lua (40+ functions)
- lazy.lua (15+ functions)
- gc.lua (20+ functions)
- format.lua (40+ functions)
- buffer.lua (15+ functions)
- float.lua (50+ functions)
- fail.lua (30+ functions)
- map.lua (60+ functions)
- io.lua (70+ functions)
- stream.lua (40+ functions)
- lexing.lua (30+ functions)
- etc.

**But most programs only need 5-20 of these functions!**

---

## How js_of_ocaml Does It ✅

**File**: `compiler/lib/driver.ml:670-680`

```ocaml
let used =
  let free =
    lazy
      (let free = ref StringSet.empty in
       let o = new Js_traverse.fast_freevar (fun s -> free := StringSet.add s !free) in
       o#program js;
       !free)
  in
  match link with
  | `All ->
      let prim = Primitive.get_external () in
      StringSet.union (StringSet.inter prim (Lazy.force free)) all_provided
  | `Needed ->
      let prim = Primitive.get_external () in
      let all_external = StringSet.union prim all_provided in
      StringSet.inter (Lazy.force free) all_external
```

**The Algorithm:**
1. **Collect primitives** from bytecode: `Primitive.get_external()` → 439 primitives
2. **Traverse generated JS** to find free variables (actually called functions)
3. **Intersect** free vars with available primitives
4. **Link only needed** functions via `Linker.resolve_deps`

**Result**: Only 50-100 functions for hello_lua instead of 755!

---

## Analysis: What's Actually Needed

### Minimal Program: `print_int 42; print_newline ()`

**Bytecode primitives**: 439 (full stdlib listed)
**Actually used** (estimated): ~15 functions
- `caml_ml_output` (for printing)
- `caml_ml_flush`
- `caml_ml_open_descriptor_out`
- `caml_ml_channels`
- `caml_format_int` (for int formatting)
- `caml_string_of_jsbytes`
- `caml_fresh_oo_id` (maybe?)
- `caml_register_global`
- A few others

**Currently linked**: 755 functions (50x bloat!)

### hello_lua: Printf + String operations

**Actually needed** (estimated): ~40 functions
- Printf: `caml_format_int`, `caml_format_string`, `caml_parse_format`, etc. (~10)
- String: `caml_bytes_uppercase`, `caml_string_of_bytes`, `caml_bytes_unsafe_get`, etc. (~8)
- I/O: `caml_ml_output`, `caml_ml_flush`, `caml_ml_open_descriptor_out`, etc. (~5)
- Core: `caml_register_global`, `caml_fresh_oo_id`, `caml_call_gen`, etc. (~5)
- Buffer: `caml_buffer_*` (~5)
- Utils: `caml_unsigned`, `caml_ocaml_string_to_lua`, etc. (~7)

**Currently linked**: 755 functions (19x bloat!)

---

## Master Checklist

### Phase 1: Understand Primitive Collection - [x] COMPLETE

**Goal**: Understand how to collect actually-used primitives from IR/generated code

- [x] Task 1.1: Study js_of_ocaml primitive collection ✅
  - Read `compiler/lib/primitive.ml` to understand `get_external()`
  - Understand how it extracts primitives from Code.program
  - Document the data structures used
  - **Reference**: `compiler/lib/primitive.ml:60-94`

  **Findings**:

  **1. Primitive Collection from Bytecode** (`parse_bytecode.ml:2650-2680`):
  ```ocaml
  (* Read PRIM section from bytecode - contains ALL primitives *)
  let primitives = read_primitives toc ic in  (* 439 primitives *)
  let primitive_table = Array.of_list primitives in

  (* During bytecode parsing, when C_CALL instructions found: *)
  let prim = primitive_name state i in  (* Index into primitive_table *)
  Primitive.add_external prim;          (* Register primitive *)
  ```

  **2. Free Variable Collection** (`js_traverse.ml:1335-1395`):
  ```ocaml
  class fast_freevar f =
    object (m)
      inherit iter as super
      val decl = StringSet.empty  (* Declared variables in scope *)

      method ident x : unit =
        match x with
        | V _ -> ()
        | S { name = Utf8 name; _ } ->
            if not (StringSet.mem name decl) then f name  (* Free variable! *)
  ```

  **Key**: Traverses JavaScript AST, calls `f name` for every identifier not declared in scope.

  **3. Minimal Linking Algorithm** (`driver.ml:365-381`):
  ```ocaml
  let used =
    let free = lazy (
      let free = ref StringSet.empty in
      let o = new Js_traverse.fast_freevar (fun s -> free := StringSet.add s !free) in
      o#program js;  (* Traverse generated JS *)
      !free
    ) in
    match link with
    | `Needed ->
        let prim = Primitive.get_external () in          (* Bytecode primitives *)
        let all_external = StringSet.union prim all_provided in  (* + runtime *)
        StringSet.inter (Lazy.force free) all_external   (* Intersection! *)
  ```

  **The Algorithm**:
  1. Parse bytecode → collect ALL primitives (439 for stdlib)
  2. Generate JavaScript code
  3. Traverse JavaScript AST → collect free variables (all referenced identifiers)
  4. Intersect free vars with (bytecode primitives ∪ runtime functions)
  5. Result = actually used primitives
  6. Pass to `Linker.resolve_deps` → add dependencies → minimal set

  **Test Results** (minimal program: `print_int 42; print_newline ()`):
  - Bytecode primitives: 439 (full stdlib listed)
  - JS linked functions: **68** (via minimal linking ✅)
  - Lua linked functions: **682** (via linkall ❌)
  - **Bloat factor**: 10x

  **Unused functions in Lua** (examples):
  - All bigarray ops (caml_ba_*): 50+ functions
  - Array iteration (fold, map, iter): 15+ functions
  - Atomic operations: 10+ functions
  - Marshal/IO that's never called: 100+ functions
  - Weak refs, lazy, streams, lexing: 200+ functions

- [x] Task 1.2: Study js_of_ocaml free variable analysis ✅
  - Read `compiler/lib/js_traverse.ml` class `fast_freevar`
  - Understand how it traverses JavaScript AST to find free variables
  - Document the algorithm
  - **Reference**: `compiler/lib/driver.ml:670-680`, `compiler/lib/js_traverse.ml:1335-1468`

  **Findings**:

  **The fast_freevar Class** (`js_traverse.ml:1335-1468`):

  **Core Mechanism**:
  ```ocaml
  class fast_freevar f =
    object (m)
      inherit iter as super               (* Base visitor *)
      val decl = StringSet.empty          (* Declared vars in this scope *)

      (* Override: check every identifier *)
      method ident x =
        match x with
        | S { name = Utf8 name; _ } ->
            if not (StringSet.mem name decl) then f name  (* FREE! *)
  ```

  **Scope Management** (key innovation):
  ```ocaml
  method private update_state scope params iter_body =
    let declared_names = StringSet.union decl (declared scope params iter_body) in
    {<decl = declared_names>}  (* Creates NEW object with updated decl *)
  ```

  **The `declared` Helper** (`js_traverse.ml:1212-1333`):
  - Scans a scope (function/block) to find ALL declared variables
  - Handles: function params, var/let/const declarations, function declarations
  - Returns: StringSet of declared names
  - Used by update_state to build decl set for nested scopes

  **Scope Handling Patterns**:

  1. **Function Scope**:
  ```ocaml
  method fun_decl (_k, params, body, _nid) =
    let ids = bound_idents_of_params params in      (* Get param names *)
    let m' = m#update_state (Fun_block None) ids body in  (* New scope *)
    m'#formal_parameter_list params;                (* Traverse in new scope *)
    m'#function_body body                           (* Traverse in new scope *)
  ```

  2. **Block Scope** (let/const):
  ```ocaml
  method statement s =
    match s with
    | Block l ->
        let m' = m#update_state Lexical_block [] l in  (* New scope *)
        m'#statements l                                 (* Traverse in new scope *)
  ```

  3. **Try/Catch** (catch variable is local):
  ```ocaml
  | Try_statement (block, catch, final) ->
      (* ... *)
      match catch with
      | Some (i, catch) ->
          let ids = bound_idents_of_binding pat in
          let m' = m#update_state Lexical_block ids catch in  (* Catch var in scope *)
          m'#statements catch
  ```

  **Algorithm Summary**:
  1. Start with empty decl set
  2. For each scope (function/block):
     - Call `declared()` to find all vars declared in that scope
     - Create new traverser object with decl = old_decl ∪ new_declarations
     - Traverse scope with updated object
  3. When visiting identifier:
     - If in decl → bound variable (skip)
     - If not in decl → free variable (call f(name))
  4. Result: Set of all free variables in the program

  **Key for Lua Implementation**:
  - Lua has simpler scoping than JavaScript (only function and block scopes)
  - No var/let/const distinction (just local)
  - No classes, imports, exports
  - Same visitor pattern will work
  - Simpler implementation due to simpler language!

- [x] Task 1.3: Test js_of_ocaml linking with minimal program ✅
  - Compile minimal test: `print_int 42`
  - Use `just compile-js-pretty` to see which primitives are linked
  - Count functions in output vs bytecode primitives
  - **Command**: `just compile-js-pretty /tmp/test_linking.bc /tmp/test_linking.js`

  **Test Results**:
  ```bash
  $ cat > /tmp/test.ml << 'EOF'
  let () = print_int 42; print_newline ()
  EOF
  $ ocamlc -o /tmp/test.bc /tmp/test.ml
  $ ocamlobjinfo /tmp/test.bc | grep "Primitives used" -A1000 | grep -c "caml_"
  439  # Bytecode lists 439 primitives

  $ just compile-js-pretty /tmp/test.bc /tmp/test.js
  $ grep -o "^function caml_[a-z_]*" /tmp/test.js | sort -u | wc -l
  68  # Only 68 functions linked! (85% reduction)

  $ node /tmp/test.js
  42  # Works perfectly!
  ```

  **Linked functions** (partial list):
  - caml_call_gen (closure calling convention)
  - caml_ml_output, caml_ml_flush (I/O for print_int)
  - caml_ml_open_descriptor_out (stdout)
  - caml_bytes_* (string/bytes ops)
  - caml_string_of_jsbytes
  - caml_failwith, caml_invalid_argument (error handling)
  - caml_register_global (global registration)
  - etc.

  **NOT linked** (examples of unused functions):
  - caml_ba_* (50+ bigarray functions - not used)
  - caml_array_fold_left, map, iter (not used)
  - caml_marshal_* (100+ functions - not used)
  - caml_lazy_* (15+ functions - not used)
  - caml_stream_* (40+ functions - not used)
  - caml_weak_* (20+ functions - not used)

  **Comparison**:
  - Bytecode declares: 439 primitives (full stdlib)
  - JS links: 68 functions (15% of bytecode list)
  - Efficiency: **85% reduction through minimal linking** ✅

- [x] Task 1.4: Document current lua_of_ocaml linking behavior ✅
  - Trace code flow: `lua_generate.ml:3610-3672`
  - Document why linkall is forced (line 3610 comment)
  - List all 25+ runtime modules being linked

  **Current Lua Linking** (`lua_generate.ml:3610-3672`):

  **The Problem Code**:
  ```ocaml
  (* TEMPORARY: Use linkall behavior - include ALL runtime modules.
     This is needed because code generation adds primitive calls (like caml_fresh_oo_id)
     that aren't in the original IR, so collect_used_primitives misses them.
     TODO: Either (1) track primitives during codegen, or (2) analyze generated AST. *)
  let needed_symbols =
    (* Include all symbols from all fragments (linkall) *)
    List.fold_left
      ~f:(fun acc frag ->
        if String.equal frag.Lua_link.name "core" then acc
        else
          List.fold_left
            ~f:(fun acc2 sym -> StringSet.add sym acc2)
            ~init:acc
            frag.Lua_link.provides)
      ~init:StringSet.empty
      fragments
  in
  ```

  **What it does**: Includes EVERY function from EVERY runtime module (except core.lua)

  **Runtime modules linked** (all 25+ modules):
  1. weak.lua - 17 functions (weak references)
  2. trampoline.lua - 2 functions (stack unwinding)
  3. stack.lua - 8 functions (call stack)
  4. result.lua - 14 functions (Result type)
  5. queue.lua - 18 functions (Queue data structure)
  6. option.lua - 22 functions (Option type)
  7. obj.lua - 35 functions (Obj module)
  8. mlBytes.lua - 60+ functions (bytes/string ops)
  9. ints.lua - 50+ functions (int32 operations)
  10. marshal_io.lua - 30+ functions (marshaling I/O)
  11. marshal_header.lua - 10+ functions (marshal headers)
  12. marshal.lua - 50+ functions (marshaling)
  13. list.lua - 40+ functions (List module)
  14. lazy.lua - 15+ functions (Lazy module)
  15. gc.lua - 20+ functions (GC operations)
  16. format.lua - 40+ functions (Printf/Scanf)
  17. buffer.lua - 15+ functions (Buffer module)
  18. float.lua - 50+ functions (float operations)
  19. fail.lua - 30+ functions (exception handling)
  20. map.lua - 60+ functions (Map data structure)
  21. io.lua - 70+ functions (I/O operations)
  22. stream.lua - 40+ functions (Stream module)
  23. lexing.lua - 30+ functions (Lexing module)
  24. array.lua - 40+ functions (Array operations)
  25. bigarray.lua - 80+ functions (Bigarray)
  26. compare.lua - 20+ functions (comparison)
  27. domain.lua - 15+ functions (Domain/multicore)
  28. digest.lua - 10+ functions (MD5/hashing)
  29. filename.lua - 15+ functions (Filename module)
  30. hashtbl.lua - 30+ functions (Hashtbl)
  31. And more...

  **Total**: ~755 unique functions, most programs use <50

  **Why this is bad**:
  - `print_int 42` needs ~10 functions, gets 755 (75x bloat)
  - hello_lua needs ~40 functions, gets 755 (19x bloat)
  - 16x code size vs JS (26K lines vs 1.6K)

  **The fix** (Option 2 from comment):
  - Generate Lua code first
  - Analyze generated Lua AST to find free variables (like JS does)
  - Pass only used functions to Lua_link.resolve_deps
  - Result: Minimal linking ✅

**Deliverable**: Complete understanding of js_of_ocaml minimal linking and current lua_of_ocaml linkall problem

---

### Phase 2: Design Lua Free Variable Traversal - [ ]

**Goal**: Create Lua AST traversal to find actually-used caml_* functions

- [ ] Task 2.1: Design lua_traverse.ml module
  - Mirror structure of `js_traverse.ml`
  - Create class `traverse` with visitor pattern for Lua AST
  - Create class `fast_freevar` to collect free variables
  - **Reference**: `compiler/lib/js_traverse.ml:180-250`
  - **File**: Create `compiler/lib-lua/lua_traverse.ml`

- [ ] Task 2.2: Implement Lua expression traversal
  - Handle all expr types: Ident, Call, BinOp, UnOp, etc.
  - Collect identifiers that look like `caml_*` functions
  - Distinguish function calls from variable references
  - **Reference**: `compiler/lib/js_traverse.ml` methods for expressions

- [ ] Task 2.3: Implement Lua statement traversal
  - Handle all statement types: Assign, If, While, Call_stat, etc.
  - Recursively traverse nested blocks
  - Collect all free variables
  - **Reference**: `compiler/lib/js_traverse.ml` methods for statements

- [ ] Task 2.4: Add test for lua_traverse
  - Create test file: `compiler/tests-lua/test_lua_traverse.ml`
  - Test with known Lua code containing caml_* calls
  - Verify all free variables are found
  - **Expected**: Test finds exact set of caml_* functions
  - **Command**: `just test-file test_lua_traverse`

- [ ] Task 2.5: Handle edge cases
  - Function calls via variables: `local f = caml_foo; f(arg)`
  - Method calls: (probably not needed for caml_* functions)
  - Closure captures: functions defined in closures
  - Generated code patterns: inline runtime, primitives added by codegen

**Deliverable**: `lua_traverse.ml` module that can find free variables in Lua AST

---

### Phase 3: Implement Minimal Linking - [ ]

**Goal**: Replace linkall with minimal linking based on actually-used primitives

- [ ] Task 3.1: Collect primitives from generated Lua AST
  - In `lua_generate.ml:generate()`, after generating code
  - Use `lua_traverse.fast_freevar` to collect free variables
  - Filter to only `caml_*` functions (primitives)
  - **Location**: `compiler/lib-lua/lua_generate.ml:~3675` (before return)

- [ ] Task 3.2: Track primitives added during code generation
  - Code generation adds primitives not in IR (e.g., `caml_fresh_oo_id`)
  - Option A: Track during codegen (add to ctx)
  - Option B: Analyze generated AST (use lua_traverse)
  - **Recommendation**: Option B (simpler, no ctx changes)
  - **Reference**: Comment at `lua_generate.ml:3612-3613`

- [ ] Task 3.3: Replace linkall with minimal linking
  - Change `needed_symbols` from "all symbols" to "actually used"
  - Use `lua_traverse` to find free variables in generated code
  - Pass to `Lua_link.resolve_deps` (already works correctly)
  - **Location**: `lua_generate.ml:3630-3642`
  - **Before**: `List.fold_left ... frag.Lua_link.provides` (all symbols)
  - **After**: `StringSet.elements (find_free_variables lua_code)` (used symbols)

- [ ] Task 3.4: Handle inline runtime conflicts
  - Inline runtime provides: `caml_register_global`, bitwise ops, etc.
  - Don't link these from runtime modules (already inlined)
  - Filter them out before calling resolve_deps
  - **Check**: Lines 3432-3530 for inline runtime functions

- [ ] Task 3.5: Add debug output for linked functions
  - When debug enabled, print which functions are being linked
  - Format: `[LINKER] Linking 47 functions (out of 755 available)`
  - List the functions being linked
  - **Use**: Existing debug flags

**Deliverable**: Minimal linking that only includes needed runtime functions

---

### Phase 4: Test and Validate - [ ]

**Goal**: Verify minimal linking works and measure improvements

- [ ] Task 4.1: Test minimal program
  - Program: `print_int 42; print_newline ()`
  - **Before**: 12,756 lines, 765 Provides
  - **After target**: ~500-1000 lines, ~15 Provides
  - **Command**: `just quick-test /tmp/minimal_test.ml && wc -l /tmp/quick_test.lua`
  - **Verify**: Output still works correctly

- [ ] Task 4.2: Test hello_lua
  - **Before**: 26,919 lines, 765 Provides
  - **After target**: ~1500-3000 lines, ~40-50 Provides
  - **Command**: `dune build examples/hello_lua/hello.bc.lua && wc -l _build/default/examples/hello_lua/hello.bc.lua`
  - **Verify**: All output correct (Printf, String.uppercase_ascii, etc.)

- [ ] Task 4.3: Test all Printf formats
  - Run existing Printf tests
  - **Command**: `just test-file test_printf_formats`
  - **Verify**: All tests pass, output sizes reduced

- [ ] Task 4.4: Compare with JS output sizes
  - Compile same programs to both Lua and JS
  - **Target**: Lua should be 1-2x JS size (currently 16x!)
  - Acceptable reasons for larger size:
    - Lua verbosity (while loops vs for loops)
    - Dispatch patterns
    - Variable table management
  - **Not acceptable**: Linking entire stdlib when using 5 functions

- [ ] Task 4.5: Run full test suite
  - **Command**: `just test-lua`
  - **Verify**: No regressions, all tests pass
  - **Check**: Test output sizes also reduced

**Deliverable**: Minimal linking works, significant size reduction achieved

---

### Phase 5: Advanced Optimizations - [ ]

**Goal**: Further optimize linking and remove unnecessary code

- [ ] Task 5.1: Remove --Provides comments from final output
  - JS doesn't include //Provides in output (they're for linking only)
  - Strip --Provides and --Requires comments after linking
  - **Location**: `lua_link.ml:embed_runtime_module` or `lua_output.ml`
  - **Savings**: ~765 lines (one per function)

- [ ] Task 5.2: Implement function-level linking
  - Currently links entire files (e.g., all of mlBytes.lua)
  - Extract individual functions based on --Provides comments
  - Only include the specific functions needed
  - **Reference**: js_of_ocaml does this with //Provides parsing
  - **Location**: `lua_link.ml:parse_fragment`

- [ ] Task 5.3: Dead code elimination
  - Some linked functions may have unused branches
  - Could eliminate unreachable code paths
  - **Complexity**: Medium-high
  - **Priority**: Low (do later)

- [ ] Task 5.4: Optimize inline runtime
  - Currently includes full bitwise operation implementations
  - Could use Lua 5.3+ native bitwise when available
  - Provide Lua 5.1 fallback
  - **Location**: `lua_generate.ml:3432-3530`

- [ ] Task 5.5: Benchmark and measure
  - Create benchmarks for different program sizes
  - Measure:
    - Compilation time
    - Output file size
    - Runtime performance
  - **Command**: Create `just benchmark-linking`

**Deliverable**: Maximum optimization, Lua output comparable to JS size

---

### Phase 6: Documentation and Cleanup - [ ]

**Goal**: Clean code, documentation, maintainability

- [ ] Task 6.1: Remove linkall workaround
  - Delete comment at line 3610: "FORCE linkall behavior..."
  - Delete TODO at line 3612: "track primitives during codegen"
  - Update comments to explain minimal linking

- [ ] Task 6.2: Add linking documentation
  - Document the linking algorithm in LINKING.md
  - Explain --Provides/--Requires system
  - Explain how lua_traverse finds free variables
  - Examples of linking for different programs

- [ ] Task 6.3: Update CLAUDE.md
  - Add section on minimal linking
  - Explain that runtime is linked on-demand
  - Warn against adding unused primitives

- [ ] Task 6.4: Verify no warnings
  - **Command**: `just build-strict`
  - Fix any compilation warnings
  - Ensure clean build

- [ ] Task 6.5: Update LUA.md checklist
  - Mark linking optimization complete
  - Note size improvements
  - Reference OPTIMAL_LINKING.md

**Deliverable**: Clean, well-documented minimal linking system

---

## Implementation Strategy

### Key Insight

js_of_ocaml's approach (3 steps):
```
Bytecode Primitives (439)
    ↓
Generated JS Free Variables (50-100 caml_* calls)
    ↓
Intersection → Actually Used Primitives (50-100)
    ↓
Linker.resolve_deps → Functions + Dependencies (50-150)
```

lua_of_ocaml should do exactly the same:
```
Bytecode Primitives (439)
    ↓
Generated Lua Free Variables (find via lua_traverse)
    ↓
Intersection → Actually Used Primitives
    ↓
Lua_link.resolve_deps → Functions + Dependencies
```

### Technical Details

#### 1. Free Variable Collection

**Create `lua_traverse.ml`** modeled after `js_traverse.ml`:

```ocaml
class fast_freevar (f : string -> unit) =
  object (self)
    inherit traverse as super

    method expression expr =
      match expr with
      | L.Ident id -> f id; super#expression expr
      | L.Call (L.Ident id, args) ->
          f id;  (* Function being called *)
          List.iter self#expression args;
      | _ -> super#expression expr

    (* ... handle all expr/stat types ... *)
  end

let collect_free_vars lua_ast =
  let free = ref StringSet.empty in
  let visitor = new fast_freevar (fun s -> free := StringSet.add s !free) in
  visitor#program lua_ast;
  !free
```

#### 2. Filter to Primitives

```ocaml
let filter_primitives free_vars =
  StringSet.filter (fun s ->
    String.starts_with ~prefix:"caml_" s &&
    not (is_inline_runtime_function s)  (* Skip inlined functions *)
  ) free_vars
```

#### 3. Resolve Dependencies

```ocaml
(* This already works! Just need to pass the right set *)
let needed_primitives = filter_primitives (collect_free_vars lua_code) in
let sorted_fragment_names, _missing =
  Lua_link.resolve_deps state (StringSet.elements needed_primitives)
in
```

---

## Expected Results

### Size Reductions

| Program | Before (lines) | After (estimated) | Reduction |
|---------|---------------|-------------------|-----------|
| `print_int 42` | 12,756 | ~800-1,200 | **10-16x smaller** |
| `hello_lua` | 26,919 | ~2,000-3,500 | **8-13x smaller** |
| Printf tests | ~15,000 | ~1,500-2,500 | **6-10x smaller** |

### Function Count Reductions

| Program | Before (Provides) | After (estimated) | Reduction |
|---------|------------------|-------------------|-----------|
| `print_int 42` | 765 | ~15 | **50x fewer** |
| `hello_lua` | 765 | ~40-50 | **15-19x fewer** |

### Comparison with JS

| Program | Lua After Fix | JS | Ratio |
|---------|--------------|-----|-------|
| `print_int 42` | ~1,000 | 2,762 | **~2.7x** (acceptable!) |
| `hello_lua` | ~2,500 | 1,671 | **~1.5x** (excellent!) |

**Target**: Lua should be 1-3x the size of JS (accounting for verbosity)
**Current**: Lua is 16x the size of JS (unacceptable!)
**After fix**: Lua will be 1.5-3x the size of JS ✅

---

## Risk Assessment

### Low Risk ✅
- lua_link.ml already has correct dependency resolution
- --Provides/--Requires system works perfectly
- Just need to pass the right set of symbols
- Can test incrementally (linkall → minimal)

### Medium Risk ⚠️
- lua_traverse.ml is new code (but modeled after js_traverse.ml)
- May miss some free variables initially (tests will catch this)
- Inline runtime functions must be excluded from linking

### High Risk 🔴
- None identified

### Mitigation
- Compare output with linkall vs minimal for same program
- Extensive testing with diverse programs
- Keep linkall as fallback flag: `--linkall` forces old behavior
- Add validation: warn if linked functions > bytecode primitives

---

## Testing Strategy

### Phase 1-2 Testing
```bash
# No code changes yet, just investigation
just build-lua-all  # Should succeed
```

### Phase 3 Testing (after implementing minimal linking)
```bash
# Test 1: Minimal program
echo 'let () = print_int 42; print_newline ()' > /tmp/test.ml
just quick-test /tmp/test.ml
# Verify: works correctly, smaller output

# Test 2: hello_lua
just quick-test examples/hello_lua/hello.ml
# Verify: all output correct, much smaller

# Test 3: Printf tests
just test-file test_printf_formats
# Verify: all pass

# Test 4: Full suite
just test-lua
# Verify: no regressions

# Test 5: Size comparison
wc -l /tmp/quick_test.lua _build/default/examples/hello_lua/hello.bc.lua
# Verify: Significant reduction
```

### Validation Commands
```bash
# Compare with JS
just compile-js-pretty <file.bc> <file.js>
wc -l <file.js> <file.lua>

# Check linked functions
grep "^--Provides:" <file.lua> | wc -l

# Compare primitives
ocamlobjinfo <file.bc> | grep "Primitives used" -A1000 | grep -c "^\s*caml_"

# Full verification
just full-test
```

---

## Success Criteria

### Must Have ✅
1. Minimal programs (<100 LOC source) produce <2,000 lines of Lua
2. hello_lua produces <4,000 lines of Lua (currently 26,919)
3. Only used primitives are linked (not all 765 functions)
4. All existing tests pass
5. Output correctness matches before optimization

### Nice to Have 🌟
1. Lua output size within 2x of JS output size
2. --Provides comments stripped from final output
3. Function-level granularity (not file-level)
4. Debug flag to show linked vs available functions
5. Benchmark showing compilation time not significantly impacted

---

## Timeline Estimate

- **Phase 1**: 2-3 hours (investigation, understand js_of_ocaml)
- **Phase 2**: 4-6 hours (implement lua_traverse.ml)
- **Phase 3**: 3-4 hours (integrate minimal linking)
- **Phase 4**: 2-3 hours (testing and validation)
- **Phase 5**: 3-5 hours (advanced optimizations)
- **Phase 6**: 1-2 hours (documentation and cleanup)

**Total**: 15-23 hours

**Priority**: Complete Phases 1-4 first (core functionality)
**Later**: Phases 5-6 (optimizations and polish)

---

## Quick Commands Reference

```bash
# Investigation
ocamlobjinfo <file.bc> | grep "Primitives" -A1000  # See bytecode primitives
grep "^--Provides:" <file.lua> | wc -l             # Count linked functions
wc -l <file.lua> <file.js>                         # Compare sizes

# Testing
just quick-test <file.ml>                          # Test single file
just test-file <test_name>                         # Run specific test
just test-lua                                       # Run full Lua test suite
just build-strict                                   # Check for warnings

# Debugging
just compile-lua-debug <file.bc>                   # Compile with debug info
grep "caml_" <file.lua> | sort -u | head -50       # See used primitives

# Comparison
just compile-js-pretty <file.bc> <file.js>         # Compile to JS
just compare-outputs <file.ml>                     # Compare Lua vs JS output
```

---

## Notes

- This is **THE** most impactful optimization for lua_of_ocaml usability
- 16x code bloat makes Lua output impractical for real-world use
- After this fix, lua_of_ocaml will be production-ready for small-medium programs
- The infrastructure (lua_link.ml, --Provides/--Requires) already exists and works!
- We just need to connect the pieces (collect free vars + pass to linker)

---

## Related Files

### Files to Modify
- `compiler/lib-lua/lua_traverse.ml` (NEW - Lua AST traversal)
- `compiler/lib-lua/lua_traverse.mli` (NEW - interface)
- `compiler/lib-lua/lua_generate.ml` (lines 3630-3642 - use minimal linking)
- `compiler/lib-lua/dune` (add lua_traverse module)
- `compiler/tests-lua/test_lua_traverse.ml` (NEW - tests)

### Files to Reference
- `compiler/lib/js_traverse.ml` (model for lua_traverse)
- `compiler/lib/driver.ml:670-680` (how JS does minimal linking)
- `compiler/lib/primitive.ml` (primitive collection)
- `compiler/lib/linker.ml:721-760` (dependency resolution)

### Files That Already Work
- `compiler/lib-lua/lua_link.ml` (dependency resolution ✅)
- `runtime/lua/*.lua` (--Provides/--Requires system ✅)

---

## Celebration Target 🎯

```bash
$ echo 'let () = print_int 42; print_newline ()' > /tmp/minimal.ml
$ just quick-test /tmp/minimal.ml
...
42

$ wc -l /tmp/quick_test.lua
800 /tmp/quick_test.lua  # Down from 12,756! ✅

$ grep "^--Provides:" /tmp/quick_test.lua | wc -l
15  # Down from 765! ✅

$ dune build examples/hello_lua/hello.bc.lua
$ wc -l _build/default/examples/hello_lua/hello.bc.lua
2,500 _build/default/examples/hello_lua/hello.bc.lua  # Down from 26,919! ✅

🎉 Lua output is now practical for real-world use!
```
