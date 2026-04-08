# BitNet CPU Docker

[![Docker Publish](https://github.com/prachwal/BitNet_app/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/prachwal/BitNet_app/actions/workflows/docker-publish.yml)
[![GHCR](https://img.shields.io/badge/GHCR-ghcr.io%2Fprachwal%2FBitNet__app-blue)](https://github.com/prachwal/BitNet_app/pkgs/container/BitNet_app)

CPU-only container for `microsoft/BitNet` with an HTTP API and Docker Compose orchestration.

The project builds a BitNet image, downloads the official GGUF model from Hugging Face, and runs a server compatible with the `llama.cpp` API.

## Upstream

This repository is a fork of [microsoft/BitNet](https://github.com/microsoft/BitNet) with custom fixes for Docker, runtime behavior, and image publishing.

## Sync

To pull changes from the original repository, use:

```bash
git fetch upstream
git merge upstream/main
```

If you prefer to keep your own history and apply upstream changes incrementally, use:

```bash
git fetch upstream
git rebase upstream/main
```

## Features

- CPU-only runtime
- automatic download of `microsoft/bitnet-b1.58-2B-4T-gguf`
- `health` and `ready` endpoints
- ready-to-use `docker-compose.yml`
- GitHub Actions workflow for publishing the image to GHCR

## Requirements

- Docker 24+
- Docker Compose v2
- internet access during the first container startup

## Quick Start

1. Copy the environment file:

```bash
cp .env.example .env
```

1. Build and start the service:

```bash
docker compose up -d --build
```

1. Check readiness:

```bash
curl -sS http://127.0.0.1:8081/health
curl -sS http://127.0.0.1:8081/ready
```

1. Send a test prompt:

```bash
curl -sS http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "bitnet",
    "messages": [
      { "role": "user", "content": "Reply with exactly the word OK." }
    ],
    "max_tokens": 8,
    "temperature": 0
  }'
```

## Endpoints

- `GET /health`
  Returns the current startup state of the container.
- `GET /ready`
  Returns `200` only when the model server is accepting connections.
- `GET /v1/models`
  Lists models exposed by `llama-server`.
- `POST /v1/chat/completions`
  Chat completions-compatible endpoint.

## Configuration

Configuration values are read from `.env` and passed to Compose.

Important variables:

- `BITNET_IMAGE_NAME`
- `BITNET_CONTAINER_NAME`
- `BITNET_MODEL_REPO`
- `BITNET_PORT`
- `BITNET_HEALTH_PORT`
- `BITNET_THREADS`
- `BITNET_CTX_SIZE`
- `BITNET_N_PREDICT`
- `BITNET_TEMPERATURE`
- `BITNET_QUANT_TYPE`

## Image Publishing

The GitHub Actions workflow publishes the image to GitHub Container Registry:

- image namespace: `ghcr.io/<owner>/<repo>`
- publish on `main`
- publish on `v*` tags

After pushing the repository to GitHub, enable Actions and grant the repository permission to publish packages.

## Project Files

- [Dockerfile](./Dockerfile)
- [docker-entrypoint.sh](./docker-entrypoint.sh)
- [docker-compose.yml](./docker-compose.yml)
- [CONTRIBUTING.md](./CONTRIBUTING.md)
- [.env.example](./.env.example)
- [.github/workflows/docker-publish.yml](./.github/workflows/docker-publish.yml)
- [CHANGELOG.md](./CHANGELOG.md)

## Notes

- The first run takes longer because the container downloads the model from Hugging Face.
- The model is stored in the Docker volume `bitnet-models`.
- The repository includes the MIT license in [LICENSE](./LICENSE).
- The default RAM limit for the container is `16g`.
- The default `BITNET_THREADS=6` fits the physical cores of an i5-10400F; adjust it in `.env` if needed.
