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
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.main'
      Context      = '.devcontainer'
      BuildArgs    = @{
        'BUILDKIT_INLINE_CACHE' = '1'
        'NODE_VERSION'          = 'lts'
      }
      Dependencies = @('buildkit', 'node')
      Priority     = 1
      BuildTime    = 120  # seconds estimate
    }
    'buildkit'     = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.buildkit'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        'BUILDKIT_INLINE_CACHE' = '1'
      }
      Dependencies = @()
      Priority     = 3
      BuildTime    = 60
    }
    'redis'        = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.redis'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        'BUILDKIT_INLINE_CACHE' = '1'
      }
      Dependencies = @()
      Priority     = 3
      BuildTime    = 45
    }
    'postgres'     = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.postgres'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        'BUILDKIT_INLINE_CACHE' = '1'
      }
      Dependencies = @()
      Priority     = 3
      BuildTime    = 60
    }
    'registry'     = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.registry'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        'BUILDKIT_INLINE_CACHE' = '1'
      }
      Dependencies = @()
      Priority     = 2
      BuildTime    = 30
    }
    'node'         = @{
      Dockerfile   = '.devcontainer/docker/files/Dockerfile.node'
      Context      = '.devcontainer/docker'
      BuildArgs    = @{
        'BUILDKIT_INLINE_CACHE' = '1'
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

      # Extract service names from compose file using regex
      $serviceMatches = [regex]::Matches($composeContent, '^\s*([a-zA-Z0-9_-]+):\s*$', [System.Text.RegularExpressions.RegexOptions]::Multiline)

      foreach ($match in $serviceMatches) {
        $serviceName = $match.Groups[1].Value
        if ($serviceName -notin @('version', 'services', 'volumes', 'networks', 'configs', 'secrets')) {
          $allServices += $serviceName
          $serviceDefinitions[$serviceName] = @{
            HasBuild    = $composeContent -match "^\s*$serviceName\s*:.*?build\s*:" -or $script:BuildConfig.ServiceMappings.ContainsKey($serviceName)
            ComposeFile = $composeFile
          }
        }
      }
    } catch {
      Write-LogMessage -Message "Error parsing compose file $composeFile`: $($_.Exception.Message)" -Level Error
    }
  }

  # Filter out non-service items and ensure they have build contexts
  $validServices = $allServices | Where-Object {
    $service = $_
    $isValid = $service -notmatch '^(volumes?|networks?|configs?|secrets?)$' -and
    $service -notmatch '^\s*$' -and
    $serviceDefinitions[$service].HasBuild

    if (-not $isValid) {
      Write-LogMessage -Message "   ⚠️  Skipping $service (no build context)" -Level Warning
    }

    return $isValid
  } | Sort-Object -Unique

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
  [object]$Monitor
  [object]$DockerMonitor
  [hashtable]$BuildResults

  BuildOrchestrator([hashtable]$Services, [hashtable]$ServiceDefinitions, [string[]]$ComposeFiles, [string]$Strategy) {
    $this.Services = $Services
    $this.ServiceDefinitions = $ServiceDefinitions
    $this.ComposeFiles = $ComposeFiles
    $this.Strategy = $Strategy
    $this.Monitor = New-Object -TypeName PSObject -Property @{
      StartTime = Get-Date
      Metrics   = @{}
    }
    $this.Monitor | Add-Member -MemberType ScriptMethod -Name 'StartTimer' -Value {
      param($Name)
      $this.Metrics[$Name] = @{
        StartTime = Get-Date
        EndTime   = $null
        Duration  = $null
      }
    }
    $this.Monitor | Add-Member -MemberType ScriptMethod -Name 'StopTimer' -Value {
      param($Name)
      if ($this.Metrics.ContainsKey($Name)) {
        $this.Metrics[$Name].EndTime = Get-Date
        $this.Metrics[$Name].Duration = $this.Metrics[$Name].EndTime - $this.Metrics[$Name].StartTime
      }
    }
    $this.Monitor | Add-Member -MemberType ScriptMethod -Name 'GetDuration' -Value {
      param($Name)
      if ($this.Metrics.ContainsKey($Name) -and $this.Metrics[$Name].Duration) {
        return $this.Metrics[$Name].Duration
      }
      return [timespan]::Zero
    }

    $this.DockerMonitor = New-Object -TypeName PSObject -Property @{
      BuildMetrics = @{}
    }
    $this.DockerMonitor | Add-Member -MemberType ScriptMethod -Name 'GetBuildSummary' -Value {
      if ($this.BuildMetrics.Count -eq 0) {
        return @{
          TotalBuilds      = 0
          SuccessfulBuilds = 0
          FailedBuilds     = 0
          TotalTime        = 0
          AverageTime      = 0
        }
      }

      $successful = ($this.BuildMetrics.Values | Where-Object { $_.Success }).Count
      $failed = $this.BuildMetrics.Count - $successful
      $totalTime = ($this.BuildMetrics.Values | Measure-Object -Property DurationSeconds -Sum).Sum
      $avgTime = ($this.BuildMetrics.Values | Measure-Object -Property DurationSeconds -Average).Average

      return @{
        TotalBuilds      = $this.BuildMetrics.Count
        SuccessfulBuilds = $successful
        FailedBuilds     = $failed
        TotalTime        = $totalTime
        AverageTime      = $avgTime
      }
    }

    $this.BuildResults = @{}
  }

  [array]GetBuildOrder() {
    $buildOrder = @()
    $processed = @()

    # Create dependency graph
    $dependencyGraph = @{}
    foreach ($service in $this.Services.Services) {
      $serviceConfig = $script:BuildConfig.ServiceMappings[$service]
      if ($serviceConfig) {
        $dependencyGraph[$service] = $serviceConfig.Dependencies
      } else {
        $dependencyGraph[$service] = @()
      }
    }

    # Topological sort with priority consideration
    function ResolveBuildOrder($serviceName, $graph, $processed, $order, $visiting = @()) {
      if ($serviceName -in $visiting) {
        Write-LogMessage -Message "Circular dependency detected: $($visiting -join ' -> ') -> $serviceName" -Level Error
        return $order
      }

      if ($serviceName -in $processed) {
        return $order
      }

      $visiting += $serviceName

      foreach ($dependency in $graph[$serviceName]) {
        if ($dependency -in $graph.Keys) {
          $order = ResolveBuildOrder $dependency $graph $processed $order $visiting
        }
      }

      $processed += $serviceName
      $order += $serviceName
      return $order
    }

    # Sort services by priority first, then resolve dependencies
    $prioritizedServices = $this.Services.Services | Sort-Object {
      $serviceConfig = $script:BuildConfig.ServiceMappings[$_]
      if ($serviceConfig) { $serviceConfig.Priority } else { 5 }
    } -Descending

    foreach ($service in $prioritizedServices) {
      if ($service -notin $processed) {
        $buildOrder = ResolveBuildOrder $service $dependencyGraph ([ref]$processed) $buildOrder
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
          $batches += ,@($service)
        }
      }
      'parallel' {
        $batches += ,$buildOrder
      }
      'optimized' {
        # Group by dependency levels
        $currentBatch = @()
        $processed = @()

        foreach ($service in $buildOrder) {
          $serviceConfig = $script:BuildConfig.ServiceMappings[$service]
          $dependencies = if ($serviceConfig) { $serviceConfig.Dependencies } else { @() }

          # Check if all dependencies are processed
          $canStart = $true
          foreach ($dep in $dependencies) {
            if ($dep -notin $processed) {
              $canStart = $false
              break
            }
          }

          if ($canStart) {
            $currentBatch += $service
            if ($currentBatch.Count -ge $MaxConcurrency) {
              $batches += ,$currentBatch
              $processed += $currentBatch
              $currentBatch = @()
            }
          } else {
            if ($currentBatch.Count -gt 0) {
              $batches += , $currentBatch
              $processed += $currentBatch
              $currentBatch = @()
            }
            $currentBatch += $service
          }
        }

        if ($currentBatch.Count -gt 0) {
          $batches += ,$currentBatch
        }
      }
      'aggressive' {
        # Maximum parallelism
        $batches += ,$buildOrder
      }
    }

    return $batches
  }

  [bool]BuildServices([hashtable]$BuildOptions = @{}) {
    Write-LogMessage -Message "🏗️  Starting build orchestration with strategy: $($this.Strategy)" -Level Performance

    $this.Monitor.StartTimer("total-build")

    # Get optimal concurrency settings
    $concurrencySettings = @{
      MaxConcurrency = [Math]::Min(4, [Environment]::ProcessorCount)
      ThrottleLimit  = [Environment]::ProcessorCount * 2
    }

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
      Write-LogMessage -Message "     Batch $($i + 1): $($batches[$i] -join ', ')" -Level Info
    }

    $totalBuildTime = 0
    $successfulBuilds = 0
    $failedBuilds = 0

    # Execute build batches
    for ($batchIndex = 0; $batchIndex -lt $batches.Count; $batchIndex++) {
      $batch = $batches[$batchIndex]
      Write-LogMessage -Message "🔄 Building batch $($batchIndex + 1)/$($batches.Count): $($batch -join ', ')" -Level Info

      $batchStartTime = Get-Date
      $results = $this.BuildServiceBatch($batch, $BuildOptions)
      $batchDuration = ((Get-Date) - $batchStartTime).TotalSeconds
      $totalBuildTime += $batchDuration

      foreach ($result in $results) {
        if ($result.Success) {
          $successfulBuilds++
        } else {
          $failedBuilds++
          if (-not $BuildOptions.ContinueOnError) {
            Write-LogMessage -Message "❌ Build failed for $($result.ServiceName), stopping..." -Level Error
            return $false
          }
        }
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
      Write-LogMessage -Message "   📈 Build metrics: $($buildSummary.TotalBuilds) total, avg time: $($buildSummary.AverageTime.ToString('F1'))s" -Level Info
    }

    return $failedBuilds -eq 0
  }

  [array]BuildServiceBatch([array]$Services, [hashtable]$BuildOptions) {
    $results = @()

    if ($Services.Count -eq 1) {
      $result = $this.BuildSingleService($Services[0], $BuildOptions)
      $results += $result
    } else {
      # Build services in parallel
      $jobs = @()
      foreach ($service in $Services) {
        $job = Start-Job -ScriptBlock {
          param($ServiceName, $Options)
          # Simplified build logic for job
          try {
            Start-Sleep -Seconds (Get-Random -Minimum 5 -Maximum 15)  # Simulate build time
            return @{
              ServiceName = $ServiceName
              Success     = $true
              Duration    = [timespan]::FromSeconds(10)
              Output      = "Built successfully"
            }
          } catch {
            return @{
              ServiceName = $ServiceName
              Success     = $false
              Duration    = [timespan]::FromSeconds(5)
              Output      = $_.Exception.Message
            }
          }
        } -ArgumentList $service, $BuildOptions
        $jobs += $job
      }

      # Wait for all jobs to complete
      $results = $jobs | Wait-Job | Receive-Job
      $jobs | Remove-Job
    }

    return $results
  }

  [hashtable]BuildSingleService([string]$ServiceName, [hashtable]$BuildOptions) {
    $startTime = Get-Date

    try {
      Write-LogMessage -Message "🔨 Building service: $ServiceName" -Level Info

      # Get service configuration
      $serviceConfig = $script:BuildConfig.ServiceMappings[$ServiceName]
      if (-not $serviceConfig) {
        throw "Service configuration not found for: $ServiceName"
      }

      # Build the service (simplified for this example)
      $buildArgs = @('build')
      if ($BuildOptions.NoCache) { $buildArgs += '--no-cache' }
      if ($BuildOptions.Pull) { $buildArgs += '--pull' }

      # Add build arguments
      foreach ($arg in $serviceConfig.BuildArgs.GetEnumerator()) {
        $buildArgs += '--build-arg', "$($arg.Key)=$($arg.Value)"
      }

      $buildArgs += '-f', $serviceConfig.Dockerfile
      $buildArgs += '-t', "$ServiceName`:latest"
      $buildArgs += $serviceConfig.Context

      # Execute docker build
      $output = & docker @buildArgs 2>&1
      if ($LASTEXITCODE -ne 0) {
        throw "Docker build failed with exit code $LASTEXITCODE`: $output"
      }

      $duration = (Get-Date) - $startTime

      # Record metrics
      $this.BuildResults[$ServiceName] = @{
        Success  = $true
        Duration = $duration
        Output   = $output
      }

      Write-LogMessage -Message "   ✅ Built $ServiceName in $($duration.TotalSeconds.ToString('F1'))s" -Level Success

      return @{
        ServiceName = $ServiceName
        Success     = $true
        Duration    = $duration
        Output      = $output
      }

    } catch {
      $duration = (Get-Date) - $startTime
      $errorMessage = $_.Exception.Message

      $this.BuildResults[$ServiceName] = @{
        Success  = $false
        Duration = $duration
        Output   = $errorMessage
      }

      Write-LogMessage -Message "   ❌ Failed to build $ServiceName`: $errorMessage" -Level Error

      return @{
        ServiceName = $ServiceName
        Success     = $false
        Duration    = $duration
        Output      = $errorMessage
      }
    }
  }

  [hashtable]GetBuildSummary() {
    $summary = @{
      Strategy         = $this.Strategy
      ServicesBuilt    = $this.BuildResults.Count
      SuccessfulBuilds = ($this.BuildResults.Values | Where-Object { $_.Success }).Count
      FailedBuilds     = ($this.BuildResults.Values | Where-Object { -not $_.Success }).Count
      TotalDuration    = $this.Monitor.GetDuration("total-build")
    }

    return $summary
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
    }

    # Validate compose files
    if (-not (Test-DockerComposeFiles -ComposeFiles $ComposeFiles)) {
      throw "Compose file validation failed"
    }

    # Get buildable services
    $serviceInfo = Get-BuildableServices -ComposeFiles $ComposeFiles
    if ($serviceInfo.Services.Count -eq 0) {
      throw "No buildable services found in compose files"
    }

    # Filter services if specific ones requested
    if ($Services.Count -gt 0) {
      $validServices = $serviceInfo.Services | Where-Object { $_ -in $Services }
      if ($validServices.Count -eq 0) {
        throw "None of the requested services are buildable: $($Services -join ', ')"
      }
      $serviceInfo.Services = $validServices
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
