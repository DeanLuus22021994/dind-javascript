#!/usr/bin/env pwsh
# Docker Environment Cleanup Script
# Dramatically cleans Docker system to free up maximum space with MAXIMUM CPU UTILIZATION

# Set error action preference and enable maximum performance
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Get maximum CPU threads for parallel processing
$MaxThreads = [Environment]::ProcessorCount
$ThrottleLimit = $MaxThreads * 2  # Hyper-threading optimization

Write-Host "🚀 INITIALIZING MAXIMUM PERFORMANCE CLEANUP..." -ForegroundColor Red
Write-Host "💻 CPU Cores: $MaxThreads | Thread Limit: $ThrottleLimit" -ForegroundColor Yellow

# Navigate to the project root directory
Set-Location -Path (Split-Path -Parent -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSScriptRoot)))

Write-Host "🧹 DRAMATICALLY CLEANING DOCKER ENVIRONMENT WITH MAXIMUM CPU UTILIZATION..." -ForegroundColor Blue
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

# Function to clean Docker BuildKit cache aggressively with parallel processing
function Clear-BuildKitCache {
  Write-Host "🗑️  Clearing BuildKit cache aggressively with PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Parallel BuildKit operations
    $jobs = @()

    # Job 1: Clear all BuildKit cache
    $jobs += Start-Job -ScriptBlock {
      docker buildx prune --all --force 2>$null
    }

    # Job 2: Get and remove BuildKit builders in parallel
    $jobs += Start-Job -ScriptBlock {
      $builders = docker buildx ls --format "{{.Name}}" | Where-Object { $_ -ne "default" }
      $builders | ForEach-Object -Parallel {
        docker buildx rm $_ --force 2>$null
      } -ThrottleLimit $using:ThrottleLimit
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    Write-Host "✅ BuildKit cache cleared with MAXIMUM CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  BuildKit cache cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker volumes aggressively with parallel processing
function Clear-DockerVolumes {
  Write-Host "📦 Cleaning Docker volumes aggressively with PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Get volumes count before cleanup
    $volumesBefore = (docker volume ls -q | Measure-Object).Count
    Write-Host "   Found $volumesBefore volumes before cleanup" -ForegroundColor DarkYellow

    # Parallel volume operations
    $jobs = @()

    # Job 1: Prune unused volumes
    $jobs += Start-Job -ScriptBlock {
      docker volume prune --all --force 2>$null
    }

    # Job 2: Remove project-specific volumes in parallel
    $jobs += Start-Job -ScriptBlock {
      $projectVolumes = docker volume ls --filter "name=dind-*" --format "{{.Name}}"
      if ($projectVolumes) {
        $projectVolumes | ForEach-Object -Parallel {
          Write-Host "   Removing project volume: $_" -ForegroundColor DarkYellow
          docker volume rm $_ --force 2>$null
        } -ThrottleLimit $using:ThrottleLimit
      }
    }

    # Job 3: Remove any orphaned volumes
    $jobs += Start-Job -ScriptBlock {
      $orphanedVolumes = docker volume ls --filter "dangling=true" --format "{{.Name}}"
      if ($orphanedVolumes) {
        $orphanedVolumes | ForEach-Object -Parallel {
          docker volume rm $_ --force 2>$null
        } -ThrottleLimit $using:ThrottleLimit
      }
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    $volumesAfter = (docker volume ls -q | Measure-Object).Count
    $volumesRemoved = $volumesBefore - $volumesAfter
    Write-Host "✅ Removed $volumesRemoved volumes with MAXIMUM CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Volume cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker networks aggressively with parallel processing
function Clear-DockerNetworks {
  Write-Host "🌐 Cleaning Docker networks aggressively with PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Get networks count before cleanup
    $networksBefore = (docker network ls --filter "driver=bridge" --format "{{.Name}}" | Where-Object { $_ -ne "bridge" -and $_ -ne "host" -and $_ -ne "none" } | Measure-Object).Count
    Write-Host "   Found $networksBefore custom networks before cleanup" -ForegroundColor DarkYellow

    # Parallel network operations
    $jobs = @()

    # Job 1: Prune unused networks
    $jobs += Start-Job -ScriptBlock {
      docker network prune --force 2>$null
    }

    # Job 2: Remove project-specific networks in parallel
    $jobs += Start-Job -ScriptBlock {
      $projectNetworks = docker network ls --filter "name=*devcontainer*" --format "{{.Name}}"
      if ($projectNetworks) {
        $projectNetworks | ForEach-Object -Parallel {
          Write-Host "   Removing project network: $_" -ForegroundColor DarkYellow
          docker network rm $_ --force 2>$null
        } -ThrottleLimit $using:ThrottleLimit
      }
    }

    # Job 3: Remove custom bridge networks
    $jobs += Start-Job -ScriptBlock {
      $customNetworks = docker network ls --filter "driver=bridge" --format "{{.Name}}" | Where-Object { $_ -ne "bridge" -and $_ -notlike "*devcontainer*" }
      if ($customNetworks) {
        $customNetworks | ForEach-Object -Parallel {
          docker network rm $_ --force 2>$null
        } -ThrottleLimit $using:ThrottleLimit
      }
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    Write-Host "✅ Networks cleaned with MAXIMUM CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Network cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker images aggressively with parallel processing
function Clear-DockerImages {
  Write-Host "🖼️  Cleaning Docker images aggressively with PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Get images count before cleanup
    $imagesBefore = (docker images -q | Measure-Object).Count
    Write-Host "   Found $imagesBefore images before cleanup" -ForegroundColor DarkYellow

    # Parallel image operations
    $jobs = @()

    # Job 1: Prune all unused images
    $jobs += Start-Job -ScriptBlock {
      docker image prune --all --force 2>$null
    }

    # Job 2: Remove project-specific images in parallel
    $jobs += Start-Job -ScriptBlock {
      $projectImages = docker images --filter "reference=dind-*" --format "{{.Repository}}:{{.Tag}}"
      if ($projectImages) {
        $projectImages | ForEach-Object -Parallel {
          Write-Host "   Removing project image: $_" -ForegroundColor DarkYellow
          docker rmi $_ --force 2>$null
        } -ThrottleLimit $using:ThrottleLimit
      }
    }

    # Job 3: Remove dangling images in parallel
    $jobs += Start-Job -ScriptBlock {
      $danglingImages = docker images -f "dangling=true" -q
      if ($danglingImages) {
        $danglingImages | ForEach-Object -Parallel {
          docker rmi $_ --force 2>$null
        } -ThrottleLimit $using:ThrottleLimit
      }
    }

    # Job 4: Remove untagged images in parallel
    $jobs += Start-Job -ScriptBlock {
      $untaggedImages = docker images --filter "dangling=false" --format "{{.ID}}" | Where-Object { (docker images --format "{{.Repository}}:{{.Tag}}" $_) -eq "<none>:<none>" }
      if ($untaggedImages) {
        $untaggedImages | ForEach-Object -Parallel {
          docker rmi $_ --force 2>$null
        } -ThrottleLimit $using:ThrottleLimit
      }
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    $imagesAfter = (docker images -q | Measure-Object).Count
    $imagesRemoved = $imagesBefore - $imagesAfter
    Write-Host "✅ Removed $imagesRemoved images with MAXIMUM CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Image cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker containers aggressively with parallel processing
function Clear-DockerContainers {
  Write-Host "📦 Cleaning Docker containers aggressively with PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Get containers count before cleanup
    $containersBefore = (docker ps -aq | Measure-Object).Count
    Write-Host "   Found $containersBefore containers before cleanup" -ForegroundColor DarkYellow

    # Parallel container operations
    $jobs = @()

    # Job 1: Stop all running containers in parallel
    $jobs += Start-Job -ScriptBlock {
      $runningContainers = docker ps -q
      if ($runningContainers) {
        Write-Host "   Stopping all running containers with PARALLEL PROCESSING..." -ForegroundColor DarkYellow
        $runningContainers | ForEach-Object -Parallel {
          docker stop $_ --time 10 2>$null
        } -ThrottleLimit $using:ThrottleLimit
      }
    }

    # Wait for stop job to complete before removal
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job
    $jobs = @()

    # Job 2: Prune containers
    $jobs += Start-Job -ScriptBlock {
      docker container prune --force 2>$null
    }

    # Job 3: Force remove any remaining containers in parallel
    $jobs += Start-Job -ScriptBlock {
      Start-Sleep -Seconds 2  # Small delay to ensure stop operations complete
      $allContainers = docker ps -aq
      if ($allContainers) {
        Write-Host "   Force removing remaining containers with PARALLEL PROCESSING..." -ForegroundColor DarkYellow
        $allContainers | ForEach-Object -Parallel {
          docker rm $_ --force 2>$null
        } -ThrottleLimit $using:ThrottleLimit
      }
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    $containersAfter = (docker ps -aq | Measure-Object).Count
    $containersRemoved = $containersBefore - $containersAfter
    Write-Host "✅ Removed $containersRemoved containers with MAXIMUM CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Container cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker system cache with parallel processing
function Clear-DockerSystemCache {
  Write-Host "💾 Cleaning Docker system cache with PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Parallel system operations
    $jobs = @()

    # Job 1: System prune
    $jobs += Start-Job -ScriptBlock {
      docker system prune --all --force --volumes 2>$null
    }

    # Job 2: Clear build cache
    $jobs += Start-Job -ScriptBlock {
      docker builder prune --all --force 2>$null
    }

    # Job 3: Clean up temporary files
    $jobs += Start-Job -ScriptBlock {
      if ($IsWindows) {
        # Windows Docker temp cleanup
        $dockerTemp = "$env:LOCALAPPDATA\Docker"
        if (Test-Path $dockerTemp) {
          Get-ChildItem $dockerTemp -Recurse -Force | Where-Object { $_.Name -like "*tmp*" -or $_.Name -like "*temp*" } | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
      }
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    Write-Host "✅ System cache cleared with MAXIMUM CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  System cache cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to perform comprehensive parallel cleanup
function Invoke-ParallelDockerCleanup {
  Write-Host "🚀 EXECUTING COMPREHENSIVE PARALLEL CLEANUP..." -ForegroundColor Red

  # Phase 1: Stop services and containers (sequential for safety)
  Write-Host "🛑 Phase 1: Stopping services and containers..." -ForegroundColor Yellow
  Clear-DockerContainers
  Write-Host ""

  # Phase 2: Parallel cleanup of images, volumes, networks, and cache
  Write-Host "⚡ Phase 2: MAXIMUM PARALLEL CLEANUP..." -ForegroundColor Red
  $cleanupJobs = @()

  # Start all cleanup functions in parallel
  $cleanupJobs += Start-Job -Name "ImageCleanup" -ScriptBlock ${function:Clear-DockerImages}
  $cleanupJobs += Start-Job -Name "VolumeCleanup" -ScriptBlock ${function:Clear-DockerVolumes}
  $cleanupJobs += Start-Job -Name "NetworkCleanup" -ScriptBlock ${function:Clear-DockerNetworks}
  $cleanupJobs += Start-Job -Name "BuildKitCleanup" -ScriptBlock ${function:Clear-BuildKitCache}

  # Monitor parallel jobs with progress
  Write-Host "   Running parallel cleanup jobs across $($cleanupJobs.Count) threads..." -ForegroundColor Cyan

  $completed = 0
  while ($completed -lt $cleanupJobs.Count) {
    $runningJobs = $cleanupJobs | Where-Object { $_.State -eq "Running" }
    $completedJobs = $cleanupJobs | Where-Object { $_.State -eq "Completed" }

    if ($completedJobs.Count -gt $completed) {
      $completed = $completedJobs.Count
      Write-Host "   ✅ $completed/$($cleanupJobs.Count) parallel cleanup jobs completed" -ForegroundColor Green
    }

    Start-Sleep -Milliseconds 500
  }

  # Wait for all jobs and collect output
  $cleanupJobs | Wait-Job | Receive-Job
  $cleanupJobs | Remove-Job

  Write-Host ""

  # Phase 3: Final system cleanup
  Write-Host "🧹 Phase 3: Final system cleanup..." -ForegroundColor Yellow
  Clear-DockerSystemCache
  Write-Host ""
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
  Write-Host "🚀 BEGINNING MAXIMUM PARALLEL AGGRESSIVE CLEANUP..." -ForegroundColor Red
  Write-Host "💻 Utilizing ALL $MaxThreads CPU cores with $ThrottleLimit concurrent threads!" -ForegroundColor Red
  Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

  # Execute comprehensive parallel cleanup
  Invoke-ParallelDockerCleanup

  Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host "📊 FINAL DOCKER SYSTEM STATUS:" -ForegroundColor Cyan
  Get-DockerSystemUsage
  Write-Host ""

  # Additional system information
  Write-Host "🔍 ADDITIONAL CLEANUP INFORMATION:" -ForegroundColor Cyan
  try {
    Write-Host "   Docker version: $(docker --version)" -ForegroundColor DarkCyan
    Write-Host "   Docker Compose version: $(docker-compose --version)" -ForegroundColor DarkCyan
    Write-Host "   CPU Cores utilized: $MaxThreads" -ForegroundColor DarkCyan
    Write-Host "   Thread limit used: $ThrottleLimit" -ForegroundColor DarkCyan

    $dockerInfo = docker info --format "{{.DriverStatus}}" 2>$null
    if ($dockerInfo) {
      Write-Host "   Docker driver status: Available" -ForegroundColor DarkCyan
    }
  } catch {
    Write-Host "   Docker system information unavailable" -ForegroundColor Yellow
  }

  Write-Host ""
  Write-Host "✅ MAXIMUM PARALLEL DOCKER ENVIRONMENT CLEANUP COMPLETED SUCCESSFULLY!" -ForegroundColor Green
  Write-Host "🚀 Your Docker environment has been DRAMATICALLY cleaned with MAXIMUM CPU UTILIZATION!" -ForegroundColor Green
  Write-Host "⚡ Performance: $ThrottleLimit concurrent threads across $MaxThreads CPU cores!" -ForegroundColor Green
  Write-Host ""
  Write-Host "💡 Next steps:" -ForegroundColor Blue
  Write-Host "   🔨 Rebuild containers: pwsh .devcontainer\scripts\powershell\build.ps1" -ForegroundColor Cyan
  Write-Host "   🚀 Start fresh environment: docker-compose up -d" -ForegroundColor Cyan
  Write-Host "   📊 Check status: docker system df" -ForegroundColor Cyan

} catch {
  Write-Host ""
  Write-Host "❌ CRITICAL ERROR DURING MAXIMUM PARALLEL CLEANUP: $_" -ForegroundColor Red
  Write-Host "💡 Try running the following manual commands:" -ForegroundColor Yellow
  Write-Host "   docker system prune --all --force --volumes" -ForegroundColor Cyan
  Write-Host "   docker container prune --force" -ForegroundColor Cyan
  Write-Host "   docker image prune --all --force" -ForegroundColor Cyan
  Write-Host "   docker volume prune --all --force" -ForegroundColor Cyan
  Write-Host "   docker network prune --force" -ForegroundColor Cyan
  exit 1
}
