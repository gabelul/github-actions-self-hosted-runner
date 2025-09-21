# Runner Scaling Guide

This guide explains when and how to scale your GitHub self-hosted runner setup from single to multiple runners, including performance benefits, cost considerations, and practical implementation strategies.

## Single Runner vs Multiple Runners

### Single Runner Architecture
```
┌─────────────────┐    ┌──────────────────┐
│   Repository A  │───▶│                  │
├─────────────────┤    │                  │
│   Repository B  │───▶│  Single Runner   │
├─────────────────┤    │                  │
│   Repository C  │───▶│                  │
└─────────────────┘    └──────────────────┘
```

### Multiple Runner Architecture
```
┌─────────────────┐    ┌──────────────────┐
│   Repository A  │───▶│    Runner 1      │
├─────────────────┤    ├──────────────────┤
│   Repository B  │───▶│    Runner 2      │
├─────────────────┤    ├──────────────────┤
│   Repository C  │───▶│    Runner 3      │
└─────────────────┘    └──────────────────┘
```

## Performance Benefits of Multiple Runners

### Parallel Job Execution

**The Primary Advantage**: Running multiple workflows simultaneously instead of queuing them.

#### Example Scenario
You have 3 workflows that each take 5 minutes:

**Single Runner (Sequential)**:
```
Test    ████████████████████ (0-5 min)
Build   ░░░░░░░░░░░░░░░░░░░░████████████████████ (5-10 min)
Deploy  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░████████████████████ (10-15 min)
Total: 15 minutes
```

**Multiple Runners (Parallel)**:
```
Test    ████████████████████ (0-5 min)
Build   ████████████████████ (0-5 min)
Deploy  ████████████████████ (0-5 min)
Total: 5 minutes
```

### Real-World Performance Impact

#### High-Traffic Repository Example
- **10 developers** pushing code throughout the day
- **Average workflow time**: 8 minutes
- **Commits per day**: 50

**Single Runner**:
- Total execution time: 50 × 8 = 400 minutes (6.7 hours)
- Last commit waits: ~6 hours
- Developer feedback delay: Unacceptable

**5 Runners**:
- Parallel execution: 400 ÷ 5 = 80 minutes (1.3 hours)
- Maximum wait time: ~8-16 minutes
- Developer feedback: Acceptable

## When to Scale: Decision Framework

### Stay with Single Runner If:
- **Low frequency**: < 10 workflows per day
- **Short duration**: Workflows complete in < 5 minutes
- **Small team**: 1-3 developers
- **Simple workflows**: No complex builds or tests
- **Cost-conscious**: Budget limitations

### Scale to Multiple Runners If:
- **High frequency**: > 20 workflows per day
- **Long duration**: Workflows take > 10 minutes
- **Large team**: > 5 developers
- **Queue complaints**: Developers report slow CI/CD
- **Complex workflows**: Matrix builds, multiple environments

### Decision Tree
```
Start: Do you have workflow queuing issues?
├─ No → Stay with single runner
└─ Yes
   ├─ Are workflows > 10 minutes?
   │  ├─ Yes → Add 2-3 runners immediately
   │  └─ No → Monitor for 1 week, then decide
   └─ Team size > 10 people?
      ├─ Yes → Consider runner pool (5+ runners)
      └─ No → Add 1-2 runners
```

## Runner Configuration Strategies

### Strategy 1: Resource-Based Separation

```bash
# Light workloads (unit tests, linting)
runner-light:   2 CPU, 4GB RAM
  └── Unit tests, code linting, small builds

# Medium workloads (integration tests)
runner-medium:  4 CPU, 8GB RAM
  └── Integration tests, medium builds

# Heavy workloads (full builds, deployments)
runner-heavy:   8 CPU, 16GB RAM
  └── Docker builds, deployment, compilation
```

### Strategy 2: Environment-Based Separation

```bash
# Development environment
runner-dev:     Fast feedback, loose security
  └── PR validation, development branches

# Staging environment
runner-staging: Production-like testing
  └── Pre-production validation

# Production environment
runner-prod:    High security, controlled access
  └── Production deployments only
```

### Strategy 3: Technology Stack Separation

```bash
# Frontend stack
runner-frontend: Node.js, npm, yarn, browser testing tools
  └── React, Vue, Angular projects

# Backend stack
runner-backend:  Python, Java, Go, database tools
  └── API services, microservices

# DevOps stack
runner-devops:   Docker, Kubernetes, cloud CLI tools
  └── Infrastructure, deployments
```

### Strategy 4: Team-Based Separation

```bash
# Team Alpha
runner-team-alpha: Team A repositories and preferences
  └── Team A projects

# Team Beta
runner-team-beta:  Team B repositories and preferences
  └── Team B projects

# Shared Infrastructure
runner-infra:      Shared services and infrastructure
  └── Common libraries, shared deployments
```

## Cost-Benefit Analysis

### Single Runner Economics

**Costs**:
- 1 server: $20-50/month
- Maintenance: 2 hours/month
- Setup complexity: Low

**Benefits**:
- Simple management
- Lower resource usage
- Single point of configuration

**Break-even**: Teams with < 20 workflows/day

### Multiple Runner Economics

**Costs**:
- Multiple servers: $60-200/month
- Maintenance: 4-6 hours/month
- Setup complexity: Medium-High

**Benefits**:
- Parallel execution saves developer time
- Better developer experience
- Reduced bottlenecks
- Higher team productivity

**Break-even**: Teams with > 30 workflows/day

### ROI Calculation Example

**Assumptions**:
- 10 developers at $50/hour
- 5 workflows/day/developer = 50 total
- Single runner causes 30-minute average delay
- Multiple runners reduce delay to 5 minutes

**Time Savings**:
- Per workflow: 25 minutes saved
- Per day: 50 × 25 = 1,250 minutes (20.8 hours)
- Monthly value: 20.8 × 22 × $50 = $22,880

**Additional Costs**:
- Extra servers: $150/month
- Extra maintenance: $200/month
- Total extra cost: $350/month

**ROI**: $22,880 - $350 = $22,530/month return

## Security Considerations

### Runner Isolation Benefits

**Separate sensitive workloads**:
```bash
# Public repositories
runner-public:    Open source projects, public workflows
  └── Lower security requirements

# Private repositories
runner-private:   Proprietary code, internal projects
  └── Standard security measures

# Sensitive operations
runner-secure:    Production deployments, secrets access
  └── Enhanced security, restricted access
```

### Access Control Strategies

1. **Network Isolation**: Different runners on different network segments
2. **Credential Separation**: Each runner accesses only required secrets
3. **Audit Trails**: Separate logging for sensitive operations
4. **Principle of Least Privilege**: Runners have minimal required permissions

## Management and Maintenance

### Single Runner Maintenance

**Advantages**:
- One system to update
- Simple monitoring
- Single configuration
- Easy troubleshooting

**Tasks**:
- Weekly health checks
- Monthly updates
- Quarterly capacity review

### Multiple Runner Maintenance

**Challenges**:
- Configuration drift between runners
- Multiple systems to monitor
- Complex troubleshooting
- Resource planning

**Best Practices**:
- **Configuration Management**: Use infrastructure as code
- **Monitoring**: Centralized monitoring for all runners
- **Updates**: Automated update processes
- **Documentation**: Clear runbook for each runner type

### Automation Tools

```bash
# Health check all runners
./scripts/health-check-all.sh

# Update all runners
./scripts/update-all-runners.sh

# Monitor runner usage
./scripts/runner-metrics.sh

# Scale runners based on queue depth
./scripts/auto-scale-runners.sh
```

## Practical Implementation Guide

### Phase 1: Single Runner (Start Here)
1. Deploy one runner using setup.sh
2. Monitor usage for 2-4 weeks
3. Document pain points and bottlenecks
4. Measure workflow frequency and duration

### Phase 2: Add Second Runner (Scale Point)
**Trigger**: Regular queuing or complaints about slow CI/CD

1. Use setup.sh with different name
2. Configure for different workload type
3. Update workflows to use appropriate runner
4. Monitor distribution and effectiveness

### Phase 3: Runner Pool (Growth)
**Trigger**: Multiple runners frequently busy

1. Deploy 3-5 runners with same configuration
2. Use generic labels (self-hosted, pool)
3. Let GitHub distribute workload automatically
4. Implement auto-scaling if needed

### Phase 4: Specialized Runners (Optimization)
**Trigger**: Different resource or security requirements

1. Analyze workflow patterns
2. Create specialized runner configurations
3. Update workflows with specific labels
4. Optimize resource allocation

## Monitoring and Metrics

### Key Metrics to Track

**Performance Metrics**:
- Average queue time
- Workflow completion time
- Runner utilization percentage
- Failed job rate

**Business Metrics**:
- Developer satisfaction
- Time to deployment
- CI/CD reliability
- Cost per workflow

### Monitoring Tools

```bash
# Basic monitoring
docker stats github-runner-*
systemctl status github-runner-*

# Advanced monitoring
prometheus + grafana
github actions usage API
custom dashboards
```

### Alerting Thresholds

- Queue time > 10 minutes
- Runner utilization > 80%
- Failed jobs > 5%
- Runner offline > 5 minutes

## Common Pitfalls and Solutions

### Pitfall 1: Over-Engineering Early
**Problem**: Creating complex multi-runner setup before needed
**Solution**: Start simple, scale based on actual pain points

### Pitfall 2: Configuration Drift
**Problem**: Runners become inconsistent over time
**Solution**: Use infrastructure as code, regular audits

### Pitfall 3: Poor Resource Allocation
**Problem**: Some runners overwhelmed, others idle
**Solution**: Monitor usage patterns, rebalance workloads

### Pitfall 4: Security Gaps
**Problem**: Inconsistent security across runners
**Solution**: Standardized security baseline, regular reviews

## Migration Strategies

### From Single to Multiple Runners

1. **Parallel Deployment**: Keep existing runner, add new ones
2. **Gradual Migration**: Move repositories one by one
3. **Testing Period**: Run both setups temporarily
4. **Rollback Plan**: Keep single runner as backup

### Workflow Label Updates

```yaml
# Before (single runner)
jobs:
  test:
    runs-on: self-hosted

# After (multiple specialized runners)
jobs:
  test:
    runs-on: [self-hosted, test-runner]
  build:
    runs-on: [self-hosted, build-runner]
  deploy:
    runs-on: [self-hosted, prod-runner]
```

## Future Scaling Options

### Auto-Scaling Solutions
- **Kubernetes**: Dynamic runner pods
- **Cloud Auto-Scaling**: VM instances based on queue depth
- **GitHub Hosted + Self-Hosted Hybrid**: Overflow to GitHub runners

### Enterprise Solutions
- **Runner Groups**: Organize runners by team/project
- **RBAC Integration**: Active Directory / SSO integration
- **Compliance**: SOC2, HIPAA, PCI compliance requirements

## Conclusion

The decision to scale from single to multiple runners should be data-driven and based on actual workflow patterns rather than theoretical needs. Start with a single runner, monitor its performance, and scale when you encounter real bottlenecks.

**Quick Decision Guide**:
- **< 10 workflows/day**: Single runner
- **10-50 workflows/day**: 2-3 runners
- **50+ workflows/day**: Runner pool (5+)
- **Enterprise scale**: Auto-scaling solution

Remember: The goal is developer productivity, not runner complexity. Scale when it solves real problems, not just because you can.