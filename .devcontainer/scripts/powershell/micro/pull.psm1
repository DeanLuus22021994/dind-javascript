# filepath: .devcontainer/scripts/powershell/micro/pull.psm1
# Single-responsibility: Docker pull
function Pull {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $dockerPullArgs = @('pull', $Image)
  Write-Host "🐳 docker $($dockerPullArgs -join ' ')"
  & docker @dockerPullArgs
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Pull
