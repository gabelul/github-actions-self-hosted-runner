# Multi-Runner Setup Guide

This guide explains how to configure and manage multiple GitHub Actions runners on a single machine, enabling you to efficiently serve multiple repositories or handle parallel workflows.

## 🎯 Overview

Multi-runner deployments allow you to:
- **Serve multiple repositories** from a single server
- **Handle parallel workflows** with dedicated runners
- **Optimize resource utilization** across different projects
- **Isolate environments** for different teams or purposes
- **Scale cost-effectively** by maximizing hardware usage

## 🏗️ Architecture

### Single vs Multi-Runner

```
Single Runner Architecture:
┌─────────────────────────────┐
│        VPS/Server           │
│  ┌─────────────────────┐    │
│  │     Runner 1        │    │
│  │  ┌───────────────┐  │    │
│  │  │ GitHub Repo A │  │    │
│  │  └───────────────┘  │    │
│  └─────────────────────┘    │
└─────────────────────────────┘

Multi-Runner Architecture:
┌─────────────────────────────┐
│        VPS/Server           │
│  ┌───────────┐ ┌───────────┐│
│  │ Runner 1  │ │ Runner 2  ││
│  │┌─────────┐│ │┌─────────┐││
│  ││ Repo A  ││ ││ Repo B  │││
│  │└─────────┘│ │└─────────┘││
│  └───────────┘ └───────────┘│
│  ┌───────────┐ ┌───────────┐│
│  │ Runner 3  │ │ Runner 4  ││
│  │┌─────────┐│ │┌─────────┐││
│  ││ Repo C  ││ ││ Repo D  │││
│  │└─────────┘│ │└─────────┘││
│  └───────────┘ └───────────┘│
└─────────────────────────────┘
```

## 🚀 Quick Setup

### Method 1: Using the Add Runner Script

```bash
# Add first runner
./scripts/add-runner.sh --name project1 --token ghp_xxxx --repo owner/project1

# Add second runner
./scripts/add-runner.sh --name project2 --token ghp_xxxx --repo owner/project2

# Add third runner with custom labels
./scripts/add-runner.sh --name build-server --token ghp_xxxx --repo owner/project3 \
  --labels "self-hosted,Linux,X64,build,high-memory"
```

### Method 2: Using Setup Script Multiple Times

```bash
# Setup first runner
./setup.sh --token ghp_xxxx --repo owner/project1 --name runner-project1

# Setup second runner
./setup.sh --token ghp_xxxx --repo owner/project2 --name runner-project2

# Setup third runner
./setup.sh --token ghp_xxxx --repo owner/project3 --name runner-project3
```

### Method 3: Docker Multi-Runner

```bash
# Start first runner
docker-compose up -d

# Start second runner with different configuration
RUNNER_NAME=project2-runner \
GITHUB_REPOSITORY=owner/project2 \
docker-compose --project-name runner2 up -d

# Start third runner with GPU support
RUNNER_NAME=gpu-runner \
GITHUB_REPOSITORY=owner/ml-project \
RUNNER_LABELS=self-hosted,Linux,X64,gpu,cuda \
docker-compose --project-name gpu-runner up -d
```

## 🔧 Detailed Configuration

### SystemD Template Service Setup

The multi-runner architecture uses SystemD template services for management:

```bash
# Install template service
sudo cp systemd/github-runner@.service /etc/systemd/system/
sudo systemctl daemon-reload
```

### Directory Structure

```
/home/github-runner/
├── runners/
│   ├── project1/               # Runner instance directory
│   │   ├── run.sh             # Runner binary
│   │   ├── config.sh          # Configuration script
│   │   ├── .runner            # Runner configuration
│   │   └── _work/             # Job workspace
│   ├── project2/
│   │   └── ... (same structure)
│   ├── build-server/
│   │   └── ... (same structure)
│   └── shared-cache/          # Shared cache directory
├── shared/                    # Shared utilities and scripts
└── logs/                      # Centralized logs

/etc/github-runner/
├── project1.env              # Environment for project1 runner
├── project2.env              # Environment for project2 runner
├── build-server.env          # Environment for build-server runner
└── shared.env                # Common environment variables
```

### Environment Configuration

Create individual environment files for each runner:

**`/etc/github-runner/project1.env`**:
```bash
GITHUB_TOKEN=ghp_your_token_for_project1
GITHUB_REPOSITORY=owner/project1
RUNNER_NAME=project1-runner
RUNNER_LABELS=self-hosted,Linux,X64,project1
```

**`/etc/github-runner/project2.env`**:
```bash
GITHUB_TOKEN=ghp_your_token_for_project2
GITHUB_REPOSITORY=owner/project2
RUNNER_NAME=project2-runner
RUNNER_LABELS=self-hosted,Linux,X64,project2,testing
```

**`/etc/github-runner/build-server.env`**:
```bash
GITHUB_TOKEN=ghp_your_token_for_builds
GITHUB_REPOSITORY=owner/large-project
RUNNER_NAME=build-server
RUNNER_LABELS=self-hosted,Linux,X64,build,high-memory,dedicated
```

## 🎛️ Resource Management

### CPU and Memory Allocation

Configure resource limits in SystemD service files:

```ini
# In /etc/systemd/system/github-runner@.service

# Memory limits per runner instance
MemoryMax=2G
MemorySwapMax=1G

# CPU limits per runner (allows 2 cores per runner)
CPUQuota=200%
CPUWeight=100

# Process limits per runner
TasksMax=500
```

### Calculating Optimal Runner Count

```bash
# Get system resources
CPU_CORES=$(nproc)
MEMORY_GB=$(free -g | awk 'NR==2{printf "%.0f", $7}')

# Rule of thumb: 1 runner per 2 CPU cores, minimum 2GB RAM per runner
MAX_RUNNERS_BY_CPU=$((CPU_CORES / 2))
MAX_RUNNERS_BY_MEMORY=$((MEMORY_GB / 2))

# Take the limiting factor
RECOMMENDED_RUNNERS=$([ $MAX_RUNNERS_BY_CPU -lt $MAX_RUNNERS_BY_MEMORY ] && echo $MAX_RUNNERS_BY_CPU || echo $MAX_RUNNERS_BY_MEMORY)

# Apply sensible limits (minimum 1, maximum 8)
RECOMMENDED_RUNNERS=$([ $RECOMMENDED_RUNNERS -lt 1 ] && echo 1 || echo $RECOMMENDED_RUNNERS)
RECOMMENDED_RUNNERS=$([ $RECOMMENDED_RUNNERS -gt 8 ] && echo 8 || echo $RECOMMENDED_RUNNERS)

echo "Recommended runners for this system: $RECOMMENDED_RUNNERS"
```

### Resource Monitoring

```bash
# Monitor all runners
systemctl status github-runner@*

# Check resource usage
./scripts/health-check.sh --all --resources

# Monitor specific runner
./scripts/health-check.sh --runner project1 --verbose
```

## 🔐 Security and Isolation

### Runner Isolation

Each runner operates in its own isolated environment:

```bash
# Filesystem isolation
ReadWritePaths=/home/github-runner/runners/%i
ReadWritePaths=/home/github-runner/shared-cache
InaccessiblePaths=/home/github-runner/runners
ReadWritePaths=/home/github-runner/runners/%i

# Network isolation (if needed)
PrivateNetwork=yes
```

### Token Management

Best practices for managing multiple tokens:

1. **Use separate tokens** for each repository
2. **Rotate tokens regularly** (every 90 days)
3. **Use fine-grained permissions** where possible
4. **Store tokens securely** in environment files with restricted permissions

```bash
# Set secure permissions on environment files
sudo chmod 600 /etc/github-runner/*.env
sudo chown root:root /etc/github-runner/*.env
```

## 🎯 Use Cases and Patterns

### Pattern 1: Multi-Project Team

```bash
# Frontend project runner
./scripts/add-runner.sh --name frontend \
  --token ghp_frontend_token \
  --repo company/frontend-app \
  --labels "self-hosted,Linux,X64,frontend,nodejs"

# Backend project runner
./scripts/add-runner.sh --name backend \
  --token ghp_backend_token \
  --repo company/backend-api \
  --labels "self-hosted,Linux,X64,backend,java"

# Mobile project runner
./scripts/add-runner.sh --name mobile \
  --token ghp_mobile_token \
  --repo company/mobile-app \
  --labels "self-hosted,Linux,X64,mobile,react-native"
```

### Pattern 2: Environment-Based Runners

```bash
# Development environment runner
./scripts/add-runner.sh --name dev-runner \
  --token ghp_dev_token \
  --repo company/project \
  --labels "self-hosted,Linux,X64,development,testing"

# Staging environment runner
./scripts/add-runner.sh --name staging-runner \
  --token ghp_staging_token \
  --repo company/project \
  --labels "self-hosted,Linux,X64,staging,integration"

# Production deployment runner
./scripts/add-runner.sh --name prod-runner \
  --token ghp_prod_token \
  --repo company/project \
  --labels "self-hosted,Linux,X64,production,deployment"
```

### Pattern 3: Specialized Runners

```bash
# High-memory data processing runner
./scripts/add-runner.sh --name data-processor \
  --token ghp_data_token \
  --repo company/data-pipeline \
  --labels "self-hosted,Linux,X64,data,high-memory,python"

# GPU machine learning runner
./scripts/add-runner.sh --name ml-gpu \
  --token ghp_ml_token \
  --repo company/ml-models \
  --labels "self-hosted,Linux,X64,ml,gpu,cuda,pytorch"

# Security scanning runner
./scripts/add-runner.sh --name security-scanner \
  --token ghp_security_token \
  --repo company/security-tests \
  --labels "self-hosted,Linux,X64,security,scan,isolated"
```

## 📊 Management Commands

### Service Management

```bash
# Start all runners
sudo systemctl start github-runner@*

# Stop all runners
sudo systemctl stop github-runner@*

# Restart specific runner
sudo systemctl restart github-runner@project1

# Check status of all runners
sudo systemctl status github-runner@*

# Enable auto-start for specific runner
sudo systemctl enable github-runner@project1
```

### Log Management

```bash
# View logs for specific runner
sudo journalctl -u github-runner@project1 -f

# View logs for all runners
sudo journalctl -u github-runner@* -f

# View logs since specific time
sudo journalctl -u github-runner@project1 --since "2 hours ago"

# Export logs to file
sudo journalctl -u github-runner@project1 --since yesterday > runner-project1.log
```

### Health Monitoring

```bash
# Check health of all runners
./scripts/health-check.sh --all

# Detailed health report
./scripts/health-check.sh --all --verbose

# Monitor resources continuously
./scripts/health-check.sh --all --resources --continuous
```

## 🔄 Maintenance and Updates

### Updating Runners

```bash
# Update specific runner
./scripts/update-runner.sh project1

# Update all runners (one at a time to maintain availability)
./scripts/update-all-runners.sh --sequential

# Update with zero downtime (requires multiple runners)
./scripts/update-all-runners.sh --rolling
```

### Adding New Runners

```bash
# Interactive setup
./scripts/add-runner.sh --interactive

# Automated setup
./scripts/add-runner.sh \
  --name new-project \
  --token ghp_new_token \
  --repo owner/new-project \
  --labels "self-hosted,Linux,X64,new-project" \
  --auto-start
```

### Removing Runners

```bash
# Remove specific runner
./scripts/remove-runner.sh project1

# Remove runner with cleanup
./scripts/remove-runner.sh project1 --cleanup --force
```

## 🚨 Troubleshooting

### Common Issues

#### Runner Not Starting

```bash
# Check service status
sudo systemctl status github-runner@project1

# Check logs
sudo journalctl -u github-runner@project1 -f

# Verify configuration
cat /etc/github-runner/project1.env

# Test runner manually
sudo -u github-runner /home/github-runner/runners/project1/run.sh
```

#### Resource Conflicts

```bash
# Check resource usage
./scripts/health-check.sh --all --resources

# Check for competing processes
ps aux | grep github-runner

# Monitor disk space
df -h /home/github-runner

# Check memory usage per runner
sudo systemctl show github-runner@* --property=MemoryCurrent
```

#### Token Issues

```bash
# Test token validity
curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user

# Check repository access
curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/repos/owner/repo

# Rotate token
./scripts/rotate-token.sh project1 new_token_here
```

### Performance Optimization

#### Cache Sharing

```bash
# Setup shared cache directory
sudo mkdir -p /home/github-runner/shared-cache/{npm,yarn,pip,docker-layers}
sudo chown -R github-runner:github-runner /home/github-runner/shared-cache

# Configure runners to use shared cache
echo 'CACHE_DIR=/home/github-runner/shared-cache' >> /etc/github-runner/shared.env
```

#### Build Parallelization

Configure parallel builds in workflow files:

```yaml
# .github/workflows/build.yml
jobs:
  build-frontend:
    runs-on: [self-hosted, Linux, X64, frontend]
    steps:
      - uses: actions/checkout@v4
      - run: npm run build

  build-backend:
    runs-on: [self-hosted, Linux, X64, backend]
    steps:
      - uses: actions/checkout@v4
      - run: mvn clean package

  test-integration:
    runs-on: [self-hosted, Linux, X64, testing]
    needs: [build-frontend, build-backend]
    steps:
      - run: npm run test:integration
```

## 📈 Scaling Strategies

### Vertical Scaling (Same Machine)

1. **Increase runner count** up to system limits
2. **Optimize resource allocation** per runner
3. **Implement shared caching** to reduce redundancy
4. **Use specialized runners** for different workloads

### Horizontal Scaling (Multiple Machines)

1. **Deploy runners across multiple VPS** instances
2. **Use load balancing** with GitHub's runner groups
3. **Implement centralized monitoring** across machines
4. **Coordinate deployments** using infrastructure as code

## 🔗 Integration Examples

### GitHub Workflow Targeting

```yaml
# Target specific runner
jobs:
  build:
    runs-on: [self-hosted, Linux, X64, project1]

  test:
    runs-on: [self-hosted, Linux, X64, testing]

  deploy:
    runs-on: [self-hosted, Linux, X64, production]
```

### Conditional Runner Selection

```yaml
jobs:
  build:
    runs-on: >
      ${{
        github.ref == 'refs/heads/main' &&
        '[self-hosted, Linux, X64, production]' ||
        '[self-hosted, Linux, X64, development]'
      }}
```

---

Multi-runner setups maximize the value of your self-hosted infrastructure while providing flexibility for different projects and workflows. This approach is essential for teams looking to scale their GitHub Actions usage cost-effectively.

---
*Crafted by [Gabel @ Booplex.com](https://booplex.com) - 50% human, 50% AI, 100% trying our best.*