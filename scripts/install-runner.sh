#!/bin/bash

# GitHub Actions Self-Hosted Runner - Core Installation Script
#
# This script handles the core installation of GitHub Actions runner binaries,
# dependency management, and system configuration. It's designed to work across
# different operating systems and environments.
#
# Usage:
#   ./install-runner.sh --token TOKEN --repo owner/repo [OPTIONS]
#   ./install-runner.sh --help
#
# Author: Gabel (Booplex.com)
# Website: https://booplex.com
# Built with: Bash, caffeine, and mild panic about cross-platform compatibility
#
# Warning: May contain traces of AI assistance and human stubbornness

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly DEFAULT_RUNNER_VERSION="2.319.1"
readonly RUNNER_INSTALL_DIR="/home/github-runner"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m' # No Color

# Global variables
GITHUB_TOKEN=""
REPOSITORY=""
RUNNER_NAME=""
RUNNER_VERSION="$DEFAULT_RUNNER_VERSION"
INSTALL_DIR="$RUNNER_INSTALL_DIR"
VERBOSE=false
DRY_RUN=false

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

# Show help information
show_help() {
    cat << EOF
GitHub Actions Self-Hosted Runner - Core Installation Script

USAGE:
    $0 --token TOKEN --repo OWNER/REPOSITORY [OPTIONS]

REQUIRED OPTIONS:
    --token TOKEN       GitHub personal access token with repo permissions
    --repo OWNER/REPO   Target GitHub repository (e.g., myuser/myproject)

OPTIONAL OPTIONS:
    --name NAME         Custom runner name (default: auto-generated)
    --version VERSION   Runner version to install (default: $DEFAULT_RUNNER_VERSION)
    --install-dir DIR   Installation directory (default: $RUNNER_INSTALL_DIR)
    --dry-run          Show what would be done without making changes
    --verbose          Enable verbose logging
    --help             Show this help message

EXAMPLES:
    # Basic installation
    $0 --token ghp_xxxx --repo myuser/myproject

    # Custom runner name and location
    $0 --token ghp_xxxx --repo myuser/myproject --name build-server --install-dir /opt/runner

    # Install specific version
    $0 --token ghp_xxxx --repo myuser/myproject --version 2.318.0

EOF
}

# Parse command line arguments
parse_args() {
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
            --version)
                RUNNER_VERSION="$2"
                shift 2
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
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

    # Validate required parameters
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "GitHub token is required. Use --token option."
        exit 1
    fi

    if [[ -z "$REPOSITORY" ]]; then
        log_error "Repository is required. Use --repo option."
        exit 1
    fi

    # Generate runner name if not provided
    if [[ -z "$RUNNER_NAME" ]]; then
        RUNNER_NAME="runner-$(hostname)-$(date +%s)"
        log_debug "Generated runner name: $RUNNER_NAME"
    fi
}

# Detect operating system and architecture
detect_system() {
    log_debug "Detecting system information..."

    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="osx"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        OS="win"
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi

    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="x64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="arm"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    log_debug "Detected system: $OS-$ARCH"
}

# Check system prerequisites
check_prerequisites() {
    log_info "Checking system prerequisites..."

    local missing_deps=()

    # Check for required commands
    local required_commands=("curl" "tar" "sudo" "unzip")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # OS-specific checks
    case $OS in
        linux)
            # Check for systemd (for service management)
            if ! command -v systemctl &> /dev/null; then
                log_warning "systemctl not found - service management may not work"
            fi

            # Check for package manager
            if command -v apt-get &> /dev/null; then
                PACKAGE_MANAGER="apt"
            elif command -v yum &> /dev/null; then
                PACKAGE_MANAGER="yum"
            elif command -v dnf &> /dev/null; then
                PACKAGE_MANAGER="dnf"
            else
                log_warning "No supported package manager found"
            fi
            ;;
        osx)
            # Check for Homebrew
            if ! command -v brew &> /dev/null; then
                log_warning "Homebrew not found - some dependencies may need manual installation"
            fi
            ;;
    esac

    # Install missing dependencies automatically
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_warning "Missing required dependencies: ${missing_deps[*]}"
        log_info "Attempting to install missing dependencies..."

        case $OS in
            linux)
                if [[ -n "${PACKAGE_MANAGER:-}" ]]; then
                    case $PACKAGE_MANAGER in
                        apt)
                            sudo apt-get update -qq
                            sudo apt-get install -y "${missing_deps[@]}"
                            ;;
                        yum)
                            sudo yum install -y "${missing_deps[@]}"
                            ;;
                        dnf)
                            sudo dnf install -y "${missing_deps[@]}"
                            ;;
                    esac
                    log_success "Dependencies installed successfully"
                else
                    log_error "No package manager found. Please install missing dependencies manually: ${missing_deps[*]}"
                    exit 1
                fi
                ;;
            osx)
                if command -v brew &> /dev/null; then
                    brew install "${missing_deps[@]}" || true
                    log_success "Dependencies installed via Homebrew"
                else
                    log_error "Homebrew not found. Please install missing dependencies manually: ${missing_deps[*]}"
                    exit 1
                fi
                ;;
            *)
                log_error "Please install missing dependencies manually: ${missing_deps[*]}"
                exit 1
                ;;
        esac
    fi

    log_success "Prerequisites check passed"
}

# Create runner user and directories
create_runner_user() {
    log_info "Setting up runner user and directories..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create user 'github-runner' and directories"
        return 0
    fi

    # Create github-runner user if it doesn't exist
    if ! id "github-runner" &>/dev/null; then
        case $OS in
            linux)
                sudo useradd -m -s /bin/bash -c "GitHub Actions Runner" github-runner
                log_success "Created user 'github-runner'"
                ;;
            osx)
                # On macOS, we'll use the current user to avoid permission issues
                log_warning "On macOS, using current user instead of creating new user"
                RUNNER_USER=$(whoami)
                INSTALL_DIR="$HOME/github-runner"
                ;;
        esac
    else
        log_debug "User 'github-runner' already exists"
    fi

    # Create installation directory
    sudo mkdir -p "$INSTALL_DIR"

    # Set ownership and permissions
    case $OS in
        linux)
            sudo chown github-runner:github-runner "$INSTALL_DIR"
            sudo chmod 755 "$INSTALL_DIR"
            ;;
        osx)
            sudo chown "$(whoami):staff" "$INSTALL_DIR"
            sudo chmod 755 "$INSTALL_DIR"
            ;;
    esac

    log_success "Runner directories created"
}

# Download and install GitHub Actions runner
download_runner() {
    log_info "Downloading GitHub Actions runner v$RUNNER_VERSION..."

    local runner_package="actions-runner-${OS}-${ARCH}-${RUNNER_VERSION}.tar.gz"
    local download_url="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${runner_package}"
    # Use project temp directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(dirname "$script_dir")"
    local temp_dir="$project_root/.tmp/installs/github-runner-install-$$"
    mkdir -p "$temp_dir"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would download: $download_url"
        log_info "[DRY RUN] Would extract to: $INSTALL_DIR"
        return 0
    fi

    # Create temporary directory
    mkdir -p "$temp_dir"
    cd "$temp_dir"

    # Download runner package
    log_debug "Downloading from: $download_url"
    if ! curl -L -o "$runner_package" "$download_url"; then
        log_error "Failed to download runner package"
        exit 1
    fi

    # Verify download
    if [[ ! -f "$runner_package" ]]; then
        log_error "Downloaded package not found"
        exit 1
    fi

    # Extract to installation directory
    log_info "Extracting runner to $INSTALL_DIR..."
    case $OS in
        linux)
            sudo -u github-runner tar xzf "$runner_package" -C "$INSTALL_DIR"
            ;;
        osx)
            tar xzf "$runner_package" -C "$INSTALL_DIR"
            ;;
    esac

    # Set execute permissions
    case $OS in
        linux)
            sudo -u github-runner chmod +x "$INSTALL_DIR/run.sh"
            sudo -u github-runner chmod +x "$INSTALL_DIR/config.sh"
            ;;
        osx)
            chmod +x "$INSTALL_DIR/run.sh"
            chmod +x "$INSTALL_DIR/config.sh"
            ;;
    esac

    # Clean up
    rm -rf "$temp_dir"

    log_success "Runner binaries installed"
}

# Install runner dependencies
install_dependencies() {
    log_info "Installing runner dependencies..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would install runner dependencies"
        return 0
    fi

    # Run the dependency installer script
    case $OS in
        linux)
            if [[ -f "$INSTALL_DIR/bin/installdependencies.sh" ]]; then
                log_debug "Running dependency installer..."
                sudo "$INSTALL_DIR/bin/installdependencies.sh"
            else
                log_warning "Dependency installer script not found"
            fi
            ;;
        osx)
            log_debug "Skipping dependency installation on macOS (handled by runner)"
            ;;
    esac

    log_success "Dependencies installed"
}

# Configure runner registration
configure_runner() {
    log_info "Configuring runner registration..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would configure runner for repository: $REPOSITORY"
        return 0
    fi

    local config_script="$INSTALL_DIR/config.sh"
    local github_url="https://github.com/${REPOSITORY}"

    # Prepare configuration command
    local config_cmd="$config_script --url $github_url --token $GITHUB_TOKEN --name $RUNNER_NAME --unattended"

    log_debug "Running configuration command..."
    case $OS in
        linux)
            if ! sudo -u github-runner $config_cmd; then
                log_error "Failed to configure runner"
                exit 1
            fi
            ;;
        osx)
            if ! $config_cmd; then
                log_error "Failed to configure runner"
                exit 1
            fi
            ;;
    esac

    log_success "Runner configured successfully"
}

# Set up systemd service (Linux only)
setup_service() {
    if [[ "$OS" != "linux" ]]; then
        log_debug "Skipping service setup (not Linux)"
        return 0
    fi

    log_info "Setting up systemd service..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create systemd service for runner"
        return 0
    fi

    local service_file="/etc/systemd/system/github-runner-${RUNNER_NAME}.service"

    # Create service file
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=GitHub Actions Self-Hosted Runner ($RUNNER_NAME)
After=network.target

[Service]
Type=simple
User=github-runner
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/run.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable "github-runner-${RUNNER_NAME}.service"

    log_success "Service configured: github-runner-${RUNNER_NAME}"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    # Check if runner directory exists and has required files
    local required_files=("run.sh" "config.sh")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$INSTALL_DIR/$file" ]]; then
            log_error "Required file missing: $INSTALL_DIR/$file"
            exit 1
        fi
    done

    # Check if runner is configured
    if [[ ! -f "$INSTALL_DIR/.runner" ]]; then
        log_error "Runner configuration file missing: $INSTALL_DIR/.runner"
        exit 1
    fi

    log_success "Installation verification completed"
}

# Display installation summary
show_summary() {
    log_info "Installation Summary:"
    echo "  Runner Name: $RUNNER_NAME"
    echo "  Repository: $REPOSITORY"
    echo "  Install Directory: $INSTALL_DIR"
    echo "  Version: $RUNNER_VERSION"
    echo "  System: $OS-$ARCH"

    if [[ "$OS" == "linux" ]]; then
        echo ""
        log_info "Service Management Commands:"
        echo "  Start:  sudo systemctl start github-runner-${RUNNER_NAME}"
        echo "  Stop:   sudo systemctl stop github-runner-${RUNNER_NAME}"
        echo "  Status: sudo systemctl status github-runner-${RUNNER_NAME}"
        echo "  Logs:   sudo journalctl -u github-runner-${RUNNER_NAME} -f"
    fi

    echo ""
    log_info "Manual Start Command:"
    echo "  cd $INSTALL_DIR && ./run.sh"
}

# Main installation flow
main() {
    log_info "GitHub Actions Self-Hosted Runner Installation"
    log_info "=============================================="

    parse_args "$@"
    detect_system
    check_prerequisites
    create_runner_user
    download_runner
    install_dependencies
    configure_runner
    setup_service
    verify_installation
    show_summary

    log_success "Runner installation completed successfully!"

    if [[ "$OS" == "linux" ]]; then
        log_info "To start the runner: sudo systemctl start github-runner-${RUNNER_NAME}"
    else
        log_info "To start the runner: cd $INSTALL_DIR && ./run.sh"
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi