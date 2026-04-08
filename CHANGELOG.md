# Changelog

## Unreleased

- Dodano kontener CPU-only dla `microsoft/BitNet` z serwerem HTTP zgodnym z `llama.cpp`.
- Dodano `docker-compose.yml`, health/readiness endpointy i workflow publikacji obrazu do GHCR.
- Ustalono domyślny limit RAM kontenera na `16g` oraz `BITNET_THREADS=6`.
- Dodano licencję MIT i badge’e GitHub Actions / GHCR do README.

## 0.1.0

- Pierwsza publiczna wersja repozytorium.
- Rozwiązano problemy z budową obrazu wynikające z:
  - braku zgodności toolchaina i potrzeby użycia `clang-18`,
  - błędu kompilacji w kodzie C++ BitNet,
  - niedopasowania konwertera HF -> GGUF do modelu BitNet,
  - konieczności przejścia na oficjalny model GGUF zamiast konwersji w runtime,
  - rozdzielenia pobierania modelu, readiness i startu serwera.
