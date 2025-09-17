#!/bin/bash

# GitHub Self-Hosted Runner - Testing Tool
#
# A friendly way to test your GitHub runner setup using Docker containers.
# No changes to your system, just safe containerized testing.
#
# Usage:
#   ./test.sh                    # Smart auto-detection and testing
#   ./test.sh --quick            # Fast 30-second Docker test
#   ./test.sh --full             # Complete validation suite
#   ./test.sh --help             # Show all options
#
# Author: GitHub Self-Hosted Runner Universal Tool

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$SCRIPT_DIR"
readonly TEST_LOG="/tmp/github-runner-test-$$.log"

# Colors for output (friendlier than ALL CAPS)
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly GRAY='\033[0;37m'
readonly NC='\033[0m' # No Color

# Test configuration
GITHUB_TOKEN=""
GITHUB_REPOSITORY=""
TEST_MODE="auto"
VERBOSE=false
DRY_RUN=false
CLEANUP=true
USE_GH_CLI=false

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Friendly logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1" | tee -a "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$TEST_LOG"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$TEST_LOG"
}

log_error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$TEST_LOG"
}

log_step() {
    echo -e "${PURPLE}→${NC} $1" | tee -a "$TEST_LOG"
}

log_quiet() {
    echo -e "${GRAY}$1${NC}" | tee -a "$TEST_LOG"
}

# Test framework functions
test_start() {
    local test_name="$1"
    log_step "Testing: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    local test_name="$1"
    log_success "$test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    local test_name="$1"
    local reason="${2:-Unknown issue}"
    log_error "$test_name - $reason"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

# Show help information
show_help() {
    cat << EOF
GitHub Self-Hosted Runner Testing Tool

Test your runner setup safely with Docker containers.

Usage:
    ./test.sh                    Auto-detect and run appropriate tests
    ./test.sh --quick            30-second validation test
    ./test.sh --validate         Register runner and verify it comes online
    ./test.sh --integration      Full workflow execution test (requires token/repo)
    ./test.sh --full             Complete test suite
    ./test.sh --syntax           Just check scripts and configs

Test options:
    --token TOKEN               Use specific GitHub token
    --repo OWNER/REPO           Test with specific repository
    --use-gh-cli                Try using your gh CLI authentication

Behavior:
    --verbose                   Show detailed output
    --dry-run                   Show what would be tested
    --no-cleanup                Keep test containers for debugging
    --help                      Show this help

Examples:
    # Quick test (uses gh CLI if available)
    ./test.sh --quick

    # Test with your token and repo
    ./test.sh --token ghp_abc123 --repo myuser/test-repo

    # Full test suite
    ./test.sh --full --verbose

Getting started:
    If you don't have a token, try: ./test.sh --quick
    This will use your GitHub CLI login if it's set up.

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                TEST_MODE="quick"
                shift
                ;;
            --full)
                TEST_MODE="full"
                shift
                ;;
            --syntax)
                TEST_MODE="syntax"
                shift
                ;;
            --validate)
                TEST_MODE="validate"
                shift
                ;;
            --integration)
                TEST_MODE="integration"
                shift
                ;;
            --token)
                GITHUB_TOKEN="$2"
                shift 2
                ;;
            --repo)
                GITHUB_REPOSITORY="$2"
                shift 2
                ;;
            --use-gh-cli)
                USE_GH_CLI=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-cleanup)
                CLEANUP=false
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help to see available options"
                exit 1
                ;;
        esac
    done
}

# Smart credential detection
detect_credentials() {
    log_step "Looking for GitHub credentials"

    # Check if gh CLI is authenticated
    if command -v gh &> /dev/null && gh auth status &> /dev/null; then
        log_success "Found GitHub CLI authentication"

        # Extract token if user wants to use it
        if [[ "$USE_GH_CLI" == "true" || (-z "$GITHUB_TOKEN" && "$TEST_MODE" != "syntax") ]]; then
            if gh auth token &> /dev/null; then
                GITHUB_TOKEN=$(gh auth token)
                log_info "Using your GitHub CLI token for testing"
                USE_GH_CLI=true
            fi
        fi

        # Try to detect a reasonable test repository
        if [[ -z "$GITHUB_REPOSITORY" && "$USE_GH_CLI" == "true" ]]; then
            local current_repo
            if current_repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
                log_info "Found current repository: $current_repo"
                if ask_yes_no "Use $current_repo for testing?"; then
                    GITHUB_REPOSITORY="$current_repo"
                fi
            fi
        fi
    else
        log_info "GitHub CLI not authenticated (that's okay)"
    fi

    # If still no token and we need one, guide the user
    if [[ -z "$GITHUB_TOKEN" && "$TEST_MODE" != "syntax" ]]; then
        cat << EOF

No GitHub token found. Here are your options:

1. Quick test without token: ./test.sh --syntax
2. Set up GitHub CLI: gh auth login
3. Create a token manually: https://github.com/settings/tokens/new

For a token, you'll need:
  • Scope: 'repo'
  • Expiration: 90 days (recommended)
  • Repository access: Any repo you can push to

EOF
        if ask_yes_no "Open token creation page in browser?"; then
            open "https://github.com/settings/tokens/new?scopes=repo&description=Self-hosted%20runner%20testing" 2>/dev/null || \
            xdg-open "https://github.com/settings/tokens/new?scopes=repo&description=Self-hosted%20runner%20testing" 2>/dev/null || \
            log_info "Please visit: https://github.com/settings/tokens/new"
        fi

        if [[ "$TEST_MODE" != "syntax" ]]; then
            TEST_MODE="syntax"
            log_info "Switching to syntax-only testing"
        fi
    fi
}

# Helper function for yes/no questions
ask_yes_no() {
    local question="$1"
    echo -n "$question (y/n): "
    read -r response
    [[ "$response" =~ ^[Yy] ]]
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking what you have installed"

    local missing_tools=()

    # Check Docker only if needed
    if [[ "$TEST_MODE" == "quick" || "$TEST_MODE" == "full" ]]; then
        if ! command -v docker &> /dev/null; then
            missing_tools+=("docker")
        elif ! docker info &> /dev/null; then
            log_error "Docker is installed but not running"
            log_info "Please start Docker and try again"
            exit 1
        else
            log_success "Docker is ready"
        fi
    fi

    # Check required files
    local required_files=("setup.sh" "scripts/test-suite.sh")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            log_error "Missing file: $file"
            exit 1
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing tools: ${missing_tools[*]}"
        log_info "Install them and try again"
        exit 1
    fi

    log_success "All prerequisites are ready"
}

# Validate GitHub credentials when provided
validate_credentials() {
    if [[ -z "$GITHUB_TOKEN" || -z "$GITHUB_REPOSITORY" ]]; then
        return 0  # Skip if not provided
    fi

    test_start "GitHub connection"

    # Basic format validation (supports ghp_, ghs_, gho_ formats)
    if [[ ! "$GITHUB_TOKEN" =~ ^gh[pso]_[a-zA-Z0-9]{36,}$ ]]; then
        test_fail "GitHub connection" "Token format looks wrong"
        return 1
    fi

    if [[ ! "$GITHUB_REPOSITORY" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
        test_fail "GitHub connection" "Repository should be 'owner/repo' format"
        return 1
    fi

    # Test API access
    local api_response
    if api_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                          -H "Accept: application/vnd.github.v3+json" \
                          "https://api.github.com/repos/$GITHUB_REPOSITORY" 2>&1); then

        if echo "$api_response" | grep -q '"id"'; then
            test_pass "GitHub connection established"
            return 0
        else
            test_fail "GitHub connection" "Can't access repository '$GITHUB_REPOSITORY'"
            return 1
        fi
    else
        test_fail "GitHub connection" "Can't reach GitHub API"
        return 1
    fi
}

# Run syntax tests (no external dependencies)
run_syntax_tests() {
    log_step "Checking scripts and configuration"

    test_start "Script syntax"
    local syntax_ok=true

    # Check main scripts
    local scripts=("setup.sh" "scripts/configure-runner.sh" "scripts/install-runner.sh")
    for script in "${scripts[@]}"; do
        local script_path="$PROJECT_ROOT/$script"
        if [[ -f "$script_path" ]]; then
            if bash -n "$script_path" 2>/dev/null; then
                log_quiet "✓ $script syntax is valid"
            else
                log_error "✗ $script has syntax errors"
                syntax_ok=false
            fi
        fi
    done

    if [[ "$syntax_ok" == "true" ]]; then
        test_pass "All scripts have valid syntax"
    else
        test_fail "Script syntax check"
    fi

    # Check Docker configuration
    test_start "Docker configuration"
    if [[ -f "$PROJECT_ROOT/docker/docker-compose.yml" ]]; then
        if command -v docker-compose &>/dev/null; then
            if docker-compose -f "$PROJECT_ROOT/docker/docker-compose.yml" config &>/dev/null; then
                test_pass "Docker configuration is valid"
            else
                test_fail "Docker configuration" "docker-compose.yml has issues"
            fi
        else
            log_info "Skipping docker-compose validation (not installed)"
        fi
    fi
}

# Run quick Docker test
run_quick_test() {
    log_step "Running quick Docker validation"

    test_start "Docker image build"
    if docker build -t github-runner-test:local "$PROJECT_ROOT/docker" &> "$TEST_LOG.build"; then
        test_pass "Docker image builds successfully"
    else
        test_fail "Docker image build" "Check $TEST_LOG.build for details"
        return 1
    fi

    test_start "Runner configuration"
    local container_name="github-runner-quick-test-$$"

    # Create minimal test environment
    local test_env_file="/tmp/quick-test.env"
    cat > "$test_env_file" << EOF
GITHUB_TOKEN=${GITHUB_TOKEN:-dummy_token}
GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-test/repo}
RUNNER_NAME=quick-test-$$
RUNNER_LABELS=self-hosted,linux,x64,docker,test
EPHEMERAL=true
DEBUG=true
EOF

    # Test container creation (not full startup)
    if docker create \
        --name "$container_name" \
        --env-file "$test_env_file" \
        github-runner-test:local &>/dev/null; then

        test_pass "Runner container can be created"

        # Quick container inspection
        if docker inspect "$container_name" &>/dev/null; then
            test_pass "Container configuration looks good"
        fi
    else
        test_fail "Runner configuration" "Could not create test container"
    fi

    # Cleanup
    if [[ "$CLEANUP" == "true" ]]; then
        docker rm "$container_name" &>/dev/null || true
        docker rmi github-runner-test:local &>/dev/null || true
    fi
    rm -f "$test_env_file"
}

# Run validation test (register runner and verify online)
run_validation_test() {
    log_step "Testing runner registration and connectivity"

    if [[ -z "$GITHUB_TOKEN" || -z "$GITHUB_REPOSITORY" ]]; then
        log_error "Validation test requires GitHub token and repository"
        return 1
    fi

    test_start "Runner registration"
    local container_name="github-runner-validate-$$"
    local runner_name="validate-test-$$"

    # Create environment file
    local test_env_file="/tmp/validate-test.env"
    cat > "$test_env_file" << EOF
GITHUB_TOKEN=$GITHUB_TOKEN
GITHUB_REPOSITORY=$GITHUB_REPOSITORY
RUNNER_NAME=$runner_name
RUNNER_LABELS=self-hosted,linux,x64,docker,validation-test
EPHEMERAL=true
RUNNER_REPLACE=true
DEBUG=true
EOF

    # Start the runner container
    if docker run -d \
        --name "$container_name" \
        --env-file "$test_env_file" \
        -v /var/run/docker.sock:/var/run/docker.sock:rw \
        github-runner-test:local > /dev/null 2>&1; then

        test_pass "Runner container started"

        # Wait for registration (up to 60 seconds)
        log_info "Waiting for runner to register with GitHub..."
        local wait_time=0
        local max_wait=60
        local runner_online=false

        while [[ $wait_time -lt $max_wait ]]; do
            # Check if runner appears in GitHub API
            local runners_response
            if runners_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                                       -H "Accept: application/vnd.github.v3+json" \
                                       "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/runners" 2>/dev/null); then

                if echo "$runners_response" | grep -q "\"name\":\"$runner_name\""; then
                    runner_online=true
                    break
                fi
            fi

            sleep 2
            wait_time=$((wait_time + 2))
            if [[ $((wait_time % 10)) -eq 0 ]]; then
                log_quiet "Still waiting... (${wait_time}s/${max_wait}s)"
            fi
        done

        if [[ "$runner_online" == "true" ]]; then
            test_pass "Runner registered and online"
            log_success "Runner '$runner_name' is connected to GitHub!"
        else
            test_fail "Runner registration" "Runner did not come online within ${max_wait}s"

            # Show container logs for debugging
            log_info "Container logs:"
            docker logs "$container_name" | tail -20
        fi
    else
        test_fail "Runner container startup" "Failed to start validation container"
    fi

    # Cleanup
    if [[ "$CLEANUP" == "true" ]]; then
        log_info "Cleaning up validation test..."
        docker stop "$container_name" &>/dev/null || true
        docker rm "$container_name" &>/dev/null || true
    fi
    rm -f "$test_env_file"
}

# Run integration test (full workflow execution)
run_integration_test() {
    log_step "Running full workflow integration test"

    if [[ -z "$GITHUB_TOKEN" || -z "$GITHUB_REPOSITORY" ]]; then
        log_error "Integration test requires GitHub token and repository"
        return 1
    fi

    test_start "Workflow integration test"
    local container_name="github-runner-integration-$$"
    local runner_name="integration-test-$$"
    local workflow_file=".github/workflows/test-runner-integration-$$.yml"
    local workflow_name="test-runner-integration-$$"

    # Create test workflow
    log_info "Creating test workflow..."
    if ! create_test_workflow "$workflow_file" "$workflow_name"; then
        test_fail "Workflow integration test" "Failed to create test workflow"
        return 1
    fi

    # Create environment file
    local test_env_file="/tmp/integration-test.env"
    cat > "$test_env_file" << EOF
GITHUB_TOKEN=$GITHUB_TOKEN
GITHUB_REPOSITORY=$GITHUB_REPOSITORY
RUNNER_NAME=$runner_name
RUNNER_LABELS=self-hosted,linux,x64,docker,integration-test
EPHEMERAL=true
RUNNER_REPLACE=true
DEBUG=true
EOF

    # Start runner container
    if docker run -d \
        --name "$container_name" \
        --env-file "$test_env_file" \
        -v /var/run/docker.sock:/var/run/docker.sock:rw \
        github-runner-test:local > /dev/null 2>&1; then

        log_success "Integration test runner started"

        # Wait for runner to come online
        if wait_for_runner_online "$runner_name" 60; then
            log_success "Runner is online, triggering test workflow..."

            # Trigger the workflow
            if trigger_test_workflow "$workflow_name"; then
                # Monitor workflow execution
                if monitor_workflow_execution "$workflow_name" "$runner_name"; then
                    test_pass "Full workflow integration test"
                    log_success "🎉 Workflow ran successfully on self-hosted runner!"
                else
                    test_fail "Workflow integration test" "Workflow did not complete successfully"
                fi
            else
                test_fail "Workflow integration test" "Failed to trigger workflow"
            fi
        else
            test_fail "Workflow integration test" "Runner did not come online"
        fi
    else
        test_fail "Workflow integration test" "Failed to start integration test container"
    fi

    # Cleanup
    if [[ "$CLEANUP" == "true" ]]; then
        log_info "Cleaning up integration test..."
        docker stop "$container_name" &>/dev/null || true
        docker rm "$container_name" &>/dev/null || true
        cleanup_test_workflow "$workflow_file"
    fi
    rm -f "$test_env_file"
}

# Helper function to wait for runner to come online
wait_for_runner_online() {
    local runner_name="$1"
    local max_wait="${2:-60}"
    local wait_time=0

    log_info "Waiting for runner '$runner_name' to come online..."

    while [[ $wait_time -lt $max_wait ]]; do
        local runners_response
        if runners_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                                   -H "Accept: application/vnd.github.v3+json" \
                                   "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/runners" 2>/dev/null); then

            if echo "$runners_response" | grep -q "\"name\":\"$runner_name\""; then
                log_success "Runner '$runner_name' is online!"
                return 0
            fi
        fi

        sleep 3
        wait_time=$((wait_time + 3))
        if [[ $((wait_time % 15)) -eq 0 ]]; then
            log_quiet "Still waiting for runner... (${wait_time}s/${max_wait}s)"
        fi
    done

    log_error "Runner '$runner_name' did not come online within ${max_wait}s"
    return 1
}

# Helper function to create test workflow
create_test_workflow() {
    local workflow_file="$1"
    local workflow_name="$2"

    # Check if we're in a git repository
    if ! git rev-parse --git-dir &>/dev/null; then
        log_warning "Not in a git repository - cannot create workflow file"
        return 1
    fi

    # Create workflow directory if it doesn't exist
    mkdir -p "$(dirname "$workflow_file")"

    # Create the test workflow
    cat > "$workflow_file" << EOF
name: $workflow_name

on:
  workflow_dispatch:
    inputs:
      test_message:
        description: 'Test message'
        required: false
        default: 'Integration test from self-hosted runner'

jobs:
  test-self-hosted-runner:
    runs-on: self-hosted

    steps:
    - name: Test runner info
      run: |
        echo "🤖 Integration test running on self-hosted runner"
        echo "Runner name: \$RUNNER_NAME"
        echo "Repository: \$GITHUB_REPOSITORY"
        echo "Workflow: \$GITHUB_WORKFLOW"
        echo "Test message: \${{ github.event.inputs.test_message || 'Integration test from self-hosted runner' }}"

    - name: Test basic commands
      run: |
        echo "Testing basic commands..."
        whoami
        pwd
        uname -a
        docker --version || echo "Docker not available"

    - name: Test success marker
      run: |
        echo "INTEGRATION_TEST_SUCCESS=true" >> \$GITHUB_ENV
        echo "✅ Integration test completed successfully!"
EOF

    # Commit the workflow
    git add "$workflow_file"
    git commit -m "Add integration test workflow ($workflow_name)" &>/dev/null

    # Push to trigger workflow
    if git push &>/dev/null; then
        log_success "Test workflow created and pushed"
        return 0
    else
        log_error "Failed to push test workflow"
        return 1
    fi
}

# Helper function to trigger test workflow
trigger_test_workflow() {
    local workflow_name="$1"

    log_info "Triggering workflow '$workflow_name'..."

    # Use GitHub API to trigger workflow_dispatch
    local trigger_response
    if trigger_response=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/workflows/$workflow_name.yml/dispatches" \
        -d '{"ref":"main","inputs":{"test_message":"Integration test triggered via API"}}' 2>&1); then

        log_success "Workflow triggered successfully"
        return 0
    else
        log_error "Failed to trigger workflow: $trigger_response"
        return 1
    fi
}

# Helper function to monitor workflow execution
monitor_workflow_execution() {
    local workflow_name="$1"
    local runner_name="$2"
    local max_wait=120
    local wait_time=0

    log_info "Monitoring workflow execution..."

    while [[ $wait_time -lt $max_wait ]]; do
        # Get recent workflow runs
        local runs_response
        if runs_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                                   -H "Accept: application/vnd.github.v3+json" \
                                   "https://api.github.com/repos/$GITHUB_REPOSITORY/actions/runs?per_page=5" 2>/dev/null); then

            # Look for our workflow run
            local run_status
            if run_status=$(echo "$runs_response" | grep -A 10 "\"name\":\"$workflow_name\"" | grep "\"status\"" | head -1 | cut -d'"' -f4); then
                case "$run_status" in
                    "completed")
                        local conclusion
                        conclusion=$(echo "$runs_response" | grep -A 15 "\"name\":\"$workflow_name\"" | grep "\"conclusion\"" | head -1 | cut -d'"' -f4)
                        if [[ "$conclusion" == "success" ]]; then
                            log_success "Workflow completed successfully!"
                            return 0
                        else
                            log_error "Workflow completed with conclusion: $conclusion"
                            return 1
                        fi
                        ;;
                    "in_progress")
                        log_info "Workflow is running..."
                        ;;
                    "queued")
                        log_info "Workflow is queued..."
                        ;;
                    *)
                        log_warning "Workflow status: $run_status"
                        ;;
                esac
            fi
        fi

        sleep 5
        wait_time=$((wait_time + 5))
        if [[ $((wait_time % 30)) -eq 0 ]]; then
            log_quiet "Still monitoring workflow... (${wait_time}s/${max_wait}s)"
        fi
    done

    log_error "Workflow monitoring timed out after ${max_wait}s"
    return 1
}

# Helper function to cleanup test workflow
cleanup_test_workflow() {
    local workflow_file="$1"

    if [[ -f "$workflow_file" ]]; then
        log_info "Removing test workflow file..."
        git rm "$workflow_file" &>/dev/null || rm -f "$workflow_file"
        git commit -m "Remove integration test workflow" &>/dev/null || true
        git push &>/dev/null || true
    fi
}

# Run full test suite
run_full_tests() {
    log_step "Running comprehensive test suite"

    # Include syntax tests
    run_syntax_tests

    # Include quick test
    if [[ -n "$GITHUB_TOKEN" && -n "$GITHUB_REPOSITORY" ]]; then
        run_quick_test
    fi

    # Run existing test suite if available
    test_start "Complete test suite"
    if [[ -f "$PROJECT_ROOT/scripts/test-suite.sh" ]]; then
        local test_args=()

        if [[ "$VERBOSE" == "true" ]]; then
            test_args+=("--verbose")
        fi

        if "$PROJECT_ROOT/scripts/test-suite.sh" "${test_args[@]}" &> "$TEST_LOG.full"; then
            test_pass "All comprehensive tests passed"
        else
            test_fail "Comprehensive tests" "Some tests failed - check $TEST_LOG.full"
        fi
    else
        log_info "Extended test suite not found (that's okay)"
    fi
}

# Cleanup function
cleanup_test_environment() {
    if [[ "$CLEANUP" == "true" ]]; then
        log_quiet "Cleaning up test containers and images"

        # Remove test containers
        docker ps -a --filter "name=github-runner-test" --format "{{.Names}}" 2>/dev/null | \
            xargs -r docker rm -f &>/dev/null || true
        docker ps -a --filter "name=github-runner-quick-test" --format "{{.Names}}" 2>/dev/null | \
            xargs -r docker rm -f &>/dev/null || true

        # Remove test images
        docker images --filter "reference=github-runner-test" --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | \
            xargs -r docker rmi &>/dev/null || true
    fi
}

# Show test summary
show_test_summary() {
    echo ""
    echo "Test Results"
    echo "============"
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"

    if [[ $TESTS_RUN -gt 0 ]]; then
        local success_rate=$(( (TESTS_PASSED * 100) / TESTS_RUN ))
        echo "Success rate: ${success_rate}%"
    fi

    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "Some tests didn't pass"
        echo ""
        log_info "Common fixes:"
        log_info "• Make sure Docker is running: docker info"
        log_info "• Check your GitHub token has 'repo' scope"
        log_info "• Verify repository name format: owner/repo"
        log_info "• Ensure you can access the repository"
        echo ""
        log_info "For detailed logs: $TEST_LOG*"
        return 1
    else
        log_success "All tests passed!"
        echo ""
        case "$TEST_MODE" in
            "syntax")
                log_info "Your scripts look good. Ready to try a quick test?"
                log_info "Next: ./test.sh --quick"
                ;;
            "quick")
                log_info "Quick test successful! Your setup should work."
                log_info "Next: ./test.sh --validate to test runner registration"
                ;;
            "validate")
                log_success "Validation successful! Runner can connect to GitHub."
                log_info "Next: ./test.sh --integration for full workflow testing"
                ;;
            "integration")
                log_success "🎉 Integration test passed! Workflows run on your runner!"
                echo ""
                log_info "Your self-hosted runner system is fully working!"
                log_info "Deploy options:"
                log_info "• Direct install: ./setup.sh --token TOKEN --repo REPO"
                log_info "• Docker deploy: Use docker/docker-compose.yml"
                ;;
            "full")
                log_success "Everything looks great! Your runner system is ready."
                echo ""
                log_info "Deploy options:"
                log_info "• Direct install: ./setup.sh --token TOKEN --repo REPO"
                log_info "• Docker deploy: Use docker/docker-compose.yml"
                log_info "• Multiple runners: ./setup.sh with different names"
                ;;
        esac
        return 0
    fi
}

# Main execution
main() {
    echo "GitHub Self-Hosted Runner Test Tool"
    echo "==================================="
    echo ""

    parse_args "$@"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would run: $TEST_MODE mode tests"
        if [[ -n "$GITHUB_TOKEN" ]]; then
            echo "Using token: ${GITHUB_TOKEN:0:7}..."
        fi
        if [[ -n "$GITHUB_REPOSITORY" ]]; then
            echo "Using repository: $GITHUB_REPOSITORY"
        fi
        exit 0
    fi

    # Smart detection if auto mode
    if [[ "$TEST_MODE" == "auto" ]]; then
        detect_credentials

        if [[ -n "$GITHUB_TOKEN" && -n "$GITHUB_REPOSITORY" ]]; then
            TEST_MODE="validate"
            log_info "Auto-detected credentials, running validation test"
        else
            TEST_MODE="syntax"
            log_info "No credentials found, running syntax check"
        fi
    fi

    check_prerequisites

    # Validate credentials if we have them
    if [[ -n "$GITHUB_TOKEN" && -n "$GITHUB_REPOSITORY" ]]; then
        validate_credentials || exit 1
    fi

    # Run appropriate tests
    case "$TEST_MODE" in
        "syntax")
            run_syntax_tests
            ;;
        "quick")
            run_syntax_tests
            if [[ -n "$GITHUB_TOKEN" && -n "$GITHUB_REPOSITORY" ]]; then
                run_quick_test
            else
                log_warning "No credentials provided for Docker test"
            fi
            ;;
        "validate")
            run_syntax_tests
            if [[ -n "$GITHUB_TOKEN" && -n "$GITHUB_REPOSITORY" ]]; then
                run_quick_test
                run_validation_test
            else
                log_error "Validation test requires GitHub token and repository"
                exit 1
            fi
            ;;
        "integration")
            run_syntax_tests
            if [[ -n "$GITHUB_TOKEN" && -n "$GITHUB_REPOSITORY" ]]; then
                run_quick_test
                run_integration_test
            else
                log_error "Integration test requires GitHub token and repository"
                exit 1
            fi
            ;;
        "full")
            run_full_tests
            ;;
        *)
            log_error "Unknown test mode: $TEST_MODE"
            exit 1
            ;;
    esac

    cleanup_test_environment
    show_test_summary
}

# Trap for cleanup
trap cleanup_test_environment EXIT

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi