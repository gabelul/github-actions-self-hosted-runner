#!/bin/bash

# GitHub Actions Self-Hosted Runner - Start Script
#
# This script provides a unified way to start GitHub runners whether they're
# configured as single instances or multi-runner template services.
#
# Usage:
#   ./start-runner.sh                    # Start default single runner
#   ./start-runner.sh runner1            # Start specific template runner
#   ./start-runner.sh --all              # Start all configured runners
#   ./start-runner.sh --docker           # Start Docker-based runner
#   ./start-runner.sh --help             # Show help

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
GitHub Actions Self-Hosted Runner - Start Script

USAGE:
    $0 [OPTIONS] [RUNNER_NAME]

ARGUMENTS:
    RUNNER_NAME         Name of the runner instance (for template services)

OPTIONS:
    --all              Start all configured runner instances
    --docker           Start Docker-based runner using docker-compose
    --status           Show status of all runners
    --help             Show this help message

EXAMPLES:
    $0                 # Start default single runner service
    $0 project1        # Start template runner named 'project1'
    $0 --all           # Start all configured template runners
    $0 --docker        # Start Docker runner with docker-compose
    $0 --status        # Show status of all runners

SYSTEMD SERVICES:
    Single Runner:     github-runner.service
    Template Runners:  github-runner@RUNNER_NAME.service

DOCKER SERVICES:
    Docker Compose:    Uses docker-compose.yml in project root

For more information, see the documentation in docs/
EOF
}

# Check if running as root (not recommended for security)
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root is not recommended for security reasons."
        log_warning "Consider running as a non-privileged user with sudo access."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
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

# Start single default runner
start_default_runner() {
    log_info "Starting default GitHub runner service..."

    if systemctl is-active --quiet "$DEFAULT_SERVICE"; then
        log_warning "Default runner is already running."
        systemctl status "$DEFAULT_SERVICE" --no-pager -l
        return 0
    fi

    if ! systemctl is-enabled --quiet "$DEFAULT_SERVICE"; then
        log_info "Enabling default runner service for auto-start..."
        sudo systemctl enable "$DEFAULT_SERVICE"
    fi

    sudo systemctl start "$DEFAULT_SERVICE"

    # Wait a moment for service to initialize
    sleep 2

    if systemctl is-active --quiet "$DEFAULT_SERVICE"; then
        log_success "Default GitHub runner started successfully!"
        systemctl status "$DEFAULT_SERVICE" --no-pager -l
    else
        log_error "Failed to start default GitHub runner."
        log_info "Check logs with: sudo journalctl -u $DEFAULT_SERVICE -f"
        exit 1
    fi
}

# Start specific template runner
start_template_runner() {
    local runner_name="$1"
    local service_name="${TEMPLATE_SERVICE}${runner_name}"

    log_info "Starting GitHub runner instance: $runner_name"

    # Check if environment file exists
    local env_file="/etc/github-runner/${runner_name}.env"
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        log_info "Create the environment file with runner configuration first."
        log_info "Example: GITHUB_TOKEN=ghp_xxx, RUNNER_NAME=${runner_name}-runner"
        exit 1
    fi

    # Check if runner directory exists
    local runner_dir="/home/github-runner/runners/${runner_name}"
    if [[ ! -d "$runner_dir" ]]; then
        log_error "Runner directory not found: $runner_dir"
        log_info "Configure the runner first using setup.sh script."
        exit 1
    fi

    if systemctl is-active --quiet "$service_name"; then
        log_warning "Runner '$runner_name' is already running."
        systemctl status "$service_name" --no-pager -l
        return 0
    fi

    if ! systemctl is-enabled --quiet "$service_name"; then
        log_info "Enabling runner service '$runner_name' for auto-start..."
        sudo systemctl enable "$service_name"
    fi

    sudo systemctl start "$service_name"

    # Wait a moment for service to initialize
    sleep 2

    if systemctl is-active --quiet "$service_name"; then
        log_success "GitHub runner '$runner_name' started successfully!"
        systemctl status "$service_name" --no-pager -l
    else
        log_error "Failed to start GitHub runner '$runner_name'."
        log_info "Check logs with: sudo journalctl -u $service_name -f"
        exit 1
    fi
}

# Start all configured template runners
start_all_runners() {
    log_info "Starting all configured GitHub runners..."

    # Find all template service instances
    local template_services
    template_services=$(systemctl list-unit-files --type=service | grep "^github-runner@" | awk '{print $1}' | sed 's/\.service$//' || true)

    if [[ -z "$template_services" ]]; then
        log_warning "No template runner services found."
        log_info "Check if any github-runner@*.service files exist in /etc/systemd/system/"

        # Try to start the default service instead
        if systemctl list-unit-files --type=service | grep -q "^$DEFAULT_SERVICE"; then
            log_info "Starting default single runner service instead..."
            start_default_runner
        else
            log_error "No GitHub runner services found to start."
            exit 1
        fi
        return
    fi

    local started_count=0
    local failed_count=0

    # Start each template service
    while IFS= read -r service; do
        local runner_name=${service#github-runner@}
        log_info "Starting runner: $runner_name"

        if systemctl is-active --quiet "$service.service"; then
            log_warning "Runner '$runner_name' is already running."
            continue
        fi

        if sudo systemctl start "$service.service"; then
            ((started_count++))
            log_success "Started runner: $runner_name"
        else
            ((failed_count++))
            log_error "Failed to start runner: $runner_name"
        fi

        sleep 1  # Brief pause between starts
    done <<< "$template_services"

    # Summary
    echo
    log_info "Start operation complete:"
    log_success "$started_count runners started successfully"
    if [[ $failed_count -gt 0 ]]; then
        log_error "$failed_count runners failed to start"
    fi

    # Show overall status
    echo
    show_all_status
}

# Start Docker-based runner
start_docker_runner() {
    log_info "Starting Docker-based GitHub runner..."

    cd "$PROJECT_ROOT"

    if [[ ! -f "docker-compose.yml" ]]; then
        log_error "docker-compose.yml not found in project root."
        log_info "Make sure you're running this from the correct directory."
        exit 1
    fi

    if [[ ! -f "docker/.env" ]]; then
        log_warning "Docker environment file not found at docker/.env"
        log_info "Copy docker/.env.example to docker/.env and configure it first."
        exit 1
    fi

    # Check if already running
    if docker-compose ps | grep -q "Up"; then
        log_warning "Docker runner appears to be already running."
        docker-compose ps
        return 0
    fi

    # Start the services
    log_info "Pulling latest images..."
    docker-compose pull

    log_info "Starting Docker runner services..."
    docker-compose up -d

    # Wait for services to initialize
    sleep 5

    # Check status
    if docker-compose ps | grep -q "Up"; then
        log_success "Docker GitHub runner started successfully!"
        echo
        docker-compose ps
        echo
        log_info "View logs with: docker-compose logs -f"
        log_info "Stop with: docker-compose down"
    else
        log_error "Failed to start Docker GitHub runner."
        echo
        docker-compose ps
        echo
        log_info "Check logs with: docker-compose logs"
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
    local start_all=false
    local use_docker=false
    local show_status=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --all)
                start_all=true
                shift
                ;;
            --docker)
                use_docker=true
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

    # Handle different start modes
    if [[ "$use_docker" == true ]]; then
        check_docker
        start_docker_runner
    elif [[ "$start_all" == true ]]; then
        check_systemd
        start_all_runners
    elif [[ -n "$runner_name" ]]; then
        check_systemd
        start_template_runner "$runner_name"
    else
        check_systemd
        start_default_runner
    fi

    echo
    log_success "Runner start operation completed!"
    log_info "Monitor logs with: sudo journalctl -u github-runner* -f"
}

# Run main function with all arguments
main "$@"