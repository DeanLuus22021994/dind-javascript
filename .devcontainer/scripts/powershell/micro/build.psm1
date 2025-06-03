# filepath: .devcontainer/scripts/powershell/micro/build.psm1
# Single-responsibility: Docker build
function Build {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Context,
    [Parameter(Mandatory = $true)]
    [string]$Dockerfile,
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [Parameter(Mandatory = $false)]
    [hashtable]$BuildArgs = @{},
    [Parameter(Mandatory = $false)]
    [switch]$NoCache,
    [Parameter(Mandatory = $false)]
    [switch]$Pull
  )
  $dockerBuildCmds = @('build', '-f', $Dockerfile, '-t', $Tag)
  if ($NoCache) { $dockerBuildCmds += '--no-cache' }
  if ($Pull) { $dockerBuildCmds += '--pull' }
  foreach ($key in $BuildArgs.Keys) {
    $dockerBuildCmds += '--build-arg'; $dockerBuildCmds += "$key=$($BuildArgs[$key])"
  }
  $dockerBuildCmds += $Context
  Write-Host "🐳 docker $($dockerBuildCmds -join ' ')"
  & docker @dockerBuildCmds
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Build
