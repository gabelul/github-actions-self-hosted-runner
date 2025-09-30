# Commit Message Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/) to automatically determine version bumps and generate changelogs.

## Quick Reference

| Commit Prefix | Version Bump | Example |
|--------------|--------------|---------|
| `fix:` | **Patch** (0.0.X) | `fix: resolve token encryption bug` |
| `feat:` | **Minor** (0.X.0) | `feat: add multi-runner support` |
| `BREAKING CHANGE:` or `breaking:` | **Major** (X.0.0) | `BREAKING CHANGE: remove deprecated API` |
| `chore:`, `docs:`, `style:`, `refactor:`, `test:`, `ci:` | **Patch** (0.0.X) | `chore: update dependencies` |

## How It Works

When you push to `main`, the **Version & Release** workflow automatically:
1. 📊 Analyzes your commit messages since the last release
2. 🔢 Determines the version bump type (major, minor, or patch)
3. 📝 Updates `VERSION` and `CHANGELOG.md` files
4. 🏷️ Creates a git tag (e.g., `v2.3.0`)
5. 🚀 Publishes a GitHub release with generated notes

## Commit Message Format

```
<type>: <description>

[optional body]

[optional footer]
```

### Examples

**Patch Release (Bug Fix)**
```bash
git commit -m "fix: resolve Docker container timeout issue"
```

**Minor Release (New Feature)**
```bash
git commit -m "feat: add workflow migration wizard

Implements interactive workflow conversion from GitHub-hosted
to self-hosted runners with backup and rollback support."
```

**Major Release (Breaking Change)**
```bash
git commit -m "BREAKING CHANGE: remove legacy token storage

The old plaintext token storage has been removed.
Users must re-configure their runners with encrypted tokens."
```

**Maintenance (Patch)**
```bash
git commit -m "chore: update GitHub Actions runner to v2.315.0"
git commit -m "docs: improve setup wizard documentation"
git commit -m "test: add integration tests for multi-runner setup"
```

## Commit Types

- **feat**: New feature (triggers minor version bump)
- **fix**: Bug fix (triggers patch version bump)
- **BREAKING CHANGE**: Breaking API change (triggers major version bump)
- **chore**: Maintenance tasks, dependency updates
- **docs**: Documentation changes
- **style**: Code formatting, whitespace changes
- **refactor**: Code restructuring without feature/bug changes
- **test**: Adding or updating tests
- **ci**: CI/CD configuration changes

## Semantic Versioning

This project follows [Semantic Versioning](https://semver.org/):

- **Major (X.0.0)**: Breaking changes that require user action
- **Minor (0.X.0)**: New features, backward-compatible
- **Patch (0.0.X)**: Bug fixes, backward-compatible

### Version History Example
```
v1.0.0 → Initial release
v1.1.0 → Added workflow templates (feat:)
v1.1.1 → Fixed token encryption (fix:)
v1.2.0 → Added multi-runner support (feat:)
v2.0.0 → Removed deprecated commands (BREAKING CHANGE:)
```

## Tips

1. **Be specific**: `fix: resolve token encryption for org repos` is better than `fix: bug fix`
2. **Use imperative mood**: "add feature" not "added feature"
3. **Keep it concise**: First line should be under 72 characters
4. **Add body for context**: Use the body to explain *why*, not *what*
5. **Reference issues**: Add `Closes #123` in the footer

## Skipping Version Bumps

If you need to push without triggering a release (very rare), use commit messages without conventional prefixes:
```bash
git commit -m "update README screenshot"
git commit -m "rename internal variable"
```

These won't trigger automatic versioning.

## Manual Override

If automation fails or you need manual control:
```bash
# Manually create a tag
git tag -a v2.5.0 -m "Release 2.5.0"
git push origin v2.5.0

# Update VERSION file
echo "2.5.0" > VERSION
git add VERSION
git commit -m "chore: manual version bump to 2.5.0"
git push
```

## Questions?

- **"What if I mix multiple types?"** - The workflow picks the highest priority: BREAKING > feat > fix
- **"Can I test locally?"** - Yes! Check `.github/workflows/version-release.yml` and run the version calculation logic
- **"What about pre-releases?"** - Use branches like `beta` or `rc` (future enhancement)

---

**TL;DR**: Use `fix:` for bugs (0.0.X), `feat:` for features (0.X.0), `BREAKING CHANGE:` for major updates (X.0.0). The robots handle the rest.