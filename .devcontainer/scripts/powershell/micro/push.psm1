# filepath: .devcontainer/scripts/powershell/micro/push.psm1
# Single-responsibility: Docker push
function Push {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $dockerPushParams = @('push', $Image)
  Write-Host "🐳 docker $($dockerPushParams -join ' ')"
  & docker @dockerPushParams
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Push
