# Want to Help? We'd Love That! 🎉

Hey there! Thanks for thinking about contributing to our GitHub runner project. Whether you're a coding wizard or someone who's never contributed to open source before, we're excited you're here!

**First time contributing to open source?** Perfect! We wrote this guide specifically for people like you. Don't worry - we've all been beginners, and the community is super friendly and helpful.

## 🤔 What Even Is This Project?

This project helps people run GitHub Actions on their own servers instead of paying GitHub's expensive prices. Think of it like this:

- **GitHub's way:** Rent their kitchen to cook your meals (expensive)
- **Our way:** Use your own kitchen to cook the same meals (way cheaper!)

We built this because we got tired of paying so much for GitHub Actions minutes. Now thousands of developers save money with it!

## 👋 Never Done This Before? Start Here!

Don't worry about having everything figured out. Here's what you need to know:

### What You'll Need
- A computer (Mac, Windows with WSL, or Linux)
- Basic comfort with the command line (we'll help you!)
- A GitHub account
- Willingness to learn (most important!)

**Don't have these technical skills yet?**
- GitHub Actions workflows ← We'll teach you
- Linux commands ← We'll show you what you need
- Shell scripting ← You can learn as you go
- Docker ← Only needed for some contributions

### Your First Day Setup

1. **Get Your Own Copy**
   ```bash
   # Fork the project on GitHub first (big green button), then:
   git clone https://github.com/gabelul/github-self-hosted-runner.git
   cd github-self-hosted-runner
   ```

2. **Look Around**
   ```bash
   # Take a look at what we've built
   ls -la

   # Read about how everything works (optional but interesting!)
   cat CLAUDE.md
   ```

3. **Test That Everything Works**
   ```bash
   # Make sure our tests pass on your computer
   ./scripts/test-suite.sh --check-environment

   # Run some basic tests (don't worry if you don't understand them yet)
   ./scripts/test-suite.sh --unit-tests
   ```

**Stuck already?** No worries! [Open an issue](../../issues) and tell us where you got stuck. We love helping newcomers!

## 🎨 How You Can Help (Pick What Sounds Fun!)

### 🐛 Found Something Broken?
**Perfect for:** Anyone who uses the tool

- **Something doesn't work?** Tell us about it! Even if you can't fix it, reporting it helps everyone.
- **Documentation confusing?** Let us know what didn't make sense.
- **Error message unclear?** Help us make it better.
- **Security concern?** We take these super seriously.

**How to report:** [Open an issue](../../issues) and tell us what happened. Don't worry about being "technical enough" - your perspective is valuable!

### ✨ Want to Add Something Cool?
**Perfect for:** People who like to build things

- **Support for your operating system** (Windows, different Linux flavors)
- **New ways to install** (maybe a web interface?)
- **Better monitoring** (dashboards, alerts, pretty graphs)
- **Performance improvements** (make it faster!)

**Don't know how to code it?** That's fine! Share your idea in [Discussions](../../discussions) and maybe someone else will love it too.

### 📚 Love to Explain Things?
**Perfect for:** Teachers, writers, people who like helping others

- **Write setup guides** for platforms we don't cover yet
- **Create troubleshooting docs** when you figure out tricky problems
- **Make examples** for common use cases
- **Improve our explanations** when something is confusing

### 🧪 Like to Break Things (In a Good Way)?
**Perfect for:** Detail-oriented people, QA folks, security enthusiasts

- **Test on different systems** and report what works/doesn't work
- **Look for security issues** (we'll credit you for finding them!)
- **Try edge cases** that most people wouldn't think of
- **Performance testing** on different server sizes

## 🛠️ Ready to Make Your First Change?

Here's the step-by-step process (don't worry, it's easier than it looks!):

### 1. Tell Us What You Want to Work On
- **Found a bug?** [Open an issue](../../issues) describing what's broken
- **Have an idea?** [Start a discussion](../../discussions) to chat about it
- **Want to help but not sure how?** Check our [open issues](../../issues) for things marked "good first issue"

### 2. Make Your Own Copy to Work On
```bash
# Create your own branch (like your own workspace)
git checkout -b fix/make-setup-clearer
# or
git checkout -b feature/add-windows-support
```

### 3. Make Your Changes
- **Fixing bugs?** Change what's broken and test that it works
- **Adding features?** Build it and make sure it doesn't break existing stuff
- **Improving docs?** Make them clearer and more helpful
- **Don't forget:** Update any relevant documentation

### 4. Test Your Changes (Important!)
```bash
# Make sure you didn't break anything
./scripts/test-suite.sh

# If you're feeling thorough, test on different systems
./scripts/test-environments.sh

# Check that security is still good
./scripts/security-audit.sh
```

### 5. Share Your Work
- **Create a Pull Request** on GitHub
- **Describe what you changed** and why
- **Link to any related issues**
- **Don't be shy!** Explain what you learned or what was tricky

**First pull request?** We'll help you through the process. Every expert was once a beginner!

## 🛠️ Development Guidelines

### Coding Standards

#### Shell Script Standards

```bash
#!/bin/bash

# File header with description and usage
# GitHub Actions Self-Hosted Runner - [Script Purpose]
#
# Brief description of what this script does
#
# Usage:
#   ./script.sh [OPTIONS]

set -euo pipefail  # Always use strict mode

# Use readonly for constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="1.0.0"

# Use descriptive variable names
GITHUB_TOKEN=""
REPOSITORY_NAME=""
RUNNER_INSTANCE_NAME=""

# Function naming: verb_noun or action_target
configure_runner() {
    local token="$1"
    local repo="$2"

    # Validate inputs
    if [[ -z "$token" ]]; then
        log_error "GitHub token is required"
        return 1
    fi

    # Implementation
}

# Always include help function
show_help() {
    cat << EOF
Script Name - Brief Description

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --option VALUE    Description
    --help           Show this help

EXAMPLES:
    $0 --option value
EOF
}
```

#### Documentation Standards

- **Comments**: Explain the "why", not the "what"
- **Function headers**: Document parameters and return values
- **Complex logic**: Add inline comments for clarity
- **Examples**: Provide usage examples in help text

#### Security Standards

```bash
# ✅ GOOD - Secure practices
validate_input() {
    local input="$1"

    # Input validation
    if [[ ! "$input" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        log_error "Invalid input format"
        return 1
    fi
}

# Secure file operations
sudo -u github-runner mkdir -p "$SECURE_DIR"
sudo -u github-runner chmod 700 "$SECURE_DIR"

# ❌ BAD - Security anti-patterns
# Don't do these:
eval "$user_input"  # Command injection risk
cp "$user_file" /system/  # Path traversal risk
echo "$token" > /tmp/token  # Insecure storage
```

### Testing Requirements

#### Unit Testing

```bash
# Test functions in isolation
test_validate_github_token() {
    # Test valid token
    if validate_github_token "ghp_valid_token_format_here"; then
        echo "✅ Valid token test passed"
    else
        echo "❌ Valid token test failed"
        return 1
    fi

    # Test invalid token
    if ! validate_github_token "invalid_token"; then
        echo "✅ Invalid token test passed"
    else
        echo "❌ Invalid token test failed"
        return 1
    fi
}
```

#### Integration Testing

```bash
# Test complete workflows
test_full_runner_setup() {
    local test_token="$1"
    local test_repo="$2"

    # Setup test environment
    local test_dir="/tmp/runner-test-$$"
    mkdir -p "$test_dir"

    # Run setup process
    if ./setup.sh --token "$test_token" --repo "$test_repo" --install-dir "$test_dir"; then
        echo "✅ Integration test passed"
        cleanup_test_environment "$test_dir"
        return 0
    else
        echo "❌ Integration test failed"
        cleanup_test_environment "$test_dir"
        return 1
    fi
}
```

#### Platform Testing

Test across different environments:

- **Ubuntu 20.04/22.04** (Primary support)
- **Debian 11/12** (Secondary support)
- **CentOS 8 / Rocky Linux** (Enterprise support)
- **macOS** (Local development)
- **Docker containers** (Containerized deployment)

### Documentation Guidelines

#### README Updates

When adding features, update:
- Feature list in main README
- Usage examples
- Supported environments table
- Installation instructions

#### CLAUDE.md Maintenance

**Critical**: Always update CLAUDE.md when modifying:
- System architecture
- Security patterns
- Installation workflows
- Testing procedures

```bash
# Update the modification tracking
- **Last Modified**: $(date +%Y-%m-%d)
- **Last Claude Review**: $(date +%Y-%m-%d)
- **Work Sessions**: $((CURRENT_COUNT + 1))
```

## 🔒 Security Guidelines

### Security Review Checklist

- [ ] **Input Validation**: All user inputs are validated
- [ ] **Privilege Escalation**: No unnecessary root operations
- [ ] **Secret Management**: Tokens and secrets handled securely
- [ ] **Path Traversal**: File paths are validated and restricted
- [ ] **Command Injection**: No dynamic command construction
- [ ] **Network Security**: Outbound connections are restricted
- [ ] **File Permissions**: Appropriate file and directory permissions

### Security Testing

```bash
# Run security audit
./scripts/security-audit.sh

# Test with malicious inputs
test_malicious_inputs() {
    local malicious_inputs=(
        "../../etc/passwd"
        "\$(rm -rf /)"
        "; cat /etc/shadow"
        "../../../../../etc/hosts"
    )

    for input in "${malicious_inputs[@]}"; do
        if validate_input "$input"; then
            echo "❌ Security test failed for: $input"
            return 1
        fi
    done

    echo "✅ Security tests passed"
}
```

## 🧪 Testing Framework

### Running Tests

```bash
# Full test suite
./scripts/test-suite.sh

# Specific test categories
./scripts/test-suite.sh --unit-tests
./scripts/test-suite.sh --integration-tests
./scripts/test-suite.sh --security-tests

# Platform-specific tests
./scripts/test-environments.sh --ubuntu
./scripts/test-environments.sh --debian
./scripts/test-environments.sh --docker
```

### Writing New Tests

```bash
# Test file: tests/test-runner-setup.sh
#!/bin/bash

source "$(dirname "$0")/../scripts/test-framework.sh"

test_runner_installation() {
    local test_name="Runner Installation Test"

    # Setup
    local temp_dir=$(mktemp -d)

    # Test
    if setup_runner_test_environment "$temp_dir"; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Setup failed"
    fi

    # Cleanup
    rm -rf "$temp_dir"
}

# Run tests
run_tests test_runner_installation
```

## 📊 Performance Guidelines

### Optimization Priorities

1. **Startup Time**: Minimize runner startup latency
2. **Resource Usage**: Efficient CPU and memory utilization
3. **Network Efficiency**: Minimize API calls and downloads
4. **Disk Usage**: Efficient cache management

### Performance Testing

```bash
# Benchmark runner startup
time ./setup.sh --token "$TOKEN" --repo "$REPO" --dry-run

# Monitor resource usage
./scripts/monitor-performance.sh --during-setup

# Test with multiple runners
./scripts/stress-test.sh --runners 5 --duration 300
```

## 📝 Documentation Standards

### Code Documentation

```bash
# Function documentation
# Configures a new GitHub Actions runner instance
# Globals:
#   GITHUB_TOKEN - GitHub personal access token
#   REPOSITORY - Target repository name
# Arguments:
#   $1 - Runner name
#   $2 - Installation directory (optional)
# Returns:
#   0 on success, 1 on error
configure_runner() {
    # Implementation
}
```

### Markdown Standards

- Use clear, descriptive headings
- Include code examples for complex procedures
- Add emoji icons for visual organization
- Cross-reference related documentation
- Keep language simple and accessible

## 🚨 Issue and PR Templates

### Bug Report Template

```markdown
**Bug Description**
Clear description of the bug

**Environment**
- OS: [Ubuntu 22.04]
- Architecture: [x64]
- Installation method: [native/docker]

**Reproduction Steps**
1. Step one
2. Step two
3. Step three

**Expected vs Actual**
- Expected: What should happen
- Actual: What actually happened

**Additional Context**
Logs, screenshots, configuration files
```

### Feature Request Template

```markdown
**Feature Description**
Clear description of the proposed feature

**Use Case**
Why is this feature needed?

**Implementation Ideas**
Suggested approach (optional)

**Additional Context**
Related issues, alternatives considered
```

## 🏗️ Release Process

### Version Numbering

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features, backward compatible
- **PATCH**: Bug fixes, backward compatible

### Release Checklist

- [ ] All tests pass on supported platforms
- [ ] Security audit completed
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version numbers updated
- [ ] Git tags created
- [ ] Release notes prepared

## 🤝 Community Guidelines

### Code of Conduct

We follow a simple code of conduct:

1. **Be respectful** of different viewpoints and experiences
2. **Be collaborative** and help others learn
3. **Focus on the technical merit** of contributions
4. **Keep discussions constructive** and professional
5. **Help newcomers** get up to speed

### Getting Help

- **Documentation**: Check the `docs/` directory first
- **Discussions**: Use GitHub Discussions for questions
- **Issues**: Report bugs and feature requests
- **Community**: Contribute to discussions and help others

## 📞 Contact and Support

- **Project Maintainer**: [Contact information]
- **Security Issues**: [Security contact]
- **General Questions**: GitHub Discussions
- **Bug Reports**: GitHub Issues

## 🙏 Recognition

We appreciate all contributions! Contributors will be:

- Listed in project documentation
- Mentioned in release notes
- Given appropriate credit in commit history
- Invited to join the contributor community

---

## About Booplex

This project is maintained by **[Gabel @ Booplex.com](https://booplex.com)** - a human who loves building stuff with AI so much, it's probably concerning.

We believe software should be:
- Powerful enough to impress your boss
- Simple enough that you don't need three PhDs to use it
- Fun enough that you don't hate your life while using it

**Our Process:** Human creativity + AI superpowers = Actually useful stuff

Want to see what other chaos we're creating? Visit [Booplex.com](https://booplex.com)!

*Disclaimer: No AI was harmed in the making of this project. Can't say the same for Gabel's sanity.*

---

**Thank you for contributing to our little corner of the internet!**

Your help makes it possible for developers worldwide to save money on GitHub Actions while keeping their sanity intact. That's pretty cool if you ask us!