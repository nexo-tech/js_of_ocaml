# XPLAN Phase 3 Task 3.3: Exact Discrepancy in lua_generate.ml

## Status: ✅ COMPLETE

## Objective
Identify the exact code location and logic that needs to be fixed to prevent variable shadowing

## Root Cause: Variable Shadowing in Nested Closures

### The Problem

**File**: `compiler/lib-lua/lua_generate.ml`
**Function**: `setup_hoisted_variables` (lines 1666-1732)
**Critical Line**: 1701-1705

```ocaml
let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params in
let init_stmts =
  StringSet.elements vars_to_init
  |> List.map ~f:(fun var ->
      L.Assign ([ L.Dot (L.Ident var_table_name, var) ], [ L.Nil ]))
in
```

This code initializes ALL hoisted variables (except entry block params) to `nil`, including:
- ✅ Local variables (should be initialized)
- ❌ **Free variables** (should NOT be initialized - should be captured from parent!)

### Understanding Variable Types

The function `collect_block_variables` (lines 1162-1250) already distinguishes:

1. **Defined Variables** (lines 1208-1217):
   - Variables assigned in THIS closure: `Let (var, _)` or `Assign (var, _)`
   - Example: `v314`, `v315` in nested Printf closure
   - **Should be initialized to nil**

2. **Free Variables** (lines 1240-1243):
   ```ocaml
   (* Free variables = USED - DEFINED - PARAMETERS *)
   let free_vars =
     Code.Var.Set.diff (Code.Var.Set.diff used_vars defined_vars) entry_params
   ```
   - Variables USED but not DEFINED in this closure
   - Example: `v21` (stdout), `v268` (format function) in nested Printf closure
   - **Should NOT be initialized - captured from parent via __index!**

3. **Entry Block Parameters** (already excluded at line 1701):
   - Function parameters like `v274`
   - Assigned from function arguments

### Current Bug

**When `ctx.inherit_var_table = true` (nested closure):**

Current code (lines 1707-1717):
```ocaml
if ctx.inherit_var_table then
  (* Task 3.3.4: Create new _V table with metatable for lexical scope (like JS) *)
  [ L.Comment (Printf.sprintf "Hoisted variables (%d total, using own _V table for closure scope)" total_vars)
  ; L.Local ([ "parent_V" ], Some [ L.Ident var_table_name ])
  ; L.Local ([ var_table_name ], Some [
      L.Call (L.Ident "setmetatable",
        [ L.Table []
        ; L.Table [ L.Rec_field ("__index", L.Ident "parent_V") ]
        ])
    ])
  ] @ init_stmts  (* ❌ BUG: init_stmts includes FREE variables! *)
```

This generates:
```lua
local parent_V = _V
local _V = setmetatable({}, {__index = parent_V})
_V.v21 = nil    -- ❌ BUG: Shadows parent's stdout!
_V.v268 = nil   -- ❌ BUG: Shadows parent's format function!
_V.v274 = nil   -- ✅ OK: Function parameter (will be assigned)
_V.v314 = nil   -- ✅ OK: Local variable
_V.v315 = nil   -- ✅ OK: Local variable
```

When the closure tries to access `_V.v268` or `_V.v21`:
1. Lua looks in child's `_V` table first
2. Finds `nil` value (the shadowing initialization)
3. Never checks parent via __index metatable
4. Returns `nil` instead of parent's value
5. Printf fails: `caml_format_int(nil, arg)` → crash

### The Fix

**Change line 1701** from:
```ocaml
let vars_to_init = StringSet.diff all_hoisted_vars entry_block_params in
```

**To** (when `ctx.inherit_var_table = true`):
```ocaml
let vars_to_init =
  if ctx.inherit_var_table then
    (* In nested closures: only initialize DEFINED vars, not FREE vars *)
    StringSet.diff (StringSet.diff all_hoisted_vars free_vars) entry_block_params
  else
    (* In top-level: initialize all (no parent to capture from) *)
    StringSet.diff all_hoisted_vars entry_block_params
in
```

But we need access to `free_vars`. Currently `collect_block_variables` returns only the union. We need to either:

**Option A**: Modify `collect_block_variables` to return `(defined_vars, free_vars)` tuple
**Option B**: Recompute `free_vars` in `setup_hoisted_variables` using the same logic

**Recommendation**: Option A - cleaner, more efficient

### Modified Function Signature

Change `collect_block_variables` from:
```ocaml
and collect_block_variables ctx program start_addr =
  (* ... *)
  let all_vars = Code.Var.Set.union defined_vars free_vars in
  Code.Var.Set.fold
    (fun var acc -> StringSet.add (var_name ctx var) acc)
    all_vars
    StringSet.empty
```

To:
```ocaml
and collect_block_variables ctx program start_addr =
  (* ... *)
  let defined_names =
    Code.Var.Set.fold
      (fun var acc -> StringSet.add (var_name ctx var) acc)
      defined_vars
      StringSet.empty
  in
  let free_names =
    Code.Var.Set.fold
      (fun var acc -> StringSet.add (var_name ctx var) acc)
      free_vars
      StringSet.empty
  in
  (defined_names, free_names)
```

### Expected Output After Fix

With the fix, nested closures will generate:
```lua
local parent_V = _V
local _V = setmetatable({}, {__index = parent_V})
-- Only initialize DEFINED variables, NOT free variables
_V.v274 = nil   -- ✅ Function parameter (will be assigned)
_V.v314 = nil   -- ✅ Local variable
_V.v315 = nil   -- ✅ Local variable
-- v21 and v268 NOT initialized - captured from parent_V via __index
```

Now when accessing `_V.v268` or `_V.v21`:
1. Lua looks in child's `_V` table
2. Doesn't find it (not initialized)
3. Checks `parent_V` via __index metatable
4. Finds parent's value
5. Printf succeeds!

## JavaScript Comparison

JavaScript doesn't have this problem because of lexical scoping:

```javascript
function outer() {
  var captured_var = "value";  // Captured variable

  return function inner(own_param) {
    var local_var;  // Local variable
    // Uses captured_var directly - NO re-declaration
    use(captured_var, own_param, local_var);
  };
}
```

The `parallel_renaming` function (generate.ml:981) only declares NEW variables, never re-declares captured ones.

## Implementation Details

Files to modify:
1. `compiler/lib-lua/lua_generate.ml`
   - Line 1162: `collect_block_variables` - return `(defined, free)` tuple
   - Line 1667: `setup_hoisted_variables` - use separate sets
   - Line 1701: Exclude free_vars when `ctx.inherit_var_table = true`
   - Line 1991: Update call site in `compile_func_decl`

Update all call sites of `collect_block_variables` to handle tuple return.

## Verification

After fix, test with:
```bash
just quick-test /tmp/test4.ml
```

Expected: Printf with %d should work without hanging or crashing.

## Next Steps

See Phase 3 Task 3.7: Design and implement the fix
