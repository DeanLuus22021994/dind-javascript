#!/bin/bash
set -e
echo "[dev-status.sh] Devcontainer Status Report"
echo "----------------------------------------"
echo
echo "Docker Containers (running):"
docker ps || echo "(docker not available or not running)"
echo
echo "Docker Images:"
docker images || echo "(docker not available or not running)"
echo
echo "Node.js version:"
node --version 2>/dev/null || echo "(node not available)"
echo
echo "Workspace health endpoints (if available):"
if command -v curl >/dev/null 2>&1; then
  for port in 3000 4000 5000; do
    if curl -s "http://localhost:$port/health" | grep -q 'ok'; then
      echo "  [PASS] http://localhost:$port/health"
    else
      echo "  [WARN] http://localhost:$port/health not responding or not healthy"
    fi
  done
else
  echo "  curl not available, skipping endpoint checks."
fi
