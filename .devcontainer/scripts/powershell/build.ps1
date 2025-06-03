# build.ps1
# Enhanced script to build the Docker image using the micro Build module
Import-Module "$PSScriptRoot\micro\build.psm1"


# Set defaults for a typical devcontainer build
$context = Join-Path $PSScriptRoot "..\..\.."
$dockerfile = Join-Path $PSScriptRoot "..\..\docker\files\Dockerfile.main"
$tag = "dind-javascript-dev:latest"

Write-Host "Starting Docker build for tag: $tag"
$success = Build -Context $context -Dockerfile $dockerfile -Tag $tag
if ($success) {
  Write-Host "✅ Docker image '$tag' built successfully."
  exit 0
} else {
  Write-Error "❌ Docker build failed for image '$tag'."
  exit 1
}
