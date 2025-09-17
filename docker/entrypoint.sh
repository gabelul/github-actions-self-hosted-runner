#!/bin/bash
# GitHub Actions Self-Hosted Runner Docker Entrypoint
#
# This script handles runner registration, configuration, and lifecycle management
# when running in Docker containers. It supports both ephemeral and persistent
# runner configurations with proper error handling and cleanup.
#
# Features:
# - Automatic runner registration with GitHub
# - Ephemeral vs persistent runner modes
# - Graceful shutdown handling with cleanup
# - Environment variable validation
# - Docker-in-Docker support verification
# - Comprehensive logging and error handling
#
# Environment Variables:
#   GITHUB_TOKEN          - GitHub personal access token (required)
#   GITHUB_REPOSITORY     - Repository in format owner/repo (required)
#   GITHUB_URL            - GitHub URL (default: https://github.com)
#   RUNNER_NAME           - Custom runner name (default: hostname)
#   RUNNER_LABELS         - Comma-separated labels (default: self-hosted,linux,x64,docker)
#   RUNNER_GROUP          - Runner group (default: default)
#   RUNNER_WORK_DIRECTORY - Work directory name (default: _work)
#   EPHEMERAL             - Enable ephemeral mode (default: false)
#   RUNNER_REPLACE        - Replace existing runner (default: true)
#   DEBUG                 - Enable debug logging (default: false)

set -e

# Script metadata
SCRIPT_NAME="GitHub Runner Entrypoint"
SCRIPT_VERSION="1.0.0"

# Default configurations
RUNNER_HOME="/home/github-runner"
RUNNER_CONFIG_FILE="${RUNNER_HOME}/.runner"
RUNNER_CREDENTIALS_FILE="${RUNNER_HOME}/.credentials"

# Logging functions
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Script failed at line $line_number with exit code $exit_code"
    cleanup_runner
    exit $exit_code
}

trap 'handle_error $LINENO' ERR

# Cleanup function for graceful shutdown
cleanup_runner() {
    log_info "Starting graceful runner cleanup..."

    # If runner is configured, attempt to remove it
    if [ -f "${RUNNER_CONFIG_FILE}" ]; then
        log_info "Removing runner from GitHub..."
        if [ -n "${GITHUB_TOKEN}" ]; then
            ./config.sh remove --token "${GITHUB_TOKEN}" || {
                log_warn "Failed to remove runner gracefully"
            }
        else
            log_warn "No GITHUB_TOKEN available for cleanup"
        fi
    else
        log_debug "No runner configuration found, skipping removal"
    fi

    # Stop any running processes
    local runner_pid
    runner_pid=$(pgrep -f "Runner.Listener" || echo "")
    if [ -n "${runner_pid}" ]; then
        log_info "Stopping runner process (PID: ${runner_pid})..."
        kill -TERM "${runner_pid}" 2>/dev/null || true

        # Wait for graceful shutdown
        local wait_count=0
        while kill -0 "${runner_pid}" 2>/dev/null && [ ${wait_count} -lt 30 ]; do
            sleep 1
            wait_count=$((wait_count + 1))
        done

        # Force kill if still running
        if kill -0 "${runner_pid}" 2>/dev/null; then
            log_warn "Force killing runner process..."
            kill -KILL "${runner_pid}" 2>/dev/null || true
        fi
    fi

    log_info "Cleanup completed"
}

# Trap signals for graceful shutdown
trap cleanup_runner SIGTERM SIGINT SIGQUIT

# Environment validation
validate_environment() {
    log_info "Validating environment configuration..."

    # Required variables
    local required_vars=(
        "GITHUB_TOKEN"
        "GITHUB_REPOSITORY"
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables:"
        printf '  - %s\n' "${missing_vars[@]}"
        log_error "Please provide all required environment variables"
        exit 1
    fi

    # Set defaults for optional variables
    export GITHUB_URL="${GITHUB_URL:-https://github.com}"
    export RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
    export RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,x64,docker}"
    export RUNNER_GROUP="${RUNNER_GROUP:-default}"
    export RUNNER_WORK_DIRECTORY="${RUNNER_WORK_DIRECTORY:-_work}"
    export EPHEMERAL="${EPHEMERAL:-false}"
    export RUNNER_REPLACE="${RUNNER_REPLACE:-true}"
    export DISABLE_AUTO_UPDATE="${DISABLE_AUTO_UPDATE:-false}"

    # Validate GitHub repository format
    if [[ ! "${GITHUB_REPOSITORY}" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
        log_error "Invalid GITHUB_REPOSITORY format. Expected: owner/repo"
        exit 1
    fi

    # Validate GitHub URL
    if ! curl -sSf "${GITHUB_URL}" >/dev/null 2>&1; then
        log_warn "Cannot reach GitHub URL: ${GITHUB_URL}"
    fi

    log_info "Environment validation completed"
}

# Docker configuration verification
verify_docker_access() {
    log_info "Verifying Docker access for Docker-in-Docker workflows..."

    if [ -S /var/run/docker.sock ]; then
        if docker version >/dev/null 2>&1; then
            log_info "Docker access verified successfully"
            log_debug "Docker version: $(docker version --format '{{.Server.Version}}')"
        else
            log_warn "Docker socket mounted but Docker CLI not working"
            log_warn "Docker-in-Docker workflows may not function properly"
        fi
    else
        log_warn "Docker socket not mounted at /var/run/docker.sock"
        log_warn "Docker-in-Docker workflows will not be available"
    fi
}

# GitHub runner registration
register_runner() {
    log_info "Registering GitHub Actions runner..."

    # Build configuration arguments
    local config_args=(
        "--url" "${GITHUB_URL}/${GITHUB_REPOSITORY}"
        "--token" "${GITHUB_TOKEN}"
        "--name" "${RUNNER_NAME}"
        "--labels" "${RUNNER_LABELS}"
        "--runnergroup" "${RUNNER_GROUP}"
        "--work" "${RUNNER_WORK_DIRECTORY}"
        "--unattended"
    )

    # Add optional arguments
    if [ "${EPHEMERAL}" = "true" ]; then
        config_args+=("--ephemeral")
        log_info "Ephemeral mode enabled - runner will be automatically removed after one job"
    fi

    if [ "${RUNNER_REPLACE}" = "true" ]; then
        config_args+=("--replace")
        log_debug "Runner replacement enabled"
    fi

    if [ "${DISABLE_AUTO_UPDATE}" = "true" ]; then
        config_args+=("--disableupdate")
        log_debug "Auto-update disabled"
    fi

    # Execute registration
    log_debug "Running: ./config.sh ${config_args[*]}"
    if ./config.sh "${config_args[@]}"; then
        log_info "Runner registered successfully"
        log_info "Runner name: ${RUNNER_NAME}"
        log_info "Runner labels: ${RUNNER_LABELS}"
        log_info "Repository: ${GITHUB_REPOSITORY}"
    else
        log_error "Failed to register runner"
        exit 1
    fi
}

# Runner startup
start_runner() {
    log_info "Starting GitHub Actions runner..."
    log_info "Runner will begin listening for workflow jobs..."

    # Create work directory if it doesn't exist
    mkdir -p "${RUNNER_WORK_DIRECTORY}"

    # Start the runner
    if [ "${DEBUG}" = "true" ]; then
        log_debug "Starting runner with debug logging enabled"
        ./run.sh
    else
        exec ./run.sh
    fi
}

# Health check endpoint setup (optional)
setup_health_check() {
    if command -v nc >/dev/null 2>&1; then
        log_debug "Setting up health check endpoint..."
        # Simple health check that responds on port 8080
        {
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: text/plain"
            echo "Content-Length: 2"
            echo ""
            echo "OK"
        } | nc -l -p 8080 &
        log_debug "Health check endpoint available on port 8080"
    fi
}

# Main execution
main() {
    log_info "Starting ${SCRIPT_NAME} v${SCRIPT_VERSION}"
    log_info "GitHub Runner Docker Container Initialization"

    # Change to runner directory
    cd "${RUNNER_HOME}" || {
        log_error "Cannot change to runner home directory: ${RUNNER_HOME}"
        exit 1
    }

    # Validate environment
    validate_environment

    # Verify Docker access
    verify_docker_access

    # Check if already configured (for container restarts)
    if [ -f "${RUNNER_CONFIG_FILE}" ]; then
        log_info "Runner already configured, checking status..."

        # Verify configuration is still valid
        if ./config.sh --check >/dev/null 2>&1; then
            log_info "Existing configuration is valid, reusing..."
        else
            log_warn "Existing configuration is invalid, re-registering..."
            rm -f "${RUNNER_CONFIG_FILE}" "${RUNNER_CREDENTIALS_FILE}"
            register_runner
        fi
    else
        log_info "No existing configuration found, registering new runner..."
        register_runner
    fi

    # Setup health check (optional)
    setup_health_check

    # Start the runner
    start_runner
}

# Handle different command arguments
case "${1:-run}" in
    "run"|"")
        main
        ;;
    "register")
        log_info "Registration mode - registering runner without starting"
        cd "${RUNNER_HOME}"
        validate_environment
        register_runner
        log_info "Runner registered successfully. Use 'run' command to start."
        ;;
    "remove")
        log_info "Removal mode - removing runner configuration"
        cd "${RUNNER_HOME}"
        cleanup_runner
        log_info "Runner removed successfully"
        ;;
    "status")
        log_info "Status check mode"
        cd "${RUNNER_HOME}"
        if [ -f "${RUNNER_CONFIG_FILE}" ]; then
            log_info "Runner is configured"
            ./config.sh --check && log_info "Configuration is valid" || log_warn "Configuration is invalid"
        else
            log_info "Runner is not configured"
        fi
        ;;
    "help"|"--help"|"-h")
        cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}

Usage: $0 [COMMAND]

Commands:
  run         Register and start the runner (default)
  register    Register the runner without starting
  remove      Remove runner configuration
  status      Check runner configuration status
  help        Show this help message

Environment Variables:
  GITHUB_TOKEN          - GitHub personal access token (required)
  GITHUB_REPOSITORY     - Repository in format owner/repo (required)
  GITHUB_URL            - GitHub URL (default: https://github.com)
  RUNNER_NAME           - Custom runner name (default: hostname)
  RUNNER_LABELS         - Comma-separated labels (default: self-hosted,linux,x64,docker)
  RUNNER_GROUP          - Runner group (default: default)
  RUNNER_WORK_DIRECTORY - Work directory name (default: _work)
  EPHEMERAL             - Enable ephemeral mode (default: false)
  RUNNER_REPLACE        - Replace existing runner (default: true)
  DEBUG                 - Enable debug logging (default: false)

Examples:
  # Start runner with defaults
  $0

  # Register only (don't start)
  $0 register

  # Remove runner
  $0 remove

  # Check status
  $0 status

For more information, visit: https://docs.github.com/en/actions/hosting-your-own-runners
EOF
        ;;
    *)
        log_error "Unknown command: $1"
        log_error "Use '$0 help' for usage information"
        exit 1
        ;;
esac