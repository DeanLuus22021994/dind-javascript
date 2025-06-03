#!/usr/bin/env pwsh
# Docker Environment Cleanup Script
# Dramatically cleans Docker system to free up maximum space with MAXIMUM CPU UTILIZATION

# Set error action preference and enable maximum performance
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Get maximum CPU threads for parallel processing with aggressive optimization
$MaxThreads = [Environment]::ProcessorCount
$ThrottleLimit = $MaxThreads * 4  # EXTREME hyper-threading optimization
$ParallelBatchSize = [Math]::Max(1, [Math]::Floor($MaxThreads / 2))

Write-Host "🚀 INITIALIZING MAXIMUM PERFORMANCE CLEANUP..." -ForegroundColor Red
Write-Host "💻 CPU Cores: $MaxThreads | Thread Limit: $ThrottleLimit | Batch Size: $ParallelBatchSize" -ForegroundColor Yellow

# Navigate to the project root directory
Set-Location -Path (Split-Path -Parent -Path (Split-Path -Parent -Path (Split-Path -Parent -Path $PSScriptRoot)))

Write-Host "🧹 DRAMATICALLY CLEANING DOCKER ENVIRONMENT WITH EXTREME CPU UTILIZATION..." -ForegroundColor Blue
Write-Host "📍 Current directory: $(Get-Location)" -ForegroundColor Yellow

# Function to get Docker system usage with fallback
function Get-DockerSystemUsage {
  Write-Host "📊 Docker system disk usage:" -ForegroundColor Cyan
  try {
    # Try modern format first
    $usage = docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}" 2>$null
    if ($LASTEXITCODE -eq 0 -and $usage) {
      $usage
    } else {
      # Fallback to basic format
      docker system df 2>$null
    }
  } catch {
    try {
      # Final fallback - basic command
      docker system df
    } catch {
      Write-Host "   Unable to get Docker system usage - Docker may not be running or accessible" -ForegroundColor Yellow
    }
  }
}

# Function to execute Docker commands in ultra-parallel batches
function Invoke-UltraParallelDockerCommand {
  param(
    [Parameter(Mandatory)]
    [string[]]$Items,

    [Parameter(Mandatory)]
    [scriptblock]$Command,

    [string]$Description = "Processing items"
  )

  if ($Items.Count -eq 0) {
    return
  }

  Write-Host "   $Description with ULTRA-PARALLEL processing ($($Items.Count) items)..." -ForegroundColor DarkYellow

  # Split items into batches for maximum CPU utilization
  $batches = @()
  for ($i = 0; $i -lt $Items.Count; $i += $ParallelBatchSize) {
    $end = [Math]::Min($i + $ParallelBatchSize - 1, $Items.Count - 1)
    $batches += , @($Items[$i..$end])
  }

  # Process batches in parallel with maximum throttling
  $batches | ForEach-Object -Parallel {
    $batch = $_
    $batch | ForEach-Object -Parallel $using:Command -ThrottleLimit $using:ThrottleLimit
  } -ThrottleLimit $MaxThreads
}

# Function to clean Docker BuildKit cache with EXTREME parallel processing
function Clear-BuildKitCache {
  Write-Host "🗑️  Clearing BuildKit cache with EXTREME PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Ultra-parallel BuildKit operations
    $jobs = @()

    # Job 1: Clear all BuildKit cache with multiple prune commands
    $jobs += Start-Job -ScriptBlock {
      @(
        { docker buildx prune --all --force 2>$null },
        { docker builder prune --all --force 2>$null },
        { docker buildx prune --filter "until=1h" --force 2>$null }
      ) | ForEach-Object -Parallel { & $_ } -ThrottleLimit $using:ThrottleLimit
    }

    # Job 2: Remove BuildKit builders in ultra-parallel
    $jobs += Start-Job -ScriptBlock {
      try {
        $builders = docker buildx ls --format "{{.Name}}" 2>$null | Where-Object { $_ -ne "default" -and $_ -ne "desktop-linux" }
        if ($builders) {
          $builders | ForEach-Object -Parallel {
            docker buildx rm $_ --force 2>$null
          } -ThrottleLimit $using:ThrottleLimit
        }
      } catch { }
    }

    # Job 3: Clear Docker build cache
    $jobs += Start-Job -ScriptBlock {
      @(
        { docker system prune --filter "label=stage=builder" --force 2>$null },
        { docker image prune --filter "label=stage=builder" --force 2>$null }
      ) | ForEach-Object -Parallel { & $_ } -ThrottleLimit $using:ThrottleLimit
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    Write-Host "✅ BuildKit cache cleared with EXTREME CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  BuildKit cache cleanup encountered issues (this is normal if BuildKit is not available)" -ForegroundColor Yellow
  }
}

# Function to clean Docker volumes with EXTREME parallel processing
function Clear-DockerVolumes {
  Write-Host "📦 Cleaning Docker volumes with EXTREME PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Get volumes count before cleanup
    $allVolumes = docker volume ls -q 2>$null
    $volumesBefore = ($allVolumes | Measure-Object).Count
    Write-Host "   Found $volumesBefore volumes before cleanup" -ForegroundColor DarkYellow

    # Ultra-parallel volume operations
    $jobs = @()

    # Job 1: Multiple prune operations in parallel
    $jobs += Start-Job -ScriptBlock {
      @(
        { docker volume prune --all --force 2>$null },
        { docker volume prune --filter "dangling=true" --force 2>$null },
        { docker system prune --volumes --force 2>$null }
      ) | ForEach-Object -Parallel { & $_ } -ThrottleLimit $using:ThrottleLimit
    }

    # Job 2: Remove project-specific volumes in ultra-parallel
    $jobs += Start-Job -ScriptBlock {
      try {
        $projectVolumes = docker volume ls --filter "name=dind-*" --format "{{.Name}}" 2>$null
        if ($projectVolumes) {
          & $using:Function:Invoke-UltraParallelDockerCommand -Items $projectVolumes -Command {
            docker volume rm $_ --force 2>$null
          } -Description "Removing project volumes"
        }
      } catch { }
    }

    # Job 3: Remove orphaned and unnamed volumes
    $jobs += Start-Job -ScriptBlock {
      try {
        $orphanedVolumes = docker volume ls --filter "dangling=true" --format "{{.Name}}" 2>$null
        if ($orphanedVolumes) {
          & $using:Function:Invoke-UltraParallelDockerCommand -Items $orphanedVolumes -Command {
            docker volume rm $_ --force 2>$null
          } -Description "Removing orphaned volumes"
        }
      } catch { }
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    $volumesAfter = (docker volume ls -q 2>$null | Measure-Object).Count
    $volumesRemoved = $volumesBefore - $volumesAfter
    Write-Host "✅ Removed $volumesRemoved volumes with EXTREME CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Volume cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker networks with EXTREME parallel processing
function Clear-DockerNetworks {
  Write-Host "🌐 Cleaning Docker networks with EXTREME PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Get networks count before cleanup
    $customNetworks = docker network ls --filter "driver=bridge" --format "{{.Name}}" 2>$null | Where-Object { $_ -ne "bridge" -and $_ -ne "host" -and $_ -ne "none" }
    $networksBefore = ($customNetworks | Measure-Object).Count
    Write-Host "   Found $networksBefore custom networks before cleanup" -ForegroundColor DarkYellow

    # Ultra-parallel network operations
    $jobs = @()

    # Job 1: Multiple network prune operations
    $jobs += Start-Job -ScriptBlock {
      @(
        { docker network prune --force 2>$null },
        { docker system prune --force 2>$null }
      ) | ForEach-Object -Parallel { & $_ } -ThrottleLimit $using:ThrottleLimit
    }

    # Job 2: Remove project-specific networks
    $jobs += Start-Job -ScriptBlock {
      try {
        $projectNetworks = docker network ls --filter "name=*devcontainer*" --format "{{.Name}}" 2>$null
        if ($projectNetworks) {
          & $using:Function:Invoke-UltraParallelDockerCommand -Items $projectNetworks -Command {
            docker network rm $_ --force 2>$null
          } -Description "Removing project networks"
        }
      } catch { }
    }

    # Job 3: Remove custom bridge networks
    $jobs += Start-Job -ScriptBlock {
      try {
        $customBridgeNetworks = docker network ls --filter "driver=bridge" --format "{{.Name}}" 2>$null | Where-Object { $_ -ne "bridge" -and $_ -notlike "*devcontainer*" -and $_ -ne "host" -and $_ -ne "none" }
        if ($customBridgeNetworks) {
          & $using:Function:Invoke-UltraParallelDockerCommand -Items $customBridgeNetworks -Command {
            docker network rm $_ --force 2>$null
          } -Description "Removing custom networks"
        }
      } catch { }
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    Write-Host "✅ Networks cleaned with EXTREME CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Network cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker images with EXTREME parallel processing
function Clear-DockerImages {
  Write-Host "🖼️  Cleaning Docker images with EXTREME PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Get images count before cleanup
    $allImages = docker images -q 2>$null
    $imagesBefore = ($allImages | Measure-Object).Count
    Write-Host "   Found $imagesBefore images before cleanup" -ForegroundColor DarkYellow

    # Ultra-parallel image operations
    $jobs = @()

    # Job 1: Multiple image prune operations
    $jobs += Start-Job -ScriptBlock {
      @(
        { docker image prune --all --force 2>$null },
        { docker image prune --filter "dangling=true" --force 2>$null },
        { docker system prune --all --force 2>$null }
      ) | ForEach-Object -Parallel { & $_ } -ThrottleLimit $using:ThrottleLimit
    }

    # Job 2: Remove project-specific images
    $jobs += Start-Job -ScriptBlock {
      try {
        $projectImages = docker images --filter "reference=dind-*" --format "{{.Repository}}:{{.Tag}}" 2>$null
        if ($projectImages) {
          & $using:Function:Invoke-UltraParallelDockerCommand -Items $projectImages -Command {
            docker rmi $_ --force 2>$null
          } -Description "Removing project images"
        }
      } catch { }
    }

    # Job 3: Remove dangling and untagged images
    $jobs += Start-Job -ScriptBlock {
      try {
        $danglingImages = docker images -f "dangling=true" -q 2>$null
        if ($danglingImages) {
          & $using:Function:Invoke-UltraParallelDockerCommand -Items $danglingImages -Command {
            docker rmi $_ --force 2>$null
          } -Description "Removing dangling images"
        }
      } catch { }
    }

    # Job 4: Remove <none> tagged images
    $jobs += Start-Job -ScriptBlock {
      try {
        $noneImages = docker images --format "{{.ID}}" --filter "dangling=false" 2>$null | Where-Object {
          $imageInfo = docker images --format "{{.Repository}}:{{.Tag}}" $_ 2>$null
          $imageInfo -eq "<none>:<none>"
        }
        if ($noneImages) {
          & $using:Function:Invoke-UltraParallelDockerCommand -Items $noneImages -Command {
            docker rmi $_ --force 2>$null
          } -Description "Removing untagged images"
        }
      } catch { }
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    $imagesAfter = (docker images -q 2>$null | Measure-Object).Count
    $imagesRemoved = $imagesBefore - $imagesAfter
    Write-Host "✅ Removed $imagesRemoved images with EXTREME CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Image cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker containers with EXTREME parallel processing
function Clear-DockerContainers {
  Write-Host "📦 Cleaning Docker containers with EXTREME PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Get containers count before cleanup
    $allContainers = docker ps -aq 2>$null
    $containersBefore = ($allContainers | Measure-Object).Count
    Write-Host "   Found $containersBefore containers before cleanup" -ForegroundColor DarkYellow

    # Phase 1: Stop all running containers with extreme parallelization
    $runningContainers = docker ps -q 2>$null
    if ($runningContainers) {
      Write-Host "   Stopping $($runningContainers.Count) running containers with EXTREME PARALLEL PROCESSING..." -ForegroundColor DarkYellow
      Invoke-UltraParallelDockerCommand -Items $runningContainers -Command {
        docker stop $_ --time 5 2>$null  # Reduced timeout for faster cleanup
      } -Description "Stopping containers"

      # Small delay to ensure graceful shutdown
      Start-Sleep -Seconds 1
    }

    # Phase 2: Ultra-parallel container removal
    $jobs = @()

    # Job 1: Container prune operations
    $jobs += Start-Job -ScriptBlock {
      @(
        { docker container prune --force 2>$null },
        { docker system prune --force 2>$null }
      ) | ForEach-Object -Parallel { & $_ } -ThrottleLimit $using:ThrottleLimit
    }

    # Job 2: Force remove any remaining containers
    $jobs += Start-Job -ScriptBlock {
      Start-Sleep -Seconds 1  # Small delay to ensure prune operations start
      try {
        $remainingContainers = docker ps -aq 2>$null
        if ($remainingContainers) {
          & $using:Function:Invoke-UltraParallelDockerCommand -Items $remainingContainers -Command {
            docker rm $_ --force 2>$null
          } -Description "Force removing containers"
        }
      } catch { }
    }

    # Wait for all jobs to complete
    $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    $containersAfter = (docker ps -aq 2>$null | Measure-Object).Count
    $containersRemoved = $containersBefore - $containersAfter
    Write-Host "✅ Removed $containersRemoved containers with EXTREME CONCURRENCY!" -ForegroundColor Green
  } catch {
    Write-Host "⚠️  Container cleanup encountered issues" -ForegroundColor Yellow
  }
}

# Function to clean Docker system cache with EXTREME parallel processing
function Clear-DockerSystemCache {
  Write-Host "💾 Cleaning Docker system cache with EXTREME PARALLEL PROCESSING..." -ForegroundColor Yellow
  try {
    # Ultra-parallel system operations
    $jobs = @()

    # Job 1: Multiple system prune operations
    $jobs += Start-Job -ScriptBlock {
      @(
        { docker system prune --all --force --volumes 2>$null },
        { docker builder prune --all --force 2>$null },
        { docker buildx prune --all --force 2>$null }
      ) | ForEach-Object -Parallel { & $_ } -ThrottleLimit $using:ThrottleLimit
    }

    # Job 2: Clean up Docker temporary files and caches
    $jobs += Start-Job -ScriptBlock {
      try {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
          # Windows Docker temp cleanup with parallel processing
          $dockerPaths = @(
            "$env:LOCALAPPDATA\Docker",
            "$env:PROGRAMDATA\Docker",
            "$env:TEMP\docker*",
            "$env:LOCALAPPDATA\Temp\docker*"
          )

          $dockerPaths | ForEach-Object -Parallel {
            if (Test-Path $_) {
              try {
                Get-ChildItem $_ -Recurse -Force -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -like "*tmp*" -or $_.Name -like "*temp*" -or $_.Name -like "*cache*" } |
                  Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                } catch { }
              }
            } -ThrottleLimit $using:ThrottleLimit
          } else {
            # Linux/macOS Docker temp cleanup
            $dockerPaths = @(
              "/tmp/docker*",
              "/var/tmp/docker*",
              "$HOME/.docker/buildx",
              "$HOME/.docker/cli-plugins"
            )

            $dockerPaths | ForEach-Object -Parallel {
              if (Test-Path $_) {
                try {
                  Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
                } catch { }
              }
            } -ThrottleLimit $using:ThrottleLimit
          }
        } catch { }
      }

      # Job 3: Clear Docker logs
      $jobs += Start-Job -ScriptBlock {
        try {
          if ($IsWindows -or $env:OS -eq "Windows_NT") {
            $logPath = "$env:LOCALAPPDATA\Docker\log.txt"
            if (Test-Path $logPath) {
              Clear-Content $logPath -Force -ErrorAction SilentlyContinue
            }
          } else {
            $logPaths = @("/var/log/docker*", "/var/lib/docker/containers/*/*-json.log")
            $logPaths | ForEach-Object -Parallel {
              if (Test-Path $_) {
                try {
                  Clear-Content $_ -Force -ErrorAction SilentlyContinue
                } catch { }
              }
            } -ThrottleLimit $using:ThrottleLimit
          }
        } catch { }
      }

      # Wait for all jobs to complete
      $jobs | Wait-Job | Receive-Job
      $jobs | Remove-Job

      Write-Host "✅ System cache cleared with EXTREME CONCURRENCY!" -ForegroundColor Green
    } catch {
      Write-Host "⚠️  System cache cleanup encountered issues" -ForegroundColor Yellow
    }
  }

  # Function to perform comprehensive ultra-parallel cleanup
  function Invoke-UltraParallelDockerCleanup {
    Write-Host "🚀 EXECUTING COMPREHENSIVE ULTRA-PARALLEL CLEANUP..." -ForegroundColor Red

    # Phase 1: Stop services and containers (optimized for safety)
    Write-Host "🛑 Phase 1: Stopping services and containers with EXTREME optimization..." -ForegroundColor Yellow
    Clear-DockerContainers
    Write-Host ""

    # Phase 2: EXTREME parallel cleanup of all resources simultaneously
    Write-Host "⚡ Phase 2: EXTREME PARALLEL CLEANUP WITH MAXIMUM CPU UTILIZATION..." -ForegroundColor Red
    $cleanupJobs = @()

    # Start ALL cleanup functions in parallel with maximum concurrency
    $cleanupJobs += Start-Job -Name "ImageCleanup" -ScriptBlock ${function:Clear-DockerImages}
    $cleanupJobs += Start-Job -Name "VolumeCleanup" -ScriptBlock ${function:Clear-DockerVolumes}
    $cleanupJobs += Start-Job -Name "NetworkCleanup" -ScriptBlock ${function:Clear-DockerNetworks}
    $cleanupJobs += Start-Job -Name "BuildKitCleanup" -ScriptBlock ${function:Clear-BuildKitCache}
    $cleanupJobs += Start-Job -Name "SystemCacheCleanup" -ScriptBlock ${function:Clear-DockerSystemCache}

    # Enhanced monitoring with real-time progress
    Write-Host "   Running $($cleanupJobs.Count) EXTREME parallel cleanup jobs across ALL CPU threads..." -ForegroundColor Cyan
    Write-Host "   CPU Utilization: $ThrottleLimit concurrent threads on $MaxThreads cores" -ForegroundColor Cyan

    $completed = 0
    $startTime = Get-Date
    while ($completed -lt $cleanupJobs.Count) {
      $runningJobs = $cleanupJobs | Where-Object { $_.State -eq "Running" }
      $completedJobs = $cleanupJobs | Where-Object { $_.State -eq "Completed" }
      $failedJobs = $cleanupJobs | Where-Object { $_.State -eq "Failed" }

      if ($completedJobs.Count -gt $completed) {
        $completed = $completedJobs.Count
        $elapsedTime = ((Get-Date) - $startTime).TotalSeconds
        Write-Host ("   ✅ {0}/{1} parallel cleanup jobs completed ({2:F1}s elapsed)" -f $completed, $cleanupJobs.Count, $elapsedTime) -ForegroundColor Green
      }

      if ($failedJobs.Count -gt 0) {
        Write-Host "   ⚠️  $($failedJobs.Count) cleanup jobs encountered issues (continuing...)" -ForegroundColor Yellow
      }

      # Use $runningJobs for status monitoring
      if ($runningJobs.Count -gt 0) {
        Write-Host "   🔄 $($runningJobs.Count) jobs still running..." -ForegroundColor DarkCyan
      }

      Start-Sleep -Milliseconds 250  # Faster polling for better responsiveness
    }

    # Wait for all jobs and collect output
    $totalExecutionTime = ((Get-Date) - $startTime).TotalSeconds
    Write-Host ("   🎯 All parallel jobs completed in {0:F1} seconds!" -f $totalExecutionTime) -ForegroundColor Green

    $cleanupJobs | Wait-Job | Receive-Job
    $cleanupJobs | Remove-Job

    Write-Host ""
    Write-Host "🏁 EXTREME PARALLEL CLEANUP PHASE COMPLETED!" -ForegroundColor Green
  }

  try {
    # Show initial disk usage
    Write-Host "📊 INITIAL DOCKER SYSTEM STATUS:" -ForegroundColor Cyan
    Get-DockerSystemUsage
    Write-Host ""

    # Stop DevContainer services first with optimized approach
    Write-Host "🛑 Stopping DevContainer services with optimized approach..." -ForegroundColor Yellow
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
      # Parallel service shutdown
      $shutdownJobs = @()
      $shutdownJobs += Start-Job -ScriptBlock {
        & docker-compose @using:composeArgs down --remove-orphans 2>$null
      }
      $shutdownJobs += Start-Job -ScriptBlock {
        & docker-compose @using:composeArgs down --volumes 2>$null
      }
      $shutdownJobs += Start-Job -ScriptBlock {
        & docker-compose @using:composeArgs down --rmi all 2>$null
      }

      $shutdownJobs | Wait-Job | Receive-Job
      $shutdownJobs | Remove-Job

      Write-Host "✅ DevContainer services stopped with parallel optimization!" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "🚀 BEGINNING EXTREME PARALLEL AGGRESSIVE CLEANUP..." -ForegroundColor Red
    Write-Host "💻 Utilizing ALL $MaxThreads CPU cores with $ThrottleLimit concurrent threads!" -ForegroundColor Red
    Write-Host "⚡ Batch processing: $ParallelBatchSize items per batch for optimal throughput!" -ForegroundColor Red
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

    # Execute ultra-parallel comprehensive cleanup
    $cleanupStartTime = Get-Date
    Invoke-UltraParallelDockerCleanup
    $totalCleanupTime = ((Get-Date) - $cleanupStartTime).TotalSeconds

    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "📊 FINAL DOCKER SYSTEM STATUS:" -ForegroundColor Cyan
    Get-DockerSystemUsage
    Write-Host ""

    # Enhanced system information with performance metrics
    Write-Host "🔍 EXTREME CLEANUP PERFORMANCE METRICS:" -ForegroundColor Cyan
    try {
      Write-Host "   🐋 Docker version: $(docker --version)" -ForegroundColor DarkCyan
      Write-Host "   🐙 Docker Compose version: $(docker-compose --version)" -ForegroundColor DarkCyan
      Write-Host "   💻 CPU Cores utilized: $MaxThreads" -ForegroundColor DarkCyan
      Write-Host "   🧵 Thread limit used: $ThrottleLimit" -ForegroundColor DarkCyan
      Write-Host "   📦 Batch size: $ParallelBatchSize" -ForegroundColor DarkCyan
      Write-Host ("   ⏱️  Total cleanup time: {0:F1} seconds" -f $totalCleanupTime) -ForegroundColor DarkCyan
      Write-Host ("   ⚡ Performance: {0:F1} threads/second efficiency" -f ($ThrottleLimit / $totalCleanupTime)) -ForegroundColor DarkCyan

      $dockerInfo = docker info --format "{{.ServerVersion}}" 2>$null
      if ($dockerInfo) {
        Write-Host "   🔧 Docker Engine: $dockerInfo" -ForegroundColor DarkCyan
      }
    } catch {
      Write-Host "   ⚠️  Some Docker system information unavailable" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "✅ EXTREME PARALLEL DOCKER ENVIRONMENT CLEANUP COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "🚀 Your Docker environment has been DRAMATICALLY cleaned with EXTREME CPU UTILIZATION!" -ForegroundColor Green
    Write-Host "⚡ Performance Achievement: $ThrottleLimit concurrent threads across $MaxThreads CPU cores!" -ForegroundColor Green
    Write-Host ("🎯 Cleanup completed in {0:F1} seconds with maximum efficiency!" -f $totalCleanupTime) -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 Next steps:" -ForegroundColor Blue
    Write-Host "   🔨 Rebuild containers: pwsh .devcontainer\scripts\powershell\build.ps1" -ForegroundColor Cyan
    Write-Host "   🚀 Start fresh environment: docker-compose up -d" -ForegroundColor Cyan
    Write-Host "   📊 Check status: docker system df" -ForegroundColor Cyan

  } catch {
    Write-Host ""
    Write-Host "❌ CRITICAL ERROR DURING EXTREME PARALLEL CLEANUP: $_" -ForegroundColor Red
    Write-Host "💡 Try running the following manual commands:" -ForegroundColor Yellow
    Write-Host "   docker system prune --all --force --volumes" -ForegroundColor Cyan
    Write-Host "   docker container prune --force" -ForegroundColor Cyan
    Write-Host "   docker image prune --all --force" -ForegroundColor Cyan
    Write-Host "   docker volume prune --all --force" -ForegroundColor Cyan
    Write-Host "   docker network prune --force" -ForegroundColor Cyan
    Write-Host "   docker buildx prune --all --force" -ForegroundColor Cyan
    exit 1
  }
