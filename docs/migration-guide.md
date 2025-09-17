# Migration Guide: From GitHub-Hosted to Self-Hosted Runners

This guide provides a comprehensive approach to migrating from GitHub-hosted runners to self-hosted runners, including planning, implementation strategies, and testing procedures.

## 🎯 Why Migrate to Self-Hosted Runners?

### Cost Benefits

| GitHub Plan | Monthly Minutes | Overage Cost/min | Break-even Point |
|-------------|-----------------|------------------|------------------|
| **Free** | 2,000 | $0.008 | 1,250 minutes |
| **Pro** | 3,000 | $0.008 | 1,875 minutes |
| **Team** | 3,000 | $0.008 | 1,875 minutes |
| **Enterprise** | 50,000 | $0.008 | N/A (usually sufficient) |

**If you're using more than 1,250-1,875 minutes per month, self-hosted runners will save money.**

### Performance Benefits

- **Faster execution**: No queue waiting times
- **Persistent caches**: Build artifacts persist between runs
- **Custom environment**: Pre-installed tools and dependencies
- **Better hardware**: Choose your own CPU/RAM/storage configurations

### Control Benefits

- **Security**: Complete control over the execution environment
- **Compliance**: Meet specific regulatory requirements
- **Customization**: Install any software or configuration needed
- **Debugging**: Direct access to runners for troubleshooting

## 📊 Migration Planning

### Phase 1: Assessment

#### Analyze Current Usage

**Option 1: Use the Workflow Helper (Recommended)**

```bash
# Quick analysis with our built-in tool
./scripts/workflow-helper.sh analyze /path/to/your/repository

# Example output:
# 📊 GitHub Actions Usage Analysis
# ===============================
#
#   ci.yml: GitHub-hosted (ubuntu-latest)
#   deploy.yml: GitHub-hosted (ubuntu-latest)
#   tests.yml: Self-hosted (self-hosted)
#
# Summary:
#   Total workflows: 3
#   GitHub-hosted runners: 2
#   Self-hosted runners: 1
#
# 💰 Migration Potential:
#   • 2 workflow(s) can be migrated to self-hosted runners
#   • Estimated monthly savings: ~$16 USD
#     (Based on 200 minutes/month at $0.008/minute for Linux)
```

**Option 2: Manual Analysis with GitHub CLI**

```bash
# Use GitHub CLI to analyze repository actions usage
gh api repos/owner/repo/actions/runs --paginate | jq '
  .workflow_runs[] |
  select(.created_at >= "2024-01-01") |
  {
    name: .name,
    status: .status,
    conclusion: .conclusion,
    created_at: .created_at,
    run_started_at: .run_started_at,
    updated_at: .updated_at
  }'
```

#### Calculate Migration ROI

```bash
#!/bin/bash
# migration-calculator.sh

# Current GitHub Actions usage (get from GitHub billing)
MONTHLY_MINUTES=5000
OVERAGE_RATE=0.008  # $0.008 per minute

# Self-hosted costs
VPS_MONTHLY_COST=50  # Example: DigitalOcean droplet
SETUP_TIME_HOURS=8
HOURLY_RATE=50

# Calculate costs
MONTHLY_OVERAGE_COST=$((MONTHLY_MINUTES * OVERAGE_RATE))
SETUP_COST=$((SETUP_TIME_HOURS * HOURLY_RATE))
MONTHLY_SAVINGS=$((MONTHLY_OVERAGE_COST - VPS_MONTHLY_COST))
PAYBACK_MONTHS=$((SETUP_COST / MONTHLY_SAVINGS))

echo "Monthly GitHub Actions cost: \$${MONTHLY_OVERAGE_COST}"
echo "Monthly self-hosted cost: \$${VPS_MONTHLY_COST}"
echo "Monthly savings: \$${MONTHLY_SAVINGS}"
echo "Setup cost: \$${SETUP_COST}"
echo "Payback period: ${PAYBACK_MONTHS} months"
```

#### Inventory Workflows

Create an inventory of your current workflows:

```yaml
# workflow-inventory.yml
workflows:
  - name: "CI/CD Pipeline"
    file: ".github/workflows/ci.yml"
    frequency: "Every push"
    duration: "~10 minutes"
    runners: ["ubuntu-latest"]
    special_requirements: ["Node.js 18", "Docker"]

  - name: "Security Scan"
    file: ".github/workflows/security.yml"
    frequency: "Daily"
    duration: "~5 minutes"
    runners: ["ubuntu-latest"]
    special_requirements: ["Snyk CLI", "Trivy"]

  - name: "Performance Tests"
    file: ".github/workflows/perf.yml"
    frequency: "Weekly"
    duration: "~30 minutes"
    runners: ["ubuntu-latest"]
    special_requirements: ["K6", "8GB RAM"]
```

### Phase 2: Infrastructure Planning

#### Choose Hosting Option

| Option | Pros | Cons | Best For |
|--------|------|------|----------|
| **VPS (DigitalOcean, Linode)** | Cost-effective, simple | Manual management | Small teams, simple setups |
| **Cloud VM (AWS EC2, GCP)** | Scalable, integrated services | More complex, potentially expensive | Enterprise, complex integrations |
| **Dedicated Server** | High performance, predictable costs | Higher upfront cost | High-volume usage |
| **Local Machine** | No hosting costs, full control | Uptime dependency, network requirements | Development, testing |

#### Size Your Infrastructure

```bash
# infrastructure-sizing.sh

# Analyze workflow requirements
CONCURRENT_WORKFLOWS=3
AVG_WORKFLOW_DURATION=10  # minutes
PEAK_MULTIPLIER=2

# Calculate resource needs
REQUIRED_RUNNERS=$((CONCURRENT_WORKFLOWS * PEAK_MULTIPLIER))
CPU_CORES_PER_RUNNER=2
RAM_GB_PER_RUNNER=4

TOTAL_CPU_CORES=$((REQUIRED_RUNNERS * CPU_CORES_PER_RUNNER))
TOTAL_RAM_GB=$((REQUIRED_RUNNERS * RAM_GB_PER_RUNNER))

echo "Recommended infrastructure:"
echo "- Runners needed: $REQUIRED_RUNNERS"
echo "- Total CPU cores: $TOTAL_CPU_CORES"
echo "- Total RAM: ${TOTAL_RAM_GB}GB"
echo "- Recommended VM: ${TOTAL_CPU_CORES}vCPU, ${TOTAL_RAM_GB}GB RAM"
```

## 🚀 Migration Strategies

### Strategy 1: Gradual Migration (Recommended)

Migrate workflows one at a time to minimize risk:

#### Step 1: Setup Self-Hosted Runner

```bash
# Deploy your first runner
./setup.sh --token ghp_xxxx --repo owner/repo --name migration-test
```

#### Step 2: Create Test Workflow

```yaml
# .github/workflows/test-self-hosted.yml
name: Test Self-Hosted Runner
on:
  workflow_dispatch:  # Manual trigger only

jobs:
  test:
    runs-on: [self-hosted, Linux, X64]
    steps:
      - uses: actions/checkout@v4
      - name: Test Environment
        run: |
          echo "Runner OS: $(uname -a)"
          echo "Available tools:"
          which git node npm docker
          echo "System resources:"
          nproc
          free -h
          df -h
```

#### Step 3: Migrate Non-Critical Workflows

Start with workflows that:
- Run infrequently
- Are not on the critical path
- Have simple requirements

```yaml
# Before (GitHub-hosted)
jobs:
  docs:
    runs-on: ubuntu-latest

# After (Self-hosted)
jobs:
  docs:
    runs-on: [self-hosted, Linux, X64]
```

#### Step 4: Migrate Critical Workflows

Only after thorough testing of non-critical workflows.

### Strategy 2: Parallel Running

Run both GitHub-hosted and self-hosted runners simultaneously:

```yaml
name: Parallel Testing
on: [push, pull_request]

jobs:
  test-github-hosted:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  test-self-hosted:
    runs-on: [self-hosted, Linux, X64]
    steps:
      - uses: actions/checkout@v4
      - run: npm test

  compare-results:
    needs: [test-github-hosted, test-self-hosted]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Compare Results
        run: |
          echo "GitHub-hosted result: ${{ needs.test-github-hosted.result }}"
          echo "Self-hosted result: ${{ needs.test-self-hosted.result }}"
```

### Strategy 3: Feature Branch Testing

Test on feature branches before migrating main:

```yaml
name: Smart Runner Selection
on: [push, pull_request]

jobs:
  test:
    runs-on: >
      ${{
        github.ref == 'refs/heads/main' &&
        'ubuntu-latest' ||
        '[self-hosted, Linux, X64]'
      }}
```

## 🤖 Automated Migration with Workflow Helper

### Quick Automated Migration

For most users, the automated approach is faster and safer:

```bash
# Step 1: Setup your self-hosted runner
./setup.sh --token ghp_your_token --repo owner/your-repo

# Step 2: Analyze your workflows
./scripts/workflow-helper.sh analyze /path/to/your/repository

# Step 3: Migrate workflows interactively
./scripts/workflow-helper.sh migrate /path/to/your/repository
```

### Interactive Migration Process

The workflow helper provides a user-friendly interface:

```
🔄 GitHub Actions Workflow Helper
====================================

Found 5 workflow file(s):

[x] 1. ci.yml (currently: ubuntu-latest)
[x] 2. tests.yml (currently: ubuntu-latest)
[ ] 3. windows-build.yml (currently: windows-latest)
[x] 4. deploy.yml (currently: ubuntu-latest)
[ ] 5. release.yml (currently: macos-latest)

Selection options:
  [a]ll - Select all workflows
  [n]one - Deselect all workflows
  [i]nvert - Invert current selection
  [1-9] - Toggle specific workflow
  [d]one - Proceed with current selection

Select workflows to migrate: d

Selected 3 workflow(s) for migration

Preview of changes:
==================

ci.yml:
  Line 15:    runs-on: ubuntu-latest
  After:      runs-on: self-hosted

tests.yml:
  Line 8:     runs-on: ubuntu-latest
  After:      runs-on: self-hosted

deploy.yml:
  Line 12:    runs-on: ubuntu-latest
  After:      runs-on: self-hosted

Proceed with migration? [y/N]: y

✅ Successfully migrated 3 out of 3 workflows
💾 Backups stored in: ~/.github-runner-backups/20250917_142030
```

### Automated Migration Features

#### Safe Migration
- **Automatic backups** with timestamps
- **Preview changes** before applying
- **Rollback capability** if issues occur

#### Smart Detection
- Finds all workflow files (`.yml` and `.yaml`)
- Identifies GitHub-hosted vs self-hosted runners
- Handles complex `runs-on` configurations

#### Selective Migration
- Choose specific workflows to migrate
- Skip workflows that need to stay on GitHub (e.g., Windows builds)
- Pre-selects obvious migration candidates

#### Cost Analysis
- Shows potential monthly savings
- Calculates break-even point
- Estimates migration impact

### Advanced Automated Options

```bash
# Dry run (preview only)
./scripts/workflow-helper.sh migrate /path/to/repo --dry-run

# Use specific runner labels
./scripts/workflow-helper.sh migrate /path/to/repo --runner "[self-hosted, Linux, X64]"

# Skip backups (not recommended)
./scripts/workflow-helper.sh migrate /path/to/repo --no-backup

# Force migration without confirmation
./scripts/workflow-helper.sh migrate /path/to/repo --force
```

### When to Use Automated vs Manual Migration

**Use Automated Migration When:**
- You have standard Linux-based workflows
- Most workflows use `ubuntu-latest`
- You want to migrate quickly and safely
- You prefer interactive selection

**Use Manual Migration When:**
- You have complex matrix strategies
- You need custom runner configurations
- You want to gradually migrate specific jobs
- You have workflows with special requirements

## 🔧 Manual Workflow Modifications

### Common Changes Required

#### 1. Update Runner Labels

```yaml
# Before
runs-on: ubuntu-latest

# After
runs-on: [self-hosted, Linux, X64]

# Or with specific labels
runs-on: [self-hosted, Linux, X64, nodejs, docker]
```

#### 2. Handle Pre-installed Software

GitHub-hosted runners come with many tools pre-installed. Document what you need:

```yaml
# Document current dependencies
- name: Check Environment
  run: |
    echo "Node version: $(node --version)"
    echo "Python version: $(python3 --version)"
    echo "Docker version: $(docker --version)"
    echo "Available tools:" > environment.txt
    ls /usr/local/bin >> environment.txt
```

#### 3. Install Missing Dependencies

```yaml
# Add installation steps for missing tools
- name: Setup Environment
  run: |
    # Install Node.js if not available
    if ! command -v node &> /dev/null; then
      curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
      sudo apt-get install -y nodejs
    fi

    # Install Python packages
    pip3 install --user pytest coverage
```

#### 4. Handle Checkout Differences

Self-hosted runners maintain state between runs:

```yaml
# Clean workspace before checkout
- name: Clean Workspace
  run: |
    # Remove all files except .git
    find . -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

- uses: actions/checkout@v4
  with:
    clean: true  # Important for self-hosted runners
```

#### 5. Manage Artifacts and Caches

Take advantage of persistent storage:

```yaml
# Use local caching
- name: Cache Dependencies
  run: |
    # Check if cache exists locally
    if [ -d "/home/github-runner/cache/node_modules" ]; then
      cp -r /home/github-runner/cache/node_modules .
    fi

- name: Save Cache
  if: always()
  run: |
    # Save cache locally
    mkdir -p /home/github-runner/cache
    cp -r node_modules /home/github-runner/cache/
```

## 🧪 Testing Your Migration

### Pre-Migration Testing

#### 1. Environment Compatibility Test

```bash
#!/bin/bash
# test-environment.sh

# Test script to verify self-hosted runner environment
echo "=== Environment Compatibility Test ==="

# Check required commands
REQUIRED_COMMANDS=("git" "node" "npm" "docker" "curl" "wget")
MISSING_COMMANDS=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_COMMANDS+=("$cmd")
    else
        echo "✅ $cmd: $(which $cmd)"
    fi
done

if [ ${#MISSING_COMMANDS[@]} -ne 0 ]; then
    echo "❌ Missing commands: ${MISSING_COMMANDS[*]}"
    exit 1
fi

# Check versions
echo -e "\n=== Version Check ==="
echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo "Docker: $(docker --version)"

# Check resources
echo -e "\n=== Resource Check ==="
echo "CPU cores: $(nproc)"
echo "Memory: $(free -h | awk '/^Mem:/{print $2}')"
echo "Disk space: $(df -h / | awk 'NR==2{print $4}')"

echo -e "\n=== Network Test ==="
if curl -s https://api.github.com/zen > /dev/null; then
    echo "✅ GitHub API accessible"
else
    echo "❌ Cannot reach GitHub API"
    exit 1
fi

echo -e "\n✅ Environment test passed!"
```

#### 2. Workflow Dry Run

```bash
# Create a minimal test repository
mkdir migration-test
cd migration-test
git init

# Create test workflow
mkdir -p .github/workflows
cat > .github/workflows/test.yml << 'EOF'
name: Migration Test
on: workflow_dispatch

jobs:
  test:
    runs-on: [self-hosted, Linux, X64]
    steps:
      - uses: actions/checkout@v4
      - name: Basic Test
        run: |
          echo "Hello from self-hosted runner!"
          pwd
          whoami
          uname -a
EOF

# Push and test
git add .
git commit -m "Add test workflow"
# Push to GitHub and run manually
```

### Post-Migration Validation

#### 1. Performance Comparison

```yaml
# .github/workflows/performance-test.yml
name: Performance Comparison
on: workflow_dispatch

jobs:
  github-hosted:
    runs-on: ubuntu-latest
    outputs:
      duration: ${{ steps.timer.outputs.duration }}
    steps:
      - uses: actions/checkout@v4
      - id: timer
        run: |
          start=$(date +%s)
          # Your build process here
          npm ci
          npm run build
          npm test
          end=$(date +%s)
          duration=$((end - start))
          echo "duration=$duration" >> $GITHUB_OUTPUT

  self-hosted:
    runs-on: [self-hosted, Linux, X64]
    outputs:
      duration: ${{ steps.timer.outputs.duration }}
    steps:
      - uses: actions/checkout@v4
      - id: timer
        run: |
          start=$(date +%s)
          # Same build process
          npm ci
          npm run build
          npm test
          end=$(date +%s)
          duration=$((end - start))
          echo "duration=$duration" >> $GITHUB_OUTPUT

  compare:
    needs: [github-hosted, self-hosted]
    runs-on: ubuntu-latest
    steps:
      - name: Compare Performance
        run: |
          github_duration=${{ needs.github-hosted.outputs.duration }}
          self_hosted_duration=${{ needs.self-hosted.outputs.duration }}

          echo "GitHub-hosted duration: ${github_duration}s"
          echo "Self-hosted duration: ${self_hosted_duration}s"

          if [ $self_hosted_duration -lt $github_duration ]; then
            improvement=$((github_duration - self_hosted_duration))
            echo "✅ Self-hosted is ${improvement}s faster!"
          else
            regression=$((self_hosted_duration - github_duration))
            echo "❌ Self-hosted is ${regression}s slower"
          fi
```

#### 2. Resource Usage Monitoring

```bash
#!/bin/bash
# monitor-usage.sh

echo "Monitoring self-hosted runner usage..."

# Monitor during a workflow run
PID=$(pgrep -f "Runner.Worker")
if [ -n "$PID" ]; then
    echo "Monitoring process $PID"

    # Monitor for 5 minutes
    for i in {1..300}; do
        CPU=$(ps -p $PID -o %cpu --no-headers)
        MEM=$(ps -p $PID -o %mem --no-headers)
        echo "$(date): CPU: ${CPU}%, Memory: ${MEM}%"
        sleep 1
    done
else
    echo "Runner process not found"
fi
```

## 🚨 Common Migration Issues and Solutions

### Issue 1: Missing Dependencies

**Problem**: Workflow fails because a tool isn't installed.

**Solution**:
```yaml
- name: Install Dependencies
  run: |
    sudo apt-get update
    sudo apt-get install -y build-essential python3-dev
```

**Better Solution**: Pre-install dependencies in runner setup or Docker image.

### Issue 2: Permission Issues

**Problem**: Cannot write to certain directories.

**Solution**:
```yaml
- name: Fix Permissions
  run: |
    sudo chown -R $USER:$USER $GITHUB_WORKSPACE
    chmod -R 755 $GITHUB_WORKSPACE
```

### Issue 3: Port Conflicts

**Problem**: Multiple workflows trying to use the same port.

**Solution**: Use dynamic port allocation:
```yaml
- name: Start Service
  run: |
    PORT=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
    echo "SERVICE_PORT=$PORT" >> $GITHUB_ENV
    ./start-service.sh --port $PORT
```

### Issue 4: Disk Space Issues

**Problem**: Runner disk fills up over time.

**Solution**: Implement cleanup:
```bash
# Add to crontab
0 2 * * * /home/github-runner/cleanup.sh

# cleanup.sh
#!/bin/bash
# Clean old Docker images
docker image prune -a -f --filter "until=24h"

# Clean npm cache
npm cache clean --force

# Clean old logs
find /home/github-runner -name "*.log" -mtime +7 -delete

# Clean old workspaces
find /home/github-runner -name "_work" -type d -mtime +1 -exec rm -rf {} +
```

### Issue 5: Network Configuration

**Problem**: Cannot reach external services.

**Solution**: Configure firewall and proxy settings:
```bash
# Allow outbound connections
sudo ufw allow out 80
sudo ufw allow out 443

# Configure proxy if needed
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
```

## 📋 Migration Checklist

### Pre-Migration
- [ ] Analyze current GitHub Actions usage and costs
- [ ] Calculate migration ROI and timeline
- [ ] Choose hosting infrastructure
- [ ] Set up test environment
- [ ] Document current workflow dependencies
- [ ] Plan rollback strategy

### During Migration
- [ ] Deploy self-hosted runner
- [ ] Test environment compatibility
- [ ] Migrate non-critical workflows first
- [ ] Run parallel testing period
- [ ] Monitor performance and resource usage
- [ ] Update documentation

### Post-Migration
- [ ] Validate all workflows are working
- [ ] Set up monitoring and alerting
- [ ] Implement backup and recovery procedures
- [ ] Train team on new processes
- [ ] Document lessons learned
- [ ] Plan for scaling and maintenance

## 📚 Additional Resources

### Useful Scripts and Tools

- **GitHub CLI**: `gh` for API interactions
- **Runner management**: Custom scripts in `/scripts` directory
- **Monitoring tools**: Prometheus, Grafana for advanced monitoring
- **Cost tracking**: Scripts to monitor actual vs. projected costs

### Documentation References

- [GitHub Self-Hosted Runners Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

---

Migration to self-hosted runners is a significant step that can provide substantial cost savings and improved performance. Take a gradual, well-planned approach to ensure success.

---
*Crafted by [Gabel @ Booplex.com](https://booplex.com) - 50% human, 50% AI, 100% trying our best.*