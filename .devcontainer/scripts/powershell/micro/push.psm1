# filepath: .devcontainer/scripts/powershell/micro/push.psm1
# Single-responsibility: Docker push
function Push {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $dockerPushCmd = @('push', $Image)
  Write-Host "🐳 docker $($dockerPushCmd -join ' ')"
  & docker @dockerPushCmd
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Push
