FROM mcr.microsoft.com/devcontainers/base:bullseye

# Install buildkit and docker compose
RUN apt-get update && apt-get install -y \
  docker-buildx-plugin \
  docker-compose-plugin \
  && rm -rf /var/lib/apt/lists/*

# Create cache directories
RUN mkdir -p /cache/buildkit /cache/docker /cache/npm /cache/yarn

# Configure buildkit
ENV BUILDKIT_HOST=docker-container://buildkit
ENV DOCKER_BUILDKIT=1
ENV COMPOSE_DOCKER_CLI_BUILD=1
