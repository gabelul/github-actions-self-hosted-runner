# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.3.0] - 2025-09-30

### Changes
- feat: add automated semantic versioning and release system (72f32a9)
- fix: resolve CI workflow failures - arithmetic bugs and Docker conflicts (fd51fd5)
- chore: remove temporary test-suite.sh from root directory (693f728)
- fix: prevent set -e exit on arithmetic operations starting from zero (2e1db76)
- fix: redirect all log functions to stderr to prevent command substitution contamination (43159e4)
- fix: use .env file for docker-compose to avoid YAML escaping issues (df3ad2e)
- fix: prevent duplicate menu and quote docker-compose env vars (b0dc98a)
- fix: skip token save prompt when token already saved (4b13293)
- fix: set -e causing script to exit on non-zero return codes (34d289c)
- debug: add trace output for multi-repo runner creation flow (0590eb8)
- fix: wizard exits instead of creating new runner (d06a441)
- fix: properly handle multi-repository runner setup (39101ca)
- fix: menu not redisplaying when returning from runner operations (54ff061)
- fix: update GitHub API authentication to Bearer token format (cb59313)
- fix: wizard continues after going back from runner management (b6dc3ab)
- fix: resolve token management bugs and add retry limits (78d792d)
- feat: add comprehensive code quality and testing infrastructure (52074b6)
- refactor: move test script to proper location and enhance CI (af08c11)
- test: add comprehensive token management testing and fix unbound variable issue (1c0451a)
- fix: enhance multi-repository token handling and validation (76e28e4)

## [2.2.3] - 2025-09-27

### Fixed
- **🔐 Enhanced Token Encryption**: Implemented OpenSSL AES-256-CBC encryption as primary method with XOR fallback
  - Fixed OpenSSL command syntax to use `aes-256-cbc` instead of `enc -aes-256-cbc`
  - Proper encryption/decryption flow with base64 encoding
  - Maintains backward compatibility with existing XOR-encrypted tokens
- **🛡️ Token Validation**: Added comprehensive token validation after decryption
  - Automatic detection and cleanup of corrupted tokens
  - Minimum length validation (20+ characters for GitHub tokens)
  - Token preview in debug output for troubleshooting
- **🔧 Script Compatibility**: Fixed BASH_SOURCE parameter expansion issues
  - Proper handling when script is sourced vs executed directly
  - Prevents "parameter not set" errors in strict mode
- **📱 Function Structure**: Cleaned up decrypt_token function structure and removed duplicate code

### Security
- Token encryption now uses industry-standard AES-256-CBC with OpenSSL when available
- Fallback XOR encryption maintains compatibility with existing installations
- Enhanced error handling prevents token corruption issues

## [2.2.2] - 2025-09-27

### Fixed
- **🔄 Workflow Migration Critical Fix**: Fixed bash arithmetic increment that caused migration to stop after first workflow
  - Replaced `((success_count++))` with `success_count=$((success_count + 1))` to avoid zero-evaluation exit code
  - Now properly processes all workflows instead of stopping after the first conversion
  - Affects both `migrate_workflows()` and `update_workflows()` functions

## [2.2.1] - 2025-09-26

### Fixed
- **🔧 Token Encryption Issues**: Fixed XOR cipher NULL byte handling that caused token corruption
  - Replaced character-based XOR with hex-based implementation
  - All GitHub token formats now encrypt/decrypt correctly
- **📂 Temporary Directory Management**: All temporary files now use project directory instead of system `/tmp`
  - Created organized `.tmp/` structure with subdirectories for migrations, tests, backups, installs
  - Improved security and portability for all temporary operations
- **🔄 Workflow Migration Fixes**: Fixed missing output redirection in workflow conversion
  - Workflow files now convert properly from GitHub-hosted to self-hosted runners
  - Fixed directory handling in migration process

### Changed
- All scripts now use project-based temporary directories for better organization
- Enhanced security with proper file permissions (700) for temp directories
- Automatic cleanup of temporary files older than 24 hours

## [2.0.0] - 2025-01-19

### Added
- **🧙‍♂️ Interactive Setup Wizard**: Run `./setup.sh` without arguments for guided configuration
  - Smart GitHub CLI token detection and integration
  - Repository suggestions from user's GitHub account
  - Installation method selection (Docker vs Native)
  - Configuration summary with confirmation before proceeding
- **🧪 Post-Setup Testing Integration**: Automatic test offer after successful installation
  - Integrates with existing test.sh validation system
  - Fallback basic connectivity testing if test.sh unavailable
  - Clear success/failure feedback with next steps
- **🔄 Enhanced Workflow Migration System**:
  - `scan` command: Quick migration opportunity detection (works from any directory)
  - `update` command: Non-interactive bulk workflow migration with backup
  - Improved workflow detection across multiple directory structures
  - Real-time cost estimation and savings calculation
- **⚡ Comprehensive Workflow Automation**:
  - 6 pre-built workflow templates (Node.js, Python, Docker, Deploy, Matrix, Security)
  - Interactive workflow generator with guided setup
  - Smart backup system with timestamped files and rollback instructions
  - Multi-environment migration support
- **📊 Advanced Usage Analysis**:
  - Detailed GitHub Actions usage reports
  - Cost breakdown with monthly savings estimates
  - Migration impact assessment
- **🎯 Seamless Setup Flow**: Complete Setup → Test → Migration pipeline
  - Context-aware workflow detection in repository
  - Automatic post-setup offers for testing and migration
  - Smart integration between all components

### Changed
- **Enhanced GitHub CLI Integration**: Better token detection and user experience
- **Improved Repository Validation**: Better error handling and user guidance
- **Expanded Help System**: Interactive mode documentation and examples
- **Workflow Helper Interface**: Added scan and update commands to existing migrate functionality
- **Setup Process**: Now defaults to interactive mode when no arguments provided

### Fixed
- **GitHub Token Detection**: Improved validation for different token formats (ghp_, gho_, ghu_, etc.)
- **Cross-Platform Architecture Detection**: Better ARM64/x86_64 compatibility
- **Registration Token Generation**: Fixed API endpoint issues and token parsing
- **Error Handling**: More graceful failures with helpful guidance

### Security
- **Enhanced Token Storage**: Improved encryption and access control
- **User Isolation**: Better sandboxing for runner processes
- **Backup Protection**: Secure backup file permissions and storage

## [1.0.0] - 2025-01-16

### Added
- Initial release of GitHub Self-Hosted Runner Universal Tool
- **Multi-Platform Support**: Ubuntu, Debian, CentOS, Rocky Linux, macOS
- **Docker Integration**: Complete containerized deployment option
- **Security-First Design**: Non-root execution, token encryption, network hardening
- **Multi-Runner Management**: Support for multiple runners on single machine
- **SystemD Service Integration**: Auto-start and monitoring capabilities
- **Comprehensive Documentation**: VPS setup, local setup, troubleshooting guides
- **Testing Framework**: Multi-environment validation system
- **Health Monitoring**: Runner status tracking and automated recovery
- **Basic Workflow Migration**: Initial workflow conversion capabilities

### Security
- Implemented secure token handling and storage
- Added user isolation and privilege separation
- Configured network security and firewall rules
- Added comprehensive logging and audit trails

---

## Migration Guide: v1.x → v2.0

### Breaking Changes
None! v2.0 is fully backward compatible with v1.x installations.

### New Features to Try
1. **Interactive Setup**: Try `./setup.sh` without arguments for the new wizard experience
2. **Workflow Migration**: Use `./scripts/workflow-helper.sh scan` to see migration opportunities
3. **Quick Updates**: Use `./scripts/workflow-helper.sh update` for fast workflow conversion

### Recommended Upgrade Steps
1. Pull the latest changes: `git pull origin main`
2. Test the interactive setup: `./setup.sh --dry-run`
3. Scan your workflows: `./scripts/workflow-helper.sh scan`
4. Consider migrating workflows: `./scripts/workflow-helper.sh migrate .`

---

## Future Releases

### [2.1.0] - Planned
- Windows PowerShell support for local Windows development
- Kubernetes deployment templates
- Web dashboard for multi-runner monitoring
- Auto-scaling based on GitHub Actions queue

### [2.2.0] - Planned
- Cloud provider integration (AWS, DigitalOcean, Linode)
- Advanced security scanning and compliance reports
- Performance analytics and optimization suggestions
- Team management and access controls

---

*For detailed information about any release, see the [GitHub Releases](https://github.com/gabel/github-self-hosted-runner/releases) page.*