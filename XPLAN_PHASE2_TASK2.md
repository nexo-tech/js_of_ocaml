# Phase 2 Task 2.2: JavaScript Code Generation Study

**Date**: 2025-10-14
**Status**: Complete

---

## Code Generation Pipeline Overview

**Main File**: `compiler/lib/generate.ml` (2,431 lines)

### Key Functions

1. **`compile_program`** (line 2386)
   - Entry point for code generation
   - Calls `compile_closure` for the main program block

2. **`compile_closure`** (line 2319)
   - Compiles a closure/function
   - Builds control flow graph
   - Calls `compile_branch` for each branch

3. **`compile_branch`** (line 2245)
   - Compiles a single branch/block
   - Handles control flow (loops, breaks, continues)
   - Calls `compile_argument_passing` to pass arguments

4. **`compile_argument_passing`** (line 2238)
   - Passes arguments to block parameters
   - Calls `parallel_renaming` to generate assignments

5. **`parallel_renaming`** (line 981) ⭐ **CRITICAL**
   - Generates variable declarations for parameters
   - Handles dependency ordering
   - Ensures parameters are set BEFORE block body executes

---

## Critical Function: `parallel_renaming`

This is THE KEY function that makes JS work correctly!

### Purpose
Assigns argument values to parameter variables in correct order, handling dependencies.

### Algorithm

```ocaml
let parallel_renaming ctx loc back_edge params args continuation queue =
  let l = visit_all params args in
  let queue, before, renaming, _ =
    List.fold_left l ~init:(queue, [], [], Code.Var.Set.empty)
      ~f:(fun (queue, before, renaming, seen) (y, x) ->
        let ((_, deps_x), cx, locx), queue = Q.access_queue_loc ~ctx queue loc x in
        let seen' = Code.Var.Set.add y seen in
        if not Code.Var.Set.(is_empty (inter seen deps_x))
        then (* Handle circular dependency with temp variable *)
          let before = (J.variable_declaration [J.V x, (cx, locx)], locx) :: before in
          let renaming = (y, J.EVar (J.V x)) :: renaming in
          queue, before, renaming, seen'
        else (* No dependency conflict *)
          let renaming = (y, cx) :: renaming in
          queue, before, renaming, seen')
  in
  let renaming =
    if back_edge
    then List.map renaming ~f:(fun (t, e) ->
            J.Expression_statement (J.EBin (J.Eq, J.EVar (J.V t), e)), loc)
    else List.map renaming ~f:(fun (t, e) ->
            J.variable_declaration [J.V t, (e, loc)], loc)
  in
  let never, code = continuation queue in
  never, List.rev_append before (List.rev_append renaming code)
```

### Key Steps

1. **Compute dependency order**: `visit_all params args`
   - Returns list of (param, arg) pairs in safe evaluation order

2. **Generate assignments**: For each (param, arg):
   - Get the value of arg: `cx`
   - Check for circular dependencies
   - If no conflict: `renaming = (param, value) :: renaming`
   - If conflict: Use temp variable

3. **Generate variable declarations**:
   - Not back_edge: `var param = value;`
   - Back_edge: `param = value;` (assignment, not declaration)

4. **Prepend to continuation code**:
   ```ocaml
   List.rev_append before (List.rev_append renaming code)
   ```
   - Parameter assignments come BEFORE the block body!

### Example Generated Code

For Printf closure expecting format string and integer:

```javascript
// parallel_renaming generates:
var format_str = "Value: %d\n";  // Parameter declaration
var arg_value = 42;               // Parameter declaration

// Then continuation code (block body):
result = caml_format_int(format_str, arg_value);
return result;
```

**THE KEY**: Parameters are declared and assigned BEFORE the body executes, so all variables are available!

---

## Closure Compilation

### From `translate_expr` (line 1488):

```ocaml
| Closure (args, ((pc, _) as cont), cloc) ->
    let loc = source_location cloc in
    let fv = Addr.Map.find pc ctx.freevars in
    let clo = compile_closure ctx cont cloc in
    let clo =
      J.EFun
        ( None
        , J.fun_ (List.map args ~f:(fun v -> J.V v))
                 (Js_simpl.function_body clo)
                 loc )
    in
    let* () = info (Const, fv) in
    return (clo, [])
```

### Process

1. Get free variables: `fv = Addr.Map.find pc ctx.freevars`
2. Compile closure body: `compile_closure ctx cont cloc`
3. Wrap in JavaScript function:
   ```javascript
   function(arg1, arg2, ...) {
     // closure body from compile_closure
   }
   ```

4. The closure body includes variable declarations from `parallel_renaming`!

---

## Printf Closure Creation Pattern

### In Generated JS (from Task 2.1)

```javascript
function A(g, f, e, h, d, c, b){
  // Create closure that captures: g, f, e, c, b (format string!)
  return function(d){
    return a(g, [4, f, caml_call2(c, b, d)], e);
    // c = caml_format_int
    // b = format string (CAPTURED!)
    // d = argument (42)
  };
}
```

### How `parallel_renaming` Makes This Work

When the returned closure is called:
1. `parallel_renaming` is invoked to pass argument `d` (42) to the closure
2. It generates: `var d = 42;`
3. THEN the closure body executes
4. Inside closure, `caml_call2(c, b, d)` has access to:
   - `c` (caml_format_int) - from outer scope
   - `b` (format string) - from outer scope (CAPTURED!)
   - `d` (42) - from parameter declaration

**Result**: `caml_format_int("Value: %d\n", 42)` is called with BOTH arguments!

---

## Control Flow Structure

### Branch Compilation
```
compile_closure
  ↓
build_graph (create CFG)
  ↓
compile_branch
  ↓
compile_argument_passing
  ↓
parallel_renaming (declare parameters)
  ↓
continuation (block body)
```

### Argument Flow

```
Closure call: f(arg)
  ↓
apply_fun (check arity)
  ↓
compile_branch (target block)
  ↓
compile_argument_passing
  ↓
parallel_renaming
  ↓ generates:
var param = arg;  // Parameter declaration
// ... block body with param available
```

---

## Key Insights

### 1. Parameter Declaration Order
JS generator ensures parameters are declared BEFORE block execution through `parallel_renaming`.

### 2. Dependency Handling
The `visit_all` function computes a topological order to handle parameter dependencies:
- `var x = y; var y = z;` ❌ (y undefined)
- `var y = z; var x = y;` ✅ (correct order)

### 3. Closure Variable Capture
JavaScript's lexical scoping automatically captures outer variables:
```javascript
function outer(format_str) {
  return function(arg) {
    caml_format_int(format_str, arg);  // format_str captured!
  };
}
```

### 4. No Special Handling Needed
Because parameters are declared as proper JavaScript variables, closures naturally capture them - no special "capture table" needed!

---

## Comparison Point for Lua

**Question for Lua study**: Does `compiler/lib-lua/lua_generate.ml` have equivalent of `parallel_renaming`?

**Expected**: Yes, should generate parameter assignments before block body
**If missing**: This would explain why Printf fails - parameters not declared before use!

**Next**: Compare with Lua's `lua_generate.ml` to find the discrepancy.

---

## Summary

**JS Code Generation Success Factors**:
1. ✅ `parallel_renaming` declares parameters before block execution
2. ✅ Proper dependency ordering prevents undefined variables
3. ✅ JavaScript lexical scoping captures closure variables automatically
4. ✅ Arguments flow correctly through CPS chains

**For Lua to work**: Must replicate this parameter declaration pattern!
