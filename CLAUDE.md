# CLAUDE.md

This project is creation of lua_of_ocaml: Ocaml -> lua compiler. Based on
js_of_ocaml

## Using Just Commands

**IMPORTANT**: All development tasks should use the `just` command runner defined in `justfile`.

### Quick Reference

```bash
# List all available commands
just --list

# Get help for a specific command
just --show <command-name>

# Common workflows
just build-lua-all        # Build all lua_of_ocaml components
just test-lua             # Run lua_of_ocaml tests only
just test-runtime-all     # Test all runtime modules
just clean                # Clean build artifacts
just verify-all           # Verify environment setup
just full-test            # Clean, build, and test everything

# Development workflows
just quick-test <file.ml>      # Compile and run OCaml file
just compare-outputs <file.ml> # Compare Lua vs JS output
just test-file <test_name>     # Run specific test
just inspect-bytecode <file>   # Inspect bytecode structure
```

### Why Just?

- **Single source of truth**: All commands in one place (`justfile`)
- **Consistent interface**: Same commands work across different environments
- **Self-documenting**: Commands include descriptions and show usage
- **Lua-focused**: Commands skip non-lua_of_ocaml tests by default
- **Simplified debugging**: Standard workflows for common tasks

### Environment Setup

See `ENV.md` for complete environment setup checklist with 8 phases of verification and testing.

**DO NOT** use raw `dune`, `ocamlc`, or `lua` commands directly unless specifically required. Always prefer `just` commands.

## Development Environment

**IMPORTANT - Lua 5.1 Baseline Requirement**:
- Lua 5.1 compatibility is **REQUIRED** and is the baseline for all runtime code
- LuaJIT is based on Lua 5.1, so all code must work on Lua 5.1
- Do NOT use Lua 5.2+ features (bitwise operators, goto, `\z`, etc.)
- Do NOT use Lua 5.3+ features (string.pack/unpack, `//`, bitwise `&|~`, etc.)
- All runtime tests must pass on Lua 5.1 - **verify with Lua 5.1 before committing**
- Use `lua -v` to confirm you're testing with Lua 5.1.x
- If implementing features that benefit from Lua 5.3+ (like string.pack), provide Lua 5.1 fallback
- Runtime code must work on both standard Lua 5.1 and LuaJIT

**Lua is required for**:
  - Running generated `.lua` files
  - Verifying lua_of_ocaml output
  - Testing runtime behavior (ALL tests must pass on Lua 5.1)
  - Validating hello_lua example


## Lua_of_ocaml Development Guidelines

### Task Completion Protocol

**IMPORTANT**: Follow this protocol for EVERY task user requested

1. **Be sure you understand what and how you are building**. If you don't
   understand how it's build, search for files and also compare to Js compiler.
2. **Complete fully task without leaving placeholders/TODOs you may forget about**
3. If something doesn't work or there's bug then it's likely YOUR lua code
   generation code or runtime bug that YOU introduced. To fix it: reference
   thoroughly how js_of_ocaml solves this issue and make sure you do 1:1
   approach to fix it.
3. **Write tests for the new stuff, since you have to be sure that your code works**: Tests go in `compiler/tests-lua/` or `lib/tests/`. Use ppx_expect patterns from existing tests. Cover complete functionality, not just happy paths.
4. **Task completion only counts when the code compiles and contains no warnings and all tests pass**: Run `just check && just test-lua && just build-strict` to verify no warnings or errors.
5. **Once the task is completed update master checklist with `- [x]` mark to track progress in LUA.md then commit and push**:
   ```bash
   # Update LUA.md checklist
   git add .
   git commit -m "feat|test|fix|docs: <description>"
   git push
   ```

### Code Quality Standards
- **Complete Implementation**: No `failwith "TODO"`, `assert false` placeholders, or unimplemented branches
- **Self-Contained**: Each task must leave the codebase in a working, compilable state
- **No Warnings**: Zero compilation warnings tolerated
- **Tested**: All new code must have corresponding tests
- **Documented**: Complex logic should have explanatory comments (but no TODO comments)

### Lua Runtime Implementation Guidelines

**CRITICAL**: The Lua runtime (`runtime/lua/`) has strict requirements for linker compatibility. Follow these rules exactly:

#### Compatibility Requirements
- **Lua 5.1 compatibility REQUIRED**: All runtime code must work on Lua 5.1 and LuaJIT
- **NO Lua 5.2+ features**: Cannot use bitwise operators (&, |, <<, >>), goto, etc.
- **NO external dependencies**: Cannot use `require()` for external modules like bit, bit32, etc.
- **Pure Lua 5.1**: Implement bitwise operations using math.floor and modulo if needed

#### Function Structure
- **ONLY global functions with `caml_` prefix**: Every runtime function must be named `caml_*` and be global
- **Provides comment required**: Each function MUST have `--Provides: function_name` comment
- **Requires comment optional**: Add `--Requires: dep1, dep2` if function depends on other `caml_` functions
- **No documentation comments**: Only `--Provides:` and `--Requires:` comments allowed

```lua
--Provides: caml_example_function
--Requires: caml_helper_function
function caml_example_function(arg1, arg2)
  local result = caml_helper_function(arg1)
  return result + arg2
end
```

#### Restrictions
- **NO global variables**: Cannot have `GLOBAL_VAR = 42` or similar
- **NO global tables**: Cannot have `MyTable = {}` or class definitions
- **NO local helper functions**: Linker cannot inline local functions - all helpers must be `caml_` functions with `--Provides:`
- **NO module wrappers**: No `local M = {}` or `return M` patterns
- **NO local variables with require()**: Cannot have `local bit = require("compat_bit")` or similar

#### Testing
- **Tests use dofile()**: Test files load runtime with `dofile("filename.lua")`, NOT `require()`
- **Tests call caml_ functions directly**: Access functions by name, not through module tables

#### Rationale
The OCaml-to-Lua linker parses `--Provides:` comments to extract only needed functions from the runtime. It cannot:
- Extract local functions (they're not visible)
- Handle global variables/tables (compilation model doesn't support them)
- Process module patterns (needs flat namespace)

This matches the js_of_ocaml JavaScript runtime structure where all primitives are registered functions.

## Testing Infrastructure

### Test Categories
- `compiler/tests-compiler/`: Compiler functionality tests
- `compiler/tests-jsoo/`: JavaScript output tests
- `compiler/tests-wasm_of_ocaml/`: WebAssembly-specific tests
- `compiler/tests-js-parser/`: JavaScript parser tests
- `lib/tests/`: Library binding tests
- `compiler/tests-num/`, `compiler/tests-re/`: External library compatibility

### Test Utilities
- Tests use `ppx_expect` for snapshot testing
- `.expected` files contain expected output
- Use `dune promote` to accept new test outputs

## Common Gotchas

### Dune Library Module Wrapping

When a dune library has multiple .ml files, dune automatically wraps them with a `__` prefix:

```ocaml
(* If you have a library named "lua_of_ocaml_compiler" with files:
   - lua_of_ocaml_compiler.ml
   - lua_ast.ml

   Dune creates wrapped modules:
   - Lua_of_ocaml_compiler (main module)
   - Lua_of_ocaml_compiler__Lua_ast (wrapped submodule)
*)

(* In tests or other code, access submodules like this: *)
module Lua_ast = struct
  include Lua_of_ocaml_compiler__Lua_ast  (* Note the __ prefix *)
end

(* NOT like this: *)
module Lua_ast = Lua_of_ocaml_compiler.Lua_ast  (* ❌ Won't work *)
```

This is the default behavior when you don't specify `(wrapped false)` in your dune library stanza. The wrapping prevents name conflicts between libraries.

### Js_of_ocaml_compiler Stdlib Module

The `js_of_ocaml_compiler` library includes a custom `Stdlib` module (in `compiler/lib/stdlib.ml`) that:

- Uses **labeled arguments** for common functions (`List.fold_left ~f ~init`, `String.iter ~f`, etc.)
- Provides `StringSet`, `StringMap`, `IntSet`, `IntMap` from `Set.Make` and `Map.Make`
- Is automatically opened when using lua_of_ocaml_compiler via the dune `(flags (:standard -open Js_of_ocaml_compiler))`

When writing code in `compiler/lib-lua/`, remember to:

```ocaml
(* Use labeled arguments *)
List.fold_left ~f:(fun acc x -> ...) ~init:StringSet.empty [...]
String.iter ~f:(fun c -> ...) str
String.for_all ~f:(fun c -> ...) str

(* Pattern match chars instead of >= <= comparisons *)
match c with
| 'a' .. 'z' | 'A' .. 'Z' -> true
| _ -> false
```

