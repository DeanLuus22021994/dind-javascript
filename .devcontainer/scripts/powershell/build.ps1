#!/usr/bin/env pwsh
# DevContainer Build Script - Simplified and Modular
# Leverages advanced modular implementations for optimal performance

#Requires -Version 7.0

[CmdletBinding()]
param(
  [Parameter(Mandatory = $false)]
  [ValidateSet('sequential', 'parallel', 'optimized', 'aggressive')]
  [string]$BuildStrategy = 'optimized',

  [Parameter(Mandatory = $false)]
  [switch]$NoCacheFrom,

  [Parameter(Mandatory = $false)]
  [switch]$NoCache,

  [Parameter(Mandatory = $false)]
  [switch]$CleanFirst,

  [Parameter(Mandatory = $false)]
  [string[]]$Services = @(),

  [Parameter(Mandatory = $false)]
  [int]$MaxParallelBuilds = 0,

  [Parameter(Mandatory = $false)]
  [switch]$OptimizeSystem,

  [Parameter(Mandatory = $false)]
  [switch]$ContinueOnError,

  [Parameter(Mandatory = $false)]
  [switch]$ShowProgress
)

# Set error action preference and enable maximum performance
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Import all required modules with error handling
$ModulesPath = Join-Path $PSScriptRoot "modules"
$RequiredModules = @(
  "Core-Utils",
  "Performance-Utils",
  "Docker-Utils",
  "Service-Utils",
  "Build-Utils",
  "Cleanup-Utils"
)

Write-Host "🔧 Loading build modules..." -ForegroundColor Cyan

foreach ($Module in $RequiredModules) {
  $ModulePath = Join-Path $ModulesPath "$Module.psm1"
  if (Test-Path $ModulePath) {
    try {
      Import-Module $ModulePath -Force -ErrorAction Stop
      Write-Host "✅ Loaded module: $Module" -ForegroundColor Green
    } catch {
      Write-Host "❌ Failed to load module $Module : $($_.Exception.Message)" -ForegroundColor Red
      exit 1
    }
  } else {
    Write-Host "❌ Module not found: $ModulePath" -ForegroundColor Red
    exit 1
  }
}

# Main build execution
try {
  Write-LogMessage -Message "🚀 DevContainer Build Starting..." -Level Info
  Write-LogMessage -Message "Strategy: $BuildStrategy | Max Parallel: $MaxParallelBuilds" -Level Info

  # Start total timer
  $totalStartTime = Get-Date

  # Define compose files
  $composeFiles = @(
    ".devcontainer/docker/compose/docker-compose.main.yml",
    ".devcontainer/docker/compose/docker-compose.services.yml"
  )

  # Phase 1: System optimization (if requested)
  if ($OptimizeSystem) {
    Write-LogMessage -Message "⚡ Phase 1: System Optimization..." -Level Performance
    $optimizeResult = Optimize-SystemForDocker -AggressiveOptimization:($BuildStrategy -eq 'aggressive')
    if ($optimizeResult) {
      Write-LogMessage -Message "✅ System optimization completed" -Level Success
    } else {
      Write-LogMessage -Message "⚠️  System optimization had issues (continuing anyway)" -Level Warning
    }
    Write-Host ""
  }

  # Phase 2: Pre-build cleanup (if requested)
  if ($CleanFirst) {
    Write-LogMessage -Message "🧹 Phase 2: Pre-build Cleanup..." -Level Info
    $cleanupResult = Invoke-DockerSystemCleanup -IncludeVolumes -IncludeNetworks -Force
    if ($cleanupResult) {
      Write-LogMessage -Message "✅ Cleanup completed successfully" -Level Success
    } else {
      Write-LogMessage -Message "⚠️  Cleanup had issues (continuing anyway)" -Level Warning
    }
    Write-Host ""
  }

  # Phase 3: Validate environment and compose files
  Write-LogMessage -Message "🔍 Phase 3: Environment Validation..." -Level Info

  # Test Docker availability
  if (-not (Test-DockerAvailability)) {
    throw "Docker is not available or not responding"
  }
  Write-LogMessage -Message "✅ Docker is available and responding" -Level Success

  # Validate compose files
  if (-not (Test-DockerComposeFiles -ComposeFiles $composeFiles -Detailed)) {
    throw "Docker Compose file validation failed"
  }
  Write-LogMessage -Message "✅ All compose files validated successfully" -Level Success
  Write-Host ""

  # Phase 4: Build orchestration using Build-Utils module
  Write-LogMessage -Message "🏗️  Phase 4: Advanced Build Orchestration..." -Level Performance

  # Prepare build options
  $buildOptions = @{
    NoCache         = $NoCache.IsPresent
    Pull            = $NoCacheFrom.IsPresent -eq $false  # Pull if not explicitly disabled
    ContinueOnError = $ContinueOnError.IsPresent
    BuildArgs       = @{
      'BUILDKIT_INLINE_CACHE' = '1'
      'DOCKER_BUILDKIT'       = '1'
    }
    MaxConcurrency  = if ($MaxParallelBuilds -gt 0) { $MaxParallelBuilds } else { 0 }
    ShowProgress    = $ShowProgress.IsPresent
  }

  # Execute build using the advanced Build-Utils module
  $buildResult = Invoke-DevContainerBuild -ComposeFiles $composeFiles -Services $Services -Strategy $BuildStrategy @buildOptions

  if (-not $buildResult) {
    throw "Build orchestration failed"
  }

  Write-LogMessage -Message "✅ Build orchestration completed successfully!" -Level Success
  Write-Host ""

  # Phase 5: Post-build validation and optimization
  Write-LogMessage -Message "🔍 Phase 5: Post-build Validation..." -Level Info

  # Get buildable services for validation
  $serviceInfo = Get-BuildableServices -ComposeFiles $composeFiles
  $servicesToValidate = if ($Services.Count -gt 0) {
    $serviceInfo.Services | Where-Object { $_ -in $Services }
  } else {
    $serviceInfo.Services
  }

  # Validate built images exist
  $validationErrors = @()
  foreach ($service in $servicesToValidate) {
    try {
      $imageExists = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -like "*$service*" }
      if (-not $imageExists) {
        $validationErrors += "Image for service '$service' not found"
      }
    } catch {
      $validationErrors += "Failed to validate service '$service': $($_.Exception.Message)"
    }
  }

  if ($validationErrors.Count -gt 0) {
    Write-LogMessage -Message "⚠️  Post-build validation warnings:" -Level Warning
    foreach ($validationError in $validationErrors) {
      Write-LogMessage -Message "   - $validationError" -Level Warning
    }
  } else {
    Write-LogMessage -Message "✅ All built images validated successfully" -Level Success
  }

  # Perform post-build cleanup optimization
  Write-LogMessage -Message "🚀 Performing post-build optimization..." -Level Info
  $cleanupResult = Invoke-DockerSystemCleanup -Force
  if ($cleanupResult) {
    Write-LogMessage -Message "✅ Post-build optimization completed" -Level Success
  }

  Write-Host ""

  # Phase 6: Final summary and performance metrics
  $totalExecutionTime = ((Get-Date) - $totalStartTime).TotalSeconds

  Write-LogMessage -Message "🎉 BUILD COMPLETED SUCCESSFULLY!" -Level Success
  Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
  Write-LogMessage -Message "📊 Build Summary:" -Level Info
  Write-LogMessage -Message "   ⚡ Strategy: $BuildStrategy" -Level Info
  Write-LogMessage -Message "   🎯 Services: $($servicesToValidate.Count) built" -Level Info
  Write-LogMessage -Message "   ⏱️  Total time: $($totalExecutionTime.ToString('F1'))s" -Level Info
  Write-LogMessage -Message "   💻 CPU cores utilized: $([Environment]::ProcessorCount)" -Level Info

  # Get system performance info for final report
  try {
    $perfInfo = Get-SystemPerformanceInfo
    Write-LogMessage -Message "   🧠 Memory usage: $($perfInfo.Memory.UsagePercent.ToString('F1'))%" -Level Info
  } catch {
    Write-LogMessage -Message "   🧠 Memory usage: Unable to determine" -Level Info
  }

  Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
  Write-LogMessage -Message "🚀 Your DevContainer is ready for development!" -Level Success

  exit 0

} catch {
  $totalExecutionTime = ((Get-Date) - $totalStartTime).TotalSeconds

  Write-Host ""
  Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Red
  Write-LogMessage -Message "❌ BUILD FAILED: $($_.Exception.Message)" -Level Error
  Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Red

  Write-LogMessage -Message "💡 Troubleshooting suggestions:" -Level Info
  Write-LogMessage -Message "   🧹 Clean first: pwsh $PSCommandPath -CleanFirst" -Level Info
  Write-LogMessage -Message "   🔍 Check Docker: docker info" -Level Info
  Write-LogMessage -Message "   📋 Check compose: docker-compose config" -Level Info
  Write-LogMessage -Message "   🛠️  Manual build: docker-compose build --no-cache" -Level Info
  Write-LogMessage -Message "   📊 System check: docker system df" -Level Info

  # Show system information for debugging
  Write-LogMessage -Message "🖥️  System Information:" -Level Info
  Write-LogMessage -Message "   PowerShell: $($PSVersionTable.PSVersion)" -Level Info
  Write-LogMessage -Message "   OS: $([Environment]::OSVersion.VersionString)" -Level Info
  Write-LogMessage -Message "   CPU Cores: $([Environment]::ProcessorCount)" -Level Info

  try {
    $dockerInfo = Get-DockerSystemInfo
    if ($dockerInfo.Count -gt 0) {
      Write-LogMessage -Message "   Docker: $($dockerInfo.Version) ($($dockerInfo.Architecture))" -Level Info
      Write-LogMessage -Message "   Docker Memory: $($dockerInfo.Memory)GB" -Level Info
    } else {
      Write-LogMessage -Message "   Docker: Not available or not responding" -Level Error
    }
  } catch {
    Write-LogMessage -Message "   Docker: Error getting info - $($_.Exception.Message)" -Level Error
  }

  try {
    $systemInfo = Get-SystemPerformanceInfo
    Write-LogMessage -Message "   Available Memory: $($systemInfo.Memory.TotalGB)GB" -Level Info
    Write-LogMessage -Message "   Memory Usage: $($systemInfo.Memory.UsagePercent.ToString('F1'))%" -Level Info
  } catch {
    Write-LogMessage -Message "   Memory: Unable to determine" -Level Info
  }

  Write-LogMessage -Message "   Build time: $($totalExecutionTime.ToString('F1'))s" -Level Info

  exit 1
}
