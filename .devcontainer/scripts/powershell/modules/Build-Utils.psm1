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
        'NODE_VERSION'     = '20'
        'BUILDKIT_VERSION' = 'latest'
      }
      Dependencies = @('buildkit', 'node')
      Priority     = 1
      BuildTime    = 120  # seconds estimate
    }
    'buildkit'     = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.buildkit'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        'BUILDKIT_VERSION' = 'latest'
      }
      Dependencies = @()
      Priority     = 3
      BuildTime    = 60
    }
    'redis'        = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.redis'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        'REDIS_VERSION' = '7-alpine'
      }
      Dependencies = @()
      Priority     = 3
      BuildTime    = 45
    }
    'postgres'     = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.postgres'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        'POSTGRES_VERSION' = '16-alpine'
      }
      Dependencies = @()
      Priority     = 3
      BuildTime    = 60
    }
    'registry'     = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.registry'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        'REGISTRY_VERSION' = '2'
      }
      Dependencies = @()
      Priority     = 2
      BuildTime    = 30
    }
    'node'         = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.node'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        'NODE_VERSION' = '20-alpine'
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

        foreach ($service in $services) {
          if ($service -notin $allServices) {
            # Check if service has build configuration
            $serviceConfig = docker-compose -f $composeFile config --format json 2>$null | ConvertFrom-Json

            if ($serviceConfig.services.$service.build -or $serviceConfig.services.$service.dockerfile) {
              $buildInfo = $serviceConfig.services.$service.build
              $dockerfile = $serviceConfig.services.$service.dockerfile

              $serviceDefinitions[$service] = @{
                ComposeFile  = $composeFile
                HasBuild     = $true
                BuildContext = if ($buildInfo.context) { $buildInfo.context } else { "." }
                Dockerfile   = if ($buildInfo.dockerfile) { $buildInfo.dockerfile } elseif ($dockerfile) { $dockerfile } else { "Dockerfile" }
                BuildArgs    = if ($buildInfo.args) { $buildInfo.args } else { @{} }
                Target       = if ($buildInfo.target) { $buildInfo.target } else { $null }
              }

              $allServices += $service
            } elseif ($script:BuildConfig.ServiceMappings.ContainsKey($service)) {
              # Service has predefined build configuration
              $mappingConfig = $script:BuildConfig.ServiceMappings[$service]
              $serviceDefinitions[$service] = @{
                ComposeFile  = $composeFile
                HasBuild     = $true
                BuildContext = $mappingConfig.Context
                Dockerfile   = $mappingConfig.Dockerfile
                BuildArgs    = $mappingConfig.BuildArgs
                Target       = $null
                IsMapped     = $true
              }

              $allServices += $service
            } elseif ($IncludeOptional) {
              # Include non-build services if requested
              $serviceDefinitions[$service] = @{
                ComposeFile = $composeFile
                HasBuild    = $false
                Image       = $serviceConfig.services.$service.image
              }

              $allServices += $service
            }
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
        @()  # No dependencies for services not in mapping
      }
      $dependencyGraph[$service] = $dependencies
    }

    # Topological sort with priority consideration
    function ResolveBuildOrder($serviceName, $graph, $processed, $order, $visiting = @()) {
      if ($serviceName -in $visiting) {
        Write-LogMessage -Message "⚠️  Circular dependency detected involving: $($visiting -join ' → ') → $serviceName" -Level Warning
        return
      }

      if ($serviceName -in $processed) {
        return
      }

      $visiting += $serviceName

      if ($graph.ContainsKey($serviceName)) {
        $dependencies = $graph[$serviceName]
        foreach ($dep in $dependencies) {
          if ($dep -in $this.Services.Services) {
            ResolveBuildOrder $dep $graph $processed $order $visiting
          }
        }
      }

      $order.Add($serviceName)
      $processed += $serviceName
      $visiting = $visiting | Where-Object { $_ -ne $serviceName }
    }

    # Sort services by priority first, then resolve dependencies
    $prioritizedServices = $this.Services.Services | Sort-Object {
      if ($script:BuildConfig.ServiceMappings.ContainsKey($_)) {
        $script:BuildConfig.ServiceMappings[$_].Priority
      } else {
        2  # Default priority
      }
    } -Descending

    foreach ($service in $prioritizedServices) {
      ResolveBuildOrder $service $dependencyGraph $processed $buildOrder
    }

    return $buildOrder
  }

  [array]GetBuildBatches([int]$MaxConcurrency) {
    $buildOrder = $this.GetBuildOrder()
    $batches = @()

    switch ($this.Strategy) {
      'sequential' {
        # One service per batch
        foreach ($service in $buildOrder) {
          $batches += , @($service)
        }
      }
      'parallel' {
        # Simple batching without dependency consideration
        for ($i = 0; $i -lt $buildOrder.Count; $i += $MaxConcurrency) {
          $end = [Math]::Min($i + $MaxConcurrency - 1, $buildOrder.Count - 1)
          $batches += , @($buildOrder[$i..$end])
        }
      }
      'optimized' -or 'aggressive' {
        # Dependency-aware batching
        $remaining = $buildOrder.Clone()
        $currentBatch = @()

        while ($remaining.Count -gt 0) {
          $canBuild = @()

          foreach ($service in $remaining) {
            $dependencies = if ($script:BuildConfig.ServiceMappings.ContainsKey($service)) {
              $script:BuildConfig.ServiceMappings[$service].Dependencies
            } else {
              @()
            }

            $dependenciesMet = $true
            foreach ($dep in $dependencies) {
              if ($dep -in $remaining) {
                $dependenciesMet = $false
                break
              }
            }

            if ($dependenciesMet) {
              $canBuild += $service
            }
          }

          if ($canBuild.Count -eq 0) {
            # Force include next service to break deadlock
            $canBuild += $remaining[0]
            Write-LogMessage -Message "⚠️  Breaking potential deadlock by force-including: $($remaining[0])" -Level Warning
          }

          # Limit batch size
          $batchSize = [Math]::Min($MaxConcurrency, $canBuild.Count)
          $currentBatch = $canBuild | Select-Object -First $batchSize
          $batches += , $currentBatch

          # Remove built services from remaining
          $remaining = $remaining | Where-Object { $_ -notin $currentBatch }
        }
      }
      default {
        # Fallback to optimized
        return $this.GetBuildBatches($MaxConcurrency)
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
      $batch = $batches[$i]
      Write-LogMessage -Message "      Batch $($i + 1): $($batch -join ', ')" -Level Debug
    }

    $totalBuildTime = 0
    $successfulBuilds = 0
    $failedBuilds = 0

    # Execute build batches
    for ($batchIndex = 0; $batchIndex -lt $batches.Count; $batchIndex++) {
      $batch = $batches[$batchIndex]
      $batchNumber = $batchIndex + 1

      Write-LogMessage -Message "🔄 Building batch $batchNumber/$($batches.Count): $($batch -join ', ')" -Level Performance

      $batchStartTime = Get-Date
      $this.Monitor.StartTimer("batch-$batchNumber")

      # Build services in batch
      $batchResults = $this.BuildServiceBatch($batch, $BuildOptions)

      $this.Monitor.StopTimer("batch-$batchNumber")
      $batchEndTime = Get-Date
      $batchDuration = ($batchEndTime - $batchStartTime).TotalSeconds
      $totalBuildTime += $batchDuration

      # Process batch results
      $batchSuccesses = $batchResults | Where-Object { $_.Success }
      $batchFailures = $batchResults | Where-Object { -not $_.Success }

      $successfulBuilds += $batchSuccesses.Count
      $failedBuilds += $batchFailures.Count

      Write-LogMessage -Message "   ⚡ Batch $batchNumber completed: $($batchSuccesses.Count)/$($batch.Count) successful ($($batchDuration.ToString('F1'))s)" -Level Success

      if ($batchFailures.Count -gt 0) {
        Write-LogMessage -Message "   ❌ Failed builds in batch $batchNumber`:" -Level Error
        foreach ($failure in $batchFailures) {
          Write-LogMessage -Message "      $($failure.Service): $($failure.Error)" -Level Error
        }

        if (-not $BuildOptions.ContinueOnError) {
          Write-LogMessage -Message "❌ Build stopped due to failures (ContinueOnError not set)" -Level Error
          return $false
        }
      }

      # Add results to build results
      foreach ($result in $batchResults) {
        $this.BuildResults[$result.Service] = $result
        $this.DockerMonitor.MonitorBuildPerformance($result.Service, $result.Duration, $result.Success)
      }
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
      Write-LogMessage -Message "   📈 Performance: $($buildSummary.SuccessRate.ToString('F1'))% success rate, avg $($buildSummary.AverageTimeSeconds.ToString('F1'))s per build" -Level Performance
    }

    return $failedBuilds -eq 0
  }

  [array]BuildServiceBatch([array]$Services, [hashtable]$BuildOptions) {
    $results = @()

    if ($Services.Count -eq 1) {
      # Single service - build directly
      $result = $this.BuildSingleService($Services[0], $BuildOptions)
      $results += $result
    } else {
      # Multiple services - build in parallel
      $results = Invoke-UltraParallelExecution -Items $Services -ScriptBlock {
        param($service)
        return $using:this.BuildSingleService($service, $using:BuildOptions)
      } -Description "Building services in parallel" -CustomThrottleLimit $Services.Count -ContinueOnError:$BuildOptions.ContinueOnError
    }

    return $results
  }

  [hashtable]BuildSingleService([string]$ServiceName, [hashtable]$BuildOptions) {
    $startTime = Get-Date

    try {
      Write-LogMessage -Message "   🔨 Building service: $ServiceName" -Level Info

      # Get service definition
      $serviceDefinition = $this.ServiceDefinitions[$ServiceName]
      if (-not $serviceDefinition) {
        throw "Service definition not found for: $ServiceName"
      }

      # Prepare build command
      $buildCommand = @('docker-compose')

      # Add compose files
      foreach ($file in $this.ComposeFiles) {
        $buildCommand += '-f', $file
      }

      $buildCommand += 'build'

      # Add build options
      if ($BuildOptions.NoCache) {
        $buildCommand += '--no-cache'
      }

      if ($BuildOptions.Pull) {
        $buildCommand += '--pull'
      }

      if ($BuildOptions.Parallel -and $BuildOptions.Parallel -gt 1) {
        $buildCommand += '--parallel'
      }

      # Add build args from definition and options
      $allBuildArgs = @{}
      if ($serviceDefinition.BuildArgs) {
        foreach ($key in $serviceDefinition.BuildArgs.Keys) {
          $allBuildArgs[$key] = $serviceDefinition.BuildArgs[$key]
        }
      }
      if ($BuildOptions.BuildArgs) {
        foreach ($key in $BuildOptions.BuildArgs.Keys) {
          $allBuildArgs[$key] = $BuildOptions.BuildArgs[$key]
        }
      }

      foreach ($key in $allBuildArgs.Keys) {
        $buildCommand += '--build-arg', "$key=$($allBuildArgs[$key])"
      }

      $buildCommand += $ServiceName

      Write-LogMessage -Message "      🚀 Executing: $($buildCommand -join ' ')" -Level Debug

      # Execute build with timeout
      $buildOutput = & $buildCommand[0] $buildCommand[1..($buildCommand.Length - 1)] 2>&1
      $endTime = Get-Date
      $duration = $endTime - $startTime

      if ($LASTEXITCODE -eq 0) {
        Write-LogMessage -Message "      ✅ $ServiceName built successfully ($($duration.TotalSeconds.ToString('F1'))s)" -Level Success
        return @{
          Service   = $ServiceName
          Success   = $true
          Duration  = $duration
          Output    = $buildOutput -join "`n"
          Error     = $null
          StartTime = $startTime
          EndTime   = $endTime
        }
      } else {
        $errorMsg = "Build failed with exit code: $LASTEXITCODE"
        Write-LogMessage -Message "      ❌ $ServiceName build failed: $errorMsg" -Level Error
        return @{
          Service   = $ServiceName
          Success   = $false
          Duration  = $duration
          Output    = $buildOutput -join "`n"
          Error     = $errorMsg
          StartTime = $startTime
          EndTime   = $endTime
        }
      }

    } catch {
      $endTime = Get-Date
      $duration = $endTime - $startTime
      $errorMsg = $_.Exception.Message
      Write-LogMessage -Message "      ❌ $ServiceName build error: $errorMsg" -Level Error
      return @{
        Service   = $ServiceName
        Success   = $false
        Duration  = $duration
        Output    = ""
        Error     = $errorMsg
        StartTime = $startTime
        EndTime   = $endTime
      }
    }
  }

  [hashtable]GetBuildSummary() {
    return @{
      Strategy           = $this.Strategy
      ServicesBuilt      = $this.BuildResults.Count
      SuccessfulBuilds   = ($this.BuildResults.Values | Where-Object { $_.Success }).Count
      FailedBuilds       = ($this.BuildResults.Values | Where-Object { -not $_.Success }).Count
      TotalDuration      = $this.Monitor.GetDuration("total-build")
      BuildResults       = $this.BuildResults
      DockerMetrics      = $this.DockerMonitor.GetBuildSummary()
      PerformanceMetrics = $this.Monitor.GetSummary()
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
      Optimize-SystemForDocker -AggressiveOptimization:($Strategy -eq 'aggressive')
    }

    # Validate compose files
    if (-not (Test-DockerComposeFiles -ComposeFiles $ComposeFiles)) {
      Write-LogMessage -Message "❌ Compose file validation failed" -Level Error
      return $false
    }

    # Get buildable services
    $serviceInfo = Get-BuildableServices -ComposeFiles $ComposeFiles
    if ($serviceInfo.Services.Count -eq 0) {
      Write-LogMessage -Message "⚠️  No buildable services found in compose files" -Level Warning
      return $true
    }

    # Filter services if specific ones requested
    if ($Services.Count -gt 0) {
      $requestedServices = $Services | Where-Object { $_ -in $serviceInfo.Services }
      $invalidServices = $Services | Where-Object { $_ -notin $serviceInfo.Services }

      if ($invalidServices.Count -gt 0) {
        Write-LogMessage -Message "⚠️  Invalid services requested: $($invalidServices -join ', ')" -Level Warning
      }

      if ($requestedServices.Count -eq 0) {
        Write-LogMessage -Message "❌ No valid services found in the requested list" -Level Error
        return $false
      }

      $serviceInfo.Services = $requestedServices
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
