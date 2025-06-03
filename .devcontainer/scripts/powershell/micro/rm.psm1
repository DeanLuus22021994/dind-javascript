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
    $args = @('rm')
    if ($Force) { $args += '-f' }
    $args += $Container
    Write-Host "🐳 docker $($args -join ' ')"
    & docker @args
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Rm
