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

  $argsList = @('build', '-f', $Dockerfile, '-t', $Tag)
  if ($NoCache.IsPresent) { $argsList += '--no-cache' }
  if ($Pull.IsPresent) { $argsList += '--pull' }
  if ($BuildArgs -and $BuildArgs.Count -gt 0) {
    foreach ($key in $BuildArgs.Keys) {
      $argsList += '--build-arg'
      $argsList += ("{0}={1}" -f $key, $BuildArgs[$key])
    }
  }
  $argsList += $Context

  Write-Host ("🐳 docker {0}" -f ($argsList -join ' '))

  $output = & docker @argsList 2>&1
  $exitCode = $LASTEXITCODE
  if ($output) {
    if ($exitCode -eq 0) {
      Write-Host $output
    } else {
      Write-Error $output
    }
  }
  return ($exitCode -eq 0)
}
Export-ModuleMember -Function Build
