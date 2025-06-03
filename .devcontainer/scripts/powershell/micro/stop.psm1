# filepath: .devcontainer/scripts/powershell/micro/stop.psm1
# Single-responsibility: Docker stop
function Stop {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Container
    )
    $argsList = @('stop', $Container)
    Write-Host ("🐳 docker {0}" -f ($argsList -join ' '))
    $output = & docker @argsList 2>&1
    $exitCode = $LASTEXITCODE
    if ($output) {
        if ($exitCode -eq 0) {
            Write-Host $output
        } else {
            Write-Error $output
        }
    }
    return ($exitCode -eq 0)
}
Export-ModuleMember -Function Stop
