#!/usr/bin/env bats

# Unit tests for setup.sh script
# Tests the main installation and configuration logic

load '../test_helper'

# Test setup for this file
setup_file() {
    # Ensure mocks directory exists
    mkdir -p "$TEST_MOCKS_DIR"

    # Create basic mocks for system commands
    create_logging_mock "systemctl"
    create_logging_mock "useradd"
    create_logging_mock "usermod"
}

@test "setup.sh exists and is executable" {
    assert_file_exist "$PROJECT_ROOT/setup.sh"
    assert_file_executable "$PROJECT_ROOT/setup.sh"
}

@test "setup.sh displays help when called with --help" {
    run "$PROJECT_ROOT/setup.sh" --help
    assert_success
    assert_output_contains "GitHub Self-Hosted Runner Universal Tool"
    assert_output_contains "Usage:"
}

@test "setup.sh validates required GitHub token parameter" {
    run "$PROJECT_ROOT/setup.sh" --repo "testorg/testrepo"
    assert_failure
    assert_output_contains "GitHub token is required"
}

@test "setup.sh validates required repository parameter" {
    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN"
    assert_failure
    assert_output_contains "GitHub repository is required"
}

@test "setup.sh validates GitHub token format" {
    run "$PROJECT_ROOT/setup.sh" --token "invalid_token" --repo "testorg/testrepo"
    assert_failure
    assert_output_contains "Invalid GitHub token format"
}

@test "setup.sh validates repository format" {
    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "invalid-repo-format"
    assert_failure
    assert_output_contains "Invalid repository format"
}

@test "setup.sh detects environment correctly" {
    # Test VPS detection
    export VPS_MODE=true
    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --dry-run
    assert_output_contains "VPS environment detected"
    unset VPS_MODE

    # Test local detection (macOS)
    if [[ "$(uname)" == "Darwin" ]]; then
        run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --dry-run
        assert_output_contains "Local macOS environment detected"
    fi
}

@test "setup.sh checks system prerequisites" {
    # Mock missing curl
    cat > "$TEST_MOCKS_DIR/curl" << 'EOF'
#!/bin/bash
exit 127
EOF
    chmod +x "$TEST_MOCKS_DIR/curl"

    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --dry-run
    assert_failure
    assert_output_contains "curl is required"
}

@test "setup.sh handles dry-run mode correctly" {
    # Mock successful system commands
    create_mock_response "curl" "Mock response" 0
    create_mock_response "systemctl" "Mock systemctl response" 0

    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --dry-run
    assert_success
    assert_output_contains "DRY RUN MODE"
    assert_output_contains "Would create runner user"
}

@test "setup.sh creates runner configuration directory" {
    # Setup mocks for successful installation
    mock_github_api "api.github.com/repos/$MOCK_GITHUB_REPO" '{"name":"testrepo"}'
    create_mock_response "tar" "Extracted successfully" 0

    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --dry-run
    assert_success
    assert_output_contains "Configuration directory created"
}

@test "setup.sh handles existing runner gracefully" {
    # Create existing runner configuration
    create_test_runner_config "$MOCK_RUNNER_NAME"

    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --name "$MOCK_RUNNER_NAME" --dry-run
    assert_success
    assert_output_contains "Runner '$MOCK_RUNNER_NAME' already exists"
}

@test "setup.sh validates GitHub repository access" {
    # Mock failed GitHub API response
    mock_github_api "api.github.com/repos/$MOCK_GITHUB_REPO" '{"message":"Not Found"}' 404

    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --dry-run
    assert_failure
    assert_output_contains "Cannot access repository"
}

@test "setup.sh generates correct runner labels" {
    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --labels "custom,test" --dry-run
    assert_success
    assert_output_contains "custom,test"
}

@test "setup.sh handles runner name conflicts" {
    # Simulate existing runner with same name
    simulate_running_runner "$MOCK_RUNNER_NAME"

    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --name "$MOCK_RUNNER_NAME" --dry-run
    assert_success
    assert_output_contains "auto-generated name"
}

@test "setup.sh creates systemd service file" {
    skip_if_macos

    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --dry-run
    assert_success
    assert_output_contains "SystemD service configured"
}

@test "setup.sh validates token permissions" {
    # Mock GitHub API response with limited permissions
    mock_github_api "api.github.com/user" '{"login":"testuser"}'
    mock_github_api "api.github.com/repos/$MOCK_GITHUB_REPO/actions/runners/registration-token" '{"message":"Forbidden"}' 403

    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --dry-run
    assert_failure
    assert_output_contains "insufficient permissions"
}

@test "setup.sh handles network connectivity issues" {
    # Mock network failure
    create_mock_response "curl" "curl: (6) Could not resolve host" 6

    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --dry-run
    assert_failure
    assert_output_contains "Network connectivity issue"
}