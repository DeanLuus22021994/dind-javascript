# build.ps1
# Simple script to build the Docker image using the micro Build module
Import-Module "$PSScriptRoot\micro\build.psm1"

# Set defaults for a typical devcontainer build
$context = "$PSScriptRoot\..\.."
$dockerfile = "$context\Dockerfile"
$tag = "dind-javascript-dev"

# Call Build with defaults (no build args, no flags)
Build -Context $context -Dockerfile $dockerfile -Tag $tag
