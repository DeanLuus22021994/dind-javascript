# filepath: .devcontainer/scripts/powershell/micro/push.psm1
# Single-responsibility: Docker push
function Push {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $dockerPushArgsList = @('push', $Image)
  Write-Host "🐳 docker $($dockerPushArgsList -join ' ')"
  & docker @dockerPushArgsList
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Push
