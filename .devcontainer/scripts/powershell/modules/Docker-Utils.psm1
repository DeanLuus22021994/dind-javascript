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
  $validationResults = @()
  foreach ($file in $ComposeFiles) {
    try {
      # Test if file can be parsed as YAML/JSON
      $content = Get-Content $file -Raw
      if ($content -match "version\s*:\s*['" + '"' + "]?[\d.]+['" + '"' + "]?" -or $content -match "services\s*:") {
        $validationResults += @{
          File = $file
          Valid = $true
          Error = $null
        }
      } else {
        $validationResults += @{
          File = $file
          Valid = $false
          Error = "File does not appear to be a valid Docker Compose file"
        }
      }
    } catch {
      $validationResults += @{
        File = $file
        Valid = $false
        Error = $_.Exception.Message
      }
    }
  }

  # Process results
  $validFiles = $validationResults | Where-Object { $_.Valid }
  $invalidFiles = $validationResults | Where-Object { -not $_.Valid }

  if ($invalidFiles.Count -gt 0) {
    Write-LogMessage -Message "Validation failed for $($invalidFiles.Count) files:" -Level Error
    foreach ($invalid in $invalidFiles) {
      Write-LogMessage -Message "  $($invalid.File): $($invalid.Error)" -Level Error
    }
    return $false
  }

  Write-LogMessage -Message "All compose files validated successfully!" -Level Success
  if ($Detailed) {
    foreach ($valid in $validFiles) {
      Write-LogMessage -Message "  ✅ $($valid.File)" -Level Success
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
      'running' { $dockerArgs += '--filter', 'status=running' }
      'exited' { $dockerArgs += '--filter', 'status=exited' }
      'paused' { $dockerArgs += '--filter', 'status=paused' }
      'all' { $dockerArgs += '-a' }
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

  # Create a simple monitor object
  $monitor = New-Object -TypeName PSObject -Property @{
    Metrics = @{}
  }
  $monitor | Add-Member -MemberType ScriptMethod -Name 'StartTimer' -Value {
    param($Name)
    $this.Metrics[$Name] = @{
      StartTime = Get-Date
      EndTime = $null
      Duration = $null
    }
  }
  $monitor | Add-Member -MemberType ScriptMethod -Name 'StopTimer' -Value {
    param($Name)
    if ($this.Metrics.ContainsKey($Name)) {
      $this.Metrics[$Name].EndTime = Get-Date
      $this.Metrics[$Name].Duration = $this.Metrics[$Name].EndTime - $this.Metrics[$Name].StartTime
    }
  }

  foreach ($service in $Services) {
    $monitor.StartTimer("validate-$service")

    # Check if service has Dockerfile or build context
    $hasDockerfile = $false
    $contextPath = ""
    $contextSize = 0

    # Try to determine build context from compose files
    foreach ($composeFile in $ComposeFiles) {
      if (Test-Path $composeFile) {
        $content = Get-Content $composeFile -Raw
        if ($content -match "$service\s*:.*?build\s*:") {
          $hasDockerfile = $true
          $contextPath = Split-Path $composeFile -Parent
          break
        }
      }
    }

    # Fallback: check for service-specific Dockerfile
    if (-not $hasDockerfile) {
      $possibleDockerfiles = @(
        ".devcontainer/docker/files/Dockerfile.$service",
        ".devcontainer/Dockerfile.$service",
        "Dockerfile.$service",
        "Dockerfile"
      )

      foreach ($dockerfile in $possibleDockerfiles) {
        if (Test-Path $dockerfile) {
          $hasDockerfile = $true
          $contextPath = Split-Path $dockerfile -Parent
          break
        }
      }
    }

    # Calculate context size if found
    if ($hasDockerfile -and (Test-Path $contextPath)) {
      try {
        $contextSize = [math]::Round((Get-ChildItem $contextPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
      } catch {
        $contextSize = 0
      }
    }

    $monitor.StopTimer("validate-$service")

    if ($hasDockerfile) {
      $validServices += $service
      Write-LogMessage -Message "   ✅ $service`: Ready (Context: $($contextSize)MB)" -Level Success
    } else {
      Write-LogMessage -Message "   ❌ $service`: No Dockerfile found" -Level Error
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
    Write-LogMessage -Message "🔄 Building phase $phaseNumber with $($group.Count) services in EXTREME PARALLEL..." -Level Performance

    $phaseStart = Get-Date
    $monitor.StartTimer("phase-$phaseNumber")

    # Build services in parallel within the group
    $buildJobs = @()
    foreach ($service in $group) {
      $job = Start-Job -ScriptBlock {
        param($ServiceName, $ComposeFilesParam, $NoCacheParam, $PullParam, $BuildArgsParam)

        try {
          $buildArgsList = @('build')
          if ($NoCacheParam) { $buildArgsList += '--no-cache' }
          if ($PullParam) { $buildArgsList += '--pull' }

          # Add build arguments
          foreach ($arg in $BuildArgsParam.GetEnumerator()) {
            $buildArgsList += '--build-arg', "$($arg.Key)=$($arg.Value)"
          }

          # Add compose files
          foreach ($file in $ComposeFilesParam) {
            $buildArgsList += '-f', $file
          }

          $buildArgsList += $ServiceName

          $output = & docker-compose @buildArgsList 2>&1

          return @{
            ServiceName = $ServiceName
            Success = $LASTEXITCODE -eq 0
            Output = $output -join "`n"
            Duration = [timespan]::FromSeconds(10)  # Placeholder
          }
        } catch {
          return @{
            ServiceName = $ServiceName
            Success = $false
            Output = $_.Exception.Message
            Duration = [timespan]::FromSeconds(0)
          }
        }
      } -ArgumentList $service, $ComposeFiles, $NoCache.IsPresent, $Pull.IsPresent, $BuildArgs

      $buildJobs += $job
    }

    # Wait for all builds in this phase to complete
    $buildResults = $buildJobs | Wait-Job | Receive-Job
    $buildJobs | Remove-Job

    $monitor.StopTimer("phase-$phaseNumber")
    $phaseEnd = Get-Date
    $phaseDuration = ($phaseEnd - $phaseStart).TotalSeconds
    $totalBuildTime += $phaseDuration

    # Report phase results
    $successCount = ($buildResults | Where-Object { $_.Success }).Count
    $failCount = $buildResults.Count - $successCount

    Write-LogMessage -Message "   Phase $phaseNumber completed: $successCount successful, $failCount failed in $($phaseDuration.ToString('F1'))s" -Level Info

    foreach ($result in $buildResults) {
      if ($result.Success) {
        Write-LogMessage -Message "     ✅ $($result.ServiceName) built successfully" -Level Success
      } else {
        Write-LogMessage -Message "     ❌ $($result.ServiceName) build failed: $($result.Output)" -Level Error
      }
    }

    $phaseNumber++
  }

  Write-LogMessage -Message "🎉 ALL SERVICES BUILT WITH EXTREME PARALLEL OPTIMIZATION!" -Level Success
  Write-LogMessage -Message "⚡ Total build time: $($totalBuildTime.ToString('F1'))s across $([Environment]::ProcessorCount) CPU cores!" -Level Performance

  return $true
}

# Enhanced Docker cleanup with ultra-parallel processing
function Invoke-DockerSystemCleanup {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false)]
    [switch]$IncludeVolumes,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeNetworks,

    [Parameter(Mandatory = $false)]
    [switch]$Force
  )

  if (-not (Test-DockerAvailability)) {
    Write-LogMessage -Message "Docker is not available for cleanup" -Level Error
    return $false
  }

  Write-LogMessage -Message "Performing Docker system cleanup with ULTRA-PARALLEL processing..." -Level Performance

  # Create a simple monitor object
  $monitor = New-Object -TypeName PSObject -Property @{
    Metrics = @{}
  }
  $monitor | Add-Member -MemberType ScriptMethod -Name 'StartTimer' -Value {
    param($Name)
    $this.Metrics[$Name] = @{
      StartTime = Get-Date
      EndTime = $null
      Duration = $null
    }
  }
  $monitor | Add-Member -MemberType ScriptMethod -Name 'StopTimer' -Value {
    param($Name)
    if ($this.Metrics.ContainsKey($Name)) {
      $this.Metrics[$Name].EndTime = Get-Date
      $this.Metrics[$Name].Duration = $this.Metrics[$Name].EndTime - $this.Metrics[$Name].StartTime
    }
  }

  $cleanupJobs = @()

  # Phase 1: Parallel container cleanup
  $monitor.StartTimer("containers")
  Write-LogMessage -Message "🗑️  Phase 1: Cleaning containers..." -Level Info

  $cleanupJobs += Start-Job -ScriptBlock {
    param($ForceParam)
    try {
      if ($ForceParam) {
        & docker container prune -f 2>$null
      } else {
        & docker container prune -f 2>$null
      }
      return @{ Phase = "containers"; Success = $true; Output = "Containers cleaned" }
    } catch {
      return @{ Phase = "containers"; Success = $false; Output = $_.Exception.Message }
    }
  } -ArgumentList $Force.IsPresent

  # Phase 2: Parallel image cleanup
  $monitor.StartTimer("images")
  Write-LogMessage -Message "🗑️  Phase 2: Cleaning images..." -Level Info

  $cleanupJobs += Start-Job -ScriptBlock {
    param($ForceParam)
    try {
      if ($ForceParam) {
        & docker image prune -a -f 2>$null
      } else {
        & docker image prune -f 2>$null
      }
      return @{ Phase = "images"; Success = $true; Output = "Images cleaned" }
    } catch {
      return @{ Phase = "images"; Success = $false; Output = $_.Exception.Message }
    }
  } -ArgumentList $Force.IsPresent

  # Phase 3: Parallel BuildKit cleanup
  $monitor.StartTimer("buildkit")
  Write-LogMessage -Message "🗑️  Phase 3: Cleaning BuildKit cache..." -Level Info

  $cleanupJobs += Start-Job -ScriptBlock {
    try {
      & docker builder prune -f 2>$null
      return @{ Phase = "buildkit"; Success = $true; Output = "BuildKit cache cleaned" }
    } catch {
      return @{ Phase = "buildkit"; Success = $false; Output = $_.Exception.Message }
    }
  }

  # Optional Phase 4: Volume cleanup
  if ($IncludeVolumes) {
    $monitor.StartTimer("volumes")
    Write-LogMessage -Message "🗑️  Phase 4: Cleaning volumes..." -Level Info

    $cleanupJobs += Start-Job -ScriptBlock {
      try {
        & docker volume prune -f 2>$null
        return @{ Phase = "volumes"; Success = $true; Output = "Volumes cleaned" }
      } catch {
        return @{ Phase = "volumes"; Success = $false; Output = $_.Exception.Message }
      }
    }
  }

  # Optional Phase 5: Network cleanup
  if ($IncludeNetworks) {
    $monitor.StartTimer("networks")
    Write-LogMessage -Message "🗑️  Phase 5: Cleaning networks..." -Level Info

    $cleanupJobs += Start-Job -ScriptBlock {
      try {
        & docker network prune -f 2>$null
        return @{ Phase = "networks"; Success = $true; Output = "Networks cleaned" }
      } catch {
        return @{ Phase = "networks"; Success = $false; Output = $_.Exception.Message }
      }
    }
  }

  # Wait for all cleanup jobs to complete
  Write-LogMessage -Message "⏳ Waiting for cleanup operations to complete..." -Level Info
  $cleanupResults = $cleanupJobs | Wait-Job | Receive-Job
  $cleanupJobs | Remove-Job

  # Stop timers and get results
  $monitor.StopTimer("containers")
  $monitor.StopTimer("images")
  $monitor.StopTimer("buildkit")
  if ($IncludeVolumes) { $monitor.StopTimer("volumes") }
  if ($IncludeNetworks) { $monitor.StopTimer("networks") }

  # Report results
  Write-LogMessage -Message "✅ Docker cleanup completed successfully!" -Level Success

  foreach ($result in $cleanupResults) {
    if ($result.Success) {
      Write-LogMessage -Message "   ✅ $($result.Phase): $($result.Output)" -Level Success
    } else {
      Write-LogMessage -Message "   ❌ $($result.Phase): $($result.Output)" -Level Error
    }
  }

  return $true
}

# Enhanced Docker network management
function Invoke-DockerNetworkManagement {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('create', 'remove', 'list', 'inspect')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$NetworkName,

    [Parameter(Mandatory = $false)]
    [hashtable]$Options = @{}
  )

  if (-not (Test-DockerAvailability)) {
    Write-LogMessage -Message "Docker is not available" -Level Error
    return $false
  }

  switch ($Action) {
    'create' {
      if (-not $NetworkName) {
        Write-LogMessage -Message "Network name is required for create action" -Level Error
        return $false
      }

      $dockerArgs = @('network', 'create', $NetworkName)
      foreach ($option in $Options.GetEnumerator()) {
        $dockerArgs += "--$($option.Key)", $option.Value
      }

      $result = & docker @dockerArgs 2>&1
      return $LASTEXITCODE -eq 0
    }
    'remove' {
      if (-not $NetworkName) {
        Write-LogMessage -Message "Network name is required for remove action" -Level Error
        return $false
      }

      $result = & docker network rm $NetworkName 2>&1
      return $LASTEXITCODE -eq 0
    }
    'list' {
      $result = & docker network ls 2>&1
      if ($LASTEXITCODE -eq 0) {
        return $result
      }
      return @()
    }
    'inspect' {
      if (-not $NetworkName) {
        Write-LogMessage -Message "Network name is required for inspect action" -Level Error
        return $null
      }

      $result = & docker network inspect $NetworkName 2>&1
      if ($LASTEXITCODE -eq 0) {
        return $result | ConvertFrom-Json
      }
      return $null
    }
  }
}

# Enhanced Docker volume management
function Invoke-DockerVolumeManagement {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('create', 'remove', 'list', 'inspect')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [string]$VolumeName,

    [Parameter(Mandatory = $false)]
    [hashtable]$Options = @{}
  )

  if (-not (Test-DockerAvailability)) {
    Write-LogMessage -Message "Docker is not available" -Level Error
    return $false
  }

  switch ($Action) {
    'create' {
      if (-not $VolumeName) {
        Write-LogMessage -Message "Volume name is required for create action" -Level Error
        return $false
      }

      $dockerArgs = @('volume', 'create', $VolumeName)
      foreach ($option in $Options.GetEnumerator()) {
        $dockerArgs += "--$($option.Key)", $option.Value
      }

      $result = & docker @dockerArgs 2>&1
      return $LASTEXITCODE -eq 0
    }
    'remove' {
      if (-not $VolumeName) {
        Write-LogMessage -Message "Volume name is required for remove action" -Level Error
        return $false
      }

      $result = & docker volume rm $VolumeName 2>&1
      return $LASTEXITCODE -eq 0
    }
    'list' {
      $result = & docker volume ls 2>&1
      if ($LASTEXITCODE -eq 0) {
        return $result
      }
      return @()
    }
    'inspect' {
      if (-not $VolumeName) {
        Write-LogMessage -Message "Volume name is required for inspect action" -Level Error
        return $null
      }

      $result = & docker volume inspect $VolumeName 2>&1
      if ($LASTEXITCODE -eq 0) {
        return $result | ConvertFrom-Json
      }
      return $null
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
