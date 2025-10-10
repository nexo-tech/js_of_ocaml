# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Js_of_ocaml is a compiler from OCaml bytecode to JavaScript, enabling pure OCaml programs to run in browsers and Node.js environments. The project also includes Wasm_of_ocaml, which compiles OCaml bytecode to WebAssembly.

**Active Development**: This repository is being extended with Lua_of_ocaml, adding Lua as a compilation target.

**Documentation**:
- `LUA.md` - Detailed implementation plan with 48 tasks across 12 phases
- `ARCH.md` - Architectural guidance on code reuse and implementation patterns
- `RUNTIME.md` - Runtime API design, OCaml-Lua interop, and Neovim plugin development

## Development Environment

### OPAM Switch Setup

Create an OPAM switch for lua_of_ocaml_52 development:

```bash
# Create switch with OCaml 5.2.0
opam switch create lua_of_ocaml_52 5.2.0

# Install dependencies
eval $(opam env --switch=lua_of_ocaml_52)
opam pin add . --no-action --yes
opam install . --deps-only --yes

# Activate switch
opam switch lua_of_ocaml_52
eval $(opam env)
```

Verify setup:
```bash
dune --version  # Should be >= 3.17
ocaml --version  # Should be 5.2.0
```

### Lua Installation (for lua_of_ocaml testing)

**CRITICAL**: Lua_of_ocaml targets **Lua 5.1 and LuaJIT** for maximum compatibility.

Install Lua 5.1 using Nix package manager:

```bash
# Install Nix (if not already installed)
# See: https://nixos.org/download.html

# Install Lua 5.1 (NOT 5.2, 5.3, or 5.4)
nix-env -iA nixpkgs.lua5_1

# Verify installation
lua -v  # Should show: Lua 5.1.x
```

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

## Build Commands

### Primary Build Commands
- `make` or `dune build @all` - Build all packages
- `make tests` or `dune build @runtest @runtest-js` - Run JavaScript tests
- `make tests-wasm` or `WASM_OF_OCAML=true dune build @runtest-wasm` - Run WebAssembly tests
- `make fmt` - Format OCaml code with dune
- `make fmt-js` - Format JavaScript code with Biome
- `make lint-js` - Lint JavaScript code with Biome
- `make clean` - Clean build artifacts
- `make bench` - Run benchmarks

### Single Test Commands
- `dune exec --no-buffer -- <test_path>` - Run a single test file
- `dune build @runtest --force` - Force rerun all tests

### Dune Commands
- `dune build <target>` - Build a specific target
- `dune promote` - Accept test output changes
- `dune build @fmt --auto-promote` - Auto-format code

## Architecture Overview

### Multi-Package Structure
The repository contains multiple related packages:
- **js_of_ocaml-compiler**: Core bytecode-to-JavaScript compiler
- **js_of_ocaml**: Base library with JavaScript bindings
- **js_of_ocaml-ppx**: PPX syntax extensions
- **js_of_ocaml-lwt**: Lwt support
- **js_of_ocaml-tyxml**: TyXml support
- **js_of_ocaml-toplevel**: Browser-based OCaml toplevel
- **wasm_of_ocaml-compiler**: Bytecode-to-WebAssembly compiler

### Compilation Pipeline
1. **Parse Bytecode** (`compiler/lib/parse_bytecode.ml`): OCaml bytecode → intermediate representation
2. **Driver** (`compiler/lib/driver.ml`): Orchestrates optimization passes
3. **Optimization Passes**:
   - Deadcode elimination
   - Inlining
   - Specialization (including JavaScript-specific)
   - Tail call optimization
   - Effects handling (CPS transformation or JSPI)
4. **Code Generation**:
   - JavaScript: `compiler/lib/generate.ml`, `compiler/lib/js_output.ml`
   - WebAssembly: `compiler/lib-wasm/code_generation.ml`

### Runtime System
- **JavaScript Runtime** (`runtime/js/`): Core runtime functions for JavaScript target
- **WebAssembly Runtime** (`runtime/wasm/`): WAT files and runtime for Wasm target
- Runtimes handle OCaml primitives, memory management, exceptions, effects

### Key Intermediate Representations
- **Code.program**: Main IR after bytecode parsing
- **Javascript.program**: JavaScript AST before output
- **Wasm_ast**: WebAssembly AST

## Lua_of_ocaml Development Guidelines

### Task Completion Protocol

**IMPORTANT**: Follow this protocol for EVERY task in LUA.md

1. **Be sure you understand what and how you are building**: Reference ARCH.md and RUNTIME.md for implementation understanding. Review similar code in `compiler/lib/` (shared IR), `compiler/lib-wasm/` (reference backend), and `runtime/js/` (runtime reference).

2. **Complete fully task without leaving placeholders/TODOs you may forget about**: No `failwith "TODO"`, `assert false`, or `(* TODO *)` comments. Every function, branch, and edge case must be fully implemented. Maximum 300 lines per task. Write idiomatic OCaml following js_of_ocaml patterns.

3. **Write tests for the new stuff, since you have to be sure that your code works**: Tests go in `compiler/tests-lua/` or `lib/tests/`. Use ppx_expect patterns from existing tests. Cover complete functionality, not just happy paths.

4. **Task completion only counts when the code compiles and contains no warnings and all tests pass**: Run `dune build @check && dune build @runtest` and ensure `dune build @all 2>&1 | grep -i warning` produces no output.

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

## JavaScript/Biome Configuration

JavaScript code uses Biome for formatting and linting (`biome.json`):
- Formatter follows `.editorconfig` settings
- Custom lint rules for js_of_ocaml's generated code patterns
- Run `npx @biomejs/biome@1.9 format --write` to format
- Run `npx @biomejs/biome@1.9 lint` to lint

## Effect Handlers

Js_of_ocaml supports OCaml 5 effect handlers via two strategies:
- **CPS transformation** (`--effects=cps`): Compatible with all JavaScript engines
- **JSPI** (`--effects=jspi`, Wasm only): Uses JavaScript Promise Integration extension

Implementation in `compiler/lib/effects.ml` and related modules.

