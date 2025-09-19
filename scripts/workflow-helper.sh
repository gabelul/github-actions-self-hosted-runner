#!/bin/bash

# GitHub Actions Workflow Helper
#
# This script helps automate the creation and migration of GitHub Actions workflows
# to use self-hosted runners instead of GitHub's hosted runners.
#
# Features:
# - Interactive migration of existing workflows
# - Generation of new workflow templates
# - Batch processing with selective conversion
# - Backup and rollback capabilities
# - Template library for common scenarios
#
# Usage:
#   ./workflow-helper.sh migrate /path/to/repo      # Migrate existing workflows
#   ./workflow-helper.sh generate                   # Create new workflow
#   ./workflow-helper.sh template <type>            # Use pre-built template
#   ./workflow-helper.sh analyze /path/to/repo      # Analyze current usage
#
# Author: Gabel (Booplex.com)
# Website: https://booplex.com
# Built with: Interactive bash, YAML wizardry, and the hope that users read instructions

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly TEMPLATES_DIR="$SCRIPT_DIR/workflow-templates"
readonly BACKUP_DIR="$HOME/.github-runner-backups"

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
VERBOSE=false
DRY_RUN=false
FORCE=false
TARGET_RUNNER="self-hosted"
BACKUP_ENABLED=true

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
    echo -e "${WHITE}$1${NC}"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# Show help information
show_help() {
    cat << EOF
${WHITE}GitHub Actions Workflow Helper${NC}

Automate creation and migration of GitHub Actions workflows for self-hosted runners.

${WHITE}USAGE:${NC}
    $0 <command> [options] [arguments]

${WHITE}COMMANDS:${NC}
    migrate <repo_path>     Migrate existing workflows to self-hosted runners
    scan [repo_path]        Scan for workflows that can be migrated (default: current dir)
    update <repo_path>      Quick update workflows to self-hosted (no interaction)
    generate                Generate new workflow with guided wizard
    template <type>         Create workflow from pre-built template
    analyze <repo_path>     Analyze current workflow runner usage
    list-templates          Show available workflow templates

${WHITE}OPTIONS:${NC}
    --runner RUNNER         Target runner (default: self-hosted)
    --dry-run              Show what would be done without making changes
    --verbose              Enable verbose output
    --no-backup            Skip creating backups
    --force                Force overwrite without confirmation
    --help                 Show this help message

${WHITE}EXAMPLES:${NC}
    # Scan current directory for migration opportunities
    $0 scan

    # Migrate existing workflows with interactive selection
    $0 migrate ~/projects/my-app

    # Quick update all GitHub-hosted workflows (no prompts)
    $0 update ~/projects/my-app

    # Generate new Node.js CI workflow
    $0 generate --type ci --lang node

    # Use pre-built template
    $0 template node-ci --output .github/workflows/

    # Analyze potential savings
    $0 analyze ~/projects/my-app

${WHITE}MIGRATION FEATURES:${NC}
    • Interactive workflow selection with checkboxes
    • Automatic backup creation with timestamps
    • Preview changes before applying
    • Support for complex matrix strategies
    • Rollback capability if needed

${WHITE}SUPPORTED TEMPLATES:${NC}
    • node-ci        - Node.js continuous integration
    • python-ci      - Python continuous integration
    • docker-build   - Docker build and push
    • deploy-prod    - Production deployment
    • matrix-test    - Multi-environment testing
    • security-scan  - Security scanning workflow

EOF
}

# Create backup directory if it doesn't exist
ensure_backup_dir() {
    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_debug "Backup directory ready: $BACKUP_DIR"
    fi
}

# Create backup of workflow file
backup_workflow() {
    local workflow_file="$1"
    local repo_name="$2"

    if [[ "$BACKUP_ENABLED" != "true" ]]; then
        return 0
    fi

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local workflow_name=$(basename "$workflow_file" .yml)
    local backup_file="$BACKUP_DIR/${repo_name}_${workflow_name}_${timestamp}.yml.backup"

    cp "$workflow_file" "$backup_file"
    log_debug "Created backup: $backup_file"
    echo "$backup_file"
}

# Parse YAML to extract runs-on value
get_runs_on_value() {
    local workflow_file="$1"

    # Extract runs-on values (handle both single and array formats)
    grep -E "^\s*runs-on:" "$workflow_file" | head -1 | sed 's/^\s*runs-on:\s*//' | sed 's/\[//' | sed 's/\]//' | sed 's/,.*$//' | tr -d '"' | tr -d "'"
}

# Check if workflow uses GitHub-hosted runners
uses_github_runners() {
    local workflow_file="$1"
    local runs_on_value

    runs_on_value=$(get_runs_on_value "$workflow_file")

    case "$runs_on_value" in
        "ubuntu-latest"|"ubuntu-"*|"windows-latest"|"windows-"*|"macos-latest"|"macos-"*)
            return 0  # true - uses GitHub runners
            ;;
        "self-hosted"|"\${{ "*" }}"|"")
            return 1  # false - already uses self-hosted or dynamic
            ;;
        *)
            # Check if it contains GitHub runner names
            if echo "$runs_on_value" | grep -qE "(ubuntu|windows|macos)-(latest|[0-9]+\.[0-9]+)"; then
                return 0  # true - uses GitHub runners
            else
                return 1  # false - probably self-hosted
            fi
            ;;
    esac
}

# Interactive workflow selection
select_workflows() {
    local workflows_dir="$1"
    local selected_workflows=()
    local workflow_files=()
    local workflow_info=()

    # Find all workflow files
    while IFS= read -r file; do
        if [[ -n "$file" && -f "$file" ]]; then
            workflow_files+=("$file")
            local filename=$(basename "$file")
            local runs_on=$(get_runs_on_value "$file")
            workflow_info+=("$filename (currently: ${runs_on:-unknown})")
        fi
    done <<< "$(find "$workflows_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null | sort)"

    if [[ ${#workflow_files[@]} -eq 0 ]]; then
        log_warning "No workflow files found in $workflows_dir"
        return 1
    fi

    log_header "Found ${#workflow_files[@]} workflow file(s):"
    echo

    # Display workflows with selection status
    local selections=()
    for i in "${!workflow_files[@]}"; do
        if uses_github_runners "${workflow_files[$i]}"; then
            selections+=("true")  # Pre-select GitHub-hosted runners
            echo -e "${GREEN}[x]${NC} $((i+1)). ${workflow_info[$i]}"
        else
            selections+=("false")
            echo -e "${RED}[ ]${NC} $((i+1)). ${workflow_info[$i]} ${YELLOW}(already self-hosted)${NC}"
        fi
    done

    echo
    echo "Selection options:"
    echo "  [a]ll - Select all workflows"
    echo "  [n]one - Deselect all workflows"
    echo "  [i]nvert - Invert current selection"
    echo "  [1-9] - Toggle specific workflow"
    echo "  [d]one - Proceed with current selection"
    echo

    # Interactive selection loop
    while true; do
        echo -n "Select workflows to migrate: "
        read -r choice

        case "$choice" in
            "a"|"all")
                for i in "${!selections[@]}"; do
                    selections[$i]="true"
                done
                ;;
            "n"|"none")
                for i in "${!selections[@]}"; do
                    selections[$i]="false"
                done
                ;;
            "i"|"invert")
                for i in "${!selections[@]}"; do
                    if [[ "${selections[$i]}" == "true" ]]; then
                        selections[$i]="false"
                    else
                        selections[$i]="true"
                    fi
                done
                ;;
            "d"|"done")
                break
                ;;
            [1-9]*)
                local num=$((choice - 1))
                if [[ $num -ge 0 && $num -lt ${#selections[@]} ]]; then
                    if [[ "${selections[$num]}" == "true" ]]; then
                        selections[$num]="false"
                    else
                        selections[$num]="true"
                    fi
                else
                    log_error "Invalid workflow number: $choice"
                    continue
                fi
                ;;
            *)
                log_error "Invalid choice: $choice"
                continue
                ;;
        esac

        # Redisplay selection
        clear
        log_header "Found ${#workflow_files[@]} workflow file(s):"
        echo
        for i in "${!workflow_files[@]}"; do
            local marker="${RED}[ ]${NC}"
            if [[ "${selections[$i]}" == "true" ]]; then
                marker="${GREEN}[x]${NC}"
            fi
            echo -e "$marker $((i+1)). ${workflow_info[$i]}"
        done
        echo
        echo "Selection options: [a]ll, [n]one, [i]nvert, [1-9] toggle, [d]one"
    done

    # Collect selected workflows
    for i in "${!selections[@]}"; do
        if [[ "${selections[$i]}" == "true" ]]; then
            selected_workflows+=("${workflow_files[$i]}")
        fi
    done

    if [[ ${#selected_workflows[@]} -eq 0 ]]; then
        log_warning "No workflows selected for migration"
        return 1
    fi

    # Return selected workflows (using global array)
    SELECTED_WORKFLOWS=("${selected_workflows[@]}")
    return 0
}

# Convert workflow to use self-hosted runner
convert_workflow() {
    local workflow_file="$1"
    local target_runner="$2"

    log_debug "Converting $workflow_file to use $target_runner"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would convert $workflow_file"
        return 0
    fi

    # Create temporary file for modifications
    local temp_file=$(mktemp)

    # Convert runs-on values
    # Handle different formats:
    # runs-on: ubuntu-latest
    # runs-on: [ubuntu-latest, macos-latest]
    # runs-on: ${{ matrix.os }}

    while IFS= read -r line; do
        if echo "$line" | grep -qE "^\s*runs-on:\s*(ubuntu|windows|macos)"; then
            # Simple case: runs-on: ubuntu-latest
            local indent=$(echo "$line" | sed 's/[^ ].*//')
            echo "${indent}runs-on: $target_runner"
        elif echo "$line" | grep -qE "^\s*runs-on:\s*\[.*\]"; then
            # Array case: runs-on: [ubuntu-latest, macos-latest]
            local indent=$(echo "$line" | sed 's/[^ ].*//')
            log_warning "Array runs-on detected in $(basename "$workflow_file") - manual review recommended"
            echo "${indent}runs-on: [$target_runner]  # TODO: Review array conversion"
        else
            echo "$line"
        fi
    done < "$workflow_file" > "$temp_file"

    # Replace original file
    mv "$temp_file" "$workflow_file"

    log_success "Converted $(basename "$workflow_file")"
}

# Preview changes that would be made
preview_changes() {
    local workflow_file="$1"
    local target_runner="$2"

    log_info "Preview changes for $(basename "$workflow_file"):"

    # Show current runs-on lines
    local current_lines
    current_lines=$(grep -n "runs-on:" "$workflow_file" || true)

    if [[ -n "$current_lines" ]]; then
        echo "Current configuration:"
        echo "$current_lines" | while read -r line; do
            echo "  $line"
        done

        echo "After conversion:"
        echo "$current_lines" | while read -r line; do
            local line_num=$(echo "$line" | cut -d: -f1)
            local content=$(echo "$line" | cut -d: -f2-)
            local indent=$(echo "$content" | sed 's/runs-on.*//')
            echo "  $line_num:${indent}runs-on: $target_runner"
        done
    else
        log_warning "No runs-on declarations found in $workflow_file"
    fi

    echo
}

# Migrate workflows in a repository
migrate_workflows() {
    local repo_path="$1"
    local workflows_dir="$repo_path/.github/workflows"

    if [[ ! -d "$workflows_dir" ]]; then
        log_error "No .github/workflows directory found in $repo_path"
        return 1
    fi

    log_info "Migrating workflows in: $repo_path"

    # Select workflows interactively (unless dry run)
    if [[ "$DRY_RUN" == "true" ]]; then
        # In dry run mode, select all GitHub-hosted workflows automatically
        local workflow_files=()
        while IFS= read -r file; do
            if [[ -n "$file" && -f "$file" ]]; then
                if uses_github_runners "$file"; then
                    workflow_files+=("$file")
                fi
            fi
        done <<< "$(find "$workflows_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null | sort)"

        if [[ ${#workflow_files[@]} -eq 0 ]]; then
            log_info "No GitHub-hosted workflows found to migrate"
            return 0
        fi

        SELECTED_WORKFLOWS=("${workflow_files[@]}")
        log_info "Selected ${#SELECTED_WORKFLOWS[@]} GitHub-hosted workflow(s) for dry run"
    else
        # Interactive selection for real runs
        if ! select_workflows "$workflows_dir"; then
            return 1
        fi
    fi

    local selected_count=${#SELECTED_WORKFLOWS[@]}
    log_info "Selected $selected_count workflow(s) for migration"

    # Preview changes if not in dry run mode
    if [[ "$DRY_RUN" != "true" ]]; then
        echo
        log_header "Preview of changes:"
        echo

        for workflow_file in "${SELECTED_WORKFLOWS[@]}"; do
            preview_changes "$workflow_file" "$TARGET_RUNNER"
        done

        if [[ "$FORCE" != "true" ]]; then
            echo -n "Proceed with migration? [y/N]: "
            read -r confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                log_info "Migration cancelled"
                return 0
            fi
        fi
    fi

    # Perform migration
    local repo_name=$(basename "$repo_path")
    local success_count=0

    for workflow_file in "${SELECTED_WORKFLOWS[@]}"; do
        log_info "Processing $(basename "$workflow_file")..."

        # Create backup
        if [[ "$BACKUP_ENABLED" == "true" ]]; then
            backup_file=$(backup_workflow "$workflow_file" "$repo_name")
            log_debug "Backup created: $backup_file"
        fi

        # Convert workflow
        if convert_workflow "$workflow_file" "$TARGET_RUNNER"; then
            ((success_count++))
        else
            log_error "Failed to convert $(basename "$workflow_file")"
        fi
    done

    log_success "Successfully migrated $success_count out of $selected_count workflows"

    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        log_info "Backups stored in: $BACKUP_DIR"
    fi

    # Show next steps
    echo
    log_header "Next Steps:"
    echo "1. Review the converted workflows for any manual adjustments"
    echo "2. Test the workflows with your self-hosted runner"
    echo "3. Commit and push the changes to your repository"
    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        echo "4. Backups are available for rollback if needed"
    fi
}

# Generate new workflow
generate_workflow() {
    log_header "GitHub Actions Workflow Generator"
    echo

    # Gather information
    echo "Let's create a new workflow for your self-hosted runner!"
    echo

    # Workflow type
    echo "Available workflow types:"
    echo "1. CI (Continuous Integration)"
    echo "2. CD (Continuous Deployment)"
    echo "3. Test (Testing only)"
    echo "4. Build (Build artifacts)"
    echo "5. Custom (Start from scratch)"
    echo

    local workflow_type
    while true; do
        echo -n "Select workflow type [1-5]: "
        read -r choice
        case "$choice" in
            1) workflow_type="ci"; break ;;
            2) workflow_type="cd"; break ;;
            3) workflow_type="test"; break ;;
            4) workflow_type="build"; break ;;
            5) workflow_type="custom"; break ;;
            *) log_error "Invalid choice. Please select 1-5." ;;
        esac
    done

    # Programming language/framework
    echo
    echo "Programming language/framework:"
    echo "1. Node.js"
    echo "2. Python"
    echo "3. Java"
    echo "4. Go"
    echo "5. Docker"
    echo "6. Generic/Other"
    echo

    local language
    while true; do
        echo -n "Select language [1-6]: "
        read -r choice
        case "$choice" in
            1) language="nodejs"; break ;;
            2) language="python"; break ;;
            3) language="java"; break ;;
            4) language="go"; break ;;
            5) language="docker"; break ;;
            6) language="generic"; break ;;
            *) log_error "Invalid choice. Please select 1-6." ;;
        esac
    done

    # Workflow name
    echo
    echo -n "Workflow name (default: ${workflow_type}-${language}): "
    read -r workflow_name
    if [[ -z "$workflow_name" ]]; then
        workflow_name="${workflow_type}-${language}"
    fi

    # Output location
    echo
    echo -n "Output directory (default: .github/workflows/): "
    read -r output_dir
    if [[ -z "$output_dir" ]]; then
        output_dir=".github/workflows"
    fi

    # Create output directory
    mkdir -p "$output_dir"

    # Generate workflow
    local workflow_file="$output_dir/${workflow_name}.yml"

    log_info "Generating workflow: $workflow_file"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create $workflow_file"
        return 0
    fi

    # Generate workflow content based on selections
    generate_workflow_content "$workflow_type" "$language" > "$workflow_file"

    log_success "Created workflow: $workflow_file"

    # Show next steps
    echo
    log_header "Next Steps:"
    echo "1. Review and customize the generated workflow"
    echo "2. Ensure your self-hosted runner has the required tools"
    echo "3. Commit and push to trigger the workflow"
}

# Generate workflow content based on type and language
generate_workflow_content() {
    local workflow_type="$1"
    local language="$2"

    # Common header
    cat << EOF
# GitHub Actions Workflow - Generated by workflow-helper.sh
#
# This workflow runs on self-hosted runners for better performance
# and cost efficiency compared to GitHub-hosted runners.
#
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Type: $workflow_type
# Language: $language

name: ${workflow_type^^} - ${language^}

# Trigger events
on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

# Environment variables (customize as needed)
env:
  NODE_VERSION: '18'
  PYTHON_VERSION: '3.11'
  GO_VERSION: '1.21'

jobs:
EOF

    # Generate job content based on workflow type and language
    case "$workflow_type" in
        "ci")
            generate_ci_job "$language"
            ;;
        "cd")
            generate_cd_job "$language"
            ;;
        "test")
            generate_test_job "$language"
            ;;
        "build")
            generate_build_job "$language"
            ;;
        "custom")
            generate_custom_job "$language"
            ;;
    esac
}

# Generate CI job content
generate_ci_job() {
    local language="$1"

    cat << EOF
  continuous-integration:
    name: Continuous Integration
    runs-on: $TARGET_RUNNER

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

EOF

    case "$language" in
        "nodejs")
            cat << EOF
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: \${{ env.NODE_VERSION }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linting
        run: npm run lint

      - name: Run tests
        run: npm test

      - name: Build application
        run: npm run build
EOF
            ;;
        "python")
            cat << EOF
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: \${{ env.PYTHON_VERSION }}

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt

      - name: Run linting
        run: |
          pip install flake8
          flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics

      - name: Run tests
        run: |
          pip install pytest
          pytest
EOF
            ;;
        "docker")
            cat << EOF
      - name: Build Docker image
        run: docker build -t test-image .

      - name: Run tests in container
        run: docker run --rm test-image npm test

      - name: Security scan
        run: |
          docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            -v \$PWD:/root/.cache/ aquasec/trivy:latest image test-image
EOF
            ;;
        *)
            cat << EOF
      - name: Run custom build
        run: |
          echo "Add your build commands here"
          # Example: make build

      - name: Run tests
        run: |
          echo "Add your test commands here"
          # Example: make test
EOF
            ;;
    esac
}

# Generate CD job content
generate_cd_job() {
    local language="$1"

    cat << EOF
  continuous-deployment:
    name: Continuous Deployment
    runs-on: $TARGET_RUNNER
    needs: continuous-integration
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build for production
        run: |
          echo "Add your production build commands here"

      - name: Deploy to production
        run: |
          echo "Add your deployment commands here"
          # Example:
          # docker build -t myapp:latest .
          # docker push myapp:latest
          # kubectl set image deployment/myapp myapp=myapp:latest
EOF
}

# Generate test job content
generate_test_job() {
    local language="$1"

    cat << EOF
  test:
    name: Run Tests
    runs-on: $TARGET_RUNNER

    strategy:
      matrix:
        test-type: [unit, integration, e2e]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run \${{ matrix.test-type }} tests
        run: |
          echo "Running \${{ matrix.test-type }} tests"
          # Add your specific test commands here
EOF
}

# Generate build job content
generate_build_job() {
    local language="$1"

    cat << EOF
  build:
    name: Build Application
    runs-on: $TARGET_RUNNER

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build application
        run: |
          echo "Building application"
          # Add your build commands here

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts
          path: |
            dist/
            build/
EOF
}

# Generate custom job content
generate_custom_job() {
    local language="$1"

    cat << EOF
  custom-job:
    name: Custom Job
    runs-on: $TARGET_RUNNER

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Custom step 1
        run: |
          echo "Add your custom commands here"

      - name: Custom step 2
        run: |
          echo "Add more custom commands here"

      # Add more steps as needed
EOF
}

# List available templates
list_templates() {
    log_header "Available Workflow Templates"
    echo

    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        log_warning "Templates directory not found: $TEMPLATES_DIR"
        log_info "You can create templates in $TEMPLATES_DIR"
        return 1
    fi

    local templates=()
    while IFS= read -r -d '' template; do
        templates+=("$(basename "$template" .yml.template)")
    done < <(find "$TEMPLATES_DIR" -name "*.yml.template" -print0 2>/dev/null | sort -z)

    if [[ ${#templates[@]} -eq 0 ]]; then
        log_warning "No templates found in $TEMPLATES_DIR"
        return 1
    fi

    log_info "Found ${#templates[@]} template(s):"
    echo

    for template in "${templates[@]}"; do
        local template_file="$TEMPLATES_DIR/${template}.yml.template"
        local description="No description available"

        # Try to extract description from template file
        if [[ -f "$template_file" ]]; then
            description=$(grep "^# Description:" "$template_file" 2>/dev/null | cut -d: -f2- | sed 's/^ *//' || echo "No description available")
        fi

        echo "  • $template"
        echo "    $description"
        echo
    done

    log_info "Use: $0 template <template_name> to use a template"
}

# Scan for workflows that can be migrated (simplified analyze)
scan_workflows() {
    local repo_path="${1:-.}"  # Default to current directory
    local workflows_dir="$repo_path/.github/workflows"

    # Handle case where repo_path doesn't end with .github/workflows
    if [[ ! -d "$workflows_dir" ]]; then
        if [[ -d "$repo_path" && "$(basename "$repo_path")" == "workflows" ]]; then
            workflows_dir="$repo_path"
            repo_path="$(dirname "$(dirname "$repo_path")")"
        else
            # Try to find .github/workflows
            for search_dir in "$repo_path" "$repo_path/.." "$repo_path/../.."; do
                if [[ -d "$search_dir/.github/workflows" ]]; then
                    workflows_dir="$search_dir/.github/workflows"
                    repo_path="$search_dir"
                    break
                fi
            done
        fi
    fi

    if [[ ! -d "$workflows_dir" ]]; then
        log_error "No .github/workflows directory found"
        log_info "Searched in: $repo_path"
        return 1
    fi

    log_header "🔍 Workflow Migration Scan"
    echo
    log_info "Scanning: $(realpath "$repo_path")"
    echo

    local total_workflows=0
    local github_hosted=0
    local github_hosted_files=()

    # Scan each workflow file
    while IFS= read -r workflow_file; do
        if [[ -n "$workflow_file" && -f "$workflow_file" ]]; then
            ((total_workflows++))
            local filename=$(basename "$workflow_file")

            if uses_github_runners "$workflow_file"; then
                ((github_hosted++))
                github_hosted_files+=("$workflow_file")
                local runs_on=$(get_runs_on_value "$workflow_file")
                echo "  📄 $filename (${runs_on})"
            fi
        fi
    done <<< "$(find "$workflows_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null)"

    echo
    if [[ $github_hosted -gt 0 ]]; then
        log_warning "Found $github_hosted workflow(s) using GitHub-hosted runners"
        echo
        echo "These workflows can be migrated to self-hosted runners:"
        for file in "${github_hosted_files[@]}"; do
            echo "  • $(basename "$file")"
        done
        echo
        echo "Migration options:"
        echo "  $0 migrate $repo_path      # Interactive migration with preview"
        echo "  $0 update $repo_path       # Quick migration without prompts"
        echo

        # Estimate potential savings
        local estimated_minutes=$((github_hosted * 100))
        local estimated_cost=$((estimated_minutes * 8 / 1000))
        echo "💰 Estimated monthly savings: ~$estimated_cost USD"
        echo "   (Based on $estimated_minutes minutes/month at \$0.008/minute)"
    else
        log_success "✅ All $total_workflows workflow(s) already use self-hosted runners!"
    fi

    return 0
}

# Quick update workflows (non-interactive)
update_workflows() {
    local repo_path="$1"
    local workflows_dir="$repo_path/.github/workflows"

    if [[ ! -d "$workflows_dir" ]]; then
        log_error "No .github/workflows directory found in $repo_path"
        return 1
    fi

    log_header "⚡ Quick Workflow Update"
    echo
    log_info "Updating workflows in: $repo_path"
    log_info "Target runner: $TARGET_RUNNER"
    echo

    # Find all GitHub-hosted workflows
    local github_hosted_files=()
    while IFS= read -r workflow_file; do
        if [[ -n "$workflow_file" && -f "$workflow_file" ]]; then
            if uses_github_runners "$workflow_file"; then
                github_hosted_files+=("$workflow_file")
            fi
        fi
    done <<< "$(find "$workflows_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null | sort)"

    if [[ ${#github_hosted_files[@]} -eq 0 ]]; then
        log_success "No GitHub-hosted workflows found - nothing to update"
        return 0
    fi

    log_info "Found ${#github_hosted_files[@]} workflow(s) to update:"
    for file in "${github_hosted_files[@]}"; do
        echo "  • $(basename "$file")"
    done
    echo

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would update ${#github_hosted_files[@]} workflow(s)"
        return 0
    fi

    # Create backups if enabled
    local repo_name=$(basename "$repo_path")
    local backup_files=()

    if [[ "$BACKUP_ENABLED" == "true" ]]; then
        log_info "Creating backups..."
        for workflow_file in "${github_hosted_files[@]}"; do
            backup_file=$(backup_workflow "$workflow_file" "$repo_name")
            backup_files+=("$backup_file")
        done
        log_success "Backups created: ${#backup_files[@]} files"
    fi

    # Update workflows
    local success_count=0
    for workflow_file in "${github_hosted_files[@]}"; do
        local filename=$(basename "$workflow_file")
        echo -n "  Updating $filename... "

        if convert_workflow "$workflow_file" "$TARGET_RUNNER"; then
            echo "✅"
            ((success_count++))
        else
            echo "❌"
            log_error "Failed to update $filename"
        fi
    done

    echo
    if [[ $success_count -eq ${#github_hosted_files[@]} ]]; then
        log_success "✅ Successfully updated all $success_count workflow(s)!"
    else
        log_warning "⚠️  Updated $success_count out of ${#github_hosted_files[@]} workflow(s)"
    fi

    if [[ "$BACKUP_ENABLED" == "true" && ${#backup_files[@]} -gt 0 ]]; then
        echo
        log_info "Backups stored in: $BACKUP_DIR"
        echo "To rollback changes, restore from:"
        for backup in "${backup_files[@]}"; do
            echo "  $backup"
        done
    fi

    echo
    log_header "Next Steps:"
    echo "1. Review the updated workflows"
    echo "2. Test with your self-hosted runner"
    echo "3. Commit and push the changes"
    echo "4. Monitor the first few workflow runs"

    return 0
}

# Analyze current workflow usage
analyze_workflows() {
    local repo_path="$1"
    local workflows_dir="$repo_path/.github/workflows"

    if [[ ! -d "$workflows_dir" ]]; then
        log_error "No .github/workflows directory found in $repo_path"
        return 1
    fi

    log_header "GitHub Actions Usage Analysis"
    echo
    log_info "Analyzing workflows in: $repo_path"
    echo

    local total_workflows=0
    local github_hosted=0
    local self_hosted=0
    local unknown=0

    # Analyze each workflow file
    while IFS= read -r workflow_file; do
        if [[ -n "$workflow_file" && -f "$workflow_file" ]]; then
            ((total_workflows++))
            local filename=$(basename "$workflow_file")
            local runs_on=$(get_runs_on_value "$workflow_file")

            echo -n "  $filename: "

            if uses_github_runners "$workflow_file"; then
                echo -e "${RED}GitHub-hosted${NC} ($runs_on)"
                ((github_hosted++))
            elif [[ -n "$runs_on" ]]; then
                if echo "$runs_on" | grep -q "self-hosted"; then
                    echo -e "${GREEN}Self-hosted${NC} ($runs_on)"
                    ((self_hosted++))
                else
                    echo -e "${YELLOW}Custom${NC} ($runs_on)"
                    ((unknown++))
                fi
            else
                echo -e "${YELLOW}Unknown${NC}"
                ((unknown++))
            fi
        fi
    done <<< "$(find "$workflows_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null)"

    echo
    log_header "Summary:"
    echo "  Total workflows: $total_workflows"
    echo "  GitHub-hosted runners: $github_hosted"
    echo "  Self-hosted runners: $self_hosted"
    echo "  Custom/Unknown: $unknown"
    echo

    if [[ $github_hosted -gt 0 ]]; then
        log_info "Migration Potential:"
        echo "  • $github_hosted workflow(s) can be migrated to self-hosted runners"

        # Rough cost estimation (GitHub Actions pricing as of 2024)
        local estimated_minutes=$((github_hosted * 100))  # Rough estimate
        local estimated_cost=$((estimated_minutes * 8 / 1000))  # $0.008 per minute for Linux

        echo "  • Estimated monthly savings: ~$estimated_cost USD"
        echo "    (Based on $estimated_minutes minutes/month at \$0.008/minute for Linux)"
        echo

        log_info "To migrate these workflows, run:"
        echo "  $0 migrate $repo_path"
    else
        log_success "All workflows are already using self-hosted or custom runners!"
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --runner)
                TARGET_RUNNER="$2"
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
            --no-backup)
                BACKUP_ENABLED=false
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done
}

# Main function
main() {
    log_header "🔄 GitHub Actions Workflow Helper"
    echo

    # Parse global options first
    parse_args "$@"

    # Get remaining arguments
    local remaining_args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
            --runner|--dry-run|--verbose|--no-backup|--force|--help)
                # Skip options we already processed
                if [[ "$1" == "--runner" ]]; then
                    shift 2
                else
                    shift
                fi
                ;;
            *)
                remaining_args+=("$1")
                shift
                ;;
        esac
    done

    set -- "${remaining_args[@]}"

    if [[ $# -eq 0 ]]; then
        log_error "No command specified"
        show_help
        exit 1
    fi

    local command="$1"
    shift

    # Ensure backup directory exists
    ensure_backup_dir

    # Execute command
    case "$command" in
        "scan")
            # Default to current directory if no path provided
            scan_workflows "${1:-.}"
            ;;
        "migrate")
            if [[ $# -eq 0 ]]; then
                log_error "Repository path required for migrate command"
                echo "Usage: $0 migrate <repo_path>"
                exit 1
            fi
            migrate_workflows "$1"
            ;;
        "update")
            if [[ $# -eq 0 ]]; then
                log_error "Repository path required for update command"
                echo "Usage: $0 update <repo_path>"
                exit 1
            fi
            update_workflows "$1"
            ;;
        "generate")
            generate_workflow "$@"
            ;;
        "template")
            if [[ $# -eq 0 ]]; then
                list_templates
            else
                log_error "Template functionality not yet implemented"
                echo "Available templates:"
                list_templates
            fi
            ;;
        "analyze")
            if [[ $# -eq 0 ]]; then
                log_error "Repository path required for analyze command"
                echo "Usage: $0 analyze <repo_path>"
                exit 1
            fi
            analyze_workflows "$1"
            ;;
        "list-templates")
            list_templates
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Global array for selected workflows (used by select_workflows function)
declare -a SELECTED_WORKFLOWS

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi