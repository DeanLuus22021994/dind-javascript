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
  $dockerBuildCmd = @('build', '-f', $Dockerfile, '-t', $Tag)
  if ($NoCache) { $dockerBuildCmd += '--no-cache' }
  if ($Pull) { $dockerBuildCmd += '--pull' }
  foreach ($key in $BuildArgs.Keys) {
    $dockerBuildCmd += '--build-arg'; $dockerBuildCmd += "$key=$($BuildArgs[$key])"
  }
  $dockerBuildCmd += $Context
  Write-Host "🐳 docker $($dockerBuildCmd -join ' ')"
  & docker @dockerBuildCmd
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Build
