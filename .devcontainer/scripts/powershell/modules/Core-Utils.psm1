#!/usr/bin/env pwsh
# Core-Utils.psm1 - Core utility functions for DevContainer PowerShell scripts
# Provides foundational functions for logging, performance monitoring, and system utilities

# Set strict mode for maximum performance and error detection
Set-StrictMode -Version Latest

# Performance constants for extreme optimization
$script:MaxThreads = [Environment]::ProcessorCount
$script:ThrottleLimit = $script:MaxThreads * 4  # EXTREME hyper-threading optimization
$script:ParallelBatchSize = [Math]::Max(1, [Math]::Floor($script:MaxThreads / 2))
$script:MemoryThreshold = 0.85  # 85% memory usage threshold

# Color definitions for enhanced UX
$script:Colors = @{
  Red         = 'Red'
  Green       = 'Green'
  Yellow      = 'Yellow'
  Blue        = 'Blue'
  Cyan        = 'Cyan'
  Magenta     = 'Magenta'
  White       = 'White'
  DarkGray    = 'DarkGray'
  DarkRed     = 'DarkRed'
  DarkGreen   = 'DarkGreen'
  DarkYellow  = 'DarkYellow'
  DarkBlue    = 'DarkBlue'
  DarkCyan    = 'DarkCyan'
  DarkMagenta = 'DarkMagenta'
}

# Emoji constants for better visual feedback
$script:Emojis = @{
  Success   = "✅"
  Error     = "❌"
  Warning   = "⚠️"
  Info      = "ℹ️"
  Rocket    = "🚀"
  Gear      = "⚙️"
  Package   = "📦"
  Database  = "🗄️"
  Network   = "🌐"
  Docker    = "🐳"
  Build     = "🏗️"
  Clock     = "⏰"
  Lock      = "🔒"
  Clean     = "🧹"
  Fire      = "🔥"
  Lightning = "⚡"
  Target    = "🎯"
  Chart     = "📊"
  Memory    = "💾"
  CPU       = "💻"
  Progress  = "🔄"
  Complete  = "🎉"
}

# Performance monitoring class
class PerformanceMonitor {
  [datetime]$StartTime
  [hashtable]$Metrics
  [int]$MaxThreads
  [int]$ThrottleLimit

  PerformanceMonitor() {
    $this.StartTime = Get-Date
    $this.Metrics = @{}
    $this.MaxThreads = $script:MaxThreads
    $this.ThrottleLimit = $script:ThrottleLimit
  }

  [void]StartTimer([string]$Name) {
    $this.Metrics[$Name] = @{
      StartTime = Get-Date
      EndTime   = $null
      Duration  = $null
    }
  }

  [void]StopTimer([string]$Name) {
    if ($this.Metrics.ContainsKey($Name)) {
      $this.Metrics[$Name].EndTime = Get-Date
      $this.Metrics[$Name].Duration = $this.Metrics[$Name].EndTime - $this.Metrics[$Name].StartTime
    }
  }

  [timespan]GetDuration([string]$Name) {
    if ($this.Metrics.ContainsKey($Name) -and $this.Metrics[$Name].Duration) {
      return $this.Metrics[$Name].Duration
    }
    return [timespan]::Zero
  }

  [hashtable]GetSummary() {
    $totalDuration = (Get-Date) - $this.StartTime
    return @{
      TotalDuration = $totalDuration
      Metrics       = $this.Metrics
      MaxThreads    = $this.MaxThreads
      ThrottleLimit = $this.ThrottleLimit
    }
  }
}

# Advanced logging function with performance optimization
function Write-LogMessage {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug', 'Performance')]
    [string]$Level = 'Info',

    [Parameter(Mandatory = $false)]
    [string]$Emoji,

    [Parameter(Mandatory = $false)]
    [string]$Color,

    [Parameter(Mandatory = $false)]
    [switch]$NoNewline,

    [Parameter(Mandatory = $false)]
    [switch]$Timestamp
  )

  # Determine emoji and color based on level
  if (-not $Emoji) {
    $Emoji = switch ($Level) {
      'Info' { $script:Emojis.Info }
      'Success' { $script:Emojis.Success }
      'Warning' { $script:Emojis.Warning }
      'Error' { $script:Emojis.Error }
      'Debug' { $script:Emojis.Gear }
      'Performance' { $script:Emojis.Lightning }
      default { $script:Emojis.Info }
    }
  }

  if (-not $Color) {
    $Color = switch ($Level) {
      'Info' { $script:Colors.Cyan }
      'Success' { $script:Colors.Green }
      'Warning' { $script:Colors.Yellow }
      'Error' { $script:Colors.Red }
      'Debug' { $script:Colors.DarkGray }
      'Performance' { $script:Colors.Magenta }
      default { $script:Colors.White }
    }
  }

  # Build message
  $fullMessage = if ($Timestamp) {
    "$Emoji [$(Get-Date -Format 'HH:mm:ss.fff')] $Message"
  } else {
    "$Emoji $Message"
  }

  # Output with specified parameters
  $writeParams = @{
    Object          = $fullMessage
    ForegroundColor = $Color
  }
  if ($NoNewline) { $writeParams.NoNewline = $true }

  Write-Host @writeParams
}

# System information gathering with performance optimization
function Get-SystemPerformanceInfo {
  [CmdletBinding()]
  param()

  try {
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $memory = Get-CimInstance -ClassName Win32_OperatingSystem
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }

    $systemInfo = @{
      CPU         = @{
        Name              = $cpu.Name
        Cores             = $cpu.NumberOfCores
        LogicalProcessors = $cpu.NumberOfLogicalProcessors
        MaxClockSpeed     = $cpu.MaxClockSpeed
      }
      Memory      = @{
        TotalGB      = [Math]::Round($memory.TotalVisibleMemorySize / 1MB, 2)
        FreeGB       = [Math]::Round($memory.FreePhysicalMemory / 1MB, 2)
        UsedGB       = [Math]::Round(($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / 1MB, 2)
        UsagePercent = [Math]::Round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)
      }
      Disk        = $disk | ForEach-Object {
        @{
          Drive        = $_.DeviceID
          TotalGB      = [Math]::Round($_.Size / 1GB, 2)
          FreeGB       = [Math]::Round($_.FreeSpace / 1GB, 2)
          UsedGB       = [Math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)
          UsagePercent = [Math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 2)
        }
      }
      Performance = @{
        MaxThreads        = $script:MaxThreads
        ThrottleLimit     = $script:ThrottleLimit
        ParallelBatchSize = $script:ParallelBatchSize
      }
    }

    return $systemInfo
  } catch {
    Write-LogMessage -Message "Failed to gather system performance info: $($_.Exception.Message)" -Level Error
    return @{}
  }
}

# Enhanced parallel execution with dynamic throttling
function Invoke-UltraParallelExecution {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [array]$Items,

    [Parameter(Mandatory = $true)]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory = $false)]
    [string]$Description = "Processing items",

    [Parameter(Mandatory = $false)]
    [int]$CustomThrottleLimit = $script:ThrottleLimit,

    [Parameter(Mandatory = $false)]
    [int]$CustomBatchSize = $script:ParallelBatchSize,

    [Parameter(Mandatory = $false)]
    [switch]$ShowProgress,

    [Parameter(Mandatory = $false)]
    [switch]$ContinueOnError
  )

  if ($Items.Count -eq 0) {
    Write-LogMessage -Message "No items to process for: $Description" -Level Warning
    return @()
  }

  Write-LogMessage -Message "$Description with ULTRA-PARALLEL processing ($($Items.Count) items)..." -Level Performance

  # Dynamic throttle adjustment based on system resources
  $systemInfo = Get-SystemPerformanceInfo
  if ($systemInfo.Memory.UsagePercent -gt ($script:MemoryThreshold * 100)) {
    $CustomThrottleLimit = [Math]::Max(1, [Math]::Floor($CustomThrottleLimit * 0.7))
    Write-LogMessage -Message "Reducing throttle limit to $CustomThrottleLimit due to high memory usage" -Level Warning
  }

  $results = @()
  $startTime = Get-Date

  try {
    # Split items into optimized batches
    $batches = @()
    for ($i = 0; $i -lt $Items.Count; $i += $CustomBatchSize) {
      $end = [Math]::Min($i + $CustomBatchSize - 1, $Items.Count - 1)
      $batches += , @($Items[$i..$end])
    }

    Write-LogMessage -Message "Processing $($batches.Count) batches with throttle limit: $CustomThrottleLimit" -Level Debug

    # Process batches in parallel with error handling
    $batchResults = $batches | ForEach-Object -Parallel {
      param($batch)

      $batchResults = @()
      $errorCount = 0

      foreach ($item in $batch) {
        try {
          $result = & $using:ScriptBlock $item
          $batchResults += $result
        } catch {
          $errorCount++
          if (-not $using:ContinueOnError) {
            throw "Error processing item '$item': $($_.Exception.Message)"
          }
          Write-Warning "Error processing item '$item': $($_.Exception.Message)"
        }
      }

      return @{
        Results    = $batchResults
        ErrorCount = $errorCount
        BatchSize  = $batch.Count
      }
    } -ThrottleLimit $CustomThrottleLimit

    # Aggregate results
    $totalErrors = 0
    foreach ($batchResult in $batchResults) {
      if ($batchResult.Results) {
        $results += $batchResult.Results
      }
      $totalErrors += $batchResult.ErrorCount
    }

    $duration = (Get-Date) - $startTime
    $successCount = $Items.Count - $totalErrors

    Write-LogMessage -Message "Completed: $successCount/$($Items.Count) items processed successfully in $($duration.TotalSeconds.ToString('F2'))s" -Level Success

    if ($totalErrors -gt 0) {
      Write-LogMessage -Message "Encountered $totalErrors errors during processing" -Level Warning
    }

    return $results

  } catch {
    Write-LogMessage -Message "Critical error in parallel execution: $($_.Exception.Message)" -Level Error
    throw
  }
}

# Docker utilities with enhanced error handling
function Test-DockerAvailability {
  [CmdletBinding()]
  param()

  try {
    $null = docker version --format '{{.Client.Version}}' 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-LogMessage -Message "Docker is available and responding" -Level Success
      return $true
    } else {
      Write-LogMessage -Message "Docker command failed with exit code: $LASTEXITCODE" -Level Error
      return $false
    }
  } catch {
    Write-LogMessage -Message "Docker is not available: $($_.Exception.Message)" -Level Error
    return $false
  }
}

function Get-DockerSystemInfo {
  [CmdletBinding()]
  param()

  if (-not (Test-DockerAvailability)) {
    return @{}
  }

  try {
    $info = docker info --format '{{json .}}' 2>$null | ConvertFrom-Json
    $version = docker version --format '{{json .}}' 2>$null | ConvertFrom-Json

    return @{
      Version       = $version.Client.Version
      ServerVersion = $version.Server.Version
      Architecture  = $version.Client.Arch
      OS            = $version.Client.Os
      Containers    = $info.Containers
      Images        = $info.Images
      CPUs          = $info.NCPU
      Memory        = [Math]::Round($info.MemTotal / 1GB, 2)
      StorageDriver = $info.Driver
      DockerRootDir = $info.DockerRootDir
    }
  } catch {
    Write-LogMessage -Message "Failed to get Docker system info: $($_.Exception.Message)" -Level Warning
    return @{}
  }
}

# Export performance constants
$script:ExportedConstants = @{
  MaxThreads        = $script:MaxThreads
  ThrottleLimit     = $script:ThrottleLimit
  ParallelBatchSize = $script:ParallelBatchSize
  Colors            = $script:Colors
  Emojis            = $script:Emojis
}

# Export functions and classes
Export-ModuleMember -Function @(
  'Write-LogMessage',
  'Get-SystemPerformanceInfo',
  'Invoke-UltraParallelExecution',
  'Test-DockerAvailability',
  'Get-DockerSystemInfo'
) -Variable ExportedConstants
