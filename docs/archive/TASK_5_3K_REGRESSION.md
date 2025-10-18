# Task 5.3k.1 - Regression Analysis
**Date**: 2025-10-15
**Status**: MAJOR PROGRESS but introduced REGRESSION

## What Was Fixed ✅

### All Dispatch Blocks Now Have Cases
- ✅ Blocks 246, 248, 383, 448, 827, 828 all have dispatch cases
- ✅ No missing blocks (verified with check_dispatch script)
- ✅ Continuation dispatch ends with `break` (no empty else)

### Root Causes Fixed
1. **Switch cases CAN be continuation blocks** (line 2208-2215)
   - OLD: Excluded all switch_case_addrs from continuation
   - NEW: Only exclude inline_blocks (entry, true branch, dispatcher)
   - Why: Switch cases like 383 are BOTH switch cases AND continuation targets

2. **True branch blocks not collected** (line 1933-1951)
   - OLD: Only collected from switch_cases
   - NEW: Also collect from true_addr
   - Why: True branch's Cond may reference blocks like 246/248

3. **Empty continuation else** (line 2281-2285)
   - OLD: Returned [] for empty case list → empty else
   - NEW: Return [ L.Break ] → proper loop exit
   - Why: Prevents infinite loop when no case matches

## Regression Introduced ❌

### Symptom
```bash
# BEFORE changes (commit 26da1b2e)
just quick-test test_int.ml  # Works, prints "42"
just quick-test test_float.ml  # Hangs (expected - not yet fixed)

# AFTER changes (current)
just quick-test test_int.ml  # HANGS! (regression)
just quick-test test_float.ml  # Still hangs
```

### Analysis

**Before**: Integer format worked correctly
**After**: Even integer format hangs
**Conclusion**: My changes broke existing functionality

### Hypothesis

By including switch cases in continuation dispatch, blocks may be generated/executed twice:
1. In tag-based switch section (if v565 == 0 then ...)
2. In continuation dispatch section (if _next_block == 314 then ...)

Even though nothing sets `_next_block = 314` for pure switch cases, the structure might be wrong.

### Alternative Hypothesis

Adding true_addr to collection might create circular references or incorrect control flow.

### What Changed

```diff
- let after_switch_diff = Code.Addr.Set.diff all_dispatch_blocks switch_case_addrs in
- let after_inline_diff = Code.Addr.Set.diff after_switch_diff inline_blocks in
- let continuation_addrs = Code.Addr.Set.elements after_inline_diff in
+ (* Don't exclude switch cases - they can be continuations too *)
+ let continuation_addrs = Code.Addr.Set.diff all_dispatch_blocks inline_blocks
+                         |> Code.Addr.Set.elements in
```

```diff
- let initial_addrs = Array.to_list switch_cases |> List.map ~f:fst in
+ let initial_addrs = Array.to_list switch_cases |> List.map ~f:fst in
+ let initial_addrs_with_true_branch = match tag_var_opt with
+   | Some _ -> (match entry Cond with | Cond (_, (true_addr, _), _) -> true_addr :: initial_addrs)
+ let all_dispatch_blocks = collect_continuation_blocks initial_addrs_with_true_branch
```

## Next Steps to Fix Regression

### Option 1: Selective Inclusion
Instead of including ALL switch cases, only include those that are ACTUALLY referenced by _next_block:

```ocaml
(* Collect blocks referenced by _next_block (not tag dispatch) *)
let find_next_block_targets blocks =
  Code.Addr.Set.fold (fun addr acc ->
    match Code.Addr.Map.find_opt addr program.Code.blocks with
    | None -> acc
    | Some block ->
        (* Extract all _next_block targets from terminators *)
        let targets = match block.Code.branch with
          | Code.Branch (next, _) -> [next]
          | Code.Cond (_, (t, _), (f, _)) -> [t; f]
          | _ -> []
        in
        List.fold_left targets ~init:acc ~f:Code.Addr.Set.add
  ) all_dispatch_blocks Code.Addr.Set.empty
in

let continuation_addrs =
  Code.Addr.Set.diff all_dispatch_blocks inline_blocks
  |> Code.Addr.Set.inter (find_next_block_targets all_dispatch_blocks)
  |> Code.Addr.Set.elements
```

### Option 2: Don't Include True Branch in Collection
Revert line 1933-1951 and find another way to handle blocks 246/248.

### Option 3: Debug the Hang
Add Lua print statements in generated code to see exactly where it's looping.

## Files Modified
- `compiler/lib-lua/lua_generate.ml` - 198 lines changed

## Test Commands

```bash
# Test before changes
git stash
just build-lua-all
just quick-test test_int.ml  # Should work

# Test with changes
git stash pop
just build-lua-all
just quick-test test_int.ml  # Hangs (regression)
```

## Key Insight

Including switch cases in continuation dispatch was correct for blocks like 383 (which are referenced by both tag dispatch AND _next_block dispatch).

But something about the implementation broke the working %d format. Need to find the specific breaking change.
