# filepath: .devcontainer/scripts/powershell/micro/pull.psm1
# Single-responsibility: Docker pull
function Pull {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Image
    )
    $args = @('pull', $Image)
    Write-Host "🐳 docker $($args -join ' ')"
    & docker @args
    return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Pull
