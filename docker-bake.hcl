variable "REGISTRY" {
  default = "localhost:5000"
}

variable "TAG" {
  default = "latest"
}

group "default" {
  targets = ["app"]
}

target "app" {
  dockerfile = "Dockerfile"
  tags = ["${REGISTRY}/dind-javascript:${TAG}"]
  cache-from = ["type=local,src=/cache/buildkit"]
  cache-to = ["type=local,dest=/cache/buildkit,mode=max"]
  output = ["type=docker"]
}

target "app-multi" {
  inherits = ["app"]
  platforms = ["linux/amd64", "linux/arm64"]
}

target "app-prod" {
  inherits = ["app"]
  target = "production"
  tags = ["${REGISTRY}/dind-javascript:production"]
}
