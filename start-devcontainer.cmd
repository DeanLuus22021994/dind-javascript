@echo off
echo Starting enhanced DevContainer with Docker Compose...
cd .devcontainer
docker compose up -d
echo DevContainer is now running. You can attach to it in VS Code.
pause
