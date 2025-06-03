#!/bin/bash
# micro/docker-run.sh - Single-responsibility: Run a Docker container
# Usage: docker-run.sh <image> [--name NAME] [--detach] [-- <args>...]
set -euo pipefail

image="$1"
shift
args=(run)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --name)
            shift
            args+=(--name "$1")
            ;;
        --detach)
            args+=(-d)
            ;;
        --)
            shift
            break
            ;;
        *)
            ;;
    esac
    shift || true
    [[ $# -eq 0 ]] && break
done

args+=("$image")
if [[ $# -gt 0 ]]; then
    args+=("$@")
fi

echo "🐳 docker ${args[*]}"
docker "${args[@]}"
