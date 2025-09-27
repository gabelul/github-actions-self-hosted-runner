# GitHub Self-Hosted Runner Universal Tool

## 🤖 Claude Self-Maintenance Protocol

**⚠️ ATTENTION CLAUDE: You are reading this because you're working on the GitHub self-hosted runner system. MANDATORY STEPS:**

### 1. Pre-Work Checklist

- [ ] Check `git status` for recent changes in this repository
- [ ] Review any `// CLAUDE UPDATE NEEDED` markers in script files
- [ ] Verify you understand the universal installer philosophy below
- [ ] Check which runner configurations are supported

### 2. During Work Requirements

- [ ] ALWAYS test scripts on both VPS and local environments
- [ ] NEVER hard-code specific GitHub repositories in universal scripts
- [ ] Follow security best practices for runner installations
- [ ] Ensure scripts work with multiple concurrent runners
- [ ] Test Docker and native installation methods

### 3. Post-Work Updates (REQUIRED)

- [ ] Update "Last Modified" date below: **2025-09-16**
- [ ] Document any new runner patterns discovered
- [ ] Add compatibility notes for different OS distributions
- [ ] Increment work counter: **Current: 1**

---

## 🧠 System Context

The GitHub Self-Hosted Runner Universal Tool is a **standalone infrastructure solution** that allows developers to run GitHub Actions workflows on their own compute resources (VPS, dedicated servers, or local machines) instead of consuming GitHub Action minutes.

### Core Runner Philosophy

**Universal Deployment + Security First + Multi-Project Support = Zero GitHub Minutes**

```bash
# ✅ CORRECT - Universal installer approach
./setup.sh --token YOUR_TOKEN --repo owner/repo --environment vps

# ❌ WRONG - Project-specific, non-reusable approach
git clone entire-project-repo-to-run-runners
```

## 🚨 Critical Architecture Patterns

### Pattern 1: Universal Installer Design

```bash
#!/bin/bash
# ✅ CORRECT - Auto-detects environment and adapts
detect_environment() {
    if [[ -n "${VPS_MODE}" ]] || [[ -f "/etc/cloud/cloud.cfg" ]]; then
        ENVIRONMENT="vps"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        ENVIRONMENT="local_mac"
    else
        ENVIRONMENT="local_linux"
    fi
}

# ❌ WRONG - Hard-coded environment assumptions
if [ "$USER" != "root" ]; then
    echo "Must run as root"  # Bad - doesn't work for all scenarios
fi
```

### Pattern 2: Multi-Runner Support

```bash
# ✅ CORRECT - Support multiple runners on same machine
./setup.sh --token TOKEN1 --repo owner/project1 --name runner-project1
./setup.sh --token TOKEN2 --repo owner/project2 --name runner-project2

# ❌ WRONG - Single runner limitation
./setup.sh --token TOKEN --global  # Doesn't scale for multiple projects
```

### Pattern 3: Security-First Installation

```bash
# ✅ CORRECT - Non-root user with proper permissions
create_runner_user() {
    sudo useradd -m -s /bin/bash github-runner
    sudo usermod -aG docker github-runner  # If Docker needed
    # Configure sudoers for specific runner commands only
}

# ❌ WRONG - Running as root or with excessive permissions
sudo ./actions-runner/run.sh  # Security risk
```

## 🗂️ Repository Structure

### Core Files

```
github-self-hosted-runner/
├── CLAUDE.md                     # This file - system documentation
├── README.md                     # Human-readable quick start guide
├── setup.sh                      # Universal installer (main entry point)
├── LICENSE                       # MIT License
├── .gitignore                     # Ignore sensitive config files
├── scripts/                       # Management and utility scripts
│   ├── workflow-helper.sh        # ⭐ NEW: Workflow automation and migration tool
│   ├── workflow-templates/       # ⭐ NEW: Pre-built workflow templates
│   │   ├── node-ci.yml.template  # Node.js CI with comprehensive testing
│   │   ├── python-ci.yml.template# Python CI with multiple versions
│   │   ├── docker-build.yml.template # Multi-arch Docker builds
│   │   ├── deploy-prod.yml.template # Production deployment pipeline
│   │   ├── matrix-test.yml.template # Cross-platform matrix testing
│   │   └── security-scan.yml.template # Comprehensive security scanning
│   ├── install-runner.sh         # Core installation logic
│   ├── configure-runner.sh       # Interactive configuration helper
│   ├── start-runner.sh           # Start runner service
│   ├── stop-runner.sh            # Stop runner service
│   ├── health-check-runner.sh    # Monitor runner health
│   ├── add-runner.sh             # Add additional runners
│   ├── remove-runner.sh          # Clean runner removal
│   ├── security-audit.sh         # Security validation and auditing
│   └── test-suite.sh             # Comprehensive testing framework
├── docker/                       # Docker-based deployment
│   ├── Dockerfile                # Optimized GitHub runner image
│   ├── docker-compose.yml        # One-command deployment
│   ├── .env.example              # Environment configuration template
│   ├── entrypoint.sh             # Container initialization script
│   └── health-check.sh           # Container health monitoring
├── systemd/                      # System service integration
│   ├── github-runner.service     # Single runner SystemD service
│   ├── github-runner@.service    # Multi-instance service template
│   └── README.md                 # Service configuration guide
├── docs/                         # Comprehensive documentation
│   ├── README.md                 # Documentation index
│   ├── workflow-automation.md    # ⭐ NEW: Complete workflow automation guide
│   ├── vps-setup.md              # Complete VPS deployment guide
│   ├── local-setup.md            # Local development machine setup
│   ├── multi-runner.md           # Multiple runners configuration
│   ├── security.md               # Security best practices guide
│   ├── troubleshooting.md        # Common issues and solutions
│   └── migration-guide.md        # Moving from GitHub-hosted runners
└── config/                       # Configuration templates and examples
    ├── runner-config.template    # Runner configuration template
    ├── labels.example            # Custom runner labels configuration
    └── environment.example       # Environment variables template
```

## 🎯 Supported Deployment Scenarios

### Scenario 1: VPS/Dedicated Server (Recommended)

- **Target**: Linux-based cloud servers (Ubuntu, Debian, CentOS)
- **Benefits**: 24/7 availability, dedicated resources, team access
- **Use Case**: Production workflows, team projects, always-on runners

### Scenario 2: Local Development Machine

- **Target**: Developer laptops/desktops (macOS, Linux, Windows)
- **Benefits**: No additional infrastructure costs, quick testing
- **Use Case**: Personal projects, development testing, temporary runners

### Scenario 3: Docker Container (Cross-Platform)

- **Target**: Any Docker-compatible environment
- **Benefits**: Isolated environment, easy cleanup, consistent setup
- **Use Case**: Temporary runners, testing, isolated environments

### Scenario 4: Multi-Runner Setup

- **Target**: Single machine serving multiple GitHub repositories
- **Benefits**: Resource efficiency, centralized management
- **Use Case**: Multiple projects, team infrastructure, CI/CD farms

## 🚨 Critical Security Requirements

### Security Pattern 1: Non-Root Execution

```bash
# ✅ ALWAYS create dedicated runner user
setup_runner_user() {
    # Create user with minimal privileges
    sudo useradd -m -s /bin/bash -c "GitHub Actions Runner" github-runner

    # Add to docker group only if Docker is needed
    if command -v docker >/dev/null 2>&1; then
        sudo usermod -aG docker github-runner
    fi

    # Configure sudoers for specific commands only
    echo "github-runner ALL=(ALL) NOPASSWD: /bin/systemctl start github-runner*" | sudo tee /etc/sudoers.d/github-runner
}
```

### Security Pattern 2: Token Management with Encryption

```bash
# ✅ CORRECT - Encrypted token storage (v2.2.1+)
save_token() {
    local token="$1"
    local password="$2"
    local config_dir="$HOME/.github-runner/config"

    # Create protected directory
    mkdir -p "$config_dir"
    chmod 700 "$config_dir"

    # Encrypt token using XOR with salt
    local salt="$(date +%s)"
    local encrypted_token=$(xor_encrypt "$token" "${password}${salt}")

    # Store encrypted token with restricted permissions
    echo "$encrypted_token" > "$config_dir/.token.enc"
    chmod 600 "$config_dir/.token.enc"

    # Store password hash for verification
    local password_hash=$(hash_password "$password")
    echo "$password_hash" > "$config_dir/.auth"
    chmod 600 "$config_dir/.auth"
}

# ✅ CORRECT - Legacy secure storage (backward compatibility)
store_token_securely() {
    local token="$1"
    local config_dir="/home/github-runner/.github-runner"

    sudo -u github-runner mkdir -p "$config_dir"
    sudo -u github-runner chmod 700 "$config_dir"
    echo "$token" | sudo -u github-runner tee "$config_dir/token" > /dev/null
    sudo -u github-runner chmod 600 "$config_dir/token"
}

# ❌ WRONG - Insecure token storage
echo "$TOKEN" > /tmp/token.txt  # World-readable
export GITHUB_TOKEN="$TOKEN"   # Visible in process list
```

### Security Pattern 3: Network Security

```bash
# ✅ CORRECT - Secure runner configuration
configure_network_security() {
    # Use official GitHub domains only
    local github_url="https://github.com"
    local api_url="https://api.github.com"

    # Configure firewall rules (example for UFW)
    sudo ufw allow out 443/tcp
    sudo ufw allow out 80/tcp

    # Block unnecessary outbound connections
    sudo ufw deny out on any
}
```

## 🔧 Runner Management Patterns

### Pattern 1: Health Monitoring

```bash
# ✅ Comprehensive health check system
check_runner_health() {
    local runner_name="$1"
    local runner_dir="/home/github-runner/actions-runner-$runner_name"

    # Check if runner process is active
    if ! systemctl is-active --quiet "github-runner@$runner_name"; then
        log_warning "Runner $runner_name is not active"
        return 1
    fi

    # Check if runner is connected to GitHub
    if ! sudo -u github-runner "$runner_dir/run.sh" --help >/dev/null 2>&1; then
        log_error "Runner $runner_name binary is corrupted"
        return 1
    fi

    # Check available disk space
    local available_space=$(df /home/github-runner | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 1048576 ]; then  # Less than 1GB
        log_warning "Low disk space for runner $runner_name: ${available_space}KB available"
    fi

    return 0
}
```

### Pattern 2: Graceful Runner Updates

```bash
# ✅ Zero-downtime runner updates
update_runner() {
    local runner_name="$1"
    local runner_dir="/home/github-runner/actions-runner-$runner_name"

    # Stop the runner gracefully (wait for current jobs to finish)
    log_info "Stopping runner $runner_name gracefully..."
    sudo systemctl stop "github-runner@$runner_name"

    # Download and install latest runner
    cd "$runner_dir"
    sudo -u github-runner ./config.sh remove --token "$GITHUB_TOKEN"

    # Download latest version
    local latest_version=$(get_latest_runner_version)
    download_runner_version "$latest_version" "$runner_dir"

    # Reconfigure and start
    configure_runner "$runner_name" "$runner_dir"
    sudo systemctl start "github-runner@$runner_name"
}
```

## 📊 Performance Optimization Patterns

### Pattern 1: Resource Allocation

```bash
# ✅ Optimal resource allocation based on machine capacity
calculate_optimal_runners() {
    local cpu_cores=$(nproc)
    local memory_gb=$(free -g | awk 'NR==2{printf "%.0f", $7}')  # Available memory

    # Rule: 1 runner per 2 CPU cores, minimum 2GB RAM per runner
    local max_runners_by_cpu=$((cpu_cores / 2))
    local max_runners_by_memory=$((memory_gb / 2))

    # Take the limiting factor
    local recommended_runners=$([ $max_runners_by_cpu -lt $max_runners_by_memory ] && echo $max_runners_by_cpu || echo $max_runners_by_memory)

    # Minimum 1, maximum 8 runners
    recommended_runners=$([ $recommended_runners -lt 1 ] && echo 1 || echo $recommended_runners)
    recommended_runners=$([ $recommended_runners -gt 8 ] && echo 8 || echo $recommended_runners)

    echo $recommended_runners
}
```

### Pattern 2: Build Cache Optimization

```bash
# ✅ Shared build cache setup
setup_build_cache() {
    local cache_dir="/home/github-runner/shared-cache"

    # Create shared cache directory
    sudo -u github-runner mkdir -p "$cache_dir"/{node_modules,.npm,.yarn,docker-layers}

    # Set proper permissions
    sudo -u github-runner chmod -R 755 "$cache_dir"

    # Configure cache limits (prevent disk overflow)
    echo "Setting up cache cleanup cron job..."
    echo "0 2 * * * /usr/bin/find $cache_dir -type f -mtime +7 -delete" | sudo -u github-runner crontab -
}
```

## 🚫 Anti-Patterns to Avoid

### ❌ DON'T: Hard-Code Repository Information

```bash
# ❌ WRONG - Repository-specific runner
REPO="owner/specific-repo"
curl -o actions-runner-linux-x64.tar.gz -L https://github.com/$REPO/actions-runner-download

# ✅ CORRECT - Universal runner that accepts any repository
setup_for_repository() {
    local repo="$1"  # Passed as parameter
    curl -o actions-runner-linux-x64.tar.gz -L "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
}
```

### ❌ DON'T: Skip Security Hardening

```bash
# ❌ WRONG - Running as root
sudo ./run.sh

# ❌ WRONG - Excessive permissions
chmod 777 /home/github-runner

# ❌ WRONG - Storing secrets in plain text
echo "token=ghp_xxxxxxxxxxxx" > config.env
```

### ❌ DON'T: Ignore Resource Limits

```bash
# ❌ WRONG - No resource monitoring
while true; do
    ./run.sh  # Could consume all system resources
done

# ✅ CORRECT - Resource-aware execution with monitoring
```

## 🔄 Installation Flow Patterns

### Pattern: Universal Setup Flow

```bash
# Universal setup.sh flow
1. detect_environment()     # VPS vs Local vs Docker
2. check_prerequisites()    # OS, dependencies, permissions
3. download_runner()        # Latest GitHub Actions runner
4. create_runner_user()     # Security hardening
5. configure_runner()       # Repository-specific config
6. setup_systemd_service()  # Auto-start and monitoring
7. verify_installation()    # Health checks
8. display_status()         # Success confirmation and next steps
```

## 🔄 Workflow Automation Patterns

### Pattern: Interactive Migration System

```bash
# ✅ CORRECT - Interactive workflow selection with preview
select_workflows() {
    local workflows_dir="$1"

    # Find all workflow files
    find_workflow_files "$workflows_dir"

    # Display with selection interface
    show_workflow_selection_ui

    # Preview changes before applying
    preview_migration_changes

    # Create backups before modification
    create_workflow_backups
}

# ❌ WRONG - Bulk modification without user consent
find . -name "*.yml" -exec sed -i 's/ubuntu-latest/self-hosted/g' {} \;
```

### Pattern: Template-Based Workflow Generation

```bash
# ✅ CORRECT - Template system with variable substitution
generate_workflow_from_template() {
    local template_type="$1"
    local target_file="$2"

    case "$template_type" in
        "node-ci")
            substitute_template_variables \
                "$TEMPLATES_DIR/node-ci.yml.template" \
                "$target_file" \
                "NODE_VERSION=${NODE_VERSION:-18}" \
                "RUNNER_TYPE=${RUNNER_TYPE:-self-hosted}"
            ;;
        "python-ci")
            substitute_template_variables \
                "$TEMPLATES_DIR/python-ci.yml.template" \
                "$target_file" \
                "PYTHON_VERSION=${PYTHON_VERSION:-3.11}"
            ;;
    esac
}
```

### Pattern: Cost Analysis and Migration Planning

```bash
# ✅ CORRECT - Comprehensive usage analysis
analyze_github_actions_usage() {
    local repo_path="$1"
    local workflows_dir="$repo_path/.github/workflows"

    # Count workflow types
    local github_hosted=0
    local self_hosted=0

    # Analyze each workflow
    for workflow in "$workflows_dir"/*.yml; do
        if uses_github_runners "$workflow"; then
            ((github_hosted++))
        else
            ((self_hosted++))
        fi
    done

    # Calculate potential savings
    local estimated_minutes=$((github_hosted * 100))
    local estimated_savings=$((estimated_minutes * 8 / 1000))

    display_cost_analysis "$github_hosted" "$self_hosted" "$estimated_savings"
}
```

### Pattern: Safe Migration with Rollback

```bash
# ✅ CORRECT - Migration with backup and rollback capability
migrate_workflows_safely() {
    local workflows=("$@")
    local backup_dir="$HOME/.github-runner-backups/$(date +%Y%m%d_%H%M%S)"

    # Create backup directory
    mkdir -p "$backup_dir"

    # Backup all files before modification
    for workflow in "${workflows[@]}"; do
        cp "$workflow" "$backup_dir/$(basename "$workflow").backup"
    done

    # Apply migrations
    for workflow in "${workflows[@]}"; do
        if ! migrate_single_workflow "$workflow"; then
            log_error "Migration failed for $workflow, rolling back..."
            rollback_from_backup "$backup_dir"
            return 1
        fi
    done

    log_success "Migration completed successfully"
    log_info "Backups stored in: $backup_dir"
}
```

## 📋 Testing Patterns

### Pattern: Multi-Environment Testing

```bash
# Test matrix for universal compatibility
test_environments() {
    local environments=(
        "ubuntu-20.04"
        "ubuntu-22.04"
        "debian-11"
        "centos-7"
        "rocky-8"
        "macos-local"
    )

    for env in "${environments[@]}"; do
        test_setup_in_environment "$env"
    done
}
```

## 📊 Maintenance Log

- **Last Modified**: 2025-09-27
- **Last Claude Review**: 2025-09-27
- **Work Sessions**: 4
- **Supported Platforms**: Linux (Ubuntu, Debian, CentOS), macOS (local), Docker (universal)
- **Security Features**: Non-root execution, OpenSSL/XOR token encryption, network hardening, secure file permissions
- **Runner Management**: Multi-runner, health monitoring, graceful updates, smart wizard flow, multi-token support
- **Token Management**: Repository validation, multi-token storage, token testing, improved scope guidance
- **Health Check**: Fixed Docker timeout issues, comprehensive diagnostics
- **Critical Issues Found**: None (resolved Docker health timeout in v2.2.0, token encryption in v2.2.1, multi-repo token issues in v2.2.4)

## 🎯 Next Priority Tasks

- ✅ COMPLETED: Workflow automation helper with interactive migration
- ✅ COMPLETED: 6 comprehensive workflow templates (Node.js, Python, Docker, Deploy, Matrix, Security)
- ✅ COMPLETED: Cost analysis and migration planning tools
- ✅ COMPLETED: Pure bash token encryption with XOR cipher and salt protection
- ✅ COMPLETED: Smart setup wizard with existing runner detection
- ✅ COMPLETED: Docker health check timeout fixes and debugging tools
- ✅ COMPLETED: Token validation before repository clone attempts
- ✅ COMPLETED: Multi-token support with repository/organization association
- ✅ COMPLETED: Token re-entry option when repository access fails
- ✅ COMPLETED: Enhanced token creation guidance with clearer scope explanations
- ✅ COMPLETED: Token management commands (list, test, clear, add-token)
- TODO CLAUDE: Add Windows PowerShell support for local Windows development
- TODO CLAUDE: Implement runner auto-scaling based on GitHub Actions queue
- TODO CLAUDE: Add integration with cloud providers (AWS, DigitalOcean, Linode)
- TODO CLAUDE: Create web dashboard for multi-runner monitoring
- PERFORMANCE TODO: Optimize runner startup time and resource usage
- SECURITY TODO: Implement runner sandboxing and container isolation
- TYPE TODO: Add configuration validation and error checking

## 🔗 Related Documentation

- **Main Setup Guide**: `README.md` - Quick start for human users
- **VPS Deployment**: `docs/vps-setup.md` - Complete VPS setup guide
- **Docker Setup**: `docker/README.md` - Container-based deployment
- **Security Guide**: `docs/security.md` - Security best practices
- **Multi-Runner Guide**: `docs/multi-runner.md` - Multiple runners configuration

---

**⚠️ REMINDER**: This tool is designed to be UNIVERSAL and work with ANY GitHub repository. When adding features, always ensure they maintain this universal compatibility!