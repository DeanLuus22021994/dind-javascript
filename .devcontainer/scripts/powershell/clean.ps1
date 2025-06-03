#!/usr/bin/env pwsh
# Docker Environment Cleanup Script
# Dramatically cleans Docker system to free up maximum space

# Set error action preference
$ErrorActionPreference = "Stop"

# Navigate to the project root directory
Set-Location -Path (Split-Path -Parent -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSScriptRoot)))

Write-Host "🧹 DRAMATICALLY CLEANING DOCKER ENVIRONMENT..." -ForegroundColor Blue
Write-Host "📍 Current directory: $(Get-Location)" -ForegroundColor Yellow

# Function to get Docker system usage
function Get-DockerSystemUsage {
  Write-Host "📊 Docker system disk usage:" -ForegroundColor Cyan
  try {
    docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}"
  } catch {
    Write-Host "   Unable to get Docker system usage" -ForegroundColor Yellow
  }
}

# Function to clean Docker BuildKit cache aggressively
function Clear-BuildKitCache {
  Write-Host "🗑️  Clearing BuildKit cache aggressively..." -ForegroundColor Yellow
  try {
    # Clear all BuildKit cache
    docker buildx prune --all --force 2>$null

    # Remove BuildKit builder instances
    $builders = docker buildx ls --format "{{.Name}}" | Where-Object { $_ -ne "default" }
    foreach ($builder in $builders) {
      Write-Host "   Removing BuildKit builder: $builder" -ForegroundColor DarkYellow
      docker buildx rm $builder --force 2>$null
    }

    Write-Host "✅ BuildKit cache cleared!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  BuildKit cache cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker volumes aggressively
function Clear-DockerVolumes {
  Write-Host "📦 Cleaning Docker volumes aggressively..." -ForegroundColor Yellow
  try {
    # List all volumes before cleanup
    $volumesBefore = (docker volume ls -q | Measure-Object).Count
    Write-Host "   Found $volumesBefore volumes before cleanup" -ForegroundColor DarkYellow

    # Remove all unused volumes
    docker volume prune --all --force 2>$null

    # Remove project-specific volumes if they exist
    $projectVolumes = docker volume ls --filter "name=dind-*" --format "{{.Name}}"
    foreach ($volume in $projectVolumes) {
      Write-Host "   Removing project volume: $volume" -ForegroundColor DarkYellow
      docker volume rm $volume --force 2>$null
    }

    $volumesAfter = (docker volume ls -q | Measure-Object).Count
    $volumesRemoved = $volumesBefore - $volumesAfter
    Write-Host "✅ Removed $volumesRemoved volumes!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Volume cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker networks aggressively
function Clear-DockerNetworks {
  Write-Host "🌐 Cleaning Docker networks aggressively..." -ForegroundColor Yellow
  try {
    # List networks before cleanup
    $networksBefore = (docker network ls --filter "driver=bridge" --format "{{.Name}}" | Where-Object { $_ -ne "bridge" -and $_ -ne "host" -and $_ -ne "none" } | Measure-Object).Count
    Write-Host "   Found $networksBefore custom networks before cleanup" -ForegroundColor DarkYellow

    # Remove all unused networks
    docker network prune --force 2>$null

    # Remove project-specific networks
    $projectNetworks = docker network ls --filter "name=*devcontainer*" --format "{{.Name}}"
    foreach ($network in $projectNetworks) {
      Write-Host "   Removing project network: $network" -ForegroundColor DarkYellow
      docker network rm $network --force 2>$null
    }

    Write-Host "✅ Networks cleaned!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Network cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker images aggressively
function Clear-DockerImages {
  Write-Host "🖼️  Cleaning Docker images aggressively..." -ForegroundColor Yellow
  try {
    # List images before cleanup
    $imagesBefore = (docker images -q | Measure-Object).Count
    Write-Host "   Found $imagesBefore images before cleanup" -ForegroundColor DarkYellow

    # Remove all unused images (not just dangling)
    docker image prune --all --force 2>$null

    # Remove project-specific images
    $projectImages = docker images --filter "reference=dind-*" --format "{{.Repository}}:{{.Tag}}"
    foreach ($image in $projectImages) {
      Write-Host "   Removing project image: $image" -ForegroundColor DarkYellow
      docker rmi $image --force 2>$null
    }

    # Remove any remaining dangling images
    $danglingImages = docker images -f "dangling=true" -q
    if ($danglingImages) {
      Write-Host "   Removing dangling images..." -ForegroundColor DarkYellow
      docker rmi $danglingImages --force 2>$null
    }

    $imagesAfter = (docker images -q | Measure-Object).Count
    $imagesRemoved = $imagesBefore - $imagesAfter
    Write-Host "✅ Removed $imagesRemoved images!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Image cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker containers aggressively
function Clear-DockerContainers {
  Write-Host "📦 Cleaning Docker containers aggressively..." -ForegroundColor Yellow
  try {
    # List containers before cleanup
    $containersBefore = (docker ps -aq | Measure-Object).Count
    Write-Host "   Found $containersBefore containers before cleanup" -ForegroundColor DarkYellow

    # Stop all running containers
    $runningContainers = docker ps -q
    if ($runningContainers) {
      Write-Host "   Stopping all running containers..." -ForegroundColor DarkYellow
      docker stop $runningContainers --time 10 2>$null
    }

    # Remove all containers
    docker container prune --force 2>$null

    # Force remove any remaining containers
    $allContainers = docker ps -aq
    if ($allContainers) {
      Write-Host "   Force removing remaining containers..." -ForegroundColor DarkYellow
      docker rm $allContainers --force 2>$null
    }

    $containersAfter = (docker ps -aq | Measure-Object).Count
    $containersRemoved = $containersBefore - $containersAfter
    Write-Host "✅ Removed $containersRemoved containers!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Container cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker system cache
function Clear-DockerSystemCache {
  Write-Host "💾 Cleaning Docker system cache..." -ForegroundColor Yellow
  try {
    # Clear system cache
    docker system prune --all --force --volumes 2>$null
    Write-Host "✅ System cache cleared!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  System cache cleanup encountered issues" -ForegroundColor Yellow
  }
}

try {
  # Show initial disk usage
  Write-Host "📊 INITIAL DOCKER SYSTEM STATUS:" -ForegroundColor Cyan
  Get-DockerSystemUsage
  Write-Host ""

  # Stop DevContainer services first
  Write-Host "🛑 Stopping DevContainer services..." -ForegroundColor Yellow
  $composeFiles = @(
    ".devcontainer/docker/compose/docker-compose.main.yml",
    ".devcontainer/docker/compose/docker-compose.services.yml",
    ".devcontainer/docker/compose/docker-compose.override.yml"
  )

  $composeArgs = @()
  foreach ($file in $composeFiles) {
    if (Test-Path $file) {
      $composeArgs += @("-f", $file)
    }
  }

  if ($composeArgs.Count -gt 0) {
    & docker-compose @composeArgs down --remove-orphans --volumes --rmi all 2>$null
    Write-Host "✅ DevContainer services stopped!" -ForegroundColor Green
  }

  Write-Host ""
  Write-Host "🚀 BEGINNING AGGRESSIVE CLEANUP..." -ForegroundColor Red
  Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

  # Perform aggressive cleanup in optimal order
  Clear-DockerContainers
  Write-Host ""

  Clear-DockerImages
  Write-Host ""

  Clear-DockerVolumes
  Write-Host ""

  Clear-DockerNetworks
  Write-Host ""

  Clear-BuildKitCache
  Write-Host ""

  Clear-DockerSystemCache
  Write-Host ""

  Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host "📊 FINAL DOCKER SYSTEM STATUS:" -ForegroundColor Cyan
  Get-DockerSystemUsage
  Write-Host ""

  # Additional system information
  Write-Host "🔍 ADDITIONAL CLEANUP INFORMATION:" -ForegroundColor Cyan
  try {
    Write-Host "   Docker version: $(docker --version)" -ForegroundColor DarkCyan
    Write-Host "   Docker Compose version: $(docker-compose --version)" -ForegroundColor DarkCyan

    $dockerInfo = docker info --format "{{.DriverStatus}}" 2>$null
    if ($dockerInfo) {
      Write-Host "   Docker driver status: Available" -ForegroundColor DarkCyan
    }
  } catch {
    Write-Host "   Docker system information unavailable" -ForegroundColor Yellow
  }

  Write-Host ""
  Write-Host "✅ DRAMATIC DOCKER ENVIRONMENT CLEANUP COMPLETED SUCCESSFULLY!" -ForegroundColor Green
  Write-Host "🎉 Your Docker environment has been completely cleaned and optimized!" -ForegroundColor Green
  Write-Host ""
  Write-Host "💡 Next steps:" -ForegroundColor Blue
  Write-Host "   🔨 Rebuild containers: pwsh .devcontainer\scripts\powershell\build.ps1" -ForegroundColor Cyan
  Write-Host "   🚀 Start fresh environment: docker-compose up -d" -ForegroundColor Cyan
  Write-Host "   📊 Check status: docker system df" -ForegroundColor Cyan

} catch {
  Write-Host ""
  Write-Host "❌ CRITICAL ERROR DURING CLEANUP: $_" -ForegroundColor Red
  Write-Host "💡 Try running the following manual commands:" -ForegroundColor Yellow
  Write-Host "   docker system prune --all --force --volumes" -ForegroundColor Cyan
  Write-Host "   docker container prune --force" -ForegroundColor Cyan
  Write-Host "   docker image prune --all --force" -ForegroundColor Cyan
  Write-Host "   docker volume prune --all --force" -ForegroundColor Cyan
  Write-Host "   docker network prune --force" -ForegroundColor Cyan
  exit 1
}
