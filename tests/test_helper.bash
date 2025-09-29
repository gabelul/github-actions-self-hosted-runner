#!/usr/bin/env bash

# GitHub Self-Hosted Runner Test Helper
# This file provides common functions and setup for all BATS tests

# Load BATS testing libraries
load '/tmp/bats-support/load'
load '/tmp/bats-assert/load'
load '/tmp/bats-file/load'

# Project paths
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCRIPTS_DIR="$PROJECT_ROOT/scripts"
readonly TEST_FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures"
readonly TEST_MOCKS_DIR="$PROJECT_ROOT/tests/mocks"

# Test configuration
export GITHUB_RUNNER_TEST_MODE=true
export TEST_TEMP_DIR="${BATS_TEST_TMPDIR:-/tmp}/github-runner-test-$$"

# Mock variables for testing
export MOCK_GITHUB_TOKEN="ghp_test1234567890abcdef1234567890abcdef12"
export MOCK_GITHUB_REPO="testorg/testrepo"
export MOCK_RUNNER_NAME="test-runner"

# Setup function called before each test
setup() {
    # Create temporary test directory
    mkdir -p "$TEST_TEMP_DIR"

    # Set up test environment variables
    export HOME="$TEST_TEMP_DIR/home"
    export XDG_CONFIG_HOME="$TEST_TEMP_DIR/.config"

    # Create mock home directory
    mkdir -p "$HOME/.github-runner"

    # Prevent actual system modifications during tests
    export GITHUB_RUNNER_DRY_RUN=true

    # Mock system commands that might cause issues in tests
    export PATH="$TEST_MOCKS_DIR:$PATH"
}

# Teardown function called after each test
teardown() {
    # Clean up temporary directory
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Helper function to create a mock script response
create_mock_response() {
    local command="$1"
    local response="$2"
    local exit_code="${3:-0}"

    cat > "$TEST_MOCKS_DIR/$command" << EOF
#!/bin/bash
echo "$response"
exit $exit_code
EOF
    chmod +x "$TEST_MOCKS_DIR/$command"
}

# Helper function to create a mock configuration file
create_mock_config() {
    local config_file="$1"
    local content="$2"

    mkdir -p "$(dirname "$config_file")"
    echo "$content" > "$config_file"
}

# Helper function to simulate GitHub API responses
mock_github_api() {
    local endpoint="$1"
    local response="$2"
    local status_code="${3:-200}"

    # Create mock curl command that responds to GitHub API calls
    cat > "$TEST_MOCKS_DIR/curl" << EOF
#!/bin/bash
if [[ "\$*" == *"$endpoint"* ]]; then
    echo "$response"
    exit $(( status_code >= 400 ? 1 : 0 ))
else
    # Fall back to real curl for other requests
    exec /usr/bin/curl "\$@"
fi
EOF
    chmod +x "$TEST_MOCKS_DIR/curl"
}

# Helper function to check if a command was called with specific arguments
assert_command_called() {
    local command="$1"
    local expected_args="$2"
    local call_log="$TEST_TEMP_DIR/${command}_calls.log"

    if [[ ! -f "$call_log" ]]; then
        fail "Command '$command' was never called"
    fi

    if ! grep -q "$expected_args" "$call_log"; then
        fail "Command '$command' was not called with expected arguments: $expected_args"
    fi
}

# Helper function to create a logging mock command
create_logging_mock() {
    local command="$1"
    local call_log="$TEST_TEMP_DIR/${command}_calls.log"

    cat > "$TEST_MOCKS_DIR/$command" << EOF
#!/bin/bash
echo "\$@" >> "$call_log"
# Execute the real command if it exists and is safe
if command -v "/usr/bin/$command" >/dev/null 2>&1; then
    exec "/usr/bin/$command" "\$@"
fi
EOF
    chmod +x "$TEST_MOCKS_DIR/$command"
}

# Helper function to skip tests that require root privileges
skip_if_not_root() {
    if [[ $EUID -ne 0 ]]; then
        skip "This test requires root privileges"
    fi
}

# Helper function to skip tests on macOS
skip_if_macos() {
    if [[ "$(uname)" == "Darwin" ]]; then
        skip "This test is not supported on macOS"
    fi
}

# Helper function to check if Docker is available
skip_if_no_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        skip "Docker is not available"
    fi
}

# Helper function to validate script output contains expected patterns
assert_output_contains() {
    local pattern="$1"
    if [[ "$output" != *"$pattern"* ]]; then
        fail "Output does not contain expected pattern: $pattern"
    fi
}

# Helper function to validate script output does not contain patterns
assert_output_not_contains() {
    local pattern="$1"
    if [[ "$output" == *"$pattern"* ]]; then
        fail "Output contains unexpected pattern: $pattern"
    fi
}

# Helper function to validate exit code
assert_exit_code() {
    local expected_code="$1"
    if [[ "$status" -ne "$expected_code" ]]; then
        fail "Expected exit code $expected_code, got $status"
    fi
}

# Helper function to create a minimal runner configuration for testing
create_test_runner_config() {
    local runner_name="${1:-test-runner}"
    local config_dir="$HOME/.github-runner"

    mkdir -p "$config_dir"

    cat > "$config_dir/config" << EOF
GITHUB_TOKEN=$MOCK_GITHUB_TOKEN
GITHUB_REPO=$MOCK_GITHUB_REPO
RUNNER_NAME=$runner_name
RUNNER_LABELS=self-hosted,test
EOF

    # Create mock token file
    echo "$MOCK_GITHUB_TOKEN" > "$config_dir/token"
    chmod 600 "$config_dir/token"
}

# Helper function to simulate a running GitHub Actions runner
simulate_running_runner() {
    local runner_name="${1:-test-runner}"
    local pid="$$"

    # Create mock process files
    mkdir -p "$TEST_TEMP_DIR/proc/$pid"
    echo "github-runner" > "$TEST_TEMP_DIR/proc/$pid/comm"

    # Mock pgrep to return our test PID
    cat > "$TEST_MOCKS_DIR/pgrep" << EOF
#!/bin/bash
if [[ "\$*" == *"github-runner"* ]]; then
    echo "$pid"
    exit 0
else
    exit 1
fi
EOF
    chmod +x "$TEST_MOCKS_DIR/pgrep"
}

# Load project-specific helper functions
if [[ -f "$PROJECT_ROOT/tests/project_helpers.bash" ]]; then
    source "$PROJECT_ROOT/tests/project_helpers.bash"
fi