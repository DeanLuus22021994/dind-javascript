# filepath: .devcontainer/scripts/powershell/micro/images.psm1
# Single-responsibility: Docker images
function Images {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Filter
    )
    $dockerImagesArgs = @('images')
    if ($Filter) { $dockerImagesArgs += $Filter }
    Write-Host "🐳 docker $($dockerImagesArgs -join ' ')"
    & docker @dockerImagesArgs
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Images
