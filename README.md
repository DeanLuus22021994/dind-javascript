# Enhanced Docker-in-Docker JavaScript Environment

This project demonstrates an advanced Docker DevContainer setup with optimized
caching, Docker Compose integration, and BuildKit support for instant subsequent
builds.

## Features

- 🚀 **Instant Rebuilds**: Pre-compiled volume cache mounts for
  near-instantaneous builds
- 🐳 **Docker Compose Integration**: Start with `docker compose up -d`
- 🔧 **Privileged Access**: Full host resource access for development
- 📦 **BuildKit & Bake**: Advanced build caching and multi-platform support
- 💾 **Persistent Caches**: Separate volumes for build artifacts and dependencies

## Quick Start

### Windows

```cmd
start-devcontainer.cmd
```

### Linux/Mac

```bash
./start-devcontainer.sh
```

### Manual Start

```bash
cd .devcontainer
docker compose up -d
```

## Architecture

The setup includes:

- **DevContainer**: Main development environment with Node.js
- **BuildKit**: Dedicated container for advanced Docker builds
- **Volume Caches**: Persistent storage for build artifacts and dependencies

## Scripts

- `npm run dev` - Start development server with nodemon
- `npm start` - Start production server
- `npm run build` - Build with Docker BuildX
- `npm run build:prod` - Build production target
- `npm run build:multi` - Multi-platform build

## Testing the Setup

1. Start the DevContainer
2. Attach VS Code to the running container
3. Run `npm run dev` to start the development server
4. Visit `http://localhost:3000` to see the application

The DevContainer will remain running in detached mode, ready for VS Code to
attach to it. All caches persist between sessions for maximum performance.
