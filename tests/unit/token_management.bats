#!/usr/bin/env bats

# Unit tests for token management functionality
# Tests token encryption, validation, and storage

load '../test_helper'

# Test setup for this file
setup_file() {
    mkdir -p "$TEST_MOCKS_DIR"
}

@test "token encryption and decryption works correctly" {
    # Source the setup script to get token functions
    source "$PROJECT_ROOT/setup.sh"

    # Test XOR encryption/decryption
    local test_token="ghp_test1234567890abcdef1234567890abcdef12"
    local password="test_password_123"
    local salt="1234567890"

    # Test encryption function
    local encrypted=$(xor_encrypt "$test_token" "${password}${salt}")
    assert [ -n "$encrypted" ]
    assert [ "$encrypted" != "$test_token" ]

    # Test decryption function
    local decrypted=$(xor_decrypt "$encrypted" "${password}${salt}")
    assert_equal "$decrypted" "$test_token"
}

@test "token validation accepts valid GitHub tokens" {
    source "$PROJECT_ROOT/setup.sh"

    # Test valid GitHub personal access token format
    run validate_github_token "ghp_1234567890abcdef1234567890abcdef12"
    assert_success

    # Test valid GitHub app token format
    run validate_github_token "ghs_1234567890abcdef1234567890abcdef12"
    assert_success

    # Test valid GitHub refresh token format
    run validate_github_token "ghr_1234567890abcdef1234567890abcdef12"
    assert_success
}

@test "token validation rejects invalid tokens" {
    source "$PROJECT_ROOT/setup.sh"

    # Test too short token
    run validate_github_token "ghp_123"
    assert_failure

    # Test invalid prefix
    run validate_github_token "invalid_1234567890abcdef1234567890abcdef12"
    assert_failure

    # Test empty token
    run validate_github_token ""
    assert_failure

    # Test token with invalid characters
    run validate_github_token "ghp_123456789@abcdef1234567890abcdef12"
    assert_failure
}

@test "token storage creates secure file permissions" {
    source "$PROJECT_ROOT/setup.sh"

    local test_token="ghp_test1234567890abcdef1234567890abcdef12"
    local password="secure_password_456"

    # Test saving token
    save_token "$test_token" "$password"

    # Check that token file exists and has correct permissions
    assert_file_exist "$HOME/.github-runner/config/.token.enc"

    # Check permissions (600 = rw-------)
    local perms=$(stat -c "%a" "$HOME/.github-runner/config/.token.enc" 2>/dev/null || stat -f "%A" "$HOME/.github-runner/config/.token.enc" 2>/dev/null)
    assert_equal "$perms" "600"

    # Check auth file exists
    assert_file_exist "$HOME/.github-runner/config/.auth"
}

@test "token retrieval works with correct password" {
    source "$PROJECT_ROOT/setup.sh"

    local test_token="ghp_test1234567890abcdef1234567890abcdef12"
    local password="correct_password_789"

    # Save and retrieve token
    save_token "$test_token" "$password"
    local retrieved_token=$(get_token "$password")

    assert_equal "$retrieved_token" "$test_token"
}

@test "token retrieval fails with incorrect password" {
    source "$PROJECT_ROOT/setup.sh"

    local test_token="ghp_test1234567890abcdef1234567890abcdef12"
    local correct_password="correct_password_789"
    local wrong_password="wrong_password_123"

    # Save token with correct password
    save_token "$test_token" "$correct_password"

    # Try to retrieve with wrong password
    run get_token "$wrong_password"
    assert_failure
}

@test "multiple tokens can be stored for different repositories" {
    source "$PROJECT_ROOT/setup.sh"

    local token1="ghp_token1234567890abcdef1234567890abcdef"
    local token2="ghp_token2234567890abcdef1234567890abcdef"
    local repo1="org1/repo1"
    local repo2="org2/repo2"
    local password="multi_repo_password"

    # Save tokens for different repositories
    save_token_for_repo "$token1" "$repo1" "$password"
    save_token_for_repo "$token2" "$repo2" "$password"

    # Retrieve tokens
    local retrieved1=$(get_token_for_repo "$repo1" "$password")
    local retrieved2=$(get_token_for_repo "$repo2" "$password")

    assert_equal "$retrieved1" "$token1"
    assert_equal "$retrieved2" "$token2"
}

@test "token testing validates repository access" {
    source "$PROJECT_ROOT/setup.sh"

    # Mock successful GitHub API response
    mock_github_api "api.github.com/repos/$MOCK_GITHUB_REPO" '{"name":"testrepo","permissions":{"admin":true}}'

    run test_token_access "$MOCK_GITHUB_TOKEN" "$MOCK_GITHUB_REPO"
    assert_success
    assert_output_contains "Token has access to repository"
}

@test "token testing detects insufficient permissions" {
    source "$PROJECT_ROOT/setup.sh"

    # Mock API response with insufficient permissions
    mock_github_api "api.github.com/repos/$MOCK_GITHUB_REPO" '{"name":"testrepo","permissions":{"admin":false,"push":false}}'

    run test_token_access "$MOCK_GITHUB_TOKEN" "$MOCK_GITHUB_REPO"
    assert_failure
    assert_output_contains "insufficient permissions"
}

@test "token listing shows stored tokens" {
    source "$PROJECT_ROOT/setup.sh"

    local password="list_test_password"

    # Store multiple tokens
    save_token_for_repo "ghp_token1" "org1/repo1" "$password"
    save_token_for_repo "ghp_token2" "org2/repo2" "$password"

    run list_stored_tokens "$password"
    assert_success
    assert_output_contains "org1/repo1"
    assert_output_contains "org2/repo2"
}

@test "token clearing removes all stored tokens" {
    source "$PROJECT_ROOT/setup.sh"

    local password="clear_test_password"

    # Store tokens
    save_token_for_repo "ghp_token1" "org1/repo1" "$password"
    save_token_for_repo "ghp_token2" "org2/repo2" "$password"

    # Clear tokens
    clear_all_tokens "$password"

    # Verify tokens are gone
    run list_stored_tokens "$password"
    assert_success
    assert_output_contains "No tokens stored"
}

@test "password hashing is consistent" {
    source "$PROJECT_ROOT/setup.sh"

    local password="consistency_test_password"

    # Hash password multiple times
    local hash1=$(hash_password "$password")
    local hash2=$(hash_password "$password")

    # Hashes should be consistent
    assert_equal "$hash1" "$hash2"
}

@test "password verification works correctly" {
    source "$PROJECT_ROOT/setup.sh"

    local password="verification_test_password"
    local wrong_password="wrong_password"

    # Save a token to create password hash
    save_token "ghp_test_token" "$password"

    # Test correct password
    run verify_password "$password"
    assert_success

    # Test wrong password
    run verify_password "$wrong_password"
    assert_failure
}