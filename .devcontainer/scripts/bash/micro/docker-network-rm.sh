#!/bin/bash
# Remove a Docker network by name
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <network_name>"
  exit 1
fi

network="$1"

if ! docker network ls --format '{{.Name}}' | grep -qw "$network"; then
  echo "Error: Network '$network' does not exist."
  exit 1
fi

echo "Removing network: $network"
docker network rm "$network"
echo "Network '$network' removed."
