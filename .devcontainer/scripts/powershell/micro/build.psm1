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
  $dockerBuildArgs = @('build', '-f', $Dockerfile, '-t', $Tag)
  if ($NoCache) { $dockerBuildArgs += '--no-cache' }
  if ($Pull) { $dockerBuildArgs += '--pull' }
  foreach ($key in $BuildArgs.Keys) {
    $dockerBuildArgs += '--build-arg'; $dockerBuildArgs += "$key=$($BuildArgs[$key])"
  }
  $dockerBuildArgs += $Context
  Write-Host "🐳 docker $($dockerBuildArgs -join ' ')"
  & docker @dockerBuildArgs
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Build
