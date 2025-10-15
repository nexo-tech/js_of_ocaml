# Task 5.3k.1 - Printf Float Fix Progress Report
**Date**: 2025-10-15
**Status**: MAJOR PROGRESS - 2 of 3 issues fixed, 1 remaining

## Issues Fixed ✅

### Issue 1: Compilation Bug (FIXED)
**Problem**: `Sys_error("Invalid argument")` when compiling any file
**Root Cause**: Called `Parse_bytecode.from_exe` on `.cmo` files
**Fix**: Call `from_channel` first to detect file type (commit 11757e37)

### Issue 2: Data-Driven Dispatch - Dispatcher Block Duplication (FIXED)
**Problem**: Dispatcher block (592) generated twice causing infinite loop
**Root Cause**:
- Entry block (801) has Cond → true=593, false=592 (dispatcher)
- Dispatcher inline in entry logic (body only, no terminator)
- ALSO generated as continuation block (body + terminator)
- Terminator is Switch setting `_next_block` to switch case blocks
- Switch cases execute inline, not via _next_block → infinite loop

**Fix** (this commit):
1. Exclude dispatcher block from continuation dispatch
2. Exclude entry block from continuation dispatch
3. Exclude true-branch block from continuation dispatch
4. Handle back-edges to entry specially (no _next_block assignment)

**Code Changes** (compiler/lib-lua/lua_generate.ml):
- Lines 2169-2194: Create `inline_blocks` set (entry, true branch, dispatcher)
- Line 2202: Exclude inline_blocks from continuation_addrs
- Lines 2247-2265: Handle back-edges in continuation blocks (update params, no _next_block)

**Result**:
- Block 592 no longer has dispatch case ✓
- Block 801 (entry) no longer referenced via _next_block ✓
- Block 593 (true branch) excluded ✓
- Continuation blocks (596, 597, 757, 758, 766, 767, 817) properly generated ✓

## Issue 3: Address-Based Dispatch - Same Problem (REMAINING) ⏳

**Problem**: Blocks 246, 248, 383, 448, 827, 828 assigned but no dispatch cases
**Evidence**:
```
Block 246: 1 assignment, 0 dispatch cases
Block 248: 1 assignment, 0 dispatch cases
Block 383: 18 assignments, 0 dispatch cases
Block 448: 28 assignments, 0 dispatch cases
Block 827: 1 assignment, 0 dispatch cases
Block 828: 1 assignment, 0 dispatch cases
```

**Hypothesis**: Address-based dispatch has similar issue:
- Some blocks are inline or special
- But get referenced via _next_block
- Not included in dispatch loop

**Next Steps**:
1. Find which closure contains blocks 246, 248, 383, 448, 827, 828
2. Determine why they're not in dispatch loop
3. Apply similar fix (exclude inline/special blocks)

## Test Status

**Before Fix**:
```bash
timeout 5 lua test_float.lua  # TIMEOUT (infinite loop)
```

**After Issue 1 + 2 Fix**:
```bash
timeout 5 lua /tmp/test_float_FINAL.lua  # TIMEOUT (but different blocks)
```

**Progress**: Fixed data-driven dispatch (entry 801), but address-based still broken.

## Files Modified

- `compiler/bin-lua_of_ocaml/compile.ml` - Compilation fix ✅
- `compiler/lib-lua/lua_generate.ml` - Data-driven dispatch fixes ✅

## Commits This Session

1. `3c9b4c85` - Test signature fixes
2. `e2d7c829` - Debug infrastructure
3. `fc9f7db0`, `cc3300f6`, `e0078264` - Documentation
4. `11757e37` - Compilation bug fix
5. **(WIP)** - Data-driven dispatcher exclusion + back-edge fix

## Key Insights

1. **Blocks DO exist!** My initial hypothesis was wrong - blocks 594-602 exist in IR
2. **Dispatcher block is special** - generated inline AND as continuation (wrong!)
3. **Entry block needs special handling** - back-edges don't use _next_block
4. **Same pattern in address-based dispatch** - need to find and fix similar issues
5. **Debug infrastructure crucial** - Printf.eprintf + clean rebuild required for output

## Next Actions

1. Add debug for address-based dispatch to find blocks 246, 248, 383, 448, 827, 828
2. Determine why they're missing from dispatch
3. Apply similar exclusion/back-edge logic
4. Test until no more missing blocks
5. Update XPLAN.md Task 5.3k.1 status
6. Run full test suite (`just test-lua`)
