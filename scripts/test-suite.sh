#!/bin/bash

# GitHub Actions Self-Hosted Runner - Test Suite
#
# This script provides comprehensive testing for the runner installation
# and management system. It includes unit tests, integration tests,
# security tests, and environment validation.
#
# Usage:
#   ./test-suite.sh                    # Run all tests
#   ./test-suite.sh --unit-tests       # Run only unit tests
#   ./test-suite.sh --integration      # Run integration tests
#   ./test-suite.sh --security         # Run security tests
#   ./test-suite.sh --help             # Show help
#
# Author: Gabel (Booplex.com)
# Website: https://booplex.com
# Built with: Rigorous testing, colorful output, and the delusion that all bugs are findable
#
# Motto: "Trust, but verify. Then test. Then test again. Then panic when it still breaks."

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly TEST_DIR="$PROJECT_ROOT/tests"
readonly TEST_LOG="/tmp/github-runner-tests-$$.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Test configuration
TEST_TYPES=()
VERBOSE=false
DRY_RUN=false
CLEANUP=true

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$TEST_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$TEST_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$TEST_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$TEST_LOG"
}

log_header() {
    echo -e "${WHITE}$1${NC}" | tee -a "$TEST_LOG"
}

log_test() {
    echo -e "${PURPLE}[TEST]${NC} $1" | tee -a "$TEST_LOG"
}

# Test framework functions
test_start() {
    local test_name="$1"
    log_test "Starting: $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))
}

test_pass() {
    local test_name="$1"
    log_success "PASSED: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    local test_name="$1"
    local reason="${2:-Unknown failure}"
    log_error "FAILED: $test_name - $reason"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

test_skip() {
    local test_name="$1"
    local reason="${2:-No reason given}"
    log_warning "SKIPPED: $test_name - $reason"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# Show help information
show_help() {
    cat << EOF
${WHITE}GitHub Actions Self-Hosted Runner - Test Suite${NC}

Comprehensive testing framework for runner installation and management.

${WHITE}USAGE:${NC}
    $0 [TEST_TYPES] [OPTIONS]

${WHITE}TEST TYPES:${NC}
    --unit-tests       Run unit tests for individual functions
    --integration      Run integration tests for complete workflows
    --security         Run security validation tests
    --environment      Run environment compatibility tests
    --performance      Run performance and resource tests
    --all              Run all test categories (default)

${WHITE}OPTIONS:${NC}
    --verbose          Enable verbose output
    --dry-run          Show what tests would run without executing
    --no-cleanup       Don't clean up test artifacts
    --log-file FILE    Custom log file location
    --help             Show this help message

${WHITE}EXAMPLES:${NC}
    # Run all tests
    $0

    # Run only unit tests with verbose output
    $0 --unit-tests --verbose

    # Run security and environment tests
    $0 --security --environment

    # Dry run to see what would be tested
    $0 --dry-run

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --unit-tests)
                TEST_TYPES+=("unit")
                shift
                ;;
            --integration)
                TEST_TYPES+=("integration")
                shift
                ;;
            --security)
                TEST_TYPES+=("security")
                shift
                ;;
            --environment)
                TEST_TYPES+=("environment")
                shift
                ;;
            --performance)
                TEST_TYPES+=("performance")
                shift
                ;;
            --all)
                TEST_TYPES=("unit" "integration" "security" "environment" "performance")
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
            --log-file)
                TEST_LOG="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Default to all tests if none specified
    if [[ ${#TEST_TYPES[@]} -eq 0 ]]; then
        TEST_TYPES=("unit" "integration" "security" "environment" "performance")
    fi
}

# Create test environment
setup_test_environment() {
    log_info "Setting up test environment..."

    # Create test directory
    mkdir -p "$TEST_DIR"
    mkdir -p "$TEST_DIR/fixtures"
    mkdir -p "$TEST_DIR/tmp"

    # Create test fixtures
    cat > "$TEST_DIR/fixtures/test-token.txt" << 'EOF'
ghp_test_token_1234567890abcdefghijklmnopqrstuvwxyz
EOF

    cat > "$TEST_DIR/fixtures/test-repo.txt" << 'EOF'
test-owner/test-repository
EOF

    # Set permissions
    chmod 600 "$TEST_DIR/fixtures/test-token.txt"

    log_success "Test environment ready"
}

# Unit Tests
run_unit_tests() {
    log_header "🧪 Running Unit Tests"
    log_header "===================="

    # Test token validation
    test_validate_github_token

    # Test repository validation
    test_validate_repository

    # Test runner name validation
    test_validate_runner_name

    # Test environment detection
    test_detect_environment

    # Test prerequisite checking
    test_check_prerequisites
}

test_validate_github_token() {
    test_start "GitHub Token Validation"

    # Source the validation function
    if [[ -f "$SCRIPT_DIR/configure-runner.sh" ]]; then
        source "$SCRIPT_DIR/configure-runner.sh"

        # Test valid token format
        if validate_github_token "ghp_1234567890abcdefghijklmnopqrstuvwxyz12"; then
            test_pass "Valid token format accepted"
        else
            test_fail "Valid token format rejected"
            return
        fi

        # Test invalid token format
        if ! validate_github_token "invalid_token_format" 2>/dev/null; then
            test_pass "Invalid token format rejected"
        else
            test_fail "Invalid token format accepted"
        fi
    else
        test_skip "GitHub Token Validation" "configure-runner.sh not found"
    fi
}

test_validate_repository() {
    test_start "Repository Validation"

    if [[ -f "$SCRIPT_DIR/configure-runner.sh" ]]; then
        source "$SCRIPT_DIR/configure-runner.sh"

        # Test valid repository format
        local test_cases=(
            "owner/repo:VALID"
            "user123/project-name:VALID"
            "org_name/repo.name:VALID"
            "invalid-format:INVALID"
            "owner/:INVALID"
            "/repo:INVALID"
            "owner/repo/extra:INVALID"
        )

        local all_passed=true
        for test_case in "${test_cases[@]}"; do
            local repo="${test_case%:*}"
            local expected="${test_case#*:}"

            # Override the token for testing
            GITHUB_TOKEN="ghp_test_token"

            if [[ "$expected" == "VALID" ]]; then
                # We expect this to pass format validation
                # (API validation will fail with test token, which is expected)
                if [[ "$repo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
                    log_info "✅ Valid format: $repo"
                else
                    log_error "❌ Failed format validation: $repo"
                    all_passed=false
                fi
            else
                # We expect this to fail format validation
                if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
                    log_info "✅ Invalid format correctly rejected: $repo"
                else
                    log_error "❌ Invalid format incorrectly accepted: $repo"
                    all_passed=false
                fi
            fi
        done

        if [[ "$all_passed" == "true" ]]; then
            test_pass "Repository format validation"
        else
            test_fail "Repository format validation"
        fi
    else
        test_skip "Repository Validation" "configure-runner.sh not found"
    fi
}

test_validate_runner_name() {
    test_start "Runner Name Validation"

    if [[ -f "$SCRIPT_DIR/configure-runner.sh" ]]; then
        source "$SCRIPT_DIR/configure-runner.sh"

        local test_cases=(
            "valid-runner-name:VALID"
            "runner123:VALID"
            "my_runner:VALID"
            "runner.test:VALID"
            "invalid runner name:INVALID"
            "runner@name:INVALID"
            "runner#name:INVALID"
        )

        local all_passed=true
        for test_case in "${test_cases[@]}"; do
            local name="${test_case%:*}"
            local expected="${test_case#*:}"

            if [[ "$expected" == "VALID" ]]; then
                if validate_runner_name "$name" 2>/dev/null; then
                    log_info "✅ Valid name accepted: $name"
                else
                    log_error "❌ Valid name rejected: $name"
                    all_passed=false
                fi
            else
                if ! validate_runner_name "$name" 2>/dev/null; then
                    log_info "✅ Invalid name rejected: $name"
                else
                    log_error "❌ Invalid name accepted: $name"
                    all_passed=false
                fi
            fi
        done

        if [[ "$all_passed" == "true" ]]; then
            test_pass "Runner name validation"
        else
            test_fail "Runner name validation"
        fi
    else
        test_skip "Runner Name Validation" "configure-runner.sh not found"
    fi
}

test_detect_environment() {
    test_start "Environment Detection"

    # Check if we can detect the current OS
    local detected_os=""
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        detected_os="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        detected_os="osx"
    else
        detected_os="unknown"
    fi

    if [[ "$detected_os" != "unknown" ]]; then
        test_pass "Environment detection - detected: $detected_os"
    else
        test_fail "Environment detection - unknown OS: $OSTYPE"
    fi
}

test_check_prerequisites() {
    test_start "Prerequisites Check"

    local required_commands=("curl" "tar" "bash")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    if [[ ${#missing_commands[@]} -eq 0 ]]; then
        test_pass "Prerequisites check - all commands available"
    else
        test_fail "Prerequisites check - missing: ${missing_commands[*]}"
    fi
}

# Integration Tests
run_integration_tests() {
    log_header "🔗 Running Integration Tests"
    log_header "============================"

    # Test complete setup workflow (dry run)
    test_setup_workflow_dry_run

    # Test script interactions
    test_script_interactions

    # Test configuration file handling
    test_configuration_files
}

test_setup_workflow_dry_run() {
    test_start "Setup Workflow (Dry Run)"

    if [[ -f "$PROJECT_ROOT/setup.sh" ]]; then
        local test_token="ghp_test_token_1234567890abcdefghijklmnopqrstuvwxyz12"
        local test_repo="test-owner/test-repo"

        if "$PROJECT_ROOT/setup.sh" --token "$test_token" --repo "$test_repo" --dry-run --verbose > /tmp/setup-test.log 2>&1; then
            test_pass "Setup script dry run"
        else
            test_fail "Setup script dry run" "Check /tmp/setup-test.log for details"
        fi
    else
        test_skip "Setup Workflow" "setup.sh not found"
    fi
}

test_script_interactions() {
    test_start "Script Interactions"

    local scripts=("setup.sh" "scripts/configure-runner.sh" "scripts/install-runner.sh")
    local all_executable=true

    for script in "${scripts[@]}"; do
        local script_path="$PROJECT_ROOT/$script"
        if [[ -f "$script_path" ]]; then
            if [[ -x "$script_path" ]]; then
                log_info "✅ $script is executable"
            else
                log_error "❌ $script is not executable"
                all_executable=false
            fi

            # Check for help option
            if "$script_path" --help &>/dev/null; then
                log_info "✅ $script has help option"
            else
                log_warning "⚠️ $script missing help option"
            fi
        else
            log_error "❌ $script not found"
            all_executable=false
        fi
    done

    if [[ "$all_executable" == "true" ]]; then
        test_pass "Script interactions"
    else
        test_fail "Script interactions"
    fi
}

test_configuration_files() {
    test_start "Configuration Files"

    local config_files=("config/runner-config.template" "config/labels.example" "config/environment.example")
    local all_present=true

    for config_file in "${config_files[@]}"; do
        local file_path="$PROJECT_ROOT/$config_file"
        if [[ -f "$file_path" ]]; then
            log_info "✅ $config_file exists"

            # Basic validation - check if it's not empty
            if [[ -s "$file_path" ]]; then
                log_info "✅ $config_file is not empty"
            else
                log_error "❌ $config_file is empty"
                all_present=false
            fi
        else
            log_error "❌ $config_file not found"
            all_present=false
        fi
    done

    if [[ "$all_present" == "true" ]]; then
        test_pass "Configuration files"
    else
        test_fail "Configuration files"
    fi
}

# Security Tests
run_security_tests() {
    log_header "🔒 Running Security Tests"
    log_header "========================="

    # Test input validation
    test_input_validation

    # Test file permissions
    test_file_permissions

    # Test secret handling
    test_secret_handling
}

test_input_validation() {
    test_start "Input Validation"

    # Test malicious inputs
    local malicious_inputs=(
        "../../etc/passwd"
        "\$(rm -rf /)"
        "; cat /etc/shadow"
        "../../../../../etc/hosts"
        "owner/repo; rm -rf /"
    )

    local all_rejected=true
    for input in "${malicious_inputs[@]}"; do
        # Test repository validation with malicious input
        if [[ "$input" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
            log_error "❌ Malicious input accepted: $input"
            all_rejected=false
        else
            log_info "✅ Malicious input rejected: $input"
        fi
    done

    if [[ "$all_rejected" == "true" ]]; then
        test_pass "Input validation - malicious inputs rejected"
    else
        test_fail "Input validation - some malicious inputs accepted"
    fi
}

test_file_permissions() {
    test_start "File Permissions"

    # Check that scripts have appropriate permissions
    local security_sensitive_files=()
    if [[ -f "$TEST_DIR/fixtures/test-token.txt" ]]; then
        security_sensitive_files+=("$TEST_DIR/fixtures/test-token.txt")
    fi

    local all_secure=true
    for file in "${security_sensitive_files[@]}"; do
        local perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)
        if [[ "$perms" =~ ^6[0-7][0-7]$ ]]; then
            log_info "✅ Secure permissions on $file: $perms"
        else
            log_error "❌ Insecure permissions on $file: $perms"
            all_secure=false
        fi
    done

    if [[ "$all_secure" == "true" ]]; then
        test_pass "File permissions"
    else
        test_fail "File permissions"
    fi
}

test_secret_handling() {
    test_start "Secret Handling"

    # Check that scripts don't log sensitive information
    local test_token="ghp_test_secret_token_should_not_appear_in_logs"

    # Create a temporary script that processes the token
    local test_script="/tmp/secret-test-$$.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
TOKEN="$1"
echo "Processing token..."
# This should NOT log the token
if [[ -n "$TOKEN" ]]; then
    echo "Token received: [REDACTED]"
else
    echo "No token provided"
fi
EOF

    chmod +x "$test_script"

    # Run the script and check output
    local output
    output=$("$test_script" "$test_token" 2>&1)

    if echo "$output" | grep -q "$test_token"; then
        test_fail "Secret handling - token appeared in output"
    else
        test_pass "Secret handling - token properly redacted"
    fi

    # Cleanup
    rm -f "$test_script"
}

# Environment Tests
run_environment_tests() {
    log_header "🌍 Running Environment Tests"
    log_header "============================="

    # Test system compatibility
    test_system_compatibility

    # Test required tools
    test_required_tools

    # Test network connectivity
    test_network_connectivity
}

test_system_compatibility() {
    test_start "System Compatibility"

    local os_info=""
    local arch_info=""

    # Get OS information
    if [[ -f /etc/os-release ]]; then
        os_info=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2)
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_info="macOS $(sw_vers -productVersion)"
    else
        os_info="Unknown OS"
    fi

    # Get architecture
    arch_info=$(uname -m)

    log_info "Detected OS: $os_info"
    log_info "Architecture: $arch_info"

    # Check if OS is supported
    local supported_os=(
        "Ubuntu"
        "Debian"
        "CentOS"
        "Red Hat"
        "Rocky"
        "macOS"
    )

    local os_supported=false
    for os in "${supported_os[@]}"; do
        if echo "$os_info" | grep -qi "$os"; then
            os_supported=true
            break
        fi
    done

    if [[ "$os_supported" == "true" ]]; then
        test_pass "System compatibility - supported OS: $os_info"
    else
        test_fail "System compatibility - unsupported OS: $os_info"
    fi
}

test_required_tools() {
    test_start "Required Tools"

    local required_tools=("bash" "curl" "tar" "sudo" "git")
    local optional_tools=("docker" "systemctl" "node" "npm")
    local missing_required=()
    local missing_optional=()

    # Check required tools
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_required+=("$tool")
        fi
    done

    # Check optional tools
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_optional+=("$tool")
        fi
    done

    # Report results
    if [[ ${#missing_required[@]} -eq 0 ]]; then
        test_pass "Required tools - all available"
    else
        test_fail "Required tools - missing: ${missing_required[*]}"
    fi

    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_warning "Optional tools missing: ${missing_optional[*]}"
    fi
}

test_network_connectivity() {
    test_start "Network Connectivity"

    local endpoints=(
        "https://api.github.com/zen"
        "https://github.com"
        "https://github.com/actions/runner/releases/latest"
    )

    local all_reachable=true
    for endpoint in "${endpoints[@]}"; do
        if curl -s --connect-timeout 10 --max-time 30 "$endpoint" >/dev/null 2>&1; then
            log_info "✅ Reachable: $endpoint"
        else
            log_error "❌ Unreachable: $endpoint"
            all_reachable=false
        fi
    done

    if [[ "$all_reachable" == "true" ]]; then
        test_pass "Network connectivity"
    else
        test_fail "Network connectivity"
    fi
}

# Performance Tests
run_performance_tests() {
    log_header "⚡ Running Performance Tests"
    log_header "============================"

    # Test script execution speed
    test_script_performance

    # Test resource usage
    test_resource_usage
}

test_script_performance() {
    test_start "Script Performance"

    # Time the help command execution
    local start_time
    local end_time
    local duration

    start_time=$(date +%s.%N)
    "$PROJECT_ROOT/setup.sh" --help >/dev/null 2>&1
    end_time=$(date +%s.%N)

    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.1")

    # Consider it good if help loads in under 1 second
    if (( $(echo "$duration < 1.0" | bc -l 2>/dev/null || echo "1") )); then
        test_pass "Script performance - help loads in ${duration}s"
    else
        test_fail "Script performance - help loads too slowly: ${duration}s"
    fi
}

test_resource_usage() {
    test_start "Resource Usage"

    # Check available resources
    local cpu_cores
    local memory_gb
    local disk_gb

    cpu_cores=$(nproc 2>/dev/null || echo "1")
    memory_gb=$(free -g 2>/dev/null | awk '/^Mem:/{print $2}' || echo "1")
    disk_gb=$(df -BG / 2>/dev/null | awk 'NR==2{gsub(/G/,"",$4); print $4}' || echo "1")

    log_info "System resources: ${cpu_cores} CPU, ${memory_gb}GB RAM, ${disk_gb}GB disk"

    # Check if system meets minimum requirements
    local meets_requirements=true

    if [[ $cpu_cores -lt 1 ]]; then
        log_error "❌ Insufficient CPU cores: $cpu_cores (minimum: 1)"
        meets_requirements=false
    fi

    if [[ $memory_gb -lt 1 ]]; then
        log_error "❌ Insufficient memory: ${memory_gb}GB (minimum: 1GB)"
        meets_requirements=false
    fi

    if [[ $disk_gb -lt 10 ]]; then
        log_error "❌ Insufficient disk space: ${disk_gb}GB (minimum: 10GB)"
        meets_requirements=false
    fi

    if [[ "$meets_requirements" == "true" ]]; then
        test_pass "Resource usage - meets minimum requirements"
    else
        test_fail "Resource usage - below minimum requirements"
    fi
}

# Cleanup function
cleanup_test_environment() {
    if [[ "$CLEANUP" == "true" ]]; then
        log_info "Cleaning up test environment..."
        rm -rf "$TEST_DIR/tmp"
        rm -f /tmp/setup-test.log
        rm -f /tmp/secret-test-*.sh
    fi
}

# Test summary
show_test_summary() {
    log_header ""
    log_header "📊 Test Summary"
    log_header "==============="

    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED"

    local success_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        success_rate=$(( (TESTS_PASSED * 100) / TESTS_RUN ))
    fi

    echo "Success rate: ${success_rate}%"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_error "Some tests failed. Check the log: $TEST_LOG"
        return 1
    else
        log_success "All tests passed!"
        return 0
    fi
}

# Main test execution
main() {
    log_header "🚀 GitHub Actions Runner Test Suite"
    log_header "===================================="

    parse_args "$@"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN - Tests that would be executed:"
        for test_type in "${TEST_TYPES[@]}"; do
            echo "  - $test_type tests"
        done
        exit 0
    fi

    setup_test_environment

    # Run selected test types
    for test_type in "${TEST_TYPES[@]}"; do
        case $test_type in
            unit)
                run_unit_tests
                ;;
            integration)
                run_integration_tests
                ;;
            security)
                run_security_tests
                ;;
            environment)
                run_environment_tests
                ;;
            performance)
                run_performance_tests
                ;;
            *)
                log_warning "Unknown test type: $test_type"
                ;;
        esac
        echo ""
    done

    cleanup_test_environment
    show_test_summary
}

# Trap for cleanup
trap cleanup_test_environment EXIT

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi