#!/usr/bin/env bats

# Integration tests for complete runner lifecycle
# Tests installation, configuration, starting, stopping, and removal

load '../test_helper'

setup_file() {
    mkdir -p "$TEST_MOCKS_DIR"

    # Create comprehensive mocks for system integration
    create_logging_mock "systemctl"
    create_logging_mock "useradd"
    create_logging_mock "usermod"
    create_logging_mock "docker"

    # Mock GitHub API for integration tests
    mock_github_api "api.github.com/repos/$MOCK_GITHUB_REPO" '{"name":"testrepo","permissions":{"admin":true}}'
    mock_github_api "api.github.com/repos/$MOCK_GITHUB_REPO/actions/runners/registration-token" '{"token":"MOCK_REG_TOKEN","expires_at":"2024-12-31T23:59:59Z"}'
}

@test "complete runner installation workflow" {
    # Mock tar extraction
    create_mock_response "tar" "Extracted runner binary" 0

    # Mock runner configuration
    cat > "$TEST_MOCKS_DIR/config.sh" << 'EOF'
#!/bin/bash
echo "√ Settings Saved."
exit 0
EOF
    chmod +x "$TEST_MOCKS_DIR/config.sh"

    # Run installation
    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --name "$MOCK_RUNNER_NAME" --dry-run

    assert_success
    assert_output_contains "Runner installation completed successfully"
    assert_output_contains "Runner '$MOCK_RUNNER_NAME' configured"
}

@test "runner starts and registers with GitHub" {
    skip_if_macos

    # Create test runner configuration
    create_test_runner_config "$MOCK_RUNNER_NAME"

    # Mock runner binary
    cat > "$TEST_MOCKS_DIR/run.sh" << 'EOF'
#!/bin/bash
echo "√ Connected to GitHub"
echo "Listening for Jobs"
while true; do sleep 1; done
EOF
    chmod +x "$TEST_MOCKS_DIR/run.sh"

    # Test starting runner
    run "$PROJECT_ROOT/scripts/start-runner.sh" "$MOCK_RUNNER_NAME" --dry-run

    assert_success
    assert_output_contains "Starting runner '$MOCK_RUNNER_NAME'"
}

@test "runner stops gracefully" {
    skip_if_macos

    # Simulate running runner
    simulate_running_runner "$MOCK_RUNNER_NAME"

    # Test stopping runner
    run "$PROJECT_ROOT/scripts/stop-runner.sh" "$MOCK_RUNNER_NAME" --dry-run

    assert_success
    assert_output_contains "Stopping runner '$MOCK_RUNNER_NAME'"
}

@test "runner health check detects issues" {
    # Create unhealthy runner simulation
    create_test_runner_config "$MOCK_RUNNER_NAME"

    # Mock failed health check
    cat > "$TEST_MOCKS_DIR/systemctl" << 'EOF'
#!/bin/bash
if [[ "$*" == *"is-active"* ]]; then
    echo "inactive"
    exit 3
fi
EOF
    chmod +x "$TEST_MOCKS_DIR/systemctl"

    run "$PROJECT_ROOT/scripts/health-check-runner.sh" "$MOCK_RUNNER_NAME"

    assert_failure
    assert_output_contains "Runner '$MOCK_RUNNER_NAME' is not healthy"
}

@test "multiple runners can coexist" {
    # Create multiple runner configurations
    create_test_runner_config "runner-1"
    create_test_runner_config "runner-2"

    # Test listing runners
    run "$PROJECT_ROOT/scripts/health-check-runner.sh" --list

    assert_success
    assert_output_contains "runner-1"
    assert_output_contains "runner-2"
}

@test "runner removal cleans up completely" {
    # Create test runner
    create_test_runner_config "$MOCK_RUNNER_NAME"

    # Mock GitHub API for removal
    mock_github_api "api.github.com/repos/$MOCK_GITHUB_REPO/actions/runners" '[{"id":1,"name":"test-runner","status":"online"}]'

    # Test removal
    run "$PROJECT_ROOT/scripts/remove-runner.sh" "$MOCK_RUNNER_NAME" --dry-run

    assert_success
    assert_output_contains "Runner '$MOCK_RUNNER_NAME' removed successfully"
}

@test "docker-based runner installation" {
    skip_if_no_docker

    # Test Docker installation method
    run "$PROJECT_ROOT/setup.sh" --token "$MOCK_GITHUB_TOKEN" --repo "$MOCK_GITHUB_REPO" --docker --dry-run

    assert_success
    assert_output_contains "Docker-based installation"
}

@test "runner auto-restart after failure" {
    skip_if_macos

    # Simulate runner crash and restart
    create_test_runner_config "$MOCK_RUNNER_NAME"

    # Mock systemctl to show restart behavior
    cat > "$TEST_MOCKS_DIR/systemctl" << 'EOF'
#!/bin/bash
case "$*" in
    *"restart"*)
        echo "Restarted github-runner@test-runner"
        ;;
    *"is-active"*)
        echo "active"
        ;;
esac
EOF
    chmod +x "$TEST_MOCKS_DIR/systemctl"

    run "$PROJECT_ROOT/scripts/start-runner.sh" "$MOCK_RUNNER_NAME" --restart

    assert_success
    assert_output_contains "Runner restarted"
}

@test "runner configuration update" {
    # Create existing runner
    create_test_runner_config "$MOCK_RUNNER_NAME"

    # Test configuration update
    run "$PROJECT_ROOT/scripts/configure-runner.sh" "$MOCK_RUNNER_NAME" --labels "updated,test"

    assert_success
    assert_output_contains "Configuration updated"
}

@test "runner logs are accessible" {
    # Create test runner with logging
    create_test_runner_config "$MOCK_RUNNER_NAME"

    # Mock journalctl for log retrieval
    cat > "$TEST_MOCKS_DIR/journalctl" << 'EOF'
#!/bin/bash
echo "2024-01-01 12:00:00 Runner started successfully"
echo "2024-01-01 12:01:00 Connected to GitHub"
echo "2024-01-01 12:02:00 Listening for jobs"
EOF
    chmod +x "$TEST_MOCKS_DIR/journalctl"

    run "$PROJECT_ROOT/scripts/health-check-runner.sh" "$MOCK_RUNNER_NAME" --logs

    assert_success
    assert_output_contains "Runner started successfully"
    assert_output_contains "Connected to GitHub"
}

@test "runner handles network disconnection gracefully" {
    # Simulate network failure
    create_mock_response "curl" "curl: (6) Could not resolve host" 6

    # Create runner configuration
    create_test_runner_config "$MOCK_RUNNER_NAME"

    # Test network failure handling
    run "$PROJECT_ROOT/scripts/health-check-runner.sh" "$MOCK_RUNNER_NAME"

    assert_failure
    assert_output_contains "Network connectivity issue"
}

@test "runner security audit passes" {
    # Create test runner
    create_test_runner_config "$MOCK_RUNNER_NAME"

    # Test security audit
    run "$PROJECT_ROOT/scripts/security-audit.sh" --runner "$MOCK_RUNNER_NAME"

    assert_success
    assert_output_contains "Security audit completed"
}

@test "runner handles disk space exhaustion" {
    # Mock df command to show low disk space
    cat > "$TEST_MOCKS_DIR/df" << 'EOF'
#!/bin/bash
echo "Filesystem     1K-blocks    Used Available Use% Mounted on"
echo "/dev/sda1       10485760 9961472    524288  95% /"
EOF
    chmod +x "$TEST_MOCKS_DIR/df"

    # Test disk space check
    run "$PROJECT_ROOT/scripts/health-check-runner.sh" "$MOCK_RUNNER_NAME"

    assert_failure
    assert_output_contains "Low disk space"
}