#!/bin/bash

# Token Management Test Suite
# Tests all token management functionality without requiring real GitHub tokens

set -euo pipefail

# Change to project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test configuration
readonly TEST_DIR="/tmp/github-runner-test-$$"
readonly ORIGINAL_HOME="$HOME"

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Setup test environment
setup_test_env() {
    log_info "Setting up test environment..."

    # Create isolated test environment
    mkdir -p "$TEST_DIR"

    # Set HOME to test directory for isolated testing
    export HOME="$TEST_DIR"
    export RUNNER_CONFIG_DIR="$TEST_DIR/.github-runner/config"

    log_info "Test environment: $TEST_DIR"
    log_info "Test HOME: $HOME"
}

# Cleanup test environment
cleanup_test_env() {
    log_info "Cleaning up test environment..."
    export HOME="$ORIGINAL_HOME"
    rm -rf "$TEST_DIR"
}

# Run a test
run_test() {
    local test_name="$1"
    local test_function="$2"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log_test "Running: $test_name"

    if $test_function; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi
    echo ""
}

# Test 1: List tokens when no directory exists
test_list_tokens_no_directory() {
    local output
    output=$(./setup.sh --list-tokens 2>&1)

    if echo "$output" | grep -q "No token directory found"; then
        return 0
    else
        echo "Expected 'No token directory found' in output"
        echo "Got: $output"
        return 1
    fi
}

# Test 2: List tokens when directory exists but no tokens
test_list_tokens_empty_directory() {
    # Create empty directory
    mkdir -p "$HOME/.github-runner/config"

    local output
    output=$(./setup.sh --list-tokens 2>&1)

    if echo "$output" | grep -q "No saved tokens found"; then
        return 0
    else
        echo "Expected 'No saved tokens found' in output"
        echo "Got: $output"
        return 1
    fi
}

# Test 3: Help message includes new commands
test_help_includes_token_commands() {
    local output
    output=$(./setup.sh --help 2>&1)

    local missing_commands=()

    if ! echo "$output" | grep -q "\-\-list-tokens"; then
        missing_commands+=("--list-tokens")
    fi

    if ! echo "$output" | grep -q "\-\-test-token"; then
        missing_commands+=("--test-token")
    fi

    if ! echo "$output" | grep -q "\-\-add-token"; then
        missing_commands+=("--add-token")
    fi

    if [[ ${#missing_commands[@]} -eq 0 ]]; then
        return 0
    else
        echo "Missing commands in help: ${missing_commands[*]}"
        return 1
    fi
}

# Test 4: Test token command requires repository argument
test_test_token_requires_repo() {
    local output
    output=$(./setup.sh --test-token 2>&1 || true)

    if echo "$output" | grep -q "Repository required for token testing"; then
        return 0
    else
        echo "Expected error about repository required"
        echo "Got: $output"
        return 1
    fi
}

# Test 5: Add token command requires repository argument
test_add_token_requires_repo() {
    local output
    output=$(./setup.sh --add-token 2>&1 || true)

    if echo "$output" | grep -q "Repository or organization required"; then
        return 0
    else
        echo "Expected error about repository required"
        echo "Got: $output"
        return 1
    fi
}

# Test 6: Validate token access function with mock
test_validate_token_access_function() {
    # This test verifies the function exists and can be called
    # We can't test the actual API calls without real tokens

    # Source the setup script to access functions
    set +e  # Temporarily disable error exit
    source ./setup.sh >/dev/null 2>&1
    set -e  # Re-enable error exit

    # Check if the function exists
    if declare -f validate_token_access >/dev/null; then
        return 0
    else
        echo "validate_token_access function not found"
        return 1
    fi
}

# Test 7: Token creation guidance includes new warnings
test_token_guidance_includes_warnings() {
    # Check if the guidance text exists in the script file itself
    if grep -q "IMPORTANT: This gives access to ALL your repositories" ./setup.sh; then
        return 0
    else
        echo "Expected improved token guidance not found in script"
        return 1
    fi
}

# Test 8: Examples section includes token management
test_examples_include_token_management() {
    local output
    output=$(./setup.sh --help 2>&1)

    if echo "$output" | grep -q "Token management"; then
        return 0
    else
        echo "Expected 'Token management' section in examples"
        return 1
    fi
}

# Main test runner
main() {
    echo "GitHub Self-Hosted Runner - Token Management Test Suite"
    echo "======================================================="
    echo ""

    setup_test_env

    # Run all tests
    run_test "List tokens (no directory)" test_list_tokens_no_directory
    run_test "List tokens (empty directory)" test_list_tokens_empty_directory
    run_test "Help includes token commands" test_help_includes_token_commands
    run_test "Test token requires repository" test_test_token_requires_repo
    run_test "Add token requires repository" test_add_token_requires_repo
    run_test "Validate token access function" test_validate_token_access_function
    run_test "Token guidance includes warnings" test_token_guidance_includes_warnings
    run_test "Examples include token management" test_examples_include_token_management

    cleanup_test_env

    # Print results
    echo "======================================================"
    echo "Test Results:"
    echo "  Total Tests: $TOTAL_TESTS"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed!${NC}"
        exit 1
    fi
}

# Run main function
main "$@"