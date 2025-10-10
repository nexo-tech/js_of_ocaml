#!/usr/bin/env bash
# Comprehensive LuaJIT compatibility test runner

echo "======================================================================"
echo "LuaJIT Full Compatibility Test Suite"
echo "======================================================================"

if ! command -v luajit &> /dev/null; then
    # Try nix
    LUAJIT="nix run nixpkgs#luajit --"
else
    LUAJIT="luajit"
fi

# Get LuaJIT version
echo ""
$LUAJIT -e "print('LuaJIT Version: ' .. jit.version); print('JIT Status: ' .. (jit.status() and 'enabled' or 'disabled'))"
echo ""

# Test files
tests=(
    "test_core.lua"
    "test_compat_bit.lua"
    "test_ints.lua"
    "test_float.lua"
    "test_mlBytes.lua"
    "test_array.lua"
    "test_obj.lua"
    "test_list.lua"
    "test_option.lua"
    "test_result.lua"
    "test_lazy.lua"
    "test_fun.lua"
    "test_fail.lua"
    "test_gc.lua"
)

passed=0
failed=0
total=${#tests[@]}

echo "Core Runtime Modules:"
echo "----------------------------------------------------------------------"

for test in "${tests[@]}"; do
    if [ ! -f "$test" ]; then
        echo "✗ $test - FILE NOT FOUND"
        ((failed++))
        continue
    fi

    printf "%-30s ... " "$test"

    # Run test and capture output
    output=$($LUAJIT "$test" 2>&1)
    exit_code=$?

    # Check for success
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "All tests passed"; then
        # Parse test count
        test_count=$(echo "$output" | grep "Tests passed:" | sed 's/[^0-9]*\([0-9]*\).*/\1/')
        echo "✓ PASS ($test_count tests)"
        ((passed++))
    elif [ $exit_code -eq 0 ] && echo "$output" | grep -q "tests passed"; then
        echo "✓ PASS"
        ((passed++))
    else
        echo "✗ FAIL"
        ((failed++))
        # Show error if verbose
        if [ "$1" = "-v" ] || [ "$1" = "--verbose" ]; then
            echo "$output" | head -20
            echo ""
        fi
    fi
done

echo ""
echo "======================================================================"
echo "Summary"
echo "======================================================================"
echo "Total modules: $total"
echo "Passed: $passed"
echo "Failed: $failed"
echo "Success rate: $(awk "BEGIN {printf \"%.1f\", ($passed/$total)*100}")%"
echo ""

if [ $failed -eq 0 ]; then
    echo "✓ All modules passed on LuaJIT!"
    echo "✓ Full compatibility verified"
    exit 0
else
    echo "✗ Some modules failed"
    echo ""
    echo "Run with -v or --verbose for detailed output"
    echo "Or run individual tests:"
    for test in "${tests[@]}"; do
        output=$($LUAJIT "$test" 2>&1)
        if [ $? -ne 0 ] || ! echo "$output" | grep -q "All tests passed\|tests passed"; then
            echo "  $LUAJIT $test"
        fi
    done
    exit 1
fi
