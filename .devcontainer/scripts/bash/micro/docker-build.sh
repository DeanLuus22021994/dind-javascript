#!/bin/bash
# micro/docker-build.sh - Single-responsibility: Build a Docker image
# Usage: docker-build.sh <context> <dockerfile> <tag> [--no-cache] [--pull] [--build-arg KEY=VALUE ...]
set -euo pipefail

context="$1"
dockerfile="$2"
tag="$3"
shift 3

args=(build -f "$dockerfile" -t "$tag")

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-cache)
            args+=(--no-cache)
            ;;
        --pull)
            args+=(--pull)
            ;;
        --build-arg)
            shift
            args+=(--build-arg "$1")
            ;;
        *)
            ;;
    esac
    shift || true
    [[ $# -eq 0 ]] && break
done

args+=("$context")
echo "🐳 docker ${args[*]}"
docker "${args[@]}"
