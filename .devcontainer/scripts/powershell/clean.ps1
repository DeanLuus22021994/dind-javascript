# clean.ps1
# Simple script to remove stopped containers and dangling images
Import-Module "$PSScriptRoot\micro\rm.psm1"
Import-Module "$PSScriptRoot\micro\images.psm1"


# Remove all stopped containers
$stopped = & docker ps -a -q -f status=exited
if ($stopped) {
  foreach ($id in $stopped) {
    Remove-Item -Container $id -Force | Out-Null
  }
}

# Remove all dangling images
$dangling = & docker images -q -f dangling=true
if ($dangling) {
  foreach ($img in $dangling) {
    Start-Process -FilePath docker -ArgumentList @('rmi', $img) -NoNewWindow -Wait | Out-Null
  }
}
