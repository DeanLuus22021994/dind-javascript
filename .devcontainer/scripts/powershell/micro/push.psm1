# filepath: .devcontainer/scripts/powershell/micro/push.psm1
# Single-responsibility: Docker push
function Push {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $dockerPushParamsList = @('push', $Image)
  Write-Host "🐳 docker $($dockerPushParamsList -join ' ')"
  & docker @dockerPushParamsList
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Push
