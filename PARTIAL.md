# Partial Application Support in Lua_of_ocaml

This document outlines the implementation plan for proper partial application (currying) support in the Lua code generator.

## Problem Statement

OCaml supports partial application where functions can be called with fewer arguments than expected, returning a closure. The current Lua generator doesn't handle this correctly, causing Printf and other stdlib functions to fail.

**Current Issues**:
1. All functions wrapped as `{l = arity, f = function}` breaks primitives
2. Channel IDs passed as blocks instead of integers
3. Some functions not wrapped, causing `caml_call_gen` to fail
4. No distinction between exact calls and partial application

## JavaScript Approach (Reference)

js_of_ocaml handles this elegantly:
- Functions have `.l` property indicating arity
- When `exact` is true: call directly `f(args...)`
- When `exact` is false: check arity and either call directly or use `caml_call_gen`
- External primitives are NOT wrapped
- Runtime `caml_call_gen` handles under-application (partial), exact application, and over-application

## Proposed Approach

**Key Insight**: Don't wrap everything. Use a hybrid approach:
1. **Direct calls** for exact applications with known arity
2. **Conditional calls** for non-exact applications (check arity at runtime)
3. **No wrapping** for external primitives and built-in functions
4. **Selective wrapping** only for user-defined closures that need it

---

## Master Checklist

### Phase 1: Analysis and Design
- [ ] Task 1.1: Analyze js_of_ocaml's function calling conventions
- [ ] Task 1.2: Document OCaml function representation requirements
- [ ] Task 1.3: Design Lua function calling strategy
- [ ] Task 1.4: Design arity tracking system

### Phase 2: Core Infrastructure
- [ ] Task 2.1: Implement function metadata tracking in code generator
- [ ] Task 2.2: Add arity annotation to generated closures
- [ ] Task 2.3: Create runtime helper for arity checking
- [ ] Task 2.4: Update caml_call_gen to handle all cases

### Phase 3: Code Generation Refactoring
- [ ] Task 3.1: Revert universal function wrapping
- [ ] Task 3.2: Implement conditional wrapping for closures
- [ ] Task 3.3: Fix function application generation
- [ ] Task 3.4: Handle exact vs non-exact calls correctly

### Phase 4: Primitive Handling
- [ ] Task 4.1: Identify all external primitives
- [ ] Task 4.2: Ensure primitives are never wrapped
- [ ] Task 4.3: Fix primitive function calls
- [ ] Task 4.4: Test primitive operations

### Phase 5: Format/Printf Fix
- [ ] Task 5.1: Trace Format module channel passing
- [ ] Task 5.2: Fix channel ID representation
- [ ] Task 5.3: Remove channel ID workarounds
- [ ] Task 5.4: Verify Printf works correctly

### Phase 6: Integration and Testing
- [ ] Task 6.1: Run hello.ml with all Printf statements
- [ ] Task 6.2: Create partial application test suite
- [ ] Task 6.3: Test curried function composition
- [ ] Task 6.4: Verify no TODOs or hacks remain
- [ ] Task 6.5: Update LUA.md Task M1.2 as complete

---

## Detailed Task Breakdown

### Phase 1: Analysis and Design

#### Task 1.1: Analyze js_of_ocaml's function calling conventions
**Estimated Lines**: 50 (analysis/documentation)
**Deliverable**: Document analyzing `compiler/lib/generate.ml` function application

**Actions**:
1. Read `apply_fun_raw` in `compiler/lib/generate.ml`
2. Document how `exact` flag is used
3. Document when `caml_call_gen` is called
4. Note how function arity is checked (`.l` property)
5. Document the conditional logic for direct vs indirect calls

**Success Criteria**: Clear understanding of JS approach documented in PARTIAL.md

---

#### Task 1.2: Document OCaml function representation requirements
**Estimated Lines**: 30 (documentation)
**Deliverable**: Specification of OCaml function format in Lua

**Actions**:
1. Document required function structure: `{l = arity, f = function}`
2. List which functions need wrapping vs direct representation
3. Document how closures capture variables
4. Specify when to use `.f` vs direct call
5. Document arity checking requirements

**Success Criteria**: Clear spec that can guide implementation

---

#### Task 1.3: Design Lua function calling strategy
**Estimated Lines**: 50 (design document)
**Deliverable**: Calling convention design document

**Actions**:
1. Design 3-tier strategy:
   - Tier 1: Direct calls for exact applications (no wrapper)
   - Tier 2: Conditional calls for non-exact with arity check
   - Tier 3: caml_call_gen for complex cases
2. Define when each tier is used
3. Design arity tracking mechanism
4. Plan backwards compatibility

**Success Criteria**: Clear decision tree for function calls

---

#### Task 1.4: Design arity tracking system
**Estimated Lines**: 40 (design)
**Deliverable**: Arity tracking design

**Actions**:
1. Design how to track function arity in IR
2. Plan how to propagate arity through compiler
3. Design metadata structure for functions
4. Plan how to distinguish user functions from primitives

**Success Criteria**: Design that enables proper arity-based decisions

---

### Phase 2: Core Infrastructure

#### Task 2.1: Implement function metadata tracking in code generator
**Estimated Lines**: 150
**Deliverable**: Enhanced context with function metadata

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Add `function_arities` map to context
2. Implement `register_function_arity` helper
3. Add `lookup_function_arity` helper
4. Populate arities during closure generation
5. Add helper to check if function is primitive

**Success Criteria**: Context tracks function arities, compiles without errors

---

#### Task 2.2: Add arity annotation to generated closures
**Estimated Lines**: 80
**Deliverable**: Closures with `.l` property

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Modify `generate_closure` to add `.l` property
2. Keep function as direct Lua function (not wrapped in table yet)
3. Add arity as metadata comment in generated code
4. Ensure arity matches parameter count

**Success Criteria**: Generated closures have arity information

---

#### Task 2.3: Create runtime helper for arity checking
**Estimated Lines**: 80
**Deliverable**: `caml_check_arity` function

**File**: `runtime/lua/fun.lua`

**Actions**:
1. Create `caml_check_arity(func, n_args)` that:
   - Returns true if function has arity n_args
   - Handles both wrapped and unwrapped functions
   - Returns false for non-functions
2. Add `--Provides: caml_check_arity` comment
3. Write tests in `test_fun.lua`

**Success Criteria**: Runtime can check function arity, tests pass

---

#### Task 2.4: Update caml_call_gen to handle all cases
**Estimated Lines**: 100
**Deliverable**: Robust caml_call_gen

**File**: `runtime/lua/fun.lua`

**Actions**:
1. Handle functions with `.l` property
2. Handle plain Lua functions (assign arity from params)
3. Handle primitives (never wrapped)
4. Add better error messages
5. Optimize common cases (1-2 arg partial application)

**Success Criteria**: caml_call_gen handles wrapped and unwrapped functions

---

### Phase 3: Code Generation Refactoring

#### Task 3.1: Revert universal function wrapping
**Estimated Lines**: 50
**Deliverable**: Closures not automatically wrapped

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Remove `{l = arity, f = function}` wrapper from `generate_closure`
2. Return plain `L.Function` instead
3. Keep arity tracking in place
4. Add comment explaining why not wrapped

**Success Criteria**: Generates plain functions, compiles successfully

---

#### Task 3.2: Implement conditional wrapping for closures
**Estimated Lines**: 120
**Deliverable**: Selective wrapping logic

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Add `needs_wrapping` predicate:
   - True for closures that can be partially applied
   - False for primitives
   - False for functions only called with exact arity
2. Modify `generate_closure` to wrap only when needed
3. Add wrapping helper function
4. Track wrapped vs unwrapped functions in context

**Success Criteria**: Only necessary functions wrapped, code compiles

---

#### Task 3.3: Fix function application generation
**Estimated Lines**: 200
**Deliverable**: Correct function calls

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Modify `Code.Apply` handling:
   ```ocaml
   | Code.Apply { f; args; exact } ->
       if exact then
         (* Exact call - check if wrapped *)
         if is_wrapped then
           L.Call (L.Index (func, L.String "f"), args)
         else
           L.Call (func, args)
       else
         (* Non-exact - use caml_call_gen *)
         L.Call (L.Ident "caml_call_gen", [func; L.Table args])
   ```
2. Add `is_wrapped_function` helper
3. Handle primitives specially (never wrapped)
4. Optimize common cases

**Success Criteria**: Generated calls are correct, compiles

---

#### Task 3.4: Handle exact vs non-exact calls correctly
**Estimated Lines**: 150
**Deliverable**: Proper exact call optimization

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. When `exact` is true:
   - Call function directly if unwrapped
   - Call `.f` if wrapped
2. When `exact` is false:
   - Always use `caml_call_gen`
   - Let runtime handle arity mismatch
3. Add fast path for known-arity functions
4. Add comments explaining logic

**Success Criteria**: Exact calls optimized, partial application works

---

### Phase 4: Primitive Handling

#### Task 4.1: Identify all external primitives
**Estimated Lines**: 80
**Deliverable**: Primitive registry

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Create `is_external_primitive` function
2. Add set of all primitive names (caml_*, runtime functions)
3. Check primitive list from `generate_prim`
4. Document which functions are primitives

**Success Criteria**: Can identify all primitives programmatically

---

#### Task 4.2: Ensure primitives are never wrapped
**Estimated Lines**: 60
**Deliverable**: Primitives always unwrapped

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Modify `needs_wrapping` to return false for primitives
2. Add assertion to prevent primitive wrapping
3. Document why primitives aren't wrapped
4. Test that primitives compile correctly

**Success Criteria**: No primitives wrapped, all primitive calls work

---

#### Task 4.3: Fix primitive function calls
**Estimated Lines**: 100
**Deliverable**: Correct primitive application

**File**: `compiler/lib-lua/lua_generate.ml`

**Actions**:
1. Modify `generate_prim` to return unwrapped calls
2. Ensure primitive calls never use `.f`
3. Primitives always called directly
4. Handle special cases (caml_ml_output, etc.)

**Success Criteria**: All primitives called correctly

---

#### Task 4.4: Test primitive operations
**Estimated Lines**: 150 (tests)
**Deliverable**: Primitive test suite

**File**: `compiler/tests-lua/test_primitives.ml`

**Actions**:
1. Test string operations (caml_string_get, etc.)
2. Test array operations
3. Test I/O operations (caml_ml_output)
4. Test arithmetic operations
5. Verify all tests pass

**Success Criteria**: All primitive tests pass

---

### Phase 5: Format/Printf Fix

#### Task 5.1: Trace Format module channel passing
**Estimated Lines**: 80 (analysis + debugging)
**Deliverable**: Understanding of channel flow

**Actions**:
1. Add debug output to generated Format code
2. Trace how stdout channel is created
3. Trace how it's passed to Format functions
4. Identify where channel becomes block
5. Document the exact call chain

**Success Criteria**: Know exactly where channel ID becomes block

---

#### Task 5.2: Fix channel ID representation
**Estimated Lines**: 120
**Deliverable**: Proper channel ID passing

**File**: `compiler/lib-lua/lua_generate.ml` or runtime

**Actions**:
1. Based on Task 5.1 findings, fix the root cause
2. Ensure channels stay as integers through call chain
3. Fix any field access bugs related to channels
4. Remove any incorrect block wrapping

**Success Criteria**: Channel IDs are integers end-to-end

---

#### Task 5.3: Remove channel ID workarounds
**Estimated Lines**: 40
**Deliverable**: Clean runtime code

**File**: `runtime/lua/io.lua`

**Actions**:
1. Remove HACK comment and workaround in `caml_unwrap_chanid`
2. Remove stdin→stdout remapping logic
3. Restore proper error handling
4. Add assertion that channel is integer

**Success Criteria**: No hacks or workarounds in io.lua

---

#### Task 5.4: Verify Printf works correctly
**Estimated Lines**: 100 (tests)
**Deliverable**: Printf test suite

**File**: `compiler/tests-lua/test_printf.ml`

**Actions**:
1. Test Printf.printf with various format strings
2. Test Printf.fprintf to stdout/stderr
3. Test Printf.sprintf
4. Test format string with multiple arguments
5. Verify output is correct

**Success Criteria**: All Printf tests pass

---

### Phase 6: Integration and Testing

#### Task 6.1: Run hello.ml with all Printf statements
**Estimated Lines**: 20 (testing)
**Deliverable**: hello.ml runs completely

**Actions**:
1. Run `lua _build/default/examples/hello_lua/hello.bc.lua`
2. Verify all output is correct:
   - "Hello from Lua_of_ocaml!"
   - "Factorial of 5 is: 120"
   - "Testing string operations..."
   - "Length of 'lua_of_ocaml': 12"
   - "Uppercase: LUA_OF_OCAML"
3. Verify no errors or crashes

**Success Criteria**: hello.ml runs to completion with correct output

---

#### Task 6.2: Create partial application test suite
**Estimated Lines**: 200
**Deliverable**: Comprehensive partial application tests

**File**: `compiler/tests-lua/test_partial_application.ml`

**Actions**:
1. Test simple partial application: `let add x y = x + y; let add5 = add 5`
2. Test multi-level currying: `let f a b c = a + b + c; let g = f 1; let h = g 2`
3. Test over-application: passing too many args
4. Test exact application
5. Test composition of partial applications
6. Verify all tests pass

**Success Criteria**: 20+ partial application tests, all passing

---

#### Task 6.3: Test curried function composition
**Estimated Lines**: 150
**Deliverable**: Composition tests

**File**: `compiler/tests-lua/test_composition.ml`

**Actions**:
1. Test `let compose f g x = f (g x)`
2. Test pipeline: `x |> f |> g |> h`
3. Test List.map with partial application
4. Test List.fold_left with currying
5. Test function returning function

**Success Criteria**: Complex currying patterns work

---

#### Task 6.4: Verify no TODOs or hacks remain
**Estimated Lines**: 20 (verification)
**Deliverable**: Clean codebase

**Actions**:
1. `grep -r "HACK\|TODO\|FIXME\|WORKAROUND" compiler/lib-lua/`
2. `grep -r "HACK\|TODO\|FIXME\|WORKAROUND" runtime/lua/`
3. Remove or document any remaining TODOs
4. Ensure all hacks are removed
5. Clean up debug output

**Success Criteria**: Zero hacks/todos related to partial application

---

#### Task 6.5: Update LUA.md Task M1.2 as complete
**Estimated Lines**: 10
**Deliverable**: LUA.md updated

**Actions**:
1. Mark Task M1.2 as `- [x]` completed
2. Update status from 🟡 to ✅
3. Add note about partial application support
4. Commit changes with proper message

**Success Criteria**: LUA.md reflects completion

---

## Implementation Notes

### Key Principles

1. **Minimize Wrapping**: Only wrap functions that absolutely need it
2. **Optimize Common Case**: Direct calls for exact applications
3. **Runtime Checks**: Use caml_call_gen only when necessary
4. **No Breaking Changes**: Existing working code should continue working
5. **Follow js_of_ocaml**: Mirror their proven approach

### Testing Strategy

Each phase should:
1. Compile without errors
2. Pass existing tests
3. Add new tests for the feature
4. Verify no regressions

### Debugging Approach

For each bug:
1. Add minimal reproduction
2. Trace through generated code
3. Compare with js_of_ocaml behavior
4. Fix root cause, not symptoms
5. Add test to prevent regression

---

## Success Criteria

The implementation is complete when:

✅ All tasks marked complete
✅ hello.ml runs with all Printf calls
✅ No hacks or workarounds remain
✅ No TODOs related to partial application
✅ 50+ tests for partial application pass
✅ Code follows js_of_ocaml patterns
✅ LUA.md Task M1.2 marked complete
✅ Partial application works for all OCaml patterns

---

## Timeline Estimate

- **Phase 1** (Analysis): 2-3 hours
- **Phase 2** (Infrastructure): 4-5 hours
- **Phase 3** (Refactoring): 6-8 hours
- **Phase 4** (Primitives): 3-4 hours
- **Phase 5** (Printf): 4-5 hours
- **Phase 6** (Testing): 3-4 hours

**Total**: 22-29 hours of focused work

---

## References

- `compiler/lib/generate.ml`: JavaScript code generation (reference)
- `compiler/lib-lua/lua_generate.ml`: Lua code generation (to be fixed)
- `runtime/js/fun.js`: JavaScript function utilities (reference)
- `runtime/lua/fun.lua`: Lua function utilities (to be enhanced)
- OCaml manual on currying and partial application
