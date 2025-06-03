# filepath: .devcontainer/scripts/powershell/micro/images.psm1
# Single-responsibility: Docker images
function Images {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Filter
    )
    $argsList = @('images')
    if ($Filter) { $argsList += $Filter }
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
Export-ModuleMember -Function Images
