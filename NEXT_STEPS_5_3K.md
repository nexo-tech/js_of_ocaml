# Task 5.3k.1 - Next Steps
**Date**: 2025-10-15

## Summary
Data-driven dispatch FIXED ✅ | Address-based dispatch BROKEN ⏳

## What Works Now
- Compilation of .cmo/.byte files ✅
- Data-driven dispatch (Printf-style closures) ✅
- Dispatcher/entry/true-branch exclusion ✅
- Back-edges to entry (no _next_block loop) ✅

## What's Broken
Missing dispatch cases in address-based closures:
- Block 246: 1 assignment
- Block 248: 1 assignment
- Block 383: 18 assignments ⚠️
- Block 448: 28 assignments ⚠️
- Block 827: 1 assignment
- Block 828: 1 assignment

## Root Cause Hypothesis
Address-based dispatch has similar issue to data-driven:
- Some blocks are special (entry/inline) but get referenced
- collect_reachable might miss them OR
- They're collected but not added to dispatch loop

## How to Fix

### Step 1: Find the Closure
```bash
# Enable debug in lua_generate.ml
let debug_var_collect = ref true

# Add debug at start of compile_address_based_dispatch:
if Code.Addr.Set.mem 383 reachable || Code.Addr.Set.mem 448 reachable then
  Printf.eprintf "[ADDRESS] Closure start=%d contains block 383/448\n%!" start_addr;

# Rebuild and check
just build-lua-all
lua_of_ocaml compile test.byte -o test.lua 2>&1 | grep '\[ADDRESS\]'
```

### Step 2: Check Reachability
```ocaml
# In compile_address_based_dispatch after collect_reachable:
if !debug_var_collect then
  Printf.eprintf "[ADDRESS] start=%d, reachable=%d blocks\n"
    start_addr (Code.Addr.Set.cardinal reachable);
  if not (Code.Addr.Set.mem 383 reachable) then
    Printf.eprintf "  Block 383 NOT reachable from %d!\n" start_addr;
```

### Step 3: Check Block Generation
```ocaml
# In block_cases generation:
|> List.map ~f:(fun addr ->
     if addr = 383 || addr = 448 then
       Printf.eprintf "[BLOCK-%d] Generating...\n" addr;
     ...
```

### Step 4: Apply Fix
Likely similar to data-driven:
- Identify entry/special blocks
- Exclude from dispatch OR
- Handle back-edges specially

## Test When Fixed
```bash
timeout 5 just quick-test /tmp/test_float.ml
# Should print: 3.140000 (or error about unsupported format)
# Should NOT timeout
```

## Files to Check
- `compiler/lib-lua/lua_generate.ml:2493-2527` - collect_reachable in address-based
- `compiler/lib-lua/lua_generate.ml:2518-2535` - block_cases generation

## Debug Commands
```bash
# Check specific blocks
for i in 246 248 383 448 827 828; do
  echo "Block $i: $(grep -c "_next_block = $i\$" test.lua) assigns, $(grep -c "if _next_block == $i " test.lua) dispatch"
done

# Find all missing
/tmp/check_dispatch.sh | head -20
```
