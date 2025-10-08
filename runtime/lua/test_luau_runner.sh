#!/usr/bin/env bash
# Luau Test Runner for lua_of_ocaml runtime
#
# This script sets up and runs tests on Luau (Roblox's Lua variant)
# to verify compatibility of the lua_of_ocaml runtime.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LUAU_CMD="${LUAU_CMD:-nix run nixpkgs#luau --}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE="${VERBOSE:-0}"

# Statistics
total_tests=0
passed_tests=0
failed_tests=0
skipped_tests=0

# Print with color
print_color() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Print header
print_header() {
    echo ""
    print_color "$BLUE" "======================================================================"
    print_color "$BLUE" "$1"
    print_color "$BLUE" "======================================================================"
}

# Check if Luau is available
check_luau() {
    print_header "Checking Luau Installation"

    if ! $LUAU_CMD -h > /dev/null 2>&1; then
        print_color "$RED" "Error: Luau not found!"
        print_color "$YELLOW" "Install via: nix-env -iA nixpkgs.luau"
        print_color "$YELLOW" "Or ensure LUAU_CMD environment variable is set correctly"
        exit 1
    fi

    print_color "$GREEN" "✓ Luau is available"
}

# Get Luau version and features
get_luau_info() {
    print_header "Luau Version and Features"

    # Create a temporary test file
    local temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
print("Version: " .. _VERSION)
print("")
print("Standard Library:")
print("  table.create:", table.create ~= nil)
print("  table.find:", table.find ~= nil)
print("  table.clear:", table.clear ~= nil)
print("  math.clamp:", math.clamp ~= nil)
print("  math.round:", math.round ~= nil)
print("  math.sign:", math.sign ~= nil)
print("  string.split:", string.split ~= nil)
print("  buffer (type):", typeof(buffer) ~= "nil")
print("")
print("Missing Functions:")
print("  loadstring:", loadstring ~= nil)
print("  load:", load ~= nil)
print("  setfenv:", setfenv ~= nil)
print("  getfenv:", getfenv ~= nil)
print("  module:", module ~= nil)
print("  unpack (global):", unpack ~= nil)
print("  table.unpack:", table.unpack ~= nil)
print("  table.getn:", table.getn ~= nil)
EOF

    $LUAU_CMD "$temp_file"
    rm -f "$temp_file"
    echo ""
}

# Run a single test file
run_test() {
    local test_file=$1
    local test_name=$(basename "$test_file" .lua)

    ((total_tests++))

    printf "%-35s ... " "$test_name"

    if [ ! -f "$test_file" ]; then
        print_color "$YELLOW" "SKIP (file not found)"
        ((skipped_tests++))
        return
    fi

    # Create a wrapper to handle script execution
    local temp_wrapper=$(mktemp)
    cat > "$temp_wrapper" << EOF
-- Luau compatibility wrapper
package.path = "$SCRIPT_DIR/?.lua;" .. (package.path or "")

-- Run the test
local success, err = pcall(function()
    dofile("$test_file")
end)

if not success then
    print("ERROR: " .. tostring(err))
    os.exit(1)
end
EOF

    # Run the test and capture output
    local output
    local exit_code
    if output=$($LUAU_CMD "$temp_wrapper" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi

    rm -f "$temp_wrapper"

    # Check results
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "All tests passed\|tests passed"; then
        # Extract test count if available
        local test_count=$(echo "$output" | grep -oP "Tests passed: \K\d+" | head -1)
        if [ -n "$test_count" ]; then
            print_color "$GREEN" "✓ PASS ($test_count tests)"
        else
            print_color "$GREEN" "✓ PASS"
        fi
        ((passed_tests++))

        if [ "$VERBOSE" = "1" ]; then
            echo "$output" | sed 's/^/    /'
        fi
    else
        print_color "$RED" "✗ FAIL"
        ((failed_tests++))

        # Show error output
        if [ "$VERBOSE" = "1" ] || [ -n "${SHOW_ERRORS:-}" ]; then
            echo "$output" | grep -A 5 "Error\|error\|FAIL" | sed 's/^/    /' || echo "$output" | head -10 | sed 's/^/    /'
        fi
    fi
}

# Main test execution
run_all_tests() {
    print_header "Running Runtime Module Tests"

    cd "$SCRIPT_DIR"

    # Core modules
    echo "Core Runtime Modules:"
    echo "----------------------------------------------------------------------"
    run_test "test_core.lua"
    run_test "test_compat_bit.lua"
    run_test "test_ints.lua"
    run_test "test_float.lua"
    run_test "test_mlBytes.lua"
    run_test "test_array.lua"
    run_test "test_obj.lua"

    echo ""
    echo "Standard Library Modules:"
    echo "----------------------------------------------------------------------"
    run_test "test_list.lua"
    run_test "test_option.lua"
    run_test "test_result.lua"
    run_test "test_lazy.lua"
    run_test "test_fun.lua"
    run_test "test_fail.lua"
    run_test "test_gc.lua"
}

# Print summary
print_summary() {
    print_header "Test Summary"

    echo "Total tests: $total_tests"
    print_color "$GREEN" "Passed: $passed_tests"
    print_color "$RED" "Failed: $failed_tests"
    if [ $skipped_tests -gt 0 ]; then
        print_color "$YELLOW" "Skipped: $skipped_tests"
    fi

    if [ $total_tests -gt 0 ]; then
        local success_rate=$(awk "BEGIN {printf \"%.1f\", ($passed_tests/$total_tests)*100}")
        echo "Success rate: ${success_rate}%"
    fi

    echo ""

    if [ $failed_tests -eq 0 ] && [ $passed_tests -gt 0 ]; then
        print_color "$GREEN" "✓ All tests passed on Luau!"
        return 0
    elif [ $failed_tests -gt 0 ]; then
        print_color "$RED" "✗ Some tests failed"
        echo ""
        echo "Tips:"
        echo "  - Run with VERBOSE=1 to see detailed output"
        echo "  - Run with SHOW_ERRORS=1 to see error messages"
        echo "  - Check LUAU_NOTES.md for known compatibility issues"
        return 1
    else
        print_color "$YELLOW" "⚠ No tests completed"
        return 1
    fi
}

# Main execution
main() {
    print_header "Luau Test Environment Setup"
    echo "Script directory: $SCRIPT_DIR"
    echo "Luau command: $LUAU_CMD"
    echo ""

    check_luau
    get_luau_info
    run_all_tests
    print_summary
}

# Run main function
main
exit_code=$?

echo ""
print_color "$BLUE" "Test run completed!"
exit $exit_code
