#!/usr/bin/env bash
# Lua Runtime Compatibility Test Runner
# Tests compatible modules across Lua 5.1, 5.4, and LuaJIT

set -e

cd "$(dirname "$0")"

# Modules compatible with all Lua versions
COMPAT_TESTS=(
    "test_core.lua"
    "test_mlBytes.lua"
    "test_array.lua"
    "test_fail.lua"
    "test_obj.lua"
    "test_fun.lua"
    "test_lazy.lua"
    "test_list.lua"
    "test_option.lua"
    "test_result.lua"
    "test_gc.lua"
)

# Modules requiring Lua 5.3+ (have bitwise operators in syntax)
LUA53_TESTS=(
    "test_ints.lua"
    "test_float.lua"
)

# Lua variants
declare -A VARIANTS
VARIANTS[lua5_1]="Lua 5.1"
VARIANTS[lua5_4]="Lua 5.4"
VARIANTS[luajit]="LuaJIT"

echo "╔════════════════════════════════════════════════════╗"
echo "║   Lua_of_ocaml Runtime Compatibility Tests         ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Track results
declare -A results
total=0
passed=0
failed=0

# Test compatible modules on all versions
for variant_pkg in "${!VARIANTS[@]}"; do
    variant_name="${VARIANTS[$variant_pkg]}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Testing with $variant_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Show version
    nix run "nixpkgs#$variant_pkg" -- -v 2>&1 | head -1
    echo ""

    # Test compatible modules
    for test in "${COMPAT_TESTS[@]}"; do
        [ ! -f "$test" ] && continue
        ((total++))

        if timeout 5 nix run "nixpkgs#$variant_pkg" -- "$test" >/tmp/luatest_$$.txt 2>&1; then
            if grep -q "All tests passed" /tmp/luatest_$$.txt; then
                echo "  ✅ PASS  $test"
                results["$variant_name:$test"]="PASS"
                ((passed++))
            else
                echo "  ❌ FAIL  $test"
                results["$variant_name:$test"]="FAIL"
                ((failed++))
                grep "✗" /tmp/luatest_$$.txt | head -2 | sed 's/^/      /'
            fi
        else
            echo "  ❌ ERROR $test"
            results["$variant_name:$test"]="ERROR"
            ((failed++))
            head -2 /tmp/luatest_$$.txt | sed 's/^/      /'
        fi
    done

    # Test Lua 5.3+ modules only on compatible versions
    if [[ "$variant_pkg" != "lua5_1" ]]; then
        echo ""
        echo "  Testing Lua 5.3+ specific modules..."
        for test in "${LUA53_TESTS[@]}"; do
            [ ! -f "$test" ] && continue
            ((total++))

            if timeout 5 nix run "nixpkgs#$variant_pkg" -- "$test" >/tmp/luatest_$$.txt 2>&1; then
                if grep -q "All tests passed" /tmp/luatest_$$.txt; then
                    echo "  ✅ PASS  $test"
                    results["$variant_name:$test"]="PASS"
                    ((passed++))
                else
                    echo "  ❌ FAIL  $test"
                    results["$variant_name:$test"]="FAIL"
                    ((failed++))
                fi
            else
                echo "  ❌ ERROR $test"
                results["$variant_name:$test"]="ERROR"
                ((failed++))
            fi
        done
    else
        echo ""
        echo "  ⚠️  Skipping Lua 5.3+ modules (bitwise operator syntax not supported)"
    fi

    echo ""
done

rm -f /tmp/luatest_$$.txt

# Print compatibility matrix
echo "╔════════════════════════════════════════════════════╗"
echo "║            Compatibility Matrix                    ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

printf "%-20s" "Module"
for variant_name in "Lua 5.1" "Lua 5.4" "LuaJIT"; do
    printf " %-12s" "$variant_name"
done
echo ""

for i in {1..70}; do echo -n "─"; done
echo ""

# Show compatible modules
for test in "${COMPAT_TESTS[@]}"; do
    [ ! -f "$test" ] && continue
    module="${test%.lua}"
    module="${module#test_}"
    printf "%-20s" "$module"

    for variant_name in "Lua 5.1" "Lua 5.4" "LuaJIT"; do
        status="${results[$variant_name:$test]:-SKIP}"
        case "$status" in
            PASS)  printf " %-12s" "✅ PASS" ;;
            FAIL)  printf " %-12s" "❌ FAIL" ;;
            ERROR) printf " %-12s" "❌ ERROR" ;;
            *)     printf " %-12s" "⊘ SKIP" ;;
        esac
    done
    echo ""
done

# Show Lua 5.3+ modules
for test in "${LUA53_TESTS[@]}"; do
    [ ! -f "$test" ] && continue
    module="${test%.lua}"
    module="${module#test_}"
    printf "%-20s" "$module (*)"

    for variant_name in "Lua 5.1" "Lua 5.4" "LuaJIT"; do
        if [[ "$variant_name" == "Lua 5.1" ]]; then
            printf " %-12s" "⚠️  N/A"
        else
            status="${results[$variant_name:$test]:-SKIP}"
            case "$status" in
                PASS)  printf " %-12s" "✅ PASS" ;;
                FAIL)  printf " %-12s" "❌ FAIL" ;;
                ERROR) printf " %-12s" "❌ ERROR" ;;
                *)     printf " %-12s" "⊘ SKIP" ;;
            esac
        fi
    done
    echo ""
done

echo ""
echo "(*) Requires Lua 5.3+ (bitwise operators)"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════╗"
echo "║                  Summary                           ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "  Total Tests:  $total"
echo "  Passed:       $passed"
echo "  Failed:       $failed"

if [ $total -gt 0 ]; then
    pass_rate=$((passed * 100 / total))
    echo "  Pass Rate:    ${pass_rate}%"
fi

echo ""

if [ $failed -eq 0 ]; then
    echo "✅ All compatibility tests passed!"
    echo ""
    echo "See COMPAT_MATRIX.md for detailed compatibility information."
    exit 0
else
    echo "❌ Some tests failed. Check output above for details."
    exit 1
fi
