#!/usr/bin/env pwsh
# Build-Utils.psm1 - Specialized build utilities for DevContainer PowerShell scripts
# Provides advanced Docker build operations with intelligent service detection and optimization

# Import required modules
Import-Module "$PSScriptRoot\Core-Utils.psm1" -Force
Import-Module "$PSScriptRoot\Docker-Utils.psm1" -Force
Import-Module "$PSScriptRoot\Performance-Utils.psm1" -Force

Set-StrictMode -Version Latest

# Build configuration and service mappings
$script:BuildConfig = @{
  ServiceMappings = @{
    'devcontainer' = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.devcontainer'
      Context      = '.devcontainer'
      BuildArgs    = @{
        BUILDKIT_INLINE_CACHE = '1'
        NODE_VERSION          = 'lts'
      }
      Dependencies = @('buildkit', 'node')
      Priority     = 1
      BuildTime    = 120  # seconds estimate
    }
    'buildkit'     = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.buildkit'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        BUILDKIT_INLINE_CACHE = '1'
      }
      Dependencies = @()
      Priority     = 3
      BuildTime    = 60
    }
    'redis'        = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.redis'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        BUILDKIT_INLINE_CACHE = '1'
      }
      Dependencies = @()
      Priority     = 3
      BuildTime    = 45
    }
    'postgres'     = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.postgres'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        BUILDKIT_INLINE_CACHE = '1'
      }
      Dependencies = @()
      Priority     = 3
      BuildTime    = 60
    }
    'registry'     = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.registry'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        BUILDKIT_INLINE_CACHE = '1'
      }
      Dependencies = @()
      Priority     = 2
      BuildTime    = 30
    }
    'node'         = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.node'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        BUILDKIT_INLINE_CACHE = '1'
      }
      Dependencies = @()
      Priority     = 3
      BuildTime    = 90
    }
  }
  BuildStrategies = @{
    'sequential' = 'Build services one at a time'
    'parallel'   = 'Build independent services in parallel'
    'optimized'  = 'Build using dependency-aware parallel batching'
    'aggressive' = 'Maximum parallelism with resource monitoring'
  }
  DefaultStrategy = 'optimized'
}

# Intelligent service detection from compose files
function Get-BuildableServices {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$ComposeFiles,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeOptional
  )

  Write-LogMessage -Message "🔍 Intelligently detecting buildable services..." -Level Performance

  $allServices = @()
  $serviceDefinitions = @{}

  foreach ($composeFile in $ComposeFiles) {
    if (-not (Test-Path $composeFile)) {
      Write-LogMessage -Message "Compose file not found: $composeFile" -Level Warning
      continue
    }

    try {
      # Parse compose file for services
      $composeContent = Get-Content $composeFile -Raw

      # Use docker-compose config to get parsed services
      $configResult = docker-compose -f $composeFile config --services 2>$null
      if ($LASTEXITCODE -eq 0 -and $configResult) {
        $services = $configResult | Where-Object { $_ -and $_.Trim() }
        $allServices += $services

        foreach ($service in $services) {
          $serviceDefinitions[$service] = @{
            HasBuild    = $true
            ComposeFile = $composeFile
          }
        }
      }
    } catch {
      Write-LogMessage -Message "Failed to parse compose file '$composeFile': $($_.Exception.Message)" -Level Warning
    }
  }

  # Filter out non-service items (volumes, networks, etc.)
  $validServices = $allServices | Where-Object {
    $service = $_
    $isValid = $service -notmatch '^(volumes?|networks?|configs?|secrets?)$' -and
    $service -notmatch '^\s*$' -and
    $serviceDefinitions[$service].HasBuild

    if (-not $isValid) {
      Write-LogMessage -Message "   ⏭️  Skipping non-buildable item: $service" -Level Debug
    }

    return $isValid
  }

  Write-LogMessage -Message "   ✅ Found $($validServices.Count) buildable services: $($validServices -join ', ')" -Level Success

  return @{
    Services    = $validServices
    Definitions = $serviceDefinitions
  }
}

# Advanced build orchestrator with dependency resolution
class BuildOrchestrator {
  [hashtable]$Services
  [hashtable]$ServiceDefinitions
  [string[]]$ComposeFiles
  [string]$Strategy
  [PerformanceMonitor]$Monitor
  [DockerPerformanceMonitor]$DockerMonitor
  [hashtable]$BuildResults

  BuildOrchestrator([hashtable]$Services, [hashtable]$ServiceDefinitions, [string[]]$ComposeFiles, [string]$Strategy) {
    $this.Services = $Services
    $this.ServiceDefinitions = $ServiceDefinitions
    $this.ComposeFiles = $ComposeFiles
    $this.Strategy = $Strategy
    $this.Monitor = [PerformanceMonitor]::new()
    $this.DockerMonitor = [DockerPerformanceMonitor]::new()
    $this.BuildResults = @{}
  }

  [array]GetBuildOrder() {
    $buildOrder = @()
    $processed = @()

    # Create dependency graph
    $dependencyGraph = @{}
    foreach ($service in $this.Services.Services) {
      $dependencies = if ($script:BuildConfig.ServiceMappings.ContainsKey($service)) {
        $script:BuildConfig.ServiceMappings[$service].Dependencies
      } else {
        @()
      }
      $dependencyGraph[$service] = $dependencies
    }

    # Topological sort with priority consideration
    function ResolveBuildOrder($serviceName, $graph, $processed, $order, $visiting = @()) {
      if ($serviceName -in $visiting) {
        throw "Circular dependency detected involving service: $serviceName"
      }

      if ($serviceName -in $processed) {
        return
      }

      $visiting += $serviceName

      foreach ($dependency in $graph[$serviceName]) {
        ResolveBuildOrder $dependency $graph $processed $order $visiting
      }

      $processed += $serviceName
      $order += $serviceName
    }

    # Sort services by priority first, then resolve dependencies
    $prioritizedServices = $this.Services.Services | Sort-Object {
      if ($script:BuildConfig.ServiceMappings.ContainsKey($_)) {
        $script:BuildConfig.ServiceMappings[$_].Priority
      } else {
        99
      }
    } -Descending

    foreach ($service in $prioritizedServices) {
      if ($service -notin $processed) {
        ResolveBuildOrder $service $dependencyGraph ([ref]$processed) ([ref]$buildOrder)
      }
    }

    return $buildOrder
  }

  [array]GetBuildBatches([int]$MaxConcurrency) {
    $buildOrder = $this.GetBuildOrder()
    $batches = @()

    switch ($this.Strategy) {
      'sequential' {
        foreach ($service in $buildOrder) {
          $batches += , @($service)
        }
      }
      'parallel' {
        $batches += , $buildOrder
      }
      'optimized' {
        # Group by dependency levels
        $dependencyLevels = @{}
        foreach ($service in $buildOrder) {
          $level = 0
          if ($script:BuildConfig.ServiceMappings.ContainsKey($service)) {
            $level = $script:BuildConfig.ServiceMappings[$service].Dependencies.Count
          }
          if (-not $dependencyLevels.ContainsKey($level)) {
            $dependencyLevels[$level] = @()
          }
          $dependencyLevels[$level] += $service
        }

        foreach ($level in ($dependencyLevels.Keys | Sort-Object)) {
          $batches += , $dependencyLevels[$level]
        }
      }
      'aggressive' {
        # Split into smaller batches for maximum concurrency
        for ($i = 0; $i -lt $buildOrder.Count; $i += $MaxConcurrency) {
          $end = [Math]::Min($i + $MaxConcurrency - 1, $buildOrder.Count - 1)
          $batches += , $buildOrder[$i..$end]
        }
      }
    }

    return $batches
  }

  [bool]BuildServices([hashtable]$BuildOptions = @{}) {
    Write-LogMessage -Message "🏗️  Starting build orchestration with strategy: $($this.Strategy)" -Level Performance

    $this.Monitor.StartTimer("total-build")

    # Get optimal concurrency settings
    $concurrencySettings = Get-OptimalConcurrencySettings -WorkloadType 'build'
    $maxConcurrency = if ($BuildOptions.MaxConcurrency) {
      [Math]::Min($BuildOptions.MaxConcurrency, $concurrencySettings.MaxConcurrency)
    } else {
      $concurrencySettings.MaxConcurrency
    }

    Write-LogMessage -Message "   ⚙️  Max Concurrency: $maxConcurrency, Throttle: $($concurrencySettings.ThrottleLimit)" -Level Info

    # Get build batches
    $batches = $this.GetBuildBatches($maxConcurrency)

    Write-LogMessage -Message "   📋 Build plan: $($batches.Count) batches" -Level Info
    for ($i = 0; $i -lt $batches.Count; $i++) {
      Write-LogMessage -Message "      Batch $($i + 1): $($batches[$i] -join ', ')" -Level Info
    }

    $totalBuildTime = 0
    $successfulBuilds = 0
    $failedBuilds = 0

    # Execute build batches
    for ($batchIndex = 0; $batchIndex -lt $batches.Count; $batchIndex++) {
      $batch = $batches[$batchIndex]
      $batchStart = Get-Date

      Write-LogMessage -Message "🔨 Building batch $($batchIndex + 1)/$($batches.Count): $($batch -join ', ')" -Level Info

      $batchResults = $this.BuildServiceBatch($batch, $BuildOptions)

      $batchEnd = Get-Date
      $batchDuration = ($batchEnd - $batchStart).TotalSeconds
      $totalBuildTime += $batchDuration

      foreach ($result in $batchResults) {
        if ($result.Success) {
          $successfulBuilds++
        } else {
          $failedBuilds++
        }
        $this.BuildResults[$result.ServiceName] = $result
      }

      Write-LogMessage -Message "   ✅ Batch $($batchIndex + 1) completed in $($batchDuration.ToString('F1'))s" -Level Success
    }

    $this.Monitor.StopTimer("total-build")

    # Final summary
    $totalDuration = $this.Monitor.GetDuration("total-build")
    Write-LogMessage -Message "🎉 BUILD ORCHESTRATION COMPLETED!" -Level Success
    Write-LogMessage -Message "   📊 Results: $successfulBuilds successful, $failedBuilds failed" -Level Info
    Write-LogMessage -Message "   ⏱️  Total time: $($totalDuration.TotalSeconds.ToString('F1'))s" -Level Info
    Write-LogMessage -Message "   ⚡ Strategy: $($this.Strategy) with max concurrency: $maxConcurrency" -Level Info

    # Show build performance summary
    $buildSummary = $this.DockerMonitor.GetBuildSummary()
    if ($buildSummary.TotalBuilds -gt 0) {
      Write-LogMessage -Message "   🏗️  Build Performance: avg $($buildSummary.AverageBuildTime.ToString('F1'))s/service" -Level Info
    }

    return $failedBuilds -eq 0
  }

  [array]BuildServiceBatch([array]$Services, [hashtable]$BuildOptions) {
    $results = @()

    if ($Services.Count -eq 1) {
      $result = $this.BuildSingleService($Services[0], $BuildOptions)
      $results += $result
    } else {
      # Build services in parallel within batch
      $parallelResults = $Services | ForEach-Object -Parallel {
        $serviceName = $_
        $buildOptions = $using:BuildOptions

        try {
          $startTime = Get-Date

          # Build the service
          $buildArgs = @('docker', 'build')
          if ($buildOptions.NoCache) { $buildArgs += '--no-cache' }
          if ($buildOptions.Pull) { $buildArgs += '--pull' }

          $buildCommand = $buildArgs -join ' '
          $buildResult = & $buildCommand 2>&1

          $endTime = Get-Date
          $duration = ($endTime - $startTime).TotalSeconds

          return @{
            ServiceName = $serviceName
            Success     = $LASTEXITCODE -eq 0
            Duration    = $duration
            Output      = $buildResult
            Error       = if ($LASTEXITCODE -ne 0) { $buildResult } else { $null }
          }
        } catch {
          return @{
            ServiceName = $serviceName
            Success     = $false
            Duration    = 0
            Output      = $null
            Error       = $_.Exception.Message
          }
        }
      } -ThrottleLimit $Services.Count

      $results += $parallelResults
    }

    return $results
  }

  [hashtable]BuildSingleService([string]$ServiceName, [hashtable]$BuildOptions) {
    $startTime = Get-Date

    try {
      Write-LogMessage -Message "🏗️  Building service: $ServiceName" -Level Info

      # Build logic here
      $buildArgs = @('docker', 'build')
      if ($BuildOptions.NoCache) { $buildArgs += '--no-cache' }
      if ($BuildOptions.Pull) { $buildArgs += '--pull' }

      $buildCommand = $buildArgs -join ' '
      $buildResult = & $buildCommand 2>&1

      $endTime = Get-Date
      $duration = ($endTime - $startTime).TotalSeconds

      $success = $LASTEXITCODE -eq 0

      $this.DockerMonitor.MonitorBuildPerformance($ServiceName, [timespan]::FromSeconds($duration), $success)

      return @{
        ServiceName = $ServiceName
        Success     = $success
        Duration    = $duration
        Output      = $buildResult
        Error       = if (-not $success) { $buildResult } else { $null }
      }
    } catch {
      $endTime = Get-Date
      $duration = ($endTime - $startTime).TotalSeconds

      return @{
        ServiceName = $ServiceName
        Success     = $false
        Duration    = $duration
        Output      = $null
        Error       = $_.Exception.Message
      }
    }
  }

  [hashtable]GetBuildSummary() {
    return @{
      Strategy         = $this.Strategy
      ServicesBuilt    = $this.BuildResults.Count
      SuccessfulBuilds = ($this.BuildResults.Values | Where-Object { $_.Success }).Count
      FailedBuilds     = ($this.BuildResults.Values | Where-Object { -not $_.Success }).Count
      TotalDuration    = $this.Monitor.GetDuration("total-build")
      Results          = $this.BuildResults
    }
  }
}

# Main build function
function Invoke-DevContainerBuild {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$ComposeFiles,

    [Parameter(Mandatory = $false)]
    [string[]]$Services = @(),

    [Parameter(Mandatory = $false)]
    [ValidateSet('sequential', 'parallel', 'optimized', 'aggressive')]
    [string]$Strategy = $script:BuildConfig.DefaultStrategy,

    [Parameter(Mandatory = $false)]
    [switch]$NoCache,

    [Parameter(Mandatory = $false)]
    [switch]$Pull,

    [Parameter(Mandatory = $false)]
    [switch]$ContinueOnError,

    [Parameter(Mandatory = $false)]
    [hashtable]$BuildArgs = @{},

    [Parameter(Mandatory = $false)]
    [int]$MaxConcurrency = 0,

    [Parameter(Mandatory = $false)]
    [switch]$OptimizeSystem,

    [Parameter(Mandatory = $false)]
    [switch]$ShowProgress
  )

  try {
    # Optimize system if requested
    if ($OptimizeSystem) {
      Write-LogMessage -Message "🚀 Optimizing system for build..." -Level Info
      $null = Optimize-SystemForDocker
    }

    # Validate compose files
    if (-not (Test-DockerComposeFiles -ComposeFiles $ComposeFiles)) {
      throw "Compose file validation failed"
    }

    # Get buildable services
    $serviceInfo = Get-BuildableServices -ComposeFiles $ComposeFiles
    if ($serviceInfo.Services.Count -eq 0) {
      throw "No buildable services found"
    }

    # Filter services if specific ones requested
    if ($Services.Count -gt 0) {
      $filteredServices = $serviceInfo.Services | Where-Object { $_ -in $Services }
      $serviceInfo.Services = $filteredServices
    }

    # Create build orchestrator
    $buildOptions = @{
      NoCache         = $NoCache.IsPresent
      Pull            = $Pull.IsPresent
      ContinueOnError = $ContinueOnError.IsPresent
      BuildArgs       = $BuildArgs
      MaxConcurrency  = $MaxConcurrency
      ShowProgress    = $ShowProgress.IsPresent
    }

    $orchestrator = [BuildOrchestrator]::new($serviceInfo, $serviceInfo.Definitions, $ComposeFiles, $Strategy)

    # Execute build
    $buildSuccess = $orchestrator.BuildServices($buildOptions)

    # Show final summary
    $summary = $orchestrator.GetBuildSummary()
    Write-LogMessage -Message "📋 Build Summary:" -Level Info
    Write-LogMessage -Message "   Strategy: $($summary.Strategy)" -Level Info
    Write-LogMessage -Message "   Services: $($summary.ServicesBuilt) total, $($summary.SuccessfulBuilds) successful, $($summary.FailedBuilds) failed" -Level Info
    Write-LogMessage -Message "   Duration: $($summary.TotalDuration.TotalSeconds.ToString('F1'))s" -Level Info

    return $buildSuccess

  } catch {
    Write-LogMessage -Message "❌ Build orchestration failed: $($_.Exception.Message)" -Level Error
    return $false
  }
}

# Export functions and classes
Export-ModuleMember -Function @(
  'Get-BuildableServices',
  'Invoke-DevContainerBuild'
) -Variable @('BuildConfig')
