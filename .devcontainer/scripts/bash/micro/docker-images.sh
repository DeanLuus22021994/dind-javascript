#!/bin/bash
# List Docker images with optional filtering
set -euo pipefail

filter="${1:-}"

if [[ -n "$filter" ]]; then
  echo "Listing Docker images matching: $filter"
  docker images | grep "$filter"
else
  echo "Listing all Docker images"
  docker images
fi
