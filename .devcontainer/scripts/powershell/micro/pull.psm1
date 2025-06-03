# filepath: .devcontainer/scripts/powershell/micro/pull.psm1
# Single-responsibility: Docker pull
function Pull {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $dockerPullCmd = @('pull', $Image)
  Write-Host "🐳 docker $($dockerPullCmd -join ' ')"
  & docker @dockerPullCmd
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Pull
