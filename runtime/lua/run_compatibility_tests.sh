#!/usr/bin/env bash
# Simple Lua Version Compatibility Test Runner
# Tests runtime modules across Lua 5.1, 5.4, and LuaJIT

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Test files
TESTS=(test_core.lua test_ints.lua test_mlBytes.lua test_array.lua test_fail.lua test_obj.lua test_float.lua)

# Lua variants
VARIANTS=("lua5_1" "lua5_4" "luajit")
VARIANT_NAMES=("Lua 5.1" "Lua 5.4" "LuaJIT")

echo "╔════════════════════════════════════════════╗"
echo "║  Lua Runtime Compatibility Test Summary    ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Run tests for each variant
for i in "${!VARIANTS[@]}"; do
    variant="${VARIANTS[$i]}"
    name="${VARIANT_NAMES[$i]}"

    echo "Testing with $name..."
    echo "----------------------------------------"

    # Get version
    nix run "nixpkgs#$variant" -- -v 2>&1 | head -1
    echo ""

    passed=0
    failed=0

    for test in "${TESTS[@]}"; do
        if [ ! -f "$test" ]; then
            echo "  ⊘ SKIP $test (not found)"
            continue
        fi

        # Run test with timeout
        if timeout 5 nix run "nixpkgs#$variant" -- "$test" > /tmp/lua_test_out.txt 2>&1; then
            # Check for failures in output
            if grep -q "✗" /tmp/lua_test_out.txt 2>/dev/null; then
                echo "  ✗ FAIL $test"
                ((failed++))
                grep "✗" /tmp/lua_test_out.txt | head -3 | sed 's/^/      /'
            elif grep -q "All tests passed" /tmp/lua_test_out.txt 2>/dev/null; then
                echo "  ✓ PASS $test"
                ((passed++))
            else
                echo "  ? UNKNOWN $test"
            fi
        else
            echo "  ✗ ERROR $test (timeout or crash)"
            ((failed++))
        fi
    done

    echo ""
    echo "  Results: $passed passed, $failed failed"
    echo ""
done

# Create compatibility matrix
echo "╔════════════════════════════════════════════╗"
echo "║         Compatibility Matrix               ║"
echo "╚════════════════════════════════════════════╝"
echo ""
printf "%-15s %-10s %-10s %-10s\n" "Module" "Lua 5.1" "Lua 5.4" "LuaJIT"
echo "-------------------------------------------------------"

for test in "${TESTS[@]}"; do
    [ ! -f "$test" ] && continue

    module="${test%.lua}"
    module="${module#test_}"
    printf "%-15s" "$module"

    for variant in "${VARIANTS[@]}"; do
        if timeout 5 nix run "nixpkgs#$variant" -- "$test" > /tmp/lua_test_out.txt 2>&1; then
            if grep -q "All tests passed" /tmp/lua_test_out.txt 2>/dev/null; then
                printf " %-10s" "✓"
            else
                printf " %-10s" "✗"
            fi
        else
            printf " %-10s" "✗"
        fi
    done
    echo ""
done

echo ""
echo "Legend: ✓ = Pass, ✗ = Fail"
