# BitNet CPU Docker

Kontener CPU-only dla `microsoft/BitNet` z gotowym API HTTP i orkiestracją przez Docker Compose.

Projekt buduje obraz BitNet, pobiera oficjalny model GGUF z Hugging Face i uruchamia serwer zgodny z API `llama.cpp`.

## Funkcje

- CPU-only runtime
- automatyczne pobieranie modelu `microsoft/bitnet-b1.58-2B-4T-gguf`
- endpointy `health` i `ready`
- gotowy `docker-compose.yml`
- workflow GitHub Actions do publikacji obrazu do GHCR

## Wymagania

- Docker 24+
- Docker Compose v2
- dostęp do internetu podczas pierwszego uruchomienia kontenera

## Szybki start

1. Skopiuj plik środowiskowy:

```bash
cp .env.example .env
```

2. Zbuduj i uruchom usługę:

```bash
docker compose up -d --build
```

3. Sprawdź gotowość:

```bash
curl -sS http://127.0.0.1:8081/health
curl -sS http://127.0.0.1:8081/ready
```

4. Wyślij testowy prompt:

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

## Endpointy

- `GET /health`
  Zwraca bieżący stan startu kontenera.
- `GET /ready`
  Zwraca `200` dopiero wtedy, gdy serwer modelu przyjmuje połączenia.
- `GET /v1/models`
  Lista modeli wystawionych przez `llama-server`.
- `POST /v1/chat/completions`
  Endpoint zgodny z chat completions.

## Konfiguracja

Wartości konfiguracyjne są czytane z `.env` i przekazywane do Compose.

Najważniejsze zmienne:

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

## Publikacja obrazu

Workflow GitHub Actions publikuje obraz do GitHub Container Registry:

- repozytorium obrazu: `ghcr.io/<owner>/<repo>`
- publikacja na `main`
- publikacja przy tagach `v*`

Po wypchnięciu repo do GitHub wystarczy włączyć Actions i nadać repo uprawnienie do pakietów.

## Pliki projektu

- [Dockerfile](/home/prachwal/src/python/BitNet_app/Dockerfile)
- [docker-entrypoint.sh](/home/prachwal/src/python/BitNet_app/docker-entrypoint.sh)
- [docker-compose.yml](/home/prachwal/src/python/BitNet_app/docker-compose.yml)
- [.env.example](/home/prachwal/src/python/BitNet_app/.env.example)
- [.github/workflows/docker-publish.yml](/home/prachwal/src/python/BitNet_app/.github/workflows/docker-publish.yml)

## Uwagi

- Pierwsze uruchomienie trwa dłużej, bo kontener pobiera model z Hugging Face.
- Model jest przechowywany w wolumenie Dockera `bitnet-models`.
- Projekt nie zawiera licencji. Przed publikacją publiczną dodaj plik licencyjny zgodny z Twoją decyzją prawną.
