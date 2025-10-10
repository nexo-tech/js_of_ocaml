#!/usr/bin/env bash
# Lua Version Compatibility Test Suite
# Tests all runtime modules across Lua 5.1, 5.4, and LuaJIT

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Lua variants to test
LUA_VARIANTS=(
    "lua5_1:Lua 5.1"
    "lua5_4:Lua 5.4"
    "luajit:LuaJIT"
)

# Test files to run
TEST_FILES=(
    "test_core.lua"
    "test_ints.lua"
    "test_mlBytes.lua"
    "test_array.lua"
    "test_fail.lua"
    "test_fun.lua"
    "test_obj.lua"
    "test_float.lua"
    "test_gc.lua"
    "test_lazy.lua"
    "test_list.lua"
    "test_option.lua"
    "test_result.lua"
)

# Track results
declare -A results
total_tests=0
passed_tests=0
failed_tests=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Lua_of_ocaml Runtime Compatibility Test Suite         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to run a test file with a specific Lua variant
run_test() {
    local variant_pkg="$1"
    local variant_name="$2"
    local test_file="$3"
    local test_path="$SCRIPT_DIR/$test_file"

    if [ ! -f "$test_path" ]; then
        echo -e "  ${YELLOW}⊘ SKIP${NC} $test_file (file not found)"
        return 0
    fi

    # Run the test with nix
    local output
    local exit_code=0

    # Set LUA_PATH to find modules in current directory
    export LUA_PATH="$SCRIPT_DIR/?.lua;;"

    output=$(cd "$SCRIPT_DIR" && nix run "nixpkgs#$variant_pkg" -- "$test_file" 2>&1) || exit_code=$?

    if [ $exit_code -eq 0 ]; then
        # Check if output indicates test failures
        if echo "$output" | grep -q "✗"; then
            echo -e "  ${RED}✗ FAIL${NC} $test_file"
            results["$variant_name:$test_file"]="FAIL"
            ((failed_tests++))
            ((total_tests++))
            # Show failed test details
            echo "$output" | grep "✗" | sed 's/^/    /'
            return 1
        else
            echo -e "  ${GREEN}✓ PASS${NC} $test_file"
            results["$variant_name:$test_file"]="PASS"
            ((passed_tests++))
            ((total_tests++))
            return 0
        fi
    else
        echo -e "  ${RED}✗ ERROR${NC} $test_file (exit code: $exit_code)"
        results["$variant_name:$test_file"]="ERROR"
        ((failed_tests++))
        ((total_tests++))
        # Show error details
        echo "$output" | head -5 | sed 's/^/    /'
        return 1
    fi
}

# Run all tests for all variants
for variant_spec in "${LUA_VARIANTS[@]}"; do
    IFS=':' read -r variant_pkg variant_name <<< "$variant_spec"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing with $variant_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Get Lua version info
    version_info=$(nix run "nixpkgs#$variant_pkg" -- -v 2>&1 | head -1)
    echo -e "  Version: $version_info"
    echo ""

    for test_file in "${TEST_FILES[@]}"; do
        run_test "$variant_pkg" "$variant_name" "$test_file"
    done

    echo ""
done

# Print compatibility matrix
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Compatibility Matrix                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Print header
printf "%-20s" "Test Module"
for variant_spec in "${LUA_VARIANTS[@]}"; do
    IFS=':' read -r _ variant_name <<< "$variant_spec"
    printf "%-15s" "$variant_name"
done
echo ""

# Print separator
printf "%-20s" "--------------------"
for variant_spec in "${LUA_VARIANTS[@]}"; do
    printf "%-15s" "-------------"
done
echo ""

# Print results for each test file
for test_file in "${TEST_FILES[@]}"; do
    # Extract module name (remove test_ prefix and .lua suffix)
    module_name="${test_file#test_}"
    module_name="${module_name%.lua}"
    printf "%-20s" "$module_name"

    for variant_spec in "${LUA_VARIANTS[@]}"; do
        IFS=':' read -r _ variant_name <<< "$variant_spec"
        key="$variant_name:$test_file"
        result="${results[$key]:-SKIP}"

        case "$result" in
            PASS)
                printf "${GREEN}%-15s${NC}" "✓ PASS"
                ;;
            FAIL)
                printf "${RED}%-15s${NC}" "✗ FAIL"
                ;;
            ERROR)
                printf "${RED}%-15s${NC}" "✗ ERROR"
                ;;
            SKIP)
                printf "${YELLOW}%-15s${NC}" "⊘ SKIP"
                ;;
        esac
    done
    echo ""
done

echo ""

# Print summary
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    Test Summary                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Total Tests:   $total_tests"
echo -e "  ${GREEN}Passed:        $passed_tests${NC}"
echo -e "  ${RED}Failed:        $failed_tests${NC}"
echo ""

# Calculate pass rate
if [ $total_tests -gt 0 ]; then
    pass_rate=$((passed_tests * 100 / total_tests))
    echo -e "  Pass Rate:     ${pass_rate}%"
    echo ""

    if [ $failed_tests -eq 0 ]; then
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  All compatibility tests passed! Runtime is cross-platform ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
        exit 0
    else
        echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  Some tests failed. Check compatibility issues above.      ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}No tests were run.${NC}"
    exit 1
fi
