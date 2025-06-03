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
    $dockerRmArgsList = @('rm')
    if ($Force) { $dockerRmArgsList += '-f' }
    $dockerRmArgsList += $Container
    Write-Host "🐳 docker $($dockerRmArgsList -join ' ')"
    & docker @dockerRmArgsList
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Rm
