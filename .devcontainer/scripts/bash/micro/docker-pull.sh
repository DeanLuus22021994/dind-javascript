#!/bin/bash
# micro/docker-pull.sh - Single-responsibility: Pull a Docker image
# Usage: docker-pull.sh <image>
set -euo pipefail

image="$1"
echo "🐳 docker pull $image"
docker pull "$image"
