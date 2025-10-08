# Lua Runtime

This directory contains the Lua runtime for lua_of_ocaml.

The runtime implements OCaml primitives and standard library functions in Lua,
enabling compiled OCaml bytecode to execute in Lua environments including **Neovim**, **LuaJIT**, and embedded systems.

## Documentation

- **[USER_GUIDE.md](USER_GUIDE.md)** - Complete user guide with installation, quick start, API reference, performance benchmarks, and troubleshooting
- **[RUNTIME.md](../../RUNTIME.md)** - Detailed runtime API design and OCaml-Lua interop specifications
- **[COMPAT_MATRIX.md](COMPAT_MATRIX.md)** - Lua version compatibility matrix
- **[TEST_RESULTS.md](TEST_RESULTS.md)** - Comprehensive test results across Lua versions
- **[LUAJIT_NOTES.md](LUAJIT_NOTES.md)** - LuaJIT-specific compatibility notes

## Quick Start

```bash
# Compile OCaml to Lua
ocamlc -o program.byte program.ml
lua_of_ocaml program.byte -o program.lua

# Run with Lua
lua program.lua
# Or with LuaJIT (100-300x faster!)
luajit program.lua
# Or in Neovim
nvim -c "luafile program.lua"
```

## Runtime Modules

### Core Modules (Implemented ✅)

- **`core.lua`** - Module system, primitive registration, type encodings
- **`ints.lua`** - 32-bit integer operations (add, mul, div, bitwise ops)
- **`float.lua`** - IEEE 754 float operations (modf, ldexp, frexp, classify)
- **`mlBytes.lua`** - Bytes/string operations (create, get, set, conversions)
- **`array.lua`** - OCaml array operations (make, get, set, length)
- **`list.lua`** - OCaml list operations (cons, map, fold, rev)
- **`option.lua`** - Option type operations (None, Some)
- **`result.lua`** - Result type operations (Ok, Error)
- **`lazy.lua`** - Lazy evaluation support
- **`fail.lua`** - Exception handling
- **`gc.lua`** - Garbage collection integration
- **`weak.lua`** - Weak references (arrays, hash tables, sets)
- **`obj.lua`** - Object system primitives
- **`fun.lua`** - Function utilities
- **`io.lua`** - File I/O operations
- **`compat_bit.lua`** - Cross-version bitwise operations

### Testing

```bash
# Test all modules on Lua 5.1
./test_lua51_full.sh

# Test all modules on LuaJIT
./test_all_luajit.sh

# Run individual module test
lua test_array.lua
lua test_list.lua
```

### Benchmarking

```bash
# Run performance benchmarks
lua benchmarks.lua
luajit benchmarks.lua  # Much faster!
```

## Compatibility

| Version | Status | Performance | Notes |
|---------|--------|-------------|-------|
| **Lua 5.1** | ✅ 100% | 5-13M ops/sec | Requires `compat_bit.lua` |
| **Lua 5.4** | ✅ 100% | 7-22M ops/sec | Native bitops, best standard Lua |
| **LuaJIT** | ✅ 79% | 1.3-2.5B ops/sec | 100-300x faster, minor edge cases |

See [USER_GUIDE.md](USER_GUIDE.md) for detailed compatibility information.

## Performance

**LuaJIT performance highlights** (ops/sec):
- Integer operations: **2.2B ops/sec** (100x faster than Lua 5.1)
- Array operations: **2.5B ops/sec** (250x faster)
- List operations: **1.3B ops/sec** (300x faster)

See [benchmarks.lua](benchmarks.lua) for comprehensive benchmarks.

## Contributing

When adding new runtime modules:
1. Follow the naming convention: `modulename.lua`
2. Add corresponding test: `test_modulename.lua`
3. Update this README and USER_GUIDE.md
4. Ensure compatibility with Lua 5.1, 5.4, and LuaJIT
5. Add benchmarks if performance-critical

## License

Same as js_of_ocaml (LGPL 2.1 with static linking exception)
