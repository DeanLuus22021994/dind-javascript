# filepath: .devcontainer/scripts/powershell/micro/pull.psm1
# Single-responsibility: Docker pull
function Pull {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $dockerPullParams = @('pull', $Image)
  Write-Host "🐳 docker $($dockerPullParams -join ' ')"
  & docker @dockerPullParams
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Pull
