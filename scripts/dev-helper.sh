#!/bin/bash

# Development Helper Script for GitHub Self-Hosted Runner
# Provides convenient commands for development, testing, and maintenance

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly COMMAND="${1:-help}"
shift || true

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "\n${WHITE}=== $1 ===${NC}\n"
}

# Check all code quality aspects
check_all() {
    log_header "Running All Quality Checks"

    local exit_code=0

    # ShellCheck
    log_info "Running ShellCheck..."
    if check_shellcheck; then
        log_success "ShellCheck passed ✓"
    else
        log_error "ShellCheck failed ✗"
        exit_code=1
    fi

    # Formatting
    log_info "Checking script formatting..."
    if check_format; then
        log_success "Formatting check passed ✓"
    else
        log_error "Formatting check failed ✗"
        exit_code=1
    fi

    # Security
    log_info "Running security scan..."
    if check_security; then
        log_success "Security scan passed ✓"
    else
        log_error "Security issues found ✗"
        exit_code=1
    fi

    # Tests
    log_info "Running tests..."
    if run_tests; then
        log_success "All tests passed ✓"
    else
        log_error "Some tests failed ✗"
        exit_code=1
    fi

    # Architecture compliance (if checker exists locally)
    if [[ -f "$PROJECT_ROOT/scripts/check-architecture-compliance.sh" ]]; then
        log_info "Checking architecture compliance..."
        if check_architecture_compliance; then
            log_success "Architecture compliance check passed ✓"
        else
            log_error "Architecture compliance issues found ✗"
            exit_code=1
        fi
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_success "All checks passed! 🎉"
    else
        log_error "Some checks failed. Please fix the issues before committing."
    fi

    return $exit_code
}

# Run ShellCheck on all scripts
check_shellcheck() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_warning "ShellCheck not installed. Install with: brew install shellcheck (macOS) or apt-get install shellcheck (Linux)"
        return 1
    fi

    local errors=0
    while IFS= read -r -d '' script; do
        if ! shellcheck --external-sources --source-path="$PROJECT_ROOT/scripts" "$script"; then
            ((errors++))
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -type f -print0 | grep -zv node_modules | grep -zv .git)

    return $errors
}

# Check script formatting
check_format() {
    if ! command -v shfmt >/dev/null 2>&1; then
        log_warning "shfmt not installed. Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest"
        return 1
    fi

    local errors=0
    while IFS= read -r -d '' script; do
        if ! shfmt -d -i 4 -ci "$script"; then
            log_warning "Formatting issues in: $script"
            ((errors++))
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -type f -print0 | grep -zv node_modules | grep -zv .git)

    return $errors
}

# Fix formatting issues automatically
fix_format() {
    log_header "Auto-Fixing Script Formatting"

    if ! command -v shfmt >/dev/null 2>&1; then
        log_error "shfmt not installed. Install with: go install mvdan.cc/sh/v3/cmd/shfmt@latest"
        return 1
    fi

    local fixed=0
    while IFS= read -r -d '' script; do
        log_info "Formatting: $script"
        if shfmt -w -i 4 -ci "$script"; then
            ((fixed++))
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -type f -print0 | grep -zv node_modules | grep -zv .git)

    log_success "Fixed formatting in $fixed scripts"
}

# Run security scan
check_security() {
    if ! command -v gitleaks >/dev/null 2>&1; then
        log_warning "GitLeaks not installed. Install from: https://github.com/gitleaks/gitleaks"
        return 1
    fi

    gitleaks detect --config "$PROJECT_ROOT/.gitleaks.toml" --verbose
}

# Run all tests
run_tests() {
    log_header "Running Tests"

    # Check if BATS is installed
    if ! command -v bats >/dev/null 2>&1; then
        log_warning "BATS not installed. Install with: brew install bats-core (macOS)"
        return 1
    fi

    # Run unit tests
    log_info "Running unit tests..."
    if [[ -d "$PROJECT_ROOT/tests/unit" ]]; then
        bats "$PROJECT_ROOT/tests/unit"/*.bats || return 1
    else
        log_warning "No unit tests found"
    fi

    # Run integration tests
    log_info "Running integration tests..."
    if [[ -d "$PROJECT_ROOT/tests/integration" ]]; then
        bats "$PROJECT_ROOT/tests/integration"/*.bats || return 1
    else
        log_warning "No integration tests found"
    fi

    # Run test suite
    if [[ -f "$PROJECT_ROOT/scripts/test-suite.sh" ]]; then
        "$PROJECT_ROOT/scripts/test-suite.sh" --unit-tests || return 1
    fi

    return 0
}

# Check architecture compliance
check_architecture_compliance() {
    if [[ -f "$PROJECT_ROOT/scripts/check-architecture-compliance.sh" ]]; then
        "$PROJECT_ROOT/scripts/check-architecture-compliance.sh"
    else
        log_warning "Architecture compliance checker not found"
        return 1
    fi
}

# Setup development environment
setup_dev() {
    log_header "Setting Up Development Environment"

    # Install pre-commit hooks
    if command -v pre-commit >/dev/null 2>&1; then
        log_info "Installing pre-commit hooks..."
        pre-commit install
        log_success "Pre-commit hooks installed"
    else
        log_warning "pre-commit not installed. Install with: pip install pre-commit"
    fi

    # Install BATS
    if ! command -v bats >/dev/null 2>&1; then
        log_info "Installing BATS testing framework..."
        if [[ "$(uname)" == "Darwin" ]]; then
            brew install bats-core
        else
            git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
            cd /tmp/bats-core
            sudo ./install.sh /usr/local
        fi
    fi

    # Install ShellCheck
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_info "Installing ShellCheck..."
        if [[ "$(uname)" == "Darwin" ]]; then
            brew install shellcheck
        else
            sudo apt-get update && sudo apt-get install -y shellcheck
        fi
    fi

    # Install shfmt
    if ! command -v shfmt >/dev/null 2>&1; then
        log_info "Installing shfmt..."
        go install mvdan.cc/sh/v3/cmd/shfmt@latest
    fi

    # Install GitLeaks
    if ! command -v gitleaks >/dev/null 2>&1; then
        log_info "Installing GitLeaks..."
        if [[ "$(uname)" == "Darwin" ]]; then
            brew install gitleaks
        else
            wget -O /tmp/gitleaks.tar.gz https://github.com/gitleaks/gitleaks/releases/download/v8.18.4/gitleaks_8.18.4_linux_x64.tar.gz
            tar -xzf /tmp/gitleaks.tar.gz -C /tmp
            sudo mv /tmp/gitleaks /usr/local/bin/
        fi
    fi

    log_success "Development environment setup complete"
}

# Get development status
dev_status() {
    log_header "Development Environment Status"

    # Check for required tools
    local tools=("git" "bash" "shellcheck" "shfmt" "bats" "gitleaks" "pre-commit" "jq")

    echo -e "${CYAN}Tool Status:${NC}"
    for tool in "${tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            local version
            case "$tool" in
                git) version=$(git --version | awk '{print $3}') ;;
                bash) version=$(bash --version | head -n1 | awk '{print $4}') ;;
                shellcheck) version=$(shellcheck --version | grep version: | awk '{print $2}') ;;
                shfmt) version=$(shfmt --version 2>&1 || echo "unknown") ;;
                bats) version=$(bats --version | awk '{print $2}') ;;
                gitleaks) version=$(gitleaks version 2>&1 | grep -oE 'v[0-9.]+' || echo "unknown") ;;
                pre-commit) version=$(pre-commit --version | awk '{print $3}') ;;
                jq) version=$(jq --version | sed 's/jq-//') ;;
                *) version="unknown" ;;
            esac
            echo -e "  ${GREEN}✓${NC} $tool ($version)"
        else
            echo -e "  ${RED}✗${NC} $tool (not installed)"
        fi
    done

    # Check for pre-commit hooks
    echo -e "\n${CYAN}Pre-commit Hooks:${NC}"
    if [[ -f "$PROJECT_ROOT/.git/hooks/pre-commit" ]]; then
        echo -e "  ${GREEN}✓${NC} Pre-commit hooks installed"
    else
        echo -e "  ${YELLOW}⚠${NC} Pre-commit hooks not installed (run: dev-helper.sh setup)"
    fi

    # Check for test files
    echo -e "\n${CYAN}Test Coverage:${NC}"
    local unit_tests=$(find "$PROJECT_ROOT/tests/unit" -name "*.bats" 2>/dev/null | wc -l)
    local integration_tests=$(find "$PROJECT_ROOT/tests/integration" -name "*.bats" 2>/dev/null | wc -l)
    echo -e "  Unit tests: $unit_tests"
    echo -e "  Integration tests: $integration_tests"

    # Git status
    echo -e "\n${CYAN}Git Status:${NC}"
    cd "$PROJECT_ROOT"
    local branch=$(git branch --show-current)
    local uncommitted=$(git status --porcelain | wc -l)
    echo -e "  Current branch: $branch"
    echo -e "  Uncommitted changes: $uncommitted"

    # Recent commits
    echo -e "\n${CYAN}Recent Commits:${NC}"
    git log --oneline -5
}

# Clean up development artifacts
clean() {
    log_header "Cleaning Development Artifacts"

    # Clean test artifacts
    rm -rf "$PROJECT_ROOT/.tmp"
    rm -rf "$PROJECT_ROOT/.performance"
    rm -rf "$PROJECT_ROOT/tests/*.log"

    # Clean build artifacts
    find "$PROJECT_ROOT" -name "*.bak" -type f -delete
    find "$PROJECT_ROOT" -name ".DS_Store" -type f -delete

    # Clean temporary files
    rm -rf /tmp/github-runner-test-*
    rm -rf /tmp/bats-*

    log_success "Development artifacts cleaned"
}

# Generate test coverage report
coverage() {
    log_header "Generating Test Coverage Report"

    local total_scripts=$(find "$PROJECT_ROOT/scripts" -name "*.sh" -type f | wc -l)
    local tested_scripts=0

    echo "Analyzing test coverage..."

    # Check which scripts have corresponding tests
    while IFS= read -r script; do
        local script_name=$(basename "$script" .sh)
        if grep -r "$script_name" "$PROJECT_ROOT/tests" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $script_name"
            ((tested_scripts++))
        else
            echo -e "  ${RED}✗${NC} $script_name (no tests found)"
        fi
    done < <(find "$PROJECT_ROOT/scripts" -name "*.sh" -type f)

    local coverage=$((tested_scripts * 100 / total_scripts))
    echo -e "\nCoverage: ${coverage}% ($tested_scripts/$total_scripts scripts tested)"

    if [[ $coverage -lt 80 ]]; then
        log_warning "Test coverage is below 80%. Consider adding more tests."
    else
        log_success "Good test coverage!"
    fi
}

# Show usage
show_usage() {
    cat << EOF
${WHITE}GitHub Self-Hosted Runner - Development Helper${NC}

${CYAN}Usage:${NC}
    $0 <command> [options]

${CYAN}Commands:${NC}
    ${GREEN}check:all${NC}      Run all quality checks
    ${GREEN}check:lint${NC}     Run ShellCheck on all scripts
    ${GREEN}check:format${NC}   Check script formatting
    ${GREEN}check:security${NC} Run security scan
    ${GREEN}check:arch${NC}     Check architecture compliance (if available locally)

    ${GREEN}fix:format${NC}     Auto-fix formatting issues

    ${GREEN}test${NC}           Run all tests
    ${GREEN}test:unit${NC}      Run unit tests only
    ${GREEN}test:integration${NC} Run integration tests only

    ${GREEN}setup${NC}          Set up development environment
    ${GREEN}status${NC}         Show development environment status
    ${GREEN}coverage${NC}       Generate test coverage report
    ${GREEN}clean${NC}          Clean development artifacts

    ${GREEN}help${NC}           Show this help message

${CYAN}Examples:${NC}
    $0 check:all        # Run all quality checks
    $0 fix:format       # Auto-fix formatting issues
    $0 test            # Run all tests
    $0 setup           # Set up development environment
    $0 status          # Check development status

${CYAN}Quick Development Workflow:${NC}
    1. $0 setup         # Initial setup
    2. $0 check:all     # Before committing
    3. $0 fix:format    # Auto-fix issues
    4. $0 test         # Run tests

EOF
}

# Main command dispatcher
case "$COMMAND" in
    check:all|check-all|check)
        check_all
        ;;
    check:lint|lint)
        check_shellcheck
        ;;
    check:format|format)
        check_format
        ;;
    check:security|security)
        check_security
        ;;
    check:arch|arch)
        check_architecture_compliance
        ;;
    fix:format|fix-format|fix)
        fix_format
        ;;
    test)
        run_tests
        ;;
    test:unit|unit)
        bats "$PROJECT_ROOT/tests/unit"/*.bats
        ;;
    test:integration|integration)
        bats "$PROJECT_ROOT/tests/integration"/*.bats
        ;;
    setup)
        setup_dev
        ;;
    status|dev-status)
        dev_status
        ;;
    coverage)
        coverage
        ;;
    clean)
        clean
        ;;
    help|--help|-h|"")
        show_usage
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac