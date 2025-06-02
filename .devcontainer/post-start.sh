#!/bin/bash
set -e

echo "🔧 Post-start configuration..."

# Ensure buildkit is running
docker buildx inspect --bootstrap

# Warm up the cache by pulling common base images
docker pull node:lts-alpine &
docker pull nginx:alpine &
docker pull redis:alpine &

# Set up git safe directory
git config --global --add safe.directory /workspace

# Install global npm packages to cache
npm install -g typescript ts-node nodemon --cache /cache/npm

echo "✅ Post-start setup complete!"
