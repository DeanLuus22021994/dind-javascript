FROM mcr.microsoft.com/devcontainers/base:bullseye
FROM mcr.microsoft.com/devcontainers/base:bullseye

# Set up environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV SHELL=/bin/bash

# Install essential packages and dependencies
RUN apt-get update && apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  wget \
  software-properties-common \
  apt-transport-https \
  build-essential \
  python3 \
  python3-pip \
  git \
  vim \
  nano \
  htop \
  jq \
  unzip \
  zip \
  tree \
  net-tools \
  iputils-ping \
  telnet \
  tcpdump \
  strace \
  procps \
  file \
  && mkdir -p /etc/apt/keyrings

# Install Docker and Docker Compose
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
  && apt-get update \
  && apt-get install -y \
  docker-ce-cli \
  docker-buildx-plugin \
  docker-compose-plugin \
  && rm -rf /var/lib/apt/lists/*

# Install Node.js LTS and npm/yarn
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
  && apt-get install -y nodejs \
  && npm install -g npm@latest \
  && npm install -g yarn \
  && npm install -g pnpm \
  && rm -rf /var/lib/apt/lists/*

# Install global development tools
RUN npm install -g \
  typescript \
  ts-node \
  nodemon \
  pm2 \
  eslint \
  prettier \
  @angular/cli \
  @vue/cli \
  create-react-app \
  nx \
  lerna \
  serverless \
  firebase-tools \
  @nestjs/cli \
  @storybook/cli \
  localtunnel \
  ngrok \
  autocannon \
  clinic \
  0x

# Install additional useful tools
RUN curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose \
  && chmod +x /usr/local/bin/docker-compose

# Install ctop for container monitoring
RUN wget https://github.com/bcicen/ctop/releases/download/0.7.7/ctop-0.7.7-linux-amd64 -O /usr/local/bin/ctop \
  && chmod +x /usr/local/bin/ctop

# Install lazydocker for Docker management
RUN curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# Install yq for YAML processing
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
  && chmod +x /usr/local/bin/yq

# Create cache directories with proper permissions
RUN mkdir -p /cache/buildkit /cache/docker /cache/npm /cache/yarn /cache/pnpm \
  && chown -R vscode:vscode /cache

# Configure buildkit
ENV BUILDKIT_HOST=docker-container://buildkit
ENV DOCKER_BUILDKIT=1
ENV COMPOSE_DOCKER_CLI_BUILD=1

# Configure npm, yarn, and pnpm cache
RUN npm config set cache /cache/npm --global \
  && yarn config set cache-folder /cache/yarn --global

# Set up shell enhancements
RUN echo 'alias ll="ls -alF"' >> /home/vscode/.bashrc \
  && echo 'alias la="ls -A"' >> /home/vscode/.bashrc \
  && echo 'alias l="ls -CF"' >> /home/vscode/.bashrc \
  && echo 'alias dps="docker ps"' >> /home/vscode/.bashrc \
  && echo 'alias dimg="docker images"' >> /home/vscode/.bashrc \
  && echo 'alias dlog="docker logs"' >> /home/vscode/.bashrc \
  && echo 'alias dexec="docker exec -it"' >> /home/vscode/.bashrc \
  && echo 'alias dcup="docker-compose up"' >> /home/vscode/.bashrc \
  && echo 'alias dcdown="docker-compose down"' >> /home/vscode/.bashrc \
  && echo 'alias k="kubectl"' >> /home/vscode/.bashrc \
  && echo 'export PATH="$PATH:/home/vscode/.local/bin"' >> /home/vscode/.bashrc

# Set up Git configuration helpers
RUN git config --global --add safe.directory '*' \
  && git config --global init.defaultBranch main \
  && git config --global pull.rebase false

# Create development directories
RUN mkdir -p /home/vscode/.local/bin \
  && mkdir -p /home/vscode/.config \
  && chown -R vscode:vscode /home/vscode/.local \
  && chown -R vscode:vscode /home/vscode/.config

# Switch to vscode user
USER vscode

# Configure npm for vscode user
RUN npm config set cache /cache/npm \
  && yarn config set cache-folder /cache/yarn \
  && echo 'export NPM_CONFIG_CACHE="/cache/npm"' >> ~/.bashrc \
  && echo 'export YARN_CACHE_FOLDER="/cache/yarn"' >> ~/.bashrc \
  && echo 'export PNPM_HOME="/cache/pnpm"' >> ~/.bashrc

# Back to root for final setup
USER root

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD docker version || exit 1

# Clean up
RUN apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/*
