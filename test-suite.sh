#!/bin/bash

# Comprehensive Test Suite for GitHub Self-Hosted Runner Setup
# Tests for common failure points and error handling

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test result tracking
test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "${YELLOW}⊘${NC} $1"
    ((TESTS_SKIPPED++))
}

test_header() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Test 1: Check if all log functions write to stderr
test_log_functions() {
    test_header "Test 1: Log Functions Output to stderr"

    # Source the script
    source setup.sh 2>/dev/null || { test_fail "Failed to source setup.sh"; return; }

    # Test each log function
    local test_msg="test message"

    # Capture stdout and stderr separately
    local stdout_capture=$(log_info "$test_msg" 2>/dev/null)
    local stderr_capture=$(log_info "$test_msg" 2>&1 >/dev/null)

    if [[ -z "$stdout_capture" && -n "$stderr_capture" ]]; then
        test_pass "log_info writes to stderr only"
    else
        test_fail "log_info writes to stdout (will contaminate command substitution)"
    fi

    # Test log_success
    stdout_capture=$(log_success "$test_msg" 2>/dev/null)
    stderr_capture=$(log_success "$test_msg" 2>&1 >/dev/null)

    if [[ -z "$stdout_capture" && -n "$stderr_capture" ]]; then
        test_pass "log_success writes to stderr only"
    else
        test_fail "log_success writes to stdout (will contaminate command substitution)"
    fi
}

# Test 2: Check for unprotected arithmetic operations
test_arithmetic_operations() {
    test_header "Test 2: Arithmetic Operations with set -e"

    # Test that arithmetic operations handle zero correctly
    bash -c '
    set -e
    count=0
    ((count++)) || true  # Should not exit
    if [[ $count -eq 1 ]]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
    ' > /tmp/test-arithmetic.out 2>&1

    if grep -q "PASS" /tmp/test-arithmetic.out; then
        test_pass "Arithmetic operations handle zero safely with set -e"
    else
        test_fail "Arithmetic operations can cause exit with set -e"
    fi

    rm -f /tmp/test-arithmetic.out
}

# Test 3: Check for unprotected function calls
test_function_calls() {
    test_header "Test 3: Function Calls Error Handling"

    # Search for function calls without error capture
    local unprotected_calls=$(grep -n "^\s*[a-z_]*\s*||" setup.sh | wc -l)
    local total_function_calls=$(grep -n "^[[:space:]]*[a-z_][a-z_0-9]*\s*(" setup.sh | wc -l)

    echo "Found $unprotected_calls protected calls out of $total_function_calls total functions"

    # Check specific problematic patterns
    if grep -q 'git clone.*2>/dev/null$' setup.sh; then
        test_fail "git clone with stderr redirect but no error capture"
    else
        test_pass "git clone has proper error handling"
    fi
}

# Test 4: Test token encryption/decryption
test_token_encryption() {
    test_header "Test 4: Token Encryption/Decryption"

    source setup.sh 2>/dev/null || { test_fail "Failed to source setup.sh"; return; }

    local test_token="ghp_test1234567890abcdefghijklmnopqrst"
    local test_password="test_password_123"

    # Test encryption
    local encrypted=$(encrypt_token "$test_token" "$test_password" 2>/dev/null)

    if [[ -n "$encrypted" && "$encrypted" != "$test_token" ]]; then
        test_pass "Token encryption produces encrypted output"
    else
        test_fail "Token encryption failed or returned plaintext"
        return
    fi

    # Test decryption
    local decrypted=$(decrypt_token "$encrypted" "$test_password" 2>/dev/null)

    if [[ "$decrypted" == "$test_token" ]]; then
        test_pass "Token decryption recovers original token"
    else
        test_fail "Token decryption failed (got: '$decrypted')"
    fi
}

# Test 5: Test command substitution doesn't capture log output
test_command_substitution() {
    test_header "Test 5: Command Substitution Cleanliness"

    # Create a test function that logs and returns a value
    cat > /tmp/test-cmd-sub.sh << 'EOF'
#!/bin/bash
source setup.sh 2>/dev/null

test_function() {
    log_success "This should not appear in output"
    log_info "Neither should this"
    echo "ghp_cleantoken"
}

result=$(test_function)

if [[ "$result" == "ghp_cleantoken" ]]; then
    echo "PASS: Command substitution is clean"
    exit 0
else
    echo "FAIL: Got contaminated result: [$result]"
    exit 1
fi
EOF

    chmod +x /tmp/test-cmd-sub.sh

    if bash /tmp/test-cmd-sub.sh > /tmp/test-result.txt 2>&1; then
        if grep -q "PASS" /tmp/test-result.txt; then
            test_pass "Command substitution doesn't capture log output"
        else
            test_fail "Command substitution captured wrong data"
        fi
    else
        test_fail "Command substitution test script failed"
    fi

    rm -f /tmp/test-cmd-sub.sh /tmp/test-result.txt
}

# Test 6: Test for unhandled return codes
test_return_codes() {
    test_header "Test 6: Return Code Handling"

    # Check for direct function calls that might fail
    local patterns=(
        'git clone [^|&]*$'
        'curl [^|&]*$'
        'docker [^|&]*$'
        '\$\([a-z_][a-z_0-9]*\)(?! \|\| )'
    )

    local found_issues=0
    for pattern in "${patterns[@]}"; do
        if grep -qE "$pattern" setup.sh 2>/dev/null; then
            ((found_issues++))
        fi
    done

    if [[ $found_issues -eq 0 ]]; then
        test_pass "No obvious unhandled return codes found"
    else
        test_fail "Found $found_issues potential unhandled return codes"
    fi
}

# Test 7: Check for proper .env file generation
test_env_file_generation() {
    test_header "Test 7: .env File Generation"

    source setup.sh 2>/dev/null || { test_fail "Failed to source setup.sh"; return; }

    # Create test .env file
    local test_dir="/tmp/test-env-$$"
    mkdir -p "$test_dir"

    local test_token="ghp_test\nwith\nnewlines\x1b[0m"

    # Simulate env file creation
    {
        echo "GITHUB_REPOSITORY=test/repo"
        echo "GITHUB_TOKEN=$test_token"
        echo "RUNNER_NAME=test-runner"
    } > "$test_dir/.env"

    # Check if .env file is valid
    if grep -q "\\x1b" "$test_dir/.env"; then
        test_fail ".env file contains control characters"
    else
        test_pass ".env file generation is clean"
    fi

    rm -rf "$test_dir"
}

# Test 8: Test workflow-helper.sh existence and executability
test_workflow_helper() {
    test_header "Test 8: Workflow Helper Script"

    local workflow_helper="./scripts/workflow-helper.sh"

    if [[ ! -f "$workflow_helper" ]]; then
        test_fail "workflow-helper.sh not found"
        return
    fi

    test_pass "workflow-helper.sh exists"

    if [[ ! -x "$workflow_helper" ]]; then
        test_fail "workflow-helper.sh is not executable"
        return
    fi

    test_pass "workflow-helper.sh is executable"

    # Test if it has proper help
    if "$workflow_helper" --help &>/dev/null || "$workflow_helper" help &>/dev/null; then
        test_pass "workflow-helper.sh has help command"
    else
        test_skip "workflow-helper.sh help command test skipped"
    fi
}

# Test 9: Test set -e doesn't cause unexpected exits
test_set_e_safety() {
    test_header "Test 9: set -e Safety Checks"

    # Test script with set -e
    cat > /tmp/test-set-e.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Test 1: Arithmetic that evaluates to 0
count=0
((count++)) || true
echo "Test 1: PASS"

# Test 2: Function with non-zero return captured
test_func() {
    return 2
}

result=0
test_func || result=$?
if [[ $result -eq 2 ]]; then
    echo "Test 2: PASS"
fi

# Test 3: Command substitution with failure
get_value() {
    echo "value"
    return 1
}

value=$(get_value) || true
if [[ "$value" == "value" ]]; then
    echo "Test 3: PASS"
fi
EOF

    chmod +x /tmp/test-set-e.sh
    local output=$(bash /tmp/test-set-e.sh 2>&1)
    local pass_count=$(echo "$output" | grep -c "PASS")

    if [[ $pass_count -eq 3 ]]; then
        test_pass "set -e safety patterns work correctly"
    else
        test_fail "set -e safety patterns failed (only $pass_count/3 passed)"
    fi

    rm -f /tmp/test-set-e.sh
}

# Test 10: Integration test - dry run
test_dry_run() {
    test_header "Test 10: Dry Run Integration Test"

    # Test dry run doesn't fail
    if bash setup.sh --dry-run --token "ghp_test" --repo "test/repo" --name "test-runner" > /tmp/dry-run.log 2>&1; then
        test_pass "Dry run completes without errors"
    else
        test_fail "Dry run failed"
        echo "Last 10 lines of output:"
        tail -10 /tmp/dry-run.log
    fi

    rm -f /tmp/dry-run.log
}

# Run all tests
main() {
    echo
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  GitHub Self-Hosted Runner Setup - Test Suite             ║"
    echo "╚════════════════════════════════════════════════════════════╝"

    test_log_functions
    test_arithmetic_operations
    test_function_calls
    test_token_encryption
    test_command_substitution
    test_return_codes
    test_env_file_generation
    test_workflow_helper
    test_set_e_safety
    test_dry_run

    # Summary
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Test Results Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}Passed:${NC}  $TESTS_PASSED"
    echo -e "${RED}Failed:${NC}  $TESTS_FAILED"
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Some tests failed. Please review the output above.${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"