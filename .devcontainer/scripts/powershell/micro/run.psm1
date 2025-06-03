# filepath: .devcontainer/scripts/powershell/micro/run.psm1
# Single-responsibility: Docker run
function Run {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Image,
        [Parameter(Mandatory = $false)]
        [string[]]$Args = @(),
        [Parameter(Mandatory = $false)]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        [switch]$Detach
    )
    $cmd = @('run')
    if ($Detach) { $cmd += '-d' }
    if ($Name) { $cmd += '--name'; $cmd += $Name }
    $cmd += $Image
    if ($Args) { $cmd += $Args }
    Write-Host "🐳 docker $($cmd -join ' ')"
    & docker @cmd
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Run
