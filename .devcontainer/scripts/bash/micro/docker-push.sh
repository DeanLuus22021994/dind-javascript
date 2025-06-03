#!/bin/bash
# micro/docker-push.sh - Single-responsibility: Push a Docker image
# Usage: docker-push.sh <image>
set -euo pipefail

image="$1"
echo "🐳 docker push $image"
docker push "$image"
