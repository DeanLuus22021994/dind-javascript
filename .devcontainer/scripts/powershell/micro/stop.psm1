# filepath: .devcontainer/scripts/powershell/micro/stop.psm1
# Single-responsibility: Docker stop
function Stop {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Container
  )
  $dockerStopParams = @('stop', $Container)
  Write-Host "🐳 docker $($dockerStopParams -join ' ')"
  & docker @dockerStopParams
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Stop
