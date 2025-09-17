# Testing your GitHub runner setup

This guide shows you how to safely test the GitHub self-hosted runner system on your machine using Docker containers.

## Quick start

Run this command and the script will figure out what it can test:

```bash
./test.sh
```

That's it! The script will:
- Check if you have GitHub CLI set up
- Use your existing authentication when possible
- Run the right tests for your situation
- Guide you through any missing pieces

## What you might need

### If you want the full test experience

1. **GitHub token** - Get one [here](https://github.com/settings/tokens/new?scopes=repo&description=Self-hosted%20runner%20testing)
   - Just check the "repo" box
   - Set it to expire in 90 days

2. **Test repository** - Any repo you can push to works
   - Your own repo is perfect
   - Or create a new test repo: `gh repo create test-runner --public`

3. **Docker** - For safe testing without changing your system
   - [Get Docker here](https://docs.docker.com/get-docker/) if you don't have it

### If you just want to check things out

Just run `./test.sh` and it'll check your scripts without needing anything else.

## Test options

```bash
./test.sh                    # Smart mode - figures out what to test
./test.sh --quick            # 30-second build validation
./test.sh --validate         # Test runner registration (60s)
./test.sh --integration      # Full workflow execution test (2-3 min)
./test.sh --full             # Complete test suite
./test.sh --syntax           # Just check the scripts
```

### Using your existing GitHub CLI

If you've already done `gh auth login`, the test script can use that:

```bash
./test.sh --use-gh-cli       # Use your gh CLI authentication
```

### Testing with specific credentials

```bash
./test.sh --token ghp_abc123 --repo myuser/my-repo
```

## What the tests do

### Syntax check
- Makes sure all scripts have valid bash syntax
- Checks Docker configuration files
- No external connections needed

### Quick test
- Builds a Docker image with your runner setup
- Creates a test container (doesn't run it)
- Validates the configuration
- Takes about 30 seconds

### Validation test
- Everything from syntax and quick tests
- Actually starts a runner container
- Registers runner with GitHub
- Verifies runner appears online
- Takes about 60 seconds

### Integration test
- Everything from validation test
- Creates and pushes a test workflow
- Triggers the workflow to run
- Monitors execution on your self-hosted runner
- Verifies workflow completes successfully
- Cleans up test workflow
- Takes 2-3 minutes

### Full test
- Runs complete test suite including all above
- Most thorough validation available

## Example test run

Here's what you'll see when things work:

```
GitHub Self-Hosted Runner Test Tool
===================================

→ Looking for GitHub credentials
✓ Found GitHub CLI authentication
ℹ Using your GitHub CLI token for testing
ℹ Auto-detected credentials, running validation test

→ Checking what you have installed
✓ Docker is ready
✓ All prerequisites are ready

→ Testing: GitHub connection
✓ GitHub connection established

→ Checking scripts and configuration
✓ All scripts have valid syntax
✓ Docker configuration is valid

→ Running quick Docker validation
✓ Docker image builds successfully
✓ Runner container can be created
✓ Container configuration looks good

→ Testing runner registration and connectivity
✓ Runner container started
ℹ Waiting for runner to register with GitHub...
✓ Runner registered and online
✓ Runner 'validate-test-12345' is connected to GitHub!

Test Results
============
Tests run: 8
Passed: 8
Failed: 0
Success rate: 100%

✓ All tests passed!

✓ Validation successful! Runner can connect to GitHub.
ℹ Next: ./test.sh --integration for full workflow testing
```

## If something goes wrong

### Docker isn't running
```
✗ Docker is installed but not running
ℹ Please start Docker and try again
```
**Fix**: Start Docker Desktop or your Docker service

### No GitHub credentials
```
No GitHub token found. Here are your options:

1. Quick test without token: ./test.sh --syntax
2. Set up GitHub CLI: gh auth login
3. Create a token manually: https://github.com/settings/tokens/new
```
**Fix**: Pick one of those options. GitHub CLI (`gh auth login`) is usually easiest.

### Can't access repository
```
✗ GitHub connection - Can't access repository 'user/repo'
```
**Fix**:
- Make sure the repository name is exactly `owner/repo`
- Check that your token has access to that repository
- Verify the repository exists

## Testing with real workflows

After your tests pass, you can try running an actual workflow:

1. **Copy the test workflow to your repository**:
   ```bash
   cp examples/test-workflow.yml /path/to/your/repo/.github/workflows/
   ```

2. **Commit and push**:
   ```bash
   cd /path/to/your/repo
   git add .github/workflows/test-workflow.yml
   git commit -m "Add runner test workflow"
   git push
   ```

3. **Set up your runner** (if tests passed):
   ```bash
   ./setup.sh --token YOUR_TOKEN --repo YOUR_REPO
   ```

4. **Run the workflow**:
   - Go to your repo on GitHub
   - Click "Actions" tab
   - Click "Test Self-Hosted Runner"
   - Click "Run workflow"
   - Watch it run on your runner!

## Safety features

The testing system is designed to be safe:

- **Containerized**: All tests run in Docker containers
- **No system changes**: Your host machine stays untouched
- **Automatic cleanup**: Test containers are removed automatically
- **Credential security**: Tokens aren't logged or stored permanently
- **Minimal permissions**: Only uses what's needed for testing

## Advanced options

### Keep test containers for debugging
```bash
./test.sh --no-cleanup --verbose
```

### Test with specific Docker configuration
```bash
./test.sh --token TOKEN --repo REPO --verbose
# Then check: docker ps -a | grep github-runner-test
```

### Test progression (recommended order)
```bash
./test.sh --syntax           # 1. Check scripts first
./test.sh --quick            # 2. Validate Docker build
./test.sh --validate         # 3. Test runner registration
./test.sh --integration      # 4. Full workflow test
```

### Other options
```bash
./test.sh --dry-run          # See what would be tested
./test.sh --full --verbose   # Everything with detailed output
```

## Next steps

After successful testing:

### Deploy to production
```bash
# Direct installation
./setup.sh --token YOUR_TOKEN --repo YOUR_REPO

# Or Docker deployment
cp docker/.env.example docker/.env
# Edit .env with your settings
docker-compose -f docker/docker-compose.yml up -d
```

### Set up multiple runners
```bash
./setup.sh --token TOKEN1 --repo owner/repo1 --name runner-1
./setup.sh --token TOKEN2 --repo owner/repo2 --name runner-2
```

### Monitor your runners
```bash
./scripts/health-check-runner.sh
docker-compose -f docker/docker-compose.yml logs -f
```

## Getting help

If you're stuck:

1. **Check the logs**: Test failures show log file locations
2. **Try verbose mode**: Add `--verbose` to see more details
3. **Start simple**: Use `./test.sh --syntax` first, then work up
4. **Verify basics**: Make sure Docker is running and you can reach GitHub

The testing tool is designed to guide you through setup, so follow its suggestions and you should be up and running quickly.