# filepath: .devcontainer/scripts/powershell/micro/images.psm1
# Single-responsibility: Docker images
function Images {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Filter
    )
    $args = @('images')
    if ($Filter) { $args += $Filter }
    Write-Host "🐳 docker $($args -join ' ')"
    & docker @args
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Images
