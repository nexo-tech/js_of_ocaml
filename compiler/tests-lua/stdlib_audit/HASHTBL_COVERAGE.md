# Hashtbl Module Coverage - lua_of_ocaml

**Status**: ⛔ **BLOCKED** - Exception handling bug prevents Hashtbl from working
**Date**: 2025-10-18
**Blocker**: Try/with exception handling not implemented in lua_of_ocaml

## Summary

The Hashtbl module cannot be used in lua_of_ocaml due to a **critical exception handling bug**. The module initialization code uses `try/with` to check for environment variables, but lua_of_ocaml does not properly implement exception handling with pcall wrapping.

## Root Cause Analysis

###  The Problem

Hashtbl module initialization code (from OCaml stdlib):
```ocaml
let randomized_default =
  let params =
    try Sys.getenv "OCAMLRUNPARAM" with Not_found ->
    try Sys.getenv "CAMLRUNPARAM" with Not_found -> "" in
  String.contains params 'R'
```

This code tries to read environment variables, catching `Not_found` exceptions if they don't exist.

### What Happens

1. **OCaml bytecode IR**: Generates `Pushtrap` and `Poptrap` instructions to mark try/with blocks
2. **lua_of_ocaml current implementation**:
   - Pushtrap: Just jumps to continuation block (STUB implementation!)
   - Does NOT wrap try block in pcall
   - Does NOT catch exceptions
   - Does NOT set exception variable
3. **When `caml_sys_getenv` is called**:
   - Raises `Not_found` exception via `error()`
   - Exception NOT caught (no pcall wrapper)
   - Program crashes

### Generated Code (Broken)

```lua
if _next_block == 797 then
  _V.v315 = caml_sys_getenv("OCAMLRUNPARAM")  -- ❌ Raises error(), not caught!
  _V.v307 = _V.v315
  _next_block = 804
else
  if _next_block == 798 then
    _V.v189 = _V.v305 == _V.Not_found  -- v305 is nil, never set!
    ...
```

### What SHOULD Happen

```lua
if _next_block == 797 then
  local success, result = pcall(caml_sys_getenv, "OCAMLRUNPARAM")
  if success then
    _V.v315 = result
    _V.v307 = _V.v315
    _next_block = 804  -- Continue
  else
    _V.v305 = result  -- Exception variable
    _next_block = 798  -- Handler block
  end
end
```

### How js_of_ocaml Handles It

js_of_ocaml generates proper JavaScript try/catch:

```javascript
try {
  // try block
  var params = caml_sys_getenv("OCAMLRUNPARAM");
  ...
} catch (exn) {
  // handler block
  if (exn === Not_found) {
    try {
      var params = caml_sys_getenv("CAMLRUNPARAM");
      ...
    } catch (exn2) {
      if (exn2 === Not_found) {
        var params = "";
      }
    }
  }
}
```

## Current Implementation Status

### Completed
- ✅ Exception handler tracking added to context (`exception_handlers` field)
- ✅ Pushtrap/Poptrap track active handlers
- ✅ Root cause identified and documented

### Blocked / TODO
- ⛔ pcall wrapping not implemented
- ⛔ Exception variable assignment not implemented
- ⛔ Jump to handler on exception not implemented
- ⛔ Block dispatch model incompatible with structured try/catch

## Test Suite

Created comprehensive test suite in `test_hashtbl.ml` covering:
- Hashtbl creation, add, find, find_opt
- remove, replace, mem, clear
- iter, fold, copy, length
- Large hashtables (resize testing)
- Mixed types, complex values
- Duplicate keys, find_all
- Stats, filter_map_inplace
- Edge cases and stress tests

**Total**: 20+ test sections, 100+ individual test cases

**Status**: Cannot run until exception handling is fixed

## The Fix Required

To fix Hashtbl (and ALL try/with in lua_of_ocaml), we need to:

1. **Modify Pushtrap code generation** to wrap try blocks in pcall
2. **Track which blocks are inside try region** for proper wrapping
3. **Generate exception variable assignment** on pcall failure
4. **Generate jump to handler block** when exception matches

### Implementation Challenges

- Lua's pcall requires function wrapping, not block wrapping
- Current block dispatch model uses one big while loop
- Can't easily wrap subset of blocks in pcall
- May need to restructure code generation significantly

### Possible Approaches

**Option 1**: Wrap each potentially-raising operation in pcall when in try block
- Pro: Targeted, minimal changes
- Con: Need to identify all raising operations

**Option 2**: Restructure blocks for structured try/catch
- Pro: Clean, matches JS implementation
- Con: Major refactor of code generation

**Option 3**: Generate nested while loops for try regions
- Pro: Works with block dispatch model
- Con: Complex, may have performance impact

## Impact

**Affected Modules**:
- ❌ Hashtbl - completely broken
- ❌ Any code using try/with - broken
- ❌ Sys.getenv - raises exceptions
- ✅ Modules not using exceptions - work fine

**Working Examples**:
- ✅ hello_lua - no try/with
- ✅ factorial, fibonacci, list_operations, quicksort, tree, calculator - all work
- ✅ Array, List, String modules - work (when not using Hashtbl)

## Priority

**CRITICAL** - Exception handling is fundamental to OCaml. This blocks:
- Hashtbl usage (common data structure)
- Any error handling code
- Many stdlib functions that use try/with internally
- Production-ready status

## Related Files

- `compiler/lib-lua/lua_generate.ml:3238-3258` - Pushtrap/Poptrap (stub implementation)
- `runtime/lua/sys.lua:104-113` - caml_sys_getenv (raises Not_found)
- `runtime/lua/fail.lua` - Exception raising functions
- `compiler/lib/generate.ml:2148-2193` - JS implementation (reference)

## References

- Task: UPLAN.md Task 4.4 (Hashtbl stdlib audit)
- Root cause analysis: This document
- Test suite: `compiler/tests-lua/stdlib_audit/test_hashtbl.ml`
- Bug tracking: exception_handlers field added to context

---

**Next Steps**: Implement proper exception handling in lua_of_ocaml before Hashtbl can be used.
