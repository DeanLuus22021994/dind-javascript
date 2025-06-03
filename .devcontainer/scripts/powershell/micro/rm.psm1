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
  $dockerRmList = @('rm')
  if ($Force) { $dockerRmList += '-f' }
  $dockerRmList += $Container
  Write-Host "🐳 docker $($dockerRmList -join ' ')"
  & docker @dockerRmList
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Rm
