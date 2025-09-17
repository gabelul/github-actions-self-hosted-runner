# Troubleshooting Guide - GitHub Self-Hosted Runner

Comprehensive troubleshooting guide for diagnosing and resolving common issues with GitHub Actions self-hosted runners across all platforms and deployment methods.

## 🔧 Quick Diagnostic Commands

### Essential Health Checks

```bash
# 1. Quick system overview
sudo /usr/local/bin/runner-health-check.sh 2>/dev/null || echo "Health check script not found"

# 2. Runner service status
sudo systemctl status github-runner --no-pager -l

# 3. Runner process check
ps aux | grep -E "(Runner|github)" | grep -v grep

# 4. GitHub connectivity test
curl -I https://api.github.com

# 5. Recent error logs
sudo journalctl -u github-runner --since "1 hour ago" | grep -i error
```

### Environment Information Collection

```bash
# Create diagnostic information script
cat > ~/runner-diagnostics.sh << 'EOF'
#!/bin/bash
echo "=== GitHub Runner Diagnostics ==="
echo "Date: $(date)"
echo "Hostname: $(hostname)"
echo "OS: $(uname -a)"
echo ""

echo "=== Runner Status ==="
systemctl status github-runner --no-pager || echo "Service not found"
echo ""

echo "=== Runner Process ==="
ps aux | grep Runner.Listener | grep -v grep || echo "Runner process not found"
echo ""

echo "=== Network Connectivity ==="
echo "GitHub API: $(curl -s -o /dev/null -w "%{http_code}" https://api.github.com)"
echo "GitHub: $(curl -s -o /dev/null -w "%{http_code}" https://github.com)"
echo ""

echo "=== System Resources ==="
echo "Memory: $(free -h | grep Mem)"
echo "Disk: $(df -h /home/github-runner | tail -1)"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

echo "=== Runner Configuration ==="
if [ -f /home/github-runner/.runner ]; then
    echo "Configuration file exists"
    grep -E "(agentName|serverUrl)" /home/github-runner/.runner 2>/dev/null | head -2
else
    echo "No configuration file found"
fi
echo ""

echo "=== Recent Logs (last 10 lines) ==="
journalctl -u github-runner --no-pager -n 10 2>/dev/null || echo "No logs available"
EOF

chmod +x ~/runner-diagnostics.sh
~/runner-diagnostics.sh
```

## 🚨 Common Issues and Solutions

### Issue 1: Runner Registration Fails

#### Symptoms
```
Error: The runner registration did not complete successfully
```

#### Diagnosis
```bash
# Check token validity
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Check repository access
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/OWNER/REPO

# Verify network connectivity
curl -v https://api.github.com 2>&1 | grep -E "(Connected|SSL|HTTP)"
```

#### Solutions

**Solution A: Token Issues**
```bash
# 1. Verify token has correct permissions
# Go to GitHub Settings > Developer settings > Personal access tokens
# Required scopes: repo (and admin:org for organization runners)

# 2. Check token format
echo "$GITHUB_TOKEN" | grep -E "^ghp_[A-Za-z0-9]{36}$" && echo "Token format OK" || echo "Invalid token format"

# 3. Test token permissions
gh auth status  # If using GitHub CLI
```

**Solution B: Network/Firewall Issues**
```bash
# 1. Check firewall settings
sudo ufw status verbose

# 2. Test specific GitHub endpoints
curl -v https://api.github.com/repos/OWNER/REPO

# 3. Verify DNS resolution
nslookup api.github.com
dig api.github.com

# 4. Temporarily disable firewall for testing (CAUTION)
sudo ufw disable  # Test registration, then re-enable
./setup.sh --token TOKEN --repo REPO
sudo ufw enable
```

**Solution C: Repository Access Issues**
```bash
# 1. Verify repository exists and you have access
gh repo view OWNER/REPO

# 2. Check organization permissions (for org repos)
curl -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/orgs/ORG/actions/runners/registration-token"

# 3. Try with personal repository first
./setup.sh --token TOKEN --repo YOUR_USERNAME/your-repo
```

### Issue 2: Runner Service Won't Start

#### Symptoms
```
Failed to start github-runner.service
```

#### Diagnosis
```bash
# Check service status
sudo systemctl status github-runner -l

# Check service logs
sudo journalctl -u github-runner -f

# Verify user permissions
id github-runner
ls -la /home/github-runner

# Check binary permissions
ls -la /home/github-runner/run.sh
```

#### Solutions

**Solution A: File Permissions**
```bash
# 1. Fix ownership
sudo chown -R github-runner:github-runner /home/github-runner

# 2. Fix permissions
sudo chmod 700 /home/github-runner
sudo chmod +x /home/github-runner/run.sh
sudo chmod +x /home/github-runner/config.sh

# 3. Verify key files
sudo chmod 600 /home/github-runner/.runner
sudo chmod 600 /home/github-runner/.credentials
```

**Solution B: Missing Configuration**
```bash
# 1. Check if runner is configured
ls -la /home/github-runner/.runner

# 2. If missing, re-register
cd /home/github-runner
sudo -u github-runner ./config.sh \
  --url https://github.com/OWNER/REPO \
  --token TOKEN \
  --name RUNNER_NAME \
  --unattended \
  --replace

# 3. Start service
sudo systemctl start github-runner
```

**Solution C: SystemD Configuration Issues**
```bash
# 1. Reload systemd daemon
sudo systemctl daemon-reload

# 2. Check service file
sudo cat /etc/systemd/system/github-runner.service

# 3. Re-create service file if corrupted
sudo tee /etc/systemd/system/github-runner.service << 'EOF'
[Unit]
Description=GitHub Actions Runner
After=network.target

[Service]
Type=simple
User=github-runner
WorkingDirectory=/home/github-runner
ExecStart=/home/github-runner/run.sh
Restart=always
RestartSec=5
KillMode=process
KillSignal=SIGINT
TimeoutStopSec=5min

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable github-runner
sudo systemctl start github-runner
```

### Issue 3: Jobs Fail to Execute

#### Symptoms
```
Job completed with error
Workflow run failed
```

#### Diagnosis
```bash
# Check job logs
ls -la /home/github-runner/_work/*/
find /home/github-runner/_work -name "*.log" -exec tail -20 {} +

# Check runner diagnostic logs
ls -la /home/github-runner/_diag/
tail -50 /home/github-runner/_diag/Runner_*.log

# Verify permissions in work directory
ls -la /home/github-runner/_work/
```

#### Solutions

**Solution A: Permission Issues**
```bash
# 1. Fix work directory permissions
sudo chown -R github-runner:github-runner /home/github-runner/_work
sudo chmod -R 755 /home/github-runner/_work

# 2. Check disk space
df -h /home/github-runner

# 3. Clean old job artifacts
sudo find /home/github-runner/_work -type f -mtime +7 -delete
sudo find /home/github-runner/_work -type d -empty -delete
```

**Solution B: Docker Issues (if using Docker)**
```bash
# 1. Check Docker daemon status
sudo systemctl status docker

# 2. Test Docker access for runner user
sudo -u github-runner docker version
sudo -u github-runner docker ps

# 3. Fix Docker group membership
sudo usermod -aG docker github-runner
sudo systemctl restart github-runner

# 4. Test Docker functionality
sudo -u github-runner docker run hello-world
```

**Solution C: Environment/Dependencies**
```bash
# 1. Check required tools installation
which git node npm python3 docker

# 2. Install missing dependencies
sudo apt update
sudo apt install -y git build-essential curl wget

# 3. Verify PATH for runner user
sudo -u github-runner echo $PATH
sudo -u github-runner which git
```

### Issue 4: High Resource Usage

#### Symptoms
```
System becomes slow during job execution
Runner consumes excessive CPU/Memory
```

#### Diagnosis
```bash
# Monitor resource usage
htop -u github-runner
iostat -x 1 5
free -h

# Check concurrent jobs
ps aux | grep Runner.Worker | wc -l

# Monitor disk I/O
sudo iotop -ao

# Check for memory leaks
ps aux | grep Runner | awk '{print $6}' | sort -n
```

#### Solutions

**Solution A: Resource Limits**
```bash
# 1. Limit concurrent jobs in runner labels
# Use specific labels to control job distribution
RUNNER_LABELS="self-hosted,linux,x64,single-job"

# 2. Set system resource limits
sudo tee /etc/systemd/system/github-runner.service.d/limits.conf << 'EOF'
[Service]
MemoryMax=2G
CPUQuota=200%
TasksMax=100
EOF

sudo systemctl daemon-reload
sudo systemctl restart github-runner

# 3. Configure swap if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**Solution B: Cleanup and Optimization**
```bash
# 1. Automated cleanup script
sudo tee /usr/local/bin/runner-cleanup.sh << 'EOF'
#!/bin/bash
# Clean up runner artifacts and temporary files

# Clean work directories older than 7 days
find /home/github-runner/_work -type f -mtime +7 -delete
find /home/github-runner/_work -type d -empty -delete

# Clean temporary files
find /tmp -user github-runner -type f -mtime +1 -delete

# Clean Docker (if applicable)
docker system prune -af --filter "until=24h" 2>/dev/null || true

# Clean package cache
apt clean

echo "Cleanup completed: $(date)"
EOF

sudo chmod +x /usr/local/bin/runner-cleanup.sh

# 2. Schedule daily cleanup
echo '0 2 * * * root /usr/local/bin/runner-cleanup.sh' | sudo tee -a /etc/crontab

# 3. Monitor resources
sudo tee /usr/local/bin/resource-monitor.sh << 'EOF'
#!/bin/bash
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
MEM=$(free | awk 'FNR==2{printf "%.2f", $3/($3+$4)*100}')
DISK=$(df /home/github-runner | awk 'FNR==2{print $5}' | cut -d'%' -f1)

if (( $(echo "$CPU > 80" | bc -l) )); then
    echo "HIGH CPU: ${CPU}%" | logger -t runner-monitor
fi

if (( $(echo "$MEM > 80" | bc -l) )); then
    echo "HIGH MEMORY: ${MEM}%" | logger -t runner-monitor
fi

if [ "$DISK" -gt 85 ]; then
    echo "HIGH DISK: ${DISK}%" | logger -t runner-monitor
fi
EOF

sudo chmod +x /usr/local/bin/resource-monitor.sh
echo '*/5 * * * * root /usr/local/bin/resource-monitor.sh' | sudo tee -a /etc/crontab
```

### Issue 5: Network Connectivity Problems

#### Symptoms
```
Unable to download actions
Connection timeout errors
SSL/TLS errors
```

#### Diagnosis
```bash
# Test connectivity
curl -v https://github.com 2>&1 | head -20
curl -v https://api.github.com 2>&1 | head -20

# Check DNS resolution
nslookup github.com
dig api.github.com

# Test from runner user context
sudo -u github-runner curl -I https://api.github.com

# Check proxy settings
env | grep -i proxy
```

#### Solutions

**Solution A: DNS Issues**
```bash
# 1. Use reliable DNS servers
sudo tee /etc/systemd/resolved.conf << 'EOF'
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=8.8.4.4 1.0.0.1
EOF

sudo systemctl restart systemd-resolved

# 2. Test DNS resolution
nslookup github.com
dig +trace api.github.com

# 3. Clear DNS cache
sudo systemd-resolve --flush-caches
```

**Solution B: Firewall/Proxy Configuration**
```bash
# 1. Configure proxy (if needed)
sudo tee -a /etc/environment << 'EOF'
HTTP_PROXY=http://proxy.company.com:8080
HTTPS_PROXY=http://proxy.company.com:8080
NO_PROXY=localhost,127.0.0.1,::1
EOF

# 2. Configure proxy for runner user
sudo tee -a /home/github-runner/.bashrc << 'EOF'
export HTTP_PROXY=http://proxy.company.com:8080
export HTTPS_PROXY=http://proxy.company.com:8080
export NO_PROXY=localhost,127.0.0.1,::1
EOF

# 3. Update firewall rules
sudo ufw allow out 443/tcp
sudo ufw allow out 80/tcp
sudo ufw allow out 53/tcp
sudo ufw allow out 53/udp

# 4. Restart services
sudo systemctl restart github-runner
```

**Solution C: SSL/Certificate Issues**
```bash
# 1. Update CA certificates
sudo apt update
sudo apt install -y ca-certificates
sudo update-ca-certificates

# 2. Test SSL connection
openssl s_client -connect api.github.com:443 -servername api.github.com

# 3. Check system time (important for SSL)
timedatectl status
sudo timedatectl set-ntp true

# 4. Verify certificate chain
curl -v https://api.github.com 2>&1 | grep -E "(certificate|SSL)"
```

## 🔍 Advanced Diagnostics

### Memory Leak Detection

```bash
# 1. Monitor memory usage over time
sudo tee /usr/local/bin/memory-leak-detector.sh << 'EOF'
#!/bin/bash
LOGFILE="/var/log/memory-monitor.log"

while true; do
    DATE=$(date)
    RUNNER_PID=$(pgrep -f "Runner.Listener" || echo "N/A")

    if [ "$RUNNER_PID" != "N/A" ]; then
        MEMORY=$(ps -p $RUNNER_PID -o rss= | awk '{print $1}')
        VIRTUAL=$(ps -p $RUNNER_PID -o vsz= | awk '{print $1}')

        echo "$DATE,PID:$RUNNER_PID,RSS:${MEMORY}KB,VSZ:${VIRTUAL}KB" >> $LOGFILE

        # Alert if memory usage exceeds threshold
        if [ "$MEMORY" -gt 1048576 ]; then  # 1GB in KB
            echo "$DATE: WARNING - High memory usage: ${MEMORY}KB" >> $LOGFILE
        fi
    else
        echo "$DATE,PID:N/A,RSS:0,VSZ:0" >> $LOGFILE
    fi

    sleep 60  # Check every minute
done
EOF

sudo chmod +x /usr/local/bin/memory-leak-detector.sh

# 2. Run in background
nohup sudo /usr/local/bin/memory-leak-detector.sh &

# 3. Analyze memory patterns
tail -100 /var/log/memory-monitor.log | awk -F',' '{print $3}' | sort -V
```

### Performance Profiling

```bash
# 1. CPU usage profiling
sudo tee /usr/local/bin/cpu-profiler.sh << 'EOF'
#!/bin/bash
RUNNER_PID=$(pgrep -f "Runner.Listener")

if [ -n "$RUNNER_PID" ]; then
    echo "Profiling CPU usage for Runner PID: $RUNNER_PID"

    # Monitor for 5 minutes
    for i in {1..300}; do
        CPU=$(ps -p $RUNNER_PID -o %cpu= 2>/dev/null || echo "0")
        THREADS=$(ps -p $RUNNER_PID -o nlwp= 2>/dev/null || echo "0")
        echo "$(date),CPU:${CPU}%,Threads:$THREADS"
        sleep 1
    done > /tmp/cpu-profile-$(date +%Y%m%d-%H%M%S).log

    echo "CPU profiling completed. Results in /tmp/"
else
    echo "Runner process not found"
fi
EOF

sudo chmod +x /usr/local/bin/cpu-profiler.sh
```

### Network Traffic Analysis

```bash
# 1. Monitor network connections
sudo tee /usr/local/bin/network-monitor.sh << 'EOF'
#!/bin/bash
RUNNER_PID=$(pgrep -f "Runner.Listener")

if [ -n "$RUNNER_PID" ]; then
    echo "Monitoring network traffic for Runner PID: $RUNNER_PID"

    # Monitor for 10 minutes
    timeout 600 lsof -p $RUNNER_PID -r 5 | grep -E "(TCP|UDP)" |
    while read line; do
        echo "$(date): $line"
    done > /tmp/network-monitor-$(date +%Y%m%d-%H%M%S).log

    echo "Network monitoring completed. Results in /tmp/"
else
    echo "Runner process not found"
fi
EOF

sudo chmod +x /usr/local/bin/network-monitor.sh
```

## 📊 Monitoring and Alerting

### Health Check Automation

```bash
# 1. Comprehensive health check with alerting
sudo tee /usr/local/bin/automated-health-check.sh << 'EOF'
#!/bin/bash
ALERT_EMAIL="admin@company.com"
HEALTH_SCORE=0
TOTAL_CHECKS=0

check_and_score() {
    local description="$1"
    local command="$2"
    local expected="$3"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

    if result=$(eval "$command" 2>/dev/null) && [ "$result" = "$expected" ]; then
        HEALTH_SCORE=$((HEALTH_SCORE + 1))
        return 0
    else
        echo "FAILED: $description (got: $result, expected: $expected)"
        return 1
    fi
}

echo "=== Automated Health Check $(date) ==="

# Run health checks
check_and_score "Runner service active" "systemctl is-active github-runner" "active"
check_and_score "Runner process running" "pgrep -f 'Runner.Listener' >/dev/null && echo 'running'" "running"
check_and_score "GitHub connectivity" "curl -s -o /dev/null -w '%{http_code}' https://api.github.com" "200"
check_and_score "Disk space under 80%" "df /home/github-runner | awk 'NR==2 {print (\$5+0 < 80) ? \"ok\" : \"full\"}'" "ok"

HEALTH_PERCENTAGE=$((HEALTH_SCORE * 100 / TOTAL_CHECKS))

echo "Health Score: $HEALTH_SCORE/$TOTAL_CHECKS ($HEALTH_PERCENTAGE%)"

# Send alert if health score is below threshold
if [ "$HEALTH_PERCENTAGE" -lt 75 ]; then
    {
        echo "Subject: GitHub Runner Health Alert"
        echo ""
        echo "GitHub Runner health check failed on $(hostname)"
        echo "Health Score: $HEALTH_SCORE/$TOTAL_CHECKS ($HEALTH_PERCENTAGE%)"
        echo ""
        echo "Please check the runner status immediately."
    } | sendmail "$ALERT_EMAIL" 2>/dev/null || echo "Failed to send alert email"
fi
EOF

sudo chmod +x /usr/local/bin/automated-health-check.sh

# 2. Schedule health checks
echo '*/15 * * * * root /usr/local/bin/automated-health-check.sh' | sudo tee -a /etc/crontab
```

### Log Analysis and Alerting

```bash
# 1. Error pattern detection
sudo tee /usr/local/bin/log-analyzer.sh << 'EOF'
#!/bin/bash
LOG_FILE="/var/log/github-runner-alerts.log"
ERROR_PATTERNS="error|exception|failed|timeout|refused|denied"

# Analyze recent logs
journalctl -u github-runner --since "15 minutes ago" |
grep -iE "$ERROR_PATTERNS" |
while read line; do
    echo "$(date): ALERT - $line" >> $LOG_FILE

    # Send immediate alert for critical errors
    if echo "$line" | grep -qi "critical\|fatal\|segfault"; then
        echo "CRITICAL ERROR detected on $(hostname): $line" |
        mail -s "CRITICAL: GitHub Runner Error" admin@company.com 2>/dev/null || true
    fi
done
EOF

sudo chmod +x /usr/local/bin/log-analyzer.sh

# 2. Schedule log analysis
echo '*/5 * * * * root /usr/local/bin/log-analyzer.sh' | sudo tee -a /etc/crontab
```

## 🛠️ Recovery Procedures

### Automatic Recovery

```bash
# 1. Service recovery script
sudo tee /usr/local/bin/service-recovery.sh << 'EOF'
#!/bin/bash
SERVICE="github-runner"
MAX_ATTEMPTS=3
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if systemctl is-active --quiet $SERVICE; then
        echo "Service $SERVICE is running"
        exit 0
    else
        ATTEMPT=$((ATTEMPT + 1))
        echo "Attempt $ATTEMPT: Restarting $SERVICE"

        systemctl restart $SERVICE
        sleep 30

        if systemctl is-active --quiet $SERVICE; then
            echo "Service $SERVICE recovered successfully"
            exit 0
        fi
    fi
done

echo "Failed to recover service $SERVICE after $MAX_ATTEMPTS attempts"
# Send alert
echo "Service recovery failed on $(hostname)" | mail -s "Service Recovery Failed" admin@company.com
exit 1
EOF

sudo chmod +x /usr/local/bin/service-recovery.sh

# 2. Schedule recovery checks
echo '*/10 * * * * root /usr/local/bin/service-recovery.sh' | sudo tee -a /etc/crontab
```

### Manual Recovery Steps

```bash
# 1. Complete runner reset
sudo systemctl stop github-runner
sudo -u github-runner rm -f /home/github-runner/.runner
sudo -u github-runner rm -f /home/github-runner/.credentials
sudo -u github-runner rm -rf /home/github-runner/_work/*

# 2. Re-register runner
sudo -u github-runner /home/github-runner/config.sh \
    --url https://github.com/OWNER/REPO \
    --token NEW_TOKEN \
    --name $(hostname)-recovered \
    --unattended \
    --replace

# 3. Start service
sudo systemctl start github-runner
sudo systemctl status github-runner
```

---

## 📞 Getting Help

### Information to Collect Before Seeking Help

```bash
# Run this script and provide output when seeking help
cat > ~/collect-debug-info.sh << 'EOF'
#!/bin/bash
echo "=== GitHub Runner Debug Information ==="
echo "Generated: $(date)"
echo ""

echo "=== System Information ==="
uname -a
lsb_release -a 2>/dev/null || cat /etc/os-release
echo ""

echo "=== Runner Status ==="
systemctl status github-runner --no-pager -l
echo ""

echo "=== Recent Logs ==="
journalctl -u github-runner --no-pager -n 20
echo ""

echo "=== Configuration ==="
ls -la /home/github-runner/
if [ -f /home/github-runner/.runner ]; then
    echo "Runner configuration exists"
else
    echo "No runner configuration found"
fi
echo ""

echo "=== Resources ==="
free -h
df -h
uptime
echo ""

echo "=== Network ==="
curl -I https://api.github.com
echo ""

echo "=== Process ==="
ps aux | grep -E "(Runner|github)" | grep -v grep
echo ""
EOF

chmod +x ~/collect-debug-info.sh
~/collect-debug-info.sh > runner-debug-$(date +%Y%m%d-%H%M%S).txt
```

### Support Channels

1. **GitHub Issues**: Create detailed issue with debug information
2. **Documentation**: Check our comprehensive docs in `/docs/` directory
3. **Community**: GitHub Discussions for questions and tips
4. **Security Issues**: Report privately to security team

---

**Remember**: Most issues can be resolved by following the diagnostic steps above. Always collect debug information before seeking help, and never share sensitive tokens or credentials in public forums.

For additional help:
- **[Security Guide](security.md)** - Security-related troubleshooting
- **[VPS Setup](vps-setup.md)** - VPS-specific issues
- **[Local Setup](local-setup.md)** - Local environment issues
- **[Multi-Runner Setup](multi-runner.md)** - Multiple runner issues

**Troubleshooting is Systematic** - Follow the diagnostic steps methodically for best results.

---
*Crafted by [Gabel @ Booplex.com](https://booplex.com) - 50% human, 50% AI, 100% trying our best.*