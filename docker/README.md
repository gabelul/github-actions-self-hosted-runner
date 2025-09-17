# Docker GitHub Actions Self-Hosted Runner

Easy Docker deployment for GitHub Actions self-hosted runners with production-ready configuration.

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- GitHub Personal Access Token with `repo` scope
- Target GitHub repository access

### One-Command Setup

```bash
# 1. Clone and navigate to docker directory
git clone [repository-url]
cd github-self-hosted-runner/docker

# 2. Configure environment
cp .env.example .env
nano .env  # Edit GITHUB_TOKEN and GITHUB_REPOSITORY

# 3. Deploy runner
docker-compose up -d

# 4. Verify deployment
docker-compose logs -f github-runner
```

## 📋 Configuration

### Required Settings

Edit `.env` file with your configuration:

```bash
# Required
GITHUB_TOKEN=ghp_your_personal_access_token_here
GITHUB_REPOSITORY=owner/repository-name

# Optional (with defaults)
RUNNER_NAME=my-docker-runner
RUNNER_LABELS=self-hosted,linux,x64,docker
```

### GitHub Token Setup

1. Go to https://github.com/settings/tokens/new
2. Create token with `repo` scope (and `admin:org` for organization runners)
3. Copy token to `GITHUB_TOKEN` in `.env` file

## 🐳 Docker Commands

### Basic Operations

```bash
# Start runner
docker-compose up -d

# View logs
docker-compose logs -f github-runner

# Stop runner
docker-compose down

# Restart runner
docker-compose restart github-runner

# Update runner image
docker-compose pull && docker-compose up -d
```

### Health Monitoring

```bash
# Check runner health
docker-compose exec github-runner ./health-check.sh

# Detailed health report
docker-compose exec github-runner ./health-check.sh verbose

# View resource usage
docker stats github-runner
```

### Maintenance

```bash
# Shell into container
docker-compose exec github-runner bash

# View runner configuration
docker-compose exec github-runner cat .runner

# Manual runner registration (if needed)
docker-compose exec github-runner ./entrypoint.sh register

# Remove runner configuration
docker-compose exec github-runner ./entrypoint.sh remove
```

## 🔧 Multi-Runner Setup

Run multiple runners on the same machine:

```bash
# Primary runner (default)
docker-compose up -d

# Secondary runner with different name
RUNNER_NAME=runner-2 docker-compose --project-name runner2 up -d

# GPU runner with special labels
RUNNER_NAME=gpu-runner \
RUNNER_LABELS=self-hosted,linux,x64,docker,gpu \
docker-compose --project-name gpu-runner up -d
```

## 📊 Production Deployment

### Resource Configuration

For production workloads, adjust resource limits in `.env`:

```bash
# Production settings
CPU_LIMIT=4.0
MEMORY_LIMIT=8G
CPU_RESERVATION=1.0
MEMORY_RESERVATION=2G
```

### Security Settings

```bash
# Enhanced security
EPHEMERAL=true           # Auto-remove after each job
DISABLE_AUTO_UPDATE=false  # Keep runner updated
DEBUG=false              # Disable debug logging
```

### Monitoring Setup

Enable monitoring profile for health endpoints:

```bash
# Start with monitoring
docker-compose --profile monitoring up -d

# Access health endpoint
curl http://localhost:8080
```

## 🔒 Security Features

### Container Security

- **Non-root execution**: Runner runs as `github-runner` user
- **Resource limits**: CPU and memory constraints
- **Security options**: `no-new-privileges` enabled
- **Volume isolation**: Restricted volume mounts

### Token Security

- **Environment variables**: Tokens stored securely
- **No logging**: Tokens never appear in logs
- **Rotation support**: Easy token updates via `.env`

### Network Security

- **Bridge network**: Isolated container network
- **No exposed ports**: Container doesn't expose external ports
- **GitHub HTTPS**: All communication over HTTPS

## 🐛 Troubleshooting

### Common Issues

#### Runner Registration Fails

```bash
# Check token permissions
curl -H "Authorization: token $GITHUB_TOKEN" \
     https://api.github.com/repos/OWNER/REPO

# Verify repository access
docker-compose exec github-runner \
    curl -H "Authorization: token $GITHUB_TOKEN" \
         https://api.github.com/repos/$GITHUB_REPOSITORY
```

#### Docker-in-Docker Issues

```bash
# Verify Docker socket mount
docker-compose exec github-runner ls -la /var/run/docker.sock

# Test Docker access
docker-compose exec github-runner docker version

# Check user groups
docker-compose exec github-runner groups
```

#### Resource Issues

```bash
# Check resource usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# View detailed resource limits
docker inspect github-runner | grep -A 10 "Resources"

# Monitor disk space
docker system df
docker-compose exec github-runner df -h
```

### Debug Mode

Enable detailed logging:

```bash
# Set in .env file
DEBUG=true

# Restart with debug
docker-compose up -d

# View debug logs
docker-compose logs -f github-runner
```

### Health Diagnostics

```bash
# Comprehensive health check
docker-compose exec github-runner ./health-check.sh verbose

# Manual diagnostics
docker-compose exec github-runner bash -c "
  echo '=== System Info ==='
  uname -a
  echo '=== Disk Space ==='
  df -h
  echo '=== Memory ==='
  free -h
  echo '=== Processes ==='
  ps aux | grep -i runner
"
```

## 📚 Advanced Configuration

### Custom Docker Image

Build custom runner image with additional tools:

```dockerfile
# Dockerfile.custom
FROM github-runner:latest

# Install additional tools
RUN apt-get update && apt-get install -y \
    custom-tool-1 \
    custom-tool-2 \
    && rm -rf /var/lib/apt/lists/*

# Add custom scripts
COPY custom-scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*
```

Build and use:

```bash
# Build custom image
docker build -f Dockerfile.custom -t github-runner:custom .

# Update docker-compose.yml
services:
  github-runner:
    image: github-runner:custom
    # ... rest of configuration
```

### Volume Persistence

Configure persistent storage:

```yaml
# docker-compose.override.yml
version: '3.8'
services:
  github-runner:
    volumes:
      - ./persistent-data:/home/github-runner:rw
      - ./runner-cache:/home/github-runner/.cache:rw
      - ./custom-config:/home/github-runner/config:ro
```

### Environment Overrides

Create environment-specific configurations:

```bash
# docker-compose.prod.yml
version: '3.8'
services:
  github-runner:
    environment:
      RUNNER_LABELS: self-hosted,linux,x64,docker,production
      EPHEMERAL: true
    deploy:
      resources:
        limits:
          cpus: '4.0'
          memory: 8G

# Deploy production
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## 📈 Monitoring and Metrics

### Log Aggregation

Use log profiles for centralized logging:

```bash
# Start with log aggregation
docker-compose --profile logging up -d

# View aggregated logs
docker-compose exec runner-logs tail -f /fluentd/log/docker.log
```

### Metrics Collection

Monitor runner performance:

```bash
# Real-time stats
watch docker stats github-runner

# Resource usage over time
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" \
    --no-stream

# Container inspection
docker inspect github-runner | jq '.State'
```

### Health Endpoints

Set up external monitoring:

```bash
# Enable monitoring profile
MONITOR_PORT=8080 docker-compose --profile monitoring up -d

# Health check endpoint
curl http://localhost:8080

# Prometheus metrics (if configured)
curl http://localhost:8080/metrics
```

## 🔄 Maintenance

### Updates

Regular maintenance tasks:

```bash
# Update runner image
docker-compose pull
docker-compose up -d

# Clean up old images
docker image prune -f

# Clean up old containers
docker container prune -f

# Clean up volumes (careful!)
docker volume ls
docker volume prune
```

### Backup

Backup runner configuration:

```bash
# Backup runner data
docker cp github-runner:/home/github-runner/.runner ./backup/
docker cp github-runner:/home/github-runner/.credentials ./backup/

# Backup environment
cp .env .env.backup

# Create full backup
tar czf runner-backup-$(date +%Y%m%d).tar.gz \
    .env docker-compose.yml backup/
```

### Migration

Move runner to new host:

```bash
# On old host - remove runner cleanly
docker-compose exec github-runner ./entrypoint.sh remove
docker-compose down

# Backup configuration
tar czf runner-config.tar.gz .env docker-compose.yml

# On new host - restore and start
tar xzf runner-config.tar.gz
docker-compose up -d
```

---

## 📖 Additional Resources

- **Main Documentation**: `../CLAUDE.md` - Comprehensive system documentation
- **Universal Setup**: `../setup.sh` - VPS and local installation script
- **Native Setup**: `../docs/` - Non-Docker installation guides
- **Security Guide**: `../docs/security.md` - Security best practices
- **Troubleshooting**: `../docs/troubleshooting.md` - Common issues and solutions

---

**Docker Deployment Guide** - Part of the GitHub Self-Hosted Runner Universal Tool