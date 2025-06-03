# filepath: .devcontainer/scripts/powershell/micro/stop.psm1
# Single-responsibility: Docker stop
function Stop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Container
    )
    $args = @('stop', $Container)
    Write-Host "🐳 docker $($args -join ' ')"
    & docker @args
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Stop
