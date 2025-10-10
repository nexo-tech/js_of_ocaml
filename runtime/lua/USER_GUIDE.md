# Lua_of_ocaml User Guide

Complete guide to using lua_of_ocaml - compile OCaml to Lua for Neovim, LuaJIT, and embedded systems.

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Runtime Modules](#runtime-modules)
5. [Compatibility](#compatibility)
6. [Performance](#performance)
7. [Migration from js_of_ocaml](#migration-from-js_of_ocaml)
8. [Troubleshooting](#troubleshooting)

---

## Introduction

**Lua_of_ocaml** is a compiler from OCaml bytecode to Lua, enabling OCaml programs to run in Lua environments including:

- **Neovim** - Write Neovim plugins in OCaml
- **LuaJIT** - High-performance Lua with JIT compilation
- **Embedded Systems** - Lua-based game engines, embedded platforms
- **Lua 5.1/5.4** - Standard Lua interpreters

### Why Lua_of_ocaml?

- **OCaml's Type Safety** - Strong typing, inference, exhaustiveness checking
- **Neovim Integration** - Modern plugin development with OCaml
- **Performance** - LuaJIT provides exceptional runtime speed (100-300x faster than standard Lua)
- **Code Reuse** - Share code between web (js_of_ocaml), native, and Lua targets

---

## Installation

### Prerequisites

- OCaml 5.2.0 or later
- dune 3.17 or later
- OPAM package manager

### Setting Up OPAM Switch

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

### Building lua_of_ocaml

```bash
# Build compiler and runtime
make

# Run tests
make tests

# Install
make install
```

---

## Quick Start

### Hello World

Create `hello.ml`:

```ocaml
let () = print_endline "Hello from OCaml in Lua!"
```

Compile to Lua:

```bash
# Compile OCaml to bytecode
ocamlc -o hello.byte hello.ml

# Compile bytecode to Lua
lua_of_ocaml hello.byte -o hello.lua

# Run with Lua
lua hello.lua
# Or with LuaJIT
luajit hello.lua
# Or in Neovim
nvim -c "luafile hello.lua"
```

### Using Runtime Modules

OCaml code automatically uses the runtime modules:

```ocaml
(* OCaml code *)
let numbers = [|1; 2; 3; 4; 5|]
let doubled = Array.map (fun x -> x * 2) numbers
let sum = Array.fold_left (+) 0 doubled

let () = Printf.printf "Sum: %d\n" sum
```

Compiles to Lua using `array.lua`, `ints.lua`, and `io.lua` runtime modules.

---

## Runtime Modules

The lua_of_ocaml runtime consists of modular Lua files implementing OCaml primitives:

### Core Modules

#### `core.lua` - Runtime Bootstrap

Provides primitive registration, module system, and core type encodings.

**Key Functions**:
- `get_primitive(name)` - Get registered primitive
- `ml_bool(lua_bool)` - Convert Lua boolean to OCaml bool (0/1)
- `lua_bool(ml_bool)` - Convert OCaml bool to Lua boolean
- `some(value)` - Create OCaml `Some value`
- `none` - OCaml `None` value
- `unit` - OCaml `()` value

**Type Encodings**:
- `unit` → `0`
- `true` → `1`, `false` → `0`
- `None` → `0`, `Some x` → `{tag=0, x}`
- Lists: `[]` → `0`, `x::xs` → `{tag=0, x, xs}`

#### `ints.lua` - Integer Operations

32-bit signed integer operations matching OCaml semantics.

**Functions**:
- `add(a, b)`, `sub(a, b)`, `mul(a, b)`, `div(a, b)`, `mod(a, b)`
- `band(a, b)`, `bor(a, b)`, `bxor(a, b)`, `bnot(a)`
- `lsl(a, n)`, `lsr(a, n)`, `asr(a, n)` - Bit shifts
- `compare(a, b)` - Three-way comparison (-1, 0, 1)

#### `float.lua` - Float Operations

IEEE 754 floating-point operations.

**Functions**:
- `caml_modf_float(x)` - Split float into integer and fractional parts
- `caml_ldexp_float(x, n)` - x * 2^n
- `caml_frexp_float(x)` - Normalize float to mantissa and exponent
- `caml_is_finite(x)` - Check if finite (not NaN or infinity)
- `caml_classify_float(x)` - Classify float (normal, subnormal, zero, infinite, nan)

#### `mlBytes.lua` - Bytes/String Operations

Byte sequence operations for OCaml strings and bytes.

**Functions**:
- `create(length)` - Create byte sequence
- `get(bytes, index)`, `set(bytes, index, value)` - Access bytes
- `get16(bytes, index)`, `set16(bytes, index, value)` - 16-bit access
- `get32(bytes, index)`, `set32(bytes, index, value)` - 32-bit access
- `bytes_of_string(str)`, `string_of_bytes(bytes)` - Conversions

#### `array.lua` - Array Operations

OCaml array operations.

**Functions**:
- `make(length, init)` - Create array
- `get(array, index)`, `set(array, index, value)` - Access elements (0-indexed)
- `length(array)` - Get length

#### `list.lua` - List Operations

OCaml list operations.

**Functions**:
- `caml_list_cons(hd, tl)` - Add element to front
- `caml_list_hd(list)`, `caml_list_tl(list)` - Head and tail
- `caml_list_length(list)` - Length
- `caml_list_rev(list)` - Reverse
- `caml_list_map(f, list)` - Map function
- `caml_list_fold_left(f, init, list)` - Left fold

### Additional Modules

#### `option.lua` - Option Type

OCaml Option module operations.

#### `result.lua` - Result Type

OCaml Result module operations (`Ok`/`Error`).

#### `lazy.lua` - Lazy Evaluation

OCaml lazy value support.

#### `fail.lua` - Exception Handling

OCaml exception raising and handling.

#### `gc.lua` - Garbage Collection

GC control and finalization.

#### `weak.lua` - Weak References

Weak arrays, hash tables, and sets.

#### `obj.lua` - Obj Module

OCaml object system primitives.

#### `fun.lua` - Function Utilities

Function composition and application.

#### `io.lua` - Input/Output

File I/O operations.

---

## Compatibility

### Supported Lua Versions

| Version | Status | Notes |
|---------|--------|-------|
| **Lua 5.1** | ✅ 100% | Fully compatible, requires `compat_bit.lua` for bitops |
| **Lua 5.4** | ✅ 100% | Native bitwise operators, best standard Lua target |
| **LuaJIT** | ✅ 79% | High performance (100-300x faster), minor edge cases |
| **Luau** | ❌ Not supported | Readonly `_G`, require() restrictions |

### Compatibility Features

**`compat_bit.lua`** - Cross-version bitwise operations:

- Lua 5.1: Falls back to arithmetic implementation or `bit32`/`bit` library
- Lua 5.2/5.3: Uses `bit32` library
- Lua 5.4: Uses native bitwise operators (`&`, `|`, `~`, `<<`, `>>`)
- LuaJIT: Uses `bit` library

All runtime modules automatically handle version differences.

### Testing

Run compatibility tests:

```bash
cd runtime/lua

# Test on Lua 5.1
./test_lua51_full.sh

# Test on LuaJIT
./test_all_luajit.sh

# Run individual module test
lua5.4 test_array.lua
```

---

## Performance

### Benchmark Results

Performance benchmarks on modern hardware (ops/sec):

| Operation | Lua 5.1 | Lua 5.4 | LuaJIT |
|-----------|---------|---------|--------|
| Integer add | 5.7M | 7.7M | **2.2B** |
| Integer mul | 5.7M | 7.8M | **2.0B** |
| Integer div | 4.1M | 5.8M | **2.5B** |
| Bitwise and | 0.7M | 6.6M | **2.5B** |
| Float operations | 4-11M | 6-16M | **1.3-2.4B** |
| Array get | 9.7M | 16M | **2.5B** |
| Array set | 9.0M | 15M | **1.4B** |
| List operations | 0.2-3.7M | 0.3-7.5M | **0.6-1.3B** |

**Key Takeaways**:
- **LuaJIT** provides 100-300x speedup with JIT compilation
- **Lua 5.4** is 20-50% faster than Lua 5.1 (native bitops, optimizations)
- **Bitwise operations** see the largest improvement in 5.4+ (10x over 5.1)

### Running Benchmarks

```bash
cd runtime/lua

# Run benchmarks
lua5.1 benchmarks.lua
lua5.4 benchmarks.lua
luajit benchmarks.lua
```

### Optimization Tips

1. **Use LuaJIT** - Massive performance gains for compute-heavy code
2. **Minimize table allocations** - Lists and arrays allocate tables
3. **Prefer arrays over lists** - Arrays have better cache locality
4. **Use local variables** - Lua optimizes local variable access
5. **Profile your code** - Use LuaJIT's profiler to find bottlenecks

---

## Migration from js_of_ocaml

If you're familiar with **js_of_ocaml**, lua_of_ocaml follows similar patterns:

### Similarities

| Aspect | js_of_ocaml | lua_of_ocaml |
|--------|-------------|--------------|
| **Input** | OCaml bytecode | OCaml bytecode |
| **Compilation** | Bytecode → JS | Bytecode → Lua |
| **Runtime** | `runtime/js/` | `runtime/lua/` |
| **Module pattern** | Modular JS files | Modular Lua files |
| **Primitives** | External FFI | External FFI |

### Key Differences

#### 1. Type Representations

**JavaScript (js_of_ocaml)**:
- `unit` → `0`
- `bool` → `0` (false) / `1` (true)
- `None` → `0`, `Some x` → `[0, x]`
- Lists → `[0, hd, tl]`

**Lua (lua_of_ocaml)**:
- `unit` → `0`
- `bool` → `0` (false) / `1` (true)
- `None` → `0`, `Some x` → `{tag=0, x}`
- Lists → `{tag=0, hd, tl}`

Key difference: Lua uses **tables with `tag` field** instead of arrays.

#### 2. Arrays

**JavaScript**: Arrays are 0-indexed, same as OCaml
**Lua**: Arrays are **1-indexed by convention**, but runtime uses **0-indexed** tables for OCaml compatibility

```lua
-- OCaml array [|1; 2; 3|]
-- Stored as: {[0]=1, [1]=2, [2]=3}
```

#### 3. Module System

**JavaScript**: `require()` or ES6 imports
**Lua**: `require()` (no relative path needed in most versions)

```lua
local core = require("core")
local ints = require("ints")
```

#### 4. Performance Characteristics

| Target | Optimization | Typical Speedup |
|--------|-------------|-----------------|
| **JavaScript** | V8 JIT, SpiderMonkey JIT | 10-100x over bytecode |
| **Lua (standard)** | Bytecode interpreter | 1-2x over OCaml bytecode |
| **LuaJIT** | Trace-based JIT | 100-300x over Lua 5.1 |

**Recommendation**: Use LuaJIT for production deployments.

---

## Troubleshooting

### Common Issues

#### Issue: "module 'core' not found"

**Cause**: Runtime modules not in Lua's `package.path`

**Solution**: Add runtime directory to path:

```bash
# In your shell
export LUA_PATH="path/to/runtime/lua/?.lua;;"

# Or in Lua code
package.path = package.path .. ";path/to/runtime/lua/?.lua"
```

#### Issue: "attempt to perform arithmetic on a nil value"

**Cause**: Missing module or primitive

**Solution**: Ensure all required runtime modules are loaded:

```lua
local core = require("core")
local ints = require("ints")
local array = require("array")
-- etc.
```

#### Issue: "Undefined primitive: caml_xxx"

**Cause**: Primitive not implemented in runtime

**Solution**: Check which primitives are needed:

```bash
# See which primitives your bytecode uses
strings hello.byte | grep caml_
```

Add missing primitive to appropriate runtime module.

#### Issue: Different behavior on LuaJIT vs Lua 5.4

**Cause**: Bitwise operation edge cases (signed vs unsigned)

**Example**: `0xFFFFFFFF` may be `-1` on LuaJIT (signed) but `4294967295` on Lua 5.4 (unsigned)

**Solution**: Both are semantically equivalent in 32-bit two's complement. Use `compat_bit.lua` for consistent behavior.

### Getting Help

- **Issues**: https://github.com/ocsigen/js_of_ocaml/issues
- **Documentation**: See `RUNTIME.md`, `LUA.md`, `COMPAT.md`
- **Tests**: Look at `test_*.lua` files for usage examples

---

## Examples

### Neovim Plugin Example

```ocaml
(* neovim_plugin.ml *)

(* Define Lua FFI *)
external vim_api_call : string -> 'a array -> 'b = "vim_api_call"

let set_keymap mode lhs rhs =
  vim_api_call "nvim_set_keymap"
    [|mode; lhs; rhs; [("noremap", true)]|]

let setup () =
  set_keymap "n" "<leader>h" ":echo 'Hello from OCaml!'<CR>"

let () = setup ()
```

Compile and use in Neovim:

```bash
lua_of_ocaml neovim_plugin.byte -o plugin.lua
```

```lua
-- In init.lua
require("plugin")
```

### List Processing

```ocaml
let sum_list lst =
  List.fold_left (+) 0 lst

let double_list lst =
  List.map (fun x -> x * 2) lst

let () =
  let numbers = [1; 2; 3; 4; 5] in
  let doubled = double_list numbers in
  let total = sum_list doubled in
  Printf.printf "Total: %d\n" total
```

### Working with Options

```ocaml
let safe_divide a b =
  if b = 0 then None
  else Some (a / b)

let () =
  match safe_divide 10 2 with
  | Some result -> Printf.printf "Result: %d\n" result
  | None -> print_endline "Division by zero"
```

---

## Next Steps

- Read **RUNTIME.md** for detailed runtime API specifications
- See **LUA.md** for implementation roadmap and task tracking
- Check **COMPAT.md** for Lua version compatibility details
- Browse `runtime/lua/test_*.lua` for comprehensive usage examples
- Run `benchmarks.lua` to understand performance characteristics

Happy coding with lua_of_ocaml! 🐫🌙
