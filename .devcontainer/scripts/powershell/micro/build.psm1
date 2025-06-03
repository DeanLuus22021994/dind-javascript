# filepath: .devcontainer/scripts/powershell/micro/build.psm1
# Single-responsibility: Docker build
function Build {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Context,
        [Parameter(Mandatory = $true)]
        [string]$Dockerfile,
        [Parameter(Mandatory = $true)]
        [string]$Tag,
        [Parameter(Mandatory = $false)]
        [hashtable]$BuildArgs = @{},
        [Parameter(Mandatory = $false)]
        [switch]$NoCache,
        [Parameter(Mandatory = $false)]
        [switch]$Pull
    )
    $args = @('build', '-f', $Dockerfile, '-t', $Tag)
    if ($NoCache) { $args += '--no-cache' }
    if ($Pull) { $args += '--pull' }
    foreach ($key in $BuildArgs.Keys) {
        $args += '--build-arg'; $args += "$key=$($BuildArgs[$key])"
    }
    $args += $Context
    Write-Host "🐳 docker $($args -join ' ')"
    & docker @args
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Build
