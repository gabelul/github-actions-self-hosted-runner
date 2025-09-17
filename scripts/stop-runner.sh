#!/bin/bash

# GitHub Actions Self-Hosted Runner - Stop Script
#
# This script provides a unified way to stop GitHub runners whether they're
# configured as single instances or multi-runner template services.
#
# Usage:
#   ./stop-runner.sh                     # Stop default single runner
#   ./stop-runner.sh runner1             # Stop specific template runner
#   ./stop-runner.sh --all               # Stop all configured runners
#   ./stop-runner.sh --docker            # Stop Docker-based runner
#   ./stop-runner.sh --force             # Force stop (immediate termination)
#   ./stop-runner.sh --help              # Show help

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEFAULT_SERVICE="github-runner"
TEMPLATE_SERVICE="github-runner@"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Show help information
show_help() {
    cat << EOF
GitHub Actions Self-Hosted Runner - Stop Script

USAGE:
    $0 [OPTIONS] [RUNNER_NAME]

ARGUMENTS:
    RUNNER_NAME         Name of the runner instance (for template services)

OPTIONS:
    --all              Stop all configured runner instances
    --docker           Stop Docker-based runner using docker-compose
    --force            Force stop runners (immediate termination)
    --disable          Stop and disable auto-start for the service
    --status           Show status of all runners
    --help             Show this help message

EXAMPLES:
    $0                 # Stop default single runner service gracefully
    $0 project1        # Stop template runner named 'project1'
    $0 --all           # Stop all configured template runners
    $0 --docker        # Stop Docker runner with docker-compose
    $0 --force         # Force immediate termination of all runners
    $0 --disable       # Stop and disable auto-start for default runner

GRACEFUL VS FORCE STOPPING:
    Graceful Stop:     Allows running jobs to complete (up to 5 minutes)
    Force Stop:        Immediately terminates all processes

For more information, see the documentation in docs/
EOF
}

# Check if running as root (not recommended for security)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root is not recommended for security reasons."
        log_warning "Consider running as a non-privileged user with sudo access."
    fi
}

# Check if systemctl is available
check_systemd() {
    if ! command -v systemctl &> /dev/null; then
        log_error "systemctl is not available. This system may not use systemd."
        log_info "For non-systemd systems, consider using Docker deployment instead."
        exit 1
    fi
}

# Check if docker-compose is available
check_docker() {
    if ! command -v docker-compose &> /dev/null && ! command -v docker &> /dev/null; then
        log_error "Docker or docker-compose is not available."
        log_info "Install Docker first or use systemd deployment instead."
        exit 1
    fi
}

# Stop single default runner
stop_default_runner() {
    local force_stop="$1"
    local disable_service="$2"

    log_info "Stopping default GitHub runner service..."

    if ! systemctl is-active --quiet "$DEFAULT_SERVICE"; then
        log_warning "Default runner is already stopped."
        systemctl status "$DEFAULT_SERVICE" --no-pager -l || true
        return 0
    fi

    if [[ "$force_stop" == true ]]; then
        log_warning "Force stopping default runner (immediate termination)..."
        sudo systemctl kill --signal=SIGKILL "$DEFAULT_SERVICE"
    else
        log_info "Gracefully stopping default runner (allows jobs to complete)..."
        sudo systemctl stop "$DEFAULT_SERVICE"
    fi

    # Wait for service to stop
    local timeout=30
    local count=0
    while systemctl is-active --quiet "$DEFAULT_SERVICE" && [[ $count -lt $timeout ]]; do
        sleep 1
        ((count++))
    done

    if systemctl is-active --quiet "$DEFAULT_SERVICE"; then
        log_warning "Service did not stop gracefully within ${timeout}s. Force stopping..."
        sudo systemctl kill --signal=SIGKILL "$DEFAULT_SERVICE"
        sleep 2
    fi

    if [[ "$disable_service" == true ]]; then
        log_info "Disabling default runner service from auto-start..."
        sudo systemctl disable "$DEFAULT_SERVICE"
    fi

    if ! systemctl is-active --quiet "$DEFAULT_SERVICE"; then
        log_success "Default GitHub runner stopped successfully!"
        if [[ "$disable_service" == true ]]; then
            log_success "Service auto-start disabled."
        fi
    else
        log_error "Failed to stop default GitHub runner."
        systemctl status "$DEFAULT_SERVICE" --no-pager -l
        exit 1
    fi
}

# Stop specific template runner
stop_template_runner() {
    local runner_name="$1"
    local force_stop="$2"
    local disable_service="$3"
    local service_name="${TEMPLATE_SERVICE}${runner_name}"

    log_info "Stopping GitHub runner instance: $runner_name"

    if ! systemctl is-active --quiet "$service_name"; then
        log_warning "Runner '$runner_name' is already stopped."
        systemctl status "$service_name" --no-pager -l || true
        return 0
    fi

    if [[ "$force_stop" == true ]]; then
        log_warning "Force stopping runner '$runner_name' (immediate termination)..."
        sudo systemctl kill --signal=SIGKILL "$service_name"
    else
        log_info "Gracefully stopping runner '$runner_name' (allows jobs to complete)..."
        sudo systemctl stop "$service_name"
    fi

    # Wait for service to stop
    local timeout=30
    local count=0
    while systemctl is-active --quiet "$service_name" && [[ $count -lt $timeout ]]; do
        sleep 1
        ((count++))
    done

    if systemctl is-active --quiet "$service_name"; then
        log_warning "Service did not stop gracefully within ${timeout}s. Force stopping..."
        sudo systemctl kill --signal=SIGKILL "$service_name"
        sleep 2
    fi

    if [[ "$disable_service" == true ]]; then
        log_info "Disabling runner '$runner_name' service from auto-start..."
        sudo systemctl disable "$service_name"
    fi

    if ! systemctl is-active --quiet "$service_name"; then
        log_success "GitHub runner '$runner_name' stopped successfully!"
        if [[ "$disable_service" == true ]]; then
            log_success "Service auto-start disabled."
        fi
    else
        log_error "Failed to stop GitHub runner '$runner_name'."
        systemctl status "$service_name" --no-pager -l
        exit 1
    fi
}

# Stop all configured template runners
stop_all_runners() {
    local force_stop="$1"
    local disable_service="$2"

    log_info "Stopping all configured GitHub runners..."

    # Find all active runner services (both default and template)
    local active_services
    active_services=$(systemctl list-units --type=service --state=active | grep "github-runner" | awk '{print $1}' | sed 's/\.service$//' || true)

    if [[ -z "$active_services" ]]; then
        log_warning "No active GitHub runner services found."
        return 0
    fi

    local stopped_count=0
    local failed_count=0

    # Stop each active service
    while IFS= read -r service; do
        log_info "Stopping service: $service"

        if [[ "$force_stop" == true ]]; then
            if sudo systemctl kill --signal=SIGKILL "$service.service"; then
                ((stopped_count++))
                log_success "Force stopped service: $service"
            else
                ((failed_count++))
                log_error "Failed to force stop service: $service"
            fi
        else
            if sudo systemctl stop "$service.service"; then
                ((stopped_count++))
                log_success "Stopped service: $service"
            else
                ((failed_count++))
                log_error "Failed to stop service: $service"
            fi
        fi

        if [[ "$disable_service" == true ]]; then
            sudo systemctl disable "$service.service" || true
        fi

        sleep 1  # Brief pause between stops
    done <<< "$active_services"

    # Wait a moment for all services to fully stop
    sleep 3

    # Summary
    echo
    log_info "Stop operation complete:"
    log_success "$stopped_count runners stopped successfully"
    if [[ $failed_count -gt 0 ]]; then
        log_error "$failed_count runners failed to stop"
    fi

    if [[ "$disable_service" == true ]]; then
        log_success "Auto-start disabled for all services"
    fi
}

# Stop Docker-based runner
stop_docker_runner() {
    local force_stop="$1"

    log_info "Stopping Docker-based GitHub runner..."

    cd "$PROJECT_ROOT"

    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in project root."
        log_info "Make sure you're running this from the correct directory."
        exit 1
    fi

    # Check if running
    if ! docker-compose ps | grep -q "Up"; then
        log_warning "Docker runner appears to already be stopped."
        docker-compose ps
        return 0
    fi

    if [[ "$force_stop" == true ]]; then
        log_warning "Force stopping Docker runner (immediate termination)..."
        docker-compose kill
        docker-compose down --remove-orphans
    else
        log_info "Gracefully stopping Docker runner..."
        docker-compose down --remove-orphans
    fi

    # Wait a moment and check status
    sleep 3

    if ! docker-compose ps | grep -q "Up"; then
        log_success "Docker GitHub runner stopped successfully!"
    else
        log_error "Failed to stop Docker GitHub runner."
        docker-compose ps
        exit 1
    fi
}

# Show status of all runners
show_all_status() {
    log_info "GitHub Runner Status Summary"
    echo "================================"

    # Check default service
    if systemctl list-unit-files --type=service | grep -q "^$DEFAULT_SERVICE"; then
        local status
        if systemctl is-active --quiet "$DEFAULT_SERVICE"; then
            status="${GREEN}RUNNING${NC}"
        else
            status="${RED}STOPPED${NC}"
        fi
        echo -e "Default Runner:    $status"
    fi

    # Check template services
    local template_services
    template_services=$(systemctl list-unit-files --type=service | grep "^github-runner@" | awk '{print $1}' | sed 's/\.service$//' || true)

    if [[ -n "$template_services" ]]; then
        echo "Template Runners:"
        while IFS= read -r service; do
            local runner_name=${service#github-runner@}
            local status
            if systemctl is-active --quiet "$service.service"; then
                status="${GREEN}RUNNING${NC}"
            else
                status="${RED}STOPPED${NC}"
            fi
            echo -e "  $runner_name:    $status"
        done <<< "$template_services"
    fi

    # Check Docker services
    if [[ -f "$PROJECT_ROOT/docker-compose.yml" ]] && command -v docker-compose &> /dev/null; then
        echo "Docker Services:"
        cd "$PROJECT_ROOT"
        if docker-compose ps | grep -q "Up"; then
            echo -e "  Docker Runner: ${GREEN}RUNNING${NC}"
        else
            echo -e "  Docker Runner: ${RED}STOPPED${NC}"
        fi
    fi

    echo "================================"
}

# Main execution
main() {
    local runner_name=""
    local stop_all=false
    local use_docker=false
    local force_stop=false
    local disable_service=false
    local show_status=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --all)
                stop_all=true
                shift
                ;;
            --docker)
                use_docker=true
                shift
                ;;
            --force)
                force_stop=true
                shift
                ;;
            --disable)
                disable_service=true
                shift
                ;;
            --status)
                show_status=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
            *)
                runner_name="$1"
                shift
                ;;
        esac
    done

    # Show status and exit if requested
    if [[ "$show_status" == true ]]; then
        check_systemd
        show_all_status
        exit 0
    fi

    # Security check
    check_root

    # Warning for force stop
    if [[ "$force_stop" == true ]]; then
        log_warning "Force stop will immediately terminate running jobs!"
        read -p "Are you sure you want to force stop? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled."
            exit 0
        fi
    fi

    # Handle different stop modes
    if [[ "$use_docker" == true ]]; then
        check_docker
        stop_docker_runner "$force_stop"
    elif [[ "$stop_all" == true ]]; then
        check_systemd
        stop_all_runners "$force_stop" "$disable_service"
    elif [[ -n "$runner_name" ]]; then
        check_systemd
        stop_template_runner "$runner_name" "$force_stop" "$disable_service"
    else
        check_systemd
        stop_default_runner "$force_stop" "$disable_service"
    fi

    echo
    log_success "Runner stop operation completed!"
    if [[ "$force_stop" == false ]]; then
        log_info "Jobs were allowed to complete gracefully."
    fi
}

# Run main function with all arguments
main "$@"