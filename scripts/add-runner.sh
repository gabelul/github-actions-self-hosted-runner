#!/bin/bash

# GitHub Actions Self-Hosted Runner - Add New Runner Script
#
# This script creates and configures a new runner instance for multi-runner
# template service deployments. It handles runner registration, directory
# setup, environment configuration, and service installation.
#
# Usage:
#   ./add-runner.sh --name runner1 --token TOKEN --repo owner/repo
#   ./add-runner.sh --name project2 --token TOKEN --org organization
#   ./add-runner.sh --interactive                    # Interactive setup
#   ./add-runner.sh --help                          # Show help

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RUNNER_BASE_DIR="/home/github-runner/runners"
ENV_BASE_DIR="/etc/github-runner"
TEMPLATE_SERVICE="github-runner@"
GITHUB_RUNNER_VERSION="2.311.0"  # Update as needed

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
GitHub Actions Self-Hosted Runner - Add New Runner Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --name NAME            Runner instance name (used for service and directories)
    --token TOKEN          GitHub personal access token or runner token
    --repo OWNER/REPO      Repository to register runner with (e.g., "owner/repository")
    --org ORGANIZATION     Organization to register runner with
    --labels LABELS        Comma-separated runner labels (default: "self-hosted,Linux,X64")
    --runner-group GROUP   Runner group name (enterprise feature)
    --work-folder PATH     Custom work folder path (optional)
    --interactive          Interactive setup mode
    --replace              Replace existing runner with same name
    --help                 Show this help message

EXAMPLES:
    # Add runner for specific repository
    $0 --name project1 --token ghp_xxx --repo owner/project1

    # Add runner for organization
    $0 --name org-runner --token ghp_xxx --org myorganization

    # Interactive setup
    $0 --interactive

    # Custom labels and work folder
    $0 --name build-server --token ghp_xxx --repo owner/repo \\
       --labels "self-hosted,Linux,build-server" --work-folder "/tmp/builds"

    # Replace existing runner
    $0 --name project1 --token ghp_xxx --repo owner/project1 --replace

REQUIREMENTS:
    - GitHub personal access token with 'repo' or 'admin:org' scope
    - SystemD template service (github-runner@.service) must be installed
    - Runner user 'github-runner' must exist
    - Internet connectivity to download GitHub runner binary

DIRECTORY STRUCTURE:
    $RUNNER_BASE_DIR/RUNNER_NAME/    # Runner installation directory
    $ENV_BASE_DIR/RUNNER_NAME.env    # Environment configuration file

For more information, see the documentation in docs/
EOF
}

# Check if running as root (not recommended)
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if template service exists
    if [[ ! -f "/etc/systemd/system/github-runner@.service" ]]; then
        log_error "Template service not found: /etc/systemd/system/github-runner@.service"
        log_info "Install the template service first using setup.sh script."
        exit 1
    fi

    # Check if github-runner user exists
    if ! id "github-runner" &>/dev/null; then
        log_error "User 'github-runner' does not exist."
        log_info "Create the user first using setup.sh script."
        exit 1
    fi

    # Check if base directories exist
    if [[ ! -d "$RUNNER_BASE_DIR" ]]; then
        log_info "Creating runner base directory: $RUNNER_BASE_DIR"
        sudo mkdir -p "$RUNNER_BASE_DIR"
        sudo chown github-runner:github-runner "$RUNNER_BASE_DIR"
    fi

    if [[ ! -d "$ENV_BASE_DIR" ]]; then
        log_info "Creating environment base directory: $ENV_BASE_DIR"
        sudo mkdir -p "$ENV_BASE_DIR"
        sudo chmod 755 "$ENV_BASE_DIR"
    fi

    # Check required commands
    for cmd in curl tar jq systemctl; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done

    log_success "Prerequisites check completed"
}

# Validate runner name
validate_runner_name() {
    local runner_name="$1"

    if [[ -z "$runner_name" ]]; then
        log_error "Runner name cannot be empty"
        return 1
    fi

    if [[ ! "$runner_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$ ]] && [[ ${#runner_name} -gt 1 ]]; then
        log_error "Invalid runner name: $runner_name"
        log_info "Runner name must contain only letters, numbers, hyphens, and underscores"
        log_info "Must start and end with alphanumeric characters"
        return 1
    fi

    return 0
}

# Interactive setup
interactive_setup() {
    echo "========================================"
    log_info "Interactive GitHub Runner Setup"
    echo "========================================"

    # Get runner name
    local runner_name=""
    while [[ -z "$runner_name" ]]; do
        read -p "Enter runner name: " runner_name
        if ! validate_runner_name "$runner_name"; then
            runner_name=""
        fi
    done

    # Get GitHub token
    local github_token=""
    while [[ -z "$github_token" ]]; do
        read -s -p "Enter GitHub token: " github_token
        echo
        if [[ ${#github_token} -lt 10 ]]; then
            log_error "Token seems too short. Please enter a valid GitHub token."
            github_token=""
        fi
    done

    # Get repository or organization
    echo
    echo "Register runner with:"
    echo "1) Repository (owner/repository)"
    echo "2) Organization"
    read -p "Choose (1/2): " choice

    local repo=""
    local org=""
    case "$choice" in
        1)
            read -p "Enter repository (owner/repository): " repo
            if [[ ! "$repo" =~ ^[^/]+/[^/]+$ ]]; then
                log_error "Invalid repository format. Use: owner/repository"
                exit 1
            fi
            ;;
        2)
            read -p "Enter organization name: " org
            if [[ -z "$org" ]]; then
                log_error "Organization name cannot be empty"
                exit 1
            fi
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac

    # Get optional labels
    local labels="self-hosted,Linux,X64"
    read -p "Enter custom labels (press Enter for default: $labels): " custom_labels
    if [[ -n "$custom_labels" ]]; then
        labels="$custom_labels"
    fi

    # Get optional work folder
    local work_folder=""
    read -p "Enter custom work folder (press Enter for default): " work_folder

    # Confirm settings
    echo
    echo "========================================"
    log_info "Configuration Summary"
    echo "========================================"
    echo "Runner Name: $runner_name"
    if [[ -n "$repo" ]]; then
        echo "Repository: $repo"
    else
        echo "Organization: $org"
    fi
    echo "Labels: $labels"
    if [[ -n "$work_folder" ]]; then
        echo "Work Folder: $work_folder"
    fi
    echo "========================================"

    read -p "Proceed with this configuration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled by user."
        exit 0
    fi

    # Call main setup function with collected parameters
    setup_runner "$runner_name" "$github_token" "$repo" "$org" "$labels" "" "$work_folder" false
}

# Download and extract GitHub runner
download_runner() {
    local runner_dir="$1"

    log_info "Downloading GitHub runner binary..."

    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Download runner
    local runner_url="https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-linux-x64-${GITHUB_RUNNER_VERSION}.tar.gz"

    if ! curl -L -o "actions-runner.tar.gz" "$runner_url"; then
        log_error "Failed to download GitHub runner from: $runner_url"
        rm -rf "$temp_dir"
        exit 1
    fi

    # Verify download
    if [[ ! -s "actions-runner.tar.gz" ]]; then
        log_error "Downloaded file is empty or corrupted"
        rm -rf "$temp_dir"
        exit 1
    fi

    log_success "GitHub runner downloaded successfully"

    # Extract to runner directory
    log_info "Extracting runner to: $runner_dir"

    # Create runner directory as github-runner user
    sudo -u github-runner mkdir -p "$runner_dir"

    # Extract files as github-runner user
    sudo -u github-runner tar xzf "actions-runner.tar.gz" -C "$runner_dir"

    # Make run.sh executable
    sudo -u github-runner chmod +x "$runner_dir/run.sh"
    sudo -u github-runner chmod +x "$runner_dir/config.sh"

    log_success "GitHub runner extracted successfully"

    # Cleanup
    rm -rf "$temp_dir"
}

# Configure runner with GitHub
configure_runner() {
    local runner_dir="$1"
    local runner_name="$2"
    local github_token="$3"
    local repo="$4"
    local org="$5"
    local labels="$6"
    local runner_group="$7"
    local work_folder="$8"
    local replace="$9"

    log_info "Configuring runner with GitHub..."

    cd "$runner_dir"

    # Build configuration command
    local config_cmd=("./config.sh")

    # Add URL (repository or organization)
    if [[ -n "$repo" ]]; then
        config_cmd+=("--url" "https://github.com/$repo")
    elif [[ -n "$org" ]]; then
        config_cmd+=("--url" "https://github.com/$org")
    else
        log_error "Either repository or organization must be specified"
        exit 1
    fi

    # Add token
    config_cmd+=("--token" "$github_token")

    # Add runner name
    config_cmd+=("--name" "$runner_name")

    # Add labels
    if [[ -n "$labels" ]]; then
        config_cmd+=("--labels" "$labels")
    fi

    # Add runner group if specified
    if [[ -n "$runner_group" ]]; then
        config_cmd+=("--runnergroup" "$runner_group")
    fi

    # Add work folder if specified
    if [[ -n "$work_folder" ]]; then
        config_cmd+=("--work" "$work_folder")
    fi

    # Add replace flag if specified
    if [[ "$replace" == true ]]; then
        config_cmd+=("--replace")
    fi

    # Add unattended flag
    config_cmd+=("--unattended")

    # Run configuration as github-runner user
    log_info "Running runner configuration..."
    if sudo -u github-runner "${config_cmd[@]}"; then
        log_success "Runner configured successfully with GitHub"
    else
        log_error "Failed to configure runner with GitHub"
        log_info "Check your token permissions and network connectivity"
        exit 1
    fi
}

# Create environment file for the runner
create_environment_file() {
    local runner_name="$1"
    local github_token="$2"
    local repo="$3"
    local org="$4"

    local env_file="$ENV_BASE_DIR/${runner_name}.env"

    log_info "Creating environment file: $env_file"

    # Create environment file with secure permissions
    sudo tee "$env_file" > /dev/null << EOF
# GitHub Actions Self-Hosted Runner Environment Configuration
# Runner: $runner_name
# Created: $(date)

# GitHub Configuration
GITHUB_TOKEN=$github_token
RUNNER_NAME=$runner_name
$(if [[ -n "$repo" ]]; then echo "GITHUB_REPOSITORY=$repo"; fi)
$(if [[ -n "$org" ]]; then echo "GITHUB_ORGANIZATION=$org"; fi)

# Runner Configuration
RUNNER_INSTANCE=$runner_name
RUNNER_WORK_DIRECTORY=/home/github-runner/runners/$runner_name/_work

# System Configuration
HOME=/home/github-runner
USER=github-runner
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

# Optional: Add custom environment variables below
# CUSTOM_VAR=value
EOF

    # Set secure permissions
    sudo chmod 600 "$env_file"
    sudo chown github-runner:github-runner "$env_file"

    log_success "Environment file created with secure permissions"
}

# Enable and start the service
setup_service() {
    local runner_name="$1"
    local service_name="${TEMPLATE_SERVICE}${runner_name}"

    log_info "Setting up systemd service: $service_name"

    # Reload systemd daemon
    sudo systemctl daemon-reload

    # Enable service for auto-start
    if sudo systemctl enable "$service_name"; then
        log_success "Service enabled for auto-start"
    else
        log_error "Failed to enable service"
        exit 1
    fi

    # Start the service
    if sudo systemctl start "$service_name"; then
        log_success "Service started successfully"
    else
        log_error "Failed to start service"
        log_info "Check service status: sudo systemctl status $service_name"
        log_info "Check logs: sudo journalctl -u $service_name -f"
        exit 1
    fi

    # Wait a moment and check if service is running
    sleep 3
    if systemctl is-active --quiet "$service_name"; then
        log_success "Service is running correctly"
        systemctl status "$service_name" --no-pager -l
    else
        log_warning "Service may have issues starting"
        log_info "Check logs: sudo journalctl -u $service_name -f"
    fi
}

# Main setup function
setup_runner() {
    local runner_name="$1"
    local github_token="$2"
    local repo="$3"
    local org="$4"
    local labels="$5"
    local runner_group="$6"
    local work_folder="$7"
    local replace="$8"

    local runner_dir="$RUNNER_BASE_DIR/$runner_name"
    local service_name="${TEMPLATE_SERVICE}${runner_name}"

    echo "========================================"
    log_info "Setting up GitHub runner: $runner_name"
    echo "========================================"

    # Check if runner already exists
    if [[ -d "$runner_dir" ]] && [[ "$replace" != true ]]; then
        log_error "Runner directory already exists: $runner_dir"
        log_info "Use --replace flag to replace existing runner"
        exit 1
    fi

    if systemctl list-unit-files --type=service | grep -q "^${service_name}\.service"; then
        if [[ "$replace" != true ]]; then
            log_error "Service already exists: $service_name"
            log_info "Use --replace flag to replace existing runner"
            exit 1
        else
            log_warning "Stopping existing service for replacement..."
            sudo systemctl stop "$service_name" || true
            sudo systemctl disable "$service_name" || true
        fi
    fi

    # Remove existing runner directory if replacing
    if [[ -d "$runner_dir" ]] && [[ "$replace" == true ]]; then
        log_warning "Removing existing runner directory..."
        sudo rm -rf "$runner_dir"
    fi

    # Download and extract runner
    download_runner "$runner_dir"

    # Configure runner with GitHub
    configure_runner "$runner_dir" "$runner_name" "$github_token" "$repo" "$org" "$labels" "$runner_group" "$work_folder" "$replace"

    # Create environment file
    create_environment_file "$runner_name" "$github_token" "$repo" "$org"

    # Set up and start service
    setup_service "$runner_name"

    echo "========================================"
    log_success "GitHub runner '$runner_name' setup completed!"
    echo "========================================"
    echo
    log_info "Service Information:"
    echo "  Service Name: $service_name"
    echo "  Runner Directory: $runner_dir"
    echo "  Environment File: $ENV_BASE_DIR/${runner_name}.env"
    echo
    log_info "Management Commands:"
    echo "  Start:   sudo systemctl start $service_name"
    echo "  Stop:    sudo systemctl stop $service_name"
    echo "  Status:  sudo systemctl status $service_name"
    echo "  Logs:    sudo journalctl -u $service_name -f"
    echo
    log_info "Or use the provided management scripts:"
    echo "  Start:   ./scripts/start-runner.sh $runner_name"
    echo "  Stop:    ./scripts/stop-runner.sh $runner_name"
    echo "  Health:  ./scripts/health-check-runner.sh $runner_name"
    echo
}

# Main execution
main() {
    local runner_name=""
    local github_token=""
    local repo=""
    local org=""
    local labels="self-hosted,Linux,X64"
    local runner_group=""
    local work_folder=""
    local replace=false
    local interactive=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --name)
                runner_name="$2"
                shift 2
                ;;
            --token)
                github_token="$2"
                shift 2
                ;;
            --repo)
                repo="$2"
                shift 2
                ;;
            --org)
                org="$2"
                shift 2
                ;;
            --labels)
                labels="$2"
                shift 2
                ;;
            --runner-group)
                runner_group="$2"
                shift 2
                ;;
            --work-folder)
                work_folder="$2"
                shift 2
                ;;
            --replace)
                replace=true
                shift
                ;;
            --interactive)
                interactive=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                echo
                show_help
                exit 1
                ;;
        esac
    done

    # Security check
    check_root

    # Check prerequisites
    check_prerequisites

    # Handle interactive mode
    if [[ "$interactive" == true ]]; then
        interactive_setup
        exit 0
    fi

    # Validate required parameters
    if [[ -z "$runner_name" ]]; then
        log_error "Runner name is required (--name)"
        echo
        show_help
        exit 1
    fi

    if ! validate_runner_name "$runner_name"; then
        exit 1
    fi

    if [[ -z "$github_token" ]]; then
        log_error "GitHub token is required (--token)"
        echo
        show_help
        exit 1
    fi

    if [[ -z "$repo" && -z "$org" ]]; then
        log_error "Either repository (--repo) or organization (--org) is required"
        echo
        show_help
        exit 1
    fi

    if [[ -n "$repo" && -n "$org" ]]; then
        log_error "Cannot specify both repository and organization"
        echo
        show_help
        exit 1
    fi

    # Set up the runner
    setup_runner "$runner_name" "$github_token" "$repo" "$org" "$labels" "$runner_group" "$work_folder" "$replace"
}

# Run main function with all arguments
main "$@"