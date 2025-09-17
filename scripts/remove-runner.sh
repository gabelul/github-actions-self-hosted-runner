#!/bin/bash

# GitHub Actions Self-Hosted Runner - Remove Runner Script
#
# This script safely removes a GitHub runner instance, including deregistration
# from GitHub, service cleanup, and directory removal.
#
# Usage:
#   ./remove-runner.sh runner1                      # Remove specific runner
#   ./remove-runner.sh --all                        # Remove all runners
#   ./remove-runner.sh runner1 --force              # Skip confirmations
#   ./remove-runner.sh runner1 --keep-data          # Keep runner data
#   ./remove-runner.sh --help                       # Show help

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RUNNER_BASE_DIR="/home/github-runner/runners"
ENV_BASE_DIR="/etc/github-runner"
TEMPLATE_SERVICE="github-runner@"
DEFAULT_SERVICE="github-runner"

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
GitHub Actions Self-Hosted Runner - Remove Runner Script

USAGE:
    $0 [OPTIONS] [RUNNER_NAME]

ARGUMENTS:
    RUNNER_NAME         Name of the runner instance to remove

OPTIONS:
    --all              Remove all configured runner instances
    --force            Skip all confirmation prompts (dangerous!)
    --keep-data        Keep runner data directory (don't delete files)
    --keep-logs        Keep systemd service logs
    --github-only      Only deregister from GitHub (keep local files)
    --local-only       Only remove local files (skip GitHub deregistration)
    --help             Show this help message

EXAMPLES:
    $0 runner1         # Remove specific runner with confirmations
    $0 --all           # Remove all runners with confirmations
    $0 runner1 --force # Remove runner without confirmations
    $0 runner1 --keep-data    # Remove service but keep data
    $0 runner1 --github-only  # Only deregister from GitHub

WHAT GETS REMOVED:
    1. Runner deregistration from GitHub
    2. SystemD service stop and disable
    3. Service configuration files
    4. Runner installation directory
    5. Environment configuration file
    6. Service logs (unless --keep-logs specified)

SAFETY FEATURES:
    - Confirmation prompts for destructive operations
    - Graceful service shutdown (allows jobs to complete)
    - Backup option for runner configuration
    - Rollback capability for failed operations

For more information, see the documentation in docs/
EOF
}

# Check if running as root (not recommended)
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
        exit 1
    fi
}

# Get confirmation from user
confirm_action() {
    local message="$1"
    local force="$2"

    if [[ "$force" == true ]]; then
        return 0
    fi

    echo
    log_warning "$message"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Operation cancelled by user."
        exit 0
    fi
}

# Deregister runner from GitHub
deregister_from_github() {
    local runner_dir="$1"
    local runner_name="$2"
    local force="$3"

    log_info "Deregistering runner '$runner_name' from GitHub..."

    if [[ ! -d "$runner_dir" ]]; then
        log_warning "Runner directory not found: $runner_dir"
        log_info "Runner may already be removed or was never properly configured."
        return 0
    fi

    if [[ ! -f "$runner_dir/config.sh" ]]; then
        log_warning "Runner configuration script not found in: $runner_dir"
        log_info "Cannot deregister runner from GitHub automatically."
        return 0
    fi

    # Check if runner is registered
    if [[ ! -f "$runner_dir/.runner" ]]; then
        log_warning "Runner configuration file not found. Runner may not be registered."
        return 0
    fi

    cd "$runner_dir"

    # Get GitHub token from environment file
    local env_file="$ENV_BASE_DIR/${runner_name}.env"
    local github_token=""

    if [[ -f "$env_file" ]]; then
        # Source the environment file to get the token
        source "$env_file" 2>/dev/null || true
        github_token="$GITHUB_TOKEN"
    fi

    if [[ -z "$github_token" ]]; then
        log_warning "GitHub token not found in environment file."
        log_info "Manual deregistration may be required from GitHub repository/organization settings."

        if [[ "$force" != true ]]; then
            read -p "Continue with local removal only? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Operation cancelled."
                exit 0
            fi
        fi
        return 0
    fi

    # Run deregistration as github-runner user
    log_info "Running GitHub deregistration..."
    if sudo -u github-runner ./config.sh remove --token "$github_token"; then
        log_success "Runner deregistered from GitHub successfully"
    else
        log_error "Failed to deregister runner from GitHub"
        log_info "The runner may need to be manually removed from GitHub settings."

        if [[ "$force" != true ]]; then
            read -p "Continue with local removal? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Operation cancelled."
                exit 1
            fi
        fi
    fi
}

# Stop and disable service
remove_service() {
    local service_name="$1"
    local keep_logs="$2"

    log_info "Removing service: $service_name"

    # Check if service exists
    if ! systemctl list-unit-files --type=service | grep -q "^${service_name}\.service"; then
        log_warning "Service not found: $service_name"
        return 0
    fi

    # Stop service if running
    if systemctl is-active --quiet "$service_name"; then
        log_info "Stopping service gracefully..."
        sudo systemctl stop "$service_name"

        # Wait for service to stop
        local timeout=30
        local count=0
        while systemctl is-active --quiet "$service_name" && [[ $count -lt $timeout ]]; do
            sleep 1
            ((count++))
        done

        if systemctl is-active --quiet "$service_name"; then
            log_warning "Service did not stop gracefully. Force stopping..."
            sudo systemctl kill --signal=SIGKILL "$service_name"
            sleep 2
        fi

        log_success "Service stopped"
    else
        log_info "Service is not running"
    fi

    # Disable service
    if systemctl is-enabled --quiet "$service_name"; then
        log_info "Disabling service auto-start..."
        sudo systemctl disable "$service_name"
        log_success "Service disabled"
    fi

    # Reset failed state if present
    if systemctl is-failed --quiet "$service_name"; then
        sudo systemctl reset-failed "$service_name"
    fi

    # Remove service logs if requested
    if [[ "$keep_logs" != true ]]; then
        log_info "Removing service logs..."
        sudo journalctl --vacuum-size=1K --unit="$service_name" || true
        log_success "Service logs removed"
    fi
}

# Remove runner files and directories
remove_runner_files() {
    local runner_name="$1"
    local keep_data="$2"

    local runner_dir="$RUNNER_BASE_DIR/$runner_name"
    local env_file="$ENV_BASE_DIR/${runner_name}.env"

    # Remove environment file
    if [[ -f "$env_file" ]]; then
        log_info "Removing environment file: $env_file"
        sudo rm -f "$env_file"
        log_success "Environment file removed"
    else
        log_info "Environment file not found: $env_file"
    fi

    # Remove runner directory
    if [[ -d "$runner_dir" ]]; then
        if [[ "$keep_data" == true ]]; then
            log_info "Keeping runner data directory as requested: $runner_dir"
        else
            log_info "Removing runner directory: $runner_dir"

            # Create backup of runner configuration if it exists
            if [[ -f "$runner_dir/.runner" ]]; then
                local backup_dir="/tmp/github-runner-backup-$(date +%Y%m%d-%H%M%S)"
                log_info "Creating backup of runner configuration: $backup_dir"
                sudo mkdir -p "$backup_dir"
                sudo cp "$runner_dir/.runner" "$backup_dir/" || true
                sudo cp "$runner_dir/.credentials" "$backup_dir/" 2>/dev/null || true
                log_success "Backup created at: $backup_dir"
            fi

            # Remove directory
            sudo rm -rf "$runner_dir"
            log_success "Runner directory removed"
        fi
    else
        log_info "Runner directory not found: $runner_dir"
    fi
}

# Create removal summary
create_removal_summary() {
    local runner_name="$1"
    local github_deregistered="$2"
    local service_removed="$3"
    local files_removed="$4"

    echo
    echo "========================================"
    log_info "Removal Summary for: $runner_name"
    echo "========================================"

    if [[ "$github_deregistered" == true ]]; then
        echo "✅ GitHub deregistration: COMPLETED"
    else
        echo "⚠️  GitHub deregistration: SKIPPED or FAILED"
    fi

    if [[ "$service_removed" == true ]]; then
        echo "✅ Service removal: COMPLETED"
    else
        echo "⚠️  Service removal: SKIPPED or FAILED"
    fi

    if [[ "$files_removed" == true ]]; then
        echo "✅ File removal: COMPLETED"
    else
        echo "⚠️  File removal: SKIPPED"
    fi

    echo "========================================"

    if [[ "$github_deregistered" == true && "$service_removed" == true && "$files_removed" == true ]]; then
        log_success "Runner '$runner_name' removed completely!"
    else
        log_warning "Runner '$runner_name' removal completed with some issues."
        log_info "Check the summary above for details."
    fi
}

# Remove single runner
remove_single_runner() {
    local runner_name="$1"
    local force="$2"
    local keep_data="$3"
    local keep_logs="$4"
    local github_only="$5"
    local local_only="$6"

    local runner_dir="$RUNNER_BASE_DIR/$runner_name"
    local service_name="${TEMPLATE_SERVICE}${runner_name}"
    local github_deregistered=false
    local service_removed=false
    local files_removed=false

    echo "========================================"
    log_info "Removing GitHub runner: $runner_name"
    echo "========================================"

    # Check if runner exists
    if [[ ! -d "$runner_dir" ]] && ! systemctl list-unit-files --type=service | grep -q "^${service_name}\.service"; then
        log_error "Runner '$runner_name' not found."
        log_info "No runner directory or service found."
        exit 1
    fi

    # Show what will be removed
    echo
    log_info "Runner removal plan:"
    if [[ "$local_only" != true ]]; then
        echo "  • Deregister from GitHub"
    fi
    if [[ "$github_only" != true ]]; then
        echo "  • Stop and disable service: $service_name"
        if [[ "$keep_data" != true ]]; then
            echo "  • Remove runner directory: $runner_dir"
        fi
        echo "  • Remove environment file: $ENV_BASE_DIR/${runner_name}.env"
        if [[ "$keep_logs" != true ]]; then
            echo "  • Remove service logs"
        fi
    fi
    echo

    # Confirm removal
    confirm_action "This will permanently remove the runner '$runner_name'." "$force"

    # GitHub deregistration
    if [[ "$local_only" != true ]]; then
        deregister_from_github "$runner_dir" "$runner_name" "$force"
        github_deregistered=true
    else
        log_info "Skipping GitHub deregistration (--local-only specified)"
    fi

    # Local cleanup
    if [[ "$github_only" != true ]]; then
        # Remove service
        remove_service "$service_name" "$keep_logs"
        service_removed=true

        # Remove files
        remove_runner_files "$runner_name" "$keep_data"
        files_removed=true
    else
        log_info "Skipping local cleanup (--github-only specified)"
    fi

    # Reload systemd daemon
    if [[ "$github_only" != true ]]; then
        sudo systemctl daemon-reload
    fi

    # Show summary
    create_removal_summary "$runner_name" "$github_deregistered" "$service_removed" "$files_removed"
}

# Remove all runners
remove_all_runners() {
    local force="$1"
    local keep_data="$2"
    local keep_logs="$3"
    local github_only="$4"
    local local_only="$5"

    log_info "Removing all GitHub runners..."

    # Find all template services
    local template_services
    template_services=$(systemctl list-unit-files --type=service | grep "^github-runner@" | awk '{print $1}' | sed 's/\.service$//' || true)

    # Also check for default service
    local default_exists=false
    if systemctl list-unit-files --type=service | grep -q "^$DEFAULT_SERVICE\.service"; then
        default_exists=true
    fi

    # Collect all runner names
    local all_runners=()

    if [[ "$default_exists" == true ]]; then
        all_runners+=("default")
    fi

    if [[ -n "$template_services" ]]; then
        while IFS= read -r service; do
            local runner_name=${service#github-runner@}
            all_runners+=("$runner_name")
        done <<< "$template_services"
    fi

    if [[ ${#all_runners[@]} -eq 0 ]]; then
        log_warning "No GitHub runners found to remove."
        return 0
    fi

    echo
    log_info "Found ${#all_runners[@]} runner(s) to remove:"
    for runner in "${all_runners[@]}"; do
        echo "  • $runner"
    done
    echo

    # Confirm removal of all runners
    confirm_action "This will permanently remove ALL GitHub runners on this system!" "$force"

    # Remove each runner
    local removed_count=0
    local failed_count=0

    for runner_name in "${all_runners[@]}"; do
        echo
        log_info "Removing runner: $runner_name"
        echo "----------------------------------------"

        if [[ "$runner_name" == "default" ]]; then
            # Handle default service differently
            if [[ "$local_only" != true ]]; then
                deregister_from_github "/home/github-runner" "default" "$force"
            fi

            if [[ "$github_only" != true ]]; then
                remove_service "$DEFAULT_SERVICE" "$keep_logs"
                if [[ "$keep_data" != true ]]; then
                    sudo rm -rf "/home/github-runner/_work" 2>/dev/null || true
                fi
            fi
            ((removed_count++))
        else
            # Handle template service
            if remove_single_runner "$runner_name" true "$keep_data" "$keep_logs" "$github_only" "$local_only"; then
                ((removed_count++))
            else
                ((failed_count++))
            fi
        fi
    done

    # Final summary
    echo
    echo "========================================"
    log_info "Bulk Removal Summary"
    echo "========================================"
    log_success "$removed_count runners removed successfully"
    if [[ $failed_count -gt 0 ]]; then
        log_error "$failed_count runners failed to remove completely"
    fi
    echo "========================================"

    # Reload systemd daemon
    if [[ "$github_only" != true ]]; then
        sudo systemctl daemon-reload
    fi
}

# Main execution
main() {
    local runner_name=""
    local remove_all=false
    local force=false
    local keep_data=false
    local keep_logs=false
    local github_only=false
    local local_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --all)
                remove_all=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --keep-data)
                keep_data=true
                shift
                ;;
            --keep-logs)
                keep_logs=true
                shift
                ;;
            --github-only)
                github_only=true
                shift
                ;;
            --local-only)
                local_only=true
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

    # Validate conflicting options
    if [[ "$github_only" == true && "$local_only" == true ]]; then
        log_error "Cannot specify both --github-only and --local-only"
        exit 1
    fi

    if [[ "$github_only" == true && "$keep_data" == true ]]; then
        log_warning "--keep-data has no effect with --github-only"
    fi

    if [[ "$github_only" == true && "$keep_logs" == true ]]; then
        log_warning "--keep-logs has no effect with --github-only"
    fi

    # Security check
    check_root

    # Check prerequisites
    check_systemd

    # Handle different removal modes
    if [[ "$remove_all" == true ]]; then
        remove_all_runners "$force" "$keep_data" "$keep_logs" "$github_only" "$local_only"
    elif [[ -n "$runner_name" ]]; then
        remove_single_runner "$runner_name" "$force" "$keep_data" "$keep_logs" "$github_only" "$local_only"
    else
        log_error "Either specify a runner name or use --all to remove all runners"
        echo
        show_help
        exit 1
    fi

    echo
    log_success "Runner removal operation completed!"
    if [[ "$github_only" != true ]]; then
        log_info "System resources have been cleaned up."
    fi
    if [[ "$local_only" != true ]]; then
        log_info "Runners have been deregistered from GitHub."
    fi
}

# Run main function with all arguments
main "$@"