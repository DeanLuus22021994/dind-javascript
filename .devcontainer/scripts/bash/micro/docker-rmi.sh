#!/bin/bash
# Remove a Docker image by name or ID
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <image_name_or_id>"
  exit 1
fi

image="$1"

if ! docker images --format '{{.Repository}}:{{.Tag}}' | grep -qw "$image" && ! docker images --format '{{.ID}}' | grep -qw "$image"; then
  echo "Error: Image '$image' does not exist."
  exit 1
fi

echo "Removing image: $image"
docker rmi "$image"
echo "Image '$image' removed."
