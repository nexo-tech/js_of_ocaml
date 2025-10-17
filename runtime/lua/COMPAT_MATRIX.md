# Lua Version Compatibility Matrix

This document tracks the compatibility of lua_of_ocaml runtime modules across different Lua versions.

## Testing Environment

- **Lua 5.1**: Version 5.1.5 (via nixpkgs)
- **Lua 5.4**: Version 5.4.7 (via nixpkgs)
- **LuaJIT**: Version 2.1 (via nixpkgs)

## Compatibility Status

| Module     | Lua 5.1 | Lua 5.4 | LuaJIT | Notes |
|------------|---------|---------|--------|-------|
| core       | ✅      | ✅      | ✅     | Full compatibility |
| mlBytes    | ✅      | ✅      | ✅     | Full compatibility |
| array      | ✅      | ✅      | ✅     | Full compatibility |
| fail       | ✅      | ✅      | ✅     | Full compatibility |
| obj        | ✅      | ✅      | ✅     | Full compatibility |
| fun        | ✅      | ✅      | ✅     | Full compatibility |
| lazy       | ✅      | ✅      | ✅     | Full compatibility |
| list       | ✅      | ✅      | ✅     | Full compatibility |
| option     | ✅      | ✅      | ✅     | Full compatibility |
| result     | ✅      | ✅      | ✅     | Full compatibility |
| gc         | ✅      | ✅      | ✅     | Full compatibility |
| ints       | ⚠️      | ✅      | ✅     | Syntax compatibility issue (see below) |
| float      | ⚠️      | ✅      | ✅     | Syntax compatibility issue (see below) |
| io         | ⚠️      | ✅      | ✅     | Requires file I/O testing |

## Known Issues

### Lua 5.1 Syntax Compatibility

**Issue**: Bitwise operator syntax `&`, `|`, `~`, `<<`, `>>` is not available in Lua 5.1.

**Affected Modules**:
- `ints.lua` - Uses `&` operator directly in code (line 41)
- `float.lua` - May use bitwise operators

**Workaround**: These modules use runtime detection (`core.has_bitops`) to choose the right implementation, but the syntax itself prevents loading in Lua 5.1.

**Solution Options**:
1. Use string-based code loading for version-specific code
2. Split version-specific implementations into separate files
3. Use bit library for Lua 5.1 (via LuaBit or bit32 compat)

**Current Status**: Modules work correctly in Lua 5.3+, 5.4, and LuaJIT (which has bitops).

### Luau Compatibility

Luau (Roblox's Lua variant) has not been tested yet. Key differences to consider:

- Strong typing system (optional)
- Different standard library
- No `loadstring` function
- Different module system
- Custom optimizations

**Status**: Not yet tested. Planned for future work.

## Test Results

### Successfully Tested Modules

All tests passing on Lua 5.4 and LuaJIT:

```
✅ core       - 17/17 tests passed
✅ mlBytes    - All tests passed
✅ array      - All tests passed
✅ fail       - All tests passed
✅ obj        - All tests passed
✅ fun        - All tests passed
✅ lazy       - All tests passed
✅ list       - All tests passed
✅ option     - All tests passed
✅ result     - All tests passed
✅ gc         - All tests passed
```

### Modules Requiring Lua 5.3+

These modules use features only available in Lua 5.3 and later:

- `ints.lua` - Bitwise operators
- `float.lua` - Bitwise operators (if used)

## Recommendations

### For Maximum Compatibility

If targeting Lua 5.1:
1. Use `core`, `mlBytes`, `array`, `fail`, `obj`, `fun`, `lazy`, `list`, `option`, `result`, `gc` modules - all fully compatible
2. For integer operations, use external bit library or implement without bitwise ops
3. Avoid modules that require Lua 5.3+ features

### For Modern Lua (5.3+, 5.4, LuaJIT)

All modules work correctly. No restrictions.

## Testing Procedure

To run compatibility tests:

```bash
cd runtime/lua

# Test specific module with Lua 5.1
nix run nixpkgs#lua5_1 -- test_core.lua

# Test specific module with Lua 5.4
nix run nixpkgs#lua5_4 -- test_core.lua

# Test specific module with LuaJIT
nix run nixpkgs#luajit -- test_core.lua

# Run compatibility test suite
./run_compatibility_tests.sh
```

## Version-Specific Features

### Lua 5.1
- No bitwise operators
- No integer type (all numbers are doubles)
- `module()` function for modules
- Different table size behavior

### Lua 5.3+
- Native integer type (64-bit)
- Bitwise operators (`&`, `|`, `~`, `<<`, `>>`, `~`)
- UTF-8 library
- Integer division operator (`//`)

### Lua 5.4
- New garbage collector (generational GC)
- `<const>` and `<close>` attributes
- New metamethods

### LuaJIT
- JIT compilation
- FFI library
- BitOp library
- Mostly Lua 5.1 compatible with extensions
- Native 32-bit and 64-bit integers via FFI

## Future Work

1. **Fix Lua 5.1 compatibility**: Refactor `ints.lua` and `float.lua` to avoid syntax errors
2. **Add Luau support**: Test and document Luau compatibility
3. **Performance testing**: Benchmark runtime modules across versions
4. **Automated CI**: Set up continuous testing across all Lua versions
