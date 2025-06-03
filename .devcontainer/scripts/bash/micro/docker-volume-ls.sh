#!/bin/bash
# List Docker volumes
set -euo pipefail

echo "Listing Docker volumes:"
docker volume ls
