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

  # Compose the docker build command arguments
  $dockerBuildArgs = @('build', '-f', $Dockerfile, '-t', $Tag)
  if ($NoCache.IsPresent) { $dockerBuildArgs += '--no-cache' }
  if ($Pull.IsPresent) { $dockerBuildArgs += '--pull' }
  if ($BuildArgs -and $BuildArgs.Count -gt 0) {
    foreach ($key in $BuildArgs.Keys) {
      $dockerBuildArgs += '--build-arg'
      $dockerBuildArgs += ("{0}={1}" -f $key, $BuildArgs[$key])
    }
  }
  $dockerBuildArgs += $Context

  # Output the command for visibility
  Write-Host ("🐳 docker {0}" -f ($dockerBuildArgs -join ' '))

  # Run the docker build command and capture output
  $processInfo = New-Object System.Diagnostics.ProcessStartInfo
  $processInfo.FileName = 'docker'
  $processInfo.Arguments = $dockerBuildArgs -join ' '
  $processInfo.RedirectStandardOutput = $true
  $processInfo.RedirectStandardError = $true
  $processInfo.UseShellExecute = $false
  $processInfo.CreateNoWindow = $true

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $processInfo
  $null = $process.Start()
  $stdOut = $process.StandardOutput.ReadToEnd()
  $stdErr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  $exitCode = $process.ExitCode

  if ($stdOut) { Write-Host $stdOut }
  if ($stdErr) { Write-Error $stdErr }

  return ($exitCode -eq 0)
}
Export-ModuleMember -Function Build
