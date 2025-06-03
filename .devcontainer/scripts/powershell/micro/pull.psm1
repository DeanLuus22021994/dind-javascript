# filepath: .devcontainer/scripts/powershell/micro/pull.psm1
# Single-responsibility: Docker pull
function Pull {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $dockerPullArray = @('pull', $Image)
  Write-Host "🐳 docker $($dockerPullArray -join ' ')"
  & docker @dockerPullArray
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Pull
