#!/bin/bash
set -e

echo "🚀 Starting enhanced DevContainer with Docker Compose..."
cd .devcontainer || exit 1
docker compose up -d
echo "✅ DevContainer is now running. You can attach to it in VS Code."
