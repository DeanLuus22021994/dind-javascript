#!/usr/bin/env pwsh
# Service-Utils.psm1 - Advanced service management utilities for DevContainer PowerShell scripts
# Provides comprehensive service orchestration with health monitoring and dependency management

# Import required modules
Import-Module "$PSScriptRoot\Core-Utils.psm1" -Force
Import-Module "$PSScriptRoot\Docker-Utils.psm1" -Force

Set-StrictMode -Version Latest

# Service configuration and dependency mapping
$script:ServiceConfig = @{
  'devcontainer' = @{
    DependsOn     = @('buildkit', 'redis', 'postgres', 'registry', 'node')
    HealthCheck   = 'docker exec dind-javascript-devcontainer echo "healthy" 2>$null'
    Port          = $null
    Essential     = $true
    StartupTime   = 30
    HealthTimeout = 60
  }
  'buildkit'     = @{
    DependsOn     = @()
    HealthCheck   = 'docker exec dind-buildkit buildctl debug workers 2>$null'
    Port          = $null
    Essential     = $true
    StartupTime   = 15
    HealthTimeout = 30
  }
  'redis'        = @{
    DependsOn     = @()
    HealthCheck   = 'docker exec dind-redis redis-cli ping 2>$null'
    Port          = 6379
    Essential     = $true
    StartupTime   = 10
    HealthTimeout = 30
  }
  'postgres'     = @{
    DependsOn     = @()
    HealthCheck   = 'docker exec dind-postgres pg_isready -U devuser 2>$null'
    Port          = 5432
    Essential     = $true
    StartupTime   = 15
    HealthTimeout = 45
  }
  'registry'     = @{
    DependsOn     = @()
    HealthCheck   = 'docker exec dind-registry /bin/registry --version 2>$null'
    Port          = 5000
    Essential     = $false
    StartupTime   = 10
    HealthTimeout = 30
  }
  'node'         = @{
    DependsOn     = @()
    HealthCheck   = 'docker exec dind-node node --version 2>$null'
    Port          = $null
    Essential     = $false
    StartupTime   = 10
    HealthTimeout = 30
  }
}

# Performance monitoring class for service metrics
class ServicePerformanceMonitor {
  [hashtable]$Timers
  [hashtable]$Metrics

  ServicePerformanceMonitor() {
    $this.Timers = @{}
    $this.Metrics = @{}
  }

  [void]StartTimer([string]$Name) {
    $this.Timers[$Name] = Get-Date
  }

  [void]StopTimer([string]$Name) {
    if ($this.Timers.ContainsKey($Name)) {
      $elapsed = (Get-Date) - $this.Timers[$Name]
      $this.Metrics[$Name] = $elapsed.TotalSeconds
      $this.Timers.Remove($Name)
    }
  }

  [hashtable]GetSummary() {
    return $this.Metrics.Clone()
  }
}

# Service management class for advanced operations
class ServiceManager {
  [hashtable]$Services
  [string[]]$ComposeFiles
  [ServicePerformanceMonitor]$Monitor

  ServiceManager([string[]]$ComposeFiles) {
    $this.Services = $script:ServiceConfig
    $this.ComposeFiles = $ComposeFiles
    $this.Monitor = [ServicePerformanceMonitor]::new()
  }

  [array]GetServiceStartOrder() {
    $startOrder = @()
    $processed = @()

    # Recursive function to resolve dependencies
    function ResolveDependencies($serviceName, $services, $processed, $order) {
      if ($serviceName -in $processed) {
        return
      }

      if ($services.ContainsKey($serviceName)) {
        $dependencies = $services[$serviceName].DependsOn
        foreach ($dep in $dependencies) {
          ResolveDependencies $dep $services $processed $order
        }

        $order.Add($serviceName)
        $processed += $serviceName
      }
    }

    # Resolve dependencies for all services
    foreach ($serviceName in $this.Services.Keys) {
      ResolveDependencies $serviceName $this.Services $processed $startOrder
    }

    return $startOrder
  }

  [bool]StartServices([string[]]$ServiceNames = @()) {
    $servicesToStart = if ($ServiceNames.Count -gt 0) { $ServiceNames } else { $this.Services.Keys }
    $startOrder = $this.GetServiceStartOrder() | Where-Object { $_ -in $servicesToStart }

    Write-LogMessage -Message "Starting services in dependency order: $($startOrder -join ' → ')" -Level Info

    $this.Monitor.StartTimer("service-startup")

    try {
      # Start services in batches based on dependencies
      $currentLevel = @()
      $nextLevel = @()

      foreach ($service in $startOrder) {
        $dependencies = $this.Services[$service].DependsOn
        $dependenciesReady = $true

        foreach ($dep in $dependencies) {
          if (-not $this.IsServiceHealthy($dep)) {
            $dependenciesReady = $false
            break
          }
        }

        if ($dependenciesReady -or $dependencies.Count -eq 0) {
          $currentLevel += $service
        } else {
          $nextLevel += $service
        }

        # Start batch when we have enough services or reached the end
        if ($currentLevel.Count -ge 3 -or ($currentLevel.Count -gt 0 -and $service -eq $startOrder[-1])) {
          $this.StartServiceBatch($currentLevel)
          $currentLevel = @()

          # Move next level services to current if their dependencies are now ready
          $stillWaiting = @()
          foreach ($waitingService in $nextLevel) {
            $deps = $this.Services[$waitingService].DependsOn
            $depsReady = $true
            foreach ($dep in $deps) {
              if (-not $this.IsServiceHealthy($dep)) {
                $depsReady = $false
                break
              }
            }
            if ($depsReady) {
              $currentLevel += $waitingService
            } else {
              $stillWaiting += $waitingService
            }
          }
          $nextLevel = $stillWaiting
        }
      }

      # Start any remaining services
      if ($currentLevel.Count -gt 0) {
        $this.StartServiceBatch($currentLevel)
      }

      $this.Monitor.StopTimer("service-startup")

      # Final health check for all requested services
      $allHealthy = $true
      foreach ($service in $servicesToStart) {
        if (-not $this.WaitForServiceHealth($service)) {
          $allHealthy = $false
          Write-LogMessage -Message "Service '$service' failed to become healthy" -Level Error
        }
      }

      return $allHealthy

    } catch {
      Write-LogMessage -Message "Error starting services: $($_.Exception.Message)" -Level Error
      return $false
    }
  }

  [void]StartServiceBatch([string[]]$Services) {
    if ($Services.Count -eq 0) { return }

    Write-LogMessage -Message "🚀 Starting service batch: $($Services -join ', ')" -Level Info

    # Use docker-compose to start services in parallel
    try {
      $composeArgs = @()
      foreach ($file in $this.ComposeFiles) {
        $composeArgs += '-f', $file
      }
      $composeArgs += 'up', '-d', '--no-recreate'
      $composeArgs += $Services

      $null = & docker-compose @composeArgs 2>&1
      if ($LASTEXITCODE -eq 0) {
        Write-LogMessage -Message "✅ Batch started successfully: $($Services -join ', ')" -Level Success
      } else {
        Write-LogMessage -Message "❌ Failed to start batch" -Level Error
        throw "Failed to start service batch"
      }
    } catch {
      Write-LogMessage -Message "Error starting service batch: $($_.Exception.Message)" -Level Error
      throw
    }
  }

  [bool]IsServiceHealthy([string]$ServiceName) {
    if (-not $this.Services.ContainsKey($ServiceName)) {
      return $false
    }

    $serviceConfig = $this.Services[$ServiceName]

    try {
      # Check if container is running first
      $containerName = "dind-$ServiceName"
      if ($ServiceName -eq 'devcontainer') {
        $containerName = 'dind-javascript-devcontainer'
      }

      $containerStatus = docker inspect $containerName --format '{{.State.Status}}' 2>$null
      if ($LASTEXITCODE -ne 0 -or $containerStatus -ne 'running') {
        return $false
      }

      # Execute health check command
      $healthResult = Invoke-Expression $serviceConfig.HealthCheck
      return $LASTEXITCODE -eq 0 -and $healthResult

    } catch {
      return $false
    }
  }

  [bool]WaitForServiceHealth([string]$ServiceName, [int]$TimeoutSeconds = 0) {
    if (-not $this.Services.ContainsKey($ServiceName)) {
      Write-LogMessage -Message "Unknown service: $ServiceName" -Level Error
      return $false
    }

    $serviceConfig = $this.Services[$ServiceName]
    $timeout = if ($TimeoutSeconds -gt 0) { $TimeoutSeconds } else { $serviceConfig.HealthTimeout }

    Write-LogMessage -Message "⏳ Waiting for '$ServiceName' to become healthy (timeout: ${timeout}s)..." -Level Info

    $startTime = Get-Date
    $attempts = 0

    while (((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
      $attempts++

      if ($this.IsServiceHealthy($ServiceName)) {
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        Write-LogMessage -Message "✅ '$ServiceName' is healthy (${attempts} attempts, ${elapsed:F1}s)" -Level Success
        return $true
      }

      Start-Sleep -Seconds 2
    }

    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    Write-LogMessage -Message "❌ '$ServiceName' health check timed out after ${elapsed:F1}s (${attempts} attempts)" -Level Error
    return $false
  }

  [hashtable]GetServiceStatus() {
    $status = @{}

    foreach ($serviceName in $this.Services.Keys) {
      $containerName = if ($serviceName -eq 'devcontainer') { 'dind-javascript-devcontainer' } else { "dind-$serviceName" }

      try {
        $containerInfo = docker inspect $containerName --format '{{json .}}' 2>$null | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0 -and $containerInfo) {
          $status[$serviceName] = @{
            Name          = $serviceName
            ContainerName = $containerName
            Status        = $containerInfo.State.Status
            Health        = if ($this.IsServiceHealthy($serviceName)) { 'Healthy' } else { 'Unhealthy' }
            StartedAt     = $containerInfo.State.StartedAt
            Image         = $containerInfo.Config.Image
            Ports         = $containerInfo.NetworkSettings.Ports
            Essential     = $this.Services[$serviceName].Essential
          }
        } else {
          $status[$serviceName] = @{
            Name          = $serviceName
            ContainerName = $containerName
            Status        = 'Not Found'
            Health        = 'Unknown'
            StartedAt     = $null
            Image         = $null
            Ports         = @{}
            Essential     = $this.Services[$serviceName].Essential
          }
        }
      } catch {
        $status[$serviceName] = @{
          Name          = $serviceName
          ContainerName = $containerName
          Status        = 'Error'
          Health        = 'Unknown'
          StartedAt     = $null
          Image         = $null
          Ports         = @{}
          Essential     = $this.Services[$serviceName].Essential
          Error         = $_.Exception.Message
        }
      }
    }

    return $status
  }

  [bool]StopServices([string[]]$ServiceNames = @(), [bool]$Force = $false) {
    $servicesToStop = if ($ServiceNames.Count -gt 0) { $ServiceNames } else { $this.Services.Keys }

    # Reverse dependency order for stopping
    $startOrder = $this.GetServiceStartOrder()
    $stopOrder = $servicesToStop | Where-Object { $_ -in $startOrder }
    [array]::Reverse($stopOrder)

    Write-LogMessage -Message "Stopping services in reverse dependency order: $($stopOrder -join ' → ')" -Level Info

    $this.Monitor.StartTimer("service-shutdown")

    try {
      $composeArgs = @()
      foreach ($file in $this.ComposeFiles) {
        $composeArgs += '-f', $file
      }

      if ($Force) {
        $composeArgs += 'kill'
      } else {
        $composeArgs += 'stop'
      }

      $composeArgs += $stopOrder

      $null = & docker-compose @composeArgs 2>&1

      $this.Monitor.StopTimer("service-shutdown")

      if ($LASTEXITCODE -eq 0) {
        Write-LogMessage -Message "✅ Services stopped successfully" -Level Success
        return $true
      } else {
        Write-LogMessage -Message "❌ Failed to stop services" -Level Error
        return $false
      }

    } catch {
      Write-LogMessage -Message "Error stopping services: $($_.Exception.Message)" -Level Error
      return $false
    }
  }

  [bool]RestartServices([string[]]$ServiceNames = @()) {
    Write-LogMessage -Message "🔄 Restarting services..." -Level Info

    $stopResult = $this.StopServices($ServiceNames)
    if (-not $stopResult) {
      Write-LogMessage -Message "Failed to stop services for restart" -Level Error
      return $false
    }

    Start-Sleep -Seconds 3  # Brief pause between stop and start

    $startResult = $this.StartServices($ServiceNames)
    if ($startResult) {
      Write-LogMessage -Message "✅ Services restarted successfully" -Level Success
    } else {
      Write-LogMessage -Message "❌ Failed to restart services" -Level Error
    }

    return $startResult
  }

  [void]ShowServiceStatus() {
    $status = $this.GetServiceStatus()

    Write-LogMessage -Message "📊 Service Status Report" -Level Info
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray

    $essentialServices = $status.Values | Where-Object { $_.Essential } | Sort-Object Name
    $optionalServices = $status.Values | Where-Object { -not $_.Essential } | Sort-Object Name

    Write-LogMessage -Message "🔴 Essential Services:" -Level Info
    foreach ($service in $essentialServices) {
      $statusEmoji = switch ($service.Status) {
        'running' { '✅' }
        'exited' { '❌' }
        'paused' { '⏸️' }
        default { '❓' }
      }

      $healthEmoji = switch ($service.Health) {
        'Healthy' { '💚' }
        'Unhealthy' { '💔' }
        default { '❓' }
      }

      Write-Host "   $statusEmoji $healthEmoji $($service.Name.PadRight(15)) | $($service.Status.PadRight(10)) | $($service.ContainerName)" -ForegroundColor White
    }

    if ($optionalServices.Count -gt 0) {
      Write-LogMessage -Message "🟡 Optional Services:" -Level Info
      foreach ($service in $optionalServices) {
        $statusEmoji = switch ($service.Status) {
          'running' { '✅' }
          'exited' { '❌' }
          'paused' { '⏸️' }
          default { '❓' }
        }

        $healthEmoji = switch ($service.Health) {
          'Healthy' { '💚' }
          'Unhealthy' { '💔' }
          default { '❓' }
        }

        Write-Host "   $statusEmoji $healthEmoji $($service.Name.PadRight(15)) | $($service.Status.PadRight(10)) | $($service.ContainerName)" -ForegroundColor Gray
      }
    }

    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor DarkGray

    # Summary
    $runningCount = ($status.Values | Where-Object { $_.Status -eq 'running' }).Count
    $healthyCount = ($status.Values | Where-Object { $_.Health -eq 'Healthy' }).Count
    $totalCount = $status.Count

    Write-LogMessage -Message "📈 Summary: $runningCount/$totalCount running, $healthyCount/$totalCount healthy" -Level Info
  }

  [hashtable]GetPerformanceMetrics() {
    return $this.Monitor.GetSummary()
  }
}

# Convenience functions that use the ServiceManager
function Start-DevContainerServices {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string[]]$Services = @(),

    [Parameter(Mandatory = $true)]
    [string[]]$ComposeFiles
  )

  $manager = [ServiceManager]::new($ComposeFiles)
  return $manager.StartServices($Services)
}

function Stop-DevContainerServices {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string[]]$Services = @(),

    [Parameter(Mandatory = $true)]
    [string[]]$ComposeFiles,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  $manager = [ServiceManager]::new($ComposeFiles)
  return $manager.StopServices($Services, $Force.IsPresent)
}

function Restart-DevContainerServices {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string[]]$Services = @(),

    [Parameter(Mandatory = $true)]
    [string[]]$ComposeFiles
  )

  $manager = [ServiceManager]::new($ComposeFiles)
  return $manager.RestartServices($Services)
}

function Get-DevContainerServiceStatus {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$ComposeFiles,

    [Parameter(Mandatory = $false)]
    [switch]$ShowDetails
  )

  $manager = [ServiceManager]::new($ComposeFiles)

  if ($ShowDetails) {
    $manager.ShowServiceStatus()
  }

  return $manager.GetServiceStatus()
}

function Test-DevContainerServiceHealth {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$ServiceName,

    [Parameter(Mandatory = $true)]
    [string[]]$ComposeFiles,

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 60
  )

  $manager = [ServiceManager]::new($ComposeFiles)
  return $manager.WaitForServiceHealth($ServiceName, $TimeoutSeconds)
}

# Advanced health monitoring function
function Start-ServiceHealthMonitoring {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$ComposeFiles,

    [Parameter(Mandatory = $false)]
    [int]$IntervalSeconds = 30,

    [Parameter(Mandatory = $false)]
    [int]$DurationMinutes = 0  # 0 = indefinite
  )

  $manager = [ServiceManager]::new($ComposeFiles)
  $startTime = Get-Date
  $endTime = if ($DurationMinutes -gt 0) { $startTime.AddMinutes($DurationMinutes) } else { [datetime]::MaxValue }

  Write-LogMessage -Message "🔍 Starting health monitoring (interval: ${IntervalSeconds}s)..." -Level Info
  Write-LogMessage -Message "Press Ctrl+C to stop monitoring" -Level Info

  try {
    while ((Get-Date) -lt $endTime) {
      Clear-Host
      Write-LogMessage -Message "🔍 DevContainer Health Monitor - $(Get-Date -Format 'HH:mm:ss')" -Level Info
      $manager.ShowServiceStatus()

      if ((Get-Date) -lt $endTime) {
        Write-LogMessage -Message "Next update in ${IntervalSeconds}s..." -Level Info
        Start-Sleep -Seconds $IntervalSeconds
      }
    }
  } catch {
    Write-LogMessage -Message "Health monitoring stopped" -Level Info
  }
}

# Export functions and classes
Export-ModuleMember -Function @(
  'Start-DevContainerServices',
  'Stop-DevContainerServices',
  'Restart-DevContainerServices',
  'Get-DevContainerServiceStatus',
  'Test-DevContainerServiceHealth',
  'Start-ServiceHealthMonitoring'
) -Variable @('ServiceConfig')
