# Set Up Your Runner on a VPS (Rent-a-Server Guide)

Never rented a server before? No worries! This guide will walk you through everything from getting your first server to having GitHub Actions running on it.

**What's a VPS?** Think of it like renting an apartment, but instead of living space, you're renting computer space in someone else's data center. Popular "landlords" include DigitalOcean, Linode, and AWS.

## 🤔 Should You Use a VPS?

**Perfect for you if:**
- You want your runner online 24/7
- You're working with a team
- You want to save money on GitHub Actions
- You don't mind spending $10-50/month for a server

**Maybe not right if:**
- You just want to try this out first (use your local computer instead)
- You're only doing personal projects (local might be cheaper)
- You're scared of the command line (we'll help you get over that!)

## 🚀 Super Quick Setup (If You Already Have a Server)

### What You'll Need Before Starting
- A server running Ubuntu 20.04 or newer (or Debian 11+)
- Admin access to that server
- Your GitHub token (we showed you how to get this in the main README)
- Your GitHub repository name (like "yourname/your-project")

### The Magic One-Liner

Already have a server? Just copy and paste this command after logging in:

```bash
# Connect to your server first (ssh root@your-server-ip), then run this:
curl -fsSL https://raw.githubusercontent.com/gabelul/github-self-hosted-runner/main/setup.sh | bash -s -- \
  --token ghp_your_personal_access_token_here \
  --repo owner/repository-name \
  --environment vps
```

**What this does:** Downloads our setup script and runs it with your information. In about 2-3 minutes, you'll have a working GitHub runner!

## 📋 Don't Have a Server Yet? Let's Get You One!

### Step 1: Rent Your Server

**Recommended for beginners:** DigitalOcean (super user-friendly)

1. Go to [DigitalOcean.com](https://digitalocean.com)
2. Sign up for an account
3. Click "Create" → "Droplet"
4. Choose:
   - **Image:** Ubuntu 22.04 LTS
   - **Plan:** Basic ($12/month with 2GB RAM is perfect to start)
   - **Region:** Closest to you
5. Add an SSH key (they'll walk you through this)
6. Click "Create Droplet"

**Alternative options:**
- **Linode** - $10/month, also very beginner-friendly
- **Vultr** - Often has promotions for new users
- **AWS EC2** - More complex but more features

### Step 2: Connect to Your New Server

Once your server is ready (usually takes 2-3 minutes):

```bash
# Replace "your-server-ip" with the IP address they gave you
ssh root@your-server-ip
```

**First time connecting?** Your computer might ask if you trust this server. Type "yes" and press Enter.

### Step 3: Prepare Your Server (The Boring But Important Stuff)

Copy and paste these commands one at a time:

```bash
# Update everything (like updating apps on your phone)
apt update && apt upgrade -y

# Install tools we need (takes about 2-3 minutes)
apt install -y curl wget git build-essential sudo

# Give your server a friendly name (optional but nice)
hostnamectl set-hostname my-github-runner
```

### Step 4: Install the GitHub Runner

Now for the fun part! Download our setup script:

```bash
# Get our setup script
curl -o setup.sh https://raw.githubusercontent.com/gabelul/github-self-hosted-runner/main/setup.sh
chmod +x setup.sh

# Now run it and follow the prompts (it'll ask you for your token and repo)
./setup.sh

That's it! In a few minutes, you'll have your own GitHub runner saving you money. Pretty cool, right?

```

### Alternative: Use Parameters Directly

If you prefer to skip the interactive setup, you can also run it with parameters:

```bash
# OR run with parameters
./setup.sh \
  --token ghp_your_personal_access_token_here \
  --repo owner/repository-name \
  --name vps-runner-01 \
  --environment vps
```

### Step 3: Verify Installation

```bash
# 1. Check runner service status
sudo systemctl status github-runner

# 2. View runner logs
sudo journalctl -u github-runner -f

# 3. Check runner registration
sudo -u github-runner cat /home/github-runner/.runner

# 4. Test runner health
sudo -u github-runner /home/github-runner/health-check.sh
```

## 🔒 Security Configuration

### Firewall Setup

```bash
# 1. Install and configure UFW firewall
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 2. Allow SSH (change 22 to your SSH port if different)
sudo ufw allow 22/tcp

# 3. Allow HTTPS for GitHub communication
sudo ufw allow out 443/tcp
sudo ufw allow out 80/tcp

# 4. Enable firewall
sudo ufw --force enable

# 5. Verify firewall status
sudo ufw status verbose
```

### SSH Hardening

```bash
# 1. Create SSH config backup
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# 2. Configure SSH security
sudo tee -a /etc/ssh/sshd_config << EOF

# GitHub Runner VPS Security Configuration
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers $USER
EOF

# 3. Restart SSH service
sudo systemctl restart sshd
```

### User Security

```bash
# 1. Verify github-runner user is created correctly
id github-runner

# 2. Check user permissions
sudo -u github-runner groups

# 3. Verify home directory permissions
ls -la /home/github-runner

# 4. Test sudo restrictions
sudo -u github-runner sudo -l
```

## ⚙️ Production Configuration

### Resource Optimization

```bash
# 1. Configure swap (if not already configured)
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 2. Optimize system limits
sudo tee /etc/security/limits.d/github-runner.conf << EOF
github-runner soft nofile 65536
github-runner hard nofile 65536
github-runner soft nproc 32768
github-runner hard nproc 32768
EOF

# 3. Configure log rotation
sudo tee /etc/logrotate.d/github-runner << EOF
/var/log/github-runner.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 github-runner github-runner
}
EOF
```

### SystemD Service Configuration

```bash
# 1. Verify service is installed and enabled
sudo systemctl is-enabled github-runner
sudo systemctl is-active github-runner

# 2. Configure automatic restart on failure
sudo systemctl edit github-runner << EOF
[Unit]
StartLimitIntervalSec=0

[Service]
Restart=always
RestartSec=30
EOF

# 3. Reload systemd and restart service
sudo systemctl daemon-reload
sudo systemctl restart github-runner
```

### Monitoring Setup

```bash
# 1. Install monitoring tools
sudo apt install -y htop iotop netstat-nat

# 2. Create monitoring script
sudo tee /usr/local/bin/runner-monitor.sh << 'EOF'
#!/bin/bash
# GitHub Runner VPS Monitoring Script

LOGFILE="/var/log/runner-monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# System stats
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
DISK_USAGE=$(df /home/github-runner | awk 'NR==2 {print $5}' | sed 's/%//')

# Runner status
RUNNER_STATUS=$(systemctl is-active github-runner)
RUNNER_PID=$(pgrep -f "Runner.Listener" || echo "N/A")

# Log monitoring data
echo "[$DATE] CPU: ${CPU_USAGE}% | MEM: ${MEMORY_USAGE}% | DISK: ${DISK_USAGE}% | RUNNER: $RUNNER_STATUS | PID: $RUNNER_PID" >> $LOGFILE

# Alert if thresholds exceeded
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    echo "[$DATE] WARNING: High CPU usage: ${CPU_USAGE}%" >> $LOGFILE
fi

if (( $(echo "$MEMORY_USAGE > 85" | bc -l) )); then
    echo "[$DATE] WARNING: High memory usage: ${MEMORY_USAGE}%" >> $LOGFILE
fi

if [ "$RUNNER_STATUS" != "active" ]; then
    echo "[$DATE] ERROR: Runner service not active: $RUNNER_STATUS" >> $LOGFILE
fi
EOF

sudo chmod +x /usr/local/bin/runner-monitor.sh

# 3. Setup monitoring cron job
sudo crontab -e << EOF
# GitHub Runner Monitoring (every 5 minutes)
*/5 * * * * /usr/local/bin/runner-monitor.sh
EOF
```

## 🔍 Health Monitoring

### Automated Health Checks

```bash
# 1. Create comprehensive health check
sudo tee /usr/local/bin/runner-health-check.sh << 'EOF'
#!/bin/bash
# VPS Runner Health Check Script

set -e

echo "=== GitHub Runner VPS Health Check ==="
echo "Timestamp: $(date)"
echo "Host: $(hostname)"
echo ""

# System Health
echo "📊 SYSTEM HEALTH"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')"
echo "Memory Usage: $(free -h | grep Mem | awk '{print "Used: " $3 " / Total: " $2}')"
echo "Disk Usage: $(df -h /home/github-runner | awk 'NR==2 {print "Used: " $3 " / Total: " $2 " (" $5 ")"}')"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# Network Connectivity
echo "🌐 NETWORK CONNECTIVITY"
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "✅ Internet connectivity: OK"
else
    echo "❌ Internet connectivity: FAILED"
fi

if curl -s https://api.github.com >/dev/null 2>&1; then
    echo "✅ GitHub API access: OK"
else
    echo "❌ GitHub API access: FAILED"
fi
echo ""

# Runner Status
echo "🏃 RUNNER STATUS"
if systemctl is-active --quiet github-runner; then
    echo "✅ Runner service: ACTIVE"
    echo "   PID: $(pgrep -f "Runner.Listener" || echo "N/A")"
else
    echo "❌ Runner service: INACTIVE"
fi

if [ -f /home/github-runner/.runner ]; then
    echo "✅ Runner configuration: EXISTS"
    RUNNER_NAME=$(sudo -u github-runner grep -E '"agentName"' /home/github-runner/.runner | sed 's/.*: "\(.*\)",/\1/' 2>/dev/null || echo "unknown")
    echo "   Name: $RUNNER_NAME"
else
    echo "❌ Runner configuration: MISSING"
fi
echo ""

# Security Status
echo "🔒 SECURITY STATUS"
echo "UFW Status: $(sudo ufw status | head -1)"
echo "SSH Config: $(grep "PermitRootLogin no" /etc/ssh/sshd_config >/dev/null 2>&1 && echo "✅ Secure" || echo "❌ Check needed")"
echo "Runner User: $(id github-runner >/dev/null 2>&1 && echo "✅ Exists" || echo "❌ Missing")"
echo ""

# Recent Activity
echo "📝 RECENT ACTIVITY"
echo "Runner Log (last 5 lines):"
sudo journalctl -u github-runner --no-pager -n 5 | tail -5
echo ""

echo "Health check completed at $(date)"
EOF

sudo chmod +x /usr/local/bin/runner-health-check.sh

# 2. Run health check
sudo /usr/local/bin/runner-health-check.sh
```

### Log Monitoring

```bash
# 1. Real-time log monitoring
sudo journalctl -u github-runner -f

# 2. Check for errors in logs
sudo journalctl -u github-runner --since "1 hour ago" | grep -i error

# 3. Monitor system logs
sudo tail -f /var/log/syslog | grep github-runner

# 4. Check runner specific logs
sudo -u github-runner tail -f /home/github-runner/_diag/Runner_*.log
```

## 🚀 Multi-Runner VPS Setup

### Running Multiple Runners

```bash
# 1. Setup first runner (already done above)
./setup.sh --token TOKEN --repo owner/repo1 --name vps-runner-01

# 2. Setup second runner for different repository
./setup.sh --token TOKEN --repo owner/repo2 --name vps-runner-02

# 3. Setup third runner with custom labels
./setup.sh --token TOKEN --repo owner/repo3 --name gpu-runner --labels "self-hosted,linux,x64,gpu"

# 4. List all runners
sudo systemctl list-units --type=service | grep github-runner

# 5. Check all runner statuses
for runner in $(sudo systemctl list-units --type=service | grep github-runner | awk '{print $1}'); do
    echo "=== $runner ==="
    sudo systemctl status $runner --no-pager -l
    echo ""
done
```

### Resource Allocation

```bash
# 1. Check optimal runner count for VPS
CPU_CORES=$(nproc)
MEMORY_GB=$(free -g | awk 'NR==2{print $2}')

echo "VPS Resources:"
echo "  CPU Cores: $CPU_CORES"
echo "  Memory: ${MEMORY_GB}GB"
echo "  Recommended Runners: $(( CPU_CORES / 2 ))"
echo "  Max Concurrent Jobs: $(( CPU_CORES ))"

# 2. Monitor resource usage with multiple runners
watch -n 5 'echo "=== System Resources ===" && free -h && echo "" && echo "=== Runner Processes ===" && ps aux | grep -E "(Runner|github)" | grep -v grep'
```

## 🔧 VPS Provider Specific Guides

### DigitalOcean Setup

```bash
# 1. Create Droplet with optimal specs
# Recommended: 2GB+ RAM, 2+ CPU cores, Ubuntu 22.04

# 2. Configure DigitalOcean specific optimizations
echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 3. Setup DigitalOcean monitoring agent (optional)
curl -sSL https://repos.insights.digitalocean.com/install.sh | sudo bash

# 4. Configure automatic security updates
sudo apt install -y unattended-upgrades
echo 'APT::Periodic::Unattended-Upgrade "1";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades
```

### Linode Setup

```bash
# 1. Configure Linode-specific network optimizations
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 2. Setup Linode longview monitoring (optional)
# Follow Linode dashboard instructions for monitoring setup

# 3. Configure Linode firewall (in Linode dashboard)
# Allow: SSH (22), HTTPS (443)
# Deny: All other inbound traffic
```

### AWS EC2 Setup

```bash
# 1. EC2 instance recommendations:
# - Instance Type: t3.medium or larger
# - AMI: Ubuntu 22.04 LTS
# - Security Group: SSH (22) and HTTPS (443) outbound

# 2. Configure EC2-specific optimizations
# Install AWS CLI and configure instance metadata
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 3. Configure CloudWatch monitoring (optional)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i -E amazon-cloudwatch-agent.deb
```

## 🔄 Maintenance and Updates

### Regular Maintenance Tasks

```bash
# 1. Weekly system updates
sudo apt update && sudo apt upgrade -y

# 2. Update runner to latest version
sudo systemctl stop github-runner
sudo -u github-runner cd /home/github-runner && ./config.sh remove --token $GITHUB_TOKEN
# Re-run setup.sh with same parameters

# 3. Clean up old logs and artifacts
sudo find /home/github-runner/_work -type f -mtime +7 -delete
sudo journalctl --vacuum-time=30d

# 4. Check disk space
df -h
du -sh /home/github-runner/*

# 5. Verify security settings
sudo /usr/local/bin/runner-health-check.sh
```

### Backup Configuration

```bash
# 1. Backup runner configuration
sudo tar czf runner-backup-$(date +%Y%m%d).tar.gz \
    /home/github-runner/.runner \
    /home/github-runner/.credentials \
    /etc/systemd/system/github-runner.service

# 2. Backup to remote location (optional)
# rsync -av runner-backup-*.tar.gz user@backup-server:/backups/

# 3. Restore from backup (if needed)
# sudo tar xzf runner-backup-YYYYMMDD.tar.gz -C /
# sudo systemctl daemon-reload && sudo systemctl start github-runner
```

## 🐛 Troubleshooting

### Common VPS Issues

#### Runner Registration Fails

```bash
# 1. Check network connectivity
curl -I https://api.github.com

# 2. Verify token permissions
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# 3. Check repository access
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/OWNER/REPO

# 4. Verify firewall isn't blocking
sudo ufw status
telnet api.github.com 443
```

#### Service Won't Start

```bash
# 1. Check service status
sudo systemctl status github-runner -l

# 2. View detailed logs
sudo journalctl -u github-runner -n 50

# 3. Check runner user permissions
sudo -u github-runner ls -la /home/github-runner

# 4. Verify runner binary
sudo -u github-runner /home/github-runner/run.sh --help
```

#### High Resource Usage

```bash
# 1. Check resource usage by runner
ps aux | grep Runner
htop

# 2. Monitor I/O usage
sudo iotop -ao

# 3. Check network usage
sudo netstat -tuln

# 4. Identify resource-heavy jobs
ls -la /home/github-runner/_work/
```

### VPS Performance Optimization

```bash
# 1. Optimize for CI/CD workloads
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
echo 'net.core.rmem_max=16777216' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max=16777216' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 2. Setup build cache directory
sudo mkdir -p /tmp/build-cache
sudo chown github-runner:github-runner /tmp/build-cache
sudo chmod 755 /tmp/build-cache

# 3. Configure temporary file cleanup
sudo tee /etc/tmpfiles.d/github-runner.conf << EOF
# GitHub Runner temporary file cleanup
d /tmp/build-cache 0755 github-runner github-runner 7d
d /home/github-runner/_work 0755 github-runner github-runner -
EOF
```

## 📊 Monitoring Dashboard

### Simple Web Dashboard

```bash
# 1. Install nginx for simple status page
sudo apt install -y nginx

# 2. Create status page
sudo tee /var/www/html/runner-status.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>GitHub Runner VPS Status</title>
    <meta http-equiv="refresh" content="30">
    <style>
        body { font-family: monospace; margin: 40px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .active { background-color: #d4edda; }
        .inactive { background-color: #f8d7da; }
        .info { background-color: #d1ecf1; }
    </style>
</head>
<body>
    <h1>GitHub Runner VPS Status</h1>
    <div id="status-content">Loading...</div>

    <script>
    function updateStatus() {
        fetch('/runner-status.json')
            .then(response => response.json())
            .then(data => {
                document.getElementById('status-content').innerHTML =
                    '<div class="info">Last Updated: ' + data.timestamp + '</div>' +
                    '<div class="' + (data.runner_active ? 'active' : 'inactive') + '">Runner Status: ' + (data.runner_active ? 'ACTIVE' : 'INACTIVE') + '</div>' +
                    '<div class="info">CPU Usage: ' + data.cpu_usage + '%</div>' +
                    '<div class="info">Memory Usage: ' + data.memory_usage + '%</div>' +
                    '<div class="info">Disk Usage: ' + data.disk_usage + '%</div>';
            })
            .catch(error => {
                document.getElementById('status-content').innerHTML = '<div class="inactive">Error loading status</div>';
            });
    }

    updateStatus();
    setInterval(updateStatus, 30000);
    </script>
</body>
</html>
EOF

# 3. Create status API endpoint script
sudo tee /usr/local/bin/generate-status.sh << 'EOF'
#!/bin/bash
# Generate runner status JSON

CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
MEMORY_USAGE=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
DISK_USAGE=$(df /home/github-runner | awk 'NR==2 {print $5}' | sed 's/%//')
RUNNER_ACTIVE=$(systemctl is-active --quiet github-runner && echo "true" || echo "false")

cat > /var/www/html/runner-status.json << EOJSON
{
    "timestamp": "$(date)",
    "hostname": "$(hostname)",
    "runner_active": $RUNNER_ACTIVE,
    "cpu_usage": "$CPU_USAGE",
    "memory_usage": "$MEMORY_USAGE",
    "disk_usage": "$DISK_USAGE"
}
EOJSON
EOF

sudo chmod +x /usr/local/bin/generate-status.sh

# 4. Setup cron to update status every minute
echo '* * * * * /usr/local/bin/generate-status.sh' | sudo crontab -

# 5. Access dashboard
echo "Status dashboard available at: http://$(curl -s ifconfig.me)/runner-status.html"
```

---

## 🎯 Next Steps

After completing your VPS setup:

1. **Test your runner**: Create a simple GitHub Actions workflow to verify functionality
2. **Setup monitoring**: Implement the monitoring dashboard and alerts
3. **Security audit**: Run security checks and ensure all hardening is in place
4. **Documentation**: Document your specific VPS configuration for team access
5. **Backup setup**: Implement regular configuration backups
6. **Scaling**: Consider multi-runner setup for increased capacity

For additional guides, see:
- **[Multi-Runner Setup](multi-runner.md)** - Running multiple runners on your VPS
- **[Security Guide](security.md)** - Advanced security configuration
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions

---

**VPS Setup Complete** - Your GitHub Actions self-hosted runner is now ready for production use!

---
*Crafted by [Gabel @ Booplex.com](https://booplex.com) - 50% human, 50% AI, 100% trying our best.*