#!/bin/bash
set -e

echo "🚀 Setting up enhanced Docker in Docker environment..."

# Configure buildkit
docker buildx create --name container --driver docker-container --use --bootstrap || true
docker buildx inspect --bootstrap

# Set up NPM/Yarn cache
npm config set cache /cache/npm
yarn config set cache-folder /cache/yarn

# Create docker bake configuration
cat > docker-bake.hcl << 'EOF'
variable "CACHE_FROM" {
  default = "type=local,src=/cache/buildkit"
}

variable "CACHE_TO" {
  default = "type=local,dest=/cache/buildkit,mode=max"
}

group "default" {
  targets = ["app"]
}

target "app" {
  dockerfile = "Dockerfile"
  cache-from = ["${CACHE_FROM}"]
  cache-to = ["${CACHE_TO}"]
  output = ["type=docker"]
}

target "app-prod" {
  inherits = ["app"]
  target = "production"
  tags = ["app:latest", "app:production"]
}
EOF

# Create buildkit daemon config
mkdir -p /etc/buildkit
cat > /etc/buildkit/buildkitd.toml << 'EOF'
[worker.oci]
  enabled = true
  platforms = [ "linux/amd64", "linux/arm64" ]

[worker.containerd]
  enabled = true
  platforms = [ "linux/amd64", "linux/arm64" ]

[cache]
  [cache.local]
    enabled = true
    rootdir = "/cache/buildkit"
EOF

echo "✅ Setup complete!"
