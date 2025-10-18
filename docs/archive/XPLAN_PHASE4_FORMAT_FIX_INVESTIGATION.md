# XPLAN Phase 4: Format String Fix - IR Investigation Results

## Status: 🔍 ROOT CAUSE CONFIRMED

## Investigation Summary

Added debug output to `lua_generate.ml` to analyze switch compilation and discovered the exact nature of the bug.

## Key Findings

### Switch Compilation Analysis

**Three large switches found in test_simple.ml bytecode:**

1. **v9046**: 15 cases, **NO args**, NO string constants in target blocks
2. **v3027**: 14 cases, mostly NO args (except cases 8-10, 13)
3. **v9505**: 14 cases, **HAS args** for cases 8-10, 13

### Pattern Discovery

**Working Pattern (v9505)**:
```
Group 1: addr=809, args=[v2358], indices=[8]
  Block params: [v9468]
  Block has NO string constant loads
```
- Format strings ARE passed as **variables** (v2358, v2359, v2360, v2361)
- Target block receives them as **parameters** (v9468)
- NO constant loads needed - format strings come from args!

**Broken Pattern (v9046)**:
```
Group 0: addr=714, args=[], indices=[0, 2]
  Block params: []
  Block has NO string constant loads
```
- **args=[] (EMPTY!)**  ← THE BUG
- No block params
- No string constant loads
- Format strings completely missing!

## Root Cause

**The IR switch for convert_int (v9046) has empty args when it should pass format string variables.**

The format string variables (like `v102 = "%d"`, `v103 = "%+d"`) exist in the code, but the switch doesn't pass them as arguments to the target blocks.

## Why This Happens

### Expected IR Pattern
```ocaml
(* Before switch: format strings defined *)
let v102 = "%d" in
let v103 = "%+d" in
(* Switch should pass these as args *)
Switch(iconv, [|
  (0, jump_to_block_with_args [v102]);  (* case 0 -> use "%d" *)
  (1, jump_to_block_with_args [v103]);  (* case 1 -> use "%+d" *)
  ...
|])
```

### Actual IR Pattern (Broken)
```ocaml
(* Format strings exist somewhere *)
let v102 = "%d" in
let v103 = "%+d" in
(* But switch doesn't pass them! *)
Switch(iconv, [|
  (0, jump_to_block_with_args []);  (* args EMPTY! *)
  (1, jump_to_block_with_args []);  (* args EMPTY! *)
  ...
|])
```

## Comparison with JS

**JavaScript (Working)**:
```javascript
function convert_int(iconv, n){
  switch(iconv){
    case 0: var a = Z; break;   // Load format string
    case 1: var a = _; break;   // Different format string
  }
  return caml_format_int(a, n);  // Use after switch
}
```

**Lua (Current - Broken)**:
```lua
if v260 == 0 then
  v314 = caml_format_int(v316, v259)  -- v316 is nil!
elseif v260 == 1 then
  v314 = caml_format_int(v316, v259)  -- Same v316 (still nil!)
end
```

**Lua (Should Be)**:
```lua
if v260 == 0 then
  v316 = v102  -- Load "%d"
  v314 = caml_format_int(v316, v259)
elseif v260 == 1 then
  v316 = v103  -- Load "%+d"
  v314 = caml_format_int(v316, v259)
end
```

## Fix Options

### Option A: Fix IR Generation (Upstream Fix)
Modify the OCaml IR generator to ensure switch cases pass format string variables as arguments.

**Pros**: Correct fix at the right level
**Cons**: Requires deep understanding of js_of_ocaml IR generation, may affect JS output

### Option B: Fix Switch Compilation (Lua Generator Fix)
Modify `lua_generate.ml` to detect when switch args are empty but format strings are needed, and generate the load instructions inline.

**Pros**: Contained to Lua backend, doesn't affect other backends
**Cons**: Requires hardcoding knowledge of Printf internals, not general

### Option C: Workaround with Phi Nodes
Transform switches with empty args into phi-node style switches with explicit argument passing.

**Pros**: More general than Option B
**Cons**: Complex transformation, may have edge cases

## Recommended Approach

**Short-term**: Implement Option B - Generate format string loads inline when switch args are empty
**Long-term**: Investigate Option A - Fix IR generation to pass format strings as args

## Implementation Plan for Option B

1. Detect convert_int-style switches:
   - Large number of cases (14-16)
   - Empty args
   - Target blocks call formatting primitives

2. For each case, generate assignment:
   ```ocaml
   (* case 0 *)
   _V.v316 = _V.v102  -- "%d"
   (* case 1 *)
   _V.v316 = _V.v103  -- "%+d"
   ```

3. Mapping from case index to format string variable:
   - Analyze program to find format string constants (v102, v103, etc.)
   - Map case indices to appropriate constants
   - OR hardcode mapping for stdlib Printf (quick fix)

## Questions for Further Investigation

1. **Why does v9505 have args but v9046 doesn't?**
   - Different optimization level?
   - Different function structure?
   - Bug in specific IR transformation?

2. **Where are format strings defined?**
   - Need to trace back to find v102, v103, etc. definitions
   - Understand relationship between case index and format string

3. **Is this specific to convert_int or general problem?**
   - Check other Printf functions (convert_float, etc.)
   - Test with different format specifiers

## Next Steps

1. ✅ Debug output added and analyzed
2. ✅ Root cause confirmed (empty args in switch)
3. ⬅️ **Current**: Decide on fix approach
4. Implement fix (Option B recommended for quick progress)
5. Test with Printf %d
6. Expand fix to cover all format functions
7. Update XPLAN.md and commit

## Files Modified

- `compiler/lib-lua/lua_generate.ml`: Added debug output (now removed)

## Test Case

```bash
echo 'let () = Printf.printf "%d\n" 42' > /tmp/test.ml
just quick-test /tmp/test.ml
# Expected: 42
# Actual: Error (v316 is nil)
```
