# clean.ps1
# Enhanced script to remove stopped containers and dangling images
Import-Module "$PSScriptRoot\micro\rm.psm1"
Import-Module "$PSScriptRoot\micro\images.psm1"

Write-Host "Cleaning up stopped containers..."
$stopped = & docker ps -a -q -f status=exited
if ($stopped) {
    foreach ($id in $stopped) {
        $result = Rm -Container $id -Force
        if ($result) {
            Write-Host "Removed container: $id"
        } else {
            Write-Warning "Failed to remove container: $id"
        }
    }
} else {
    Write-Host "No stopped containers to remove."
}

Write-Host "Cleaning up dangling images..."
$dangling = & docker images -q -f dangling=true
if ($dangling) {
    foreach ($img in $dangling) {
        $output = & docker rmi $img 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Removed image: $img"
        } else {
            Write-Warning "Failed to remove image: $img. $output"
        }
    }
} else {
    Write-Host "No dangling images to remove."
}
