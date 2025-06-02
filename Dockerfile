# syntax=docker/dockerfile:1
FROM node:lts-alpine AS base

# Install dependencies with cache mount
RUN --mount=type=cache,target=/var/cache/apk \
  apk add --no-cache git

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies with cache
RUN --mount=type=cache,target=/root/.npm \
  npm ci --only=production

FROM base AS development
RUN --mount=type=cache,target=/root/.npm \
  npm ci

COPY . .
CMD ["npm", "run", "dev"]

FROM base AS production
COPY . .
CMD ["npm", "start"]
