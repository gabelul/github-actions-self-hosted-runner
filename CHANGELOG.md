# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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