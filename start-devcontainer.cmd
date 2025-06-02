@echo off
echo Starting enhanced DevContainer with Docker Compose...
Set-Location .devcontainer
if not exist docker-compose.yml (
    echo Error: docker-compose.yml not found in .devcontainer directory
    Set-Location ..
    pause
    exit /b 1
)
docker compose up -d
if %errorlevel% neq 0 (
    echo Error: Failed to start Docker Compose
    Set-Location ..
    pause
    exit /b 1
)
Set-Location ..
echo DevContainer is now running. You can attach to it in VS Code.
pause
