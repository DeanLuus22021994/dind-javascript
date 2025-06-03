# filepath: .devcontainer/scripts/powershell/micro/push.psm1
# Single-responsibility: Docker push
function Push {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Image
    )
    $argsList = @('push', $Image)
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
Export-ModuleMember -Function Push
