#!/usr/bin/env pwsh
# Docker Environment Cleanup Script
# Prunes Docker system to free up space

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🧹 Cleaning Docker environment..." -ForegroundColor Blue

try {
  # Stop any running containers from the DevContainer
  Write-Host "Stopping DevContainer services..." -ForegroundColor Yellow
  Set-Location -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSScriptRoot))
  docker-compose down --remove-orphans 2>$null

  # Prune Docker system
  Write-Host "Pruning Docker containers..." -ForegroundColor Yellow
  docker container prune -f

  Write-Host "Pruning Docker images..." -ForegroundColor Yellow
  docker image prune -f

  Write-Host "Pruning Docker networks..." -ForegroundColor Yellow
  docker network prune -f

  Write-Host "Pruning Docker build cache..." -ForegroundColor Yellow
  docker builder prune -f

  # Show disk space reclaimed
  Write-Host "Docker system disk usage:" -ForegroundColor Cyan
  docker system df

  Write-Host "✅ Docker environment cleanup completed!" -ForegroundColor Green

} catch {
  Write-Host "❌ Error during cleanup: $_" -ForegroundColor Red
  exit 1
}
