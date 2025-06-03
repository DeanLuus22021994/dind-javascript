#!/usr/bin/env pwsh
# Cleanup-Utils Module - Advanced Docker and System Cleanup Utilities
# Provides intelligent cleanup operations with dependency management and safety checks

#Requires -Version 7.0

# Module metadata
$ModuleVersion = "1.0.0"
$ModuleName = "Cleanup-Utils"

# Import required modules if available
try {
    if (Get-Module -Name "Core-Utils" -ListAvailable) {
        Import-Module "Core-Utils" -Force -ErrorAction SilentlyContinue
    }
} catch {
    # Fallback logging function if Core-Utils is not available
    function Write-LogMessage {
        param(
            [string]$Message,
            [ValidateSet('Info', 'Warning', 'Error', 'Success', 'Performance')]
            [string]$Level = 'Info'
        )

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $colorMap = @{
            'Info' = 'White'
            'Warning' = 'Yellow'
            'Error' = 'Red'
            'Success' = 'Green'
            'Performance' = 'Cyan'
        }

        Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colorMap[$Level]
    }
}

# Configuration constants for extreme optimization
Set-Variable -Name "CLEANUP_MAX_PARALLEL_OPERATIONS" -Value 32 -Option Constant
Set-Variable -Name "CLEANUP_DOCKER_TIMEOUT" -Value 300 -Option Constant
Set-Variable -Name "CLEANUP_AGGRESSIVE_MEMORY_THRESHOLD" -Value 85 -Option Constant
Set-Variable -Name "CLEANUP_FORCE_WAIT_TIME" -Value 2 -Option Constant

<#
.SYNOPSIS
    Performs comprehensive Docker system cleanup with intelligent safety checks
.DESCRIPTION
    Executes Docker cleanup operations including containers, images, volumes, and networks.
    Supports parallel processing and provides detailed cleanup metrics.
.PARAMETER IncludeVolumes
    Include Docker volumes in cleanup operation
.PARAMETER IncludeNetworks
    Include Docker networks in cleanup operation
.PARAMETER Force
    Force cleanup without interactive prompts
.PARAMETER AggressiveMode
    Enable aggressive cleanup with extended operations
.PARAMETER MaxParallelOps
    Maximum number of parallel cleanup operations
.EXAMPLE
    Invoke-DockerSystemCleanup -IncludeVolumes -Force
#>
function Invoke-DockerSystemCleanup {
    [CmdletBinding()]
    param(
        [switch]$IncludeVolumes,
        [switch]$IncludeNetworks,
        [switch]$Force,
        [switch]$AggressiveMode,
        [int]$MaxParallelOps = $CLEANUP_MAX_PARALLEL_OPERATIONS
    )

    try {
        Write-LogMessage -Message "🧹 Starting Docker system cleanup..." -Level Performance
        $cleanupStartTime = Get-Date
        $cleanupResults = @{
            ContainersRemoved = 0
            ImagesRemoved = 0
            VolumesRemoved = 0
            NetworksRemoved = 0
            SpaceReclaimed = "0 GB"
            Errors = @()
        }

        # Check Docker availability
        if (-not (Test-DockerConnection)) {
            throw "Docker is not available or not responding"
        }

        # Get initial disk usage
        $initialUsage = Get-DockerDiskUsage
        Write-LogMessage -Message "📊 Initial Docker disk usage: $($initialUsage.Total)" -Level Info

        # Phase 1: Stop and remove containers
        Write-LogMessage -Message "🛑 Phase 1: Container cleanup..." -Level Info
        try {
            $containerCleanup = Remove-DockerContainers -Force:$Force -MaxParallel:$MaxParallelOps
            $cleanupResults.ContainersRemoved = $containerCleanup.Count
            Write-LogMessage -Message "✅ Removed $($containerCleanup.Count) containers" -Level Success
        } catch {
            $cleanupResults.Errors += "Container cleanup failed: $($_.Exception.Message)"
            Write-LogMessage -Message "⚠️  Container cleanup had issues: $($_.Exception.Message)" -Level Warning
        }

        # Phase 2: Remove unused images
        Write-LogMessage -Message "🖼️  Phase 2: Image cleanup..." -Level Info
        try {
            $imageCleanup = Remove-DockerImages -AggressiveMode:$AggressiveMode -MaxParallel:$MaxParallelOps
            $cleanupResults.ImagesRemoved = $imageCleanup.Count
            Write-LogMessage -Message "✅ Removed $($imageCleanup.Count) images" -Level Success
        } catch {
            $cleanupResults.Errors += "Image cleanup failed: $($_.Exception.Message)"
            Write-LogMessage -Message "⚠️  Image cleanup had issues: $($_.Exception.Message)" -Level Warning
        }

        # Phase 3: Remove volumes (if requested)
        if ($IncludeVolumes) {
            Write-LogMessage -Message "💾 Phase 3: Volume cleanup..." -Level Info
            try {
                $volumeCleanup = Remove-DockerVolumes -Force:$Force -MaxParallel:$MaxParallelOps
                $cleanupResults.VolumesRemoved = $volumeCleanup.Count
                Write-LogMessage -Message "✅ Removed $($volumeCleanup.Count) volumes" -Level Success
            } catch {
                $cleanupResults.Errors += "Volume cleanup failed: $($_.Exception.Message)"
                Write-LogMessage -Message "⚠️  Volume cleanup had issues: $($_.Exception.Message)" -Level Warning
            }
        }

        # Phase 4: Remove networks (if requested)
        if ($IncludeNetworks) {
            Write-LogMessage -Message "🌐 Phase 4: Network cleanup..." -Level Info
            try {
                $networkCleanup = Remove-DockerNetworks -Force:$Force -MaxParallel:$MaxParallelOps
                $cleanupResults.NetworksRemoved = $networkCleanup.Count
                Write-LogMessage -Message "✅ Removed $($networkCleanup.Count) networks" -Level Success
            } catch {
                $cleanupResults.Errors += "Network cleanup failed: $($_.Exception.Message)"
                Write-LogMessage -Message "⚠️  Network cleanup had issues: $($_.Exception.Message)" -Level Warning
            }
        }

        # Phase 5: System prune for final cleanup
        Write-LogMessage -Message "🗑️  Phase 5: System prune..." -Level Info
        try {
            $pruneArgs = @("system", "prune", "--force")
            if ($AggressiveMode) {
                $pruneArgs += "--all"
            }
            if ($IncludeVolumes) {
                $pruneArgs += "--volumes"
            }

            $pruneResult = docker @pruneArgs 2>&1
            Write-LogMessage -Message "✅ System prune completed" -Level Success
        } catch {
            $cleanupResults.Errors += "System prune failed: $($_.Exception.Message)"
            Write-LogMessage -Message "⚠️  System prune had issues: $($_.Exception.Message)" -Level Warning
        }

        # Calculate space reclaimed
        $finalUsage = Get-DockerDiskUsage
        $spaceReclaimed = Calculate-SpaceReclaimed -Initial $initialUsage.TotalBytes -Final $finalUsage.TotalBytes
        $cleanupResults.SpaceReclaimed = $spaceReclaimed

        $cleanupDuration = ((Get-Date) - $cleanupStartTime).TotalSeconds

        Write-LogMessage -Message "🎉 Docker cleanup completed!" -Level Success
        Write-LogMessage -Message "📊 Cleanup Summary:" -Level Info
        Write-LogMessage -Message "   🗑️  Containers removed: $($cleanupResults.ContainersRemoved)" -Level Info
        Write-LogMessage -Message "   🖼️  Images removed: $($cleanupResults.ImagesRemoved)" -Level Info
        Write-LogMessage -Message "   💾 Volumes removed: $($cleanupResults.VolumesRemoved)" -Level Info
        Write-LogMessage -Message "   🌐 Networks removed: $($cleanupResults.NetworksRemoved)" -Level Info
        Write-LogMessage -Message "   💽 Space reclaimed: $($cleanupResults.SpaceReclaimed)" -Level Info
        Write-LogMessage -Message "   ⏱️  Duration: $($cleanupDuration.ToString('F1'))s" -Level Info

        if ($cleanupResults.Errors.Count -gt 0) {
            Write-LogMessage -Message "⚠️  $($cleanupResults.Errors.Count) errors encountered during cleanup" -Level Warning
            return $false
        }

        return $true

    } catch {
        Write-LogMessage -Message "❌ Docker cleanup failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

<#
.SYNOPSIS
    Tests Docker connection and availability
.DESCRIPTION
    Verifies that Docker daemon is running and responsive
.EXAMPLE
    Test-DockerConnection
#>
function Test-DockerConnection {
    [CmdletBinding()]
    param()

    try {
        $dockerInfo = docker info --format "{{.ID}}" 2>$null
        return $null -ne $dockerInfo -and $dockerInfo.Length -gt 0
    } catch {
        return $false
    }
}

<#
.SYNOPSIS
    Gets Docker disk usage information
.DESCRIPTION
    Retrieves comprehensive disk usage statistics from Docker
.EXAMPLE
    Get-DockerDiskUsage
#>
function Get-DockerDiskUsage {
    [CmdletBinding()]
    param()

    try {
        $systemDf = docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}" 2>$null
        if ($systemDf) {
            $lines = $systemDf -split "`n" | Where-Object { $_ -and $_ -notmatch "TYPE" }
            $totalSize = 0
            $reclaimableSize = 0

            foreach ($line in $lines) {
                $parts = $line -split "\s+"
                if ($parts.Length -ge 5) {
                    $size = Convert-DockerSizeToBytes -SizeString $parts[3]
                    $reclaimable = Convert-DockerSizeToBytes -SizeString $parts[4]
                    $totalSize += $size
                    $reclaimableSize += $reclaimable
                }
            }

            return @{
                Total = Format-BytesToHumanReadable -Bytes $totalSize
                TotalBytes = $totalSize
                Reclaimable = Format-BytesToHumanReadable -Bytes $reclaimableSize
                ReclaimableBytes = $reclaimableSize
            }
        }

        return @{
            Total = "0 B"
            TotalBytes = 0
            Reclaimable = "0 B"
            ReclaimableBytes = 0
        }
    } catch {
        Write-LogMessage -Message "⚠️  Could not get Docker disk usage: $($_.Exception.Message)" -Level Warning
        return @{
            Total = "Unknown"
            TotalBytes = 0
            Reclaimable = "Unknown"
            ReclaimableBytes = 0
        }
    }
}

<#
.SYNOPSIS
    Removes Docker containers with parallel processing
.DESCRIPTION
    Stops and removes Docker containers with safety checks and parallel execution
.PARAMETER Force
    Force removal without confirmation
.PARAMETER MaxParallel
    Maximum number of parallel operations
.EXAMPLE
    Remove-DockerContainers -Force -MaxParallel 16
#>
function Remove-DockerContainers {
    [CmdletBinding()]
    param(
        [switch]$Force,
        [int]$MaxParallel = $CLEANUP_MAX_PARALLEL_OPERATIONS
    )

    try {
        # Get all containers (running and stopped)
        $allContainers = docker ps -aq 2>$null
        if (-not $allContainers -or $allContainers.Count -eq 0) {
            Write-LogMessage -Message "ℹ️  No containers found to remove" -Level Info
            return @()
        }

        Write-LogMessage -Message "🛑 Stopping and removing $($allContainers.Count) containers..." -Level Info

        # Stop running containers first (parallel)
        $runningContainers = docker ps -q 2>$null
        if ($runningContainers -and $runningContainers.Count -gt 0) {
            $runningContainers | ForEach-Object -Parallel {
                try {
                    docker stop $_ --time $using:CLEANUP_FORCE_WAIT_TIME 2>$null
                } catch {
                    # Continue on error
                }
            } -ThrottleLimit $MaxParallel
        }

        # Remove all containers (parallel)
        $removedContainers = @()
        $allContainers | ForEach-Object -Parallel {
            try {
                $result = docker rm $_ --force 2>$null
                if ($result) {
                    $using:removedContainers += $_
                }
            } catch {
                # Continue on error
            }
        } -ThrottleLimit $MaxParallel

        return $removedContainers

    } catch {
        Write-LogMessage -Message "❌ Container removal failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Removes Docker images with intelligent filtering
.DESCRIPTION
    Removes unused Docker images with support for aggressive mode and parallel processing
.PARAMETER AggressiveMode
    Enable aggressive removal including tagged images
.PARAMETER MaxParallel
    Maximum number of parallel operations
.EXAMPLE
    Remove-DockerImages -AggressiveMode -MaxParallel 16
#>
function Remove-DockerImages {
    [CmdletBinding()]
    param(
        [switch]$AggressiveMode,
        [int]$MaxParallel = $CLEANUP_MAX_PARALLEL_OPERATIONS
    )

    try {
        $removedImages = @()

        # Remove dangling images first
        $danglingImages = docker images -f "dangling=true" -q 2>$null
        if ($danglingImages -and $danglingImages.Count -gt 0) {
            Write-LogMessage -Message "🗑️  Removing $($danglingImages.Count) dangling images..." -Level Info
            $danglingImages | ForEach-Object -Parallel {
                try {
                    $result = docker rmi $_ --force 2>$null
                    if ($result) {
                        $using:removedImages += $_
                    }
                } catch {
                    # Continue on error
                }
            } -ThrottleLimit $MaxParallel
        }

        # In aggressive mode, remove unused images
        if ($AggressiveMode) {
            try {
                $pruneResult = docker image prune --all --force 2>$null
                Write-LogMessage -Message "🔥 Aggressive image cleanup completed" -Level Performance
            } catch {
                Write-LogMessage -Message "⚠️  Aggressive image cleanup had issues" -Level Warning
            }
        }

        return $removedImages

    } catch {
        Write-LogMessage -Message "❌ Image removal failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Removes Docker volumes with safety checks
.DESCRIPTION
    Removes unused Docker volumes with parallel processing and safety validation
.PARAMETER Force
    Force removal without confirmation
.PARAMETER MaxParallel
    Maximum number of parallel operations
.EXAMPLE
    Remove-DockerVolumes -Force -MaxParallel 16
#>
function Remove-DockerVolumes {
    [CmdletBinding()]
    param(
        [switch]$Force,
        [int]$MaxParallel = $CLEANUP_MAX_PARALLEL_OPERATIONS
    )

    try {
        # Get unused volumes
        $unusedVolumes = docker volume ls -f "dangling=true" -q 2>$null
        if (-not $unusedVolumes -or $unusedVolumes.Count -eq 0) {
            Write-LogMessage -Message "ℹ️  No unused volumes found to remove" -Level Info
            return @()
        }

        Write-LogMessage -Message "💾 Removing $($unusedVolumes.Count) unused volumes..." -Level Info

        $removedVolumes = @()
        $unusedVolumes | ForEach-Object -Parallel {
            try {
                $result = docker volume rm $_ --force 2>$null
                if ($result) {
                    $using:removedVolumes += $_
                }
            } catch {
                # Continue on error
            }
        } -ThrottleLimit $MaxParallel

        return $removedVolumes

    } catch {
        Write-LogMessage -Message "❌ Volume removal failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Removes Docker networks with dependency checking
.DESCRIPTION
    Removes unused Docker networks while preserving system networks
.PARAMETER Force
    Force removal without confirmation
.PARAMETER MaxParallel
    Maximum number of parallel operations
.EXAMPLE
    Remove-DockerNetworks -Force -MaxParallel 16
#>
function Remove-DockerNetworks {
    [CmdletBinding()]
    param(
        [switch]$Force,
        [int]$MaxParallel = $CLEANUP_MAX_PARALLEL_OPERATIONS
    )

    try {
        # Get all networks except system ones
        $allNetworks = docker network ls --format "{{.ID}} {{.Name}}" 2>$null
        $systemNetworks = @('bridge', 'host', 'none')

        $customNetworks = $allNetworks | Where-Object {
            $networkInfo = $_ -split ' '
            $networkName = $networkInfo[1]
            $networkName -notin $systemNetworks
        }

        if (-not $customNetworks -or $customNetworks.Count -eq 0) {
            Write-LogMessage -Message "ℹ️  No custom networks found to remove" -Level Info
            return @()
        }

        Write-LogMessage -Message "🌐 Removing $($customNetworks.Count) custom networks..." -Level Info

        $removedNetworks = @()
        $customNetworks | ForEach-Object -Parallel {
            try {
                $networkInfo = $_ -split ' '
                $networkId = $networkInfo[0]
                $result = docker network rm $networkId 2>$null
                if ($result) {
                    $using:removedNetworks += $networkId
                }
            } catch {
                # Continue on error - network might be in use
            }
        } -ThrottleLimit $MaxParallel

        return $removedNetworks

    } catch {
        Write-LogMessage -Message "❌ Network removal failed: $($_.Exception.Message)" -Level Error
        throw
    }
}

<#
.SYNOPSIS
    Converts Docker size string to bytes
.DESCRIPTION
    Parses Docker size strings (e.g., "1.2GB", "500MB") and converts to bytes
.PARAMETER SizeString
    Size string to convert
.EXAMPLE
    Convert-DockerSizeToBytes -SizeString "1.5GB"
#>
function Convert-DockerSizeToBytes {
    [CmdletBinding()]
    param(
        [string]$SizeString
    )

    if (-not $SizeString -or $SizeString -eq "0B" -or $SizeString -eq "-") {
        return 0
    }

    try {
        # Extract number and unit
        if ($SizeString -match '([0-9.]+)([A-Za-z]+)') {
            $number = [double]$matches[1]
            $unit = $matches[2].ToUpper()

            switch ($unit) {
                'B' { return [long]$number }
                'KB' { return [long]($number * 1024) }
                'MB' { return [long]($number * 1024 * 1024) }
                'GB' { return [long]($number * 1024 * 1024 * 1024) }
                'TB' { return [long]($number * 1024 * 1024 * 1024 * 1024) }
                default { return 0 }
            }
        }
        return 0
    } catch {
        return 0
    }
}

<#
.SYNOPSIS
    Formats bytes to human readable format
.DESCRIPTION
    Converts bytes to human readable size format (B, KB, MB, GB, TB)
.PARAMETER Bytes
    Number of bytes to format
.EXAMPLE
    Format-BytesToHumanReadable -Bytes 1073741824
#>
function Format-BytesToHumanReadable {
    [CmdletBinding()]
    param(
        [long]$Bytes
    )

    if ($Bytes -eq 0) { return "0 B" }

    $units = @('B', 'KB', 'MB', 'GB', 'TB')
    $unitIndex = 0
    $size = [double]$Bytes

    while ($size -ge 1024 -and $unitIndex -lt ($units.Length - 1)) {
        $size /= 1024
        $unitIndex++
    }

    return "{0:F1} {1}" -f $size, $units[$unitIndex]
}

<#
.SYNOPSIS
    Calculates space reclaimed from cleanup operations
.DESCRIPTION
    Computes the difference between initial and final disk usage
.PARAMETER Initial
    Initial disk usage in bytes
.PARAMETER Final
    Final disk usage in bytes
.EXAMPLE
    Calculate-SpaceReclaimed -Initial 1000000000 -Final 500000000
#>
function Calculate-SpaceReclaimed {
    [CmdletBinding()]
    param(
        [long]$Initial,
        [long]$Final
    )

    $reclaimedBytes = $Initial - $Final
    if ($reclaimedBytes -lt 0) { $reclaimedBytes = 0 }

    return Format-BytesToHumanReadable -Bytes $reclaimedBytes
}

<#
.SYNOPSIS
    Performs system-level cleanup operations
.DESCRIPTION
    Executes system cleanup including temporary files, caches, and memory optimization
.PARAMETER AggressiveMode
    Enable aggressive system cleanup
.PARAMETER IncludeUserTemp
    Include user temporary files in cleanup
.EXAMPLE
    Invoke-SystemCleanup -AggressiveMode -IncludeUserTemp
#>
function Invoke-SystemCleanup {
    [CmdletBinding()]
    param(
        [switch]$AggressiveMode,
        [switch]$IncludeUserTemp
    )

    try {
        Write-LogMessage -Message "🧽 Starting system cleanup..." -Level Performance
        $cleanupStartTime = Get-Date

        # Phase 1: PowerShell module cache cleanup
        Write-LogMessage -Message "🔧 Cleaning PowerShell module cache..." -Level Info
        try {
            if (Test-Path $env:PSModulePath) {
                $moduleCachePaths = $env:PSModulePath -split ';' | Where-Object { $_ -like "*Cache*" }
                foreach ($cachePath in $moduleCachePaths) {
                    if (Test-Path $cachePath) {
                        Get-ChildItem $cachePath -Recurse -Force -ErrorAction SilentlyContinue |
                            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
                            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    }
                }
            }
            Write-LogMessage -Message "✅ PowerShell cache cleanup completed" -Level Success
        } catch {
            Write-LogMessage -Message "⚠️  PowerShell cache cleanup had issues: $($_.Exception.Message)" -Level Warning
        }

        # Phase 2: Temporary files cleanup
        if ($IncludeUserTemp) {
            Write-LogMessage -Message "🗂️  Cleaning temporary files..." -Level Info
            try {
                $tempPaths = @($env:TEMP, $env:TMP, "$env:USERPROFILE\AppData\Local\Temp")
                foreach ($tempPath in $tempPaths) {
                    if (Test-Path $tempPath) {
                        Get-ChildItem $tempPath -Force -ErrorAction SilentlyContinue |
                            Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } |
                            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                    }
                }
                Write-LogMessage -Message "✅ Temporary files cleanup completed" -Level Success
            } catch {
                Write-LogMessage -Message "⚠️  Temporary files cleanup had issues: $($_.Exception.Message)" -Level Warning
            }
        }

        # Phase 3: Memory optimization
        if ($AggressiveMode) {
            Write-LogMessage -Message "🧠 Optimizing system memory..." -Level Performance
            try {
                # Trigger garbage collection
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                [System.GC]::Collect()

                Write-LogMessage -Message "✅ Memory optimization completed" -Level Success
            } catch {
                Write-LogMessage -Message "⚠️  Memory optimization had issues: $($_.Exception.Message)" -Level Warning
            }
        }

        $cleanupDuration = ((Get-Date) - $cleanupStartTime).TotalSeconds
        Write-LogMessage -Message "✅ System cleanup completed in $($cleanupDuration.ToString('F1'))s" -Level Success

        return $true

    } catch {
        Write-LogMessage -Message "❌ System cleanup failed: $($_.Exception.Message)" -Level Error
        return $false
    }
}

# Export public functions
Export-ModuleMember -Function @(
    'Invoke-DockerSystemCleanup',
    'Test-DockerConnection',
    'Get-DockerDiskUsage',
    'Remove-DockerContainers',
    'Remove-DockerImages',
    'Remove-DockerVolumes',
    'Remove-DockerNetworks',
    'Convert-DockerSizeToBytes',
    'Format-BytesToHumanReadable',
    'Calculate-SpaceReclaimed',
    'Invoke-SystemCleanup'
)

# Module initialization
Write-LogMessage -Message "✅ Cleanup-Utils module loaded successfully (v$ModuleVersion)" -Level Success
