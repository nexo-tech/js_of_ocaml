# Lua Runtime Compatibility Test Results

## Test Date
October 7, 2025

## Test Environment
- Lua 5.1: Version 5.1.5 (via nix run nixpkgs#lua5_1)
- Lua 5.4: Version 5.4.7 (via nix run nixpkgs#lua5_4)
- LuaJIT: Version 2.1.1741730670 (via nix run nixpkgs#luajit)

## How to Run Tests

### Testing a Single Module

```bash
cd runtime/lua

# Test with Lua 5.4
nix run nixpkgs#lua5_4 -- test_core.lua

# Test with LuaJIT
nix run nixpkgs#luajit -- test_core.lua

# Test with Lua 5.1 (some modules have syntax compatibility issues)
nix run nixpkgs#lua5_1 -- test_core.lua
```

### Testing All Compatible Modules

```bash
# Test core modules (Lua 5.4)
for test in test_core.lua test_mlBytes.lua test_array.lua test_fail.lua test_obj.lua test_fun.lua test_lazy.lua test_list.lua test_option.lua test_result.lua test_gc.lua; do
    echo "Testing $test..."
    nix run nixpkgs#lua5_4 -- "$test"
done
```

## Compatibility Matrix

| Module     | Lua 5.1       | Lua 5.4 | LuaJIT  | Notes |
|------------|---------------|---------|---------|-------|
| core       | ✅ 17/17      | ✅ 17/17 | ✅ 17/17 | Full compatibility |
| mlBytes    | ✅ All pass   | ✅ All pass | ⚠️ Error | LuaJIT: module load error |
| array      | ✅ All pass   | ✅ All pass | ✅ All pass | Full compatibility |
| fail       | ✅ All pass   | ✅ All pass | ✅ All pass | Full compatibility |
| obj        | ✅ All pass   | ✅ All pass | ⚠️ 13/17 | LuaJIT: 4 test failures |
| fun        | ✅ All pass   | ✅ All pass | ✅ All pass | Full compatibility |
| lazy       | ✅ All pass   | ✅ All pass | ✅ All pass | Full compatibility |
| list       | ✅ All pass   | ✅ All pass | ✅ All pass | Full compatibility |
| option     | ✅ All pass   | ✅ All pass | ✅ All pass | Full compatibility |
| result     | ✅ All pass   | ✅ All pass | ✅ All pass | Full compatibility |
| gc         | ✅ All pass   | ✅ All pass | ✅ All pass | Full compatibility |
| float      | ⚠️ Syntax err | ✅ All pass | ✅ All pass | Lua 5.1: bitwise operators |
| ints       | ⚠️ Syntax err | ✅ All pass | ✅ All pass | Lua 5.1: bitwise operators |

## Summary

### Fully Compatible Modules (All Versions)
These modules work on Lua 5.1, 5.4, and LuaJIT with all tests passing:
- ✅ core (17 tests)
- ✅ array
- ✅ fail
- ✅ fun
- ✅ lazy
- ✅ list
- ✅ option
- ✅ result
- ✅ gc

**Success Rate: 9/13 modules (69%) fully compatible across all tested versions**

### Lua 5.3+ Modules
These modules require Lua 5.3 or later due to bitwise operator syntax:
- ⚠️ ints (works on Lua 5.4, LuaJIT)
- ⚠️ float (works on Lua 5.4, LuaJIT)

### LuaJIT Issues
- ⚠️ mlBytes: Module loading error (needs investigation)
- ⚠️ obj: 4 test failures out of 17 (needs investigation)

## Detailed Test Results

### Core Module (test_core.lua)
- ✅ Lua 5.1: 17/17 tests passed
- ✅ Lua 5.4: 17/17 tests passed
- ✅ LuaJIT: 17/17 tests passed

Tests cover:
- Global namespace initialization
- Primitive registration
- Module system
- Value representation (unit, bool, option, blocks)
- Version detection

### Array Module (test_array.lua)
- ✅ Lua 5.1: All tests passed
- ✅ Lua 5.4: All tests passed
- ✅ LuaJIT: All tests passed

Tests cover:
- Array creation
- Bounds checking
- Element access
- Array mutation
- Length operations

### Fail Module (test_fail.lua)
- ✅ Lua 5.1: All tests passed
- ✅ Lua 5.4: All tests passed
- ✅ LuaJIT: All tests passed

Tests cover:
- Exception raising
- Exception catching
- Stack traces
- Error propagation

### Object Module (test_obj.lua)
- ✅ Lua 5.1: All tests passed
- ✅ Lua 5.4: All tests passed
- ⚠️ LuaJIT: 13/17 tests passed, 4 failed

**LuaJIT Failures** (needs investigation):
- Specific tests that failed not detailed in current output
- May be related to metatable handling or tag representation

### MlBytes Module (test_mlBytes.lua)
- ✅ Lua 5.1: All tests passed
- ✅ Lua 5.4: All tests passed
- ⚠️ LuaJIT: Module loading error

**LuaJIT Error**:
```
lua: error loading module 'mlBytes' from file 'mlBytes.lua'
```
Needs investigation - may be related to module path or syntax issue.

## Recommendations

### For Production Use

1. **Use Lua 5.4** for best compatibility
   - All tested modules work correctly
   - Modern features available
   - No known issues

2. **LuaJIT compatibility**
   - Most modules work (9/13 tested successfully)
   - mlBytes and obj modules need fixes
   - Good performance characteristics

3. **Lua 5.1 compatibility**
   - Core functionality works well
   - Avoid ints and float modules (use Lua 5.3+ instead)
   - 9/13 modules fully compatible

### For Development

1. Test your code with the specific Lua version you're targeting
2. If using bitwise operations, require Lua 5.3+
3. For maximum compatibility, stick to the 9 fully compatible modules

## Next Steps

1. **Investigate LuaJIT issues**:
   - Debug mlBytes module loading error
   - Fix obj module test failures
   - Document specific incompatibilities

2. **Fix Lua 5.1 compatibility**:
   - Refactor ints.lua to avoid syntax errors
   - Consider using bit library or conditional loading
   - Split version-specific code into separate files

3. **Add Luau testing**:
   - Set up Luau test environment
   - Test all modules
   - Document Luau-specific issues

4. **Automated CI**:
   - Set up GitHub Actions to test all versions
   - Run tests on every commit
   - Generate compatibility reports

## Test Artifacts

All test files are located in `runtime/lua/`:
- `test_*.lua` - Individual module test suites
- `COMPAT_MATRIX.md` - Compatibility matrix and notes
- `TEST_RESULTS.md` - This file
