# filepath: .devcontainer/scripts/powershell/micro/rm.psm1
# Single-responsibility: Docker rm (remove container)
function Rm {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Container,
    [Parameter(Mandatory = $false)]
    [switch]$Force
  )
  $dockerRmParams = @('rm')
  if ($Force) { $dockerRmParams += '-f' }
  $dockerRmParams += $Container
  Write-Host "🐳 docker $($dockerRmParams -join ' ')"
  & docker @dockerRmParams
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Rm
