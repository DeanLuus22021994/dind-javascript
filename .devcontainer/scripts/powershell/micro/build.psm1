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
  $dockerBuildParams = @('build', '-f', $Dockerfile, '-t', $Tag)
  if ($NoCache) { $dockerBuildParams += '--no-cache' }
  if ($Pull) { $dockerBuildParams += '--pull' }
  foreach ($key in $BuildArgs.Keys) {
    $dockerBuildParams += '--build-arg'; $dockerBuildParams += "$key=$($BuildArgs[$key])"
  }
  $dockerBuildParams += $Context
  Write-Host "🐳 docker $($dockerBuildParams -join ' ')"
  & docker @dockerBuildParams
  return $LASTEXITCODE -eq 0
}
Export-ModuleMember -Function Build
