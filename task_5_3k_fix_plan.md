# Task 5.3k.1 - Switch Filter Fix Plan
**Date**: 2025-10-14
**Status**: Implementation in progress - encountered compilation issues

## Root Cause Summary
Both address-based AND data-driven dispatch have the same bug:
1. `collect_reachable` traverses blocks, extracting Switch targets
2. When visiting targets: `Code.Addr.Map.find_opt addr` returns None for non-existent blocks
3. Collection silently skips them (returns `visited` unchanged)
4. Later, `generate_last_dispatch` generates `_next_block = addr` for ALL Switch targets
5. Result: Generated code sets `_next_block = 601` but no dispatch case exists → infinite loop

## Fix Implemented
**Location**: `compiler/lib-lua/lua_generate.ml:2816-2831`

Added filtering after grouping Switch cases:
```ocaml
let grouped_filtered =
  match ctx.program with
  | None -> grouped
  | Some program ->
      List.filter grouped ~f:(fun (addr, _args, _indices) ->
        Code.Addr.Map.mem addr program.Code.blocks)
```

Then use `grouped_filtered` instead of `grouped` when generating cases.

## Compilation Issue Encountered
After implementing fix, got `Error: Not_found` when compiling ANY file (even simple hello world).
Investigation revealed this error exists even WITHOUT my fix - possibly introduced by earlier debugging changes.

**Current Status**: Compilation broken at HEAD (commit fc9f7db0)
- Error when testing simple file: `Sys_error("Invalid argument")`
- Need to bisect to find which commit broke compilation

## Next Steps

### Immediate
1. **Bisect to find broken commit**: Test each commit from a7f4a9b9 backwards to find where compilation broke
2. **Fix or revert breaking change**: Once found, either fix the bug or revert the problematic commit
3. **Reapply Switch filter fix**: Once compilation works, reapply the filtering fix cleanly
4. **Test**: Compile test_float.ml and verify it doesn't hang

### Testing Strategy
```bash
# Test that compilation works
echo 'let x = 42' > /tmp/test.ml
ocamlc -c /tmp/test.ml
_build/default/compiler/bin-lua_of_ocaml/lua_of_ocaml.exe compile /tmp/test.cmo -o /tmp/test.lua

# Test that float format works
timeout 10 just quick-test /tmp/test_float.ml
```

### Verification Checklist
- [ ] Simple compilation works (no Sys_error or Not_found)
- [ ] Float format doesn't hang (`Printf.printf "%f\n" 3.14`)
- [ ] Integer formats still work (`Printf.printf "%d\n" 42`)
- [ ] All lua tests pass (`just test-lua`)

## Alternative Approaches (if filter doesn't work)

### Option B: Generate stub cases for missing blocks
Instead of filtering, generate empty dispatch cases:
```lua
if _next_block == 601 then
  -- Stub: block doesn't exist in IR
  break
end
```

### Option C: Change Switch to only branch to existing blocks
Modify Switch generation to skip non-existent targets entirely (no `_next_block` assignment).

### Option D: Investigate WHY blocks don't exist
Deep dive into OCaml Printf stdlib to understand why Switch references non-existent blocks.
May reveal that this is expected behavior and we need a different approach.

## Files Modified
- `compiler/lib-lua/lua_generate.ml` - Added filtering (lines 2816-2831, 2854)
- Tests unchanged (already fixed in commit 3c9b4c85)

## Commits
- fc9f7db0: Root cause analysis document
- e2d7c829: Debug infrastructure
- 3c9b4c85: Test signature fixes
- (WIP): Switch filtering fix (not yet committed due to compilation issues)
