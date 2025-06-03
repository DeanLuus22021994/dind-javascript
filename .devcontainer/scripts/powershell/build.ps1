#!/usr/bin/env pwsh
# DevContainer Build Script
# Builds the DevContainer with Docker Compose

# Set error action preference
$ErrorActionPreference = "Stop"

# Navigate to the .devcontainer directory
Set-Location -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSScriptRoot))

Write-Host "🏗️  Building DevContainer..." -ForegroundColor Blue

try {
  # Build the DevContainer using Docker Compose
  docker-compose build --no-cache

  if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ DevContainer build completed successfully!" -ForegroundColor Green
  } else {
    Write-Host "❌ DevContainer build failed!" -ForegroundColor Red
    exit 1
  }
} catch {
  Write-Host "❌ Error during build: $_" -ForegroundColor Red
  exit 1
}
