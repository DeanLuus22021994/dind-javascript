# filepath: .devcontainer/scripts/powershell/micro/run.psm1
# Single-responsibility: Docker run
function Run {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image,
    [Parameter(Mandatory = $false)]
    [string[]]$Args = @(),
    [Parameter(Mandatory = $false)]
    [string]$Name,
    [Parameter(Mandatory = $false)]
    [switch]$Detach
  )
  $dockerRunArgs = @('run')
  if ($Detach) { $dockerRunArgs += '-d' }
  if ($Name) { $dockerRunArgs += '--name'; $dockerRunArgs += $Name }
  $dockerRunArgs += $Image
  if ($Args) { $dockerRunArgs += $Args }
  Write-Host "🐳 docker $($dockerRunArgs -join ' ')"
  & docker @dockerRunArgs
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Run
