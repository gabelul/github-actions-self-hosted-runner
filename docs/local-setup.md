# Local Setup Guide - GitHub Self-Hosted Runner

Complete guide for setting up GitHub Actions self-hosted runners on local development machines (macOS, Linux, Windows WSL2) for personal projects, testing, and development workflows.

## 🎯 Overview

Local runners are perfect for:
- **Personal projects**: No GitHub Actions minutes costs
- **Development testing**: Test workflows before pushing to production
- **Private repositories**: Keep sensitive code on your machine
- **Custom environments**: Use your specific development setup

## 🚀 Quick Local Setup

### Prerequisites

- macOS 10.15+, Ubuntu 18.04+, or Windows 10 with WSL2
- Admin/sudo privileges
- GitHub Personal Access Token
- Target GitHub repository

### One-Command Installation

```bash
# Download and run universal installer (detects local environment)
curl -fsSL https://raw.githubusercontent.com/gabelul/github-self-hosted-runner/main/setup.sh | bash -s -- \
  --token ghp_your_personal_access_token_here \
  --repo owner/repository-name \
  --environment local
```

## 📋 Platform-Specific Setup

### macOS Setup

#### Prerequisites

```bash
# 1. Install Xcode Command Line Tools (if not installed)
xcode-select --install

# 2. Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 3. Install required packages
brew install curl wget git
```

#### Installation

```bash
# 1. Download setup script
curl -o setup.sh https://raw.githubusercontent.com/gabelul/github-self-hosted-runner/main/setup.sh
chmod +x setup.sh

# 2. Run setup (interactive mode)
./setup.sh

# OR with parameters
./setup.sh \
  --token ghp_your_personal_access_token_here \
  --repo owner/repository-name \
  --name macbook-runner \
  --environment local
```

#### macOS Service Management

```bash
# 1. Check runner status (macOS uses launchd)
sudo launchctl list | grep github-runner

# 2. Start runner service
sudo launchctl load /Library/LaunchDaemons/com.github.runner.plist

# 3. Stop runner service
sudo launchctl unload /Library/LaunchDaemons/com.github.runner.plist

# 4. View runner logs
tail -f /usr/local/var/log/github-runner.log
```

### Linux (Ubuntu/Debian) Setup

#### Prerequisites

```bash
# 1. Update package manager
sudo apt update

# 2. Install required packages
sudo apt install -y curl wget git build-essential sudo

# 3. Install Docker (optional, for Docker workflows)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

#### Installation

```bash
# 1. Download and run setup
curl -o setup.sh https://raw.githubusercontent.com/gabelul/github-self-hosted-runner/main/setup.sh
chmod +x setup.sh

./setup.sh \
  --token ghp_your_personal_access_token_here \
  --repo owner/repository-name \
  --name linux-dev-runner \
  --environment local
```

#### Linux Service Management

```bash
# 1. Check runner status
sudo systemctl status github-runner

# 2. Start runner
sudo systemctl start github-runner

# 3. Stop runner
sudo systemctl stop github-runner

# 4. Enable auto-start (optional for local dev)
sudo systemctl enable github-runner

# 5. View logs
sudo journalctl -u github-runner -f
```

### Windows WSL2 Setup

#### Prerequisites

```bash
# 1. Ensure you're in WSL2 (not WSL1)
wsl -l -v

# 2. Update WSL2 Ubuntu
sudo apt update && sudo apt upgrade -y

# 3. Install required packages
sudo apt install -y curl wget git build-essential

# 4. Install Docker Desktop for Windows (if needed)
# Download from https://docker.com/products/docker-desktop
```

#### Installation

```bash
# 1. Run setup in WSL2
curl -o setup.sh https://raw.githubusercontent.com/gabelul/github-self-hosted-runner/main/setup.sh
chmod +x setup.sh

./setup.sh \
  --token ghp_your_personal_access_token_here \
  --repo owner/repository-name \
  --name wsl2-runner \
  --environment local
```

#### WSL2 Service Management

```bash
# 1. Check runner status
sudo systemctl status github-runner

# 2. Auto-start runner when WSL2 starts
# Add to ~/.bashrc or ~/.zshrc:
echo 'sudo systemctl start github-runner' >> ~/.bashrc

# 3. Windows Task Scheduler for auto-start (optional)
# Create task to run: wsl -e sudo systemctl start github-runner
```

## 🔧 Local Development Configuration

### Development-Friendly Settings

```bash
# 1. Configure runner for development use
./setup.sh \
  --token ghp_your_token \
  --repo owner/repo \
  --name dev-runner \
  --environment local \
  --labels "self-hosted,local,development" \
  --ephemeral false \
  --auto-update false
```

### IDE Integration

#### VS Code Integration

```json
// .vscode/settings.json
{
  "github-actions.workflows.pinned.workflows": [".github/workflows/ci.yml"],
  "github-actions.workflows.pinned.refresh.enabled": true,
  "terminal.integrated.env.osx": {
    "GITHUB_ACTIONS_RUNNER_LOCAL": "true"
  }
}
```

#### JetBrains IDE Integration

```bash
# 1. Add run configuration for testing workflows locally
# Run Configuration -> Shell Script
# Script: gh act --job build --verbose
# Working Directory: $ProjectFileDir$

# 2. Install act for local workflow testing
# macOS
brew install act

# Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# Usage
act -j build  # Run specific job locally
```

### Local Testing Setup

```bash
# 1. Install GitHub CLI for testing
# macOS
brew install gh

# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt update && sudo apt install gh

# 2. Setup local workflow testing
gh auth login
gh workflow list
gh workflow run ci.yml

# 3. Monitor local runner activity
tail -f /home/github-runner/_diag/Runner_*.log
```

## 🔒 Local Security Configuration

### Minimal Security (Development)

```bash
# 1. Create runner user (already done by setup script)
id github-runner

# 2. Configure basic permissions
sudo usermod -aG docker github-runner  # If Docker is needed

# 3. Setup basic firewall (optional for local)
# macOS
sudo pfctl -f /etc/pf.conf

# Linux
sudo ufw enable
sudo ufw allow out 443
sudo ufw allow out 80
```

### Enhanced Security (Shared Machines)

```bash
# 1. Restrict runner user permissions
sudo usermod -s /bin/bash github-runner
sudo passwd github-runner  # Set strong password

# 2. Configure sudo restrictions
sudo visudo -f /etc/sudoers.d/github-runner
# Add: github-runner ALL=(ALL) NOPASSWD: /bin/systemctl start github-runner, /bin/systemctl stop github-runner

# 3. File system permissions
sudo chmod 700 /home/github-runner
sudo chmod 600 /home/github-runner/.credentials

# 4. Network restrictions (if needed)
# Block unnecessary outbound connections
```

## 📊 Local Monitoring

### Simple Status Checking

```bash
# 1. Create local status script
cat > ~/check-runner.sh << 'EOF'
#!/bin/bash
# Local GitHub Runner Status Check

echo "=== GitHub Runner Status ==="
echo "Date: $(date)"
echo ""

# Check service status
if pgrep -f "Runner.Listener" >/dev/null; then
    echo "✅ Runner Process: RUNNING (PID: $(pgrep -f "Runner.Listener"))"
else
    echo "❌ Runner Process: NOT RUNNING"
fi

# Check system resources
echo "💻 System Resources:"
echo "   CPU Usage: $(top -l 1 -s 0 | grep "CPU usage" | awk '{print $3}' 2>/dev/null || echo "N/A")"
echo "   Memory Usage: $(vm_stat | awk '/Pages active/ {printf "%.1f%%", $3/$(vm_stat | awk "/Pages free/ {print \$3}" | tr -d ":")*100}' 2>/dev/null || free | awk '/Mem:/ {printf "%.1f%%", $3/$2*100}')"
echo "   Disk Space: $(df -h ~ | awk 'NR==2 {print "Used: " $3 " (" $5 ")"}')"

# Check GitHub connectivity
if curl -s https://api.github.com >/dev/null; then
    echo "✅ GitHub Connection: OK"
else
    echo "❌ GitHub Connection: FAILED"
fi

# Recent activity
echo ""
echo "📝 Recent Logs:"
if [[ "$OSTYPE" == "darwin"* ]]; then
    tail -5 /usr/local/var/log/github-runner.log 2>/dev/null || echo "No logs available"
else
    sudo journalctl -u github-runner --no-pager -n 5 2>/dev/null || echo "No logs available"
fi
EOF

chmod +x ~/check-runner.sh

# 2. Run status check
~/check-runner.sh
```

### Performance Monitoring

```bash
# 1. Monitor runner resource usage
# macOS
top -pid $(pgrep -f "Runner.Listener")

# Linux
htop -p $(pgrep -f "Runner.Listener")

# 2. Monitor job execution
watch -n 5 'ls -la /home/github-runner/_work'

# 3. Network monitoring
# macOS
nettop -p $(pgrep -f "Runner.Listener")

# Linux
sudo netstat -tuln | grep $(pgrep -f "Runner.Listener")
```

### Log Management

```bash
# 1. Configure log rotation for local development
# macOS - create ~/Library/LaunchAgents/com.github.runner.logrotate.plist
cat > ~/Library/LaunchAgents/com.github.runner.logrotate.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.github.runner.logrotate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>find /usr/local/var/log -name "github-runner*.log" -size +10M -delete</string>
    </array>
    <key>StartInterval</key>
    <integer>86400</integer>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.github.runner.logrotate.plist

# 2. Linux log rotation (already handled by systemd)
sudo journalctl --vacuum-time=7d
```

## 🔄 Local Development Workflows

### Personal Project Setup

```bash
# 1. Setup runner for personal repository
./setup.sh \
  --token ghp_your_token \
  --repo gabelul/your-repo-name \
  --name local-dev \
  --labels "self-hosted,local,personal"

# 2. Create simple workflow for testing
mkdir -p .github/workflows
cat > .github/workflows/local-test.yml << 'EOF'
name: Local Development Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: [self-hosted, local]

    steps:
    - uses: actions/checkout@v4

    - name: Environment Info
      run: |
        echo "Running on: $(hostname)"
        echo "OS: $(uname -a)"
        echo "Current directory: $(pwd)"
        echo "Available space: $(df -h . | tail -1)"

    - name: Install Dependencies
      run: |
        # Add your dependency installation commands
        echo "Installing dependencies..."

    - name: Run Tests
      run: |
        # Add your test commands
        echo "Running tests..."

    - name: Build Project
      run: |
        # Add your build commands
        echo "Building project..."
EOF

# 3. Test the workflow
git add .github/workflows/local-test.yml
git commit -m "Add local runner test workflow"
git push origin main
```

### Multi-Project Setup

```bash
# 1. Setup runners for different projects
./setup.sh --token TOKEN --repo user/project1 --name project1-runner
./setup.sh --token TOKEN --repo user/project2 --name project2-runner
./setup.sh --token TOKEN --repo user/project3 --name project3-runner

# 2. List all local runners
# macOS
sudo launchctl list | grep github-runner

# Linux
sudo systemctl list-units | grep github-runner

# 3. Start/stop specific runners
# macOS
sudo launchctl load /Library/LaunchDaemons/com.github.runner.project1.plist
sudo launchctl unload /Library/LaunchDaemons/com.github.runner.project1.plist

# Linux
sudo systemctl start github-runner@project1
sudo systemctl stop github-runner@project1
```

### Testing and Development

```bash
# 1. Setup test runner with ephemeral mode
./setup.sh \
  --token TOKEN \
  --repo user/test-repo \
  --name test-runner \
  --ephemeral true \
  --labels "self-hosted,local,testing"

# 2. Local workflow testing with act
# Install act (if not already installed)
# Test workflow locally before pushing
act -j test --verbose

# 3. Debug workflow issues
act -j test --verbose --secret GITHUB_TOKEN=your_token
```

## 🛠️ Local Runner Management

### Start/Stop Scripts

```bash
# 1. Create convenience scripts
# Start all runners
cat > ~/start-runners.sh << 'EOF'
#!/bin/bash
echo "Starting all GitHub runners..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    for plist in /Library/LaunchDaemons/com.github.runner.*.plist; do
        if [ -f "$plist" ]; then
            echo "Loading $(basename "$plist")..."
            sudo launchctl load "$plist"
        fi
    done
else
    # Linux
    sudo systemctl start github-runner@*
fi

echo "All runners started!"
EOF

# Stop all runners
cat > ~/stop-runners.sh << 'EOF'
#!/bin/bash
echo "Stopping all GitHub runners..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    for plist in /Library/LaunchDaemons/com.github.runner.*.plist; do
        if [ -f "$plist" ]; then
            echo "Unloading $(basename "$plist")..."
            sudo launchctl unload "$plist"
        fi
    done
else
    # Linux
    sudo systemctl stop github-runner@*
fi

echo "All runners stopped!"
EOF

chmod +x ~/start-runners.sh ~/stop-runners.sh

# 2. Use the scripts
~/start-runners.sh
~/stop-runners.sh
```

### Maintenance Tasks

```bash
# 1. Update runner to latest version
~/stop-runners.sh
curl -o setup.sh https://raw.githubusercontent.com/gabelul/github-self-hosted-runner/main/setup.sh
chmod +x setup.sh
# Re-run setup with same parameters
~/start-runners.sh

# 2. Clean up old job artifacts
find /home/github-runner/_work -type d -name "*" -mtime +7 -exec rm -rf {} + 2>/dev/null

# 3. Check disk usage
du -sh /home/github-runner/*
df -h

# 4. Backup configuration
tar czf ~/runner-backup-$(date +%Y%m%d).tar.gz \
    /home/github-runner/.runner \
    /home/github-runner/.credentials \
    2>/dev/null
```

## 🐛 Local Troubleshooting

### Common Local Issues

#### Runner Won't Start

```bash
# 1. Check if port is available (rare issue)
# macOS
lsof -i :8080

# Linux
sudo netstat -tuln | grep 8080

# 2. Check permissions
ls -la /home/github-runner/
id github-runner

# 3. Check system logs
# macOS
sudo log show --predicate 'subsystem == "com.github.runner"' --last 1h

# Linux
sudo journalctl -u github-runner -n 50
```

#### Token Issues

```bash
# 1. Verify token permissions
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# 2. Check repository access
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/OWNER/REPO

# 3. Regenerate token if needed
# Go to GitHub Settings > Developer settings > Personal access tokens
# Delete old token and create new one with same permissions
```

#### Job Execution Issues

```bash
# 1. Check job logs
ls -la /home/github-runner/_work/*/
cat /home/github-runner/_work/*/_temp/_runner_file_commands/*.txt

# 2. Test job steps manually
sudo -u github-runner bash
cd /home/github-runner/_work/repo-name/
# Run job commands manually

# 3. Check environment variables
sudo -u github-runner env | grep -i github
```

### Performance Issues

```bash
# 1. Check if system is overloaded
# macOS
top -l 1 -s 0 | head -20

# Linux
htop

# 2. Check available disk space
df -h

# 3. Monitor memory usage
# macOS
vm_stat

# Linux
free -h

# 4. Check for resource-intensive processes
ps aux | head -10
```

### Network Issues

```bash
# 1. Test GitHub connectivity
ping github.com
curl -I https://api.github.com

# 2. Check DNS resolution
nslookup github.com
nslookup api.github.com

# 3. Test from runner user context
sudo -u github-runner curl -I https://api.github.com

# 4. Check proxy settings (if applicable)
echo $HTTP_PROXY
echo $HTTPS_PROXY
```

## 📈 Local Development Best Practices

### Security Best Practices

1. **Use separate tokens**: Create dedicated tokens for local runners
2. **Limit repository access**: Only grant access to repositories you're actively working on
3. **Regular updates**: Keep runner updated to latest version
4. **Monitor usage**: Watch for unexpected job executions
5. **Clean credentials**: Remove tokens when not actively developing

### Performance Best Practices

1. **Resource allocation**: Don't run too many concurrent jobs on local machine
2. **Clean up regularly**: Remove old job artifacts and logs
3. **Monitor resource usage**: Watch CPU, memory, and disk usage
4. **Use fast storage**: SSD storage recommended for job workspaces
5. **Network optimization**: Use wired connection for large repository clones

### Development Workflow Best Practices

1. **Test locally first**: Use `act` to test workflows before committing
2. **Use specific labels**: Target local runners with specific labels
3. **Version control**: Keep workflow files in version control
4. **Document setup**: Document your local runner configuration for team members
5. **Backup configurations**: Regular backup of runner configurations

## 🎯 Next Steps

After setting up your local runner:

1. **Test with simple workflow**: Create and run a basic workflow to verify functionality
2. **Configure your IDE**: Set up integration with your preferred development environment
3. **Optimize for your projects**: Customize runner labels and settings for your specific needs
4. **Setup monitoring**: Implement basic monitoring for runner health
5. **Document your setup**: Create documentation for team members who might use similar setup

For additional configuration:
- **[Multi-Runner Setup](multi-runner.md)** - Running multiple runners on your machine
- **[Security Guide](security.md)** - Enhanced security for shared machines
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions

---

**Local Setup Complete** - Your GitHub Actions self-hosted runner is ready for local development!

---
*Crafted by [Gabel @ Booplex.com](https://booplex.com) - 50% human, 50% AI, 100% trying our best.*