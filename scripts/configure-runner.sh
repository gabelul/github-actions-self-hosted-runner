#!/bin/bash

# GitHub Actions Self-Hosted Runner - Interactive Configuration Script
#
# This script provides an interactive way to configure GitHub Actions runners
# with guided prompts and validation. It's designed to be user-friendly for
# both beginners and advanced users.
#
# Usage:
#   ./configure-runner.sh                    # Interactive mode
#   ./configure-runner.sh --config-file FILE # Use configuration file
#   ./configure-runner.sh --help            # Show help
#
# Author: Gabel (Booplex.com)
# Website: https://booplex.com
# Built with: User empathy, validation functions, and the tears of users who hate CLIs
#
# Philosophy: Making interactive scripts that don't make you want to rage-quit

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly CONFIG_DIR="$PROJECT_ROOT/config"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Global variables
CONFIG_FILE=""
INTERACTIVE_MODE=true
RUNNER_CONFIG=()

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
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_header() {
    echo -e "${WHITE}$1${NC}"
}

log_prompt() {
    echo -e "${CYAN}$1${NC}"
}

# Show help information
show_help() {
    cat << EOF
${WHITE}GitHub Actions Self-Hosted Runner - Configuration Script${NC}

This script helps you configure GitHub Actions runners through an interactive
process or by using a configuration file.

${WHITE}USAGE:${NC}
    $0 [OPTIONS]

${WHITE}OPTIONS:${NC}
    --config-file FILE   Use existing configuration file
    --validate          Validate configuration without applying
    --help              Show this help message

${WHITE}EXAMPLES:${NC}
    # Interactive configuration
    $0

    # Use configuration file
    $0 --config-file my-runner.conf

    # Validate configuration
    $0 --config-file my-runner.conf --validate

${WHITE}CONFIGURATION FILES:${NC}
    Configuration files should be based on the template at:
    $CONFIG_DIR/runner-config.template

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config-file)
                CONFIG_FILE="$2"
                INTERACTIVE_MODE=false
                shift 2
                ;;
            --validate)
                VALIDATE_ONLY=true
                shift
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

# Prompt user for input with validation
prompt_input() {
    local prompt="$1"
    local variable="$2"
    local default="${3:-}"
    local validation_function="${4:-}"
    local value=""

    while true; do
        if [[ -n "$default" ]]; then
            log_prompt "$prompt [$default]: "
        else
            log_prompt "$prompt: "
        fi

        read -r value

        # Use default if no input provided
        if [[ -z "$value" && -n "$default" ]]; then
            value="$default"
        fi

        # Skip validation if no input and no default
        if [[ -z "$value" ]]; then
            if [[ -z "$default" ]]; then
                log_error "This field is required."
                continue
            fi
        fi

        # Run validation function if provided
        if [[ -n "$validation_function" ]]; then
            if ! $validation_function "$value"; then
                continue
            fi
        fi

        # Set the variable dynamically
        declare -g "$variable"="$value"
        break
    done
}

# Validation functions
validate_github_token() {
    local token="$1"

    if [[ ! "$token" =~ ^gh[ps]_[A-Za-z0-9_]{36,251}$ ]]; then
        log_error "Invalid GitHub token format. Tokens should start with 'ghp_' or 'ghs_'"
        return 1
    fi

    # Test token validity by making API call
    log_info "Validating GitHub token..."
    if ! curl -s -f -H "Authorization: token $token" https://api.github.com/user >/dev/null; then
        log_error "GitHub token validation failed. Please check your token."
        return 1
    fi

    log_success "GitHub token validated successfully"
    return 0
}

validate_repository() {
    local repo="$1"

    if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid repository format. Use 'owner/repository'"
        return 1
    fi

    # Test repository accessibility
    log_info "Checking repository accessibility..."
    if ! curl -s -f -H "Authorization: token ${GITHUB_TOKEN}" \
         "https://api.github.com/repos/$repo" >/dev/null; then
        log_error "Repository not accessible. Check the name and token permissions."
        return 1
    fi

    log_success "Repository validated successfully"
    return 0
}

validate_runner_name() {
    local name="$1"

    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Runner name can only contain letters, numbers, dots, hyphens, and underscores"
        return 1
    fi

    if [[ ${#name} -gt 64 ]]; then
        log_error "Runner name must be 64 characters or less"
        return 1
    fi

    return 0
}

validate_labels() {
    local labels="$1"

    # Split labels by comma and validate each
    IFS=',' read -ra LABEL_ARRAY <<< "$labels"
    for label in "${LABEL_ARRAY[@]}"; do
        # Trim whitespace
        label=$(echo "$label" | xargs)

        if [[ ! "$label" =~ ^[a-zA-Z0-9._-]+$ ]]; then
            log_error "Invalid label '$label'. Labels can only contain letters, numbers, dots, hyphens, and underscores"
            return 1
        fi
    done

    return 0
}

# Interactive configuration prompts
interactive_configuration() {
    log_header ""
    log_header "🚀 GitHub Actions Runner Configuration"
    log_header "======================================"
    echo ""

    log_info "This script will help you configure a GitHub Actions self-hosted runner."
    log_info "You'll need a GitHub personal access token with repo permissions."
    echo ""

    # GitHub Token
    log_header "📝 GitHub Authentication"
    echo ""
    log_info "Generate a token at: https://github.com/settings/tokens"
    log_info "Required permissions: repo, workflow"
    echo ""
    prompt_input "GitHub Personal Access Token" GITHUB_TOKEN "" validate_github_token

    # Repository
    echo ""
    log_header "📁 Repository Configuration"
    echo ""
    prompt_input "Repository (owner/name)" GITHUB_REPOSITORY "" validate_repository

    # Runner Name
    echo ""
    log_header "🏷️  Runner Identification"
    echo ""
    local default_name="runner-$(hostname)-$(date +%s)"
    prompt_input "Runner Name" RUNNER_NAME "$default_name" validate_runner_name

    # Runner Labels
    echo ""
    log_info "Runner labels help GitHub Actions workflows target specific runners."
    log_info "Examples: 'self-hosted,Linux,X64' or 'self-hosted,macOS,ARM64,local'"
    echo ""

    # Detect default labels
    local os_label=""
    local arch_label=""

    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_label="Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_label="macOS"
    fi

    case $(uname -m) in
        x86_64) arch_label="X64" ;;
        arm64|aarch64) arch_label="ARM64" ;;
        armv7l) arch_label="ARM" ;;
    esac

    local default_labels="self-hosted"
    if [[ -n "$os_label" ]]; then
        default_labels="$default_labels,$os_label"
    fi
    if [[ -n "$arch_label" ]]; then
        default_labels="$default_labels,$arch_label"
    fi

    prompt_input "Runner Labels (comma-separated)" RUNNER_LABELS "$default_labels" validate_labels

    # Installation Method
    echo ""
    log_header "⚙️  Installation Configuration"
    echo ""
    log_info "Installation methods:"
    log_info "  - native: Direct installation on the system"
    log_info "  - docker: Container-based installation"
    log_info "  - systemd: Service-based installation (Linux only)"
    echo ""

    local default_method="native"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        default_method="systemd"
    fi

    prompt_input "Installation Method" INSTALLATION_METHOD "$default_method"

    # Work Directory
    echo ""
    local default_work_dir="/home/github-runner/runners/${RUNNER_NAME}/_work"
    prompt_input "Work Directory" RUNNER_WORK_FOLDER "$default_work_dir"

    # Advanced Options
    echo ""
    log_header "🔧 Advanced Options"
    echo ""

    prompt_input "Enable Auto-Start Service" AUTO_START_SERVICE "true"
    prompt_input "CPU Limit (percentage)" CPU_LIMIT "200"
    prompt_input "Memory Limit (MB)" MEMORY_LIMIT "2048"
    prompt_input "Log Level" LOG_LEVEL "info"

    echo ""
    log_success "Configuration completed!"
}

# Generate configuration file
generate_config_file() {
    local output_file="$1"

    log_info "Generating configuration file: $output_file"

    cat > "$output_file" << EOF
# GitHub Self-Hosted Runner Configuration
# Generated on $(date)

# Required Configuration
GITHUB_TOKEN=$GITHUB_TOKEN
GITHUB_REPOSITORY=$GITHUB_REPOSITORY
RUNNER_NAME=$RUNNER_NAME

# Runner Configuration
RUNNER_LABELS=$RUNNER_LABELS
INSTALLATION_METHOD=$INSTALLATION_METHOD
RUNNER_WORK_FOLDER=$RUNNER_WORK_FOLDER

# Service Configuration
AUTO_START_SERVICE=${AUTO_START_SERVICE:-true}
SERVICE_USER=github-runner

# Performance Configuration
CPU_LIMIT=${CPU_LIMIT:-200}
MEMORY_LIMIT=${MEMORY_LIMIT:-2048}

# Logging Configuration
LOG_LEVEL=${LOG_LEVEL:-info}
LOG_OUTPUT=journal

# Security Configuration
NON_ROOT_USER=true
CONFIGURE_FIREWALL=true

# Update Configuration
AUTO_UPDATE=true
UPDATE_CHECK_INTERVAL=24

# Monitoring Configuration
HEALTH_CHECK_ENABLED=true
HEALTH_CHECK_INTERVAL=60

# Configuration Metadata
CONFIG_GENERATED=$(date -Iseconds)
CONFIG_VERSION=1.0.0
CONFIG_VALIDATED=true
EOF

    log_success "Configuration saved to: $output_file"
}

# Load configuration from file
load_config_file() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi

    log_info "Loading configuration from: $config_file"

    # Source the configuration file
    # shellcheck source=/dev/null
    source "$config_file"

    # Validate required fields
    local required_vars=("GITHUB_TOKEN" "GITHUB_REPOSITORY" "RUNNER_NAME")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required configuration variable missing: $var"
            exit 1
        fi
    done

    log_success "Configuration loaded successfully"
}

# Display configuration summary
show_config_summary() {
    log_header ""
    log_header "📋 Configuration Summary"
    log_header "========================"
    echo ""

    echo "GitHub Token: ${GITHUB_TOKEN:0:10}..."
    echo "Repository: $GITHUB_REPOSITORY"
    echo "Runner Name: $RUNNER_NAME"
    echo "Labels: $RUNNER_LABELS"
    echo "Installation: $INSTALLATION_METHOD"
    echo "Work Directory: ${RUNNER_WORK_FOLDER:-default}"
    echo "Auto-Start: ${AUTO_START_SERVICE:-true}"
    echo ""
}

# Apply configuration (call setup script)
apply_configuration() {
    log_info "Applying runner configuration..."

    local setup_script="$PROJECT_ROOT/setup.sh"

    if [[ ! -f "$setup_script" ]]; then
        log_error "Setup script not found: $setup_script"
        exit 1
    fi

    local setup_args=(
        --token "$GITHUB_TOKEN"
        --repo "$GITHUB_REPOSITORY"
        --name "$RUNNER_NAME"
    )

    if [[ "$INSTALLATION_METHOD" == "docker" ]]; then
        setup_args+=(--docker)
    fi

    # Execute setup script
    log_info "Running setup script with configuration..."
    if "$setup_script" "${setup_args[@]}"; then
        log_success "Runner configuration applied successfully!"
    else
        log_error "Failed to apply runner configuration"
        exit 1
    fi
}

# Prompt for confirmation
confirm_action() {
    local message="$1"
    local response=""

    while true; do
        log_prompt "$message (y/N): "
        read -r response

        case $response in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo]|"")
                return 1
                ;;
            *)
                log_error "Please answer yes (y) or no (n)"
                ;;
        esac
    done
}

# Main configuration flow
main() {
    log_info "GitHub Actions Runner Configuration Tool"
    log_info "========================================"

    parse_args "$@"

    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        # Interactive mode
        interactive_configuration
        show_config_summary

        # Ask to save configuration
        if confirm_action "Save configuration to file?"; then
            local config_file="runner-$(date +%Y%m%d-%H%M%S).conf"
            generate_config_file "$config_file"
            echo ""
        fi

        # Ask to apply configuration
        if confirm_action "Apply this configuration now?"; then
            apply_configuration
        else
            log_info "Configuration saved but not applied."
            log_info "To apply later, run: $0 --config-file $config_file"
        fi
    else
        # File-based configuration
        load_config_file "$CONFIG_FILE"
        show_config_summary

        if [[ "${VALIDATE_ONLY:-false}" == "true" ]]; then
            log_success "Configuration validation completed"
            exit 0
        fi

        if confirm_action "Apply this configuration?"; then
            apply_configuration
        else
            log_info "Configuration not applied"
        fi
    fi

    echo ""
    log_success "Configuration process completed!"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi