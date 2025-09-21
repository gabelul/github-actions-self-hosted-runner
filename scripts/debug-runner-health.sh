#!/bin/bash

# Debug Script for GitHub Runner Health Issues
# This script helps diagnose why a Docker-based GitHub runner is showing as unhealthy

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

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
    echo -e "${YELLOW}=== $1 ===${NC}"
}

# Find GitHub runner containers (returns container names only)
find_runner_containers() {
    local containers
    containers=$(docker ps -a --filter "name=github-runner-" --format "{{.Names}}" || echo "")

    if [[ -z "$containers" ]]; then
        log_error "No GitHub runner containers found"
        exit 1
    fi

    echo "$containers"
}

# Display container information
display_container_info() {
    local containers=("$@")

    log_header "Found GitHub Runner Containers"

    for container in "${containers[@]}"; do
        if [[ -n "$container" ]]; then
            local status=$(docker inspect "$container" --format='{{.State.Status}}' 2>/dev/null || echo "unknown")
            local health=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
            echo "  • $container - Status: $status, Health: $health"
        fi
    done
    echo
}

# Comprehensive health diagnosis
diagnose_container() {
    local container_name="$1"

    log_header "Diagnosing Container: $container_name"

    # Basic container info
    echo "=== Container Information ==="
    docker inspect "$container_name" --format='
Status: {{.State.Status}}
Health: {{.State.Health.Status}}
Started: {{.State.StartedAt}}
PID: {{.State.Pid}}
Exit Code: {{.State.ExitCode}}
OOMKilled: {{.State.OOMKilled}}
' 2>/dev/null || echo "Failed to get container info"
    echo

    # Health check history
    echo "=== Health Check History ==="
    docker inspect "$container_name" --format='{{range .State.Health.Log}}{{.Start}}: {{.ExitCode}} - {{.Output}}{{end}}' 2>/dev/null | tail -10 || echo "No health check history available"
    echo

    # Recent logs
    echo "=== Recent Container Logs (last 50 lines) ==="
    docker logs "$container_name" --tail 50 2>&1 | sed 's/^/  /'
    echo

    # Resource usage
    echo "=== Current Resource Usage ==="
    docker stats "$container_name" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || echo "Failed to get resource stats"
    echo

    # Network connectivity test
    echo "=== Network Connectivity Test ==="
    docker exec "$container_name" ping -c 3 8.8.8.8 2>/dev/null | sed 's/^/  /' || echo "  Network connectivity test failed"
    echo

    # GitHub connectivity test
    echo "=== GitHub Connectivity Test ==="
    docker exec "$container_name" curl -sSf https://github.com --max-time 10 >/dev/null 2>&1 && echo "  ✅ GitHub is reachable" || echo "  ❌ GitHub is not reachable"
    docker exec "$container_name" curl -sSf https://api.github.com --max-time 10 >/dev/null 2>&1 && echo "  ✅ GitHub API is reachable" || echo "  ❌ GitHub API is not reachable"
    echo

    # Manual health check
    echo "=== Manual Health Check Execution ==="
    if docker exec "$container_name" test -f /home/github-runner/health-check.sh; then
        echo "Health check script exists. Running it..."
        docker exec "$container_name" /home/github-runner/health-check.sh verbose 2>&1 | sed 's/^/  /' || echo "  Health check execution failed"
    else
        echo "  ❌ Health check script not found at /home/github-runner/health-check.sh"
    fi
    echo

    # Process information
    echo "=== Running Processes in Container ==="
    docker exec "$container_name" ps aux 2>/dev/null | sed 's/^/  /' || echo "  Failed to get process list"
    echo

    # Disk usage
    echo "=== Disk Usage in Container ==="
    docker exec "$container_name" df -h 2>/dev/null | sed 's/^/  /' || echo "  Failed to get disk usage"
    echo

    # GitHub runner specific checks
    echo "=== GitHub Runner Specific Checks ==="
    echo "Runner configuration:"
    docker exec "$container_name" ls -la /home/github-runner/.runner 2>/dev/null | sed 's/^/  /' || echo "  No runner configuration found"
    echo
    echo "Runner credentials:"
    docker exec "$container_name" ls -la /home/github-runner/.credentials 2>/dev/null | sed 's/^/  /' || echo "  No runner credentials found"
    echo
    echo "Runner work directory:"
    docker exec "$container_name" ls -la /home/github-runner/_work 2>/dev/null | sed 's/^/  /' || echo "  No work directory found"
    echo
}

# Suggest fixes based on diagnosis
suggest_fixes() {
    local container_name="$1"

    log_header "Suggested Fixes"

    echo "Based on the diagnosis, here are potential fixes:"
    echo
    echo "1. **Restart the container:**"
    echo "   docker restart $container_name"
    echo
    echo "2. **Check docker-compose logs:**"
    echo "   cd ./docker-runners/$(echo $container_name | sed 's/github-runner-//')"
    echo "   docker-compose logs"
    echo
    echo "3. **Recreate the container:**"
    echo "   cd ./docker-runners/$(echo $container_name | sed 's/github-runner-//')"
    echo "   docker-compose down"
    echo "   docker-compose up -d"
    echo
    echo "4. **Check host system resources:**"
    echo "   free -h"
    echo "   df -h"
    echo "   docker system df"
    echo
    echo "5. **Manual health check debug:**"
    echo "   docker exec -it $container_name bash"
    echo "   # Then run: /home/github-runner/health-check.sh verbose"
    echo
    echo "6. **Check for permission issues:**"
    echo "   docker exec $container_name ls -la /home/github-runner/"
    echo
    echo "7. **Verify environment variables:**"
    echo "   docker exec $container_name env | grep GITHUB"
    echo
}

# Interactive menu
interactive_menu() {
    local containers=("$@")

    if [[ ${#containers[@]} -eq 0 ]]; then
        log_error "No containers to diagnose"
        exit 1
    fi

    echo "Select a container to diagnose:"
    for i in "${!containers[@]}"; do
        echo "  $((i+1)). ${containers[$i]}"
    done
    echo

    while true; do
        echo -n "Select container [1-${#containers[@]}] or 'q' to quit: "
        read -r choice

        if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
            exit 0
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le ${#containers[@]} ]]; then
            local selected_container="${containers[$((choice-1))]}"
            diagnose_container "$selected_container"
            suggest_fixes "$selected_container"
            echo
            echo "Press Enter to continue or 'q' to quit..."
            read -r continue_choice
            if [[ "$continue_choice" == "q" || "$continue_choice" == "Q" ]]; then
                exit 0
            fi
        else
            echo "Invalid choice. Please select a number between 1 and ${#containers[@]}."
        fi
    done
}

# Main function
main() {
    log_header "GitHub Runner Health Diagnostic Tool"
    echo

    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running or not accessible"
        exit 1
    fi

    # Find containers
    local container_list
    container_list=$(find_runner_containers)

    # Convert to array
    local containers=()
    while IFS= read -r container; do
        if [[ -n "$container" ]]; then
            containers+=("$container")
        fi
    done <<< "$container_list"

    # Display container information
    display_container_info "${containers[@]}"

    # If specific container provided as argument
    if [[ $# -gt 0 ]]; then
        local target_container="$1"
        # Check if container exists
        if docker inspect "$target_container" >/dev/null 2>&1; then
            diagnose_container "$target_container"
            suggest_fixes "$target_container"
        else
            log_error "Container '$target_container' not found"
            exit 1
        fi
    else
        # Interactive mode
        interactive_menu "${containers[@]}"
    fi
}

# Show help
show_help() {
    cat << EOF
GitHub Runner Health Diagnostic Tool

USAGE:
    $0                           # Interactive mode
    $0 CONTAINER_NAME           # Diagnose specific container
    $0 --help                   # Show this help

EXAMPLES:
    $0                          # Choose from available containers
    $0 github-runner-cdn-local-413  # Diagnose specific container

This tool helps diagnose why GitHub runner containers are unhealthy by:
- Checking container status and health history
- Analyzing logs and resource usage
- Testing network connectivity
- Running manual health checks
- Suggesting specific fixes

EOF
}

# Parse arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        --help|-h|help)
            show_help
            exit 0
            ;;
        *)
            main "$@"
            ;;
    esac
else
    main
fi