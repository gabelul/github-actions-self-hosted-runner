#!/bin/bash

# Script Dependency Validator
# Validates that shell scripts declare their dependencies correctly

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Common commands that should be checked
declare -A COMMON_COMMANDS=(
    ["curl"]="Network operations"
    ["wget"]="Network operations"
    ["git"]="Git operations"
    ["docker"]="Docker operations"
    ["systemctl"]="SystemD operations"
    ["jq"]="JSON processing"
    ["tar"]="Archive operations"
    ["unzip"]="Archive operations"
    ["openssl"]="Cryptographic operations"
    ["base64"]="Encoding operations"
)

# Check if a script properly validates its dependencies
validate_script_dependencies() {
    local script_file="$1"
    local errors=0

    log_info "Validating dependencies for: $script_file"

    # Read the script content
    local script_content
    if ! script_content=$(cat "$script_file"); then
        log_error "Cannot read script file: $script_file"
        return 1
    fi

    # Extract commands used in the script
    local commands_used=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue

        # Extract command usage patterns
        for cmd in "${!COMMON_COMMANDS[@]}"; do
            if [[ "$line" =~ (^|[[:space:]]|\$\(|`)$cmd([[:space:]]|\$|'|"|`) ]]; then
                commands_used+=("$cmd")
            fi
        done
    done <<< "$script_content"

    # Remove duplicates
    local unique_commands
    mapfile -t unique_commands < <(printf '%s\n' "${commands_used[@]}" | sort -u)

    # Check if script has dependency validation
    local has_dependency_check=false
    if [[ "$script_content" =~ command[[:space:]]*-v|which[[:space:]]|type[[:space:]] ]]; then
        has_dependency_check=true
    fi

    # Report findings
    if [[ ${#unique_commands[@]} -gt 0 ]]; then
        log_info "Commands detected in $script_file:"
        for cmd in "${unique_commands[@]}"; do
            echo "  - $cmd (${COMMON_COMMANDS[$cmd]})"
        done

        if [[ "$has_dependency_check" == "false" ]]; then
            log_warning "Script $script_file uses external commands but lacks dependency validation"
            log_warning "Consider adding checks like: command -v $cmd >/dev/null || { echo 'Error: $cmd not found'; exit 1; }"
            ((errors++))
        else
            log_info "Script has dependency validation ✓"
        fi
    else
        log_info "No external command dependencies detected"
    fi

    # Check for proper error handling
    if [[ ! "$script_content" =~ set[[:space:]].*-e ]]; then
        log_warning "Script $script_file lacks 'set -e' for error handling"
        ((errors++))
    fi

    # Check for unbound variable protection
    if [[ ! "$script_content" =~ set[[:space:]].*-u ]]; then
        log_warning "Script $script_file lacks 'set -u' for unbound variable protection"
        ((errors++))
    fi

    # Check for pipefail protection
    if [[ ! "$script_content" =~ set[[:space:]].*-o[[:space:]]*pipefail ]]; then
        log_warning "Script $script_file lacks 'set -o pipefail' for pipe failure detection"
        ((errors++))
    fi

    return $errors
}

# Main function
main() {
    local exit_code=0

    log_info "Starting script dependency validation"

    # Process each file passed as argument
    for script_file in "$@"; do
        if [[ -f "$script_file" && "$script_file" =~ \.(sh|bash)$ ]]; then
            if ! validate_script_dependencies "$script_file"; then
                exit_code=1
            fi
            echo # Add spacing between files
        fi
    done

    if [[ $exit_code -eq 0 ]]; then
        log_info "All scripts passed dependency validation ✓"
    else
        log_error "Some scripts failed dependency validation ✗"
    fi

    return $exit_code
}

# Execute main function with all arguments
main "$@"