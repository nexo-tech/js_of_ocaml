# Task 2.6: Printf Entry Block Analysis

## Date: 2025-10-12

## Root Cause Identified

### The Problem

Block 484 is the closure's entry block, but it uses variable v270 which is never initialized before it runs.

**Control Flow**:
```
Entry → Block 484:  Uses v270 (ERROR: nil)
Block 482 → Block 484:  Sets v270, then may jump to 484 (WORKS)
```

### Detailed Analysis

**Block 482** (line 22513):
```lua
_V.v270 = _V.v343[2]  -- SETS v270
_V.v271 = _V.v270[1] or 0
_V.v272 = 0 == _V.v271
if _V.v272 then
  _next_block = 483
else
  _next_block = 484  -- Can jump to 484
end
```

**Block 484** (line 22552):
```lua
_V.v278 = _V.v343[3]
_V.v279 = _V.v270[2]  -- USES v270 (nil if entry!)
_V.v280 = _V.v279[2]
```

**The Issue**:
- Block 484 is reachable by TWO paths:
  1. **Entry path**: v343 set from block_args, v270 is nil ❌
  2. **Block 482 path**: v343 and v270 both set ✅

- Block 484 assumes v270 is set, but entry path doesn't set it

### JavaScript Comparison

JavaScript doesn't have this problem because it uses a different structure:

```javascript
function v(counter, af, ag, ah){
  var i = af, h = ag, f = ah;  // Immediate assignment
  l:
  for(;;){  // Loop with switch
    if(typeof f === "number") return caml_call1(i, h);
    switch(f[0]){  // Switch on f's tag
      case 0: break a;
      case 1: break b;
      // ...
    }
  }
}
```

Key differences:
1. JS assigns parameters to locals immediately: `f = ah`
2. JS uses `for(;;)` loop with `switch(f[0])` - data-driven dispatch
3. JS doesn't have "block 484" - it has switch cases driven by data
4. All variables are assigned before entering the loop

### The Real Issue: Dispatch Model Mismatch

**js_of_ocaml approach**:
- Data-driven: Switch on values in variables
- Variables assigned from params before loop
- Control flow determined by data, not block addresses

**lua_of_ocaml current approach**:
- Address-driven: Dispatch on block numbers
- Entry block specified as address (484)
- Control flow determined by block addresses

This mismatch causes the problem: We're trying to use block addresses as entry points, but the IR was designed for data-driven dispatch!

## Solution Options

### Option 1: Start at a Different Block ❌ Won't Work

We can't start at block 482 because:
- Block 482 also uses v343 (which we set)
- Block 482 would work, but it's not the designated entry in the IR
- Changing entry blocks arbitrarily breaks the IR's semantics

### Option 2: Initialize v270 Before Dispatch Loop ✅ CORRECT FIX

Since block 484 needs v270, and v270 is computed from v343:
```lua
_V.v270 = _V.v343[2]  -- Initialize before dispatch
```

This matches what block 482 does, so if we start at 484, v270 will be set correctly.

**Implementation**:
1. Detect variables USED by entry block but not in its parameters
2. Trace back to see how they're computed
3. Initialize them before the dispatch loop

But this is complex and fragile!

### Option 3: Use Data-Driven Dispatch ✅ BETTER FIX

Change our dispatch model to match JS:
1. Entry block parameters contain the DATA, not just identifiers
2. Use the DATA to determine which block to run (like JS switch)
3. Don't hardcode entry block address

This would require significant refactoring of the dispatch logic.

### Option 4: Fix at IR Level ❌ Not Our Responsibility

The IR might be wrong - block 484 shouldn't be the entry if it has unmet dependencies. But we can't change the OCaml compiler.

### Option 5: Run Block 482 Before Block 484 ⚠️ HACK

Insert code to run block 482's initialization before jumping to 484:
```lua
-- Before dispatch loop
if entry_block == 484 then
  _V.v270 = _V.v343[2]  -- Do what block 482 does
end
```

This is a hack but might work for Printf specifically.

## Recommended Fix: Option 2 (Initialize Dependencies)

Implement a dependency analyzer:

```ocaml
(* In compile_blocks_with_labels *)
let entry_block_deps =
  find_entry_block_dependencies ctx program start_addr entry_args
in
let entry_dep_stmts =
  generate_dependency_initializations ctx entry_block_deps
in

(* Return order *)
hoist_stmts @ param_copy_stmts @ entry_arg_stmts @ entry_dep_stmts @ dispatch_loop
```

**Algorithm**:
1. Analyze entry block's body
2. Find variables USED but not in parameters
3. Trace how they're computed from parameters
4. Generate initialization code

**For our case**:
- Entry block 484 uses v270
- v270 is not a parameter
- Trace: v270 = v343[2] (from block 482)
- Generate: `_V.v270 = _V.v343[2]` before dispatch

## Alternative: Fall-Through Pattern

Looking at the JS more carefully, I notice it has a pattern:
```javascript
case 18:
  var s = f[1];  // Declares variable
  if(0 === s[0]){
    // ...
  }
  else{
    // ...
  }
  break;
```

Variables are declared IN the switch cases, not before the loop. This suggests maybe our entry block initialization is missing similar in-block declarations?

But no - in Lua we hoist everything to avoid the 200 local limit. So we can't do in-block declarations.

## Conclusion

The root cause is a **dispatch model mismatch**:
- IR designed for data-driven dispatch (JS switch on values)
- Lua implementation uses address-driven dispatch (block numbers)

The fix is to **initialize entry block dependencies** before the dispatch loop. For block 484, we need to initialize v270 = v343[2] before entering the loop.

This is complex to implement generically but would be the correct solution.

## Next Steps

1. Implement dependency analysis for entry blocks
2. Generate initialization for variables used but not in parameters
3. Test with Printf
4. Verify with other complex closures

OR (simpler):

1. Special-case Printf pattern: If entry block immediately uses v343[2], initialize v270 = v343[2]
2. This is a hack but would unblock Printf quickly
3. Then implement proper solution later

## Files to Modify

- `compiler/lib-lua/lua_generate.ml`: Add dependency analysis
- Function: `compile_blocks_with_labels`
- Location: Before dispatch loop generation
