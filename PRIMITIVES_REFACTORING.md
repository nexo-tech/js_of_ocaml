# Lua Runtime Primitives Refactoring Plan

## Master Checklist

### Phase 1: Refactor Core Infrastructure (Est: 4 hours)
- [x] Task 1.1: Update linker to parse `--Provides:` comments (1 hour)
- [x] Task 1.2: Remove `--// Export:` and `core.register()` parsing (30 min)
- [x] Task 1.3: Update `embed_runtime_module` to handle direct functions (1 hour)
- [x] Task 1.4: Update wrapper generation for new structure (1 hour)
- [x] Task 1.5: Write tests for new linker infrastructure (30 min)

### Phase 2: Refactor Core Modules (Est: 6 hours)
- [x] Task 2.1: Refactor `core.lua` - base primitives (1 hour + tests)
- [x] Task 2.2: Refactor `compare.lua` - comparison primitives (1 hour + tests)
- [x] Task 2.3: Refactor `mlBytes.lua` - bytes primitives (1 hour + tests)
- [x] Task 2.4: Refactor `array.lua` - array primitives (1 hour + tests)
- [x] Task 2.5: Refactor `ints.lua` - integer primitives (1 hour + tests)
- [x] Task 2.6: Refactor `float.lua` - float primitives (1 hour + tests)

### Phase 3: Refactor Standard Library Modules (Est: 8 hours)
- [ ] Task 3.1: Refactor `buffer.lua` - buffer primitives (45 min + tests)
- [ ] Task 3.2: Refactor `format.lua` - format primitives (45 min + tests)
- [ ] Task 3.3: Refactor `hash.lua` - hashing primitives (45 min + tests)
- [ ] Task 3.4: Refactor `hashtbl.lua` - hashtable primitives (45 min + tests)
- [ ] Task 3.5: Refactor `lazy.lua` - lazy evaluation primitives (45 min + tests)
- [ ] Task 3.6: Refactor `lexing.lua` - lexer primitives (45 min + tests)
- [ ] Task 3.7: Refactor `list.lua` - list primitives (45 min + tests)
- [ ] Task 3.8: Refactor `map.lua` - map primitives (45 min + tests)
- [ ] Task 3.9: Refactor `option.lua` - option primitives (30 min + tests)
- [ ] Task 3.10: Refactor `parsing.lua` - parser primitives (45 min + tests)
- [ ] Task 3.11: Refactor `queue.lua` - queue primitives (30 min + tests)
- [ ] Task 3.12: Refactor `result.lua` - result primitives (30 min + tests)
- [ ] Task 3.13: Refactor `set.lua` - set primitives (45 min + tests)
- [ ] Task 3.14: Refactor `stack.lua` - stack primitives (30 min + tests)

### Phase 4: Refactor System & I/O Modules (Est: 4 hours)
- [ ] Task 4.1: Refactor `sys.lua` - system primitives (1 hour + tests)
- [ ] Task 4.2: Refactor `io.lua` - I/O primitives (1 hour + tests)
- [ ] Task 4.3: Refactor `filename.lua` - filename primitives (45 min + tests)
- [ ] Task 4.4: Refactor `stream.lua` - stream primitives (45 min + tests)

### Phase 5: Refactor Special Modules (Est: 4 hours)
- [ ] Task 5.1: Refactor `obj.lua` - object primitives (1 hour + tests)
- [ ] Task 5.2: Refactor `gc.lua` - GC primitives (45 min + tests)
- [ ] Task 5.3: Refactor `weak.lua` - weak reference primitives (45 min + tests)
- [ ] Task 5.4: Refactor `effect.lua` - effect handler primitives (1 hour + tests)
- [ ] Task 5.5: Refactor `fun.lua` - function primitives (30 min + tests)

### Phase 6: Refactor Advanced Modules (Est: 3 hours)
- [ ] Task 6.1: Refactor `marshal.lua` - marshaling primitives (1 hour + tests)
- [ ] Task 6.2: Refactor `marshal_header.lua` - marshal headers (30 min + tests)
- [ ] Task 6.3: Refactor `marshal_io.lua` - marshal I/O (45 min + tests)
- [ ] Task 6.4: Refactor `digest.lua` - digest primitives (45 min + tests)
- [ ] Task 6.5: Refactor `bigarray.lua` - bigarray primitives (1 hour + tests)

### Phase 7: Verification & Integration (Est: 3 hours)
- [ ] Task 7.1: Run all unit tests and fix failures (1 hour)
- [ ] Task 7.2: Build hello_lua example and verify runtime (30 min)
- [ ] Task 7.3: Run compiler test suite (30 min)
- [ ] Task 7.4: Benchmark performance vs old implementation (30 min)
- [ ] Task 7.5: Update documentation (30 min)

**Total Estimated Time: 32 hours**

---

## Refactoring Pattern

### Current Structure (WRONG)
```lua
--// Provides: array
--// Requires: core

local core = require("core")
local M = {}

function M.make(len, init)
  -- implementation
end

function M.get(arr, idx)
  -- implementation
end

-- Export functions
core.register("caml_array_make", M.make)
core.register("caml_array_get", M.get)
--// Export: make as caml_array_make
--// Export: get as caml_array_get

return M
```

### Target Structure (CORRECT - like js_of_ocaml)
```lua
--Provides: caml_array_make
--Requires: caml_make_vect
function caml_array_make(len, init)
  -- implementation
end

--Provides: caml_array_get
function caml_array_get(arr, idx)
  -- implementation
end

--Provides: caml_make_vect
function caml_make_vect(len, init)
  return caml_array_make(len, init)
end
```

### Key Changes
1. **Function Naming**: `M.make` → `function caml_array_make`
2. **Provides Comments**: `--// Provides: array` → `--Provides: caml_array_make` (one per function)
3. **Requires Comments**: `--// Requires: core` → `--Requires: caml_make_vect` (list actual function deps)
4. **Remove Module Wrapping**: No `local M = {}`, no `return M`
5. **Remove Exports**: No `core.register()`, no `--// Export:` directives
6. **Direct Dependencies**: Call `caml_other_function()` directly, not `OtherModule.function()`

---

## Phase 1: Refactor Core Infrastructure

### Task 1.1: Update linker to parse `--Provides:` comments

**File**: `compiler/lib-lua/lua_link.ml`

**Changes**:
1. Update `parse_provides` to parse `--Provides:` (not `--// Provides:`)
2. Change from parsing module-level provides to function-level provides
3. Each `--Provides:` line declares ONE function name

**Before**:
```ocaml
let parse_provides (line : string) : string list =
  let prefix = "--// Provides:" in
  (* Returns list of symbols from one line *)
```

**After**:
```ocaml
let parse_provides (line : string) : string option =
  let prefix = "--Provides:" in
  (* Returns single symbol name or None *)
  if String.starts_with ~prefix line then
    let rest = String.sub line ~pos:(String.length prefix) ~len:(...) in
    let symbol = String.trim rest in
    if String.length symbol > 0 then Some symbol else None
  else None
```

**Implementation**:
- Parse each line for `--Provides: symbol_name`
- Extract symbol name after colon
- Trim whitespace
- Return `Some symbol` or `None`

**Testing**:
```ocaml
(* Test in compiler/tests-lua/test_linker.ml *)
let%expect_test "parse provides comment" =
  let result = parse_provides "--Provides: caml_array_make" in
  print_endline (match result with Some s -> s | None -> "None");
  [%expect {| caml_array_make |}]
```

**Success Criteria**:
- [ ] Parses `--Provides: caml_foo` correctly
- [ ] Ignores `--Provides:` with no symbol
- [ ] Returns None for non-Provides lines
- [ ] Test passes

---

### Task 1.2: Remove `--// Export:` and `core.register()` parsing

**File**: `compiler/lib-lua/lua_link.ml`

**Changes**:
1. Remove `parse_export` function
2. Remove export parsing from `parse_fragment_header`
3. Remove `exports : (string * string) list` field from `fragment` type
4. Remove export-based primitive lookup

**Before**:
```ocaml
type fragment =
  { name : string
  ; provides : string list
  ; requires : string list
  ; exports : (string * string) list
  ; code : string
  }
```

**After**:
```ocaml
type fragment =
  { name : string
  ; provides : string list  (* Now list of caml_* function names *)
  ; requires : string list  (* Now list of caml_* function deps *)
  ; code : string
  }
```

**Implementation**:
- Delete `parse_export` function (lines 68-92)
- Remove `exports` from fragment type
- Remove export parsing from `parse_fragment_header`
- Update `find_primitive_implementation` to only use naming convention

**Testing**:
```ocaml
let%expect_test "fragment has no exports field" =
  let frag = { name = "test"; provides = ["caml_foo"]; requires = []; code = "" } in
  print_endline frag.name;
  [%expect {| test |}]
```

**Success Criteria**:
- [ ] `fragment` type has no `exports` field
- [ ] No `parse_export` function exists
- [ ] All code compiles without errors
- [ ] Tests pass

---

### Task 1.3: Update `embed_runtime_module` to handle direct functions

**File**: `compiler/lib-lua/lua_link.ml`

**Changes**:
1. Remove module variable creation (`local Array = M`)
2. Remove `return M` stripping logic
3. Just embed code directly with header comment

**Before**:
```ocaml
let embed_runtime_module (frag : fragment) : string =
  let buf = Buffer.create 512 in
  Buffer.add_string buf ("-- Runtime Module: " ^ frag.name ^ "\n");
  Buffer.add_string buf frag.code;
  (* Strip return M, create local var *)
  let module_var = String.capitalize_ascii frag.name in
  Buffer.add_string buf ("local " ^ module_var ^ " = M\n");
  Buffer.contents buf
```

**After**:
```ocaml
let embed_runtime_code (frag : fragment) : string =
  let buf = Buffer.create 512 in
  Buffer.add_string buf ("-- Runtime: " ^ frag.name ^ "\n");
  Buffer.add_string buf frag.code;
  if not (String.ends_with ~suffix:"\n" frag.code)
  then Buffer.add_char buf '\n';
  Buffer.add_char buf '\n';
  Buffer.contents buf
```

**Implementation**:
- Simplify function to just add header comment
- Embed code as-is (no manipulation needed)
- Ensure trailing newlines for readability

**Testing**:
```ocaml
let%expect_test "embed runtime code" =
  let frag = {
    name = "test";
    provides = ["caml_test"];
    requires = [];
    code = "--Provides: caml_test\nfunction caml_test() end"
  } in
  print_endline (embed_runtime_code frag);
  [%expect {|
    -- Runtime: test
    --Provides: caml_test
    function caml_test() end
  |}]
```

**Success Criteria**:
- [ ] No module variable creation
- [ ] Code embedded verbatim
- [ ] Proper formatting with newlines
- [ ] Test passes

---

### Task 1.4: Update wrapper generation for new structure

**File**: `compiler/lib-lua/lua_link.ml`

**Changes**:
1. Remove wrapper generation entirely - functions are already global with caml_ prefix
2. Update `generate_wrappers` to return empty string

**Before**:
```ocaml
let generate_wrappers (used_primitives : StringSet.t) (fragments : fragment list) : string =
  (* Generate wrappers like: function caml_array_make(...) return Array.make(...) end *)
  ...
```

**After**:
```ocaml
(* No wrappers needed - primitives are already global functions with caml_ prefix *)
(* This function kept for compatibility but returns empty string *)
let generate_wrappers (_used_primitives : StringSet.t) (_fragments : fragment list) : string =
  ""
```

**Rationale**:
- With refactored runtime, all functions are already `function caml_*(...)`
- No module wrapping means no need for `Module.func → caml_func` wrappers
- Linker just needs to include the right fragment files

**Implementation**:
- Replace function body with `""`
- Keep function signature for compatibility
- Update callsites to not output wrappers section

**Testing**:
```ocaml
let%expect_test "no wrappers generated" =
  let primitives = StringSet.of_list ["caml_array_make"] in
  let fragments = [...] in
  let result = generate_wrappers primitives fragments in
  print_endline (if result = "" then "empty" else "not empty");
  [%expect {| empty |}]
```

**Success Criteria**:
- [ ] Function returns empty string
- [ ] No wrappers in generated code
- [ ] Compilation still works
- [ ] Test passes

---

### Task 1.5: Write tests for new linker infrastructure

**File**: `compiler/tests-lua/test_linker.ml` (create new file)

**Implementation**:
Create comprehensive test suite for refactored linker:

```ocaml
open Js_of_ocaml_compiler

module Lua_link = struct
  include Lua_of_ocaml_compiler__Lua_link
end

let%expect_test "parse provides comment - single function" =
  let result = Lua_link.parse_provides "--Provides: caml_array_make" in
  print_endline (match result with Some s -> s | None -> "None");
  [%expect {| caml_array_make |}]

let%expect_test "parse provides comment - whitespace handling" =
  let result = Lua_link.parse_provides "--Provides:   caml_test_func  " in
  print_endline (match result with Some s -> s | None -> "None");
  [%expect {| caml_test_func |}]

let%expect_test "parse provides comment - not provides line" =
  let result = Lua_link.parse_provides "-- Regular comment" in
  print_endline (match result with Some s -> s | None -> "None");
  [%expect {| None |}]

let%expect_test "parse requires comment - single dependency" =
  let result = Lua_link.parse_requires "--Requires: caml_make_vect" in
  print_endline (String.concat ", " result);
  [%expect {| caml_make_vect |}]

let%expect_test "parse requires comment - multiple dependencies" =
  let result = Lua_link.parse_requires "--Requires: caml_foo, caml_bar" in
  print_endline (String.concat ", " result);
  [%expect {| caml_foo, caml_bar |}]

let%expect_test "load fragment - simple function" =
  (* Create temp file *)
  let temp_file = Filename.temp_file "test_frag" ".lua" in
  let oc = open_out temp_file in
  output_string oc "--Provides: caml_test\nfunction caml_test() end\n";
  close_out oc;

  let frag = Lua_link.load_runtime_file temp_file in
  print_endline ("name: " ^ frag.name);
  print_endline ("provides: " ^ String.concat ", " frag.provides);
  Sys.remove temp_file;
  [%expect {|
    name: test_frag
    provides: caml_test
  |}]

let%expect_test "embed runtime code - no modifications" =
  let frag = {
    Lua_link.name = "array";
    provides = ["caml_array_make"; "caml_array_get"];
    requires = [];
    code = "--Provides: caml_array_make\nfunction caml_array_make(n, v) end"
  } in
  let result = Lua_link.embed_runtime_code frag in
  print_endline result;
  [%expect {|
    -- Runtime: array
    --Provides: caml_array_make
    function caml_array_make(n, v) end
  |}]

let%expect_test "no wrappers generated" =
  let primitives = Stdlib.StringSet.of_list ["caml_array_make"; "caml_array_get"] in
  let fragments = [] in
  let result = Lua_link.generate_wrappers primitives fragments in
  print_endline (if result = "" then "EMPTY" else result);
  [%expect {| EMPTY |}]
```

**Success Criteria**:
- [ ] All tests pass
- [ ] Covers parse_provides
- [ ] Covers parse_requires
- [ ] Covers load_runtime_file
- [ ] Covers embed_runtime_code
- [ ] Covers generate_wrappers

---

## Phase 2: Refactor Core Modules

### Task 2.1: Refactor `core.lua` - base primitives

**File**: `runtime/lua/core.lua`

**Before** (excerpt):
```lua
--// Provides: core
local M = {}

function M.register(name, func)
  _G[name] = func
end

function M.global_object()
  return _G
end

return M
```

**After**:
```lua
-- Lua_of_ocaml runtime support
-- http://www.ocsigen.org/js_of_ocaml/
-- ...license...

--Provides: caml_register_global
--Requires: caml_named_values
function caml_register_global(name, value)
  if not caml_named_values then
    caml_named_values = {}
  end
  caml_named_values[name] = value
end

--Provides: caml_get_global_data
function caml_get_global_data()
  return _G.caml_global_data or {}
end

--Provides: caml_named_value
--Requires: caml_named_values
function caml_named_value(name)
  return caml_named_values[name]
end

-- Global table for named values
caml_named_values = {}
```

**Changes**:
1. Remove `local M = {}` and `return M`
2. Convert `M.register` to `function caml_register_global`
3. Convert `M.global_object` to `function caml_get_global_data`
4. Add `--Provides:` comment before each function
5. Add `--Requires:` where functions depend on others
6. Keep global state as module-level variables

**Testing** (`runtime/lua/test_core.lua`):
```lua
-- Test caml_register_global
caml_register_global("test_value", 42)
assert(caml_named_value("test_value") == 42)

-- Test caml_get_global_data
local data = caml_get_global_data()
assert(type(data) == "table")

print("PASS: core primitives")
```

**Success Criteria**:
- [ ] No module wrapping (no `local M`)
- [ ] All functions have `caml_` prefix
- [ ] All functions have `--Provides:` comments
- [ ] Dependencies listed in `--Requires:`
- [ ] Test file passes
- [ ] Compiles without errors

---

### Task 2.2: Refactor `compare.lua` - comparison primitives

**File**: `runtime/lua/compare.lua`

**Current Issues**:
- Uses `M.int_compare` instead of `caml_int_compare`
- Has `--// Export:` directives
- Module-wrapped

**Target Structure**:
```lua
-- Lua_of_ocaml runtime support
-- ...license...

--Provides: caml_int_compare
function caml_int_compare(a, b)
  if a < b then return -1
  elseif a > b then return 1
  else return 0
  end
end

--Provides: caml_float_compare
function caml_float_compare(a, b)
  if a < b then return -1
  elseif a > b then return 1
  elseif a == b then return 0
  else
    -- NaN handling
    if a ~= a then
      if b ~= b then return 0 else return -1 end
    else
      return 1
    end
  end
end

--Provides: caml_string_compare
function caml_string_compare(s1, s2)
  if s1 < s2 then return -1
  elseif s1 > s2 then return 1
  else return 0
  end
end

--Provides: caml_compare
--Requires: caml_int_compare caml_float_compare caml_string_compare
function caml_compare(a, b)
  local ta, tb = type(a), type(b)

  if ta ~= tb then
    return caml_int_compare(ta, tb)
  end

  if ta == "number" then
    return caml_float_compare(a, b)
  elseif ta == "string" then
    return caml_string_compare(a, b)
  elseif ta == "table" then
    -- Structural comparison for OCaml blocks
    -- ...implementation...
  end

  return 0
end

--Provides: caml_equal
--Requires: caml_compare
function caml_equal(a, b)
  return caml_compare(a, b) == 0
end

--Provides: caml_notequal
--Requires: caml_equal
function caml_notequal(a, b)
  return not caml_equal(a, b)
end

--Provides: caml_lessthan
--Requires: caml_compare
function caml_lessthan(a, b)
  return caml_compare(a, b) < 0
end

--Provides: caml_lessequal
--Requires: caml_compare
function caml_lessequal(a, b)
  return caml_compare(a, b) <= 0
end

--Provides: caml_greaterthan
--Requires: caml_compare
function caml_greaterthan(a, b)
  return caml_compare(a, b) > 0
end

--Provides: caml_greaterequal
--Requires: caml_compare
function caml_greaterequal(a, b)
  return caml_compare(a, b) >= 0
end
```

**Testing** (`runtime/lua/test_compare.lua`):
```lua
-- Test integer comparison
assert(caml_int_compare(1, 2) == -1)
assert(caml_int_compare(2, 1) == 1)
assert(caml_int_compare(5, 5) == 0)

-- Test float comparison
assert(caml_float_compare(1.5, 2.5) == -1)
assert(caml_float_compare(2.5, 1.5) == 1)
assert(caml_float_compare(1.5, 1.5) == 0)

-- Test NaN handling
local nan = 0/0
assert(caml_float_compare(nan, nan) == 0)
assert(caml_float_compare(nan, 1.0) == -1)

-- Test equality operators
assert(caml_equal(5, 5))
assert(not caml_equal(5, 6))
assert(caml_notequal(5, 6))

print("PASS: compare primitives")
```

**Success Criteria**:
- [ ] All functions have `caml_` prefix
- [ ] `--Provides:` before each function
- [ ] `--Requires:` lists dependencies
- [ ] No `--// Export:` directives
- [ ] No `core.register()` calls
- [ ] Test passes

---

### Task 2.3: Refactor `mlBytes.lua` - bytes primitives

**File**: `runtime/lua/mlBytes.lua`

**Key Functions to Refactor**:
- `M.create` → `caml_create_bytes`
- `M.get` → `caml_bytes_get`
- `M.set` → `caml_bytes_set`
- `M.of_string` → `caml_bytes_of_string`
- `M.to_string` → `caml_bytes_to_string`
- `M.concat` → `caml_bytes_concat`
- `M.sub` → `caml_bytes_sub`
- `M.blit` → `caml_blit_bytes`
- `M.fill` → `caml_fill_bytes`

**Pattern**:
```lua
--Provides: caml_create_bytes
function caml_create_bytes(len)
  return string.rep("\0", len)
end

--Provides: caml_bytes_get
function caml_bytes_get(s, i)
  return string.byte(s, i + 1)
end

--Provides: caml_bytes_set
function caml_bytes_set(s, i, c)
  return string.sub(s, 1, i) .. string.char(c) .. string.sub(s, i + 2)
end
```

**Testing** (`runtime/lua/test_mlBytes.lua`):
```lua
local b = caml_create_bytes(10)
assert(#b == 10)

caml_bytes_set(b, 0, 65) -- 'A'
assert(caml_bytes_get(b, 0) == 65)

local s = caml_bytes_to_string(b)
assert(type(s) == "string")

print("PASS: mlBytes primitives")
```

**Success Criteria**:
- [ ] ~15 functions refactored with caml_ prefix
- [ ] All have `--Provides:` comments
- [ ] Test passes
- [ ] No module wrapping

---

### Tasks 2.4-2.6: Array, Ints, Float

Follow same pattern as 2.1-2.3:
1. Remove module wrapping
2. Rename all functions to `caml_*` prefix
3. Add `--Provides:` comments
4. Add `--Requires:` for dependencies
5. Remove `--// Export:` and `core.register()`
6. Write test file for each module
7. Verify all tests pass

**Time**: 1 hour per module (implementation + testing)

---

## Phase 3-6: Remaining Modules

Each task follows the same pattern:
1. Identify all functions in the module
2. Rename to `caml_modulename_function` pattern
3. Add `--Provides:` comment before each
4. Add `--Requires:` for any dependencies
5. Remove all module infrastructure
6. Write test file
7. Verify tests pass

**Standard Test Template**:
```lua
-- Test module_name primitives
dofile("runtime/lua/module_name.lua")

-- Test function1
local result = caml_module_function1(args)
assert(result == expected, "function1 failed")

-- Test function2
...

print("PASS: module_name primitives")
```

---

## Phase 7: Verification & Integration

### Task 7.1: Run all unit tests and fix failures

**Commands**:
```bash
# Run all Lua runtime tests
for test in runtime/lua/test_*.lua; do
  echo "Running $test..."
  lua "$test" || echo "FAILED: $test"
done

# Run compiler test suite
dune build @runtest-lua
```

**Fix any failures**:
- Missing `--Provides:` comments
- Wrong function names
- Broken dependencies

### Task 7.2: Build hello_lua and verify

```bash
dune build examples/hello_lua/hello.bc.lua
lua _build/default/examples/hello_lua/hello.bc.lua
```

Expected output: "Hello, World!"

### Task 7.3: Run compiler test suite

```bash
dune build @check
dune build @all
```

All tests should pass with no warnings.

### Task 7.4: Benchmark performance

Compare old vs new implementation:
- Runtime loading time
- Generated file size
- Execution speed

### Task 7.5: Update documentation

Update `RUNTIME.md` with new structure:
- Document `--Provides:` comment syntax
- Document `--Requires:` syntax
- Remove references to module wrapping
- Add examples of refactored code

---

## Success Criteria (Overall)

- [ ] All 36 runtime Lua files refactored
- [ ] All functions have `caml_` prefix
- [ ] All functions have `--Provides:` comments
- [ ] No module wrapping (`local M = {}`)
- [ ] No `--// Export:` directives
- [ ] No `core.register()` calls
- [ ] All unit tests pass
- [ ] hello_lua example runs successfully
- [ ] Compiler test suite passes
- [ ] Zero compilation warnings
- [ ] Documentation updated

---

## Notes

- Each phase builds on the previous one
- Don't skip tests - they catch regressions
- Follow js_of_ocaml patterns exactly
- Maximum 300 lines per task
- Commit after each completed task
- Update master checklist after each task
