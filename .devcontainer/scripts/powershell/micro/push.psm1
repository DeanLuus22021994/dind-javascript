# filepath: .devcontainer/scripts/powershell/micro/push.psm1
# Single-responsibility: Docker push
function Push {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Image
    )
    $args = @('push', $Image)
    Write-Host "🐳 docker $($args -join ' ')"
    & docker @args
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Push
