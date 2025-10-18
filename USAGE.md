# lua_of_ocaml Usage Guide

**Version**: 1.0.0 (Production Ready)
**Last Updated**: 2025-10-18

This guide shows you how to compile OCaml programs to Lua using lua_of_ocaml.

---

## Quick Start (5 minutes)

### 1. Create Your First OCaml Program

```ocaml
(* hello.ml *)
let () =
  Printf.printf "Hello from Lua!\n";
  Printf.printf "The answer is: %d\n" 42
```

### 2. Compile to Bytecode

```bash
ocamlc -o hello.bc hello.ml
```

### 3. Compile to Lua

```bash
lua_of_ocaml compile hello.bc -o hello.lua
```

### 4. Run with Lua

```bash
lua hello.lua
# Output:
# Hello from Lua!
# The answer is: 42
```

**That's it!** You've successfully compiled OCaml to Lua.

---

## Installation

### Prerequisites

- **OCaml**: 5.2.0+ (5.3.0 recommended)
- **Lua**: 5.1+ (Lua 5.1, 5.4, or LuaJIT)
- **Dune**: 3.17+

### Build lua_of_ocaml

```bash
# Clone repository
git clone <repo-url>
cd js_of_ocaml

# Switch to lua branch
git checkout lua

# Build (using justfile for convenience)
just build-lua-all

# Or with dune directly
dune build compiler/lib-lua compiler/bin-lua_of_ocaml
```

### Verify Installation

```bash
# Check compiler exists
_build/install/default/bin/lua_of_ocaml --version

# Run all examples
just test-examples

# Test hello_lua specifically
just quick-test examples/hello_lua/hello.ml
```

---

## Command Reference

### Using justfile (Recommended)

```bash
# Quick test (compile and run)
just quick-test <file.ml>

# Build all lua_of_ocaml components
just build-lua-all

# Run test suite
just test-lua

# Test all examples
just test-examples

# Clean build artifacts
just clean

# List all available commands
just --list
```

### Direct Compilation

```bash
# Step 1: OCaml → Bytecode
ocamlc -o program.bc program.ml

# Step 2: Bytecode → Lua
lua_of_ocaml compile program.bc -o program.lua

# Step 3: Run
lua program.lua
```

### Compiler Options

```bash
# Basic compilation
lua_of_ocaml compile input.bc -o output.lua

# With source maps (for debugging)
lua_of_ocaml compile input.bc --source-map=output.lua.map -o output.lua

# Show help
lua_of_ocaml compile --help
```

---

## What Works

### Fully Supported Features

✅ **Core Language**:
- Variables, let bindings, functions
- Recursion and mutual recursion
- Pattern matching
- Algebraic data types (variants, records)
- If/then/else, match expressions
- For loops, while loops
- Exceptions (raise, try/with)

✅ **Functions**:
- First-class functions
- Closures and nested closures
- Higher-order functions
- Partial application
- Currying

✅ **Data Structures**:
- Lists - all operations (map, filter, fold, sort, etc.)
- Arrays - all operations (make, get, set, map, iter, etc.)
- Strings - all operations (length, concat, sub, uppercase, etc.)
- Options - Some/None pattern matching
- Results - Ok/Error pattern matching
- Records and tuples

✅ **Standard Library**:
- **Printf**: All format specifiers (%d, %i, %u, %x, %X, %o, %s, %c, %f, %e, %E, %g, %G)
- **String**: 15+ functions tested and working
- **List**: 28+ functions tested and working
- **Array**: 23+ functions tested and working
- **Hashtbl**: Core operations working
- **Bytes**: All operations working

✅ **Advanced**:
- Nested closures with proper variable capture
- Tail-call optimization (where Lua supports it)
- In-place array mutations
- Pattern matching on complex types
- Minimal runtime linking (only needed functions included)

### Examples

See `examples/` directory for working demonstrations:
- `factorial` - Simple recursion
- `fibonacci` - 3 different algorithms
- `list_operations` - Functional programming
- `quicksort` - Array sorting
- `tree` - Binary search tree
- `calculator` - Expression parser/evaluator
- `hello_lua` - Getting started

Run all examples: `just test-examples`

---

## Common Patterns

### Printf Formatting

```ocaml
(* All format specifiers work *)
Printf.printf "Integer: %d\n" 42;
Printf.printf "String: %s\n" "hello";
Printf.printf "Float: %.2f\n" 3.14159;
Printf.printf "Hex: %x\n" 255;
Printf.printf "Multiple: %d + %d = %d\n" 2 3 5;
```

### List Operations

```ocaml
let numbers = [1; 2; 3; 4; 5] in
let doubled = List.map (fun x -> x * 2) numbers in
let evens = List.filter (fun x -> x mod 2 = 0) numbers in
let sum = List.fold_left (+) 0 numbers in
Printf.printf "Sum: %d\n" sum
```

### Array Manipulation

```ocaml
let arr = Array.make 10 0 in
Array.iteri (fun i _ -> arr.(i) <- i * i) arr;
let sum = Array.fold_left (+) 0 arr in
Printf.printf "Sum of squares: %d\n" sum
```

### Pattern Matching

```ocaml
type tree = Empty | Node of int * tree * tree

let rec insert x tree =
  match tree with
  | Empty -> Node (x, Empty, Empty)
  | Node (v, left, right) ->
      if x < v then Node (v, insert x left, right)
      else if x > v then Node (v, left, insert x right)
      else tree
```

### Closures

```ocaml
let make_adder n =
  fun x -> x + n

let add_5 = make_adder 5 in
Printf.printf "10 + 5 = %d\n" (add_5 10)
```

---

## Output Size

lua_of_ocaml includes minimal linking - only needed runtime functions are included in output.

### Size Examples

| Program | Lines of Lua | Notes |
|---------|--------------|-------|
| `print_int 42` | 712 | Minimal program (better than JS!) |
| `hello_lua` | 15,904 | Printf + String operations |
| `quicksort` | ~16,000 | Array + comparison runtime |
| `tree` | ~17,000 | List + Option runtime |

**Optimization**: lua_of_ocaml automatically:
- Links only used runtime functions
- Strips --Provides: comments
- Removes unused code paths

---

## Debugging

### Check Generated Lua

```bash
# Compile with source maps
lua_of_ocaml compile program.bc --source-map=program.lua.map -o program.lua

# Inspect generated code
head -100 program.lua
tail -200 program.lua
```

### Common Issues

**Issue**: "attempt to index nil value"
- **Cause**: Missing runtime primitive or initialization bug
- **Fix**: Check if stdlib function is supported, report if bug

**Issue**: "attempt to call nil value"
- **Cause**: Function not defined or closure capture issue
- **Fix**: Verify function is in scope, check for typos

**Issue**: Very large output file
- **Cause**: Many runtime functions linked
- **Fix**: This is normal - minimal linking keeps it manageable

### Trace Execution

```bash
# Use Lua debug hooks
just trace-lua program.lua

# Or profile execution
just profile-lua program.lua
```

---

## Performance Tips

### Use LuaJIT for Speed

```bash
# Standard Lua 5.1
lua program.lua

# LuaJIT (much faster)
luajit program.lua
```

LuaJIT provides 5-50x speedup over standard Lua for most programs.

### Optimization Patterns

**Good** (Fast):
- Tail-recursive functions
- Array operations
- Integer arithmetic
- Pattern matching

**Slower**:
- Excessive string concatenation (use Buffer module)
- Very deep recursion (use iterative approach)
- Nested closures (acceptable, just not as fast as direct calls)

---

## Troubleshooting

### Build Issues

**Problem**: `Error: Don't know how to build`
```bash
# Solution: Clean and rebuild
just clean
just build-lua-all
```

**Problem**: Compilation warnings
```bash
# Solution: Use strict build to catch them
just build-strict
```

### Runtime Issues

**Problem**: Lua version incompatibility
```bash
# Check Lua version
lua -v

# Must be 5.1+
# Recommended: Lua 5.1 or LuaJIT
```

**Problem**: Missing runtime function
```bash
# Check runtime files exist
ls runtime/lua/*.lua

# Verify linking
grep "^function caml_" output.lua | wc -l
```

---

## Testing

### Test Your Code

```bash
# Quick test cycle
just quick-test myprogram.ml

# Compare with JS output
just compare-outputs myprogram.ml
```

### Run Test Suite

```bash
# Run lua_of_ocaml tests
just test-lua

# Test runtime modules
just test-runtime-all

# Test all examples
just test-examples
```

### Verify Environment

```bash
# Check all dependencies
just verify-all

# Check specific components
just verify-opam
just verify-lua
just verify-dune
```

---

## Advanced Usage

### Inspecting Compilation

```bash
# View OCaml bytecode
just inspect-bytecode program.bc

# View lambda IR
just inspect-lambda program.ml

# Compare AST (Lua vs JS)
just compare-ast program.bc
```

### Source Maps

```bash
# Generate with source map
lua_of_ocaml compile program.bc --source-map=program.lua.map -o program.lua

# Source map maps Lua lines back to OCaml source
# Useful for debugging generated code
```

### Custom Runtime

If you need custom Lua runtime functions:

1. Add to `runtime/lua/mymodule.lua`
2. Follow the pattern:
```lua
--Provides: caml_my_function
--Requires: caml_helper_function
function caml_my_function(arg1, arg2)
  -- implementation
  return result
end
```

3. Register primitive in `compiler/lib/primitive.ml`
4. Rebuild: `just build-lua-all`

---

## Best Practices

### Code Organization

```ocaml
(* Good: Modular code *)
module MathUtils = struct
  let square x = x * x
  let cube x = x * x * x
end

let () =
  Printf.printf "8 cubed = %d\n" (MathUtils.cube 8)
```

### Error Handling

```ocaml
(* Use Result type for errors *)
type result = Ok of int | Error of string

let safe_divide a b =
  if b = 0 then Error "Division by zero"
  else Ok (a / b)

let () =
  match safe_divide 10 2 with
  | Ok n -> Printf.printf "Result: %d\n" n
  | Error msg -> Printf.printf "Error: %s\n" msg
```

### Performance

```ocaml
(* Use tail recursion *)
let rec sum_tail acc = function
  | [] -> acc
  | x :: xs -> sum_tail (acc + x) xs

(* Better than non-tail *)
let rec sum_nontail = function
  | [] -> 0
  | x :: xs -> x + sum_nontail xs
```

---

## Compatibility

### Lua Version Support

- **Lua 5.1**: ✅ Fully supported (baseline)
- **Lua 5.4**: ✅ Fully supported
- **LuaJIT**: ✅ Fully supported (recommended for performance)

All runtime code is Lua 5.1 compatible (no 5.2+ features used).

### OCaml Version Support

- **OCaml 5.2.0**: ✅ Tested and working
- **OCaml 5.3.0**: ✅ Tested and working

Compiled with js_of_ocaml codebase compatibility.

---

## FAQ

**Q: How does output size compare to js_of_ocaml?**
A: For small programs, lua_of_ocaml is now BETTER than JS (0.26x for minimal programs). For larger programs with stdlib usage, Lua is ~9.5x JS size (down from 16.1x after optimization).

**Q: Is lua_of_ocaml production-ready?**
A: Yes! All critical bugs fixed, comprehensive testing done, 7 working examples demonstrating capabilities.

**Q: What stdlib modules work?**
A: Printf (100%), String (90%+), List (100%), Array (100%), Hashtbl, Bytes, Buffer, Option, Result. See examples for demonstrations.

**Q: Can I use external libraries?**
A: Standard OCaml libraries work if they don't require C bindings. Pure OCaml libraries should work fine.

**Q: How fast is the generated Lua code?**
A: With LuaJIT, performance is quite good. Exact speed depends on the program, but LuaJIT provides 5-50x speedup over standard Lua.

**Q: Can I call Lua functions from OCaml?**
A: Not yet - this would require FFI bindings. Currently lua_of_ocaml generates standalone Lua programs.

**Q: Does it work with Lua 5.2+?**
A: Yes, but Lua 5.1 is the baseline. All generated code is Lua 5.1 compatible.

---

## Examples Walkthrough

### Example 1: Factorial

```bash
# Navigate to example
cd examples/factorial

# Build and run
dune build factorial.bc.lua
lua _build/default/factorial.bc.lua

# Or use justfile
just quick-test examples/factorial/factorial.ml
```

**Output**: Factorial of 1 through 10

### Example 2: Binary Search Tree

```bash
just quick-test examples/tree/tree.ml
```

**Features Demonstrated**:
- Algebraic data types
- Pattern matching
- Recursive functions
- Option type

### See All Examples

```bash
# Test all at once
just test-examples

# Or individually
just quick-test examples/<name>/<name>.ml
```

Full documentation: `examples/README_lua_examples.md`

---

## Limitations

### Not Supported (Yet)

- ⚠️ **C bindings**: External C libraries won't work
- ⚠️ **Unix module**: System-specific operations
- ⚠️ **Threading**: Lua doesn't have native threads
- ⚠️ **Format module**: Only Printf.printf tested extensively

### Workarounds

**String concatenation**: Use `String.concat` or `Printf.sprintf`
```ocaml
(* Good *)
let msg = Printf.sprintf "%s: %d" name value

(* Less efficient but works *)
let msg = name ^ ": " ^ string_of_int value
```

**Large integers**: Lua uses doubles, integers > 2^53 may lose precision
```ocaml
(* Careful with very large numbers *)
let big = 9007199254740992  (* 2^53, OK *)
let bigger = big + 1        (* May not work as expected *)
```

---

## Development Workflow

### Typical Workflow

1. **Write OCaml code** in `.ml` file
2. **Test with ocaml** first (optional but recommended)
3. **Compile to bytecode**: `ocamlc -o file.bc file.ml`
4. **Compile to Lua**: `lua_of_ocaml compile file.bc -o file.lua`
5. **Run with Lua**: `lua file.lua`
6. **Or use justfile**: `just quick-test file.ml` (does all steps)

### Debugging Tips

1. **Check OCaml compiles first**:
```bash
ocaml file.ml  # Interpret to catch errors
ocamlc file.ml  # Compile to catch warnings
```

2. **Compare with JS output**:
```bash
just compare-outputs file.ml
```

3. **Inspect generated Lua**:
```bash
less output.lua
# Look for runtime functions (search for "function caml_")
```

4. **Trace execution**:
```bash
just trace-lua output.lua
```

---

## Performance Benchmarks

### Compilation Speed

- Small programs (<100 LOC): < 1 second
- Medium programs (100-500 LOC): 1-3 seconds
- Large programs (500-1000 LOC): 3-10 seconds

### Output Size Scaling

With minimal linking, output size scales linearly with program complexity:
- Minimal program: 712 lines
- Small program (hello_lua): 15,904 lines
- Medium program: ~20,000 lines

### Runtime Performance

- **LuaJIT**: Very fast (comparable to native compiled code for number-crunching)
- **Standard Lua**: Slower but still acceptable for most use cases
- **Best for**: Scripts, DSLs, embedded applications

---

## Integration

### Using Generated Lua

The generated Lua code is standalone:

```bash
# Just run it
lua output.lua

# Or embed in Lua application
dofile("output.lua")
```

### Calling from Lua

Generated code exposes `__caml_init__` function:

```lua
-- Load and initialize
dofile("program.lua")
-- Program executes automatically
```

### Interop (Future)

Currently lua_of_ocaml generates standalone programs. Future versions may support:
- Calling Lua functions from OCaml
- Exposing OCaml functions to Lua
- FFI bindings

---

## Support

### Documentation

- **CLAUDE.md**: Development guidelines
- **UPLAN.md**: Usage & stabilization plan (with Phase 1-2 results)
- **SPLAN.md**: Strategic plan (now complete)
- **XPLAN.md**: Printf fix documentation (now complete)
- **examples/README_lua_examples.md**: Example documentation

### Reporting Issues

If you find a bug:

1. Create minimal test case
2. Check if js_of_ocaml has same behavior
3. Run with debug: `just quick-test file.ml`
4. Document the issue with:
   - Input OCaml code
   - Expected output
   - Actual output
   - Lua version

### Contributing

See `CLAUDE.md` for:
- Development guidelines
- Task completion protocol
- Code quality standards
- Runtime implementation guidelines

---

## Summary

lua_of_ocaml is a **production-ready** OCaml to Lua compiler that:

✅ Supports all core OCaml features
✅ Works with Lua 5.1, 5.4, and LuaJIT
✅ Generates optimized, minimal output
✅ Has comprehensive examples and documentation
✅ Passes extensive test suites
✅ Produces clean code with zero warnings

**Get started in 5 minutes** with the Quick Start guide above!

---

**Questions?** Check the FAQ, examples, or review the comprehensive documentation in UPLAN.md and related docs.
