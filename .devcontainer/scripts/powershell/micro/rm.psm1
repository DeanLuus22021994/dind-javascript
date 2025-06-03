# filepath: .devcontainer/scripts/powershell/micro/rm.psm1
# Single-responsibility: Docker rm (remove container)
function Rm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Container,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    $dockerRmArgs = @('rm')
    if ($Force) { $dockerRmArgs += '-f' }
    $dockerRmArgs += $Container
    Write-Host "🐳 docker $($dockerRmArgs -join ' ')"
    & docker @dockerRmArgs
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Rm
