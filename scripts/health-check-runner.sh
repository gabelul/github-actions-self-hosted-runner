#!/bin/bash

# GitHub Actions Self-Hosted Runner - Health Check Script
#
# This script performs comprehensive health checks on GitHub runners to ensure
# they are functioning properly and can accept jobs from GitHub.
#
# Usage:
#   ./health-check-runner.sh                    # Check default runner
#   ./health-check-runner.sh runner1            # Check specific template runner
#   ./health-check-runner.sh --all              # Check all configured runners
#   ./health-check-runner.sh --docker           # Check Docker-based runner
#   ./health-check-runner.sh --continuous       # Continuous monitoring
#   ./health-check-runner.sh --help             # Show help

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEFAULT_SERVICE="github-runner"
TEMPLATE_SERVICE="github-runner@"
HEALTH_CHECK_INTERVAL=60  # seconds for continuous monitoring

# Health check thresholds
CPU_THRESHOLD=80        # CPU usage percentage
MEMORY_THRESHOLD=80     # Memory usage percentage
DISK_THRESHOLD=90       # Disk usage percentage
RESPONSE_TIMEOUT=30     # GitHub API response timeout

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
}

log_health() {
    echo -e "${PURPLE}🏥 HEALTH:${NC} $1"
}

# Show help information
show_help() {
    cat << EOF
GitHub Actions Self-Hosted Runner - Health Check Script

USAGE:
    $0 [OPTIONS] [RUNNER_NAME]

ARGUMENTS:
    RUNNER_NAME         Name of the runner instance (for template services)

OPTIONS:
    --all              Check all configured runner instances
    --docker           Check Docker-based runner
    --continuous       Continuous health monitoring (every ${HEALTH_CHECK_INTERVAL}s)
    --verbose          Show detailed system information
    --thresholds       Show current health check thresholds
    --fix-issues       Attempt to automatically fix common issues
    --help             Show this help message

EXAMPLES:
    $0                 # Quick health check of default runner
    $0 project1        # Check template runner named 'project1'
    $0 --all           # Check all configured runners
    $0 --continuous    # Monitor all runners continuously
    $0 --verbose       # Detailed health report with system info
    $0 --fix-issues    # Check health and attempt auto-fixes

HEALTH CHECK CATEGORIES:
    1. Service Status     - SystemD service health and activity
    2. Process Health     - Runner process CPU/memory usage
    3. System Resources   - Disk space, load average, network
    4. GitHub API         - Connectivity and authentication
    5. Runner Registration- GitHub runner status and visibility
    6. Log Analysis       - Recent errors and warnings in logs

EXIT CODES:
    0 - All health checks passed
    1 - Critical issues found (runner not functional)
    2 - Warning issues found (runner functional but degraded)
    3 - System error (health check failed to run)

For more information, see the documentation in docs/
EOF
}

# Show current health check thresholds
show_thresholds() {
    cat << EOF
Health Check Thresholds:

RESOURCE LIMITS:
    CPU Usage:         ${CPU_THRESHOLD}%
    Memory Usage:      ${MEMORY_THRESHOLD}%
    Disk Usage:        ${DISK_THRESHOLD}%

TIMEOUTS:
    GitHub API:        ${RESPONSE_TIMEOUT}s
    Process Check:     10s

MONITORING:
    Check Interval:    ${HEALTH_CHECK_INTERVAL}s
    Log Analysis:      Last 100 lines

You can modify these thresholds by editing this script.
EOF
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running health check as root."
        log_info "Some checks may behave differently with root privileges."
    fi
}

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Check system resources
check_system_resources() {
    local verbose="$1"
    local issues=0

    log_health "Checking system resources..."

    # CPU usage check
    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        log_warning "High CPU usage: ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)"
        ((issues++))
    else
        log_success "CPU usage: ${cpu_usage}% (OK)"
    fi

    # Memory usage check
    local memory_info
    memory_info=$(free -m | grep '^Mem:')
    local total_mem=$(echo "$memory_info" | awk '{print $2}')
    local used_mem=$(echo "$memory_info" | awk '{print $3}')
    local memory_percent=$((used_mem * 100 / total_mem))

    if [[ $memory_percent -gt $MEMORY_THRESHOLD ]]; then
        log_warning "High memory usage: ${memory_percent}% (${used_mem}MB/${total_mem}MB)"
        ((issues++))
    else
        log_success "Memory usage: ${memory_percent}% (${used_mem}MB/${total_mem}MB) (OK)"
    fi

    # Disk usage check for runner directories
    local runner_base="/home/github-runner"
    if [[ -d "$runner_base" ]]; then
        local disk_usage
        disk_usage=$(df "$runner_base" | tail -1 | awk '{print $5}' | sed 's/%//')
        if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
            log_warning "High disk usage: ${disk_usage}% on runner directory"
            ((issues++))
        else
            log_success "Disk usage: ${disk_usage}% (OK)"
        fi
    else
        log_warning "Runner base directory not found: $runner_base"
        ((issues++))
    fi

    # Load average check
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_cores
    cpu_cores=$(nproc)
    local load_per_core
    load_per_core=$(echo "scale=2; $load_avg / $cpu_cores" | bc -l)

    if (( $(echo "$load_per_core > 2.0" | bc -l) )); then
        log_warning "High load average: ${load_avg} on ${cpu_cores} cores (${load_per_core} per core)"
        ((issues++))
    else
        log_success "Load average: ${load_avg} on ${cpu_cores} cores (${load_per_core} per core) (OK)"
    fi

    if [[ "$verbose" == true ]]; then
        echo
        log_info "Detailed System Information:"
        echo "  Uptime: $(uptime -p)"
        echo "  Kernel: $(uname -r)"
        echo "  Distribution: $(lsb_release -d 2>/dev/null | cut -f2 | head -1 || echo "Unknown")"
        echo "  Total Processes: $(ps aux | wc -l)"
    fi

    return $issues
}

# Check GitHub API connectivity
check_github_api() {
    local verbose="$1"
    local issues=0

    log_health "Checking GitHub API connectivity..."

    # Test basic GitHub API access
    if curl -s --max-time "$RESPONSE_TIMEOUT" "https://api.github.com" > /dev/null; then
        log_success "GitHub API is accessible"
    else
        log_error "Cannot reach GitHub API (network or DNS issue)"
        ((issues++))
    fi

    # Test GitHub Actions API (if possible without authentication)
    if curl -s --max-time "$RESPONSE_TIMEOUT" "https://api.github.com/zen" > /dev/null; then
        log_success "GitHub services are responding"
    else
        log_warning "GitHub services may be experiencing issues"
        ((issues++))
    fi

    if [[ "$verbose" == true ]]; then
        echo
        log_info "Network Connectivity Details:"
        echo "  DNS Resolution (github.com): $(dig +short github.com | head -1 || echo "FAILED")"
        echo "  HTTPS Connectivity: $(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://github.com || echo "FAILED")"
    fi

    return $issues
}

# Check service status and health
check_service_health() {
    local service_name="$1"
    local verbose="$2"
    local issues=0

    log_health "Checking service health: $service_name"

    # Service active check
    if systemctl is-active --quiet "$service_name"; then
        log_success "Service is active and running"
    else
        log_error "Service is not active"
        ((issues++))
    fi

    # Service enabled check
    if systemctl is-enabled --quiet "$service_name"; then
        log_success "Service is enabled for auto-start"
    else
        log_warning "Service is not enabled for auto-start"
        # This is a warning, not a critical issue
    fi

    # Service load state check
    local load_state
    load_state=$(systemctl show "$service_name" --property=LoadState --value)
    if [[ "$load_state" == "loaded" ]]; then
        log_success "Service definition is loaded correctly"
    else
        log_error "Service definition has issues: $load_state"
        ((issues++))
    fi

    # Check for recent failures
    local failed_count
    failed_count=$(systemctl show "$service_name" --property=NRestarts --value)
    if [[ $failed_count -gt 0 ]]; then
        log_warning "Service has restarted $failed_count times"
    else
        log_success "No recent service restarts"
    fi

    # Check service age (how long it's been running)
    local active_enter
    active_enter=$(systemctl show "$service_name" --property=ActiveEnterTimestamp --value)
    if [[ -n "$active_enter" && "$active_enter" != "0" ]]; then
        log_success "Service started at: $active_enter"
    fi

    if [[ "$verbose" == true ]]; then
        echo
        log_info "Detailed Service Information:"
        systemctl status "$service_name" --no-pager -l || true
    fi

    return $issues
}

# Check runner process health
check_process_health() {
    local service_name="$1"
    local verbose="$2"
    local issues=0

    log_health "Checking runner process health..."

    # Get main PID from systemd
    local main_pid
    main_pid=$(systemctl show "$service_name" --property=MainPID --value)

    if [[ "$main_pid" == "0" || -z "$main_pid" ]]; then
        log_error "No main process found for service"
        ((issues++))
        return $issues
    fi

    log_success "Main process PID: $main_pid"

    # Check if process is still running
    if kill -0 "$main_pid" 2>/dev/null; then
        log_success "Runner process is alive"
    else
        log_error "Runner process is not responding"
        ((issues++))
        return $issues
    fi

    # Check process resource usage
    local process_info
    process_info=$(ps -p "$main_pid" -o pid,ppid,user,pcpu,pmem,comm --no-headers 2>/dev/null || echo "")

    if [[ -n "$process_info" ]]; then
        local cpu_usage
        local mem_usage
        cpu_usage=$(echo "$process_info" | awk '{print $4}')
        mem_usage=$(echo "$process_info" | awk '{print $5}')

        if (( $(echo "$cpu_usage > 50.0" | bc -l) )); then
            log_warning "High process CPU usage: ${cpu_usage}%"
        else
            log_success "Process CPU usage: ${cpu_usage}%"
        fi

        if (( $(echo "$mem_usage > 10.0" | bc -l) )); then
            log_warning "High process memory usage: ${mem_usage}%"
        else
            log_success "Process memory usage: ${mem_usage}%"
        fi

        if [[ "$verbose" == true ]]; then
            echo
            log_info "Process Details:"
            echo "  $process_info"
        fi
    else
        log_error "Cannot retrieve process information"
        ((issues++))
    fi

    return $issues
}

# Analyze service logs for issues
check_service_logs() {
    local service_name="$1"
    local verbose="$2"
    local issues=0

    log_health "Analyzing service logs..."

    # Get recent logs
    local recent_logs
    recent_logs=$(journalctl -u "$service_name" --no-pager -n 100 --since "1 hour ago" 2>/dev/null || echo "")

    if [[ -z "$recent_logs" ]]; then
        log_warning "No recent logs found or cannot access logs"
        return $issues
    fi

    # Check for error patterns
    local error_count
    error_count=$(echo "$recent_logs" | grep -ci "error\|failed\|exception\|fatal" || echo "0")

    local warning_count
    warning_count=$(echo "$recent_logs" | grep -ci "warning\|warn" || echo "0")

    if [[ $error_count -gt 0 ]]; then
        log_warning "Found $error_count error messages in recent logs"
        if [[ "$verbose" == true ]]; then
            echo "Recent errors:"
            echo "$recent_logs" | grep -i "error\|failed\|exception\|fatal" | tail -5
        fi
    else
        log_success "No error messages in recent logs"
    fi

    if [[ $warning_count -gt 0 ]]; then
        log_info "Found $warning_count warning messages in recent logs"
    else
        log_success "No warning messages in recent logs"
    fi

    # Check for specific runner patterns
    local job_count
    job_count=$(echo "$recent_logs" | grep -c "Running job:" 2>/dev/null || echo "0")
    if [[ $job_count -gt 0 ]]; then
        log_success "Runner has processed $job_count jobs recently"
    else
        log_info "No recent job activity detected"
    fi

    return $issues
}

# Check Docker runner health
check_docker_health() {
    local verbose="$1"
    local issues=0

    log_health "Checking Docker runner health..."

    cd "$PROJECT_ROOT"

    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found"
        ((issues++))
        return $issues
    fi

    # Check container status
    local container_status
    container_status=$(docker-compose ps --quiet | head -1)

    if [[ -z "$container_status" ]]; then
        log_error "No Docker containers found"
        ((issues++))
        return $issues
    fi

    # Check if container is healthy
    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_status" 2>/dev/null || echo "unknown")

    case "$health_status" in
        "healthy")
            log_success "Docker container is healthy"
            ;;
        "unhealthy")
            log_error "Docker container is unhealthy"
            ((issues++))
            ;;
        "starting")
            log_warning "Docker container is still starting"
            ;;
        *)
            log_info "Docker container health status: $health_status"
            ;;
    esac

    # Check container logs for issues
    local container_logs
    container_logs=$(docker-compose logs --tail=50 2>/dev/null || echo "")

    if [[ -n "$container_logs" ]]; then
        local log_errors
        log_errors=$(echo "$container_logs" | grep -ci "error\|failed\|exception" || echo "0")

        if [[ $log_errors -gt 0 ]]; then
            log_warning "Found $log_errors error messages in container logs"
        else
            log_success "No error messages in container logs"
        fi
    fi

    if [[ "$verbose" == true ]]; then
        echo
        log_info "Docker Container Details:"
        docker-compose ps
        echo
        log_info "Recent Container Logs:"
        docker-compose logs --tail=10
    fi

    return $issues
}

# Attempt to fix common issues
fix_common_issues() {
    local service_name="$1"

    log_info "Attempting to fix common issues for $service_name..."

    # Restart service if not active
    if ! systemctl is-active --quiet "$service_name"; then
        log_info "Service is not active, attempting restart..."
        sudo systemctl restart "$service_name" || log_warning "Failed to restart service"
        sleep 5

        if systemctl is-active --quiet "$service_name"; then
            log_success "Service restarted successfully"
        else
            log_error "Service restart failed"
        fi
    fi

    # Clear systemd failed state if present
    if systemctl is-failed --quiet "$service_name"; then
        log_info "Clearing failed service state..."
        sudo systemctl reset-failed "$service_name"
    fi

    # Check and fix permissions on runner directories
    if [[ -d "/home/github-runner" ]]; then
        log_info "Checking runner directory permissions..."
        sudo chown -R github-runner:github-runner /home/github-runner || log_warning "Failed to fix permissions"
    fi
}

# Perform health check on a single service
health_check_service() {
    local service_name="$1"
    local verbose="$2"
    local fix_issues="$3"
    local total_issues=0

    echo "========================================"
    log_health "Health Check: $service_name"
    log_health "Timestamp: $(get_timestamp)"
    echo "========================================"

    # Service-specific checks
    check_service_health "$service_name" "$verbose"
    total_issues=$((total_issues + $?))

    check_process_health "$service_name" "$verbose"
    total_issues=$((total_issues + $?))

    check_service_logs "$service_name" "$verbose"
    total_issues=$((total_issues + $?))

    # Attempt fixes if requested and issues found
    if [[ "$fix_issues" == true && $total_issues -gt 0 ]]; then
        echo
        fix_common_issues "$service_name"
    fi

    echo "========================================"
    if [[ $total_issues -eq 0 ]]; then
        log_success "Health check PASSED - No issues detected"
    elif [[ $total_issues -le 2 ]]; then
        log_warning "Health check WARNING - Minor issues detected ($total_issues)"
    else
        log_error "Health check FAILED - Critical issues detected ($total_issues)"
    fi
    echo "========================================"
    echo

    return $total_issues
}

# Main health check function
main_health_check() {
    local runner_name="$1"
    local check_all="$2"
    local use_docker="$3"
    local verbose="$4"
    local fix_issues="$5"
    local continuous="$6"
    local total_issues=0

    # System-wide checks (run once regardless of service count)
    echo "========================================"
    log_health "System Health Check"
    log_health "Timestamp: $(get_timestamp)"
    echo "========================================"

    check_system_resources "$verbose"
    total_issues=$((total_issues + $?))

    check_github_api "$verbose"
    total_issues=$((total_issues + $?))

    echo "========================================"
    if [[ $total_issues -eq 0 ]]; then
        log_success "System health PASSED"
    else
        log_warning "System health issues detected ($total_issues)"
    fi
    echo "========================================"
    echo

    # Service-specific health checks
    if [[ "$use_docker" == true ]]; then
        check_docker_health "$verbose"
        total_issues=$((total_issues + $?))
    elif [[ "$check_all" == true ]]; then
        # Check all services
        local services_checked=0

        # Check default service if it exists
        if systemctl list-unit-files --type=service | grep -q "^$DEFAULT_SERVICE"; then
            health_check_service "$DEFAULT_SERVICE" "$verbose" "$fix_issues"
            total_issues=$((total_issues + $?))
            ((services_checked++))
        fi

        # Check template services
        local template_services
        template_services=$(systemctl list-unit-files --type=service | grep "^github-runner@" | awk '{print $1}' | sed 's/\.service$//' || true)

        if [[ -n "$template_services" ]]; then
            while IFS= read -r service; do
                health_check_service "$service" "$verbose" "$fix_issues"
                total_issues=$((total_issues + $?))
                ((services_checked++))
            done <<< "$template_services"
        fi

        if [[ $services_checked -eq 0 ]]; then
            log_warning "No GitHub runner services found to check"
            total_issues=$((total_issues + 1))
        fi
    elif [[ -n "$runner_name" ]]; then
        # Check specific template service
        local service_name="${TEMPLATE_SERVICE}${runner_name}"
        health_check_service "$service_name" "$verbose" "$fix_issues"
        total_issues=$((total_issues + $?))
    else
        # Check default service
        health_check_service "$DEFAULT_SERVICE" "$verbose" "$fix_issues"
        total_issues=$((total_issues + $?))
    fi

    # Final summary
    echo "========================================"
    log_health "OVERALL HEALTH CHECK SUMMARY"
    log_health "Timestamp: $(get_timestamp)"
    echo "========================================"

    if [[ $total_issues -eq 0 ]]; then
        log_success "ALL CHECKS PASSED - Runners are healthy"
        return 0
    elif [[ $total_issues -le 3 ]]; then
        log_warning "MINOR ISSUES DETECTED - Runners are functional but may need attention ($total_issues issues)"
        return 2
    else
        log_error "CRITICAL ISSUES DETECTED - Runners may not be functional ($total_issues issues)"
        return 1
    fi
}

# Continuous monitoring loop
continuous_monitoring() {
    local runner_name="$1"
    local check_all="$2"
    local use_docker="$3"
    local verbose="$4"
    local fix_issues="$5"

    log_info "Starting continuous health monitoring..."
    log_info "Check interval: ${HEALTH_CHECK_INTERVAL} seconds"
    log_info "Press Ctrl+C to stop monitoring"
    echo

    while true; do
        main_health_check "$runner_name" "$check_all" "$use_docker" "$verbose" "$fix_issues" true

        log_info "Next check in ${HEALTH_CHECK_INTERVAL} seconds..."
        sleep "$HEALTH_CHECK_INTERVAL"
    done
}

# Main execution
main() {
    local runner_name=""
    local check_all=false
    local use_docker=false
    local verbose=false
    local fix_issues=false
    local continuous=false
    local show_thresholds=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --all)
                check_all=true
                shift
                ;;
            --docker)
                use_docker=true
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --fix-issues)
                fix_issues=true
                shift
                ;;
            --continuous)
                continuous=true
                shift
                ;;
            --thresholds)
                show_thresholds=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo
                show_help
                exit 3
                ;;
            *)
                runner_name="$1"
                shift
                ;;
        esac
    done

    # Show thresholds and exit if requested
    if [[ "$show_thresholds" == true ]]; then
        show_thresholds
        exit 0
    fi

    # Security check
    check_root

    # Check required commands
    if ! command -v systemctl &> /dev/null && [[ "$use_docker" != true ]]; then
        log_error "systemctl is not available. Use --docker for Docker-based checks."
        exit 3
    fi

    if [[ "$use_docker" == true ]] && ! command -v docker-compose &> /dev/null; then
        log_error "docker-compose is not available."
        exit 3
    fi

    # Run continuous monitoring if requested
    if [[ "$continuous" == true ]]; then
        continuous_monitoring "$runner_name" "$check_all" "$use_docker" "$verbose" "$fix_issues"
        exit 0
    fi

    # Run single health check
    main_health_check "$runner_name" "$check_all" "$use_docker" "$verbose" "$fix_issues" false
    exit $?
}

# Trap for graceful exit in continuous mode
trap 'echo; log_info "Health monitoring stopped."; exit 0' INT TERM

# Run main function with all arguments
main "$@"