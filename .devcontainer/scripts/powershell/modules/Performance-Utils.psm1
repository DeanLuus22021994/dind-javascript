#!/usr/bin/env pwsh
# Performance-Utils.psm1 - Performance monitoring and optimization utilities
# Provides advanced performance tracking, system monitoring, and optimization features

# Import core utilities
Import-Module "$PSScriptRoot\Core-Utils.psm1" -Force

Set-StrictMode -Version Latest

# Performance monitoring constants
$script:PerformanceConfig = @{
  SampleInterval       = 1  # seconds
  HistorySize          = 100   # number of samples to keep
  AlertThresholds      = @{
    CPU         = 90        # percent
    Memory      = 85     # percent
    Disk        = 90       # percent
    NetworkMbps = 100  # Mbps
  }
  OptimizationSettings = @{
    MaxConcurrentBuilds = [Math]::Min(8, [Environment]::ProcessorCount)
    MemoryLimitMB       = 4096
    IOPriority          = 'Normal'
    ProcessPriority     = 'Normal'
  }
}

# Advanced performance metrics class
class AdvancedPerformanceMonitor {
  [System.Collections.Generic.Queue[hashtable]]$CPUHistory
  [System.Collections.Generic.Queue[hashtable]]$MemoryHistory
  [System.Collections.Generic.Queue[hashtable]]$DiskHistory
  [System.Collections.Generic.Queue[hashtable]]$NetworkHistory
  [hashtable]$ProcessMetrics
  [datetime]$StartTime
  [hashtable]$Alerts
  [bool]$MonitoringActive

  AdvancedPerformanceMonitor() {
    $this.CPUHistory = [System.Collections.Generic.Queue[hashtable]]::new()
    $this.MemoryHistory = [System.Collections.Generic.Queue[hashtable]]::new()
    $this.DiskHistory = [System.Collections.Generic.Queue[hashtable]]::new()
    $this.NetworkHistory = [System.Collections.Generic.Queue[hashtable]]::new()
    $this.ProcessMetrics = @{}
    $this.Alerts = @{}
    $this.StartTime = Get-Date
    $this.MonitoringActive = $false
  }

  [void]StartMonitoring() {
    $this.MonitoringActive = $true
    $this.StartTime = Get-Date
    Write-LogMessage -Message "🔍 Advanced performance monitoring started" -Level Performance
  }

  [void]StopMonitoring() {
    $this.MonitoringActive = $false
    Write-LogMessage -Message "⏹️  Performance monitoring stopped" -Level Performance
  }

  [void]CollectMetrics() {
    if (-not $this.MonitoringActive) { return }

    $timestamp = Get-Date

    # Collect CPU metrics
    try {
      $cpuUsage = Get-CimInstance -ClassName Win32_Processor |
        Measure-Object -Property LoadPercentage -Average |
        Select-Object -ExpandProperty Average

      $cpuMetric = @{
        Timestamp = $timestamp
        Usage     = $cpuUsage
        Cores     = [Environment]::ProcessorCount
      }

      $this.AddToHistory($this.CPUHistory, $cpuMetric)
      $this.CheckAlert('CPU', $cpuUsage, $script:PerformanceConfig.AlertThresholds.CPU)
    } catch {
      Write-LogMessage -Message "Failed to collect CPU metrics: $($_.Exception.Message)" -Level Warning
    }

    # Collect Memory metrics
    try {
      $memory = Get-CimInstance -ClassName Win32_OperatingSystem
      $totalMB = [Math]::Round($memory.TotalVisibleMemorySize / 1KB, 2)
      $freeMB = [Math]::Round($memory.FreePhysicalMemory / 1KB, 2)
      $usedMB = $totalMB - $freeMB
      $usagePercent = [Math]::Round(($usedMB / $totalMB) * 100, 2)

      $memoryMetric = @{
        Timestamp    = $timestamp
        TotalMB      = $totalMB
        UsedMB       = $usedMB
        FreeMB       = $freeMB
        UsagePercent = $usagePercent
      }

      $this.AddToHistory($this.MemoryHistory, $memoryMetric)
      $this.CheckAlert('Memory', $usagePercent, $script:PerformanceConfig.AlertThresholds.Memory)
    } catch {
      Write-LogMessage -Message "Failed to collect memory metrics: $($_.Exception.Message)" -Level Warning
    }

    # Collect Disk metrics
    try {
      $disks = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
      foreach ($disk in $disks) {
        $totalGB = [Math]::Round($disk.Size / 1GB, 2)
        $freeGB = [Math]::Round($disk.FreeSpace / 1GB, 2)
        $usedGB = $totalGB - $freeGB
        $usagePercent = if ($totalGB -gt 0) { [Math]::Round(($usedGB / $totalGB) * 100, 2) } else { 0 }

        $diskMetric = @{
          Timestamp    = $timestamp
          Drive        = $disk.DeviceID
          TotalGB      = $totalGB
          UsedGB       = $usedGB
          FreeGB       = $freeGB
          UsagePercent = $usagePercent
        }

        $this.AddToHistory($this.DiskHistory, $diskMetric)
        $this.CheckAlert("Disk_$($disk.DeviceID)", $usagePercent, $script:PerformanceConfig.AlertThresholds.Disk)
      }
    } catch {
      Write-LogMessage -Message "Failed to collect disk metrics: $($_.Exception.Message)" -Level Warning
    }
  }

  [void]AddToHistory([System.Collections.Generic.Queue[hashtable]]$queue, [hashtable]$metric) {
    $queue.Enqueue($metric)
    while ($queue.Count -gt $script:PerformanceConfig.HistorySize) {
      $null = $queue.Dequeue()
    }
  }

  [void]CheckAlert([string]$metricName, [double]$value, [double]$threshold) {
    if ($value -gt $threshold) {
      $alertKey = "$metricName-$(Get-Date -Format 'yyyyMMdd-HHmm')"
      if (-not $this.Alerts.ContainsKey($alertKey)) {
        $this.Alerts[$alertKey] = @{
          Metric     = $metricName
          Value      = $value
          Threshold  = $threshold
          FirstAlert = Get-Date
          Count      = 1
        }
        Write-LogMessage -Message "⚠️  PERFORMANCE ALERT: $metricName at $($value.ToString('F1'))% (threshold: $($threshold)%)" -Level Warning
      } else {
        $this.Alerts[$alertKey].Count++
      }
    }
  }

  [hashtable]GetCurrentMetrics() {
    $latest = @{}

    if ($this.CPUHistory.Count -gt 0) {
      $latest.CPU = @($this.CPUHistory)[-1]
    }

    if ($this.MemoryHistory.Count -gt 0) {
      $latest.Memory = @($this.MemoryHistory)[-1]
    }

    if ($this.DiskHistory.Count -gt 0) {
      $latest.Disk = @($this.DiskHistory)[-1]
    }

    return $latest
  }

  [hashtable]GetPerformanceSummary() {
    $duration = (Get-Date) - $this.StartTime

    # Calculate averages
    $avgCPU = if ($this.CPUHistory.Count -gt 0) {
      ($this.CPUHistory | ForEach-Object { $_.Usage } | Measure-Object -Average).Average
    } else { 0 }

    $avgMemory = if ($this.MemoryHistory.Count -gt 0) {
      ($this.MemoryHistory | ForEach-Object { $_.UsagePercent } | Measure-Object -Average).Average
    } else { 0 }

    return @{
      Duration      = $duration
      AverageCPU    = [Math]::Round($avgCPU, 2)
      AverageMemory = [Math]::Round($avgMemory, 2)
      SampleCount   = $this.CPUHistory.Count
      AlertCount    = $this.Alerts.Count
      Alerts        = $this.Alerts
    }
  }
}

# Docker-specific performance monitoring
class DockerPerformanceMonitor {
  [hashtable]$ContainerMetrics
  [hashtable]$ImageMetrics
  [hashtable]$BuildMetrics
  [datetime]$StartTime

  DockerPerformanceMonitor() {
    $this.ContainerMetrics = @{}
    $this.ImageMetrics = @{}
    $this.BuildMetrics = @{}
    $this.StartTime = Get-Date
  }

  [void]MonitorContainerPerformance([string[]]$ContainerNames) {
    foreach ($container in $ContainerNames) {
      try {
        # Get container stats
        $stats = docker stats $container --no-stream --format "{{json .}}" 2>$null
        if ($LASTEXITCODE -eq 0 -and $stats) {
          $statsData = $stats | ConvertFrom-Json

          $this.ContainerMetrics[$container] = @{
            Timestamp     = Get-Date
            CPUPercent    = [double]($statsData.CPUPerc -replace '%', '')
            MemoryUsage   = $statsData.MemUsage
            MemoryPercent = [double]($statsData.MemPerc -replace '%', '')
            NetworkIO     = $statsData.NetIO
            BlockIO       = $statsData.BlockIO
            PIDs          = $statsData.PIDs
          }
        }
      } catch {
        Write-LogMessage -Message "Failed to get stats for container '$container': $($_.Exception.Message)" -Level Warning
      }
    }
  }

  [void]MonitorBuildPerformance([string]$ServiceName, [timespan]$Duration, [bool]$Success) {
    $this.BuildMetrics[$ServiceName] = @{
      Timestamp       = Get-Date
      Duration        = $Duration
      Success         = $Success
      DurationSeconds = $Duration.TotalSeconds
    }
  }

  [hashtable]GetDockerSystemMetrics() {
    try {
      # Get Docker system usage
      $systemDf = docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}" 2>$null

      # Get Docker info
      $dockerInfo = docker info --format "{{json .}}" 2>$null | ConvertFrom-Json

      return @{
        SystemUsage    = $systemDf
        ContainerCount = $dockerInfo.Containers
        ImageCount     = $dockerInfo.Images
        VolumeCount    = $dockerInfo.Volumes
        BuilderCount   = $dockerInfo.Builders
        MemoryLimit    = $dockerInfo.MemTotal
        CPUCount       = $dockerInfo.NCPU
        StorageDriver  = $dockerInfo.Driver
      }
    } catch {
      Write-LogMessage -Message "Failed to get Docker system metrics: $($_.Exception.Message)" -Level Warning
      return @{}
    }
  }

  [hashtable]GetBuildSummary() {
    if ($this.BuildMetrics.Count -eq 0) {
      return @{ TotalBuilds = 0 }
    }

    $successful = ($this.BuildMetrics.Values | Where-Object { $_.Success }).Count
    $failed = $this.BuildMetrics.Count - $successful
    $totalTime = ($this.BuildMetrics.Values | Measure-Object -Property DurationSeconds -Sum).Sum
    $avgTime = ($this.BuildMetrics.Values | Measure-Object -Property DurationSeconds -Average).Average

    return @{
      TotalBuilds        = $this.BuildMetrics.Count
      SuccessfulBuilds   = $successful
      FailedBuilds       = $failed
      TotalTimeSeconds   = $totalTime
      AverageTimeSeconds = [Math]::Round($avgTime, 2)
      SuccessRate        = [Math]::Round(($successful / $this.BuildMetrics.Count) * 100, 2)
      FastestBuild       = ($this.BuildMetrics.Values | Sort-Object DurationSeconds | Select-Object -First 1)
      SlowestBuild       = ($this.BuildMetrics.Values | Sort-Object DurationSeconds -Descending | Select-Object -First 1)
    }
  }
}

# Performance optimization functions
function Optimize-SystemForDocker {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [switch]$AggressiveOptimization
  )

  Write-LogMessage -Message "🚀 Optimizing system for Docker operations..." -Level Performance

  try {
    # Set PowerShell execution policy for performance
    $ProgressPreference = 'SilentlyContinue'
    $ErrorActionPreference = 'SilentlyContinue'

    # Optimize .NET garbage collection for PowerShell
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()

    # Set process priority for current PowerShell session
    $currentProcess = Get-Process -Id $PID
    $currentProcess.PriorityClass = if ($AggressiveOptimization) { 'High' } else { 'AboveNormal' }

    # Configure Docker daemon settings if accessible
    if (Test-DockerAvailability) {
      # Check Docker daemon configuration
      $dockerInfo = Get-DockerSystemInfo
      if ($dockerInfo.Count -gt 0) {
        Write-LogMessage -Message "   💻 Docker CPUs: $($dockerInfo.CPUs), Memory: $($dockerInfo.Memory)GB" -Level Info
        Write-LogMessage -Message "   🗂️  Storage Driver: $($dockerInfo.StorageDriver)" -Level Info
      }
    }

    # Set Windows performance optimizations
    if ($AggressiveOptimization) {
      Write-LogMessage -Message "   ⚡ Applying aggressive optimizations..." -Level Warning

      # Disable Windows Defender real-time protection for build directories (requires admin)
      try {
        if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
          # Add Docker build contexts to exclusions
          $buildPaths = @(
            (Get-Location).Path,
            "$env:TEMP\docker-*",
            "$env:ProgramData\Docker"
          )

          foreach ($path in $buildPaths) {
            if (Test-Path $path) {
              Add-MpPreference -ExclusionPath $path -ErrorAction SilentlyContinue
              Write-LogMessage -Message "   ✅ Added Defender exclusion: $path" -Level Success
            }
          }
        }
      } catch {
        Write-LogMessage -Message "   ⚠️  Could not modify Defender settings (requires admin)" -Level Warning
      }
    }

    Write-LogMessage -Message "✅ System optimization completed" -Level Success
    return $true

  } catch {
    Write-LogMessage -Message "❌ System optimization failed: $($_.Exception.Message)" -Level Error
    return $false
  }
}

function Get-OptimalConcurrencySettings {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [string]$WorkloadType = 'build'  # build, download, cleanup
  )

  # Get system information with safe fallbacks
  try {
    $systemInfo = Get-SystemPerformanceInfo
  } catch {
    # Fallback if Get-SystemPerformanceInfo fails
    $systemInfo = @{
      Performance = @{
        MaxThreads = [Environment]::ProcessorCount
      }
      Memory      = @{
        TotalGB      = 8  # Default fallback
        UsagePercent = 50  # Default fallback
      }
    }
  }

  # Base settings on current system resources with safe type conversion
  $cpuCores = [int]$systemInfo.Performance.MaxThreads
  $memoryGB = [double]$systemInfo.Memory.TotalGB
  $memoryUsagePercent = [double]$systemInfo.Memory.UsagePercent

  # Ensure values are valid
  if ($cpuCores -le 0) { $cpuCores = [Environment]::ProcessorCount }
  if ($memoryGB -le 0) { $memoryGB = 8.0 }
  if ($memoryUsagePercent -lt 0 -or $memoryUsagePercent -gt 100) { $memoryUsagePercent = 50.0 }

  # Adjust based on workload type and available resources
  $settings = switch ($WorkloadType) {
    'build' {
      @{
        MaxConcurrency = [Math]::Min(4, [Math]::Max(1, [Math]::Floor($cpuCores * 0.75)))
        ThrottleLimit  = [Math]::Min(16, $cpuCores * 2)
        MemoryLimit    = [Math]::Floor($memoryGB * 0.6) * 1GB
        BatchSize      = [Math]::Max(1, [Math]::Floor($cpuCores / 3))
      }
    }
    'download' {
      @{
        MaxConcurrency = [Math]::Min(8, $cpuCores)
        ThrottleLimit  = $cpuCores * 3
        MemoryLimit    = [Math]::Floor($memoryGB * 0.3) * 1GB
        BatchSize      = [Math]::Max(2, [Math]::Floor($cpuCores / 2))
      }
    }
    'cleanup' {
      @{
        MaxConcurrency = $cpuCores
        ThrottleLimit  = $cpuCores * 4
        MemoryLimit    = [Math]::Floor($memoryGB * 0.8) * 1GB
        BatchSize      = $cpuCores
      }
    }
    default {
      @{
        MaxConcurrency = [Math]::Max(1, [Math]::Floor($cpuCores / 2))
        ThrottleLimit  = $cpuCores
        MemoryLimit    = [Math]::Floor($memoryGB * 0.5) * 1GB
        BatchSize      = [Math]::Max(1, [Math]::Floor($cpuCores / 4))
      }
    }
  }

  # Adjust for memory pressure
  if ($memoryUsagePercent -gt 80) {
    $settings.MaxConcurrency = [Math]::Max(1, [Math]::Floor($settings.MaxConcurrency * 0.7))
    $settings.ThrottleLimit = [Math]::Max(1, [Math]::Floor($settings.ThrottleLimit * 0.7))
    Write-LogMessage -Message "⚠️  Reducing concurrency due to high memory usage ($($memoryUsagePercent.ToString('F1'))%)" -Level Warning
  }

  $settings.WorkloadType = $WorkloadType
  $settings.SystemInfo = $systemInfo

  return $settings
}

function Start-PerformanceMonitoring {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [int]$IntervalSeconds = 5,

    [Parameter(Mandatory = $false)]
    [string[]]$ContainerNames = @(),

    [Parameter(Mandatory = $false)]
    [switch]$IncludeDockerMetrics
  )

  $monitor = [AdvancedPerformanceMonitor]::new()
  $dockerMonitor = if ($IncludeDockerMetrics) { [DockerPerformanceMonitor]::new() } else { $null }

  $monitor.StartMonitoring()

  Write-LogMessage -Message "🔍 Starting performance monitoring (interval: ${IntervalSeconds}s)..." -Level Performance
  Write-LogMessage -Message "Press Ctrl+C to stop monitoring" -Level Info

  try {
    while ($true) {
      $monitor.CollectMetrics()

      if ($dockerMonitor -and $ContainerNames.Count -gt 0) {
        $dockerMonitor.MonitorContainerPerformance($ContainerNames)
      }

      # Display current metrics
      $current = $monitor.GetCurrentMetrics()
      if ($current.CPU) {
        Write-Host "💻 CPU: $($current.CPU.Usage.ToString('F1'))% | " -NoNewline -ForegroundColor Cyan
      }
      if ($current.Memory) {
        Write-Host "🧠 Memory: $($current.Memory.UsagePercent.ToString('F1'))% | " -NoNewline -ForegroundColor Yellow
      }
      Write-Host "$(Get-Date -Format 'HH:mm:ss')" -ForegroundColor White

      Start-Sleep -Seconds $IntervalSeconds
    }
  } catch {
    Write-LogMessage -Message "Performance monitoring stopped" -Level Info
  } finally {
    $monitor.StopMonitoring()

    # Show summary
    $summary = $monitor.GetPerformanceSummary()
    Write-LogMessage -Message "📊 Performance Summary:" -Level Info
    Write-LogMessage -Message "   Duration: $($summary.Duration.ToString('hh\:mm\:ss'))" -Level Info
    Write-LogMessage -Message "   Average CPU: $($summary.AverageCPU.ToString('F1'))%" -Level Info
    Write-LogMessage -Message "   Average Memory: $($summary.AverageMemory.ToString('F1'))%" -Level Info
    Write-LogMessage -Message "   Samples: $($summary.SampleCount)" -Level Info
    Write-LogMessage -Message "   Alerts: $($summary.AlertCount)" -Level Info
  }
}

function Test-SystemPerformanceCapabilities {
  [CmdletBinding()]
  param()

  Write-LogMessage -Message "🧪 Testing system performance capabilities..." -Level Performance

  $results = @{}

  try {
    # Test CPU performance
    Write-LogMessage -Message "   Testing CPU performance..." -Level Info
    $cpuStart = Get-Date
    $maxThreads = [Environment]::ProcessorCount

    # Use the result to avoid unused variable warning
    $null = 1..1000 | ForEach-Object -Parallel {
      [Math]::Sqrt($_) * [Math]::PI
    } -ThrottleLimit $maxThreads

    $cpuDuration = (Get-Date) - $cpuStart
    $results.CPU = @{
      Duration            = $cpuDuration
      OperationsPerSecond = [Math]::Round(1000 / $cpuDuration.TotalSeconds, 0)
    }

    # Test memory allocation
    Write-LogMessage -Message "   Testing memory allocation..." -Level Info
    $memStart = Get-Date

    # Use the result to avoid unused variable warning
    $null = 1..100 | ForEach-Object {
      $array = New-Object byte[] (1MB)
      $null = $array  # Use the variable to avoid warning
      $array = $null
    }

    $memDuration = (Get-Date) - $memStart
    $results.Memory = @{
      Duration       = $memDuration
      AllocationRate = [Math]::Round(100 / $memDuration.TotalSeconds, 0)
    }

    # Test file I/O
    Write-LogMessage -Message "   Testing file I/O performance..." -Level Info
    $ioStart = Get-Date
    $tempFile = [System.IO.Path]::GetTempFileName()
    $testData = "x" * 1KB
    1..1000 | ForEach-Object {
      $testData | Out-File -FilePath "$tempFile$_" -NoNewline
    }
    1..1000 | ForEach-Object {
      Remove-Item "$tempFile$_" -ErrorAction SilentlyContinue
    }
    $ioDuration = (Get-Date) - $ioStart
    $results.IO = @{
      Duration       = $ioDuration
      FilesPerSecond = [Math]::Round(2000 / $ioDuration.TotalSeconds, 0)  # 1000 writes + 1000 deletes
    }

    # Test network (if Docker is available)
    if (Test-DockerAvailability) {
      Write-LogMessage -Message "   Testing Docker availability..." -Level Info
      $dockerStart = Get-Date
      $dockerTest = docker version --format '{{.Client.Version}}' 2>$null
      $dockerDuration = (Get-Date) - $dockerStart
      $results.Docker = @{
        Duration  = $dockerDuration
        Available = $LASTEXITCODE -eq 0
        Version   = $dockerTest
      }
    }

    # Performance score calculation
    $cpuScore = [Math]::Min(100, $results.CPU.OperationsPerSecond / 10)
    $memScore = [Math]::Min(100, $results.Memory.AllocationRate / 5)
    $ioScore = [Math]::Min(100, $results.IO.FilesPerSecond / 20)
    $overallScore = [Math]::Round(($cpuScore + $memScore + $ioScore) / 3, 0)

    $results.PerformanceScore = @{
      CPU     = $cpuScore
      Memory  = $memScore
      IO      = $ioScore
      Overall = $overallScore
      Rating  = switch ($overallScore) {
        { $_ -ge 80 } { "Excellent" }
        { $_ -ge 60 } { "Good" }
        { $_ -ge 40 } { "Average" }
        { $_ -ge 20 } { "Poor" }
        default { "Very Poor" }
      }
    }

    Write-LogMessage -Message "✅ Performance test completed!" -Level Success
    Write-LogMessage -Message "   📊 Overall Score: $overallScore/100 ($($results.PerformanceScore.Rating))" -Level Info
    Write-LogMessage -Message "   💻 CPU: $($cpuScore.ToString('F0'))/100 ($($results.CPU.OperationsPerSecond) ops/sec)" -Level Info
    Write-LogMessage -Message "   🧠 Memory: $($memScore.ToString('F0'))/100 ($($results.Memory.AllocationRate) allocs/sec)" -Level Info
    Write-LogMessage -Message "   💾 I/O: $($ioScore.ToString('F0'))/100 ($($results.IO.FilesPerSecond) files/sec)" -Level Info

    return $results

  } catch {
    Write-LogMessage -Message "❌ Performance test failed: $($_.Exception.Message)" -Level Error
    return @{ Error = $_.Exception.Message }
  }
}

# Export functions and classes
Export-ModuleMember -Function @(
  'Optimize-SystemForDocker',
  'Get-OptimalConcurrencySettings',
  'Start-PerformanceMonitoring',
  'Test-SystemPerformanceCapabilities'
) -Variable @('PerformanceConfig')
