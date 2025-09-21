#!/bin/bash
# GitHub Actions Self-Hosted Runner Health Check
#
# This script performs comprehensive health checks for the GitHub Actions runner
# to ensure it's operating correctly and can handle workflow jobs. Used by
# Docker health checks and monitoring systems.
#
# Health Check Categories:
# 1. Runner Process Status - Verify runner daemon is running
# 2. GitHub Connectivity - Test connection to GitHub API
# 3. Runner Registration - Verify runner is properly registered
# 4. System Resources - Check disk space, memory, CPU
# 5. Docker Access - Verify Docker-in-Docker functionality (if enabled)
# 6. Work Directory - Ensure work directory is accessible and writable
#
# Exit Codes:
#   0 - Healthy (all checks passed)
#   1 - Unhealthy (critical failures)
#   2 - Degraded (warnings but functional)

set -e

# Health check configuration
SCRIPT_NAME="GitHub Runner Health Check"
RUNNER_HOME="/home/github-runner"
RUNNER_CONFIG_FILE="${RUNNER_HOME}/.runner"
RUNNER_CREDENTIALS_FILE="${RUNNER_HOME}/.credentials"
HEALTH_CHECK_TIMEOUT=10

# Health status tracking
HEALTH_STATUS="healthy"
HEALTH_WARNINGS=()
HEALTH_ERRORS=()

# Logging functions
log_info() {
    echo "[HEALTH] $(date '+%H:%M:%S') - INFO: $1"
}

log_warn() {
    echo "[HEALTH] $(date '+%H:%M:%S') - WARN: $1" >&2
    HEALTH_WARNINGS+=("$1")
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        HEALTH_STATUS="degraded"
    fi
}

log_error() {
    echo "[HEALTH] $(date '+%H:%M:%S') - ERROR: $1" >&2
    HEALTH_ERRORS+=("$1")
    HEALTH_STATUS="unhealthy"
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "[HEALTH] $(date '+%H:%M:%S') - DEBUG: $1"
    fi
}

# Check 1: Runner process status
check_runner_process() {
    log_debug "Checking runner process status..."

    # Check if runner process is running
    local runner_pid
    runner_pid=$(pgrep -f "Runner.Listener" 2>/dev/null || echo "")

    if [ -n "${runner_pid}" ]; then
        log_debug "Runner process found (PID: ${runner_pid})"

        # Check process health
        if kill -0 "${runner_pid}" 2>/dev/null; then
            log_debug "Runner process is responsive"
            return 0
        else
            log_error "Runner process exists but is not responsive"
            return 1
        fi
    else
        # In container startup, runner might not be started yet
        if [ -f "${RUNNER_CONFIG_FILE}" ]; then
            log_error "Runner is configured but process is not running"
            return 1
        else
            log_warn "Runner process not found (may be initializing)"
            return 0
        fi
    fi
}

# Check 2: GitHub connectivity
check_github_connectivity() {
    log_debug "Checking GitHub connectivity..."

    local github_url="${GITHUB_URL:-https://github.com}"
    local timeout_cmd="timeout ${HEALTH_CHECK_TIMEOUT}"

    # Test basic connectivity to GitHub
    if ${timeout_cmd} curl -sSf "${github_url}" >/dev/null 2>&1; then
        log_debug "GitHub connectivity verified"
    else
        log_error "Cannot reach GitHub at ${github_url}"
        return 1
    fi

    # Test GitHub API connectivity (if we have credentials)
    if [ -n "${GITHUB_REPOSITORY}" ] && [ -n "${GITHUB_TOKEN}" ]; then
        local api_url="https://api.github.com/repos/${GITHUB_REPOSITORY}"
        local auth_header="Authorization: token ${GITHUB_TOKEN}"

        if ${timeout_cmd} curl -sSf -H "${auth_header}" "${api_url}" >/dev/null 2>&1; then
            log_debug "GitHub API connectivity verified"
        else
            log_warn "GitHub API connectivity issues detected"
        fi
    else
        log_debug "Skipping GitHub API check (credentials not available)"
    fi

    return 0
}

# Check 3: Runner registration status
check_runner_registration() {
    log_debug "Checking runner registration status..."

    if [ ! -f "${RUNNER_CONFIG_FILE}" ]; then
        log_warn "Runner configuration file not found (may be initializing)"
        return 0
    fi

    # Parse runner configuration
    local runner_name=""
    local runner_url=""

    if [ -f "${RUNNER_CONFIG_FILE}" ]; then
        runner_name=$(grep -E "^\"agentName\":" "${RUNNER_CONFIG_FILE}" | sed 's/.*: "\(.*\)",/\1/' 2>/dev/null || echo "unknown")
        runner_url=$(grep -E "^\"serverUrl\":" "${RUNNER_CONFIG_FILE}" | sed 's/.*: "\(.*\)",/\1/' 2>/dev/null || echo "unknown")
        log_debug "Runner name: ${runner_name}, URL: ${runner_url}"
    fi

    # Validate runner configuration by checking key files and process
    cd "${RUNNER_HOME}" || {
        log_error "Cannot access runner home directory"
        return 1
    }

    # Check if runner configuration and credentials exist
    if [ -f "${RUNNER_CONFIG_FILE}" ] && [ -f "${RUNNER_CREDENTIALS_FILE}" ]; then
        log_debug "Runner configuration files found"

        # Check if the runner process is actually running
        if pgrep -f "Runner.Listener" >/dev/null 2>&1; then
            log_debug "Runner process is active"
            log_debug "Runner registration validated successfully"
        else
            log_warn "Runner configuration exists but process not running"
        fi
    else
        log_error "Runner configuration or credentials missing"
        return 1
    fi

    return 0
}

# Check 4: System resources
check_system_resources() {
    log_debug "Checking system resources..."

    # Check disk space
    local disk_usage
    disk_usage=$(df "${RUNNER_HOME}" | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ "${disk_usage}" -gt 90 ]; then
        log_error "Disk space critical: ${disk_usage}% used"
        return 1
    elif [ "${disk_usage}" -gt 80 ]; then
        log_warn "Disk space high: ${disk_usage}% used"
    else
        log_debug "Disk space OK: ${disk_usage}% used"
    fi

    # Check available memory
    local memory_available
    memory_available=$(free -m | awk 'NR==2{printf "%.0f", $7/$2*100}')

    if [ "${memory_available}" -lt 10 ]; then
        log_error "Available memory critical: ${memory_available}% free"
        return 1
    elif [ "${memory_available}" -lt 20 ]; then
        log_warn "Available memory low: ${memory_available}% free"
    else
        log_debug "Memory OK: ${memory_available}% available"
    fi

    # Check load average
    local load_avg
    load_avg=$(uptime | awk -F'[a-z]:' '{ print $2 }' | awk '{ print $1 }' | tr -d ',')
    local cpu_cores
    cpu_cores=$(nproc)
    local load_ratio
    load_ratio=$(echo "scale=2; ${load_avg} / ${cpu_cores}" | bc 2>/dev/null || echo "0")

    if [ "$(echo "${load_ratio} > 2" | bc 2>/dev/null || echo 0)" = "1" ]; then
        log_warn "High system load: ${load_avg} (ratio: ${load_ratio})"
    else
        log_debug "System load OK: ${load_avg} (ratio: ${load_ratio})"
    fi

    return 0
}

# Check 5: Docker access (if enabled)
check_docker_access() {
    log_debug "Checking Docker access..."

    if [ -S /var/run/docker.sock ]; then
        # Docker socket is mounted, verify access
        if timeout ${HEALTH_CHECK_TIMEOUT} docker version >/dev/null 2>&1; then
            log_debug "Docker access verified"

            # Check Docker daemon health
            if timeout ${HEALTH_CHECK_TIMEOUT} docker info >/dev/null 2>&1; then
                log_debug "Docker daemon healthy"
            else
                log_warn "Docker daemon may be unhealthy"
            fi

            # Check Docker space usage
            local docker_space
            docker_space=$(timeout ${HEALTH_CHECK_TIMEOUT} docker system df --format "table {{.Type}}\t{{.Size}}\t{{.Reclaimable}}" 2>/dev/null || echo "")
            if [ -n "${docker_space}" ]; then
                log_debug "Docker space usage available"
            fi

        else
            log_warn "Docker socket mounted but Docker CLI not working"
        fi
    else
        log_debug "Docker socket not mounted (Docker-in-Docker disabled)"
    fi

    return 0
}

# Check 6: Work directory status
check_work_directory() {
    log_debug "Checking work directory status..."

    local work_dir="${RUNNER_HOME}/${RUNNER_WORK_DIRECTORY:-_work}"

    # Check if work directory exists and is writable
    if [ -d "${work_dir}" ]; then
        if [ -w "${work_dir}" ]; then
            log_debug "Work directory OK: ${work_dir}"

            # Check work directory space usage
            local work_dir_size
            work_dir_size=$(du -sh "${work_dir}" 2>/dev/null | cut -f1 || echo "unknown")
            log_debug "Work directory size: ${work_dir_size}"

            # Clean up old artifacts if directory is large (optional)
            local work_dir_files
            work_dir_files=$(find "${work_dir}" -type f -mtime +7 2>/dev/null | wc -l || echo "0")
            if [ "${work_dir_files}" -gt 100 ]; then
                log_warn "Work directory contains ${work_dir_files} old files (consider cleanup)"
            fi
        else
            log_error "Work directory not writable: ${work_dir}"
            return 1
        fi
    else
        log_debug "Work directory does not exist (will be created on first job): ${work_dir}"
    fi

    return 0
}

# Comprehensive health check
perform_health_checks() {
    log_info "Starting comprehensive health check..."

    local checks=(
        "check_runner_process"
        "check_github_connectivity"
        "check_runner_registration"
        "check_system_resources"
        "check_docker_access"
        "check_work_directory"
    )

    local failed_checks=0
    local total_checks=${#checks[@]}

    for check in "${checks[@]}"; do
        if ! "${check}"; then
            failed_checks=$((failed_checks + 1))
        fi
    done

    # Generate health summary
    log_info "Health check completed: ${failed_checks}/${total_checks} checks failed"

    if [ ${#HEALTH_WARNINGS[@]} -gt 0 ]; then
        log_info "Warnings (${#HEALTH_WARNINGS[@]}):"
        for warning in "${HEALTH_WARNINGS[@]}"; do
            echo "  - ${warning}"
        done
    fi

    if [ ${#HEALTH_ERRORS[@]} -gt 0 ]; then
        log_info "Errors (${#HEALTH_ERRORS[@]}):"
        for error in "${HEALTH_ERRORS[@]}"; do
            echo "  - ${error}"
        done
    fi
}

# Generate health report
generate_health_report() {
    local status_icon
    case "${HEALTH_STATUS}" in
        "healthy")   status_icon="✅" ;;
        "degraded")  status_icon="⚠️" ;;
        "unhealthy") status_icon="❌" ;;
        *)           status_icon="❓" ;;
    esac

    cat << EOF
${status_icon} Runner Health Status: ${HEALTH_STATUS^^}

Timestamp: $(date '+%Y-%m-%d %H:%M:%S')
Runner Home: ${RUNNER_HOME}
Host: $(hostname)
Uptime: $(uptime -p 2>/dev/null || uptime)

Health Summary:
  Warnings: ${#HEALTH_WARNINGS[@]}
  Errors: ${#HEALTH_ERRORS[@]}
  Status: ${HEALTH_STATUS}
EOF
}

# Main execution
main() {
    # Change to runner directory
    cd "${RUNNER_HOME}" 2>/dev/null || {
        echo "[HEALTH] ERROR: Cannot access runner home directory: ${RUNNER_HOME}"
        exit 1
    }

    # Perform all health checks
    perform_health_checks

    # Generate and display health report
    if [ "${1:-summary}" = "verbose" ] || [ "${DEBUG:-false}" = "true" ]; then
        generate_health_report
    fi

    # Exit with appropriate status code
    case "${HEALTH_STATUS}" in
        "healthy")
            exit 0
            ;;
        "degraded")
            log_info "Runner is functional but has warnings"
            exit 0  # Changed: degraded is considered healthy for Docker
            ;;
        "unhealthy")
            log_info "Runner has critical issues"
            exit 1
            ;;
        *)
            log_error "Unknown health status: ${HEALTH_STATUS}"
            exit 1
            ;;
    esac
}

# Handle different command arguments
case "${1:-check}" in
    "check"|"")
        main
        ;;
    "verbose")
        main verbose
        ;;
    "report")
        perform_health_checks
        generate_health_report
        ;;
    "help"|"--help"|"-h")
        cat << EOF
${SCRIPT_NAME}

Usage: $0 [COMMAND]

Commands:
  check     Perform health check with minimal output (default)
  verbose   Perform health check with detailed output
  report    Generate detailed health report
  help      Show this help message

Exit Codes:
  0         Healthy (all checks passed)
  1         Unhealthy (critical failures)
  2         Degraded (warnings but functional)

Environment Variables:
  DEBUG           - Enable debug logging (default: false)
  GITHUB_URL      - GitHub URL for connectivity tests
  GITHUB_REPOSITORY - Repository for API connectivity tests
  GITHUB_TOKEN    - Token for API connectivity tests

Examples:
  # Quick health check
  $0

  # Detailed health check
  $0 verbose

  # Generate health report
  $0 report

This script is typically called by Docker health checks and monitoring systems.
EOF
        ;;
    *)
        echo "[HEALTH] ERROR: Unknown command: $1"
        echo "[HEALTH] Use '$0 help' for usage information"
        exit 1
        ;;
esac