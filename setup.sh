#!/bin/bash

# GitHub Self-Hosted Runner Universal Installer
#
# This script automatically sets up GitHub Actions self-hosted runners
# on VPS, dedicated servers, or local development machines.
#
# Usage:
#   ./setup.sh --token YOUR_GITHUB_TOKEN --repo owner/repository-name
#   ./setup.sh --token TOKEN --repo owner/repo --name custom-runner-name
#   ./setup.sh --docker --token TOKEN --repo owner/repo
#
# Author: Gabel (Booplex.com)
# Website: https://booplex.com
# Built with: Bash, hope, and a concerning amount of Stack Overflow
#
# Fun fact: This script was pair-programmed with AI.
# The AI wrote the good parts. I wrote the bugs.
# License: MIT

set -euo pipefail

# Script configuration
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="GitHub Self-Hosted Runner Setup"
readonly GITHUB_RUNNER_VERSION="2.319.1"  # Latest stable version as of 2025-09-16

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Global variables
GITHUB_TOKEN=""
REPOSITORY=""
RUNNER_NAME=""
INSTALLATION_METHOD="native"
ENVIRONMENT_TYPE=""
DRY_RUN=false
FORCE_INSTALL=false
VERBOSE=false

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

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

log_header() {
    echo -e "${WHITE}$1${NC}"
}

# Display help information
show_help() {
    cat << EOF
${WHITE}${SCRIPT_NAME} v${SCRIPT_VERSION}${NC}

Universal installer for GitHub Actions self-hosted runners.
Works on VPS, dedicated servers, and local development machines.

${WHITE}USAGE:${NC}
    $0                                    # Interactive setup wizard (recommended)
    $0 --token TOKEN --repo OWNER/REPO   # Direct configuration
    $0 --interactive                     # Force interactive mode

${WHITE}INTERACTIVE MODE:${NC}
    Run without arguments to enter the setup wizard. The wizard will:
    • Detect GitHub CLI authentication or prompt for token
    • Show your repositories and help with selection
    • Guide through installation method choice
    • Offer post-setup testing and workflow migration

${WHITE}DIRECT MODE OPTIONS:${NC}
    --token TOKEN       GitHub personal access token with repo permissions
    --repo OWNER/REPO   Target GitHub repository (e.g., myuser/myproject)
    --name NAME         Custom runner name (default: auto-generated)
    --docker           Use Docker installation method
    --native           Use native installation method (default)
    --interactive      Force interactive mode
    --dry-run          Show what would be done without making changes
    --force            Force installation even if runner exists
    --verbose          Enable verbose logging
    --help             Show this help message

${WHITE}EXAMPLES:${NC}
    # Interactive setup (easiest)
    $0

    # Quick direct setup
    $0 --token ghp_xxxx --repo myuser/myproject

    # Docker-based installation
    $0 --token ghp_xxxx --repo myuser/myproject --docker

    # Custom runner name
    $0 --token ghp_xxxx --repo myuser/myproject --name production-runner

    # Multiple runners for same repo
    $0 --token ghp_xxxx --repo myuser/myproject --name runner-1
    $0 --token ghp_xxxx --repo myuser/myproject --name runner-2

    # Test what would be installed
    $0 --token ghp_xxxx --repo myuser/myproject --dry-run

${WHITE}SUPPORTED PLATFORMS:${NC}
    - Ubuntu 18.04+ (recommended for VPS)
    - Debian 10+ (recommended for VPS)
    - CentOS 7+ / Rocky Linux 8+
    - macOS 10.15+ (local development)
    - Docker (any platform with Docker support)

${WHITE}PREREQUISITES:${NC}
    - sudo access (for system setup)
    - curl or wget
    - tar and gzip
    - Docker (if using --docker flag)

For more information, visit: https://github.com/actions/runner
EOF
}

# Interactive setup wizard
interactive_setup_wizard() {
    log_header "🧙‍♂️ GitHub Self-Hosted Runner Setup Wizard"
    echo
    echo "Welcome! Let's set up your GitHub Actions self-hosted runner."
    echo "This wizard will guide you through the configuration process."
    echo

    # Step 1: GitHub Token Detection/Collection
    log_info "Step 1: GitHub Authentication"
    echo

    # Try to detect existing GitHub CLI token
    if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
        local gh_user=$(gh api user --jq '.login' 2>/dev/null)
        if [[ -n "$gh_user" ]]; then
            echo "✓ Found GitHub CLI authentication for user: $gh_user"
            echo -n "Use GitHub CLI token? [Y/n]: "
            read -r use_gh_cli
            if [[ "$use_gh_cli" != "n" && "$use_gh_cli" != "N" ]]; then
                GITHUB_TOKEN=$(gh auth token)
                log_success "Using GitHub CLI token"
            fi
        fi
    fi

    # If no token found, prompt for manual entry
    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "GitHub personal access token is required."
        echo "Create one at: https://github.com/settings/tokens/new?scopes=repo&description=Self-hosted%20runner"
        echo
        while [[ -z "$GITHUB_TOKEN" ]]; do
            echo -n "Enter your GitHub token: "
            read -r -s token_input
            echo
            if [[ -n "$token_input" ]]; then
                GITHUB_TOKEN="$token_input"
                break
            else
                log_error "Token cannot be empty. Please try again."
            fi
        done
    fi

    # Step 2: Repository Selection
    echo
    log_info "Step 2: Repository Selection"
    echo

    # Try to suggest repositories if GitHub CLI is available
    if command -v gh &> /dev/null && [[ -n "$GITHUB_TOKEN" ]]; then
        echo "Fetching your repositories..."
        local repos
        repos=$(gh api user/repos --paginate --jq '.[].full_name' 2>/dev/null | head -10)
        if [[ -n "$repos" ]]; then
            echo "Your recent repositories:"
            echo "$repos" | nl -w2 -s ". "
            echo
        fi
    fi

    while [[ -z "$REPOSITORY" ]]; do
        echo -n "Enter repository (owner/repo format): "
        read -r repo_input
        if [[ "$repo_input" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
            REPOSITORY="$repo_input"
            break
        else
            log_error "Invalid format. Please use: owner/repository"
        fi
    done

    # Step 3: Installation Method
    echo
    log_info "Step 3: Installation Method"
    echo
    echo "Choose installation method:"
    echo "1. Native (installs directly on this system)"
    echo "2. Docker (containerized, isolated)"
    echo
    echo -n "Select method [1-2] (default: 1): "
    read -r method_choice

    case "$method_choice" in
        2|"docker"|"Docker")
            INSTALLATION_METHOD="docker"
            log_info "Selected: Docker installation"
            ;;
        *)
            INSTALLATION_METHOD="native"
            log_info "Selected: Native installation"
            ;;
    esac

    # Step 4: Runner Name
    echo
    log_info "Step 4: Runner Name"
    echo
    generate_runner_name  # This will set a default name
    echo "Suggested runner name: $RUNNER_NAME"
    echo -n "Press Enter to use suggested name, or type a custom name: "
    read -r custom_name
    if [[ -n "$custom_name" ]]; then
        RUNNER_NAME="$custom_name"
    fi

    # Step 5: Configuration Summary
    echo
    log_header "📋 Configuration Summary"
    echo
    echo "Repository: $REPOSITORY"
    echo "Runner Name: $RUNNER_NAME"
    echo "Installation: $INSTALLATION_METHOD"
    echo "Environment: $ENVIRONMENT_TYPE"
    echo
    echo -n "Proceed with installation? [Y/n]: "
    read -r proceed
    if [[ "$proceed" == "n" || "$proceed" == "N" ]]; then
        log_info "Installation cancelled by user"
        exit 0
    fi

    log_success "Configuration completed! Starting installation..."
    echo
}

# Parse command line arguments
parse_arguments() {
    # If no arguments provided, enter interactive mode
    if [[ $# -eq 0 ]]; then
        return 0  # Will trigger interactive mode in main()
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --token)
                GITHUB_TOKEN="$2"
                shift 2
                ;;
            --repo)
                REPOSITORY="$2"
                shift 2
                ;;
            --name)
                RUNNER_NAME="$2"
                shift 2
                ;;
            --docker)
                INSTALLATION_METHOD="docker"
                shift
                ;;
            --native)
                INSTALLATION_METHOD="native"
                shift
                ;;
            --interactive|-i)
                # Force interactive mode even with arguments
                GITHUB_TOKEN=""
                REPOSITORY=""
                RUNNER_NAME=""
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                log_info "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Validate required arguments
validate_arguments() {
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "GitHub token is required. Use --token YOUR_TOKEN"
        exit 1
    fi

    if [[ -z "$REPOSITORY" ]]; then
        log_error "Repository is required. Use --repo owner/repository"
        exit 1
    fi

    # Validate repository format
    if [[ ! "$REPOSITORY" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
        log_error "Invalid repository format. Use: owner/repository"
        exit 1
    fi

    # Validate GitHub token format (basic check)
    if [[ ! "$GITHUB_TOKEN" =~ ^(ghp_|gho_|ghu_|ghs_|ghr_) ]]; then
        log_warning "GitHub token format looks unusual. Make sure it's a valid personal access token."
    fi
}

# Detect the current environment
detect_environment() {
    log_debug "Detecting environment type..."

    # Check if running in Docker
    if [[ -f /.dockerenv ]]; then
        ENVIRONMENT_TYPE="docker"
        return
    fi

    # Check for VPS/cloud indicators
    if [[ -f "/etc/cloud/cloud.cfg" ]] || [[ -n "${VPS_MODE:-}" ]] || [[ -f "/sys/hypervisor/uuid" ]]; then
        ENVIRONMENT_TYPE="vps"
        return
    fi

    # Detect OS type
    if [[ "$OSTYPE" == "darwin"* ]]; then
        ENVIRONMENT_TYPE="macos_local"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        ENVIRONMENT_TYPE="linux_local"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        ENVIRONMENT_TYPE="windows_local"
    else
        ENVIRONMENT_TYPE="unknown"
        log_warning "Unknown environment detected: $OSTYPE"
    fi

    log_debug "Environment detected: $ENVIRONMENT_TYPE"
}

# Check system prerequisites
check_prerequisites() {
    log_info "Checking system prerequisites..."

    local missing_tools=()

    # Check for required commands
    local required_commands=("curl" "tar" "sudo")

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_tools+=("$cmd")
        fi
    done

    # Docker-specific checks
    if [[ "$INSTALLATION_METHOD" == "docker" ]]; then
        if ! command -v docker >/dev/null 2>&1; then
            missing_tools+=("docker")
        elif ! docker info >/dev/null 2>&1; then
            log_error "Docker is installed but not running or accessible"
            exit 1
        fi
    fi

    # Report missing tools
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again"
        exit 1
    fi

    # Check if we have sufficient permissions
    if [[ "$INSTALLATION_METHOD" == "native" ]] && ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo access for native installation"
        exit 1
    fi

    log_success "All prerequisites met"
}

# Generate runner name if not provided
generate_runner_name() {
    if [[ -z "$RUNNER_NAME" ]]; then
        local hostname_part
        hostname_part=$(hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
        local environment_suffix

        case "$ENVIRONMENT_TYPE" in
            vps)
                environment_suffix="vps"
                ;;
            macos_local|linux_local|windows_local)
                environment_suffix="local"
                ;;
            docker)
                environment_suffix="docker"
                ;;
            *)
                environment_suffix="runner"
                ;;
        esac

        RUNNER_NAME="$hostname_part-$environment_suffix-$(date +%s | tail -c 4)"
        log_info "Generated runner name: $RUNNER_NAME"
    fi
}

# Create dedicated runner user for security
create_runner_user() {
    if [[ "$INSTALLATION_METHOD" == "docker" ]]; then
        return 0  # Docker handles user isolation
    fi

    log_info "Creating dedicated runner user..."

    # Check if user already exists
    if id "github-runner" >/dev/null 2>&1; then
        log_info "github-runner user already exists"
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would create github-runner user"
        else
            sudo useradd -m -s /bin/bash -c "GitHub Actions Runner" github-runner
            log_success "Created github-runner user"
        fi
    fi

    # Add to docker group if Docker is available and needed
    if command -v docker >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would add github-runner to docker group"
        else
            sudo usermod -aG docker github-runner
            log_info "Added github-runner to docker group"
        fi
    fi

    # Create runner directory
    local runner_home="/home/github-runner"
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create runner directory: $runner_home"
    else
        sudo -u github-runner mkdir -p "$runner_home/runners"
        sudo -u github-runner chmod 755 "$runner_home/runners"
        log_success "Created runner directory"
    fi
}

# Download GitHub Actions runner
download_runner() {
    log_info "Downloading GitHub Actions runner v$GITHUB_RUNNER_VERSION..."

    local runner_dir="/home/github-runner/runners/$RUNNER_NAME"
    local download_url="https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-linux-x64-${GITHUB_RUNNER_VERSION}.tar.gz"

    if [[ "$ENVIRONMENT_TYPE" == "macos_local" ]]; then
        download_url="https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-osx-x64-${GITHUB_RUNNER_VERSION}.tar.gz"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would download runner from: $download_url"
        log_info "[DRY RUN] Would extract to: $runner_dir"
        return 0
    fi

    # Create runner directory
    sudo -u github-runner mkdir -p "$runner_dir"
    cd "$runner_dir"

    # Download and extract runner
    sudo -u github-runner curl -o actions-runner.tar.gz -L "$download_url"
    sudo -u github-runner tar xzf actions-runner.tar.gz
    sudo -u github-runner rm actions-runner.tar.gz

    # Install dependencies
    if [[ "$ENVIRONMENT_TYPE" != "macos_local" ]]; then
        sudo "$runner_dir/bin/installdependencies.sh"
    fi

    log_success "GitHub Actions runner downloaded and extracted"
}

# Configure the runner
configure_runner() {
    log_info "Configuring runner for repository: $REPOSITORY"

    local runner_dir="/home/github-runner/runners/$RUNNER_NAME"
    local github_url="https://github.com/$REPOSITORY"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would configure runner with:"
        log_info "  - Repository: $REPOSITORY"
        log_info "  - Runner name: $RUNNER_NAME"
        log_info "  - Labels: self-hosted,linux,x64,$ENVIRONMENT_TYPE"
        return 0
    fi

    # Configure the runner
    cd "$runner_dir"
    sudo -u github-runner ./config.sh \
        --url "$github_url" \
        --token "$GITHUB_TOKEN" \
        --name "$RUNNER_NAME" \
        --labels "self-hosted,linux,x64,$ENVIRONMENT_TYPE" \
        --work "_work" \
        --unattended

    log_success "Runner configured successfully"
}

# Set up systemd service for automatic startup
setup_systemd_service() {
    if [[ "$INSTALLATION_METHOD" == "docker" ]]; then
        return 0  # Docker handles service management
    fi

    log_info "Setting up systemd service..."

    local service_name="github-runner-$RUNNER_NAME"
    local service_file="/etc/systemd/system/$service_name.service"
    local runner_dir="/home/github-runner/runners/$RUNNER_NAME"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create systemd service: $service_name"
        return 0
    fi

    # Create systemd service file
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=GitHub Actions Runner ($RUNNER_NAME)
After=network.target
Wants=network.target

[Service]
Type=simple
User=github-runner
WorkingDirectory=$runner_dir
ExecStart=$runner_dir/run.sh
Restart=on-failure
RestartSec=5
KillMode=process
KillSignal=SIGINT
TimeoutStopSec=4m

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    sudo systemctl start "$service_name"

    log_success "Systemd service created and started"
}

# Docker-based installation
install_docker_runner() {
    log_info "Setting up Docker-based runner..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create Docker container for runner"
        return 0
    fi

    # Create docker-compose.yml for the runner
    local compose_dir="./docker-runners/$RUNNER_NAME"
    mkdir -p "$compose_dir"

    cat > "$compose_dir/docker-compose.yml" << EOF
version: '3.8'

services:
  github-runner:
    build:
      context: ../../docker
      dockerfile: Dockerfile
    container_name: github-runner-$RUNNER_NAME
    environment:
      - GITHUB_REPOSITORY=$REPOSITORY
      - GITHUB_TOKEN=$GITHUB_TOKEN
      - RUNNER_NAME=$RUNNER_NAME
      - RUNNER_LABELS=self-hosted,linux,x64,docker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # For Docker-in-Docker
      - runner_work:/home/github-runner/_work
    restart: unless-stopped
    working_dir: /home/github-runner

volumes:
  runner_work:
EOF

    # Start the Docker container
    cd "$compose_dir"
    docker-compose up -d

    log_success "Docker-based runner started"
}

# Verify the installation
verify_installation() {
    log_info "Verifying runner installation..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would verify runner is connected to GitHub"
        return 0
    fi

    local max_attempts=30
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Verification attempt $attempt/$max_attempts"

        if [[ "$INSTALLATION_METHOD" == "docker" ]]; then
            # Check Docker container status
            if docker-compose ps | grep -q "Up"; then
                log_success "Docker runner is running"
                break
            fi
        else
            # Check systemd service status
            local service_name="github-runner-$RUNNER_NAME"
            if systemctl is-active --quiet "$service_name"; then
                log_success "Runner service is active"
                break
            fi
        fi

        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Runner verification failed after $max_attempts attempts"
            return 1
        fi

        sleep 2
        ((attempt++))
    done

    log_success "Runner installation verified"
}

# Offer post-setup testing
offer_testing() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    echo
    log_header "🧪 Test Your Runner Setup"
    echo
    echo "Would you like to test your runner setup to ensure it's working properly?"
    echo "This will verify the runner can connect to GitHub and execute workflows."
    echo
    echo -n "Run setup validation? [Y/n]: "
    read -r run_tests

    if [[ "$run_tests" != "n" && "$run_tests" != "N" ]]; then
        log_info "Running validation tests..."
        echo

        # Check if test.sh exists and run appropriate test
        if [[ -f "./test.sh" ]]; then
            # Use existing test script
            if ./test.sh --validate --token "$GITHUB_TOKEN" --repo "$REPOSITORY"; then
                log_success "✅ Runner validation completed successfully!"
                return 0
            else
                log_warning "❌ Some tests failed. Please check the output above."
                return 1
            fi
        else
            # Fallback: basic connection test
            log_info "Running basic connectivity test..."
            if curl -s "https://api.github.com/repos/$REPOSITORY" >/dev/null 2>&1; then
                log_success "✅ GitHub API connectivity confirmed"
                return 0
            else
                log_warning "❌ Could not connect to GitHub API for repository"
                return 1
            fi
        fi
    else
        log_info "Skipping tests. You can run them later with: ./test.sh --validate"
        return 0
    fi
}

# Offer workflow migration
offer_workflow_migration() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    echo
    log_header "🔄 Migrate Existing Workflows"
    echo

    # Check if we're in a git repository with workflows
    local workflows_dir="./.github/workflows"
    if [[ ! -d "$workflows_dir" ]]; then
        # Try common patterns for finding repository root
        for dir in "../.github/workflows" "../../.github/workflows"; do
            if [[ -d "$dir" ]]; then
                workflows_dir="$dir"
                break
            fi
        done
    fi

    if [[ ! -d "$workflows_dir" ]]; then
        log_info "No .github/workflows directory found in current location."
        echo "If you have existing workflows, you can migrate them later with:"
        echo "  ./scripts/workflow-helper.sh migrate /path/to/your/repo"
        return 0
    fi

    # Count GitHub-hosted workflows
    local github_hosted_count=0
    local total_workflows=0

    if [[ -f "./scripts/workflow-helper.sh" ]]; then
        # Use the workflow helper to analyze
        log_info "Scanning for existing workflows..."
        local analysis_output
        analysis_output=$(./scripts/workflow-helper.sh analyze "$(dirname "$workflows_dir")" 2>/dev/null || echo "")

        # Extract counts from analysis (simple grep approach)
        github_hosted_count=$(echo "$analysis_output" | grep "GitHub-hosted runners:" | grep -o '[0-9]\+' || echo "0")
        total_workflows=$(echo "$analysis_output" | grep "Total workflows:" | grep -o '[0-9]\+' || echo "0")
    else
        # Fallback: count workflows manually
        while IFS= read -r workflow_file; do
            if [[ -n "$workflow_file" && -f "$workflow_file" ]]; then
                ((total_workflows++))
                if grep -q "runs-on:.*ubuntu-latest\|runs-on:.*windows-latest\|runs-on:.*macos-latest" "$workflow_file" 2>/dev/null; then
                    ((github_hosted_count++))
                fi
            fi
        done <<< "$(find "$workflows_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null || echo "")"
    fi

    if [[ $total_workflows -eq 0 ]]; then
        log_info "No workflows found to migrate."
        return 0
    fi

    echo "Found $total_workflows workflow(s) in $(dirname "$workflows_dir")"
    if [[ $github_hosted_count -gt 0 ]]; then
        echo "→ $github_hosted_count workflow(s) are using GitHub-hosted runners"
        echo "→ These can be migrated to use your self-hosted runner"
        echo
        echo -n "Migrate workflows to use self-hosted runners? [y/N]: "
        read -r migrate_workflows

        if [[ "$migrate_workflows" == "y" || "$migrate_workflows" == "Y" ]]; then
            if [[ -f "./scripts/workflow-helper.sh" ]]; then
                log_info "Starting workflow migration..."
                ./scripts/workflow-helper.sh migrate "$(dirname "$workflows_dir")"
                log_success "Workflow migration completed!"
            else
                log_error "Workflow helper script not found. Please run manually:"
                echo "  ./scripts/workflow-helper.sh migrate $(dirname "$workflows_dir")"
            fi
        else
            log_info "Skipping workflow migration. You can migrate later with:"
            echo "  ./scripts/workflow-helper.sh migrate $(dirname "$workflows_dir")"
        fi
    else
        log_success "All workflows are already using self-hosted or custom runners!"
    fi
}

# Display final status and next steps
display_status() {
    echo
    log_success "✨ GitHub Self-Hosted Runner Setup Complete!"
    echo
    echo -e "${WHITE}Runner Details:${NC}"
    echo -e "  Name: ${CYAN}$RUNNER_NAME${NC}"
    echo -e "  Repository: ${CYAN}$REPOSITORY${NC}"
    echo -e "  Environment: ${CYAN}$ENVIRONMENT_TYPE${NC}"
    echo -e "  Installation Method: ${CYAN}$INSTALLATION_METHOD${NC}"
    echo

    if [[ "$DRY_RUN" != "true" ]]; then
        echo -e "${WHITE}Next Steps:${NC}"
        echo "  1. Check runner status in your GitHub repository:"
        echo "     https://github.com/$REPOSITORY/settings/actions/runners"
        echo
        echo "  2. Your workflows will now run on this runner"
        echo "     instead of using GitHub Action minutes!"
        echo

        if [[ "$INSTALLATION_METHOD" == "native" ]]; then
            echo -e "${WHITE}Management Commands:${NC}"
            echo "  Start:  sudo systemctl start github-runner-$RUNNER_NAME"
            echo "  Stop:   sudo systemctl stop github-runner-$RUNNER_NAME"
            echo "  Status: sudo systemctl status github-runner-$RUNNER_NAME"
            echo "  Logs:   sudo journalctl -u github-runner-$RUNNER_NAME -f"
        else
            echo -e "${WHITE}Management Commands:${NC}"
            echo "  Stop:   docker-compose down"
            echo "  Start:  docker-compose up -d"
            echo "  Logs:   docker-compose logs -f"
        fi

        # Offer post-setup testing
        offer_testing

        # Offer workflow migration
        offer_workflow_migration
    fi

    echo
    log_info "To set up additional runners, run this script again with --name different-runner-name"
}

# Main installation orchestrator
main() {
    # Print banner
    echo -e "${WHITE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                 GitHub Self-Hosted Runner                   ║"
    echo "║                   Universal Installer                       ║"
    echo "║                      Version $SCRIPT_VERSION                       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Parse and validate arguments
    parse_arguments "$@"

    # Check if we need to run interactive mode
    if [[ -z "$GITHUB_TOKEN" && -z "$REPOSITORY" ]]; then
        # Run interactive setup wizard
        detect_environment  # Need this before the wizard
        interactive_setup_wizard
    fi

    validate_arguments

    # Environment detection and setup (if not already done)
    if [[ -z "$ENVIRONMENT_TYPE" ]]; then
        detect_environment
    fi
    if [[ -z "$RUNNER_NAME" ]]; then
        generate_runner_name
    fi
    check_prerequisites

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN MODE - No actual changes will be made"
    fi

    log_info "Starting installation process..."
    log_info "Environment: $ENVIRONMENT_TYPE"
    log_info "Installation method: $INSTALLATION_METHOD"
    log_info "Runner name: $RUNNER_NAME"

    # Installation steps
    if [[ "$INSTALLATION_METHOD" == "docker" ]]; then
        install_docker_runner
    else
        create_runner_user
        download_runner
        configure_runner
        setup_systemd_service
    fi

    # Verification and completion
    verify_installation
    display_status

    log_success "GitHub Self-Hosted Runner setup completed successfully!"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi