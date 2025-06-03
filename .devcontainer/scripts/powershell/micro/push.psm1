# filepath: .devcontainer/scripts/powershell/micro/push.psm1
# Single-responsibility: Docker push
function Push {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $dockerPushArgs = @('push', $Image)
  Write-Host "🐳 docker $($dockerPushArgs -join ' ')"
  & docker @dockerPushArgs
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Push
