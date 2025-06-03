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
    $argsList = @('run')
    if ($Detach.IsPresent) { $argsList += '-d' }
    if ($Name) { $argsList += '--name'; $argsList += $Name }
    $argsList += $Image
    if ($Args) { $argsList += $Args }
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
Export-ModuleMember -Function Run
