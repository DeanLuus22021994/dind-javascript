#!/bin/bash
set -e
echo "[validate.sh] Devcontainer Health Check"
echo "--------------------------------------"

fail=0

# Check Docker is running and containers are up
if ! docker info >/dev/null 2>&1; then
  echo "[FAIL] Docker daemon is not running or not accessible."
  fail=1
else
  running=$(docker ps -q | wc -l)
  if [ "$running" -eq 0 ]; then
    echo "[FAIL] No running containers found."
    fail=1
  else
    echo "[PASS] $running containers running."
  fi
fi

# Check health endpoints
if command -v curl >/dev/null 2>&1; then
  for port in 3000 4000 5000; do
    if curl -s "http://localhost:$port/health" | grep -q 'ok'; then
      echo "[PASS] http://localhost:$port/health"
    else
      echo "[FAIL] http://localhost:$port/health not responding or not healthy"
      fail=1
    fi
  done
else
  echo "[WARN] curl not available, skipping endpoint checks."
fi

if [ "$fail" -eq 0 ]; then
  echo "[validate.sh] All checks passed."
  exit 0
else
  echo "[validate.sh] One or more checks failed."
  exit 1
fi
