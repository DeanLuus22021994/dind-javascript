#!/usr/bin/env pwsh
# Enhanced DevContainer Startup Script for PowerShell

Write-Host "🚀 Starting enhanced DevContainer with Docker Compose..." -ForegroundColor Green

# Function to check if Docker Desktop is running
function Test-DockerRunning {
    try {
        $null = docker version 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

# Function to start Docker Desktop
function Start-DockerDesktop {
    Write-Host "Docker Desktop is not running. Starting Docker Desktop..." -ForegroundColor Yellow
    
    # Common Docker Desktop installation paths
    $dockerPaths = @(
        "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe",
        "${env:LOCALAPPDATA}\Programs\Docker\Docker\Docker Desktop.exe",
        "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe"
    )
    
    $dockerPath = $null
    foreach ($path in $dockerPaths) {
        if (Test-Path $path) {
            $dockerPath = $path
            break
        }
    }
    
    if (-not $dockerPath) {
        Write-Error "Docker Desktop not found. Please install Docker Desktop and ensure it's in your PATH."
        exit 1
    }
    
    # Start Docker Desktop
    Start-Process -FilePath $dockerPath -WindowStyle Hidden
    
    # Wait for Docker to be ready (up to 60 seconds)
    Write-Host "Waiting for Docker Desktop to start..." -ForegroundColor Yellow
    $timeout = 60
    $elapsed = 0
    
    while (-not (Test-DockerRunning) -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 2
        $elapsed += 2
        Write-Host "." -NoNewline -ForegroundColor Yellow
    }
    
    Write-Host ""
    
    if (-not (Test-DockerRunning)) {
        Write-Error "Docker Desktop failed to start within $timeout seconds. Please start it manually."
        exit 1
    }
    
    Write-Host "✅ Docker Desktop is now running!" -ForegroundColor Green
}

try {
    # Check if Docker is running, start if not
    if (-not (Test-DockerRunning)) {
        Start-DockerDesktop
    } else {
        Write-Host "✅ Docker Desktop is already running." -ForegroundColor Green
    }    
    # Change to .devcontainer directory
    Set-Location ".devcontainer"    
    if (-not (Test-Path "docker-compose.yml")) {
        Write-Error "docker-compose.yml not found in .devcontainer directory"
        Set-Location ".."
        exit 1
    }
    
    Write-Host "Starting Docker Compose services..." -ForegroundColor Yellow
    docker compose up -d
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start Docker Compose"
        Set-Location ".."
        exit 1
    }    
    Set-Location ".."
    Write-Host "✅ DevContainer is now running. You can attach to it in VS Code." -ForegroundColor Green
    
    # Optional: Wait for services to be ready
    Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    
    Write-Host "Testing container connectivity..." -ForegroundColor Yellow
    docker compose -f .devcontainer/docker-compose.yml ps
    
} catch {
    Write-Error "An error occurred: $_"
    Set-Location ".."
    exit 1
}
