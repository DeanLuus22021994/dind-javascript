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
    $argsList = @('rm')
    if ($Force.IsPresent) { $argsList += '-f' }
    $argsList += $Container
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
Export-ModuleMember -Function Rm
