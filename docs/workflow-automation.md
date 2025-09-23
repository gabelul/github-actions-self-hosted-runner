# Workflow Automation Guide

This comprehensive guide covers the workflow automation system that helps you migrate existing GitHub Actions workflows to self-hosted runners and generate new workflows optimized for self-hosted execution.

## 🔄 Overview

The workflow automation system consists of:
- **workflow-helper.sh** - Main automation script
- **6 workflow templates** - Pre-built workflows for common scenarios
- **Interactive migration** - User-friendly interface for workflow conversion
- **Cost analysis** - Calculate potential savings
- **Safe migration** - Backups and rollback capabilities
- **Integrated workflow management** - Built right into runner management (NEW!)

## ⭐ Integrated Workflow Management (NEW!)

**Workflow migration is now built directly into the runner management interface!** This is the easiest way to analyze and migrate workflows:

### Access Method

```bash
./setup.sh
# → Select "Manage existing runners"
# → Choose "View connected repositories"
# → Select any repository to see workflow analysis
```

### What You Get

**🔍 Real-time Analysis:**
- **API-powered analysis** - Fetches workflows via GitHub API (no cloning!)
- Shows which workflows use GitHub-hosted vs self-hosted runners
- Calculates potential cost savings for each repository (e.g., "~$3.20/month")
- Updates analysis based on current repository state
- **Lightning fast** - Especially for large repositories

**🎯 Smart Migration Options:**
- **Migrate all workflows** - Convert everything in one operation
- **Select specific workflows** - Choose exactly which ones to migrate
- **Preview changes** - See what will change before applying
- **Safe with automatic backups** - Timestamped backups with easy rollback

**💰 Cost Insights:**
- Per-repository savings calculation
- Monthly cost reduction estimates
- Break-even analysis for self-hosted runners

### Benefits of Integrated Approach

✅ **No context switching** - Manage runners and workflows in one place
✅ **Always current** - Analysis reflects the latest repository state
✅ **Seamless workflow** - Setup → analyze → migrate in one session
✅ **Error handling** - Built-in authentication and error recovery
✅ **User-friendly** - Guided interface with clear options
✅ **API-powered** - No repository cloning, much faster analysis
✅ **Smart authentication** - Uses GitHub CLI or prompts for token

### When to Use Integrated vs Standalone

**Use Integrated Management (Recommended) When:**
- You're already managing runners
- You want the simplest workflow
- You need real-time repository analysis
- You prefer guided interfaces

**Use Standalone Scripts When:**
- You want to automate migration in scripts
- You're working with local repository clones
- You need advanced customization options
- You're integrating with CI/CD systems

## 🚀 Quick Start

### 1. Setup Your Self-Hosted Runner

First, ensure you have a working self-hosted runner:

```bash
./setup.sh --token ghp_your_token --repo owner/your-repo
```

### 2. Analyze Your Repository

See what workflows you have and potential savings:

```bash
./scripts/workflow-helper.sh analyze /path/to/your/repository
```

### 3. Migrate Your Workflows

Convert existing workflows to use self-hosted runners:

```bash
./scripts/workflow-helper.sh migrate /path/to/your/repository
```

### 4. Generate New Workflows

Create new workflows from templates:

```bash
./scripts/workflow-helper.sh generate
```

## 📋 Available Commands

### `analyze` - Repository Analysis

Analyzes your repository's GitHub Actions usage and calculates migration potential.

```bash
./scripts/workflow-helper.sh analyze <repo_path> [options]
```

**Example Output:**
```
📊 GitHub Actions Usage Analysis
===============================

  ci.yml: GitHub-hosted (ubuntu-latest)
  tests.yml: GitHub-hosted (ubuntu-latest)
  deploy.yml: Self-hosted (self-hosted)
  windows-test.yml: GitHub-hosted (windows-latest)

Summary:
  Total workflows: 4
  GitHub-hosted runners: 3
  Self-hosted runners: 1
  Custom/Unknown: 0

💰 Migration Potential:
  • 3 workflow(s) can be migrated to self-hosted runners
  • Estimated monthly savings: ~$24 USD
    (Based on 300 minutes/month at $0.008/minute for Linux)

To migrate these workflows, run:
  ./scripts/workflow-helper.sh migrate /path/to/your/repository
```

### `migrate` - Interactive Workflow Migration

Migrates existing workflows to use self-hosted runners with interactive selection.

```bash
./scripts/workflow-helper.sh migrate <repo_path> [options]
```

**Options:**
- `--runner RUNNER` - Target runner (default: self-hosted)
- `--dry-run` - Preview changes without applying
- `--no-backup` - Skip creating backups
- `--force` - Skip confirmation prompts
- `--verbose` - Enable detailed output

**Interactive Process:**

1. **Workflow Discovery**
   - Scans `.github/workflows/` directory
   - Finds all `.yml` and `.yaml` files
   - Identifies current runner configurations

2. **Interactive Selection**
   ```
   Found 5 workflow file(s):

   [x] 1. ci.yml (currently: ubuntu-latest)
   [x] 2. tests.yml (currently: ubuntu-latest)
   [ ] 3. windows-build.yml (currently: windows-latest)
   [x] 4. deploy.yml (currently: ubuntu-latest)
   [ ] 5. security.yml (currently: ubuntu-latest)

   Selection options:
     [a]ll - Select all workflows
     [n]one - Deselect all workflows
     [i]nvert - Invert current selection
     [1-9] - Toggle specific workflow
     [d]one - Proceed with current selection
   ```

3. **Preview Changes**
   ```
   Preview of changes:
   ==================

   ci.yml:
     Line 15:    runs-on: ubuntu-latest
     After:      runs-on: self-hosted
   ```

4. **Safe Migration**
   - Creates timestamped backups
   - Applies changes atomically
   - Provides rollback information

### `generate` - Workflow Generator

Creates new workflows from templates with interactive wizard.

```bash
./scripts/workflow-helper.sh generate
```

**Wizard Process:**

1. **Workflow Type Selection**
   ```
   Available workflow types:
   1. CI (Continuous Integration)
   2. CD (Continuous Deployment)
   3. Test (Testing only)
   4. Build (Build artifacts)
   5. Custom (Start from scratch)

   Select workflow type [1-5]:
   ```

2. **Language/Framework Selection**
   ```
   Programming language/framework:
   1. Node.js
   2. Python
   3. Java
   4. Go
   5. Docker
   6. Generic/Other

   Select language [1-6]:
   ```

3. **Configuration**
   - Workflow name
   - Output directory
   - Custom parameters

4. **Generation**
   - Creates workflow file
   - Uses self-hosted runners by default
   - Includes best practices

### `list-templates` - Available Templates

Shows all available workflow templates.

```bash
./scripts/workflow-helper.sh list-templates
```

**Available Templates:**

- **node-ci** - Node.js Continuous Integration
- **python-ci** - Python Continuous Integration
- **docker-build** - Docker build and push
- **deploy-prod** - Production deployment
- **matrix-test** - Multi-environment testing
- **security-scan** - Comprehensive security scanning

## 📚 Workflow Templates

### Node.js CI Template (`node-ci.yml.template`)

**Features:**
- Multi-version Node.js testing (16, 18, 20)
- ESLint and Prettier code quality checks
- TypeScript type checking
- Unit and integration tests
- Coverage reporting with Codecov
- Security scanning with Snyk
- Bundle size analysis
- E2E testing with Cypress
- Build artifact generation

**Generated Structure:**
```yaml
name: Node.js CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  lint:
    runs-on: self-hosted
    # ... linting and formatting checks

  test:
    runs-on: self-hosted
    strategy:
      matrix:
        node-version: [16, 18, 20]
    # ... testing with multiple Node versions

  security:
    runs-on: self-hosted
    # ... dependency auditing and security scans

  build:
    runs-on: self-hosted
    # ... application build and artifact generation
```

### Python CI Template (`python-ci.yml.template`)

**Features:**
- Multi-version Python testing (3.9, 3.10, 3.11, 3.12)
- Code quality with flake8, black, isort
- Type checking with mypy
- Testing with pytest and coverage
- Security scanning with safety and bandit
- Package building and validation
- Documentation generation with Sphinx

### Docker Build Template (`docker-build.yml.template`)

**Features:**
- Multi-architecture builds (AMD64, ARM64)
- Docker layer caching
- Security scanning with Trivy
- SBOM generation
- Multi-registry push support
- Image optimization
- Deployment automation
- Health checks

### Production Deployment Template (`deploy-prod.yml.template`)

**Features:**
- Manual approval gates for production
- Environment-specific configurations
- Database migration support
- Health checks and smoke tests
- Automatic rollback on failure
- Deployment notifications
- Blue-green deployment patterns

### Matrix Testing Template (`matrix-test.yml.template`)

**Features:**
- Multi-platform testing simulation
- Multiple runtime versions
- Different dependency combinations
- Performance testing matrices
- Result aggregation
- Comprehensive reporting
- Parallel execution optimization

### Security Scanning Template (`security-scan.yml.template`)

**Features:**
- Static Application Security Testing (SAST)
- Dependency vulnerability scanning
- Secret detection in code and history
- Container security scanning
- License compliance checking
- Security policy enforcement
- Comprehensive reporting

## 🛠️ Advanced Usage

### Custom Runner Labels

Use specific runner labels for targeted deployment:

```bash
# Use runners with specific labels
./scripts/workflow-helper.sh migrate /path/to/repo --runner "[self-hosted, Linux, X64, nodejs]"

# Use different runners for different environments
./scripts/workflow-helper.sh migrate /path/to/repo --runner "production-runners"
```

### Batch Migration

Migrate multiple repositories:

```bash
#!/bin/bash
REPOSITORIES=(
    "/home/user/project1"
    "/home/user/project2"
    "/home/user/project3"
)

for repo in "${REPOSITORIES[@]}"; do
    echo "Migrating $repo..."
    ./scripts/workflow-helper.sh migrate "$repo" --force
done
```

### Integration with CI/CD

Automate workflow migration as part of your infrastructure updates:

```yaml
name: Infrastructure Update
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday

jobs:
  migrate-workflows:
    runs-on: self-hosted
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Update workflow configurations
        run: |
          for repo in $(find /repos -name ".github" -type d); do
            repo_root=$(dirname "$repo")
            ./scripts/workflow-helper.sh analyze "$repo_root"
          done
```

### Custom Templates

Create your own workflow templates:

1. **Create Template File**
   ```bash
   # Create new template
   touch scripts/workflow-templates/my-custom.yml.template
   ```

2. **Template Format**
   ```yaml
   # Description: Your custom workflow description

   name: Custom Workflow

   on:
     push:
       branches: [ main ]

   jobs:
     custom:
       runs-on: self-hosted
       steps:
         - uses: actions/checkout@v4
         - name: Custom step
           run: echo "Custom logic here"
   ```

3. **Use Custom Template**
   ```bash
   ./scripts/workflow-helper.sh template my-custom
   ```

## 📊 Cost Analysis Deep Dive

### Understanding the Analysis

The cost analysis considers:

1. **Current Usage Patterns**
   - Number of GitHub-hosted workflows
   - Estimated minutes per workflow
   - GitHub Actions pricing tiers

2. **Migration Potential**
   - Workflows that can be migrated
   - Workflows that should stay on GitHub (Windows, macOS)
   - Complex workflows requiring manual review

3. **Savings Calculation**
   ```
   Monthly Savings = (Migrated Workflows × Minutes/Workflow × $0.008) - Server Cost
   ```

### Example Calculations

**Scenario 1: Small Project**
- 3 workflows using ubuntu-latest
- ~100 minutes/month total
- Current cost: $0.80/month
- Self-hosted cost: $12/month VPS
- **Result**: Not cost-effective (break-even at ~1,500 minutes)

**Scenario 2: Active Development**
- 8 workflows using ubuntu-latest
- ~2,000 minutes/month total
- Current cost: $16/month
- Self-hosted cost: $12/month VPS
- **Result**: Save $4/month ($48/year)

**Scenario 3: Enterprise Usage**
- 15 workflows using ubuntu-latest
- ~5,000 minutes/month total
- Current cost: $40/month
- Self-hosted cost: $20/month powerful VPS
- **Result**: Save $20/month ($240/year)

## 🔒 Security Considerations

### Safe Migration Practices

1. **Always Create Backups**
   ```bash
   # Backups are created by default
   ./scripts/workflow-helper.sh migrate /path/to/repo

   # Skip backups only if absolutely necessary
   ./scripts/workflow-helper.sh migrate /path/to/repo --no-backup
   ```

2. **Test Before Production**
   ```bash
   # Use dry-run to preview changes
   ./scripts/workflow-helper.sh migrate /path/to/repo --dry-run
   ```

3. **Gradual Migration**
   ```bash
   # Migrate non-critical workflows first
   # Test thoroughly
   # Then migrate critical production workflows
   ```

### Security Template Usage

The security scanning template includes:

- **Secret Detection**: TruffleHog, GitLeaks
- **Dependency Scanning**: Snyk, npm audit
- **Static Analysis**: ESLint security rules, Semgrep
- **Container Scanning**: Trivy, Docker Bench
- **Compliance**: License checking, policy validation

## 🐛 Troubleshooting

### Common Issues

#### Migration Failures

**Problem**: Migration fails with "file not found"
```bash
Error: No .github/workflows directory found
```

**Solution**:
```bash
# Ensure you're in the correct repository directory
cd /path/to/your/repository
ls -la .github/workflows/

# Or provide absolute path
./scripts/workflow-helper.sh migrate /full/path/to/repository
```

#### Interactive Selection Issues

**Problem**: Selection interface not responding

**Solution**:
```bash
# Use non-interactive mode
./scripts/workflow-helper.sh migrate /path/to/repo --force

# Or use dry-run first
./scripts/workflow-helper.sh migrate /path/to/repo --dry-run
```

#### Template Generation Errors

**Problem**: Template generation fails

**Solution**:
```bash
# Check templates directory exists
ls -la scripts/workflow-templates/

# Verify template file permissions
chmod +r scripts/workflow-templates/*.template

# Use verbose mode for debugging
./scripts/workflow-helper.sh generate --verbose
```

### Getting Help

1. **Check Tool Help**
   ```bash
   ./scripts/workflow-helper.sh --help
   ```

2. **Enable Verbose Output**
   ```bash
   ./scripts/workflow-helper.sh migrate /path/to/repo --verbose
   ```

3. **Check Logs**
   ```bash
   # Migration logs
   tail -f ~/.github-runner-backups/migration.log

   # Runner logs
   journalctl -u github-runner -f
   ```

4. **Rollback if Needed**
   ```bash
   # Find backup directory
   ls -la ~/.github-runner-backups/

   # Restore from backup
   cp ~/.github-runner-backups/TIMESTAMP/*.backup .github/workflows/
   ```

## 🎯 Best Practices

### Pre-Migration

1. **Test Your Self-Hosted Runner**
   ```bash
   # Ensure runner is active and working
   systemctl status github-runner
   ```

2. **Analyze Repository Thoroughly**
   ```bash
   ./scripts/workflow-helper.sh analyze /path/to/repo
   ```

3. **Review Complex Workflows Manually**
   - Matrix strategies
   - Multi-OS workflows
   - Workflows with special requirements

### During Migration

1. **Start Small**
   - Migrate one workflow at a time initially
   - Test each migration thoroughly
   - Build confidence before bulk migration

2. **Use Dry Run**
   ```bash
   # Always preview changes first
   ./scripts/workflow-helper.sh migrate /path/to/repo --dry-run
   ```

3. **Keep Backups**
   - Don't use `--no-backup` unless necessary
   - Verify backup creation before proceeding

### Post-Migration

1. **Test All Workflows**
   ```bash
   # Trigger workflows manually to test
   git commit --allow-empty -m "Test self-hosted runner"
   git push
   ```

2. **Monitor Performance**
   ```bash
   # Check runner health
   ./scripts/health-check-runner.sh

   # Monitor resource usage
   htop
   ```

3. **Document Changes**
   - Update team documentation
   - Document any custom configurations
   - Share migration results with team

### Template Usage

1. **Customize Templates**
   - Review generated workflows
   - Adjust for your specific needs
   - Add project-specific steps

2. **Version Management**
   - Pin action versions for stability
   - Update actions regularly for security
   - Test action updates in non-production first

3. **Resource Planning**
   - Configure appropriate runner labels
   - Plan for concurrent job limits
   - Monitor resource usage patterns

## 📈 Monitoring and Optimization

### Performance Monitoring

```bash
# Check workflow execution times
./scripts/workflow-helper.sh analyze /path/to/repo --performance

# Monitor system resources
./scripts/health-check-runner.sh --detailed

# Check runner queue status
./scripts/workflow-helper.sh status
```

### Cost Optimization

```bash
# Regular cost analysis
./scripts/workflow-helper.sh analyze /path/to/repo --cost-report

# Identify optimization opportunities
./scripts/workflow-helper.sh optimize /path/to/repo
```

### Maintenance

```bash
# Update workflow templates
./scripts/workflow-helper.sh update-templates

# Clean up old backups
find ~/.github-runner-backups -mtime +30 -delete

# Update runner software
./scripts/update-runner.sh
```

This comprehensive guide covers all aspects of the workflow automation system. For additional help, refer to the main [README.md](../README.md) and [CLAUDE.md](../CLAUDE.md) documentation.