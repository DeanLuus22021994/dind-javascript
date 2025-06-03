#!/bin/bash
# Remove a Docker volume by name
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <volume_name>"
  exit 1
fi

volume="$1"

if ! docker volume ls --format '{{.Name}}' | grep -qw "$volume"; then
  echo "Error: Volume '$volume' does not exist."
  exit 1
fi

echo "Removing volume: $volume"
docker volume rm "$volume"
echo "Volume '$volume' removed."
