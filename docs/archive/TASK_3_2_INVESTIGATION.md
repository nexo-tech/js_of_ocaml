# Task 3.2: Fix Dispatch Start - INVESTIGATION

## Date: 2025-10-13

## Summary

Implemented back-edge filtering using reachability analysis, but discovered that **address-based dispatch is fundamentally insufficient for Printf**. Neither starting at entry block (800) nor back-edge blocks (484) works. Printf requires **value-based dispatch** like js_of_ocaml uses.

## Implementation

### What Was Implemented

1. **Reachability Analysis** (lines 889-908)
   - `compute_reachable_blocks`: Computes forward-reachable blocks from entry
   - Used to distinguish back-edges from external branches

2. **Enhanced find_entry_initializer** (lines 910-998)
   - Filters out back-edges (blocks reachable from entry)
   - Keeps only true initializers (blocks outside loop)
   - Falls back to first candidate if all are back-edges

3. **Updated Dispatch Start Logic** (lines 1771-1790)
   - Uses enhanced find_entry_initializer
   - Starts at true initializer if found
   - Falls back to entry if no true initializer

### Test Results

**Printf with start at 484 (fallback)**:
```bash
$ lua test_printf_v3.lua
lua: test_printf_v3.lua:22482: attempt to index field 'v270' (a nil value)
```
❌ v270 nil error (block 484 needs block 482 to run first)

**Printf with start at 800 (entry)**:
```bash
$ lua test_simple_printf.lua  # Task 2.8 version
lua: test_simple_printf.lua:1318: attempt to index local 's' (a nil value)
```
❌ v247 nil error (block 601 needs block 475 to run first)

## Key Findings

### 1. All Candidate Blocks Are Back-Edges

Debug output for block 800:
```
DEBUG find_entry_initializer: Looking for blocks branching to 800
  Reachable from entry: 60 blocks
  Found candidate: block 474 branches to 800 with 3 args
  ...
  Found candidate: block 484 branches to 800 with 3 args
  Block 484 is BACK-EDGE (reachable from entry) - filtering out
  Block 483 is BACK-EDGE (reachable from entry) - filtering out
  ...
  Block 474 is BACK-EDGE (reachable from entry) - filtering out
  Result: No true initializers, using first candidate 484 as fallback
```

**All blocks (474-476, 481, 483, 484) are reachable from entry (800)**, meaning they're all inside the loop. There are NO external initializer blocks.

### 2. Catch-22 Situation

- **Start at 800 (entry)**: Skips block 475, v247 never initialized, block 601 fails
- **Start at 484 (first candidate)**: Skips block 482, v270 never initialized, block 484 itself fails

Both approaches fail because blocks have interdependencies that can't be satisfied by picking a single starting point.

### 3. Address-Based Dispatch is Insufficient

Our `while _next_block` approach treats all blocks equally - just labels to jump to. But Printf blocks have **ordering dependencies**:
- Block 482 must run before 484 (sets v270)
- Block 475 must run before 601 (sets v247)

These dependencies arise from Printf's CPS algorithm structure, not from simple control flow.

### 4. How JS Handles This

js_of_ocaml generates:
```js
for(;;) {
  if(typeof fmt === "number") return;
  switch(fmt[0]) {    ← Value-based dispatch!
    case 0: ...       ← Direct code, not block jumps
    case 1: ...
    ...
  }
}
```

**Key differences**:
- No block addresses or _next_block
- Switch on format string tag (value-based)
- Cases contain actual code, not jumps to other blocks
- Natural control flow ensures correct execution order

## Why Our Approach Fails

**Address-based dispatch** (our current approach):
```lua
local _next_block = ???  ← Which block to start at?
while true do
  if _next_block == 462 then ... end
  if _next_block == 484 then v270 = ... end  ← Needs v270 set!
  if _next_block == 601 then v247[3] ...end  ← Needs v247 set!
end
```

**Problem**: No single starting `_next_block` value satisfies all block dependencies.

**Value-based dispatch** (JS approach):
```lua
while true do
  local tag = fmt[1]  ← Get tag from data
  if tag == 0 then ... end
  if tag == 11 then
    v247 = fmt[3]     ← Set v247 naturally
  end
  ...
  if tag == X then
    use v247[3]       ← v247 already set if we got here
  end
end
```

**Solution**: Variables are set naturally as part of processing each case, in the correct order determined by the data (format string), not by picking a start address.

## Why Data-Driven Detection Doesn't Trigger

Our `detect_dispatch_mode` (Task 2.5.4) only triggers for entry blocks with **Switch terminators**.

Printf entry block (800) has **Cond** terminator (decision tree), not Switch. The IR optimization passes convert large switches into balanced decision trees (Cond chains) for efficiency.

The actual "switch" on v343[1] happens in block 462 with nested Cond checks.

## Root Cause (Final)

**Printf requires value-based dispatch**, not address-based. The IR structure (Cond decision trees) doesn't match our detection criteria (Switch terminators), so we fall back to address-based dispatch which can't handle Printf's block interdependencies.

## Proposed Solutions

### Option A: Extend Data-Driven Detection for Cond Patterns

Detect large if-else chains (Cond decision trees) and treat them like Switch:
- Entry block has Cond terminator
- Successor blocks also have Cond on same variable
- Pattern matches switch-like behavior
- Generate value-based dispatch

**Pros**: Matches JS behavior
**Cons**: Complex detection logic, may have false positives

### Option B: Use js_of_ocaml's Code Generator Directly

Instead of reimplementing closure compilation, use js_of_ocaml's Generate module:
- Generate JavaScript AST
- Transform JS AST to Lua AST
- Preserves correct control flow

**Pros**: Guaranteed correct behavior
**Cons**: Large refactor, AST transformation complexity

### Option C: Fix Block Compilation Order

Instead of using address-based dispatch, compile blocks in dependency order:
- Analyze block dependencies (which blocks must run before others)
- Topologically sort blocks
- Generate linear code without loops/jumps

**Pros**: Simpler than full data-driven dispatch
**Cons**: Doesn't handle actual loops well

### Option D: Special-Case Printf Pattern

Detect Printf-specific patterns and handle specially:
- Recognize CamlinternalFormatBasics closures
- Generate custom code for Printf dispatch
- Quick hack to make progress

**Pros**: Gets Printf working quickly
**Cons**: Not general, technical debt

## Recommendation

**Option A** (extend data-driven detection) is the correct long-term fix. It makes Lua match JS behavior and handles all similar patterns, not just Printf.

**Implementation Plan**:
1. Enhance `detect_dispatch_mode` to recognize Cond decision tree patterns
2. When entry block has Cond that checks a variable (like v343[1])
3. And successor blocks continue the same pattern
4. Treat as value-based dispatch
5. Generate switch-like if-elseif chain on the dispatch variable
6. This gives us JS-like behavior with correct variable initialization order

## Next Steps

Create **Task 3.3**: Implement Cond-based data-driven dispatch detection
- Extend detect_dispatch_mode
- Recognize decision tree patterns
- Generate value-based dispatch for Printf
- Test and verify

This is the REAL fix for Printf - matching js_of_ocaml's value-based dispatch approach.

## Files Modified

- `compiler/lib-lua/lua_generate.ml`: ~100 lines (reachability + enhanced detection)
- `TASK_3_2_INVESTIGATION.md`: This document

## What to Commit

Task 3.2 investigation proves address-based dispatch is insufficient. Commit the reachability analysis code (it's correct and useful), but mark as incomplete pending proper data-driven dispatch implementation.
