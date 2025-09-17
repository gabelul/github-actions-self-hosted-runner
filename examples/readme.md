# Workflow Examples

This directory contains example GitHub Actions workflows optimized for self-hosted runners.

## Available examples

### test-workflow.yml
A simple workflow to test that your self-hosted runner is working correctly.

**Use this to:**
- Verify your runner setup
- Test basic functionality
- Debug runner issues

**To use:**
```bash
cp examples/test-workflow.yml /path/to/your/repo/.github/workflows/
```

### production-workflow.yml
A comprehensive CI/CD pipeline demonstrating production-ready patterns.

**Features:**
- Parallel quality checks (linting, type checking, security audit)
- Matrix testing strategy (unit, integration, e2e)
- Multi-stage builds with Docker
- Environment-specific deployments (staging/production)
- Security scanning and compliance checks
- Automatic cleanup and maintenance

**Use this as a starting point for:**
- Node.js applications
- Containerized deployments
- Multi-environment workflows
- Security-conscious CI/CD

## Getting started

1. **Test your runner first:**
   ```bash
   ./test.sh
   ```

2. **Copy a workflow to your repository:**
   ```bash
   cp examples/test-workflow.yml /path/to/your/repo/.github/workflows/
   ```

3. **Customize for your needs:**
   - Update environment variables
   - Modify build commands
   - Add your deployment targets
   - Configure secrets

4. **Commit and run:**
   ```bash
   git add .github/workflows/
   git commit -m "Add self-hosted runner workflow"
   git push
   ```

## Customizing workflows

### Common modifications

**Change Node.js version:**
```yaml
env:
  NODE_VERSION: '20'  # or '16', '18', etc.
```

**Add your package manager:**
```yaml
# For Yarn
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    node-version: ${{ env.NODE_VERSION }}
    cache: 'yarn'

- name: Install dependencies
  run: yarn install --frozen-lockfile
```

**Update build commands:**
```yaml
- name: Build application
  run: |
    npm run build
    npm run test:build
```

### Adding secrets

For production workflows, you'll need to add secrets:

1. Go to your repository Settings → Secrets and variables → Actions
2. Add required secrets:
   - `DOCKER_USERNAME` - Container registry username
   - `DOCKER_PASSWORD` - Container registry password
   - `SLACK_WEBHOOK` - Slack notification webhook
   - Add others as needed for your deployment

### Environment configuration

For environment-specific deployments:

1. Go to Settings → Environments
2. Create environments (staging, production)
3. Add environment-specific secrets and variables
4. Configure protection rules (required reviewers, etc.)

## Self-hosted runner optimizations

These examples include optimizations for self-hosted runners:

### Caching strategies
```yaml
# Cache Node modules
- name: Setup Node.js
  uses: actions/setup-node@v4
  with:
    cache: 'npm'

# Cache Docker layers
- name: Build Docker image
  uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### Resource management
```yaml
# Parallel jobs for speed
strategy:
  matrix:
    test-suite: [unit, integration, e2e]

# Cleanup after workflows
- name: Clean up old Docker images
  run: docker image prune -f --filter "until=72h"
```

### Security practices
```yaml
# Use specific action versions
uses: actions/checkout@v4

# Scan for vulnerabilities
- name: Run security audit
  run: npm audit --audit-level moderate

# Container security scanning
- name: Scan Docker image
  run: docker scout cves ${{ needs.build.outputs.image-tag }}
```

## Best practices

### For development
- Start with `test-workflow.yml` to verify your setup
- Use pull request triggers for testing
- Keep workflows fast with parallel jobs

### For production
- Use environment protection rules
- Implement proper secret management
- Add comprehensive testing stages
- Include security scanning
- Set up proper monitoring and notifications

### For maintenance
- Regular cleanup of old images and artifacts
- Monitor runner resource usage
- Update action versions regularly
- Review and rotate secrets periodically

## Troubleshooting

### Workflow not running
- Check if your runner is online in repository Settings → Actions → Runners
- Verify workflow file syntax with `yamllint`
- Check if runner labels match your workflow requirements

### Runner out of resources
- Monitor disk space and memory usage
- Implement cleanup steps in workflows
- Consider multiple runners for heavy workloads

### Permission issues
- Ensure runner user has necessary permissions
- Check Docker group membership for container builds
- Verify access to required directories and files

## Contributing

Found an issue or have a better example? Feel free to:
- Report issues in the main repository
- Submit pull requests with improvements
- Share your workflow patterns

These examples are designed to get you started quickly while following best practices for self-hosted GitHub Actions runners.