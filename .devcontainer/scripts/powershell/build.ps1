#!/usr/bin/env pwsh
# DevContainer Build Script
# Builds the DevContainer with Docker Compose

# Set error action preference
$ErrorActionPreference = "Stop"

# Navigate to the project root directory
Set-Location -Path (Split-Path -Parent -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSScriptRoot)))

Write-Host "🏗️  Building DevContainer..." -ForegroundColor Blue
Write-Host "📍 Current directory: $(Get-Location)" -ForegroundColor Yellow

try {
  # Verify compose files exist
  $composeFiles = @(
    ".devcontainer/docker/compose/docker-compose.main.yml",
    ".devcontainer/docker/compose/docker-compose.services.yml",
    ".devcontainer/docker/compose/docker-compose.override.yml"
  )

  foreach ($file in $composeFiles) {
    if (-not (Test-Path $file)) {
      Write-Host "❌ Missing compose file: $file" -ForegroundColor Red
      exit 1
    }
    Write-Host "✅ Found: $file" -ForegroundColor Green
  }

  # Build with explicit context
  docker-compose -f .devcontainer/docker/compose/docker-compose.main.yml -f .devcontainer/docker/compose/docker-compose.services.yml -f .devcontainer/docker/compose/docker-compose.override.yml build --no-cache

  if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ DevContainer build completed successfully!" -ForegroundColor Green

    # Show the built images
    Write-Host "📦 Built images:" -ForegroundColor Cyan
    docker images --filter "reference=dind-*"
  } else {
    Write-Host "❌ DevContainer build failed!" -ForegroundColor Red
    exit 1
  }
} catch {
  Write-Host "❌ Error during build: $_" -ForegroundColor Red
  exit 1
}
