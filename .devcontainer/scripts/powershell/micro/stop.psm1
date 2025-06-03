# filepath: .devcontainer/scripts/powershell/micro/stop.psm1
# Single-responsibility: Docker stop
function Stop {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Container
  )
  $dockerStopArgsList = @('stop', $Container)
  Write-Host "🐳 docker $($dockerStopArgsList -join ' ')"
  & docker @dockerStopArgsList
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Stop
