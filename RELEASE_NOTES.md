# Release Notes - v2.4.0

**Release Date**: October 31, 2025  
**Release Type**: Major Feature Release  
**Status**: Stable ✅

## Overview

v2.4.0 is a **complete UI/UX redesign** of the GitHub self-hosted runner setup wizard, combined with critical bug fixes and macOS enhancements. This release transforms the setup experience from basic command-line prompts into a beautiful, interactive, and user-friendly wizard that guides users step-by-step through the installation process.

## ✨ Major Features

### 🎨 Complete UI/UX Overhaul

The setup wizard now features a professional visual design system with:

- **Beautiful boxes and visual separators** throughout the entire wizard flow
- **Color-coded output** with improved visual hierarchy (cyan for prompts, green for success, red for errors, yellow for warnings)
- **Step progress counter** showing "Step X/5" so users always know where they are in the process
- **Time estimates** for each step (2 minutes for authentication, 1 minute for repository selection, etc.)
- **Celebratory success screen** with clear next steps and management commands
- **Configuration summary box** allowing users to review all settings before confirming installation

### ✨ Enhanced Interactivity

- **Improved token input** with format validation and helpful suggestions
- **Collapsible help system** - users can skip or view full instructions as needed
- **Visual feedback** for all actions (✓ checkmarks for success, ✗ marks for errors)
- **Better menu formatting** with descriptive options for each choice
- **Enhanced confirmation prompts** with color-coded choices and visual cues

### 🔧 New UI Component Library

The wizard now includes 10+ reusable UI component functions:

```bash
print_box()           # Centered boxed messages with borders
print_separator()     # Visual line separators with colors
print_step()          # Step headers with progress counters and time estimates
print_section()       # Section headers with visual emphasis
print_menu_option()   # Formatted menu items with descriptions
print_status()        # Status indicators with checkmarks/X marks
show_config_summary() # Boxed configuration review with key-value pairs
show_spinner()        # Progress animation spinner
show_progress_dots()  # Verification feedback dots
show_progress_bar()   # Percentage-based progress bar
confirm_action()      # Visual confirmation dialogs
```

These functions maintain proper stderr/stdout separation and are available for use in other scripts.

### 🍎 macOS Enhancement

- **Auto-install Homebrew on macOS** when missing
- Automatic detection of macOS systems
- Seamless installation if Homebrew is not already present
- Eliminates manual setup steps for Mac users

## 🐛 Critical Bug Fixes

### Fix #1: Infinite Loop in Repository Input

**Severity**: Critical  
**Impact**: User could be trapped if entering invalid repository format

Previously, the repository input validation had no maximum attempt limit. If users kept entering invalid formats, they could be stuck in an infinite loop with no way out.

**Solution**: 
- Added maximum attempt limit of 3 tries
- Displays attempt counter showing "attempt 1/3", "attempt 2/3", etc.
- Provides helpful format example (owner/repo)
- Exits gracefully with error message if max attempts exceeded

### Fix #2: Silent Confirmation Input

**Severity**: High  
**Impact**: Poor user experience - users couldn't see their Y/n input

The confirmation prompt was using bash's `-s` flag which hides all user input. This confused users who couldn't see what they were typing.

**Solution**: 
- Removed `-s` flag from read command
- Users now see their Y/n input as they type
- Improved UX with clear visual feedback

### Fix #3: ANSI Color Code Rendering

**Severity**: High  
**Impact**: Color-coded output displayed literally instead of rendering

ANSI escape codes like `\033[0;36m` were displaying literally in the output instead of rendering as actual colors.

**Solution**: 
- Added `-e` flag to echo statements with color variables
- Fixed 13+ echo commands throughout the script
- All colors now render properly in all terminal environments
- UTF-8 special characters display correctly (✓, ✗, 🎉, →, ←, etc.)

## 🔄 Detailed Changes

### Setup Wizard Enhancements

The entire setup wizard has been reorganized into 5 clear steps:

1. **Step 1/5: GitHub Authentication (2 minutes)**
   - Collapsible help system for token creation
   - Token format validation
   - Error messages with suggestions
   - Optional token encryption and storage

2. **Step 2/5: Repository Selection (1 minute)**
   - Attempt counter (max 3 attempts)
   - Format validation with example
   - Helpful error messages
   - Graceful exit if max attempts exceeded

3. **Step 3/5: Installation Method (1 minute)**
   - Clear menu options (Native vs Docker)
   - Descriptions for each option
   - Visual selection indicator

4. **Step 4/5: Runner Name (1 minute)**
   - Suggested default name
   - Option for custom name
   - Visual formatting

5. **Step 5/5: Configuration Review (1 minute)**
   - Beautiful summary box with all settings
   - Token status
   - Repository details
   - Installation method
   - Runner name
   - Clear confirmation prompt

### Visual Design Elements

- Welcome banner with project name and version
- Box-drawing characters for professional appearance
- Color-coded sections and prompts
- Progress indicators throughout
- UTF-8 checkmarks and symbols
- Centered text with proper spacing
- Special attention to terminal width compatibility

## 📊 Testing Coverage

Comprehensive testing has been performed covering:

- ✅ All 10+ UI helper functions tested individually
- ✅ Complete wizard flow tested end-to-end
- ✅ Token input validation and error handling
- ✅ Repository input with max attempts
- ✅ Installation method selection
- ✅ Runner name configuration
- ✅ ANSI color code rendering verified
- ✅ UTF-8 special character handling
- ✅ Edge cases (long messages, special characters, unicode)
- ✅ Stderr/stdout separation maintained
- ✅ Error message formatting and visibility
- ✅ Configuration summary display accuracy

## 🔄 Backward Compatibility

✅ **Fully backward compatible** with v2.3.0 installations

- All existing runner configurations continue to work
- Token encryption format unchanged (OpenSSL AES-256-CBC with XOR fallback)
- SystemD service integration unchanged
- Docker deployment unchanged
- All existing runners will continue functioning

**No migration steps required** - existing installations work as-is.

## 📈 Performance Impact

- **Startup time**: Negligible increase (< 100ms) due to additional UI rendering
- **Memory usage**: No additional memory consumption
- **Disk space**: +50KB for enhanced script (primarily UI functions)

## 🔐 Security Notes

- No security changes or implications in this release
- Token encryption remains using OpenSSL AES-256-CBC
- File permissions unchanged
- User isolation unchanged

## 📚 Documentation Updates

The following documentation has been updated for v2.4.0:

- **README.md** - Updated with v2.4.0 feature highlights
- **CHANGELOG.md** - Comprehensive changelog with all features and fixes
- **docs/workflow-automation.md** - Workflow migration guide (no changes needed)
- **docs/security.md** - Security practices (no changes needed)
- **docs/troubleshooting.md** - Troubleshooting guide (no changes needed)

## 🚀 Installation Instructions

### Quick Start

```bash
# Clone or update the repository
git clone https://github.com/gabel/github-self-hosted-runner.git
cd github-self-hosted-runner

# Run the setup wizard (interactive)
./setup.sh

# Or dry-run to see without making changes
./setup.sh --dry-run
```

### Upgrade from v2.3.0

Simply pull the latest changes - no additional steps needed:

```bash
git pull origin main
./setup.sh  # Run wizard with enhanced UI
```

## 📉 Cost Savings Potential

With GitHub Actions self-hosted runners, you can save significant costs:

- **Free GitHub tier**: 2,000 minutes/month included
- **Each GitHub-hosted minute costs**: ~$0.008 (Pro tier)
- **Self-hosted runner savings**: ~$240-500/month per runner (depending on usage)

## 🆘 Support & Issues

If you encounter any issues:

1. **Check troubleshooting guide**: `docs/troubleshooting.md`
2. **Review security guide**: `docs/security.md`
3. **Report issues**: https://github.com/gabel/github-self-hosted-runner/issues
4. **Run health check**: 
   ```bash
   systemctl status github-runner
   ./scripts/health-check-runner.sh
   ```

## 📝 Upgrade Recommendations

**Recommended for all users** - This release improves user experience significantly with no breaking changes.

## 🙏 Thanks

Special thanks to the community feedback that shaped the UI/UX improvements in this release.

---

**Next Steps After Installation**:

1. Verify runner is connected: `systemctl status github-runner` or `docker-compose ps`
2. Test with a simple workflow
3. Consider migrating existing workflows: `./scripts/workflow-helper.sh scan`
4. Monitor runner health: `./scripts/health-check-runner.sh`

**For detailed upgrade guide**: See `docs/migration-guide.md`
