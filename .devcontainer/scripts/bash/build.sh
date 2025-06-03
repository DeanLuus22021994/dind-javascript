#!/bin/bash
# build.sh - High-level build script using micro docker scripts
set -euo pipefail


# Configurable variables (edit as needed)
CONTEXT="${SCRIPT_DIR}/../../.."
DOCKERFILE="${SCRIPT_DIR}/../../docker/files/Dockerfile.main"
TAG="dind-javascript-dev:latest"

# Pass through any extra build args
EXTRA_ARGS=("$@")

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
MICRO_DIR="$SCRIPT_DIR/micro"

# Build image
"$MICRO_DIR/docker-build.sh" "$CONTEXT" "$DOCKERFILE" "$TAG" "${EXTRA_ARGS[@]}"
