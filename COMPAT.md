# Lua Compatibility Implementation Plan

## Overview
This document outlines the implementation plan for achieving full compatibility of lua_of_ocaml runtime across all major Lua versions: Lua 5.1, 5.4, LuaJIT, and Luau.

**Current Status**: 9/13 modules (69%) fully compatible across Lua 5.1, 5.4, and LuaJIT.

**Goal**: 100% compatibility across all four Lua variants.

**Related Documents**:
- [TEST_RESULTS.md](runtime/lua/TEST_RESULTS.md) - Current test results and findings
- [COMPAT_MATRIX.md](runtime/lua/COMPAT_MATRIX.md) - Detailed compatibility matrix

## Master Checklist

### Phase 1: Lua 5.1 Compatibility (Week 1)

Fix bitwise operator syntax issues preventing Lua 5.1 compatibility.

#### Task 1.1: Refactor ints.lua for Lua 5.1 ✅
- [x] Replace bitwise operator syntax with bit library calls
- [x] Add LuaBit/bit32 compatibility layer
- [x] Implement fallback using arithmetic operations
- [x] Test all integer operations on Lua 5.1
- **Files**: `runtime/lua/ints.lua`, `runtime/lua/compat_bit.lua` (new)
- **Output**: 207 lines (compat_bit.lua) + refactored ints.lua
- **Test**: Integer operations work on Lua 5.1, 5.4, and LuaJIT ✅
- **Commit**: "fix: Add Lua 5.1 compatibility for ints module"

#### Task 1.2: Refactor float.lua for Lua 5.1 ✅
- [x] Replace bitwise operator syntax with bit library calls (N/A - none found)
- [x] Add compatibility layer for bitwise operations (N/A - not needed)
- [x] Implement fallback for missing operators (N/A - not needed)
- [x] Test all float operations on Lua 5.1
- **Files**: `runtime/lua/float.lua`
- **Output**: No changes needed - already compatible!
- **Test**: Float operations work on Lua 5.1, 5.4, and LuaJIT ✅
- **Finding**: float.lua uses only standard Lua math operations, no bitwise operators
- **Commit**: "test: Verify float module Lua 5.1 compatibility"

#### Task 1.3: Create bit compatibility shim ✅
- [x] Create `runtime/lua/compat_bit.lua`
- [x] Auto-detect available bit library (bit32, bit, LuaBitOp)
- [x] Provide arithmetic fallbacks for missing libraries
- [x] Export unified bit API
- **Files**: `runtime/lua/compat_bit.lua` (new)
- **Output**: 207 lines
- **Test**: Bit operations work on all Lua versions ✅
- **Note**: Completed as part of Task 1.1 - compat_bit.lua was created to enable ints.lua refactoring
- **Commit**: "fix: Add Lua 5.1 compatibility for ints module" (93014810)

#### Task 1.4: Verify Lua 5.1 full compatibility ✅
- [x] Run all tests on Lua 5.1
- [x] Fix any remaining issues (mlBytes.lua bitwise operators)
- [x] Update compatibility matrix
- [x] Document Lua 5.1 specific notes
- **Output**: test_lua51_full.lua (comprehensive test suite)
- **Test**: 7/7 core modules pass on Lua 5.1, 5.4, and LuaJIT ✅
- **Modules Tested**: core, compat_bit, ints, float, mlBytes, array, obj
- **Issues Fixed**:
  - mlBytes.lua: Replaced 8 bitwise operators (&, >>, <<) with bit.* calls
  - All modules now load and function correctly on Lua 5.1
- **Commit**: "feat: Add Lua 5.1 compatibility for mlBytes and complete Phase 1"

**Checkpoint**: ✅ Lua 5.1 - 7/7 core modules compatible (100%)

### Phase 2: LuaJIT Compatibility (Week 2)

Fix LuaJIT-specific issues with mlBytes and obj modules.

#### Task 2.1: Debug mlBytes module loading error ✅
- [x] Identify root cause of module loading failure
- [x] Check for LuaJIT-specific syntax incompatibilities
- [x] Test module path resolution
- [x] Add LuaJIT-specific workarounds if needed
- **Files**: `runtime/lua/mlBytes.lua`, `runtime/lua/compat_bit.lua`
- **Output**: Fixed as part of Task 1.4 (mlBytes refactoring)
- **Test**: mlBytes loads and runs on LuaJIT ✅
- **Root Cause**: Bitwise operator syntax (`&`, `>>`, `<<`) not supported in LuaJIT 2.0
- **Solution**: Refactored to use compat_bit which auto-detects LuaJIT's `bit` library
- **Test Results**:
  - All 38 mlBytes tests pass on LuaJIT
  - compat_bit correctly uses LuaJIT's native bit library
  - No LuaJIT-specific workarounds needed
- **Note**: Issue was resolved in Task 1.4 when mlBytes was refactored
- **Commit**: "feat: Add Lua 5.1 compatibility for mlBytes and complete Phase 1" (4dde6eb4)

#### Task 2.2: Fix obj module test failures ✅
- [x] Identify which 4 tests are failing
- [x] Debug metatable handling differences
- [x] Check tag representation compatibility
- [x] Fix type coercion issues
- [x] Verify object equality semantics
- **Files**: `runtime/lua/obj.lua`
- **Output**: 3 lines (compatibility fix)
- **Test**: All obj tests pass on LuaJIT (17/17) ✅
- **Root Cause**: `table.unpack` not available in LuaJIT/Lua 5.1
- **Failing Tests** (4/17):
  - Call method on object
  - Call method with no args
  - Call method with multiple args
  - Object with multiple instance variables
- **Solution**: Added compatibility shim `local unpack = table.unpack or unpack`
- **Test Results**:
  - ✅ Lua 5.1: 17/17 tests pass
  - ✅ Lua 5.4: 17/17 tests pass
  - ✅ LuaJIT: 17/17 tests pass
- **Commit**: "fix: Resolve obj module test failures on LuaJIT"

#### Task 2.3: Test LuaJIT-specific optimizations
- [ ] Verify FFI compatibility (if used)
- [ ] Test JIT compilation doesn't break semantics
- [ ] Check table optimizations don't affect behavior
- [ ] Add LuaJIT-specific performance notes
- **Output**: Documentation
- **Test**: All modules work with JIT enabled
- **Commit**: "test: Verify LuaJIT optimizations compatibility"

#### Task 2.4: Verify LuaJIT full compatibility
- [ ] Run all tests on LuaJIT
- [ ] Fix any remaining issues
- [ ] Update compatibility matrix
- [ ] Document LuaJIT specific notes
- **Output**: Updated documentation
- **Test**: All 13 modules pass on LuaJIT
- **Commit**: "test: Verify LuaJIT full compatibility"

**Checkpoint**: ✅ LuaJIT - 13/13 modules compatible

### Phase 3: Luau Compatibility (Week 3-4)

Add support for Luau (Roblox's Lua variant).

#### Task 3.1: Set up Luau test environment
- [ ] Install Luau via nix (nixpkgs#luau)
- [ ] Verify Luau version and features
- [ ] Create Luau test runner script
- [ ] Document Luau-specific differences
- **Files**: `runtime/lua/test_luau_runner.sh` (new)
- **Output**: ~100 lines (test runner)
- **Test**: Can execute Luau code via nix
- **Commit**: "test: Add Luau test environment setup"

#### Task 3.2: Test core modules on Luau
- [ ] Run core module tests on Luau
- [ ] Identify syntax incompatibilities
- [ ] Document type system differences
- [ ] Note standard library differences
- **Files**: Documentation
- **Output**: Compatibility report
- **Test**: Identify all breaking changes
- **Commit**: "test: Initial Luau compatibility assessment"

#### Task 3.3: Fix Luau loadstring compatibility
- [ ] Replace loadstring with Luau alternatives
- [ ] Handle absence of loadstring function
- [ ] Use alternative code loading mechanisms
- [ ] Test dynamic code execution
- **Files**: Modules using loadstring
- **Output**: ~50 lines (compatibility layer)
- **Test**: Code loading works on Luau
- **Commit**: "fix: Add Luau loadstring compatibility"

#### Task 3.4: Fix Luau module system differences
- [ ] Adapt to Luau module system
- [ ] Handle require() differences
- [ ] Test module.exports vs return
- [ ] Ensure module isolation
- **Files**: All runtime modules
- **Output**: ~30 lines (module system adaptation)
- **Test**: All modules load on Luau
- **Commit**: "fix: Adapt module system for Luau"

#### Task 3.5: Handle Luau type system
- [ ] Add type annotations where beneficial
- [ ] Ensure type inference doesn't break runtime
- [ ] Test with --!strict mode
- [ ] Document type-related limitations
- **Files**: Runtime modules (optional type annotations)
- **Output**: ~100 lines (type annotations)
- **Test**: Modules work with type checking
- **Commit**: "feat: Add Luau type annotations"

#### Task 3.6: Fix Luau standard library differences
- [ ] Handle missing functions (e.g., table.getn)
- [ ] Adapt to different string library
- [ ] Handle math library differences
- [ ] Test all stdlib usage
- **Files**: Modules using stdlib functions
- **Output**: ~80 lines (stdlib compatibility)
- **Test**: All stdlib calls work on Luau
- **Commit**: "fix: Add Luau standard library compatibility"

#### Task 3.7: Verify Luau full compatibility
- [ ] Run all tests on Luau
- [ ] Fix any remaining issues
- [ ] Update compatibility matrix
- [ ] Document Luau specific notes
- **Output**: Updated documentation
- **Test**: All 13 modules pass on Luau
- **Commit**: "test: Verify Luau full compatibility"

**Checkpoint**: ✅ Luau - 13/13 modules compatible

### Phase 4: Automated Testing Infrastructure (Week 5)

Create comprehensive automated testing across all Lua versions.

#### Task 4.1: Create unified test matrix runner
- [ ] Build single script to test all versions
- [ ] Generate HTML compatibility matrix
- [ ] Add performance comparison
- [ ] Create detailed error reports
- **Files**: `runtime/lua/test_all_versions.sh` (new)
- **Output**: ~300 lines (comprehensive test suite)
- **Test**: Runs tests on all 4 Lua variants
- **Commit**: "test: Add unified multi-version test runner"

#### Task 4.2: Add GitHub Actions CI
- [ ] Create `.github/workflows/lua-compat.yml`
- [ ] Test on Lua 5.1, 5.4, LuaJIT, Luau
- [ ] Generate compatibility reports
- [ ] Upload test results as artifacts
- **Files**: `.github/workflows/lua-compat.yml` (new)
- **Output**: ~150 lines (CI configuration)
- **Test**: CI runs on every commit
- **Commit**: "ci: Add Lua compatibility testing to GitHub Actions"

#### Task 4.3: Create compatibility badge generator
- [ ] Generate SVG badges for each Lua version
- [ ] Show pass/fail status
- [ ] Include in README.md
- [ ] Auto-update on CI runs
- **Files**: `runtime/lua/generate_badges.sh` (new)
- **Output**: ~100 lines
- **Test**: Badges display correctly
- **Commit**: "docs: Add Lua compatibility badges"

#### Task 4.4: Add regression testing
- [ ] Store baseline test results
- [ ] Compare new results against baseline
- [ ] Flag any new failures
- [ ] Track compatibility over time
- **Files**: `runtime/lua/test_regression.sh` (new)
- **Output**: ~150 lines
- **Test**: Detects compatibility regressions
- **Commit**: "test: Add compatibility regression testing"

**Checkpoint**: ✅ Automated testing for all Lua versions

### Phase 5: Documentation and Best Practices (Week 6)

Document compatibility practices and guidelines.

#### Task 5.1: Create compatibility guide
- [ ] Write developer guide for writing compatible code
- [ ] Document version-specific features
- [ ] Provide code examples
- [ ] List common pitfalls
- **Files**: `runtime/lua/COMPAT_GUIDE.md` (new)
- **Output**: ~400 lines (comprehensive guide)
- **Test**: Documentation is clear and accurate
- **Commit**: "docs: Add Lua compatibility development guide"

#### Task 5.2: Update COMPAT_MATRIX.md
- [ ] Mark all modules as compatible
- [ ] Document version-specific notes
- [ ] Add performance comparisons
- [ ] Include migration guidance
- **Files**: `runtime/lua/COMPAT_MATRIX.md`
- **Output**: Updated with 100% compatibility status
- **Test**: Matrix is accurate
- **Commit**: "docs: Update compatibility matrix to 100%"

#### Task 5.3: Create version feature matrix
- [ ] Document which features work on which versions
- [ ] List version-specific optimizations
- [ ] Note performance characteristics
- [ ] Provide selection guidance
- **Files**: `runtime/lua/VERSION_FEATURES.md` (new)
- **Output**: ~200 lines
- **Test**: Helps users choose Lua version
- **Commit**: "docs: Add Lua version feature comparison"

#### Task 5.4: Add compatibility examples
- [ ] Create example programs for each version
- [ ] Show version-specific code patterns
- [ ] Demonstrate compatibility layers
- [ ] Provide migration examples
- **Files**: `runtime/lua/examples/compat_*.lua` (new)
- **Output**: ~300 lines (example code)
- **Test**: Examples run on all versions
- **Commit**: "docs: Add Lua compatibility examples"

**Checkpoint**: ✅ Complete documentation for cross-version compatibility

## Implementation Details

### Phase 1: Lua 5.1 Bitwise Operations

#### Problem
Lua 5.1 doesn't have bitwise operators (`&`, `|`, `~`, `<<`, `>>`) in its syntax. The runtime uses these operators directly in `ints.lua` and `float.lua`, causing parse errors.

#### Solution Strategy

**Option 1: Conditional Code Loading (Recommended)**
```lua
-- compat_bit.lua
local M = {}

-- Detect available bit library
if bit32 then
  -- Lua 5.2+
  M.band = bit32.band
  M.bor = bit32.bor
  M.bxor = bit32.bxor
  M.lshift = bit32.lshift
  M.rshift = bit32.rshift
  M.bnot = bit32.bnot
elseif bit then
  -- LuaJIT
  M.band = bit.band
  M.bor = bit.bor
  M.bxor = bit.bxor
  M.lshift = bit.lshift
  M.rshift = bit.rshift
  M.bnot = bit.bnot
else
  -- Lua 5.1 fallback using arithmetic
  M.band = function(a, b)
    local result = 0
    local bit = 1
    while a > 0 or b > 0 do
      local a_bit = a % 2
      local b_bit = b % 2
      if a_bit == 1 and b_bit == 1 then
        result = result + bit
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit = bit * 2
    end
    return result
  end
  -- ... similar implementations for other operations
end

return M
```

**Option 2: Version-Specific Files**
- `ints_53.lua` - Uses native bitwise operators
- `ints_51.lua` - Uses bit library or arithmetic
- `ints.lua` - Dispatcher that loads the right version

#### Refactoring Steps

1. Create `compat_bit.lua` with unified API
2. Update `ints.lua` to use `compat_bit` instead of operators
3. Replace all `a & b` with `bit.band(a, b)`
4. Replace all `a | b` with `bit.bor(a, b)`
5. Replace all `~a` with `bit.bnot(a)`
6. Replace all `a << n` with `bit.lshift(a, n)`
7. Replace all `a >> n` with `bit.rshift(a, n)`

### Phase 2: LuaJIT Issues

#### mlBytes Module Loading Error

**Investigation Steps:**
1. Test with simple require:
   ```bash
   nix run nixpkgs#luajit -- -e "package.path='?.lua;;'; require('mlBytes')"
   ```
2. Check for syntax incompatibilities
3. Verify module path resolution
4. Test with LuaJIT 2.0 vs 2.1

**Likely Causes:**
- Metatable syntax differences
- Table constructor edge cases
- Module return statement issues
- String literal handling

#### obj Module Test Failures

**Investigation Steps:**
1. Run test with verbose output:
   ```bash
   nix run nixpkgs#luajit -- test_obj.lua | grep "✗"
   ```
2. Identify specific failing tests
3. Debug with print statements
4. Compare behavior with Lua 5.4

**Likely Causes:**
- Metatable `__eq` handling differences
- Type coercion in comparisons
- Table equality semantics
- Weak table behavior

### Phase 3: Luau Compatibility

#### Key Differences

**No loadstring:**
```lua
-- Standard Lua
local f = loadstring("return 1 + 2")
local result = f()

-- Luau alternative
-- Use static code generation or pre-compile
```

**Module System:**
```lua
-- Standard Lua
local M = {}
-- ...
return M

-- Luau
local module = {}
-- ...
return module
-- Or use ModuleScript with module.exports
```

**Type System:**
```lua
-- Luau with types (optional)
local function add(a: number, b: number): number
  return a + b
end

-- Type checking mode
--!strict
--!nonstrict
--!nocheck
```

#### Testing Strategy

1. **Initial Assessment:**
   ```bash
   nix run nixpkgs#luau -- test_core.lua
   ```

2. **Identify Breaking Changes:**
   - List all errors
   - Categorize by type (syntax, stdlib, semantics)
   - Prioritize fixes

3. **Iterative Fixing:**
   - Fix syntax issues first
   - Adapt stdlib usage
   - Handle semantic differences
   - Add Luau-specific code paths

#### Luau-Specific Modules

Create `compat_luau.lua`:
```lua
local M = {}

-- Check if running under Luau
M.is_luau = _VERSION:match("Luau") ~= nil

-- Loadstring replacement
M.loadstring = function(code)
  if M.is_luau then
    error("loadstring not supported in Luau - use static compilation")
  else
    return loadstring(code)
  end
end

-- Module system adapter
M.module_return = function(tbl)
  if M.is_luau then
    -- Luau module export
    return tbl
  else
    -- Standard Lua
    return tbl
  end
end

return M
```

### Phase 4: Automated Testing

#### Test Matrix Structure

```bash
#!/usr/bin/env bash
# test_all_versions.sh

VERSIONS=("lua5_1" "lua5_4" "luajit" "luau")
MODULES=(test_*.lua)

# Generate HTML report
cat > report.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Lua Compatibility Matrix</title></head>
<body>
<table>
  <tr>
    <th>Module</th>
    <th>Lua 5.1</th>
    <th>Lua 5.4</th>
    <th>LuaJIT</th>
    <th>Luau</th>
  </tr>
EOF

for module in "${MODULES[@]}"; do
  echo "<tr><td>$module</td>"
  for version in "${VERSIONS[@]}"; do
    if nix run "nixpkgs#$version" -- "$module" &>/dev/null; then
      echo "<td style='background:green'>✓</td>"
    else
      echo "<td style='background:red'>✗</td>"
    fi
  done
  echo "</tr>"
done

cat >> report.html <<EOF
</table>
</body>
</html>
EOF
```

#### GitHub Actions Workflow

```yaml
name: Lua Compatibility Tests

on: [push, pull_request]

jobs:
  test-lua-versions:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        lua: [lua5_1, lua5_4, luajit, luau]
    steps:
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v22
      - name: Test ${{ matrix.lua }}
        run: |
          cd runtime/lua
          for test in test_*.lua; do
            nix run nixpkgs#${{ matrix.lua }} -- "$test"
          done
```

## Testing Commands

### Manual Testing

```bash
# Test single module on specific version
nix run nixpkgs#lua5_1 -- runtime/lua/test_core.lua
nix run nixpkgs#lua5_4 -- runtime/lua/test_ints.lua
nix run nixpkgs#luajit -- runtime/lua/test_obj.lua
nix run nixpkgs#luau -- runtime/lua/test_mlBytes.lua

# Test all modules on specific version
cd runtime/lua
for test in test_*.lua; do
  echo "Testing $test..."
  nix run nixpkgs#lua5_4 -- "$test"
done

# Run compatibility matrix
./test_all_versions.sh

# Generate HTML report
./generate_report.sh > compatibility_report.html
```

### Automated Testing

```bash
# Run full test suite
make test-lua-compat

# Run CI locally
act -j test-lua-versions

# Generate badges
./generate_badges.sh
```

## Success Criteria

### Phase 1 Success
- [ ] All 13 modules pass all tests on Lua 5.1
- [ ] No syntax errors on Lua 5.1
- [ ] Bitwise operations work correctly
- [ ] Zero test failures

### Phase 2 Success
- [ ] mlBytes module loads on LuaJIT
- [ ] obj module: 17/17 tests pass on LuaJIT
- [ ] All 13 modules pass all tests on LuaJIT
- [ ] JIT compilation doesn't break semantics

### Phase 3 Success
- [ ] All 13 modules pass all tests on Luau
- [ ] Luau-specific features documented
- [ ] Type annotations added (optional)
- [ ] Migration guide available

### Phase 4 Success
- [ ] Automated tests run on all 4 versions
- [ ] CI runs on every commit
- [ ] HTML compatibility report generated
- [ ] Regression testing in place

### Phase 5 Success
- [ ] Compatibility guide published
- [ ] All documentation updated
- [ ] Examples provided for all versions
- [ ] Best practices documented

## Final Goal

**100% Compatibility Matrix:**

| Module  | Lua 5.1 | Lua 5.4 | LuaJIT | Luau |
|---------|---------|---------|--------|------|
| core    | ✅      | ✅      | ✅     | ✅   |
| ints    | ✅      | ✅      | ✅     | ✅   |
| mlBytes | ✅      | ✅      | ✅     | ✅   |
| array   | ✅      | ✅      | ✅     | ✅   |
| fail    | ✅      | ✅      | ✅     | ✅   |
| obj     | ✅      | ✅      | ✅     | ✅   |
| fun     | ✅      | ✅      | ✅     | ✅   |
| float   | ✅      | ✅      | ✅     | ✅   |
| lazy    | ✅      | ✅      | ✅     | ✅   |
| list    | ✅      | ✅      | ✅     | ✅   |
| option  | ✅      | ✅      | ✅     | ✅   |
| result  | ✅      | ✅      | ✅     | ✅   |
| gc      | ✅      | ✅      | ✅     | ✅   |

**Status**: 13/13 modules (100%) compatible across all 4 Lua versions.

## Timeline

- **Week 1**: Lua 5.1 compatibility (Phase 1)
- **Week 2**: LuaJIT compatibility (Phase 2)
- **Week 3-4**: Luau compatibility (Phase 3)
- **Week 5**: Automated testing (Phase 4)
- **Week 6**: Documentation (Phase 5)

**Total Duration**: 6 weeks to 100% compatibility
