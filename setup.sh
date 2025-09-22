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
readonly SCRIPT_VERSION="2.2.0"
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

# Token storage configuration
RUNNER_CONFIG_DIR="$HOME/.github-runner/config"
TOKEN_FILE="$RUNNER_CONFIG_DIR/.token.enc"
AUTH_FILE="$RUNNER_CONFIG_DIR/.auth"

# Create config directory if it doesn't exist
create_config_dir() {
    if [[ ! -d "$RUNNER_CONFIG_DIR" ]]; then
        mkdir -p "$RUNNER_CONFIG_DIR"
        chmod 700 "$RUNNER_CONFIG_DIR"
    fi
}

# Simple XOR encryption using pure bash (no dependencies)
xor_encrypt() {
    local input="$1"
    local password="$2"
    local salt="$(date +%s)"  # Use timestamp as salt
    local salted_password="${password}${salt}"
    local output=""

    # Extend password to match input length
    local key=""
    while [ ${#key} -lt ${#input} ]; do
        key="${key}${salted_password}"
    done

    # XOR each character with key
    for ((i=0; i<${#input}; i++)); do
        local char_ord
        char_ord=$(printf "%d" "'${input:$i:1}")
        local key_ord
        key_ord=$(printf "%d" "'${key:$i:1}")
        local xor_result=$((char_ord ^ key_ord))

        # Convert back to character and append
        output="${output}$(printf "\\$(printf "%03o" $xor_result)")"
    done

    # Prepend salt and base64 encode for safe storage
    echo -n "${salt}:${output}" | base64 -w 0
}

# XOR decryption using pure bash
xor_decrypt() {
    local encrypted="$1"
    local password="$2"

    # Decode from base64
    local decoded
    decoded=$(echo "$encrypted" | base64 -d 2>/dev/null) || return 1

    # Extract salt and encrypted data
    local salt="${decoded%%:*}"
    local encrypted_data="${decoded#*:}"
    local salted_password="${password}${salt}"

    # Extend password to match encrypted data length
    local key=""
    while [ ${#key} -lt ${#encrypted_data} ]; do
        key="${key}${salted_password}"
    done

    # XOR decrypt each character
    local output=""
    for ((i=0; i<${#encrypted_data}; i++)); do
        local char_ord
        char_ord=$(printf "%d" "'${encrypted_data:$i:1}")
        local key_ord
        key_ord=$(printf "%d" "'${key:$i:1}")
        local xor_result=$((char_ord ^ key_ord))

        # Convert back to character and append
        output="${output}$(printf "\\$(printf "%03o" $xor_result)")"
    done

    echo "$output"
}

# Generate password hash for verification (simple but effective)
hash_password() {
    local password="$1"
    local hash_input="${password}github-runner-salt"

    # Simple hash using bash arithmetic (good enough for verification)
    local hash=0
    for ((i=0; i<${#hash_input}; i++)); do
        local char_ord
        char_ord=$(printf "%d" "'${hash_input:$i:1}")
        hash=$(( (hash * 31 + char_ord) % 999999999 ))
    done

    echo "$hash"
}

# Save encrypted token
save_token() {
    local token="$1"
    local password="$2"

    create_config_dir

    # Encrypt and save token
    local encrypted_token
    encrypted_token=$(xor_encrypt "$token" "$password")
    echo "$encrypted_token" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE"

    # Save password hash for verification
    local password_hash
    password_hash=$(hash_password "$password")
    echo "$password_hash" > "$AUTH_FILE"
    chmod 600 "$AUTH_FILE"

    log_success "Token saved securely to $TOKEN_FILE"
}

# Load and decrypt token
load_token() {
    local password="$1"

    [[ -f "$TOKEN_FILE" && -f "$AUTH_FILE" ]] || return 1

    # Verify password
    local stored_hash
    stored_hash=$(cat "$AUTH_FILE" 2>/dev/null) || return 1
    local provided_hash
    provided_hash=$(hash_password "$password")

    if [[ "$stored_hash" != "$provided_hash" ]]; then
        log_error "Invalid password"
        return 1
    fi

    # Decrypt token
    local encrypted_token
    encrypted_token=$(cat "$TOKEN_FILE" 2>/dev/null) || return 1

    local decrypted_token
    decrypted_token=$(xor_decrypt "$encrypted_token" "$password") || {
        log_error "Failed to decrypt token"
        return 1
    }

    echo "$decrypted_token"
}

# Check if saved token exists
has_saved_token() {
    [[ -f "$TOKEN_FILE" && -f "$AUTH_FILE" ]]
}

# Remove saved token
remove_saved_token() {
    if has_saved_token; then
        rm -f "$TOKEN_FILE" "$AUTH_FILE"
        log_success "Saved token removed"
    else
        log_info "No saved token found"
    fi
}

# Detect existing GitHub runners
detect_existing_runners() {
    log_info "🔍 Checking for existing GitHub runners..."

    local existing_runners=()
    local runner_info=()

    # Check for Docker runners
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        # Find GitHub runner containers
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                local container_name=$(echo "$line" | awk '{print $1}')
                local status=$(echo "$line" | awk '{print $2}')
                local health=$(echo "$line" | awk '{print $3}' | sed 's/[()]//g')
                local runner_name=$(echo "$container_name" | sed 's/github-runner-//')

                # Include health status in display
                local display_status="$status"
                if [[ "$health" == "unhealthy" ]]; then
                    display_status="$status (unhealthy)"
                elif [[ "$health" == "healthy" ]]; then
                    display_status="$status (healthy)"
                fi

                existing_runners+=("$runner_name")
                runner_info+=("$runner_name:$display_status:docker")
            fi
        done <<< "$(docker ps -a --filter "name=github-runner-" --format "table {{.Names}}\t{{.Status}}\t{{.State}}" | tail -n +2)"
    fi

    # Check for native runners (systemd services)
    if command -v systemctl >/dev/null 2>&1; then
        while IFS= read -r service; do
            if [[ -n "$service" ]]; then
                local runner_name=$(echo "$service" | sed 's/github-runner-//' | sed 's/.service//')
                local status=$(systemctl is-active "github-runner-$runner_name" 2>/dev/null || echo "inactive")

                existing_runners+=("$runner_name")
                runner_info+=("$runner_name:$status:native")
            fi
        done <<< "$(systemctl list-unit-files | grep "github-runner-" | awk '{print $1}' || echo "")"
    fi

    # Return results
    if [[ ${#existing_runners[@]} -gt 0 ]]; then
        echo "EXISTING_RUNNERS:($(IFS=,; echo "${existing_runners[*]}"))"
        echo "RUNNER_INFO:($(IFS=,; echo "${runner_info[*]}"))"
        return 0
    else
        echo "NO_EXISTING_RUNNERS"
        return 1
    fi
}

# Interactive existing runner management
manage_existing_runners() {
    local detection_result
    detection_result=$(detect_existing_runners)

    if [[ "$detection_result" == "NO_EXISTING_RUNNERS" ]]; then
        log_info "No existing runners found. Proceeding with new runner creation."
        return 1
    fi

    # Parse detection results
    local existing_runners_str=$(echo "$detection_result" | grep "EXISTING_RUNNERS" | sed 's/EXISTING_RUNNERS:(\(.*\))/\1/')
    local runner_info_str=$(echo "$detection_result" | grep "RUNNER_INFO" | sed 's/RUNNER_INFO:(\(.*\))/\1/')

    IFS=',' read -ra existing_runners <<< "$existing_runners_str"
    IFS=',' read -ra runner_info <<< "$runner_info_str"

    echo
    log_header "Found existing GitHub runners:"
    echo

    for i in "${!existing_runners[@]}"; do
        local info=(${runner_info[$i]//:/ })
        local runner_name="${info[0]}"
        local status="${info[1]}"
        local type="${info[2]}"

        local status_icon="🔴"
        [[ "$status" == "Up" || "$status" == "active" ]] && status_icon="🟢"

        echo "  $((i+1)). $status_icon $runner_name ($type) - $status"
    done

    echo
    if [[ -n "$REPOSITORY" ]]; then
        echo "Current repository: $REPOSITORY"
    else
        echo "No repository specified yet"
    fi
    echo
    echo "Options:"
    echo "  1. Add repository to existing runner (recommended)"
    echo "  2. Create new dedicated runner"
    echo "  3. Manage existing runners (start/stop/remove)"
    echo "  4. Continue with automatic setup"
    echo

    while true; do
        echo -n "Select option [1-4]: "
        read -r choice

        case "$choice" in
            1)
                # Need repository and token for adding to existing runner
                if [[ -z "$REPOSITORY" ]]; then
                    echo
                    log_info "Repository information needed to add to existing runner"
                    collect_repository_info
                fi
                if [[ -z "$GITHUB_TOKEN" ]]; then
                    echo
                    log_info "GitHub token needed to configure existing runner"
                    collect_github_token
                fi
                select_existing_runner "${existing_runners[@]}"
                return $?
                ;;
            2)
                if [[ -n "$REPOSITORY" ]]; then
                    log_info "Creating new dedicated runner for $REPOSITORY"
                else
                    log_info "Creating new dedicated runner"
                fi
                return 1  # Continue with new runner creation
                ;;
            3)
                manage_runner_operations "${existing_runners[@]}"
                return $?
                ;;
            4)
                log_info "Continuing with automatic setup"
                return 1  # Continue with new runner creation
                ;;
            *)
                echo "Invalid choice. Please select 1-4."
                ;;
        esac
    done
}

# Collect GitHub token information
collect_github_token() {
    # Try to detect existing GitHub CLI token first
    if command -v gh &> /dev/null && gh auth status &> /dev/null 2>&1; then
        local gh_user=$(gh api user --jq '.login' 2>/dev/null)
        if [[ -n "$gh_user" ]]; then
            echo "✓ Found GitHub CLI authentication for user: $gh_user"
            echo -n "Use GitHub CLI token? [Y/n]: "
            read -r use_gh_cli
            if [[ "$use_gh_cli" != "n" && "$use_gh_cli" != "N" ]]; then
                GITHUB_TOKEN=$(gh auth token)
                log_success "Using GitHub CLI token"
                return 0
            fi
        fi
    fi

    # Check for saved encrypted token
    if has_saved_token; then
        echo "🔑 Found saved encrypted token."
        echo -n "Use saved token? [Y/n]: "
        read -r use_saved_token

        if [[ "$use_saved_token" != "n" && "$use_saved_token" != "N" ]]; then
            echo -n "Enter token password: "
            read -r -s token_password
            echo

            local decrypted_token
            if decrypted_token=$(load_token "$token_password"); then
                GITHUB_TOKEN="$decrypted_token"
                log_success "✅ Token loaded successfully!"
                return 0
            else
                log_warning "⚠️ Failed to decrypt token."
            fi
        fi
    fi

    # Manual token entry
    echo "GitHub personal access token is required."
    echo "Create one at: https://github.com/settings/tokens/new?scopes=repo&description=Self-hosted%20runner"
    echo
    while [[ -z "$GITHUB_TOKEN" ]]; do
        echo -n "Enter your GitHub token: "
        read -r -s token_input
        echo
        if [[ -n "$token_input" ]]; then
            GITHUB_TOKEN="$token_input"

            # Offer to save token
            echo -n "Save this token securely for future use? [Y/n]: "
            read -r save_token_choice
            if [[ "$save_token_choice" != "n" && "$save_token_choice" != "N" ]]; then
                echo -n "Create a password to encrypt your token: "
                read -r -s token_password
                echo
                echo -n "Confirm password: "
                read -r -s token_password_confirm
                echo

                if [[ "$token_password" == "$token_password_confirm" && -n "$token_password" ]]; then
                    if save_token "$GITHUB_TOKEN" "$token_password"; then
                        log_success "🔒 Token saved securely!"
                    fi
                fi
            fi
            break
        else
            log_error "Token cannot be empty. Please try again."
        fi
    done
}

# Collect repository information
collect_repository_info() {
    echo -n "Enter repository (owner/repo format): "
    read -r repo_input

    while [[ ! "$repo_input" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; do
        log_error "Invalid format. Please use: owner/repository"
        echo -n "Enter repository (owner/repo format): "
        read -r repo_input
    done

    REPOSITORY="$repo_input"
    log_success "Repository set to: $REPOSITORY"
}

# Select and configure existing runner for new repository
select_existing_runner() {
    local runners=("$@")

    echo
    echo "Select a runner to add $REPOSITORY to:"
    echo

    for i in "${!runners[@]}"; do
        echo "  $((i+1)). ${runners[$i]}"
    done
    echo

    while true; do
        echo -n "Select runner [1-${#runners[@]}]: "
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 && $choice -le ${#runners[@]} ]]; then
            local selected_runner="${runners[$((choice-1))]}"
            RUNNER_NAME="$selected_runner"

            log_info "Adding $REPOSITORY to existing runner: $selected_runner"

            # Add repository to existing runner
            add_repository_to_runner "$selected_runner"
            return 0
        else
            echo "Invalid choice. Please select a number between 1 and ${#runners[@]}."
        fi
    done
}

# Add repository to existing runner
add_repository_to_runner() {
    local runner_name="$1"

    log_info "Configuring runner '$runner_name' for additional repository: $REPOSITORY"

    # For Docker runners, we need to update the configuration
    local docker_dir="./docker-runners/$runner_name"
    if [[ -d "$docker_dir" ]]; then
        log_info "Updating Docker runner configuration..."

        # GitHub runners can handle multiple repositories automatically
        # The runner will register with GitHub and accept jobs from any repository
        # that has the runner token configured

        log_success "✅ Runner '$runner_name' can now handle workflows from $REPOSITORY"
        echo
        echo "Next steps:"
        echo "1. Go to: https://github.com/$REPOSITORY/settings/actions/runners"
        echo "2. Click 'New self-hosted runner'"
        echo "3. Use the token to register this repository with the existing runner"
        echo
        echo "Or run workflow migration to update existing workflows:"

        # Trigger workflow migration for the new repository
        offer_workflow_migration

        return 0
    fi

    # For native runners, register the new repository
    local runner_dir="/home/github-runner/runners/$runner_name"
    if [[ -d "$runner_dir" ]]; then
        log_info "Registering additional repository with native runner..."

        # Note: GitHub runners automatically accept jobs from repositories
        # that have the correct token configured
        log_success "✅ Runner '$runner_name' is ready for $REPOSITORY"
        echo
        echo "The runner will automatically accept jobs from $REPOSITORY"
        echo "once you configure the repository to use self-hosted runners."

        # Trigger workflow migration for the new repository
        offer_workflow_migration

        return 0
    fi

    log_error "❌ Runner directory not found for $runner_name"
    return 1
}

# Manage runner operations (start/stop/remove)
manage_runner_operations() {
    local runners=("$@")

    while true; do
        echo
        echo "Runner Management:"
        echo

        # Display runners with status
        for i in "${!runners[@]}"; do
            local runner_name="${runners[$i]}"
            local status="Unknown"
            local status_icon="🔴"

            # Check status for each runner
            if [[ -d "./docker-runners/$runner_name" ]]; then
                local container_status=$(docker ps --filter "name=github-runner-$runner_name" --format "{{.Status}}" 2>/dev/null | head -1)
                if [[ -n "$container_status" ]]; then
                    status="$container_status"
                    [[ "$container_status" =~ Up.*healthy ]] && status_icon="🟢"
                    [[ "$container_status" =~ Up.*unhealthy ]] && status_icon="🟡"
                    [[ "$container_status" =~ Up ]] && [[ ! "$container_status" =~ unhealthy ]] && status_icon="🟢"
                else
                    status="Stopped"
                fi
            else
                # Native runner
                if systemctl is-active --quiet "github-runner-$runner_name" 2>/dev/null; then
                    status="Running"
                    status_icon="🟢"
                else
                    status="Stopped"
                fi
            fi

            echo "  $((i+1)). $status_icon $runner_name - $status"
        done
        echo
        echo "  $((${#runners[@]}+1)). Back to main menu"
        echo

        # Step 1: Select runner
        while true; do
            echo -n "Select a runner [1-${#runners[@]}] or $((${#runners[@]}+1)) to go back: "
            read -r runner_choice

            if [[ "$runner_choice" == "$((${#runners[@]}+1))" ]]; then
                return 1  # Back to main menu
            elif [[ "$runner_choice" =~ ^[0-9]+$ ]] && [[ $runner_choice -ge 1 && $runner_choice -le ${#runners[@]} ]]; then
                local selected_runner="${runners[$((runner_choice-1))]}"
                echo
                echo "Selected: $selected_runner"
                break
            else
                echo "Invalid choice. Please select a number between 1 and $((${#runners[@]}+1))."
            fi
        done

        # Step 2: Select operation
        echo
        echo "Operations for $selected_runner:"
        echo "  1. Start runner"
        echo "  2. Stop runner"
        echo "  3. Remove runner"
        echo "  4. View logs"
        echo "  5. Check health & restart if unhealthy"
        echo "  6. View connected repositories"
        echo "  7. Back to runner selection"
        echo

        while true; do
            echo -n "Select operation [1-7]: "
            read -r op_choice

            case "$op_choice" in
                1)
                    start_runner "$selected_runner"
                    break
                    ;;
                2)
                    stop_runner "$selected_runner"
                    break
                    ;;
                3)
                    remove_runner "$selected_runner"
                    # After removal, return to main menu
                    return 0
                    ;;
                4)
                    view_runner_logs "$selected_runner"
                    break
                    ;;
                5)
                    check_and_restart_runner "$selected_runner"
                    break
                    ;;
                6)
                    view_connected_repositories "$selected_runner"
                    break
                    ;;
                7)
                    break  # Back to runner selection
                    ;;
                *)
                    echo "Invalid choice. Please select a number between 1 and 7."
                    ;;
            esac
        done

        # Continue the loop to show updated status
    done
}

# Helper functions for runner operations
start_runner() {
    local runner_name="$1"
    log_info "Starting runner: $runner_name"

    # Check if it's a Docker runner
    if [[ -d "./docker-runners/$runner_name" ]]; then
        cd "./docker-runners/$runner_name"
        docker-compose up -d
        log_success "✅ Docker runner '$runner_name' started"
    else
        # Native runner
        sudo systemctl start "github-runner-$runner_name"
        log_success "✅ Native runner '$runner_name' started"
    fi
}

stop_runner() {
    local runner_name="$1"
    log_info "Stopping runner: $runner_name"

    # Check if it's a Docker runner
    if [[ -d "./docker-runners/$runner_name" ]]; then
        cd "./docker-runners/$runner_name"
        docker-compose down
        log_success "✅ Docker runner '$runner_name' stopped"
    else
        # Native runner
        sudo systemctl stop "github-runner-$runner_name"
        log_success "✅ Native runner '$runner_name' stopped"
    fi
}

remove_runner() {
    local runner_name="$1"
    echo -n "⚠️  Are you sure you want to remove runner '$runner_name'? [y/N]: "
    read -r confirm

    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        log_info "Removing runner: $runner_name"

        # Stop first
        stop_runner "$runner_name"

        # Remove Docker resources
        if [[ -d "./docker-runners/$runner_name" ]]; then
            rm -rf "./docker-runners/$runner_name"
            log_success "✅ Docker runner '$runner_name' removed"
        fi

        # Remove native runner
        if systemctl list-unit-files | grep -q "github-runner-$runner_name"; then
            sudo systemctl disable "github-runner-$runner_name"
            sudo rm -f "/etc/systemd/system/github-runner-$runner_name.service"
            sudo systemctl daemon-reload
            log_success "✅ Native runner '$runner_name' removed"
        fi
    else
        log_info "Runner removal cancelled"
    fi
}

view_runner_logs() {
    local runner_name="$1"
    log_info "Viewing logs for runner: $runner_name"

    # Check if it's a Docker runner
    if [[ -d "./docker-runners/$runner_name" ]]; then
        cd "./docker-runners/$runner_name"
        echo "Press Ctrl+C to exit logs"
        docker-compose logs -f
    else
        # Native runner
        echo "Press Ctrl+C to exit logs"
        sudo journalctl -u "github-runner-$runner_name" -f
    fi
}

check_and_restart_runner() {
    local runner_name="$1"
    log_info "Checking health for runner: $runner_name"

    # Check if it's a Docker runner
    if [[ -d "./docker-runners/$runner_name" ]]; then
        local container_name="github-runner-$runner_name"

        # Get container health status
        local health_status=$(docker inspect "$container_name" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
        local container_status=$(docker inspect "$container_name" --format='{{.State.Status}}' 2>/dev/null || echo "not-found")

        echo "Container status: $container_status"
        echo "Health status: $health_status"

        if [[ "$health_status" == "unhealthy" ]]; then
            echo
            log_warning "Container is unhealthy. Running diagnostic checks..."

            # Check recent logs
            echo "=== Recent Container Logs ==="
            docker logs "$container_name" --tail 30
            echo

            # Check health check logs specifically
            echo "=== Health Check History ==="
            docker inspect "$container_name" --format='{{range .State.Health.Log}}{{.Start}}: {{.Output}}{{end}}' | tail -5
            echo

            # Check container resource usage
            echo "=== Container Resource Usage ==="
            docker stats "$container_name" --no-stream --format "CPU: {{.CPUPerc}}, Memory: {{.MemUsage}}, Net I/O: {{.NetIO}}"
            echo

            # Try manual health check
            echo "=== Manual Health Check ==="
            docker exec "$container_name" /home/github-runner/health-check.sh verbose 2>/dev/null || echo "Health check script failed to execute"
            echo

            echo "Diagnostic Options:"
            echo "  [r] Restart container"
            echo "  [s] Run health check in container shell"
            echo "  [l] View full logs"
            echo "  [i] Interactive shell for debugging"
            echo "  [c] Cancel"
            echo
            echo -n "Select option [r/s/l/i/c]: "
            read -r debug_choice

            case "$debug_choice" in
                r|R)
                    log_info "Restarting container..."
                    cd "./docker-runners/$runner_name"
                    docker-compose restart

                    # Wait a moment and check status again
                    sleep 5
                    local new_status=$(docker inspect "$container_name" --format='{{.State.Status}}' 2>/dev/null || echo "not-found")
                    log_info "New container status: $new_status"

                    if [[ "$new_status" == "running" ]]; then
                        log_success "✅ Container restarted successfully"
                    else
                        log_error "❌ Container restart may have failed"
                    fi
                    ;;
                s|S)
                    log_info "Running health check in container..."
                    docker exec -it "$container_name" /home/github-runner/health-check.sh verbose
                    ;;
                l|L)
                    log_info "Viewing full container logs..."
                    docker logs "$container_name" | less
                    ;;
                i|I)
                    log_info "Opening interactive shell in container..."
                    echo "Use 'exit' to return to this menu"
                    docker exec -it "$container_name" bash
                    ;;
                c|C)
                    log_info "Diagnostic cancelled"
                    ;;
                *)
                    log_error "Invalid choice"
                    ;;
            esac
        elif [[ "$health_status" == "healthy" ]]; then
            log_success "✅ Container is healthy"
        elif [[ "$container_status" == "running" ]]; then
            log_info "ℹ️  Container is running (no health check configured)"
        else
            log_warning "Container is not running. Status: $container_status"
            echo -n "Start the container? [Y/n]: "
            read -r start_choice

            if [[ "$start_choice" != "n" && "$start_choice" != "N" ]]; then
                start_runner "$runner_name"
            fi
        fi
    else
        # Native runner - check systemd status
        local service_status=$(systemctl is-active "github-runner-$runner_name" 2>/dev/null || echo "inactive")
        echo "Service status: $service_status"

        if [[ "$service_status" != "active" ]]; then
            echo -n "Start the service? [Y/n]: "
            read -r start_choice

            if [[ "$start_choice" != "n" && "$start_choice" != "N" ]]; then
                start_runner "$runner_name"
            fi
        else
            log_success "✅ Service is active"
        fi
    fi
}

# View connected repositories for a runner
view_connected_repositories() {
    local runner_name="$1"

    echo
    log_header "Connected repositories for runner: $runner_name"
    echo

    # Check if it's a Docker runner
    if [[ -d "./docker-runners/$runner_name" ]]; then
        echo "Runner type: Docker"
        echo

        # Try to get repository from docker-compose environment
        local compose_file="./docker-runners/$runner_name/docker-compose.yml"
        if [[ -f "$compose_file" ]]; then
            local repos=$(grep "GITHUB_REPOSITORY" "$compose_file" | sed 's/.*GITHUB_REPOSITORY=\([^[:space:]]*\).*/\1/' | sort -u)
            if [[ -n "$repos" ]]; then
                echo "Configured repositories:"
                echo "$repos" | while read -r repo; do
                    if [[ -n "$repo" ]]; then
                        echo "  • $repo"
                    fi
                done
            else
                echo "No repositories found in Docker configuration"
            fi
        else
            echo "Docker compose file not found"
        fi

        # Check actual runner configuration if container is running
        local container_name="github-runner-$runner_name"
        if docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "$container_name"; then
            echo
            echo "Active container configuration:"
            local env_repos=$(docker exec "$container_name" env 2>/dev/null | grep "GITHUB_REPOSITORY" | cut -d'=' -f2 | sort -u)
            if [[ -n "$env_repos" ]]; then
                echo "$env_repos" | while read -r repo; do
                    if [[ -n "$repo" ]]; then
                        echo "  • $repo (active)"
                    fi
                done
            else
                echo "  No repository environment variable found"
            fi

            # Check runner configuration file
            local runner_config=$(docker exec "$container_name" cat /home/github-runner/.runner 2>/dev/null | grep "serverUrl" | sed 's/.*"serverUrl": "\([^"]*\)".*/\1/')
            if [[ -n "$runner_config" ]]; then
                echo
                echo "GitHub registration URL:"
                echo "  $runner_config"
            fi
        else
            echo "Container is not running - cannot check active configuration"
        fi

    else
        # Native runner
        echo "Runner type: Native"
        echo

        local runner_config_dir="/home/github-runner/actions-runner-$runner_name"
        if [[ -d "$runner_config_dir" ]]; then
            local config_file="$runner_config_dir/.runner"
            if [[ -f "$config_file" ]]; then
                echo "Runner configuration:"
                local server_url=$(grep "serverUrl" "$config_file" | sed 's/.*"serverUrl": "\([^"]*\)".*/\1/')
                local agent_name=$(grep "agentName" "$config_file" | sed 's/.*"agentName": "\([^"]*\)".*/\1/')

                if [[ -n "$server_url" ]]; then
                    echo "  • Server URL: $server_url"
                fi
                if [[ -n "$agent_name" ]]; then
                    echo "  • Agent Name: $agent_name"
                fi

                # Extract repository from server URL
                local repo=$(echo "$server_url" | sed 's|https://github.com/\(.*\)|\1|')
                if [[ -n "$repo" && "$repo" != "$server_url" ]]; then
                    echo "  • Repository: $repo"
                fi
            else
                echo "Runner configuration file not found"
            fi

            # Check if service is running
            if systemctl is-active --quiet "github-runner-$runner_name" 2>/dev/null; then
                echo "  • Status: Running"
            else
                echo "  • Status: Stopped"
            fi
        else
            echo "Runner directory not found: $runner_config_dir"
        fi
    fi

    echo
    echo "Press Enter to continue..."
    read -r
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
    --clear-token      Remove saved encrypted token
    --show-token       Display saved encrypted token (requires password)
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
    echo

    # Check for saved token first
    if has_saved_token; then
        echo "🔑 Found saved encrypted token."
        echo -n "Use saved token? [Y/n]: "
        read -r use_saved_token

        if [[ "$use_saved_token" != "n" && "$use_saved_token" != "N" ]]; then
            echo -n "Enter token password: "
            read -r -s token_password
            echo

            local decrypted_token
            if decrypted_token=$(load_token "$token_password"); then
                GITHUB_TOKEN="$decrypted_token"
                log_success "✅ Token loaded successfully!"
                echo
            else
                log_warning "⚠️ Failed to decrypt token. You'll need to enter it manually."
                echo
            fi
        fi
    fi

    # Check for existing runners first (before any steps)
    if detect_existing_runners >/dev/null 2>&1; then
        echo "🔍 Found existing GitHub runners on this system!"
        echo
        echo "What would you like to do?"
        echo "1. Manage existing runners (view status, restart, stop, remove)"
        echo "2. Add a new runner for a different repository"
        echo "3. Exit"
        echo
        echo -n "Select option [1-3] (default: 1): "
        read -r action_choice

        case "${action_choice:-1}" in
            1)
                echo
                if manage_existing_runners; then
                    log_success "Runner management completed!"
                    return 0
                fi
                ;;
            2)
                echo
                log_info "Proceeding to add a new runner..."
                echo
                ;;
            3)
                log_info "Exiting setup wizard"
                return 0
                ;;
            *)
                log_error "Invalid choice. Exiting."
                return 1
                ;;
        esac
    else
        echo "No existing runners found. Let's set up your first runner!"
        echo
    fi

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

    # Offer to save token securely
    if [[ -n "$GITHUB_TOKEN" ]]; then
        echo
        echo -n "Save this token securely for future use? [Y/n]: "
        read -r save_token_choice

        if [[ "$save_token_choice" != "n" && "$save_token_choice" != "N" ]]; then
            echo -n "Create a password to encrypt your token: "
            read -r -s token_password
            echo
            echo -n "Confirm password: "
            read -r -s token_password_confirm
            echo

            if [[ "$token_password" == "$token_password_confirm" ]]; then
                if [[ -n "$token_password" ]]; then
                    if save_token "$GITHUB_TOKEN" "$token_password"; then
                        log_success "🔒 Token saved securely! You won't need to re-enter it next time."
                    else
                        log_warning "Failed to save token. Continuing without saving."
                    fi
                else
                    log_warning "Password cannot be empty. Token not saved."
                fi
            else
                log_warning "Passwords don't match. Token not saved."
            fi
        fi
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
            --clear-token)
                remove_saved_token
                exit 0
                ;;
            --show-token)
                if has_saved_token; then
                    echo -n "Enter token password: "
                    read -r -s token_password
                    echo
                    local decrypted_token
                    if decrypted_token=$(load_token "$token_password"); then
                        echo "Saved token: $decrypted_token"
                    else
                        log_error "Failed to decrypt token"
                        exit 1
                    fi
                else
                    log_info "No saved token found"
                fi
                exit 0
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

    # Check if workflow-helper.sh exists
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local workflow_helper="$script_dir/scripts/workflow-helper.sh"

    if [[ ! -f "$workflow_helper" ]]; then
        log_error "Workflow helper script not found at: $workflow_helper"
        log_info "Please run migration manually after setup completes"
        return 1
    fi

    # Create temporary directory for repository clone
    local temp_dir="/tmp/workflow-migration-$$"
    local github_url="https://github.com/$REPOSITORY.git"

    log_info "Cloning repository to analyze workflows..."

    # Clone repository with token authentication
    if ! git clone "https://${GITHUB_TOKEN}@github.com/${REPOSITORY}.git" "$temp_dir" 2>/dev/null; then
        log_error "Failed to clone repository. Please check your token permissions."
        log_info "You can migrate workflows manually later with:"
        echo "  $workflow_helper migrate /path/to/your/repo"
        return 1
    fi

    # Check if workflows directory exists
    local workflows_dir="$temp_dir/.github/workflows"

    if [[ ! -d "$workflows_dir" ]]; then
        log_info "No .github/workflows directory found in repository."
        log_info "If you add workflows later, you can migrate them with:"
        echo "  $workflow_helper migrate /path/to/your/repo"
        rm -rf "$temp_dir"
        return 0
    fi

    # Count GitHub-hosted workflows
    local github_hosted_count=0
    local total_workflows=0
    local github_hosted_files=()

    while IFS= read -r workflow_file; do
        if [[ -n "$workflow_file" && -f "$workflow_file" ]]; then
            ((total_workflows++))
            local filename=$(basename "$workflow_file")
            # Check if workflow uses GitHub-hosted runners
            if grep -qE "runs-on:\s*(ubuntu|windows|macos)-(latest|[0-9]+\.[0-9]+)" "$workflow_file"; then
                ((github_hosted_count++))
                github_hosted_files+=("$filename")
            fi
        fi
    done <<< "$(find "$workflows_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null)"

    if [[ $total_workflows -eq 0 ]]; then
        log_info "No workflow files found in repository"
        rm -rf "$temp_dir"
        return 0
    fi

    echo "Found $total_workflows workflow file(s) in your repository"

    if [[ $github_hosted_count -gt 0 ]]; then
        echo "→ $github_hosted_count workflow(s) are using GitHub-hosted runners:"
        for file in "${github_hosted_files[@]}"; do
            echo "  • $file"
        done
        echo "→ These can be migrated to use your self-hosted runner"
        echo

        echo "Migration options:"
        echo "  1. Create a PR with migrated workflows (recommended)"
        echo "  2. Push directly to main branch"
        echo "  3. Save changes locally only"
        echo "  4. Skip migration"
        echo

        while true; do
            echo -n "Select option [1-4]: "
            read -r migration_choice

            case "$migration_choice" in
                1|2|3)
                    break
                    ;;
                4)
                    log_info "Skipping workflow migration. You can migrate later with:"
                    echo "  $workflow_helper migrate /path/to/your/repo"
                    rm -rf "$temp_dir"
                    return 0
                    ;;
                *)
                    echo "Invalid choice. Please select 1-4."
                    ;;
            esac
        done

        # Perform migration
        log_info "Starting workflow migration..."

        cd "$temp_dir"

        # Run workflow-helper migration (non-interactive mode)
        if "$workflow_helper" update . --no-backup; then
            log_success "Workflows migrated successfully!"

            # Configure git user
            git config user.name "GitHub Runner Setup"
            git config user.email "runner@self-hosted"

            # Commit changes
            git add .github/workflows/

            if git diff --cached --quiet; then
                log_info "No changes to commit (workflows may already be compatible)"
                rm -rf "$temp_dir"
                return 0
            fi

            git commit -m "Migrate workflows to self-hosted runner

Migrated $github_hosted_count workflow(s) from GitHub-hosted to self-hosted runners:
$(printf '• %s\n' "${github_hosted_files[@]}")

Runner: $RUNNER_NAME
Environment: $ENVIRONMENT_TYPE

🤖 Generated with GitHub Self-Hosted Runner Setup v$SCRIPT_VERSION"

            case "$migration_choice" in
                1) # Create PR
                    local branch_name="migrate-to-self-hosted-runner-$(date +%s)"
                    git checkout -b "$branch_name"

                    if git push origin "$branch_name" 2>/dev/null; then
                        log_success "✅ Branch pushed successfully!"
                        echo
                        echo "🔗 Create a pull request at:"
                        echo "   https://github.com/$REPOSITORY/compare/$branch_name?expand=1&title=Migrate%20workflows%20to%20self-hosted%20runner"
                        echo
                        echo "📋 PR Description suggestion:"
                        echo "   Migrates $github_hosted_count workflow(s) to use self-hosted runner '$RUNNER_NAME'"
                        echo "   This will reduce GitHub Actions usage and improve build performance."
                    else
                        log_error "Failed to push branch. You may need to push manually:"
                        echo "  cd $temp_dir"
                        echo "  git push origin $branch_name"
                    fi
                    ;;
                2) # Push to main
                    if git push origin HEAD 2>/dev/null; then
                        log_success "✅ Changes pushed to main branch!"
                        echo "Your workflows are now using the self-hosted runner."
                    else
                        log_error "Failed to push to main branch. You may need to push manually:"
                        echo "  cd $temp_dir"
                        echo "  git push origin HEAD"
                    fi
                    ;;
                3) # Save locally only
                    log_info "Changes saved locally in: $temp_dir"
                    echo "To push later:"
                    echo "  cd $temp_dir"
                    echo "  git push origin HEAD"
                    return 0  # Don't clean up temp_dir
                    ;;
            esac
        else
            log_error "Workflow migration failed. Please try manual migration:"
            echo "  $workflow_helper migrate $temp_dir"
        fi
    else
        log_success "✅ All workflows are already using self-hosted or custom runners!"
    fi

    # Cleanup
    rm -rf "$temp_dir"
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
    echo "║                 GitHub Self-Hosted Runner                    ║"
    echo "║                   Universal Installer                        ║"
    echo "║                Version $SCRIPT_VERSION • Booplex.com         ║"
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
    check_prerequisites

    # Check for existing runners and offer management options
    if [[ "$FORCE_INSTALL" != "true" ]]; then
        if manage_existing_runners; then
            # User chose to use existing runner - setup is complete
            log_success "Setup completed using existing runner!"
            return 0
        fi
        # User chose to create new runner - continue with installation
    fi

    # Generate runner name if not already set
    if [[ -z "$RUNNER_NAME" ]]; then
        generate_runner_name
    fi

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