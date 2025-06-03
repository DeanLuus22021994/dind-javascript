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
  $dockerRmCmd = @('rm')
  if ($Force) { $dockerRmCmd += '-f' }
  $dockerRmCmd += $Container
  Write-Host "🐳 docker $($dockerRmCmd -join ' ')"
  & docker @dockerRmCmd
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Rm
