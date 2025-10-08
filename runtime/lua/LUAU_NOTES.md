# Luau Compatibility Notes

## Overview

Luau is Roblox's custom Lua implementation, based on Lua 5.1 with significant extensions and modifications. This document outlines Luau-specific differences and compatibility considerations for the lua_of_ocaml runtime.

## Luau Version Information

- **Version**: 0.693 (as of this testing)
- **Base**: Lua 5.1 compatible syntax
- **Key Features**: Gradual typing, performance optimizations, extended standard library
- **Official**: https://luau-lang.org/

## Key Differences from Standard Lua

### 1. Function Availability

#### ✅ Available in Luau (Unexpected!)

- `loadstring()` - Available! (despite documentation suggesting otherwise)
- `setfenv()` / `getfenv()` - Available!
- `unpack()` - Available as global function
- `table.unpack()` - Also available
- `table.getn()` - Available!

#### ❌ Not Available in Luau

- `load()` - Not available (but `loadstring` works)
- `module()` - Not available (deprecated anyway)

**Impact on lua_of_ocaml**:
- Much better compatibility than expected!
- `compat_bit.lua` can use `loadstring` on Luau

### 2. Module System - CRITICAL DIFFERENCE

**Luau requires explicit path prefixes for `require()`:**

```lua
-- ❌ Does NOT work in Luau:
require("core")
require("mymodule")

-- ✅ MUST use explicit paths:
require("./core")
require("../parent/module")
require("@lune/fs")  -- For Luau runtime libraries
```

**Valid prefixes**:
- `./` - Relative to current file
- `../` - Parent directory
- `@` - Runtime library prefix (Luau-specific)

**Impact on lua_of_ocaml**:
- **CRITICAL**: All modules must use `require("./modulename")` instead of `require("modulename")`
- This is the BIGGEST compatibility hurdle for Luau
- All runtime modules need updating

### 3. Extended Standard Library

Luau provides additional functions not present in standard Lua:

#### Table Functions
- `table.create(count, value)` - Pre-allocate table with specific size
- `table.find(table, value, init)` - Find value in array part
- `table.clear(table)` - Clear all entries efficiently
- `table.move(a1, f, e, t, a2)` - Move elements between tables (Lua 5.3 backport)
- `table.freeze(table)` - Make table immutable
- `table.isfrozen(table)` - Check if table is frozen

#### Math Functions
- `math.clamp(x, min, max)` - Clamp value to range
- `math.round(x)` - Round to nearest integer
- `math.sign(x)` - Return sign of number (-1, 0, 1)

#### String Functions
- `string.split(s, sep)` - Split string by separator

#### Buffer Type
- `buffer` - New buffer type for efficient byte manipulation
- Various buffer manipulation functions

### 4. Type System

Luau has a gradual type system that can be optionally enabled:

```lua
--!strict          -- Enable strict type checking
--!nonstrict       -- Disable type checking (default)
```

**Type Annotations** (optional):
```lua
function add(x: number, y: number): number
    return x + y
end

local myTable: {string} = {"a", "b", "c"}
```

**Impact**: Type annotations are optional and can be added without breaking Lua 5.1 compatibility (they're comments in standard Lua).

### 5. Performance Features

#### Native Code Generation
- `--codegen` flag enables native code generation
- Significantly faster than standard Lua JIT
- Similar benefits to LuaJIT

#### Optimizations
- Vector types for 3D math
- Improved table implementation
- Better memory management

### 6. Sandboxing

Luau is designed for sandboxed environments (Roblox):
- Limited file I/O
- Restricted OS functions
- No C module loading

## Compatibility Strategy

### Phase 1: Identify Blockers

**Known Issues**:
1. `compat_bit.lua` uses `loadstring` - needs alternative implementation
2. Module system may need adjustments
3. Tests using `load()`/`loadstring()` need refactoring

### Phase 2: Workarounds

#### For `loadstring` in compat_bit.lua:

**Current Code** (Lua 5.3+):
```lua
if has_native_bitops then
  local load_fn = load or loadstring
  M.band = load_fn("return function(a, b) return a & b end")()
end
```

**Luau Workaround**:
```lua
if has_native_bitops and (load or loadstring) then
  -- Use loadstring on standard Lua
  local load_fn = load or loadstring
  M.band = load_fn("return function(a, b) return a & b end")()
elseif has_native_bitops then
  -- Luau doesn't have loadstring but has native bitops in a different way
  -- Need to use bit32 library or provide fallback
  M.band = bit32.band  -- Luau provides bit32
end
```

### Phase 3: Testing

Use `test_luau_runner.sh` to systematically test all modules:
```bash
./test_luau_runner.sh
```

With verbose output:
```bash
VERBOSE=1 ./test_luau_runner.sh
```

## Expected Compatibility

### ✅ Likely Compatible (No Changes Needed)

- `core.lua` - Pure Lua, no dynamic loading
- `ints.lua` - Uses compat_bit (needs compat_bit fix)
- `float.lua` - Standard math operations
- `mlBytes.lua` - Table and string operations
- `array.lua` - Table operations
- `obj.lua` - Uses `table.unpack` (available in Luau)
- `list.lua` - Standard list operations
- `option.lua` - Standard option type
- `result.lua` - Standard result type
- `lazy.lua` - Uses tables and functions
- `fail.lua` - Exception handling
- `fun.lua` - Functional programming primitives

### ⚠️ Needs Modification

- `compat_bit.lua` - Uses `loadstring` for Lua 5.3+ operators
  - **Fix**: Detect Luau and use `bit32` library
  - Luau provides `bit32` from Lua 5.2

### ❌ May Not Work

- `gc.lua` - If it uses advanced metatable features or unsupported functions
- Tests that use `loadstring` for test generation

## Implementation Plan

### Step 1: Detect Luau

```lua
-- Detect Luau
local is_luau = _VERSION == "Luau"
```

### Step 2: Modify compat_bit.lua

```lua
local M = {}

-- Detect Lua version and available bit libraries
local is_luau = _VERSION == "Luau"
local has_native_bitops = _VERSION >= "Lua 5.3" and not is_luau
local has_bit32 = bit32 ~= nil
local has_bit = bit ~= nil

if has_native_bitops and (load or loadstring) then
  -- Lua 5.3+ with native operators and loadstring support
  local load_fn = load or loadstring
  M.band = load_fn("return function(a, b) return a & b end")()
  -- ...
elseif has_bit32 then
  -- Lua 5.2 or Luau (both have bit32)
  M.band = bit32.band
  M.bor = bit32.bor
  -- ...
elseif has_bit then
  -- LuaJIT
  M.band = bit.band
  -- ...
else
  -- Lua 5.1 arithmetic fallback
  M.band = function(a, b)
    -- ...
  end
end

-- Set implementation name
if is_luau then
  M.implementation = "luau"
elseif has_native_bitops then
  M.implementation = "native"
elseif has_bit32 then
  M.implementation = "bit32"
elseif has_bit then
  M.implementation = "luajit"
else
  M.implementation = "arithmetic"
end
```

### Step 3: Test on Luau

```bash
cd runtime/lua
./test_luau_runner.sh
```

### Step 4: Fix Remaining Issues

Based on test results, fix any remaining compatibility issues.

## Performance Considerations

### Luau vs Standard Lua

Luau is generally faster than standard Lua 5.1/5.4 due to:
- Native code generation (`--codegen`)
- Optimized table implementation
- Better type inference

### Luau vs LuaJIT

- **LuaJIT**: Generally faster for numeric computations
- **Luau**: Faster for table-heavy operations
- **Luau**: Better for sandboxed environments

### Recommendations

For **Roblox development**:
- Use Luau (only option)
- Add type annotations for better performance
- Use `table.create()` for pre-allocated tables

For **general purpose**:
- **Performance-critical**: Use LuaJIT
- **Sandboxed environments**: Use Luau
- **Compatibility**: Use Lua 5.1

## Testing Results

Will be populated after running `test_luau_runner.sh`.

### Expected Status

| Module | Status | Notes |
|--------|--------|-------|
| core | ✅ | Should work |
| compat_bit | ⚠️ | Needs loadstring fix |
| ints | ⚠️ | Depends on compat_bit |
| float | ✅ | Should work |
| mlBytes | ✅ | Should work |
| array | ✅ | Should work |
| obj | ✅ | Uses table.unpack (available) |
| list | ✅ | Should work |
| option | ✅ | Should work |
| result | ✅ | Should work |
| lazy | ✅ | Should work |
| fun | ❓ | Unknown |
| fail | ✅ | Should work |
| gc | ❓ | Unknown |

## Resources

- **Official Luau Documentation**: https://luau-lang.org/
- **Luau GitHub**: https://github.com/luau-lang/luau
- **Compatibility Guide**: https://luau-lang.org/compatibility
- **Performance Benchmarks**: https://luau-lang.org/performance

## Next Steps

1. Run `test_luau_runner.sh` to establish baseline
2. Fix `compat_bit.lua` to detect and support Luau
3. Update tests to avoid `loadstring` where possible
4. Document actual compatibility results
5. Add Luau-specific optimizations (optional type annotations)
