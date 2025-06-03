# clean.ps1
# Simple script to remove stopped containers and dangling images
Import-Module "$PSScriptRoot\micro\rm.psm1"
Import-Module "$PSScriptRoot\micro\images.psm1"

# Remove all stopped containers
$stopped = & docker ps -a -q -f status=exited
if ($stopped) {
    foreach ($id in $stopped) {
        Rm -Container $id -Force
    }
}

# Remove all dangling images
$dangling = & docker images -q -f dangling=true
if ($dangling) {
    foreach ($img in $dangling) {
        & docker rmi $img
    }
}
