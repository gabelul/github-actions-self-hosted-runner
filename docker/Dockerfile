# GitHub Actions Self-Hosted Runner Docker Image
#
# This Dockerfile creates an optimized GitHub Actions runner image
# that can be deployed anywhere Docker runs.
#
# Features:
# - Ubuntu 22.04 LTS base (stable and well-supported)
# - GitHub Actions runner pre-installed
# - Docker-in-Docker support for containerized workflows
# - Node.js, Python, and common development tools
# - Security hardening with non-root user
# - Automatic runner registration and startup
#
# Usage:
#   docker build -t github-runner .
#   docker run -e GITHUB_TOKEN=your_token -e GITHUB_REPOSITORY=owner/repo github-runner

FROM ubuntu:22.04

# Metadata
LABEL maintainer="Ultimate Template Team"
LABEL description="GitHub Actions Self-Hosted Runner"
LABEL version="1.0.0"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV GITHUB_RUNNER_VERSION=2.319.1
ENV RUNNER_USER=github-runner
ENV RUNNER_HOME=/home/github-runner
ENV PATH="$PATH:$RUNNER_HOME"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Core system tools
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    # Development tools
    git \
    build-essential \
    sudo \
    # Networking and security
    openssh-client \
    # Process management
    supervisor \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CE for Docker-in-Docker workflows
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (latest LTS)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs

# Install Python and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Create github-runner user with sudo privileges
RUN useradd -m -s /bin/bash -c "GitHub Actions Runner" $RUNNER_USER \
    && echo "$RUNNER_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && groupadd -f docker \
    && usermod -aG docker $RUNNER_USER

# Switch to runner user
USER $RUNNER_USER
WORKDIR $RUNNER_HOME

# Download and install GitHub Actions runner (architecture-aware)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        RUNNER_ARCH="x64"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        RUNNER_ARCH="arm64"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi && \
    echo "Downloading runner for architecture: $RUNNER_ARCH" && \
    curl -o actions-runner-linux.tar.gz -L \
    "https://github.com/actions/runner/releases/download/v${GITHUB_RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${GITHUB_RUNNER_VERSION}.tar.gz" \
    && tar xzf actions-runner-linux.tar.gz \
    && rm actions-runner-linux.tar.gz

# Install runner dependencies
USER root
RUN $RUNNER_HOME/bin/installdependencies.sh
USER $RUNNER_USER

# Create work directory
RUN mkdir -p $RUNNER_HOME/_work

# Copy entrypoint script
COPY --chown=$RUNNER_USER:$RUNNER_USER entrypoint.sh $RUNNER_HOME/
RUN chmod +x $RUNNER_HOME/entrypoint.sh

# Create health check script
COPY --chown=$RUNNER_USER:$RUNNER_USER health-check.sh $RUNNER_HOME/
RUN chmod +x $RUNNER_HOME/health-check.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD $RUNNER_HOME/health-check.sh

# Expose any necessary ports (none needed for runner)
# EXPOSE 8080

# Set the entrypoint
ENTRYPOINT ["./entrypoint.sh"]

# Default command
CMD ["run"]

# Image metadata
LABEL org.opencontainers.image.title="GitHub Actions Runner"
LABEL org.opencontainers.image.description="Self-hosted GitHub Actions runner in Docker"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.created="2025-09-16"
LABEL org.opencontainers.image.source="https://github.com/actions/runner"
LABEL org.opencontainers.image.licenses="MIT"