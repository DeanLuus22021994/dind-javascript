#!/usr/bin/env pwsh
# Enhanced DevContainer Startup Script for PowerShell

Write-Host "🚀 Starting enhanced DevContainer with Docker Compose..." -ForegroundColor Green

try {
  Set-Location ".devcontainer"
    
  if (-not (Test-Path "docker-compose.yml")) {
    Write-Error "docker-compose.yml not found in .devcontainer directory"
    Set-Location ".."
    exit 1
  }
    
  Write-Host "Starting Docker Compose services..." -ForegroundColor Yellow
  docker compose up -d
    
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to start Docker Compose"
    Set-Location ".."
    exit 1
  }
    
  Set-Location ".."
  Write-Host "✅ DevContainer is now running. You can attach to it in VS Code." -ForegroundColor Green
    
  # Optional: Wait for services to be ready
  Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
  Start-Sleep -Seconds 5
    
  Write-Host "Testing container connectivity..." -ForegroundColor Yellow
  docker compose -f .devcontainer/docker-compose.yml ps
    
} catch {
  Write-Error "An error occurred: $_"
  Set-Location ".."
  exit 1
}
