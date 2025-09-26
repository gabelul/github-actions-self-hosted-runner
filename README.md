# Run GitHub Actions on Your Own Server (And Save Money!)

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://choosealicense.com/licenses/mit/)
[![Latest Release](https://img.shields.io/github/v/release/gabel/github-self-hosted-runner?color=blue&label=latest%20release)](https://github.com/gabel/github-self-hosted-runner/releases/latest)
[![Platform Support](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Docker-blue)](https://github.com/gabel/github-self-hosted-runner)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Compatible-2088FF?logo=github-actions&logoColor=white)](https://github.com/features/actions)
[![Made with ❤️](https://img.shields.io/badge/Made%20with-❤️%20%26%20AI-ff69b4)](https://booplex.com)
[![Star on GitHub](https://img.shields.io/github/stars/gabel/github-self-hosted-runner?style=social)](https://github.com/gabel/github-self-hosted-runner/stargazers)

Have you ever hit your GitHub Actions limit and wondered "Why am I paying for this?" Well, you're in the right place! This tool lets you run GitHub Actions on your own computer or server instead of GitHub's expensive servers.

> ⭐ **Found this helpful?** Give us a star on GitHub! It helps other developers discover this tool and saves them money too!

**Think of it like this:** Instead of renting GitHub's kitchen to cook your meals (running your code), you're using your own kitchen. Same great meals, way less expensive!

## 🆕 What's New in v2.2.1 - Stability & Fixes! 🔧✨

🎉 **Critical fixes for token handling and workflow migration!** Now more reliable than ever:

```bash
# Same great setup, now with fixes!
./setup.sh
```

**🔧 Fixed in v2.2.1:**
- **Token Encryption**: Fixed NULL byte issues that corrupted GitHub tokens
- **Workflow Migration**: Fixed missing output in workflow conversion process
- **Temp Directories**: All temporary files now use project directory instead of system `/tmp`
- **Better Organization**: Cleaner `.tmp/` structure for migrations, tests, and backups

**🧠 Smart Setup Wizard (ENHANCED!)**
- Detects existing runners first - no more redundant setup!
- Smart menu: manage existing vs add new runner
- Only asks for token when actually needed
- Auto-loads saved encrypted tokens

**🔧 Enhanced Container Health**
- Fixed Docker health check timeouts
- New debug tool: `./scripts/debug-runner-health.sh`
- Comprehensive container diagnostics
- Automatic health issue detection

**🔄 Supercharged Workflow Migration**
- `scan` command shows migration opportunities instantly
- `update` command migrates workflows with one command
- Real-time cost savings calculator
- Safe backups with easy rollback

> 💰 **AI enthusiastically predicts savings of $50-200/month!** *(The math seems legit, but we'll let you be the judge)*

**📚 Full Details:** [Release Notes](RELEASE_NOTES.md) | [Changelog](CHANGELOG.md)

## 🤔 Wait, What's This All About?

**The Problem:** GitHub Actions minutes cost money. If you use more than 2,000 minutes per month (that's about 33 hours), you start paying $0.008 per minute. That adds up fast!

**The Solution:** Run your GitHub Actions on your own computer or rented server. It's like having your own personal robot that tests your code for free.

## 👋 Complete Beginner? Start Here!

Never done anything like this before? No problem! Here's what you need to know:

- **GitHub Actions** = Robots that test your code automatically when you make changes
- **Self-hosted runner** = Your own robot instead of GitHub's robot
- **VPS/Server** = A computer you rent online (like renting an apartment, but for computers)

**Why would you want this?**
- Save money (seriously, a lot of money)
- Your tests run faster (no waiting in line)
- You control everything

## ✨ What This Tool Does For You

### 🌍 Works Everywhere
- **Smart setup** - Figures out what kind of computer you have and sets itself up
- **Multiple ways to install** - Choose what works for you (simple, Docker, or service)
- **Lots of computers supported** - Ubuntu, Debian, CentOS, Rocky Linux, macOS

### 🔒 Keeps You Safe
- **No admin access needed** - Creates a special user just for running your code
- **Protects your secrets** - Keeps your GitHub tokens safe and encrypted
- **Blocks bad guys** - Sets up firewall rules to protect your server
- **Tracks everything** - Logs what happens so you can see if anything goes wrong

### 🏗️ Handle Multiple Projects
- **One server, many projects** - Run tests for different repositories on the same machine
- **Fair sharing** - Makes sure each project gets its fair share of computer power
- **Works together** - Automatically spreads the work across available resources
- **Easy management** - Start, stop, and check on each project independently

### 🔄 Automatic Workflow Migration
- **Smart migration** - Automatically converts your existing GitHub workflows to use self-hosted runners
- **Interactive selection** - Choose exactly which workflows to convert with checkbox interface
- **Safe with backups** - Creates timestamped backups before making any changes
- **6 ready-to-use templates** - Node.js, Python, Docker, deployment, security scanning, and matrix testing workflows
- **Cost calculator** - Shows exactly how much money you'll save with self-hosted runners

### 📊 Built to Last
- **Health checks** - Constantly monitors to make sure everything is working
- **Auto-recovery** - If something breaks, it fixes itself automatically
- **Smart logging** - Keeps track of everything and cleans up old logs
- **Safe updates** - Updates the runner without breaking your running tests

## 🚀 Let's Get You Started!

### Quick Start (For the Impatient)

Got 5 minutes? Here's the fastest way to get running:

**🆕 Interactive Mode (Recommended):**
```bash
# Download and run the interactive wizard - it guides you through everything!
git clone https://github.com/gabel/github-self-hosted-runner.git
cd github-self-hosted-runner
./setup.sh  # Just run it! No flags needed!
```

**Classic Mode (If you know what you want):**
```bash
# Direct setup with your token and repository
curl -fsSL https://raw.githubusercontent.com/gabel/github-self-hosted-runner/main/setup.sh | bash -s -- \
  --token ghp_your_personal_access_token_here \
  --repo owner/repository-name
```

**What happens?** The interactive wizard detects your GitHub CLI auth, shows your repositories, and guides you through the setup. It's like having a friendly expert helping you!

### I Want to Understand What I'm Doing

No problem! Here's the step-by-step way:

```bash
# Step 1: Download the code to your computer
git clone https://github.com/gabel/github-self-hosted-runner.git
cd github-self-hosted-runner

# Step 2: Run the setup (replace YOUR_TOKEN and owner/repository-name with your actual values)
./setup.sh --token YOUR_TOKEN --repo owner/repository-name

# Step 3: Check that it worked (you should see "active" in green)
sudo systemctl status github-runner
```

**What's happening here?**
1. We download the code to your computer
2. We run a script that sets everything up for your specific project
3. We check that the runner is actually working

### Wait, What's This Token Thing?

Great question! You need to get a "token" from GitHub first. Think of it like a password that lets this tool talk to your GitHub repository.

**How to get your token:**
1. Go to [GitHub Token Settings](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Give it a name like "My Self-Hosted Runner"
4. Check the "repo" and "workflow" boxes
5. Click "Generate token"
6. Copy the token (it starts with `ghp_`) - you'll need this!

### Prefer Docker? (For the Container Fans)

If you're already using Docker and want to keep everything in containers:

```bash
# Step 1: Go to the Docker folder
cd docker

# Step 2: Set up your configuration
cp .env.example .env
# Now edit the .env file and put in your GitHub token and repository

# Step 3: Start it up!
docker-compose up -d

# Step 4: Watch what's happening (press Ctrl+C to stop watching)
docker-compose logs -f github-runner
```

**What's Docker doing?** It's running your GitHub runner inside a container - like a little isolated box. This keeps everything clean and separated from your main system.

## 📚 Need More Help? We've Got Guides!

### Getting Started (Pick Your Adventure)
- **[Setting Up on a VPS](docs/vps-setup.md)** - Rent a server online and set it up step-by-step
- **[Setting Up Locally](docs/local-setup.md)** - Use your own computer (great for testing)
- **[Docker Setup](docker/README.md)** - Keep everything in containers (for Docker lovers)

### Making It Work for You
- **[Running Multiple Projects](docs/multi-runner.md)** - One server, many GitHub repositories
- **[Keeping Things Secure](docs/security.md)** - Lock down your setup (very important!)
- **[Auto-Start Services](systemd/README.md)** - Make it start automatically when your server boots

### When Things Go Wrong (Don't Panic!)
- **[Common Problems & Solutions](docs/troubleshooting.md)** - "Help, it's not working!" fixes
- **[Moving From GitHub's Servers](docs/migration-guide.md)** - Switch from paid GitHub Actions to your own
- **[Workflow Automation Guide](docs/workflow-automation.md)** - Automate the migration of your existing workflows ⭐ NEW

### For the Curious
- **[How Everything Works](CLAUDE.md)** - The complete technical breakdown
- **[System Design](docs/architecture.md)** - Why we built it this way

## 💻 Where Can You Run This?

### Best for Real Work (Always Online)

| Where You Can Run It | How Well It Works | Why You'd Want This | Perfect For |
|----------------------|-------------------|---------------------|-------------|
| **Ubuntu Server (DigitalOcean, Linode, etc.)** | ✅ Works Great | Always running, super reliable | Your main projects, team work |
| **Debian Server** | ✅ Works Great | Rock solid, gets updates for years | Big companies, important stuff |
| **CentOS/Rocky Linux** | ✅ Works Great | Enterprise-grade security | Corporate environments |

**Popular choices:**
- **DigitalOcean** - $12/month, super easy to set up
- **Linode** - $10/month, great support
- **AWS EC2** - More expensive but integrates with everything

### For Testing and Development

| Where You Can Run It | How Well It Works | Why You'd Want This | Perfect For |
|----------------------|-------------------|---------------------|-------------|
| **Your Mac** | ✅ Works Great | Right on your laptop, no extra cost | Learning, personal projects |
| **Your Linux Computer** | ✅ Works Great | Complete control, totally free | Home labs, experimenting |
| **Windows (with WSL2)** | 🚧 Mostly Works | Use Windows but run Linux stuff | Windows developers |
| **Docker Container** | ✅ Works Great | Clean, isolated, easy to delete | Quick tests, trying it out |

### Container Platforms

| Platform | Status | Good For |
|----------|--------|----------|
| **Docker Compose** | ✅ Ready to Go | Simple setups, local testing |
| **Kubernetes** | 🔄 Coming Soon | Big deployments, auto-scaling |
| **Docker Swarm** | 🔄 Coming Soon | Small clusters |

## 💡 Real Examples (Copy & Paste Ready!)

### Just Getting Started

```bash
# Set up one runner for your main project
./setup.sh --token ghp_your_token_here --repo yourname/yourproject --name my-first-runner
```

**What this does:** Creates one runner that will handle all GitHub Actions for "yourproject"

### Multiple Projects on One Server

```bash
# Set up runners for different projects (save even more money!)
./setup.sh --token ghp_token1 --repo company/website --name website-runner
./setup.sh --token ghp_token2 --repo company/api --name api-runner
./setup.sh --token ghp_token3 --repo company/mobile-app --name mobile-runner
```

**What this does:** One server now handles GitHub Actions for three different projects. Triple the savings!

### Special Setups

```bash
# If you have a powerful GPU server for machine learning
./setup.sh \
  --token ghp_your_token \
  --repo yourname/ml-project \
  --name gpu-runner \
  --labels "self-hosted,linux,x64,gpu,cuda"
```

**What this does:** Creates a runner that your GitHub Actions can specifically target when they need GPU power

### Docker Examples

```bash
# Basic Docker setup
docker-compose up -d

# Run multiple projects in separate containers
RUNNER_NAME=project1-runner GITHUB_REPOSITORY=owner/project1 docker-compose --project-name project1 up -d
RUNNER_NAME=project2-runner GITHUB_REPOSITORY=owner/project2 docker-compose --project-name project2 up -d
```

**What this does:** Each project gets its own isolated container - super clean and organized

## 🔧 Managing Your Runners

### Basic Controls (Start, Stop, Check Status)

```bash
# Start all your runners
sudo systemctl start github-runner@*

# Stop one specific runner (replace "runner-name" with your actual runner name)
sudo systemctl stop github-runner@my-project-runner

# Check if a runner is working (should show "active" in green)
sudo systemctl status github-runner@my-project-runner

# See what your runner is doing right now (press Ctrl+C to stop watching)
sudo journalctl -u github-runner@my-project-runner -f
```

### Health Checks (Is Everything OK?)

```bash
# Quick check - are all runners healthy?
scripts/health-check.sh --all

# Detailed report for one specific runner
scripts/health-check.sh --runner my-project-runner --verbose

# How much CPU/memory are my runners using?
scripts/health-check.sh --resources
```

### Maintenance (Keeping Things Fresh)

```bash
# Update a runner to the latest version
scripts/update-runner.sh my-project-runner

# Clean up old stuff (keeps things running smoothly)
scripts/cleanup.sh --age 7

# Backup your runner settings (just in case!)
scripts/backup.sh --output ./backups/
```

## 🔒 We Keep You Safe

### Your Secrets Stay Secret
- **Secure token storage** - Your GitHub tokens are encrypted and protected
- **Limited access** - Each runner can only access the repositories you specify
- **Easy token updates** - Change your tokens anytime without breaking anything

### System Protection
- **Special user account** - Runners don't run as admin/root (much safer!)
- **Isolation** - Your runner jobs can't mess with your system files
- **Firewall setup** - Blocks unwanted network connections automatically
- **File protection** - Keeps runner files separate from your important stuff

### Always Watching (The Good Kind)
- **Activity logs** - We track what happens so you can see if anything goes wrong
- **Health monitoring** - Constantly checks that everything is working properly
- **Resource tracking** - Monitors CPU, memory, and disk usage so nothing gets overloaded
- **Security alerts** - Logs any suspicious activity for you to review

## 💰 How Much Money Will You Save?

### What GitHub Currently Charges You

| Your Plan | Free Minutes Each Month | What You Pay for Extra Minutes | If You Use 4,000 Minutes/Month |
|-----------|-------------------------|--------------------------------|--------------------------------|
| **Free** | 2,000 minutes | $0.008 per minute | $16/month for extra 2,000 minutes |
| **Pro** | 3,000 minutes | $0.008 per minute | $8/month for extra 1,000 minutes |
| **Team** | 3,000 minutes | $0.008 per minute | $8/month for extra 1,000 minutes |

### What Your Own Server Costs

| Server Provider | What You Pay | What You Get | Like Getting This Many Minutes |
|----------------|--------------|-------------|-------------------------------|
| **DigitalOcean** | $12/month | 2 CPU, 2GB RAM | 1,500 GitHub minutes worth |
| **Linode** | $10/month | 2 CPU, 4GB RAM | 1,250 GitHub minutes worth |
| **AWS EC2** | $30/month | 2 CPU, 4GB RAM | 3,750 GitHub minutes worth |
| **Powerful Server** | $50/month | 8 CPU, 16GB RAM | 6,250 GitHub minutes worth |

### The Bottom Line

**You start saving money when you use more than about 1,250-1,500 GitHub minutes per month.**

**Real example:** If you're using 5,000 minutes per month on the Free plan:
- **GitHub's cost:** $24/month (2,000 free + $24 for 3,000 extra)
- **Your own server:** $12-15/month
- **You save:** $9-12/month ($108-144 per year!)

Plus your builds run faster and you never have to wait in queue!

> 💡 **Hypothetical Success Story:** "An AI imagines you could save $65/month. We're pretty sure the math checks out, but we're also the ones who did the math, so... 🤷" - *Your friendly neighborhood AI*

## 🔄 Automatic Workflow Migration (New!)

Got existing GitHub Actions workflows? Don't rewrite them manually! Our workflow helper automatically converts your workflows to use self-hosted runners.

### Quick Migration

```bash
# First, set up your self-hosted runner
./setup.sh --token ghp_your_token --repo owner/your-repo

# Then migrate your workflows automatically
./scripts/workflow-helper.sh migrate /path/to/your-repository
```

**What happens?** The tool will:
1. 📋 Show you all your current workflows
2. ✅ Let you pick which ones to migrate (with checkboxes!)
3. 💾 Create backups of your original workflows
4. 🔄 Convert `runs-on: ubuntu-latest` to `runs-on: self-hosted`
5. 💰 Tell you how much money you'll save

### Integrated Workflow Management (⭐ NEW!)

**Workflow analysis built right into runner management!** When managing your existing runners, you can now:

```bash
./setup.sh
# → Select "Manage existing runners"
# → Choose "View connected repositories"
# → See workflow analysis for each repository
# → Migrate workflows directly from the management interface!
```

**🎯 Smart workflow analysis shows you:**
- ✅ Which workflows are already using self-hosted runners
- ❌ Which workflows are still using GitHub-hosted runners (costing money!)
- 💰 Exact cost savings potential per repository (e.g., "~$3.20/month saved")
- 🔄 One-click migration for unconverted workflows
- ⚡ **Lightning fast** - Uses GitHub API instead of cloning repositories

**🚀 Migration options:**
- **Migrate all workflows** - Convert everything in one go
- **Select specific workflows** - Choose exactly which ones to convert
- **Preview changes first** - See what will change before applying
- **Safe with backups** - Automatic backups with easy rollback

**⚡ API-Based Analysis (NEW!):**
- **No cloning needed** - Analyzes workflows via GitHub API only
- **Works everywhere** - Requires only GitHub CLI or curl (no git needed)
- **Lightning fast** - Especially for large repositories
- **Less disk space** - No temporary repository copies
- **Smart authentication** - Uses your existing GitHub CLI login or prompts for token
- **Real-time data** - Always analyzes the latest workflow versions

### See What You'll Save

```bash
# Analyze your repository without making changes
./scripts/workflow-helper.sh analyze /path/to/your-repository
```

**Example output:**
```
📊 GitHub Actions Usage Analysis
===============================

  ci.yml: GitHub-hosted (ubuntu-latest)
  tests.yml: GitHub-hosted (ubuntu-latest)
  deploy.yml: GitHub-hosted (ubuntu-latest)

Summary:
  Total workflows: 3
  GitHub-hosted runners: 3
  Self-hosted runners: 0

💰 Migration Potential:
  • 3 workflow(s) can be migrated to self-hosted runners
  • Estimated monthly savings: ~$24 USD
    (Based on 300 minutes/month at $0.008/minute for Linux)
```

### Generate New Workflows

Starting a new project? Use our templates that are already set up for self-hosted runners:

```bash
# Interactive workflow generator
./scripts/workflow-helper.sh generate

# Available templates:
# • node-ci        - Node.js CI with tests, linting, security
# • python-ci      - Python CI with multiple versions
# • docker-build   - Docker build with security scanning
# • deploy-prod    - Production deployment with approval gates
# • matrix-test    - Cross-platform testing matrix
# • security-scan  - Comprehensive security scanning
```

### Migration Features

✨ **Interactive Selection**
- See all your workflows in a nice list
- Check/uncheck which ones to migrate
- Skip workflows you want to keep on GitHub's runners

🛡️ **Safe Migration**
- Creates timestamped backups before any changes
- Preview changes before they're applied
- Easy rollback if something goes wrong

🎯 **Smart Detection**
- Automatically finds all `.yml` and `.yaml` workflow files
- Detects which workflows use GitHub-hosted runners
- Handles complex `runs-on` configurations

📊 **Cost Analysis**
- Shows current runner usage
- Calculates potential savings
- Estimates break-even point

### Example: Complete Migration

Here's what a real migration looks like:

```bash
# Step 1: See what workflows you have
./scripts/workflow-helper.sh analyze ~/my-project

# Output: Found 5 workflows, 3 using GitHub runners
# Potential savings: $18/month

# Step 2: Migrate interactively
./scripts/workflow-helper.sh migrate ~/my-project

# You'll see:
# ✅ 1. ci.yml (currently: ubuntu-latest)
# ✅ 2. tests.yml (currently: ubuntu-latest)
# ❌ 3. windows-build.yml (currently: windows-latest)
# ✅ 4. deploy.yml (currently: ubuntu-latest)
# ❌ 5. security.yml (currently: ubuntu-latest)

# Select: [a]ll, [n]one, [3] toggle, [d]one
# Choice: 3  (uncheck windows build - we want that on GitHub)
# Choice: d  (done)

# Step 3: Confirm and migrate
# ✅ Migrated 3 workflows successfully!
# 💾 Backups stored in ~/.github-runner-backups/
```

**Pro tip:** Start with non-critical workflows to test everything works, then migrate your main CI/CD workflows.

## 🤝 Want to Help Make This Better?

We'd love your help! Whether you're a beginner or expert, there's something you can do.

**Never contributed to open source before?** Perfect! Check out our [Contributing Guide](CONTRIBUTING.md) - we wrote it specifically to help newcomers get started.

### Easy Ways to Contribute

> 🌟 **First time contributing to open source?** We're beginner-friendly! Check our [Contributing Guide](CONTRIBUTING.md) for a warm welcome.

- **Found a bug?** [Open an issue](https://github.com/gabel/github-self-hosted-runner/issues) - we love fixing things!
- **Documentation unclear?** Help us make it better - small improvements make a big difference!
- **Want a new feature?** [Tell us about it](https://github.com/gabel/github-self-hosted-runner/discussions) - we're always listening!
- **Good at testing?** Try it on different systems and report back - you'll be helping thousands of developers!

**Fun fact:** This project was born because Gabel ran out of GitHub Actions minutes. Now you don't have to! ⭐

### For Developers

```bash
# Get the code and start experimenting
git clone https://github.com/gabel/github-self-hosted-runner.git
cd github-self-hosted-runner

# Create your own branch for your changes
git checkout -b feature/my-awesome-improvement

# Test your changes (this won't actually install anything, just checks)
./setup.sh --test --dry-run

# When you're happy, share it with the world
git push origin feature/my-awesome-improvement
```

### Make Sure Everything Still Works

```bash
# Run all our tests
scripts/test-suite.sh

# Test on different operating systems
scripts/test-environments.sh

# Check that security is still tight
scripts/security-audit.sh
```

## 🎉 Something Went Wrong? Don't Panic!

### Quick Troubleshooting
**Runner won't start?**
- Check if you used the right token: `./setup.sh --token ghp_xxxxxxxxxxxxx --repo YOUR_USERNAME/YOUR_REPO`
- Make sure your token has "repo" and "workflow" permissions

**Getting permission errors?**
- Try running with `sudo` if on Linux
- On macOS, make sure you have admin access

**Still stuck?** Check our [Troubleshooting Guide](docs/troubleshooting.md) for detailed solutions.

### Get Help
- **Found a bug?** [Tell us about it](../../issues) - we fix them quickly!
- **Have questions?** [Start a discussion](../../discussions) - the community is friendly!
- **Security problem?** Email us privately (we take security seriously)

## 📄 Legal Stuff

This project is free and open source under the MIT License. Use it however you want! See the [LICENSE](LICENSE) file for the boring legal details.

## 🚀 What's Coming Next?

We're always improving! Here's what we're working on:

### 🎯 v2.1.0 - Windows & Kubernetes (Next Month)
- [ ] **Windows PowerShell Support** - Native setup for Windows developers
- [ ] **Kubernetes Integration** - One-click K8s deployments with Helm charts
- [ ] **Update Notifications** - Built-in version checking and upgrade prompts
- [ ] **Enhanced Templates** - More workflow templates (Go, Rust, PHP, .NET)

### 🚀 v2.2.0 - Cloud & Scale (Q2 2025)
- [ ] **Cloud Provider Wizards** - One-click setup on AWS, DigitalOcean, Linode
- [ ] **Web Dashboard** - Beautiful interface to monitor all your runners
- [ ] **Smart Auto-scaling** - Automatically add/remove runners based on queue
- [ ] **Performance Analytics** - See exactly how much faster your builds are

### 🔮 v3.0.0 - Enterprise & Teams (Q3 2025)
- [ ] **Multi-team Support** - Organization-wide runner management
- [ ] **Advanced Security** - RBAC, audit logs, compliance reports
- [ ] **Cost Analytics** - Detailed savings reports and optimization suggestions
- [ ] **API & Integrations** - REST API for programmatic management

---

## 🌟 That's It!

You now have your own GitHub Actions runners that:
- **Save you money** (potentially hundreds of dollars per year)
- **Run your tests faster** (no more waiting in queues)
- **Give you complete control** (install whatever you need)
- **Work everywhere** (from your laptop to enterprise servers)

**Questions? Problems? Ideas?** We're here to help! This tool exists to make your development life easier and cheaper.

**Love this project?**
- ⭐ Star us on GitHub to help others discover it
- 🐦 [Follow Booplex on Twitter](https://x.com/GabiExplores) for updates
- 📧 [Subscribe to our newsletter](https://booplex.com) for more developer tools

---

## 🚀 Built by Booplex

Built with ❤️ (and probably too much coffee) by **[Gabel @ Booplex.com](https://booplex.com)**

*Making apps that don't suck since... well, recently. But we're getting good at it!*

**[Booplex](https://booplex.com)** - Where AI meets human creativity, and they become best friends.

### 🔗 Connect with Booplex
- 🌐 **Website:** [booplex.com](https://booplex.com)
- 🐦 **X:** [@booplex](https://x.com/GabiExplores) (follow me and let's see what happens!)
- 💼 **LinkedIn:** [Connect with Gabel](https://www.linkedin.com/in/gabi-florea/)
- 📧 **Email:** [hey@booplex.com](mailto:hey@booplex.com)

P.S. - Yes, AI helped write this documentation. No, it didn't become sentient. We checked. 🤖

*Happy coding, and may your builds always be green!* 🚀✨