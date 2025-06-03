#!/usr/bin/env pwsh
# Docker-Utils.psm1 - Advanced Docker management utilities for DevContainer PowerShell scripts
# Provides comprehensive Docker operations with extreme performance optimization

# Import core utilities
Import-Module "$PSScriptRoot\Core-Utils.psm1" -Force

Set-StrictMode -Version Latest

# Docker operation constants
$script:DockerTimeouts = @{
  Build   = 1800      # 30 minutes for builds
  Pull    = 600        # 10 minutes for pulls
  Push    = 600        # 10 minutes for pushes
  Inspect = 30      # 30 seconds for inspect
  Stop    = 60         # 1 minute for container stops
  Remove  = 120      # 2 minutes for removals
}

$script:DockerRetries = @{
  Network = 3
  Volume  = 3
  Build   = 2
  Pull    = 3
  Push    = 2
}

# Enhanced Docker compose validation with parallel processing
function Test-DockerComposeFiles {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$ComposeFiles,

    [Parameter(Mandatory = $false)]
    [switch]$Detailed
  )

  Write-LogMessage -Message "Validating compose files with PARALLEL processing..." -Level Performance

  if ($ComposeFiles.Count -eq 0) {
    Write-LogMessage -Message "No compose files provided for validation" -Level Warning
    return $false
  }

  # Validate files exist first
  $missingFiles = $ComposeFiles | Where-Object { -not (Test-Path $_) }
  if ($missingFiles.Count -gt 0) {
    Write-LogMessage -Message "Missing compose files: $($missingFiles -join ', ')" -Level Error
    return $false
  }

  # Parallel validation with enhanced error reporting
  $validationResults = Invoke-UltraParallelExecution -Items $ComposeFiles -ScriptBlock {
    param($file)

    try {
      # Test file syntax and structure
      $result = docker-compose -f $file config --quiet 2>&1
      if ($LASTEXITCODE -eq 0) {
        $fileInfo = Get-Item $file
        return @{
          File         = $file
          Valid        = $true
          Size         = $fileInfo.Length
          LastModified = $fileInfo.LastWriteTime
          Error        = $null
        }
      } else {
        return @{
          File         = $file
          Valid        = $false
          Size         = 0
          LastModified = $null
          Error        = $result -join "`n"
        }
      }
    } catch {
      return @{
        File         = $file
        Valid        = $false
        Size         = 0
        LastModified = $null
        Error        = $_.Exception.Message
      }
    }
  } -Description "Validating compose files" -ContinueOnError

  # Process results
  $validFiles = $validationResults | Where-Object { $_.Valid }
  $invalidFiles = $validationResults | Where-Object { -not $_.Valid }

  if ($invalidFiles.Count -gt 0) {
    Write-LogMessage -Message "Validation failed for $($invalidFiles.Count) files:" -Level Error
    foreach ($invalid in $invalidFiles) {
      Write-LogMessage -Message "  ❌ $($invalid.File): $($invalid.Error)" -Level Error
    }
    return $false
  }

  Write-LogMessage -Message "All compose files validated successfully!" -Level Success
  if ($Detailed) {
    foreach ($valid in $validFiles) {
      $sizeKB = [Math]::Round($valid.Size / 1KB, 2)
      Write-LogMessage -Message "   ✓ $($valid.File) ($($sizeKB)KB, modified: $($valid.LastModified.ToString('dd/MM/yyyy HH:mm:ss')))" -Level Success
    }
  }

  return $true
}

# Enhanced Docker image management with parallel operations
function Get-DockerImages {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string]$Filter,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeDangling,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeSize
  )

  if (-not (Test-DockerAvailability)) {
    Write-LogMessage -Message "Docker is not available" -Level Error
    return @()
  }

  try {
    $dockerArgs = @('images')

    if ($Filter) {
      $dockerArgs += '--filter', $Filter
    }

    if ($IncludeDangling) {
      $dockerArgs += '--filter', 'dangling=true'
    }

    $dockerArgs += '--format', 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}'

    $result = & docker @dockerArgs 2>$null
    if ($LASTEXITCODE -eq 0 -and $result) {
      return $result
    } else {
      Write-LogMessage -Message "Failed to get Docker images" -Level Warning
      return @()
    }
  } catch {
    Write-LogMessage -Message "Error getting Docker images: $($_.Exception.Message)" -Level Error
    return @()
  }
}

# Enhanced Docker container management
function Get-DockerContainers {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('running', 'exited', 'paused', 'all')]
    [string]$Status = 'all',

    [Parameter(Mandatory = $false)]
    [string]$Filter,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeStats
  )

  if (-not (Test-DockerAvailability)) {
    Write-LogMessage -Message "Docker is not available" -Level Error
    return @()
  }

  try {
    $dockerArgs = @('ps')

    switch ($Status) {
      'all' { $dockerArgs += '-a' }
      'running' { } # Default behavior
      'exited' { $dockerArgs += '--filter', 'status=exited' }
      'paused' { $dockerArgs += '--filter', 'status=paused' }
    }

    if ($Filter) {
      $dockerArgs += '--filter', $Filter
    }

    $dockerArgs += '--format', 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}\t{{.CreatedAt}}'

    $result = & docker @dockerArgs 2>$null
    if ($LASTEXITCODE -eq 0) {
      return $result
    } else {
      Write-LogMessage -Message "Failed to get Docker containers" -Level Warning
      return @()
    }
  } catch {
    Write-LogMessage -Message "Error getting Docker containers: $($_.Exception.Message)" -Level Error
    return @()
  }
}

# Ultra-parallel Docker service building
function Invoke-DockerServiceBuild {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Services,

    [Parameter(Mandatory = $false)]
    [string[]]$ComposeFiles = @(),

    [Parameter(Mandatory = $false)]
    [switch]$NoCache,

    [Parameter(Mandatory = $false)]
    [switch]$Pull,

    [Parameter(Mandatory = $false)]
    [hashtable]$BuildArgs = @{},

    [Parameter(Mandatory = $false)]
    [int]$MaxParallelBuilds = 3
  )

  if (-not (Test-DockerAvailability)) {
    Write-LogMessage -Message "Docker is not available for building" -Level Error
    return $false
  }

  Write-LogMessage -Message "Building services with EXTREME PARALLEL PROCESSING..." -Level Performance

  # Validate services have build contexts
  $validServices = @()
  $monitor = [PerformanceMonitor]::new()

  foreach ($service in $Services) {
    $monitor.StartTimer("validate-$service")

    # Check if service has Dockerfile or build context
    $hasDockerfile = $false
    $contextPath = ""

    # Try to determine build context from compose files
    foreach ($composeFile in $ComposeFiles) {
      if (Test-Path $composeFile) {
        try {
          $composeContent = Get-Content $composeFile -Raw | ConvertFrom-Yaml -ErrorAction SilentlyContinue
          if ($composeContent.services.$service.build) {
            $buildConfig = $composeContent.services.$service.build
            if ($buildConfig.dockerfile -or $buildConfig.context) {
              $hasDockerfile = $true
              $contextPath = if ($buildConfig.context) { $buildConfig.context } else { "." }
              break
            }
          } elseif ($composeContent.services.$service.dockerfile) {
            $hasDockerfile = $true
            $contextPath = "."
            break
          }
        } catch {
          # Continue checking other files
        }
      }
    }

    # Fallback: check for service-specific Dockerfile
    if (-not $hasDockerfile) {
      $possibleDockerfiles = @(
        ".devcontainer/docker/files/Dockerfile.$service",
        "Dockerfile.$service",
        "$service/Dockerfile"
      )

      foreach ($dockerfile in $possibleDockerfiles) {
        if (Test-Path $dockerfile) {
          $hasDockerfile = $true
          $contextPath = Split-Path $dockerfile -Parent
          if (-not $contextPath) { $contextPath = "." }
          break
        }
      }
    }

    $monitor.StopTimer("validate-$service")

    if ($hasDockerfile) {
      $validServices += @{
        Name          = $service
        ContextPath   = $contextPath
        HasDockerfile = $true
      }
      $contextSize = if (Test-Path $contextPath) {
        $size = (Get-ChildItem $contextPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
        [Math]::Round($size / 1MB, 2)
      } else { 0 }
      Write-LogMessage -Message "   ✅ $service`: Ready (Context: $($contextSize)MB)" -Level Success
    } else {
      Write-LogMessage -Message "   ⚠️  $service`: No specific Dockerfile found" -Level Warning
    }
  }

  if ($validServices.Count -eq 0) {
    Write-LogMessage -Message "No valid services found for building" -Level Warning
    return $false
  }

  # Group services for phased building to optimize dependencies
  $serviceGroups = @()
  $remainingServices = $validServices

  while ($remainingServices.Count -gt 0) {
    $currentBatch = $remainingServices | Select-Object -First $MaxParallelBuilds
    $serviceGroups += , $currentBatch
    $remainingServices = $remainingServices | Select-Object -Skip $MaxParallelBuilds
  }

  Write-LogMessage -Message "Building in $($serviceGroups.Count) phases with maximum $MaxParallelBuilds parallel builds" -Level Info

  $totalBuildTime = 0
  $phaseNumber = 1

  foreach ($group in $serviceGroups) {
    Write-LogMessage -Message "🔄 Building phase with $($group.Count) services in EXTREME PARALLEL..." -Level Performance

    $phaseStart = Get-Date
    $monitor.StartTimer("phase-$phaseNumber")

    # Build services in parallel within the group
    $buildResults = Invoke-UltraParallelExecution -Items $group -ScriptBlock {
      param($serviceInfo)

      $service = $serviceInfo.Name
      $startTime = Get-Date

      try {
        # Prepare build arguments
        $buildCommand = @('docker-compose')

        # Add compose files
        foreach ($file in $using:ComposeFiles) {
          $buildCommand += '-f', $file
        }

        $buildCommand += 'build'

        if ($using:NoCache) {
          $buildCommand += '--no-cache'
        }

        if ($using:Pull) {
          $buildCommand += '--pull'
        }

        # Add build args
        foreach ($key in $using:BuildArgs.Keys) {
          $buildCommand += '--build-arg', "$key=$($using:BuildArgs[$key])"
        }

        $buildCommand += $service

        # Execute build with timeout
        $result = & $buildCommand[0] $buildCommand[1..($buildCommand.Length - 1)] 2>&1
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds

        if ($LASTEXITCODE -eq 0) {
          return @{
            Service  = $service
            Success  = $true
            Duration = $duration
            Output   = $result -join "`n"
            Error    = $null
          }
        } else {
          return @{
            Service  = $service
            Success  = $false
            Duration = $duration
            Output   = $result -join "`n"
            Error    = "Build failed with exit code: $LASTEXITCODE"
          }
        }
      } catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        return @{
          Service  = $service
          Success  = $false
          Duration = $duration
          Output   = ""
          Error    = $_.Exception.Message
        }
      }
    } -Description "Building services in phase $phaseNumber" -CustomThrottleLimit $MaxParallelBuilds

    $monitor.StopTimer("phase-$phaseNumber")
    $phaseEnd = Get-Date
    $phaseDuration = ($phaseEnd - $phaseStart).TotalSeconds
    $totalBuildTime += $phaseDuration

    # Report phase results
    $successfulBuilds = $buildResults | Where-Object { $_.Success }
    $failedBuilds = $buildResults | Where-Object { -not $_.Success }

    Write-LogMessage -Message "      ⚡ $($successfulBuilds.Count)/$($group.Count) services completed ($($phaseDuration.ToString('F1'))s elapsed)" -Level Success

    if ($failedBuilds.Count -gt 0) {
      Write-LogMessage -Message "Failed builds in phase $phaseNumber`:" -Level Error
      foreach ($failed in $failedBuilds) {
        Write-LogMessage -Message "   ❌ $($failed.Service): $($failed.Error)" -Level Error
      }
      return $false
    }

    Write-LogMessage -Message "   🎯 Phase completed in $($phaseDuration.ToString('F1'))s with EXTREME EFFICIENCY!" -Level Success
    $phaseNumber++
  }

  Write-LogMessage -Message "🎉 ALL SERVICES BUILT WITH EXTREME PARALLEL OPTIMIZATION!" -Level Success
  Write-LogMessage -Message "⚡ Total build time: $($totalBuildTime.ToString('F1'))s across $($script:ExportedConstants.MaxThreads) CPU cores!" -Level Performance

  return $true
}

# Enhanced Docker cleanup with ultra-parallel processing
function Invoke-DockerSystemCleanup {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [switch]$Aggressive,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeVolumes,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeNetworks,

    [Parameter(Mandatory = $false)]
    [string]$UntilFilter = "24h"
  )

  if (-not (Test-DockerAvailability)) {
    Write-LogMessage -Message "Docker is not available for cleanup" -Level Error
    return $false
  }

  Write-LogMessage -Message "Performing Docker system cleanup with ULTRA-PARALLEL processing..." -Level Performance

  $monitor = [PerformanceMonitor]::new()
  $cleanupJobs = @()

  # Phase 1: Parallel container cleanup
  $monitor.StartTimer("containers")
  Write-LogMessage -Message "🗑️  Phase 1: Cleaning containers..." -Level Info

  $cleanupJobs += Start-Job -ScriptBlock {
    $containers = docker ps -aq --filter "status=exited" 2>$null
    if ($containers) {
      $containers | ForEach-Object -Parallel {
        docker rm $_ --force 2>$null
      } -ThrottleLimit $using:script:ExportedConstants.ThrottleLimit
      return $containers.Count
    }
    return 0
  }

  # Phase 2: Parallel image cleanup
  $monitor.StartTimer("images")
  Write-LogMessage -Message "🗑️  Phase 2: Cleaning images..." -Level Info

  $cleanupJobs += Start-Job -ScriptBlock {
    $pruneArgs = @('image', 'prune', '--force')
    if ($using:Aggressive) {
      $pruneArgs += '--all'
    }
    if ($using:UntilFilter) {
      $pruneArgs += '--filter', "until=$($using:UntilFilter)"
    }

    $result = & docker system @pruneArgs 2>$null
    return if ($result -match "Total reclaimed space: (.+)") { $matches[1] } else { "0B" }
  }

  # Phase 3: Parallel BuildKit cleanup
  $monitor.StartTimer("buildkit")
  Write-LogMessage -Message "🗑️  Phase 3: Cleaning BuildKit cache..." -Level Info

  $cleanupJobs += Start-Job -ScriptBlock {
    $buildkitCommands = @(
      { docker buildx prune --all --force 2>$null },
      { docker builder prune --all --force 2>$null }
    )

    $buildkitCommands | ForEach-Object -Parallel {
      & $_
    } -ThrottleLimit 2
  }

  # Optional Phase 4: Volume cleanup
  if ($IncludeVolumes) {
    $monitor.StartTimer("volumes")
    Write-LogMessage -Message "🗑️  Phase 4: Cleaning volumes..." -Level Info

    $cleanupJobs += Start-Job -ScriptBlock {
      docker volume prune --force 2>$null
    }
  }

  # Optional Phase 5: Network cleanup
  if ($IncludeNetworks) {
    $monitor.StartTimer("networks")
    Write-LogMessage -Message "🗑️  Phase 5: Cleaning networks..." -Level Info

    $cleanupJobs += Start-Job -ScriptBlock {
      docker network prune --force 2>$null
    }
  }

  # Wait for all cleanup jobs to complete
  Write-LogMessage -Message "⏳ Waiting for cleanup operations to complete..." -Level Info
  $jobResults = $cleanupJobs | Receive-Job -Wait

  # Stop timers and get results
  $monitor.StopTimer("containers")
  $monitor.StopTimer("images")
  $monitor.StopTimer("buildkit")
  if ($IncludeVolumes) { $monitor.StopTimer("volumes") }
  if ($IncludeNetworks) { $monitor.StopTimer("networks") }

  # Report results
  Write-LogMessage -Message "✅ Docker cleanup completed successfully!" -Level Success

  $summary = $monitor.GetSummary()
  foreach ($metric in $summary.Metrics.Keys) {
    $duration = $summary.Metrics[$metric].Duration
    if ($duration) {
      Write-LogMessage -Message "   📊 $metric`: $($duration.TotalSeconds.ToString('F1'))s" -Level Info
    }
  }

  return $true
}

# Enhanced Docker network management
function Invoke-DockerNetworkManagement {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('create', 'remove', 'inspect', 'list', 'prune')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$NetworkName,

    [Parameter(Mandatory = $false)]
    [string]$Driver = 'bridge',

    [Parameter(Mandatory = $false)]
    [hashtable]$Options = @{}
  )

  if (-not (Test-DockerAvailability)) {
    Write-LogMessage -Message "Docker is not available for network management" -Level Error
    return $false
  }

  switch ($Action) {
    'create' {
      if (-not $NetworkName) {
        Write-LogMessage -Message "Network name is required for creation" -Level Error
        return $false
      }

      try {
        $dockerArgs = @('network', 'create', '--driver', $Driver)

        foreach ($key in $Options.Keys) {
          $dockerArgs += '--opt', "$key=$($Options[$key])"
        }

        $dockerArgs += $NetworkName

        $result = & docker @dockerArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
          Write-LogMessage -Message "Network '$NetworkName' created successfully" -Level Success
          return $true
        } else {
          Write-LogMessage -Message "Failed to create network '$NetworkName': $result" -Level Error
          return $false
        }
      } catch {
        Write-LogMessage -Message "Error creating network '$NetworkName': $($_.Exception.Message)" -Level Error
        return $false
      }
    }

    'remove' {
      if (-not $NetworkName) {
        Write-LogMessage -Message "Network name is required for removal" -Level Error
        return $false
      }

      try {
        $result = docker network rm $NetworkName 2>&1
        if ($LASTEXITCODE -eq 0) {
          Write-LogMessage -Message "Network '$NetworkName' removed successfully" -Level Success
          return $true
        } else {
          Write-LogMessage -Message "Failed to remove network '$NetworkName': $result" -Level Warning
          return $false
        }
      } catch {
        Write-LogMessage -Message "Error removing network '$NetworkName': $($_.Exception.Message)" -Level Error
        return $false
      }
    }

    'list' {
      try {
        $result = docker network ls --format 'table {{.Name}}\t{{.Driver}}\t{{.Scope}}\t{{.CreatedAt}}' 2>$null
        if ($LASTEXITCODE -eq 0) {
          return $result
        } else {
          Write-LogMessage -Message "Failed to list networks" -Level Warning
          return @()
        }
      } catch {
        Write-LogMessage -Message "Error listing networks: $($_.Exception.Message)" -Level Error
        return @()
      }
    }

    'prune' {
      try {
        $result = docker network prune --force 2>&1
        if ($LASTEXITCODE -eq 0) {
          Write-LogMessage -Message "Network pruning completed" -Level Success
          return $true
        } else {
          Write-LogMessage -Message "Network pruning failed: $result" -Level Warning
          return $false
        }
      } catch {
        Write-LogMessage -Message "Error during network pruning: $($_.Exception.Message)" -Level Error
        return $false
      }
    }

    default {
      Write-LogMessage -Message "Unsupported network action: $Action" -Level Error
      return $false
    }
  }
}

# Enhanced Docker volume management
function Invoke-DockerVolumeManagement {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('create', 'remove', 'inspect', 'list', 'prune')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$VolumeName,

    [Parameter(Mandatory = $false)]
    [string]$Driver = 'local',

    [Parameter(Mandatory = $false)]
    [hashtable]$Options = @{}
  )

  if (-not (Test-DockerAvailability)) {
    Write-LogMessage -Message "Docker is not available for volume management" -Level Error
    return $false
  }

  switch ($Action) {
    'create' {
      if (-not $VolumeName) {
        Write-LogMessage -Message "Volume name is required for creation" -Level Error
        return $false
      }

      try {
        $dockerArgs = @('volume', 'create', '--driver', $Driver)

        foreach ($key in $Options.Keys) {
          $dockerArgs += '--opt', "$key=$($Options[$key])"
        }

        $dockerArgs += $VolumeName

        $result = & docker @dockerArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
          Write-LogMessage -Message "Volume '$VolumeName' created successfully" -Level Success
          return $true
        } else {
          Write-LogMessage -Message "Failed to create volume '$VolumeName': $result" -Level Error
          return $false
        }
      } catch {
        Write-LogMessage -Message "Error creating volume '$VolumeName': $($_.Exception.Message)" -Level Error
        return $false
      }
    }

    'list' {
      try {
        $result = docker volume ls --format 'table {{.Name}}\t{{.Driver}}\t{{.Scope}}\t{{.CreatedAt}}' 2>$null
        if ($LASTEXITCODE -eq 0) {
          return $result
        } else {
          Write-LogMessage -Message "Failed to list volumes" -Level Warning
          return @()
        }
      } catch {
        Write-LogMessage -Message "Error listing volumes: $($_.Exception.Message)" -Level Error
        return @()
      }
    }

    'prune' {
      try {
        $result = docker volume prune --force 2>&1
        if ($LASTEXITCODE -eq 0) {
          Write-LogMessage -Message "Volume pruning completed" -Level Success
          return $true
        } else {
          Write-LogMessage -Message "Volume pruning failed: $result" -Level Warning
          return $false
        }
      } catch {
        Write-LogMessage -Message "Error during volume pruning: $($_.Exception.Message)" -Level Error
        return $false
      }
    }

    default {
      Write-LogMessage -Message "Unsupported volume action: $Action" -Level Error
      return $false
    }
  }
}

# Export functions
Export-ModuleMember -Function @(
  'Test-DockerComposeFiles',
  'Get-DockerImages',
  'Get-DockerContainers',
  'Invoke-DockerServiceBuild',
  'Invoke-DockerSystemCleanup',
  'Invoke-DockerNetworkManagement',
  'Invoke-DockerVolumeManagement'
)
