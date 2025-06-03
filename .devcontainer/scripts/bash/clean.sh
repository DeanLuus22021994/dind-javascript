#!/bin/bash
# clean.sh - High-level clean script using micro docker scripts
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
MICRO_DIR="$SCRIPT_DIR/micro"
TAG="dind-javascript:dev"

# Remove containers using this image (if any)
CONTAINERS=$(docker ps -a --filter ancestor="$TAG" --format '{{.ID}}')
if [[ -n "$CONTAINERS" ]]; then
  for c in $CONTAINERS; do
    "$MICRO_DIR/docker-stop.sh" "$c" || true
    "$MICRO_DIR/docker-rm.sh" "$c" || true
  done
fi

# Remove the image
"$MICRO_DIR/docker-rmi.sh" "$TAG" || true
