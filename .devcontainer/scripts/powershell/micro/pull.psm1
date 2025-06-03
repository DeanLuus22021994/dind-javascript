# filepath: .devcontainer/scripts/powershell/micro/pull.psm1
# Single-responsibility: Docker pull
function Pull {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $dockerPullArgsList = @('pull', $Image)
  Write-Host "🐳 docker $($dockerPullArgsList -join ' ')"
  & docker @dockerPullArgsList
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Pull
