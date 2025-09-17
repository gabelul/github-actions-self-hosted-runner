# Security Guide - GitHub Self-Hosted Runner

Comprehensive security guide for hardening GitHub Actions self-hosted runners with production-grade security practices, threat mitigation, and compliance considerations.

## 🔒 Security Overview

Self-hosted runners require careful security configuration as they have access to your infrastructure and can execute arbitrary code from GitHub workflows. This guide covers all aspects of runner security from basic hardening to advanced threat protection.

## ⚠️ Critical Security Considerations

### Trust Model

**IMPORTANT**: Self-hosted runners should only be used with **private repositories** unless you have implemented advanced sandboxing. Public repositories can potentially:

- Execute malicious code in pull requests
- Access your infrastructure and secrets
- Compromise your entire network
- Extract sensitive data

### Recommended Usage Patterns

```bash
# ✅ SAFE - Private repository with trusted contributors
./setup.sh --token TOKEN --repo your-org/private-repo

# ⚠️ CAUTION - Organization runners with proper access controls
./setup.sh --token TOKEN --org your-org --group "trusted-repos"

# ❌ DANGEROUS - Never use with public repositories
# ./setup.sh --token TOKEN --repo public-org/public-repo  # DON'T DO THIS
```

## 🛡️ Foundation Security

### User Security

```bash
# 1. Verify runner user configuration
id github-runner

# Expected output:
# uid=1001(github-runner) gid=1001(github-runner) groups=1001(github-runner),999(docker)

# 2. Check user home directory permissions
ls -la /home/github-runner
# Should show: drwx------ github-runner github-runner

# 3. Verify no shell access for automated systems
# For production, consider: sudo usermod -s /bin/false github-runner

# 4. Check sudo permissions (should be minimal)
sudo -u github-runner sudo -l
```

### File System Security

```bash
# 1. Secure runner configuration files
sudo chmod 600 /home/github-runner/.runner
sudo chmod 600 /home/github-runner/.credentials
sudo chown github-runner:github-runner /home/github-runner/.runner
sudo chown github-runner:github-runner /home/github-runner/.credentials

# 2. Protect runner binary and scripts
sudo chmod 755 /home/github-runner/run.sh
sudo chmod 755 /home/github-runner/config.sh
sudo chown root:root /home/github-runner/*.sh

# 3. Secure work directories
sudo chmod 750 /home/github-runner/_work
sudo chown github-runner:github-runner /home/github-runner/_work

# 4. Set up restricted permissions for sensitive directories
sudo chmod 700 /home/github-runner/.ssh 2>/dev/null || true
sudo chmod 700 /home/github-runner/.gnupg 2>/dev/null || true
```

### Network Security

```bash
# 1. Configure restrictive firewall
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default deny outgoing

# 2. Allow only necessary outbound connections
sudo ufw allow out 443/tcp    # HTTPS to GitHub
sudo ufw allow out 80/tcp     # HTTP for package updates
sudo ufw allow out 53/tcp     # DNS
sudo ufw allow out 53/udp     # DNS

# 3. Allow SSH (modify port if using non-standard)
sudo ufw allow 22/tcp

# 4. Block unnecessary protocols
sudo ufw deny out 21/tcp      # FTP
sudo ufw deny out 23/tcp      # Telnet
sudo ufw deny out 3389/tcp    # RDP

# 5. Enable firewall
sudo ufw --force enable

# 6. Verify configuration
sudo ufw status verbose
```

## 🔐 Token Security

### Token Management

```bash
# 1. Create fine-grained tokens (recommended)
# Go to GitHub Settings > Developer settings > Personal access tokens (fine-grained)
# Set expiration to 90 days or less
# Grant only necessary repository permissions

# 2. Store tokens securely
sudo mkdir -p /etc/github-runner/
echo "TOKEN=ghp_your_token_here" | sudo tee /etc/github-runner/token.env
sudo chmod 600 /etc/github-runner/token.env
sudo chown root:root /etc/github-runner/token.env

# 3. Use environment file in systemd service
sudo systemctl edit github-runner << 'EOF'
[Service]
EnvironmentFile=/etc/github-runner/token.env
EOF

# 4. Remove token from command line history
history -d $(history | grep "TOKEN\|token\|ghp_" | tail -1 | awk '{print $1}')
```

### Token Rotation

```bash
# 1. Create token rotation script
sudo tee /usr/local/bin/rotate-runner-token.sh << 'EOF'
#!/bin/bash
# GitHub Runner Token Rotation Script

set -e

OLD_TOKEN_FILE="/etc/github-runner/token.env"
NEW_TOKEN="$1"
RUNNER_NAME="${2:-$(hostname)}"

if [ -z "$NEW_TOKEN" ]; then
    echo "Usage: $0 <new_token> [runner_name]"
    exit 1
fi

echo "Rotating GitHub runner token..."

# Stop runner service
sudo systemctl stop github-runner

# Remove old runner registration
if [ -f "$OLD_TOKEN_FILE" ]; then
    OLD_TOKEN=$(grep "^TOKEN=" "$OLD_TOKEN_FILE" | cut -d'=' -f2)
    sudo -u github-runner /home/github-runner/config.sh remove --token "$OLD_TOKEN" || true
fi

# Update token file
echo "TOKEN=$NEW_TOKEN" | sudo tee "$OLD_TOKEN_FILE"
sudo chmod 600 "$OLD_TOKEN_FILE"
sudo chown root:root "$OLD_TOKEN_FILE"

# Re-register with new token
sudo -u github-runner /home/github-runner/config.sh \
    --url https://github.com/$(grep REPO /etc/github-runner/config | cut -d'=' -f2) \
    --token "$NEW_TOKEN" \
    --name "$RUNNER_NAME" \
    --replace \
    --unattended

# Start runner service
sudo systemctl start github-runner

echo "Token rotation completed successfully!"
EOF

sudo chmod +x /usr/local/bin/rotate-runner-token.sh

# 2. Setup automatic token rotation reminder
echo '0 0 * * 0 root echo "GitHub runner token expires soon - rotate token" | mail -s "Runner Token Rotation" admin@company.com' | sudo tee -a /etc/crontab
```

## 🚧 Sandboxing and Isolation

### Container-Based Isolation

```bash
# 1. Setup Docker-in-Docker for job isolation
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "seccomp-profile": "/etc/docker/seccomp.json",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    },
    "nproc": {
      "Name": "nproc",
      "Hard": 32768,
      "Soft": 16384
    }
  }
}
EOF

# 2. Configure Docker security
sudo usermod -aG docker github-runner
sudo systemctl restart docker

# 3. Create job isolation script
sudo tee /usr/local/bin/isolated-job.sh << 'EOF'
#!/bin/bash
# Isolated Job Execution Script

CONTAINER_NAME="github-job-$$"
REPO_PATH="$1"
JOB_COMMANDS="$2"

# Create isolated container for job
docker run -d \
  --name "$CONTAINER_NAME" \
  --rm \
  --security-opt no-new-privileges:true \
  --security-opt apparmor:docker-default \
  --cap-drop ALL \
  --cap-add SETUID \
  --cap-add SETGID \
  --read-only \
  --tmpfs /tmp:exec,nodev,nosuid,size=1g \
  --tmpfs /var/tmp:exec,nodev,nosuid,size=512m \
  --network none \
  -v "$REPO_PATH:/workspace:ro" \
  ubuntu:22.04 \
  bash -c "$JOB_COMMANDS"

# Wait for completion and cleanup
docker wait "$CONTAINER_NAME"
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
EOF

sudo chmod +x /usr/local/bin/isolated-job.sh
```

### AppArmor Profile (Linux)

```bash
# 1. Create AppArmor profile for runner
sudo tee /etc/apparmor.d/github-runner << 'EOF'
#include <tunables/global>

/home/github-runner/run.sh {
  #include <abstractions/base>
  #include <abstractions/bash>

  capability dac_override,
  capability setuid,
  capability setgid,

  /home/github-runner/ r,
  /home/github-runner/** rwk,
  /tmp/ r,
  /tmp/** rwk,
  /var/tmp/ r,
  /var/tmp/** rwk,

  /usr/bin/docker Px,
  /usr/bin/git Px,
  /usr/bin/curl Px,

  # Network access
  network inet stream,
  network inet6 stream,

  # Deny access to sensitive system files
  deny /etc/shadow r,
  deny /etc/passwd w,
  deny /etc/sudoers r,
  deny /root/ r,
  deny /home/*/.ssh/ r,
  deny /var/log/auth.log r,
}
EOF

# 2. Load AppArmor profile
sudo apparmor_parser -r /etc/apparmor.d/github-runner
sudo aa-enforce /etc/apparmor.d/github-runner

# 3. Verify profile is active
sudo aa-status | grep github-runner
```

## 🔍 Monitoring and Auditing

### Comprehensive Logging

```bash
# 1. Configure detailed audit logging
sudo tee /etc/audit/rules.d/github-runner.rules << 'EOF'
# GitHub Runner Security Audit Rules

# Monitor runner user activities
-w /home/github-runner -p wa -k github_runner_activity

# Monitor runner configuration changes
-w /home/github-runner/.runner -p wa -k github_runner_config
-w /home/github-runner/.credentials -p wa -k github_runner_credentials

# Monitor job executions
-w /home/github-runner/_work -p wa -k github_runner_jobs

# Monitor network connections from runner
-a always,exit -F arch=b64 -S connect -F uid=1001 -k github_runner_network

# Monitor file access
-a always,exit -F arch=b64 -S open,openat -F uid=1001 -k github_runner_files

# Monitor process execution
-a always,exit -F arch=b64 -S execve -F uid=1001 -k github_runner_exec
EOF

# 2. Restart audit daemon
sudo systemctl restart auditd

# 3. Create log analysis script
sudo tee /usr/local/bin/analyze-runner-logs.sh << 'EOF'
#!/bin/bash
# GitHub Runner Security Log Analysis

echo "=== GitHub Runner Security Analysis ==="
echo "Analysis Date: $(date)"
echo ""

# Check for suspicious file access
echo "📁 Suspicious File Access:"
ausearch -k github_runner_files -ts today | grep -E "(passwd|shadow|sudoers|ssh)" || echo "None found"
echo ""

# Check network connections
echo "🌐 Network Connections:"
ausearch -k github_runner_network -ts today | grep -oE "addr=[0-9.]+" | sort | uniq -c | sort -nr | head -10
echo ""

# Check executed commands
echo "⚡ Command Executions:"
ausearch -k github_runner_exec -ts today | grep -oE "comm=\"[^\"]+\"" | sort | uniq -c | sort -nr | head -10
echo ""

# Check configuration changes
echo "⚙️ Configuration Changes:"
ausearch -k github_runner_config -ts today || echo "None found"
echo ""

# Check for elevated privileges
echo "🔐 Privilege Escalation Attempts:"
grep "sudo" /var/log/auth.log | grep github-runner | tail -5
echo ""

echo "Analysis complete. Review any suspicious activities above."
EOF

sudo chmod +x /usr/local/bin/analyze-runner-logs.sh

# 4. Schedule daily security analysis
echo '0 6 * * * root /usr/local/bin/analyze-runner-logs.sh | mail -s "GitHub Runner Security Report" security@company.com' | sudo tee -a /etc/crontab
```

### Real-time Monitoring

```bash
# 1. Install monitoring tools
sudo apt install -y inotify-tools psacct

# 2. Create real-time monitor script
sudo tee /usr/local/bin/monitor-runner.sh << 'EOF'
#!/bin/bash
# Real-time GitHub Runner Monitoring

ALERT_EMAIL="security@company.com"
LOG_FILE="/var/log/runner-security.log"

log_alert() {
    local message="$1"
    echo "$(date): $message" >> "$LOG_FILE"
    echo "$message" | mail -s "GitHub Runner Security Alert" "$ALERT_EMAIL"
}

# Monitor file system changes
inotifywait -m -r /home/github-runner \
    -e create,delete,modify,move,attrib \
    --format '%T %w %f %e' --timefmt '%Y-%m-%d %H:%M:%S' |
while read date time dir file event; do
    # Alert on sensitive file access
    if [[ "$file" =~ \.(pem|key|crt|p12)$ ]] || [[ "$dir$file" =~ \.ssh|\.gnupg ]]; then
        log_alert "ALERT: Sensitive file access - $dir$file ($event)"
    fi

    # Alert on configuration changes outside normal operation
    if [[ "$file" =~ \.runner|\.credentials ]] && [[ "$event" != "MODIFY" ]]; then
        log_alert "ALERT: Runner configuration change - $dir$file ($event)"
    fi
done &

# Monitor process creation
sudo tail -F /var/log/messages |
while read line; do
    if echo "$line" | grep -q "github-runner"; then
        # Check for suspicious process names
        if echo "$line" | grep -qE "(nc|netcat|socat|python.*-c|perl.*-e|ruby.*-e)"; then
            log_alert "ALERT: Suspicious process detected - $line"
        fi
    fi
done &

echo "Real-time monitoring started. PID: $$"
wait
EOF

sudo chmod +x /usr/local/bin/monitor-runner.sh

# 3. Create systemd service for monitoring
sudo tee /etc/systemd/system/github-runner-monitor.service << 'EOF'
[Unit]
Description=GitHub Runner Security Monitor
After=github-runner.service
Requires=github-runner.service

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/monitor-runner.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable github-runner-monitor
sudo systemctl start github-runner-monitor
```

## 🛠️ Advanced Security Configuration

### Secrets Management

```bash
# 1. Never store secrets in environment variables or files
# Use external secret management systems

# 2. Setup secrets rotation for workflows
sudo tee /usr/local/bin/rotate-workflow-secrets.sh << 'EOF'
#!/bin/bash
# Workflow Secrets Rotation Script

SECRET_NAME="$1"
NEW_SECRET_VALUE="$2"
REPO="$3"

if [ -z "$SECRET_NAME" ] || [ -z "$NEW_SECRET_VALUE" ] || [ -z "$REPO" ]; then
    echo "Usage: $0 <secret_name> <new_value> <repo>"
    exit 1
fi

# Use GitHub CLI to update secrets
gh secret set "$SECRET_NAME" --body "$NEW_SECRET_VALUE" --repo "$REPO"

echo "Secret $SECRET_NAME updated for repository $REPO"
EOF

sudo chmod +x /usr/local/bin/rotate-workflow-secrets.sh

# 3. Create secure environment for sensitive jobs
sudo tee /usr/local/bin/secure-job-env.sh << 'EOF'
#!/bin/bash
# Secure Job Environment Setup

# Clear all environment variables except essential ones
env -i \
  PATH="/usr/local/bin:/usr/bin:/bin" \
  HOME="/home/github-runner" \
  USER="github-runner" \
  SHELL="/bin/bash" \
  "$@"
EOF

sudo chmod +x /usr/local/bin/secure-job-env.sh
```

### Network Segmentation

```bash
# 1. Create dedicated network namespace for runner (advanced)
sudo ip netns add github-runner
sudo ip netns exec github-runner ip link set dev lo up

# 2. Configure restrictive iptables rules
sudo tee /usr/local/bin/setup-runner-firewall.sh << 'EOF'
#!/bin/bash
# Advanced GitHub Runner Firewall Setup

# Clear existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outbound HTTPS to GitHub (443)
iptables -A OUTPUT -p tcp --dport 443 -d github.com -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -d api.github.com -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -d objects.githubusercontent.com -j ACCEPT

# Allow DNS
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

# Allow SSH (modify as needed)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Log dropped packets
iptables -A INPUT -j LOG --log-prefix "INPUT-DROP: "
iptables -A OUTPUT -j LOG --log-prefix "OUTPUT-DROP: "

# Save rules
iptables-save > /etc/iptables/rules.v4
EOF

sudo chmod +x /usr/local/bin/setup-runner-firewall.sh
# sudo /usr/local/bin/setup-runner-firewall.sh  # Run when ready to apply
```

### Compliance and Hardening

```bash
# 1. CIS Hardening Script
sudo tee /usr/local/bin/harden-runner.sh << 'EOF'
#!/bin/bash
# GitHub Runner CIS Hardening Script

echo "Applying CIS hardening to GitHub Runner..."

# Disable unnecessary services
sudo systemctl disable avahi-daemon 2>/dev/null || true
sudo systemctl disable bluetooth 2>/dev/null || true
sudo systemctl disable cups 2>/dev/null || true

# Configure password policies (if passwords are used)
sudo sed -i 's/PASS_MAX_DAYS\t99999/PASS_MAX_DAYS\t90/' /etc/login.defs
sudo sed -i 's/PASS_MIN_DAYS\t0/PASS_MIN_DAYS\t7/' /etc/login.defs

# Set umask
echo "umask 027" | sudo tee -a /home/github-runner/.bashrc

# Disable core dumps
echo "* hard core 0" | sudo tee -a /etc/security/limits.conf

# Configure kernel parameters
sudo tee -a /etc/sysctl.conf << 'EOSysctl'
# GitHub Runner Security Hardening
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
kernel.yama.ptrace_scope=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv4.conf.all.secure_redirects=0
net.ipv4.conf.default.secure_redirects=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.icmp_ignore_bogus_error_responses=1
EOSysctl

sudo sysctl -p

# Set secure file permissions
sudo chmod 600 /boot/grub/grub.cfg 2>/dev/null || true
sudo chmod 600 /etc/ssh/sshd_config
sudo chmod 644 /etc/passwd
sudo chmod 644 /etc/group
sudo chmod 600 /etc/shadow
sudo chmod 600 /etc/gshadow

echo "Hardening completed!"
EOF

sudo chmod +x /usr/local/bin/harden-runner.sh
# sudo /usr/local/bin/harden-runner.sh  # Run when ready to apply

# 2. Security benchmark compliance check
sudo tee /usr/local/bin/security-benchmark.sh << 'EOF'
#!/bin/bash
# GitHub Runner Security Benchmark Check

echo "=== GitHub Runner Security Benchmark ==="
echo "Date: $(date)"
echo ""

score=0
total=0

check_item() {
    local description="$1"
    local command="$2"
    local expected="$3"

    echo -n "Checking: $description... "
    result=$(eval "$command" 2>/dev/null)
    total=$((total + 1))

    if [[ "$result" == "$expected" ]]; then
        echo "✅ PASS"
        score=$((score + 1))
    else
        echo "❌ FAIL (got: $result, expected: $expected)"
    fi
}

# Run security checks
check_item "Runner user exists" "id github-runner >/dev/null && echo 'exists'" "exists"
check_item "Runner home permissions" "stat -c '%a' /home/github-runner" "700"
check_item "Credentials file permissions" "stat -c '%a' /home/github-runner/.credentials 2>/dev/null || echo '600'" "600"
check_item "UFW firewall enabled" "ufw status | grep -q 'Status: active' && echo 'active'" "active"
check_item "AppArmor profile loaded" "aa-status 2>/dev/null | grep -q github-runner && echo 'loaded'" "loaded"
check_item "Audit logging enabled" "systemctl is-active auditd" "active"
check_item "Runner service active" "systemctl is-active github-runner" "active"

echo ""
echo "Security Score: $score/$total ($(( score * 100 / total ))%)"

if [ "$score" -eq "$total" ]; then
    echo "🎉 All security checks passed!"
    exit 0
else
    echo "⚠️  Some security checks failed. Review configuration."
    exit 1
fi
EOF

sudo chmod +x /usr/local/bin/security-benchmark.sh

# 3. Run security benchmark
sudo /usr/local/bin/security-benchmark.sh
```

## 🚨 Incident Response

### Security Incident Playbook

```bash
# 1. Create incident response script
sudo tee /usr/local/bin/security-incident-response.sh << 'EOF'
#!/bin/bash
# GitHub Runner Security Incident Response

INCIDENT_LOG="/var/log/security-incident.log"
INCIDENT_TIME=$(date)

log_incident() {
    echo "[$INCIDENT_TIME] $1" | tee -a "$INCIDENT_LOG"
}

case "$1" in
    "compromise")
        log_incident "SECURITY INCIDENT: Suspected runner compromise"

        # Immediate actions
        log_incident "Stopping runner service..."
        systemctl stop github-runner

        log_incident "Disabling network access..."
        iptables -A OUTPUT -j DROP

        log_incident "Backing up evidence..."
        tar czf "/tmp/incident-evidence-$(date +%Y%m%d-%H%M%S).tar.gz" \
            /home/github-runner \
            /var/log/github-runner* \
            /var/log/audit/audit.log

        log_incident "Incident response initiated. Evidence collected."
        ;;

    "token-leak")
        log_incident "SECURITY INCIDENT: Token leak detected"

        # Revoke token immediately
        log_incident "Revoking GitHub token..."
        # Manual step: Go to GitHub settings and revoke the token

        # Stop and remove runner
        systemctl stop github-runner
        sudo -u github-runner /home/github-runner/config.sh remove --token "$GITHUB_TOKEN" 2>/dev/null || true

        log_incident "Runner removed. Generate new token and re-register."
        ;;

    "analyze")
        log_incident "SECURITY ANALYSIS: Analyzing recent activity"
        /usr/local/bin/analyze-runner-logs.sh | tee -a "$INCIDENT_LOG"
        ;;

    *)
        echo "Usage: $0 {compromise|token-leak|analyze}"
        exit 1
        ;;
esac
EOF

sudo chmod +x /usr/local/bin/security-incident-response.sh
```

### Recovery Procedures

```bash
# 1. Create secure recovery script
sudo tee /usr/local/bin/secure-recovery.sh << 'EOF'
#!/bin/bash
# Secure Runner Recovery Procedure

echo "=== GitHub Runner Secure Recovery ==="
echo "Starting recovery procedure at $(date)"

# Stop all runner services
echo "1. Stopping all runner services..."
systemctl stop github-runner* 2>/dev/null || true

# Remove existing configurations
echo "2. Removing existing runner configurations..."
sudo -u github-runner rm -f /home/github-runner/.runner
sudo -u github-runner rm -f /home/github-runner/.credentials

# Clean work directories
echo "3. Cleaning work directories..."
sudo -u github-runner rm -rf /home/github-runner/_work/*
sudo -u github-runner rm -rf /home/github-runner/_diag/*

# Reset file permissions
echo "4. Resetting file permissions..."
chown -R github-runner:github-runner /home/github-runner
chmod 700 /home/github-runner
chmod 755 /home/github-runner/*.sh

# Apply security hardening
echo "5. Applying security hardening..."
/usr/local/bin/harden-runner.sh

# Reset firewall rules
echo "6. Resetting firewall rules..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow out 443/tcp
ufw allow out 80/tcp
ufw allow out 53
ufw --force enable

# Update system
echo "7. Updating system packages..."
apt update && apt upgrade -y

echo "Recovery procedure completed. Ready for re-registration with new token."
echo "Next steps:"
echo "1. Generate new GitHub personal access token"
echo "2. Run setup script with new token"
echo "3. Run security benchmark to verify configuration"
EOF

sudo chmod +x /usr/local/bin/secure-recovery.sh
```

## 📊 Security Monitoring Dashboard

### Security Metrics Collection

```bash
# 1. Create security metrics script
sudo tee /usr/local/bin/collect-security-metrics.sh << 'EOF'
#!/bin/bash
# Security Metrics Collection for GitHub Runner

METRICS_FILE="/var/log/security-metrics.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Collect metrics
FAILED_LOGINS=$(grep "Failed password" /var/log/auth.log | wc -l)
RUNNER_UPTIME=$(systemctl show github-runner --property=ActiveEnterTimestamp | cut -d'=' -f2)
FIREWALL_DROPS=$(grep "UFW BLOCK" /var/log/kern.log | wc -l)
AUDIT_EVENTS=$(ausearch -ts today 2>/dev/null | wc -l)
PROCESS_COUNT=$(pgrep -f "Runner.Listener" | wc -l)

# Generate JSON metrics
cat > "$METRICS_FILE" << EOF
{
  "timestamp": "$TIMESTAMP",
  "hostname": "$(hostname)",
  "security_metrics": {
    "failed_logins": $FAILED_LOGINS,
    "runner_uptime": "$RUNNER_UPTIME",
    "firewall_drops": $FIREWALL_DROPS,
    "audit_events": $AUDIT_EVENTS,
    "runner_processes": $PROCESS_COUNT
  },
  "health_status": "$(systemctl is-active github-runner)"
}
EOF

echo "Security metrics collected at $TIMESTAMP"
EOF

sudo chmod +x /usr/local/bin/collect-security-metrics.sh

# 2. Schedule metrics collection
echo '*/5 * * * * root /usr/local/bin/collect-security-metrics.sh' | sudo tee -a /etc/crontab
```

---

## ✅ Security Checklist

### Pre-Deployment Security

- [ ] **Repository Access**: Verify runner will only access private repositories
- [ ] **Token Permissions**: Use fine-grained tokens with minimal necessary permissions
- [ ] **Network Isolation**: Configure firewall rules to restrict unnecessary access
- [ ] **User Isolation**: Verify github-runner user has minimal system privileges
- [ ] **File Permissions**: Secure all configuration and credential files

### Post-Deployment Security

- [ ] **Security Benchmark**: Run security benchmark and achieve 100% score
- [ ] **Monitoring Setup**: Configure audit logging and real-time monitoring
- [ ] **Incident Response**: Test incident response procedures
- [ ] **Regular Updates**: Schedule regular security updates and token rotation
- [ ] **Backup Strategy**: Implement secure backup and recovery procedures

### Ongoing Security

- [ ] **Weekly Security Scan**: Run automated security analysis
- [ ] **Monthly Token Rotation**: Rotate GitHub tokens regularly
- [ ] **Quarterly Security Review**: Comprehensive security assessment
- [ ] **Security Training**: Keep team updated on security best practices
- [ ] **Threat Intelligence**: Monitor for new threats and vulnerabilities

## 🆘 Emergency Procedures

### If Compromise is Suspected

```bash
# 1. Immediate isolation
sudo /usr/local/bin/security-incident-response.sh compromise

# 2. Evidence collection
sudo tar czf /tmp/forensic-evidence-$(date +%Y%m%d).tar.gz \
    /var/log/ \
    /home/github-runner/ \
    /etc/github-runner/

# 3. Network isolation
sudo iptables -A OUTPUT -j DROP

# 4. Notify security team
echo "SECURITY INCIDENT: GitHub runner compromise suspected on $(hostname)" | \
    mail -s "URGENT: Security Incident" security@company.com
```

### Recovery Steps

```bash
# 1. Run secure recovery
sudo /usr/local/bin/secure-recovery.sh

# 2. Generate new credentials
# - Create new GitHub personal access token
# - Update any exposed secrets in repositories

# 3. Re-deploy with enhanced security
./setup.sh --token NEW_TOKEN --repo REPO --enhanced-security

# 4. Verify security posture
sudo /usr/local/bin/security-benchmark.sh
```

---

**Remember**: Security is an ongoing process, not a one-time setup. Regularly review and update your security configuration based on evolving threats and best practices.

For additional security resources:
- **[Multi-Runner Security](multi-runner.md)** - Security considerations for multiple runners
- **[VPS Security](vps-setup.md#security-configuration)** - VPS-specific security hardening
- **[Troubleshooting](troubleshooting.md)** - Security-related troubleshooting

**Security is Priority #1** - Never compromise on security for convenience.

---
*Crafted by [Gabel @ Booplex.com](https://booplex.com) - 50% human, 50% AI, 100% trying our best.*