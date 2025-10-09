# Lua Runtime Primitive Linking Strategy

This document details the implementation plan for Task 14.3: Runtime Primitive Linking.

## Problem Statement

**Current State**:
- Generated Lua code calls global `caml_*` functions (e.g., `caml_array_make()`)
- Runtime modules export functions as `M.function` (e.g., `array.lua` exports `M.make()`)
- hello_lua example fails because `caml_register_global` doesn't exist
- 70 primitives documented in PRIMITIVES.md need linking

**Current Workaround**:
- Task 14.1 added inline `caml_register_global()` to generated code
- This works for one primitive but doesn't scale to 70 primitives

**Requirements**:
- ✅ Zero code duplication (don't copy runtime module implementations)
- ✅ No heavy refactoring (runtime modules keep `M.*` pattern for standalone testing)
- ✅ Reuse existing DEPS.md linking infrastructure
- ✅ All 35 existing Lua tests continue passing
- ✅ hello_lua example runs successfully
- ✅ Verify all 70 primitives from PRIMITIVES.md are covered

## Architecture Overview

```
┌─────────────────────┐
│ OCaml Bytecode      │
└──────────┬──────────┘
           │ Parse
           ▼
┌─────────────────────┐
│ Code.program (IR)   │──────┐
└──────────┬──────────┘      │
           │ Generate        │ Track used primitives:
           ▼                 │ - caml_array_make
┌─────────────────────┐      │ - caml_string_get
│ Lua AST             │      │ - ...
│ (uses caml_* calls) │◄─────┘
└──────────┬──────────┘
           │
           │ Link
           ▼
┌─────────────────────────────────────────────────┐
│ Final Lua Code Structure:                      │
│                                                 │
│ 1. Inline Runtime (caml_register_global)       │
│                                                 │
│ 2. Runtime Modules (embedded, unchanged):      │
│    local M = {}                                 │
│    function M.make(...) ... end                 │
│    local Array = M  -- Module variable          │
│                                                 │
│ 3. Global Wrapper Functions (auto-generated):  │
│    function caml_array_make(...)                │
│      return Array.make(...)                     │
│    end                                          │
│                                                 │
│ 4. Program Code (from IR):                     │
│    function __caml_init__()                     │
│      local v0 = caml_array_make(10, 0)          │
│      return v0                                  │
│    end                                          │
│    __caml_init__()                              │
└─────────────────────────────────────────────────┘
```

## Key Insights

### 1. Direct Embedding (Not Lua `require()`)

Generated standalone Lua programs are **self-contained** - they don't use `require()` or Lua's module system. Everything is embedded directly in one file.

**Evidence** from `_build/default/examples/hello_lua/hello.bc.lua`:
```lua
-- Runtime inlined directly
function caml_register_global(n, v, name) ... end

-- Program code directly follows
function __caml_init__()
  -- No require() calls anywhere
end
```

**Implication**: We can't use `package.loaded` or `require()`. We must:
1. Inline runtime module code directly
2. Store module in a local variable (e.g., `local Array = M`)
3. Generate global wrapper functions that call the local module

### 2. Reuse DEPS.md Infrastructure (But Not Its Output)

DEPS.md defines fragment-based linking with `--// Provides:` and `--// Requires:` headers. The infrastructure in `lua_link.ml` is valuable:
- `load_runtime_dir()` - loads all .lua files
- `parse_fragment_header()` - parses header directives
- `resolve_deps()` - topological sort with dependency resolution

**What we WON'T use**:
- `generate_loader()` - wraps fragments in `package.loaded["symbol"] = function()` (for modular loading)

**What we WILL use**:
- Fragment loading and parsing
- Dependency resolution
- **New directive**: `--// Export: function_name as global_name`

### 3. Module Variables Enable Wrappers

Runtime modules return `M` and can be stored in a local variable:

```lua
-- Embed array.lua code directly
local M = {}
function M.make(len, init)
  local arr = { tag = 0, [0] = len }
  for i = 1, len do arr[i] = init end
  return arr
end
function M.get(arr, idx) return arr[idx + 1] end
-- ... more functions
local Array = M  -- Store module in local variable
```

Now we can generate wrappers:
```lua
function caml_array_make(...) return Array.make(...) end
function caml_array_get(...) return Array.get(...) end
```

This is **zero-overhead**: just a function call forwarding.

### 4. Missing Primitives Get M.* Implementations

Some primitives don't exist in runtime modules yet (compare, ref, sys, weak). We'll add them to existing or new runtime modules using the same `M.*` pattern.

Example - `runtime/lua/compare.lua`:
```lua
local M = {}

function M.int_compare(a, b)
  if a < b then return -1
  elseif a > b then return 1
  else return 0 end
end

function M.float_compare(a, b)
  if a ~= a then return (b ~= b) and 0 or 1 end  -- NaN handling
  if b ~= b then return -1 end
  if a < b then return -1
  elseif a > b then return 1
  else return 0 end
end

return M
```

## Implementation Plan

### Master Checklist

- [ ] **Step 1**: Extend `lua_link.ml` to parse `--// Export:` directives
- [ ] **Step 2**: Implement module embedding (not `package.loaded` wrapping)
- [ ] **Step 3**: Implement global wrapper generation
- [ ] **Step 4**: Implement primitive usage tracking in code generator
- [ ] **Step 5**: Integrate linking in `lua_generate.ml`
- [ ] **Step 6**: Add missing runtime primitives (compare, ref, sys, weak)
- [ ] **Step 7**: Verify PRIMITIVES.md coverage
- [ ] **Step 8**: Test hello_lua example works
- [ ] **Step 9**: Verify all existing tests still pass

---

### Step 1: Extend lua_link.ml to Parse Export Directives

**File**: `compiler/lib-lua/lua_link.ml`

**Changes** (~60 lines):

1. Add `exports` field to `fragment` type:
```ocaml
type fragment =
  { name : string
  ; provides : string list
  ; requires : string list
  ; exports : (string * string) list  (* (module_func, global_name) *)
  ; code : string
  }
```

2. Add `parse_export` function (similar to `parse_provides`):
```ocaml
(* Parse export directive: "--// Export: make as caml_array_make" *)
let parse_export (line : string) : (string * string) option =
  let prefix = "--// Export:" in
  let prefix_len = String.length prefix in
  if String.length line >= prefix_len
     && String.equal (String.sub line ~pos:0 ~len:prefix_len) prefix
  then
    let rest = String.sub line ~pos:prefix_len ~len:(String.length line - prefix_len) in
    let trimmed = String.trim rest in
    (* Parse "make as caml_array_make" *)
    match String.split_on_char ~sep:' ' trimmed with
    | func :: "as" :: global_parts ->
        let global = String.concat ~sep:" " global_parts |> String.trim in
        if String.length global > 0
        then Some (String.trim func, global)
        else None
    | _ -> None
  else None
```

3. Update `parse_fragment_header` to collect exports:
```ocaml
let parse_fragment_header ~name (code : string) : fragment =
  let lines = String.split_on_char ~sep:'\n' code in
  let rec parse_headers provides requires exports version_ok = function
    | [] -> provides, requires, exports, version_ok
    | line :: rest ->
        let trimmed = String.trim line in
        (* Stop at first non-comment line *)
        if String.length trimmed > 0
           && not (String.starts_with ~prefix:"--" trimmed)
        then provides, requires, exports, version_ok
        (* Parse directives *)
        else if String.starts_with ~prefix:"--//" trimmed then
          let new_provides = ... in
          let new_requires = ... in
          let new_exports = match parse_export trimmed with
            | Some export -> export :: exports
            | None -> exports
          in
          let new_version_ok = ... in
          parse_headers new_provides new_requires new_exports new_version_ok rest
        else parse_headers provides requires exports version_ok rest
  in
  let provides, requires, exports, version_ok = parse_headers [] [] [] true lines in
  ...
  { name; provides; requires; exports = List.rev exports; code }
```

**Test**: Unit test that parses `--// Export: make as caml_array_make` correctly

**Files Modified**: `compiler/lib-lua/lua_link.ml` (~60 lines modified/added)

---

### Step 2: Implement Module Embedding

**File**: `compiler/lib-lua/lua_link.ml`

**New Function** (~40 lines):

```ocaml
(* Embed runtime module code directly (NOT wrapped in package.loaded) *)
let embed_runtime_module (frag : fragment) : string =
  let buf = Buffer.create 512 in

  (* Add comment header *)
  Buffer.add_string buf ("-- Runtime Module: " ^ frag.name ^ "\n");

  (* Embed module code directly *)
  Buffer.add_string buf frag.code;
  if not (String.ends_with ~suffix:"\n" frag.code) then
    Buffer.add_char buf '\n';

  (* Store module in local variable for wrappers to use *)
  let module_var = String.capitalize_ascii frag.name in
  Buffer.add_string buf ("local " ^ module_var ^ " = M\n");
  Buffer.add_char buf '\n';

  Buffer.contents buf
```

**Why this works**:
- Runtime modules are written as `local M = {}; ...; return M`
- When embedded, the `return M` executes and the value can be assigned to a variable
- We store it in a capitalized variable (e.g., `Array`, `MlBytes`) for clarity

**Files Modified**: `compiler/lib-lua/lua_link.ml` (~40 lines added)

---

### Step 3: Implement Global Wrapper Generation

**File**: `compiler/lib-lua/lua_link.ml`

**New Function** (~50 lines):

```ocaml
(* Generate global wrapper functions from exports *)
let generate_wrappers_for_fragment (frag : fragment) : string =
  if List.length frag.exports = 0 then ""
  else
    let buf = Buffer.create 256 in
    let module_var = String.capitalize_ascii frag.name in

    (* Add comment header *)
    Buffer.add_string buf ("-- Global Wrappers: " ^ frag.name ^ "\n");

    (* Generate wrapper for each export *)
    List.iter
      ~f:(fun (module_func, global_func) ->
        Printf.bprintf buf "function %s(...)\n" global_func;
        Printf.bprintf buf "  return %s.%s(...)\n" module_var module_func;
        Buffer.add_string buf "end\n")
      frag.exports;

    Buffer.add_char buf '\n';
    Buffer.contents buf
```

**Example Output**:
```lua
-- Global Wrappers: array
function caml_array_make(...)
  return Array.make(...)
end
function caml_array_get(...)
  return Array.get(...)
end
```

**Files Modified**: `compiler/lib-lua/lua_link.ml` (~50 lines added)

---

### Step 4: Implement Primitive Usage Tracking

**File**: `compiler/lib-lua/lua_generate.ml`

**New Function** (~60 lines):

Track which `caml_*` primitives are actually used in the program.

```ocaml
(* Collect all primitives used in a program *)
let collect_used_primitives (program : Code.program) : StringSet.t =
  let rec collect_expr acc = function
    | Code.Constant _ | Code.Pc _ | Code.Pv _ -> acc
    | Code.Apply { f; args; _ } ->
        let acc' = collect_expr acc (Code.Pv f) in
        List.fold_left ~f:collect_expr ~init:acc' args
    | Code.Block (_, arr, _, _) ->
        Array.fold_left ~f:(fun a v -> collect_expr a (Code.Pv v)) ~init:acc arr
    | Code.Field (v, _, _) -> collect_expr acc (Code.Pv v)
    | Code.Closure _ -> acc
    | Code.Prim (prim, args) ->
        let acc' = List.fold_left ~f:collect_expr ~init:acc args in
        (match prim with
         | Code.Extern name ->
             (* External primitive - add to set if starts with or will get caml_ prefix *)
             let prim_name =
               if String.starts_with ~prefix:"caml_" name then name
               else "caml_" ^ name
             in
             StringSet.add prim_name acc'
         | _ -> acc')
    | Code.Special _ -> acc
  in

  let collect_instr acc = function
    | Code.Let (_, expr) -> collect_expr acc expr
    | Code.Set_field (v, _, _, fv) ->
        collect_expr (collect_expr acc (Code.Pv v)) (Code.Pv fv)
    | Code.Offset_ref (v, _) -> collect_expr acc (Code.Pv v)
    | Code.Array_set (arr, idx, v) ->
        collect_expr (collect_expr (collect_expr acc (Code.Pv arr)) (Code.Pv idx)) (Code.Pv v)
  in

  Code.Addr.Map.fold
    (fun _ block acc ->
      List.fold_left ~f:collect_instr ~init:acc block.Code.body)
    program.Code.blocks
    StringSet.empty
```

**Files Modified**: `compiler/lib-lua/lua_generate.ml` (~60 lines added)

---

### Step 5: Integrate Linking in Code Generator

**File**: `compiler/lib-lua/lua_generate.ml`

**Modify `generate_standalone`** (~80 lines modified):

```ocaml
let generate_standalone ctx program =
  (* 1. Track which primitives are used *)
  let used_primitives = collect_used_primitives program in

  (* 2. Load runtime modules *)
  let runtime_dir = "runtime/lua" in
  let fragments = Lua_link.load_runtime_dir runtime_dir in

  (* 3. Build mapping: global_name -> fragment *)
  let global_to_fragment =
    List.fold_left
      ~f:(fun map frag ->
        List.fold_left
          ~f:(fun m (_, global_name) -> StringMap.add global_name frag m)
          ~init:map
          frag.exports)
      ~init:StringMap.empty
      fragments
  in

  (* 4. Find fragments that provide used primitives *)
  let needed_fragments =
    StringSet.fold
      (fun prim_name acc ->
        match StringMap.find_opt prim_name global_to_fragment with
        | Some frag ->
            if not (List.mem ~eq:(fun a b -> String.equal a.Lua_link.name b.Lua_link.name) frag acc)
            then frag :: acc
            else acc
        | None ->
            (* Primitive not found - might be inline or missing *)
            acc)
      used_primitives
      []
  in

  (* 5. Resolve dependencies between needed fragments *)
  let state =
    List.fold_left
      ~f:Lua_link.add_fragment
      ~init:(Lua_link.init ())
      fragments
  in
  let required_symbols =
    List.fold_left
      ~f:(fun acc frag -> frag.Lua_link.provides @ acc)
      ~init:[]
      needed_fragments
  in
  let sorted_fragment_names, _missing = Lua_link.resolve_deps state required_symbols in
  let sorted_fragments =
    List.filter_map
      ~f:(fun name ->
        List.find_opt (fun f -> String.equal f.Lua_link.name name) needed_fragments)
      sorted_fragment_names
  in

  (* 6. Generate code in order:
     - Inline runtime (caml_register_global)
     - Runtime modules (embedded)
     - Global wrappers
     - Program code *)
  let inline_runtime = generate_inline_runtime () in
  let embedded_modules =
    List.map ~f:Lua_link.embed_runtime_module sorted_fragments
    |> List.map ~f:(fun code -> L.Comment code)
  in
  let wrappers =
    List.map ~f:Lua_link.generate_wrappers_for_fragment sorted_fragments
    |> List.filter ~f:(fun s -> String.length s > 0)
    |> List.map ~f:(fun code -> L.Comment code)
  in
  let program_code = generate_module_init ctx program in

  inline_runtime @ [ L.Comment "" ] @ embedded_modules @ wrappers @ [ L.Comment "" ] @ program_code
```

**Files Modified**: `compiler/lib-lua/lua_generate.ml` (~80 lines modified)

---

### Step 6: Add Missing Runtime Primitives

Add runtime modules for primitives that don't exist yet.

#### 6a. Compare Primitives

**File**: `runtime/lua/compare.lua` (new file, ~50 lines)

```lua
-- Compare primitives for OCaml values
-- Provides int and float comparison with OCaml semantics

local M = {}

function M.int_compare(a, b)
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

function M.float_compare(a, b)
  -- Handle NaN: NaN != NaN in OCaml
  if a ~= a then
    -- a is NaN
    if b ~= b then
      return 0  -- Both NaN
    else
      return 1  -- NaN > any number
    end
  end
  if b ~= b then
    return -1  -- any number < NaN
  end

  -- Normal comparison
  if a < b then
    return -1
  elseif a > b then
    return 1
  else
    return 0
  end
end

return M
```

**Exports to add**:
```lua
--// Export: int_compare as caml_int_compare
--// Export: int_compare as caml_int32_compare
--// Export: int_compare as caml_nativeint_compare
--// Export: float_compare as caml_float_compare
```

**Note**: int32 and nativeint use same implementation as int (Lua numbers are 64-bit floats or integers depending on version).

#### 6b. Reference Primitives

**File**: `runtime/lua/core.lua` (add to existing, ~10 lines)

```lua
-- Add to existing M functions:
function M.ref_set(ref, value)
  -- References are {tag=0, [1]=value}
  ref[1] = value
end
```

**Export to add**:
```lua
--// Export: ref_set as caml_ref_set
```

#### 6c. System Primitives (Stubs)

**File**: `runtime/lua/sys.lua` (new file, ~30 lines)

```lua
-- System primitives (stubs for now)
-- File descriptors not fully supported yet

local M = {}

function M.sys_open(path, flags)
  error("caml_sys_open: not yet implemented in lua_of_ocaml")
end

function M.sys_close(fd)
  error("caml_sys_close: not yet implemented in lua_of_ocaml")
end

return M
```

**Exports**:
```lua
--// Export: sys_open as caml_sys_open
--// Export: sys_close as caml_sys_close
```

#### 6d. Weak Reference Primitives (Stubs)

**File**: `runtime/lua/weak.lua` (new file, ~40 lines)

```lua
-- Weak reference primitives using Lua's weak tables

local M = {}

function M.create(size)
  -- Create weak array with __mode = "v" (values are weak)
  local arr = { tag = 0, [0] = size }
  for i = 1, size do
    arr[i] = nil
  end
  setmetatable(arr, { __mode = "v" })
  return arr
end

function M.set(weak_arr, idx, value)
  local len = weak_arr[0]
  if idx < 0 or idx >= len then
    error("weak array index out of bounds")
  end
  weak_arr[idx + 1] = value
end

function M.get(weak_arr, idx)
  local len = weak_arr[0]
  if idx < 0 or idx >= len then
    error("weak array index out of bounds")
  end
  return weak_arr[idx + 1]
end

return M
```

**Exports**:
```lua
--// Export: create as caml_weak_create
--// Export: set as caml_weak_set
--// Export: get as caml_weak_get
```

**Files Created**:
- `runtime/lua/compare.lua` (~50 lines)
- `runtime/lua/sys.lua` (~30 lines)
- `runtime/lua/weak.lua` (~40 lines)

**Files Modified**:
- `runtime/lua/core.lua` (~10 lines added)

---

### Step 7: Verify PRIMITIVES.md Coverage

Create a test that ensures all 70 primitives from PRIMITIVES.md are covered.

**File**: `compiler/tests-lua/test_primitive_coverage.ml` (new file, ~100 lines)

```ocaml
(* Test that all primitives from PRIMITIVES.md are covered *)

open Js_of_ocaml_compiler

module Lua_link = struct
  include Lua_of_ocaml_compiler__Lua_link
end

(* List of all 70 primitives from PRIMITIVES.md *)
let all_primitives = [
  (* Global/Registry *)
  "caml_register_global";

  (* Integer Comparison *)
  "caml_int_compare";
  "caml_int32_compare";
  "caml_nativeint_compare";

  (* Float *)
  "caml_float_compare";

  (* String *)
  "caml_string_compare";
  "caml_string_get";
  "caml_string_set";
  "caml_string_unsafe_set";
  "caml_create_string";
  "caml_blit_string";

  (* ... all 70 primitives ... *)
]

let%expect_test "all primitives covered" =
  (* Load runtime modules *)
  let runtime_dir = "runtime/lua" in
  let fragments = Lua_link.load_runtime_dir runtime_dir in

  (* Build set of all exported globals *)
  let exported_globals =
    List.fold_left
      (fun set frag ->
        List.fold_left
          (fun s (_, global) -> StringSet.add global s)
          set
          frag.exports)
      StringSet.empty
      fragments
  in

  (* Check each primitive *)
  let missing =
    List.filter
      (fun prim -> not (StringSet.mem prim exported_globals))
      all_primitives
  in

  (* Report results *)
  if List.length missing = 0 then
    print_endline "All 70 primitives covered!"
  else begin
    Printf.printf "Missing %d primitives:\n" (List.length missing);
    List.iter (fun p -> Printf.printf "  - %s\n" p) missing
  end;

  [%expect {| All 70 primitives covered! |}]
```

**Files Created**: `compiler/tests-lua/test_primitive_coverage.ml` (~100 lines)

---

### Step 8: Test hello_lua Example

Verify the hello_lua example works end-to-end.

**Test Command**:
```bash
dune build examples/hello_lua/hello.bc.lua
lua examples/hello_lua/hello.bc.lua
```

**Expected Output**:
```
Hello from OCaml compiled to Lua!
```

**Debug if it fails**:
1. Check generated code structure:
   ```bash
   cat _build/default/examples/hello_lua/hello.bc.lua | head -100
   ```
2. Look for:
   - Inline runtime present
   - Runtime modules embedded
   - Global wrappers generated
   - Program code present
3. Run with Lua error messages:
   ```bash
   lua _build/default/examples/hello_lua/hello.bc.lua 2>&1 | head -50
   ```

---

### Step 9: Verify All Existing Tests Pass

**Test Command**:
```bash
dune build @runtest
```

**Expected**: All 35 existing Lua tests pass with no failures.

**If tests fail**:
1. Check which tests are failing
2. Examine test expectations (`.expected` files)
3. Verify generated code structure matches expectations
4. Use `dune promote` if new output is correct

---

## Success Criteria

- [ ] All 70 primitives from PRIMITIVES.md are covered (Step 7 test passes)
- [ ] hello_lua example runs successfully (Step 8)
- [ ] All 35 existing Lua tests pass (Step 9)
- [ ] Zero code duplication (runtime modules embedded as-is)
- [ ] No heavy refactoring (runtime modules keep M.* pattern)
- [ ] Generated code is self-contained (no external dependencies)
- [ ] `dune build compiler/lib-lua` succeeds with zero warnings

## Files Modified/Created Summary

**Modified**:
- `compiler/lib-lua/lua_link.ml` (~150 lines added)
- `compiler/lib-lua/lua_generate.ml` (~140 lines added/modified)
- `runtime/lua/core.lua` (~10 lines added for ref_set)

**Created**:
- `runtime/lua/compare.lua` (~50 lines)
- `runtime/lua/sys.lua` (~30 lines)
- `runtime/lua/weak.lua` (~40 lines)
- `compiler/tests-lua/test_primitive_coverage.ml` (~100 lines)
- `LINKING.md` (this file)

**Total**: ~520 lines of new code (plus comprehensive documentation)

## Commit Strategy

1. `feat(lua/link): Add Export directive parsing for primitive linking`
2. `feat(lua/link): Add module embedding and global wrapper generation`
3. `feat(lua): Track primitive usage in code generator`
4. `feat(lua): Integrate runtime linking in code generation`
5. `feat(lua/runtime): Add compare primitives module`
6. `feat(lua/runtime): Add sys and weak primitive stubs`
7. `feat(lua/runtime): Add ref_set primitive to core`
8. `test(lua): Add primitive coverage verification test`
9. `docs(lua): Add LINKING.md with implementation strategy`

## References

- DEPS.md - Fragment-based module linking (inspiration)
- PRIMITIVES.md - Complete primitive catalog
- LUA.md Task 14.3 - High-level requirements
- `compiler/lib-lua/lua_link.ml` - Existing linking infrastructure
- `compiler/lib-lua/lua_generate.ml` - Code generator
- `_build/default/examples/hello_lua/hello.bc.lua` - Generated code structure
