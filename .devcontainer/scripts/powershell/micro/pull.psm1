# filepath: .devcontainer/scripts/powershell/micro/pull.psm1
# Single-responsibility: Docker pull
function Pull {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Image
  )
  $argsList = @('pull', $Image)
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
Export-ModuleMember -Function Pull
