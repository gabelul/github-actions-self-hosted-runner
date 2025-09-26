#!/bin/bash

# GitHub Actions Self-Hosted Runner - Security Audit Script
#
# This script performs comprehensive security auditing for the runner
# installation and configuration. It checks for common security issues,
# misconfigurations, and compliance with best practices.
#
# Usage:
#   ./security-audit.sh                    # Full security audit
#   ./security-audit.sh --quick           # Quick security check
#   ./security-audit.sh --fix             # Attempt to fix issues
#   ./security-audit.sh --help            # Show help

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly TEMP_DIR="$PROJECT_ROOT/.tmp"
readonly AUDIT_LOG="$TEMP_DIR/tests/github-runner-security-audit-$$.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Security check configuration
QUICK_MODE=false
FIX_ISSUES=false
VERBOSE=false

# Security counters
CHECKS_RUN=0
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$AUDIT_LOG"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$AUDIT_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$AUDIT_LOG"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$AUDIT_LOG"
}

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1" | tee -a "$AUDIT_LOG"
}

log_header() {
    echo -e "${WHITE}$1${NC}" | tee -a "$AUDIT_LOG"
}

# Security check functions
security_pass() {
    local check_name="$1"
    log_success "$check_name"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

security_warn() {
    local check_name="$1"
    local issue="${2:-No details provided}"
    log_warning "$check_name - $issue"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
}

security_fail() {
    local check_name="$1"
    local issue="${2:-No details provided}"
    log_error "$check_name - $issue"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

security_critical() {
    local check_name="$1"
    local issue="${2:-No details provided}"
    log_critical "$check_name - $issue"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

# Show help information
show_help() {
    cat << EOF
${WHITE}GitHub Actions Self-Hosted Runner - Security Audit${NC}

Comprehensive security analysis and hardening for GitHub Actions runners.

${WHITE}USAGE:${NC}
    $0 [OPTIONS]

${WHITE}OPTIONS:${NC}
    --quick            Perform quick security check (essential checks only)
    --fix              Attempt to automatically fix security issues
    --verbose          Enable verbose output and detailed explanations
    --log-file FILE    Custom log file location
    --help             Show this help message

${WHITE}SECURITY CHECKS:${NC}
    - File permissions and ownership
    - User account security
    - Network configuration
    - Service configuration
    - Secret management
    - Input validation
    - System hardening
    - Compliance verification

${WHITE}EXAMPLES:${NC}
    # Full security audit
    $0

    # Quick security check
    $0 --quick

    # Audit with automatic fixes
    $0 --fix --verbose

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --fix)
                FIX_ISSUES=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --log-file)
                AUDIT_LOG="$2"
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
}

# File Permission Checks
check_file_permissions() {
    log_header "🔒 File Permission Security Checks"
    log_header "=================================="

    # Check script permissions
    check_script_permissions

    # Check configuration file permissions
    check_config_permissions

    # Check sensitive file permissions
    check_sensitive_files

    # Check directory permissions
    check_directory_permissions
}

check_script_permissions() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    local scripts=(
        "$PROJECT_ROOT/setup.sh"
        "$PROJECT_ROOT/scripts/install-runner.sh"
        "$PROJECT_ROOT/scripts/configure-runner.sh"
        "$PROJECT_ROOT/scripts/add-runner.sh"
        "$PROJECT_ROOT/scripts/remove-runner.sh"
    )

    local all_secure=true

    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            local perms
            perms=$(stat -c "%a" "$script" 2>/dev/null || stat -f "%A" "$script" 2>/dev/null)
            local owner
            owner=$(stat -c "%U" "$script" 2>/dev/null || stat -f "%Su" "$script" 2>/dev/null)

            # Check if file is executable by owner and group only (755 or 750)
            if [[ "$perms" =~ ^75[0-5]$ ]]; then
                if [[ "$VERBOSE" == "true" ]]; then
                    log_info "✅ Script permissions OK: $script ($perms, $owner)"
                fi
            else
                log_error "❌ Insecure script permissions: $script ($perms)"
                all_secure=false

                if [[ "$FIX_ISSUES" == "true" ]]; then
                    log_info "🔧 Fixing permissions for $script"
                    chmod 755 "$script"
                fi
            fi
        fi
    done

    if [[ "$all_secure" == "true" ]]; then
        security_pass "Script permissions"
    else
        security_fail "Script permissions" "Some scripts have insecure permissions"
    fi
}

check_config_permissions() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    local config_dirs=("/etc/github-runner" "/home/github-runner/.config")
    local all_secure=true

    for config_dir in "${config_dirs[@]}"; do
        if [[ -d "$config_dir" ]]; then
            # Check .env files
            while IFS= read -r -d '' env_file; do
                local perms
                perms=$(stat -c "%a" "$env_file" 2>/dev/null || stat -f "%A" "$env_file" 2>/dev/null)

                if [[ "$perms" =~ ^6[0-7]0$ ]]; then
                    if [[ "$VERBOSE" == "true" ]]; then
                        log_info "✅ Config file permissions OK: $env_file ($perms)"
                    fi
                else
                    log_error "❌ Insecure config file permissions: $env_file ($perms)"
                    all_secure=false

                    if [[ "$FIX_ISSUES" == "true" ]]; then
                        log_info "🔧 Fixing permissions for $env_file"
                        chmod 600 "$env_file"
                    fi
                fi
            done < <(find "$config_dir" -name "*.env" -type f -print0 2>/dev/null || true)
        fi
    done

    if [[ "$all_secure" == "true" ]]; then
        security_pass "Configuration file permissions"
    else
        security_fail "Configuration file permissions" "Some config files have insecure permissions"
    fi
}

check_sensitive_files() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    local sensitive_patterns=(
        "**/token*"
        "**/secret*"
        "**/.credentials*"
        "**/.runner"
        "**/id_rsa*"
        "**/id_ed25519*"
    )

    local all_secure=true

    for pattern in "${sensitive_patterns[@]}"; do
        while IFS= read -r -d '' file; do
            local perms
            perms=$(stat -c "%a" "$file" 2>/dev/null || stat -f "%A" "$file" 2>/dev/null)

            if [[ "$perms" =~ ^6[0-7]0$ ]]; then
                if [[ "$VERBOSE" == "true" ]]; then
                    log_info "✅ Sensitive file permissions OK: $file ($perms)"
                fi
            else
                log_error "❌ Insecure sensitive file permissions: $file ($perms)"
                all_secure=false

                if [[ "$FIX_ISSUES" == "true" ]]; then
                    log_info "🔧 Fixing permissions for $file"
                    chmod 600 "$file"
                fi
            fi
        done < <(find /home/github-runner 2>/dev/null -path "$pattern" -type f -print0 2>/dev/null || true)
    done

    if [[ "$all_secure" == "true" ]]; then
        security_pass "Sensitive file permissions"
    else
        security_fail "Sensitive file permissions" "Some sensitive files have insecure permissions"
    fi
}

check_directory_permissions() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    local directories=(
        "/home/github-runner"
        "/home/github-runner/runners"
        "/etc/github-runner"
    )

    local all_secure=true

    for dir in "${directories[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms
            perms=$(stat -c "%a" "$dir" 2>/dev/null || stat -f "%A" "$dir" 2>/dev/null)
            local owner
            owner=$(stat -c "%U" "$dir" 2>/dev/null || stat -f "%Su" "$dir" 2>/dev/null)

            # Check if directory has appropriate permissions (755 or 750)
            if [[ "$perms" =~ ^75[0-5]$ ]]; then
                if [[ "$VERBOSE" == "true" ]]; then
                    log_info "✅ Directory permissions OK: $dir ($perms, $owner)"
                fi
            else
                log_error "❌ Insecure directory permissions: $dir ($perms)"
                all_secure=false

                if [[ "$FIX_ISSUES" == "true" ]]; then
                    log_info "🔧 Fixing permissions for $dir"
                    chmod 755 "$dir"
                fi
            fi
        fi
    done

    if [[ "$all_secure" == "true" ]]; then
        security_pass "Directory permissions"
    else
        security_fail "Directory permissions" "Some directories have insecure permissions"
    fi
}

# User Account Security
check_user_security() {
    log_header ""
    log_header "👤 User Account Security Checks"
    log_header "==============================="

    check_runner_user
    check_sudo_configuration
    check_user_groups
}

check_runner_user() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    if id "github-runner" &>/dev/null; then
        local user_info
        user_info=$(getent passwd github-runner)
        local home_dir
        home_dir=$(echo "$user_info" | cut -d: -f6)
        local shell
        shell=$(echo "$user_info" | cut -d: -f7)

        # Check home directory
        if [[ "$home_dir" == "/home/github-runner" ]]; then
            if [[ "$VERBOSE" == "true" ]]; then
                log_info "✅ Runner user home directory correct: $home_dir"
            fi
        else
            security_warn "Runner user home directory" "Unexpected home directory: $home_dir"
        fi

        # Check shell
        if [[ "$shell" =~ ^/bin/(bash|sh)$ ]]; then
            if [[ "$VERBOSE" == "true" ]]; then
                log_info "✅ Runner user shell appropriate: $shell"
            fi
        else
            security_warn "Runner user shell" "Unusual shell: $shell"
        fi

        security_pass "Runner user configuration"
    else
        security_fail "Runner user" "github-runner user does not exist"
    fi
}

check_sudo_configuration() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    if [[ -f "/etc/sudoers.d/github-runner" ]]; then
        local sudo_config
        sudo_config=$(cat "/etc/sudoers.d/github-runner")

        # Check for overly permissive sudo rules
        if echo "$sudo_config" | grep -q "ALL=(ALL) NOPASSWD: ALL"; then
            security_critical "Sudo configuration" "github-runner has unrestricted sudo access"
        elif echo "$sudo_config" | grep -q "NOPASSWD"; then
            # Check what specific commands are allowed
            if echo "$sudo_config" | grep -q "systemctl\|docker\|service"; then
                security_pass "Sudo configuration - limited access"
            else
                security_warn "Sudo configuration" "Review sudo permissions"
            fi
        else
            security_pass "Sudo configuration"
        fi
    else
        security_warn "Sudo configuration" "No sudo configuration found for github-runner"
    fi
}

check_user_groups() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    if id "github-runner" &>/dev/null; then
        local groups
        groups=$(groups github-runner 2>/dev/null | cut -d: -f2)

        # Check for potentially dangerous group memberships
        local dangerous_groups=("root" "wheel" "admin")
        local has_dangerous_group=false

        for group in $groups; do
            for dangerous in "${dangerous_groups[@]}"; do
                if [[ "$group" == "$dangerous" ]]; then
                    security_critical "User group membership" "github-runner in dangerous group: $group"
                    has_dangerous_group=true
                fi
            done
        done

        if [[ "$has_dangerous_group" == "false" ]]; then
            security_pass "User group membership"
        fi
    else
        security_fail "User groups" "Cannot check groups for github-runner user"
    fi
}

# Network Security
check_network_security() {
    if [[ "$QUICK_MODE" == "true" ]]; then
        return 0
    fi

    log_header ""
    log_header "🌐 Network Security Checks"
    log_header "=========================="

    check_firewall_configuration
    check_open_ports
    check_network_connections
}

check_firewall_configuration() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    # Check UFW (Ubuntu/Debian)
    if command -v ufw &>/dev/null; then
        local ufw_status
        ufw_status=$(sudo ufw status 2>/dev/null | head -1)

        if echo "$ufw_status" | grep -q "Status: active"; then
            security_pass "Firewall configuration (UFW active)"
        else
            security_warn "Firewall configuration" "UFW is not active"
        fi

    # Check iptables
    elif command -v iptables &>/dev/null; then
        local iptables_rules
        iptables_rules=$(sudo iptables -L 2>/dev/null | wc -l)

        if [[ $iptables_rules -gt 10 ]]; then
            security_pass "Firewall configuration (iptables rules present)"
        else
            security_warn "Firewall configuration" "Limited iptables rules detected"
        fi
    else
        security_warn "Firewall configuration" "No firewall detected"
    fi
}

check_open_ports() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    if command -v netstat &>/dev/null; then
        local listening_ports
        listening_ports=$(netstat -tuln 2>/dev/null | grep LISTEN | awk '{print $4}' | cut -d: -f2 | sort -n | uniq)

        # Check for commonly dangerous ports
        local dangerous_ports=("21" "23" "25" "53" "135" "139" "445" "1433" "3306" "5432")
        local found_dangerous=false

        for port in $listening_ports; do
            for dangerous in "${dangerous_ports[@]}"; do
                if [[ "$port" == "$dangerous" ]]; then
                    security_warn "Open ports" "Potentially dangerous port open: $port"
                    found_dangerous=true
                fi
            done
        done

        if [[ "$found_dangerous" == "false" ]]; then
            security_pass "Open ports check"
        fi
    else
        security_warn "Open ports" "Cannot check open ports (netstat not available)"
    fi
}

check_network_connections() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    # Check if runner can reach GitHub
    if curl -s --connect-timeout 5 https://api.github.com/zen >/dev/null; then
        security_pass "GitHub connectivity"
    else
        security_fail "GitHub connectivity" "Cannot reach GitHub API"
    fi

    # Check for unexpected outbound connections
    if command -v netstat &>/dev/null; then
        local suspicious_connections
        suspicious_connections=$(netstat -tn 2>/dev/null | grep ESTABLISHED | grep -v ":443\|:80\|:22" | wc -l)

        if [[ $suspicious_connections -eq 0 ]]; then
            security_pass "Network connections"
        else
            security_warn "Network connections" "$suspicious_connections non-standard connections detected"
        fi
    fi
}

# Service Security
check_service_security() {
    log_header ""
    log_header "⚙️  Service Security Checks"
    log_header "==========================="

    check_systemd_services
    check_service_configuration
    check_process_isolation
}

check_systemd_services() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    if command -v systemctl &>/dev/null; then
        local runner_services
        runner_services=$(systemctl list-units --type=service --state=active 2>/dev/null | grep github-runner | wc -l)

        if [[ $runner_services -gt 0 ]]; then
            security_pass "SystemD services - $runner_services runner services active"

            # Check service isolation
            local service_files
            service_files=$(find /etc/systemd/system -name "*github-runner*" 2>/dev/null)

            for service_file in $service_files; do
                if [[ -f "$service_file" ]]; then
                    # Check for security hardening options
                    local hardening_options=("ProtectSystem" "ProtectHome" "NoNewPrivileges" "PrivateTmp")
                    local missing_options=()

                    for option in "${hardening_options[@]}"; do
                        if ! grep -q "^$option=" "$service_file"; then
                            missing_options+=("$option")
                        fi
                    done

                    if [[ ${#missing_options[@]} -eq 0 ]]; then
                        security_pass "Service hardening - $service_file"
                    else
                        security_warn "Service hardening" "$service_file missing: ${missing_options[*]}"
                    fi
                fi
            done
        else
            security_warn "SystemD services" "No active github-runner services found"
        fi
    else
        security_warn "SystemD services" "SystemD not available"
    fi
}

check_service_configuration() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    # Check if runners are running as non-root
    if command -v ps &>/dev/null; then
        local runner_processes
        runner_processes=$(ps aux | grep -E "(Runner\.|run\.sh)" | grep -v grep)

        if [[ -n "$runner_processes" ]]; then
            local running_as_root
            running_as_root=$(echo "$runner_processes" | awk '$1 == "root"' | wc -l)

            if [[ $running_as_root -eq 0 ]]; then
                security_pass "Non-root execution"
            else
                security_critical "Non-root execution" "$running_as_root runners running as root"
            fi
        else
            security_warn "Service configuration" "No active runner processes found"
        fi
    fi
}

check_process_isolation() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    # Check if runners have proper process limits
    if command -v pgrep &>/dev/null && command -v ps &>/dev/null; then
        local runner_pids
        runner_pids=$(pgrep -f "Runner\." 2>/dev/null || true)

        if [[ -n "$runner_pids" ]]; then
            local high_resource_processes=0

            for pid in $runner_pids; do
                local cpu_usage
                cpu_usage=$(ps -p "$pid" -o %cpu --no-headers 2>/dev/null | tr -d ' ' || echo "0")

                if (( $(echo "$cpu_usage > 80.0" | bc -l 2>/dev/null || echo "0") )); then
                    high_resource_processes=$((high_resource_processes + 1))
                fi
            done

            if [[ $high_resource_processes -eq 0 ]]; then
                security_pass "Process resource usage"
            else
                security_warn "Process resource usage" "$high_resource_processes high-CPU processes"
            fi
        fi
    fi
}

# Secret Management
check_secret_management() {
    log_header ""
    log_header "🔐 Secret Management Checks"
    log_header "==========================="

    check_token_storage
    check_environment_variables
    check_log_security
}

check_token_storage() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    local token_files=()
    local all_secure=true

    # Find potential token files
    while IFS= read -r -d '' file; do
        token_files+=("$file")
    done < <(find /home/github-runner /etc/github-runner 2>/dev/null \
             -type f \( -name "*.env" -o -name "*token*" -o -name ".credentials*" \) \
             -print0 2>/dev/null || true)

    for token_file in "${token_files[@]}"; do
        if [[ -f "$token_file" ]]; then
            # Check permissions
            local perms
            perms=$(stat -c "%a" "$token_file" 2>/dev/null || stat -f "%A" "$token_file" 2>/dev/null)

            if [[ "$perms" =~ ^6[0-7]0$ ]]; then
                if [[ "$VERBOSE" == "true" ]]; then
                    log_info "✅ Token file permissions OK: $token_file"
                fi
            else
                security_fail "Token storage" "Insecure permissions on $token_file: $perms"
                all_secure=false
            fi

            # Check for tokens in plain text (basic pattern matching)
            if grep -q "ghp_\|ghs_\|github_pat_" "$token_file" 2>/dev/null; then
                if [[ "$VERBOSE" == "true" ]]; then
                    log_info "✅ GitHub token pattern found in $token_file"
                fi
            fi
        fi
    done

    if [[ "$all_secure" == "true" ]]; then
        security_pass "Token storage"
    fi
}

check_environment_variables() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    # Check if tokens are exposed in environment
    local exposed_tokens=false

    # Check current environment
    if env | grep -q "GITHUB_TOKEN\|GITHUB_PAT"; then
        security_warn "Environment variables" "GitHub tokens found in environment"
        exposed_tokens=true
    fi

    # Check process environment (if we can)
    if command -v pgrep &>/dev/null; then
        local runner_pids
        runner_pids=$(pgrep -f "Runner\." 2>/dev/null || true)

        for pid in $runner_pids; do
            if [[ -f "/proc/$pid/environ" ]] && [[ -r "/proc/$pid/environ" ]]; then
                if tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | grep -q "GITHUB_TOKEN\|GITHUB_PAT"; then
                    security_warn "Process environment" "GitHub tokens in process environment"
                    exposed_tokens=true
                fi
            fi
        done
    fi

    if [[ "$exposed_tokens" == "false" ]]; then
        security_pass "Environment variable security"
    fi
}

check_log_security() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    local log_locations=(
        "/var/log"
        "/home/github-runner"
        "/tmp"
    )

    local tokens_in_logs=false

    for log_location in "${log_locations[@]}"; do
        if [[ -d "$log_location" ]]; then
            # Look for potential token leaks in log files
            while IFS= read -r -d '' log_file; do
                if grep -q "ghp_\|ghs_\|github_pat_" "$log_file" 2>/dev/null; then
                    security_critical "Log security" "GitHub token found in log: $log_file"
                    tokens_in_logs=true
                fi
            done < <(find "$log_location" -name "*.log" -type f -readable -print0 2>/dev/null || true)
        fi
    done

    if [[ "$tokens_in_logs" == "false" ]]; then
        security_pass "Log security - no tokens in logs"
    fi
}

# System Hardening
check_system_hardening() {
    if [[ "$QUICK_MODE" == "true" ]]; then
        return 0
    fi

    log_header ""
    log_header "🛡️  System Hardening Checks"
    log_header "==========================="

    check_os_updates
    check_unnecessary_services
    check_kernel_parameters
}

check_os_updates() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    # Check for available security updates
    if command -v apt-get &>/dev/null; then
        log_info "Checking for security updates..."
        local security_updates
        security_updates=$(apt list --upgradable 2>/dev/null | grep -c "security" || echo "0")

        if [[ $security_updates -eq 0 ]]; then
            security_pass "OS security updates"
        else
            security_warn "OS security updates" "$security_updates security updates available"
        fi

    elif command -v yum &>/dev/null; then
        local security_updates
        security_updates=$(yum --security check-update 2>/dev/null | grep -c "security" || echo "0")

        if [[ $security_updates -eq 0 ]]; then
            security_pass "OS security updates"
        else
            security_warn "OS security updates" "$security_updates security updates available"
        fi
    else
        security_warn "OS security updates" "Cannot check updates (no package manager found)"
    fi
}

check_unnecessary_services() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    if command -v systemctl &>/dev/null; then
        # List of potentially unnecessary services for a runner
        local unnecessary_services=("apache2" "nginx" "mysql" "postgresql" "samba" "nfs" "rpcbind")
        local running_unnecessary=()

        for service in "${unnecessary_services[@]}"; do
            if systemctl is-active --quiet "$service" 2>/dev/null; then
                running_unnecessary+=("$service")
            fi
        done

        if [[ ${#running_unnecessary[@]} -eq 0 ]]; then
            security_pass "Unnecessary services"
        else
            security_warn "Unnecessary services" "Running services: ${running_unnecessary[*]}"
        fi
    else
        security_warn "Unnecessary services" "Cannot check services (systemctl not available)"
    fi
}

check_kernel_parameters() {
    CHECKS_RUN=$((CHECKS_RUN + 1))

    # Check important kernel security parameters
    local security_params=(
        "net.ipv4.ip_forward:0"
        "net.ipv4.conf.all.send_redirects:0"
        "net.ipv4.conf.default.send_redirects:0"
        "net.ipv4.conf.all.accept_redirects:0"
    )

    local insecure_params=()

    for param in "${security_params[@]}"; do
        local param_name="${param%:*}"
        local expected_value="${param#*:}"
        local current_value

        current_value=$(sysctl -n "$param_name" 2>/dev/null || echo "unknown")

        if [[ "$current_value" != "$expected_value" ]]; then
            insecure_params+=("$param_name=$current_value")
        fi
    done

    if [[ ${#insecure_params[@]} -eq 0 ]]; then
        security_pass "Kernel security parameters"
    else
        security_warn "Kernel security parameters" "Insecure: ${insecure_params[*]}"
    fi
}

# Generate Security Report
generate_security_report() {
    log_header ""
    log_header "📋 Security Audit Summary"
    log_header "========================="

    echo "Checks performed: $CHECKS_RUN"
    echo "Passed: $CHECKS_PASSED"
    echo "Warnings: $CHECKS_WARNING"
    echo "Failed: $CHECKS_FAILED"

    local risk_level="LOW"
    if [[ $CHECKS_FAILED -gt 0 ]]; then
        risk_level="HIGH"
    elif [[ $CHECKS_WARNING -gt 3 ]]; then
        risk_level="MEDIUM"
    fi

    echo "Overall risk level: $risk_level"

    if [[ $CHECKS_FAILED -gt 0 ]]; then
        echo ""
        log_error "CRITICAL ISSUES DETECTED!"
        log_error "Please review the audit log: $AUDIT_LOG"
        log_error "Address failed checks before deploying to production."
    elif [[ $CHECKS_WARNING -gt 0 ]]; then
        echo ""
        log_warning "Warnings detected. Review recommendations in: $AUDIT_LOG"
    else
        echo ""
        log_success "Security audit passed! No critical issues found."
    fi

    echo ""
    log_info "Full audit log: $AUDIT_LOG"
}

# Main security audit execution
main() {
    log_header "🔐 GitHub Actions Runner Security Audit"
    log_header "========================================"

    parse_args "$@"

    log_info "Starting security audit..."
    log_info "Quick mode: $QUICK_MODE"
    log_info "Fix issues: $FIX_ISSUES"

    # Run security checks
    check_file_permissions
    check_user_security

    if [[ "$QUICK_MODE" == "false" ]]; then
        check_network_security
        check_service_security
        check_secret_management
        check_system_hardening
    fi

    generate_security_report

    # Return appropriate exit code
    if [[ $CHECKS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi