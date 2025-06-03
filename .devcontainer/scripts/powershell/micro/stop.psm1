# filepath: .devcontainer/scripts/powershell/micro/stop.psm1
# Single-responsibility: Docker stop
function Stop {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Container
  )
  $dockerStopCmdList = @('stop', $Container)
  Write-Host "🐳 docker $($dockerStopCmdList -join ' ')"
  & docker @dockerStopCmdList
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Stop
