# filepath: .devcontainer/scripts/powershell/micro/stop.psm1
# Single-responsibility: Docker stop
function Stop {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Container
  )
  $dockerStopCmd = @('stop', $Container)
  Write-Host "🐳 docker $($dockerStopCmd -join ' ')"
  & docker @dockerStopCmd
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Stop
