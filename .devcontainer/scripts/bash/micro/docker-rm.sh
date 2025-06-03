#!/bin/bash
# Remove a Docker container by name or ID
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <container_name_or_id>"
  exit 1
fi

container="$1"

if ! docker ps -a --format '{{.Names}}' | grep -qw "$container"; then
  echo "Error: Container '$container' does not exist."
  exit 1
fi

echo "Removing container: $container"
docker rm "$container"
echo "Container '$container' removed."
