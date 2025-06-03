#!/bin/bash
# List Docker containers (running or all)
set -euo pipefail

all="${1:-}"

if [[ "$all" == "-a" || "$all" == "--all" ]]; then
  echo "Listing all Docker containers:"
  docker ps -a
else
  echo "Listing running Docker containers:"
  docker ps
fi
