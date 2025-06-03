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

  # Clean up any existing containers first
  Write-Host "🧹 Cleaning up existing containers..." -ForegroundColor Yellow
  docker-compose -f .devcontainer/docker/compose/docker-compose.main.yml -f .devcontainer/docker/compose/docker-compose.services.yml -f .devcontainer/docker/compose/docker-compose.override.yml down --remove-orphans 2>$null

  # Build with explicit context and FULL BUILD OUTPUT
  Write-Host "🔨 Building containers with FULL OUTPUT..." -ForegroundColor Yellow
  Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

  # Use docker-compose build with verbose output - NO SUPPRESSION
  docker-compose -f .devcontainer/docker/compose/docker-compose.main.yml -f .devcontainer/docker/compose/docker-compose.services.yml -f .devcontainer/docker/compose/docker-compose.override.yml build --no-cache --progress=plain

  Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

  if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ DevContainer build completed successfully!" -ForegroundColor Green

    # Show the built images
    Write-Host "📦 Built images:" -ForegroundColor Cyan
    docker images --filter "reference=dind-*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

    Write-Host "" -ForegroundColor White
    Write-Host "🎉 Next steps:" -ForegroundColor Green
    Write-Host "   🚀 Run: docker-compose up -d" -ForegroundColor Cyan
    Write-Host "   🔍 Check: docker-compose ps" -ForegroundColor Cyan
    Write-Host "   📊 Status: ./dev-status.sh" -ForegroundColor Cyan
  } else {
    Write-Host "❌ DevContainer build failed!" -ForegroundColor Red
    Write-Host "💡 Try running the clean script first: pwsh .devcontainer\scripts\powershell\clean.ps1" -ForegroundColor Yellow
    exit 1
  }
} catch {
  Write-Host "❌ Error during build: $_" -ForegroundColor Red
  Write-Host "💡 Check the error details above and try again" -ForegroundColor Yellow
  exit 1
}
