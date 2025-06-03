# filepath: .devcontainer/scripts/powershell/micro/stop.psm1
# Single-responsibility: Docker stop
function Stop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Container
    )
    $dockerStopArgs = @('stop', $Container)
    Write-Host "🐳 docker $($dockerStopArgs -join ' ')"
    & docker @dockerStopArgs
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Stop
